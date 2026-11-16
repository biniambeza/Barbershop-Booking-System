import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/data/addis_time.dart';
import 'package:barbershop_booking/features/reports/widgets/busy_hours_tab.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/owner_insights_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _b(
  String id,
  DateTime startUtc, {
  BookingStatus status = BookingStatus.completed,
  String shopId = 's1',
}) =>
    Booking(
      id: id,
      shopId: shopId,
      shopName: 'Shop',
      barberId: 'b1',
      barberName: 'Yonas',
      customerId: 'c1',
      customerName: 'Liya',
      customerPhone: '+251911000301',
      serviceId: 'srv1',
      serviceName: 'Fade',
      price: 300,
      date: startUtc,
      timeSlot: '',
      status: status,
      createdAt: startUtc,
      startAt: startUtc,
      durationMinutes: 30,
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

  group('periods', () {
    test('last 30 / 90 days end now', () {
      final p30 = BusyHoursPeriod.of(BusyHoursRange.last30Days, _now);
      expect(p30.endUtc, _now);
      expect(p30.startUtc, _now.subtract(const Duration(days: 30)));
      final p90 = BusyHoursPeriod.of(BusyHoursRange.last90Days, _now);
      expect(p90.startUtc, _now.subtract(const Duration(days: 90)));
      expect(p30.contains(_now), isFalse, reason: 'end is exclusive');
      expect(p30.contains(p30.startUtc), isTrue);
    });

    test('a month is the Addis calendar month', () {
      final p = BusyHoursPeriod.of(BusyHoursRange.month, _now, month: '2026-10');
      expect(p.startUtc, DateTime.utc(2026, 9, 30, 21)); // 1 Oct 00:00 Addis
      expect(p.endUtc, DateTime.utc(2026, 10, 31, 21));
      expect(BusyHoursPeriod.of(BusyHoursRange.month, _now).month, '2026-11');
      final dec = BusyHoursPeriod.of(BusyHoursRange.month, _now, month: '2025-12');
      expect(dec.endUtc, DateTime.utc(2025, 12, 31, 21), reason: 'rolls over the year');
      expect(() => BusyHoursPeriod.of(BusyHoursRange.month, _now, month: 'Oct'), throwsArgumentError);
    });
  });

  group('heatmap aggregation', () {
    // Monday 16 Nov 2026 in Addis.
    DateTime addis(int day, int hour, [int minute = 0]) => addisLocalToUtc(2026, 11, day, hour, minute);

    final bookings = [
      _b('mon1', addis(16, 10, 15)),
      _b('mon2', addis(16, 10, 45), status: BookingStatus.noShow),
      _b('mon3', addis(16, 11), status: BookingStatus.confirmed),
      _b('sat1', addis(14, 14)),
      _b('sat-late', addis(14, 0, 30), status: BookingStatus.pending), // Fri 21:30 UTC
      _b('cancelled', addis(14, 15), status: BookingStatus.cancelled),
      _b('other-shop', addis(16, 10), shopId: 's2'),
      _b('too-old', addis(1, 10).subtract(const Duration(days: 40))),
    ];
    final period = BusyHoursPeriod.of(BusyHoursRange.last30Days, _now);
    final map = busyHoursFromBookings(bookings, shopId: 's1', period: period);

    test('counts each booking in its Addis weekday and start hour', () {
      expect(map.at(DateTime.monday, 10), 2);
      expect(map.at(DateTime.monday, 11), 1);
      expect(map.at(DateTime.saturday, 14), 1);
      expect(map.at(DateTime.saturday, 0), 1, reason: 'Friday 21:30 UTC is Saturday 00:30 in Addis');
      expect(map.at(DateTime.friday, 21), 0);
      expect(map.total, 5, reason: 'cancelled, other shop and out-of-period bookings are left out');
      expect(map.maxCell, 2);
      expect(map.byWeekday, [3, 0, 0, 0, 0, 2, 0]);
      expect(map.byHour[10], 2);
    });

    test('callouts', () {
      expect(map.busiestWeekday, DateTime.monday);
      expect(map.busiestSlot, (DateTime.monday, 10));
      // Open 08-20: 08 and 09 have nothing; the earliest wins.
      expect(map.quietestHour(openingHour: 8, closingHour: 20), 8);
      // Open 10-12 only: 11 has one booking, 10 has two.
      expect(map.quietestHour(openingHour: 10, closingHour: 12), 11);
      // The Saturday 00:30 booking widens the grid.
      expect(map.visibleHours(openingHour: 8, closingHour: 20), (0, 20));
      expect(map.visibleHours(openingHour: 9, closingHour: 15), (0, 15));
    });

    test('ties go to the earlier day and hour', () {
      final tie = busyHoursFromBookings([_b('tue', addis(17, 9)), _b('mon', addis(16, 15))],
          shopId: 's1', period: period);
      expect(tie.busiestWeekday, DateTime.monday);
      expect(tie.busiestSlot, (DateTime.monday, 15));
    });

    test('an empty period has no callouts', () {
      final empty = busyHoursFromBookings(const [], shopId: 's1', period: period);
      expect(empty.isEmpty, isTrue);
      expect(empty.busiestWeekday, isNull);
      expect(empty.busiestSlot, isNull);
      expect(empty.quietestHour(openingHour: 8, closingHour: 20), isNull);
      expect(empty.visibleHours(openingHour: 8, closingHour: 20), (8, 20));
    });

    test('odd opening hours fall back to the whole day', () {
      expect(map.visibleHours(openingHour: 20, closingHour: 8), (0, 24));
      expect(map.quietestHour(openingHour: 20, closingHour: 8), 1);
    });

    test('fromGrid checks the shape', () {
      expect(() => BusyHoursHeatmap.fromGrid([[1]]), throwsArgumentError);
      final grid = List.generate(7, (_) => List.filled(24, 0));
      grid[6][23] = 4;
      final m = BusyHoursHeatmap.fromGrid(grid);
      expect(m.at(DateTime.sunday, 23), 4);
      expect(m.busiestWeekday, DateTime.sunday);
    });
  });

  group('OwnerInsightsService', () {
    final repo = AppRepository.instance;
    setUp(() => loadTestSeed(now: _now));

    test('local mode reads the cached bookings', () async {
      final service = OwnerInsightsService(repository: repo);
      final period = BusyHoursPeriod.of(BusyHoursRange.last90Days, _now);
      expect(service.needsQuery(period, _now), isFalse);
      final map = await service.busyHours('shop_1', period, now: _now);
      expect(map.total, busyHoursFromBookings(repo.getShopBookings('shop_1'), shopId: 'shop_1', period: period).total);
    });

    test('with Firestore, a month older than the cached window is queried and merged', () async {
      final db = FakeFirebaseFirestore();
      final service = OwnerInsightsService(repository: repo, firestore: db);
      final june = BusyHoursPeriod.of(BusyHoursRange.month, _now, month: '2026-06');
      final thisMonth = BusyHoursPeriod.of(BusyHoursRange.month, _now);
      expect(service.needsQuery(june, _now), isTrue);
      expect(service.needsQuery(thisMonth, _now), isFalse);
      expect(OwnerInsightsService.cacheCovers(BusyHoursPeriod.of(BusyHoursRange.last90Days, _now), _now), isTrue);

      Future<void> put(Booking b) => db.collection('bookings').doc(b.id).set(b.toMap());
      await put(_b('j1', addisLocalToUtc(2026, 6, 6, 9), shopId: 'shop_1')); // Saturday
      await put(_b('j2', addisLocalToUtc(2026, 6, 13, 9, 30), shopId: 'shop_1'));
      await put(_b('j3', addisLocalToUtc(2026, 6, 13, 10), shopId: 'shop_1', status: BookingStatus.cancelled));
      await put(_b('other', addisLocalToUtc(2026, 6, 13, 9), shopId: 'shop_2'));
      await put(_b('july', addisLocalToUtc(2026, 7, 1, 0, 30), shopId: 'shop_1'));

      final map = await service.busyHours('shop_1', june, now: _now);
      expect(map.total, 2);
      expect(map.at(DateTime.saturday, 9), 2);
      expect(map.busiestWeekday, DateTime.saturday);
    });
  });

  group('Busy hours tab', () {
    final repo = AppRepository.instance;
    setUp(() {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    });

    testWidgets('shows the total, callouts and the grid; ranges switch', (tester) async {
      await tester.pumpWidget(_app(BusyHoursTab(shopId: 'shop_1', now: _now)));
      await tester.pumpAndSettle();

      final p30 = BusyHoursPeriod.of(BusyHoursRange.last30Days, _now);
      final expected = busyHoursFromBookings(repo.getShopBookings('shop_1'), shopId: 'shop_1', period: p30);
      expect(expected.total, greaterThan(0), reason: 'the seed has past bookings at shop_1');
      expect(find.byKey(const ValueKey('busy-summary')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('busy-total'))).data, '${expected.total}');
      expect(find.text('Busiest day'), findsOneWidget);
      expect(find.text('Quietest hour'), findsOneWidget);
      final (d, h) = expected.busiestSlot!;
      expect(find.byKey(ValueKey('busy-cell-$d-$h')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('bookings')), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('busy-range-month')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('busy-month-picker')), findsOneWidget);

      // October 2026: the seed has nothing at shop_1 then.
      await tester.tap(find.byKey(const ValueKey('busy-month-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('October 2026').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('busy-empty')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('busy-total'))).data, '0');
    });

    testWidgets('Amharic labels', (tester) async {
      await tester.pumpWidget(_app(BusyHoursTab(shopId: 'shop_1', now: _now), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('በጣም የተጨናነቀ ቀን'), findsOneWidget);
      expect(find.text('ያለፉት 30 ቀናት'), findsOneWidget);
    });
  });
}
