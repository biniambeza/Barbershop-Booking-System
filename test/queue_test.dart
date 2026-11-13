import 'dart:convert';

import 'package:barbershop_booking/features/queue/queue_l10n.dart';
import 'package:barbershop_booking/features/queue/queue_screen.dart';
import 'package:barbershop_booking/features/queue/queue_status_card.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/queue_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

QueueEntry _entry(String id, int minute, {QueueStatus status = QueueStatus.waiting, String? serviceId}) => QueueEntry(
      id: id,
      shopId: 's',
      name: id,
      serviceId: serviceId,
      status: status,
      createdAt: DateTime.utc(2026, 11, 13, 7, minute),
      addedBy: 'u',
    );

/// A fresh service on the local store, seeded with the demo queue.
QueueService _seededService() {
  final service = QueueService();
  service.local.loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>);
  return service;
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

void main() {
  final repo = AppRepository.instance;

  group('estimateQueueWait (same cases as functions/queue)', () {
    const durations = {'fade': 45, 'beard': 30, 'full': 90};

    test('empty queue', () {
      final s = estimateQueueWait(entries: const [], serviceDurations: durations, availableBarbers: 2);
      expect(s.waitingCount, 0);
      expect(s.estimatedWaitMinutes, 0);
      expect(s.positions, isEmpty);
    });

    test('sums the services ahead, divides by barbers, rounds up', () {
      final s = estimateQueueWait(
        entries: [
          _entry('a', 0, serviceId: 'fade'),
          _entry('b', 5, serviceId: 'beard'),
          _entry('c', 10),
          _entry('d', 15, serviceId: 'full'),
        ],
        serviceDurations: durations,
        availableBarbers: 2,
      );
      expect(s.waitingCount, 4);
      expect(s.positions, {
        'a': const QueuePosition(position: 1, waitMinutes: 0),
        'b': const QueuePosition(position: 2, waitMinutes: 23),
        'c': const QueuePosition(position: 3, waitMinutes: 38),
        'd': const QueuePosition(position: 4, waitMinutes: 53),
      });
      expect(s.estimatedWaitMinutes, 98);
    });

    test('arrival order, other statuses ignored, at least one barber', () {
      final s = estimateQueueWait(
        entries: [
          _entry('z', 10),
          _entry('b', 0),
          _entry('a', 0),
          _entry('s', 1, status: QueueStatus.serving, serviceId: 'full'),
          _entry('d', 2, status: QueueStatus.done),
          _entry('l', 3, status: QueueStatus.left),
        ],
        serviceDurations: durations,
        availableBarbers: 0,
      );
      expect(s.positions.keys, ['a', 'b', 'z']);
      expect(s.positions['z'], const QueuePosition(position: 3, waitMinutes: 60));
      expect(s.estimatedWaitMinutes, 90);
      expect(queueServiceMinutes('gone', durations), kQueueDefaultServiceMinutes);
      expect(queueServiceMinutes(null, durations), 30);
    });
  });

  group('models', () {
    test('entry round trip leaves out empty optionals', () {
      final e = QueueEntry(
        id: 'e1',
        shopId: 'shop_1',
        name: 'Abel',
        phone: '+251911000401',
        status: QueueStatus.serving,
        barberId: 'barber_1',
        createdAt: DateTime.utc(2026, 11, 13, 7),
        servingStartedAt: DateTime.utc(2026, 11, 13, 7, 30),
        addedBy: 'owner_1',
      );
      final map = e.toMap();
      expect(map.containsKey('serviceId'), isFalse);
      expect(map.containsKey('shopId'), isFalse);
      expect(map['createdAt'], '2026-11-13T07:00:00.000Z');
      expect(map['source'], 'walkIn');
      final back = QueueEntry.fromMap(map, 'e1', shopId: 'shop_1');
      expect(back.status, QueueStatus.serving);
      expect(back.servingStartedAt, e.servingStartedAt);
      expect(back.phone, e.phone);
    });

    test('summary from the function document', () {
      final s = QueueSummary.fromMap({
        'waitingCount': 2,
        'estimatedWaitMinutes': 40,
        'positions': {
          'a': {'position': 1, 'waitMinutes': 0},
          'b': {'position': 2, 'waitMinutes': 20},
        },
        'updatedAt': '2026-11-13T07:00:00.000Z',
      });
      expect(s.waitingCount, 2);
      expect(s.positions['b'], const QueuePosition(position: 2, waitMinutes: 20));
      expect(QueueSummary.fromMap(s.toMap()).positions, s.positions);
    });
  });

  group('local queue (demo data)', () {
    setUp(loadTestSeed);

    test('seeded shop_1 summary matches tool/seed/seed.js', () {
      final service = _seededService();
      final s = service.local.summaryOf('shop_1');
      expect(s.waitingCount, 3);
      expect(s.estimatedWaitMinutes, 35);
      expect(s.positions, {
        'queue_1_2': const QueuePosition(position: 1, waitMinutes: 0),
        'queue_1_3': const QueuePosition(position: 2, waitMinutes: 10),
        'queue_1_4': const QueuePosition(position: 3, waitMinutes: 25),
      });
    });

    test('owner: add walk-in, call next, busy barber, finish, left', () async {
      final service = _seededService();
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');

      await expectLater(
        service.addWalkIn(shopId: 'shop_1', name: '   '),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.nameRequired)),
      );
      await expectLater(
        service.addWalkIn(shopId: 'shop_1', name: 'Hana', phone: '12345'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.invalidPhone)),
      );
      await expectLater(
        service.addWalkIn(shopId: 'shop_2', name: 'Hana'),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.notStaff)),
      );
      final hana =
          await service.addWalkIn(shopId: 'shop_1', name: ' Hana ', phone: '0911 22 33 44', serviceId: 'srv_1_3');
      expect(hana.name, 'Hana');
      expect(hana.phone, '+251911223344');
      expect(hana.source, QueueSource.walkIn);
      expect(service.local.summaryOf('shop_1').waitingCount, 4);
      expect(service.local.summaryOf('shop_1').positions[hana.id]!.position, 4);

      // barber_1 is serving queue_1_1 already.
      await expectLater(
        service.callNext('shop_1', 'barber_1'),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.barberBusy)),
      );

      // barber_1_3: queue_1_2 has no preference -> served first.
      final first = await service.callNext('shop_1', 'barber_1_3');
      expect(first!.id, 'queue_1_2');
      expect(first.barberId, 'barber_1_3');
      // barber_2: queue_1_3 (no preference) is next.
      final second = await service.callNext('shop_1', 'barber_2');
      expect(second!.id, 'queue_1_3');

      var active = await service.store.fetchActive('shop_1');
      expect(QueueService.servingByBarber(active).keys.toSet(), {'barber_1', 'barber_1_3', 'barber_2'});
      // queue_1_4 prefers barber_2, who is busy; nobody else may take them via callNext.
      expect(QueueService.nextFor(active, 'barber_1_3')?.id, hana.id);

      await service.finish(active.firstWhere((e) => e.id == 'queue_1_1'));
      final queue14 = active.firstWhere((e) => e.id == 'queue_1_4');
      await service.markLeft(queue14);
      await expectLater(
        service.markLeft(queue14.copyWith(status: QueueStatus.left)),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.notWaiting)),
      );
      await expectLater(
        service.startServing(queue14, 'barber_1'),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.notWaiting)),
      );

      active = await service.store.fetchActive('shop_1');
      expect(active.map((e) => e.id), ['queue_1_2', 'queue_1_3', hana.id]);
      final summary = service.local.summaryOf('shop_1');
      expect(summary.waitingCount, 1);
      expect(summary.positions[hana.id], const QueuePosition(position: 1, waitMinutes: 0));
      expect(summary.estimatedWaitMinutes, 30); // 90-minute package / 3 barbers
    });

    test('barber calls the next person for themselves', () async {
      final service = _seededService();
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      expect(service.isStaffOf('shop_1'), isTrue);
      final next = await service.callNext('shop_1', 'barber_2');
      expect(next!.id, 'queue_1_2');
      await expectLater(
        service.callNext('shop_1', 'barber_2'),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.barberBusy)),
      );
    });

    test('customer: join once, see position, leave; staff cannot join', () async {
      final service = _seededService();
      repo.switchRole(UserRole.customer);
      final uid = repo.currentUser!.uid;

      // user_cust_1 is already in shop_1's queue (seed).
      final seeded = await service.joinQueue(shopId: 'shop_1');
      expect(seeded.id, 'queue_1_3');

      await expectLater(
        service.addWalkIn(shopId: 'shop_2', name: 'Me'),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.notStaff)),
      );

      final mine = service.watchMyEntry('shop_2');
      final joined = await service.joinQueue(shopId: 'shop_2', serviceId: 'srv_2_1');
      expect(joined.source, QueueSource.remote);
      expect(joined.addedBy, uid);
      expect(joined.name, repo.currentUser!.name);
      expect(joined.phone, matches(RegExp(r'^\+251[79]\d{8}$')));
      expect((await service.joinQueue(shopId: 'shop_2')).id, joined.id, reason: 'one active entry per shop');
      expect(await mine.first, isNotNull);
      expect(service.local.summaryOf('shop_2').positions[joined.id]!.position, 1);

      await service.leaveQueue(joined);
      expect(await service.watchMyEntry('shop_2').first, isNull);
      expect(service.local.summaryOf('shop_2').waitingCount, 0);
      final again = await service.joinQueue(shopId: 'shop_2');
      expect(again.id, isNot(joined.id));

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(
        service.joinQueue(shopId: 'shop_2'),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.customersOnly)),
      );
      await expectLater(
        service.leaveQueue(again),
        throwsA(isA<QueueException>().having((e) => e.code, 'code', QueueErrorCode.customersOnly)),
      );
    });

    test('error texts in both languages', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final am = lookupAppLocalizations(const Locale('am'));
      for (final code in QueueErrorCode.values) {
        final e = QueueException(code, const ['Yonas']);
        expect(en.queueErrorText(e), isNotEmpty);
        expect(am.queueErrorText(e), isNot(en.queueErrorText(e)));
      }
      expect(en.queueErrorText(QueueException(QueueErrorCode.barberBusy, ['Yonas'])), contains('Yonas'));
      expect(en.queueErrorText(AppStateException(AppErrorCode.signInRequired)), en.errSignInRequired);
    });
  });

  group('Firestore queue store', () {
    setUp(loadTestSeed);

    test('writes the contract shape and reads it back', () async {
      final db = FakeFirebaseFirestore();
      final service = QueueService(cloud: FirestoreQueueStore(db));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');

      final added = await service.addWalkIn(shopId: 'shop_1', name: 'Hana', serviceId: 'srv_1_1');
      final doc = await db.doc('barbershops/shop_1/queue/${added.id}').get();
      expect(doc.data(), {
        'name': 'Hana',
        'serviceId': 'srv_1_1',
        'status': 'waiting',
        'createdAt': added.createdAt.toIso8601String(),
        'addedBy': repo.currentUser!.uid,
        'source': 'walkIn',
      });

      expect((await service.watchActiveQueue('shop_1').first).map((e) => e.id), [added.id]);
      final serving = await service.callNext('shop_1', 'barber_2');
      final after = (await db.doc('barbershops/shop_1/queue/${added.id}').get()).data()!;
      expect(after['status'], 'serving');
      expect(after['barberId'], 'barber_2');
      expect(after['servingStartedAt'], serving!.servingStartedAt!.toIso8601String());

      await service.finish(serving);
      expect((await db.doc('barbershops/shop_1/queue/${added.id}').get()).data()!['status'], 'done');
      expect(await service.watchActiveQueue('shop_1').first, isEmpty);

      // Summary comes from the function's document.
      expect(await service.watchSummary('shop_1').first, isA<QueueSummary>().having((s) => s.waitingCount, 'n', 0));
      await db.doc('barbershops/shop_1/queueSummary/current').set({
        'waitingCount': 4,
        'estimatedWaitMinutes': 50,
        'positions': <String, dynamic>{},
        'updatedAt': '2026-11-13T07:00:00.000Z',
      });
      expect((await service.watchSummary('shop_1').first).estimatedWaitMinutes, 50);
    });

    test('customer finds their own latest entry', () async {
      final db = FakeFirebaseFirestore();
      final service = QueueService(cloud: FirestoreQueueStore(db));
      repo.switchRole(UserRole.customer);
      final joined = await service.joinQueue(shopId: 'shop_1');
      expect((await db.doc('barbershops/shop_1/queue/${joined.id}').get()).data()!['source'], 'remote');
      expect((await service.watchMyEntry('shop_1').first)?.id, joined.id);
      await service.leaveQueue(joined);
      final left = (await db.doc('barbershops/shop_1/queue/${joined.id}').get()).data()!;
      expect(left['status'], 'left');
      expect(left['finishedAt'], isA<String>());
      expect(await service.watchMyEntry('shop_1').first, isNull);
    });
  });

  group('screens', () {
    setUp(loadTestSeed);

    testWidgets('staff queue screen lists the queue and adds a walk-in', (tester) async {
      final service = _seededService();
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(QueueScreen(shopId: 'shop_1', service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Waiting (3)'), findsOneWidget);
      expect(find.text('In the chair (1)'), findsOneWidget);
      expect(find.text('Dawit Bekele'), findsOneWidget);
      expect(find.text('Serving Abel Tesfaye'), findsWidgets); // barber_1's chip
      expect(find.text('about 10 min'), findsOneWidget);
      expect(find.text('3 waiting, about 35 min'), findsOneWidget);

      await tester.tap(find.byKey(const Key('queueAddWalkIn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('queueWalkInName')), 'Hana Tadesse');
      await tester.tap(find.byKey(const Key('queueWalkInSubmit')));
      await tester.pumpAndSettle();
      expect(find.text('Hana Tadesse'), findsOneWidget);
      expect(find.text('Waiting (4)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('queueLeft_queue_1_2')));
      await tester.pumpAndSettle();
      expect(find.text('Dawit Bekele'), findsNothing);
      expect(find.text('Waiting (3)'), findsOneWidget);
    });

    testWidgets('customer card shows the wait, their place and leaves (Amharic too)', (tester) async {
      final service = _seededService();
      repo.switchRole(UserRole.customer);
      final shop = repo.getShopById('shop_1')!;
      await tester.pumpWidget(_app(Scaffold(body: QueueStatusCard(shop: shop, service: service))));
      await tester.pumpAndSettle();
      expect(find.text('3 waiting, about 35 min'), findsOneWidget);
      expect(find.text('You are number 2 in line, about 10 min'), findsOneWidget);

      await tester.tap(find.byKey(const Key('queueLeaveButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('queueLeaveConfirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queueJoinButton')), findsOneWidget);
      expect(find.text('2 waiting, about 20 min'), findsOneWidget);

      await tester.tap(find.byKey(const Key('queueJoinButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('queueJoinSubmit')));
      await tester.pumpAndSettle();
      expect(find.text('You are number 3 in line, about 20 min'), findsOneWidget);

      await tester
          .pumpWidget(_app(Scaffold(body: QueueStatusCard(shop: shop, service: service)), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3ኛ'), findsOneWidget);
    });
  });
}
