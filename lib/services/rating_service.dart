/// Rating math shared by every screen that shows a barber's or a shop's
/// rating. Pure functions (no Firebase), mirrored by
/// functions/insights/src/logic/ratings.ts.
///
///  * Barber: `ratingSum / reviewCount` (one decimal). The customer's app
///    adds the review's stars to `ratingSum` and 1 to `reviewCount` in the
///    transaction that creates the review, adds (new - old) stars when the
///    customer edits it and takes the stars and 1 off when they delete it
///    (firestore.rules checks the maths).
///    Legacy docs without `ratingSum` use round(rating * reviewCount).
///    No reviews = "New".
///  * Shop: the average of its rated barbers' averages (barbers with
///    reviewCount > 0), one decimal, computed from the barbers the app has
///    already loaded. No rated barber = "New". The shop doc's own
///    `rating` / `reviewCount` fields are not used for display.
library;

import '../models/barber_model.dart';
import '../models/review_model.dart';

/// One decimal, half up. The tiny epsilon keeps values such as 4.25 that
/// floating point stores as 4.2499999 on the same side in Dart and in the
/// insights function.
/// Ratings are never negative, so Dart's round (half away from zero) and
/// JavaScript's Math.round (half up) agree.
double roundRating(double value) => (value * 10 + 1e-9).round() / 10;

/// A barber's average (one decimal) and review count; [RatingSummary.empty]
/// ("New") without reviews.
RatingSummary barberRatingSummary(Barber barber) => barberRatingFromCounters(
      ratingSum: barber.effectiveRatingSum,
      reviewCount: barber.reviewCount,
    );

/// [barberRatingSummary] from the raw counters.
RatingSummary barberRatingFromCounters({required int ratingSum, required int reviewCount}) {
  if (reviewCount <= 0) return RatingSummary.empty;
  return RatingSummary(rating: roundRating(ratingSum / reviewCount), count: reviewCount);
}

/// A shop's rating: the average of its rated barbers' averages.
class ShopRating {
  const ShopRating({required this.rating, required this.ratedBarbers, required this.reviewCount});

  /// Average of the rated barbers' (unrounded) averages, one decimal; 0
  /// when [isNew].
  final double rating;

  /// Barbers with at least one review.
  final int ratedBarbers;

  /// Reviews of those barbers together.
  final int reviewCount;

  static const ShopRating empty = ShopRating(rating: 0, ratedBarbers: 0, reviewCount: 0);

  /// No rated barber yet: shown as "New".
  bool get isNew => ratedBarbers == 0;

  /// For the summary card and badges: the shop average with the number of
  /// reviews behind it.
  RatingSummary get summary => isNew ? RatingSummary.empty : RatingSummary(rating: rating, count: reviewCount);

  @override
  bool operator ==(Object other) =>
      other is ShopRating &&
      other.rating == rating &&
      other.ratedBarbers == ratedBarbers &&
      other.reviewCount == reviewCount;

  @override
  int get hashCode => Object.hash(rating, ratedBarbers, reviewCount);

  @override
  String toString() => 'ShopRating($rating, $ratedBarbers barbers, $reviewCount reviews)';
}

/// The shop rating from its [barbers] (only those with reviews count).
/// Barbers are taken in id order so the floating-point sum is the same as
/// in the insights function.
ShopRating shopRatingFromBarbers(Iterable<Barber> barbers) {
  final rated = barbers.where((b) => b.reviewCount > 0).toList()..sort((a, b) => a.id.compareTo(b.id));
  if (rated.isEmpty) return ShopRating.empty;
  var sum = 0.0;
  var reviews = 0;
  for (final b in rated) {
    sum += b.effectiveRatingSum / b.reviewCount;
    reviews += b.reviewCount;
  }
  return ShopRating(rating: roundRating(sum / rated.length), ratedBarbers: rated.length, reviewCount: reviews);
}

/// Higher rated first; "New" shops last; ties by more rated barbers, then
/// more reviews. For any "sort by rating".
int compareShopRatings(ShopRating a, ShopRating b) {
  if (a.isNew != b.isNew) return a.isNew ? 1 : -1;
  final byRating = b.rating.compareTo(a.rating);
  if (byRating != 0) return byRating;
  final byBarbers = b.ratedBarbers.compareTo(a.ratedBarbers);
  return byBarbers != 0 ? byBarbers : b.reviewCount.compareTo(a.reviewCount);
}

/// The barber-doc update written with a new review (same transaction):
/// `ratingSum` + stars, `reviewCount` + 1 and `lastReviewId` (the review's
/// doc id, which lets firestore.rules find the review in the same write).
/// [barberDoc] is the barber document as read in the transaction.
Map<String, Object> barberCounterUpdate(Map<String, dynamic> barberDoc, Review review) {
  final current = Barber.fromMap(barberDoc, review.barberId);
  return {
    'ratingSum': current.effectiveRatingSum + review.rating,
    'reviewCount': current.reviewCount + 1,
    'lastReviewId': review.bookingId,
  };
}

/// The barber-doc update written with an edited review (same transaction):
/// `ratingSum` + ([newRating] - [oldRating]), `reviewCount` unchanged and
/// `lastReviewId` = [reviewId]. [oldRating] is the stored review's rating as
/// read in the transaction.
Map<String, Object> barberCounterEditUpdate(
  Map<String, dynamic> barberDoc, {
  required String barberId,
  required String reviewId,
  required int oldRating,
  required int newRating,
}) {
  final current = Barber.fromMap(barberDoc, barberId);
  return {
    'ratingSum': current.effectiveRatingSum + newRating - oldRating,
    'lastReviewId': reviewId,
  };
}

/// The barber-doc update written with a deleted review (same transaction):
/// `ratingSum` - its stars, `reviewCount` - 1 and `lastReviewId` = the
/// review's id. [review] is the stored review as read in the transaction.
Map<String, Object> barberCounterDeleteUpdate(Map<String, dynamic> barberDoc, Review review) {
  final current = Barber.fromMap(barberDoc, review.barberId);
  return {
    'ratingSum': current.effectiveRatingSum - review.rating,
    'reviewCount': current.reviewCount - 1,
    'lastReviewId': review.bookingId,
  };
}
