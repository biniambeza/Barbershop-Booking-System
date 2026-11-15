import 'dart:io';

import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/booking_acceptance.dart';
import 'package:barbershop_booking/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

// Monday 23 Nov 2026, 10:00 Addis: free for barber_1 in the seed.
final _start = DateTime.utc(2026, 11, 23, 7, 0);

Booking _booking({
  BookingStatus status = BookingStatus.pending,
  DateTime? start,
  String shopId = 's',
  String barberId = 'br',
  String? cancelledBy,
  String? cancelReason,
}) {
  final s = start ?? _start;
  return Booking(
    id: 'b',
    shopId: shopId,
    shopName: 'Shop',
    barberId: barberId,
    barberName: 'Barber',
    customerId: 'c',
    customerName: 'Abebe',
    customerPhone: '+251911234567',
    serviceId: 'sv',
    serviceName: 'Cut',
    price: 300,
    date: DateTime(2026, 11, 23),
    timeSlot: '10:00 AM',
    status: status,
    createdAt: _now,
    startAt: s,
    durationMinutes: 30,
    cancelledBy: cancelledBy,
    cancelReason: cancelReason,
  );
}

Barbershop _shop({bool require = false}) => Barbershop(
      id: 's',
      ownerId: 'o',
      name: 'Shop',
      description: '',
      address: '',
      city: 'Addis Ababa',
      phone: '+251911000000',
      imageUrl: '',
      requireBarberAcceptance: require,
    );

AppUser _user(UserRole role, {String? shopId, String? barberId}) => AppUser(
      uid: 'u',
      name: 'U',
      email: 'u@example.com',
      role: role,
      shopId: shopId,
      barberId: barberId,
      createdAt: _now,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  group('rules (booking_acceptance.dart)', () {
    test('initial status follows the shop setting', () {
      expect(initialBookingStatus(_shop()), BookingStatus.confirmed);
      expect(initialBookingStatus(_shop(require: true)), BookingStatus.pending);
      expect(initialBookingStatus(null), BookingStatus.confirmed);
    });

    test('requests expire 60 minutes before the start', () {
      expect(isRequestExpired(_booking(), _start.subtract(const Duration(minutes: 61))), isFalse);
      expect(isRequestExpired(_booking(), _start.subtract(const Duration(minutes: 60))), isTrue);
      expect(isRequestExpired(_booking(), _start.add(const Duration(minutes: 5))), isTrue);
      expect(isOpenRequest(_booking(), _now), isTrue);
      expect(isOpenRequest(_booking(status: BookingStatus.confirmed), _now), isFalse);
    });

    test('open requests are filtered by barber/shop and sorted soonest first', () {
      final later = _booking(start: _start.add(const Duration(hours: 2))).copyWith(id: 'later');
      final sooner = _booking().copyWith(id: 'sooner');
      final expired = _booking(start: _now.add(const Duration(minutes: 30))).copyWith(id: 'expired');
      final other = _booking(barberId: 'x').copyWith(id: 'other');
      final all = [later, sooner, expired, other, _booking(status: BookingStatus.confirmed).copyWith(id: 'c')];
      expect(openRequestsForBarber(all, 'br', _now).map((b) => b.id), ['sooner', 'later']);
      // 'other' starts at the same time as 'sooner' (stable sort keeps input order).
      expect(openRequestsForShop(all, 's', _now).map((b) => b.id), ['sooner', 'other', 'later']);
    });

    test('who may answer', () {
      final b = _booking();
      expect(canRespondToRequest(_user(UserRole.barber, shopId: 's', barberId: 'br'), b), isTrue);
      expect(canRespondToRequest(_user(UserRole.barber, shopId: 's', barberId: 'other'), b), isFalse);
      expect(canRespondToRequest(_user(UserRole.barber, shopId: 'x', barberId: 'br'), b), isFalse);
      expect(canRespondToRequest(_user(UserRole.barbershopOwner, shopId: 's'), b), isTrue);
      expect(canRespondToRequest(_user(UserRole.barbershopOwner, shopId: 'x'), b), isFalse);
      expect(canRespondToRequest(_user(UserRole.admin), b), isTrue);
      expect(canRespondToRequest(_user(UserRole.customer), b), isFalse);
      expect(canRespondToRequest(null, b), isFalse);
    });

    test('decline reason: trimmed, optional, at most 200 characters', () {
      expect(normalizeDeclineReason(null), isNull);
      expect(normalizeDeclineReason('   '), isNull);
      expect(normalizeDeclineReason('  Sick today '), 'Sick today');
      expect(normalizeDeclineReason('x' * 200), 'x' * 200);
      expect(
        () => normalizeDeclineReason('x' * 201),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.declineReasonTooLong)),
      );
    });

    test('written fields', () {
      expect(acceptFields(_now), {'status': 'confirmed', 'acceptedAt': '2026-11-20T07:00:00.000Z'});
      expect(declineFields(null), {'status': 'cancelled', 'cancelledBy': 'barber'});
      expect(declineFields('Busy'), {'status': 'cancelled', 'cancelledBy': 'barber', 'declineReason': 'Busy'});
    });

    test('ended requests', () {
      expect(wasDeclined(_booking(status: BookingStatus.cancelled, cancelledBy: 'barber')), isTrue);
      expect(wasDeclined(_booking(status: BookingStatus.cancelled, cancelledBy: 'c')), isFalse);
      expect(
        wasNotAccepted(_booking(status: BookingStatus.cancelled, cancelledBy: 'system', cancelReason: 'not_accepted')),
        isTrue,
      );
      expect(isAwaitingAcceptance(_booking()), isTrue);
    });

    test('pending bookings cannot be paid online yet', () {
      final pending = _booking();
      expect(canPayBookingOnline(pending), isFalse);
      expect(canPayBookingOnline(pending.copyWith(status: BookingStatus.confirmed)), isTrue);
      expect(checkBookingPayable(pending.copyWith(customerId: 'c'), 'c')?.code, 'failed-precondition');
      expect(checkBookingPayable(pending.copyWith(status: BookingStatus.confirmed), 'c'), isNull);
    });
  });

  group('demo seed', () {
    setUp(() => loadTestSeed(now: _now));

    test('shop_2 requires acceptance and has a pending request', () {
      expect(repo.getShopById('shop_2')?.requireBarberAcceptance, isTrue);
      expect(repo.getShopById('shop_1')?.requireBarberAcceptance, isFalse);
      final requests = repo.getBookingRequestsForShop('shop_2');
      expect(requests.map((b) => b.id), contains('book_21'));
      expect(requests.firstWhere((b) => b.id == 'book_21').barberId, 'barber_2_2');
    });
  });

  group('repository (local mode)', () {
    setUp(() => loadTestSeed(now: _now));

    Future<Booking> book() async {
      repo.switchRole(UserRole.customer); // user_cust_1
      return repo.createBooking(
        shopId: 'shop_1',
        shopName: 'Shop 1',
        barberId: 'barber_1',
        barberName: 'Yonas Tadesse',
        serviceId: 'srv_1_1',
        serviceName: 'Cut',
        price: 300,
        date: DateTime(2026, 11, 23),
        timeSlot: '10:00 AM',
        startAt: _start,
        durationMinutes: 45,
      );
    }

    Future<void> requireAcceptance() async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final shop = repo.getShopById('shop_1')!;
      await repo.updateShopPolicy('shop_1',
          cancellationCutoffHours: shop.cancellationCutoffHours,
          maxReschedules: shop.maxReschedules,
          requireBarberAcceptance: true);
    }

    Future<List<BusyInterval>> busy() async {
      var latest = const <BusyInterval>[];
      final sub = repo.watchBarberBusyTimes('shop_1', 'barber_1', DateTime(2026, 11, 23)).listen((v) => latest = v);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return latest;
    }

    bool holds(List<BusyInterval> list) => list.any((i) => i.start == _start);

    test('without the setting, bookings are confirmed right away', () async {
      final b = await book();
      expect(b.status, BookingStatus.confirmed);
    });

    test('owner turns it on via the policy write; bookings start pending and keep their time', () async {
      await requireAcceptance();
      expect(repo.getShopById('shop_1')?.requireBarberAcceptance, isTrue);
      final b = await book();
      expect(b.status, BookingStatus.pending);
      expect(holds(await busy()), isTrue);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(repo.getBookingRequestsForBarber('barber_1').map((r) => r.id), [b.id]);
    });

    test('the barber accepts: confirmed + acceptedAt, slot still held', () async {
      await requireAcceptance();
      final b = await book();
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.acceptBookingRequest(b.id);
      final after = repo.getBookingById(b.id)!;
      expect(after.status, BookingStatus.confirmed);
      expect(after.acceptedAt, _now);
      expect(holds(await busy()), isTrue);
      expect(repo.getBookingRequestsForBarber('barber_1'), isEmpty);
      // A second answer is refused.
      await expectLater(
        repo.acceptBookingRequest(b.id),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.bookingNotChangeable)),
      );
    });

    test('the barber declines with a reason: cancelled by barber, slot freed', () async {
      await requireAcceptance();
      final b = await book();
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.declineBookingRequest(b.id, reason: '  Out sick  ');
      final after = repo.getBookingById(b.id)!;
      expect(after.status, BookingStatus.cancelled);
      expect(after.cancelledBy, 'barber');
      expect(after.declineReason, 'Out sick');
      expect(wasDeclined(after), isTrue);
      expect(holds(await busy()), isFalse);
    });

    test('a too-long reason is refused before anything is written', () async {
      await requireAcceptance();
      final b = await book();
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await expectLater(
        repo.declineBookingRequest(b.id, reason: 'x' * 201),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.declineReasonTooLong)),
      );
      expect(repo.getBookingById(b.id)?.status, BookingStatus.pending);
    });

    test('the owner can answer on behalf of the barber', () async {
      await requireAcceptance();
      final b = await book();
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(repo.getBookingRequestsForShop('shop_1').map((r) => r.id), [b.id]);
      await repo.acceptBookingRequest(b.id);
      expect(repo.getBookingById(b.id)?.status, BookingStatus.confirmed);
    });

    test('customers and other barbers cannot answer', () async {
      await requireAcceptance();
      final b = await book();
      repo.switchRole(UserRole.customer);
      await expectLater(
        repo.acceptBookingRequest(b.id),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.bookingRequestNotAllowed)),
      );
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      await expectLater(
        repo.declineBookingRequest(b.id),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.bookingRequestNotAllowed)),
      );
      expect(repo.getBookingById(b.id)?.status, BookingStatus.pending);
    });

    test('inside the expiry window a request can be declined but no longer accepted', () async {
      await requireAcceptance();
      final b = await book();
      repo.debugClock = () => _start.subtract(const Duration(minutes: 30));
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(repo.getBookingRequestsForBarber('barber_1'), isEmpty);
      await expectLater(
        repo.acceptBookingRequest(b.id),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.bookingNotChangeable)),
      );
      await repo.declineBookingRequest(b.id);
      expect(repo.getBookingById(b.id)?.status, BookingStatus.cancelled);
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

    Future<Booking> pendingRequest() async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final shop = repo.getShopById('shop_1')!;
      await repo.updateShopPolicy('shop_1',
          cancellationCutoffHours: shop.cancellationCutoffHours,
          maxReschedules: shop.maxReschedules,
          requireBarberAcceptance: true);
      repo.switchRole(UserRole.customer);
      return repo.createBooking(
        shopId: 'shop_1',
        shopName: 'Shop 1',
        barberId: 'barber_1',
        barberName: 'Yonas Tadesse',
        serviceId: 'srv_1_1',
        serviceName: 'Cut',
        price: 300,
        date: DateTime(2026, 11, 23),
        timeSlot: '10:00 AM',
        startAt: _start,
        durationMinutes: 45,
      );
    }

    testWidgets('customer sees "Waiting for barber" and no Pay button', (tester) async {
      bigScreen(tester);
      final b = await pendingRequest();
      await tester.pumpWidget(app(CustomerBookingsScreen(clock: () => _now)));
      await tester.pumpAndSettle();
      expect(find.text(en.acceptWaitingForBarber.toUpperCase()), findsOneWidget);
      expect(find.byKey(ValueKey('pay-booking-${b.id}')), findsNothing);
    });

    testWidgets('barber dashboard: New requests -> Accept confirms the booking', (tester) async {
      bigScreen(tester);
      final b = await pendingRequest();
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await tester.pumpWidget(app(const BarberDashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('booking-requests-section')), findsOneWidget);
      expect(find.text(en.acceptRequestsTitle), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('accept-request-${b.id}')));
      await tester.pumpAndSettle();
      expect(repo.getBookingById(b.id)?.status, BookingStatus.confirmed);
      expect(find.byKey(const ValueKey('booking-requests-section')), findsNothing);
    });

    testWidgets('barber dashboard: Decline with a reason frees the slot', (tester) async {
      bigScreen(tester);
      final b = await pendingRequest();
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await tester.pumpWidget(app(const BarberDashboardScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('decline-request-${b.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('decline-reason-field')), 'Fully booked');
      await tester.tap(find.byKey(const ValueKey('decline-request-confirm')));
      await tester.pumpAndSettle();
      final after = repo.getBookingById(b.id)!;
      expect(after.status, BookingStatus.cancelled);
      expect(after.cancelledBy, 'barber');
      expect(after.declineReason, 'Fully booked');
    });
  });
}
