import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bounds of the customer / owner / barber booking listeners: every upcoming
/// booking, plus at most N past bookings from the last 90 days.
void main() {
  final now = DateTime.utc(2026, 11, 13, 9, 7, 30);

  late FakeFirebaseFirestore db;
  late DataCache cache;
  late FirestoreDataStore store;

  Booking booking(String id, DateTime startAt, {String customerId = 'cust', String barberId = 'b1', String shopId = 's1'}) =>
      Booking(
        id: id,
        shopId: shopId,
        shopName: 'Shop',
        barberId: barberId,
        barberName: 'Yonas',
        customerId: customerId,
        customerName: 'Liya',
        customerPhone: '+251911000301',
        serviceId: 'srv',
        serviceName: 'Cut',
        price: 300,
        date: DateTime(startAt.year, startAt.month, startAt.day),
        timeSlot: '',
        status: BookingStatus.confirmed,
        createdAt: startAt.subtract(const Duration(days: 1)),
        startAt: startAt,
        endAt: startAt.add(const Duration(minutes: 30)),
        durationMinutes: 30,
      );

  Future<void> put(Booking b) => db.collection('bookings').doc(b.id).set(b.toMap());

  AppUser user(String uid, UserRole role, {String? shopId, String? barberId}) => AppUser(
        uid: uid,
        name: uid,
        phone: '+251911000301',
        role: role,
        shopId: shopId,
        barberId: barberId,
        createdAt: now,
      );

  setUp(() async {
    db = FakeFirebaseFirestore();
    cache = DataCache();
    store = FirestoreDataStore(
      cache: cache,
      firestore: db,
      onChanged: () {},
      onCurrentUserChanged: (_) {},
      clock: () => now,
    );
    // Upcoming, including far ahead and one starting this very minute.
    await put(booking('future_1', now.add(const Duration(hours: 2))));
    await put(booking('future_30d', now.add(const Duration(days: 30))));
    await put(booking('this_minute', DateTime.utc(2026, 11, 13, 9, 7)));
    // Recent past (in progress / earlier today, last month).
    await put(booking('past_1h', now.subtract(const Duration(hours: 1))));
    await put(booking('past_80d', now.subtract(const Duration(days: 80))));
    // Older than the window.
    await put(booking('past_100d', now.subtract(const Duration(days: 100))));
    // Someone else's booking at another barber and shop.
    await put(booking('other_customer', now.add(const Duration(hours: 3)), customerId: 'cust2', barberId: 'b2'));
    await put(booking('other_shop', now.add(const Duration(hours: 3)), customerId: 'cust2', shopId: 's2'));
    // Legacy booking without the appointment interval.
    final legacy = booking('legacy', now.subtract(const Duration(days: 1))).toMap()
      ..remove('startAt')
      ..remove('endAt');
    await db.collection('bookings').doc('legacy').set(legacy);
  });

  tearDown(() => store.stop());

  test('bookingWindowBounds: whole minutes, 90 days of history', () {
    final (nowIso, cutoffIso) = FirestoreDataStore.bookingWindowBounds(now);
    expect(nowIso, '2026-11-13T09:07:00.000Z');
    expect(cutoffIso, '2026-08-15T09:07:00.000Z');
    // Local times are converted to UTC first.
    expect(FirestoreDataStore.bookingWindowBounds(now.toLocal()).$1, nowIso);
  });

  test('customer: every upcoming booking plus the last 90 days, nothing older', () async {
    await store.start(user('cust', UserRole.customer));
    expect(cache.bookings.keys.toSet(), {'future_1', 'future_30d', 'this_minute', 'past_1h', 'past_80d'});
  });

  test('owner: the shop\'s bookings in the window, all barbers', () async {
    await store.start(user('owner', UserRole.barbershopOwner, shopId: 's1'));
    expect(
      cache.bookings.keys.toSet(),
      {'future_1', 'future_30d', 'this_minute', 'past_1h', 'past_80d', 'other_customer'},
    );
  });

  test('barber: own bookings in the window', () async {
    await store.start(user('barber', UserRole.barber, shopId: 's1', barberId: 'b2'));
    expect(cache.bookings.keys.toSet(), {'other_customer'});
  });

  test('history is capped at the limit; upcoming bookings are never cut', () async {
    for (var i = 1; i <= FirestoreDataStore.customerHistoryLimit + 5; i++) {
      await put(booking('old_$i', now.subtract(Duration(hours: 2 + i))));
    }
    await store.start(user('cust', UserRole.customer));
    final cutoff = DateTime.utc(2026, 11, 13, 9, 7);
    final past = cache.bookings.values.where((b) => b.startAt.isBefore(cutoff));
    expect(past, hasLength(FirestoreDataStore.customerHistoryLimit));
    expect(cache.bookings.keys, containsAll(['future_1', 'future_30d', 'this_minute']));
    expect(cache.bookings.containsKey('past_100d'), false);
  });

  test('the history query keeps the newest past bookings', () async {
    for (var i = 1; i <= 10; i++) {
      await put(booking('old_$i', now.subtract(Duration(hours: 2 + i))));
    }
    final base = db.collection('bookings').where('customerId', isEqualTo: 'cust');
    final history = await FirestoreDataStore.historyBookingsQuery(base, now, 3).get();
    expect(history.docs.map((d) => d.id), ['past_1h', 'old_1', 'old_2']);
    final upcoming = await FirestoreDataStore.upcomingBookingsQuery(base, now).get();
    // (fake_cloud_firestore does not order range queries reliably, so
    // only the set is checked here.)
    expect(upcoming.docs.map((d) => d.id).toSet(), {'this_minute', 'future_1', 'future_30d'});
  });

  test('a booking pushed out of the limited history leaves the cache', () async {
    final small = FirestoreDataStore(
      cache: cache,
      firestore: db,
      onChanged: () {},
      onCurrentUserChanged: (_) {},
      clock: () => now,
    );
    await small.start(user('cust', UserRole.customer));
    expect(cache.bookings.containsKey('past_80d'), true);
    await db.collection('bookings').doc('past_80d').delete();
    await pumpEventQueue();
    expect(cache.bookings.containsKey('past_80d'), false);
    await small.stop();
  });

  test('new and cancelled bookings reach the listener', () async {
    await store.start(user('cust', UserRole.customer));
    await put(booking('new_one', now.add(const Duration(days: 2))));
    await db.collection('bookings').doc('future_1').update({'status': 'cancelled'});
    await pumpEventQueue();
    expect(cache.bookings.containsKey('new_one'), true);
    expect(cache.bookings['future_1']!.status, BookingStatus.cancelled);
  });
}
