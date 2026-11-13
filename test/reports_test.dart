import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/reports_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _booking(
  String id, {
  required BookingStatus status,
  required DateTime startAt,
  String customerId = 'c1',
  String customerName = 'Liya',
  String serviceId = 'srv1',
  String serviceName = 'Fade',
  String barberId = 'b1',
  String barberName = 'Yonas',
  double price = 350,
}) =>
    Booking(
      id: id,
      shopId: 's1',
      shopName: 'Shop',
      barberId: barberId,
      barberName: barberName,
      customerId: customerId,
      customerName: customerName,
      customerPhone: '+251911000301',
      serviceId: serviceId,
      serviceName: serviceName,
      price: price,
      date: startAt,
      timeSlot: '',
      status: status,
      createdAt: startAt,
      startAt: startAt,
      durationMinutes: 30,
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

  group('month keys', () {
    test('Addis month of a UTC instant', () {
      expect(addisMonthKey(DateTime.utc(2026, 10, 31, 21, 30)), '2026-11'); // 00:30 Nov 1 in Addis
      expect(addisMonthKey(DateTime.utc(2026, 10, 31, 20, 59)), '2026-10');
    });

    test('last 12 months, newest first, across a year boundary', () {
      final keys = recentMonthKeys(DateTime.utc(2026, 2, 10), 12);
      expect(keys.first, '2026-02');
      expect(keys[2], '2025-12');
      expect(keys.last, '2025-03');
      expect(keys, hasLength(12));
    });
  });

  group('local computation', () {
    test('totals, revenue, top services, barbers and clients', () {
      final bookings = [
        _booking('1', status: BookingStatus.completed, startAt: DateTime.utc(2026, 11, 3, 7)),
        _booking('2',
            status: BookingStatus.completed,
            startAt: DateTime.utc(2026, 11, 5, 7),
            serviceId: 'srv2',
            serviceName: 'Beard',
            price: 150,
            barberId: 'b2',
            barberName: 'Kaleab'),
        _booking('3',
            status: BookingStatus.completed,
            startAt: DateTime.utc(2026, 11, 6, 7),
            customerId: 'c2',
            customerName: 'Hanna'),
        _booking('4', status: BookingStatus.cancelled, startAt: DateTime.utc(2026, 11, 7, 7)),
        _booking('5',
            status: BookingStatus.noShow,
            startAt: DateTime.utc(2026, 11, 8, 7),
            customerId: 'c2',
            customerName: 'Hanna'),
        _booking('6', status: BookingStatus.confirmed, startAt: DateTime.utc(2026, 11, 25, 7)),
        _booking('7', status: BookingStatus.completed, startAt: DateTime.utc(2026, 9, 1, 7), price: 300),
        // Another shop: ignored.
        _booking('8', status: BookingStatus.completed, startAt: DateTime.utc(2026, 11, 3, 7)).copyWith(shopId: 's2'),
      ];
      final report = ReportsService.reportFromBookings('s1', bookings, now: _now);
      expect(report.months, hasLength(ReportsService.monthsShown));
      expect(report.months.first.month, '2026-11');

      final nov = report.month('2026-11');
      expect(nov.bookings, 6);
      expect(nov.completed, 3);
      expect(nov.cancelled, 1);
      expect(nov.noShows, 1);
      expect(nov.revenueEtb, 850);
      expect(nov.topServices.map((s) => (s.name, s.count, s.revenueEtb)), [('Fade', 2, 700.0), ('Beard', 1, 150.0)]);
      expect(nov.barberPerformance.map((b) => (b.name, b.completed)), [('Yonas', 2), ('Kaleab', 1)]);

      expect(report.month('2026-09').revenueEtb, 300);
      expect(report.month('2026-10').isEmpty, isTrue);
      final trend = report.trendEndingAt('2026-11', ReportsService.trendMonths);
      expect(trend.map((m) => m.month), ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11']);

      expect(report.clients.map((c) => c.customerId), ['c1', 'c2']);
      final c1 = report.clients.first;
      expect(c1.completedCount, 3);
      expect(c1.cancelledCount, 1);
      expect(c1.lastVisitAt, DateTime.utc(2026, 11, 5, 7));
      final c2 = report.clients.last;
      expect(c2.noShowCount, 1);
      expect(c2.name, 'Hanna');
    });

    test('system slot-conflict cancellations count for nothing (as in functions/insights)', () {
      final start = DateTime.utc(2026, 11, 7, 7);
      final report = ReportsService.reportFromBookings('s1', [
        _booking('1', status: BookingStatus.cancelled, startAt: start).copyWith(cancelReason: 'slot_conflict'),
        _booking('2', status: BookingStatus.cancelled, startAt: start),
      ], now: _now);
      expect(report.month('2026-11').bookings, 1);
      expect(report.month('2026-11').cancelled, 1);
      expect(report.clients.single.cancelledCount, 1);
    });

    test('demo repository report matches its own bookings', () {
      loadTestSeed(now: _now);
      final repo = AppRepository.instance;
      final report = ReportsService(repository: repo).computeLocalReport('shop_1', now: _now);
      final inNovember = repo.getShopBookings('shop_1').where((b) => addisMonthKey(b.startAt) == '2026-11');
      expect(report.month('2026-11').bookings, inNovember.length);
      expect(
        report.month('2026-11').revenueEtb,
        inNovember.where((b) => b.status == BookingStatus.completed).fold<double>(0, (s, b) => s + b.price),
      );
    });
  });

  group('Firestore', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      db = FakeFirebaseFirestore();
      final shop = db.collection('barbershops').doc('s1');
      await shop.collection('stats').doc('2026-11').set({
        'month': '2026-11',
        'bookings': 7,
        'completed': 4,
        'cancelled': 2,
        'noShows': 1,
        'revenueEtb': 1250.5,
        'byService': {
          'srv1': {'name': 'Fade', 'count': 3, 'revenueEtb': 1050.5},
          'srv2': {'name': 'Beard', 'count': 1, 'revenueEtb': 200},
        },
        'byBarber': {
          'b1': {'name': 'Yonas', 'completed': 4, 'revenueEtb': 1250.5},
        },
        'updatedAt': '2026-11-20T06:00:00.000Z',
      });
      await shop
          .collection('stats')
          .doc('2026-10')
          .set({'month': '2026-10', 'bookings': 2, 'completed': 2, 'revenueEtb': 600});
      await shop.collection('clients').doc('c1').set({
        'customerId': 'c1',
        'name': 'Liya Getachew',
        'phone': '+251911000301',
        'completedCount': 5,
        'noShowCount': 0,
        'cancelledCount': 1,
        'lastVisitAt': '2026-11-18T07:30:00.000Z',
      });
      await shop.collection('clients').doc('c2').set({
        'customerId': 'c2',
        'name': 'Dawit Bekele',
        'phone': '+251911000302',
        'completedCount': 1,
        'noShowCount': 2,
        'cancelledCount': 0,
        'lastVisitAt': null,
      });
    });

    test('reads stats and clients docs', () async {
      final report = await ReportsService.loadFromFirestore(db, 's1', now: _now);
      expect(report.months, hasLength(12));
      final nov = report.month('2026-11');
      expect(nov.bookings, 7);
      expect(nov.revenueEtb, 1250.5);
      expect(nov.topServices.first.name, 'Fade');
      expect(nov.updatedAt, DateTime.utc(2026, 11, 20, 6));
      expect(report.month('2026-10').revenueEtb, 600);
      expect(report.month('2026-08').isEmpty, isTrue);
      expect(report.clients.map((c) => c.name), ['Liya Getachew', 'Dawit Bekele']);
      expect(report.clients.last.lastVisitAt, isNull);
    });

    testWidgets('screen shows totals, trend and the no-show badge (English)', (tester) async {
      final service = ReportsService(firestore: db);
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(OwnerReportsScreen(shopId: 's1', service: service, now: _now)));
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('reports-total-bookings')), matching: find.text('7')),
          findsOneWidget);
      expect(
          find.descendant(of: find.byKey(const ValueKey('reports-total-revenue')), matching: find.text('ETB 1,250.50')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('reports-revenue-trend')), findsOneWidget);
      expect(find.text('Fade'), findsOneWidget);
      expect(find.text('Yonas'), findsOneWidget);

      // Pick October.
      await tester.tap(find.byKey(const ValueKey('reports-month-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('October 2026').last);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('reports-total-revenue')), matching: find.text('ETB 600')),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reports-tab-clients')));
      await tester.pumpAndSettle();
      expect(find.text('Liya Getachew'), findsOneWidget);
      expect(find.byKey(const ValueKey('reports-noshow-badge-c2')), findsOneWidget);
      expect(find.text('2 no-shows'), findsOneWidget);
      expect(find.byKey(const ValueKey('reports-noshow-badge-c1')), findsNothing);
    });

    testWidgets('screen in Amharic uses Birr', (tester) async {
      final service = ReportsService(firestore: db);
      await tester
          .pumpWidget(_app(OwnerReportsScreen(shopId: 's1', service: service, now: _now), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('ሪፖርቶች'), findsOneWidget);
      expect(
          find.descendant(of: find.byKey(const ValueKey('reports-total-revenue')), matching: find.text('1,250.50 ብር')),
          findsOneWidget);
    });
  });

  group('demo mode screen', () {
    setUp(() => loadTestSeed(now: _now));

    testWidgets('owner opens reports from the dashboard', (tester) async {
      final repo = AppRepository.instance;
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const OwnerDashboardScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('open-reports')));
      await tester.tap(find.byKey(const ValueKey('open-reports')));
      await tester.pumpAndSettle();
      expect(find.byType(OwnerReportsScreen), findsOneWidget);

      final expected = ReportsService(repository: repo).computeLocalReport('shop_1');
      final current = expected.months.first;
      expect(
        find.descendant(
            of: find.byKey(const ValueKey('reports-total-bookings')), matching: find.text('${current.bookings}')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('reports-tab-clients')));
      await tester.pumpAndSettle();
      expect(expected.clients, isNotEmpty);
      expect(find.byKey(ValueKey('reports-client-${expected.clients.first.customerId}')), findsOneWidget);
    });
  });
}
