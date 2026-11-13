import 'dart:io';

import 'package:barbershop_booking/features/barber/screens/barber_schedule_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  setUp(() => loadTestSeed(now: _now));

  final repo = AppRepository.instance;

  Future<void> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shop = repo.getShopById('shop_1')!;
    await tester.pumpWidget(MaterialApp(
      home: BookingFlowScreen(
        shop: shop,
        initialService: repo.getServiceById('srv_1_1')!,
        initialBarber: repo.getBarberById('barber_1')!,
        clock: () => _now,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows only real free slots and books one', (tester) async {
    repo.switchRole(UserRole.customer);
    await pumpFlow(tester);

    expect(find.text('Today'), findsOneWidget);
    // 10:00 now + 30 min lead time: 10:15 is gone, 10:30 is the first slot.
    expect(find.byKey(const ValueKey('slot-10:15 AM')), findsNothing);
    expect(find.byKey(const ValueKey('slot-10:30 AM')), findsOneWidget);
    // Seeded book_2 holds barber_1 from 14:15 to 14:45 today.
    expect(find.byKey(const ValueKey('slot-02:15 PM')), findsNothing);
    expect(find.byKey(const ValueKey('slot-01:30 PM')), findsOneWidget);
    expect(find.byKey(const ValueKey('slot-02:45 PM')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('slot-11:00 AM')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.pumpAndSettle();

    expect(find.text('Booking Confirmed!'), findsOneWidget);
    final mine = repo.getCustomerBookings(repo.currentUser!.uid).firstWhere((b) => b.startAt == DateTime.utc(2026, 11, 20, 8, 0));
    expect(mine.startAt, DateTime.utc(2026, 11, 20, 8, 0));
    expect(mine.timeSlot, '11:00 AM');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a slot booked by someone else disappears live', (tester) async {
    repo.switchRole(UserRole.customer);
    await pumpFlow(tester);
    await tester.tap(find.byKey(const ValueKey('slot-04:00 PM')));
    await tester.pump();

    // Another customer books 16:00 for the same barber.
    await repo.createBooking(
      shopId: 'shop_1',
      shopName: 'Crown Cuts Bole',
      barberId: 'barber_1',
      barberName: 'Yonas Tadesse',
      serviceId: 'srv_1_1',
      serviceName: 'x',
      price: 450,
      date: DateTime(2026, 11, 20),
      timeSlot: '04:00 PM',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('slot-04:00 PM')), findsNothing);
    expect(find.text('Select a time'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('barber schedule shows bookings at their real time', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.switchRole(UserRole.barber);
    final barber = repo.getBarberForCurrentUser()!;
    await tester.pumpWidget(MaterialApp(home: BarberScheduleScreen(barber: barber, clock: () => _now)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Working hours'), findsOneWidget);
    final today = repo
        .getBookingsForBarber(barber.id)
        .where((b) => b.startAt.isAfter(_now) && b.startAt.isBefore(_now.add(const Duration(hours: 14))))
        .toList();
    for (final b in today) {
      expect(find.text(b.customerName), findsWidgets);
    }
  });
}
