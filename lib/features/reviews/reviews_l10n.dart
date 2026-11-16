import '../../l10n/l10n.dart';
import '../../services/reviews_service.dart';

/// Review texts in the active language.
extension ReviewsL10n on AppLocalizations {
  /// [ReviewException]s by code; everything else via [errorText].
  String reviewsErrorText(Object error) {
    if (error is! ReviewException) return errorText(error);
    final first = error.args.isEmpty ? null : error.args.first;
    switch (error.code) {
      case ReviewErrorCode.notYourBooking:
        return reviewsErrNotYourBooking;
      case ReviewErrorCode.notCompleted:
        return reviewsErrNotCompleted;
      case ReviewErrorCode.alreadyReviewed:
        return reviewsErrAlreadyReviewed;
      case ReviewErrorCode.invalidRating:
        return reviewsErrInvalidRating;
      case ReviewErrorCode.commentTooLong:
        return reviewsErrCommentTooLong(first is int ? first : kReviewCommentMaxLength);
      case ReviewErrorCode.replyInvalid:
        return reviewsErrReplyInvalid(first is int ? first : kReviewReplyMaxLength);
      case ReviewErrorCode.ownerOnly:
        return reviewsErrOwnerOnly;
      case ReviewErrorCode.notFound:
        return reviewsErrNotFound;
    }
  }

  /// "4.5 out of 5 · 12 reviews", or "No reviews yet".
  String reviewsSummaryText(RatingSummary summary) =>
      summary.count == 0 ? reviewsCountLabel(0) : reviewsSummaryLine(summary.rating.toStringAsFixed(1), summary.count);

  /// "4.5 (12 reviews)", or "New" while nobody has rated yet (the stored
  /// rating is then only a model default or 0 from the function).
  String reviewsRatingShort(double rating, int count) =>
      count == 0 ? reviewsNew : reviewsCount(rating.toStringAsFixed(1), count);

  /// "4.5", or "New" while nobody has rated yet.
  String reviewsRatingValue(double rating, int count) => count == 0 ? reviewsNew : rating.toStringAsFixed(1);

  /// A barber's "4.5 (12 reviews)" or "New" (ratingSum / reviewCount).
  String barberRatingText(RatingSummary summary) => reviewsRatingShort(summary.rating, summary.count);

  /// A shop's "4.6 · 3 barbers rated" (average of its rated barbers'
  /// averages), or "New" while no barber has a review.
  String shopRatingText(ShopRating rating) =>
      rating.isNew ? reviewsNew : ratingShopSummary(rating.rating.toStringAsFixed(1), rating.ratedBarbers);
}
