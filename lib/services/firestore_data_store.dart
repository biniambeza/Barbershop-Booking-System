import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/addis_time.dart';
import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/plan_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import '../models/app_exception.dart';
import 'availability_service.dart';
import 'data_cache.dart';
import 'data_store.dart';
import 'time_off_service.dart';

/// Firestore-backed [DataStore].
///
/// Writes go to Firestore only. Reads come from snapshot listeners that
/// [start] opens for the signed-in user, scoped by role, and that copy every
/// change into the shared [DataCache]. Firestore applies local writes to
/// listeners immediately (latency compensation), so the UI updates at once.
///
/// Listeners per role (see the handoff notes / firestore.rules):
///  * everyone:  doc users/{uid}
///  * customer:  barbershops where subscriptionStatus in [trialing, active, past_due];
///               collectionGroup services; collectionGroup barbers;
///               bookings where customerId == uid (bounded, see below)
///  * owner:     doc barbershops/{shopId}; its services and barbers subcollections;
///               bookings where shopId == shopId (bounded);
///               invites where shopId == shopId and role == 'barber';
///               users where shopId == shopId; plans
///  * barber:    doc barbershops/{shopId}; its services and barbers subcollections;
///               bookings where shopId == shopId and barberId == barberId (bounded)
///  * admin:     barbershops; collectionGroup services; collectionGroup barbers;
///               bookings orderBy createdAt desc limit 500; users; invites; plans
///
/// Booking listeners of customers, owners and barbers are bounded by two
/// queries on `startAt` (needs the composite indexes in
/// firestore.indexes.json), split at the minute [start] runs:
///  * upcoming: `startAt >= now`, orderBy startAt, no limit. Complete: the
///    rules only accept bookings up to 31 days ahead.
///  * history:  `now - [bookingHistoryDays] <= startAt < now`, orderBy
///    startAt desc, limited to the newest [customerHistoryLimit] /
///    [staffHistoryLimit].
/// Legacy bookings without `startAt` match neither query.
class FirestoreDataStore implements DataStore {
  FirestoreDataStore({
    required this.cache,
    required this.onChanged,
    required this.onCurrentUserChanged,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  final DataCache cache;
  final FirebaseFirestore _db;

  /// Called after every snapshot that changed the cache.
  final VoidCallback onChanged;

  /// Called when the signed-in user's own `users/{uid}` document changes
  /// (null when it is deleted).
  final void Function(AppUser? user) onCurrentUserChanged;

  static const int adminBookingLimit = 500;

  /// How far back the customer/owner/barber booking listeners reach.
  static const int bookingHistoryDays = 90;

  /// Most past bookings a customer listener keeps (newest first).
  static const int customerHistoryLimit = 200;

  /// Most past bookings an owner or barber listener keeps (newest first).
  static const int staffHistoryLimit = 1000;

  final DateTime Function() _clock;

  final List<StreamSubscription<dynamic>> _subs = [];
  String? _scopeKey;

  /// Last listener error (permission denied, offline, ...), if any.
  String? lastError;

  // --- Paths ---

  CollectionReference<Map<String, dynamic>> get _shops => _db.collection('barbershops');
  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _invites => _db.collection('invites');
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> _servicesOf(String shopId) => _shops.doc(shopId).collection('services');
  CollectionReference<Map<String, dynamic>> _barbersOf(String shopId) => _shops.doc(shopId).collection('barbers');

  // --- Listeners ---

  bool get isRunning => _subs.isNotEmpty;

  /// Opens the role-scoped listeners for [user] (restarting them if the
  /// user's role or shop changed). Completes when every listener has
  /// delivered its first snapshot, or after [timeout].
  Future<void> start(AppUser user, {Duration timeout = const Duration(seconds: 10)}) async {
    final key = '${user.uid}|${user.role.name}|${user.shopId}|${user.barberId}';
    if (key == _scopeKey && isRunning) return;
    await stop();
    _scopeKey = key;
    lastError = null;

    final firstSnapshots = <Future<void>>[];
    void listen<T>(Stream<T> stream, void Function(T) apply) {
      final first = Completer<void>();
      firstSnapshots.add(first.future);
      _subs.add(stream.listen(
        (event) {
          apply(event);
          if (!first.isCompleted) first.complete();
          onChanged();
        },
        onError: (Object e) {
          debugPrint('Firestore listener error: $e');
          lastError = e.toString();
          if (!first.isCompleted) first.complete();
          onChanged();
        },
      ));
    }

    void listenQuery<M>(Query<Map<String, dynamic>> query, Map<String, M> target, M Function(Map<String, dynamic>, String) parse) {
      listen<QuerySnapshot<Map<String, dynamic>>>(query.snapshots(), (snap) => _applyQuery(snap, target, parse));
    }

    void listenDoc<M>(DocumentReference<Map<String, dynamic>> ref, Map<String, M> target, M Function(Map<String, dynamic>, String) parse) {
      listen<DocumentSnapshot<Map<String, dynamic>>>(ref.snapshots(), (snap) {
        final data = snap.data();
        if (data == null) {
          target.remove(snap.id);
        } else {
          target[snap.id] = parse(data, snap.id);
        }
      });
    }

    // Mirrors the full result set of [query] into [target]: documents that
    // left the result (deleted, or pushed out by the limit) are removed.
    // Used where a query has a limit, instead of docChanges.
    void listenQueryResults<M>(Query<Map<String, dynamic>> query, Map<String, M> target, M Function(Map<String, dynamic>, String) parse) {
      final held = <String>{};
      listen<QuerySnapshot<Map<String, dynamic>>>(query.snapshots(), (snap) {
        final ids = <String>{};
        for (final doc in snap.docs) {
          ids.add(doc.id);
          target[doc.id] = parse(doc.data(), doc.id);
        }
        for (final id in held.difference(ids)) {
          target.remove(id);
        }
        held
          ..clear()
          ..addAll(ids);
      });
    }

    // Upcoming bookings in full plus recent history (see the class doc).
    // The two ranges are disjoint, so a removal from one never drops a
    // document the other still matches.
    void listenBookings(Query<Map<String, dynamic>> base, int historyLimit) {
      final now = _clock();
      listenQuery(upcomingBookingsQuery(base, now), cache.bookings, Booking.fromMap);
      listenQueryResults(historyBookingsQuery(base, now, historyLimit), cache.bookings, Booking.fromMap);
    }

    // Own profile (role changes, removal of a barber's access, ...).
    listen<DocumentSnapshot<Map<String, dynamic>>>(_users.doc(user.uid).snapshots(), (snap) {
      final data = snap.data();
      final updated = data == null ? null : AppUser.fromMap(data, snap.id);
      if (updated != null) cache.users[updated.uid] = updated;
      onCurrentUserChanged(updated);
    });

    switch (user.role) {
      case UserRole.customer:
        listenQuery(
          _shops.where('subscriptionStatus', whereIn: SubscriptionStatus.customerVisibleValues),
          cache.shops,
          Barbershop.fromMap,
        );
        listenQuery(_db.collectionGroup('services'), cache.services, BarbershopService.fromMap);
        listenQuery(_db.collectionGroup('barbers'), cache.barbers, Barber.fromMap);
        listenBookings(_bookings.where('customerId', isEqualTo: user.uid), customerHistoryLimit);
      case UserRole.barbershopOwner:
        final shopId = user.shopId;
        if (shopId != null) {
          listenDoc(_shops.doc(shopId), cache.shops, Barbershop.fromMap);
          listenQuery(_servicesOf(shopId), cache.services, BarbershopService.fromMap);
          listenQuery(_barbersOf(shopId), cache.barbers, Barber.fromMap);
          listenBookings(_bookings.where('shopId', isEqualTo: shopId), staffHistoryLimit);
          listenQuery(
            _invites.where('shopId', isEqualTo: shopId).where('role', isEqualTo: UserRole.barber.name),
            cache.invites,
            UserInvite.fromMap,
          );
          listenQuery(_users.where('shopId', isEqualTo: shopId), cache.users, AppUser.fromMap);
        }
        listenQuery(_db.collection('plans'), cache.plans, SubscriptionPlan.fromMap);
      case UserRole.barber:
        final shopId = user.shopId;
        final barberId = user.barberId;
        if (shopId != null && barberId != null) {
          listenDoc(_shops.doc(shopId), cache.shops, Barbershop.fromMap);
          listenQuery(_servicesOf(shopId), cache.services, BarbershopService.fromMap);
          listenQuery(_barbersOf(shopId), cache.barbers, Barber.fromMap);
          listenBookings(
            _bookings.where('shopId', isEqualTo: shopId).where('barberId', isEqualTo: barberId),
            staffHistoryLimit,
          );
        }
      case UserRole.admin:
        listenQuery(_shops, cache.shops, Barbershop.fromMap);
        listenQuery(_db.collectionGroup('services'), cache.services, BarbershopService.fromMap);
        listenQuery(_db.collectionGroup('barbers'), cache.barbers, Barber.fromMap);
        listenQuery(
          _bookings.orderBy('createdAt', descending: true).limit(adminBookingLimit),
          cache.bookings,
          Booking.fromMap,
        );
        listenQuery(_users, cache.users, AppUser.fromMap);
        listenQuery(_invites, cache.invites, UserInvite.fromMap);
        listenQuery(_db.collection('plans'), cache.plans, SubscriptionPlan.fromMap);
    }

    await Future.wait(firstSnapshots).timeout(timeout, onTimeout: () => const []);
  }

  /// The `startAt` bounds of the booking listeners for [now]: `(nowIso,
  /// cutoffIso)`, both whole UTC minutes in the stored ISO format, with
  /// cutoff [bookingHistoryDays] before now.
  static (String, String) bookingWindowBounds(DateTime now) {
    final t = now.toUtc();
    final minute = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);
    return (
      minute.toIso8601String(),
      minute.subtract(const Duration(days: bookingHistoryDays)).toIso8601String(),
    );
  }

  /// Bookings of [base] starting at or after the minute of [now], soonest
  /// first (no limit: bookings are at most 31 days ahead).
  static Query<Map<String, dynamic>> upcomingBookingsQuery(Query<Map<String, dynamic>> base, DateTime now) {
    final (nowIso, _) = bookingWindowBounds(now);
    return base.where('startAt', isGreaterThanOrEqualTo: nowIso).orderBy('startAt');
  }

  /// The newest [limit] bookings of [base] that started in the
  /// [bookingHistoryDays] before the minute of [now].
  static Query<Map<String, dynamic>> historyBookingsQuery(Query<Map<String, dynamic>> base, DateTime now, int limit) {
    final (nowIso, cutoffIso) = bookingWindowBounds(now);
    return base
        .where('startAt', isGreaterThanOrEqualTo: cutoffIso)
        .where('startAt', isLessThan: nowIso)
        .orderBy('startAt', descending: true)
        .limit(limit);
  }

  /// Cancels every listener and empties the cache (sign-out).
  Future<void> stop() async {
    final subs = List.of(_subs);
    _subs.clear();
    _scopeKey = null;
    for (final s in subs) {
      await s.cancel();
    }
    cache.clear();
  }

  void _applyQuery<M>(
    QuerySnapshot<Map<String, dynamic>> snap,
    Map<String, M> target,
    M Function(Map<String, dynamic>, String) parse,
  ) {
    for (final change in snap.docChanges) {
      final doc = change.doc;
      if (change.type == DocumentChangeType.removed) {
        target.remove(doc.id);
      } else {
        final data = doc.data();
        if (data != null) target[doc.id] = parse(data, doc.id);
      }
    }
  }

  /// Null values become field deletes in an `update()`.
  static Map<String, dynamic> _forUpdate(Map<String, dynamic> fields) => {
        for (final e in fields.entries) e.key: e.value ?? FieldValue.delete(),
      };

  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> fields) => {
        for (final e in fields.entries)
          if (e.value != null) e.key: e.value,
      };

  // --- Writes ---

  @override
  Future<void> createShop({
    required Barbershop shop,
    required List<BarbershopService> services,
    required List<Barber> barbers,
    UserInvite? ownerInvite,
  }) async {
    final shopRef = _shops.doc(shop.id);
    final batch = _db.batch();
    batch.set(shopRef, _withoutNulls(shop.toMap()));
    for (final s in services) {
      batch.set(shopRef.collection('services').doc(s.id), s.toMap());
    }
    for (final b in barbers) {
      batch.set(shopRef.collection('barbers').doc(b.id), _withoutNulls(b.toMap()));
    }
    if (ownerInvite != null) batch.set(_invites.doc(ownerInvite.email), ownerInvite.toMap());
    await batch.commit();
  }

  @override
  Future<void> updateShopProfile(Barbershop shop) =>
      _shops.doc(shop.id).update(_forUpdate(shop.toProfileMap()));

  @override
  Future<void> setShopVerified(String shopId, bool isVerified) =>
      _shops.doc(shopId).update({'isVerified': isVerified});

  @override
  Future<void> updateShopSubscription(
    String shopId, {
    required String plan,
    required SubscriptionStatus status,
    DateTime? endsAt,
  }) {
    return _shops.doc(shopId).update({
      'subscriptionPlan': plan,
      'subscriptionStatus': status.value,
      'subscriptionEndsAt': endsAt == null ? FieldValue.delete() : endsAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> deleteShop(String shopId) async {
    // Subcollections are not deleted with their parent; remove them so the
    // collection-group listeners do not show orphans. (Only the admin, who
    // has every service/barber/invite in the cache, deletes shops.)
    final batch = _db.batch();
    for (final s in cache.services.values.where((s) => s.shopId == shopId)) {
      batch.delete(_servicesOf(shopId).doc(s.id));
    }
    for (final b in cache.barbers.values.where((b) => b.shopId == shopId)) {
      batch.delete(_barbersOf(shopId).doc(b.id));
    }
    for (final i in cache.invites.values.where((i) => i.shopId == shopId)) {
      batch.delete(_invites.doc(i.email));
    }
    batch.delete(_shops.doc(shopId));
    await batch.commit();
  }

  @override
  Future<void> addService(BarbershopService service) =>
      _servicesOf(service.shopId).doc(service.id).set(service.toMap());

  @override
  Future<void> updateService(BarbershopService service) =>
      _servicesOf(service.shopId).doc(service.id).update(service.toMap());

  @override
  Future<void> deleteService(BarbershopService service) => _servicesOf(service.shopId).doc(service.id).delete();

  @override
  Future<void> addBarber(Barber barber, UserInvite? invite) async {
    final batch = _db.batch();
    batch.set(_barbersOf(barber.shopId).doc(barber.id), _withoutNulls(barber.toMap()));
    if (invite != null) batch.set(_invites.doc(invite.email), invite.toMap());
    await batch.commit();
  }

  @override
  Future<void> updateBarberProfile(Barber barber) =>
      _barbersOf(barber.shopId).doc(barber.id).update(_forUpdate(barber.toProfileMap()));

  @override
  Future<void> setBarberAvailability(Barber barber, bool isAvailable) =>
      _barbersOf(barber.shopId).doc(barber.id).update({'isAvailable': isAvailable});

  @override
  Future<void> deleteBarber(Barber barber, UserInvite? pendingInvite) async {
    final batch = _db.batch();
    batch.delete(_barbersOf(barber.shopId).doc(barber.id));
    if (pendingInvite != null) batch.delete(_invites.doc(pendingInvite.email));
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _slotLocksOf(String shopId, String barberId) =>
      _barbersOf(shopId).doc(barberId).collection('slotLocks');

  /// Double-booking prevention. In ONE transaction:
  ///  1. read `slotLocks/{id}` for every 15-minute block the booking covers;
  ///  2. if any exists, abort with [SlotTakenException];
  ///  3. otherwise create `bookings/{id}` and every lock
  ///     `{bookingId, startAt, expiresAt}` (no customer data: any signed-in
  ///     user can read locks; the rules tie each lock to its booking).
  /// The rules check the first four and the last lock; the `verifyBookingLocks`
  /// trigger (functions/bookings) checks all of them and cancels a booking
  /// with `cancelReason: 'slot_conflict'` if one is missing.
  /// Two customers racing for the same block: Firestore retries the loser's
  /// transaction, which then sees the winner's lock. (The rules also only
  /// allow *creating* locks, so an overwrite is rejected server-side.)
  @override
  Future<void> createBooking(Booking booking) async {
    final locksRef = _slotLocksOf(booking.shopId, booking.barberId);
    final locks = slotLocksForBooking(booking);
    try {
      await _db.runTransaction<void>((tx) async {
        for (final lock in locks) {
          final snap = await tx.get(locksRef.doc(lock.id));
          if (snap.exists) throw const SlotTakenException();
        }
        tx.set(_bookings.doc(booking.id), booking.toMap());
        for (final lock in locks) {
          tx.set(locksRef.doc(lock.id), lock.toMap());
        }
      });
    } on SlotTakenException {
      rethrow;
    } on FirebaseException catch (e) {
      // A lost race can also surface as a rules rejection (lock already
      // exists, so the write would be an update). Report it as "taken" if a
      // lock is there now.
      if (await _anyLockExists(locksRef, locks)) throw const SlotTakenException();
      throw StateError('Could not book: ${e.message ?? e.code}');
    }
  }

  Future<bool> _anyLockExists(CollectionReference<Map<String, dynamic>> locksRef, List<SlotLock> locks) async {
    try {
      for (final lock in locks) {
        if ((await locksRef.doc(lock.id).get()).exists) return true;
      }
    } catch (_) {
      // Fall through: report the original error.
    }
    return false;
  }

  /// Cancelling releases the booking's slot locks in the same transaction:
  /// the status update plus a delete of each lock doc that exists and has
  /// `bookingId == booking.id` (locks are never deleted for anyone else's
  /// booking, and missing locks of legacy bookings are skipped). Any other
  /// status change is a plain `update({status})`.
  @override
  Future<void> updateBookingStatus(Booking booking, BookingStatus status, {String? cancelledBy}) async {
    final bookingRef = _bookings.doc(booking.id);
    if (status != BookingStatus.cancelled) {
      await bookingRef.update({'status': status.name});
      return;
    }
    final locksRef = _slotLocksOf(booking.shopId, booking.barberId);
    final ids = slotLockIdsFor(booking.startAt, booking.endAt);
    await _db.runTransaction<void>((tx) async {
      final mine = <DocumentReference<Map<String, dynamic>>>[];
      for (final id in ids) {
        final snap = await tx.get(locksRef.doc(id));
        if (snap.exists && snap.data()?['bookingId'] == booking.id) mine.add(snap.reference);
      }
      tx.update(bookingRef, {
        'status': status.name,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
      });
      for (final ref in mine) {
        tx.delete(ref);
      }
    });
  }

  /// Locks whose `startAt` falls on the Addis day (a single-field range
  /// query, no composite index needed).
  @override
  Stream<List<SlotLock>> watchSlotLocks(String shopId, String barberId, DateTime addisDate) {
    final (dayStart, dayEnd) = addisDayBoundsUtc(addisDate);
    return _slotLocksOf(shopId, barberId)
        .where('startAt', isGreaterThanOrEqualTo: dayStart.toIso8601String())
        .where('startAt', isLessThan: dayEnd.toIso8601String())
        .snapshots()
        .map((snap) => [for (final d in snap.docs) SlotLock.fromMap(d.data(), d.id)]);
  }

  @override
  Future<void> updateUserProfile(String uid, {String? name, String? language, String? phone}) {
    return _users.doc(uid).update({
      if (name != null) 'name': name,
      if (language != null) 'language': language,
      if (phone != null) 'phone': phone,
    });
  }

  // --- Reschedule, policy, time off ---

  /// The reschedule transaction (customer, same barber and service):
  ///  1. read the booking (it must still be pending/confirmed) and every
  ///     lock of the old and the new interval;
  ///  2. abort with [SlotTakenException] if a new block is held by anyone
  ///     else (another booking, or time off: `timeOffId`, no bookingId);
  ///  3. `update` the booking with exactly `startAt, endAt, date, timeSlot,
  ///     rescheduleCount (stored + 1), rescheduledAt`;
  ///  4. `delete` each old lock with `bookingId == booking.id` whose block
  ///     is not in the new interval;
  ///  5. `set` (create) `{bookingId, startAt, expiresAt: newEnd + 1 day}`
  ///     for each new block that has no lock yet. Blocks in both intervals
  ///     keep their existing lock untouched.
  /// The `verifyBookingLocks` function re-checks every new block after the
  /// write and cancels the booking (`slot_conflict`) if one is missing.
  @override
  Future<void> rescheduleBooking(Booking original, Booking updated) async {
    final bookingRef = _bookings.doc(original.id);
    final locksRef = _slotLocksOf(original.shopId, original.barberId);
    final newLocks = slotLocksForBooking(updated);
    final newIds = {for (final l in newLocks) l.id};
    try {
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(bookingRef);
        final data = snap.data();
        if (data == null) throw AppStateException(AppErrorCode.bookingNotChangeable);
        final fresh = Booking.fromMap(data, snap.id);
        if (fresh.status != BookingStatus.pending && fresh.status != BookingStatus.confirmed) {
          throw AppStateException(AppErrorCode.bookingNotChangeable);
        }
        final oldIds = slotLockIdsFor(fresh.startAt, fresh.endAt);

        final releasable = <DocumentReference<Map<String, dynamic>>>[];
        for (final id in oldIds) {
          if (newIds.contains(id)) continue;
          final lock = await tx.get(locksRef.doc(id));
          if (lock.exists && lock.data()?['bookingId'] == original.id) releasable.add(lock.reference);
        }
        final toCreate = <SlotLock>[];
        for (final lock in newLocks) {
          final existing = await tx.get(locksRef.doc(lock.id));
          if (!existing.exists) {
            toCreate.add(lock);
          } else if (existing.data()?['bookingId'] != original.id) {
            throw const SlotTakenException();
          }
        }

        tx.update(bookingRef, {
          ...updated.rescheduleFields(),
          'rescheduleCount': fresh.rescheduleCount + 1,
        });
        for (final ref in releasable) {
          tx.delete(ref);
        }
        for (final lock in toCreate) {
          tx.set(locksRef.doc(lock.id), lock.toMap());
        }
      });
    } on SlotTakenException {
      rethrow;
    } on AppException {
      rethrow;
    } on FirebaseException {
      // A lost race can surface as a rules rejection (the lock now exists,
      // so the create became an update).
      final oldIds = slotLockIdsFor(original.startAt, original.endAt).toSet();
      final added = newLocks.where((l) => !oldIds.contains(l.id)).toList();
      if (await _anyLockExists(locksRef, added)) throw const SlotTakenException();
      rethrow;
    }
  }

  /// Only the two policy fields (the rules let the owner change them).
  @override
  Future<void> updateShopPolicy(String shopId, {required int cancellationCutoffHours, required int maxReschedules}) {
    return _shops.doc(shopId).update({
      'cancellationCutoffHours': cancellationCutoffHours,
      'maxReschedules': maxReschedules,
    });
  }

  CollectionReference<Map<String, dynamic>> _timeOffOf(String shopId, String barberId) =>
      _barbersOf(shopId).doc(barberId).collection('timeOff');

  /// How far back the time-off listener reaches (by `endAt`).
  static const Duration timeOffHistory = Duration(days: 7);

  /// Time off ending in the last [timeOffHistory] or later: a single-field
  /// range on `endAt` (no composite index), sorted by start on the client.
  @override
  Stream<List<TimeOff>> watchTimeOff(String shopId, String barberId) {
    final since = _clock().toUtc().subtract(timeOffHistory).toIso8601String();
    return _timeOffOf(shopId, barberId)
        .where('endAt', isGreaterThanOrEqualTo: since)
        .orderBy('endAt')
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs) TimeOff.fromMap(d.data(), d.id, shopId: shopId, barberId: barberId),
            ]..sort((a, b) => a.startAt.compareTo(b.startAt)));
  }

  /// One batch: `set` the time-off doc `{startAt, endAt, reason?, createdBy,
  /// createdAt}` and `set` a lock `{timeOffId, startAt, expiresAt}` for each
  /// block. The day's locks are read first so a clash is reported as
  /// [AppErrorCode.timeOffConflict]; a lock created in between makes the
  /// batch fail in the rules (locks are never updated), reported the same.
  @override
  Future<void> addTimeOff(TimeOff timeOff) async {
    final locksRef = _slotLocksOf(timeOff.shopId, timeOff.barberId);
    final day = toAddisWallClock(timeOff.startAt);
    Future<List<SlotLock>> dayLocks() async {
      final (dayStart, dayEnd) = addisDayBoundsUtc(DateTime(day.year, day.month, day.day));
      final snap = await locksRef
          .where('startAt', isGreaterThanOrEqualTo: dayStart.toIso8601String())
          .where('startAt', isLessThan: dayEnd.toIso8601String())
          .get();
      return [for (final d in snap.docs) SlotLock.fromMap(d.data(), d.id)];
    }

    if (timeOffConflicts(timeOff, bookings: cache.bookings.values, locks: await dayLocks())) {
      throw AppStateException(AppErrorCode.timeOffConflict);
    }
    final batch = _db.batch();
    batch.set(_timeOffOf(timeOff.shopId, timeOff.barberId).doc(timeOff.id), timeOff.toMap());
    for (final lock in slotLocksForTimeOff(timeOff)) {
      batch.set(locksRef.doc(lock.id), lock.toMap());
    }
    try {
      await batch.commit();
    } on FirebaseException {
      var locks = const <SlotLock>[];
      try {
        locks = await dayLocks();
      } catch (_) {
        // Report the original error.
      }
      if (timeOffConflicts(timeOff, locks: locks)) throw AppStateException(AppErrorCode.timeOffConflict);
      rethrow;
    }
  }

  /// One batch: delete the time-off doc and every lock with
  /// `timeOffId == timeOff.id` (an equality query on the barber's
  /// slotLocks; the automatic single-field index serves it).
  @override
  Future<void> deleteTimeOff(TimeOff timeOff) async {
    final locks = await _slotLocksOf(timeOff.shopId, timeOff.barberId).where('timeOffId', isEqualTo: timeOff.id).get();
    final batch = _db.batch();
    for (final d in locks.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_timeOffOf(timeOff.shopId, timeOff.barberId).doc(timeOff.id));
    await batch.commit();
  }
}
