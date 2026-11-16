/// New-review notices: when a customer reviews a visit, the shop's owner
/// (and, where the app knows their account, the reviewed barber) gets an
/// inbox entry.
///
/// Free Spark plan: the customer's app writes the owner's entry in the
/// same transaction that creates the review (FirestoreReviewStore.create),
/// at `users/{ownerId}/notifications/{reviewNotificationId}`. The customer
/// cannot see staff accounts, so the barber's entry and the pushes come
/// from functions/notifications reviews.ts on Blaze (same doc id, so the
/// owner never gets two entries). In local mode (DEMO_MODE, tests) the
/// barber's entry is delivered too.
///
/// Pure logic (no Firebase, no Flutter), mirrored by
/// functions/notifications/src/reviews.ts.
library;

import '../models/app_notification.dart' show AppNotification, NotificationTypes;
import '../models/review_model.dart';

/// Inbox doc id of the notice for the review [reviewId] created at
/// [createdAtIso] (the stored `createdAt` string): `review_{reviewId}_{the
/// digits of createdAt}`. Deterministic, so the customer's app and the
/// Cloud Function write the same doc; a review deleted and written again
/// gets a new id (the old notice stays and cannot block the new one).
String reviewNotificationId(String reviewId, String createdAtIso) =>
    'review_${reviewId}_${createdAtIso.replaceAll(RegExp(r'[^0-9]'), '')}';

/// One inbox entry to write for a new review.
class ReviewNotice {
  const ReviewNotice({
    required this.id,
    required this.recipientUid,
    required this.bookingId,
    required this.shopId,
    required this.barberId,
    required this.rating,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  /// [reviewNotificationId].
  final String id;

  /// `users/{recipientUid}/notifications/{id}`.
  final String recipientUid;

  /// The reviewed booking (= the review's id).
  final String bookingId;
  final String shopId;
  final String barberId;
  final int rating;
  final String title;
  final String body;

  /// The review's stored `createdAt` (ISO string, UTC).
  final String createdAt;

  /// Exactly the keys the rules accept for a customer-created review notice.
  Map<String, dynamic> toMap() => {
        'type': NotificationTypes.newReview,
        'title': title,
        'body': body,
        'bookingId': bookingId,
        'shopId': shopId,
        'barberId': barberId,
        'rating': rating,
        'read': false,
        'createdAt': createdAt,
      };

  AppNotification toAppNotification() => AppNotification(
        id: id,
        title: title,
        body: body,
        type: NotificationTypes.newReview,
        bookingId: bookingId,
        createdAt: DateTime.parse(createdAt).toUtc(),
        rating: rating,
      );
}

/// The inbox entries for a new [review]: the shop's owner ([ownerUid]) and
/// [barberUids] (the barber's accounts, when known), each once, never the
/// reviewing customer. [languageOf] gives a recipient's language when known;
/// unknown means Amharic (the app re-renders the copy in the viewer's
/// language, [renderReviewNoticeText]).
List<ReviewNotice> planReviewNotices(
  Review review, {
  String? ownerUid,
  Iterable<String> barberUids = const [],
  String barberName = '',
  String? Function(String uid)? languageOf,
}) {
  final createdAt = review.toMap()['createdAt'] as String;
  final id = reviewNotificationId(review.bookingId, createdAt);
  final recipients = <String>[];
  for (final uid in [ownerUid, ...barberUids]) {
    if (uid == null || uid.isEmpty || uid == review.customerId || recipients.contains(uid)) continue;
    recipients.add(uid);
  }
  return [
    for (final uid in recipients)
      () {
        final text = renderReviewNoticeText(
          rating: review.rating,
          customerName: review.customerName,
          barberName: barberName,
          language: languageOf?.call(uid),
        );
        return ReviewNotice(
          id: id,
          recipientUid: uid,
          bookingId: review.bookingId,
          shopId: review.shopId,
          barberId: review.barberId,
          rating: review.rating,
          title: text.title,
          body: text.body,
          createdAt: createdAt,
        );
      }(),
  ];
}

/// Copy of a new-review notice in [language] ('en'; anything else,
/// including null, is Amharic). Only the customer's first name is used.
/// Matches reviews.ts.
({String title, String body}) renderReviewNoticeText({
  required int rating,
  required String customerName,
  required String barberName,
  String? language,
}) {
  final first = customerFirstName(customerName);
  final stars = '★' * rating.clamp(1, 5);
  if (language == 'en') {
    final who = first.isEmpty ? 'A customer' : first;
    return (
      title: 'New review $stars',
      body: barberName.isEmpty ? '$who rated their visit $rating/5.' : '$who rated $barberName $rating/5.',
    );
  }
  final who = first.isEmpty ? 'አንድ ደንበኛ' : first;
  return (
    title: 'አዲስ ግምገማ $stars',
    body: barberName.isEmpty ? '$who ለጉብኝታቸው $rating/5 ሰጥተዋል።' : '$who ለ$barberName $rating/5 ሰጥተዋል።',
  );
}
