import 'package:barbershop_booking/data/addis_time.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  final repo = AppRepository.instance;

  group('Addis time helpers', () {
    test('parse and format display slots', () {
      expect(parseTimeSlot('02:30 PM'), (14, 30));
      expect(parseTimeSlot('12:00 PM'), (12, 0));
      expect(parseTimeSlot('12:15 AM'), (0, 15));
      expect(parseTimeSlot('9:45 am'), (9, 45));
      expect(parseTimeSlot('16:00'), (16, 0));
      expect(parseTimeSlot('25:00'), isNull);
      expect(parseTimeSlot('13:00 PM'), isNull);
      expect(formatTimeSlot(14, 30), '02:30 PM');
      expect(formatTimeSlot(0, 5), '12:05 AM');
    });

    test('Addis local time is UTC+3', () {
      expect(addisLocalToUtc(2026, 11, 20, 9, 0), DateTime.utc(2026, 11, 20, 6, 0));
      expect(addisLocalToUtc(2026, 11, 20, 1, 0), DateTime.utc(2026, 11, 19, 22, 0));
      expect(appointmentStartUtc(DateTime(2026, 11, 20, 18, 42), '02:30 PM'), DateTime.utc(2026, 11, 20, 11, 30));
      expect(addisNow(DateTime.utc(2026, 11, 20, 22, 30)).day, 21);
    });
  });

  group('Seed dataset', () {
    final now = DateTime.utc(2026, 11, 20, 7, 0); // 10:00 in Addis
    final seed = loadSeedDataset(now: now);

    test('has the Addis shops with stable demo ids', () {
      expect(seed.shops.length, 6);
      expect(seed.shops.map((s) => s.id), containsAll(['shop_1', 'shop_2', 'shop_3', 'shop_4', 'shop_5', 'shop_6']));
      expect(seed.shops.map((s) => s.subCity).toSet().length, greaterThanOrEqualTo(5));
      for (final s in seed.shops) {
        expect(s.city, 'Addis Ababa');
        expect(s.phone, matches(r'^\+251[79]\d{8}$'));
        expect(['trial', 'basic', 'pro'], contains(s.subscriptionPlan));
        expect(s.subscriptionEndsAt, isNotNull);
      }
      expect(seed.shops.firstWhere((s) => s.id == 'shop_6').isSuspended, true);
      expect(seed.barbers.any((b) => b.id == 'barber_1' && b.shopId == 'shop_1'), true);
      expect(seed.plans.map((p) => p.id), ['trial', 'basic', 'pro']);
    });

    test('keeps the demo sign-in accounts', () {
      AppUser user(String phone) => seed.users.firstWhere((u) => u.phone == phone);
      expect(user('+251911000001').role, UserRole.admin);
      expect(user('+251911000101').role, UserRole.barbershopOwner);
      expect(user('+251911000101').shopId, 'shop_1');
      expect(user('+251911000201').role, UserRole.barber);
      expect(user('+251911000201').barberId, 'barber_1');
      expect(user('+251911000301').role, UserRole.customer);
      for (final u in seed.users) {
        expect(u.phone, matches(r'^\+251[79]\d{8}$'));
      }
    });

    test('prices are in a realistic ETB range', () {
      for (final s in seed.services) {
        expect(s.price, inInclusiveRange(100, 2000), reason: s.name);
      }
    });

    test('bookings are resolved relative to today in Addis', () {
      final b2 = seed.bookings.firstWhere((b) => b.id == 'book_2');
      // dayOffset 0, 14:15 Addis = 11:15 UTC on the same day.
      expect(b2.startAt, DateTime.utc(2026, 11, 20, 11, 15));
      expect(b2.timeSlot, '02:15 PM');
      expect(b2.date, DateTime(2026, 11, 20));
      final service = seed.services.firstWhere((s) => s.id == b2.serviceId);
      expect(b2.durationMinutes, service.durationMinutes);
      expect(b2.endAt, b2.startAt.add(Duration(minutes: service.durationMinutes)));
      expect(b2.price, service.price);
      expect(b2.customerName, 'Natnael Assefa');
      expect(b2.shopName, 'Crown Cuts Bole');

      final b1 = seed.bookings.firstWhere((b) => b.id == 'book_1');
      expect(b1.startAt, DateTime.utc(2026, 11, 21, 8, 15));
      final b5 = seed.bookings.firstWhere((b) => b.id == 'book_5');
      expect(b5.paymentMethod, PaymentMethod.chapa);
      expect(b5.paymentStatus, PaymentStatus.paid);
    });
  });

  group('Models', () {
    test('legacy documents get backward-compatible defaults', () {
      final shop = Barbershop.fromMap({'name': 'Old', 'ownerId': 'o'}, 's');
      expect(shop.subCity, '');
      expect(shop.landmark, isNull);
      expect(shop.subscriptionPlan, 'trial');
      expect(shop.subscriptionStatus, SubscriptionStatus.trialing);

      final barber = Barber.fromMap({'name': 'B', 'shopId': 's'}, 'b');
      expect(barber.workingDays, isNull);
      expect(barber.startHour, isNull);

      final booking = Booking.fromMap({
        'shopId': 's',
        'date': '2026-11-20T00:00:00.000',
        'timeSlot': '10:30 AM',
        'status': 'confirmed',
        'createdAt': '2026-11-19T10:00:00.000Z',
      }, 'bk');
      expect(booking.startAt, DateTime.utc(2026, 11, 20, 7, 30));
      expect(booking.durationMinutes, 30);
      expect(booking.endAt, DateTime.utc(2026, 11, 20, 8, 0));
      expect(booking.paymentStatus, PaymentStatus.unpaid);
      expect(booking.paymentMethod, PaymentMethod.cash);

      final user = AppUser.fromMap({'name': 'U', 'role': 'customer'}, 'u');
      expect(user.language, isNull);
      expect(user.preferredLanguage, 'am');
    });

    test('contract fields round-trip', () {
      final ends = DateTime.utc(2026, 12, 1);
      final shop = Barbershop(
        id: 's',
        ownerId: 'o',
        name: 'N',
        description: 'D',
        address: 'A',
        city: 'Addis Ababa',
        subCity: 'Bole',
        landmark: 'Edna Mall',
        phone: '+251911000000',
        imageUrl: 'https://x.y/z.jpg',
        subscriptionPlan: 'pro',
        subscriptionStatus: SubscriptionStatus.pastDue,
        subscriptionEndsAt: ends,
      );
      final map = shop.toMap();
      expect(map['subscriptionStatus'], 'past_due');
      expect(map['subscriptionEndsAt'], '2026-12-01T00:00:00.000Z');
      final back = Barbershop.fromMap(map, 's');
      expect(back.subscriptionStatus, SubscriptionStatus.pastDue);
      expect(back.subscriptionEndsAt, ends);
      expect(back.landmark, 'Edna Mall');
      // Owners' profile writes never carry the protected fields.
      expect(shop.toProfileMap().keys,
          isNot(anyElement(isIn(['ownerId', 'isVerified', 'rating', 'reviewCount', 'subscriptionPlan', 'subscriptionStatus', 'subscriptionEndsAt']))));

      final booking = loadSeedDataset().bookings.first;
      final bMap = booking.toMap();
      expect(bMap['startAt'], endsWith('Z'));
      expect(bMap['paymentStatus'], 'unpaid');
      expect(bMap['paymentMethod'], 'cash');
      final bBack = Booking.fromMap(bMap, booking.id);
      expect(bBack.startAt, booking.startAt);
      expect(bBack.endAt, booking.endAt);
      expect(bBack.durationMinutes, booking.durationMinutes);
    });
  });

  group('Local repository', () {
    setUp(loadTestSeed);

    test('customers do not see suspended shops; admins do', () {
      repo.switchRole(UserRole.customer);
      expect(repo.getShops().any((s) => s.id == 'shop_6'), false);
      expect(repo.getAllBarbersWithShops().any((b) => b.shop.id == 'shop_6'), false);
      repo.switchRole(UserRole.admin);
      expect(repo.getShops().any((s) => s.id == 'shop_6'), true);
    });

    test('a suspended shop cannot be booked', () async {
      repo.switchRole(UserRole.customer);
      expect(
        () => repo.createBooking(
          shopId: 'shop_6',
          shopName: 'Megenagna Express Cuts',
          barberId: 'barber_6_1',
          barberName: 'Bereket Wolde',
          serviceId: 'srv_6_1',
          serviceName: 'Quick Cut',
          price: 200,
          date: DateTime(2026, 11, 20),
          timeSlot: '10:30 AM',
        ),
        throwsStateError,
      );
    });

    test('createBooking stores the real interval in UTC with payment defaults', () async {
      repo.switchRole(UserRole.customer);
      final customer = repo.currentUser!;
      final booking = await repo.createBooking(
        shopId: 'shop_1',
        shopName: 'Crown Cuts Bole',
        barberId: 'barber_1',
        barberName: 'Yonas Tadesse',
        serviceId: 'srv_1_3', // 90 minutes
        serviceName: 'Full Grooming Package',
        price: 1200,
        date: DateTime(2026, 11, 20, 15, 12),
        timeSlot: '02:30 PM',
      );
      expect(booking.customerId, customer.uid);
      expect(booking.customerPhone, '+251911000301');
      expect(booking.startAt, DateTime.utc(2026, 11, 20, 11, 30));
      expect(booking.durationMinutes, 90);
      expect(booking.endAt, DateTime.utc(2026, 11, 20, 13, 0));
      expect(booking.paymentStatus, PaymentStatus.unpaid);
      expect(booking.paymentMethod, PaymentMethod.cash);
      expect(repo.getBookingById(booking.id), isNotNull);
      expect(repo.getCustomerBookings(customer.uid), contains(predicate<Booking>((b) => b.id == booking.id)));
    });

    test('createBooking requires a signed-in user', () async {
      await repo.signOut();
      expect(
        () => repo.createBooking(
          shopId: 'shop_1',
          shopName: 'x',
          barberId: 'barber_1',
          barberName: 'x',
          serviceId: 'srv_1_1',
          serviceName: 'x',
          price: 450,
          date: DateTime(2026, 11, 20),
          timeSlot: '10:30 AM',
        ),
        throwsStateError,
      );
    });

    test('bookings are listed newest appointment first', () {
      final list = repo.getBookingsForBarber('barber_1');
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].startAt.isAfter(list[i].startAt) || list[i - 1].startAt == list[i].startAt, true);
      }
    });

    test('owner profile edits cannot change verification, rating or subscription', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_4');
      final shop = repo.getShopById('shop_4')!;
      await repo.updateShop(shop.copyWith(
        name: 'Sarbet Fade Studio & Spa',
        landmark: 'Opposite Sarbet Total',
        isVerified: true,
        rating: 5.0,
        subscriptionPlan: 'pro',
        subscriptionStatus: SubscriptionStatus.active,
      ));
      final after = repo.getShopById('shop_4')!;
      expect(after.name, 'Sarbet Fade Studio & Spa');
      expect(after.landmark, 'Opposite Sarbet Total');
      expect(after.isVerified, shop.isVerified);
      expect(after.rating, shop.rating);
      expect(after.subscriptionPlan, 'trial');
      expect(after.subscriptionStatus, SubscriptionStatus.trialing);
    });

    test('admin can change a subscription', () async {
      repo.switchRole(UserRole.admin);
      await repo.updateShopSubscription('shop_6', plan: 'basic', status: SubscriptionStatus.active);
      expect(repo.getShopById('shop_6')!.isSuspended, false);
      repo.switchRole(UserRole.customer);
      expect(repo.getShops().any((s) => s.id == 'shop_6'), true);
    });

    test('deleting a shop removes its services, barbers and invites', () async {
      repo.switchRole(UserRole.admin);
      await repo.addBarber(shopId: 'shop_3', name: 'Invited', title: 'Barber', phone: '0977001122');
      expect(repo.getPendingInvites().any((i) => i.shopId == 'shop_3'), true);
      await repo.deleteShop('shop_3');
      expect(repo.getShopById('shop_3'), isNull);
      expect(repo.getServicesForShop('shop_3'), isEmpty);
      expect(repo.getBarbersForShop('shop_3'), isEmpty);
      expect(repo.getPendingInvites().any((i) => i.shopId == 'shop_3'), false);
    });

    test('barber schedule fields are saved and can be cleared', () async {
      final barber = repo.getBarberById('barber_1_3')!;
      expect(barber.workingDays, [2, 3, 4, 5, 6, 7]);
      expect(barber.startHour, 12);
      await repo.updateBarber(Barber(
        id: barber.id,
        shopId: barber.shopId,
        name: barber.name,
        title: 'Senior Barber',
        rating: 1.0, // ignored
        specialties: barber.specialties,
      ));
      final after = repo.getBarberById('barber_1_3')!;
      expect(after.title, 'Senior Barber');
      expect(after.rating, barber.rating);
      expect(after.workingDays, isNull);
      expect(after.startHour, isNull);
    });

    test('users can set their name and language', () async {
      repo.switchRole(UserRole.customer);
      await repo.updateMyProfile(language: 'am', name: 'Liya G.');
      expect(repo.currentUser!.language, 'am');
      expect(repo.currentUser!.name, 'Liya G.');
      expect(repo.getAllUsers().firstWhere((u) => u.uid == repo.currentUser!.uid).language, 'am');
      expect(() => repo.updateMyProfile(language: 'fr'), throwsArgumentError);
    });

    test('plans are available', () {
      expect(repo.getPlan('pro')!.priceMonthlyEtb, 1200);
      expect(repo.getPlans().length, 3);
    });
  });
}
