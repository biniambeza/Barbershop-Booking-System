import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/service_model.dart';
import 'availability_service.dart';
import 'data_cache.dart';

export 'availability_service.dart' show SlotLock, SlotTakenException;

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

  /// The signed-in user's own editable fields (name, language).
  Future<void> updateUserProfile(String uid, {String? name, String? language});
}

/// In-memory [DataStore] used when Firebase is not attached.
class LocalDataStore implements DataStore {
  LocalDataStore(this.cache);

  final DataCache cache;

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
    if (ownerInvite != null) cache.invites[ownerInvite.phone] = ownerInvite;
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
    if (invite != null) cache.invites[invite.phone] = invite;
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
    if (pendingInvite != null) cache.invites.remove(pendingInvite.phone);
  }

  /// Same rule as the Firestore transaction: no two non-cancelled bookings
  /// of a barber may share a 15-minute block.
  @override
  Future<void> createBooking(Booking booking) async {
    final taken = cache.bookings.values.any((b) => b.id != booking.id && occupiesSlot(b) && bookingsConflict(b, booking));
    if (taken) throw const SlotTakenException();
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

  @override
  Stream<List<SlotLock>> watchSlotLocks(String shopId, String barberId, DateTime addisDate) =>
      Stream.value(const <SlotLock>[]);

  @override
  Future<void> updateUserProfile(String uid, {String? name, String? language}) async {
    final old = cache.users[uid];
    if (old != null) cache.users[uid] = old.copyWith(name: name, language: language);
  }
}
