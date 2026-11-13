import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Cloud Function that verifies a booking's slot locks
/// (functions/bookings/src/logic/lockIds.ts) must compute the same lock ids
/// as the app. Both test suites read this fixture.
const _fixturePath = 'functions/bookings/test/fixtures/lock_ids.json';

void main() {
  final cases = (jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>)['cases'] as List<dynamic>;

  test('fixture is not empty', () => expect(cases.length, greaterThanOrEqualTo(8)));

  for (final raw in cases.cast<Map<String, dynamic>>()) {
    test('lock ids match the functions port: ${raw['name']}', () {
      final start = DateTime.parse(raw['startAt'] as String);
      final end = DateTime.parse(raw['endAt'] as String);
      final ids = (raw['lockIds'] as List<dynamic>).cast<String>();
      expect(slotLockIdsFor(start, end), ids);

      final booking = Booking(
        id: 'bk',
        shopId: 's1',
        shopName: 'Shop',
        barberId: 'b1',
        barberName: 'Yonas',
        customerId: 'c1',
        customerName: 'Liya',
        customerPhone: '+251911000301',
        serviceId: 'srv',
        serviceName: 'Cut',
        price: 300,
        date: DateTime(start.year, start.month, start.day),
        timeSlot: '',
        status: BookingStatus.confirmed,
        createdAt: start,
        startAt: start,
        endAt: end,
        durationMinutes: end.difference(start).inMinutes,
      );
      final locks = slotLocksForBooking(booking);
      expect(locks.map((l) => l.id), ids);
      expect(locks.map((l) => l.toMap()['expiresAt']).toSet(), {raw['expiresAt']});
    });
  }
}
