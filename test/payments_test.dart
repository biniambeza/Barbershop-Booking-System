import 'dart:io';

import 'package:barbershop_booking/features/admin/screens/admin_subscriptions_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/features/payments/widgets/subscription_banner.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_subscription_screen.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/plan_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  final repo = AppRepository.instance;
  late LocalPaymentBackend backend;
  late PaymentService service;

  setUp(() {
    loadTestSeed(now: _now);
    backend = LocalPaymentBackend(repository: repo, clock: () => _now);
    service = PaymentService(backend: backend, repository: repo);
    PaymentService.instance = service;
  });

  Future<PaymentException> failure(Future<Object?> future) async {
    try {
      await future;
    } on PaymentException catch (e) {
      return e;
    }
    fail('expected a PaymentException');
  }

  group('period maths (mirrors functions/payments/src/logic/period.ts)', () {
    test('addMonthsUtc clamps the day and rolls the year', () {
      expect(addMonthsUtc(DateTime.utc(2027, 1, 31, 10), 1), DateTime.utc(2027, 2, 28, 10));
      expect(addMonthsUtc(DateTime.utc(2028, 1, 31), 1), DateTime.utc(2028, 2, 29));
      expect(addMonthsUtc(DateTime.utc(2026, 12, 15), 1), DateTime.utc(2027, 1, 15));
      expect(addMonthsUtc(DateTime.utc(2026, 11, 30), 14), DateTime.utc(2028, 1, 30));
      expect(addMonthsUtc(DateTime.utc(2026, 1, 31), -2), DateTime.utc(2025, 11, 30));
    });

    test('extendSubscriptionEnd extends from a future end, else from now', () {
      final future = _now.add(const Duration(days: 10));
      expect(extendSubscriptionEnd(future, _now), addMonthsUtc(future, 1));
      expect(extendSubscriptionEnd(_now.subtract(const Duration(days: 3)), _now), addMonthsUtc(_now, 1));
      expect(extendSubscriptionEnd(null, _now, 3), addMonthsUtc(_now, 3));
    });

    test('subscriptionDaysLeft rounds up and goes negative after the end', () {
      expect(subscriptionDaysLeft(null, _now), isNull);
      expect(subscriptionDaysLeft(_now.add(const Duration(days: 2, hours: 1)), _now), 3);
      expect(subscriptionDaysLeft(_now.add(const Duration(hours: 1)), _now), 1);
      expect(subscriptionDaysLeft(_now, _now), 0);
      expect(subscriptionDaysLeft(_now.subtract(const Duration(days: 2)), _now), -2);
    });
  });

  group('helpers', () {
    test('callable error codes become friendly messages', () {
      expect(paymentErrorMessage('unavailable'), contains('Chapa'));
      expect(paymentErrorMessage('already-exists'), 'This booking is already paid.');
      expect(paymentErrorMessage('failed-precondition', 'This booking was cancelled.'), 'This booking was cancelled.');
      expect(paymentErrorMessage('failed-precondition', 'Payments are not configured (PAYMENT_RETURN_URL).'),
          contains('not set up'));
      expect(paymentErrorMessage('internal', 'INTERNAL'), contains('could not be completed'));
      expect(paymentExceptionFrom(StateError('x')).code, 'unknown');
    });

    test('paymentIdFromReturnUri reads paymentId or the cb- txRef', () {
      expect(PaymentService.paymentIdFromReturnUri(Uri.parse('https://app.example/pay?paymentId=abc&txRef=cb-abc')), 'abc');
      expect(PaymentService.paymentIdFromReturnUri(Uri.parse('https://app.example/?trx_ref=cb-xyz')), 'xyz');
      expect(PaymentService.paymentIdFromReturnUri(Uri.parse('https://app.example/')), isNull);
      expect(PaymentService.paymentIdFromReturnUri(Uri.parse('https://app.example/?paymentId=a%2Fb')), isNull);
    });

    test('validatePlan', () {
      const ok = SubscriptionPlan(id: 'basic', name: 'Basic', priceMonthlyEtb: 500, maxBarbers: 3);
      expect(validatePlan(ok), isNull);
      expect(validatePlan(ok.copyWith(maxBarbers: -1)), isNull);
      expect(validatePlan(ok.copyWith(maxBarbers: 0)), isNotNull);
      expect(validatePlan(ok.copyWith(priceMonthlyEtb: 0)), isNotNull);
      expect(validatePlan(ok.copyWith(name: ' ')), isNotNull);
      expect(validatePlan(const SubscriptionPlan(id: 'gold', name: 'Gold', priceMonthlyEtb: 9, maxBarbers: 1)), isNotNull);
      expect(validatePlan(const SubscriptionPlan(id: 'trial', name: 'Trial', priceMonthlyEtb: 0, maxBarbers: 3)), isNull);
    });

    test('plan limits and purchasability', () {
      final pro = repo.getPlan('pro')!;
      expect(pro.isPurchasable, isTrue);
      expect(repo.getPlan('trial')!.isPurchasable, isFalse);
      const unlimited = SubscriptionPlan(id: 'pro', name: 'Pro', priceMonthlyEtb: 1200, maxBarbers: -1);
      expect(unlimited.allowsBarbers(500), isTrue);
      expect(unlimited.barberLimitLabel, 'Unlimited barbers');
      expect(checkPlanFitsShop(unlimited.copyWith(maxBarbers: 1), 2)?.code, 'failed-precondition');
    });

    test('subscription banner messages', () {
      Barbershop shop(SubscriptionStatus s, int days) => repo.getShopById('shop_1')!.copyWith(
            subscriptionStatus: s,
            subscriptionEndsAt: _now.add(Duration(days: days)),
          );
      expect(SubscriptionBanner.messageFor(shop(SubscriptionStatus.active, 25), _now), isNull);
      expect(SubscriptionBanner.messageFor(shop(SubscriptionStatus.trialing, 3), _now), contains('free trial ends in 3 days'));
      expect(SubscriptionBanner.messageFor(shop(SubscriptionStatus.pastDue, -2), _now), contains('suspended in 5 days'));
      expect(SubscriptionBanner.messageFor(shop(SubscriptionStatus.suspended, -10), _now), contains('suspended'));
    });
  });

  group('offline booking payments', () {
    setUp(() => repo.switchRole(UserRole.customer)); // user_cust_1

    test('pending checkout, then success marks the booking paid', () async {
      final checkout = await service.startBookingPayment('book_1');
      expect(checkout.isSimulated, isTrue);
      expect(checkout.txRef, 'cb-${checkout.paymentId}');
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.pending);
      expect(repo.getBookingById('book_1')!.paymentMethod, PaymentMethod.chapa);

      // A second tap within 30 minutes reuses the same checkout.
      final again = await service.startBookingPayment('book_1');
      expect(again.paymentId, checkout.paymentId);
      expect((await service.verify(checkout.paymentId)).isPending, isTrue);

      final result = await service.completeSimulatedPayment(checkout.paymentId);
      expect(result.isSuccess, isTrue);
      expect(result.amount, repo.getBookingById('book_1')!.price);
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.paid);
      expect((await service.verify(checkout.paymentId)).isSuccess, isTrue);

      expect((await failure(service.startBookingPayment('book_1'))).code, 'already-exists');
    });

    test('a failed payment frees the booking for another attempt', () async {
      final checkout = await service.startBookingPayment('book_1');
      final result = await service.completeSimulatedPayment(checkout.paymentId, success: false);
      expect(result.status, PaymentRecordStatus.failed);
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.unpaid);
      final retry = await service.startBookingPayment('book_1');
      expect(retry.paymentId, isNot(checkout.paymentId));
    });

    test('only the booking customer can pay, and not for cancelled bookings', () async {
      expect((await failure(service.startBookingPayment('book_2'))).code, 'permission-denied');
      expect((await failure(service.startBookingPayment('book_7'))).code, 'failed-precondition');
      expect((await failure(service.startBookingPayment('book_5'))).code, 'already-exists');
      expect((await failure(service.startBookingPayment('nope'))).code, 'not-found');
      expect(canPayBookingOnline(repo.getBookingById('book_1')!), isTrue);
      expect(canPayBookingOnline(repo.getBookingById('book_7')!), isFalse);
    });

    test('payment history streams per user', () async {
      final checkout = await service.startBookingPayment('book_1');
      final list = await service.watchUserPayments('user_cust_1').first;
      expect(list.single.id, checkout.paymentId);
      expect(list.single.type, PaymentType.booking);
      expect(await service.watchUserPayments('user_cust_2').first, isEmpty);
    });
  });

  group('offline subscriptions', () {
    test('owner pays a plan: active and one month added to the current end', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final before = repo.getShopById('shop_1')!;
      final checkout = await service.startSubscriptionPayment(shopId: 'shop_1', planId: 'basic');
      expect(repo.getShopById('shop_1')!.subscriptionPlan, before.subscriptionPlan); // unchanged while pending

      final result = await service.completeSimulatedPayment(checkout.paymentId);
      final after = repo.getShopById('shop_1')!;
      expect(result.isSuccess, isTrue);
      expect(result.amount, repo.getPlan('basic')!.priceMonthlyEtb);
      expect(after.subscriptionPlan, 'basic');
      expect(after.subscriptionStatus, SubscriptionStatus.active);
      expect(after.subscriptionEndsAt, addMonthsUtc(before.subscriptionEndsAt!, 1));
      expect(result.periodEndsAt, after.subscriptionEndsAt);
    });

    test('suspended shop is reactivated from now', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_6');
      expect(repo.getShopById('shop_6')!.isSuspended, isTrue);
      final checkout = await service.startSubscriptionPayment(shopId: 'shop_6', planId: 'pro');
      await service.completeSimulatedPayment(checkout.paymentId);
      final shop = repo.getShopById('shop_6')!;
      expect(shop.subscriptionStatus, SubscriptionStatus.active);
      expect(shop.subscriptionEndsAt, addMonthsUtc(_now, 1));
    });

    test('rejects other shops, the trial plan, customers and too-small plans', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect((await failure(service.startSubscriptionPayment(shopId: 'shop_2', planId: 'basic'))).code, 'permission-denied');
      expect((await failure(service.startSubscriptionPayment(shopId: 'shop_1', planId: 'trial'))).code, 'invalid-argument');

      repo.switchRole(UserRole.admin);
      await service.savePlan(repo.getPlan('basic')!.copyWith(maxBarbers: 1));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(repo.getBarbersForShop('shop_1').length, greaterThan(1));
      expect((await failure(service.startSubscriptionPayment(shopId: 'shop_1', planId: 'basic'))).code, 'failed-precondition');

      repo.switchRole(UserRole.admin);
      await service.setPlanActive(repo.getPlan('pro')!, false);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect((await failure(service.startSubscriptionPayment(shopId: 'shop_1', planId: 'pro'))).code, 'not-found');

      repo.switchRole(UserRole.customer);
      expect((await failure(service.startSubscriptionPayment(shopId: 'shop_1', planId: 'basic'))).code, 'permission-denied');
    });

    test('admin manual changes and default plans', () async {
      repo.switchRole(UserRole.customer);
      expect((await failure(service.setShopSubscription(shopId: 'shop_5', months: 1))).code, 'permission-denied');

      repo.switchRole(UserRole.admin);
      final pastDue = repo.getShopById('shop_5')!;
      expect(pastDue.subscriptionStatus, SubscriptionStatus.pastDue);
      await service.setShopSubscription(shopId: 'shop_5', months: 2);
      expect(repo.getShopById('shop_5')!.subscriptionStatus, SubscriptionStatus.active);
      expect(repo.getShopById('shop_5')!.subscriptionEndsAt, addMonthsUtc(_now, 2));

      final end = DateTime.utc(2027, 3, 1);
      await service.setShopSubscription(shopId: 'shop_5', plan: 'pro', status: SubscriptionStatus.suspended, endsAt: end);
      final s = repo.getShopById('shop_5')!;
      expect((s.subscriptionPlan, s.subscriptionStatus, s.subscriptionEndsAt), ('pro', SubscriptionStatus.suspended, end));

      expect((await failure(service.setShopSubscription(shopId: 'shop_5', endsAt: end, months: 1))).code, 'invalid-argument');
      expect((await failure(service.setShopSubscription(shopId: 'shop_5', months: 30))).code, 'invalid-argument');
      expect((await failure(service.setShopSubscription(shopId: 'shop_5', plan: 'gold'))).code, 'invalid-argument');

      expect(await service.seedDefaultPlans(), isEmpty); // seed already has basic + pro
      expect(await service.seedDefaultPlans(overwrite: true), ['basic', 'pro']);
      expect(repo.getPlan('pro')!.isUnlimited, isTrue);
      expect((await failure(service.savePlan(repo.getPlan('basic')!.copyWith(maxBarbers: 0)))).code, 'invalid-argument');
    });
  });

  group('widgets', () {
    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('book and pay now with Chapa (demo checkout)', (tester) async {
      bigView(tester);
      repo.switchRole(UserRole.customer);
      final shop = repo.getShopById('shop_1')!;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => BookingFlowScreen(
                    shop: shop,
                    initialService: repo.getServiceById('srv_1_1')!,
                    initialBarber: repo.getBarberById('barber_1')!,
                    clock: () => _now,
                  ),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pay-method-chapa')));
      await tester.pump();
      expect(find.text('Total (pay online):'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('slot-11:00 AM')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-booking')));
      await tester.pumpAndSettle();

      expect(find.text('Booking Confirmed!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pay-now-chapa')));
      await tester.pumpAndSettle();
      expect(find.text('Chapa checkout (demo)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('demo-chapa-pay')));
      await tester.pumpAndSettle();

      final booking = repo.getCustomerBookings('user_cust_1').firstWhere((b) => b.timeSlot == '11:00 AM');
      expect(booking.paymentStatus, PaymentStatus.paid);
      expect(find.textContaining('Payment received'), findsOneWidget);
      expect(find.text('open'), findsOneWidget); // back on the previous screen
    });

    testWidgets('customer bookings: Pay now, badge updates to Paid', (tester) async {
      bigView(tester);
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(const MaterialApp(locale: Locale('en'), home: CustomerBookingsScreen()));
      expect(find.byKey(const ValueKey('pay-booking-book_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-booking-book_7')), findsNothing); // cancelled
      expect(find.text('Pay at shop'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('pay-booking-book_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('demo-chapa-pay')));
      await tester.pumpAndSettle();

      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.paid);
      expect(find.byKey(const ValueKey('pay-booking-book_1')), findsNothing);
    });

    testWidgets('owner subscription screen pays a plan', (tester) async {
      bigView(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_5'); // past due
      await tester.pumpWidget(MaterialApp(locale: const Locale('en'), home: OwnerSubscriptionScreen(shopId: 'shop_5', clock: () => _now)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subscription-banner')), findsOneWidget);
      expect(find.text('Payment overdue'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-trial')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pay-plan-basic')));
      // The plan button shows a spinner while the checkout is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('demo-chapa-pay')));
      await tester.pumpAndSettle();

      expect(repo.getShopById('shop_5')!.subscriptionStatus, SubscriptionStatus.active);
      expect(find.byKey(const ValueKey('subscription-banner')), findsNothing);
      expect(find.text('Active'), findsOneWidget);
      expect(find.textContaining('Paid'), findsOneWidget); // history row
    });

    testWidgets('admin extends a suspended shop and toggles a plan', (tester) async {
      bigView(tester);
      repo.switchRole(UserRole.admin);
      await tester.pumpWidget(MaterialApp(locale: const Locale('en'), home: AdminSubscriptionsScreen(clock: () => _now)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-sub-shop_6')), findsOneWidget); // suspended still listed

      await tester.tap(find.byKey(const ValueKey('admin-sub-shop_6')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-subscription')));
      await tester.pumpAndSettle();
      expect(repo.getShopById('shop_6')!.subscriptionStatus, SubscriptionStatus.active);
      expect(repo.getShopById('shop_6')!.subscriptionEndsAt, addMonthsUtc(_now, 1));

      await tester.tap(find.text('Plans (3)'));
      await tester.pumpAndSettle();
      final proSwitch = find.descendant(of: find.byKey(const ValueKey('admin-plan-pro')), matching: find.byType(Switch));
      await tester.tap(proSwitch);
      await tester.pumpAndSettle();
      expect(repo.getPlan('pro')!.active, isFalse);
    });
  });
}
