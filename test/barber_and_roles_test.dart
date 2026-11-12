import 'dart:async';
import 'dart:convert';
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

class _TestHttpClientResponse extends Fake implements HttpClientResponse {
  static final _transparentImage = base64Decode(
    'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  );

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
}

class _TestHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _TestHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });
  test('AppRepository supports all 4 distinct roles with dedicated personas', () {
    final repo = AppRepository.instance;

    // 1. Switch to Admin
    repo.switchRole(UserRole.admin);
    expect(repo.currentUser?.role, UserRole.admin);
    expect(repo.currentUser?.email, 'admin@crownblade.com');

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
    expect(repo.currentUser?.email, 'alex@example.com');
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
