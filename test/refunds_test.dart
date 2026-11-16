import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/payments/widgets/payment_status_badge.dart';
import 'package:barbershop_booking/features/refunds/refunds_dashboard_entries.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/data_cache.dart';
import 'package:barbershop_booking/services/firestore_data_store.dart';
import 'package:barbershop_booking/services/notification_service.dart';
import 'package:barbershop_booking/services/refunds.dart';
import 'package:barbershop_booking/services/shop_deletion.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _booking({
  String id = 'b1',
  double price = 300,
  BookingStatus status = BookingStatus.confirmed,
  PaymentStatus paymentStatus = PaymentStatus.paid,
  DateTime? startAt,
  BookingRefund? refund,
}) {
  final start = startAt ?? _now.add(const Duration(days: 1));
  return Booking(
    id: id,
    shopId: 'shop_1',
    shopName: 'Fade Lab',
    barberId: 'barber_1',
    barberName: 'Abel',
    customerId: 'user_cust_1',
    customerName: 'Hana',
    customerPhone: '+251911000000',
    serviceId: 'srv_1_1',
    serviceName: 'Haircut',
    price: price,
    date: DateTime(start.year, start.month, start.day),
    timeSlot: '10:00 AM',
    status: status,
    createdAt: _now.subtract(const Duration(days: 1)),
    startAt: start,
    durationMinutes: 30,
    paymentStatus: paymentStatus,
    paymentMethod: PaymentMethod.chapa,
    refund: refund,
  );
}

RefundContext _ctx(RefundCanceller by, {int? cutoffHours, String? reason, DateTime? now}) =>
    RefundContext(by: by, nowUtc: now ?? _now, cutoffHours: cutoffHours, reason: reason);

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  group('amount rules', () {
    test('the shop side cancelling refunds the full price', () {
      for (final by in [RefundCanceller.barber, RefundCanceller.owner, RefundCanceller.admin, RefundCanceller.system]) {
        final flag = refundFlagFor(_booking(), _ctx(by))!;
        expect(flag.amount, 300, reason: '$by');
        expect(flag.status, RefundStatus.due);
        expect(flag.flaggedAt, _now);
      }
      expect(refundFlagFor(_booking(), _ctx(RefundCanceller.barber))!.reason, RefundReasons.barberCancelled);
      expect(refundFlagFor(_booking(), _ctx(RefundCanceller.owner))!.reason, RefundReasons.shopCancelled);
      expect(refundFlagFor(_booking(), _ctx(RefundCanceller.admin))!.reason, RefundReasons.adminCancelled);
      expect(refundFlagFor(_booking(), _ctx(RefundCanceller.system))!.reason, RefundReasons.systemCancelled);
    });

    test('fixed reasons (shop deleted, declined, expired) refund in full', () {
      for (final reason in [RefundReasons.shopDeleted, RefundReasons.requestDeclined, RefundReasons.requestExpired]) {
        final flag = refundFlagFor(_booking(), _ctx(RefundCanceller.admin, reason: reason))!;
        expect((flag.reason, flag.amount), (reason, 300));
      }
    });

    test('the customer before the cutoff gets everything back, after it the late share', () {
      final start = _now.add(const Duration(hours: 5));
      final b = _booking(startAt: start, price: 250);
      // Exactly at the deadline (start - 2 h) is still on time.
      final onTime = refundFlagFor(b, _ctx(RefundCanceller.customer, cutoffHours: 2, now: start.subtract(const Duration(hours: 2))))!;
      expect((onTime.reason, onTime.amount), (RefundReasons.customerCancelled, 250));
      final late = refundFlagFor(
          b, _ctx(RefundCanceller.customer, cutoffHours: 2, now: start.subtract(const Duration(hours: 2, seconds: -1))))!;
      expect(late.reason, RefundReasons.customerLateCancel);
      expect(late.amount, 250 * kLateCancelRefundPercent / 100);
      // No known cutoff: treated as on time.
      expect(refundFlagFor(b, _ctx(RefundCanceller.customer))!.amount, 250);
    });

    test('late share is rounded to cents', () {
      expect(refundAmountFor(_booking(price: 99.99), RefundReasons.customerLateCancel), 50.0);
      expect(refundAmountFor(_booking(price: 120.5), RefundReasons.shopCancelled), 120.5);
    });

    test('nothing is flagged when nothing was paid, already flagged, refunded, a no-show or free', () {
      final ctx = _ctx(RefundCanceller.owner);
      expect(refundFlagFor(_booking(paymentStatus: PaymentStatus.unpaid), ctx), isNull);
      expect(refundFlagFor(_booking(paymentStatus: PaymentStatus.pending), ctx), isNull);
      expect(refundFlagFor(_booking(paymentStatus: PaymentStatus.refunded), ctx), isNull);
      expect(refundFlagFor(_booking(status: BookingStatus.noShow), ctx), isNull);
      expect(refundAmountFor(_booking(status: BookingStatus.noShow), RefundReasons.shopCancelled), 0);
      expect(refundFlagFor(_booking(price: 0), ctx), isNull);
      final flagged = BookingRefund(
          status: RefundStatus.due, amount: 300, reason: RefundReasons.shopCancelled, flaggedAt: _now);
      expect(refundFlagFor(_booking(refund: flagged), ctx), isNull);
    });

    test('canceller from the signed-in user', () {
      final b = _booking();
      AppUser user(UserRole role, String uid) => AppUser(uid: uid, name: 'x', email: 'x@x.et', role: role, createdAt: _now);
      expect(refundCancellerFor(user(UserRole.customer, 'user_cust_1'), b), RefundCanceller.customer);
      expect(refundCancellerFor(user(UserRole.barber, 'u_b'), b), RefundCanceller.barber);
      expect(refundCancellerFor(user(UserRole.barbershopOwner, 'u_o'), b), RefundCanceller.owner);
      expect(refundCancellerFor(user(UserRole.admin, 'u_a'), b), RefundCanceller.admin);
      expect(refundCancellerFor(null, b), RefundCanceller.system);
    });

    test('past cancellations (sweep) get their reason from the booking', () {
      String reasonOf(Booking b) => refundReasonFor(b, refundContextForPastCancel(b, _now));
      final c = _booking(status: BookingStatus.cancelled);
      expect(reasonOf(c.copyWith(cancelReason: 'shop_deleted')), RefundReasons.shopDeleted);
      expect(reasonOf(c.copyWith(cancelledBy: 'system', cancelReason: 'not_accepted')), RefundReasons.requestExpired);
      expect(reasonOf(c.copyWith(cancelledBy: 'barber', declineReason: 'not_accepted')), RefundReasons.requestExpired);
      expect(reasonOf(c.copyWith(cancelledBy: 'barber')), RefundReasons.requestDeclined);
      expect(reasonOf(c.copyWith(cancelledBy: 'user_cust_1')), RefundReasons.customerCancelled);
      expect(reasonOf(c.copyWith(cancelledBy: 'system')), RefundReasons.systemCancelled);
      expect(reasonOf(c.copyWith(cancelledBy: 'u_owner')), RefundReasons.shopCancelled);
    });

    test('booking refund fields round-trip', () {
      final flag = refundFlagFor(_booking(), _ctx(RefundCanceller.owner))!;
      final map = {..._booking().toMap(), ...flag.toFlagFields()};
      expect(_booking().toMap().keys.any((k) => k.startsWith('refund')), isFalse);
      final parsed = Booking.fromMap(map, 'b1').refund!;
      expect((parsed.status, parsed.amount, parsed.reason, parsed.flaggedAt), (RefundStatus.due, 300, flag.reason, _now));
      final done = Booking.fromMap({
        ...map,
        ...refundCompletionFields(refundedAt: _now, refundedBy: 'u_o', method: RefundMethod.cbe, reference: 'FT123'),
      }, 'b1');
      expect(done.paymentStatus, PaymentStatus.refunded);
      expect((done.refund!.status, done.refund!.method, done.refund!.reference, done.refund!.refundedBy),
          (RefundStatus.refunded, RefundMethod.cbe, 'FT123', 'u_o'));
    });

    test('reference is trimmed and capped', () {
      expect(normalizeRefundReference('   '), isNull);
      expect(normalizeRefundReference(' FT1 '), 'FT1');
      expect(() => normalizeRefundReference('x' * (kMaxRefundReferenceLength + 1)), throwsArgumentError);
    });

    test('notices are in the customer language (Amharic by default)', () {
      final b = _booking();
      final flag = refundFlagFor(b, _ctx(RefundCanceller.owner))!;
      final en = refundDueNotice(b, flag, language: 'en');
      expect(en.id, 'b1_refundDue');
      expect(en.type, NotificationTypes.refundDue);
      expect(en.recipientUid, 'user_cust_1');
      expect(en.body, contains('ETB 300.00'));
      expect(en.toMap().keys.toSet(), {'type', 'title', 'body', 'bookingId', 'read', 'createdAt'});
      expect(refundDueNotice(b, flag).title, isNot(en.title));
      expect(refundedNotice(b, 300, _now, language: 'en').id, 'b1_paymentRefunded');
    });
  });

  group('cancellation paths (local repository)', () {
    final repo = AppRepository.instance;
    late NotificationService notifications;

    setUp(() {
      loadTestSeed(now: _now);
      notifications = NotificationService(repository: repo)..start();
    });
    tearDown(() => notifications.dispose());

    void pay(String bookingId) => repo.applySimulatedBookingPayment(bookingId, PaymentStatus.paid, paymentId: 'p_$bookingId');

    test('customer cancels a paid booking before the cutoff: full refund due, inbox notice', () async {
      repo.switchRole(UserRole.customer);
      expect(repo.currentUser!.uid, 'user_cust_1');
      pay('book_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      final b = repo.getBookingById('book_1')!;
      expect(b.status, BookingStatus.cancelled);
      expect(b.refund!.isDue, isTrue);
      expect(b.refund!.reason, RefundReasons.customerCancelled);
      expect(b.refund!.amount, b.price);
      expect(notifications.local.inboxFor('user_cust_1').where((n) => n.type == NotificationTypes.refundDue), hasLength(1));
    });

    test('an unpaid booking is cancelled without a refund', () async {
      repo.switchRole(UserRole.customer);
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      expect(repo.getBookingById('book_1')!.refund, isNull);
    });

    test('barber cancel: full refund (barber_cancelled)', () async {
      pay('book_1');
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await repo.cancelBookingAsBarber('book_1');
      final r = repo.getBookingById('book_1')!.refund!;
      expect((r.reason, r.amount), (RefundReasons.barberCancelled, repo.getBookingById('book_1')!.price));
    });

    test('owner cancel: full refund (shop_cancelled)', () async {
      pay('book_1');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      expect(repo.getBookingById('book_1')!.refund!.reason, RefundReasons.shopCancelled);
    });

    test('admin cancel: full refund (admin_cancelled)', () async {
      pay('book_1');
      repo.switchRole(UserRole.admin);
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      expect(repo.getBookingById('book_1')!.refund!.reason, RefundReasons.adminCancelled);
    });

    test('a no-show is not refunded', () async {
      pay('book_2');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      repo.debugClock = () => repo.getBookingById('book_2')!.startAt.add(const Duration(minutes: 20));
      await repo.markNoShow('book_2');
      expect(repo.getBookingById('book_2')!.status, BookingStatus.noShow);
      expect(repo.getBookingById('book_2')!.refund, isNull);
    });

    test('declined and expired requests that were paid are refunded in full', () async {
      final shopId = repo.getBookingById('book_6')!.shopId;
      repo.switchRole(UserRole.barbershopOwner, targetShopId: shopId);
      expect(repo.currentUser!.shopId, shopId);
      pay('book_6');
      await repo.declineBookingRequest('book_6');
      expect(repo.getBookingById('book_6')!.refund!.reason, RefundReasons.requestDeclined);

      loadTestSeed(now: _now);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: shopId);
      pay('book_6');
      // Inside the expiry window: the staff app closes the request itself.
      repo.debugClock = () => repo.getBookingById('book_6')!.startAt.subtract(const Duration(minutes: 30));
      expect(await repo.closeExpiredBookingRequests(force: true), 1);
      final b = repo.getBookingById('book_6')!;
      expect(b.status, BookingStatus.cancelled);
      expect((b.refund!.reason, b.refund!.amount), (RefundReasons.requestExpired, b.price));
    });

    test('shop deletion flags paid upcoming bookings (shop_deleted)', () async {
      pay('book_1');
      repo.switchRole(UserRole.admin);
      final shop = repo.getShopById('shop_1')!;
      await repo.deleteShopConfirmed('shop_1', shop.name);
      final b = repo.getBookingById('book_1')!;
      expect(b.status, BookingStatus.cancelled);
      expect((b.refund!.reason, b.refund!.amount), (RefundReasons.shopDeleted, b.price));
      expect(b.cancelReason, kShopDeletedCancelReason);
      // Unpaid upcoming ones are cancelled without a refund.
      expect(repo.getBookingById('book_4')!.refund, isNull);
    });

    test('an already-cancelled booking is not flagged again', () async {
      pay('book_1');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      final first = repo.getBookingById('book_1')!.refund!;
      repo.switchRole(UserRole.admin);
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      expect(repo.getBookingById('book_1')!.refund!.reason, first.reason);
    });

    test('owner list, mark refunded, customer told; others may not', () async {
      pay('book_1');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      final due = await repo.watchRefundsDue(shopId: 'shop_1').first;
      expect(due.map((b) => b.id), ['book_1']);
      // Another shop's list is empty for this owner.
      expect(await repo.watchRefundsDue(shopId: 'shop_2').first, isEmpty);

      await repo.markRefunded(due.single, method: RefundMethod.telebirr, reference: ' TX99 ');
      final b = repo.getBookingById('book_1')!;
      expect(b.refund!.isRefunded, isTrue);
      expect(b.refund!.method, RefundMethod.telebirr);
      expect(b.refund!.reference, 'TX99');
      expect(b.refund!.refundedBy, repo.currentUser!.uid);
      expect(b.paymentStatus, PaymentStatus.refunded);
      expect(await repo.watchRefundsDue(shopId: 'shop_1').first, isEmpty);
      expect(
          notifications.local.inboxFor('user_cust_1').where((n) => n.type == NotificationTypes.paymentRefunded), hasLength(1));
      // Twice is refused.
      expect(() => repo.markRefunded(b, method: RefundMethod.cash), throwsA(isA<AppStateException>()));

      // A customer or barber cannot settle refunds.
      pay('book_2');
      await repo.updateBookingStatus('book_2', BookingStatus.cancelled);
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(repo.canManageRefunds(shopId: 'shop_1'), isFalse);
      expect(() => repo.markRefunded(repo.getBookingById('book_2')!, method: RefundMethod.cash),
          throwsA(isA<AppStateException>()));
      repo.switchRole(UserRole.admin);
      expect((await repo.watchRefundsDue().first).map((b) => b.id), ['book_2']);
    });

    test('the owner sweep flags cancelled paid bookings an older app left unflagged', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      // book_7 was cancelled (by the customer) long ago; pretend it was paid.
      pay('book_7');
      expect(repo.getBookingById('book_7')!.refund, isNull);
      expect(await repo.flagMissingRefunds(), 1);
      expect(repo.getBookingById('book_7')!.refund!.isDue, isTrue);
      expect(await repo.flagMissingRefunds(), 0);
    });
  });

  group('Firestore writes', () {
    late FakeFirebaseFirestore db;
    late FirestoreDataStore store;

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestoreDataStore(
        cache: DataCache(),
        firestore: db,
        onChanged: () {},
        onCurrentUserChanged: (_) {},
      );
    });

    Future<Map<String, dynamic>> bookingDoc(String id) async => (await db.collection('bookings').doc(id).get()).data()!;
    Future<Map<String, dynamic>?> notice(String uid, String id) async =>
        (await db.collection('users').doc(uid).collection('notifications').doc(id).get()).data();

    test('a cancel flags the refund in the same transaction (paid state re-read)', () async {
      final b = _booking();
      // The cached copy says unpaid; the stored booking is paid.
      await db.collection('bookings').doc(b.id).set(b.toMap());
      await store.updateBookingStatus(b.copyWith(paymentStatus: PaymentStatus.unpaid), BookingStatus.cancelled,
          cancelledBy: 'u_owner', refund: _ctx(RefundCanceller.owner));
      final d = await bookingDoc(b.id);
      expect(d['status'], 'cancelled');
      expect(d['cancelledBy'], 'u_owner');
      expect(d['refundStatus'], 'due');
      expect(d['refundAmount'], 300);
      expect(d['refundReason'], RefundReasons.shopCancelled);
      expect(d['refundFlaggedAt'], _now.toIso8601String());
      final n = await notice('user_cust_1', 'b1_refundDue');
      expect(n!['type'], 'refundDue');
      expect(n['bookingId'], 'b1');
      expect(n['read'], false);
    });

    test('an unpaid cancel writes no refund fields and no notice', () async {
      final b = _booking(paymentStatus: PaymentStatus.unpaid);
      await db.collection('bookings').doc(b.id).set(b.toMap());
      await store.updateBookingStatus(b, BookingStatus.cancelled,
          cancelledBy: 'user_cust_1', refund: _ctx(RefundCanceller.customer, cutoffHours: 2));
      final d = await bookingDoc(b.id);
      expect(d.keys.where((k) => k.startsWith('refund')), isEmpty);
      expect(await notice('user_cust_1', 'b1_refundDue'), isNull);
    });

    test('decline of a paid request flags it', () async {
      final b = _booking(status: BookingStatus.pending);
      await db.collection('bookings').doc(b.id).set(b.toMap());
      await store.declineBookingRequest(b,
          reason: 'not_accepted', refund: _ctx(RefundCanceller.barber, reason: RefundReasons.requestExpired));
      final d = await bookingDoc(b.id);
      expect((d['status'], d['refundStatus'], d['refundReason']), ('cancelled', 'due', RefundReasons.requestExpired));
      expect(await notice('user_cust_1', 'b1_refundDue'), isNotNull);
    });

    test('shop deletion batch flags paid bookings', () async {
      final paid = _booking(id: 'p1');
      final unpaid = _booking(id: 'u1', paymentStatus: PaymentStatus.unpaid);
      for (final b in [paid, unpaid]) {
        await db.collection('bookings').doc(b.id).set(b.toMap());
      }
      final items = planShopBookingCancellations('shop_1', [paid, unpaid], _now);
      await store.cancelBookingsForShopDeletion(items,
          cancelledBy: 'u_admin', refund: _ctx(RefundCanceller.admin, reason: RefundReasons.shopDeleted));
      expect((await bookingDoc('p1'))['refundReason'], RefundReasons.shopDeleted);
      expect((await bookingDoc('p1'))['cancelReason'], 'shop_deleted');
      expect((await bookingDoc('u1')).containsKey('refundStatus'), isFalse);
      expect(await notice('user_cust_1', 'p1_refundDue'), isNotNull);
      expect(await notice('user_cust_1', 'u1_refundDue'), isNull);
    });

    test('refunds-due query and mark refunded', () async {
      final b = _booking();
      final flag = refundFlagFor(b, _ctx(RefundCanceller.owner))!;
      await db.collection('bookings').doc(b.id).set({...b.copyWith(status: BookingStatus.cancelled).toMap(), ...flag.toFlagFields()});
      final other = _booking(id: 'b2').copyWith(shopId: 'shop_2');
      await db.collection('bookings').doc('b2').set({...other.toMap(), ...flag.toFlagFields()});

      expect((await store.watchRefundsDue(shopId: 'shop_1').first).map((b) => b.id), ['b1']);
      expect((await store.watchRefundsDue().first).map((b) => b.id).toSet(), {'b1', 'b2'});

      final stored = Booking.fromMap(await bookingDoc('b1'), 'b1');
      final fields = refundCompletionFields(refundedAt: _now, refundedBy: 'u_owner', method: RefundMethod.bank);
      await store.markRefunded(stored, fields, refundedNotice(stored, 300, _now));
      final d = await bookingDoc('b1');
      expect((d['refundStatus'], d['refundMethod'], d['refundedBy'], d['paymentStatus']),
          ('refunded', 'bank', 'u_owner', 'refunded'));
      expect(d.containsKey('refundReference'), isFalse);
      expect(await notice('user_cust_1', 'b1_paymentRefunded'), isNotNull);
      expect(await store.watchRefundsDue(shopId: 'shop_1').first, isEmpty);
      // No longer due: refused.
      expect(() => store.markRefunded(stored, fields, null), throwsA(isA<AppStateException>()));
    });

    test('the sweep flag is refused for a booking that is already flagged', () async {
      final b = _booking(status: BookingStatus.cancelled);
      await db.collection('bookings').doc(b.id).set(b.toMap());
      final flag = refundFlagFor(b, _ctx(RefundCanceller.system))!;
      await store.flagRefund(b, flag, refundDueNotice(b, flag));
      expect((await bookingDoc('b1'))['refundStatus'], 'due');
      expect(() => store.flagRefund(b, flag, null), throwsA(isA<AppStateException>()));
    });
  });

  group('screens', () {
    final repo = AppRepository.instance;
    setUp(() => loadTestSeed(now: _now));

    testWidgets('badge shows refund due / refunded', (tester) async {
      final flag = refundFlagFor(_booking(), _ctx(RefundCanceller.owner))!;
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          PaymentStatusBadge(booking: _booking(id: 'd', refund: flag)),
          PaymentStatusBadge(
            booking: _booking(id: 'r', refund: flag.markedRefunded(at: _now, by: 'u', method: RefundMethod.cash)),
          ),
          PaymentStatusBadge(booking: _booking(id: 'p')),
        ]),
      )));
      expect(find.byKey(const ValueKey('refund-badge-d')), findsOneWidget);
      expect(find.textContaining('Refund due'), findsOneWidget);
      expect(find.text('Refunded'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-badge-p')), findsOneWidget);
    });

    testWidgets('owner opens Refunds due and marks one refunded', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p1');
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);

      await tester.pumpWidget(_app(const Scaffold(body: OwnerRefundsButton(shopId: 'shop_1'))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('refunds-badge')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-refunds')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('refund-book_1')), findsOneWidget);
      expect(find.text('Shop cancelled · Cancelled ${AppFormats('en').addisDateMedium(_now)}'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('refund-mark-book_1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('refund-reference')), 'TX-1');
      await tester.tap(find.byKey(const ValueKey('refund-confirm')));
      await tester.pumpAndSettle();
      expect(repo.getBookingById('book_1')!.refund!.isRefunded, isTrue);
      expect(repo.getBookingById('book_1')!.refund!.reference, 'TX-1');
      expect(find.byKey(const ValueKey('refunds-empty')), findsOneWidget);
    });

    testWidgets('admin card counts refunds in every shop', (tester) async {
      repo.applySimulatedBookingPayment('book_1', PaymentStatus.paid, paymentId: 'p1');
      repo.switchRole(UserRole.admin);
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      await tester.pumpWidget(_app(const Scaffold(body: AdminRefundsCard())));
      await tester.pumpAndSettle();
      expect(find.text('1 refund waiting'), findsOneWidget);
      expect(find.byKey(const ValueKey('refunds-badge')), findsOneWidget);
    });
  });
}
