import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/core/config/legal_links.dart';
import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/account/delete_account_screen.dart';
import 'package:barbershop_booking/features/admin/screens/admin_removal_requests_screen.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/features/legal/privacy_policy_screen.dart';
import 'package:barbershop_booking/features/legal/privacy_policy_text.dart';
import 'package:barbershop_booking/features/shared/widgets/app_bar_menu.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/account_auth_service.dart';
import 'package:barbershop_booking/services/account_deletion_writes.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/reviews_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

final _en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// A tall window, so the whole delete form is built (its ListView is lazy).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AppRepository get _repo => AppRepository.instance;

LocalAccountDeletionWrites get _writes => _repo.accountDeletionWrites as LocalAccountDeletionWrites;

LocalAccountAuthService get _auth => _repo.accountAuthService as LocalAccountAuthService;

/// A login with a password ('secret123'); also offers Google when [google].
LocalAccountAuthService _passwordAuth({bool google = false}) => _PasswordAuth(google: google);

class _PasswordAuth extends LocalAccountAuthService {
  _PasswordAuth({required this.google})
      : super(
          hasPassword: (_) => true,
          verifyPassword: (email, password) async {
            if (password != 'secret123') throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
          },
        );

  final bool google;

  @override
  Set<ReauthMethod> methodsFor(String email) => {ReauthMethod.password, if (google) ReauthMethod.google};
}

const _shops = ['shop_1', 'shop_2', 'shop_3', 'shop_4', 'shop_5', 'shop_6'];

List<Review> _reviewsBy(String uid) => [
      for (final s in _shops)
        for (final r in ReviewsService.instance.local.reviewsOf(s))
          if (r.customerId == uid) r,
    ];

AppUser _user(String uid, UserRole role, {bool disabled = false, String? shopId}) => AppUser(
      uid: uid,
      name: uid,
      email: '$uid@example.com',
      role: role,
      shopId: shopId,
      createdAt: _now,
      disabled: disabled,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  setUp(() {
    loadTestSeed(now: _now);
    final reviews = ReviewsService(clock: () => _now, onLocalNotice: (_) {});
    reviews.local.loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now);
    ReviewsService.instance = reviews;
    debugLinkLauncher = (_) async => false; // no browser in tests: the bundled copy opens
  });
  tearDown(() {
    ReviewsService.instance = null;
    debugLinkLauncher = null;
  });

  group('confirmation word', () {
    test('DELETE in any letter case, surrounding spaces ignored', () {
      expect(isDeleteConfirmation('DELETE'), isTrue);
      expect(isDeleteConfirmation('  delete '), isTrue);
      expect(isDeleteConfirmation('Delete'), isTrue);
      expect(isDeleteConfirmation('DELET'), isFalse);
      expect(isDeleteConfirmation('DELETE!'), isFalse);
      expect(isDeleteConfirmation('DE LETE'), isFalse);
      expect(isDeleteConfirmation(''), isFalse);
    });

    test('a wrong word changes nothing', () async {
      _repo.switchRole(UserRole.customer);
      await expectLater(
        _repo.deleteMyAccount(confirmation: 'nope'),
        throwsA(
            isA<AccountDeletionException>().having((e) => e.error, 'error', AccountDeletionError.confirmationMismatch)),
      );
      expect(_repo.currentUser?.uid, 'user_cust_1');
      expect(_writes.deletedProfiles, isEmpty);
      expect(_auth.deletedLogins, isEmpty);
      expect(_repo.getBookingById('book_1')!.status, BookingStatus.confirmed);
    });
  });

  group('customer deletion (local repository)', () {
    test('upcoming bookings cancelled (paid: refund flag, contact kept), history and reviews anonymised', () async {
      _repo.switchRole(UserRole.customer);
      final uid = _repo.currentUser!.uid;
      expect(uid, 'user_cust_1');
      _repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p_book_1');
      final reviewsBefore = _reviewsBy(uid);
      expect(reviewsBefore, isNotEmpty);
      expect(reviewsBefore.any((r) => r.hasComment), isTrue);

      final preview = _repo.previewAccountDeletion();
      expect(preview.canDelete, isTrue);
      expect(preview.toCancel.map((b) => b.id), ['book_1']);
      expect(preview.paidToCancel, 1);
      expect(preview.keptInsideCutoff, isEmpty);

      final steps = <AccountDeletionStep>[];
      await _repo.reauthenticateWithGoogle();
      await _repo.deleteMyAccount(confirmation: ' delete ', onStep: steps.add);

      expect(steps, [
        AccountDeletionStep.cancelBookings,
        AccountDeletionStep.anonymizeReviews,
        AccountDeletionStep.anonymizeBookings,
        AccountDeletionStep.deletePersonalData,
        AccountDeletionStep.deleteProfile,
        AccountDeletionStep.deleteLogin,
      ]);

      // The paid upcoming booking: cancelled, full refund due, the shop keeps the phone.
      final paid = _repo.getBookingById('book_1')!;
      expect(paid.status, BookingStatus.cancelled);
      expect(paid.cancelledBy, uid);
      expect(paid.refund!.isDue, isTrue);
      expect(paid.refund!.reason, RefundReasons.customerCancelled);
      expect(paid.refund!.amount, paid.price);
      expect(paid.customerName, isNot(kFormerCustomerName));
      expect(paid.customerPhone, isNotEmpty);

      // History: "Former customer", no phone; the visit itself stays.
      for (final id in ['book_5', 'book_7', 'book_9']) {
        final b = _repo.getBookingById(id)!;
        expect(b.customerName, kFormerCustomerName, reason: id);
        expect(b.customerPhone, isEmpty, reason: id);
        expect(b.customerId, uid, reason: id);
      }
      expect(_repo.getBookingById('book_9')!.status, BookingStatus.completed);
      // Someone else's booking is untouched.
      expect(_repo.getBookingById('book_3')!.customerName, isNot(kFormerCustomerName));

      // Reviews: stars and reply kept, name replaced, comment gone.
      final reviewsAfter = _reviewsBy(uid);
      expect(reviewsAfter, hasLength(reviewsBefore.length));
      for (final r in reviewsAfter) {
        final before = reviewsBefore.firstWhere((x) => x.bookingId == r.bookingId);
        expect(r.isFormerCustomer, isTrue);
        expect(r.hasComment, isFalse);
        expect(r.rating, before.rating);
        expect(r.reply, before.reply);
      }

      // Profile, personal data and login gone; signed out with a notice.
      expect(_writes.deletedProfiles, [uid]);
      expect(_writes.clearedInboxes, [uid]);
      expect(_repo.getUserById(uid), isNull);
      expect(_auth.deletedLogins, ['liya@example.com']);
      expect(_repo.currentUser, isNull);
      expect(_repo.authStatus, AuthStatus.signedOut);
      expect(_repo.takeAccountDeletedNotice(), isTrue);
      expect(_repo.takeAccountDeletedNotice(), isFalse);
      expect(_repo.accountDeletionPending, isFalse);
    });

    test('inside the cutoff: the booking stays with the shop, anonymised unless it is paid', () async {
      final start = _repo.getBookingById('book_1')!.startAt;
      _repo.debugClock = () => start.subtract(const Duration(hours: 1)); // shop_1 cutoff: 2 h
      _repo.switchRole(UserRole.customer);
      final preview = _repo.previewAccountDeletion();
      expect(preview.toCancel, isEmpty);
      expect(preview.keptInsideCutoff.map((b) => b.id), ['book_1']);

      await _repo.deleteMyAccount(confirmation: 'DELETE');
      final b = _repo.getBookingById('book_1')!;
      expect(b.status, BookingStatus.confirmed);
      expect(b.customerName, kFormerCustomerName);
      expect(b.customerPhone, isEmpty);
    });

    test('inside the cutoff and paid: the phone stays for the refund (the server cancels it on Blaze)', () async {
      final start = _repo.getBookingById('book_1')!.startAt;
      _repo.debugClock = () => start.subtract(const Duration(hours: 1));
      _repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p_book_1');
      _repo.switchRole(UserRole.customer);
      await _repo.deleteMyAccount(confirmation: 'DELETE');
      final b = _repo.getBookingById('book_1')!;
      expect(b.status, BookingStatus.confirmed);
      expect(b.customerName, isNot(kFormerCustomerName));
      expect(b.customerPhone, isNotEmpty);
      expect(keepsContactForRefund(b), isTrue);
    });
  });

  group('barber deletion (local repository)', () {
    test('their customers\' upcoming bookings are cancelled (paid: refunded) and the barber leaves the shop', () async {
      _repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p_book_1');
      _repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final uid = _repo.currentUser!.uid;
      expect(_repo.currentUser!.shopId, 'shop_1');
      final preview = _repo.previewAccountDeletion();
      expect(preview.barberToCancel.map((b) => b.id), contains('book_1'));

      final steps = <AccountDeletionStep>[];
      await _repo.deleteMyAccount(confirmation: 'DELETE', onStep: steps.add);
      expect(steps, contains(AccountDeletionStep.leaveShop));

      final b = _repo.getBookingById('book_1')!;
      expect(b.status, BookingStatus.cancelled);
      expect(b.refund!.reason, RefundReasons.barberCancelled);
      expect(b.refund!.amount, b.price);
      // A customer's booking keeps the customer's details.
      expect(b.customerName, isNot(kFormerCustomerName));
      for (final id in preview.barberToCancel.map((b) => b.id)) {
        expect(_repo.getBookingById(id)!.status, BookingStatus.cancelled, reason: id);
      }
      expect(_repo.getBarberById('barber_1'), isNull);
      expect(_repo.getBarberById('barber_2'), isNotNull);
      expect(_writes.deletedProfiles, [uid]);
      expect(_repo.currentUser, isNull);
    });

    test('the customer notice names the barber and the shop (English and Amharic)', () {
      final b = _repo.getBookingById('book_1')!;
      final en = renderBarberLeftText(b, language: 'en');
      expect(en.title, 'Booking cancelled');
      expect(en.body, contains(b.barberName));
      expect(en.body, contains(b.shopName));
      expect(renderBarberLeftText(b, language: 'am').title, 'ቀጠሮዎ ተሰርዟል');
    });
  });

  group('shop owner and admin', () {
    test('an owner with a shop is blocked and asks the admin, who marks it done or dismissed', () async {
      _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final owner = _repo.currentUser!;
      final preview = _repo.previewAccountDeletion();
      expect(preview.blocker, AccountDeletionBlocker.ownsShop);
      expect(preview.ownedShop!.id, 'shop_1');
      await expectLater(
        _repo.deleteMyAccount(confirmation: 'DELETE'),
        throwsA(isA<AccountDeletionException>().having((e) => e.error, 'error', AccountDeletionError.ownsShop)),
      );
      expect(_writes.deletedProfiles, isEmpty);

      await expectLater(
        _repo.requestShopRemoval(note: 'x' * (kShopRemovalNoteMaxLength + 1)),
        throwsA(isA<AccountDeletionException>().having((e) => e.error, 'error', AccountDeletionError.noteTooLong)),
      );
      await _repo.requestShopRemoval(note: '  Closing the shop  ');
      final mine = await _repo.watchMyShopRemovalRequest().first;
      expect(mine!.isPending, isTrue);
      expect(mine.note, 'Closing the shop');
      expect(mine.shopId, 'shop_1');
      expect(mine.toCreateMap().keys.toSet(),
          {'uid', 'email', 'name', 'shopId', 'shopName', 'note', 'status', 'createdAt'});

      // Only the admin sees and resolves requests.
      expect(await _repo.watchShopRemovalRequests().first, isEmpty);
      expect(() => _repo.resolveShopRemovalRequest(owner.uid, ShopRemovalStatus.done), throwsA(anything));

      _repo.switchRole(UserRole.admin);
      final admin = _repo.currentUser!;
      final list = await _repo.watchShopRemovalRequests().first;
      expect(list.map((r) => r.uid), [owner.uid]);
      await _repo.resolveShopRemovalRequest(owner.uid, ShopRemovalStatus.done);
      final done = _writes.requests[owner.uid]!;
      expect(done.status, ShopRemovalStatus.done);
      expect(done.handledBy, admin.uid);
      expect(done.handledAt, _now);
      expect(ShopRemovalRequest.resolveFields(ShopRemovalStatus.dismissed, at: _now, by: 'a').keys.toSet(),
          {'status', 'handledAt', 'handledBy'});

      // A dismissed request: the owner may send a new one.
      _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      await _repo.requestShopRemoval();
      final owner2 = _repo.currentUser!.uid;
      _repo.switchRole(UserRole.admin);
      await _repo.resolveShopRemovalRequest(owner2, ShopRemovalStatus.dismissed);
      expect(_writes.requests[owner2]!.status, ShopRemovalStatus.dismissed);
      _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      await _repo.withdrawShopRemovalRequest();
      await _repo.requestShopRemoval(note: 'Again');
      expect(_writes.requests[owner2]!.isPending, isTrue);
    });

    test('an owner whose shop is gone can delete the account (blocker logic)', () {
      final owner = _user('o1', UserRole.barbershopOwner, shopId: 'gone');
      final shop = _repo.getShopById('shop_1')!;
      AccountDeletionPreview plan(Map<String, Barbershop> shops) =>
          planAccountDeletion(user: owner, bookings: const [], shops: shops, users: const [], nowUtc: _now);
      expect(plan({}).blocker, isNull);
      // Found by ownerId too, even when the profile lost its shopId.
      expect(plan({'x': shop.copyWith(ownerId: 'o1')}).blocker, AccountDeletionBlocker.ownsShop);
    });

    test('the last enabled admin cannot delete their account', () async {
      _repo.switchRole(UserRole.admin);
      expect(_repo.previewAccountDeletion().blocker, AccountDeletionBlocker.lastAdmin);
      await expectLater(
        _repo.deleteMyAccount(confirmation: 'DELETE'),
        throwsA(isA<AccountDeletionException>().having((e) => e.error, 'error', AccountDeletionError.lastAdmin)),
      );
      expect(_repo.currentUser, isNotNull);

      final me = _user('a1', UserRole.admin);
      AccountDeletionBlocker? blocker(List<AppUser> users) =>
          planAccountDeletion(user: me, bookings: const [], shops: const {}, users: users, nowUtc: _now).blocker;
      expect(blocker([me]), AccountDeletionBlocker.lastAdmin);
      expect(blocker([me, _user('a2', UserRole.admin, disabled: true)]), AccountDeletionBlocker.lastAdmin);
      expect(blocker([me, _user('a2', UserRole.admin)]), isNull);
    });
  });

  group('re-authentication', () {
    test('Firebase wants a fresh sign-in: data deleted, the login after signing in again', () async {
      _repo.switchRole(UserRole.customer);
      final uid = _repo.currentUser!.uid;
      _auth.requireRecentLoginOnce = true;
      await expectLater(
        _repo.deleteMyAccount(confirmation: 'DELETE'),
        throwsA(isA<AccountDeletionException>().having((e) => e.error, 'error', AccountDeletionError.reauthRequired)),
      );
      expect(_repo.accountDeletionPending, isTrue);
      expect(_repo.currentUser?.uid, uid);
      expect(_writes.deletedProfiles, [uid]);
      expect(_auth.deletedLogins, isEmpty);

      final steps = <AccountDeletionStep>[];
      await _repo.reauthenticateWithGoogle();
      await _repo.deleteMyAccount(confirmation: 'DELETE', onStep: steps.add);
      expect(steps, [AccountDeletionStep.deleteLogin]); // nothing deleted twice
      expect(_writes.deletedProfiles, [uid]);
      expect(_auth.deletedLogins, ['liya@example.com']);
      expect(_repo.currentUser, isNull);
    });

    test('signing out after a half-finished deletion does not carry it over to the next account', () async {
      _repo.switchRole(UserRole.customer);
      _auth.requireRecentLoginOnce = true;
      await expectLater(_repo.deleteMyAccount(confirmation: 'DELETE'), throwsA(isA<AccountDeletionException>()));
      expect(_repo.accountDeletionPending, isTrue);
      await _repo.signOut();
      expect(_repo.accountDeletionPending, isFalse);
      _repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      expect(_repo.accountDeletionPending, isFalse);
      expect(_repo.previewAccountDeletion().canDelete, isTrue);
    });

    test('a wrong password or a cancelled Google sign-in stops before anything is deleted', () async {
      _repo.switchRole(UserRole.customer);
      _repo.accountAuthService = _passwordAuth();
      expect(_repo.reauthMethods, {ReauthMethod.password});
      await expectLater(
        _repo.reauthenticateWithPassword('wrong'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.wrongCredentials)),
      );
      await _repo.reauthenticateWithPassword('secret123');

      final google = LocalAccountAuthService(hasPassword: (_) => false, verifyPassword: (_, __) async {})
        ..googleError = const AccountDeletionException(AccountDeletionError.reauthCancelled);
      _repo.accountAuthService = google;
      await expectLater(
        _repo.reauthenticateWithGoogle(),
        throwsA(isA<AccountDeletionException>().having((e) => e.error, 'error', AccountDeletionError.reauthCancelled)),
      );
      expect(_writes.deletedProfiles, isEmpty);
    });
  });

  group('delete account screen', () {
    testWidgets('the button waits for DELETE, then the account is deleted', (tester) async {
      _repo.switchRole(UserRole.customer);
      _tall(tester);
      await tester.pumpWidget(_app(const DeleteAccountScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account-summary')), findsOneWidget);
      expect(find.text(_en.deleteAccountCancelCount(1)), findsOneWidget);

      final submit = find.byKey(const ValueKey('delete-account-submit'));
      ButtonStyleButton button() => tester.widget<ButtonStyleButton>(submit);
      expect(button().onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('delete-account-confirm')), 'DELET');
      await tester.pump();
      expect(button().onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('delete-account-confirm')), 'delete');
      await tester.pump();
      expect(button().onPressed, isNotNull);

      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(_auth.deletedLogins, ['liya@example.com']);
      expect(_repo.currentUser, isNull);
    });

    testWidgets('a cancelled Google sign-in shows why and deletes nothing', (tester) async {
      _repo.switchRole(UserRole.customer);
      _auth.googleError = const AccountDeletionException(AccountDeletionError.reauthCancelled);
      _tall(tester);
      await tester.pumpWidget(_app(const DeleteAccountScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('delete-account-confirm')), 'DELETE');
      await tester.pump();
      final submit = find.byKey(const ValueKey('delete-account-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text(_en.deleteAccountErrReauthCancelled), findsOneWidget);
      expect(_writes.deletedProfiles, isEmpty);
      expect(_repo.currentUser, isNotNull);
    });

    testWidgets('a password account must type its password; a wrong one is shown under the field', (tester) async {
      _repo.switchRole(UserRole.customer);
      _repo.accountAuthService = _passwordAuth();
      _tall(tester);
      await tester.pumpWidget(_app(const DeleteAccountScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account-password')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('delete-account-confirm')), 'DELETE');
      await tester.pump();
      final submit = find.byKey(const ValueKey('delete-account-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text(_en.changePasswordErrCurrentRequired), findsOneWidget);

      await tester.enterText(
          find.descendant(of: find.byKey(const ValueKey('delete-account-password')), matching: find.byType(TextField)),
          'nope');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text(_en.changePasswordErrWrongCurrent), findsOneWidget);
      expect(_writes.deletedProfiles, isEmpty);

      await tester.enterText(
          find.descendant(of: find.byKey(const ValueKey('delete-account-password')), matching: find.byType(TextField)),
          'secret123');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(_writes.deletedProfiles, ['user_cust_1']);
      expect(_repo.currentUser, isNull);
    });

    testWidgets('an owner sees the shop first and sends the removal request', (tester) async {
      _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      _tall(tester);
      await tester.pumpWidget(_app(const DeleteAccountScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account-owner-blocked')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-submit')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('shop-removal-note')), 'Closing');
      await tester.tap(find.byKey(const ValueKey('shop-removal-request')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shop-removal-pending')), findsOneWidget);
      expect(find.text(_en.shopRemovalSent), findsOneWidget);
      expect(_writes.requests.values.single.note, 'Closing');

      await tester.tap(find.byKey(const ValueKey('shop-removal-withdraw')));
      await tester.pumpAndSettle();
      expect(_writes.requests, isEmpty);
      expect(find.byKey(const ValueKey('shop-removal-request')), findsOneWidget);
    });

    testWidgets('the last admin is told why', (tester) async {
      _repo.switchRole(UserRole.admin);
      _tall(tester);
      await tester.pumpWidget(_app(const DeleteAccountScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account-last-admin')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-submit')), findsNothing);
    });

    testWidgets('the admin lists removal requests and marks one done', (tester) async {
      _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final owner = _repo.currentUser!.uid;
      await _repo.requestShopRemoval(note: 'Please remove');
      _repo.switchRole(UserRole.admin);
      await tester.pumpWidget(_app(const AdminRemovalRequestsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('removal-request-$owner')), findsOneWidget);
      expect(find.text('"Please remove"'), findsOneWidget);
      expect(find.byKey(ValueKey('removal-open-shop-$owner')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('removal-done-$owner')));
      await tester.pumpAndSettle();
      expect(_writes.requests[owner]!.status, ShopRemovalStatus.done);
      expect(find.text(_en.shopRemovalStatusDone), findsOneWidget);
      expect(find.byKey(ValueKey('removal-done-$owner')), findsNothing);
    });
  });

  group('entry points', () {
    testWidgets('the app-bar menu opens the privacy policy and Delete account', (tester) async {
      _repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(Scaffold(appBar: AppBar(actions: const [AppBarMenu(role: UserRole.customer)]))));
      await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-bar-menu-privacy')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-bar-menu-delete-account')));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-bar-menu-privacy')));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('signed out, the menu has the privacy policy but no Delete account', (tester) async {
      await tester.pumpWidget(_app(Scaffold(appBar: AppBar(actions: const [AppBarMenu(role: UserRole.customer)]))));
      await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-bar-menu-privacy')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-bar-menu-delete-account')), findsNothing);
    });

    testWidgets('sign-up: "By signing up you agree to our Privacy policy" opens it', (tester) async {
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.pumpAndSettle();
      expect(find.text(_en.privacyConsentPrefix), findsOneWidget);
      final link = find.byKey(const ValueKey('privacy-consent-link'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('with a browser, the web page opens instead of the bundled copy', (tester) async {
      final opened = <Uri>[];
      debugLinkLauncher = (url) async {
        opened.add(url);
        return true;
      };
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.pumpAndSettle();
      final link = find.byKey(const ValueKey('privacy-consent-link'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(kPrivacyPolicyUrl)]);
      expect(find.byType(PrivacyPolicyScreen), findsNothing);
    });
  });

  group('Firestore writes (free plan)', () {
    test('a leaving barber removes their portfolio photos, then the profile and private contact', () async {
      final db = FakeFirebaseFirestore();
      final barber = db.doc('barbershops/s1/barbers/x1');
      await barber.set({'name': 'Dawit'});
      await barber.collection('private').doc('contact').set({'phone': '+251911000201'});
      for (final id in ['p01', 'p02']) {
        await barber.collection('portfolio').doc(id).set({'image': 'aGk=', 'createdAt': '2026-11-01T00:00:00.000Z'});
      }
      await db
          .doc('barbershops/s1/barbers/x2/portfolio/p01')
          .set({'image': 'aGk=', 'createdAt': '2026-11-01T00:00:00.000Z'});
      await FirestoreAccountDeletionWrites(db).removeBarberProfile('s1', 'x1');
      expect((await barber.get()).exists, isFalse);
      expect((await barber.collection('private').doc('contact').get()).exists, isFalse);
      expect((await barber.collection('portfolio').get()).docs, isEmpty);
      expect((await db.doc('barbershops/s1/barbers/x2/portfolio/p01').get()).exists, isTrue);
    });

    test('personal data: invite, unapproved application, removal request of any status, inbox, devices', () async {
      final db = FakeFirebaseFirestore();
      final user = _user('u1', UserRole.customer);
      await db.doc('invites/u1@example.com').set({'role': 'barber'});
      await db.doc('shopApplications/u1').set({'status': 'rejected'});
      await db.doc('shopRemovalRequests/u1').set({'status': 'done', 'email': 'u1@example.com', 'name': 'u1'});
      await db.doc('users/u1/notifications/n1').set({'title': 'x'});
      await db.doc('users/u1/devices/d1').set({'token': 't'});
      await db.doc('users/u2/notifications/n1').set({'title': 'x'});
      final failed = await FirestoreAccountDeletionWrites(db).deletePersonalData(user);
      expect(failed, isEmpty);
      for (final path in [
        'invites/u1@example.com',
        'shopApplications/u1',
        'shopRemovalRequests/u1',
        'users/u1/notifications/n1',
        'users/u1/devices/d1'
      ]) {
        expect((await db.doc(path).get()).exists, isFalse, reason: path);
      }
      expect((await db.doc('users/u2/notifications/n1').get()).exists, isTrue);

      // An approved application stays (the admin's record).
      await db.doc('shopApplications/u1').set({'status': 'approved'});
      await FirestoreAccountDeletionWrites(db).deletePersonalData(user);
      expect((await db.doc('shopApplications/u1').get()).exists, isTrue);
    });

    test('bookings are anonymised with exactly the two fields the rules accept', () async {
      final db = FakeFirebaseFirestore();
      final b = _repo.getBookingById('book_9')!;
      await db.doc('bookings/${b.id}').set(b.toMap());
      expect(await FirestoreAccountDeletionWrites(db).anonymizeBookings([b]), 1);
      final data = (await db.doc('bookings/${b.id}').get()).data()!;
      expect(data['customerName'], kFormerCustomerName);
      expect(data['customerPhone'], '');
      expect(data['customerId'], b.customerId);
      expect(kAnonymizedBookingFields.keys.toSet(), {'customerName', 'customerPhone'});
    });
  });

  group('privacy policy', () {
    for (final (code, policy) in [('en', kPrivacyPolicyEn), ('am', kPrivacyPolicyAm)]) {
      testWidgets('renders in $code', (tester) async {
        await tester.pumpWidget(_app(const PrivacyPolicyScreen(), locale: Locale(code)));
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(code));
        expect(find.text(l.privacyPolicyTitle), findsWidgets);
        expect(find.text(l.privacyPolicyUpdated(kPrivacyPolicyUpdated)), findsOneWidget);
        final list = find.byKey(const ValueKey('privacy-policy-list'));
        for (final s in policy) {
          await tester.scrollUntilVisible(find.text(s.title), 300,
              scrollable: find.descendant(of: list, matching: find.byType(Scrollable)).first);
          expect(find.text(s.title), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the web and delete-page links use the configured URLs', (tester) async {
      final opened = <Uri>[];
      debugLinkLauncher = (url) async {
        opened.add(url);
        return false;
      };
      await tester.pumpWidget(_app(const PrivacyPolicyScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacy-open-web')));
      await tester.pumpAndSettle();
      expect(find.text(_en.privacyLinkFailed), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('privacy-open-delete-page')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(kPrivacyPolicyUrl), Uri.parse(kDeleteAccountUrl)]);
    });

    test('both languages have the same sections, and the web page has every title', () {
      expect(kPrivacyPolicyAm, hasLength(kPrivacyPolicyEn.length));
      expect(privacyPolicySections('am'), same(kPrivacyPolicyAm));
      expect(privacyPolicySections('en'), same(kPrivacyPolicyEn));
      final web = File('web/privacy.html').readAsStringSync();
      String esc(String s) => s.replaceAll('&', '&amp;');
      for (final s in [...kPrivacyPolicyEn, ...kPrivacyPolicyAm]) {
        expect(web, contains('<h2>${esc(s.title)}</h2>'), reason: s.title);
      }
      expect(web, contains('Last updated $kPrivacyPolicyUpdated'));
    });

    test('portfolio photos (consent, removal) and the map pin are covered in both languages and on the web', () {
      final en = kPrivacyPolicyEn.map((s) => s.body).join('\n');
      final am = kPrivacyPolicyAm.map((s) => s.body).join('\n');
      expect(en, contains('Portfolio photos'));
      expect(en, contains('ask the customer'));
      expect(en, contains('removes it when the customer asks'));
      expect(en, contains('map pin'));
      expect(am, contains('የሥራ ፎቶዎች'));
      expect(am, contains('ደንበኛውን መጠየቅ አለበት'));
      expect(am, contains('በካርታ'));
      final web = File('web/privacy.html').readAsStringSync();
      expect(web, contains('Portfolio photos of haircuts are public.'));
      expect(web, contains('የፀጉር ቁርጥ የሥራ ፎቶዎች ለሁሉም ይታያሉ።'));
    });

    test('the contact address is defined in exactly one Dart place and used by the web pages', () {
      final defining = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.readAsStringSync().contains("'$kPrivacyContactEmail'")) defining.add(f.path.replaceAll('\\', '/'));
      }
      expect(defining, ['lib/core/config/legal_links.dart']);
      expect(kPrivacyPolicyEn.first.body, contains(kPrivacyContactEmail));
      expect(kPrivacyPolicyAm.first.body, contains(kPrivacyContactEmail));
      for (final page in ['web/privacy.html', 'web/delete-account.html']) {
        expect(File(page).readAsStringSync(), contains('mailto:$kPrivacyContactEmail'), reason: page);
      }
    });
  });
}
