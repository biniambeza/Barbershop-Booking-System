/// Customer reviews of completed bookings and the rating summaries shown on
/// shops and barbers.
///
/// Firestore: `barbershops/{shopId}/reviews/{bookingId}` (public read). The
/// customer of a completed booking creates it once (doc id = bookingId),
/// and may later edit its stars / comment (sets [Review.editedAt]) or
/// delete it; the shop owner may add or edit [Review.reply] only. The same
/// transaction keeps the barber's `ratingSum` / `reviewCount` in line
/// (create: + stars, + 1; edit: + new - old; delete: - stars, - 1); barber
/// and shop ratings are computed from those counters in
/// lib/services/rating_service.dart.
library;

/// Longest review comment (characters, after trimming).
const int kReviewCommentMaxLength = 500;

/// Longest owner reply (characters, after trimming).
const int kReviewReplyMaxLength = 500;

/// Reviews per page in the paginated lists.
const int kReviewPageSize = 10;

bool isValidReviewRating(Object? value) => value is int && value >= 1 && value <= 5;

class Review {
  Review({
    required this.bookingId,
    required this.shopId,
    required this.barberId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reply,
    this.replyAt,
    this.editedAt,
  });

  /// Also the document id.
  final String bookingId;
  final String shopId;
  final String barberId;
  final String customerId;

  /// The booking's customer name (only the first name is shown, see
  /// [displayName]).
  final String customerName;

  /// Whole stars, 1..5.
  final int rating;
  final String? comment;
  final DateTime createdAt;

  /// The shop owner's public answer.
  final String? reply;
  final DateTime? replyAt;

  /// When the customer last changed the stars or the comment (null = never
  /// edited; shown as "edited").
  final DateTime? editedAt;

  String get id => bookingId;

  bool get hasComment => comment != null && comment!.isNotEmpty;
  bool get hasReply => reply != null && reply!.isNotEmpty;
  bool get isEdited => editedAt != null;

  /// First name only ("Liya"), so full names are not shown publicly.
  /// Empty when the name is empty.
  String get displayName => customerFirstName(customerName);

  /// The document written on create (no reply fields; optional comment
  /// left out when empty).
  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'shopId': shopId,
        'barberId': barberId,
        'customerId': customerId,
        'customerName': customerName,
        'rating': rating,
        if (hasComment) 'comment': comment,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (hasReply) 'reply': reply,
        if (replyAt != null) 'replyAt': replyAt!.toUtc().toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
      };

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
    final rating = map['rating'];
    final comment = (map['comment'] as String?)?.trim();
    final reply = (map['reply'] as String?)?.trim();
    return Review(
      bookingId: id,
      shopId: map['shopId'] as String? ?? '',
      barberId: map['barberId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      rating: rating is num ? rating.toInt().clamp(1, 5) : 5,
      comment: comment == null || comment.isEmpty ? null : comment,
      createdAt: date(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      reply: reply == null || reply.isEmpty ? null : reply,
      replyAt: date(map['replyAt']),
      editedAt: date(map['editedAt']),
    );
  }

  /// [clearComment] removes the comment (an edit that empties it).
  Review copyWith({
    String? reply,
    DateTime? replyAt,
    int? rating,
    String? comment,
    bool clearComment = false,
    DateTime? editedAt,
  }) =>
      Review(
        bookingId: bookingId,
        shopId: shopId,
        barberId: barberId,
        customerId: customerId,
        customerName: customerName,
        rating: rating ?? this.rating,
        comment: clearComment ? null : (comment ?? this.comment),
        createdAt: createdAt,
        reply: reply ?? this.reply,
        replyAt: replyAt ?? this.replyAt,
        editedAt: editedAt ?? this.editedAt,
      );

  /// Newest first (ties by id, so pages are stable).
  static int newestFirst(Review a, Review b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.bookingId.compareTo(a.bookingId);
  }
}

/// "Liya Getachew" -> "Liya"; empty for an empty name.
String customerFirstName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.isEmpty ? '' : parts.first;
}

/// "Liya Getachew" -> "Liya G."; a single name is kept as is.
String shortCustomerName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.first} ${parts.last.characters1}.';
}

extension on String {
  /// First user-perceived character (Ethiopic syllables are single code
  /// units, so the first rune is enough here).
  String get characters1 => isEmpty ? '' : String.fromCharCode(runes.first);
}

/// Average rating (one decimal) and count: only whole ratings 1..5 count;
/// no reviews = rating 0 (shown as "New").
class RatingSummary {
  const RatingSummary({required this.rating, required this.count});

  final double rating;
  final int count;

  static const RatingSummary empty = RatingSummary(rating: 0, count: 0);

  factory RatingSummary.fromRatings(Iterable<Object?> ratings) {
    final valid = ratings.where(isValidReviewRating).cast<int>().toList();
    if (valid.isEmpty) return empty;
    final avg = valid.fold<int>(0, (s, r) => s + r) / valid.length;
    return RatingSummary(rating: (avg * 10).round() / 10, count: valid.length);
  }

  @override
  bool operator ==(Object other) => other is RatingSummary && other.rating == rating && other.count == count;

  @override
  int get hashCode => Object.hash(rating, count);

  @override
  String toString() => 'RatingSummary($rating, $count)';
}

/// Number of reviews per star (1..5).
class RatingDistribution {
  RatingDistribution(Map<int, int> counts) : counts = {for (var s = 1; s <= 5; s++) s: counts[s] ?? 0};

  final Map<int, int> counts;

  static RatingDistribution fromRatings(Iterable<int> ratings) {
    final counts = <int, int>{};
    for (final r in ratings) {
      if (isValidReviewRating(r)) counts[r] = (counts[r] ?? 0) + 1;
    }
    return RatingDistribution(counts);
  }

  int get total => counts.values.fold(0, (s, c) => s + c);

  /// Share of reviews with [stars] (0 when there are none).
  double fraction(int stars) => total == 0 ? 0 : (counts[stars] ?? 0) / total;
}

/// One page of a newest-first review list. [cursor] is opaque (passed back
/// to load the next page); null with [hasMore] false at the end.
class ReviewPage {
  const ReviewPage({required this.reviews, this.cursor, this.hasMore = false});

  final List<Review> reviews;
  final Object? cursor;
  final bool hasMore;
}
