import '../services/subscription_state.dart'; // subscription expiry (client-side)
import '../services/shop_maps.dart' show isValidShopCoordinate; // shop location (maps)

/// Subscription state of a shop on the platform. Written by the admin or
/// Cloud Functions (payments); the owner app only records a lapsed period
/// (downgrade to past_due / suspended, see services/subscription_state.dart).
enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  suspended;

  /// Firestore value: 'trialing' | 'active' | 'past_due' | 'suspended'.
  String get value => this == SubscriptionStatus.pastDue ? 'past_due' : name;

  static SubscriptionStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return SubscriptionStatus.active;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'suspended':
        return SubscriptionStatus.suspended;
      default:
        return SubscriptionStatus.trialing;
    }
  }

  /// Firestore values of the statuses customers can see and book.
  static const List<String> customerVisibleValues = ['trialing', 'active', 'past_due'];
}

/// Defaults and limits of the shop booking policy (owner-editable; the
/// rules enforce the same ranges).
const int kDefaultCancellationCutoffHours = 2;
const int kMaxCancellationCutoffHours = 72;
const int kDefaultMaxReschedules = 2;
const int kMaxMaxReschedules = 5;

class Barbershop {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String city;

  /// Addis Ababa sub-city, e.g. 'Bole', 'Kirkos', 'Arada', 'Yeka'.
  final String subCity;

  /// Optional well-known landmark, e.g. 'Near Edna Mall'.
  final String? landmark;

  // --- shop location (maps) ---
  /// Optional map pin (WGS84 degrees), set by the owner or admin. Stored as
  /// two numbers `latitude` / `longitude`, always both or neither.
  final double? latitude;
  final double? longitude;
  // --- end shop location ---
  final String phone;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int openingHour; // e.g. 9 for 09:00, Addis local time
  final int closingHour; // e.g. 20 for 20:00, Addis local time
  final List<int> workingDays; // 1 = Mon ... 7 = Sun
  final bool isVerified;

  /// Plan id in `plans/{planId}`: 'trial' | 'basic' | 'pro'.
  final String subscriptionPlan;
  final SubscriptionStatus subscriptionStatus;

  /// End of the current trial / paid period (UTC).
  final DateTime? subscriptionEndsAt;

  /// Customers cannot cancel or reschedule within this many hours of the
  /// appointment start (0..72).
  final int cancellationCutoffHours;

  /// How many times a customer may move one booking (0..5).
  final int maxReschedules;

  // --- barber acceptance ---
  /// New customer bookings start 'pending' until the barber accepts them
  /// (owner-editable with the booking policy; absent = false).
  final bool requireBarberAcceptance;

  // --- admin shop management (suspension) ---
  /// Set by the platform admin (separate from [subscriptionStatus]). A
  /// suspended shop is hidden from customers and takes no new bookings.
  final bool adminSuspended;

  /// Why the admin suspended the shop (1..300 characters), shown to the owner.
  final String? adminSuspendedReason;

  /// When the admin suspended the shop (UTC).
  final DateTime? adminSuspendedAt;

  /// Uid of the admin who suspended the shop.
  final String? adminSuspendedBy;
  // --- end admin shop management ---

  Barbershop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.phone,
    required this.imageUrl,
    this.subCity = '',
    this.landmark,
    this.latitude,
    this.longitude,
    this.rating = 4.8,
    this.reviewCount = 0,
    this.openingHour = 9,
    this.closingHour = 20,
    this.workingDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isVerified = false,
    this.subscriptionPlan = 'trial',
    this.subscriptionStatus = SubscriptionStatus.trialing,
    this.subscriptionEndsAt,
    this.cancellationCutoffHours = kDefaultCancellationCutoffHours,
    this.maxReschedules = kDefaultMaxReschedules,
    this.requireBarberAcceptance = false,
    // admin shop management (suspension)
    this.adminSuspended = false,
    this.adminSuspendedReason,
    this.adminSuspendedAt,
    this.adminSuspendedBy,
  });

  /// True when the shop has a valid map pin (see services/shop_maps.dart).
  bool get hasLocation => isValidShopCoordinate(latitude, longitude);

  String get fullAddress {
    final parts = [address, if (subCity.isNotEmpty) subCity, city].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  /// Suspended shops are hidden from customers and cannot take bookings.
  // --- subscription expiry (client-side) ---
  // The *effective* status: a lapsed trial/paid period counts as suspended
  // from 7 days after subscriptionEndsAt even while the stored status is
  // stale (no Cloud Functions on the free plan). See
  // services/subscription_state.dart; [subscriptionClock] is the app clock.
  bool get isSuspended => effectiveSubscriptionStatus(this, subscriptionClock()) == SubscriptionStatus.suspended;
  // --- end subscription expiry ---

  // --- admin shop management ---
  /// Not available to customers: suspended by the admin or for an unpaid
  /// subscription. Hidden from customer lists, search and favourites; the
  /// shop page shows "temporarily unavailable" and takes no new bookings.
  bool get isBlocked => adminSuspended || isSuspended;

  /// The suspension fields of an admin suspend (or, with [suspended] false,
  /// a reactivate: the other three are null, i.e. deleted in an update).
  static Map<String, dynamic> adminSuspensionFields({
    required bool suspended,
    String? reason,
    DateTime? at,
    String? by,
  }) =>
      {
        'adminSuspended': suspended,
        'adminSuspendedReason': suspended ? reason : null,
        'adminSuspendedAt': suspended ? at?.toUtc().toIso8601String() : null,
        'adminSuspendedBy': suspended ? by : null,
      };

  /// Opening-hours fields of the shop document. Only the shop owner sets
  /// them (the owner's profile update); the admin edit never writes them.
  static const List<String> ownerOnlyHoursFields = ['openingHour', 'closingHour', 'workingDays'];

  /// The fields the admin edit screen writes in one update: the profile
  /// without the opening hours ([ownerOnlyHoursFields] are set only by the
  /// shop owner), plus verification and the subscription override. A null
  /// `subscriptionEndsAt` (or landmark) means "delete the field".
  Map<String, dynamic> toAdminEditMap() => {
        ...(toProfileMap()..removeWhere((key, _) => ownerOnlyHoursFields.contains(key))),
        'isVerified': isVerified,
        'subscriptionPlan': subscriptionPlan,
        'subscriptionStatus': subscriptionStatus.value,
        'subscriptionEndsAt': subscriptionEndsAt?.toUtc().toIso8601String(),
      };
  // --- end admin shop management ---

  bool isOpenNow({DateTime? now}) {
    final current = now ?? DateTime.now();
    if (!workingDays.contains(current.weekday)) return false;
    final hour = current.hour;
    return hour >= openingHour && hour < closingHour;
  }

  /// Full document, used when the shop is created (admin / seed).
  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      ...toProfileMap(),
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionStatus': subscriptionStatus.value,
      if (subscriptionEndsAt != null) 'subscriptionEndsAt': subscriptionEndsAt!.toUtc().toIso8601String(),
      ...toPolicyMap(),
      // Barber acceptance: only written when on, so the default create
      // shape is unchanged.
      if (requireBarberAcceptance) 'requireBarberAcceptance': true,
      // admin shop management: only written when suspended (seed / tests).
      if (adminSuspended)
        ...adminSuspensionFields(
            suspended: true, reason: adminSuspendedReason, at: adminSuspendedAt, by: adminSuspendedBy),
    };
  }

  /// The booking policy fields (owner-editable, written on their own by
  /// `DataStore.updateShopPolicy`).
  Map<String, dynamic> toPolicyMap() => {
        'cancellationCutoffHours': cancellationCutoffHours,
        'maxReschedules': maxReschedules,
      };

  /// The fields a shop owner may edit. Used for profile updates so an owner's
  /// write never touches ownership, verification, ratings or subscription.
  Map<String, dynamic> toProfileMap() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'subCity': subCity,
      'landmark': landmark,
      // Map pin: null (no pin) deletes both fields in an update and is left
      // out on create.
      'latitude': hasLocation ? latitude : null,
      'longitude': hasLocation ? longitude : null,
      'phone': phone,
      'imageUrl': imageUrl,
      'openingHour': openingHour,
      'closingHour': closingHour,
      'workingDays': workingDays,
    };
  }

  Barbershop copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? address,
    String? city,
    String? subCity,
    String? landmark,
    String? phone,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    int? openingHour,
    int? closingHour,
    List<int>? workingDays,
    bool? isVerified,
    String? subscriptionPlan,
    SubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionEndsAt,
    int? cancellationCutoffHours,
    int? maxReschedules,
    bool? requireBarberAcceptance,
    bool clearLandmark = false,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    // admin shop management (suspension)
    bool? adminSuspended,
    String? adminSuspendedReason,
    DateTime? adminSuspendedAt,
    String? adminSuspendedBy,
    bool clearAdminSuspension = false,
    bool clearSubscriptionEndsAt = false,
  }) {
    return Barbershop(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      subCity: subCity ?? this.subCity,
      landmark: clearLandmark ? null : (landmark ?? this.landmark),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      openingHour: openingHour ?? this.openingHour,
      closingHour: closingHour ?? this.closingHour,
      workingDays: workingDays ?? this.workingDays,
      isVerified: isVerified ?? this.isVerified,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionEndsAt: clearSubscriptionEndsAt ? null : (subscriptionEndsAt ?? this.subscriptionEndsAt),
      cancellationCutoffHours: cancellationCutoffHours ?? this.cancellationCutoffHours,
      maxReschedules: maxReschedules ?? this.maxReschedules,
      requireBarberAcceptance: requireBarberAcceptance ?? this.requireBarberAcceptance,
      // admin shop management (suspension)
      adminSuspended: clearAdminSuspension ? false : (adminSuspended ?? this.adminSuspended),
      adminSuspendedReason: clearAdminSuspension ? null : (adminSuspendedReason ?? this.adminSuspendedReason),
      adminSuspendedAt: clearAdminSuspension ? null : (adminSuspendedAt ?? this.adminSuspendedAt),
      adminSuspendedBy: clearAdminSuspension ? null : (adminSuspendedBy ?? this.adminSuspendedBy),
    );
  }

  factory Barbershop.fromMap(Map<String, dynamic> map, String id) {
    return Barbershop(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      subCity: map['subCity'] ?? '',
      landmark: map['landmark'],
      latitude: _coordinates(map)?.$1,
      longitude: _coordinates(map)?.$2,
      phone: map['phone'] ?? '',
      imageUrl: map['imageUrl'] ?? 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      openingHour: (map['openingHour'] as num?)?.toInt() ?? 9,
      closingHour: (map['closingHour'] as num?)?.toInt() ?? 20,
      workingDays: (map['workingDays'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      isVerified: map['isVerified'] ?? false,
      subscriptionPlan: map['subscriptionPlan'] ?? 'trial',
      subscriptionStatus: SubscriptionStatus.fromString(map['subscriptionStatus']),
      subscriptionEndsAt: _parseDate(map['subscriptionEndsAt']),
      cancellationCutoffHours: _intIn(map['cancellationCutoffHours'], 0, kMaxCancellationCutoffHours) ??
          kDefaultCancellationCutoffHours,
      maxReschedules: _intIn(map['maxReschedules'], 0, kMaxMaxReschedules) ?? kDefaultMaxReschedules,
      requireBarberAcceptance: map['requireBarberAcceptance'] == true,
      // admin shop management (suspension)
      adminSuspended: map['adminSuspended'] == true,
      adminSuspendedReason: map['adminSuspendedReason'] is String ? map['adminSuspendedReason'] as String : null,
      adminSuspendedAt: _parseDate(map['adminSuspendedAt']),
      adminSuspendedBy: map['adminSuspendedBy'] is String ? map['adminSuspendedBy'] as String : null,
    );
  }
}

/// The stored map pin as (latitude, longitude), or null when either is
/// missing or out of range.
(double, double)? _coordinates(Map<String, dynamic> map) {
  final lat = map['latitude'];
  final lng = map['longitude'];
  if (lat is! num || lng is! num) return null;
  final la = lat.toDouble(), ln = lng.toDouble();
  return isValidShopCoordinate(la, ln) ? (la, ln) : null;
}

/// A whole number within [min, max], or null.
int? _intIn(dynamic value, int min, int max) {
  if (value is! num) return null;
  final v = value.toInt();
  return v < min || v > max ? null : v;
}

/// Accepts an ISO-8601 string or a Firestore Timestamp (anything with
/// `toDate()`), returning UTC.
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is DateTime) return value.toUtc();
  try {
    return (value as dynamic).toDate().toUtc() as DateTime;
  } catch (_) {
    return null;
  }
}
