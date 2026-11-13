import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 07:00 UTC = 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);
final _friday = DateTime(2026, 11, 20);
final _saturday = DateTime(2026, 11, 21);
final _sunday = DateTime(2026, 11, 22);

Barbershop _shop({int open = 9, int close = 18, List<int> days = const [1, 2, 3, 4, 5, 6], SubscriptionStatus status = SubscriptionStatus.active}) =>
    Barbershop(
      id: 's1',
      ownerId: 'o1',
      name: 'Test Shop',
      description: '',
      address: 'Bole Road',
      city: 'Addis Ababa',
      phone: '+251911000000',
      imageUrl: '',
      openingHour: open,
      closingHour: close,
      workingDays: days,
      subscriptionStatus: status,
    );

Barber _barber({bool available = true, List<int>? days, int? start, int? end}) => Barber(
      id: 'b1',
      shopId: 's1',
      name: 'Yonas',
      title: 'Barber',
      isAvailable: available,
      workingDays: days,
      startHour: start,
      endHour: end,
    );

/// Addis wall-clock time on [day] as UTC.
DateTime _at(DateTime day, int h, [int m = 0]) => DateTime.utc(day.year, day.month, day.day, h, m).subtract(const Duration(hours: 3));

Booking _booking(String id, DateTime startUtc, int minutes, {String barberId = 'b1', BookingStatus status = BookingStatus.confirmed, String customerId = 'c1'}) =>
    Booking(
      id: id,
      shopId: 's1',
      shopName: 'Test Shop',
      barberId: barberId,
      barberName: 'Yonas',
      customerId: customerId,
      customerName: 'Liya',
      customerPhone: '+251911000301',
      serviceId: 'srv',
      serviceName: 'Cut',
      price: 300,
      date: DateTime(2026, 11, 20),
      timeSlot: '',
      status: status,
      createdAt: _now,
      startAt: startUtc,
      endAt: startUtc.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
    );

void main() {
  group('slot lock ids', () {
    test('are Addis wall-clock 15-minute blocks', () {
      expect(slotLockId(_at(_friday, 14, 30)), '20261120-1430');
      expect(slotLockIdsFor(_at(_friday, 14, 30), _at(_friday, 15, 15)), ['20261120-1430', '20261120-1445', '20261120-1500']);
      expect(slotLockStartUtc('20261120-1430'), _at(_friday, 14, 30));
      expect(slotLockStartUtc('nonsense'), isNull);
    });

    test('off-grid appointments lock every block they touch', () {
      expect(slotLockIdsFor(_at(_friday, 9, 10), _at(_friday, 9, 40)), ['20261120-0900', '20261120-0915', '20261120-0930']);
    });

    test('a booking crossing Addis midnight uses the next day id', () {
      expect(slotLockIdsFor(_at(_friday, 23, 45), _at(_friday, 24, 15)), ['20261120-2345', '20261121-0000']);
    });

    test('slotLocksForBooking carries booking and customer ids', () {
      final locks = slotLocksForBooking(_booking('bk', _at(_friday, 11), 30));
      expect(locks.map((l) => l.id), ['20261120-1100', '20261120-1115']);
      expect(locks.first.toMap(), {'bookingId': 'bk', 'customerId': 'c1', 'startAt': '2026-11-20T08:00:00.000Z'});
      final back = SlotLock.fromMap(locks.last.toMap(), locks.last.id);
      expect(back.startAt, _at(_friday, 11, 15));
      expect(back.interval.end, _at(_friday, 11, 30));
    });
  });

  group('availableSlotStarts', () {
    List<DateTime> slots({
      Barbershop? shop,
      Barber? barber,
      int minutes = 30,
      DateTime? day,
      List<BusyInterval> busy = const [],
      DateTime? now,
    }) =>
        availableSlotStarts(
          shop: shop ?? _shop(),
          barber: barber ?? _barber(),
          durationMinutes: minutes,
          addisDate: day ?? _saturday,
          busy: busy,
          nowUtc: now ?? _now,
        );

    test('15-minute grid from opening until the service no longer fits', () {
      final s = slots(minutes: 45);
      expect(s.first, _at(_saturday, 9));
      expect(s[1], _at(_saturday, 9, 15));
      // Closing 18:00: the last 45-minute appointment starts at 17:15.
      expect(s.last, _at(_saturday, 17, 15));
      expect(s.length, (8 * 60 + 15) ~/ 15 + 1);
    });

    test('a service longer than the working day has no slots', () {
      expect(slots(minutes: 10 * 60), isEmpty);
    });

    test('no slots in the past or inside the lead time', () {
      // Today in Addis is Friday, 10:00; the earliest slot is 10:30.
      final s = slots(day: _friday);
      expect(s.first, _at(_friday, 10, 30));
      expect(s.every((t) => !t.isBefore(_now.add(kBookingLeadTime))), true);
      // Late in the day nothing is left.
      expect(slots(day: _friday, now: _at(_friday, 17, 45)), isEmpty);
    });

    test('yesterday and beyond the booking window are not bookable', () {
      expect(slots(day: DateTime(2026, 11, 19)), isEmpty);
      expect(slots(day: DateTime(2026, 12, 19)), isNotEmpty); // day 29
      expect(slots(day: DateTime(2026, 12, 20)), isEmpty); // day 30
    });

    test('existing bookings block overlapping starts only', () {
      final busy = busyIntervalsFromBookings([_booking('x', _at(_saturday, 11), 60)], 'b1');
      final s = slots(minutes: 30, busy: busy);
      expect(s, contains(_at(_saturday, 10, 30))); // ends exactly at 11:00
      expect(s, isNot(contains(_at(_saturday, 10, 45))));
      expect(s, isNot(contains(_at(_saturday, 11))));
      expect(s, isNot(contains(_at(_saturday, 11, 45))));
      expect(s, contains(_at(_saturday, 12))); // starts exactly at the end
    });

    test('cancelled bookings and other barbers do not block', () {
      final busy = busyIntervalsFromBookings([
        _booking('x', _at(_saturday, 11), 60, status: BookingStatus.cancelled),
        _booking('y', _at(_saturday, 11), 60, barberId: 'b2'),
      ], 'b1');
      expect(busy, isEmpty);
      expect(slots(busy: busy), contains(_at(_saturday, 11)));
    });

    test('off-grid bookings block their whole lock blocks', () {
      final busy = busyIntervalsFromBookings([_booking('x', _at(_saturday, 11, 5), 20)], 'b1');
      expect(busy.single, BusyInterval(_at(_saturday, 11), _at(_saturday, 11, 30)));
      final s = slots(minutes: 15, busy: busy);
      expect(s, contains(_at(_saturday, 10, 45)));
      expect(s, isNot(contains(_at(_saturday, 11, 15))));
      expect(s, contains(_at(_saturday, 11, 30)));
    });

    test('non-working days have no slots', () {
      expect(slots(day: _sunday), isEmpty);
      expect(isBookableDate(shop: _shop(), barber: _barber(), addisDate: _sunday, nowUtc: _now), false);
      // The barber's own days are limited to the shop's.
      final barber = _barber(days: [6, 7]);
      expect(isBookableDate(shop: _shop(), barber: barber, addisDate: _saturday, nowUtc: _now), true);
      expect(isBookableDate(shop: _shop(), barber: barber, addisDate: _sunday, nowUtc: _now), false);
      expect(slots(barber: _barber(days: [1, 2]), day: _saturday), isEmpty);
    });

    test("barber hours narrow the shop's hours", () {
      final s = slots(barber: _barber(start: 12, end: 22), minutes: 60);
      expect(s.first, _at(_saturday, 12));
      expect(s.last, _at(_saturday, 17)); // shop closes at 18:00
      final early = slots(barber: _barber(start: 6, end: 11), minutes: 60);
      expect(early.first, _at(_saturday, 9));
      expect(early.last, _at(_saturday, 10));
    });

    test('unavailable barbers and suspended shops have no slots', () {
      expect(slots(barber: _barber(available: false)), isEmpty);
      expect(slots(shop: _shop(status: SubscriptionStatus.suspended)), isEmpty);
    });

    test('a shop open until midnight offers late slots', () {
      final s = slots(shop: _shop(open: 18, close: 24), minutes: 30);
      expect(s.last, _at(_saturday, 23, 30));
    });

    test('isSlotAvailable matches the generator', () {
      expect(isSlotAvailable(shop: _shop(), barber: _barber(), durationMinutes: 30, startUtc: _at(_saturday, 9), nowUtc: _now), true);
      expect(isSlotAvailable(shop: _shop(), barber: _barber(), durationMinutes: 30, startUtc: _at(_saturday, 9, 5), nowUtc: _now), false);
    });

    test('upcomingAddisDates starts on the Addis calendar day', () {
      // 22:30 UTC on the 19th is already the 20th in Addis.
      final dates = upcomingAddisDates(nowUtc: DateTime.utc(2026, 11, 19, 22, 30), count: 3);
      expect(dates, [DateTime(2026, 11, 20), DateTime(2026, 11, 21), DateTime(2026, 11, 22)]);
    });
  });

  group('local double-booking prevention', () {
    final repo = AppRepository.instance;
    setUp(() => loadTestSeed(now: _now));

    Future<Booking> book({required DateTime startUtc, String serviceId = 'srv_1_1', String barberId = 'barber_1'}) {
      final service = repo.getServiceById(serviceId)!;
      final barber = repo.getBarberById(barberId)!;
      return repo.createBooking(
        shopId: 'shop_1',
        shopName: 'Crown Cuts Bole',
        barberId: barber.id,
        barberName: barber.name,
        serviceId: service.id,
        serviceName: service.name,
        price: service.price,
        date: DateTime(2026, 11, 25),
        timeSlot: '',
        startAt: startUtc,
      );
    }

    test('an overlapping booking for the same barber is rejected', () async {
      repo.switchRole(UserRole.customer);
      final day = DateTime(2026, 11, 25);
      final first = await book(startUtc: _at(day, 10));
      expect(repo.getBookingById(first.id), isNotNull);

      await expectLater(book(startUtc: _at(day, 10)), throwsA(isA<SlotTakenException>()));
      await expectLater(book(startUtc: _at(day, 9, 45), serviceId: 'srv_1_3'), throwsA(isA<SlotTakenException>()));
      final count = repo.getBookingsForBarber('barber_1').length;

      // Back-to-back is fine; so is another barber at the same time.
      await book(startUtc: first.endAt);
      await book(startUtc: _at(day, 10), barberId: 'barber_2');
      expect(repo.getBookingsForBarber('barber_1').length, count + 1);
    });

    test('a seeded booking blocks its slot and cancelling frees it', () async {
      final seeded = repo.getBookingById('book_2')!;
      repo.switchRole(UserRole.customer);
      final service = repo.getServiceById(seeded.serviceId)!;
      Future<Booking> again() => repo.createBooking(
            shopId: seeded.shopId,
            shopName: seeded.shopName,
            barberId: seeded.barberId,
            barberName: seeded.barberName,
            serviceId: service.id,
            serviceName: service.name,
            price: service.price,
            date: seeded.date,
            timeSlot: seeded.timeSlot,
          );
      await expectLater(again(), throwsA(isA<SlotTakenException>()));
      await repo.updateBookingStatus('book_2', BookingStatus.cancelled);
      final rebooked = await again();
      expect(rebooked.startAt, seeded.startAt);
    });

    test('unavailable barbers cannot be booked', () async {
      repo.switchRole(UserRole.customer);
      await repo.updateBarberAvailability('barber_1', false);
      await expectLater(book(startUtc: _at(DateTime(2026, 11, 25), 10)), throwsStateError);
    });

    test('watchBarberBusyTimes emits the barber bookings and updates live', () async {
      repo.switchRole(UserRole.customer);
      final day = DateTime(2026, 11, 25);
      final emissions = <List<BusyInterval>>[];
      final sub = repo.watchBarberBusyTimes('shop_1', 'barber_1', day).listen(emissions.add);
      await pumpEventQueue();
      final before = emissions.last.length;
      final added = await book(startUtc: _at(day, 15));
      await pumpEventQueue();
      expect(emissions.last.length, before + 1);
      expect(emissions.last, contains(BusyInterval(added.startAt, added.endAt)));
      await sub.cancel();
    });
  });

  group('Firestore transaction', () {
    late FakeFirebaseFirestore db;
    late FirestoreDataStore store;

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestoreDataStore(cache: DataCache(), firestore: db, onChanged: () {}, onCurrentUserChanged: (_) {});
    });

    Future<List<String>> lockIds() async =>
        (await db.collection('barbershops').doc('s1').collection('barbers').doc('b1').collection('slotLocks').get())
            .docs
            .map((d) => d.id)
            .toList()
          ..sort();

    test('creates the booking and its locks together, and rejects overlaps', () async {
      final first = _booking('bk1', _at(_saturday, 11), 45);
      await store.createBooking(first);
      expect((await db.collection('bookings').doc('bk1').get()).exists, true);
      expect(await lockIds(), ['20261121-1100', '20261121-1115', '20261121-1130']);
      final lock = await db.doc('barbershops/s1/barbers/b1/slotLocks/20261121-1115').get();
      expect(lock.data(), {'bookingId': 'bk1', 'customerId': 'c1', 'startAt': '2026-11-21T08:15:00.000Z'});

      final clash = _booking('bk2', _at(_saturday, 11, 30), 30, customerId: 'c2');
      await expectLater(store.createBooking(clash), throwsA(isA<SlotTakenException>()));
      expect((await db.collection('bookings').doc('bk2').get()).exists, false);
      expect(await lockIds(), hasLength(3));

      // Another barber is unaffected.
      await store.createBooking(_booking('bk3', _at(_saturday, 11), 45, barberId: 'b2'));
      expect((await db.collection('bookings').doc('bk3').get()).exists, true);
    });

    test('cancelling deletes only that booking\'s locks; the slot can be booked again', () async {
      final first = _booking('bk1', _at(_saturday, 11), 30);
      await store.createBooking(first);
      await store.createBooking(_booking('bk2', _at(_saturday, 11, 30), 15));
      // A legacy lock-less booking cancels cleanly too.
      await db.collection('bookings').doc('legacy').set(_booking('legacy', _at(_saturday, 16), 30).toMap());

      await store.updateBookingStatus(first, BookingStatus.cancelled, cancelledBy: 'c1');
      final cancelled = (await db.collection('bookings').doc('bk1').get()).data()!;
      expect(cancelled['status'], 'cancelled');
      expect(cancelled['cancelledBy'], 'c1');
      expect(await lockIds(), ['20261121-1130']);

      await store.updateBookingStatus(_booking('legacy', _at(_saturday, 16), 30), BookingStatus.cancelled);
      expect((await db.collection('bookings').doc('legacy').get()).data()!['status'], 'cancelled');

      await store.createBooking(_booking('bk4', _at(_saturday, 11), 30, customerId: 'c2'));
      expect(await lockIds(), ['20261121-1100', '20261121-1115', '20261121-1130']);

      // Non-cancel status changes keep the locks.
      await store.updateBookingStatus(_booking('bk4', _at(_saturday, 11), 30), BookingStatus.completed);
      expect(await lockIds(), hasLength(3));
    });

    test('watchSlotLocks streams one Addis day', () async {
      await store.createBooking(_booking('bk1', _at(_saturday, 9), 30));
      await store.createBooking(_booking('bk2', _at(_sunday, 9), 15));
      // 01:00 Addis on Saturday is 22:00 UTC on Friday.
      await store.createBooking(_booking('bk3', _at(_saturday, 1), 15));
      final locks = await store.watchSlotLocks('s1', 'b1', _saturday).first;
      expect(locks.map((l) => l.id).toList()..sort(), ['20261121-0100', '20261121-0900', '20261121-0915']);
    });
  });
}
