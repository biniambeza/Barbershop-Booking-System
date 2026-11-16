import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/models/invite_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:barbershop_booking/services/shop_deletion.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 20, 7, 0);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreDataStore store;
  late SeedDataset seed;

  setUp(() async {
    seed = loadSeedDataset(now: _now);
    db = FakeFirebaseFirestore();
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
      final ref = db.collection('barbershops').doc(b.shopId).collection('barbers').doc(b.id);
      await ref.set(b.toMap()..removeWhere((_, v) => v == null));
      await ref.collection('private').doc('contact').set({'phone': '+251911000000'});
      await ref.collection('slotLocks').doc('l1').set({'startAt': 'x'});
      await ref.collection('timeOff').doc('t1').set({'startAt': 'x'});
    }
    for (final b in seed.bookings) {
      await db.collection('bookings').doc(b.id).set(b.toMap());
    }
    final shop = db.collection('barbershops').doc('shop_1');
    for (final sub in ['queue', 'queueSummary', 'reviews', 'stats', 'clients', 'payouts']) {
      await shop.collection(sub).doc('d').set({'x': 1});
    }
    await db.collection('invites').doc('new.barber@gmail.com').set(UserInvite(
          email: 'new.barber@gmail.com',
          role: UserRole.barber,
          name: 'N',
          shopId: 'shop_1',
          barberId: 'bx',
          createdBy: 'owner_1',
          createdAt: _now,
          authUid: 'uid_new',
          mustChangePassword: true,
        ).toMap());
    store = FirestoreDataStore(cache: DataCache(), firestore: db, onChanged: () {}, onCurrentUserChanged: (_) {});
  });

  test('the cascade writes the documented shapes and leaves nothing under the shop', () async {
    await store.recordShopDeletion(ShopDeletionRecord(
      shopId: 'shop_1',
      shopName: 'Shop',
      requestedBy: 'user_admin_1',
      requestedAt: _now,
      staffUids: const ['owner_1'],
      barberAccountUids: const ['uid_new'],
    ));
    final record = (await db.collection(kShopDeletionsCollection).doc('shop_1').get()).data()!;
    expect(record['staffUids'], ['owner_1']);
    expect(record['barberAccountUids'], ['uid_new']);

    final upcoming = await store.upcomingBookingsOfShop('shop_1', _now);
    expect(upcoming.every((b) => b.shopId == 'shop_1' && !b.startAt.isBefore(_now)), isTrue);
    final cancels = planShopBookingCancellations('shop_1', upcoming, _now);
    expect(cancels, isNotEmpty);
    await store.cancelBookingsForShopDeletion(cancels, cancelledBy: 'user_admin_1');
    for (final c in cancels) {
      final b = (await db.collection('bookings').doc(c.booking.id).get()).data()!;
      expect((b['status'], b['cancelledBy'], b['cancelReason']), ('cancelled', 'user_admin_1', 'shop_deleted'));
      final n = (await db.collection('users').doc(c.booking.customerId).collection('notifications').doc(c.notice.id).get())
          .data()!;
      expect(n['type'], 'shopDeleted');
      expect(n['bookingId'], c.booking.id);
    }

    final staff = await store.staffOfShop('shop_1');
    expect(staff.map((u) => u.uid), containsAll(['owner_1', 'barber_user_1', 'barber_user_2']));
    await store.revokeShopStaff('shop_1', planShopStaffRevocations('shop_1', 'Shop', staff, _now));
    for (final uid in ['owner_1', 'barber_user_1', 'barber_user_2']) {
      final u = (await db.collection('users').doc(uid).get()).data()!;
      expect(u['role'], 'customer');
      expect(u.containsKey('shopId'), isFalse);
      expect(u.containsKey('barberId'), isFalse);
      expect((await db.collection('users').doc(uid).collection('notifications').doc('shopRemoved_shop_1').get()).exists,
          isTrue);
    }
    expect((await db.collection('invites').doc('new.barber@gmail.com').get()).exists, isFalse);

    await store.deleteShopData('shop_1');
    final shop = db.collection('barbershops').doc('shop_1');
    expect((await shop.get()).exists, isTrue); // the document goes last
    for (final sub in ['barbers', 'services', ...kShopSubcollections]) {
      expect((await shop.collection(sub).get()).docs, isEmpty, reason: sub);
    }
    for (final b in seed.barbers.where((b) => b.shopId == 'shop_1')) {
      for (final sub in kBarberSubcollections) {
        expect((await shop.collection('barbers').doc(b.id).collection(sub).get()).docs, isEmpty, reason: sub);
      }
    }
    await store.deleteShopDoc('shop_1');
    expect((await shop.get()).exists, isFalse);

    // Other shops untouched; past bookings kept.
    expect((await db.collection('barbershops').doc('shop_2').collection('services').get()).docs, isNotEmpty);
    final past = seed.bookings.where((b) => b.shopId == 'shop_1' && b.startAt.isBefore(_now));
    for (final b in past) {
      expect((await db.collection('bookings').doc(b.id).get()).data()!['status'], b.status.name);
    }
  });
}
