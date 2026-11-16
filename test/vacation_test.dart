import 'dart:io';

import 'package:barbershop_booking/data/addis_time.dart';
import 'package:barbershop_booking/features/barber/screens/barber_schedule_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/time_off_service.dart';
import 'package:barbershop_booking/services/vacation_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

/// The busy times once the slot-lock stream has delivered too.
Future<List<BusyInterval>> _busyNow(String barberId, DateTime addisDate) async {
  var latest = const <BusyInterval>[];
  final sub = AppRepository.instance.watchBarberBusyTimes('shop_1', barberId, addisDate).listen((v) => latest = v);
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return latest;
}

Matcher _code(AppErrorCode code) => isA<AppException>().having((e) => e.code, 'code', code);

TimeOff _part(String id, DateTime start, DateTime end, {String? group, String from = '2026-11-21', String to = '2026-11-23'}) =>
    TimeOff(
      id: id,
      shopId: 'shop_1',
      barberId: 'barber_2',
      startAt: start,
      endAt: end,
      createdBy: 'u',
      createdAt: _now,
      groupId: group,
      groupFrom: group == null ? null : from,
      groupTo: group == null ? null : to,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  group('vacation rules (pure)', () {
    setUp(() => loadTestSeed(now: _now));

    test('validation: order, at most 90 days, not in the past, grid minutes, note length', () {
      void check(DateTime from, DateTime to, {int? first, int? last, String? reason}) => validateVacation(
          fromDate: from, toDate: to, firstDayFromMinute: first, lastDayToMinute: last, reason: reason, nowUtc: _now);

      expect(() => check(DateTime(2026, 11, 22), DateTime(2026, 11, 21)), throwsA(_code(AppErrorCode.timeOffInvalidRange)));
      // 21 Nov + 89 days = 90 days inclusive: allowed; one more is too long.
      check(DateTime(2026, 11, 21), DateTime(2026, 11, 21 + 89));
      expect(vacationLengthDays(DateTime(2026, 11, 21), DateTime(2026, 11, 21 + 89)), kMaxVacationDays);
      expect(() => check(DateTime(2026, 11, 21), DateTime(2026, 11, 21 + 90)), throwsA(_code(AppErrorCode.vacationTooLong)));
      expect(() => check(DateTime(2026, 11, 19), DateTime(2026, 11, 22)), throwsA(_code(AppErrorCode.timeOffInPast)));
      check(DateTime(2026, 11, 20), DateTime(2026, 11, 20)); // today is fine
      expect(() => check(DateTime(2026, 11, 21), DateTime(2026, 11, 22), first: 610), throwsA(_code(AppErrorCode.timeOffInvalidRange)));
      expect(() => check(DateTime(2026, 11, 21), DateTime(2026, 11, 21), first: 720, last: 600),
          throwsA(_code(AppErrorCode.timeOffInvalidRange)));
      expect(() => check(DateTime(2026, 11, 21), DateTime(2026, 11, 22), reason: 'x' * 201),
          throwsA(_code(AppErrorCode.timeOffReasonTooLong)));
      // Across a month end and a year end.
      expect(vacationDates(DateTime(2026, 12, 30), DateTime(2027, 1, 2)).map(addisDateKey),
          ['2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02']);
      expect(parseAddisDateKey('2026-02-30'), isNull);
      expect(parseAddisDateKey('2026-12-12'), DateTime(2026, 12, 12));
    });

    test('every working day of the range is blocked (Addis hours); partial first/last day', () {
      final shop = repo.getShopById('shop_1')!; // 08:00-20:00 Addis = 05:00-17:00Z
      final b2 = repo.getBarberById('barber_2')!;
      final ranges = vacationDayRanges(shop, b2, DateTime(2026, 11, 21), DateTime(2026, 11, 24));
      expect(ranges, [
        for (final d in [21, 22, 23, 24]) (DateTime.utc(2026, 11, d, 5), DateTime.utc(2026, 11, d, 17)),
      ]);
      final partial = vacationDayRanges(shop, b2, DateTime(2026, 11, 21), DateTime(2026, 11, 24),
          firstDayFromMinute: 14 * 60, lastDayToMinute: 12 * 60);
      expect(partial.first, (DateTime.utc(2026, 11, 21, 11), DateTime.utc(2026, 11, 21, 17)));
      expect(partial.last, (DateTime.utc(2026, 11, 24, 5), DateTime.utc(2026, 11, 24, 9)));
      expect(partial[1], ranges[1]);

      // barber_1_3 does not work on Mondays (23 Nov): no part that day.
      final b13 = vacationDayRanges(shop, repo.getBarberById('barber_1_3')!, DateTime(2026, 11, 22), DateTime(2026, 11, 24));
      expect(b13.map((r) => toAddisWallClock(r.$1).day), [22, 24]);

      // Today: only what is still ahead, from the next quarter hour.
      expect(vacationDayRanges(shop, b2, DateTime(2026, 11, 20), DateTime(2026, 11, 20), nowUtc: _now),
          [(DateTime.utc(2026, 11, 20, 7), DateTime.utc(2026, 11, 20, 17))]);
      expect(
          vacationDayRanges(shop, b2, DateTime(2026, 11, 20), DateTime(2026, 11, 20),
                  nowUtc: _now.add(const Duration(minutes: 5)))
              .single
              .$1,
          DateTime.utc(2026, 11, 20, 7, 15));
    });

    test('taken blocks split a day; conflicts list only cancellable bookings in the range', () {
      final day = (DateTime.utc(2026, 11, 21, 5), DateTime.utc(2026, 11, 21, 17));
      final taken = {DateTime.utc(2026, 11, 21, 8, 15), DateTime.utc(2026, 11, 21, 8, 30), DateTime.utc(2026, 11, 21, 8, 45)};
      expect(freeVacationSegments([day], taken), [
        (DateTime.utc(2026, 11, 21, 5), DateTime.utc(2026, 11, 21, 8, 15)),
        (DateTime.utc(2026, 11, 21, 9), DateTime.utc(2026, 11, 21, 17)),
      ]);
      expect(freeVacationSegments([day], {for (final b in slotBlocksFor(day.$1, day.$2)) b}), isEmpty);

      final all = repo.getBookingsForBarber('barber_1');
      final ranges = vacationDayRanges(repo.getShopById('shop_1')!, repo.getBarberById('barber_1')!,
          DateTime(2026, 11, 20), DateTime(2026, 11, 22), nowUtc: _now);
      final conflicts = vacationConflicts(all, shopId: 'shop_1', barberId: 'barber_1', ranges: ranges, nowUtc: _now);
      // book_2 (today 14:15) and book_1 (tomorrow 11:15); not past/cancelled ones.
      expect(conflicts.map((b) => b.id), ['book_2', 'book_1']);
      // Kept bookings stay taken; cancelled ones (and their locks) do not.
      final keep = vacationTakenBlocks(shopId: 'shop_1', barberId: 'barber_1', bookings: all);
      expect(keep, contains(DateTime.utc(2026, 11, 21, 8, 15)));
      final drop = vacationTakenBlocks(shopId: 'shop_1', barberId: 'barber_1', bookings: all, cancelledIds: {'book_1'});
      expect(drop, isNot(contains(DateTime.utc(2026, 11, 21, 8, 15))));
    });

    test('old single-day docs read as before; vacation parts round-trip and group into one row', () {
      final legacy = TimeOff.fromMap({
        'startAt': '2026-11-21T10:00:00.000Z',
        'endAt': '2026-11-21T11:00:00.000Z',
        'createdBy': 'u',
        'createdAt': '2026-11-20T07:00:00.000Z',
      }, 'old', shopId: 'shop_1', barberId: 'barber_2');
      expect(legacy.isVacationPart, isFalse);
      expect(legacy.toMap().keys.toSet(), {'startAt', 'endAt', 'createdBy', 'createdAt'});

      final p1 = _part('p1', DateTime.utc(2026, 11, 21, 5), DateTime.utc(2026, 11, 21, 17), group: 'g');
      final p2 = _part('p2', DateTime.utc(2026, 11, 23, 5), DateTime.utc(2026, 11, 23, 17), group: 'g');
      expect(p1.toMap(), containsPair('groupId', 'g'));
      expect(p1.toMap()['groupFrom'], '2026-11-21');
      expect(p1.toMap()['groupTo'], '2026-11-23');
      expect(TimeOff.fromMap(p1.toMap(), 'p1', shopId: 'shop_1', barberId: 'barber_2'), p1);
      // Half a group (missing groupTo) reads as a plain entry.
      final half = Map<String, dynamic>.of(p1.toMap())..remove('groupTo');
      expect(TimeOff.fromMap(half, 'p1', shopId: 'shop_1', barberId: 'barber_2').isVacationPart, isFalse);

      final single = _part('s', DateTime.utc(2026, 11, 22, 6), DateTime.utc(2026, 11, 22, 7));
      final items = groupTimeOff([p2, single, p1]);
      expect(items, hasLength(2));
      final vacation = items.firstWhere((i) => i.isVacation);
      expect(vacation.parts.map((p) => p.id), ['p1', 'p2']);
      expect(vacation.fromDate, DateTime(2026, 11, 21));
      expect(vacation.toDate, DateTime(2026, 11, 23));
      expect(vacation.isUpcoming(_now), isTrue);
      expect(vacation.isUpcoming(DateTime.utc(2026, 11, 24)), isFalse);
      expect(items.firstWhere((i) => !i.isVacation).parts.single.id, 's');
    });

    test('the customer notice: cancelled type, deterministic id, both languages', () {
      final b = repo.getBookingById('book_1')!;
      final en = vacationCancelNotice(b, nowUtc: _now, language: 'en');
      expect(en.id, 'book_1_cancelled');
      expect(en.type, 'cancelled');
      expect(en.bookingId, 'book_1');
      expect(en.toMap().keys.toSet(), {'title', 'body', 'type', 'bookingId', 'read', 'createdAt'});
      expect(en.body, contains('2026-11-21 11:15 AM'));
      final am = vacationCancelNotice(b, nowUtc: _now, language: 'am');
      expect(am.title, isNot(en.title));
    });
  });

  group('vacation (local repository)', () {
    setUp(() => loadTestSeed(now: _now));

    test('availability is blocked on every day of the range and free again after removing it', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      final result = await repo.addVacation(
        barberId: 'barber_2',
        fromDate: DateTime(2026, 11, 21),
        toDate: DateTime(2026, 11, 25),
        reason: ' Holiday ',
      );
      expect(result.parts, hasLength(5));
      expect(result.cancelled, isEmpty);
      expect(result.parts.map((p) => p.groupId).toSet(), hasLength(1));
      expect(result.parts.every((p) => p.reason == 'Holiday' && p.groupFrom == '2026-11-21' && p.groupTo == '2026-11-25'),
          isTrue);

      final shop = repo.getShopById('shop_1')!;
      final barber = repo.getBarberById('barber_2')!;
      Future<List<DateTime>> free(DateTime day) async => availableSlotStarts(
            shop: shop,
            barber: barber,
            durationMinutes: 30,
            addisDate: day,
            busy: await _busyNow('barber_2', day),
            nowUtc: _now,
          );
      for (final d in [21, 22, 23, 24, 25]) {
        expect(await free(DateTime(2026, 11, d)), isEmpty, reason: 'day $d');
      }
      expect(await free(DateTime(2026, 11, 26)), isNotEmpty);
      expect(await free(DateTime(2026, 11, 20)), isNotEmpty); // today untouched

      // A customer cannot book into it.
      repo.switchRole(UserRole.customer);
      await expectLater(
        repo.createBooking(
          shopId: 'shop_1',
          shopName: 'Crown Cuts Bole',
          barberId: 'barber_2',
          barberName: 'Kaleab',
          serviceId: 'srv_1_2',
          serviceName: 'x',
          price: 300,
          date: DateTime(2026, 11, 23),
          timeSlot: '10:00 AM',
          startAt: DateTime.utc(2026, 11, 23, 7),
        ),
        throwsA(isA<SlotTakenException>()),
      );

      // Shown as one item; removing it frees every day.
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      final items = groupTimeOff(await repo.watchTimeOff('shop_1', 'barber_2').first);
      expect(items.where((i) => i.isVacation), hasLength(1));
      await repo.deleteTimeOffItem(items.firstWhere((i) => i.isVacation));
      expect(await repo.watchTimeOff('shop_1', 'barber_2').first, isEmpty);
      expect(await free(DateTime(2026, 11, 23)), isNotEmpty);
    });

    test('owner cancels the bookings inside: customers notified, paid ones refund-flagged', () async {
      repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p_book_1');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final conflicts = repo.vacationConflictsFor(
          barberId: 'barber_1', fromDate: DateTime(2026, 11, 21), toDate: DateTime(2026, 11, 22));
      expect(conflicts.map((b) => b.id), ['book_1']);
      expect(conflicts.single.paymentStatus, PaymentStatus.paid);

      final result = await repo.addVacation(
        barberId: 'barber_1',
        fromDate: DateTime(2026, 11, 21),
        toDate: DateTime(2026, 11, 22),
        cancelBookingIds: ['book_1'],
      );
      final b1 = repo.getBookingById('book_1')!;
      expect(b1.status, BookingStatus.cancelled);
      expect(b1.cancelledBy, repo.currentUser!.uid);
      expect(b1.refund!.isDue, isTrue);
      expect(b1.refund!.reason, RefundReasons.shopCancelled);
      expect(result.cancelled.map((b) => b.id), ['book_1']);
      expect(result.notices.single.id, 'book_1_cancelled');
      expect(result.notices.single.bookingId, 'book_1');
      // The whole working day is blocked now that book_1 is gone.
      final whole = wholeDayTimeOffRange(repo.getShopById('shop_1')!, repo.getBarberById('barber_1')!, DateTime(2026, 11, 21));
      expect(result.parts.first.startAt, whole!.$1);
      expect(result.parts.first.endAt, whole.$2);
    });

    test('keeping a booking leaves its time out (the day splits around it)', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      final result = await repo.addVacation(
          barberId: 'barber_1', fromDate: DateTime(2026, 11, 21), toDate: DateTime(2026, 11, 21));
      expect(repo.getBookingById('book_1')!.status, BookingStatus.confirmed);
      expect(result.parts, hasLength(2));
      expect(result.parts[0].endAt, DateTime.utc(2026, 11, 21, 8, 15)); // book_1 11:15-12:00 Addis
      expect(result.parts[1].startAt, DateTime.utc(2026, 11, 21, 9));
      // Nothing else is bookable that day.
      final day = DateTime(2026, 11, 21);
      expect(
        availableSlotStarts(
          shop: repo.getShopById('shop_1')!,
          barber: repo.getBarberById('barber_1')!,
          durationMinutes: 15,
          addisDate: day,
          busy: await _busyNow('barber_1', day),
          nowUtc: _now,
        ),
        isEmpty,
      );
    });

    test('permissions and limits', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await expectLater(
          repo.addVacation(barberId: 'barber_2', fromDate: DateTime(2026, 11, 21), toDate: DateTime(2026, 11, 22)),
          throwsA(_code(AppErrorCode.timeOffNotAllowed)));
      repo.switchRole(UserRole.customer);
      await expectLater(
          repo.addVacation(barberId: 'barber_1', fromDate: DateTime(2026, 11, 21), toDate: DateTime(2026, 11, 22)),
          throwsA(_code(AppErrorCode.timeOffNotAllowed)));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(
          repo.addVacation(barberId: 'barber_2', fromDate: DateTime(2026, 11, 21), toDate: DateTime(2027, 3, 1)),
          throwsA(_code(AppErrorCode.vacationTooLong)));
      // barber_1_3 only, on a Monday they never work: nothing to block.
      await expectLater(
          repo.addVacation(barberId: 'barber_1_3', fromDate: DateTime(2026, 11, 23), toDate: DateTime(2026, 11, 23)),
          throwsA(_code(AppErrorCode.vacationNothingToBlock)));
      // An existing single-day time off inside the range is left as it is.
      await repo.addTimeOff(barberId: 'barber_2', startUtc: DateTime.utc(2026, 11, 22, 6), endUtc: DateTime.utc(2026, 11, 22, 7));
      final r = await repo.addVacation(barberId: 'barber_2', fromDate: DateTime(2026, 11, 22), toDate: DateTime(2026, 11, 22));
      expect(r.parts.map((p) => (p.startAt.hour, p.endAt.hour)), [(5, 6), (7, 17)]);
    });
  });

  group('Firestore writes', () {
    test('parts carry the group fields; range lock query; the customer notice shape', () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreDataStore(
        cache: DataCache(),
        firestore: db,
        onChanged: () {},
        onCurrentUserChanged: (_) {},
      );
      final p1 = _part('p1', DateTime.utc(2026, 11, 21, 5), DateTime.utc(2026, 11, 21, 17), group: 'g');
      final p2 = _part('p2', DateTime.utc(2026, 11, 23, 5), DateTime.utc(2026, 11, 23, 6), group: 'g');
      await store.addTimeOff(p1);
      await store.addTimeOff(p2);
      final doc = (await db.doc('barbershops/shop_1/barbers/barber_2/timeOff/p1').get()).data()!;
      expect(doc.keys.toSet(), {'startAt', 'endAt', 'createdBy', 'createdAt', 'groupId', 'groupFrom', 'groupTo'});
      expect(doc['groupFrom'], '2026-11-21');

      final locks = await store.slotLocksBetween('shop_1', 'barber_2', DateTime.utc(2026, 11, 21), DateTime.utc(2026, 11, 24));
      expect(locks, hasLength(48 + 4));
      expect(locks.every((l) => l.isTimeOff), isTrue);
      final day23 = await store.slotLocksBetween('shop_1', 'barber_2', DateTime.utc(2026, 11, 23), DateTime.utc(2026, 11, 24));
      expect(day23.map((l) => l.timeOffId).toSet(), {'p2'});

      loadTestSeed(now: _now);
      final notice = vacationCancelNotice(repo.getBookingById('book_1')!, nowUtc: _now, language: 'en');
      await store.writeVacationCancelNotice('user_cust_1', notice);
      final n = (await db.doc('users/user_cust_1/notifications/book_1_cancelled').get()).data()!;
      expect(n, {
        'title': notice.title,
        'body': notice.body,
        'type': 'cancelled',
        'bookingId': 'book_1',
        'read': false,
        'createdAt': _now.toIso8601String(),
      });

      await store.deleteTimeOff(p2);
      expect(await store.slotLocksBetween('shop_1', 'barber_2', DateTime.utc(2026, 11, 23), DateTime.utc(2026, 11, 24)), isEmpty);
    });
  });

  group('screen', () {
    setUp(() => loadTestSeed(now: _now));
    final en = lookupAppLocalizations(const Locale('en'));

    Widget app(Widget home) => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        );

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('barber adds a vacation (one row) and removes it', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      await tester.pumpWidget(app(BarberScheduleScreen(barber: repo.getBarberById('barber_2')!, clock: () => _now)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-time-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-off-several-days')));
      await tester.pumpAndSettle();
      expect(find.text(en.vacationMaxDays(3, kMaxVacationDays)), findsOneWidget); // 21-23 by default
      await tester.tap(find.byKey(const ValueKey('save-time-off')));
      await tester.pumpAndSettle();
      expect(find.text(en.vacationSaved), findsOneWidget);

      final rows = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('vacation-'));
      expect(rows, findsOneWidget);
      expect(find.textContaining(' • ${en.vacationLabel}'), findsOneWidget);
      // The day's own list does not repeat the vacation part.
      expect(
          find.byWidgetPredicate(
              (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('remove-time-off-')),
          findsNothing);
      expect(find.text(en.timeOffSlotLabel), findsWidgets);

      await tester.tap(find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('remove-vacation-')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-remove-vacation')));
      await tester.pumpAndSettle();
      expect(find.text(en.timeOffRemoved), findsOneWidget);
      expect(find.text(en.timeOffEmpty), findsOneWidget);
    });

    testWidgets('owner sees the bookings inside, paid ones marked, and cancels them', (tester) async {
      bigScreen(tester);
      repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p_book_1');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.pumpWidget(app(BarberScheduleScreen(barber: repo.getBarberById('barber_1')!, clock: () => _now)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-time-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-off-several-days')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-time-off')));
      await tester.pumpAndSettle();

      expect(find.text(en.vacationConflictsTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('vacation-conflict-book_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('vacation-conflict-paid-book_1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vacation-cancel-bookings')));
      await tester.pumpAndSettle();
      expect(find.text(en.vacationSavedCancelled(1)), findsOneWidget);
      expect(repo.getBookingById('book_1')!.status, BookingStatus.cancelled);
      expect(repo.getBookingById('book_1')!.refund!.isDue, isTrue);
    });
  });
}
