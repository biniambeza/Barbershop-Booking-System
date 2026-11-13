// End-to-end walkthrough of this wave's features in demo (local) mode:
// a customer books, reschedules and cancels outside the cutoff; a barber
// marks a no-show; the owner adds time off; a walk-in and a remote customer
// join the queue; a customer reviews a completed visit; the owner opens the
// reports and sees the day's changes.
import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/queue_service.dart';
import 'package:barbershop_booking/services/reports_service.dart';
import 'package:barbershop_booking/services/reviews_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);
// Monday 23 Nov 2026 (Addis calendar day).
final _monday = DateTime(2026, 11, 23);
final _tuesday = DateTime(2026, 11, 24);

const _shopId = 'shop_1';
const _barberId = 'barber_1';
const _serviceId = 'srv_1_1';

final _repo = AppRepository.instance;

/// Free starts for [_barberId] on [addisDate] given what the cache holds.
List<DateTime> _freeStarts(DateTime addisDate, int minutes) => availableSlotStarts(
      shop: _repo.getShopById(_shopId)!,
      barber: _repo.getBarberById(_barberId)!,
      durationMinutes: minutes,
      addisDate: addisDate,
      busy: busyIntervalsFromBookings(_repo.getAllBookings(), _barberId),
      nowUtc: _repo.nowUtc(),
    );

Future<Booking> _book(DateTime startUtc) {
  final service = _repo.getServiceById(_serviceId)!;
  final barber = _repo.getBarberById(_barberId)!;
  final shop = _repo.getShopById(_shopId)!;
  return _repo.createBooking(
    shopId: shop.id,
    shopName: shop.name,
    barberId: barber.id,
    barberName: barber.name,
    serviceId: service.id,
    serviceName: service.name,
    price: service.price,
    date: _monday,
    timeSlot: '',
    startAt: startUtc,
  );
}

Map<String, dynamic> _seedJson() => jsonDecode(readSeedJson()) as Map<String, dynamic>;

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  setUp(() => loadTestSeed(now: _now));

  test('customer books, reschedules and cancels outside the cutoff', () async {
    _repo.switchRole(UserRole.customer); // user_cust_1
    final minutes = _repo.getServiceById(_serviceId)!.durationMinutes;
    final free = _freeStarts(_monday, minutes);
    expect(free.length, greaterThan(2));

    final booked = await _book(free.first);
    expect(_repo.getBookingById(booked.id)!.status, BookingStatus.confirmed);
    expect(_freeStarts(_monday, minutes), isNot(contains(free.first)));

    final target = free.last;
    final moved = await _repo.rescheduleBooking(booked.id, target);
    expect(moved.startAt, target);
    expect(moved.rescheduleCount, 1);
    final afterMove = _freeStarts(_monday, minutes);
    expect(afterMove, contains(free.first), reason: 'old time is free again');
    expect(afterMove, isNot(contains(target)));

    // Monday is days away, so the 2 h cutoff has not passed.
    await _repo.updateBookingStatus(booked.id, BookingStatus.cancelled);
    expect(_repo.getBookingById(booked.id)!.status, BookingStatus.cancelled);
    expect(_freeStarts(_monday, minutes), contains(target));
  });

  test('barber marks a no-show once the start has passed', () async {
    _repo.switchRole(UserRole.customer);
    final minutes = _repo.getServiceById(_serviceId)!.durationMinutes;
    final booking = await _book(_freeStarts(_monday, minutes).first);

    _repo.switchRole(UserRole.barber, targetBarberId: _barberId);
    _repo.debugClock = () => booking.startAt.add(const Duration(minutes: 20));
    await _repo.markNoShow(booking.id);
    expect(_repo.getBookingById(booking.id)!.status, BookingStatus.noShow);
  });

  test('owner adds time off and it disappears from availability', () async {
    _repo.switchRole(UserRole.barbershopOwner, targetShopId: _shopId);
    // Tuesday 14:00-16:00 Addis = 11:00-13:00Z.
    final start = DateTime.utc(2026, 11, 24, 11, 0);
    final end = DateTime.utc(2026, 11, 24, 13, 0);
    final freeBefore = _freeStarts(_tuesday, 15);
    expect(freeBefore, contains(start));

    final entry = await _repo.addTimeOff(barberId: _barberId, startUtc: start, endUtc: end, reason: 'Clinic');
    expect(entry.startAt, start);
    final list = await _repo.watchTimeOff(_shopId, _barberId).first;
    expect(list.map((t) => t.id), contains(entry.id));

    // A customer can no longer book inside it.
    _repo.switchRole(UserRole.customer);
    await expectLater(_book(start.add(const Duration(minutes: 30))), throwsA(isA<SlotTakenException>()));
    var busy = const <BusyInterval>[];
    final sub = _repo.watchBarberBusyTimes(_shopId, _barberId, _tuesday).listen((v) => busy = v);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    final freeAfter = availableSlotStarts(
      shop: _repo.getShopById(_shopId)!,
      barber: _repo.getBarberById(_barberId)!,
      durationMinutes: 15,
      addisDate: _tuesday,
      busy: busy,
      nowUtc: _now,
    );
    expect(freeAfter, isNot(contains(start)));
    expect(freeAfter, isNot(contains(end.subtract(const Duration(minutes: 15)))));
    expect(freeAfter, contains(end));
  });

  test('a walk-in and a remote customer join the queue', () async {
    final queue = QueueService();
    queue.local.loadSeedJson(_seedJson());
    final before = queue.local.summaryOf(_shopId).waitingCount;

    _repo.switchRole(UserRole.barbershopOwner, targetShopId: _shopId);
    final walkIn = await queue.addWalkIn(shopId: _shopId, name: 'Dawit', phone: '0911223344', serviceId: _serviceId);
    expect(walkIn.phone, '+251911223344');
    expect(queue.local.summaryOf(_shopId).waitingCount, before + 1);

    _repo.switchRole(UserRole.customer);
    final own = await queue.joinQueue(shopId: _shopId);
    expect(own.source, QueueSource.remote);
    expect(queue.local.summaryOf(_shopId).positions[own.id], isNotNull);
  });

  test('customer reviews a completed booking and the shop rating updates', () async {
    final reviews = ReviewsService(clock: () => _now);
    reviews.local.loadSeedJson(_seedJson(), now: _now);
    _repo.switchRole(UserRole.customer);
    final booking = _repo.getBookingById('book_5')!; // completed, not reviewed
    final countBefore = reviews.shopSummary(booking.shopId).count;

    final review = await reviews.submitReview(booking, rating: 5, comment: 'Great fade');
    expect(review.rating, 5);
    expect(reviews.shopSummary(booking.shopId).count, countBefore + 1);
    await expectLater(reviews.submitReview(booking, rating: 4), throwsA(isA<ReviewException>()));
  });

  testWidgets('owner opens reports and sees the no-show and cancellation', (tester) async {
    late int noShowsBefore;
    late int cancelledBefore;
    await tester.runAsync(() async {
      noShowsBefore = ReportsService(repository: _repo).computeLocalReport(_shopId, now: _now).months.first.noShows;
      cancelledBefore = ReportsService(repository: _repo).computeLocalReport(_shopId, now: _now).months.first.cancelled;
      _repo.switchRole(UserRole.customer);
      final free = _freeStarts(_monday, _repo.getServiceById(_serviceId)!.durationMinutes);
      final a = await _book(free.first);
      final b = await _book(free.last);
      await _repo.updateBookingStatus(b.id, BookingStatus.cancelled);
      _repo.switchRole(UserRole.barber, targetBarberId: _barberId);
      _repo.debugClock = () => a.startAt.add(const Duration(minutes: 20));
      await _repo.markNoShow(a.id);
      _repo.debugClock = () => _now;
    });

    _repo.switchRole(UserRole.barbershopOwner, targetShopId: _shopId);
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const OwnerDashboardScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open-reports')));
    await tester.tap(find.byKey(const ValueKey('open-reports')));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerReportsScreen), findsOneWidget);

    final current = ReportsService(repository: _repo).computeLocalReport(_shopId, now: _now).months.first;
    expect(current.noShows, noShowsBefore + 1);
    expect(current.cancelled, cancelledBefore + 1);
    expect(
      find.descendant(of: find.byKey(const ValueKey('reports-total-noshows')), matching: find.text('${current.noShows}')),
      findsOneWidget,
    );
  });
}
