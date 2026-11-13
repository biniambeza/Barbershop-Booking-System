import 'package:barbershop_booking/features/notifications/screens/notifications_screen.dart';
import 'package:barbershop_booking/features/notifications/widgets/notification_bell.dart';
import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('booking event detection (mirrors the Cloud Function)', () {
    test('new bookings', () {
      expect(bookingEventType(null, BookingStatus.pending, isNew: true), NotificationTypes.created);
      expect(bookingEventType(null, BookingStatus.confirmed, isNew: true), NotificationTypes.confirmed);
      expect(bookingEventType(null, BookingStatus.completed, isNew: true), isNull);
    });

    test('status changes', () {
      expect(bookingEventType(BookingStatus.pending, BookingStatus.confirmed, isNew: false), NotificationTypes.confirmed);
      expect(bookingEventType(BookingStatus.confirmed, BookingStatus.cancelled, isNew: false), NotificationTypes.cancelled);
      expect(bookingEventType(BookingStatus.confirmed, BookingStatus.inProgress, isNew: false), NotificationTypes.started);
      expect(bookingEventType(BookingStatus.inProgress, BookingStatus.completed, isNew: false), NotificationTypes.completed);
      expect(bookingEventType(BookingStatus.confirmed, BookingStatus.confirmed, isNew: false), isNull);
      expect(bookingEventType(BookingStatus.confirmed, BookingStatus.pending, isNew: false), isNull);
    });
  });

  group('formatting', () {
    test('ETB amounts are grouped', () {
      expect(formatEtb(1250), '1,250 ETB');
      expect(formatEtb(150), '150 ETB');
      expect(formatEtb(99.5), '99.50 ETB');
      expect(formatEtb(1234567), '1,234,567 ETB');
    });

    test('times use the Addis wall clock (UTC+3)', () {
      expect(formatAddisWhen(DateTime.utc(2026, 11, 13, 7, 30)), 'Fri 13 Nov 2026, 10:30');
      expect(formatAddisWhen(DateTime.utc(2026, 11, 13, 22, 0)), 'Sat 14 Nov 2026, 01:00');
    });

    test('relative time', () {
      final now = DateTime.utc(2026, 11, 13, 12);
      expect(relativeTime(now, now: now), 'Just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2 d ago');
    });
  });

  group('push registration helpers', () {
    test('device id is a stable 16-hex-char hash of the token', () {
      final id = deviceIdForToken('fcm:token-abc_123');
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(deviceIdForToken('fcm:token-abc_123'), id);
      expect(deviceIdForToken('fcm:token-abc_124'), isNot(id));
    });

    test('device doc has exactly the contract keys', () {
      final doc = deviceDocument('tok', 'android', DateTime.utc(2026, 11, 13, 9));
      expect(doc.keys.toSet(), {'token', 'platform', 'updatedAt'});
      expect(doc['updatedAt'], '2026-11-13T09:00:00.000Z');
    });

    test('push data maps to the inbox doc id', () {
      expect(notificationIdFromPushData({'bookingId': 'b1', 'type': 'confirmed'}), 'b1_confirmed');
      expect(notificationIdFromPushData({'type': 'confirmed'}), isNull);
    });
  });

  group('local inbox (demo mode)', () {
    late NotificationService service;
    late List<AppNotification> banners;
    final repo = AppRepository.instance;

    setUp(() {
      loadTestSeed();
      service = NotificationService(repository: repo);
      banners = [];
      service.onNewNotification = banners.add;
      service.start();
    });

    tearDown(() => service.dispose());

    test('loading the dataset does not notify anyone', () {
      repo.switchRole(UserRole.customer);
      expect(service.notifications, isEmpty);
      loadTestSeed();
      expect(service.local.inboxFor('user_cust_1'), isEmpty);
      expect(service.local.inboxFor('owner_1'), isEmpty);
    });

    test('a started appointment reaches customer, barber and owner', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(repo.currentUser!.uid, 'barber_user_1');

      await repo.updateBookingStatus('book_1', BookingStatus.inProgress);

      for (final uid in ['user_cust_1', 'barber_user_1', 'owner_1']) {
        final inbox = service.local.inboxFor(uid);
        expect(inbox, hasLength(1), reason: uid);
        expect(inbox.single.id, 'book_1_started');
        expect(inbox.single.type, NotificationTypes.started);
        expect(inbox.single.bookingId, 'book_1');
        expect(inbox.single.read, isFalse);
      }
      expect(service.local.inboxFor('user_cust_1').single.title, 'Your appointment has started');
      expect(service.local.inboxFor('owner_1').single.title, 'Appointment started');
      // The signed-in barber sees it in their own inbox and as a banner.
      expect(service.unreadCount, 1);
      expect(banners.map((n) => n.id), ['book_1_started']);
    });

    test('whoever cancels is not notified; the others are told who did it', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(repo.currentUser!.uid, 'owner_1');

      await repo.updateBookingStatus('book_4', BookingStatus.cancelled);

      expect(service.local.inboxFor('owner_1'), isEmpty);
      expect(service.notifications, isEmpty);
      expect(banners, isEmpty);
      final customer = service.local.inboxFor('user_cust_4').single;
      expect(customer.title, 'Booking cancelled');
      expect(customer.body, contains('was cancelled by the shop.'));
      expect(service.local.inboxFor('barber_user_2').single.body, contains('by the shop'));
    });

    test('mark read and mark all read', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.updateBookingStatus('book_1', BookingStatus.inProgress);
      await repo.updateBookingStatus('book_2', BookingStatus.inProgress);
      expect(service.unreadCount, 2);

      await service.markRead('book_2_started');
      expect(service.unreadCount, 1);
      expect(service.local.inboxFor('barber_user_1').firstWhere((n) => n.id == 'book_2_started').read, isTrue);

      await service.markAllRead();
      expect(service.unreadCount, 0);

      // Inboxes survive a persona switch.
      repo.switchRole(UserRole.customer);
      expect(repo.currentUser!.uid, 'user_cust_1');
      expect(service.notifications.map((n) => n.id), ['book_1_started']);
      expect(service.unreadCount, 1);
    });

    test('signing out empties the visible inbox', () async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.updateBookingStatus('book_1', BookingStatus.inProgress);
      expect(service.notifications, hasLength(1));
      await repo.signOut();
      expect(service.notifications, isEmpty);
      expect(service.unreadCount, 0);
    });
  });

  group('Firestore inbox', () {
    late FakeFirebaseFirestore db;

    Future<void> seedInbox() async {
      final col = db.collection('users').doc('u1').collection('notifications');
      await col.doc('b1_confirmed').set({
        'title': 'Booking confirmed',
        'body': 'Your Haircut ...',
        'type': 'confirmed',
        'bookingId': 'b1',
        'read': false,
        'createdAt': '2026-11-13T08:00:00.000Z',
      });
      await col.doc('b1_reminder2h').set({
        'title': 'Your appointment is in 2 hours',
        'body': '...',
        'type': 'reminder2h',
        'bookingId': 'b1',
        'read': false,
        'createdAt': '2026-11-13T10:00:00.000Z',
      });
      await db.collection('users').doc('u2').collection('notifications').doc('x').set({
        'title': 'Other user',
        'body': '',
        'type': 'created',
        'read': false,
        'createdAt': '2026-11-13T11:00:00.000Z',
      });
    }

    setUp(() async {
      db = FakeFirebaseFirestore();
      await seedInbox();
    });

    test('watch returns only the user\'s notifications, newest first', () async {
      final items = await FirestoreInbox(db).watch('u1').first;
      expect(items.map((n) => n.id), ['b1_reminder2h', 'b1_confirmed']);
      expect(items.first.isReminder, isTrue);
      expect(items.first.createdAt, DateTime.utc(2026, 11, 13, 10));
    });

    test('markRead writes only the read flag', () async {
      await FirestoreInbox(db).markRead('u1', 'b1_confirmed');
      final doc = await db.collection('users').doc('u1').collection('notifications').doc('b1_confirmed').get();
      expect(doc.data()!['read'], isTrue);
      expect(doc.data()!['title'], 'Booking confirmed');
    });

    test('markAllRead updates every listed doc', () async {
      await FirestoreInbox(db).markAllRead('u1', ['b1_confirmed', 'b1_reminder2h']);
      final items = await FirestoreInbox(db).watch('u1').first;
      expect(items.every((n) => n.read), isTrue);
      final other = await db.collection('users').doc('u2').collection('notifications').doc('x').get();
      expect(other.data()!['read'], isFalse);
    });
  });

  group('inbox UI', () {
    final repo = AppRepository.instance;
    late NotificationService service;

    setUp(() {
      loadTestSeed();
      service = NotificationService(repository: repo)..onNewNotification = (_) {};
      service.start();
    });

    tearDown(() => service.dispose());

    testWidgets('empty state, then bell badge and tap-to-read', (tester) async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(appBar: AppBar(actions: [NotificationBell(service: service)])),
      ));
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);

      await repo.updateBookingStatus('book_1', BookingStatus.inProgress);
      await tester.pump();
      expect(find.text('Appointment started'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      await tester.tap(find.text('Appointment started'));
      await tester.pump();
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(service.unreadCount, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
    });
  });
}
