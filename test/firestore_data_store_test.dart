import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/invite_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Writes the seed dataset the way tool/seed/seed.js does.
Future<void> writeSeed(FakeFirebaseFirestore db, SeedDataset seed) async {
  for (final p in seed.plans) {
    await db.collection('plans').doc(p.id).set(p.toMap());
  }
  for (final u in seed.users) {
    await db.collection('users').doc(u.uid).set(u.toMap());
  }
  for (final s in seed.shops) {
    await db.collection('barbershops').doc(s.id).set(s.toMap()..removeWhere((_, v) => v == null));
  }
  for (final s in seed.services) {
    await db.collection('barbershops').doc(s.shopId).collection('services').doc(s.id).set(s.toMap());
  }
  for (final b in seed.barbers) {
    await db
        .collection('barbershops')
        .doc(b.shopId)
        .collection('barbers')
        .doc(b.id)
        .set(b.toMap()..removeWhere((_, v) => v == null));
  }
  for (final b in seed.bookings) {
    await db.collection('bookings').doc(b.id).set(b.toMap());
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late DataCache cache;
  late FirestoreDataStore store;
  late SeedDataset seed;
  AppUser? lastUserDoc;
  var changes = 0;

  AppUser user(String uid) => seed.users.firstWhere((u) => u.uid == uid);

  setUp(() async {
    seed = loadSeedDataset();
    db = FakeFirebaseFirestore();
    await writeSeed(db, seed);
    cache = DataCache();
    changes = 0;
    store = FirestoreDataStore(
      cache: cache,
      firestore: db,
      onChanged: () => changes++,
      onCurrentUserChanged: (u) => lastUserDoc = u,
    );
  });

  tearDown(() => store.stop());

  test('customer sees non-suspended shops, all their services/barbers and only own bookings', () async {
    await store.start(user('user_cust_1'));
    expect(cache.shops.keys, isNot(contains('shop_6')));
    expect(cache.shops.length, 5);
    expect(cache.services.values.any((s) => s.shopId == 'shop_1'), true);
    expect(cache.barbers.containsKey('barber_1'), true);
    expect(cache.bookings.values.every((b) => b.customerId == 'user_cust_1'), true);
    expect(cache.bookings.keys, containsAll(['book_1', 'book_5', 'book_7']));
    expect(cache.users.keys, ['user_cust_1']);
    expect(cache.invites, isEmpty);
    expect(lastUserDoc?.uid, 'user_cust_1');
    expect(changes, greaterThan(0));
  });

  test('a shop that gets suspended disappears from the customer listing', () async {
    await store.start(user('user_cust_1'));
    expect(cache.shops.containsKey('shop_2'), true);
    await db.collection('barbershops').doc('shop_2').update({'subscriptionStatus': 'suspended'});
    await pumpEventQueue();
    expect(cache.shops.containsKey('shop_2'), false);
  });

  test('owner sees only their shop and its bookings, invites and staff', () async {
    await db.collection('invites').doc('+251912000999').set(UserInvite(
          phone: '+251912000999',
          role: UserRole.barber,
          name: 'New',
          shopId: 'shop_1',
          barberId: 'barber_1_3',
          createdBy: 'owner_1',
          createdAt: DateTime.now(),
        ).toMap());
    await db.collection('invites').doc('+251912000888').set(UserInvite(
          phone: '+251912000888',
          role: UserRole.barber,
          name: 'Other shop',
          shopId: 'shop_2',
          barberId: 'barber_2_2',
          createdBy: 'owner_2',
          createdAt: DateTime.now(),
        ).toMap());

    await store.start(user('owner_1'));
    expect(cache.shops.keys, ['shop_1']);
    expect(cache.services.values.every((s) => s.shopId == 'shop_1'), true);
    expect(cache.barbers.values.every((b) => b.shopId == 'shop_1'), true);
    expect(cache.bookings.values.every((b) => b.shopId == 'shop_1'), true);
    expect(cache.bookings.length, 5);
    expect(cache.invites.keys, ['+251912000999']);
    expect(cache.users.values.every((u) => u.shopId == 'shop_1'), true);
    expect(cache.plans.length, 3);
  });

  test('barber sees only their own bookings', () async {
    await store.start(user('barber_user_2'));
    expect(cache.shops.keys, ['shop_1']);
    expect(cache.bookings.keys, ['book_4']);
  });

  test('admin sees everything', () async {
    await store.start(user('user_admin_1'));
    expect(cache.shops.length, 6);
    expect(cache.bookings.length, seed.bookings.length);
    expect(cache.users.length, seed.users.length);
    expect(cache.services.length, seed.services.length);
    expect(cache.barbers.length, seed.barbers.length);
  });

  test('stop() clears the cache', () async {
    await store.start(user('user_admin_1'));
    await store.stop();
    expect(cache.shops, isEmpty);
    expect(cache.bookings, isEmpty);
    expect(store.isRunning, false);
  });

  test('writes go to Firestore and come back through the listeners', () async {
    await store.start(user('user_admin_1'));

    final booking = seed.bookings.first.copyWith(id: 'book_new', status: BookingStatus.pending);
    await store.createBooking(booking);
    final doc = await db.collection('bookings').doc('book_new').get();
    expect(doc.data()!['startAt'], booking.startAt.toIso8601String());
    expect(doc.data()!['paymentStatus'], 'unpaid');
    await pumpEventQueue();
    expect(cache.bookings['book_new']?.status, BookingStatus.pending);

    await store.updateBookingStatus(booking, BookingStatus.cancelled);
    await pumpEventQueue();
    expect(cache.bookings['book_new']?.status, BookingStatus.cancelled);

    // Profile updates never touch protected fields and clear null fields.
    final shop = cache.shops['shop_1']!;
    await store.updateShopProfile(shop.copyWith(name: 'Renamed', isVerified: false));
    final shopDoc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
    expect(shopDoc['name'], 'Renamed');
    expect(shopDoc['isVerified'], true);
    expect(shopDoc['subscriptionPlan'], 'pro');

    await store.updateShopSubscription('shop_1', plan: 'basic', status: SubscriptionStatus.pastDue);
    final subDoc = (await db.collection('barbershops').doc('shop_1').get()).data()!;
    expect(subDoc['subscriptionStatus'], 'past_due');
    expect(subDoc.containsKey('subscriptionEndsAt'), false);
  });

  test('deleteShop removes the subcollections and invites too', () async {
    await db.collection('invites').doc('+251912000777').set(UserInvite(
          phone: '+251912000777',
          role: UserRole.barbershopOwner,
          name: 'X',
          shopId: 'shop_4',
          createdBy: 'user_admin_1',
          createdAt: DateTime.now(),
        ).toMap());
    await store.start(user('user_admin_1'));
    await store.deleteShop('shop_4');
    expect((await db.collection('barbershops').doc('shop_4').get()).exists, false);
    expect((await db.collection('barbershops').doc('shop_4').collection('services').get()).docs, isEmpty);
    expect((await db.collection('barbershops').doc('shop_4').collection('barbers').get()).docs, isEmpty);
    expect((await db.collection('invites').doc('+251912000777').get()).exists, false);
    await pumpEventQueue();
    expect(cache.shops.containsKey('shop_4'), false);
  });
}
