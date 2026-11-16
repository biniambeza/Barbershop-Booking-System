import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_home_screen.dart';
import 'package:barbershop_booking/features/reviews/reviews_l10n.dart';
import 'package:barbershop_booking/features/reviews/screens/reviews_screen.dart';
import 'package:barbershop_booking/features/reviews/widgets/rate_prompt_banner.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/reviews_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// 10:00 in Addis on Friday 2026-11-20.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Barber _barber(String id, {int? ratingSum, int reviewCount = 0, double rating = 5.0}) => Barber(
      id: id,
      shopId: 's1',
      name: 'Barber $id',
      title: 'Barber',
      rating: rating,
      reviewCount: reviewCount,
      ratingSum: ratingSum,
    );

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    );

ReviewsService _seededService() {
  final service = ReviewsService(clock: () => _now);
  service.local.loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now);
  ReviewsService.instance = service;
  return service;
}

void main() {
  final repo = AppRepository.instance;
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => ReviewsService.instance = null);

  group('rating math', () {
    test('barber average = ratingSum / reviewCount, one decimal; none = New', () {
      expect(barberRatingSummary(_barber('a', ratingSum: 9, reviewCount: 2)), const RatingSummary(rating: 4.5, count: 2));
      expect(barberRatingSummary(_barber('a', ratingSum: 13, reviewCount: 3)), const RatingSummary(rating: 4.3, count: 3));
      expect(barberRatingSummary(_barber('a', ratingSum: 14, reviewCount: 3)), const RatingSummary(rating: 4.7, count: 3));
      expect(barberRatingSummary(_barber('a')), RatingSummary.empty); // default rating 5.0 is not shown
      expect(barberRatingSummary(_barber('a', ratingSum: 0, reviewCount: 0)).count, 0);
      expect(roundRating(4.25), 4.3);
      expect(roundRating(4.249), 4.2);
    });

    test('legacy docs without ratingSum use round(rating * reviewCount)', () {
      expect(_barber('a', rating: 3.5, reviewCount: 2).effectiveRatingSum, 7);
      expect(_barber('a', rating: 4.3, reviewCount: 3).effectiveRatingSum, 13);
      expect(_barber('a', rating: 5.0).effectiveRatingSum, 0);
      expect(_barber('a', rating: 4.3, reviewCount: 3, ratingSum: 12).effectiveRatingSum, 12);
      expect(barberRatingSummary(_barber('a', rating: 3.5, reviewCount: 2)), const RatingSummary(rating: 3.5, count: 2));
      // Read from Firestore maps.
      final legacy = Barber.fromMap({'shopId': 's1', 'name': 'A', 'rating': 4.5, 'reviewCount': 2}, 'a');
      expect((legacy.ratingSum, legacy.effectiveRatingSum), (null, 9));
      final fresh = Barber.fromMap({'shopId': 's1', 'name': 'A', 'ratingSum': 11, 'reviewCount': 3}, 'a');
      expect(barberRatingSummary(fresh), const RatingSummary(rating: 3.7, count: 3));
      expect(fresh.toMap()['ratingSum'], 11);
      expect(_barber('a').toMap().containsKey('ratingSum'), isFalse);
      expect(fresh.toProfileMap().containsKey('ratingSum'), isFalse); // owners never write it
    });

    test('shop rating = average of the rated barbers\' averages', () {
      final rating = shopRatingFromBarbers([
        _barber('b2', ratingSum: 7, reviewCount: 2), // 3.5
        _barber('b1', ratingSum: 10, reviewCount: 2), // 5.0
        _barber('b3', ratingSum: 4, reviewCount: 1), // 4.0
        _barber('b4'), // new: ignored
      ]);
      expect(rating, const ShopRating(rating: 4.2, ratedBarbers: 3, reviewCount: 5));
      expect(rating.summary, const RatingSummary(rating: 4.2, count: 5));
      // Not the plain average of all reviews (that would be 4.2 here too, so
      // a case where they differ): 4 x 5 stars and 1 x 1 star -> (5 + 1) / 2.
      expect(
        shopRatingFromBarbers([_barber('x', ratingSum: 20, reviewCount: 4), _barber('y', ratingSum: 1, reviewCount: 1)])
            .rating,
        3.0,
      );
    });

    test('a shop without rated barbers is New', () {
      expect(shopRatingFromBarbers(const []), ShopRating.empty);
      expect(shopRatingFromBarbers([_barber('a'), _barber('b')]).isNew, isTrue);
      expect(ShopRating.empty.summary, RatingSummary.empty);
    });

    test('sort by rating: higher first, New last', () {
      const a = ShopRating(rating: 4.2, ratedBarbers: 3, reviewCount: 5);
      const b = ShopRating(rating: 4.8, ratedBarbers: 1, reviewCount: 2);
      const c = ShopRating(rating: 4.2, ratedBarbers: 1, reviewCount: 9);
      final sorted = [ShopRating.empty, a, c, b]..sort(compareShopRatings);
      expect(sorted, [b, a, c, ShopRating.empty]);
    });

    test('the barber-doc update of a new review', () {
      final review = Review(
        bookingId: 'bk9',
        shopId: 's1',
        barberId: 'b1',
        customerId: 'c1',
        customerName: 'Liya Getachew',
        rating: 4,
        createdAt: _now,
      );
      expect(barberCounterUpdate({'ratingSum': 9, 'reviewCount': 2}, review),
          {'ratingSum': 13, 'reviewCount': 3, 'lastReviewId': 'bk9'});
      expect(barberCounterUpdate({'rating': 3.5, 'reviewCount': 2}, review),
          {'ratingSum': 11, 'reviewCount': 3, 'lastReviewId': 'bk9'});
      expect(barberCounterUpdate({'rating': 5.0}, review), {'ratingSum': 4, 'reviewCount': 1, 'lastReviewId': 'bk9'});
    });

    test('texts in English and Amharic', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final am = lookupAppLocalizations(const Locale('am'));
      const shop = ShopRating(rating: 4.6, ratedBarbers: 3, reviewCount: 8);
      expect(en.shopRatingText(shop), '4.6 · 3 barbers rated');
      expect(en.shopRatingText(const ShopRating(rating: 5, ratedBarbers: 1, reviewCount: 1)), '5.0 · 1 barber rated');
      expect(en.shopRatingText(ShopRating.empty), 'New');
      expect(am.shopRatingText(shop), '4.6 · 3 ፀጉር አስተካካዮች ተገምግመዋል');
      expect(am.shopRatingText(ShopRating.empty), 'አዲስ');
      expect(en.barberRatingText(const RatingSummary(rating: 4.5, count: 2)), '4.5 (2 reviews)');
      expect(en.barberRatingText(RatingSummary.empty), 'New');
      expect(en.reviewsRateAction, 'Rate your barber');
      expect(en.reviewsCommentHint, 'Tell us about your experience');
      expect(am.reviewsRateAction, isNot(en.reviewsRateAction));
    });
  });

  group('demo data', () {
    late ReviewsService service;

    setUp(() {
      loadTestSeed(now: _now);
      service = _seededService();
    });

    test('shop ratings come from the loaded barbers', () {
      expect(repo.shopRatingOf('shop_1'), const ShopRating(rating: 4.2, ratedBarbers: 3, reviewCount: 5));
      expect(repo.barberRatingOf('barber_2'), const RatingSummary(rating: 3.5, count: 2));
      expect(repo.barberRatingOf('nobody'), RatingSummary.empty);
    });

    test('a new review moves the barber and so the shop rating, once', () async {
      repo.switchRole(UserRole.customer); // user_cust_1
      final before = repo.shopRatingOf('shop_2'); // barber_2_1: 5, barber_2_2: 4
      expect(before, const ShopRating(rating: 4.5, ratedBarbers: 2, reviewCount: 2));
      await service.submitReview(repo.getBookingById('book_5')!, rating: 1);
      expect((repo.getBarberById('barber_2_1')!.ratingSum, repo.getBarberById('barber_2_1')!.reviewCount), (6, 2));
      expect(repo.shopRatingOf('shop_2'), const ShopRating(rating: 3.5, ratedBarbers: 2, reviewCount: 3));
      await expectLater(service.submitReview(repo.getBookingById('book_5')!, rating: 5), throwsA(isA<ReviewException>()));
      expect(repo.getBarberById('barber_2_1')!.reviewCount, 2);
    });

    test('owner profile edits keep the counters', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final b = repo.getBarberById('barber_2')!;
      await repo.updateBarber(b.copyWith(title: 'Head Stylist'));
      final after = repo.getBarberById('barber_2')!;
      expect((after.title, after.ratingSum, after.reviewCount), ('Head Stylist', 7, 2));
    });
  });

  group('rate prompt', () {
    Booking completed(String id, DateTime startAt, {String customerId = 'c1', BookingStatus status = BookingStatus.completed}) =>
        Booking(
          id: id,
          shopId: 's1',
          shopName: 'Shop',
          barberId: 'b1',
          barberName: 'Yonas',
          customerId: customerId,
          customerName: 'Liya',
          customerPhone: '+251911000301',
          serviceId: 'srv',
          serviceName: 'Fade',
          price: 300,
          date: DateTime(startAt.year, startAt.month, startAt.day),
          timeSlot: '10:00 AM',
          status: status,
          createdAt: startAt.subtract(const Duration(days: 1)),
          startAt: startAt,
          endAt: startAt.add(const Duration(minutes: 30)),
        );

    test('the newest completed visit of the customer, not prompted before, within two weeks', () {
      final bookings = [
        completed('old', _now.subtract(const Duration(days: 20))),
        completed('a', _now.subtract(const Duration(days: 3))),
        completed('b', _now.subtract(const Duration(days: 1))),
        completed('other', _now.subtract(const Duration(hours: 2)), customerId: 'c2'),
        completed('confirmed', _now.subtract(const Duration(hours: 3)), status: BookingStatus.confirmed),
      ];
      String? pick(Set<String> prompted) =>
          ratePromptCandidate(bookings, customerId: 'c1', alreadyPrompted: prompted, nowUtc: _now)?.id;
      expect(pick({}), 'b');
      expect(pick({'b'}), 'a');
      expect(pick({'a', 'b'}), isNull);
    });

    test('the store remembers prompted visits (in memory without preferences)', () async {
      final store = RatePromptStore(usePreferences: false);
      expect(await store.load(), isEmpty);
      await store.markShown('bk1');
      expect(store.wasShown('bk1'), isTrue);
      for (var i = 0; i < RatePromptStore.maxKept + 5; i++) {
        await store.markShown('x$i');
      }
      expect(store.wasShown('bk1'), isFalse); // oldest dropped
    });

    testWidgets('banner on the next open: rate from it, shown only once', (tester) async {
      loadTestSeed(now: _now);
      _seededService();
      repo.switchRole(UserRole.customer); // user_cust_1: book_5 completed, not reviewed
      final store = RatePromptStore(usePreferences: false);
      await tester.pumpWidget(_app(Scaffold(body: RatePromptBanner(store: store, clock: () => _now))));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rate-prompt-book_5')), findsOneWidget);
      expect(find.text('How was your cut?'), findsOneWidget);
      expect(store.wasShown('book_5'), isTrue);

      await tester.tap(find.byKey(const ValueKey('rate-prompt-action')));
      await tester.pumpAndSettle();
      expect(find.text('Rate your barber'), findsWidgets);
      expect(find.text('Tell us about your experience'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rate-star-5')));
      // No comment: optional.
      await tester.tap(find.byKey(const ValueKey('submit-review')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rate-prompt-book_5')), findsNothing);
      final review = ReviewsService.instance.local.reviewsOf('shop_2').firstWhere((r) => r.bookingId == 'book_5');
      expect((review.rating, review.comment), (5, null));
      expect(repo.getBarberById('barber_2_1')!.reviewCount, 2);
    });

    testWidgets('dismissed, and not shown again on the next open', (tester) async {
      loadTestSeed(now: _now);
      _seededService();
      repo.switchRole(UserRole.customer);
      final store = RatePromptStore(usePreferences: false);
      await tester.pumpWidget(_app(Scaffold(body: RatePromptBanner(store: store, clock: () => _now))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rate-prompt-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rate-prompt-book_5')), findsNothing);

      // "Next app open": a new banner with the same store.
      await tester.pumpWidget(_app(const Scaffold(body: SizedBox())));
      await tester.pumpWidget(_app(Scaffold(body: RatePromptBanner(store: store, clock: () => _now))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rate-prompt-book_5')), findsNothing);
    });

    testWidgets('no banner for owners or when the visit is already reviewed', (tester) async {
      loadTestSeed(now: _now);
      final service = _seededService();
      repo.switchRole(UserRole.customer);
      await service.submitReview(repo.getBookingById('book_5')!, rating: 4);
      await tester.pumpWidget(_app(Scaffold(body: RatePromptBanner(store: RatePromptStore(usePreferences: false), clock: () => _now))));
      await tester.pumpAndSettle();
      expect(find.byType(Container), findsNothing);

      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_2');
      await tester.pumpWidget(_app(Scaffold(body: RatePromptBanner(store: RatePromptStore(usePreferences: false), clock: () => _now))));
      await tester.pumpAndSettle();
      expect(find.text('How was your cut?'), findsNothing);
    });
  });

  group('customer home', () {
    testWidgets('shop cards show the computed rating and the prompt; no overflow at 360 px in Amharic',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      RatePromptStore.instance = RatePromptStore();
      addTearDown(() => RatePromptStore.instance = RatePromptStore());
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      loadTestSeed(now: _now);
      _seededService();
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(const CustomerHomeScreen(), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('shop-rating-shop_1')), findsOneWidget);
      expect(find.text('4.2 · 3 ፀጉር አስተካካዮች ተገምግመዋል'), findsOneWidget);
      expect(find.byKey(const ValueKey('rate-prompt-book_5')), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(RatePromptStore.prefsKey), ['book_5']);
    });
  });

  group('per-barber reviews', () {
    setUp(() {
      loadTestSeed(now: _now);
      _seededService();
      repo.switchRole(UserRole.customer);
    });

    testWidgets('the barber card opens that barber\'s reviews', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(BarbershopDetailScreen(shop: repo.getShopById('shop_1')!)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-barber-reviews-barber_2')));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewsScreen), findsOneWidget);
      expect(find.text('Reviews for Kaleab Mekonnen'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_10')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_12')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_9')), findsNothing); // Yonas'
      expect(find.text('3.5'), findsOneWidget); // the barber's average
    });

    testWidgets('the shop reviews section filters by barber', (tester) async {
      await tester.pumpWidget(_app(BarbershopDetailScreen(shop: repo.getShopById('shop_1')!)));
      await tester.pumpAndSettle();
      final chip = find.byKey(const ValueKey('barber-reviews-barber_1'));
      await tester.scrollUntilVisible(chip, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Reviews for Yonas Tadesse'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_3')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_9')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-book_10')), findsNothing);
    });
  });
}
