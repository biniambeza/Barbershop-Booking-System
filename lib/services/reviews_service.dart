import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/config/app_config.dart';
import '../data/seed_dataset.dart';
import '../models/booking_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import 'app_repository.dart';

export '../models/review_model.dart';

/// Review-specific failures. Screens show them with `reviewsErrorText`
/// (lib/features/reviews/reviews_l10n.dart); sign-in errors are
/// [AppException]s and Firestore failures stay [FirebaseException]s.
enum ReviewErrorCode {
  /// Only the booking's own customer may rate it.
  notYourBooking,

  /// The booking is not completed (yet).
  notCompleted,

  /// A review for this booking already exists (one per booking).
  alreadyReviewed,

  /// Rating outside 1..5.
  invalidRating,

  /// args: [max characters].
  commentTooLong,

  /// args: [max characters]. Reply empty or too long.
  replyInvalid,

  /// Only the shop's owner replies to its reviews.
  ownerOnly,

  /// The review does not exist (any more).
  notFound,
}

class ReviewException implements Exception {
  ReviewException(this.code, [this.args = const []]);

  final ReviewErrorCode code;
  final List<Object?> args;

  @override
  String toString() => 'ReviewException(${code.name}${args.isEmpty ? '' : ', $args'})';
}

/// Storage of reviews: [FirestoreReviewStore] in production,
/// [LocalReviewStore] in DEMO_MODE builds and tests.
abstract class ReviewStore {
  /// The review of one booking (null when there is none), live.
  Stream<Review?> watchReview(String shopId, String bookingId);

  /// Newest-first page of a shop's reviews, optionally only [barberId]'s.
  Future<ReviewPage> fetchPage(String shopId, {String? barberId, Object? cursor, int limit = kReviewPageSize});

  /// Reviews per star for the shop (or one of its barbers).
  Future<RatingDistribution> distribution(String shopId, {String? barberId});

  /// Creates the review; throws [ReviewErrorCode.alreadyReviewed] if the
  /// booking already has one.
  Future<void> create(Review review);

  /// Sets the owner's reply (only `reply` and `replyAt` change).
  Future<void> updateReply(Review review, String reply, DateTime replyAt);
}

/// Firestore access, all under `barbershops/{shopId}/reviews`:
///
///  * one review:   doc `reviews/{bookingId}` snapshots (customer's own
///                  booking card)
///  * shop list:    orderBy createdAt desc, limit n+1, startAfterDocument
///  * barber list:  where barberId == b orderBy createdAt desc (composite
///                  index barberId ASC, createdAt DESC)
///  * distribution: 5 count() aggregations where rating == 1..5 (and
///                  barberId == b for a barber)
///  * create:       transaction: get `reviews/{bookingId}`, abort if it
///                  exists, set the doc
///  * reply:        update {reply, replyAt}
class FirestoreReviewStore implements ReviewStore {
  FirestoreReviewStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _reviews(String shopId) =>
      _db.collection('barbershops').doc(shopId).collection('reviews');

  Query<Map<String, dynamic>> _base(String shopId, String? barberId) {
    Query<Map<String, dynamic>> q = _reviews(shopId);
    if (barberId != null) q = q.where('barberId', isEqualTo: barberId);
    return q;
  }

  @override
  Stream<Review?> watchReview(String shopId, String bookingId) => _reviews(shopId)
      .doc(bookingId)
      .snapshots()
      .map((s) => s.exists ? Review.fromMap(s.data()!, s.id) : null);

  @override
  Future<ReviewPage> fetchPage(String shopId, {String? barberId, Object? cursor, int limit = kReviewPageSize}) async {
    var q = _base(shopId, barberId).orderBy('createdAt', descending: true);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.limit(limit + 1).get();
    final docs = snap.docs.take(limit).toList();
    return ReviewPage(
      reviews: [for (final d in docs) Review.fromMap(d.data(), d.id)],
      cursor: docs.isEmpty ? null : docs.last,
      hasMore: snap.docs.length > limit,
    );
  }

  @override
  Future<RatingDistribution> distribution(String shopId, {String? barberId}) async {
    final counts = await Future.wait([
      for (var s = 1; s <= 5; s++) _base(shopId, barberId).where('rating', isEqualTo: s).count().get(),
    ]);
    return RatingDistribution({for (var s = 1; s <= 5; s++) s: counts[s - 1].count ?? 0});
  }

  @override
  Future<void> create(Review review) async {
    final ref = _reviews(review.shopId).doc(review.bookingId);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) throw ReviewException(ReviewErrorCode.alreadyReviewed);
      tx.set(ref, review.toMap());
    });
  }

  @override
  Future<void> updateReply(Review review, String reply, DateTime replyAt) =>
      _reviews(review.shopId).doc(review.bookingId).update({
        'reply': reply,
        'replyAt': replyAt.toUtc().toIso8601String(),
      });
}

/// In-memory reviews for DEMO_MODE builds and tests. In DEMO_MODE it loads
/// the dataset's `reviews` on first use.
class LocalReviewStore implements ReviewStore {
  LocalReviewStore({this.seedFromAssets = false});

  /// DEMO_MODE: load the reviews of the bundled dataset on first use.
  final bool seedFromAssets;

  final Map<String, Map<String, Review>> _byShop = {};
  final StreamController<String> _changes = StreamController<String>.broadcast(sync: true);
  bool _seeded = false;
  Future<void>? _seeding;

  /// Replaces all reviews with the `reviews` list of the demo dataset JSON.
  /// Each entry names a seeded booking (`bookingId`); shop, barber and
  /// customer come from that booking, and `hoursAfterVisit` /
  /// `replyHoursAfterVisit` are counted from its start. tool/seed/seed.js
  /// applies the same rules.
  void loadSeedJson(Map<String, dynamic> json, {DateTime? now}) {
    _byShop.clear();
    for (final review in reviewsFromSeedJson(json, now: now)) {
      (_byShop[review.shopId] ??= {})[review.bookingId] = review;
    }
    _seeded = true;
    for (final shopId in _byShop.keys.toList()) {
      _changes.add(shopId);
    }
  }

  /// Empties the store (tests).
  void clear() {
    final shops = _byShop.keys.toList();
    _byShop.clear();
    _seeded = true;
    shops.forEach(_changes.add);
  }

  Future<void> _ensureSeeded() {
    if (_seeded || !seedFromAssets) return Future.value();
    return _seeding ??= () async {
      try {
        final text = await rootBundle.loadString(kSeedAssetPath);
        if (!_seeded) loadSeedJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not load the demo reviews: $e');
        _seeded = true;
      }
    }();
  }

  /// Every review of [shopId] (tests, local rating recompute).
  List<Review> reviewsOf(String shopId) => (_byShop[shopId]?.values.toList() ?? <Review>[])..sort(Review.newestFirst);

  List<Review> _filtered(String shopId, String? barberId) =>
      reviewsOf(shopId).where((r) => barberId == null || r.barberId == barberId).toList();

  @override
  Stream<Review?> watchReview(String shopId, String bookingId) {
    late StreamController<Review?> controller;
    StreamSubscription<String>? sub;
    Review? read() => _byShop[shopId]?[bookingId];
    controller = StreamController<Review?>(
      onListen: () {
        sub = _changes.stream.where((id) => id == shopId).listen((_) => controller.add(read()));
        _ensureSeeded().then((_) {
          if (!controller.isClosed) controller.add(read());
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<ReviewPage> fetchPage(String shopId, {String? barberId, Object? cursor, int limit = kReviewPageSize}) async {
    await _ensureSeeded();
    final all = _filtered(shopId, barberId);
    final start = cursor is int ? cursor : 0;
    final end = (start + limit).clamp(0, all.length);
    return ReviewPage(
      reviews: start >= all.length ? const [] : all.sublist(start, end),
      cursor: end,
      hasMore: end < all.length,
    );
  }

  @override
  Future<RatingDistribution> distribution(String shopId, {String? barberId}) async {
    await _ensureSeeded();
    return RatingDistribution.fromRatings(_filtered(shopId, barberId).map((r) => r.rating));
  }

  @override
  Future<void> create(Review review) async {
    await _ensureSeeded();
    final shop = _byShop[review.shopId] ??= {};
    if (shop.containsKey(review.bookingId)) throw ReviewException(ReviewErrorCode.alreadyReviewed);
    shop[review.bookingId] = review;
    _changes.add(review.shopId);
  }

  @override
  Future<void> updateReply(Review review, String reply, DateTime replyAt) async {
    await _ensureSeeded();
    final current = _byShop[review.shopId]?[review.bookingId];
    if (current == null) throw ReviewException(ReviewErrorCode.notFound);
    _byShop[review.shopId]![review.bookingId] = current.copyWith(reply: reply, replyAt: replyAt.toUtc());
    _changes.add(review.shopId);
  }
}

/// The demo dataset's reviews, resolved against its bookings (see
/// [LocalReviewStore.loadSeedJson]). Entries naming an unknown booking are
/// skipped.
List<Review> reviewsFromSeedJson(Map<String, dynamic> json, {DateTime? now}) {
  final raw = json['reviews'] as List<dynamic>? ?? const [];
  if (raw.isEmpty) return const [];
  final bookings = {for (final b in SeedDataset.fromJson(json, now: now).bookings) b.id: b};
  final reviews = <Review>[];
  for (final entry in raw) {
    final m = Map<String, dynamic>.from(entry as Map);
    final booking = bookings[m['bookingId']];
    if (booking == null) continue;
    Duration hours(Object? v) => Duration(minutes: (((v as num?) ?? 0) * 60).round());
    final reply = (m['reply'] as String?)?.trim();
    final comment = (m['comment'] as String?)?.trim();
    reviews.add(Review(
      bookingId: booking.id,
      shopId: booking.shopId,
      barberId: booking.barberId,
      customerId: booking.customerId,
      customerName: booking.customerName,
      rating: (m['rating'] as num).toInt(),
      comment: comment == null || comment.isEmpty ? null : comment,
      createdAt: booking.startAt.add(hours(m['hoursAfterVisit'])),
      reply: reply == null || reply.isEmpty ? null : reply,
      replyAt: reply == null || reply.isEmpty ? null : booking.startAt.add(hours(m['replyHoursAfterVisit'])),
    ));
  }
  return reviews;
}

/// Reviews and ratings.
///
///  * Customers rate each completed booking once ([submitReview]) and see
///    their own review on the booking card ([watchReviewForBooking]).
///  * Everyone reads a shop's or a barber's reviews newest first
///    ([loadPage]) and the star distribution ([loadDistribution]).
///  * The shop owner adds or edits a reply ([saveReply]).
///
/// Shop and barber averages shown in the app are the `rating` /
/// `reviewCount` fields the insights Cloud Function maintains. Without
/// Firebase (DEMO_MODE, tests) this service recomputes them after each new
/// review and hands them to [AppRepository.applyLocalRatings].
class ReviewsService {
  ReviewsService({AppRepository? repository, ReviewStore? cloud, LocalReviewStore? local, DateTime Function()? clock})
      : _repo = repository ?? AppRepository.instance,
        _cloudOverride = cloud,
        _clock = clock {
    this.local = local ?? LocalReviewStore(seedFromAssets: kDemoMode);
  }

  static ReviewsService? _instance;
  static ReviewsService get instance => _instance ??= ReviewsService();

  /// Tests: replaces the shared instance (null restores a fresh default).
  @visibleForTesting
  static set instance(ReviewsService? service) => _instance = service;

  final AppRepository _repo;
  final ReviewStore? _cloudOverride;
  final DateTime Function()? _clock;
  ReviewStore? _cloud;

  /// The in-memory store (DEMO_MODE and tests).
  late final LocalReviewStore local;

  ReviewStore get store {
    if (_cloudOverride != null) return _cloudOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestoreReviewStore(FirebaseFirestore.instance);
  }

  DateTime _now() => (_clock?.call() ?? _repo.nowUtc()).toUtc();

  // --- Reads ---

  Stream<Review?> watchReviewForBooking(Booking booking) => store.watchReview(booking.shopId, booking.id);

  Future<ReviewPage> loadPage(String shopId, {String? barberId, Object? cursor, int limit = kReviewPageSize}) =>
      store.fetchPage(shopId, barberId: barberId, cursor: cursor, limit: limit);

  Future<RatingDistribution> loadDistribution(String shopId, {String? barberId}) =>
      store.distribution(shopId, barberId: barberId);

  /// The shop's rating fields (live in the repository).
  RatingSummary shopSummary(String shopId) {
    final shop = _repo.getShopById(shopId);
    return shop == null ? RatingSummary.empty : RatingSummary(rating: shop.rating, count: shop.reviewCount);
  }

  /// A barber's rating fields (live in the repository).
  RatingSummary barberSummary(String barberId) {
    final barber = _repo.getBarberById(barberId);
    return barber == null ? RatingSummary.empty : RatingSummary(rating: barber.rating, count: barber.reviewCount);
  }

  // --- Customer ---

  /// Why the signed-in user may not rate [booking] (null = they may, if it
  /// has no review yet).
  ReviewErrorCode? reviewBlocker(Booking booking) {
    final user = _repo.currentUser;
    if (user == null || booking.customerId != user.uid) return ReviewErrorCode.notYourBooking;
    if (booking.status != BookingStatus.completed) return ReviewErrorCode.notCompleted;
    return null;
  }

  /// Rates a completed booking of the signed-in customer, once.
  Future<Review> submitReview(Booking booking, {required int rating, String? comment}) async {
    if (_repo.currentUser == null) throw AppStateException(AppErrorCode.signInRequired);
    final blocker = reviewBlocker(booking);
    if (blocker != null) throw ReviewException(blocker);
    if (!isValidReviewRating(rating)) throw ReviewException(ReviewErrorCode.invalidRating);
    final text = comment?.trim() ?? '';
    if (text.length > kReviewCommentMaxLength) {
      throw ReviewException(ReviewErrorCode.commentTooLong, [kReviewCommentMaxLength]);
    }
    final review = Review(
      bookingId: booking.id,
      shopId: booking.shopId,
      barberId: booking.barberId,
      customerId: booking.customerId,
      customerName: booking.customerName,
      rating: rating,
      comment: text.isEmpty ? null : text,
      createdAt: _now(),
    );
    await store.create(review);
    if (store is LocalReviewStore) _recomputeLocalRatings(review.shopId);
    return review;
  }

  // --- Owner ---

  /// Whether the signed-in user owns [shopId] (only they reply).
  bool canReply(String shopId) {
    final user = _repo.currentUser;
    if (user == null || user.role != UserRole.barbershopOwner) return false;
    return user.shopId == shopId || _repo.getShopById(shopId)?.ownerId == user.uid;
  }

  /// Adds or replaces the owner's reply to [review].
  Future<Review> saveReply(Review review, String reply) async {
    if (_repo.currentUser == null) throw AppStateException(AppErrorCode.signInRequired);
    if (!canReply(review.shopId)) throw ReviewException(ReviewErrorCode.ownerOnly);
    final text = reply.trim();
    if (text.isEmpty || text.length > kReviewReplyMaxLength) {
      throw ReviewException(ReviewErrorCode.replyInvalid, [kReviewReplyMaxLength]);
    }
    final at = _now();
    await store.updateReply(review, text, at);
    return review.copyWith(reply: text, replyAt: at);
  }

  // --- Local ratings (what aggregateReviewRatings does in Firebase) ---

  void _recomputeLocalRatings(String shopId) {
    final reviews = local.reviewsOf(shopId);
    _repo.applyLocalRatings(
      shopId,
      RatingSummary.fromRatings(reviews.map((r) => r.rating)),
      {
        for (final b in _repo.getBarbersForShop(shopId))
          b.id: RatingSummary.fromRatings(reviews.where((r) => r.barberId == b.id).map((r) => r.rating)),
      },
    );
  }
}
