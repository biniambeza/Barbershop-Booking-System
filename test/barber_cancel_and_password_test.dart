import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/data/addis_time.dart';
import 'package:barbershop_booking/features/auth/screens/change_password_screen.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/shared/widgets/app_bar_menu.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:barbershop_booking/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

final _en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  /// A barber account of shop_1 whose profile is not barber_1.
  AppUser otherBarber() =>
      repo.getAllUsers().firstWhere((u) => u.role == UserRole.barber && u.barberId != null && u.barberId != 'barber_1');

  group('barber cancel (repository)', () {
    setUp(() => loadTestSeed(now: _now));

    test('the barber cancels their own confirmed booking: cancelledBy uid, note, slot freed, customer told', () async {
      final notifications = NotificationService(repository: repo)..start();
      addTearDown(notifications.dispose);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final uid = repo.currentUser!.uid;
      final booking = repo.getBookingById('book_1')!;
      expect(booking.status, BookingStatus.confirmed);
      expect(repo.canBarberCancelBooking(booking), isTrue);

      final day = toAddisWallClock(booking.startAt);
      Future<bool> blocked() async =>
          (await repo.watchBarberBusyTimes('shop_1', 'barber_1', DateTime(day.year, day.month, day.day)).first)
              .any((i) => i.start.isBefore(booking.endAt) && i.end.isAfter(booking.startAt));
      expect(await blocked(), isTrue);

      await repo.cancelBookingAsBarber('book_1', reason: '  Sick today  ');

      final after = repo.getBookingById('book_1')!;
      expect(after.status, BookingStatus.cancelled);
      expect(after.cancelledBy, uid);
      expect(after.cancelReasonNote, 'Sick today');
      expect(await blocked(), isFalse);

      final inbox = notifications.local.inboxFor(after.customerId);
      expect(inbox.single.title, 'Booking cancelled');
      expect(inbox.single.body, contains('by the barber'));
      // Whoever cancels is not notified about it.
      expect(notifications.local.inboxFor(uid), isEmpty);
    });

    test('no reason: nothing stored besides the cancel', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.cancelBookingAsBarber('book_1', reason: '   ');
      expect(repo.getBookingById('book_1')!.cancelReasonNote, isNull);
    });

    test('other barbers, customers and owners cannot use the barber cancel', () async {
      final other = otherBarber();
      repo.switchRole(UserRole.barber, targetBarberId: other.barberId);
      expect(repo.currentUser!.uid, other.uid);
      final booking = repo.getBookingById('book_1')!;
      expect(repo.canBarberCancelBooking(booking), isFalse);
      await expectLater(repo.cancelBookingAsBarber('book_1'),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.barberCancelNotAllowed)));

      repo.switchRole(UserRole.customer);
      await expectLater(repo.cancelBookingAsBarber('book_1'),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.barberCancelNotAllowed)));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(repo.cancelBookingAsBarber('book_1'),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.barberCancelNotAllowed)));
      expect(repo.getBookingById('book_1')!.status, BookingStatus.confirmed);
    });

    test('not after the start, not once in progress, reason <= 200 characters', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final booking = repo.getBookingById('book_1')!;

      await expectLater(repo.cancelBookingAsBarber('book_1', reason: 'x' * 201),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.declineReasonTooLong)));

      repo.debugClock = () => booking.startAt;
      expect(repo.canBarberCancelBooking(booking), isFalse);
      await expectLater(repo.cancelBookingAsBarber('book_1'),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.barberCancelAfterStart)));

      repo.debugClock = () => _now;
      await repo.updateBookingStatus('book_1', BookingStatus.inProgress);
      final started = repo.getBookingById('book_1')!;
      expect(repo.canBarberCancelBooking(started), isFalse);
      await expectLater(repo.cancelBookingAsBarber('book_1'),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.bookingNotChangeable)));
      expect(repo.getBookingById('book_1')!.status, BookingStatus.inProgress);
    });
  });

  group('barber cancel (Firestore write)', () {
    test('writes status, cancelledBy and cancelReasonNote and deletes only its own locks', () async {
      final db = FakeFirebaseFirestore();
      final store =
          FirestoreDataStore(cache: DataCache(), firestore: db, onChanged: () {}, onCurrentUserChanged: (_) {});
      Booking booking(String id, DateTime start) => Booking(
            id: id,
            shopId: 's1',
            shopName: 'Shop',
            barberId: 'b1',
            barberName: 'Barber',
            customerId: 'c1',
            customerName: 'Abebe',
            customerPhone: '+251911234567',
            serviceId: 'sv',
            serviceName: 'Cut',
            price: 300,
            date: DateTime(2026, 11, 21),
            timeSlot: '11:00 AM',
            status: BookingStatus.confirmed,
            createdAt: _now,
            startAt: start,
            durationMinutes: 30,
          );
      final mine = booking('bk1', DateTime.utc(2026, 11, 21, 8, 0));
      final other = booking('bk2', DateTime.utc(2026, 11, 21, 8, 30));
      await store.createBooking(mine);
      await store.createBooking(other);

      await store.updateBookingStatus(mine, BookingStatus.cancelled,
          cancelledBy: 'barber_uid', cancelReasonNote: 'Sick today');

      final doc = (await db.collection('bookings').doc('bk1').get()).data()!;
      expect(doc['status'], 'cancelled');
      expect(doc['cancelledBy'], 'barber_uid');
      expect(doc['cancelReasonNote'], 'Sick today');
      final locks = (await db.collection('barbershops/s1/barbers/b1/slotLocks').get()).docs;
      expect(locks.map((d) => d['bookingId']).toSet(), {'bk2'});
      expect(locks.map((d) => d.id), containsAll(slotLockIdsFor(other.startAt, other.endAt)));
    });
  });

  group('barber dashboard', () {
    setUp(() => loadTestSeed(now: _now));

    testWidgets('Cancel → confirm with a reason cancels and shows a snackbar', (tester) async {
      _bigScreen(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await tester.pumpWidget(_app(const BarberDashboardScreen()));
      await tester.pumpAndSettle();

      final cancel = find.byKey(const ValueKey('barber-cancel-book_1'));
      expect(cancel, findsOneWidget);
      expect(find.byKey(const ValueKey('barber-start-book_1')), findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text(_en.barberCancelTitle), findsOneWidget);

      // "Keep booking" changes nothing.
      await tester.tap(find.byKey(const ValueKey('barber-cancel-keep')));
      await tester.pumpAndSettle();
      expect(repo.getBookingById('book_1')!.status, BookingStatus.confirmed);

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('barber-cancel-reason')), 'Family emergency');
      await tester.tap(find.byKey(const ValueKey('barber-cancel-confirm')));
      await tester.pumpAndSettle();

      final after = repo.getBookingById('book_1')!;
      expect(after.status, BookingStatus.cancelled);
      expect(after.cancelledBy, repo.currentUser!.uid);
      expect(after.cancelReasonNote, 'Family emergency');
      expect(find.text(_en.barberCancelDone), findsOneWidget);
    });

    testWidgets('after the start there is no Cancel, only No-show and Start', (tester) async {
      _bigScreen(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final start = repo.getBookingById('book_1')!.startAt;
      repo.debugClock = () => start.add(const Duration(minutes: 5));
      await tester.pumpWidget(_app(const BarberDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('barber-cancel-book_1')), findsNothing);
      expect(find.byKey(const ValueKey('barber-no-show-book_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('barber-start-book_1')), findsOneWidget);
    });
  });

  group('change password', () {
    setUp(() => loadTestSeed(now: _now));

    test('happy path in the local fake: the old password stops working', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final email = repo.currentUser!.email!;
      expect(repo.canChangePassword, isTrue);

      await repo.changePassword(currentPassword: 'demo1234', newPassword: 'newPass2026');

      await repo.signOut();
      await expectLater(repo.loginWithEmail(email: email, password: 'demo1234'),
          throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.wrongCredentials)));
      await repo.loginWithEmail(email: email, password: 'newPass2026');
      expect(repo.currentUser?.email, email);
    });

    test('wrong current password and weak new passwords are rejected', () async {
      repo.switchRole(UserRole.customer);
      await expectLater(repo.changePassword(currentPassword: 'nope1234', newPassword: 'newPass2026'),
          throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.wrongCredentials)));
      await expectLater(repo.changePassword(currentPassword: 'demo1234', newPassword: 'short1'),
          throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.weakPassword)));
      await expectLater(repo.changePassword(currentPassword: 'demo1234', newPassword: 'lettersonly'),
          throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.weakPassword)));
    });

    testWidgets('screen: wrong current password, then success', (tester) async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(actions: const [AppBarMenu(role: UserRole.barbershopOwner)]),
      )));
      await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
      await tester.pumpAndSettle();
      expect(find.text(_en.changePasswordMenu), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-bar-menu-password')));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      Finder field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));
      await tester.enterText(field('change-password-current'), 'wrong1234');
      await tester.enterText(field('change-password-new'), 'newPass2026');
      await tester.enterText(field('change-password-confirm'), 'newPass2026');
      await tester.tap(find.byKey(const ValueKey('change-password-save')));
      await tester.pumpAndSettle();
      expect(find.text(_en.changePasswordErrWrongCurrent), findsOneWidget);

      await tester.enterText(field('change-password-current'), 'demo1234');
      await tester.enterText(field('change-password-confirm'), 'different99');
      await tester.tap(find.byKey(const ValueKey('change-password-save')));
      await tester.pumpAndSettle();
      expect(find.text(_en.passwordsDontMatch), findsOneWidget);

      await tester.enterText(field('change-password-confirm'), 'newPass2026');
      await tester.tap(find.byKey(const ValueKey('change-password-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.text(_en.changePasswordDone), findsOneWidget);
    });

    testWidgets('Google-only users see "Set a password" guidance', (tester) async {
      await signInWithGoogleAs('new.person@gmail.com', displayName: 'New Person');
      await repo.completeProfile(name: 'New Person', phone: '0933 445 566');
      expect(repo.currentUser?.role, UserRole.customer);
      expect(repo.canChangePassword, isFalse);
      await expectLater(repo.changePassword(currentPassword: 'demo1234', newPassword: 'newPass2026'),
          throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.noPassword)));

      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(actions: const [AppBarMenu(role: UserRole.customer)]),
      )));
      await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
      await tester.pumpAndSettle();
      expect(find.text(_en.changePasswordMenu), findsNothing);
      expect(find.text(_en.setPasswordMenu), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-bar-menu-password')));
      await tester.pumpAndSettle();
      expect(find.byType(SetPasswordScreen), findsOneWidget);
      expect(find.text(_en.setPasswordBody('new.person@gmail.com')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('set-password-sign-out')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('set-password-confirm-sign-out')));
      await tester.pumpAndSettle();
      expect(repo.currentUser, isNull);
      expect(repo.takeSetPasswordEmail(), 'new.person@gmail.com');
      expect(repo.takeSetPasswordEmail(), isNull);
    });

    test('"Forgot password" gives a Google-only account a password', () async {
      await signInWithGoogleAs('new.person@gmail.com');
      await repo.completeProfile(name: 'New Person', phone: '0933 445 566');
      expect(repo.canChangePassword, isFalse);
      await repo.signOut();

      await repo.resetRequestCode(email: 'new.person@gmail.com');
      final verified = await repo.resetVerifyCode(email: 'new.person@gmail.com', code: '123456');
      await repo.resetComplete(
          email: 'new.person@gmail.com', verificationToken: verified.verificationToken, newPassword: 'myPass2026');
      await repo.loginWithEmail(email: 'new.person@gmail.com', password: 'myPass2026');
      expect(repo.canChangePassword, isTrue);
    });
  });

  group('manage barbers', () {
    setUp(() => loadTestSeed(now: _now));

    testWidgets('a new barber shows "waiting for sign-up" until the invite is used', (tester) async {
      _bigScreen(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.pumpWidget(_app(const ManageBarbersScreen(shopId: 'shop_1')));
      await tester.pumpAndSettle();

      // The add sheet explains the invitation.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text(_en.barberInviteHelper), findsOneWidget);
      await tester.tap(find.text(_en.cancel).last);
      await tester.pumpAndSettle();

      await repo.addBarber(shopId: 'shop_1', name: 'Dawit Bekele', title: 'Barber', email: 'dawit.bekele@gmail.com');
      final barber = repo.getBarbersForShop('shop_1').firstWhere((b) => b.name == 'Dawit Bekele');
      await tester.pumpWidget(_app(ManageBarbersScreen(key: UniqueKey(), shopId: 'shop_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('barber-invite-waiting-${barber.id}')), findsOneWidget);
      expect(find.text('dawit.bekele@gmail.com'), findsOneWidget);

      // The barber signs up with that Gmail: the invite is consumed.
      await signInWithGoogleAs('dawit.bekele@gmail.com');
      await repo.completeProfile(name: 'Dawit Bekele', phone: '0911 223 344');
      expect(repo.currentUser?.role, UserRole.barber);
      await tester.pumpWidget(_app(ManageBarbersScreen(key: UniqueKey(), shopId: 'shop_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('barber-invite-waiting-${barber.id}')), findsNothing);
    });
  });
}
