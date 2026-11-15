import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/payouts/payouts_dashboard_entries.dart';
import 'package:barbershop_booking/features/payouts/payouts_l10n.dart';
import 'package:barbershop_booking/features/payouts/payouts_manager.dart';
import 'package:barbershop_booking/features/payouts/payouts_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// 10:00 in Addis on Friday 2026-11-20.
final _now = DateTime.utc(2026, 11, 20, 7, 0);
final _nov = PayoutMonth(2026, 11);

Map<String, dynamic> _seedJson() => jsonDecode(readSeedJson()) as Map<String, dynamic>;

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

Barber _barber({String id = 'b1', String shopId = 's1', int? commission}) =>
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

Payout _payout(String id, double amount, PayoutMonth month,
        {String barberId = 'b1', String shopId = 's1', DateTime? createdAt}) =>
    Payout(
      id: id,
      shopId: shopId,
      barberId: barberId,
      amount: amount,
      periodStart: month.firstDay,
      periodEnd: month.lastDay,
      method: PayoutMethod.cash,
      createdBy: 'owner',
      createdAt: createdAt ?? _now,
    );

/// A fresh manager over the local store holding the demo payouts,
/// installed as the shared instance.
PayoutsManager _seededManager({DateTime Function()? clock}) {
  final store = LocalPayoutStore()..loadSeedJson(_seedJson(), now: _now);
  final manager = PayoutsManager(local: store, clock: clock ?? () => _now);
  PayoutsManager.instance = manager;
  return manager;
}

void main() {
  final repo = AppRepository.instance;
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => PayoutsManager.instance = null);

  group('pure calculations', () {
    test('commission defaults to 50 and is validated', () {
      expect(commissionOf(_barber()), kDefaultCommissionPercent);
      expect(commissionOf(_barber(commission: 0)), 0);
      expect(commissionOf(_barber(commission: 100)), 100);
      expect(commissionOf(_barber(commission: 140)), kDefaultCommissionPercent);
      expect(isValidCommissionPercent(-1), isFalse);
      expect(isValidCommissionPercent(101), isFalse);
      expect(_barber().effectiveCommissionPercent, 50);
    });

    test('share is rounded to whole Birr per booking', () {
      expect(barberShareOf(1200, 60), 720);
      expect(barberShareOf(255, 50), 128); // 127.5 rounds half away from zero
      expect(barberShareOf(333, 40), 133); // 133.2
      expect(barberShareOf(450, 0), 0);
      expect(barberShareOf(450, 100), 450);
    });

    test('Addis months: boundaries, keys, navigation', () {
      final m = PayoutMonth.ofInstant(DateTime.utc(2026, 11, 30, 21, 30)); // Dec 1, 00:30 Addis
      expect(m, PayoutMonth(2026, 12));
      expect(PayoutMonth.ofInstant(DateTime.utc(2026, 11, 30, 20, 59)), _nov);
      expect(_nov.startUtc, DateTime.utc(2026, 10, 31, 21));
      expect(_nov.endUtc, DateTime.utc(2026, 11, 30, 21));
      expect(_nov.firstDay, DateTime.utc(2026, 11, 1));
      expect(_nov.lastDay, DateTime.utc(2026, 11, 30));
      expect(PayoutMonth(2026, 1).previous(), PayoutMonth(2025, 12));
      expect(PayoutMonth(2026, 12).next(), PayoutMonth(2027, 1));
      expect(_nov.key, '2026-11');
      expect(PayoutMonth.tryParse('2026-11'), _nov);
      expect(PayoutMonth.tryParse('2026-13'), isNull);
      expect(PayoutMonth.recent(_now, 3), [_nov, PayoutMonth(2026, 10), PayoutMonth(2026, 9)]);
    });

    test('month summary counts only completed bookings of the barber in the Addis month', () {
      final barber = _barber(commission: 40);
      final bookings = [
        _booking('a', 1000, DateTime.utc(2026, 11, 5, 8)),
        _booking('b', 333, DateTime.utc(2026, 11, 6, 8)),
        _booking('c', 500, DateTime.utc(2026, 11, 7, 8), status: BookingStatus.confirmed),
        _booking('d', 500, DateTime.utc(2026, 11, 7, 8), status: BookingStatus.noShow),
        _booking('e', 500, DateTime.utc(2026, 11, 8, 8), barberId: 'other'),
        _booking('f', 500, DateTime.utc(2026, 10, 31, 20)), // Oct 31, 23:00 Addis
        _booking('g', 700, DateTime.utc(2026, 10, 31, 21)), // Nov 1, 00:00 Addis
      ];
      final payouts = [
        _payout('p1', 300, _nov),
        _payout('p2', 100, PayoutMonth(2026, 10)),
        _payout('p3', 900, _nov, barberId: 'other'),
      ];
      final s = summarizeBarberMonth(barber: barber, bookings: bookings, payouts: payouts, month: _nov);
      expect(s.completedJobs, 3);
      expect(s.gross, 2033);
      expect(s.share, 400 + 133 + 280);
      expect(s.paid, 300);
      expect(s.balance, 513);
      expect(s.suggestedPayout, 513);
      expect(s.commissionPercent, 40);
    });

    test('totals: owed sums positive balances only', () {
      final rows = summarizeShopMonth(
        barbers: [_barber(id: 'b1', commission: 50), _barber(id: 'b2', commission: 50)],
        bookings: [_booking('a', 1000, DateTime.utc(2026, 11, 5, 8))],
        payouts: [_payout('p1', 200, _nov, barberId: 'b2')],
        month: _nov,
      );
      expect(rows.map((r) => r.balance), [500, -200]);
      expect(rows[1].suggestedPayout, 0);
      final t = ShopPayoutTotals.of(rows);
      expect(t.gross, 1000);
      expect(t.share, 500);
      expect(t.paid, 200);
      expect(t.owed, 500);
    });

    test('input validation and amount parsing', () {
      final d = DateTime.utc(2026, 11, 1);
      expect(validatePayoutInput(amount: 100, periodStart: d, periodEnd: d), isNull);
      expect(validatePayoutInput(amount: 0, periodStart: d, periodEnd: d), PayoutErrorCode.invalidAmount);
      expect(validatePayoutInput(amount: -5, periodStart: d, periodEnd: d), PayoutErrorCode.invalidAmount);
      expect(validatePayoutInput(amount: 1000000, periodStart: d, periodEnd: d), isNull);
      expect(validatePayoutInput(amount: 1000000.01, periodStart: d, periodEnd: d), PayoutErrorCode.invalidAmount);
      expect(validatePayoutInput(amount: double.nan, periodStart: d, periodEnd: d), PayoutErrorCode.invalidAmount);
      expect(validatePayoutInput(amount: 5, periodStart: d.add(const Duration(days: 1)), periodEnd: d),
          PayoutErrorCode.invalidPeriod);
      expect(validatePayoutInput(amount: 5, periodStart: d, periodEnd: d, note: 'x' * 201), PayoutErrorCode.noteTooLong);
      expect(validatePayoutInput(amount: 5, periodStart: d, periodEnd: d, note: 'x' * 200), isNull);
      expect(parsePayoutAmount('1,250'), 1250);
      expect(parsePayoutAmount(' 300.5 '), 300.5);
      expect(parsePayoutAmount(''), isNull);
      expect(parsePayoutAmount('abc'), isNull);
      expect(roundBirr(10.006), 10.01);
    });

    test('delete window is 24 hours from recording', () {
      final p = _payout('p', 100, _nov, createdAt: _now);
      expect(isWithinPayoutDeleteWindow(p, _now.add(const Duration(hours: 23, minutes: 59))), isTrue);
      expect(isWithinPayoutDeleteWindow(p, _now.add(const Duration(hours: 24))), isFalse);
    });

    test('payout map round trip', () {
      final p = Payout(
        id: 'p1',
        shopId: 's1',
        barberId: 'b1',
        amount: 1250,
        periodStart: DateTime.utc(2026, 11, 1),
        periodEnd: DateTime.utc(2026, 11, 30),
        method: PayoutMethod.telebirr,
        note: 'Week 1',
        createdBy: 'owner_1',
        createdAt: _now,
      );
      final map = p.toMap();
      expect(map, {
        'barberId': 'b1',
        'amount': 1250,
        'periodStart': '2026-11-01T00:00:00.000Z',
        'periodEnd': '2026-11-30T00:00:00.000Z',
        'method': 'telebirr',
        'note': 'Week 1',
        'createdBy': 'owner_1',
        'createdAt': '2026-11-20T07:00:00.000Z',
      });
      expect(map['amount'], isA<int>());
      expect(Payout.fromMap(map, 'p1', shopId: 's1'), p);
      final noNote = Payout.fromMap({...map}..remove('note'), 'p1', shopId: 's1');
      expect(noNote.note, isNull);
      expect(noNote.toMap().containsKey('note'), isFalse);
      expect(PayoutMethod.fromName('crypto'), PayoutMethod.other);
    });

    test('barber commission round-trips through the profile maps', () {
      final b = _barber(commission: 60);
      expect(b.toMap()['commissionPercent'], 60);
      expect(_barber().toMap().containsKey('commissionPercent'), isFalse);
      expect(b.toProfileMap()['commissionPercent'], 60);
      expect(Barber.fromMap(b.toMap(), 'b1').commissionPercent, 60);
      expect(b.copyWith(name: 'X').commissionPercent, 60);
      expect(b.copyWith(commissionPercent: 45).commissionPercent, 45);
    });
  });

  group('demo seed', () {
    setUp(() => loadTestSeed(now: _now));

    test('seeded barbers carry commission and the payouts resolve to the current month', () {
      expect(repo.getBarberById('barber_1')!.commissionPercent, 60);
      expect(repo.getBarberById('barber_2')!.commissionPercent, 50);
      expect(repo.getBarberById('barber_1_3')!.commissionPercent, 40);
      final payouts = payoutsFromSeedJson(_seedJson(), now: _now);
      expect(payouts, hasLength(2));
      final first = payouts.firstWhere((p) => p.id == 'payout_seed_1');
      expect(first.shopId, 'shop_1');
      expect(first.barberId, 'barber_1');
      expect(first.amount, 200);
      expect(first.periodStart, DateTime.utc(2026, 11, 1));
      expect(first.periodEnd, DateTime.utc(2026, 11, 30));
      expect(first.createdAt, _now.subtract(const Duration(hours: 30)));
      expect(first.createdBy, 'owner_1');
    });
  });

  group('manager (local store)', () {
    late PayoutsManager m;

    setUp(() {
      loadTestSeed(now: _now);
      m = _seededManager();
    });

    test('owner sees per-barber figures for the month', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final bookings = await m.loadMonthBookings('shop_1', _nov);
      final payouts = await m.watchShopPayouts('shop_1', _nov).first;
      expect(payouts.map((p) => p.id), ['payout_seed_2', 'payout_seed_1']); // newest recorded first
      final rows = {for (final r in m.summarizeMonth('shop_1', _nov, bookings: bookings, payouts: payouts)) r.barberId: r};
      // book_3: barber_1, completed 2 days ago, 1200 Birr at 60%.
      expect(rows['barber_1']!.completedJobs, 1);
      expect(rows['barber_1']!.gross, 1200);
      expect(rows['barber_1']!.share, 720);
      expect(rows['barber_1']!.paid, 200);
      expect(rows['barber_1']!.balance, 520);
      expect(rows['barber_2']!.paid, 150);
      expect(rows['barber_2']!.balance, -150);
      expect(rows['barber_1_3']!.share, 0);
      expect(ShopPayoutTotals.of(rows.values).owed, 520);
    });

    test('completing a booking adds the share at its price', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateBookingStatus('book_2', BookingStatus.completed); // barber_1, 300 Birr, today
      final s = m
          .summarizeMonth('shop_1', _nov, bookings: m.cachedMonthBookings('shop_1', _nov), payouts: const [])
          .firstWhere((r) => r.barberId == 'barber_1');
      expect(s.completedJobs, 2);
      expect(s.share, 720 + 180);
    });

    test('owner records a payout; it shows for the owner and the barber', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final p = await m.recordPayout(
        shopId: 'shop_1',
        barberId: 'barber_1',
        amount: 520,
        method: PayoutMethod.bank,
        month: _nov,
        note: '  November balance ',
      );
      expect(p.createdBy, 'owner_1');
      expect(p.createdAt, _now);
      expect(p.note, 'November balance');
      expect(p.periodStart, DateTime.utc(2026, 11, 1));
      expect(p.periodEnd, DateTime.utc(2026, 11, 30));
      expect((await m.watchShopPayouts('shop_1', _nov).first).first.id, p.id);
      final mine = await m.watchBarberPayouts(repo.getBarberById('barber_1')!).first;
      expect(mine.map((x) => x.id), [p.id, 'payout_seed_1']);
      expect(mine.every((x) => x.barberId == 'barber_1'), isTrue);
    });

    test('payout input and permissions are enforced', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      Future<Payout> record({String shopId = 'shop_1', String barberId = 'barber_1', double amount = 100, String? note}) =>
          m.recordPayout(shopId: shopId, barberId: barberId, amount: amount, method: PayoutMethod.cash, note: note);
      Matcher code(PayoutErrorCode c) => throwsA(isA<PayoutException>().having((e) => e.code, 'code', c));
      await expectLater(record(amount: 0), code(PayoutErrorCode.invalidAmount));
      await expectLater(record(amount: 2000000), code(PayoutErrorCode.invalidAmount));
      await expectLater(record(note: 'x' * 201), code(PayoutErrorCode.noteTooLong));
      await expectLater(record(barberId: 'barber_2_1'), code(PayoutErrorCode.unknownBarber));
      await expectLater(record(shopId: 'shop_2', barberId: 'barber_2_1'), code(PayoutErrorCode.ownerOnly));
      await expectLater(
        m.recordPayout(
          shopId: 'shop_1',
          barberId: 'barber_1',
          amount: 10,
          method: PayoutMethod.cash,
          periodStart: DateTime.utc(2026, 11, 10),
          periodEnd: DateTime.utc(2026, 11, 9),
        ),
        code(PayoutErrorCode.invalidPeriod),
      );

      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await expectLater(record(), code(PayoutErrorCode.ownerOnly));
      await expectLater(m.setCommission('barber_1', 70), code(PayoutErrorCode.ownerOnly));

      await repo.signOut();
      await expectLater(record(), throwsA(isA<AppStateException>()));
    });

    test('owner deletes a payout only within 24 hours', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final all = await m.watchShopPayouts('shop_1', _nov).first;
      final recent = all.firstWhere((p) => p.id == 'payout_seed_2'); // 3 hours old
      final old = all.firstWhere((p) => p.id == 'payout_seed_1'); // 30 hours old
      expect(m.canDelete(recent), isTrue);
      expect(m.canDelete(old), isFalse);
      await expectLater(
        m.deletePayout(old),
        throwsA(isA<PayoutException>().having((e) => e.code, 'code', PayoutErrorCode.deleteWindowPassed)),
      );
      await m.deletePayout(recent);
      expect((await m.watchShopPayouts('shop_1', _nov).first).map((p) => p.id), ['payout_seed_1']);

      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(m.canDelete(old), isFalse);
    });

    test('owner sets commission; it changes the share', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await m.setCommission('barber_1', 45);
      expect(repo.getBarberById('barber_1')!.commissionPercent, 45);
      final s = m
          .summarizeMonth('shop_1', _nov, bookings: m.cachedMonthBookings('shop_1', _nov), payouts: const [])
          .firstWhere((r) => r.barberId == 'barber_1');
      expect(s.share, 540);
      await expectLater(m.setCommission('barber_1', 101),
          throwsA(isA<PayoutException>().having((e) => e.code, 'code', PayoutErrorCode.invalidCommission)));
      await expectLater(m.setCommission('nope', 10),
          throwsA(isA<PayoutException>().having((e) => e.code, 'code', PayoutErrorCode.notFound)));
      await expectLater(m.setCommission('barber_2_1', 10),
          throwsA(isA<PayoutException>().having((e) => e.code, 'code', PayoutErrorCode.ownerOnly)));
    });
  });

  group('l10n', () {
    test('every error code has English and Amharic text', () async {
      for (final locale in const [Locale('en'), Locale('am')]) {
        final l = await AppLocalizations.delegate.load(locale);
        for (final c in PayoutErrorCode.values) {
          expect(l.payoutsErrorText(PayoutException(c)), isNotEmpty, reason: '$locale $c');
        }
        for (final m in PayoutMethod.values) {
          expect(l.payoutMethodLabel(m), isNotEmpty);
        }
      }
    });
  });

  group('screens', () {
    setUp(() => loadTestSeed(now: _now));

    /// A tall surface so the whole payouts list is built.
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('owner payouts screen: figures, record a payout, delete it', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final m = _seededManager();
      await tester.pumpWidget(_app(PayoutsScreen(shopId: 'shop_1', manager: m)));
      await tester.pumpAndSettle();

      expect(find.text('Barber payouts'), findsOneWidget);
      final row1 = find.byKey(const ValueKey('payout-row-barber_1'));
      expect(find.descendant(of: row1, matching: find.text('ETB 720')), findsOneWidget);
      expect(find.descendant(of: row1, matching: find.text('Commission: 60%')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('payout-balance-barber_1')), matching: find.text('ETB 520')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('payouts-total-owed')), matching: find.text('ETB 520')),
        findsOneWidget,
      );
      // Only the 3-hour-old seeded payout can still be deleted.
      expect(find.byKey(const ValueKey('payout-delete-payout_seed_2'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('payout-delete-payout_seed_1'), skipOffstage: false), findsNothing);

      await tester.tap(find.byKey(const ValueKey('payout-record-barber_1')));
      await tester.pumpAndSettle();
      final amountField = find.byKey(const ValueKey('payout-amount-field'));
      expect(tester.widget<TextField>(amountField).controller!.text, '520');
      await tester.tap(find.byKey(const ValueKey('payout-method-telebirr')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('payout-save')));
      await tester.pumpAndSettle();

      expect(find.text('Payout recorded.'), findsOneWidget);
      expect(m.local.all.where((p) => p.barberId == 'barber_1' && p.amount == 520 && p.method == PayoutMethod.telebirr),
          hasLength(1));
      expect(
        find.descendant(of: find.byKey(const ValueKey('payout-balance-barber_1')), matching: find.text('ETB 0')),
        findsOneWidget,
      );

      // Delete the seeded 3-hour-old payout.
      final del = find.byKey(const ValueKey('payout-delete-payout_seed_2'));
      await tester.scrollUntilVisible(del, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(del);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payout-delete-confirm')));
      await tester.pumpAndSettle();
      expect(m.local.all.any((p) => p.id == 'payout_seed_2'), isFalse);
    });

    testWidgets('owner payouts screen: invalid amount shows an error', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final m = _seededManager();
      await tester.pumpWidget(_app(PayoutsScreen(shopId: 'shop_1', manager: m)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payout-record-barber_2')));
      await tester.pumpAndSettle();
      // barber_2 is overpaid, so nothing is prefilled.
      expect(tester.widget<TextField>(find.byKey(const ValueKey('payout-amount-field'))).controller!.text, '');
      await tester.tap(find.byKey(const ValueKey('payout-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('payout-error')), findsOneWidget);
    });

    testWidgets('owner sets commission from the payouts screen', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final m = _seededManager();
      await tester.pumpWidget(_app(PayoutsScreen(shopId: 'shop_1', manager: m)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payout-commission-barber_1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('commission-field')), '50');
      await tester.tap(find.byKey(const ValueKey('commission-save')));
      await tester.pumpAndSettle();
      expect(repo.getBarberById('barber_1')!.commissionPercent, 50);
      final row1 = find.byKey(const ValueKey('payout-row-barber_1'));
      expect(find.descendant(of: row1, matching: find.text('ETB 600')), findsOneWidget);
    });

    testWidgets('barber card: share, paid, balance and own payouts (Amharic too)', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      _seededManager();
      final barber = repo.getBarberById('barber_1')!;
      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: BarberPayoutsCard(barber: barber)))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('barber-payouts-card')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('barber-payouts-share'))).data, 'ETB 720');
      expect(find.descendant(of: find.byKey(const ValueKey('barber-payouts-paid')), matching: find.text('ETB 200')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('barber-payouts-balance')), matching: find.text('ETB 520')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('payout-payout_seed_1')), findsOneWidget);
      // Another barber's payout is not listed.
      expect(find.byKey(const ValueKey('payout-payout_seed_2')), findsNothing);
      // Barbers never get a delete action.
      expect(find.byKey(const ValueKey('payout-delete-payout_seed_1')), findsNothing);

      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: BarberPayoutsCard(barber: barber))),
          locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('720 ብር'), findsOneWidget);
    });

    testWidgets('manage barbers: commission line and edit dialog', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      _seededManager();
      await tester.pumpWidget(_app(const ManageBarbersScreen(shopId: 'shop_1')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('barber-commission-barber_1_3'))).data, 'Commission: 40%');
      await tester.tap(find.byKey(const ValueKey('edit-commission-barber_1_3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('commission-field')), '101');
      await tester.tap(find.byKey(const ValueKey('commission-save')));
      await tester.pumpAndSettle();
      expect(find.text('Commission must be a whole number from 0 to 100.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('commission-field')), '55');
      await tester.tap(find.byKey(const ValueKey('commission-save')));
      await tester.pumpAndSettle();
      expect(repo.getBarberById('barber_1_3')!.commissionPercent, 55);
      expect(tester.widget<Text>(find.byKey(const ValueKey('barber-commission-barber_1_3'))).data, 'Commission: 55%');
    });

    testWidgets('owner dashboard entry opens the payouts screen', (tester) async {
      tallView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      _seededManager();
      await tester.pumpWidget(_app(const Scaffold(body: OwnerPayoutsButton(shopId: 'shop_1'))));
      await tester.tap(find.byKey(const ValueKey('open-payouts')));
      await tester.pumpAndSettle();
      expect(find.byType(PayoutsScreen), findsOneWidget);
    });
  });
}
