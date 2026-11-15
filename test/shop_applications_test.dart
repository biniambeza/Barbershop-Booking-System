import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/applications/applications_l10n.dart';
import 'package:barbershop_booking/features/applications/screens/admin_shop_applications_screen.dart';
import 'package:barbershop_booking/features/applications/screens/shop_application_screen.dart';
import 'package:barbershop_booking/features/applications/shop_applications_service.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 20, 7);

Matcher _appError(ShopApplicationErrorCode code) =>
    isA<ShopApplicationException>().having((e) => e.code, 'code', code);

/// Fresh repository (demo seed, signed out) and a service with an in-memory
/// store holding the seeded applications.
ShopApplicationsService _setUp() {
  loadTestSeed(now: _now);
  final local = LocalShopApplicationStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now);
  final service = ShopApplicationsService(repository: AppRepository.instance, local: local);
  ShopApplicationsService.instance = service;
  return service;
}

Future<ShopApplication> _submitValid(ShopApplicationsService s, {String shopName = 'Gerji Sharp Cuts'}) => s.submit(
      ownerName: '  Rahel Desta ',
      shopName: shopName,
      address: 'Gerji, behind Unity University',
      subCity: 'Yeka',
      phone: '0911 22 33 44',
      description: '  ',
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => ShopApplicationsService.instance = null);

  group('pure validation', () {
    test('input is trimmed and normalized', () {
      final input = ShopApplicationInput.validate(
        ownerName: ' Abebe ',
        shopName: ' Bole Fade ',
        address: ' Bole Road ',
        subCity: 'Bole',
        phone: '011 551 2345',
        description: ' ',
      );
      expect(input.ownerName, 'Abebe');
      expect(input.shopName, 'Bole Fade');
      expect(input.phone, startsWith('+251'));
      expect(input.description, isNull);
    });

    test('each field is checked', () {
      ShopApplicationInput call({
        String owner = 'A',
        String shop = 'Shop',
        String address = 'Here',
        String sub = 'Bole',
        String phone = '0911223344',
        String? desc,
      }) =>
          ShopApplicationInput.validate(
              ownerName: owner, shopName: shop, address: address, subCity: sub, phone: phone, description: desc);
      expect(() => call(owner: ' '), throwsA(_appError(ShopApplicationErrorCode.ownerNameInvalid)));
      expect(() => call(shop: 'X'), throwsA(_appError(ShopApplicationErrorCode.shopNameInvalid)));
      expect(() => call(shop: 'x' * 81), throwsA(_appError(ShopApplicationErrorCode.shopNameInvalid)));
      expect(() => call(address: 'x' * 161), throwsA(_appError(ShopApplicationErrorCode.addressInvalid)));
      expect(() => call(sub: 'Mars'), throwsA(_appError(ShopApplicationErrorCode.subCityInvalid)));
      expect(() => call(phone: '12345'), throwsA(_appError(ShopApplicationErrorCode.phoneInvalid)));
      expect(() => call(desc: 'x' * 501), throwsA(_appError(ShopApplicationErrorCode.descriptionTooLong)));
      expect(call(desc: 'x' * 500).description, hasLength(500));
    });

    test('reject reason is 1..300 characters', () {
      expect(validateRejectReason('  Missing address '), 'Missing address');
      expect(() => validateRejectReason('  '), throwsA(_appError(ShopApplicationErrorCode.rejectReasonInvalid)));
      expect(() => validateRejectReason('x' * 301), throwsA(_appError(ShopApplicationErrorCode.rejectReasonInvalid)));
    });

    test('submit blocker: none or rejected may submit', () {
      final base = ShopApplication(
        uid: 'u',
        email: 'u@example.com',
        ownerName: 'U',
        shopName: 'Shop',
        address: 'Here',
        subCity: 'Bole',
        phone: '+251911223344',
        createdAt: _now,
      );
      expect(submitBlocker(null), isNull);
      expect(submitBlocker(base.copyWith(status: ShopApplicationStatus.rejected)), isNull);
      expect(submitBlocker(base), ShopApplicationErrorCode.alreadyPending);
      expect(submitBlocker(base.copyWith(status: ShopApplicationStatus.approved)), ShopApplicationErrorCode.alreadyApproved);
    });

    test('map round trip and admin order', () {
      final a = ShopApplication(
        uid: 'u1',
        email: 'a@example.com',
        ownerName: 'A',
        shopName: 'Shop A',
        address: 'Here',
        subCity: 'Bole',
        phone: '+251911223344',
        description: 'Nice',
        createdAt: _now,
      );
      final map = a.toMap();
      expect(map['status'], 'pending');
      expect(map['createdAt'], '2026-11-20T07:00:00.000Z');
      expect(map.containsKey('reviewedBy'), isFalse);
      final back = ShopApplication.fromMap(map, 'u1');
      expect(back.shopName, 'Shop A');
      expect(back.description, 'Nice');
      final older = a.copyWith(createdAt: _now.subtract(const Duration(days: 1)));
      final decided = a.copyWith(status: ShopApplicationStatus.approved, reviewedAt: _now);
      final list = [decided, a, older]..sort(ShopApplication.adminOrder);
      expect(list, [older, a, decided]);
    });

    test('approval writes exactly the four review fields', () {
      final approval = ShopApplicationApproval(applicantUid: 'u1', reviewedBy: 'admin', reviewedAt: _now);
      expect(approval.path, 'shopApplications/u1');
      expect(approval.fieldsFor('shop9'), {
        'status': 'approved',
        'reviewedBy': 'admin',
        'reviewedAt': '2026-11-20T07:00:00.000Z',
        'shopId': 'shop9',
      });
    });
  });

  group('seed', () {
    test('the demo dataset has a pending application for a seeded customer', () {
      final apps = shopApplicationsFromSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now);
      expect(apps, hasLength(1));
      final app = apps.single;
      expect(app.uid, 'user_cust_2');
      expect(app.email, 'customer2@example.com');
      expect(app.isPending, isTrue);
      expect(app.createdAt, _now.subtract(const Duration(hours: 20)));
    });
  });

  group('repository flow (local mode)', () {
    test('customer applies, edits, withdraws and applies again', () async {
      final s = _setUp();
      await signInWithGoogleAs('customer3@example.com');
      expect(s.canApply, isTrue);
      expect(await s.loadMine(), isNull);

      final app = await _submitValid(s);
      expect(app.uid, AppRepository.instance.currentUser!.uid);
      expect(app.email, 'customer3@example.com');
      expect(app.ownerName, 'Rahel Desta');
      expect(app.phone, '+251911223344');
      expect(app.description, isNull);
      expect(app.createdAt, _now);
      expect((await s.loadMine())!.isPending, isTrue);

      await expectLater(_submitValid(s), throwsA(_appError(ShopApplicationErrorCode.alreadyPending)));

      final edited = await s.update(
        ownerName: 'Rahel Desta',
        shopName: 'Gerji Sharp',
        address: 'Gerji',
        subCity: 'Bole',
        phone: '0722 33 44 55',
        description: 'Kids cuts too',
      );
      expect(edited.shopName, 'Gerji Sharp');
      expect((await s.loadMine())!.description, 'Kids cuts too');

      await s.withdraw();
      expect(await s.loadMine(), isNull);
      await expectLater(s.withdraw(), throwsA(_appError(ShopApplicationErrorCode.notFound)));
      await _submitValid(s);
      expect((await s.loadMine())!.isPending, isTrue);
    });

    test('only customers apply; only the admin reviews', () async {
      final s = _setUp();
      await signInWithGoogleAs('admin@example.com');
      expect(s.canApply, isFalse);
      await expectLater(_submitValid(s), throwsA(_appError(ShopApplicationErrorCode.customersOnly)));

      await signInWithGoogleAs('customer3@example.com');
      await expectLater(s.approve('user_cust_2'), throwsA(_appError(ShopApplicationErrorCode.adminOnly)));
      await expectLater(s.reject('user_cust_2', 'No'), throwsA(_appError(ShopApplicationErrorCode.adminOnly)));
      expect(await s.watchForAdmin().first, isEmpty);

      await AppRepository.instance.signOut();
      await expectLater(_submitValid(s), throwsA(isA<AppStateException>()));
    });

    test('admin rejects; the customer sees the reason and resubmits', () async {
      final s = _setUp();
      await signInWithGoogleAs('admin@example.com');
      final adminUid = AppRepository.instance.currentUser!.uid;
      final list = await s.watchForAdmin().first;
      expect(list.map((a) => a.uid), ['user_cust_2']);

      await expectLater(s.reject('user_cust_2', ' '), throwsA(_appError(ShopApplicationErrorCode.rejectReasonInvalid)));
      await s.reject('user_cust_2', ' Please add a street address. ');
      await expectLater(s.reject('user_cust_2', 'again'), throwsA(_appError(ShopApplicationErrorCode.notPending)));
      await expectLater(s.approve('user_cust_2'), throwsA(_appError(ShopApplicationErrorCode.notPending)));
      final decided = (await s.watchForAdmin().first).single;
      expect(decided.isRejected, isTrue);
      expect(decided.reviewedBy, adminUid);
      expect(decided.reviewedAt, _now);
      expect(decided.rejectReason, 'Please add a street address.');

      await signInWithGoogleAs('customer2@example.com');
      final mine = await s.loadMine();
      expect(mine!.rejectReason, 'Please add a street address.');
      await expectLater(
        s.update(ownerName: 'N', shopName: 'Shop', address: 'Here', subCity: 'Bole', phone: '0911223344'),
        throwsA(_appError(ShopApplicationErrorCode.notPending)),
      );
      final again = await _submitValid(s, shopName: "Natty's Fade Studio");
      expect(again.isPending, isTrue);
      expect(again.reviewedBy, isNull);
      expect(again.rejectReason, isNull);
    });

    test('admin approves: shop + services + owner invite, applicant upgraded without signing out', () async {
      final s = _setUp();
      final repo = AppRepository.instance;
      await signInWithGoogleAs('admin@example.com');
      final shopsBefore = repo.getShops().length;
      final adminUid = repo.currentUser!.uid;
      final shopId = await s.approve('user_cust_2');

      final shop = repo.getShopById(shopId)!;
      expect(repo.getShops().length, shopsBefore + 1);
      expect(shop.name, "Natty's Fade Studio");
      expect(shop.subCity, 'Bole');
      expect(shop.phone, '+251911223344');
      expect(shop.ownerId, isEmpty);
      expect(repo.getServicesForShop(shopId), hasLength(2));
      final invite = repo.getPendingOwnerInvite(shopId)!;
      expect(invite.email, 'customer2@example.com');
      expect(invite.role, UserRole.barbershopOwner);

      final app = (await s.watchForAdmin().first).single;
      expect(app.isApproved, isTrue);
      expect(app.shopId, shopId);
      expect(app.reviewedBy, adminUid);
      expect(app.reviewedAt, _now);
      await expectLater(s.approve('user_cust_2'), throwsA(_appError(ShopApplicationErrorCode.notPending)));

      // The applicant is still signed in as a customer (another device): the
      // approval is seen live and the invite applied without signing out.
      await signInWithGoogleAs('customer2@example.com');
      // Signing in again already consumes the invite (app start path).
      expect(repo.currentUser!.role, UserRole.barbershopOwner);
      expect(repo.currentUser!.shopId, shopId);
      expect(repo.getShopById(shopId)!.ownerId, repo.currentUser!.uid);
    });

    test('a signed-in customer is upgraded live when the approval arrives', () async {
      final s = _setUp();
      final repo = AppRepository.instance;
      await signInWithGoogleAs('customer2@example.com');
      final uid = repo.currentUser!.uid;
      final seen = <ShopApplicationStatus>[];
      final sub = s.watchMine().listen((a) => seen.add(a!.status));
      await pumpEventQueue();
      expect(seen, [ShopApplicationStatus.pending]);

      // Approve "behind the scenes" (as the admin would, from another device).
      final shopId = await repo.registerBarbershopByAdmin(
        shopName: "Natty's Fade Studio",
        ownerName: 'Natnael Assefa',
        ownerEmail: 'customer2@example.com',
        address: 'Africa Avenue',
        city: 'Addis Ababa',
        description: '',
        imageUrl: '',
        openingHour: 9,
        closingHour: 20,
        workingDays: const [1, 2, 3, 4, 5, 6, 7],
        isVerified: true,
        fromApplication: ShopApplicationApproval(
          applicantUid: uid,
          reviewedBy: 'user_admin_1',
          reviewedAt: _now,
          applyLocally: (id) => s.local.markApproved(uid, {
            'reviewedBy': 'user_admin_1',
            'reviewedAt': _now.toIso8601String(),
            'shopId': id,
          }),
        ),
      );
      await pumpEventQueue();
      expect(seen.last, ShopApplicationStatus.approved);
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser!.uid, uid);
      expect(repo.currentUser!.role, UserRole.barbershopOwner);
      expect(repo.currentUser!.shopId, shopId);
      expect(repo.getShopById(shopId)!.ownerId, uid);
      expect(repo.getPendingOwnerInvite(shopId), isNull);
      // Nothing more to apply.
      expect(await s.syncApprovedInvite(await s.loadMine()), isFalse);
      await sub.cancel();
    });
  });

  group('l10n', () {
    test('every error code has English and Amharic text', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final am = lookupAppLocalizations(const Locale('am'));
      for (final code in ShopApplicationErrorCode.values) {
        final e = ShopApplicationException(code);
        expect(en.applicationsErrorText(e), isNotEmpty);
        expect(am.applicationsErrorText(e), isNot(en.applicationsErrorText(e)));
      }
    });
  });

  group('screens', () {
    Widget host(Widget child) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        );

    testWidgets('customer submits the form and sees the pending status', (tester) async {
      final s = _setUp();
      await tester.runAsync(() => signInWithGoogleAs('customer3@example.com'));
      await tester.pumpWidget(host(ShopApplicationScreen(service: s)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('appl-save')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('appl-shop')), 'Gerji Sharp Cuts');
      await tester.enterText(find.byKey(const ValueKey('appl-address')), 'Gerji');
      await tester.enterText(find.byKey(const ValueKey('appl-phone')), '0911223344');
      await tester.ensureVisible(find.byKey(const ValueKey('appl-save')));
      await tester.tap(find.byKey(const ValueKey('appl-save')));
      await tester.pumpAndSettle();
      // No sub-city yet.
      expect(find.text('Choose a sub-city.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('appl-subcity')));
      await tester.tap(find.byKey(const ValueKey('appl-subcity')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bole').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('appl-save')));
      await tester.tap(find.byKey(const ValueKey('appl-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('appl-status-pending')), findsOneWidget);
      expect(find.byKey(const ValueKey('appl-withdraw')), findsOneWidget);
    });

    testWidgets('admin rejects with a reason', (tester) async {
      final s = _setUp();
      await tester.runAsync(() => signInWithGoogleAs('admin@example.com'));
      await tester.pumpWidget(host(AdminShopApplicationsScreen(service: s)));
      await tester.pumpAndSettle();
      expect(find.text("Natty's Fade Studio"), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('appl-reject-user_cust_2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('appl-reject-reason')), 'Add photos');
      await tester.tap(find.byKey(const ValueKey('appl-reject-confirm')));
      await tester.pumpAndSettle();

      expect((await s.local.get('user_cust_2'))!.rejectReason, 'Add photos');
      expect(find.byKey(const ValueKey('appl-approve-user_cust_2')), findsNothing);
    });
  });
}
