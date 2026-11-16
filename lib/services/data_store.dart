import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/service_model.dart';
import 'dart:async';

import '../models/app_exception.dart';
import 'availability_service.dart';
import 'data_cache.dart';
import 'early_finish_service.dart' show EarlyFinishNotice; // early finish
import 'time_off_service.dart';
import '../models/user_model.dart'; // shop deletion
import 'shop_deletion.dart'; // shop deletion
import 'refunds.dart'; // refunds
import '../models/app_notification.dart' show AppNotification; // vacation

export 'availability_service.dart' show SlotLock, SlotTakenException;
export 'time_off_service.dart' show TimeOff;

/// Most bookings a "Refunds due" query returns.
const int kRefundsQueryLimit = 200; // refunds

/// All data writes the app makes (besides sign-in / profile creation, which
/// live in AppRepository). Validation and permission-shaped checks happen in
/// AppRepository before these are called.
///
/// Two implementations:
///  * [LocalDataStore] - demo builds and tests: writes straight into the
///    [DataCache], synchronously (the returned future is already complete).
///  * FirestoreDataStore - production: writes to Firestore only; the cache is
///    updated by its snapshot listeners.
abstract class DataStore {
  /// Admin: creates a shop with its starter services, barbers and the
  /// owner's invite, atomically.
  Future<void> createShop({
    required Barbershop shop,
    required List<BarbershopService> services,
    required List<Barber> barbers,
    UserInvite? ownerInvite,
  });

  /// Owner: profile fields only ([Barbershop.toProfileMap]), including the
  /// owner-only opening hours. The admin edit uses [adminUpdateShop].
  Future<void> updateShopProfile(Barbershop shop);

  /// Admin only.
  Future<void> setShopVerified(String shopId, bool isVerified);

  /// Admin only (normally done by the payments Cloud Functions).
  Future<void> updateShopSubscription(
    String shopId, {
    required String plan,
    required SubscriptionStatus status,
    DateTime? endsAt,
  });

  // --- subscription expiry (client-side) ---
  /// Owner (own shop) or admin: records a lapsed trial / paid period. One
  /// update of exactly [subscriptionTransitionPatch] (subscription_state.dart):
  /// {subscriptionStatus: 'past_due' | 'suspended', subscriptionStatusChangedAt: ISO}.
  Future<void> setShopSubscriptionTransition(String shopId, Map<String, dynamic> fields);
  // --- end subscription expiry ---

  /// Admin: deletes the shop's data ([deleteShopData]), its invites and the
  /// shop document. Bookings are kept. (The full cascade, which also
  /// cancels upcoming bookings and downgrades the staff, is
  /// AppRepository.deleteShop, see shop_deletion.dart.)
  Future<void> deleteShop(String shopId);

  // --- shop deletion (see shop_deletion.dart) ---

  /// Admin: merges [record] into `shopDeletions/{shopId}` (staff uids are
  /// added with arrayUnion, so a retry keeps the first run's list).
  Future<void> recordShopDeletion(ShopDeletionRecord record);

  /// Admin: the shop's bookings starting at or after [nowUtc] (any status;
  /// callers pick the pending/confirmed ones).
  Future<List<Booking>> upcomingBookingsOfShop(String shopId, DateTime nowUtc);

  /// Admin: in batches of [kShopDeletionBookingChunk]: `update` each booking
  /// with exactly `{status: 'cancelled', cancelledBy, cancelReason:
  /// 'shop_deleted'}` and `set` (create) its customer's notice.
  /// Refunds: with [refund], a paid booking also gets its refund flag in
  /// that update plus the `{bookingId}_refundDue` notice (refund_writes.dart).
  Future<void> cancelBookingsForShopDeletion(List<ShopBookingCancellation> items,
      {required String cancelledBy, RefundContext? refund});

  /// Admin: owner and barber accounts of the shop (`users where shopId ==`).
  Future<List<AppUser>> staffOfShop(String shopId);

  /// Admin: invites of the shop (`invites where shopId ==`; owner and barber).
  Future<List<UserInvite>> invitesOfShop(String shopId);

  /// Admin: in batches of [kShopDeletionStaffChunk]: `update` each user to
  /// `{role: 'customer'}` with shopId and barberId deleted and `set`
  /// (create) its notice; then deletes every invite of [shopId].
  Future<void> revokeShopStaff(String shopId, List<ShopStaffRevocation> items);

  /// Admin: deletes every document of the shop's subcollections
  /// ([kBarberSubcollections] of each barber, the barbers, then
  /// [kShopSubcollections]) in batches of [kShopDeletionDeleteChunk]. The
  /// shop document stays.
  Future<void> deleteShopData(String shopId);

  /// Admin: deletes `barbershops/{shopId}` only.
  Future<void> deleteShopDoc(String shopId);
  // --- end shop deletion ---

  // --- admin shop management ---
  /// Admin: one update of [Barbershop.toAdminEditMap] (profile without the
  /// owner-only opening hours, isVerified, subscriptionPlan,
  /// subscriptionStatus, subscriptionEndsAt; null values delete the field).
  Future<void> adminUpdateShop(Barbershop shop);

  /// Admin: one update of [Barbershop.adminSuspensionFields] (suspend with
  /// reason/at/by, or reactivate: adminSuspended false, the rest deleted).
  Future<void> setShopAdminSuspension(String shopId, Map<String, dynamic> fields);
  // --- end admin shop management ---

  Future<void> addService(BarbershopService service);
  Future<void> updateService(BarbershopService service);
  Future<void> deleteService(BarbershopService service);

  /// Adds a barber profile (public: never its phone) and, optionally, their
  /// sign-in invite, plus the private contact doc
  /// `barbers/{id}/private/contact {phone}` when [phone] is given. One batch.
  Future<void> addBarber(Barber barber, UserInvite? invite, {String? phone});

  /// Owner/admin: profile fields only ([Barber.toProfileMap]).
  Future<void> updateBarberProfile(Barber barber);
  Future<void> setBarberAvailability(Barber barber, bool isAvailable);
  Future<void> deleteBarber(Barber barber, UserInvite? pendingInvite);

  // --- private barber phone ---
  /// Owner/admin/that barber: sets `barbers/{id}/private/contact` to
  /// exactly `{phone}`, or deletes it when [phone] is null.
  Future<void> setBarberPhone(String shopId, String barberId, String? phone);

  /// Owner/admin: moves a legacy public barber doc's contact fields out of
  /// it. Firestore: reads the private contact first, then ONE batch: `set`
  /// the contact to `{phone}` when [phone] is given and no contact exists
  /// yet (an existing one is newer and wins), and `update` the public doc
  /// with `phone` and `email` deleted. Idempotent.
  Future<void> migrateBarberContact(Barber barber, {String? phone});

  /// Barber/owner: copies the barber's phone into a confirmed (or in
  /// progress) booking: an `update` of exactly `{barberPhone}`.
  Future<void> shareBarberPhone(Booking booking, String phone);
  // --- end private barber phone ---

  /// Stores a fully built booking, atomically with its slot locks (one per
  /// 15-minute block it covers, see availability_service.dart).
  ///
  /// Throws [SlotTakenException] if any of those blocks is already held by
  /// another booking for the same barber.
  Future<void> createBooking(Booking booking);

  /// Changes a booking's status. Cancelling also releases its slot locks in
  /// the same write and records [cancelledBy] (the caller's uid) so the
  /// notification backend can say who cancelled. [cancelReasonNote] (the
  /// barber's optional note, already trimmed and <= 200 characters) is
  /// written with a cancel only. Refunds: with [refund], cancelling a paid
  /// booking also flags its refund in the same write (refund_writes.dart).
  Future<void> updateBookingStatus(Booking booking, BookingStatus status,
      {String? cancelledBy, String? cancelReasonNote, RefundContext? refund});

  /// Live slot locks of one barber on one Addis calendar day. These cover
  /// other customers' bookings, which customers cannot read directly.
  /// The local store has no locks (every booking is in the cache) and emits
  /// a single empty list.
  Stream<List<SlotLock>> watchSlotLocks(String shopId, String barberId, DateTime addisDate);

  /// The signed-in user's own editable fields (name, language, phone).
  Future<void> updateUserProfile(String uid, {String? name, String? language, String? phone});

  // --- Reschedule, policy, time off (see booking_policy.dart and
  // time_off_service.dart) ---

  /// Customer: moves [original] to [updated]'s interval in ONE transaction:
  /// the booking update ([Booking.rescheduleFields]), a delete of every old
  /// lock this booking holds that the new interval does not reuse, and a
  /// create of every new lock it does not already hold. Locks of blocks in
  /// both intervals are left as they are.
  ///
  /// Throws [SlotTakenException] if a new block is held by anyone else
  /// (another booking or time off).
  Future<void> rescheduleBooking(Booking original, Booking updated);

  /// Owner: writes only `cancellationCutoffHours` and `maxReschedules`
  /// (plus `requireBarberAcceptance` when given).
  Future<void> updateShopPolicy(String shopId,
      {required int cancellationCutoffHours, required int maxReschedules, bool? requireBarberAcceptance});

  /// Live time-off ranges of one barber (soonest first).
  Stream<List<TimeOff>> watchTimeOff(String shopId, String barberId);

  /// Owner or that barber: creates the time-off doc and its slot locks in
  /// one batch. Throws [AppStateException] ([AppErrorCode.timeOffConflict])
  /// if any block is already held.
  Future<void> addTimeOff(TimeOff timeOff);

  /// Deletes the time-off doc and its slot locks in one batch.
  Future<void> deleteTimeOff(TimeOff timeOff);

  // --- vacation (see vacation_service.dart) ---

  /// The barber's slot locks whose `startAt` is in `[startUtc, endUtc)`
  /// (bookings and time off; one single-field range query). The local
  /// store returns its time-off locks (bookings are all in the cache).
  Future<List<SlotLock>> slotLocksBetween(String shopId, String barberId, DateTime startUtc, DateTime endUtc);

  /// Staff (owner or the booked barber) creates the customer's inbox
  /// notice `users/{recipientUid}/notifications/{notice.id}` after
  /// cancelling a booking for a vacation (free plan: no Cloud Function
  /// tells the customer). The local store only records it (its inbox
  /// derives the cancel notice from the booking).
  Future<void> writeVacationCancelNotice(String recipientUid, AppNotification notice);

  // --- barber acceptance (see booking_acceptance.dart) ---

  /// Barber/owner: a still-pending request becomes confirmed
  /// ([acceptFields]: status + acceptedAt). Throws [AppStateException]
  /// ([AppErrorCode.bookingNotChangeable]) if it is no longer pending.
  Future<void> acceptBookingRequest(Booking booking, {required DateTime acceptedAt});

  /// Barber/owner: a still-pending request is cancelled ([declineFields]:
  /// status, cancelledBy 'barber', declineReason?) and its own slot locks
  /// are released in the same write, as a cancel does (and, with [refund],
  /// a paid booking's refund is flagged in it).
  Future<void> declineBookingRequest(Booking booking, {String? reason, RefundContext? refund});
  // --- end barber acceptance ---

  // --- refunds (see refunds.dart / refund_writes.dart) ---

  /// Owner ([shopId]) or admin (null: every shop): bookings whose
  /// refundStatus is 'due'. Firestore: `bookings where refundStatus == 'due'`
  /// (+ `shopId ==`), limit [kRefundsQueryLimit]. The local store emits the
  /// cache's due refunds once (AppRepository re-reads the cache on changes).
  Stream<List<Booking>> watchRefundsDue({String? shopId});

  /// Owner/admin: flags the refund of an already-cancelled paid booking
  /// that has none (an older app cancelled it). ONE batch: `update` the
  /// booking with exactly [BookingRefund.toFlagFields] and create the
  /// customer's [notice].
  Future<void> flagRefund(Booking booking, BookingRefund flag, RefundNotice? notice);

  /// Owner/admin: "Mark refunded". ONE batch: `update` the booking with
  /// exactly [fields] (refundCompletionFields) and create the customer's
  /// [notice] (`{bookingId}_paymentRefunded`). Throws [AppStateException]
  /// ([AppErrorCode.bookingNotChangeable]) when the refund is no longer due.
  Future<void> markRefunded(Booking booking, Map<String, dynamic> fields, RefundNotice? notice);
  // --- end refunds ---

  // --- early finish (see early_finish_service.dart) ---

  /// Staff: marks [booking] completed, writing exactly
  /// `{status: 'completed', completedAt: <UTC ISO>}`.
  Future<void> completeBooking(Booking booking, {required DateTime completedAt});

  /// Staff, right after an early [completeBooking]: creates each notice at
  /// `users/{recipientUid}/notifications/{id}` in ONE batch. The local store
  /// does nothing here: LocalNotificationInbox derives the same entries
  /// from the completed booking (its completedAt).
  Future<void> writeEarlyFinishNotices(List<EarlyFinishNotice> notices);
  // --- end early finish ---
}

/// In-memory [DataStore] used when Firebase is not attached.
class LocalDataStore implements DataStore {
  LocalDataStore(this.cache);

  final DataCache cache;

  /// Time-off ranges by id (the local database has no slot-lock documents;
  /// [watchSlotLocks] derives the time-off locks from these).
  final Map<String, TimeOff> timeOff = {};
  final StreamController<void> _timeOffChanges = StreamController<void>.broadcast();

  /// Replaces all time off (demo seed, tests).
  void loadTimeOff(Iterable<TimeOff> entries) {
    timeOff
      ..clear()
      ..addEntries(entries.map((t) => MapEntry(t.id, t)));
    _timeOffChanges.add(null);
  }

  /// A stream that emits [read]() now and after every time-off change.
  Stream<T> _watchTimeOffState<T>(T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        sub = _timeOffChanges.stream.listen((_) {
          if (!controller.isClosed) controller.add(read());
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  bool _blocksTaken(Booking booking, {String? ignoreBookingId}) {
    final ids = slotLockIdsFor(booking.startAt, booking.endAt).toSet();
    final bookingClash = cache.bookings.values.any((b) =>
        b.id != booking.id && b.id != ignoreBookingId && occupiesSlot(b) && bookingsConflict(b, booking));
    final timeOffClash = timeOff.values.any((t) =>
        t.shopId == booking.shopId && t.barberId == booking.barberId && timeOffLockIds(t).any(ids.contains));
    return bookingClash || timeOffClash;
  }

  @override
  Future<void> createShop({
    required Barbershop shop,
    required List<BarbershopService> services,
    required List<Barber> barbers,
    UserInvite? ownerInvite,
  }) async {
    // Newest shop first.
    final rest = Map.of(cache.shops);
    cache.shops
      ..clear()
      ..[shop.id] = shop
      ..addAll(rest);
    for (final s in services) {
      cache.services[s.id] = s;
    }
    for (final b in barbers) {
      // private barber phone: kept out of the (public) profile.
      final phone = b.phone;
      if (phone != null && phone.isNotEmpty) cache.barberPhones[b.id] = phone;
      cache.barbers[b.id] = b.copyWith(clearContact: true);
    }
    if (ownerInvite != null) cache.invites[ownerInvite.email] = ownerInvite;
  }

  @override
  Future<void> updateShopProfile(Barbershop shop) async {
    final old = cache.shops[shop.id];
    if (old == null) return;
    cache.shops[shop.id] = old.copyWith(
      name: shop.name,
      description: shop.description,
      address: shop.address,
      city: shop.city,
      subCity: shop.subCity,
      landmark: shop.landmark,
      clearLandmark: shop.landmark == null,
      // shop location (maps): the pin is replaced (or removed) as a whole.
      latitude: shop.hasLocation ? shop.latitude : null,
      longitude: shop.hasLocation ? shop.longitude : null,
      clearLocation: !shop.hasLocation,
      phone: shop.phone,
      imageUrl: shop.imageUrl,
      openingHour: shop.openingHour,
      closingHour: shop.closingHour,
      workingDays: shop.workingDays,
    );
  }

  @override
  Future<void> setShopVerified(String shopId, bool isVerified) async {
    final old = cache.shops[shopId];
    if (old != null) cache.shops[shopId] = old.copyWith(isVerified: isVerified);
  }

  @override
  Future<void> updateShopSubscription(
    String shopId, {
    required String plan,
    required SubscriptionStatus status,
    DateTime? endsAt,
  }) async {
    final old = cache.shops[shopId];
    if (old == null) return;
    cache.shops[shopId] = old.copyWith(
      subscriptionPlan: plan,
      subscriptionStatus: status,
      subscriptionEndsAt: endsAt,
      // subscription expiry: null deletes the end date, like Firestore.
      clearSubscriptionEndsAt: endsAt == null,
    );
  }

  // --- subscription expiry (client-side) ---
  @override
  Future<void> setShopSubscriptionTransition(String shopId, Map<String, dynamic> fields) async {
    final old = cache.shops[shopId];
    if (old == null) return;
    cache.shops[shopId] =
        old.copyWith(subscriptionStatus: SubscriptionStatus.fromString(fields['subscriptionStatus'] as String?));
  }
  // --- end subscription expiry ---

  @override
  Future<void> deleteShop(String shopId) async {
    // Like Firestore: bookings stay for history; staff accounts are
    // downgraded by the cascade (AppRepository.deleteShop), not removed.
    await deleteShopData(shopId);
    cache.invites.removeWhere((_, i) => i.shopId == shopId);
    await deleteShopDoc(shopId);
  }

  // --- shop deletion ---

  /// `shopDeletions/{shopId}` records (tests, demo).
  final Map<String, ShopDeletionRecord> shopDeletions = {};

  /// Inbox notices the cascade wrote, oldest first (AppRepository forwards
  /// them to the local inboxes).
  final List<ShopDeletionNotice> sentNotices = [];

  @override
  Future<void> recordShopDeletion(ShopDeletionRecord record) async {
    final old = shopDeletions[record.shopId];
    shopDeletions[record.shopId] = ShopDeletionRecord(
      shopId: record.shopId,
      shopName: record.shopName,
      requestedBy: record.requestedBy,
      requestedAt: record.requestedAt,
      staffUids: {...?old?.staffUids, ...record.staffUids}.toList(),
      barberAccountUids: {...?old?.barberAccountUids, ...record.barberAccountUids}.toList(),
    );
  }

  @override
  Future<List<Booking>> upcomingBookingsOfShop(String shopId, DateTime nowUtc) async => [
        for (final b in cache.bookings.values)
          if (b.shopId == shopId && !b.startAt.isBefore(nowUtc.toUtc())) b,
      ];

  @override
  Future<void> cancelBookingsForShopDeletion(List<ShopBookingCancellation> items,
      {required String cancelledBy, RefundContext? refund}) async {
    for (final item in items) {
      final old = cache.bookings[item.booking.id];
      if (old == null) continue;
      cache.bookings[old.id] = old.copyWith(
        status: BookingStatus.cancelled,
        cancelledBy: cancelledBy,
        cancelReason: kShopDeletedCancelReason,
        refund: _refundFlag(old, refund), // refunds
      );
      sentNotices.add(item.notice);
    }
  }

  @override
  Future<List<AppUser>> staffOfShop(String shopId) async => [
        for (final u in cache.users.values)
          if (u.shopId == shopId) u,
      ];

  @override
  Future<List<UserInvite>> invitesOfShop(String shopId) async => [
        for (final i in cache.invites.values)
          if (i.shopId == shopId) i,
      ];

  @override
  Future<void> revokeShopStaff(String shopId, List<ShopStaffRevocation> items) async {
    for (final item in items) {
      final old = cache.users[item.user.uid];
      if (old == null) continue;
      cache.users[old.uid] = downgradedToCustomer(old);
      sentNotices.add(item.notice);
    }
    cache.invites.removeWhere((_, i) => i.shopId == shopId);
  }

  @override
  Future<void> deleteShopData(String shopId) async {
    cache.services.removeWhere((_, s) => s.shopId == shopId);
    cache.barberPhones.removeWhere((id, _) => cache.barbers[id]?.shopId == shopId);
    cache.barbers.removeWhere((_, b) => b.shopId == shopId);
    final before = timeOff.length;
    timeOff.removeWhere((_, t) => t.shopId == shopId);
    if (timeOff.length != before) _timeOffChanges.add(null);
  }

  @override
  Future<void> deleteShopDoc(String shopId) async {
    cache.shops.remove(shopId);
  }
  // --- end shop deletion ---

  // --- admin shop management ---
  @override
  Future<void> adminUpdateShop(Barbershop shop) async {
    final old = cache.shops[shop.id];
    if (old == null) return;
    // Same fields as Barbershop.toAdminEditMap: the profile without the
    // opening hours (owner only), verification and the subscription.
    cache.shops[shop.id] = old.copyWith(
      name: shop.name,
      description: shop.description,
      address: shop.address,
      city: shop.city,
      subCity: shop.subCity,
      landmark: shop.landmark,
      clearLandmark: shop.landmark == null,
      // shop location (maps): the pin is replaced (or removed) as a whole.
      latitude: shop.hasLocation ? shop.latitude : null,
      longitude: shop.hasLocation ? shop.longitude : null,
      clearLocation: !shop.hasLocation,
      phone: shop.phone,
      imageUrl: shop.imageUrl,
      isVerified: shop.isVerified,
      subscriptionPlan: shop.subscriptionPlan,
      subscriptionStatus: shop.subscriptionStatus,
      subscriptionEndsAt: shop.subscriptionEndsAt,
      clearSubscriptionEndsAt: shop.subscriptionEndsAt == null,
    );
  }

  @override
  Future<void> setShopAdminSuspension(String shopId, Map<String, dynamic> fields) async {
    final old = cache.shops[shopId];
    if (old == null) return;
    if (fields['adminSuspended'] == true) {
      cache.shops[shopId] = old.copyWith(
        adminSuspended: true,
        adminSuspendedReason: fields['adminSuspendedReason'] as String?,
        adminSuspendedAt: DateTime.tryParse(fields['adminSuspendedAt'] as String? ?? '')?.toUtc(),
        adminSuspendedBy: fields['adminSuspendedBy'] as String?,
      );
    } else {
      cache.shops[shopId] = old.copyWith(clearAdminSuspension: true);
    }
  }
  // --- end admin shop management ---

  @override
  Future<void> addService(BarbershopService service) async => cache.services[service.id] = service;

  @override
  Future<void> updateService(BarbershopService service) async {
    if (cache.services.containsKey(service.id)) cache.services[service.id] = service;
  }

  @override
  Future<void> deleteService(BarbershopService service) async => cache.services.remove(service.id);

  @override
  Future<void> addBarber(Barber barber, UserInvite? invite, {String? phone}) async {
    cache.barbers[barber.id] = barber.copyWith(clearContact: true);
    if (phone != null && phone.isNotEmpty) cache.barberPhones[barber.id] = phone;
    if (invite != null) cache.invites[invite.email] = invite;
  }

  @override
  Future<void> updateBarberProfile(Barber barber) async {
    final old = cache.barbers[barber.id];
    if (old == null) return;
    // Keep shopId and ratings; take the editable profile fields as given
    // (including clearing the optional schedule fields).
    cache.barbers[barber.id] = Barber(
      id: old.id,
      shopId: old.shopId,
      name: barber.name,
      title: barber.title,
      avatarUrl: barber.avatarUrl,
      rating: old.rating,
      reviewCount: old.reviewCount,
      ratingSum: old.ratingSum,
      isAvailable: barber.isAvailable,
      // private barber phone: the profile update never carries contact
      // fields (Firestore deletes legacy ones).
      specialties: barber.specialties,
      workingDays: barber.workingDays,
      startHour: barber.startHour,
      endHour: barber.endHour,
      commissionPercent: barber.commissionPercent, // barber commission
    );
  }

  @override
  Future<void> setBarberAvailability(Barber barber, bool isAvailable) async {
    final old = cache.barbers[barber.id];
    if (old != null) cache.barbers[barber.id] = old.copyWith(isAvailable: isAvailable);
  }

  @override
  Future<void> deleteBarber(Barber barber, UserInvite? pendingInvite) async {
    cache.barbers.remove(barber.id);
    cache.barberPhones.remove(barber.id);
    // Deleting the profile revokes the linked account (as the rules do).
    cache.users.removeWhere((_, u) => u.barberId == barber.id);
    if (pendingInvite != null) cache.invites.remove(pendingInvite.email);
  }

  // --- private barber phone ---
  @override
  Future<void> setBarberPhone(String shopId, String barberId, String? phone) async {
    if (phone == null || phone.isEmpty) {
      cache.barberPhones.remove(barberId);
    } else {
      cache.barberPhones[barberId] = phone;
    }
  }

  @override
  Future<void> migrateBarberContact(Barber barber, {String? phone}) async {
    if (phone != null && phone.isNotEmpty) cache.barberPhones[barber.id] = phone;
    final old = cache.barbers[barber.id];
    if (old != null) cache.barbers[barber.id] = old.copyWith(clearContact: true);
  }

  @override
  Future<void> shareBarberPhone(Booking booking, String phone) async {
    final old = cache.bookings[booking.id];
    if (old != null) cache.bookings[booking.id] = old.copyWith(barberPhone: phone);
  }
  // --- end private barber phone ---

  /// Same rule as the Firestore transaction: no two non-cancelled bookings
  /// of a barber may share a 15-minute block, and no booking may take a
  /// block of the barber's time off.
  @override
  Future<void> createBooking(Booking booking) async {
    if (_blocksTaken(booking)) throw const SlotTakenException();
    final rest = Map.of(cache.bookings);
    cache.bookings
      ..clear()
      ..[booking.id] = booking
      ..addAll(rest);
  }

  @override
  Future<void> updateBookingStatus(Booking booking, BookingStatus status,
      {String? cancelledBy, String? cancelReasonNote, RefundContext? refund}) async {
    final old = cache.bookings[booking.id];
    if (old == null) return;
    final cancelled = status == BookingStatus.cancelled;
    cache.bookings[booking.id] = old.copyWith(
      status: status,
      cancelledBy: cancelled ? cancelledBy : null,
      cancelReasonNote: cancelled ? cancelReasonNote : null,
      refund: cancelled && old.status != BookingStatus.cancelled ? _refundFlag(old, refund) : null, // refunds
    );
  }

  // --- refunds ---

  /// Customer notices of refunds written by this store, oldest first
  /// (tests; the local inboxes derive the same entries from the bookings).
  final List<RefundNotice> sentRefundNotices = [];

  /// The refund flag for cancelling [old] (as stored now) in [ctx], and its
  /// notice recorded like Firestore's same-write create.
  BookingRefund? _refundFlag(Booking old, RefundContext? ctx) {
    if (ctx == null) return null;
    final flag = refundFlagFor(old, ctx);
    if (flag != null && old.customerId.isNotEmpty) {
      sentRefundNotices.add(refundDueNotice(old, flag, language: ctx.languageOf?.call(old.customerId)));
    }
    return flag;
  }

  @override
  Stream<List<Booking>> watchRefundsDue({String? shopId}) =>
      Stream.value(refundsDue(cache.bookings.values, shopId: shopId));

  @override
  Future<void> flagRefund(Booking booking, BookingRefund flag, RefundNotice? notice) async {
    final old = cache.bookings[booking.id];
    if (old == null || old.refund != null) throw AppStateException(AppErrorCode.bookingNotChangeable);
    cache.bookings[booking.id] = old.copyWith(refund: flag);
    if (notice != null) sentRefundNotices.add(notice);
  }

  @override
  Future<void> markRefunded(Booking booking, Map<String, dynamic> fields, RefundNotice? notice) async {
    final old = cache.bookings[booking.id];
    final due = old?.refund;
    if (old == null || due == null || !due.isDue) throw AppStateException(AppErrorCode.bookingNotChangeable);
    cache.bookings[booking.id] = old.copyWith(
      paymentStatus: PaymentStatus.refunded,
      refund: due.markedRefunded(
        at: DateTime.parse(fields['refundedAt'] as String),
        by: fields['refundedBy'] as String,
        method: RefundMethod.fromString(fields['refundMethod'] as String?) ?? RefundMethod.other,
        reference: fields['refundReference'] as String?,
      ),
    );
    if (notice != null) sentRefundNotices.add(notice);
  }
  // --- end refunds ---

  /// Booking locks are not stored locally (every booking is in the cache);
  /// this emits the time-off locks of the day, again after each change.
  @override
  Stream<List<SlotLock>> watchSlotLocks(String shopId, String barberId, DateTime addisDate) {
    final (dayStart, dayEnd) = addisDayBoundsUtc(addisDate);
    return _watchTimeOffState(() => [
          for (final t in timeOff.values)
            if (t.shopId == shopId && t.barberId == barberId)
              for (final lock in slotLocksForTimeOff(t))
                if (!lock.startAt.isBefore(dayStart) && lock.startAt.isBefore(dayEnd)) lock,
        ]);
  }

  @override
  Future<void> updateUserProfile(String uid, {String? name, String? language, String? phone}) async {
    final old = cache.users[uid];
    if (old != null) cache.users[uid] = old.copyWith(name: name, language: language, phone: phone);
  }

  @override
  Future<void> rescheduleBooking(Booking original, Booking updated) async {
    final current = cache.bookings[original.id];
    if (current == null) throw AppStateException(AppErrorCode.bookingNotChangeable);
    if (_blocksTaken(updated)) throw const SlotTakenException();
    cache.bookings[original.id] = current.copyWith(
      startAt: updated.startAt,
      endAt: updated.endAt,
      date: updated.date,
      timeSlot: updated.timeSlot,
      rescheduleCount: updated.rescheduleCount,
      rescheduledAt: updated.rescheduledAt,
    );
  }

  @override
  Future<void> updateShopPolicy(String shopId,
      {required int cancellationCutoffHours, required int maxReschedules, bool? requireBarberAcceptance}) async {
    final old = cache.shops[shopId];
    if (old == null) return;
    cache.shops[shopId] = old.copyWith(
      cancellationCutoffHours: cancellationCutoffHours,
      maxReschedules: maxReschedules,
      requireBarberAcceptance: requireBarberAcceptance,
    );
  }

  @override
  Stream<List<TimeOff>> watchTimeOff(String shopId, String barberId) => _watchTimeOffState(() =>
      timeOff.values.where((t) => t.shopId == shopId && t.barberId == barberId).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt)));

  @override
  Future<void> addTimeOff(TimeOff entry) async {
    if (timeOffConflicts(entry, bookings: cache.bookings.values, otherTimeOff: timeOff.values)) {
      throw AppStateException(AppErrorCode.timeOffConflict);
    }
    timeOff[entry.id] = entry;
    _timeOffChanges.add(null);
  }

  @override
  Future<void> deleteTimeOff(TimeOff entry) async {
    if (timeOff.remove(entry.id) != null) _timeOffChanges.add(null);
  }

  // --- vacation ---

  @override
  Future<List<SlotLock>> slotLocksBetween(String shopId, String barberId, DateTime startUtc, DateTime endUtc) async => [
        for (final t in timeOff.values)
          if (t.shopId == shopId && t.barberId == barberId)
            for (final lock in slotLocksForTimeOff(t))
              if (!lock.startAt.isBefore(startUtc.toUtc()) && lock.startAt.isBefore(endUtc.toUtc())) lock,
      ];

  /// Vacation cancel notices "written" by this store (tests).
  final List<(String, AppNotification)> sentVacationNotices = [];

  @override
  Future<void> writeVacationCancelNotice(String recipientUid, AppNotification notice) async {
    sentVacationNotices.add((recipientUid, notice));
  }

  // --- barber acceptance ---

  @override
  Future<void> acceptBookingRequest(Booking booking, {required DateTime acceptedAt}) async {
    final current = cache.bookings[booking.id];
    if (current == null || current.status != BookingStatus.pending) {
      throw AppStateException(AppErrorCode.bookingNotChangeable);
    }
    cache.bookings[booking.id] = current.copyWith(status: BookingStatus.confirmed, acceptedAt: acceptedAt.toUtc());
  }

  /// The local database has no lock documents: a cancelled booking simply
  /// stops occupying its blocks.
  @override
  Future<void> declineBookingRequest(Booking booking, {String? reason, RefundContext? refund}) async {
    final current = cache.bookings[booking.id];
    if (current == null || current.status != BookingStatus.pending) {
      throw AppStateException(AppErrorCode.bookingNotChangeable);
    }
    cache.bookings[booking.id] = current.copyWith(
      status: BookingStatus.cancelled,
      cancelledBy: 'barber',
      declineReason: reason,
      refund: _refundFlag(current, refund), // refunds
    );
  }
  // --- end barber acceptance ---

  // --- early finish ---

  @override
  Future<void> completeBooking(Booking booking, {required DateTime completedAt}) async {
    final old = cache.bookings[booking.id];
    if (old == null) return;
    cache.bookings[booking.id] = old.copyWith(status: BookingStatus.completed, completedAt: completedAt.toUtc());
  }

  /// Local inboxes live in LocalNotificationInbox, which writes the same
  /// entries when it sees the booking completed early.
  @override
  Future<void> writeEarlyFinishNotices(List<EarlyFinishNotice> notices) async {}
  // --- end early finish ---
}
