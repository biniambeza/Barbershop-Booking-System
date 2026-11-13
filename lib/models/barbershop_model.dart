/// Subscription state of a shop on the platform. Written only by the admin
/// or Cloud Functions (payments), never by the shop owner.
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
    this.rating = 4.8,
    this.reviewCount = 0,
    this.openingHour = 9,
    this.closingHour = 20,
    this.workingDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isVerified = false,
    this.subscriptionPlan = 'trial',
    this.subscriptionStatus = SubscriptionStatus.trialing,
    this.subscriptionEndsAt,
  });

  String get fullAddress {
    final parts = [address, if (subCity.isNotEmpty) subCity, city].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  /// Suspended shops are hidden from customers and cannot take bookings.
  bool get isSuspended => subscriptionStatus == SubscriptionStatus.suspended;

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
    };
  }

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
  }) {
    return Barbershop(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      subCity: subCity ?? this.subCity,
      landmark: landmark ?? this.landmark,
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
      subscriptionEndsAt: subscriptionEndsAt ?? this.subscriptionEndsAt,
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
    );
  }
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
