import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/admin/screens/admin_payments_tab.dart';
import 'package:barbershop_booking/features/payments/receipts/admin_pricing_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/admin_receipts_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/subscription_receipts_service.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/services/admin_payments_summary.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// 2026-11-15 12:00 Addis.
final _now = DateTime.utc(2026, 11, 15, 9, 0);

SubscriptionPayment _pay(
  String id, {
  ReceiptStatus status = ReceiptStatus.verified,
  double amount = 500,
  double? verifiedAmount,
  DateTime? decidedAt,
}) =>
    SubscriptionPayment(
      id: id,
      shopId: 'shop_1',
      ownerId: 'owner_1',
      method: ReceiptMethod.telebirr,
      transactionId: id.toUpperCase(),
      amount: amount,
      status: status,
      durationDays: status == ReceiptStatus.verified ? 30 : 0,
      verifiedAmount: verifiedAmount,
      createdAt: _now.subtract(const Duration(days: 1)),
      decidedAt: decidedAt,
    );

Barbershop _shop(String id, SubscriptionStatus status, {DateTime? endsAt}) => Barbershop(
      id: id,
      ownerId: 'o_$id',
      name: 'Shop $id',
      description: 'd',
      address: 'Road 1',
      city: 'Addis Ababa',
      phone: '+251911223344',
      imageUrl: 'https://example.com/x.jpg',
      subscriptionStatus: status,
      subscriptionEndsAt: endsAt,
    );

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: home),
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  group('summarizeAdminPayments', () {
    test('counts open receipts and this Addis month\'s decisions only', () {
      final s = summarizeAdminPayments(
        payments: [
          _pay('a', status: ReceiptStatus.pending),
          _pay('b', status: ReceiptStatus.needsReview),
          _pay('c', amount: 1400, decidedAt: _now.subtract(const Duration(days: 2))),
          // Admin approved a different amount: that one counts.
          _pay('d', amount: 500, verifiedAmount: 450, decidedAt: _now.subtract(const Duration(hours: 1))),
          // Last month (Oct 31 23:00 Addis = Oct 31 20:00 UTC).
          _pay('e', amount: 5000, decidedAt: DateTime.utc(2026, 10, 31, 20)),
          _pay('f', status: ReceiptStatus.rejected, decidedAt: _now.subtract(const Duration(days: 3))),
          _pay('g', status: ReceiptStatus.rejected, decidedAt: DateTime.utc(2026, 10, 2)),
        ],
        shops: const [],
        nowUtc: _now,
      );
      expect(s.pendingCount, 2);
      expect(s.monthVerifiedCount, 2);
      expect(s.monthIncome, 1850);
      expect(s.monthRejectedCount, 1);
    });

    test('the month boundary is Addis time, not UTC', () {
      // Nov 1 00:30 Addis = Oct 31 21:30 UTC: belongs to November.
      expect(isInAddisMonth(DateTime.utc(2026, 10, 31, 21, 30), _now), isTrue);
      expect(isInAddisMonth(DateTime.utc(2026, 10, 31, 20, 59), _now), isFalse);
    });

    test('shop counts by subscription status and expiring-soon list', () {
      final s = summarizeAdminPayments(
        payments: const [],
        shops: [
          _shop('a', SubscriptionStatus.active, endsAt: _now.add(const Duration(days: 3))),
          _shop('b', SubscriptionStatus.active, endsAt: _now.add(const Duration(days: 30))),
          _shop('c', SubscriptionStatus.trialing, endsAt: _now.add(const Duration(days: 1))),
          _shop('d', SubscriptionStatus.pastDue, endsAt: _now.add(const Duration(days: 2))),
          _shop('e', SubscriptionStatus.suspended),
          _shop('f', SubscriptionStatus.active, endsAt: _now.subtract(const Duration(days: 1))),
        ],
        nowUtc: _now,
      );
      expect((s.activeShops, s.trialShops, s.pastDueShops, s.suspendedShops), (3, 1, 1, 1));
      // Past-due and already-ended shops are not "expiring"; soonest first.
      expect(s.expiringSoon.map((x) => x.id), ['c', 'a']);
    });
  });

  group('AdminPaymentsTab (local)', () {
    final repo = AppRepository.instance;
    late SubscriptionReceiptsService service;

    setUp(() {
      loadTestSeed(now: _now);
      repo.signInAsDemoUser('admin@example.com');
      service = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
      );
      SubscriptionReceiptsService.instance = service;
    });

    tearDown(() => SubscriptionReceiptsService.instance = null);

    Future<void> pumpTab(WidgetTester tester, {Locale locale = const Locale('en')}) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AdminPaymentsTab(service: service, clock: () => _now), locale: locale));
      await tester.pumpAndSettle();
    }

    testWidgets('shows income, pending receipts, subscription types and latest payments', (tester) async {
      await pumpTab(tester);
      // Seed: one verified 1400 ETB receipt this month, one pending.
      expect(find.byKey(const ValueKey('admin-payments-tab')), findsOneWidget);
      final income = tester.widget<Text>(find.byKey(const ValueKey('admin-pay-income'))).data!;
      expect(income, contains('1,400'));
      expect(find.text('1 waiting'), findsWidgets);
      expect(find.text('1 verified'), findsOneWidget);
      // Default tiers are listed.
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('365 days'), findsOneWidget);
      // Placeholder receivers: the admin is told to add them.
      expect(find.textContaining('telebirr number or CBE account'), findsOneWidget);
      expect(find.text('Latest payments'), findsOneWidget);
      expect(find.textContaining('FT26300ABC12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the receipts review and the subscription types editor', (tester) async {
      await pumpTab(tester);
      await tester.tap(find.byKey(const ValueKey('admin-pay-open-receipts')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminReceiptsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(AdminReceiptsScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('admin-pay-open-pricing')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPricingScreen), findsOneWidget);
    });

    testWidgets('renders in Amharic at phone width without overflow', (tester) async {
      await pumpTab(tester, locale: const Locale('am'));
      expect(find.text('የደንበኝነት ገቢ'), findsOneWidget);
      expect(find.text('የደንበኝነት ዓይነቶች እና ዋጋዎች'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
