import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/features/reviews/reviews_l10n.dart';
import 'package:barbershop_booking/features/reviews/screens/reviews_screen.dart';
import 'package:barbershop_booking/features/reviews/widgets/reviews_dashboard_entries.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/reviews_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// 10:00 in Addis on Friday 2026-11-20.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Map<String, dynamic> _seedJson() => jsonDecode(readSeedJson()) as Map<String, dynamic>;

/// A fresh local service holding the demo reviews, installed as the shared
/// instance (the booking card and dashboards use [ReviewsService.instance]).
ReviewsService _seededService() {
  final service = ReviewsService(clock: () => _now);
  service.local.loadSeedJson(_seedJson(), now: _now);
  ReviewsService.instance = service;
  return service;
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

Review _review(String id, int rating, DateTime at, {String shopId = 's1', String barberId = 'b1'}) => Review(
      bookingId: id,
      shopId: shopId,
      barberId: barberId,
      customerId: 'c_$id',
      customerName: 'Customer $id',
      rating: rating,
      createdAt: at,
    );

void main() {
  final repo = AppRepository.instance;
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => ReviewsService.instance = null);

  group('model', () {
    test('rating summary uses the Cloud Function rounding', () {
      expect(RatingSummary.fromRatings(const []), RatingSummary.empty);
      expect(RatingSummary.fromRatings(const [5, 4, 4, 5, 3]), const RatingSummary(rating: 4.2, count: 5));
      expect(RatingSummary.fromRatings(const [5, 4, 4]), const RatingSummary(rating: 4.3, count: 3));
      expect(RatingSummary.fromRatings(const [5, 4]), const RatingSummary(rating: 4.5, count: 2));
      // Only whole stars 1..5 count.
      expect(RatingSummary.fromRatings(const [5, 0, 6, 4.5, null]), const RatingSummary(rating: 5, count: 1));
    });

    test('distribution and short names', () {
      final d = RatingDistribution.fromRatings(const [5, 5, 4, 1]);
      expect(d.counts, {1: 1, 2: 0, 3: 0, 4: 1, 5: 2});
      expect(d.total, 4);
      expect(d.fraction(5), 0.5);
      expect(RatingDistribution({}).fraction(3), 0);
      expect(shortCustomerName('Liya Getachew'), 'Liya G.');
      expect(shortCustomerName('  Abebe  '), 'Abebe');
      expect(shortCustomerName('ራሄል ደስታ'), 'ራሄል ደ.');
      expect(shortCustomerName(''), '');
    });

    test('map round trip leaves out empty optional fields', () {
      final r = _review('b9', 4, DateTime.utc(2026, 8, 1, 9));
      expect(r.toMap().keys,
          unorderedEquals(['bookingId', 'shopId', 'barberId', 'customerId', 'customerName', 'rating', 'createdAt']));
      final full = r.copyWith(reply: 'Thanks', replyAt: DateTime.utc(2026, 8, 2));
      final back = Review.fromMap({...full.toMap(), 'comment': ' Great '}, 'b9');
      expect(back.comment, 'Great');
      expect(back.reply, 'Thanks');
      expect(back.replyAt, DateTime.utc(2026, 8, 2));
      expect(back.createdAt, DateTime.utc(2026, 8, 1, 9));
    });
  });

  group('demo seed', () {
    setUp(() => loadTestSeed(now: _now));

    test('seeded reviews resolve from completed bookings and match the rating fields', () {
      final reviews = reviewsFromSeedJson(_seedJson(), now: _now);
      expect(reviews, hasLength(13));
      for (final r in reviews) {
        final booking = repo.getBookingById(r.bookingId)!;
        expect(booking.status, BookingStatus.completed, reason: r.bookingId);
        expect(r.shopId, booking.shopId);
        expect(r.barberId, booking.barberId);
        expect(r.customerName, booking.customerName);
        expect(r.createdAt.isAfter(booking.startAt), isTrue);
      }
      for (final shop in repo.getShops()) {
        final mine = reviews.where((r) => r.shopId == shop.id);
        expect(RatingSummary(rating: shop.rating, count: shop.reviewCount),
            RatingSummary.fromRatings(mine.map((r) => r.rating)),
            reason: shop.id);
        for (final b in repo.getBarbersForShop(shop.id)) {
          expect(RatingSummary(rating: b.rating, count: b.reviewCount),
              RatingSummary.fromRatings(mine.where((r) => r.barberId == b.id).map((r) => r.rating)),
              reason: b.id);
        }
      }
      // book_3 (2 days ago, 10:30 Addis) was reviewed 5 hours later.
      expect(reviews.firstWhere((r) => r.bookingId == 'book_3').createdAt, DateTime.utc(2026, 11, 18, 12, 30));
    });
  });

  group('local service', () {
    late ReviewsService service;

    setUp(() {
      loadTestSeed(now: _now);
      service = _seededService();
    });

    test('a customer rates a completed visit once and the ratings update', () async {
      repo.switchRole(UserRole.customer); // user_cust_1
      final booking = repo.getBookingById('book_5')!; // shop_2, barber_2_1, completed
      expect(service.reviewBlocker(booking), isNull);

      final review = await service.submitReview(booking, rating: 3, comment: '  Good cut, slow service.  ');
      expect(review.comment, 'Good cut, slow service.');
      expect(review.createdAt, _now);
      expect(review.customerName, 'Liya Getachew');

      // shop_2 had 5 and 4; barber_2_1 had 5.
      expect(service.shopSummary('shop_2'), const RatingSummary(rating: 4.0, count: 3));
      expect(service.barberSummary('barber_2_1'), const RatingSummary(rating: 4.0, count: 2));
      expect(service.barberSummary('barber_2_2'), const RatingSummary(rating: 4.0, count: 1));

      await expectLater(
        service.submitReview(booking, rating: 5),
        throwsA(isA<ReviewException>().having((e) => e.code, 'code', ReviewErrorCode.alreadyReviewed)),
      );
      expect(service.shopSummary('shop_2').count, 3);
    });

    test('only the customer, only completed, valid stars and comment length', () async {
      repo.switchRole(UserRole.customer); // user_cust_1
      Matcher code(ReviewErrorCode c) => throwsA(isA<ReviewException>().having((e) => e.code, 'code', c));

      await expectLater(service.submitReview(repo.getBookingById('book_1')!, rating: 5),
          code(ReviewErrorCode.notCompleted)); // confirmed, upcoming
      await expectLater(service.submitReview(repo.getBookingById('book_7')!, rating: 5),
          code(ReviewErrorCode.notCompleted)); // cancelled
      await expectLater(service.submitReview(repo.getBookingById('book_3')!, rating: 5),
          code(ReviewErrorCode.notYourBooking)); // user_cust_3's
      final book5 = repo.getBookingById('book_5')!;
      await expectLater(service.submitReview(book5, rating: 0), code(ReviewErrorCode.invalidRating));
      await expectLater(service.submitReview(book5, rating: 6), code(ReviewErrorCode.invalidRating));
      await expectLater(service.submitReview(book5, rating: 4, comment: 'x' * (kReviewCommentMaxLength + 1)),
          code(ReviewErrorCode.commentTooLong));
      expect((await service.submitReview(book5, rating: 4, comment: 'x' * kReviewCommentMaxLength)).rating, 4);

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      expect(service.reviewBlocker(book5), ReviewErrorCode.notYourBooking);
    });

    test('pages are newest first and the distribution counts every review', () async {
      final first = await service.loadPage('shop_1', limit: 2);
      expect(first.reviews.map((r) => r.bookingId), ['book_3', 'book_9']);
      expect(first.hasMore, isTrue);
      final second = await service.loadPage('shop_1', limit: 2, cursor: first.cursor);
      expect(second.reviews.map((r) => r.bookingId), ['book_10', 'book_11']);
      final third = await service.loadPage('shop_1', limit: 2, cursor: second.cursor);
      expect(third.reviews.map((r) => r.bookingId), ['book_12']);
      expect(third.hasMore, isFalse);

      final barber = await service.loadPage('shop_1', barberId: 'barber_2');
      expect(barber.reviews.map((r) => r.bookingId), ['book_10', 'book_12']);

      expect((await service.loadDistribution('shop_1')).counts, {1: 0, 2: 0, 3: 1, 4: 2, 5: 2});
      expect((await service.loadDistribution('shop_1', barberId: 'barber_1')).counts, {1: 0, 2: 0, 3: 0, 4: 0, 5: 2});
    });

    test('only the shop owner replies', () async {
      final review = (await service.loadPage('shop_1')).reviews.firstWhere((r) => r.bookingId == 'book_9');
      Matcher code(ReviewErrorCode c) => throwsA(isA<ReviewException>().having((e) => e.code, 'code', c));

      repo.switchRole(UserRole.customer);
      await expectLater(service.saveReply(review, 'Thanks'), code(ReviewErrorCode.ownerOnly));
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
      expect(service.canReply('shop_1'), isFalse);
      await expectLater(service.saveReply(review, 'Thanks'), code(ReviewErrorCode.ownerOnly));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      await expectLater(service.saveReply(review, 'Thanks'), code(ReviewErrorCode.ownerOnly));

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      expect(service.canReply('shop_1'), isTrue);
      await expectLater(service.saveReply(review, '   '), code(ReviewErrorCode.replyInvalid));
      await expectLater(
          service.saveReply(review, 'x' * (kReviewReplyMaxLength + 1)), code(ReviewErrorCode.replyInvalid));
      final updated = await service.saveReply(review, ' Thank you, Liya! ');
      expect(updated.reply, 'Thank you, Liya!');
      expect(updated.replyAt, _now);
      final stored = service.local.reviewsOf('shop_1').firstWhere((r) => r.bookingId == 'book_9');
      expect(stored.reply, 'Thank you, Liya!');
      expect(stored.rating, 5); // nothing else changes
      // Editing replaces it.
      expect((await service.saveReply(stored, 'Edited')).reply, 'Edited');
    });

    test('error texts in English and Amharic', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final am = lookupAppLocalizations(const Locale('am'));
      for (final code in ReviewErrorCode.values) {
        final e = ReviewException(code, const [500]);
        expect(en.reviewsErrorText(e), isNotEmpty);
        expect(am.reviewsErrorText(e), isNot(en.reviewsErrorText(e)), reason: code.name);
      }
      expect(en.reviewsErrorText(ReviewException(ReviewErrorCode.commentTooLong, const [500])), contains('500'));
      expect(en.reviewsSummaryText(const RatingSummary(rating: 4.5, count: 2)), '4.5 out of 5 · 2 reviews');
      expect(en.reviewsSummaryText(RatingSummary.empty), 'No reviews yet');
      expect(am.reviewsSummaryText(RatingSummary.empty), 'እስካሁን ግምገማ የለም');
    });
  });

  group('Firestore store', () {
    late FakeFirebaseFirestore db;
    late FirestoreReviewStore store;

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestoreReviewStore(db);
    });

    test('create once, page with a cursor, count per star, reply', () async {
      for (var i = 1; i <= 5; i++) {
        await store.create(_review('bk$i', i == 5 ? 4 : 5, DateTime.utc(2026, 11, i), barberId: i.isEven ? 'b2' : 'b1'));
      }
      final doc = await db.doc('barbershops/s1/reviews/bk1').get();
      expect(doc.data(), {
        'bookingId': 'bk1',
        'shopId': 's1',
        'barberId': 'b1',
        'customerId': 'c_bk1',
        'customerName': 'Customer bk1',
        'rating': 5,
        'createdAt': '2026-11-01T00:00:00.000Z',
      });
      await expectLater(
        store.create(_review('bk1', 1, DateTime.utc(2026, 11, 9))),
        throwsA(isA<ReviewException>().having((e) => e.code, 'code', ReviewErrorCode.alreadyReviewed)),
      );
      expect((await db.doc('barbershops/s1/reviews/bk1').get()).data()!['rating'], 5);

      final p1 = await store.fetchPage('s1', limit: 2);
      expect(p1.reviews.map((r) => r.bookingId), ['bk5', 'bk4']);
      expect(p1.hasMore, isTrue);
      final p2 = await store.fetchPage('s1', limit: 2, cursor: p1.cursor);
      expect(p2.reviews.map((r) => r.bookingId), ['bk3', 'bk2']);
      final p3 = await store.fetchPage('s1', limit: 2, cursor: p2.cursor);
      expect(p3.reviews.map((r) => r.bookingId), ['bk1']);
      expect(p3.hasMore, isFalse);
      expect((await store.fetchPage('s1', barberId: 'b2')).reviews.map((r) => r.bookingId), ['bk4', 'bk2']);

      expect((await store.distribution('s1')).counts, {1: 0, 2: 0, 3: 0, 4: 1, 5: 4});
      expect((await store.distribution('s1', barberId: 'b1')).counts, {1: 0, 2: 0, 3: 0, 4: 1, 5: 2});

      final review = p3.reviews.single;
      await store.updateReply(review, 'Thanks!', DateTime.utc(2026, 11, 10));
      final data = (await db.doc('barbershops/s1/reviews/bk1').get()).data()!;
      expect(data['reply'], 'Thanks!');
      expect(data['replyAt'], '2026-11-10T00:00:00.000Z');
      expect((await store.watchReview('s1', 'bk1').first)!.reply, 'Thanks!');
      expect(await store.watchReview('s1', 'missing').first, isNull);
    });

    test('the service writes through the Firestore store', () async {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.customer);
      final service = ReviewsService(cloud: store, clock: () => _now);
      await service.submitReview(repo.getBookingById('book_5')!, rating: 5, comment: 'Great');
      final data = (await db.doc('barbershops/shop_2/reviews/book_5').get()).data()!;
      expect(data['customerId'], 'user_cust_1');
      expect(data['barberId'], 'barber_2_1');
      expect(data['comment'], 'Great');
      expect(data['createdAt'], '2026-11-20T07:00:00.000Z');
      // Ratings come from the Cloud Function with Firebase; nothing local changes.
      expect(service.shopSummary('shop_2'), const RatingSummary(rating: 4.5, count: 2));
    });
  });

  group('widgets', () {
    setUp(() {
      loadTestSeed(now: _now);
      _seededService();
    });

    testWidgets('My Appointments: rate a completed visit, then see the stars', (tester) async {
      repo.switchRole(UserRole.customer); // user_cust_1
      await tester.pumpWidget(_app(CustomerBookingsScreen(clock: () => _now)));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byKey(const ValueKey('rate-booking-book_5')), 200);
      expect(find.byKey(const ValueKey('rate-booking-book_1')), findsNothing); // upcoming
      await tester.tap(find.byKey(const ValueKey('rate-booking-book_5')));
      await tester.pumpAndSettle();

      // Sending without stars asks for them.
      await tester.tap(find.byKey(const ValueKey('submit-review')));
      await tester.pumpAndSettle();
      expect(find.text('Tap a star to rate.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rate-star-4')));
      await tester.enterText(find.byKey(const ValueKey('review-comment')), 'Sharp cut');
      await tester.tap(find.byKey(const ValueKey('submit-review')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('submit-review')), findsNothing);
      expect(find.byKey(const ValueKey('rate-booking-book_5')), findsNothing);
      expect(find.byKey(const ValueKey('my-review-book_5')), findsOneWidget);
      expect(ReviewsService.instance.local.reviewsOf('shop_2').first.comment, 'Sharp cut');
      expect(repo.getShopById('shop_2')!.reviewCount, 3);
    });

    testWidgets('shop page: summary, distribution, latest reviews and barber ratings', (tester) async {
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(BarbershopDetailScreen(shop: repo.getShopById('shop_1')!)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('barber-rating-barber_1')), findsOneWidget);
      expect(find.text('5.0 (2)'), findsOneWidget); // barber_1
      expect(find.text('3.5 (2)'), findsOneWidget); // barber_2

      final section = find.byKey(const ValueKey('shop-reviews-section'));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('reviews-see-all')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: section, matching: find.byKey(const ValueKey('rating-average'))), findsOneWidget);
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('5 reviews'), findsOneWidget);
      final bar3 = tester.widget<Text>(find.byKey(const ValueKey('rating-bar-count-3')));
      expect(bar3.data, '1');
      expect(find.byKey(const ValueKey('review-book_3')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_11')), findsNothing); // only the latest 3
      expect(find.text('Rahel D.'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-reply-book_3')), findsOneWidget);

      // Clear the booking bar at the bottom of the page.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reviews-see-all')));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-review-book_3')), findsNothing); // customers cannot reply
      await tester.scrollUntilVisible(find.byKey(const ValueKey('review-book_12')), 300,
          scrollable: find.descendant(of: find.byKey(const ValueKey('reviews-list')), matching: find.byType(Scrollable)));
      expect(find.byKey(const ValueKey('reviews-load-more')), findsNothing); // 5 reviews fit one page
    });

    testWidgets('owner replies from the reviews list; load more pages', (tester) async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final service = ReviewsService.instance;
      await tester.pumpWidget(_app(ReviewsScreen(shopId: 'shop_1', service: service)));
      await tester.pumpAndSettle();

      expect(find.text('No reply yet'), findsWidgets);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('reply-review-book_9')), 200);
      await tester.ensureVisible(find.byKey(const ValueKey('reply-review-book_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reply-review-book_9')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('review-reply-field')), 'Thanks for coming!');
      await tester.tap(find.byKey(const ValueKey('save-reply')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('review-reply-book_9')), findsOneWidget);
      expect(find.text('Thanks for coming!'), findsOneWidget);
      expect(service.local.reviewsOf('shop_1').firstWhere((r) => r.bookingId == 'book_9').reply, 'Thanks for coming!');

    });

    testWidgets('reviews list loads more pages', (tester) async {
      repo.switchRole(UserRole.customer);
      final service = ReviewsService.instance;
      // shop_1 has 5 seeded reviews; 8 older ones make two pages of 10.
      for (var i = 0; i < 8; i++) {
        await service.local.create(_review('extra$i', 5, DateTime.utc(2026, 1, 1 + i), shopId: 'shop_1', barberId: 'barber_1'));
      }
      await tester.pumpWidget(_app(ReviewsScreen(shopId: 'shop_1', service: service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-extra0')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('reviews-load-more')), 300);
      await tester.ensureVisible(find.byKey(const ValueKey('reviews-load-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reviews-load-more')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('review-extra0')), 300);
      expect(find.byKey(const ValueKey('reviews-load-more')), findsNothing);
    });

    testWidgets('barber sees their own reviews read-only (Amharic)', (tester) async {
      repo.switchRole(UserRole.barber, targetBarberId: 'barber_2');
      final barber = repo.getBarberById('barber_2')!;
      await tester.pumpWidget(_app(Scaffold(body: BarberReviewsCard(barber: barber)), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('የእኔ ግምገማዎች'), findsOneWidget);
      expect(find.text('ከ5 3.5 · 2 ግምገማዎች'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('open-my-reviews')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-book_10')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_12')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_9')), findsNothing); // barber_1's
      expect(find.byKey(const ValueKey('reply-review-book_10')), findsNothing);
      expect(find.text('ከፀጉር ቤቱ የተሰጠ ምላሽ'), findsWidgets);
    });

    testWidgets('owner dashboard entry opens the reviews', (tester) async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.pumpWidget(_app(const Scaffold(body: OwnerReviewsButton(shopId: 'shop_1'))));
      expect(find.textContaining('4.2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-reviews')));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-review-book_3')), findsOneWidget);
    });
  });
}
