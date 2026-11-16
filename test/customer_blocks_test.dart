import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/features/reports/widgets/customer_noshow_tab.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/shop_report.dart' show ShopClient;
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/customer_blocks.dart';
import 'package:barbershop_booking/services/customer_insights.dart';
import 'package:barbershop_booking/services/queue_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Booking _b(
  String id, {
  String customerId = 'c1',
  String name = 'Liya',
  BookingStatus status = BookingStatus.completed,
  String shopId = 's1',
  int daysAgo = 3,
  String? cancelReason,
}) {
  final start = _now.subtract(Duration(days: daysAgo));
  return Booking(
    id: id,
    shopId: shopId,
    shopName: 'Shop',
    barberId: 'b1',
    barberName: 'Yonas',
    customerId: customerId,
    customerName: name,
    customerPhone: '+251911000301',
    serviceId: 'srv1',
    serviceName: 'Fade',
    price: 300,
    date: start,
    timeSlot: '',
    status: status,
    createdAt: start,
    startAt: start,
    durationMinutes: 30,
    cancelReason: cancelReason,
  );
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;
  final blocks = CustomerBlockService.instance;

  group('customer rows (pure)', () {
    final bookings = [
      _b('a1'),
      _b('a2', status: BookingStatus.noShow, daysAgo: 2),
      _b('a3', status: BookingStatus.cancelled),
      _b('a4', status: BookingStatus.confirmed, daysAgo: -2, name: 'Liya G.'), // upcoming, latest name
      _b('a5', status: BookingStatus.cancelled, cancelReason: 'slot_conflict'), // ignored
      _b('b1', customerId: 'c2', name: 'Abel', status: BookingStatus.noShow),
      _b('b2', customerId: 'c2', name: 'Abel', status: BookingStatus.noShow),
      _b('c1', customerId: 'c3', name: 'Sara', status: BookingStatus.confirmed, daysAgo: -1),
      _b('x1', customerId: 'c4', shopId: 's2'),
    ];

    test('counts, name from the latest booking, rate over due appointments', () {
      final rows = {for (final r in customerRowsFromBookings(bookings, shopId: 's1')) r.customerId: r};
      expect(rows.keys, unorderedEquals(['c1', 'c2', 'c3']));
      final liya = rows['c1']!;
      expect((liya.bookings, liya.completed, liya.cancelled, liya.noShows), (4, 1, 1, 1));
      expect(liya.name, 'Liya G.');
      expect(liya.noShowRate, 0.5);
      expect(liya.noShowPercent, 50);
      expect(rows['c2']!.noShowPercent, 100);
      expect(rows['c3']!.noShowRate, isNull, reason: 'nothing came due yet');
    });

    test('sorted by rate (no rate last), then no-shows, bookings, name', () {
      final sorted = sortByNoShowRate(customerRowsFromBookings(bookings, shopId: 's1'));
      expect(sorted.map((r) => r.customerId), ['c2', 'c1', 'c3']);
      const same = [
        CustomerNoShowRow(customerId: 'z', name: 'Zed', phone: '', completed: 1, noShows: 1, bookings: 2),
        CustomerNoShowRow(customerId: 'y', name: 'Amy', phone: '', completed: 2, noShows: 2, bookings: 4),
        CustomerNoShowRow(customerId: 'x', name: 'bob', phone: '', completed: 1, noShows: 1, bookings: 2),
      ];
      expect(sortByNoShowRate(same).map((r) => r.customerId), ['y', 'x', 'z']);
    });

    test('search by name, case-insensitive', () {
      final rows = customerRowsFromBookings(bookings, shopId: 's1');
      expect(searchCustomersByName(rows, '  abel ').map((r) => r.customerId), ['c2']);
      expect(searchCustomersByName(rows, 'LIYA').map((r) => r.customerId), ['c1']);
      expect(searchCustomersByName(rows, ''), hasLength(3));
      expect(searchCustomersByName(rows, '0911'), isEmpty, reason: 'name only');
    });

    test('merging the all-time client docs keeps the larger counts', () {
      final rows = customerRowsFromBookings(bookings, shopId: 's1');
      final merged = {
        for (final r in mergeWithClientDocs(rows, const [
          ShopClient(customerId: 'c1', name: 'Liya', phone: '', completedCount: 9, noShowCount: 0, cancelledCount: 2),
          ShopClient(customerId: 'old', name: 'Old Timer', phone: '+251911', noShowCount: 3, completedCount: 1),
        ]))
          r.customerId: r
      };
      final liya = merged['c1']!;
      expect((liya.bookings, liya.completed, liya.cancelled, liya.noShows), (11, 9, 2, 1));
      expect(liya.name, 'Liya G.');
      expect((merged['old']!.bookings, merged['old']!.noShowPercent), (4, 75));
    });

    test('no-show count, counting a just-marked booking once', () {
      expect(noShowCountOf(bookings, shopId: 's1', customerId: 'c2'), 2);
      expect(noShowCountOf(bookings, shopId: 's1', customerId: 'c1', alsoNoShowId: 'a1'), 2);
      expect(noShowCountOf(bookings, shopId: 's1', customerId: 'c2', alsoNoShowId: 'b1'), 2);
      expect(noShowCountOf(bookings, shopId: 's1', customerId: 'c3', alsoNoShowId: 'missing'), 1);
    });
  });

  group('block model', () {
    test('document shape', () {
      final block = CustomerBlock(
        shopId: 'shop_1',
        customerId: 'u1',
        customerName: 'Liya',
        source: CustomerBlockSource.owner,
        blockedBy: 'owner_1',
        blockedAt: _now,
        reason: 'Rude',
      );
      expect(block.toMap(), {
        'customerId': 'u1',
        'customerName': 'Liya',
        'source': 'owner',
        'blockedBy': 'owner_1',
        'blockedAt': '2026-11-20T07:00:00.000Z',
        'reason': 'Rude',
      });
      final auto = CustomerBlock.fromMap('shop_1', 'u2', {
        'customerName': 'Abel',
        'source': 'auto',
        'blockedBy': 'barber_user_1',
        'blockedAt': '2026-11-20T07:00:00.000Z',
        'noShowCount': 3,
      });
      expect((auto.isAuto, auto.noShowCount, auto.reason, auto.blockedAt), (true, 3, null, _now));
      expect(auto.toMap().keys, ['customerId', 'customerName', 'source', 'blockedBy', 'blockedAt', 'noShowCount']);
    });

    test('reason and settings validation', () {
      expect(normalizeBlockReason('  '), isNull);
      expect(normalizeBlockReason(' late twice '), 'late twice');
      expect(() => normalizeBlockReason('x' * 201), throwsA(isA<AppFormatException>()));
      expect(CustomerBlockSettings.fromMap(null).autoBlockOn, isFalse);
      expect(CustomerBlockSettings.fromMap({'autoBlockNoShows': 3}).autoBlockNoShows, 3);
      expect(CustomerBlockSettings.fromMap({'autoBlockNoShows': 99}).autoBlockOn, isFalse);
      expect(reachesAutoBlock(const CustomerBlockSettings(autoBlockNoShows: 3), 2), isFalse);
      expect(reachesAutoBlock(const CustomerBlockSettings(autoBlockNoShows: 3), 3), isTrue);
      expect(reachesAutoBlock(CustomerBlockSettings.off, 50), isFalse);
    });
  });

  group('block flow (local repository)', () {
    setUp(() => loadTestSeed(now: _now));

    Future<Booking> book(String shopId, String barberId, String serviceId, Duration fromNow) {
      final start = _now.add(fromNow);
      return repo.createBooking(
        shopId: shopId,
        shopName: repo.getShopById(shopId)!.name,
        barberId: barberId,
        barberName: 'Barber',
        serviceId: serviceId,
        serviceName: 'Service',
        price: 300,
        date: start,
        timeSlot: '',
        startAt: start,
      );
    }

    test('a blocked customer cannot book or join the queue at that shop only', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final block = await blocks.blockCustomer(
          shopId: 'shop_1', customerId: 'user_cust_1', customerName: 'Liya Getachew', reason: ' no-shows ');
      expect(block.reason, 'no-shows');
      expect(block.blockedBy, 'owner_1');
      expect(blocks.local.blocksOf('shop_1').single.customerId, 'user_cust_1');

      repo.switchRole(UserRole.customer);
      expect(repo.currentUser!.uid, 'user_cust_1');
      expect(await blocks.isCurrentUserBlocked('shop_1'), isTrue);
      await expectLater(
        book('shop_1', 'barber_1', 'srv_1_1', const Duration(days: 3, hours: -1)),
        throwsA(isA<AppStateException>().having((e) => e.code, 'code', AppErrorCode.customerBlockedAtShop)),
      );
      final queue = QueueService();
      await expectLater(queue.joinQueue(shopId: 'shop_1'),
          throwsA(isA<AppStateException>().having((e) => e.code, 'code', AppErrorCode.customerBlockedAtShop)));
      // Other shops are not affected.
      final other = await book('shop_2', 'barber_2_1', 'srv_2_1', const Duration(days: 3, hours: -1));
      expect(repo.getBookingById(other.id), isNotNull);
      // The neutral message.
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.errorText(AppStateException(AppErrorCode.customerBlockedAtShop)),
          "This shop can't take your booking right now. Please contact the shop.");

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await blocks.unblockCustomer('shop_1', 'user_cust_1');
      repo.switchRole(UserRole.customer);
      final again = await book('shop_1', 'barber_1', 'srv_1_1', const Duration(days: 3, hours: -1));
      expect(repo.getBookingById(again.id)!.status, isNot(BookingStatus.cancelled));
    });

    test('only the shop owner blocks, unblocks and sets auto-block', () async {
      Matcher notAllowed() =>
          throwsA(isA<AppStateException>().having((e) => e.code, 'code', AppErrorCode.customerBlockNotAllowed));
      for (final role in [UserRole.customer, UserRole.barber, UserRole.admin]) {
        repo.switchRole(role);
        await expectLater(
            blocks.blockCustomer(shopId: 'shop_1', customerId: 'user_cust_1', customerName: 'Liya'), notAllowed());
        await expectLater(blocks.unblockCustomer('shop_1', 'user_cust_1'), notAllowed());
        await expectLater(blocks.setAutoBlock('shop_1', 3), notAllowed());
      }
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      await expectLater(
          blocks.blockCustomer(shopId: 'shop_1', customerId: 'user_cust_1', customerName: 'Liya'), notAllowed());
      expect(blocks.local.blocksOf('shop_1'), isEmpty);
    });

    test('blocking keeps upcoming bookings unless the owner cancels them; paid ones get a refund flag', () async {
      repo.switchRole(UserRole.customer);
      final b1 = await book('shop_1', 'barber_1', 'srv_1_1', const Duration(days: 4));
      final b2 = await book('shop_1', 'barber_2', 'srv_1_1', const Duration(days: 5));
      repo.applySimulatedBookingPayment(b2.id, PaymentStatus.paid, paymentId: 'p_b2');

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final upcoming = blocks.upcomingBookingsOf('shop_1', 'user_cust_1');
      expect(upcoming.map((b) => b.id), containsAll([b1.id, b2.id]));
      await blocks.blockCustomer(shopId: 'shop_1', customerId: 'user_cust_1', customerName: 'Liya');
      expect(repo.getBookingById(b1.id)!.status, isNot(BookingStatus.cancelled), reason: 'bookings stay');

      final n = await blocks.cancelUpcomingBookings('shop_1', 'user_cust_1');
      expect(n, upcoming.length);
      expect(repo.getBookingById(b1.id)!.status, BookingStatus.cancelled);
      expect(repo.getBookingById(b1.id)!.refund, isNull, reason: 'unpaid');
      final paid = repo.getBookingById(b2.id)!;
      expect(paid.status, BookingStatus.cancelled);
      expect(paid.refund!.isDue, isTrue);
      expect(paid.refund!.amount, paid.price);
      expect(blocks.upcomingBookingsOf('shop_1', 'user_cust_1'), isEmpty);
    });

    group('auto-block', () {
      Future<List<Booking>> pastBookings(int n) async {
        repo.switchRole(UserRole.customer);
        return [
          for (var i = 0; i < n; i++)
            await book('shop_1', 'barber_1', 'srv_1_1', Duration(days: -(i + 1), hours: -4)),
        ];
      }

      test('off by default: no-shows never block', () async {
        final past = await pastBookings(3);
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
        expect(await blocks.store.fetchSettings('shop_1'), CustomerBlockSettings.off);
        for (final b in past) {
          await repo.markNoShow(b.id);
        }
        expect(blocks.local.blocksOf('shop_1'), isEmpty);
      });

      test('the owner marking the Nth no-show blocks the customer', () async {
        final past = await pastBookings(2);
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
        await blocks.setAutoBlock('shop_1', 2);
        expect((await blocks.store.fetchSettings('shop_1')).autoBlockNoShows, 2);
        final before = noShowCountOf(repo.getShopBookings('shop_1'), shopId: 'shop_1', customerId: 'user_cust_1');
        expect(before, 0, reason: 'the seed has no no-show of user_cust_1 at shop_1');

        await repo.markNoShow(past[0].id);
        expect(blocks.local.blocksOf('shop_1'), isEmpty);
        await repo.markNoShow(past[1].id);
        final block = blocks.local.blocksOf('shop_1').single;
        expect(block.customerId, 'user_cust_1');
        expect(block.isAuto, isTrue);
        expect(block.noShowCount, 2);
        expect(block.blockedBy, 'owner_1');

        repo.switchRole(UserRole.customer);
        await expectLater(book('shop_1', 'barber_1', 'srv_1_1', const Duration(days: 3)), throwsA(isA<AppStateException>()));
      });

      test("a barber's no-show mark also auto-blocks; an unblocked customer is blocked again only by a new no-show",
          () async {
        final past = await pastBookings(3);
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
        await blocks.setAutoBlock('shop_1', 1);
        repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
        expect(repo.currentUser!.uid, 'barber_user_1');
        await repo.markNoShow(past[0].id);
        expect(blocks.local.blocksOf('shop_1').single.blockedBy, 'barber_user_1');

        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
        await blocks.unblockCustomer('shop_1', 'user_cust_1');
        expect(blocks.local.blocksOf('shop_1'), isEmpty, reason: 'unblocking is not undone on its own');
        await repo.markNoShow(past[1].id);
        expect(blocks.local.blocksOf('shop_1').single.noShowCount, 2);
      });

      test('the limit is 0..10', () async {
        repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
        expect(() => blocks.setAutoBlock('shop_1', 11), throwsArgumentError);
        expect(() => blocks.setAutoBlock('shop_1', -1), throwsArgumentError);
        await blocks.setAutoBlock('shop_1', 0);
        expect((await blocks.store.fetchSettings('shop_1')).autoBlockOn, isFalse);
      });
    });

    test('loadSeed clears the blocks and settings', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await blocks.blockCustomer(shopId: 'shop_1', customerId: 'user_cust_1', customerName: 'Liya');
      await blocks.setAutoBlock('shop_1', 4);
      loadTestSeed(now: _now);
      expect(blocks.local.blocksOf('shop_1'), isEmpty);
      expect(await blocks.local.fetchSettings('shop_1'), CustomerBlockSettings.off);
    });
  });

  group('Firestore store', () {
    test('paths and shapes; the customer check fails open', () async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreCustomerBlockStore(db);
      await store.block(CustomerBlock(
        shopId: 'shop_1',
        customerId: 'u1',
        customerName: 'Liya',
        source: CustomerBlockSource.owner,
        blockedBy: 'owner_1',
        blockedAt: _now,
      ));
      final doc = await db.doc('barbershops/shop_1/blockedCustomers/u1').get();
      expect(doc.data(), {
        'customerId': 'u1',
        'customerName': 'Liya',
        'source': 'owner',
        'blockedBy': 'owner_1',
        'blockedAt': '2026-11-20T07:00:00.000Z',
      });
      expect(await store.isBlocked('shop_1', 'u1'), isTrue);
      expect(await store.isBlocked('shop_1', 'u2'), isFalse);
      expect((await store.watchBlocks('shop_1').first).single.customerName, 'Liya');

      await store.saveSettings('shop_1', const CustomerBlockSettings(autoBlockNoShows: 3),
          updatedBy: 'owner_1', updatedAt: _now);
      expect((await db.doc('barbershops/shop_1/settings/customerBlocks').get()).data(),
          {'autoBlockNoShows': 3, 'updatedBy': 'owner_1', 'updatedAt': '2026-11-20T07:00:00.000Z'});
      expect((await store.fetchSettings('shop_1')).autoBlockNoShows, 3);

      for (final (id, status) in [('n1', 'noShow'), ('n2', 'noShow'), ('c1', 'completed')]) {
        await db.collection('bookings').doc(id).set({'shopId': 'shop_1', 'customerId': 'u1', 'status': status});
      }
      expect(await store.countNoShows('shop_1', 'u1'), 2);

      await store.unblock('shop_1', 'u1');
      expect(await store.isBlocked('shop_1', 'u1'), isFalse);
    });
  });

  group('No-shows tab', () {
    setUp(() {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    });

    Future<void> pumpTab(WidgetTester tester, {Locale locale = const Locale('en')}) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const Scaffold(body: CustomerNoShowTab(shopId: 'shop_1')), locale: locale));
      await tester.pumpAndSettle();
    }

    testWidgets('lists customers with counts and rate; search filters by name', (tester) async {
      await pumpTab(tester);
      final rows = sortByNoShowRate(customerRowsFromBookings(repo.getShopBookings('shop_1'), shopId: 'shop_1'));
      expect(rows, isNotEmpty);
      for (final r in rows) {
        expect(find.byKey(ValueKey('noshow-row-${r.customerId}')), findsOneWidget);
      }
      final first = rows.first;
      expect(
        tester.widget<Text>(find.byKey(ValueKey('noshow-stats-${first.customerId}'))).data,
        'Bookings ${first.bookings} · Completed ${first.completed} · Cancelled ${first.cancelled} · No-shows ${first.noShows}',
      );
      expect(find.text('Customers by no-show rate'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('noshow-search')), 'zzzz');
      await tester.pump();
      expect(find.byKey(const ValueKey('noshow-no-match')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('noshow-search')), first.name.substring(0, 3).toLowerCase());
      await tester.pump();
      expect(find.byKey(ValueKey('noshow-row-${first.customerId}')), findsOneWidget);
    });

    testWidgets('block with a note and cancel upcoming, then unblock', (tester) async {
      await pumpTab(tester);
      final upcoming = blocks.upcomingBookingsOf('shop_1', 'user_cust_1');
      expect(upcoming, isNotEmpty, reason: 'the seed has an upcoming booking for user_cust_1 at shop_1');

      await tester.tap(find.byKey(const ValueKey('noshow-block-user_cust_1')));
      await tester.pumpAndSettle();
      expect(find.textContaining("This shop can't take your booking right now"), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('block-reason-field')), 'Missed three times');
      await tester.tap(find.byKey(const ValueKey('block-cancel-upcoming')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('block-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('noshow-blocked-user_cust_1')), findsOneWidget);
      expect(find.text('Note: Missed three times'), findsOneWidget);
      expect(find.byKey(const ValueKey('noshow-unblock-user_cust_1')), findsOneWidget);
      expect(find.textContaining('is blocked.'), findsOneWidget);
      for (final b in upcoming) {
        expect(repo.getBookingById(b.id)!.status, BookingStatus.cancelled);
      }
      expect(blocks.local.blocksOf('shop_1').single.reason, 'Missed three times');

      await tester.tap(find.byKey(const ValueKey('noshow-filter-blocked')));
      await tester.pumpAndSettle();
      expect(find.text('Blocked (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('noshow-row-user_cust_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('noshow-row-user_cust_2')), findsNothing, reason: 'only blocked customers');

      await tester.tap(find.byKey(const ValueKey('noshow-unblock-user_cust_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('unblock-confirm')));
      await tester.pumpAndSettle();
      expect(blocks.local.blocksOf('shop_1'), isEmpty);
      expect(find.byKey(const ValueKey('noshow-blocked-user_cust_1')), findsNothing);
    });

    testWidgets('auto-block switch and limit', (tester) async {
      await pumpTab(tester);
      expect(find.textContaining('Turn it on'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('autoblock-switch')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const ValueKey('autoblock-limit'))).data, '3');
      expect(find.text('A customer is blocked after 3 no-shows at your shop.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('autoblock-inc')));
      await tester.pumpAndSettle();
      expect((await blocks.store.fetchSettings('shop_1')).autoBlockNoShows, 4);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('autoblock-dec')));
        await tester.pumpAndSettle();
      }
      expect(find.text('A customer is blocked after 1 no-show at your shop.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('autoblock-switch')));
      await tester.pumpAndSettle();
      expect((await blocks.store.fetchSettings('shop_1')).autoBlockOn, isFalse);
    });

    testWidgets('a barber sees no block actions; Amharic labels', (tester) async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      await pumpTab(tester, locale: const Locale('am'));
      expect(find.byKey(const ValueKey('autoblock-card')), findsNothing);
      expect(find.byKey(const ValueKey('noshow-block-user_cust_1')), findsNothing);
      expect(find.text('ደንበኞች ባለመምጣት መጠን'), findsOneWidget);
    });

    testWidgets('the reports screen has Busy hours and No-shows tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(OwnerReportsScreen(shopId: 'shop_1', now: _now)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reports-tab-busy-hours')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('busy-summary')), findsOneWidget);
      // Five tabs scroll sideways on a phone.
      await tester.ensureVisible(find.byKey(const ValueKey('reports-tab-noshows')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reports-tab-noshows')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('autoblock-card')), findsOneWidget);
    });
  });
}
