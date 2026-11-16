import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/features/customer/widgets/early_finish_banner.dart';
import 'package:barbershop_booking/features/notifications/screens/notifications_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/early_finish_service.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:barbershop_booking/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa (07:00 UTC).
final _now = DateTime.utc(2026, 11, 20, 7, 0);

/// [hour]:[minute] on the Addis wall clock of 20 Nov 2026 (+[dayOffset]).
DateTime _addis(int hour, int minute, {int dayOffset = 0}) =>
    DateTime.utc(2026, 11, 20 + dayOffset, hour, minute).subtract(const Duration(hours: 3));

Booking _booking(
  String id,
  DateTime start, {
  int minutes = 30,
  String barberId = 'barber_1',
  String shopId = 'shop_1',
  String? customerId,
  BookingStatus status = BookingStatus.confirmed,
}) {
  return Booking(
    id: id,
    shopId: shopId,
    shopName: 'Crown Cuts',
    barberId: barberId,
    barberName: 'Yonas',
    customerId: customerId ?? 'cust_$id',
    customerName: 'Customer $id',
    customerPhone: '+251911000000',
    serviceId: 'svc_1',
    serviceName: 'Skin Fade',
    price: 300,
    date: DateTime(2026, 11, 20),
    timeSlot: '',
    status: status,
    createdAt: DateTime.utc(2026, 11, 1),
    startAt: start,
    durationMinutes: minutes,
  );
}

/// The source booking: 09:40-10:30 Addis, in progress (finished at 10:00 it
/// is 30 minutes early).
final _source = _booking('src', _addis(9, 40), minutes: 50, status: BookingStatus.inProgress, customerId: 'user_cust_4');

/// The day around [_source]: six later confirmed bookings of the same barber
/// (one too many) and bookings that must never be told.
List<Booking> _day() => [
      _source,
      _booking('b1030', _addis(10, 30), customerId: 'user_cust_1'), // the next customer (English)
      _booking('b1100', _addis(11, 0), customerId: 'user_cust_2'), // Amharic
      _booking('b1230', _addis(12, 30)),
      _booking('b1300', _addis(13, 0)),
      _booking('b1330', _addis(13, 30)),
      _booking('b1400', _addis(14, 0)), // 6th: over the limit of 5
      _booking('pending', _addis(11, 30), status: BookingStatus.pending),
      _booking('cancelled', _addis(12, 0), status: BookingStatus.cancelled),
      _booking('otherBarber', _addis(10, 45), barberId: 'barber_2'),
      _booking('otherShop', _addis(10, 50), shopId: 'shop_2'),
      _booking('earlier', _addis(8, 0)), // already started / past
      _booking('tomorrow', _addis(9, 0, dayOffset: 1)),
    ];

const _expectedRecipients = ['b1030', 'b1100', 'b1230', 'b1300', 'b1330'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('minutes early', () {
    test('endAt - completedAt, rounded down to 5, clamped to 0..240', () {
      // _source ends 10:30 Addis = 07:30 UTC.
      expect(minutesEarly(_source, DateTime.utc(2026, 11, 20, 7, 0)), 30);
      expect(minutesEarly(_source, DateTime.utc(2026, 11, 20, 7, 3)), 25);
      expect(minutesEarly(_source, DateTime.utc(2026, 11, 20, 7, 28)), 0);
      expect(minutesEarly(_source, DateTime.utc(2026, 11, 20, 7, 30)), 0);
      expect(minutesEarly(_source, DateTime.utc(2026, 11, 20, 8, 0)), 0);
      final long = _booking('long', _addis(6, 0), minutes: 600);
      expect(minutesEarly(long, _addis(6, 5)), kEarlyFinishMaxMinutes);
    });

    test('only finishing before the scheduled end counts as early', () {
      expect(isEarlyFinish(_source, DateTime.utc(2026, 11, 20, 7, 29)), isTrue);
      expect(isEarlyFinish(_source, DateTime.utc(2026, 11, 20, 7, 30)), isFalse); // on time
      expect(isEarlyFinish(_source, DateTime.utc(2026, 11, 20, 7, 45)), isFalse); // late
    });
  });

  group('recipient selection', () {
    test('same barber and shop, confirmed, later today, soonest first, at most 5', () {
      final shuffled = _day().reversed.toList();
      final picked = earlyFinishRecipients(_source, shuffled, _now);
      expect(picked.map((b) => b.id), _expectedRecipients);
    });

    test('the Addis day (UTC+3) bounds "today", not the UTC day', () {
      final source = _booking('late', _addis(22, 30), minutes: 60, status: BookingStatus.inProgress);
      final now = _addis(23, 0); // 20:00 UTC
      final sameAddisDay = _booking('a2330', _addis(23, 30)); // 20:30 UTC
      final nextAddisDay = _booking('a0030', _addis(0, 30, dayOffset: 1)); // 21:30 UTC, same UTC day
      expect(earlyFinishRecipients(source, [source, sameAddisDay, nextAddisDay], now).map((b) => b.id), ['a2330']);
    });

    test('nobody later today means nobody is told', () {
      expect(earlyFinishRecipients(_source, [_source, _booking('tomorrow', _addis(9, 0, dayOffset: 1))], _now), isEmpty);
    });
  });

  group('notices', () {
    test('next customer: barberFreeEarly; the others: runningEarly; recipient language', () {
      final notices = planEarlyFinishNotices(_source, _day(), _now,
          languageOf: (uid) => uid == 'user_cust_1' ? 'en' : null);
      expect(notices.map((n) => n.bookingId), _expectedRecipients);
      expect(notices.first.type, NotificationTypes.barberFreeEarly);
      expect(notices.skip(1).map((n) => n.type).toSet(), {NotificationTypes.runningEarly});
      expect(notices.map((n) => n.minutesEarly).toSet(), {30});
      expect(notices.first.recipientUid, 'user_cust_1');

      // English for the customer whose language is known to be English.
      expect(notices.first.title, 'Your barber is free now');
      expect(notices.first.body, 'Yonas at Crown Cuts is free now — you can come in early for your 10:30 appointment.');
      // Unknown language: Amharic (the customer default), Ethiopian clock.
      expect(notices[1].title, 'ከፕሮግራሙ ቀድመው እየሰሩ ነው');
      expect(notices[1].body, contains('30 ደቂቃ'));
      expect(notices[1].body, contains('11:00 (ጠዋት 5:00)'));
    });

    test('English running-early copy', () {
      final text = renderEarlyFinishText(NotificationTypes.runningEarly, _booking('b', _addis(13, 0)), 25, language: 'en');
      expect(text.title, 'Running ahead of schedule');
      expect(text.body,
          'Yonas is running about 25 min ahead of schedule today; your 13:00 appointment may start earlier.');
      final am = renderEarlyFinishText(NotificationTypes.barberFreeEarly, _booking('b', _addis(13, 0)), 25);
      expect(am.body, contains('ቀድመው መምጣት ይችላሉ'));
      expect(am.body, contains('13:00 (ከሰዓት 7:00)'));
    });

    test('idempotent ids: {bookingId}_early_{sourceBookingId}', () {
      expect(earlyFinishNotificationId('b1030', 'src'), 'b1030_early_src');
      final a = planEarlyFinishNotices(_source, _day(), _now).map((n) => n.id).toList();
      final b = planEarlyFinishNotices(_source, _day().reversed, _now).map((n) => n.id).toList();
      expect(a, b);
      expect(a.first, 'b1030_early_src');
    });

    test('the document has exactly the keys the rules accept', () {
      final map = planEarlyFinishNotices(_source, _day(), _now).first.toMap();
      expect(map.keys.toSet(), {
        'type',
        'title',
        'body',
        'bookingId',
        'shopId',
        'barberId',
        'sourceBookingId',
        'minutesEarly',
        'read',
        'createdAt',
      });
      expect(map['read'], false);
      expect(map['minutesEarly'], isA<int>());
      expect(map['createdAt'], '2026-11-20T07:00:00.000Z');
      expect(map['sourceBookingId'], 'src');
      expect(map['shopId'], 'shop_1');
      expect(map['barberId'], 'barber_1');
    });

    test('not triggered when finishing on time or late', () {
      expect(planEarlyFinishNotices(_source, _day(), _source.endAt), isEmpty);
      expect(planEarlyFinishNotices(_source, _day(), _source.endAt.add(const Duration(minutes: 10))), isEmpty);
    });
  });

  group('banner window', () {
    AppNotification notice(String type, String bookingId, DateTime createdAt) => AppNotification(
          id: '${bookingId}_early_src',
          title: 't',
          body: 'b',
          type: type,
          bookingId: bookingId,
          createdAt: createdAt,
        );

    test('a barberFreeEarly notice for the booking younger than 60 min', () {
      final fresh = notice(NotificationTypes.barberFreeEarly, 'b1030', _now.subtract(const Duration(minutes: 59)));
      final stale = notice(NotificationTypes.barberFreeEarly, 'b1030', _now.subtract(const Duration(minutes: 61)));
      final running = notice(NotificationTypes.runningEarly, 'b1030', _now);
      final other = notice(NotificationTypes.barberFreeEarly, 'b1100', _now);
      expect(activeEarlyFinishNotice([fresh], 'b1030', _now), fresh);
      expect(activeEarlyFinishNotice([stale, running, other], 'b1030', _now), isNull);
    });
  });

  group('repository and local inbox', () {
    final repo = AppRepository.instance;

    void loadDay({List<Booking>? bookings}) {
      final seed = loadSeedDataset(now: _now);
      repo.loadSeed(SeedDataset(
        plans: seed.plans,
        users: seed.users,
        shops: seed.shops,
        services: seed.services,
        barbers: seed.barbers,
        bookings: bookings ?? _day(),
      ));
      repo.debugClock = () => _now;
    }

    tearDown(() => repo.debugClock = null);

    Map<String, List<AppNotification>> earlyInboxes(NotificationService svc) => {
          for (final uid in {for (final b in _day()) b.customerId})
            if (svc.local.inboxFor(uid).any((n) => isEarlyFinishType(n.type)))
              uid: svc.local.inboxFor(uid).where((n) => isEarlyFinishType(n.type)).toList(),
        };

    test('the barber finishes early: completedAt stored, the next 5 customers today are told', () async {
      loadDay();
      final notifications = NotificationService(repository: repo)..start();
      addTearDown(notifications.dispose);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');

      await repo.updateBookingStatus('src', BookingStatus.completed);

      final done = repo.getBookingById('src')!;
      expect(done.status, BookingStatus.completed);
      expect(done.completedAt, _now);
      expect(repo.earlyFinishNoticeCount('src'), 5);

      final inboxes = earlyInboxes(notifications);
      final expectedUids = {
        for (final b in _day())
          if (_expectedRecipients.contains(b.id)) b.customerId
      };
      expect(inboxes.keys.toSet(), expectedUids);
      final next = inboxes['user_cust_1']!.single;
      expect(next.id, 'b1030_early_src');
      expect(next.type, NotificationTypes.barberFreeEarly);
      expect(next.bookingId, 'b1030');
      expect(next.minutesEarly, 30);
      expect(next.title, 'Your barber is free now'); // user_cust_1 prefers English
      final second = inboxes['user_cust_2']!.single;
      expect(second.type, NotificationTypes.runningEarly);
      expect(second.title, 'ከፕሮግራሙ ቀድመው እየሰሩ ነው'); // user_cust_2 prefers Amharic

      // Delivering again (e.g. a second observe) adds nothing.
      final again = notifications.local.deliverEarlyFinish(done, repo.getAllBookings(), users: repo.getAllUsers());
      expect(again, isEmpty);
    });

    test('the owner finishing early also tells the customers', () async {
      loadDay();
      final notifications = NotificationService(repository: repo)..start();
      addTearDown(notifications.dispose);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');

      await repo.updateBookingStatus('src', BookingStatus.completed);

      expect(repo.earlyFinishNoticeCount('src'), 5);
      expect(earlyInboxes(notifications).length, 5);
    });

    test('finishing late tells nobody (completedAt is still stored)', () async {
      loadDay();
      final late = _source.endAt.add(const Duration(minutes: 5));
      repo.debugClock = () => late;
      final notifications = NotificationService(repository: repo)..start();
      addTearDown(notifications.dispose);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');

      await repo.updateBookingStatus('src', BookingStatus.completed);

      expect(repo.getBookingById('src')!.completedAt, late);
      expect(repo.earlyFinishNoticeCount('src'), 0);
      expect(earlyInboxes(notifications), isEmpty);
    });

    test('the inbox re-renders early notices in the viewer language from their booking', () async {
      loadDay();
      final n = AppNotification(
        id: 'b1030_early_src',
        title: 'stored',
        body: 'stored',
        type: NotificationTypes.barberFreeEarly,
        bookingId: 'b1030',
        createdAt: _now,
        minutesEarly: 30,
      );
      expect(earlyFinishDisplayText(n, 'en', repository: repo)!.title, 'Your barber is free now');
      expect(earlyFinishDisplayText(n, 'am', repository: repo)!.title, 'ፀጉር አስተካካይዎ አሁን ነፃ ናቸው');
      final unknown = AppNotification(
          id: 'x', title: 't', body: 'b', type: NotificationTypes.barberFreeEarly, bookingId: 'nope', createdAt: _now);
      expect(earlyFinishDisplayText(unknown, 'en', repository: repo), isNull);
    });
  });

  group('customer banner', () {
    final repo = AppRepository.instance;

    testWidgets('the next customer sees "free now" with call / directions; later customers do not', (tester) async {
      final seed = loadSeedDataset(now: _now);
      repo.loadSeed(SeedDataset(
        plans: seed.plans,
        users: seed.users,
        shops: seed.shops,
        services: seed.services,
        barbers: seed.barbers,
        bookings: _day(),
      ));
      repo.debugClock = () => _now;
      addTearDown(() => repo.debugClock = null);
      final notifications = NotificationService(repository: repo)..start();
      notifications.onNewNotification = (_) {};
      addTearDown(notifications.dispose);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.updateBookingStatus('src', BookingStatus.completed);
      repo.switchRole(UserRole.customer);
      expect(repo.currentUser!.uid, 'user_cust_1');

      final shop = repo.getShopById('shop_1');
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Column(children: [
            EarlyFinishBanner(booking: repo.getBookingById('b1030')!, shop: shop, now: () => _now, service: notifications),
            EarlyFinishBanner(booking: repo.getBookingById('b1100')!, shop: shop, now: () => _now, service: notifications),
          ]),
        ),
      ));
      expect(find.byKey(const ValueKey('early-finish-banner-b1030')), findsOneWidget);
      expect(find.text('Your barber is free now — come in early'), findsOneWidget);
      expect(find.byKey(const ValueKey('early-finish-banner-b1100')), findsNothing);
      if (shop!.phone.trim().isNotEmpty) {
        expect(find.byKey(const ValueKey('early-finish-call-b1030')), findsOneWidget);
      }

      // An hour later the banner is gone.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EarlyFinishBanner(
            booking: repo.getBookingById('b1030')!,
            shop: shop,
            now: () => _now.add(const Duration(minutes: 61)),
            service: notifications,
          ),
        ),
      ));
      expect(find.byKey(const ValueKey('early-finish-banner-b1030')), findsNothing);
    });
  });

  group('Firestore writes', () {
    test('completeBooking writes exactly status + completedAt; notices go to each customer inbox', () async {
      final db = FakeFirebaseFirestore();
      final store =
          FirestoreDataStore(cache: DataCache(), firestore: db, onChanged: () {}, onCurrentUserChanged: (_) {});
      await db.collection('bookings').doc('src').set({..._source.toMap()});

      await store.completeBooking(_source, completedAt: _now);
      final booking = (await db.collection('bookings').doc('src').get()).data()!;
      expect(booking['status'], 'completed');
      expect(booking['completedAt'], '2026-11-20T07:00:00.000Z');

      final notices = planEarlyFinishNotices(_source, _day(), _now);
      await store.writeEarlyFinishNotices(notices);
      for (final n in notices) {
        final doc = await db.collection('users').doc(n.recipientUid).collection('notifications').doc(n.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data(), n.toMap());
        expect(AppNotification.fromMap(doc.data()!, doc.id).minutesEarly, 30);
      }
    });
  });
}
