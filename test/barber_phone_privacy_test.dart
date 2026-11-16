// Private barber phone: barber profiles are public, so the phone lives in
// barbershops/{shopId}/barbers/{barberId}/private/contact and reaches a
// customer only through their own confirmed booking (`barberPhone`).
import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _booking(BookingStatus status, {String? barberPhone}) => Booking(
      id: 'b',
      shopId: 's',
      shopName: 'Shop',
      barberId: 'br',
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
      durationMinutes: 30,
      barberPhone: barberPhone,
    );

void main() {
  group('models', () {
    test('the public barber doc never carries phone or email', () {
      final b = Barber(
        id: 'br',
        shopId: 's',
        name: 'B',
        title: 'T',
        avatarUrl: '',
        phone: '+251911000201',
        email: 'b@example.com',
      );
      expect(b.toMap().containsKey('phone'), isFalse);
      expect(b.toMap().containsKey('email'), isFalse);
      expect(b.toProfileMap().containsKey('phone'), isFalse);
      expect(b.toProfileMap().containsKey('email'), isFalse);
      expect(b.hasLegacyContactFields, isTrue);
      expect(b.copyWith(clearContact: true).hasLegacyContactFields, isFalse);
    });

    test('a legacy public doc with a phone is read (so it can be migrated)', () {
      final legacy = Barber.fromMap({'shopId': 's', 'name': 'B', 'phone': '+251911000201'}, 'br');
      expect(legacy.phone, '+251911000201');
      expect(legacy.hasLegacyContactFields, isTrue);
      final clean = Barber.fromMap({'shopId': 's', 'name': 'B', 'phone': 42}, 'br');
      expect(clean.phone, isNull);
      expect(clean.hasLegacyContactFields, isFalse);
    });

    test('booking.barberPhone is visible only while confirmed or in progress', () {
      const phone = '+251911000201';
      expect(_booking(BookingStatus.confirmed, barberPhone: phone).visibleBarberPhone, phone);
      expect(_booking(BookingStatus.inProgress, barberPhone: phone).visibleBarberPhone, phone);
      expect(_booking(BookingStatus.pending, barberPhone: phone).visibleBarberPhone, isNull);
      expect(_booking(BookingStatus.completed, barberPhone: phone).visibleBarberPhone, isNull);
      expect(_booking(BookingStatus.cancelled, barberPhone: phone).visibleBarberPhone, isNull);
      expect(_booking(BookingStatus.confirmed, barberPhone: '  ').visibleBarberPhone, isNull);
      expect(_booking(BookingStatus.confirmed).visibleBarberPhone, isNull);
    });

    test('barberPhone is read from the doc but never part of the create map', () {
      final b = _booking(BookingStatus.confirmed, barberPhone: '+251911000201');
      expect(b.toMap().containsKey('barberPhone'), isFalse);
      final read = Booking.fromMap({...b.toMap(), 'barberPhone': '+251911000201'}, 'b');
      expect(read.barberPhone, '+251911000201');
    });
  });

  group('seed', () {
    test('seeded barbers have no public phone; phones go to the private map', () {
      final seed = loadSeedDataset(now: _now);
      expect(seed.barbers.every((b) => b.phone == null), isTrue);
      expect(seed.barberPhones['barber_1'], '+251911000201');
      final b1 = seed.bookings.firstWhere((b) => b.id == 'book_1'); // confirmed, barber_1
      expect(b1.barberPhone, '+251911000201');
      for (final b in seed.bookings) {
        if (b.status != BookingStatus.confirmed && b.status != BookingStatus.inProgress) {
          expect(b.barberPhone, isNull, reason: '${b.id} (${b.status})');
        }
      }
    });
  });

  group('repository (local mode)', () {
    final repo = AppRepository.instance;
    setUp(() => loadTestSeed(now: _now));

    test('only admin, the shop owner and that barber see the private phone', () {
      repo.switchRole(UserRole.customer);
      expect(repo.getBarberPhone('barber_1'), isNull);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      expect(repo.getBarberPhone('barber_1'), isNull);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(repo.getBarberPhone('barber_1'), '+251911000201');
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(repo.getBarberPhone('barber_1'), '+251911000201');
      expect(repo.getBarberPhone('barber_2'), isNull);
      repo.switchRole(UserRole.admin);
      expect(repo.getBarberPhone('barber_1'), '+251911000201');
    });

    test('accepting a request copies the phone into the booking for the customer', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_3');
      expect(repo.getBookingById('book_6')!.status, BookingStatus.pending);
      expect(repo.getBookingById('book_6')!.visibleBarberPhone, isNull);
      await repo.acceptBookingRequest('book_6');
      final after = repo.getBookingById('book_6')!;
      expect(after.status, BookingStatus.confirmed);
      expect(after.barberPhone, '+251911000103');
      expect(after.visibleBarberPhone, '+251911000103');
    });

    test('updateBarberPhone: validated, stored privately, shared with confirmed bookings', () async {
      repo.switchRole(UserRole.customer);
      await repo.updateBarberPhone('barber_1', '0911000999'); // no-op for customers
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(repo.getBarberPhone('barber_1'), '+251911000201');
      await expectLater(repo.updateBarberPhone('barber_1', '12345'), throwsA(isA<AppException>()));
      await repo.updateBarberPhone('barber_1', '0911000999');
      expect(repo.getBarberPhone('barber_1'), '+251911000999');
      expect(repo.getBarberById('barber_1')!.phone, isNull);
      expect(await repo.shareBarberPhonesWithBookings(), greaterThan(0));
      expect(repo.getBookingById('book_1')!.barberPhone, '+251911000999'); // confirmed, upcoming
      await repo.updateBarberPhone('barber_1', ' ');
      expect(repo.getBarberPhone('barber_1'), isNull);
    });

    test('legacy public phones are migrated by the owner only (idempotent)', () async {
      final seed = loadSeedDataset(now: _now);
      final phones = Map<String, String>.of(seed.barberPhones)..remove('barber_2');
      repo.loadSeed(SeedDataset(
        plans: seed.plans,
        users: seed.users,
        shops: seed.shops,
        services: seed.services,
        barbers: [
          for (final b in seed.barbers) b.id == 'barber_2' ? b.copyWith(phone: '0911000202', email: 'x@example.com') : b,
        ],
        bookings: seed.bookings,
        barberPhones: phones,
      ));
      repo.debugClock = () => _now;

      repo.switchRole(UserRole.customer);
      expect(await repo.migrateLegacyBarberContacts(), 0);
      expect(repo.getBarberById('barber_2')!.hasLegacyContactFields, isTrue);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      expect(await repo.migrateLegacyBarberContacts(), 0); // not their barber

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.migrateLegacyBarberContacts();
      await pumpEventQueue();
      expect(repo.getBarberById('barber_2')!.hasLegacyContactFields, isFalse);
      expect(repo.getBarberPhone('barber_2'), '+251911000202');
      expect(await repo.migrateLegacyBarberContacts(), 0); // nothing left
    });

    test('addBarber keeps the phone off the public profile', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.addBarber(shopId: 'shop_1', name: 'New Barber', title: 'Barber', phone: '0911555666');
      final added = repo.getBarbersForShop('shop_1').firstWhere((b) => b.name == 'New Barber');
      expect(added.phone, isNull);
      expect(repo.getBarberPhone(added.id), '+251911555666');
    });
  });

  group('FirestoreDataStore', () {
    late FakeFirebaseFirestore db;
    late DataCache cache;
    late FirestoreDataStore store;
    const shopPath = 'barbershops/shop_1';
    const barberPath = '$shopPath/barbers/barber_1';
    const contactPath = '$barberPath/private/contact';

    setUp(() async {
      db = FakeFirebaseFirestore();
      cache = DataCache();
      store = FirestoreDataStore(cache: cache, firestore: db, onChanged: () {}, onCurrentUserChanged: (_) {});
      await db.doc(barberPath).set({
        'shopId': 'shop_1',
        'name': 'Yonas',
        'title': 'Barber',
        'avatarUrl': '',
        'phone': '+251911000201',
        'email': 'yonas@example.com',
      });
    });

    tearDown(() => store.stop());

    test('barberContactPath', () {
      expect(FirestoreDataStore.barberContactPath('shop_1', 'barber_1'), contactPath);
    });

    test('migrateBarberContact moves the phone to private/contact and strips the public doc', () async {
      final legacy = Barber.fromMap((await db.doc(barberPath).get()).data()!, 'barber_1');
      await store.migrateBarberContact(legacy, phone: '+251911000201');
      final pub = (await db.doc(barberPath).get()).data()!;
      expect(pub.containsKey('phone'), isFalse);
      expect(pub.containsKey('email'), isFalse);
      expect(pub['name'], 'Yonas');
      expect((await db.doc(contactPath).get()).data(), {'phone': '+251911000201'});

      // Idempotent: a second run (e.g. another device) keeps the existing contact.
      await db.doc(contactPath).set({'phone': '+251911000999'});
      await store.migrateBarberContact(legacy, phone: '+251911000201');
      expect((await db.doc(contactPath).get()).data(), {'phone': '+251911000999'});
    });

    test('addBarber writes the phone only to private/contact', () async {
      final b = Barber(id: 'barber_new', shopId: 'shop_1', name: 'N', title: 'T', avatarUrl: '');
      await store.addBarber(b, null, phone: '+251911555666');
      expect((await db.doc('$shopPath/barbers/barber_new').get()).data()!.containsKey('phone'), isFalse);
      expect((await db.doc('$shopPath/barbers/barber_new/private/contact').get()).data(), {'phone': '+251911555666'});
    });

    test('setBarberPhone sets and removes the contact; shareBarberPhone writes only barberPhone', () async {
      await store.setBarberPhone('shop_1', 'barber_1', '+251911000777');
      expect((await db.doc(contactPath).get()).data(), {'phone': '+251911000777'});
      await store.setBarberPhone('shop_1', 'barber_1', null);
      expect((await db.doc(contactPath).get()).exists, isFalse);

      final booking = _booking(BookingStatus.confirmed);
      await db.doc('bookings/b').set(booking.toMap());
      await store.shareBarberPhone(booking, '+251911000201');
      final data = (await db.doc('bookings/b').get()).data()!;
      expect(data['barberPhone'], '+251911000201');
      expect(data['status'], 'confirmed');
    });

    test('the owner listens to the contact docs of their barbers', () async {
      await db.doc(shopPath).set({'name': 'Shop', 'ownerId': 'owner_1', 'subscriptionStatus': 'active'});
      await db.doc(contactPath).set({'phone': '+251911000201'});
      final owner = AppUser(
        uid: 'owner_1',
        name: 'Owner',
        email: 'owner@example.com',
        role: UserRole.barbershopOwner,
        shopId: 'shop_1',
        createdAt: _now,
      );
      await store.start(owner);
      await pumpEventQueue();
      expect(cache.barberPhones['barber_1'], '+251911000201');
      await db.doc(contactPath).delete();
      await pumpEventQueue();
      expect(cache.barberPhones.containsKey('barber_1'), isFalse);
    });
  });
}
