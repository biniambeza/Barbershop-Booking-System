// Free Spark plan: Cloud Functions do not run, so the app covers for
// functions/insights (reports), functions/queue (queue summary) and
// functions/bookings expirePendingBookings (unanswered requests).
import 'dart:io';

import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/booking_acceptance.dart';
import 'package:barbershop_booking/services/queue_service.dart';
import 'package:barbershop_booking/services/queue_summary_writer.dart';
import 'package:barbershop_booking/services/report_fallback.dart';
import 'package:barbershop_booking/services/reports_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _booking(
  String id, {
  BookingStatus status = BookingStatus.completed,
  DateTime? startAt,
  String shopId = 's1',
  String customerId = 'c1',
  double price = 300,
  String? cancelledBy,
  String? cancelReason,
  String? declineReason,
}) =>
    Booking(
      id: id,
      shopId: shopId,
      shopName: 'Shop',
      barberId: 'b1',
      barberName: 'Yonas',
      customerId: customerId,
      customerName: 'Liya',
      customerPhone: '+251911000301',
      serviceId: 'srv1',
      serviceName: 'Fade',
      price: price,
      date: DateTime(2026, 11, 18),
      timeSlot: '10:00 AM',
      status: status,
      createdAt: _now.subtract(const Duration(days: 3)),
      startAt: startAt ?? DateTime.utc(2026, 11, 18, 7),
      durationMinutes: 30,
      cancelledBy: cancelledBy,
      cancelReason: cancelReason,
      declineReason: declineReason,
    );

QueueEntry _entry(
  String id,
  int minute, {
  QueueStatus status = QueueStatus.waiting,
  String? serviceId,
  String addedBy = 'staff',
  QueueSource source = QueueSource.walkIn,
}) =>
    QueueEntry(
      id: id,
      shopId: 's',
      name: id,
      serviceId: serviceId,
      status: status,
      createdAt: DateTime.utc(2026, 11, 13, 7, minute),
      addedBy: addedBy,
      source: source,
    );

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  // ---------------------------------------------------------------------
  // A) Reports
  // ---------------------------------------------------------------------
  group('reports fallback (report_fallback.dart)', () {
    final bookings = [
      _booking('a'),
      _booking('b', status: BookingStatus.cancelled, cancelledBy: 'c1'),
      // Never happened for the shop (functions/insights excludes it too).
      _booking('x', status: BookingStatus.cancelled, cancelledBy: 'system', cancelReason: 'slot_conflict'),
      _booking('c', status: BookingStatus.noShow, customerId: 'c2'),
    ];
    final computed = ReportsService.reportFromBookings('s1', bookings, now: _now);

    test('no stats docs at all -> bookings', () {
      expect(
        chooseReportSource(existingStats: const {}, fromBookings: computed, currentMonth: '2026-11', now: _now),
        ReportSource.bookings,
      );
    });

    test('stats that cover the bookings -> stats', () {
      final stats = {
        '2026-11': ShopMonthStats(
            month: '2026-11', bookings: 3, completed: 1, cancelled: 1, noShows: 1, updatedAt: DateTime.utc(2026, 10)),
      };
      expect(
        chooseReportSource(existingStats: stats, fromBookings: computed, currentMonth: '2026-11', now: _now),
        ReportSource.stats,
      );
    });

    test('stats behind the bookings: stale -> bookings, just updated -> stats', () {
      final old = {
        '2026-11': ShopMonthStats(month: '2026-11', bookings: 1, completed: 1, updatedAt: DateTime.utc(2026, 11, 2)),
      };
      expect(chooseReportSource(existingStats: old, fromBookings: computed, currentMonth: '2026-11', now: _now),
          ReportSource.bookings);
      final recent = {
        '2026-11': ShopMonthStats(
            month: '2026-11', bookings: 1, completed: 1, updatedAt: _now.subtract(const Duration(minutes: 2))),
      };
      expect(chooseReportSource(existingStats: recent, fromBookings: computed, currentMonth: '2026-11', now: _now),
          ReportSource.stats);
      // Only older months exist (current month never aggregated) -> behind.
      final onlyOld = {
        '2026-10': ShopMonthStats(month: '2026-10', bookings: 4, updatedAt: DateTime.utc(2026, 10, 30)),
      };
      expect(chooseReportSource(existingStats: onlyOld, fromBookings: computed, currentMonth: '2026-11', now: _now),
          ReportSource.bookings);
    });

    test('fewer cached bookings than the stats is normal -> stats', () {
      final stats = {
        '2026-11': ShopMonthStats(month: '2026-11', bookings: 40, completed: 30, cancelled: 5, noShows: 2)
      };
      expect(chooseReportSource(existingStats: stats, fromBookings: computed, currentMonth: '2026-11', now: _now),
          ReportSource.stats);
    });

    test('Firestore without stats docs: computed from bookings, slot conflicts excluded, flagged', () async {
      final db = FakeFirebaseFirestore();
      final report = await ReportsService.loadWithBookingFallback(db, 's1', bookings: bookings, now: _now);
      expect(report.fromBookings, isTrue);
      final nov = report.month('2026-11');
      expect(nov.bookings, 3);
      expect(nov.completed, 1);
      expect(nov.cancelled, 1);
      expect(nov.noShows, 1);
      expect(nov.revenueEtb, 300);
      expect(report.clients.map((c) => c.customerId).toSet(), {'c1', 'c2'});
    });

    test('Firestore with fresh stats docs: the stats and clients docs are used', () async {
      final db = FakeFirebaseFirestore();
      final shop = db.collection('barbershops').doc('s1');
      await shop.collection('stats').doc('2026-11').set({
        'month': '2026-11',
        'bookings': 7,
        'completed': 4,
        'cancelled': 2,
        'noShows': 1,
        'revenueEtb': 1250.5,
        'updatedAt': '2026-11-20T06:00:00.000Z',
      });
      await shop.collection('clients').doc('c9').set({
        'customerId': 'c9',
        'name': 'Dawit',
        'phone': '+251911000302',
        'completedCount': 4,
        'noShowCount': 0,
        'cancelledCount': 0,
        'lastVisitAt': null,
      });
      final report = await ReportsService.loadWithBookingFallback(db, 's1', bookings: bookings, now: _now);
      expect(report.fromBookings, isFalse);
      expect(report.month('2026-11').bookings, 7);
      expect(report.clients.single.customerId, 'c9');
    });

    testWidgets('owner screen shows the 90-day note and live figures from bookings', (tester) async {
      loadTestSeed(now: _now);
      final service = ReportsService(repository: repo, firestore: FakeFirebaseFirestore());
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(OwnerReportsScreen(shopId: 'shop_1', service: service, now: _now)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reports-from-bookings-note')), findsOneWidget);
      expect(find.text('Based on the last 90 days of bookings.'), findsOneWidget);
      expect(find.text('Figures update a few seconds after each booking change.'), findsNothing);
      final expected = service.computeLocalReport('shop_1', now: _now).month('2026-11').bookings;
      expect(
        find.descendant(of: find.byKey(const ValueKey('reports-total-bookings')), matching: find.text('$expected')),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------
  // B) Queue summary
  // ---------------------------------------------------------------------
  group('queue summary writer (queue_summary_writer.dart)', () {
    const durations = {'fade': 45, 'beard': 30};

    test('the function document shape: exact keys, int values, ISO millis', () {
      final plan = planQueueSummary(
        active: [
          _entry('a', 0, serviceId: 'fade'),
          _entry('s', 1, status: QueueStatus.serving),
          _entry('b', 5, serviceId: 'beard'),
          _entry('c', 10),
        ],
        serviceDurations: durations,
        availableBarbers: 2,
        now: DateTime.utc(2026, 11, 13, 7, 30, 0, 123, 456),
      );
      expect(plan.doc, {
        'waitingCount': 3,
        'estimatedWaitMinutes': 53, // ceil((45 + 30 + 30) / 2)
        'positions': {
          'a': {'position': 1, 'waitMinutes': 0},
          'b': {'position': 2, 'waitMinutes': 23},
          'c': {'position': 3, 'waitMinutes': 38},
        },
        'updatedAt': '2026-11-13T07:30:00.123Z',
      });
      expect(plan.duplicates, isEmpty);
    });

    test('duplicate remote entries of one customer (functions/queue rule)', () {
      final active = [
        _entry('r1', 0, addedBy: 'cust', source: QueueSource.remote),
        _entry('r2', 3, addedBy: 'cust', source: QueueSource.remote),
        _entry('w', 4, addedBy: 'cust'), // walk-in added by staff uid: not counted
        _entry('o1', 1, addedBy: 'other', source: QueueSource.remote, status: QueueStatus.serving),
        _entry('o2', 0, addedBy: 'other', source: QueueSource.remote),
      ];
      expect(findDuplicateRemoteEntries(active), unorderedEquals(['r2', 'o2']));
      final plan = planQueueSummary(active: active, serviceDurations: durations, availableBarbers: 1, now: _now);
      expect((plan.doc['positions'] as Map).keys, ['r1', 'w']);
    });

    test('content comparison ignores updatedAt', () {
      final a = {
        'waitingCount': 1,
        'estimatedWaitMinutes': 0,
        'positions': {
          'x': {'position': 1, 'waitMinutes': 0}
        }
      };
      expect(sameQueueSummaryContent({...a, 'updatedAt': '1'}, {...a, 'updatedAt': '2'}), isTrue);
      expect(sameQueueSummaryContent(a, {...a, 'waitingCount': 2}), isFalse);
      expect(sameQueueSummaryContent(a, {...a, 'positions': <String, dynamic>{}}), isFalse);
      expect(sameQueueSummaryContent(a, {...a, 'extra': true}), isFalse);
      expect(sameQueueSummaryContent(null, a), isFalse);
    });

    test('writes when changed, skips when unchanged, closes duplicates, never throws', () async {
      Map<String, dynamic>? stored;
      var writes = 0;
      final left = <String>[];
      var entries = [_entry('a', 0), _entry('b', 1)];
      final writer = QueueSummaryWriter(
        fetchActive: (_) async => entries,
        readSummary: (_) async => stored,
        writeSummary: (_, doc) async {
          writes++;
          stored = doc;
        },
        markLeft: (e, _) async => left.add(e.id),
        serviceDurations: (_) => durations,
        availableBarbers: (_) => 1,
        clock: () => _now,
      );
      expect(await writer.recomputeNow('s'), QueueSummaryWriteOutcome.written);
      expect(stored!['waitingCount'], 2);
      expect(await writer.recomputeNow('s'), QueueSummaryWriteOutcome.unchanged);
      expect(writes, 1);

      entries = [
        _entry('a', 0),
        _entry('r1', 2, addedBy: 'cust', source: QueueSource.remote),
        _entry('r2', 3, addedBy: 'cust', source: QueueSource.remote),
      ];
      expect(await writer.recomputeNow('s'), QueueSummaryWriteOutcome.written);
      expect(left, ['r2']);
      expect((stored!['positions'] as Map).keys, ['a', 'r1']);

      final failing = QueueSummaryWriter(
        fetchActive: (_) async => throw StateError('offline'),
        readSummary: (_) async => null,
        writeSummary: (_, __) async {},
        markLeft: (_, __) async {},
        serviceDurations: (_) => durations,
        availableBarbers: (_) => 1,
      );
      expect(await failing.recomputeNow('s'), QueueSummaryWriteOutcome.failed);
    });

    test('schedule is debounced per shop (one write for a burst)', () async {
      var writes = 0;
      final writer = QueueSummaryWriter(
        fetchActive: (_) async => [_entry('a', 0)],
        readSummary: (_) async => null,
        writeSummary: (_, __) async => writes++,
        markLeft: (_, __) async {},
        serviceDurations: (_) => durations,
        availableBarbers: (_) => 1,
        debounce: const Duration(milliseconds: 20),
      );
      writer.schedule('s');
      writer.schedule('s');
      writer.schedule('s', entries: [_entry('a', 0), _entry('b', 1)]);
      expect(writer.isScheduled('s'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(writes, 1);
      expect(writer.isScheduled('s'), isFalse);
      writer.dispose();
    });

    group('QueueService with Firestore (staff app writes the summary)', () {
      setUp(loadTestSeed);

      test('staff action + refresh write the exact function document', () async {
        final db = FakeFirebaseFirestore();
        final service = QueueService(cloud: FirestoreQueueStore(db));
        addTearDown(service.summaryWriter.dispose);
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');

        final hana = await service.addWalkIn(shopId: 'shop_1', name: 'Hana', serviceId: 'srv_1_1');
        expect(service.summaryWriter.isScheduled('shop_1'), isTrue);
        expect(await service.refreshSummary('shop_1'), QueueSummaryWriteOutcome.written);

        final doc = (await db.doc('barbershops/shop_1/queueSummary/current').get()).data()!;
        expect(doc.keys.toSet(), {'waitingCount', 'estimatedWaitMinutes', 'positions', 'updatedAt'});
        expect(doc['waitingCount'], 1);
        expect(doc['estimatedWaitMinutes'], isA<int>());
        expect(doc['positions'], {
          hana.id: {'position': 1, 'waitMinutes': 0},
        });
        expect(DateTime.parse(doc['updatedAt'] as String).isUtc, isTrue);
        // Customers read it through the usual summary stream.
        expect((await service.watchSummary('shop_1').first).positions[hana.id]?.position, 1);
        // Nothing changed -> no second write.
        expect(await service.refreshSummary('shop_1'), QueueSummaryWriteOutcome.unchanged);
      });

      test('the staff listener schedules a recompute; customers never write', () async {
        final db = FakeFirebaseFirestore();
        final service = QueueService(cloud: FirestoreQueueStore(db));
        addTearDown(service.summaryWriter.dispose);

        repo.switchRole(UserRole.customer);
        await service.joinQueue(shopId: 'shop_1');
        expect(service.summaryWriter.isScheduled('shop_1'), isFalse);
        expect(await service.refreshSummary('shop_1'), isNull);

        repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
        await service.watchActiveQueue('shop_1').first;
        expect(service.summaryWriter.isScheduled('shop_1'), isTrue);
      });

      test('local store (demo/tests) does not use the writer', () async {
        final service = QueueService();
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
        await service.addWalkIn(shopId: 'shop_1', name: 'Hana');
        expect(service.summaryWriter.isScheduled('shop_1'), isFalse);
        expect(await service.refreshSummary('shop_1'), isNull);
      });
    });
  });

  // ---------------------------------------------------------------------
  // C) Unanswered booking requests
  // ---------------------------------------------------------------------
  group('expired booking requests (no expirePendingBookings function)', () {
    final start = DateTime.utc(2026, 11, 20, 9);

    test('pure rules: expired display, client close after the grace, markers', () {
      final pending = _booking('p', status: BookingStatus.pending, startAt: start);
      // 61 minutes before: still open.
      expect(isUnansweredExpiredRequest(pending, start.subtract(const Duration(minutes: 61))), isFalse);
      // 50 minutes before: expired for display, the app does not close it yet.
      final t50 = start.subtract(const Duration(minutes: 50));
      expect(isUnansweredExpiredRequest(pending, t50), isTrue);
      expect(shouldClientCloseExpiredRequest(pending, t50), isFalse);
      // 45 minutes before (and later): the staff app closes it.
      expect(shouldClientCloseExpiredRequest(pending, start.subtract(const Duration(minutes: 45))), isTrue);
      expect(shouldClientCloseExpiredRequest(pending, start.add(const Duration(hours: 1))), isTrue);
      expect(shouldClientCloseExpiredRequest(pending.copyWith(status: BookingStatus.confirmed), start), isFalse);

      final closedByApp = _booking('p',
          status: BookingStatus.cancelled, startAt: start, cancelledBy: 'barber', declineReason: kNotAcceptedReason);
      expect(isClientExpiredClose(closedByApp), isTrue);
      expect(wasNotAccepted(closedByApp), isTrue);
      expect(wasDeclined(closedByApp), isFalse);
      final declined = _booking('p', status: BookingStatus.cancelled, cancelledBy: 'barber', declineReason: 'Busy');
      expect(wasDeclined(declined), isTrue);
      expect(wasNotAccepted(declined), isFalse);
      final byFunction =
          _booking('p', status: BookingStatus.cancelled, cancelledBy: 'system', cancelReason: kNotAcceptedReason);
      expect(wasNotAccepted(byFunction), isTrue);
    });

    group('repository (local mode)', () {
      late Booking request;

      setUp(() {
        loadTestSeed(now: _now);
        request = repo.getBookingById('book_21')!;
        expect(request.status, BookingStatus.pending);
      });

      void at(DateTime t) => repo.debugClock = () => t;

      /// A pending request for barber_1 (shop_1 switched to barber
      /// acceptance), Monday 23 Nov 2026 10:00 Addis.
      Future<Booking> barber1Request() async {
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
          startAt: DateTime.utc(2026, 11, 23, 7),
          durationMinutes: 45,
        );
      }

      test('the booked barber closes it with the existing decline write and marker', () async {
        final mine = await barber1Request();
        expect(mine.status, BookingStatus.pending);
        at(mine.startAt.subtract(const Duration(minutes: 30)));
        repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
        expect(await repo.closeExpiredBookingRequests(force: true), 1);
        final after = repo.getBookingById(mine.id)!;
        expect(after.status, BookingStatus.cancelled);
        expect(after.cancelledBy, kDeclinedBy);
        expect(after.declineReason, kNotAcceptedReason);
        expect(wasNotAccepted(after), isTrue);
        expect(wasDeclined(after), isFalse);
        // Idempotent: nothing left to close.
        expect(await repo.closeExpiredBookingRequests(force: true), 0);
      });

      test('inside the grace window, other barbers and customers: nothing happens', () async {
        final mine = await barber1Request();
        at(mine.startAt.subtract(const Duration(minutes: 50)));
        repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
        expect(await repo.closeExpiredBookingRequests(force: true), 0);

        at(mine.startAt.subtract(const Duration(minutes: 30)));
        repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
        expect(await repo.closeExpiredBookingRequests(force: true), 0);
        repo.switchRole(UserRole.customer);
        expect(await repo.closeExpiredBookingRequests(force: true), 0);
        expect(repo.getBookingById(mine.id)!.status, BookingStatus.pending);
      });

      test('the shop owner may close it; sweeps are throttled to once a minute', () async {
        at(request.startAt.subtract(const Duration(minutes: 30)));
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
        expect(await repo.closeExpiredBookingRequests(force: true), 1);
        expect(await repo.closeExpiredBookingRequests(), 0); // throttled, nothing to do anyway
        expect(repo.startExpiredRequestSweep(), isNull); // no Firebase in tests
      });
    });
  });
}
