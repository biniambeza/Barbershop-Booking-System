import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/barber/screens/barber_schedule_screen.dart';
import 'package:barbershop_booking/features/customer/screens/find_barbers_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_main_nav.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
    loadTestSeed();
  });
  test('AppRepository supports all 4 distinct roles with dedicated personas', () {
    final repo = AppRepository.instance;

    // 1. Switch to Admin
    repo.switchRole(UserRole.admin);
    expect(repo.currentUser?.role, UserRole.admin);
    expect(repo.currentUser?.phone, '+251911000001');

    // 2. Switch to Barbershop Owner
    repo.switchRole(UserRole.barbershopOwner);
    expect(repo.currentUser?.role, UserRole.barbershopOwner);
    expect(repo.currentUser?.shopId, isNotNull);

    // 3. Switch to Staff Barber
    repo.switchRole(UserRole.barber);
    expect(repo.currentUser?.role, UserRole.barber);
    expect(repo.currentUser?.barberId, isNotNull);

    // 4. Switch to Customer
    repo.switchRole(UserRole.customer);
    expect(repo.currentUser?.role, UserRole.customer);
    expect(repo.currentUser?.phone, '+251911000301');
  });

  test('Barber can toggle duty availability and manage appointment lifecycle', () {
    final repo = AppRepository.instance;
    repo.switchRole(UserRole.barber);

    final barber = repo.getBarberForCurrentUser();
    expect(barber, isNotNull);
    final barberId = barber!.id;

    // Toggle duty availability
    repo.updateBarberAvailability(barberId, false);
    expect(repo.getBarberById(barberId)?.isAvailable, false);
    repo.updateBarberAvailability(barberId, true);
    expect(repo.getBarberById(barberId)?.isAvailable, true);

    // Get assigned bookings
    final bookings = repo.getBookingsForBarber(barberId);
    expect(bookings.isNotEmpty, true);

    final testBooking = bookings.first;
    // Update to In Progress
    repo.updateBookingStatus(testBooking.id, BookingStatus.inProgress);
    var updatedBooking = repo.getAllBookings().firstWhere((b) => b.id == testBooking.id);
    expect(updatedBooking.status, BookingStatus.inProgress);

    // Update to Completed
    repo.updateBookingStatus(testBooking.id, BookingStatus.completed);
    updatedBooking = repo.getAllBookings().firstWhere((b) => b.id == testBooking.id);
    expect(updatedBooking.status, BookingStatus.completed);

    // Earnings calculation
    final earnings = repo.getBarberTotalEarnings(barberId);
    expect(earnings, greaterThan(0));
    final cutsCount = repo.getBarberCompletedCutsCount(barberId);
    expect(cutsCount, greaterThanOrEqualTo(1));
  });

  testWidgets('Test BarberDashboardScreen and BarberScheduleScreen rendering', (tester) async {
    final repo = AppRepository.instance;
    repo.switchRole(UserRole.barber);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: BarberDashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarberDashboardScreen), findsOneWidget);
    expect(find.text('Barber Workspace'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);

    // Tap schedule action
    final barber = repo.getBarberForCurrentUser()!;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: BarberScheduleScreen(barber: barber),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarberScheduleScreen), findsOneWidget);
    expect(find.textContaining('Schedule'), findsOneWidget);
  });

  testWidgets('Test CustomerMainNav with FindBarbersScreen (replaces map)', (tester) async {
    final repo = AppRepository.instance;
    repo.switchRole(UserRole.customer);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: CustomerMainNav(),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomerMainNav), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Find Barbers'), findsOneWidget);

    // Tap Find Barbers tab
    await tester.tap(find.widgetWithText(NavigationDestination, 'Find Barbers'));
    await tester.pumpAndSettle();

    expect(find.byType(FindBarbersScreen), findsOneWidget);
    expect(find.text('Find Top Barbers'), findsOneWidget);
    expect(find.textContaining('Book with'), findsWidgets);
  });
}
