import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/plan_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import 'availability_service.dart';
import 'data_cache.dart';
import 'data_store.dart';

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
///               bookings where customerId == uid
///  * owner:     doc barbershops/{shopId}; its services and barbers subcollections;
///               bookings where shopId == shopId;
///               invites where shopId == shopId and role == 'barber';
///               users where shopId == shopId; plans
///  * barber:    doc barbershops/{shopId}; its services and barbers subcollections;
///               bookings where shopId == shopId and barberId == barberId
///  * admin:     barbershops; collectionGroup services; collectionGroup barbers;
///               bookings orderBy createdAt desc limit 500; users; invites; plans
class FirestoreDataStore implements DataStore {
  FirestoreDataStore({
    required this.cache,
    required this.onChanged,
    required this.onCurrentUserChanged,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final DataCache cache;
  final FirebaseFirestore _db;

  /// Called after every snapshot that changed the cache.
  final VoidCallback onChanged;

  /// Called when the signed-in user's own `users/{uid}` document changes
  /// (null when it is deleted).
  final void Function(AppUser? user) onCurrentUserChanged;

  static const int adminBookingLimit = 500;

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
        listenQuery(_bookings.where('customerId', isEqualTo: user.uid), cache.bookings, Booking.fromMap);
      case UserRole.barbershopOwner:
        final shopId = user.shopId;
        if (shopId != null) {
          listenDoc(_shops.doc(shopId), cache.shops, Barbershop.fromMap);
          listenQuery(_servicesOf(shopId), cache.services, BarbershopService.fromMap);
          listenQuery(_barbersOf(shopId), cache.barbers, Barber.fromMap);
          listenQuery(_bookings.where('shopId', isEqualTo: shopId), cache.bookings, Booking.fromMap);
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
          listenQuery(
            _bookings.where('shopId', isEqualTo: shopId).where('barberId', isEqualTo: barberId),
            cache.bookings,
            Booking.fromMap,
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
    if (ownerInvite != null) batch.set(_invites.doc(ownerInvite.phone), ownerInvite.toMap());
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
      batch.delete(_invites.doc(i.phone));
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
    if (invite != null) batch.set(_invites.doc(invite.phone), invite.toMap());
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
    if (pendingInvite != null) batch.delete(_invites.doc(pendingInvite.phone));
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _slotLocksOf(String shopId, String barberId) =>
      _barbersOf(shopId).doc(barberId).collection('slotLocks');

  /// Double-booking prevention. In ONE transaction:
  ///  1. read `slotLocks/{id}` for every 15-minute block the booking covers;
  ///  2. if any exists, abort with [SlotTakenException];
  ///  3. otherwise create `bookings/{id}` and every lock
  ///     `{bookingId, customerId, startAt}`.
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
  Future<void> updateUserProfile(String uid, {String? name, String? language}) {
    return _users.doc(uid).update({
      if (name != null) 'name': name,
      if (language != null) 'language': language,
    });
  }
}
