import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/features/admin/screens/admin_user_edit_screen.dart';
import 'package:barbershop_booking/features/admin/screens/admin_users_tab.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/invite_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/admin_user_writes.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);
final _joined = DateTime.utc(2026, 1, 5);

AppUser _user(String uid, UserRole role, {String? shopId, String? barberId, String? email, String? phone, String? name}) =>
    AppUser(
      uid: uid,
      email: email ?? '$uid@example.com',
      name: name ?? 'User $uid',
      phone: phone ?? '+251911000${uid.hashCode.abs() % 900 + 100}',
      role: role,
      shopId: shopId,
      barberId: barberId,
      createdAt: _joined,
    );

Barbershop _shop(String id, String ownerId, String name) => Barbershop(
      id: id,
      ownerId: ownerId,
      name: name,
      description: 'd',
      address: 'Road 1',
      city: 'Addis Ababa',
      subCity: 'Bole',
      phone: '+251911223344',
      imageUrl: 'https://example.com/x.jpg',
    );

Booking _booking(String id, {required String customerId, String barberId = 'b1', int hoursFromNow = 24, bool paid = false}) =>
    Booking(
      id: id,
      shopId: 's1',
      shopName: 'Crown Cuts',
      barberId: barberId,
      barberName: 'Abel',
      customerId: customerId,
      customerName: 'Customer',
      customerPhone: '+251911223344',
      serviceId: 'svc',
      serviceName: 'Cut',
      price: 300,
      date: DateTime(2026, 11, 21),
      timeSlot: '10:00',
      createdAt: _now.subtract(const Duration(days: 1)),
      startAt: _now.add(Duration(hours: hoursFromNow)),
      status: BookingStatus.confirmed,
      paymentStatus: paid ? PaymentStatus.paid : PaymentStatus.unpaid,
    );

final _admin = _user('admin1', UserRole.admin, email: 'admin@crown.et', name: 'Hana Admin');
final _admin2 = _user('admin2', UserRole.admin, name: 'Second Admin');
final _owner = _user('owner1', UserRole.barbershopOwner, shopId: 's1', name: 'Owner One');
final _barber = _user('barber1', UserRole.barber, shopId: 's1', barberId: 'b1', name: 'Abel Barber');
final _cust = _user('cust1', UserRole.customer, email: 'selam.b@gmail.com', phone: '+251911223344', name: 'Selam Bekele');
final _cust2 = _user('cust2', UserRole.customer, name: 'Dawit Alemu');

void _seed({List<Booking> bookings = const []}) {
  final repo = AppRepository.instance;
  repo.loadSeed(SeedDataset(
    plans: const [],
    users: [_admin, _admin2, _owner, _barber, _cust, _cust2],
    shops: [_shop('s1', 'owner1', 'Crown Cuts'), _shop('s2', '', 'Blade House')],
    services: const [],
    barbers: [
      Barber(id: 'b1', shopId: 's1', name: 'Abel', title: 'Senior'),
      Barber(id: 'b2', shopId: 's1', name: 'Unlinked Profile', title: 'Junior'),
      Barber(id: 'b3', shopId: 's2', name: 'Blade Barber', title: 'Barber'),
    ],
    bookings: bookings,
  ));
  repo.debugClock = () => _now;
}

Future<void> _signInAdmin() => signInWithGoogleAs('admin@crown.et');

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.darkTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  group('masking and search', () {
    test('emails and phones are partly masked', () {
      expect(maskEmail('selam.b@gmail.com'), 'se***@gmail.com');
      expect(maskEmail('ab@x.et'), 'a***@x.et');
      expect(maskPhone('+251911223344'), '+251 91 *** **44');
      expect(maskPhone('12'), '***');
    });

    test('search matches name, email and any phone spelling', () {
      expect(matchesUserSearch(_cust, 'selam'), isTrue);
      expect(matchesUserSearch(_cust, 'GMAIL'), isTrue);
      expect(matchesUserSearch(_cust, '0911 223'), isTrue);
      expect(matchesUserSearch(_cust, '+251 911223344'), isTrue);
      expect(matchesUserSearch(_cust, '911223344'), isTrue);
      expect(matchesUserSearch(_cust, '0922'), isFalse);
      expect(matchesUserSearch(_cust, 'dawit'), isFalse);
      expect(matchesUserSearch(_cust, '  '), isTrue);
    });

    test('filters by role and disabled, sorted by name', () {
      final disabled = _cust2.copyWith(disabled: true);
      final all = [_admin, _owner, _barber, _cust, disabled];
      expect(filterAdminUsers(all, filter: AdminUserFilter.customer).map((u) => u.uid), ['cust2', 'cust1']);
      expect(filterAdminUsers(all, filter: AdminUserFilter.disabled).map((u) => u.uid), ['cust2']);
      expect(filterAdminUsers(all, filter: AdminUserFilter.barber).single.uid, 'barber1');
      expect(countUsersByFilter(all)[AdminUserFilter.all], 5);
      expect(countUsersByFilter(all)[AdminUserFilter.admin], 1);
    });
  });

  group('AppUser disabled fields', () {
    test('round-trip and are cleared by copyWith(disabled: false)', () {
      final at = DateTime.utc(2026, 11, 20, 7);
      final u = _cust.copyWith(disabled: true, disabledAt: at, disabledBy: 'admin1', disabledReason: 'Spam');
      final map = u.toMap();
      expect(map['disabled'], true);
      expect(map['disabledAt'], '2026-11-20T07:00:00.000Z');
      expect(map['disabledBy'], 'admin1');
      expect(map['disabledReason'], 'Spam');
      final back = AppUser.fromMap(map, u.uid);
      expect((back.disabled, back.disabledAt, back.disabledBy, back.disabledReason), (true, at, 'admin1', 'Spam'));
      final enabled = back.copyWith(disabled: false);
      expect(enabled.disabled, isFalse);
      expect(enabled.toMap().keys.where((k) => k.startsWith('disabled')), isEmpty);
      expect(_cust.toMap().containsKey('disabled'), isFalse);
    });
  });

  group('planRoleChange guards', () {
    RoleChangePlan plan(AppUser actor, AppUser target, RoleTarget to, {List<AppUser>? users, List<UserInvite> invites = const []}) =>
        planRoleChange(
          actor: actor,
          target: target,
          to: to,
          users: users ?? [_admin, _admin2, _owner, _barber, _cust, _cust2],
          shops: {'s1': _shop('s1', 'owner1', 'Crown Cuts'), 's2': _shop('s2', '', 'Blade House')},
          barbers: {
            'b1': Barber(id: 'b1', shopId: 's1', name: 'Abel', title: 'Senior'),
            'b2': Barber(id: 'b2', shopId: 's1', name: 'Free', title: 'Junior'),
          },
          invites: invites,
          newId: () => 'new-barber',
        );

    Matcher refused(AdminUserError code) => throwsA(isA<AdminUserException>().having((e) => e.code, 'code', code));

    test('only admins, never themselves, never the last admin', () {
      expect(() => plan(_owner, _cust, const RoleTarget.admin()), refused(AdminUserError.notAdmin));
      expect(() => plan(_admin, _admin, const RoleTarget.customer()), refused(AdminUserError.cannotChangeSelf));
      // A stale list where the target is the only admin left.
      expect(() => plan(_admin, _admin2, const RoleTarget.customer(), users: [_admin2, _cust]),
          refused(AdminUserError.lastAdmin));
      expect(plan(_admin, _admin2, const RoleTarget.customer()).after.role, UserRole.customer);
    });

    test('shop required, taken barber profile, no change', () {
      expect(() => plan(_admin, _cust, const RoleTarget(UserRole.barbershopOwner)), refused(AdminUserError.shopRequired));
      expect(() => plan(_admin, _cust, const RoleTarget.owner('nope')), refused(AdminUserError.shopNotFound));
      expect(() => plan(_admin, _cust, const RoleTarget.barber('s1', barberId: 'b1')),
          refused(AdminUserError.barberProfileTaken));
      final invite = UserInvite(
          email: 'someone@x.et', role: UserRole.barber, name: 'S', shopId: 's1', barberId: 'b2', createdBy: 'owner1', createdAt: _now);
      expect(() => plan(_admin, _cust, const RoleTarget.barber('s1', barberId: 'b2'), invites: [invite]),
          refused(AdminUserError.barberProfileTaken));
      expect(() => plan(_admin, _cust, const RoleTarget.customer()), refused(AdminUserError.noChange));
      expect(() => plan(_admin, _barber, const RoleTarget.barber('s1')), refused(AdminUserError.noChange));
    });

    test('owner of a new shop: previous owner demoted, owner invites and own invite deleted', () {
      final ownerInvite = UserInvite(
          email: 'pending@x.et', role: UserRole.barbershopOwner, name: 'P', shopId: 's1', createdBy: 'admin1', createdAt: _now);
      final ownInvite = UserInvite(
          email: _cust.email!, role: UserRole.barber, name: 'S', shopId: 's2', barberId: 'b3', createdBy: 'x', createdAt: _now);
      final p = plan(_admin, _cust, const RoleTarget.owner('s1'), invites: [ownerInvite, ownInvite]);
      expect((p.after.role, p.after.shopId, p.after.barberId), (UserRole.barbershopOwner, 's1', null));
      expect(p.claimShopId, 's1');
      expect(p.previousOwners.map((u) => u.uid), ['owner1']);
      expect(p.deleteInviteEmails, unorderedEquals(['pending@x.et', _cust.email]));
    });
  });

  group('repository (local mode)', () {
    setUp(() async {
      _seed();
      await _signInAdmin();
      expect(repo.currentUser?.uid, 'admin1');
    });

    test('customer becomes owner of an unowned shop: shop claimed', () async {
      await repo.adminChangeUserRole('cust1', const RoleTarget.owner('s2'));
      final u = repo.getUserById('cust1')!;
      expect((u.role, u.shopId, u.barberId), (UserRole.barbershopOwner, 's2', null));
      expect(repo.getShopById('s2')!.ownerId, 'cust1');
    });

    test('ownership transfer demotes the old owner; demoted owner releases the shop', () async {
      await repo.adminChangeUserRole('cust1', const RoleTarget.owner('s1'));
      expect(repo.getShopById('s1')!.ownerId, 'cust1');
      expect(repo.getUserById('owner1')!.role, UserRole.customer);
      expect(repo.getUserById('owner1')!.shopId, isNull);

      await repo.adminChangeUserRole('cust1', const RoleTarget.customer());
      expect(repo.getShopById('s1')!.ownerId, '');
      expect(repo.getUserById('cust1')!.shopId, isNull);
    });

    test('making a barber creates or links a profile; removing unlinks it', () async {
      await repo.adminChangeUserRole('cust1', const RoleTarget.barber('s2'));
      final u = repo.getUserById('cust1')!;
      expect((u.role, u.shopId), (UserRole.barber, 's2'));
      final created = repo.getBarberById(u.barberId!)!;
      expect((created.shopId, created.name, created.isAvailable), ('s2', 'Selam Bekele', true));

      expect(repo.linkableBarbersFor('s1', _cust2).map((b) => b.id), ['b2']);
      await repo.adminChangeUserRole('cust2', const RoleTarget.barber('s1', barberId: 'b2'));
      expect(repo.getUserById('cust2')!.barberId, 'b2');

      await repo.adminChangeUserRole('barber1', const RoleTarget.customer());
      expect(repo.getUserById('barber1')!.role, UserRole.customer);
      expect(repo.getUserById('barber1')!.barberId, isNull);
      expect(repo.getBarberById('b1')!.isAvailable, isFalse, reason: 'kept for history, no new bookings');
    });

    test("the person's own pending invite is deleted with the role change", () async {
      await repo.addBarber(shopId: 's1', name: 'Dawit', title: 'Barber', email: _cust2.email);
      expect(repo.getPendingInvites().any((i) => i.email == _cust2.email), isTrue);
      await repo.adminChangeUserRole('cust2', const RoleTarget.admin());
      expect(repo.getPendingInvites().any((i) => i.email == _cust2.email), isFalse);
      expect(repo.getUserById('cust2')!.role, UserRole.admin);
    });

    test('admin cannot change or disable themselves', () async {
      expect(() => repo.adminChangeUserRole('admin1', const RoleTarget.customer()), throwsA(isA<AdminUserException>()));
      expect(() => repo.adminDisableUser('admin1'), throwsA(isA<AdminUserException>()));
    });

    test('the last enabled admin cannot be disabled', () {
      final disabledActor = _admin.copyWith(disabled: true);
      expect(
        () => checkCanDisable(actor: _admin, target: _admin2, users: [disabledActor, _admin2]),
        throwsA(isA<AdminUserException>().having((e) => e.code, 'code', AdminUserError.lastAdmin)),
      );
      checkCanDisable(actor: _admin, target: _admin2, users: [_admin, _admin2]);
    });

    test('disable records who/when/why, refuses sign-in, enable restores it', () async {
      final cancelled = await repo.adminDisableUser('cust1', reason: '  Abusive messages ');
      expect(cancelled, 0);
      final u = repo.getUserById('cust1')!;
      expect((u.disabled, u.disabledBy, u.disabledReason, u.disabledAt), (true, 'admin1', 'Abusive messages', _now));
      expect(() => repo.adminDisableUser('cust1'), throwsA(isA<AdminUserException>()));

      await repo.signOut();
      await signInWithGoogleAs(_cust.email!);
      expect(repo.authStatus, AuthStatus.signedOut);
      expect(repo.currentUser, isNull);
      expect((repo.authError as AppException).code, AppErrorCode.accountDisabled);

      await _signInAdmin();
      await repo.adminEnableUser('cust1');
      expect(repo.getUserById('cust1')!.disabled, isFalse);
      await repo.signOut();
      await signInWithGoogleAs(_cust.email!);
      expect(repo.currentUser?.uid, 'cust1');
    });

    test('reason longer than the limit is refused', () {
      expect(() => repo.adminDisableUser('cust1', reason: 'x' * (kDisableReasonMaxLength + 1)),
          throwsA(isA<AdminUserException>().having((e) => e.code, 'code', AdminUserError.reasonTooLong)));
    });

    test('a signed-in user who gets disabled is signed out by the live listener', () async {
      await repo.signOut();
      await signInWithGoogleAs(_cust.email!);
      expect(repo.authStatus, AuthStatus.signedIn);
      repo.debugCurrentUserDocChanged(_cust.copyWith(disabled: true, disabledBy: 'admin1'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.authStatus, AuthStatus.signedOut);
      expect((repo.authError as AppException).code, AppErrorCode.accountDisabled);
    });
  });

  group('disable with upcoming bookings (local mode)', () {
    test('bookings stay unless asked; then cancelled, paid ones flagged, customers notified', () async {
      _seed(bookings: [
        _booking('bk1', customerId: 'cust1'),
        _booking('bk2', customerId: 'cust2', paid: true),
        _booking('bk3', customerId: 'cust2', hoursFromNow: -2), // past
        _booking('bk4', customerId: 'cust2', barberId: 'b2'), // other barber
      ]);
      await _signInAdmin();
      final notices = <ShopDeletionNotice>[];
      final previous = repo.onLocalNotice;
      repo.onLocalNotice = notices.add;
      addTearDown(() => repo.onLocalNotice = previous);

      expect(await repo.countUpcomingBookingsOf('barber1'), 2);
      expect(await repo.countUpcomingBookingsOf('cust1'), 1);

      await repo.adminDisableUser('cust1');
      expect(repo.getBookingById('bk1')!.status, BookingStatus.confirmed, reason: 'kept without the tick');

      final cancelled = await repo.adminDisableUser('barber1', cancelUpcoming: true);
      expect(cancelled, 2);
      final bk1 = repo.getBookingById('bk1')!;
      final bk2 = repo.getBookingById('bk2')!;
      expect((bk1.status, bk1.cancelReason, bk1.cancelledBy), (BookingStatus.cancelled, kAccountDisabledCancelReason, 'admin1'));
      expect(bk1.refund, isNull);
      expect(bk2.refund?.amount, 300);
      expect(repo.getBookingById('bk3')!.status, BookingStatus.confirmed);
      expect(repo.getBookingById('bk4')!.status, BookingStatus.confirmed);
      expect(notices.map((n) => n.id), unorderedEquals(['bk1_accountDisabled', 'bk2_accountDisabled']));
      expect(notices.first.toMap().keys.toSet(), {'type', 'title', 'body', 'shopId', 'bookingId', 'read', 'createdAt'});
    });

    test('a disabled customer gets no notice about their own bookings', () {
      final items = planDisableCancellations(_cust, [_booking('bk1', customerId: 'cust1')], _now);
      expect(items.single.notice, isNull);
    });
  });

  group('Firestore writes', () {
    test('role change batch: users, barber profile, shop ownerId, invites', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/cust1').set(_cust.toMap());
      await db.doc('users/owner1').set(_owner.toMap());
      await db.doc('barbershops/s1').set({'ownerId': 'owner1', 'name': 'Crown Cuts'});
      await db.doc('invites/${_cust.email}').set({'role': 'barber'});
      final plan = planRoleChange(
        actor: _admin,
        target: _cust,
        to: const RoleTarget.owner('s1'),
        users: [_admin, _owner, _cust],
        shops: {'s1': _shop('s1', 'owner1', 'Crown Cuts')},
        barbers: const {},
        invites: [
          UserInvite(email: _cust.email!, role: UserRole.barber, name: 'S', shopId: 's1', barberId: 'b1', createdBy: 'x', createdAt: _now),
        ],
        newId: () => 'x',
      );
      await FirestoreAdminUserWrites(db).applyRoleChange(plan);
      final cust = (await db.doc('users/cust1').get()).data()!;
      expect((cust['role'], cust['shopId'], cust.containsKey('barberId')), ('barbershopOwner', 's1', false));
      final owner = (await db.doc('users/owner1').get()).data()!;
      expect((owner['role'], owner.containsKey('shopId')), ('customer', false));
      expect((await db.doc('barbershops/s1').get()).data()!['ownerId'], 'cust1');
      expect((await db.doc('invites/${_cust.email}').get()).exists, isFalse);
    });

    test('new barber profile is created without null fields', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/cust1').set(_cust.toMap());
      final plan = planRoleChange(
        actor: _admin,
        target: _cust,
        to: const RoleTarget.barber('s2'),
        users: [_admin, _cust],
        shops: {'s2': _shop('s2', '', 'Blade House')},
        barbers: const {},
        invites: const [],
        newId: () => 'nb1',
      );
      await FirestoreAdminUserWrites(db).applyRoleChange(plan);
      final barber = (await db.doc('barbershops/s2/barbers/nb1').get()).data()!;
      expect(barber['name'], 'Selam Bekele');
      expect(barber.values.contains(null), isFalse);
      expect((await db.doc('users/cust1').get()).data()!['barberId'], 'nb1');
    });

    test('disable writes exactly the disable fields; enable removes them', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/cust1').set(_cust.toMap());
      final writes = FirestoreAdminUserWrites(db);
      await writes.disable('cust1', disableFields(at: _now, by: 'admin1', reason: 'Spam'));
      final data = (await db.doc('users/cust1').get()).data()!;
      expect((data['disabled'], data['disabledAt'], data['disabledBy'], data['disabledReason']),
          (true, '2026-11-20T07:00:00.000Z', 'admin1', 'Spam'));
      expect(disableFields(at: _now, by: 'a').keys, ['disabled', 'disabledAt', 'disabledBy']);
      await writes.enable('cust1');
      final after = (await db.doc('users/cust1').get()).data()!;
      expect(after.keys.where(kDisableFieldKeys.contains), isEmpty);
    });

    test('local writes keep the cache consistent', () async {
      final cache = DataCache()..users['cust1'] = _cust;
      final writes = LocalAdminUserWrites(cache);
      await writes.disable('cust1', disableFields(at: _now, by: 'admin1'));
      expect(cache.users['cust1']!.disabled, isTrue);
      await writes.enable('cust1');
      expect(cache.users['cust1']!.disabled, isFalse);
    });
  });

  group('widgets', () {
    setUp(() async {
      _seed();
      await _signInAdmin();
    });

    testWidgets('Users tab: masked contacts, search, filters, tap opens editor with full details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const Scaffold(body: AdminUsersTab())));
      await tester.pumpAndSettle();

      expect(find.textContaining('+251 91 *** **44'), findsOneWidget);
      expect(find.textContaining('se***@gmail.com'), findsOneWidget);
      expect(find.textContaining('selam.b@gmail.com'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('admin-users-search')), '0911223344');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-user-cust1')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-user-cust2')), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('admin-users-search')), '');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('admin-users-filter-barbershopOwner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-users-filter-barbershopOwner')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-user-owner1')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-user-cust1')), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('admin-users-filter-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-users-filter-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-user-cust1')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUserEditScreen), findsOneWidget);
      expect(find.text('selam.b@gmail.com'), findsOneWidget);
      expect(find.text('+251 91 122 3344'), findsOneWidget);
    });

    testWidgets('edit user: change role to owner after confirming', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const AdminUserEditScreen(uid: 'cust1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('admin-user-role-barbershopOwner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-user-shop')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blade House').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-user-save-role')));
      await tester.pumpAndSettle();
      expect(find.text('Change role?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-user-role-confirm')));
      await tester.pumpAndSettle();

      final u = repo.getUserById('cust1')!;
      expect((u.role, u.shopId), (UserRole.barbershopOwner, 's2'));
      expect(find.text('Role changed.'), findsOneWidget);
    });

    testWidgets('edit user: disable with reason, then enable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const AdminUserEditScreen(uid: 'cust2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('admin-user-disable')));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming bookings'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('admin-user-disable-reason')), 'Fake bookings');
      await tester.tap(find.byKey(const ValueKey('admin-user-disable-confirm')));
      await tester.pumpAndSettle();

      final u = repo.getUserById('cust2')!;
      expect((u.disabled, u.disabledReason), (true, 'Fake bookings'));
      expect(find.text('Reason: Fake bookings'), findsOneWidget);
      expect(find.text('Account disabled.'), findsOneWidget);
      // Let the snackbar go away (it covers the button).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('admin-user-enable')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-user-enable-confirm')));
      await tester.pumpAndSettle();
      expect(repo.getUserById('cust2')!.disabled, isFalse);
      expect(find.byKey(const ValueKey('admin-user-disable')), findsOneWidget);
    });

    testWidgets('own account: no role editor or disable button', (tester) async {
      await tester.pumpWidget(_app(const AdminUserEditScreen(uid: 'admin1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-user-self-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-user-disable')), findsNothing);
      expect(find.byKey(const ValueKey('admin-user-save-role')), findsNothing);
    });

    testWidgets('Amharic strings exist for the new screens', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('am'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const AdminUserEditScreen(uid: 'cust1'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('ተጠቃሚን ያስተካክሉ'), findsOneWidget);
    });
  });
}
