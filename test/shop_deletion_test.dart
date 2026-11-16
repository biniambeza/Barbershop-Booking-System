import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/time_off_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/notification_service.dart';
import 'package:barbershop_booking/services/shop_deletion.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _booking(String id, {required BookingStatus status, required DateTime startAt, String customerId = 'user_cust_1'}) =>
    Booking(
      id: id,
      shopId: 'shop_1',
      shopName: 'Crown Cuts Bole',
      barberId: 'barber_1',
      barberName: 'B',
      customerId: customerId,
      customerName: 'C',
      customerPhone: '+251911000000',
      date: startAt,
      timeSlot: '10:00',
      serviceId: 'svc',
      serviceName: 'Cut',
      price: 300,
      durationMinutes: 30,
      startAt: startAt,
      status: status,
      createdAt: _now.subtract(const Duration(days: 3)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = AppRepository.instance;

  group('shop_deletion logic', () {
    test('only pending/confirmed bookings of the shop starting now or later are cancelled', () {
      final list = [
        _booking('a', status: BookingStatus.confirmed, startAt: _now.add(const Duration(hours: 1))),
        _booking('b', status: BookingStatus.pending, startAt: _now),
        _booking('c', status: BookingStatus.confirmed, startAt: _now.subtract(const Duration(minutes: 1))),
        _booking('d', status: BookingStatus.completed, startAt: _now.add(const Duration(hours: 2))),
        _booking('e', status: BookingStatus.cancelled, startAt: _now.add(const Duration(hours: 2))),
      ];
      final plan = planShopBookingCancellations('shop_1', list, _now, languageOf: (_) => 'en');
      expect(plan.map((p) => p.booking.id), ['b', 'a']);
      final n = plan.last.notice;
      expect(n.id, 'a_shopDeleted');
      expect(n.recipientUid, 'user_cust_1');
      expect(n.toMap(), {
        'type': 'shopDeleted',
        'title': 'Appointment cancelled',
        'body': 'Crown Cuts Bole is no longer on Crown & Blade, so your appointment on 20/11/2026 11:00 '
            'was cancelled. Please book at another barbershop.',
        'shopId': 'shop_1',
        'bookingId': 'a',
        'read': false,
        'createdAt': '2026-11-20T07:00:00.000Z',
      });
    });

    test('staff revocation touches only the shop owner and barbers; downgrade keeps the profile', () {
      final users = [
        AppUser(uid: 'o', name: 'O', role: UserRole.barbershopOwner, shopId: 's', createdAt: _now, language: 'en'),
        AppUser(uid: 'b', name: 'B', role: UserRole.barber, shopId: 's', barberId: 'x', createdAt: _now),
        AppUser(uid: 'other', name: 'X', role: UserRole.barber, shopId: 't', createdAt: _now),
        AppUser(uid: 'adm', name: 'A', role: UserRole.admin, shopId: 's', createdAt: _now),
      ];
      final plan = planShopStaffRevocations('s', 'Shop S', users, _now);
      expect(plan.map((p) => p.user.uid), ['o', 'b']);
      expect(plan.first.notice.id, 'shopRemoved_s');
      expect(plan.first.notice.title, 'Your barbershop was removed');
      expect(plan.last.notice.title, 'ፀጉር ቤትዎ ተወግዷል');
      expect(plan.first.notice.toMap().containsKey('bookingId'), isFalse);
      final down = downgradedToCustomer(users[1]);
      expect((down.role, down.shopId, down.barberId, down.name), (UserRole.customer, null, null, 'B'));
    });

    test('chunked', () {
      expect(chunked([1, 2, 3, 4, 5], 2), [
        [1, 2],
        [3, 4],
        [5]
      ]);
      expect(chunked(<int>[], 3), isEmpty);
    });
  });

  group('AppRepository.deleteShopConfirmed (local mode)', () {
    late NotificationService notifications;

    setUp(() {
      loadTestSeed(now: _now);
      notifications = NotificationService(repository: repo)..start();
    });
    tearDown(() => notifications.dispose());

    test('staff become customers, shop data is gone, upcoming bookings cancelled and notified, history kept', () async {
      repo.switchRole(UserRole.admin);
      final barbers = repo.getBarbersForShop('shop_1');
      expect(barbers, isNotEmpty);
      repo.loadDemoTimeOff([
        TimeOff(
          id: 'to1',
          shopId: 'shop_1',
          barberId: barbers.first.id,
          startAt: _now.add(const Duration(days: 2)),
          endAt: _now.add(const Duration(days: 2, hours: 2)),
          createdBy: 'owner_1',
          createdAt: _now,
        ),
      ]);
      await repo.addBarber(shopId: 'shop_1', name: 'Invited', title: 'Barber', email: 'invited.one@gmail.com');

      final before = {for (final b in repo.getAllBookings().where((b) => b.shopId == 'shop_1')) b.id: b};
      final upcoming = before.values.where((b) => isCancelledByShopDeletion(b, 'shop_1', _now)).toList();
      final kept = before.values.where((b) => !isCancelledByShopDeletion(b, 'shop_1', _now)).toList();
      expect(upcoming, isNotEmpty);
      expect(kept, isNotEmpty);
      final staff = repo
          .getAllUsers()
          .where((u) => u.shopId == 'shop_1' && (u.role == UserRole.barber || u.role == UserRole.barbershopOwner))
          .map((u) => u.uid)
          .toList();
      expect(staff, containsAll(['owner_1', 'barber_user_1', 'barber_user_2']));

      final preview = await repo.previewShopDeletion('shop_1');
      expect(preview.upcomingBookings, upcoming.length);
      expect(preview.staffAccounts, staff.length);
      expect(preview.barbers, repo.getBarbersForShop('shop_1').length);
      expect(preview.pendingInvites, greaterThanOrEqualTo(1));

      final steps = <ShopDeletionStep>[];
      final name = repo.getShopById('shop_1')!.name;
      await repo.deleteShopConfirmed('shop_1', name, onStep: steps.add);
      expect(steps, ShopDeletionStep.values);

      // Shop and its data.
      expect(repo.getShopById('shop_1'), isNull);
      expect(repo.getBarbersForShop('shop_1'), isEmpty);
      expect(repo.getServicesForShop('shop_1'), isEmpty);
      expect(await repo.watchTimeOff('shop_1', barbers.first.id).first, isEmpty);
      expect(repo.getPendingInvites().where((i) => i.shopId == 'shop_1'), isEmpty);

      // Staff are customers now, with a notice.
      for (final uid in staff) {
        final u = repo.getAllUsers().firstWhere((u) => u.uid == uid);
        expect((u.role, u.shopId, u.barberId), (UserRole.customer, null, null), reason: uid);
        final inbox = notifications.local.inboxFor(uid);
        expect(inbox.where((n) => n.id == 'shopRemoved_shop_1' && n.type == NotificationTypes.shopRemoved), hasLength(1));
      }

      // Upcoming bookings cancelled, each customer told once (no generic
      // "cancelled" notice on top).
      for (final b in upcoming) {
        final now = repo.getBookingById(b.id)!;
        expect(now.status, BookingStatus.cancelled);
        expect(now.cancelReason, kShopDeletedCancelReason);
        final inbox = notifications.local.inboxFor(b.customerId).where((n) => n.bookingId == b.id).toList();
        expect(inbox.map((n) => n.type), [NotificationTypes.shopDeleted], reason: b.id);
      }
      // Past bookings stay as they were.
      for (final b in kept) {
        expect(repo.getBookingById(b.id)!.status, b.status, reason: b.id);
      }
    });

    test('a deleted shop\'s owner signs in as a customer and sees the notice once', () async {
      repo.switchRole(UserRole.admin);
      await repo.deleteShopConfirmed('shop_1', repo.getShopById('shop_1')!.name);
      final shown = <AppNotification>[];
      notifications.onNewNotification = shown.add;

      await repo.signOut();
      repo.signInAsDemoUser('owner.shop1@example.com');
      expect(repo.currentUser!.role, UserRole.customer);
      expect(repo.currentUser!.shopId, isNull);
      expect(shown.map((n) => n.type), [NotificationTypes.shopRemoved]);

      // Signing in again in the same session does not repeat it.
      await repo.signOut();
      repo.signInAsDemoUser('owner.shop1@example.com');
      expect(shown, hasLength(1));
    });

    test('running the delete again after a completed run is refused (shop gone); the cascade itself is idempotent',
        () async {
      repo.switchRole(UserRole.admin);
      final name = repo.getShopById('shop_2')!.name;
      await repo.deleteShop('shop_2');
      final users = repo.getAllUsers().map((u) => '${u.uid}:${u.role.name}:${u.shopId}').toList();
      await repo.deleteShop('shop_2'); // e.g. a retry after a lost response
      expect(repo.getAllUsers().map((u) => '${u.uid}:${u.role.name}:${u.shopId}').toList(), users);
      await expectLater(repo.deleteShopConfirmed('shop_2', name), throwsA(isA<AdminShopException>()));
    });

    test('only an admin may delete', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(repo.deleteShopConfirmed('shop_1', repo.getShopById('shop_1')!.name),
          throwsA(isA<AdminShopException>()));
      expect(repo.getShopById('shop_1'), isNotNull);
    });
  });
}
