import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/service_model.dart';
import 'dart:async';

import '../models/app_exception.dart';
import 'availability_service.dart';
import 'data_cache.dart';
import 'time_off_service.dart';

export 'availability_service.dart' show SlotLock, SlotTakenException;
export 'time_off_service.dart' show TimeOff;

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

  /// Owner/admin: profile fields only ([Barbershop.toProfileMap]).
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

  /// Admin: deletes the shop, its services, barbers and pending invites.
  /// Bookings are kept for history.
  Future<void> deleteShop(String shopId);

  Future<void> addService(BarbershopService service);
  Future<void> updateService(BarbershopService service);
  Future<void> deleteService(BarbershopService service);

  /// Adds a barber profile and, optionally, their sign-in invite.
  Future<void> addBarber(Barber barber, UserInvite? invite);

  /// Owner/admin: profile fields only ([Barber.toProfileMap]).
  Future<void> updateBarberProfile(Barber barber);
  Future<void> setBarberAvailability(Barber barber, bool isAvailable);
  Future<void> deleteBarber(Barber barber, UserInvite? pendingInvite);

  /// Stores a fully built booking, atomically with its slot locks (one per
  /// 15-minute block it covers, see availability_service.dart).
  ///
  /// Throws [SlotTakenException] if any of those blocks is already held by
  /// another booking for the same barber.
  Future<void> createBooking(Booking booking);

  /// Changes a booking's status. Cancelling also releases its slot locks in
  /// the same write and records [cancelledBy] (the caller's uid) so the
  /// notification backend can say who cancelled.
  Future<void> updateBookingStatus(Booking booking, BookingStatus status, {String? cancelledBy});

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

  /// Owner: writes only `cancellationCutoffHours` and `maxReschedules`.
  Future<void> updateShopPolicy(String shopId, {required int cancellationCutoffHours, required int maxReschedules});

  /// Live time-off ranges of one barber (soonest first).
  Stream<List<TimeOff>> watchTimeOff(String shopId, String barberId);

  /// Owner or that barber: creates the time-off doc and its slot locks in
  /// one batch. Throws [AppStateException] ([AppErrorCode.timeOffConflict])
  /// if any block is already held.
  Future<void> addTimeOff(TimeOff timeOff);

  /// Deletes the time-off doc and its slot locks in one batch.
  Future<void> deleteTimeOff(TimeOff timeOff);
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
      cache.barbers[b.id] = b;
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
    cache.shops[shopId] = old.copyWith(subscriptionPlan: plan, subscriptionStatus: status, subscriptionEndsAt: endsAt);
  }

  @override
  Future<void> deleteShop(String shopId) async {
    cache.shops.remove(shopId);
    cache.services.removeWhere((_, s) => s.shopId == shopId);
    cache.barbers.removeWhere((_, b) => b.shopId == shopId);
    cache.invites.removeWhere((_, i) => i.shopId == shopId);
    // Demo only: the local database also forgets the shop's bookings and
    // staff accounts. Firestore keeps bookings for history.
    cache.bookings.removeWhere((_, b) => b.shopId == shopId);
    cache.users.removeWhere((_, u) => u.shopId == shopId);
  }

  @override
  Future<void> addService(BarbershopService service) async => cache.services[service.id] = service;

  @override
  Future<void> updateService(BarbershopService service) async {
    if (cache.services.containsKey(service.id)) cache.services[service.id] = service;
  }

  @override
  Future<void> deleteService(BarbershopService service) async => cache.services.remove(service.id);

  @override
  Future<void> addBarber(Barber barber, UserInvite? invite) async {
    cache.barbers[barber.id] = barber;
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
      isAvailable: barber.isAvailable,
      email: barber.email,
      phone: barber.phone,
      specialties: barber.specialties,
      workingDays: barber.workingDays,
      startHour: barber.startHour,
      endHour: barber.endHour,
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
    // Deleting the profile revokes the linked account (as the rules do).
    cache.users.removeWhere((_, u) => u.barberId == barber.id);
    if (pendingInvite != null) cache.invites.remove(pendingInvite.email);
  }

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
  Future<void> updateBookingStatus(Booking booking, BookingStatus status, {String? cancelledBy}) async {
    final old = cache.bookings[booking.id];
    if (old != null) cache.bookings[booking.id] = old.copyWith(status: status);
  }

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
  Future<void> updateShopPolicy(String shopId, {required int cancellationCutoffHours, required int maxReschedules}) async {
    final old = cache.shops[shopId];
    if (old == null) return;
    cache.shops[shopId] = old.copyWith(cancellationCutoffHours: cancellationCutoffHours, maxReschedules: maxReschedules);
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
}
