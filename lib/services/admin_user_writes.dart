/// Writes of admin user management (admin_users.dart): a role change in
/// one batch, the disable / enable of an account and the optional
/// cancellation of the person's upcoming bookings. Firestore (works on the
/// free Spark plan) and an in-memory version for demo builds and tests.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'admin_users.dart';
import 'data_cache.dart';
import 'firestore_data_store.dart' show FirestoreDataStore;
import 'refund_writes.dart';
import 'refunds.dart';
import 'shop_deletion.dart' show chunked;

/// Bookings cancelled per batch (each may also write a notice and a
/// refund notice).
const int kDisableCancelChunk = 5;

abstract class AdminUserWrites {
  /// Applies [plan] in one batch (see [RoleChangePlan] for the writes).
  Future<void> applyRoleChange(RoleChangePlan plan);

  /// Disables [uid] with [fields] ([disableFields]).
  Future<void> disable(String uid, Map<String, dynamic> fields);

  /// Removes the disable fields ([kDisableFieldKeys]) from [uid].
  Future<void> enable(String uid);

  /// [user]'s pending/confirmed bookings starting at or after [nowUtc]:
  /// as the customer, and (a barber) with their barber profile.
  Future<List<Booking>> upcomingBookingsOf(AppUser user, DateTime nowUtc);

  /// Cancels [items] (`status: cancelled`, `cancelledBy: adminUid`,
  /// `cancelReason: 'account_disabled'`, a paid booking's refund flag) and
  /// writes each item's customer notice, in batches.
  Future<void> cancelBookings(List<DisableCancellation> items, {required String adminUid, required RefundContext refund});
}

/// Firestore: what the admin's app writes (firestore.rules, see the rules
/// handoff in the admin users change).
class FirestoreAdminUserWrites implements AdminUserWrites {
  FirestoreAdminUserWrites(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _invites => _db.collection('invites');
  CollectionReference<Map<String, dynamic>> get _shops => _db.collection('barbershops');
  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');

  /// `users/{uid}` update for the role links of [user] (absent links deleted).
  static Map<String, dynamic> roleFields(AppUser user) => {
        'role': user.role.name,
        'shopId': user.shopId ?? FieldValue.delete(),
        'barberId': user.barberId ?? FieldValue.delete(),
      };

  @override
  Future<void> applyRoleChange(RoleChangePlan plan) async {
    final batch = _db.batch();
    final newBarber = plan.newBarber;
    if (newBarber != null) {
      final data = newBarber.toMap()..removeWhere((_, v) => v == null);
      batch.set(_shops.doc(newBarber.shopId).collection('barbers').doc(newBarber.id), data);
    }
    final available = plan.makeAvailableBarberId;
    if (available != null) {
      batch.update(_shops.doc(plan.after.shopId).collection('barbers').doc(available), {'isAvailable': true});
    }
    final unlinked = plan.unlinkedBarber;
    if (unlinked != null) {
      batch.update(_shops.doc(unlinked.shopId).collection('barbers').doc(unlinked.id), {'isAvailable': false});
    }
    batch.update(_users.doc(plan.after.uid), roleFields(plan.after));
    for (final owner in plan.previousOwners) {
      batch.update(_users.doc(owner.uid), roleFields(withRole(owner, UserRole.customer)));
    }
    final release = plan.releaseShopId;
    if (release != null) batch.update(_shops.doc(release), {'ownerId': ''});
    final claim = plan.claimShopId;
    if (claim != null) batch.update(_shops.doc(claim), {'ownerId': plan.after.uid});
    for (final email in plan.deleteInviteEmails) {
      batch.delete(_invites.doc(email));
    }
    await batch.commit();
  }

  @override
  Future<void> disable(String uid, Map<String, dynamic> fields) => _users.doc(uid).update(fields);

  @override
  Future<void> enable(String uid) => _users.doc(uid).update({for (final k in kDisableFieldKeys) k: FieldValue.delete()});

  @override
  Future<List<Booking>> upcomingBookingsOf(AppUser user, DateTime nowUtc) async {
    final queries = <Query<Map<String, dynamic>>>[
      FirestoreDataStore.upcomingBookingsQuery(_bookings.where('customerId', isEqualTo: user.uid), nowUtc),
      if (user.role == UserRole.barber && user.shopId != null && user.barberId != null)
        FirestoreDataStore.upcomingBookingsQuery(
          _bookings.where('shopId', isEqualTo: user.shopId).where('barberId', isEqualTo: user.barberId),
          nowUtc,
        ),
    ];
    final byId = <String, Booking>{};
    for (final q in queries) {
      final snap = await q.get();
      for (final d in snap.docs) {
        byId[d.id] = Booking.fromMap(d.data(), d.id);
      }
    }
    return byId.values.where((b) => isCancelledByDisable(b, user, nowUtc)).toList();
  }

  @override
  Future<void> cancelBookings(List<DisableCancellation> items,
      {required String adminUid, required RefundContext refund}) async {
    for (final chunk in chunked(items, kDisableCancelChunk)) {
      final batch = _db.batch();
      for (final item in chunk) {
        final update = <String, dynamic>{
          'status': BookingStatus.cancelled.name,
          'cancelledBy': adminUid,
          'cancelReason': kAccountDisabledCancelReason,
        };
        flagRefundIfPaid(
          db: _db,
          create: (ref, data) => batch.set(ref, data),
          bookingUpdate: update,
          booking: item.booking,
          context: refund,
        );
        batch.update(_bookings.doc(item.booking.id), update);
        final notice = item.notice;
        if (notice != null) {
          batch.set(_users.doc(notice.recipientUid).collection('notifications').doc(notice.id), notice.toMap());
        }
      }
      await batch.commit();
    }
  }
}

/// Demo builds and tests: writes the in-memory [DataCache].
class LocalAdminUserWrites implements AdminUserWrites {
  LocalAdminUserWrites(this.cache, {this.onNotice});

  final DataCache cache;

  /// Receives each customer notice of [cancelBookings] (local inboxes).
  void Function(DisableCancellation item)? onNotice;

  @override
  Future<void> applyRoleChange(RoleChangePlan plan) async {
    final newBarber = plan.newBarber;
    if (newBarber != null) cache.barbers[newBarber.id] = newBarber;
    final available = plan.makeAvailableBarberId;
    final availableOld = available == null ? null : cache.barbers[available];
    if (availableOld != null) cache.barbers[availableOld.id] = availableOld.copyWith(isAvailable: true);
    final unlinked = plan.unlinkedBarber;
    final unlinkedOld = unlinked == null ? null : cache.barbers[unlinked.id];
    if (unlinkedOld != null) cache.barbers[unlinkedOld.id] = unlinkedOld.copyWith(isAvailable: false);
    final current = cache.users[plan.after.uid] ?? plan.before;
    cache.users[plan.after.uid] =
        withRole(current, plan.after.role, shopId: plan.after.shopId, barberId: plan.after.barberId);
    for (final owner in plan.previousOwners) {
      final old = cache.users[owner.uid];
      if (old != null) cache.users[old.uid] = withRole(old, UserRole.customer);
    }
    final release = plan.releaseShopId;
    final released = release == null ? null : cache.shops[release];
    if (released != null) cache.shops[released.id] = released.copyWith(ownerId: '');
    final claim = plan.claimShopId;
    final claimed = claim == null ? null : cache.shops[claim];
    if (claimed != null) cache.shops[claimed.id] = claimed.copyWith(ownerId: plan.after.uid);
    for (final email in plan.deleteInviteEmails) {
      cache.invites.remove(email);
    }
  }

  @override
  Future<void> disable(String uid, Map<String, dynamic> fields) async {
    final old = cache.users[uid];
    if (old == null) return;
    cache.users[uid] = old.copyWith(
      disabled: true,
      disabledAt: DateTime.tryParse(fields['disabledAt'] as String? ?? '')?.toUtc(),
      disabledBy: fields['disabledBy'] as String?,
      disabledReason: fields['disabledReason'] as String?,
    );
  }

  @override
  Future<void> enable(String uid) async {
    final old = cache.users[uid];
    if (old != null) cache.users[uid] = old.copyWith(disabled: false);
  }

  @override
  Future<List<Booking>> upcomingBookingsOf(AppUser user, DateTime nowUtc) async =>
      cache.bookings.values.where((b) => isCancelledByDisable(b, user, nowUtc)).toList();

  @override
  Future<void> cancelBookings(List<DisableCancellation> items,
      {required String adminUid, required RefundContext refund}) async {
    for (final item in items) {
      final old = cache.bookings[item.booking.id];
      if (old == null) continue;
      cache.bookings[old.id] = old.copyWith(
        status: BookingStatus.cancelled,
        cancelledBy: adminUid,
        cancelReason: kAccountDisabledCancelReason,
        refund: refundFlagFor(old, refund),
      );
      if (item.notice != null) onNotice?.call(item);
    }
  }
}
