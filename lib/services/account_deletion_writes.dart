/// Writes of account deletion (account_deletion.dart) and of owners' shop
/// removal requests: Firestore (works on the free Spark plan; see the rules
/// handoff in the account deletion change) and an in-memory version for
/// demo builds and tests.
///
/// Booking cancellations are not here: they reuse the normal cancel writes
/// of the DataStore (customer cancel / barber cancel, refund flagged in the
/// same write).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import 'account_deletion.dart';
import 'data_cache.dart';
import 'rating_service.dart' show barberCounterDeleteUpdate;
import 'reviews_service.dart' show ReviewsService;
import 'shop_deletion.dart' show chunked;

abstract class AccountDeletionWrites {
  /// Every booking whose customer is [uid] (all time, any status).
  Future<List<Booking>> bookingsOfCustomer(String uid);

  /// Sets [kAnonymizedBookingFields] on each booking, in batches of
  /// [kAccountDeletionChunk]. Returns how many were written.
  Future<int> anonymizeBookings(List<Booking> bookings);

  /// The reviews [uid] wrote for [completed] bookings (review id = booking
  /// id): `{customerName: 'Former customer'}` and `comment` deleted; stars
  /// and the owner's reply stay. A review the rules refuse to anonymise is
  /// deleted instead (with the barber's counters, like the customer's own
  /// delete). Returns how many reviews were changed.
  Future<int> anonymizeReviews(String uid, List<Booking> completed);

  /// Barber leaving the shop: first their public portfolio photos (best
  /// effort; the rules accept them only while the barber doc exists), then
  /// `barbers/{id}/private/contact` and `barbers/{id}` in ONE batch. Time
  /// off, slot locks and Storage copies of photos stay (functions/auth
  /// onUserProfileDeleted removes them on Blaze).
  Future<void> removeBarberProfile(String shopId, String barberId);

  /// Best effort, each part on its own: `invites/{email}`,
  /// `shopApplications/{uid}`, `shopRemovalRequests/{uid}` (any status: it
  /// holds the name and email),
  /// every `users/{uid}/notifications/*` and `users/{uid}/devices/*`.
  /// Returns the parts that failed (e.g. rules not deployed yet).
  Future<List<String>> deletePersonalData(AppUser user);

  /// Deletes `users/{uid}` (the document only; its subcollections are
  /// emptied by [deletePersonalData]).
  Future<void> deleteProfile(String uid);

  // --- shop removal requests ---

  /// The owner's own request, live (null when none).
  Stream<ShopRemovalRequest?> watchMyRemovalRequest(String uid);

  /// Owner: creates `shopRemovalRequests/{uid}` ([ShopRemovalRequest.toCreateMap]).
  Future<void> createRemovalRequest(ShopRemovalRequest request);

  /// Owner: withdraws (deletes) their request.
  Future<void> withdrawRemovalRequest(String uid);

  /// Admin: every request, newest first (limit 100).
  Stream<List<ShopRemovalRequest>> watchRemovalRequests();

  /// Admin: updates exactly [ShopRemovalRequest.resolveFields].
  Future<void> resolveRemovalRequest(String uid, Map<String, dynamic> fields);
}

/// Firestore (free Spark plan).
class FirestoreAccountDeletionWrites implements AccountDeletionWrites {
  FirestoreAccountDeletionWrites(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _requests => _db.collection(kShopRemovalRequestsCollection);

  static bool _denied(Object e) => e is FirebaseException && e.code == 'permission-denied';

  @override
  Future<List<Booking>> bookingsOfCustomer(String uid) async {
    final snap = await _bookings.where('customerId', isEqualTo: uid).get();
    return [for (final d in snap.docs) Booking.fromMap(d.data(), d.id)];
  }

  @override
  Future<int> anonymizeBookings(List<Booking> bookings) async {
    var written = 0;
    for (final chunk in chunked(bookings, kAccountDeletionChunk)) {
      final batch = _db.batch();
      for (final b in chunk) {
        batch.update(_bookings.doc(b.id), kAnonymizedBookingFields);
      }
      await batch.commit();
      written += chunk.length;
    }
    return written;
  }

  @override
  Future<int> anonymizeReviews(String uid, List<Booking> completed) async {
    var changed = 0;
    for (final b in completed) {
      final ref = _db.collection('barbershops').doc(b.shopId).collection('reviews').doc(b.id);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['customerId'] != uid) continue;
      if (data['customerName'] == kFormerCustomerName && !data.containsKey('comment')) continue;
      try {
        await ref.update({'customerName': kFormerCustomerName, 'comment': FieldValue.delete()});
      } catch (e) {
        if (!_denied(e)) rethrow;
        // Rules without the anonymise branch: remove the review instead
        // (the customer's own delete, counters in the same transaction).
        await _deleteReview(ref, b.shopId);
      }
      changed++;
    }
    return changed;
  }

  Future<void> _deleteReview(DocumentReference<Map<String, dynamic>> ref, String shopId) =>
      _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final review = Review.fromMap(snap.data()!, snap.id);
        final barberRef = _db.collection('barbershops').doc(shopId).collection('barbers').doc(review.barberId);
        final barber = await tx.get(barberRef);
        tx.delete(ref);
        if (barber.exists) tx.update(barberRef, barberCounterDeleteUpdate(barber.data()!, review));
      });

  @override
  Future<void> removeBarberProfile(String shopId, String barberId) async {
    final barber = _db.collection('barbershops').doc(shopId).collection('barbers').doc(barberId);
    try {
      await _deleteAll(barber.collection('portfolio'));
    } catch (e) {
      debugPrint('Account deletion: portfolio photos not deleted: $e');
    }
    final batch = _db.batch();
    batch.delete(barber.collection('private').doc('contact'));
    batch.delete(barber);
    await batch.commit();
  }

  Future<void> _deleteAll(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(200).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 200) return;
    }
  }

  @override
  Future<List<String>> deletePersonalData(AppUser user) async {
    final failed = <String>[];
    Future<void> part(String name, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('Account deletion: $name not deleted: $e');
        failed.add(name);
      }
    }

    final email = user.email?.trim().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      await part('invite', () async {
        final ref = _db.collection('invites').doc(email);
        if ((await ref.get()).exists) await ref.delete();
      });
    }
    await part('shopApplication', () async {
      final ref = _db.collection('shopApplications').doc(user.uid);
      final snap = await ref.get();
      if (snap.exists && snap.data()?['status'] != 'approved') await ref.delete();
    });
    await part('shopRemovalRequest', () async {
      final ref = _requests.doc(user.uid);
      final snap = await ref.get();
      if (snap.exists) await ref.delete();
    });
    await part('notifications', () => _deleteAll(_users.doc(user.uid).collection('notifications')));
    await part('devices', () => _deleteAll(_users.doc(user.uid).collection('devices')));
    return failed;
  }

  @override
  Future<void> deleteProfile(String uid) => _users.doc(uid).delete();

  @override
  Stream<ShopRemovalRequest?> watchMyRemovalRequest(String uid) => _requests
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? ShopRemovalRequest.fromMap(s.data()!, s.id) : null);

  @override
  Future<void> createRemovalRequest(ShopRemovalRequest request) =>
      _requests.doc(request.uid).set(request.toCreateMap());

  @override
  Future<void> withdrawRemovalRequest(String uid) => _requests.doc(uid).delete();

  @override
  Stream<List<ShopRemovalRequest>> watchRemovalRequests() => _requests
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) ShopRemovalRequest.fromMap(d.data(), d.id)]);

  @override
  Future<void> resolveRemovalRequest(String uid, Map<String, dynamic> fields) => _requests.doc(uid).update(fields);
}

/// Anonymises one customer's reviews in a local review store (demo, tests).
typedef LocalReviewAnonymizer = Future<int> Function(String uid);

/// Demo builds and tests: writes the in-memory [DataCache].
class LocalAccountDeletionWrites implements AccountDeletionWrites {
  LocalAccountDeletionWrites(this.cache, {this.reviews});

  final DataCache cache;

  /// The local reviews' anonymiser (default: the shared ReviewsService's
  /// in-memory store).
  LocalReviewAnonymizer? reviews;

  /// `shopRemovalRequests` by uid.
  final Map<String, ShopRemovalRequest> requests = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);

  /// Profiles deleted, oldest first (tests).
  final List<String> deletedProfiles = [];

  /// Uids whose inbox and device tokens were cleared (tests).
  final List<String> clearedInboxes = [];

  /// Tests: [deleteProfile] throws this once.
  Object? failDeleteProfileOnce;

  Stream<T> _watch<T>(T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        sub = _changes.stream.listen((_) {
          if (!controller.isClosed) controller.add(read());
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<List<Booking>> bookingsOfCustomer(String uid) async => [
        for (final b in cache.bookings.values)
          if (b.customerId == uid) b,
      ];

  @override
  Future<int> anonymizeBookings(List<Booking> bookings) async {
    var written = 0;
    for (final b in bookings) {
      final old = cache.bookings[b.id];
      if (old == null) continue;
      cache.bookings[old.id] = old.copyWith(customerName: kFormerCustomerName, customerPhone: '');
      written++;
    }
    return written;
  }

  @override
  Future<int> anonymizeReviews(String uid, List<Booking> completed) =>
      (reviews ?? ReviewsService.instance.local.anonymizeCustomer)(uid);

  @override
  Future<void> removeBarberProfile(String shopId, String barberId) async {
    cache.barberPhones.remove(barberId);
    cache.barbers.remove(barberId);
  }

  @override
  Future<List<String>> deletePersonalData(AppUser user) async {
    final email = user.email?.trim().toLowerCase();
    if (email != null) cache.invites.remove(email);
    if (requests.remove(user.uid) != null) _changes.add(null);
    clearedInboxes.add(user.uid);
    return const [];
  }

  @override
  Future<void> deleteProfile(String uid) async {
    final fail = failDeleteProfileOnce;
    if (fail != null) {
      failDeleteProfileOnce = null;
      throw fail;
    }
    cache.users.remove(uid);
    deletedProfiles.add(uid);
  }

  @override
  Stream<ShopRemovalRequest?> watchMyRemovalRequest(String uid) => _watch(() => requests[uid]);

  @override
  Future<void> createRemovalRequest(ShopRemovalRequest request) async {
    requests[request.uid] = request;
    _changes.add(null);
  }

  @override
  Future<void> withdrawRemovalRequest(String uid) async {
    requests.remove(uid);
    _changes.add(null);
  }

  @override
  Stream<List<ShopRemovalRequest>> watchRemovalRequests() =>
      _watch(() => requests.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Future<void> resolveRemovalRequest(String uid, Map<String, dynamic> fields) async {
    final old = requests[uid];
    if (old == null) return;
    requests[uid] = old.resolved(
      ShopRemovalStatus.fromString(fields['status'] as String?),
      at: DateTime.parse(fields['handledAt'] as String),
      by: fields['handledBy'] as String,
    );
    _changes.add(null);
  }
}
