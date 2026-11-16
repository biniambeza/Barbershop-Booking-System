import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/features/notifications/screens/notifications_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/review_notices.dart';
import 'package:barbershop_booking/services/reviews_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// 10:00 in Addis on Friday 2026-11-20.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Matcher _code(ReviewErrorCode c) => throwsA(isA<ReviewException>().having((e) => e.code, 'code', c));

Review _review(String id, int rating, {String barberId = 'b1', String? comment, String customerId = 'c1'}) => Review(
      bookingId: id,
      shopId: 's1',
      barberId: barberId,
      customerId: customerId,
      customerName: 'Liya Getachew',
      rating: rating,
      comment: comment,
      createdAt: DateTime.utc(2026, 11, 1, 9),
    );

void main() {
  final repo = AppRepository.instance;
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => ReviewsService.instance = null);

  group('model and notices', () {
    test('editedAt round trip and copyWith can clear the comment', () {
      final r = _review('bk1', 4, comment: 'Nice');
      expect(r.isEdited, isFalse);
      expect(r.toMap().containsKey('editedAt'), isFalse);
      final edited = r.copyWith(rating: 2, clearComment: true, editedAt: DateTime.utc(2026, 11, 2));
      expect((edited.rating, edited.comment, edited.isEdited), (2, null, true));
      final back = Review.fromMap(edited.toMap(), 'bk1');
      expect(back.editedAt, DateTime.utc(2026, 11, 2));
      expect(back.toMap()['editedAt'], '2026-11-02T00:00:00.000Z');
    });

    test('counter updates for edit and delete (legacy docs too)', () {
      final doc = {'shopId': 's1', 'name': 'Abel', 'title': 'x', 'ratingSum': 9, 'reviewCount': 2};
      expect(barberCounterEditUpdate(doc, barberId: 'b1', reviewId: 'bk1', oldRating: 4, newRating: 1),
          {'ratingSum': 6, 'lastReviewId': 'bk1'});
      expect(barberCounterDeleteUpdate(doc, _review('bk1', 4)), {'ratingSum': 5, 'reviewCount': 1, 'lastReviewId': 'bk1'});
      final legacy = {'shopId': 's1', 'name': 'Abel', 'title': 'x', 'rating': 3.5, 'reviewCount': 2};
      expect(barberCounterDeleteUpdate(legacy, _review('bk1', 4)), {'ratingSum': 3, 'reviewCount': 1, 'lastReviewId': 'bk1'});
    });

    test('notice id, recipients and copy (English and Amharic)', () {
      expect(reviewNotificationId('bk1', '2026-11-01T09:00:00.000Z'), 'review_bk1_20261101090000000');
      final notices = planReviewNotices(_review('bk1', 4),
          ownerUid: 'owner', barberUids: ['barberU', 'owner', 'c1'], barberName: 'Yonas',
          languageOf: (uid) => uid == 'owner' ? 'en' : null);
      expect(notices.map((n) => n.recipientUid), ['owner', 'barberU']);
      expect(notices.first.toMap(), {
        'type': 'newReview',
        'title': 'New review ★★★★',
        'body': 'Liya rated Yonas 4/5.',
        'bookingId': 'bk1',
        'shopId': 's1',
        'barberId': 'b1',
        'rating': 4,
        'read': false,
        'createdAt': '2026-11-01T09:00:00.000Z',
      });
      expect(notices.last.title, 'አዲስ ግምገማ ★★★★');
      expect(notices.last.body, 'Liya ለYonas 4/5 ሰጥተዋል።');
      expect(planReviewNotices(_review('bk1', 4), ownerUid: 'c1'), isEmpty); // never the reviewer
      expect(planReviewNotices(_review('bk1', 4)), isEmpty);
    });
  });

  group('local service', () {
    late ReviewsService service;
    late List<ReviewNotice> delivered;

    setUp(() {
      loadTestSeed(now: _now);
      delivered = [];
      service = ReviewsService(clock: () => _now, onLocalNotice: delivered.add);
      service.local.loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now);
      ReviewsService.instance = service;
    });

    test('a new review tells the shop owner (and, locally, the barber)', () async {
      repo.switchRole(UserRole.customer); // user_cust_1
      await service.submitReview(repo.getBookingById('book_5')!, rating: 3);
      expect(delivered.map((n) => n.recipientUid), ['owner_2']); // barber_2_1 has no account
      expect(delivered.single.id, 'review_book_5_20261120070000000');
      expect(delivered.single.rating, 3);

      // book_9 (shop_1, barber_1 = barber_user_1): delete the seeded review, rate again.
      final old = service.local.reviewsOf('shop_1').firstWhere((r) => r.bookingId == 'book_9');
      await service.deleteReview(old);
      delivered.clear();
      await service.submitReview(repo.getBookingById('book_9')!, rating: 4);
      expect(delivered.map((n) => n.recipientUid), [repo.getShopById('shop_1')!.ownerId, 'barber_user_1']);
    });

    test('edit: stars and comment change, marked edited, barber sum follows', () async {
      repo.switchRole(UserRole.customer);
      final review = await service.submitReview(repo.getBookingById('book_5')!, rating: 3, comment: 'Slow');
      expect((repo.getBarberById('barber_2_1')!.ratingSum, repo.getBarberById('barber_2_1')!.reviewCount), (8, 2));
      final shopBefore = service.shopRating('shop_2');

      final edited = await service.updateReview(review, rating: 5, comment: '  ');
      expect((edited.rating, edited.comment, edited.editedAt), (5, null, _now));
      final stored = service.local.reviewsOf('shop_2').firstWhere((r) => r.bookingId == 'book_5');
      expect((stored.rating, stored.comment, stored.isEdited), (5, null, true));
      expect(stored.createdAt, review.createdAt);
      final b21 = repo.getBarberById('barber_2_1')!;
      expect((b21.ratingSum, b21.reviewCount), (10, 2)); // 8 + 5 - 3, count unchanged
      expect(service.barberSummary('barber_2_1'), const RatingSummary(rating: 5.0, count: 2));
      expect(service.shopRating('shop_2').rating, greaterThan(shopBefore.rating));

      // A comment-only edit leaves the counters alone.
      await service.updateReview(stored, rating: 5, comment: 'Great after all');
      expect(repo.getBarberById('barber_2_1')!.ratingSum, 10);
      expect(service.local.reviewsOf('shop_2').firstWhere((r) => r.bookingId == 'book_5').comment, 'Great after all');

      await expectLater(service.updateReview(stored, rating: 0), _code(ReviewErrorCode.invalidRating));
      await expectLater(service.updateReview(stored, rating: 4, comment: 'x' * (kReviewCommentMaxLength + 1)),
          _code(ReviewErrorCode.commentTooLong));
    });

    test('delete: stars and count leave the barber; the visit can be rated again', () async {
      repo.switchRole(UserRole.customer);
      final booking = repo.getBookingById('book_5')!;
      final review = await service.submitReview(booking, rating: 3);
      await service.deleteReview(review);
      final b21 = repo.getBarberById('barber_2_1')!;
      expect((b21.ratingSum, b21.reviewCount), (5, 1)); // back to the seeded 5
      expect(service.local.reviewsOf('shop_2').any((r) => r.bookingId == 'book_5'), isFalse);
      await expectLater(service.deleteReview(review), _code(ReviewErrorCode.notFound));
      await expectLater(service.updateReview(review, rating: 4), _code(ReviewErrorCode.notFound));

      await service.submitReview(booking, rating: 4);
      expect(repo.getBarberById('barber_2_1')!.reviewCount, 2);
    });

    test('only the review\'s customer may edit or delete it', () async {
      final someoneElses = service.local.reviewsOf('shop_1').firstWhere((r) => r.bookingId == 'book_3'); // user_cust_3
      repo.switchRole(UserRole.customer); // user_cust_1
      expect(service.canEditReview(someoneElses), isFalse);
      await expectLater(service.updateReview(someoneElses, rating: 1), _code(ReviewErrorCode.notYourBooking));
      await expectLater(service.deleteReview(someoneElses), _code(ReviewErrorCode.notYourBooking));
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await expectLater(service.deleteReview(someoneElses), _code(ReviewErrorCode.notYourBooking));
      expect(service.local.reviewsOf('shop_1').any((r) => r.bookingId == 'book_3'), isTrue);
    });
  });

  group('Firestore store', () {
    late FakeFirebaseFirestore db;
    late FirestoreReviewStore store;

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestoreReviewStore(db);
    });

    Future<Map<String, dynamic>> barber(String id) async => (await db.doc('barbershops/s1/barbers/$id').get()).data()!;

    test('create writes the owner notice in the same transaction', () async {
      final review = _review('bk1', 4);
      final notices = planReviewNotices(review, ownerUid: 'owner_1', barberName: 'Yonas');
      await store.create(review, notices: notices);
      final note = (await db.doc('users/owner_1/notifications/review_bk1_20261101090000000').get()).data()!;
      expect(note['type'], 'newReview');
      expect(note['rating'], 4);
      expect(note['createdAt'], '2026-11-01T09:00:00.000Z');
      // A second create fails as a whole: no second notice either.
      await expectLater(store.create(review, notices: notices), _code(ReviewErrorCode.alreadyReviewed));
      expect((await db.collection('users/owner_1/notifications').get()).docs, hasLength(1));
    });

    test('edit and delete keep the barber counters right', () async {
      await db.doc('barbershops/s1/barbers/b1').set({'shopId': 's1', 'name': 'Abel', 'title': 'x', 'reviewCount': 0});
      await store.create(_review('bk1', 5, comment: 'Great'));
      await store.create(_review('bk2', 4));
      expect(((await barber('b1'))['ratingSum'], (await barber('b1'))['reviewCount']), (9, 2));

      // Edit uses the stored stars (5), not the caller's copy.
      final before = await store.update(_review('bk1', 3).copyWith(rating: 2, editedAt: DateTime.utc(2026, 11, 5)));
      expect(before.rating, 5);
      final data = (await db.doc('barbershops/s1/reviews/bk1').get()).data()!;
      expect((data['rating'], data.containsKey('comment'), data['editedAt']), (2, false, '2026-11-05T00:00:00.000Z'));
      var b = await barber('b1');
      expect((b['ratingSum'], b['reviewCount'], b['lastReviewId']), (6, 2, 'bk1'));

      // Same stars: only the review changes.
      await store.update(_review('bk2', 4, comment: 'ok').copyWith(editedAt: DateTime.utc(2026, 11, 6)));
      b = await barber('b1');
      expect((b['ratingSum'], b['lastReviewId']), (6, 'bk1'));
      expect((await db.doc('barbershops/s1/reviews/bk2').get()).data()!['comment'], 'ok');

      final removed = await store.delete('s1', 'bk2');
      expect(removed.rating, 4);
      b = await barber('b1');
      expect((b['ratingSum'], b['reviewCount'], b['lastReviewId']), (2, 1, 'bk2'));
      expect((await db.doc('barbershops/s1/reviews/bk2').get()).exists, isFalse);
      await expectLater(store.delete('s1', 'bk2'), _code(ReviewErrorCode.notFound));
      await expectLater(store.update(_review('bk2', 1).copyWith(editedAt: _now)), _code(ReviewErrorCode.notFound));
    });

    test('legacy barber doc (no ratingSum) and a removed barber', () async {
      await db.doc('barbershops/s1/barbers/b2').set({'shopId': 's1', 'name': 'B', 'title': 'x', 'rating': 3.5, 'reviewCount': 2});
      await db.doc('barbershops/s1/reviews/old').set(_review('old', 4, barberId: 'b2').toMap());
      await store.delete('s1', 'old');
      final b = await barber('b2');
      expect((b['ratingSum'], b['reviewCount']), (3, 1));

      await db.doc('barbershops/s1/reviews/gone').set(_review('gone', 4, barberId: 'nobody').toMap());
      await store.update(_review('gone', 4, barberId: 'nobody').copyWith(rating: 1, editedAt: _now));
      await store.delete('s1', 'gone');
      expect((await db.doc('barbershops/s1/barbers/nobody').get()).exists, isFalse);
    });

    test('the service writes the owner notice with Firebase (no barber notice)', () async {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.customer);
      final service = ReviewsService(cloud: store, clock: () => _now);
      await service.submitReview(repo.getBookingById('book_9')!, rating: 5);
      final notes = await db.collection('users/${repo.getShopById('shop_1')!.ownerId}/notifications').get();
      expect(notes.docs.map((d) => d.id), ['review_book_9_20261120070000000']);
      expect((await db.collection('users/barber_user_1/notifications').get()).docs, isEmpty);
    });
  });

  group('widgets', () {
    setUp(() {
      loadTestSeed(now: _now);
      final service = ReviewsService(clock: () => _now, onLocalNotice: (_) {});
      service.local.loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now);
      ReviewsService.instance = service;
    });

    Widget app(Widget child) => MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: child,
        );

    testWidgets('My Appointments: edit the stars, then delete the review', (tester) async {
      repo.switchRole(UserRole.customer); // user_cust_1
      await ReviewsService.instance.submitReview(repo.getBookingById('book_5')!, rating: 3, comment: 'Slow');
      await tester.pumpWidget(app(CustomerBookingsScreen(clock: () => _now)));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byKey(const ValueKey('my-review-book_5')), 200);
      await tester.ensureVisible(find.byKey(const ValueKey('my-review-book_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-review-book_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-review-book_5')));
      await tester.pumpAndSettle();
      expect(find.text('Edit your review'), findsOneWidget);
      expect(find.text('Slow'), findsOneWidget); // prefilled
      await tester.tap(find.byKey(const ValueKey('rate-star-5')));
      await tester.tap(find.byKey(const ValueKey('submit-review')));
      await tester.pumpAndSettle();
      expect(repo.getBarberById('barber_2_1')!.ratingSum, 10);
      expect(find.text('edited'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('my-review-book_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-review-book_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-review-book_5')));
      await tester.pumpAndSettle();
      expect(find.text('Delete your review?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete-review')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-review-book_5')), findsNothing);
      expect(find.byKey(const ValueKey('rate-booking-book_5')), findsOneWidget);
      expect(repo.getBarberById('barber_2_1')!.reviewCount, 1);
    });

    test('inbox re-renders a review notice in the viewer\'s language and opens the shop\'s reviews', () {
      final n = AppNotification(
        id: 'review_book_5_x',
        title: 'stored',
        body: 'stored',
        type: NotificationTypes.newReview,
        bookingId: 'book_5',
        createdAt: _now,
        rating: 4,
      );
      expect(AppNotification.fromMap(n.toMap(), n.id).rating, 4);
      final en = reviewNoticeDisplayText(n, 'en')!;
      expect(en.title, 'New review ★★★★');
      expect(en.body, startsWith('Liya rated '));
      expect(reviewNoticeDisplayText(n, 'am')!.title, 'አዲስ ግምገማ ★★★★');
      expect(reviewNoticeShopId(n), 'shop_2');
      expect(notificationIcon(NotificationTypes.newReview).$1, Icons.star_rounded);
    });
  });
}
