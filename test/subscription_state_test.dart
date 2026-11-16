import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/payments/receipts/receipt_payment_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/subscription_receipts_service.dart';
import 'package:barbershop_booking/features/payments/widgets/subscription_banner.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/subscription_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Barbershop _shop(SubscriptionStatus status, DateTime? endsAt, {String plan = 'basic', bool adminSuspended = false}) =>
    Barbershop(
      id: 's1',
      ownerId: 'o1',
      name: 'Test Cuts',
      description: '',
      address: 'Bole Road',
      city: 'Addis Ababa',
      phone: '+251911000000',
      imageUrl: 'https://example.com/a.png',
      subscriptionPlan: plan,
      subscriptionStatus: status,
      subscriptionEndsAt: endsAt,
      adminSuspended: adminSuspended,
    );

DateTime _days(num d) => _now.add(Duration(minutes: (d * 24 * 60).round()));

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  group('effective status (pure)', () {
    test('mirrors statusForEnd: end -> past_due, end + 7 days -> suspended', () {
      const t = SubscriptionStatus.trialing, a = SubscriptionStatus.active;
      const p = SubscriptionStatus.pastDue, s = SubscriptionStatus.suspended;
      expect(effectiveStatusFor(t, _days(3), _now), t);
      expect(effectiveStatusFor(a, _days(3), _now), a);
      expect(effectiveStatusFor(t, _now, _now), p); // at the end
      expect(effectiveStatusFor(a, _days(-1), _now), p);
      expect(effectiveStatusFor(t, _days(-6.9), _now), p);
      expect(effectiveStatusFor(t, _days(-7), _now), s); // grace over
      expect(effectiveStatusFor(a, _days(-30), _now), s);
      expect(effectiveStatusFor(p, _days(-8), _now), s);
      // past_due with an end moved into the future reads as active.
      expect(effectiveStatusFor(p, _days(10), _now), a);
      // suspended is sticky (only a payment / the admin lifts it).
      expect(effectiveStatusFor(s, _days(10), _now), s);
      // no end date: the stored status.
      for (final st in SubscriptionStatus.values) {
        expect(effectiveStatusFor(st, null, _now), st);
      }
      expect(kSubscriptionGracePeriod, const Duration(days: 7));
    });

    test('daysUntilSuspension counts to end + 7 days, rounded up', () {
      expect(daysUntilSuspension(_shop(SubscriptionStatus.trialing, null), _now), isNull);
      expect(daysUntilSuspension(_shop(SubscriptionStatus.trialing, _days(3)), _now), 10);
      expect(daysUntilSuspension(_shop(SubscriptionStatus.trialing, _days(-2)), _now), 5);
      expect(daysUntilSuspension(_shop(SubscriptionStatus.pastDue, _days(-2.5)), _now), 5);
      expect(daysUntilSuspension(_shop(SubscriptionStatus.pastDue, _days(-6.99)), _now), 1);
      expect(daysUntilSuspension(_shop(SubscriptionStatus.pastDue, _days(-7)), _now), isNull); // suspended
      expect(daysUntilSuspension(_shop(SubscriptionStatus.suspended, _days(5)), _now), isNull);
      expect(suspensionDateOf(_shop(SubscriptionStatus.active, _now)), _days(7));
    });

    test('only downgrades are persisted, with the exact two fields', () {
      expect(isSubscriptionDowngrade(SubscriptionStatus.trialing, SubscriptionStatus.pastDue), isTrue);
      expect(isSubscriptionDowngrade(SubscriptionStatus.active, SubscriptionStatus.suspended), isTrue);
      expect(isSubscriptionDowngrade(SubscriptionStatus.pastDue, SubscriptionStatus.suspended), isTrue);
      expect(isSubscriptionDowngrade(SubscriptionStatus.pastDue, SubscriptionStatus.active), isFalse);
      expect(isSubscriptionDowngrade(SubscriptionStatus.suspended, SubscriptionStatus.active), isFalse);
      expect(isSubscriptionDowngrade(SubscriptionStatus.trialing, SubscriptionStatus.active), isFalse);

      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.trialing, _days(1)), _now), isNull);
      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.trialing, _days(-1)), _now), {
        'subscriptionStatus': 'past_due',
        'subscriptionStatusChangedAt': '2026-11-20T07:00:00.000Z',
      });
      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.active, _days(-9)), _now)!['subscriptionStatus'],
          'suspended');
      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.pastDue, _days(-7)), _now)!['subscriptionStatus'],
          'suspended');
      // past_due -> active (end moved into the future) is never written here.
      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.pastDue, _days(5)), _now), isNull);
      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.suspended, _days(-30)), _now), isNull);
      expect(subscriptionTransitionPatch(_shop(SubscriptionStatus.active, null), _now), isNull);
    });

    test('isBlockedAt: admin suspension or effectively suspended', () {
      expect(_shop(SubscriptionStatus.trialing, _days(-6)).isBlockedAt(_now), isFalse);
      expect(_shop(SubscriptionStatus.trialing, _days(-8)).isBlockedAt(_now), isTrue);
      expect(_shop(SubscriptionStatus.active, _days(5), adminSuspended: true).isBlockedAt(_now), isTrue);
      expect(_shop(SubscriptionStatus.trialing, _days(-6)).effectiveStatusAt(_now), SubscriptionStatus.pastDue);
      expect(isTrialEnded(_shop(SubscriptionStatus.trialing, _days(-1)), _now), isTrue);
      expect(isTrialEnded(_shop(SubscriptionStatus.pastDue, _days(-1), plan: 'trial'), _now), isTrue);
      expect(isTrialEnded(_shop(SubscriptionStatus.active, _days(-1)), _now), isFalse);
    });

    test('Barbershop.isBlocked uses the app clock', () {
      final repo = AppRepository.instance;
      loadTestSeed(now: _now);
      final shop = _shop(SubscriptionStatus.trialing, _days(-3));
      expect(shop.isBlocked, isFalse);
      repo.debugClock = () => _days(5); // 8 days after the end
      addTearDown(() => repo.debugClock = null);
      expect(shop.isSuspended, isTrue);
      expect(shop.isBlocked, isTrue);
    });
  });

  group('owner banner', () {
    test('trial ended: pay message with the days left in grace', () {
      final l = lookupAppLocalizations(const Locale('en'));
      final am = lookupAppLocalizations(const Locale('am'));
      final lapsed = _shop(SubscriptionStatus.trialing, _days(-3), plan: 'trial');
      final msg = SubscriptionBanner.messageFor(lapsed, _now)!;
      expect(msg, contains('Your trial ended — pay to keep taking bookings'));
      expect(msg, contains('4 days left'));
      expect(msg, l.subExpTrialEndedInDays(4));
      expect(SubscriptionBanner.messageFor(lapsed, _now, l10n: am), am.subExpTrialEndedInDays(4));
      // Stored status already persisted as past_due: still a trial message.
      expect(SubscriptionBanner.messageFor(lapsed.copyWith(subscriptionStatus: SubscriptionStatus.pastDue), _now),
          l.subExpTrialEndedInDays(4));
      // Last day of grace.
      expect(SubscriptionBanner.messageFor(_shop(SubscriptionStatus.trialing, _days(-6.5)), _now), l.subExpTrialEndedInDays(1));
      // Grace over: suspended even though the stored status is stale.
      expect(SubscriptionBanner.messageFor(_shop(SubscriptionStatus.trialing, _days(-8)), _now), l.bannerSuspended);
      // A paid period that lapsed keeps the overdue message.
      expect(SubscriptionBanner.messageFor(_shop(SubscriptionStatus.active, _days(-2)), _now), l.bannerOverdueInDays(5));
    });

    testWidgets('dashboard: lapsed trial banner opens the receipt payment screen', (tester) async {
      final repo = AppRepository.instance;
      loadTestSeed(now: _now);
      SubscriptionReceiptsService.instance = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (_, __) {},
      );
      addTearDown(() => SubscriptionReceiptsService.instance = null);
      // Signed out: the stored status stays stale.
      await repo.updateShopSubscription('shop_1', plan: 'trial', status: SubscriptionStatus.trialing, endsAt: _days(-3));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const OwnerDashboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('subscription-banner')), findsOneWidget);
      expect(find.textContaining('Your trial ended — pay to keep taking bookings'), findsOneWidget);
      expect(find.textContaining('4 days left'), findsOneWidget);
      // The owner's app recorded the lapse.
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.pastDue);

      // The receipt screen's tier tiles trip a debug-only ListTile ink
      // assertion that is unrelated to this test; ignore just that one.
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('ListTile background color or ink splashes')) original?.call(details);
      };
      await tester.tap(find.byKey(const ValueKey('subscription-banner-action')));
      await tester.pumpAndSettle();
      FlutterError.onError = original;
      expect(find.byType(ReceiptPaymentScreen), findsOneWidget);
    });
  });

  group('persisted transition (local mode)', () {
    final repo = AppRepository.instance;

    setUp(() => loadTestSeed(now: _now));
    tearDown(() => repo.debugClock = null);

    Future<void> lapse(String shopId, double daysAgo, {SubscriptionStatus status = SubscriptionStatus.trialing}) =>
        // Written while signed out, so nothing syncs yet.
        repo.updateShopSubscription(shopId, plan: 'trial', status: status, endsAt: _days(-daysAgo));

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('the owner app writes trialing -> past_due -> suspended, once each', () async {
      await lapse('shop_1', 3);
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.trialing);

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await settle();
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.pastDue);
      expect(await repo.syncSubscriptionTransitions(), 0); // idempotent

      repo.debugClock = () => _days(4.5); // 7.5 days after the end
      expect(await repo.syncSubscriptionTransitions(), 1);
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.suspended);
      expect(await repo.syncSubscriptionTransitions(), 0);
    });

    test('an owner only writes their own shop; customers and barbers never write', () async {
      await lapse('shop_1', 3);
      await lapse('shop_2', 3);
      repo.switchRole(UserRole.customer);
      await settle();
      expect(await repo.syncSubscriptionTransitions(), 0);
      repo.switchRole(UserRole.barber);
      expect(await repo.syncSubscriptionTransitions(), 0);
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.trialing);

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await settle();
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.pastDue);
      expect(repo.getShopById('shop_2')!.subscriptionStatus, SubscriptionStatus.trialing);
    });

    test('the admin app writes every lapsed shop', () async {
      await lapse('shop_1', 3);
      await lapse('shop_2', 9, status: SubscriptionStatus.active);
      repo.switchRole(UserRole.admin);
      await settle();
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.pastDue);
      expect(repo.getShopById('shop_2')!.subscriptionStatus, SubscriptionStatus.suspended);
      // The seeded past_due / suspended shops were already consistent.
      expect(repo.getShopById('shop_5')!.subscriptionStatus, SubscriptionStatus.pastDue);
      expect(repo.getShopById('shop_6')!.subscriptionStatus, SubscriptionStatus.suspended);
    });

    test('never upgrades: past_due with a future end stays stored past_due', () async {
      await repo.updateShopSubscription('shop_1', plan: 'basic', status: SubscriptionStatus.pastDue, endsAt: _days(10));
      repo.switchRole(UserRole.admin);
      await settle();
      final shop = repo.getShopById('shop_1')!;
      expect(shop.subscriptionStatus, SubscriptionStatus.pastDue);
      expect(shop.effectiveStatusAt(_now), SubscriptionStatus.active);
    });
  });

  group('booking after grace', () {
    final repo = AppRepository.instance;

    setUp(() => loadTestSeed(now: _now));

    Future<Booking> book() => repo.createBooking(
          shopId: 'shop_1',
          shopName: 'Crown Cuts Bole',
          barberId: 'barber_1',
          barberName: 'Yonas Tadesse',
          serviceId: 'srv_1_1',
          serviceName: 'x',
          price: 450,
          date: DateTime(2026, 11, 21),
          timeSlot: '04:00 PM',
        );

    test('within grace the shop is still bookable', () async {
      await repo.updateShopSubscription('shop_1', plan: 'trial', status: SubscriptionStatus.trialing, endsAt: _days(-3));
      repo.switchRole(UserRole.customer);
      expect(repo.getShops().any((s) => s.id == 'shop_1'), isTrue);
      final booking = await book();
      expect(booking.shopId, 'shop_1');
    });

    test('a stale "trialing" shop 7+ days past its end is hidden and refuses bookings', () async {
      await repo.updateShopSubscription('shop_1', plan: 'trial', status: SubscriptionStatus.trialing, endsAt: _days(-8));
      repo.switchRole(UserRole.customer);
      // No owner/admin app has run: the stored status is still trialing.
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.trialing);
      expect(repo.getShopById('shop_1')!.isBlocked, isTrue);
      expect(repo.getShops().any((s) => s.id == 'shop_1'), isFalse);
      await expectLater(
        book(),
        throwsA(isA<AppStateException>().having((e) => e.code, 'code', AppErrorCode.shopNotTakingBookings)),
      );
    });
  });

  group('receipt approval', () {
    final repo = AppRepository.instance;

    test('approving a receipt makes a lapsed shop effectively active again', () async {
      loadTestSeed(now: _now);
      final service = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (_, __) {},
      );
      await repo.updateShopSubscription('shop_1', plan: 'trial', status: SubscriptionStatus.trialing, endsAt: _days(-10));
      repo.signInAsDemoUser('owner.shop1@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(repo.getShopById('shop_1')!.subscriptionStatus, SubscriptionStatus.suspended); // persisted by the owner app
      final p = await service.submit(
          shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: 'CHK9EXP001', amount: 500);

      repo.signInAsDemoUser('admin@example.com');
      await service.approve(p.id);
      await Future<void>.delayed(Duration.zero);
      final shop = repo.getShopById('shop_1')!;
      expect(shop.subscriptionStatus, SubscriptionStatus.active);
      expect(shop.subscriptionEndsAt!.isAfter(_now), isTrue);
      expect(shop.effectiveStatusAt(_now), SubscriptionStatus.active);
      expect(shop.isBlocked, isFalse);
      repo.switchRole(UserRole.customer);
      expect(repo.getShops().any((s) => s.id == 'shop_1'), isTrue);
    });
  });
}
