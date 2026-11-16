// End-to-end walkthrough (local mode, demo seed) of the wave-5 features
// working together:
//   admin shop management -> temporary-password barber accounts ->
//   early-finish notices -> subscription receipts.
//
// admin suspends shop_1 (hidden for customers, booking refused) and
// reactivates it; the owner creates a barber login with a temporary
// password; the barber logs in, sets up the profile, is forced to change the
// password and lands on the barber dashboard; customers A and B book that
// barber today (A first); the barber finishes A early and B is told
// 'barberFreeEarly'; the owner submits a 1400 ETB telebirr receipt, the admin
// approves it and the subscription is extended by 90 days; the same
// transaction id is refused afterwards.

import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/notifications/screens/notifications_screen.dart' show isEarlyFinishType;
import 'package:barbershop_booking/features/payments/receipts/subscription_receipts_service.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/main.dart' show RootGate;
import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/notification_service.dart';
import 'package:barbershop_booking/services/staff_account_service.dart' show BarberAccountCreated;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 08:00 in Addis Ababa (05:00 UTC).
final _morning = DateTime.utc(2026, 11, 20, 5, 0);

/// [hour]:[minute] on the Addis wall clock of Friday 20 Nov 2026.
DateTime _addis(int hour, int minute) => DateTime.utc(2026, 11, 20, hour, minute).subtract(const Duration(hours: 3));

const _admin = 'admin@example.com';
const _owner1 = 'owner.shop1@example.com'; // shop_1, active, ends in 25 days
const _owner2 = 'owner.shop2@example.com';
const _customerA = 'liya@example.com'; // user_cust_1 (English)
const _customerB = 'customer2@example.com'; // user_cust_2 (Amharic)

const _barberEmail = 'selam.newbarber@gmail.com';
const _tempPassword = 'Kx7m-Q2pab';
const _newPassword = 'SelamCuts26';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  testWidgets('wave 5: shop suspension, barber accounts, early finish and subscription receipts', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var clock = _morning;
    loadTestSeed(now: _morning);
    final repo = AppRepository.instance;
    repo.debugClock = () => clock;
    addTearDown(() => repo.debugClock = null);

    late NotificationService notifications;
    late SubscriptionReceiptsService receipts;
    late BarberAccountCreated created;

    await tester.runAsync(() async {
      notifications = NotificationService(repository: repo)..start();
      receipts = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _morning),
      );

      // 1. The admin suspends shop_1: hidden for customers, booking refused.
      repo.signInAsDemoUser(_admin);
      expect(repo.currentUser!.role, UserRole.admin);
      await repo.suspendShop('shop_1', 'Health inspection pending');
      final suspended = repo.getShopById('shop_1')!;
      expect(suspended.adminSuspended, isTrue);
      expect(suspended.adminSuspendedReason, 'Health inspection pending');
      expect(suspended.adminSuspendedBy, repo.currentUser!.uid);
      expect(suspended.subscriptionStatus, SubscriptionStatus.active, reason: 'separate from the subscription');

      repo.signInAsDemoUser(_customerA);
      expect(repo.getShops().any((s) => s.id == 'shop_1'), isFalse);
      final barber1 = repo.getBarbersForShop('shop_1').first;
      final service = repo.getServicesForShop('shop_1').first;
      await expectLater(
        repo.createBooking(
          shopId: 'shop_1',
          shopName: suspended.name,
          barberId: barber1.id,
          barberName: barber1.name,
          serviceId: service.id,
          serviceName: service.name,
          price: service.price,
          date: DateTime(2026, 11, 20),
          timeSlot: '04:00 PM',
          startAt: _addis(16, 0),
        ),
        throwsA(isA<AppStateException>().having((e) => e.code, 'code', AppErrorCode.shopNotTakingBookings)),
      );

      // ...and reactivates it.
      repo.signInAsDemoUser(_admin);
      await repo.reactivateShop('shop_1');
      expect(repo.getShopById('shop_1')!.adminSuspended, isFalse);
      expect(repo.getShopById('shop_1')!.adminSuspendedReason, isNull);
      repo.signInAsDemoUser(_customerA);
      expect(repo.getShops().any((s) => s.id == 'shop_1'), isTrue);

      // 2. The owner creates a barber login with a temporary password.
      repo.signInAsDemoUser(_owner1);
      created = await repo.addBarberWithAccount(
        shopId: 'shop_1',
        name: 'Selam Bekele',
        title: 'Fade Specialist',
        email: _barberEmail,
        phone: '0912 345 678',
        temporaryPassword: _tempPassword,
      );
      expect(created.temporaryPassword, _tempPassword);
      final invite = repo.getPendingBarberInvite(created.barberId)!;
      expect((invite.authUid, invite.mustChangePassword), (created.uid, true));

      // 3. The barber logs in, sets up the profile and must change the password.
      await repo.signOut();
      await repo.loginWithEmail(email: _barberEmail, password: _tempPassword);
      expect(repo.authStatus, AuthStatus.needsProfile);
      await repo.completeProfile(name: 'Selam Bekele', phone: repo.pendingPhone!);
      expect(repo.currentUser!.role, UserRole.barber);
      expect(repo.currentUser!.barberId, created.barberId);
      expect(repo.mustChangePassword, isTrue);
      await repo.completeRequiredPasswordChange(temporaryPassword: _tempPassword, newPassword: _newPassword);
      expect(repo.mustChangePassword, isFalse);
      expect(repo.authStatus, AuthStatus.signedIn);
    });

    // ...and lands on the barber dashboard.
    await tester.pumpWidget(_app(const RootGate()));
    await tester.pumpAndSettle();
    expect(find.byType(BarberDashboardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      // 4. Customers A (10:00) and B (11:00) book the new barber today.
      final shop = repo.getShopById('shop_1')!;
      final service = repo.getServicesForShop('shop_1').firstWhere((s) => s.durationMinutes >= 30);
      Future<Booking> book(String email, DateTime startAt, String slot) {
        repo.signInAsDemoUser(email);
        return repo.createBooking(
          shopId: shop.id,
          shopName: shop.name,
          barberId: created.barberId,
          barberName: 'Selam Bekele',
          serviceId: service.id,
          serviceName: service.name,
          price: service.price,
          date: DateTime(2026, 11, 20),
          timeSlot: slot,
          startAt: startAt,
          durationMinutes: service.durationMinutes,
        );
      }

      final a = await book(_customerA, _addis(10, 0), '10:00 AM');
      final b = await book(_customerB, _addis(11, 0), '11:00 AM');
      expect(a.status, BookingStatus.confirmed);
      expect(b.status, BookingStatus.confirmed);

      // 5. At 10:15 the barber finishes A early: B is told 'barberFreeEarly'.
      clock = _addis(10, 15);
      await repo.signOut();
      await repo.loginWithEmail(email: _barberEmail, password: _newPassword);
      expect(repo.getBarberForCurrentUser()?.id, created.barberId);
      await repo.updateBookingStatus(a.id, BookingStatus.completed);

      final done = repo.getBookingById(a.id)!;
      expect(done.status, BookingStatus.completed);
      expect(done.completedAt, clock);
      expect(repo.earlyFinishNoticeCount(a.id), 1);

      final early = notifications.local.inboxFor('user_cust_2').where((n) => isEarlyFinishType(n.type)).toList();
      expect(early, hasLength(1));
      final notice = early.single;
      expect(notice.type, NotificationTypes.barberFreeEarly);
      expect(notice.id, '${b.id}_early_${a.id}');
      expect(notice.bookingId, b.id);
      final expectedMinutes = (a.endAt.difference(clock).inMinutes ~/ 5) * 5;
      expect(notice.minutesEarly, expectedMinutes);
      expect(notifications.local.inboxFor('user_cust_1').where((n) => isEarlyFinishType(n.type)), isEmpty,
          reason: 'A is the finished booking');

      // 6. The owner pays 1400 ETB by telebirr and submits the receipt.
      clock = _addis(12, 0);
      repo.signInAsDemoUser(_owner1);
      final endsBefore = repo.getShopById('shop_1')!.subscriptionEndsAt!;
      expect(endsBefore.isAfter(clock), isTrue);
      final receipt = await receipts.submit(
        shopId: 'shop_1',
        method: ReceiptMethod.telebirr,
        transactionId: 'chk5 wave 26',
        amount: 1400,
      );
      expect(receipt.id, 'telebirr_CHK5WAVE26');
      expect(receipt.status, ReceiptStatus.pending);

      // 7. The admin approves it: +90 days from the current end.
      repo.signInAsDemoUser(_admin);
      expect((await receipts.watchForAdmin().first).map((p) => p.id), contains(receipt.id));
      final result = await receipts.approve(receipt.id);
      expect(result.durationDays, 90);
      final shopAfter = repo.getShopById('shop_1')!;
      expect(shopAfter.subscriptionEndsAt, endsBefore.add(const Duration(days: 90)));
      expect(shopAfter.subscriptionStatus, SubscriptionStatus.active);
      expect((await receipts.store.get(receipt.id))!.status, ReceiptStatus.verified);

      // 8. The same transaction id is refused, for this owner and any other.
      repo.signInAsDemoUser(_owner1);
      await expectLater(
        receipts.submit(shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: 'CHK5WAVE26', amount: 1400),
        throwsA(isA<ReceiptException>().having((e) => e.code, 'code', ReceiptErrorCode.duplicate)),
      );
      repo.signInAsDemoUser(_owner2);
      await expectLater(
        receipts.submit(shopId: 'shop_2', method: ReceiptMethod.telebirr, transactionId: 'chk5wave26', amount: 1400),
        throwsA(isA<ReceiptException>().having((e) => e.code, 'code', ReceiptErrorCode.duplicate)),
      );
      expect(repo.getShopById('shop_1')!.subscriptionEndsAt, endsBefore.add(const Duration(days: 90)));

      notifications.dispose();
    });
  });
}
