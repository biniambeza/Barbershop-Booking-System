import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/payouts/earnings_cards.dart';
import 'package:barbershop_booking/features/payouts/payouts_dashboard_entries.dart';
import 'package:barbershop_booking/features/payouts/payouts_manager.dart';
import 'package:barbershop_booking/features/payouts/payouts_screen.dart';
import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/reports_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// 10:00 in Addis on Friday 2026-11-20 (the seed's clock).
final _now = DateTime.utc(2026, 11, 20, 7, 0);
// 10:00 in Addis on Saturday 2026-12-05.
final _dec5 = DateTime.utc(2026, 12, 5, 7, 0);
final _nov = PayoutMonth(2026, 11);
final _dec = PayoutMonth(2026, 12);
final _jan = PayoutMonth(2027, 1);

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

Barber _barber({String id = 'b1', String shopId = 's1', int? commission = 50}) =>
    Barber(id: id, shopId: shopId, name: 'Barber $id', title: 'Barber', commissionPercent: commission);

Booking _booking(String id, double price, DateTime startUtc,
        {String barberId = 'b1', String shopId = 's1', BookingStatus status = BookingStatus.completed}) =>
    Booking(
      id: id,
      shopId: shopId,
      shopName: 'Shop',
      barberId: barberId,
      barberName: 'Barber',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '+251911000000',
      serviceId: 'srv',
      serviceName: 'Cut',
      price: price,
      date: DateTime(startUtc.year, startUtc.month, startUtc.day),
      timeSlot: '10:00 AM',
      status: status,
      createdAt: startUtc,
      startAt: startUtc,
      endAt: startUtc.add(const Duration(minutes: 30)),
      durationMinutes: 30,
    );

Payout _payout(String id, double amount, PayoutMonth month, {String barberId = 'b1', String shopId = 's1'}) => Payout(
      id: id,
      shopId: shopId,
      barberId: barberId,
      amount: amount,
      periodStart: month.firstDay,
      periodEnd: month.lastDay,
      method: PayoutMethod.cash,
      createdBy: 'owner',
      createdAt: _now,
    );

/// A manager over the demo payouts with its clock at [clock], installed as
/// the shared instance.
PayoutsManager _manager(DateTime clock) {
  final store = LocalPayoutStore()..loadSeedJson(Map<String, dynamic>.from(_seedJson), now: _now);
  final m = PayoutsManager(local: store, clock: () => clock);
  PayoutsManager.instance = m;
  return m;
}

late Map<String, dynamic> _seedJson;

void main() {
  final repo = AppRepository.instance;
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
    _seedJson = jsonDecode(readSeedJson()) as Map<String, dynamic>;
  });
  tearDown(() => PayoutsManager.instance = null);

  group('earnings periods (pure)', () {
    test('ranges follow the Addis calendar', () {
      final thisMonth = EarningsPeriod.of(EarningsRange.thisMonth, _now);
      expect(thisMonth.startUtc, DateTime.utc(2026, 10, 31, 21));
      expect(thisMonth.endUtc, DateTime.utc(2026, 11, 30, 21));
      expect(thisMonth.month, _nov);
      expect(thisMonth.firstDay, DateTime(2026, 11, 1));
      expect(thisMonth.lastDay, DateTime(2026, 11, 30));

      final last = EarningsPeriod.of(EarningsRange.lastMonth, DateTime.utc(2026, 1, 10));
      expect(last.month, PayoutMonth(2025, 12));

      final picked = EarningsPeriod.of(EarningsRange.month, _now, month: PayoutMonth(2026, 8));
      expect(picked.startUtc, DateTime.utc(2026, 7, 31, 21));
      expect(picked.endUtc, DateTime.utc(2026, 8, 31, 21));

      final year = EarningsPeriod.of(EarningsRange.thisYear, _now);
      expect(year.year, 2026);
      expect(year.startUtc, DateTime.utc(2025, 12, 31, 21));
      expect(year.endUtc, DateTime.utc(2026, 12, 31, 21));
      // 23:30 Addis on Dec 31 is still this year; 00:00 on Jan 1 is not.
      expect(year.contains(DateTime.utc(2026, 12, 31, 20, 30)), isTrue);
      expect(year.contains(DateTime.utc(2026, 12, 31, 21)), isFalse);

      final all = EarningsPeriod.of(EarningsRange.allTime, _now);
      expect(all.isAllTime, isTrue);
      expect(all.contains(DateTime.utc(2001)), isTrue);
    });

    test('totals count completed bookings of the shop/barber in the period, however old', () {
      final bookings = [
        _booking('a', 1000, DateTime.utc(2026, 11, 5, 8)),
        _booking('b', 300, DateTime.utc(2026, 3, 6, 8)), // 8 months ago: beyond the 90-day cache
        _booking('c', 500, DateTime.utc(2026, 11, 7, 8), status: BookingStatus.confirmed),
        _booking('d', 500, DateTime.utc(2026, 11, 7, 8), status: BookingStatus.cancelled),
        _booking('e', 700, DateTime.utc(2026, 11, 8, 8), barberId: 'b2'),
        _booking('f', 900, DateTime.utc(2026, 11, 8, 8), shopId: 's2'),
        _booking('g', 400, DateTime.utc(2024, 2, 1, 8)),
      ];
      EarningsTotals of(EarningsRange r, {String? barberId}) => earningsFromBookings(bookings,
          shopId: 's1', barberId: barberId, period: EarningsPeriod.of(r, _now));
      expect(of(EarningsRange.thisMonth), const EarningsTotals(completed: 2, revenue: 1700));
      expect(of(EarningsRange.thisMonth, barberId: 'b1'), const EarningsTotals(completed: 1, revenue: 1000));
      expect(of(EarningsRange.thisYear, barberId: 'b1'), const EarningsTotals(completed: 2, revenue: 1300));
      expect(of(EarningsRange.allTime, barberId: 'b1'), const EarningsTotals(completed: 3, revenue: 1700));
      expect(of(EarningsRange.lastMonth), EarningsTotals.zero);
      expect(of(EarningsRange.allTime, barberId: 'b1').shareAt(60), 1020);
    });

    test('shop earnings: barbers by revenue, barbers share and shop part', () {
      final e = ShopEarnings(
        shop: const EarningsTotals(completed: 4, revenue: 2000),
        barbers: ShopEarnings.sorted(const [
          BarberEarnings(
              barberId: 'a', barberName: 'Abel', commissionPercent: 50, totals: EarningsTotals(completed: 1, revenue: 500)),
          BarberEarnings(
              barberId: 'b', barberName: 'Beti', commissionPercent: 40, totals: EarningsTotals(completed: 3, revenue: 1500)),
        ]),
      );
      expect(e.barbers.map((b) => b.barberId), ['b', 'a']);
      expect(e.barbersShare, 600 + 250);
      expect(e.shopKeeps, 2000 - 850);
    });
  });

  group('carry-over (pure)', () {
    test('nothing carries into the first tracked month or before it', () {
      expect(carryOverWindow(kPayoutCarryOverStart), isNull);
      expect(carryOverWindow(PayoutMonth(2026, 6)), isNull);
      final w = carryOverWindow(_jan)!;
      expect(w.from, _nov);
      expect(w.startUtc, _nov.startUtc);
      expect(w.endUtc, _jan.startUtc);
      expect(w.containsDate(DateTime.utc(2026, 11, 1)), isTrue);
      expect(w.containsDate(DateTime.utc(2026, 12, 31)), isTrue);
      expect(w.containsDate(DateTime.utc(2027, 1, 1)), isFalse);
      expect(w.containsDate(DateTime.utc(2026, 10, 31)), isFalse);
    });

    test("a month's balance = carried + earned - paid, and it is next month's carry", () {
      final barber = _barber(commission: 50);
      final bookings = [
        _booking('old', 5000, DateTime.utc(2026, 10, 10, 8)), // before tracking: never carried
        _booking('n1', 1000, DateTime.utc(2026, 11, 3, 8)),
        _booking('n2', 600, DateTime.utc(2026, 11, 20, 8)),
        _booking('nx', 999, DateTime.utc(2026, 11, 21, 8), status: BookingStatus.noShow),
        _booking('d1', 400, DateTime.utc(2026, 12, 2, 8)),
        _booking('o1', 800, DateTime.utc(2026, 11, 3, 8), barberId: 'b2'),
      ];
      final payouts = [
        _payout('pOld', 50, PayoutMonth(2026, 10)),
        _payout('pNov', 300, _nov),
        _payout('pDec', 500, _dec),
        _payout('pOther', 999, _nov, barberId: 'b2'),
      ];

      BarberBalance balanceOf(PayoutMonth m) => BarberBalance(
            summary: summarizeBarberMonth(barber: barber, bookings: bookings, payouts: payouts, month: m),
            carry: carryOverFromData(barber: barber, bookings: bookings, payouts: payouts, month: m),
          );

      final nov = balanceOf(_nov);
      expect(nov.carriedOver, 0);
      expect(nov.summary.share, 800);
      expect(nov.balance, 500); // 800 earned - 300 paid

      final dec = balanceOf(_dec);
      expect(dec.carry.from, _nov);
      expect(dec.carry.completedJobs, 2);
      expect(dec.carry.revenue, 1600);
      expect(dec.carriedOver, nov.balance); // 500 carried from November
      expect(dec.summary.share, 200);
      expect(dec.balance, 500 + 200 - 500); // paying part leaves the rest
      expect(dec.suggestedPayout, 200);

      final jan = balanceOf(_jan);
      expect(jan.carry.from, _dec);
      expect(jan.carriedOver, dec.balance);
      expect(jan.balance, 200);
    });

    test('an overpayment carries over as a negative amount', () {
      final barber = _barber(commission: 50);
      final bookings = [_booking('n1', 1000, DateTime.utc(2026, 11, 3, 8))];
      final payouts = [_payout('p', 700, _nov)];
      final carry = carryOverFromData(barber: barber, bookings: bookings, payouts: payouts, month: _dec);
      expect(carry.amount, -200);
      final row = BarberBalance(
        summary: summarizeBarberMonth(
            barber: barber, bookings: [_booking('d', 1000, DateTime.utc(2026, 12, 3, 8))], payouts: const [], month: _dec),
        carry: carry,
      );
      expect(row.balance, 300);
    });

    test('shop totals: owed sums positive running balances only', () {
      BarberPayoutSummary s(String id, double share, double paid) => BarberPayoutSummary(
          barberId: id, barberName: id, commissionPercent: 50, completedJobs: 1, gross: share * 2, share: share, paid: paid);
      final rows = withCarryOver(
        [s('a', 100, 0), s('b', 100, 0), s('c', 0, 0)],
        {
          'a': carryOverOf(month: _dec, commissionPercent: 50, completedBefore: 1, revenueBefore: 400, paidBefore: 0),
          'b': carryOverOf(month: _dec, commissionPercent: 50, completedBefore: 1, revenueBefore: 0, paidBefore: 300),
        },
        _dec,
      );
      expect(rows.map((r) => r.balance), [300, -200, 0]);
      final t = ShopBalanceTotals.of(rows);
      expect(t.carriedOver, 200 - 300);
      expect(t.share, 200);
      expect(t.owed, 300);
    });
  });

  group('manager (local)', () {
    setUp(() => loadTestSeed(now: _now));

    test('earnings for any period include bookings older than 90 days', () async {
      final m = _manager(_now);
      // barber_1: book_3 (1200, 2 days ago) and book_9 (450, 96 days ago), 60%.
      final month = await m.loadEarnings('shop_1', EarningsPeriod.of(EarningsRange.thisMonth, _now), barberId: 'barber_1');
      expect(month, const EarningsTotals(completed: 1, revenue: 1200));
      final all = await m.loadEarnings('shop_1', EarningsPeriod.of(EarningsRange.allTime, _now), barberId: 'barber_1');
      expect(all, const EarningsTotals(completed: 2, revenue: 1650));
      expect(all.shareAt(60), 990);
      final aug = await m.loadEarnings('shop_1', EarningsPeriod.of(EarningsRange.month, _now, month: PayoutMonth(2026, 8)));
      expect(aug, const EarningsTotals(completed: 3, revenue: 1000)); // book_9, book_10, book_11

      final shop = await m.loadShopEarnings('shop_1', EarningsPeriod.of(EarningsRange.thisYear, _now));
      expect(shop.shop, const EarningsTotals(completed: 5, revenue: 3400));
      expect(shop.barbers.map((b) => b.barberId), ['barber_1', 'barber_2', 'barber_1_3']);
      expect(shop.barbersShare, 990 + 750 + 100);
      expect(shop.shopKeeps, 3400 - 1840);
    });

    test("November's unpaid balance carries into December; part payment leaves the rest", () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final m = _manager(_dec5);
      final carries = await m.loadShopCarryOver('shop_1', _dec);
      // barber_1: 720 share in November - 200 paid; barber_2 was paid 150 with nothing earned.
      expect(carries['barber_1']!.amount, 520);
      expect(carries['barber_1']!.from, _nov);
      expect(carries['barber_2']!.amount, -150);
      expect(carries['barber_1_3']!.isZero, isTrue);
      expect((await m.loadShopCarryOver('shop_1', _nov))['barber_1']!.isZero, isTrue);

      await m.recordPayout(shopId: 'shop_1', barberId: 'barber_1', amount: 300, method: PayoutMethod.cash, month: _dec);
      final decRow = BarberBalance(
        summary: m
            .summarizeMonth('shop_1', _dec,
                bookings: m.cachedMonthBookings('shop_1', _dec), payouts: await m.watchShopPayouts('shop_1', _dec).first)
            .firstWhere((r) => r.barberId == 'barber_1'),
        carry: carries['barber_1']!,
      );
      expect(decRow.balance, 220);
      final jan = await m.loadCarryOver(repo.getBarberById('barber_1')!, _jan);
      expect(jan.amount, 220);
      expect(jan.from, _dec);
    });
  });

  group('Firestore queries (fake)', () {
    test('aggregate earnings: completed bookings of the shop/barber in the range', () async {
      final db = FakeFirebaseFirestore();
      for (final b in [
        _booking('a', 1000, DateTime.utc(2026, 11, 5, 8)),
        _booking('b', 300, DateTime.utc(2026, 3, 6, 8)),
        _booking('c', 500, DateTime.utc(2026, 11, 7, 8), status: BookingStatus.confirmed),
        _booking('e', 700, DateTime.utc(2026, 11, 8, 8), barberId: 'b2'),
        _booking('f', 900, DateTime.utc(2026, 11, 8, 8), shopId: 's2'),
      ]) {
        await db.collection('bookings').doc(b.id).set(b.toMap());
      }
      final nov = EarningsPeriod.of(EarningsRange.thisMonth, _now);
      expect(
        await PayoutsManager.aggregateCompletedBookings(db, 's1', startUtc: nov.startUtc, endUtc: nov.endUtc),
        const EarningsTotals(completed: 2, revenue: 1700),
      );
      expect(
        await PayoutsManager.aggregateCompletedBookings(db, 's1', barberId: 'b1'),
        const EarningsTotals(completed: 2, revenue: 1300),
      );
      expect(
        await PayoutsManager.aggregateCompletedBookings(db, 's3'),
        EarningsTotals.zero,
      );
    });

    test('payouts sum for the carry-over window', () async {
      final db = FakeFirebaseFirestore();
      final store = FirestorePayoutStore(db);
      for (final p in [
        _payout('p1', 300, _nov),
        _payout('p2', 100, _dec),
        _payout('p3', 999, PayoutMonth(2026, 10)),
        _payout('p4', 50, _nov, barberId: 'b2'),
      ]) {
        await store.create(p);
      }
      expect(await store.sumPaid('s1', 'b1', carryOverWindow(_dec)!), 300);
      expect(await store.sumPaid('s1', 'b1', carryOverWindow(_jan)!), 400);
      expect(await store.sumPaid('s1', 'b2', carryOverWindow(_jan)!), 50);
    });
  });

  group('l10n', () {
    test('range labels and carry-over texts exist in English and Amharic', () async {
      for (final locale in const [Locale('en'), Locale('am')]) {
        final l = await AppLocalizations.delegate.load(locale);
        for (final r in EarningsRange.values) {
          expect(l.earningsRangeLabel(r), isNotEmpty);
        }
        expect(l.payoutsCarriedOver('X'), contains('X'));
        expect(l.payoutsCarryHint, isNotEmpty);
        expect(l.earningsYourShare(60), contains('60'));
        expect(l.earningsBarberJobs(3), contains('3'));
      }
    });
  });

  group('screens', () {
    setUp(() => loadTestSeed(now: _now));

    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('owner payouts screen shows the carried-over balance and prefills it', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final m = _manager(_dec5);
      await tester.pumpWidget(_app(PayoutsScreen(shopId: 'shop_1', manager: m)));
      await tester.pumpAndSettle();

      final carried = find.byKey(const ValueKey('payout-carried-barber_1'));
      expect(find.descendant(of: carried, matching: find.text('Carried over from November 2026')), findsOneWidget);
      expect(find.descendant(of: carried, matching: find.text('ETB 520')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('payout-balance-barber_1')), matching: find.text('ETB 520')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('payout-balance-barber_2')), matching: find.text('ETB -150')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('payout-carried-barber_1_3')), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('payouts-total-owed')), matching: find.text('ETB 520')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('payouts-total-carried')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('payout-record-barber_1')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('payout-amount-field'))).controller!.text, '520');
      expect(find.byKey(const ValueKey('payout-sheet-carry')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('payout-amount-field')), '300');
      await tester.tap(find.byKey(const ValueKey('payout-save')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('payout-balance-barber_1')), matching: find.text('ETB 220')),
          findsOneWidget);
    });

    testWidgets('barber card shows the carried-over balance', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      _manager(_dec5);
      final barber = repo.getBarberById('barber_1')!;
      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: BarberPayoutsCard(barber: barber)))));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(const ValueKey('barber-payouts-carried')), matching: find.text('ETB 520')),
        findsOneWidget,
      );
      expect(find.descendant(of: find.byKey(const ValueKey('barber-payouts-balance')), matching: find.text('ETB 520')),
          findsOneWidget);
    });

    testWidgets('barber earnings card: periods beyond 90 days (Amharic too)', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final m = _manager(_now);
      final barber = repo.getBarberById('barber_1')!;
      await tester.pumpWidget(
          _app(Scaffold(body: SingleChildScrollView(child: BarberEarningsCard(barber: barber, manager: m)))));
      await tester.pumpAndSettle();
      Finder value(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));
      expect(value('earnings-revenue', 'ETB 1,200'), findsOneWidget);
      expect(value('earnings-share', 'ETB 720'), findsOneWidget);
      expect(find.text('Your share (60%)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('earnings-range-allTime')));
      await tester.pumpAndSettle();
      expect(value('earnings-completed', '2'), findsOneWidget);
      expect(value('earnings-revenue', 'ETB 1,650'), findsOneWidget);
      expect(value('earnings-share', 'ETB 990'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('earnings-range-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('earnings-month-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('August 2026').last);
      await tester.pumpAndSettle();
      expect(value('earnings-revenue', 'ETB 450'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('earnings-range-lastMonth')));
      await tester.pumpAndSettle();
      expect(value('earnings-revenue', 'ETB 0'), findsOneWidget);

      await tester.pumpWidget(_app(
          Scaffold(body: SingleChildScrollView(child: BarberEarningsCard(barber: barber, manager: m))),
          locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('ሁሉም ጊዜ'), findsOneWidget);
    });

    testWidgets('owner reports: Totals tab for any period', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      _manager(_now);
      await tester.pumpWidget(_app(OwnerReportsScreen(shopId: 'shop_1', service: ReportsService(), now: _now)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reports-tab-totals')));
      await tester.pumpAndSettle();
      String? text(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data;
      Finder value(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));
      expect(text('shop-earnings-revenue'), 'ETB 1,200');
      await tester.tap(find.byKey(const ValueKey('earnings-range-thisYear')));
      await tester.pumpAndSettle();
      expect(text('shop-earnings-revenue'), 'ETB 3,400');
      expect(find.text('5 completed jobs'), findsOneWidget);
      expect(value('shop-earnings-barbers-share', 'ETB 1,840'), findsOneWidget);
      expect(value('shop-earnings-shop-keeps', 'ETB 1,560'), findsOneWidget);
      expect(text('shop-earnings-barber-revenue-barber_2'), 'ETB 1,500');
      expect(text('shop-earnings-barber-share-barber_2'), 'ETB 750');
    });
  });
}
