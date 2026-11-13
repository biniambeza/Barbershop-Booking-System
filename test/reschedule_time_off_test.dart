import 'dart:io';

import 'package:barbershop_booking/features/barber/screens/barber_schedule_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/booking_policy.dart';
import 'package:barbershop_booking/services/time_off_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

// Seeded book_1: user_cust_1 with barber_1 (shop_1), srv_1_1 (45 min),
// Saturday 21 Nov 11:15-12:00 Addis = 08:15-09:00Z.
final _book1Start = DateTime.utc(2026, 11, 21, 8, 15);

Booking _booking({
  DateTime? start,
  BookingStatus status = BookingStatus.confirmed,
  int rescheduleCount = 0,
  int minutes = 30,
}) {
  final s = start ?? DateTime.utc(2026, 11, 21, 7, 0);
  return Booking(
    id: 'b',
    shopId: 's',
    shopName: 'Shop',
    barberId: 'br',
    barberName: 'Barber',
    customerId: 'c',
    customerName: 'Abebe',
    customerPhone: '+251911234567',
    serviceId: 'sv',
    serviceName: 'Cut',
    price: 300,
    date: DateTime(2026, 11, 21),
    timeSlot: '10:00 AM',
    status: status,
    createdAt: _now,
    startAt: s,
    durationMinutes: minutes,
    rescheduleCount: rescheduleCount,
  );
}

Barbershop _shop({int cutoff = 2, int maxReschedules = 2}) => Barbershop(
      id: 's',
      ownerId: 'o',
      name: 'Shop',
      description: '',
      address: '',
      city: 'Addis Ababa',
      phone: '+251911000000',
      imageUrl: '',
      cancellationCutoffHours: cutoff,
      maxReschedules: maxReschedules,
    );

/// The busy times once the slot-lock stream has delivered too.
Future<List<BusyInterval>> _busyNow(String barberId, DateTime addisDate) async {
  var latest = const <BusyInterval>[];
  final sub = AppRepository.instance.watchBarberBusyTimes('shop_1', barberId, addisDate).listen((v) => latest = v);
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return latest;
}

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  group('policy math', () {
    test('cutoff boundary: exactly the cutoff before the start is still allowed', () {
      final b = _booking(); // starts 07:00Z
      final shop = _shop(cutoff: 2);
      expect(isBeforeCutoff(b, shop, DateTime.utc(2026, 11, 21, 5, 0)), isTrue);
      expect(isBeforeCutoff(b, shop, DateTime.utc(2026, 11, 21, 5, 0, 1)), isFalse);
      expect(() => assertCustomerCanCancel(b, shop, DateTime.utc(2026, 11, 21, 5, 0)), returnsNormally);
      expect(
        () => assertCustomerCanCancel(b, shop, DateTime.utc(2026, 11, 21, 5, 30)),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', AppErrorCode.cancellationCutoffPassed)
            .having((e) => e.args, 'args', [2])),
      );
      // Cutoff 0: changes allowed until the start itself.
      expect(isBeforeCutoff(b, _shop(cutoff: 0), DateTime.utc(2026, 11, 21, 7, 0)), isTrue);
      expect(isBeforeCutoff(b, _shop(cutoff: 0), DateTime.utc(2026, 11, 21, 7, 0, 1)), isFalse);
    });

    test('max reschedules', () {
      final shop = _shop(maxReschedules: 2);
      final now = DateTime.utc(2026, 11, 20, 7, 0);
      expect(rescheduleBlocker(_booking(rescheduleCount: 1), shop, now), isNull);
      expect(reschedulesLeft(_booking(rescheduleCount: 1), shop), 1);
      expect(
        rescheduleBlocker(_booking(rescheduleCount: 2), shop, now)?.code,
        AppErrorCode.rescheduleLimitReached,
      );
      expect(reschedulesLeft(_booking(rescheduleCount: 3), shop), 0);
      expect(rescheduleBlocker(_booking(), _shop(maxReschedules: 0), now)?.code, AppErrorCode.rescheduleLimitReached);
      // The cutoff applies to reschedules too, with its own message.
      expect(
        rescheduleBlocker(_booking(), shop, DateTime.utc(2026, 11, 21, 6, 0))?.code,
        AppErrorCode.rescheduleCutoffPassed,
      );
      expect(
        rescheduleBlocker(_booking(status: BookingStatus.completed), shop, now)?.code,
        AppErrorCode.bookingNotChangeable,
      );
    });

    test('no-show only from the start time, for pending/confirmed bookings', () {
      final b = _booking();
      expect(canMarkNoShow(b, DateTime.utc(2026, 11, 21, 6, 59)), isFalse);
      expect(canMarkNoShow(b, DateTime.utc(2026, 11, 21, 7, 0)), isTrue);
      expect(canMarkNoShow(_booking(status: BookingStatus.inProgress), DateTime.utc(2026, 11, 22)), isFalse);
      expect(
        () => assertCanMarkNoShow(b, DateTime.utc(2026, 11, 21, 6)),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.noShowTooEarly)),
      );
    });

    test('rescheduledBooking: new interval, Addis date and slot, count + 1', () {
      final moved = rescheduledBooking(_booking(rescheduleCount: 1), DateTime.utc(2026, 11, 22, 11, 45), _now);
      expect(moved.startAt, DateTime.utc(2026, 11, 22, 11, 45));
      expect(moved.endAt, DateTime.utc(2026, 11, 22, 12, 15));
      expect(moved.date, DateTime(2026, 11, 22));
      expect(moved.timeSlot, '02:45 PM');
      expect(moved.rescheduleCount, 2);
      expect(moved.rescheduledAt, _now);
      expect(moved.rescheduleFields().keys.toSet(),
          {'startAt', 'endAt', 'date', 'timeSlot', 'rescheduleCount', 'rescheduledAt'});
      // A new booking's document has no reschedule fields (19 keys).
      expect(_booking().toMap().containsKey('rescheduleCount'), isFalse);
      expect(Booking.fromMap({..._booking().toMap(), 'rescheduleCount': 2}, 'x').rescheduleCount, 2);
    });

    test('policy values are validated and parsed with defaults', () {
      expect(() => validatePolicy(cancellationCutoffHours: 73, maxReschedules: 1), throwsFormatException);
      expect(() => validatePolicy(cancellationCutoffHours: 2, maxReschedules: 6), throwsFormatException);
      final parsed = Barbershop.fromMap({'name': 'x', 'cancellationCutoffHours': 500}, 's');
      expect(parsed.cancellationCutoffHours, kDefaultCancellationCutoffHours);
      expect(parsed.maxReschedules, kDefaultMaxReschedules);
      expect(_shop(cutoff: 6, maxReschedules: 1).toPolicyMap(), {'cancellationCutoffHours': 6, 'maxReschedules': 1});
    });
  });

  group('reschedule (local transaction)', () {
    setUp(() {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.customer); // user_cust_1
    });

    test('moves the booking, frees the old blocks and takes the new ones', () async {
      final newStart = DateTime.utc(2026, 11, 21, 10, 0); // 13:00 Addis
      final moved = await repo.rescheduleBooking('book_1', newStart);
      final stored = repo.getBookingById('book_1')!;
      expect(stored.startAt, newStart);
      expect(stored.endAt, newStart.add(const Duration(minutes: 45)));
      expect(stored.timeSlot, '01:00 PM');
      expect(stored.rescheduleCount, 1);
      expect(stored.rescheduledAt, _now);
      expect(moved.rescheduleCount, 1);

      // The old time is free for someone else; the new one is not.
      repo.switchRole(UserRole.customer);
      final barber = repo.getBarberById('barber_1')!;
      final shop = repo.getShopById('shop_1')!;
      final busy = busyIntervalsFromBookings(repo.getAllBookings(), 'barber_1');
      final free = availableSlotStarts(
          shop: shop, barber: barber, durationMinutes: 45, addisDate: DateTime(2026, 11, 21), busy: busy, nowUtc: _now);
      expect(free, contains(_book1Start));
      expect(free, isNot(contains(newStart)));
    });

    test('may move into its own blocks (overlapping the old interval)', () async {
      await repo.rescheduleBooking('book_1', _book1Start.add(const Duration(minutes: 15)));
      expect(repo.getBookingById('book_1')!.startAt, DateTime.utc(2026, 11, 21, 8, 30));
    });

    test('a taken slot throws SlotTakenException and changes nothing', () async {
      // book_2 holds barber_1 today 14:15-14:45 Addis.
      await expectLater(repo.rescheduleBooking('book_1', DateTime.utc(2026, 11, 20, 11, 0)), throwsA(isA<SlotTakenException>()));
      final stored = repo.getBookingById('book_1')!;
      expect(stored.startAt, _book1Start);
      expect(stored.rescheduleCount, 0);
    });

    test('limit, cutoff and same time are enforced with typed errors', () async {
      await repo.rescheduleBooking('book_1', DateTime.utc(2026, 11, 21, 10, 0));
      await repo.rescheduleBooking('book_1', DateTime.utc(2026, 11, 21, 11, 0));
      await expectLater(
        repo.rescheduleBooking('book_1', DateTime.utc(2026, 11, 21, 12, 0)),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.rescheduleLimitReached)),
      );

      loadTestSeed(now: _now);
      repo.switchRole(UserRole.customer);
      await expectLater(
        repo.rescheduleBooking('book_1', _book1Start),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.rescheduleSameTime)),
      );
      repo.debugClock = () => _book1Start.subtract(const Duration(hours: 1));
      await expectLater(
        repo.rescheduleBooking('book_1', DateTime.utc(2026, 11, 21, 12, 0)),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.rescheduleCutoffPassed)),
      );
    });

    test('only the booking customer can reschedule', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(
        repo.rescheduleBooking('book_1', DateTime.utc(2026, 11, 21, 10, 0)),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.bookingNotChangeable)),
      );
    });
  });

  group('cancellation policy and no-show', () {
    setUp(() => loadTestSeed(now: _now));

    test('customers cannot cancel inside the cutoff; the owner still can', () async {
      repo.switchRole(UserRole.customer);
      repo.debugClock = () => _book1Start.subtract(const Duration(minutes: 90));
      await expectLater(
        repo.updateBookingStatus('book_1', BookingStatus.cancelled),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', AppErrorCode.cancellationCutoffPassed)
            .having((e) => e.args, 'args', [2])),
      );
      expect(repo.getBookingById('book_1')!.status, BookingStatus.confirmed);

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      expect(repo.getBookingById('book_1')!.status, BookingStatus.cancelled);
    });

    test('owner policy edits are validated and stored', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateShopPolicy('shop_1', cancellationCutoffHours: 24, maxReschedules: 0);
      expect(repo.getShopById('shop_1')!.cancellationCutoffHours, 24);
      expect(repo.getShopById('shop_1')!.maxReschedules, 0);
      await expectLater(repo.updateShopPolicy('shop_1', cancellationCutoffHours: -1, maxReschedules: 0),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.policyCutoffInvalid)));
    });

    test('no-show only after the start; the booking keeps its blocks', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await expectLater(
        repo.markNoShow('book_1'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.noShowTooEarly)),
      );
      repo.debugClock = () => _book1Start.add(const Duration(minutes: 10));
      await repo.markNoShow('book_1');
      final b = repo.getBookingById('book_1')!;
      expect(b.status, BookingStatus.noShow);
      expect(occupiesSlot(b), isTrue);
      expect(busyIntervalsFromBookings(repo.getAllBookings(), 'barber_1').any((i) => i.start == _book1Start), isTrue);
    });
  });

  group('time off', () {
    setUp(() => loadTestSeed(now: _now));

    TimeOff entry(DateTime start, DateTime end) => TimeOff(
          id: 'off1',
          shopId: 'shop_1',
          barberId: 'barber_2',
          startAt: start,
          endAt: end,
          createdBy: 'u',
          createdAt: _now,
        );

    test('one lock per 15-minute block, shaped {timeOffId, startAt, expiresAt}', () {
      // 13:00-14:00 Addis on 21 Nov.
      final t = entry(DateTime.utc(2026, 11, 21, 10), DateTime.utc(2026, 11, 21, 11));
      final locks = slotLocksForTimeOff(t);
      expect(locks.map((l) => l.id), ['20261121-1300', '20261121-1315', '20261121-1330', '20261121-1345']);
      expect(locks.first.toMap(), {
        'timeOffId': 'off1',
        'startAt': '2026-11-21T10:00:00.000Z',
        'expiresAt': '2026-11-22T11:00:00.000Z',
      });
      final parsed = SlotLock.fromMap(locks.first.toMap(), locks.first.id);
      expect(parsed.isTimeOff, isTrue);
      expect(parsed.bookingId, '');
      expect(parsed.interval, BusyInterval(DateTime.utc(2026, 11, 21, 10), DateTime.utc(2026, 11, 21, 10, 15)));
      expect(t.toMap().keys.toSet(), {'startAt', 'endAt', 'createdBy', 'createdAt'});
    });

    test('validation: grid, one day, future, note length', () {
      void bad(DateTime s, DateTime e, AppErrorCode code, {String? reason}) => expect(
            () => validateTimeOff(startUtc: s, endUtc: e, reason: reason, nowUtc: _now),
            throwsA(isA<AppException>().having((x) => x.code, 'code', code)),
          );
      final day = DateTime.utc(2026, 11, 21, 6); // 09:00 Addis
      expect(() => validateTimeOff(startUtc: day, endUtc: day.add(const Duration(hours: 2)), nowUtc: _now), returnsNormally);
      bad(day.add(const Duration(minutes: 5)), day.add(const Duration(hours: 1)), AppErrorCode.timeOffInvalidRange);
      bad(day, day, AppErrorCode.timeOffInvalidRange);
      // Ends after Addis midnight: two days.
      bad(day, DateTime.utc(2026, 11, 21, 21, 15), AppErrorCode.timeOffInvalidRange);
      // Up to midnight is fine.
      expect(() => validateTimeOff(startUtc: day, endUtc: DateTime.utc(2026, 11, 21, 21), nowUtc: _now), returnsNormally);
      bad(DateTime.utc(2026, 11, 19, 6), DateTime.utc(2026, 11, 19, 8), AppErrorCode.timeOffInPast);
      bad(day, day.add(const Duration(hours: 1)), AppErrorCode.timeOffReasonTooLong, reason: 'x' * 201);
    });

    test('whole day = the barber\'s working hours', () {
      final shop = repo.getShopById('shop_1')!; // 08:00-20:00
      final range = wholeDayTimeOffRange(shop, repo.getBarberById('barber_2')!, DateTime(2026, 11, 22));
      expect(range, (DateTime.utc(2026, 11, 22, 5), DateTime.utc(2026, 11, 22, 17)));
      // barber_1_3 does not work on Mondays.
      expect(wholeDayTimeOffRange(shop, repo.getBarberById('barber_1_3')!, DateTime(2026, 11, 23)), isNull);
    });

    test('availability excludes time off; bookings cannot take it; conflicts are reported', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      final start = DateTime.utc(2026, 11, 21, 10); // 13:00 Addis
      final added = await repo.addTimeOff(
          barberId: 'barber_2', startUtc: start, endUtc: start.add(const Duration(hours: 2)), reason: ' Family ');
      expect(added.reason, 'Family');
      expect(added.createdBy, repo.currentUser!.uid);

      final busy = await _busyNow('barber_2', DateTime(2026, 11, 21));
      final free = availableSlotStarts(
        shop: repo.getShopById('shop_1')!,
        barber: repo.getBarberById('barber_2')!,
        durationMinutes: 30,
        addisDate: DateTime(2026, 11, 21),
        busy: busy,
        nowUtc: _now,
      );
      expect(free, contains(DateTime.utc(2026, 11, 21, 9, 30))); // 12:30-13:00 still fits
      expect(free, isNot(contains(DateTime.utc(2026, 11, 21, 9, 45)))); // would run into 13:00
      expect(free, isNot(contains(start.add(const Duration(minutes: 90)))));
      expect(free, contains(start.add(const Duration(hours: 2))));

      // A customer booking into it is rejected like a taken slot.
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
          date: DateTime(2026, 11, 21),
          timeSlot: '01:30 PM',
          startAt: start.add(const Duration(minutes: 30)),
        ),
        throwsA(isA<SlotTakenException>()),
      );

      // Time off over an existing booking (book_4: barber_2 today 16:30) fails.
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(
        repo.addTimeOff(
            barberId: 'barber_2', startUtc: DateTime.utc(2026, 11, 20, 13), endUtc: DateTime.utc(2026, 11, 20, 14)),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.timeOffConflict)),
      );

      // Removing it frees the time again.
      await repo.deleteTimeOff(added);
      final after = await _busyNow('barber_2', DateTime(2026, 11, 21));
      expect(after.where((i) => !i.start.isBefore(start) && i.start.isBefore(start.add(const Duration(hours: 2)))), isEmpty);
    });

    test('a barber manages only their own time off; customers none', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(repo.canManageTimeOffFor(repo.getBarberById('barber_2')!), isFalse);
      await expectLater(
        repo.addTimeOff(
            barberId: 'barber_2', startUtc: DateTime.utc(2026, 11, 22, 6), endUtc: DateTime.utc(2026, 11, 22, 7)),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.timeOffNotAllowed)),
      );
      repo.switchRole(UserRole.customer);
      expect(repo.canManageTimeOffFor(repo.getBarberById('barber_1')!), isFalse);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(repo.canManageTimeOffFor(repo.getBarberById('barber_2')!), isTrue);
    });

    test('demo seed time off (barber_2 tomorrow 13:00-15:00) blocks those slots', () async {
      final seeded = timeOffFromSeedJson(readSeedJson(), now: _now);
      expect(seeded, hasLength(1));
      expect(seeded.single.barberId, 'barber_2');
      expect(seeded.single.startAt, DateTime.utc(2026, 11, 21, 10));
      expect(seeded.single.endAt, DateTime.utc(2026, 11, 21, 12));
      repo.loadDemoTimeOff(seeded);
      final busy = await _busyNow('barber_2', DateTime(2026, 11, 21));
      // book_4 (today) plus the eight 15-minute time-off locks.
      expect(busy.where((i) => i.start.day == 21), hasLength(8));
      // Policy fields come from the seed.
      expect(repo.getShopById('shop_2')!.cancellationCutoffHours, 24);
      expect(repo.getShopById('shop_2')!.maxReschedules, 1);
    });
  });

  group('screens', () {
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

    testWidgets('My Appointments -> Reschedule -> pick a time moves the booking', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(app(CustomerBookingsScreen(clock: () => _now)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('policy-note-book_1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reschedule-booking-book_1')));
      await tester.pumpAndSettle();

      expect(find.byType(BookingFlowScreen), findsOneWidget);
      expect(find.text(en.rescheduleTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('reschedule-summary')), findsOneWidget);
      // Opens on the booking's day; its own time is not offered.
      expect(find.byKey(const ValueKey('slot-11:15 AM')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('slot-11:30 AM')));
      await tester.pump();
      expect(find.text(en.rescheduleConfirm), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-booking')));
      await tester.pumpAndSettle();

      expect(find.byType(BookingFlowScreen), findsNothing);
      final b = repo.getBookingById('book_1')!;
      expect(b.startAt, DateTime.utc(2026, 11, 21, 8, 30));
      expect(b.rescheduleCount, 1);
      expect(find.byKey(const ValueKey('rescheduled-badge-book_1')), findsOneWidget);
    });

    testWidgets('inside the cutoff, cancel and reschedule explain the policy', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      final late = _book1Start.subtract(const Duration(hours: 1));
      repo.debugClock = () => late;
      await tester.pumpWidget(app(CustomerBookingsScreen(clock: () => late)));
      await tester.pumpAndSettle();

      expect(find.text(en.rescheduleCallShop), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-booking-book_1')));
      await tester.pumpAndSettle();
      expect(find.text(en.rescheduleErrCancelCutoff(2)), findsOneWidget);
      expect(repo.getBookingById('book_1')!.status, BookingStatus.confirmed);

      await tester.tap(find.byKey(const ValueKey('reschedule-booking-book_1')));
      await tester.pumpAndSettle();
      expect(find.byType(BookingFlowScreen), findsNothing);
      expect(find.text(en.rescheduleErrCutoff(2)), findsOneWidget);
    });

    testWidgets('barber adds and removes time off on the schedule', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      await tester.pumpWidget(app(BarberScheduleScreen(barber: repo.getBarberById('barber_2')!, clock: () => _now)));
      await tester.pumpAndSettle();

      expect(find.text(en.timeOffEmpty), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-time-off')));
      await tester.pumpAndSettle();
      // Whole day today overlaps book_4 (16:30): a localized conflict.
      await tester.tap(find.byKey(const ValueKey('save-time-off')));
      await tester.pumpAndSettle();
      expect(find.text(en.timeOffErrConflict), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // The add dialog stays open after an error; close it.
      await tester.tap(find.widgetWithText(TextButton, en.cancel));
      await tester.pumpAndSettle();

      // Tomorrow (Sat 21) has no bookings for barber_2: the whole day works.
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-time-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-time-off')));
      await tester.pumpAndSettle();
      expect(find.text(en.timeOffSaved), findsOneWidget);
      expect(find.text(en.timeOffSlotLabel), findsWidgets);

      final removeButtons = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('remove-time-off-'));
      expect(removeButtons, findsOneWidget);
      await tester.tap(removeButtons);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-remove-time-off')));
      await tester.pumpAndSettle();
      expect(find.text(en.timeOffRemoved), findsOneWidget);
      expect(find.text(en.timeOffEmpty), findsOneWidget);
    });
  });
}
