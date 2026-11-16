import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/admin/screens/admin_register_shop_screen.dart';
import 'package:barbershop_booking/features/admin/screens/admin_shop_edit_screen.dart';
import 'package:barbershop_booking/features/admin/widgets/shop_suspension_widgets.dart';
import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/customize_shop_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/invite_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Barbershop _shop(String id,
        {String name = 'Shop',
        String subCity = 'Bole',
        bool verified = false,
        bool adminSuspended = false,
        SubscriptionStatus status = SubscriptionStatus.active}) =>
    Barbershop(
      id: id,
      ownerId: '',
      name: name,
      description: 'd',
      address: 'Road 1',
      city: 'Addis Ababa',
      subCity: subCity,
      phone: '+251911223344',
      imageUrl: 'https://example.com/x.jpg',
      isVerified: verified,
      adminSuspended: adminSuspended,
      subscriptionStatus: status,
    );

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  group('Barbershop model', () {
    test('isBlocked = admin suspended or subscription suspended', () {
      expect(_shop('a').isBlocked, isFalse);
      expect(_shop('a', adminSuspended: true).isBlocked, isTrue);
      expect(_shop('a', status: SubscriptionStatus.suspended).isBlocked, isTrue);
      expect(_shop('a', status: SubscriptionStatus.pastDue).isBlocked, isFalse);
    });

    test('suspension fields round-trip and are only written when suspended', () {
      final at = DateTime.utc(2026, 11, 18, 7);
      final s = _shop('a').copyWith(
          adminSuspended: true, adminSuspendedReason: 'Licence', adminSuspendedAt: at, adminSuspendedBy: 'admin_1');
      final map = s.toMap();
      expect(map['adminSuspended'], true);
      expect(map['adminSuspendedReason'], 'Licence');
      expect(map['adminSuspendedAt'], '2026-11-18T07:00:00.000Z');
      expect(map['adminSuspendedBy'], 'admin_1');
      final back = Barbershop.fromMap(map, 'a');
      expect((back.adminSuspended, back.adminSuspendedReason, back.adminSuspendedAt, back.adminSuspendedBy),
          (true, 'Licence', at, 'admin_1'));
      expect(_shop('b').toMap().keys.where((k) => k.startsWith('adminSuspended')), isEmpty);
      final cleared = s.copyWith(clearAdminSuspension: true);
      expect((cleared.adminSuspended, cleared.adminSuspendedReason, cleared.adminSuspendedAt), (false, null, null));
    });

    test('adminSuspensionFields shapes', () {
      expect(Barbershop.adminSuspensionFields(suspended: true, reason: 'r', at: _now, by: 'u'), {
        'adminSuspended': true,
        'adminSuspendedReason': 'r',
        'adminSuspendedAt': '2026-11-20T07:00:00.000Z',
        'adminSuspendedBy': 'u',
      });
      expect(Barbershop.adminSuspensionFields(suspended: false, reason: 'ignored'), {
        'adminSuspended': false,
        'adminSuspendedReason': null,
        'adminSuspendedAt': null,
        'adminSuspendedBy': null,
      });
    });

    test('toAdminEditMap holds the profile (no opening hours), verification and subscription override', () {
      final map = _shop('a', verified: true).copyWith(subscriptionPlan: 'pro').toAdminEditMap();
      // Opening hours are owner-only: the admin edit never writes them.
      expect(map.keys, isNot(contains('openingHour')));
      expect(map.keys, isNot(contains('closingHour')));
      expect(map.keys, isNot(contains('workingDays')));
      expect(Barbershop.ownerOnlyHoursFields, ['openingHour', 'closingHour', 'workingDays']);
      // ...while the owner's profile update still holds them.
      expect(_shop('a').toProfileMap().keys, containsAll(Barbershop.ownerOnlyHoursFields));
      expect(map.keys.toSet(), {
        ...Barbershop.fromMap(const {}, 'x').toProfileMap().keys.where((k) => !Barbershop.ownerOnlyHoursFields.contains(k)),
        'isVerified',
        'subscriptionPlan',
        'subscriptionStatus',
        'subscriptionEndsAt',
      });
      expect(map['subscriptionEndsAt'], isNull);
      expect(map['isVerified'], true);
      expect(map['subscriptionPlan'], 'pro');
    });
  });

  group('admin shops logic', () {
    final shops = [
      _shop('1', name: 'Crown Cuts', subCity: 'Bole', verified: true),
      _shop('2', name: 'Piassa Heritage', subCity: 'Arada'),
      _shop('3', name: 'Sarbet Fade', subCity: 'Kolfe Keranio', adminSuspended: true),
      _shop('4', name: 'Megenagna', subCity: 'Yeka', status: SubscriptionStatus.suspended, verified: true),
    ];
    List<String> ids(List<Barbershop> l) => l.map((s) => s.id).toList();

    test('search by name, sub-city and address, ignoring case and spaces', () {
      expect(ids(filterAdminShops(shops, query: '  crown ')), ['1']);
      expect(ids(filterAdminShops(shops, query: 'arada')), ['2']);
      expect(ids(filterAdminShops(shops, query: 'ROAD')), ['1', '2', '3', '4']);
      expect(filterAdminShops(shops, query: 'nothing'), isEmpty);
    });

    test('filters', () {
      expect(ids(filterAdminShops(shops, filter: AdminShopFilter.active)), ['1', '2']);
      expect(ids(filterAdminShops(shops, filter: AdminShopFilter.suspended)), ['3', '4']);
      expect(ids(filterAdminShops(shops, filter: AdminShopFilter.verified)), ['1', '4']);
      expect(ids(filterAdminShops(shops, filter: AdminShopFilter.unverified)), ['2', '3']);
      expect(ids(filterAdminShops(shops, query: 'yeka', filter: AdminShopFilter.suspended)), ['4']);
    });

    test('counts', () {
      final c = AdminShopCounts.of(shops);
      expect((c.total, c.active, c.suspended), (4, 2, 2));
    });

    test('suspend reason is 1..300 characters after trimming', () {
      expect(validateSuspendReason('  Late fees  '), 'Late fees');
      expect(() => validateSuspendReason('   '),
          throwsA(isA<AdminShopException>().having((e) => e.error, 'error', AdminShopError.reasonRequired)));
      expect(validateSuspendReason('x' * 300).length, 300);
      expect(() => validateSuspendReason('x' * 301),
          throwsA(isA<AdminShopException>().having((e) => e.error, 'error', AdminShopError.reasonTooLong)));
    });

    test('typed-name delete confirmation', () {
      expect(deleteConfirmationMatches('Crown Cuts', 'Crown Cuts'), isTrue);
      expect(deleteConfirmationMatches(' Crown Cuts ', 'Crown Cuts'), isTrue);
      expect(deleteConfirmationMatches('crown cuts', 'Crown Cuts'), isFalse);
      expect(deleteConfirmationMatches('', ''), isFalse);
    });

    test('edit validation trims and rejects bad input', () {
      final ok = validateAdminShopEdit(_shop('a').copyWith(name: '  New  ', landmark: '   '));
      expect(ok.name, 'New');
      expect(ok.landmark, isNull);
      AdminShopError err(Barbershop s, {List<String> plans = const []}) {
        try {
          validateAdminShopEdit(s, planIds: plans);
        } on AdminShopException catch (e) {
          return e.error;
        }
        fail('expected an AdminShopException');
      }

      expect(err(_shop('a').copyWith(name: ' ')), AdminShopError.nameRequired);
      expect(err(_shop('a').copyWith(name: 'x' * 81)), AdminShopError.nameTooLong);
      expect(err(_shop('a').copyWith(address: '')), AdminShopError.addressRequired);
      expect(err(_shop('a').copyWith(subscriptionPlan: 'gold'), plans: ['trial', 'pro']), AdminShopError.invalidPlan);
    });

    test('weekdays summary joins runs of three or more days', () {
      String name(int d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
      expect(weekdaysSummary([1, 2, 3, 4, 5, 6], name), 'Mon–Sat');
      expect(weekdaysSummary([7, 1, 2, 3, 4, 5, 6, 6], name), 'Mon–Sun');
      expect(weekdaysSummary([1, 2, 3, 5, 7], name), 'Mon–Wed, Fri, Sun');
      expect(weekdaysSummary([1, 2, 4, 5], name), 'Mon, Tue, Thu, Fri');
      expect(weekdaysSummary(const [], name), '');
    });

    test('owner lookup: account, pending invite or none', () {
      final shop = _shop('s1');
      final owner = AppUser(
          uid: 'o', email: 'o@x.com', name: 'O', role: UserRole.barbershopOwner, shopId: 's1', createdAt: _now);
      final invite = UserInvite(
          email: 'p@x.com', role: UserRole.barbershopOwner, name: 'P', shopId: 's1', createdBy: 'a', createdAt: _now);
      final barberInvite = UserInvite(
          email: 'b@x.com', role: UserRole.barber, name: 'B', shopId: 's1', createdBy: 'a', createdAt: _now);
      final a = ShopOwnerInfo.find(shop, users: [owner], invites: [invite]);
      expect((a.hasAccount, a.email), (true, 'o@x.com'));
      final b = ShopOwnerInfo.find(shop, users: const [], invites: [barberInvite, invite]);
      expect((b.isInvitePending, b.email), (true, 'p@x.com'));
      expect(ShopOwnerInfo.find(shop, users: const [], invites: [barberInvite]).isUnassigned, isTrue);
    });
  });

  group('seed', () {
    test('shop_4 is the admin-suspended demo shop', () {
      final seed = loadSeedDataset(now: _now);
      final s4 = seed.shops.firstWhere((s) => s.id == 'shop_4');
      expect(s4.adminSuspended, isTrue);
      expect(s4.isBlocked, isTrue);
      expect(s4.subscriptionStatus, SubscriptionStatus.trialing);
      expect(s4.adminSuspendedAt, DateTime.utc(2026, 11, 18, 7));
      expect(s4.adminSuspendedBy, 'user_admin_1');
      expect(s4.adminSuspendedReason, isNotEmpty);
      expect(seed.shops.where((s) => s.adminSuspended).map((s) => s.id), ['shop_4']);
    });
  });

  group('repository (local)', () {
    setUp(() => loadTestSeed(now: _now));

    test('customers do not see admin-suspended shops; admin and the shop staff do', () {
      repo.switchRole(UserRole.customer);
      expect(repo.getShops().map((s) => s.id), isNot(contains('shop_4')));
      expect(repo.getAllBarbersWithShops().any((b) => b.shop.id == 'shop_4'), isFalse);
      repo.switchRole(UserRole.admin);
      expect(repo.getShops().map((s) => s.id), contains('shop_4'));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_4');
      expect(repo.getShops().map((s) => s.id), contains('shop_4'));
    });

    test('an admin-suspended shop cannot be booked and offers no slots', () async {
      repo.switchRole(UserRole.customer);
      final shop = repo.getShopById('shop_4')!;
      final barber = repo.getBarbersForShop('shop_4').first;
      final service = repo.getServicesForShop('shop_4').first;
      await expectLater(
        repo.createBooking(
          shopId: shop.id,
          shopName: shop.name,
          barberId: barber.id,
          barberName: barber.name,
          serviceId: service.id,
          serviceName: service.name,
          price: service.price,
          date: DateTime(2026, 11, 21),
          timeSlot: '10:00 AM',
        ),
        throwsA(isA<AppStateException>().having((e) => e.code, 'code', AppErrorCode.shopNotTakingBookings)),
      );
      expect(isBookableDate(shop: shop, barber: barber, addisDate: DateTime(2026, 11, 21), nowUtc: _now), isFalse);
    });

    test('admin suspends with a reason, then reactivates', () async {
      repo.switchRole(UserRole.admin);
      final admin = repo.currentUser!;
      await expectLater(repo.suspendShop('shop_1', '  '), throwsA(isA<AdminShopException>()));
      await expectLater(repo.suspendShop('shop_1', 'x' * 301), throwsA(isA<AdminShopException>()));
      await repo.suspendShop('shop_1', '  Unpaid fines  ');
      final s = repo.getShopById('shop_1')!;
      expect((s.adminSuspended, s.adminSuspendedReason, s.adminSuspendedAt, s.adminSuspendedBy),
          (true, 'Unpaid fines', _now, admin.uid));
      expect(s.subscriptionStatus, SubscriptionStatus.active, reason: 'separate from the subscription');

      repo.switchRole(UserRole.customer);
      expect(repo.getShops().any((x) => x.id == 'shop_1'), isFalse);
      // Existing bookings stay.
      expect(repo.getAllBookings().any((b) => b.shopId == 'shop_1'), isTrue);

      repo.switchRole(UserRole.admin);
      await repo.reactivateShop('shop_1');
      final r = repo.getShopById('shop_1')!;
      expect((r.adminSuspended, r.adminSuspendedReason, r.adminSuspendedAt, r.adminSuspendedBy),
          (false, null, null, null));
      repo.switchRole(UserRole.customer);
      expect(repo.getShops().any((x) => x.id == 'shop_1'), isTrue);
    });

    test('only the admin can suspend, edit or delete', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      AdminShopError? code(Object e) => e is AdminShopException ? e.error : null;
      Future<AdminShopError?> err(Future<void> f) async {
        try {
          await f;
        } catch (e) {
          return code(e);
        }
        return null;
      }

      expect(await err(repo.suspendShop('shop_1', 'x')), AdminShopError.notAdmin);
      expect(await err(repo.reactivateShop('shop_4')), AdminShopError.notAdmin);
      expect(await err(repo.adminUpdateShop(repo.getShopById('shop_1')!)), AdminShopError.notAdmin);
      expect(await err(repo.deleteShopConfirmed('shop_1', 'Crown Cuts Bole')), AdminShopError.notAdmin);
      repo.switchRole(UserRole.admin);
      expect(await err(repo.suspendShop('nope', 'x')), AdminShopError.shopNotFound);
    });

    test('admin edit saves profile, verified flag and subscription override', () async {
      repo.switchRole(UserRole.admin);
      final end = DateTime.utc(2027, 2, 1, 20, 59);
      final shop = repo.getShopById('shop_2')!;
      await repo.adminUpdateShop(shop.copyWith(
        name: '  Kazanchis Classic  ',
        address: 'New Road',
        subCity: 'Kirkos',
        phone: '+251911000000',
        description: 'Updated',
        isVerified: false,
        subscriptionPlan: 'pro',
        subscriptionStatus: SubscriptionStatus.active,
        subscriptionEndsAt: end,
      ));
      final s = repo.getShopById('shop_2')!;
      expect(s.name, 'Kazanchis Classic');
      expect((s.address, s.phone, s.description), ('New Road', '+251911000000', 'Updated'));
      expect((s.isVerified, s.subscriptionPlan, s.subscriptionStatus, s.subscriptionEndsAt),
          (false, 'pro', SubscriptionStatus.active, end));
      // Rating, policy and opening hours are untouched.
      expect((s.rating, s.reviewCount, s.maxReschedules), (shop.rating, shop.reviewCount, shop.maxReschedules));
      expect((s.openingHour, s.closingHour), (shop.openingHour, shop.closingHour));
      expect(s.workingDays, shop.workingDays);

      // Clearing the end date; bad input is refused.
      await repo.adminUpdateShop(s.copyWith(clearSubscriptionEndsAt: true));
      expect(repo.getShopById('shop_2')!.subscriptionEndsAt, isNull);
      await expectLater(repo.adminUpdateShop(s.copyWith(subscriptionPlan: 'gold')), throwsA(isA<AdminShopException>()));
    });

    test('opening hours are owner-only: the admin edit keeps them, the owner changes them', () async {
      repo.switchRole(UserRole.admin);
      final shop = repo.getShopById('shop_1')!;
      final hours = (shop.openingHour, shop.closingHour);
      final days = List<int>.of(shop.workingDays);
      // Even hours passed in the edited shop are not written.
      await repo.adminUpdateShop(shop.copyWith(
        name: 'Admin renamed',
        openingHour: 6,
        closingHour: 23,
        workingDays: [7],
      ));
      var s = repo.getShopById('shop_1')!;
      expect(s.name, 'Admin renamed');
      expect((s.openingHour, s.closingHour), hours);
      expect(s.workingDays, days);

      // The owner's profile update (Customize shop) sets them.
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateShop(s.copyWith(openingHour: 7, closingHour: 22, workingDays: [2, 3, 4, 5, 6, 7]));
      s = repo.getShopById('shop_1')!;
      expect((s.openingHour, s.closingHour), (7, 22));
      expect(s.workingDays, [2, 3, 4, 5, 6, 7]);
      expect(s.name, 'Admin renamed');
    });

    test('delete needs the exact shop name and removes services, barbers and invites', () async {
      repo.switchRole(UserRole.admin);
      await repo.addBarber(shopId: 'shop_3', name: 'Invited', title: 'Barber', email: 'invited.three@gmail.com');
      final name = repo.getShopById('shop_3')!.name;
      await expectLater(repo.deleteShopConfirmed('shop_3', 'wrong'),
          throwsA(isA<AdminShopException>().having((e) => e.error, 'error', AdminShopError.nameMismatch)));
      expect(repo.getShopById('shop_3'), isNotNull);
      await repo.deleteShopConfirmed('shop_3', ' $name ');
      expect(repo.getShopById('shop_3'), isNull);
      expect(repo.getServicesForShop('shop_3'), isEmpty);
      expect(repo.getBarbersForShop('shop_3'), isEmpty);
      expect(repo.getPendingInvites().any((i) => i.shopId == 'shop_3'), isFalse);
    });

    test('owner info: signed-up owner or pending invite', () async {
      repo.switchRole(UserRole.admin);
      final info = repo.getShopOwnerInfo('shop_1');
      expect(info.hasAccount, isTrue);
      expect(info.user!.role, UserRole.barbershopOwner);
      final newId = await repo.registerBarbershopByAdmin(
        shopName: 'New Shop',
        ownerName: 'New Owner',
        ownerEmail: 'new.owner.adminshops@gmail.com',
        address: 'Somewhere',
        city: 'Addis Ababa',
        description: 'x',
        imageUrl: '',
        isVerified: false,
      );
      final pending = repo.getShopOwnerInfo(newId);
      expect((pending.isInvitePending, pending.email), (true, 'new.owner.adminshops@gmail.com'));
      // The admin does not pick hours: the new shop gets the defaults.
      final created = repo.getShopById(newId)!;
      expect((created.openingHour, created.closingHour), (9, 20));
      expect(created.workingDays, [1, 2, 3, 4, 5, 6, 7]);
    });
  });

  group('Firestore writes', () {
    late FakeFirebaseFirestore db;
    late FirestoreDataStore store;
    late SeedDataset seed;

    setUp(() async {
      seed = loadSeedDataset(now: _now);
      db = FakeFirebaseFirestore();
      for (final s in seed.shops) {
        await db.collection('barbershops').doc(s.id).set(s.toMap()..removeWhere((_, v) => v == null));
      }
      for (final b in seed.bookings) {
        await db.collection('bookings').doc(b.id).set(b.toMap());
      }
      for (final u in seed.users) {
        await db.collection('users').doc(u.uid).set(u.toMap());
      }
      store = FirestoreDataStore(cache: DataCache(), firestore: db, onChanged: () {}, onCurrentUserChanged: (_) {});
    });
    tearDown(() => store.stop());

    test('the admin loads no bookings', () async {
      await store.start(seed.users.firstWhere((u) => u.role == UserRole.admin));
      expect(store.cache.shops.length, seed.shops.length);
      expect(store.cache.bookings, isEmpty);
    });

    test('suspend writes the four fields; reactivate deletes three', () async {
      await store.setShopAdminSuspension(
          'shop_1', Barbershop.adminSuspensionFields(suspended: true, reason: 'r', at: _now, by: 'user_admin_1'));
      var doc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      expect((doc['adminSuspended'], doc['adminSuspendedReason'], doc['adminSuspendedAt'], doc['adminSuspendedBy']),
          (true, 'r', '2026-11-20T07:00:00.000Z', 'user_admin_1'));
      expect(doc['subscriptionStatus'], 'active');

      await store.setShopAdminSuspension('shop_1', Barbershop.adminSuspensionFields(suspended: false));
      doc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      expect(doc['adminSuspended'], false);
      expect(doc.keys.where((k) => k.startsWith('adminSuspended') && k != 'adminSuspended'), isEmpty);
    });

    test('admin edit is one update of the edit fields; null end date deletes it', () async {
      final before = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      final shop = Barbershop.fromMap(before, 'shop_1');
      await store.adminUpdateShop(shop.copyWith(
          name: 'Renamed', isVerified: false, subscriptionPlan: 'basic', clearSubscriptionEndsAt: true));
      final doc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      expect((doc['name'], doc['isVerified'], doc['subscriptionPlan']), ('Renamed', false, 'basic'));
      expect(doc.containsKey('subscriptionEndsAt'), isFalse);
      expect((doc['rating'], doc['reviewCount'], doc['ownerId']), (before['rating'], before['reviewCount'], before['ownerId']));
    });

    test('admin edit never writes the opening hours; the owner profile update does', () async {
      final before = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      final shop = Barbershop.fromMap(before, 'shop_1');
      await store.adminUpdateShop(shop.copyWith(name: 'Renamed', openingHour: 6, closingHour: 23, workingDays: [7]));
      var doc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      expect(doc['name'], 'Renamed');
      expect((doc['openingHour'], doc['closingHour']), (before['openingHour'], before['closingHour']));
      expect(doc['workingDays'], before['workingDays']);

      await store.updateShopProfile(shop.copyWith(openingHour: 7, closingHour: 22, workingDays: [1, 2, 3]));
      doc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
      expect((doc['openingHour'], doc['closingHour']), (7, 22));
      expect(doc['workingDays'], [1, 2, 3]);
    });

    test('a customer listing still receives an admin-suspended shop (hidden by the app)', () async {
      await store.start(seed.users.firstWhere((u) => u.uid == 'user_cust_1'));
      expect(store.cache.shops['shop_4']?.adminSuspended, isTrue);
    });
  });

  group('screens', () {
    setUp(() => loadTestSeed(now: _now));

    // The shops tab is a lazy ListView: build the card, then scroll it to
    // the top (clear of the floating Register button).
    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find
            .descendant(of: find.byKey(const ValueKey('admin-shops-tab')), matching: find.byType(Scrollable))
            .first,
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    Future<void> pump(WidgetTester tester, Widget screen, {Locale locale = const Locale('en')}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(screen, locale: locale));
      await tester.pumpAndSettle();
    }

    testWidgets('admin dashboard: Shops, Payments and Users tabs (no bookings), suspended filter', (tester) async {
      repo.switchRole(UserRole.admin);
      await pump(tester, const AdminDashboardScreen());
      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.byKey(const ValueKey('admin-tab-payments')), findsOneWidget);
      expect(find.textContaining('Bookings ('), findsNothing);
      expect(find.byKey(const ValueKey('admin-shops-tab')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('admin-shops-filter-suspended')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('admin-shop-shop_4')));
      expect(find.text('Suspended by admin'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('admin-shop-shop_6')));
      expect(find.byKey(const ValueKey('admin-shop-shop_1'), skipOffstage: false), findsNothing);

      await tester.drag(find.byKey(const ValueKey('admin-shops-tab')), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-shops-filter-all')));
      await tester.enterText(find.byKey(const ValueKey('admin-shops-search')), 'kolfe');
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('admin-shop-shop_4')));
      expect(find.byKey(const ValueKey('admin-shop-shop_1'), skipOffstage: false), findsNothing);
    });

    testWidgets('suspend dialog requires a reason, then suspends', (tester) async {
      repo.switchRole(UserRole.admin);
      await pump(tester, const AdminDashboardScreen());
      await scrollTo(tester, find.byKey(const ValueKey('admin-shop-suspend-shop_2')));
      await tester.tap(find.byKey(const ValueKey('admin-shop-suspend-shop_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-suspend-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a reason.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('admin-suspend-reason')), 'Health inspection pending');
      await tester.tap(find.byKey(const ValueKey('admin-suspend-confirm')));
      await tester.pumpAndSettle();
      expect(repo.getShopById('shop_2')!.adminSuspendedReason, 'Health inspection pending');
    });

    testWidgets('delete dialog is enabled only after typing the name', (tester) async {
      repo.switchRole(UserRole.admin);
      final name = repo.getShopById('shop_5')!.name;
      await pump(tester, const AdminDashboardScreen());
      await scrollTo(tester, find.byKey(const ValueKey('admin-shop-delete-shop_5')));
      await tester.tap(find.byKey(const ValueKey('admin-shop-delete-shop_5')));
      await tester.pumpAndSettle();
      ElevatedButton confirm() => tester.widget<ElevatedButton>(find.byKey(const ValueKey('admin-delete-confirm')));
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('admin-delete-name')), name);
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('admin-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repo.getShopById('shop_5'), isNull);
    });

    // --- shop deletion ---
    testWidgets('delete dialog lists what is removed and what is kept', (tester) async {
      repo.switchRole(UserRole.admin);
      await pump(tester, const AdminDashboardScreen());
      await scrollTo(tester, find.byKey(const ValueKey('admin-shop-delete-shop_1')));
      await tester.tap(find.byKey(const ValueKey('admin-shop-delete-shop_1')));
      await tester.pumpAndSettle();
      expect(find.text('What happens'), findsOneWidget);
      expect(find.textContaining('staff accounts (owner and barbers) become customer accounts'), findsOneWidget);
      expect(find.textContaining('upcoming bookings are cancelled and their customers notified'), findsOneWidget);
      expect(find.textContaining('Past bookings are kept for history'), findsOneWidget);
    });
    // --- end shop deletion ---

    testWidgets('edit screen shows the owner and the suspension, and saves', (tester) async {
      repo.switchRole(UserRole.admin);
      await pump(tester, const AdminShopEditScreen(shopId: 'shop_4'));
      expect(find.byKey(const ValueKey('admin-shop-suspended-since')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-shop-edit-reactivate')), findsOneWidget);
      expect(find.textContaining('Signed up'), findsOneWidget);

      // Opening hours are shown read-only (set by the owner), not edited.
      final before = repo.getShopById('shop_4')!;
      final hoursLine = find.byKey(const ValueKey('admin-shop-hours-readonly'));
      expect(hoursLine, findsOneWidget);
      expect(tester.widget<Text>(hoursLine).data, contains('set by the shop owner'));
      expect(tester.widget<Text>(hoursLine).data, startsWith('Opening hours: '));
      expect(find.byType(FilterChip), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('admin-shop-name')), 'Sarbet Studio');
      await tester.tap(find.byKey(const ValueKey('admin-shop-save')));
      await tester.pumpAndSettle();
      final saved = repo.getShopById('shop_4')!;
      expect(saved.name, 'Sarbet Studio');
      expect((saved.openingHour, saved.closingHour), (before.openingHour, before.closingHour));
      expect(saved.workingDays, before.workingDays);

      await tester.ensureVisible(find.byKey(const ValueKey('admin-shop-edit-reactivate')));
      await tester.tap(find.byKey(const ValueKey('admin-shop-edit-reactivate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-reactivate-confirm')));
      await tester.pumpAndSettle();
      expect(repo.getShopById('shop_4')!.adminSuspended, isFalse);
      // (The status card shrank, so the button may sit just above the viewport.)
      expect(find.byKey(const ValueKey('admin-shop-edit-suspend'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-shop-edit-reactivate'), skipOffstage: false), findsNothing);
    });

    testWidgets('register screen: no hour pickers, a note that the owner sets the hours', (tester) async {
      repo.switchRole(UserRole.admin);
      await pump(tester, const AdminRegisterShopScreen());
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('admin-register-hours-note')));
      expect(find.text('The shop owner sets the opening hours after signing in.'), findsOneWidget);

      await pump(tester, const AdminRegisterShopScreen(), locale: const Locale('am'));
      expect(find.text('የሥራ ሰዓቱን የፀጉር ቤቱ ባለቤት ከገባ በኋላ ያስቀምጣል።'), findsOneWidget);
    });

    testWidgets('owner customize screen still changes the opening days', (tester) async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final shop = repo.getShopById('shop_1')!;
      final toggled = shop.workingDays.contains(7) ? 6 : 7; // Sat or Sun
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => CustomizeShopScreen(shop: shop))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final day = find.text(toggled == 7 ? 'Sun' : 'Sat');
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      final publish = find.text('Publish Shop Customizations');
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.pumpAndSettle();
      final saved = repo.getShopById('shop_1')!;
      expect(saved.workingDays.contains(toggled), !shop.workingDays.contains(toggled));
      expect((saved.openingHour, saved.closingHour), (shop.openingHour, shop.closingHour));
    });

    testWidgets('edit screen in Amharic', (tester) async {
      repo.switchRole(UserRole.admin);
      await pump(tester, const AdminShopEditScreen(shopId: 'shop_4'), locale: const Locale('am'));
      expect(find.text('ፀጉር ቤቱን አስተካክል'), findsOneWidget);
      expect(find.text('በአስተዳዳሪ ታግዷል'), findsWidgets);
    });

    testWidgets('owner dashboard shows the red suspension banner with the reason', (tester) async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_4');
      await pump(tester, const OwnerDashboardScreen());
      expect(find.byKey(const ValueKey('admin-suspension-banner')), findsOneWidget);
      expect(find.textContaining('Business licence expired'), findsOneWidget);

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await pump(tester, const OwnerDashboardScreen());
      expect(find.byKey(const ValueKey('admin-suspension-banner')), findsNothing);
    });

    testWidgets('customer shop page: temporarily unavailable, no booking', (tester) async {
      repo.switchRole(UserRole.customer);
      await pump(tester, BarbershopDetailScreen(shop: repo.getShopById('shop_4')!));
      expect(find.byKey(const ValueKey('shop-unavailable-notice')), findsOneWidget);
      expect(find.text('Temporarily unavailable'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('shop-book-button'))).onPressed, isNull);

      await pump(tester, BarbershopDetailScreen(shop: repo.getShopById('shop_1')!));
      expect(find.byKey(const ValueKey('shop-unavailable-notice')), findsNothing);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('shop-book-button'))).onPressed, isNotNull);
    });

    test('error texts exist in both languages', () {
      for (final locale in const [Locale('en'), Locale('am')]) {
        final l = lookupAppLocalizations(locale);
        for (final e in AdminShopError.values) {
          expect(adminShopErrorText(l, AdminShopException(e)), isNotEmpty);
        }
      }
    });
  });
}
