class Barber {
  final String id;
  final String shopId;
  final String name;
  final String title;
  final String? avatarUrl;
  /// Legacy average (seeded data, the old insights function). Read only as
  /// the fallback for [effectiveRatingSum]; averages shown in the app come
  /// from [ratingSum] / [reviewCount] (lib/services/rating_service.dart).
  final double rating;

  /// Number of reviews of this barber. The customer's app adds 1 in the
  /// same transaction that creates the review (firestore.rules checks it).
  final int reviewCount;

  /// Sum of the stars of all [reviewCount] reviews; null on legacy docs
  /// written before the client-side counters (see [effectiveRatingSum]).
  final int? ratingSum;
  final bool isAvailable;

  /// Legacy only: barber profiles are public (anyone may read them), so the
  /// app no longer writes an email here (the login email lives in the
  /// invite / users doc). Read so the owner's app can strip it
  /// ([hasLegacyContactFields]).
  final String? email;

  /// The barber's private contact number. Never written to the public
  /// barber doc ([toMap] / [toProfileMap] leave it out): it lives in
  /// `barbershops/{shopId}/barbers/{barberId}/private/contact` (readable by
  /// the shop's owner, admins and that barber) and is copied into a booking
  /// as `barberPhone` once the booking is confirmed. Set on a [Barber] only
  /// while it is being added, or when read from a legacy public doc that
  /// still has the field (the owner's app then migrates it).
  final String? phone;
  final List<String> specialties;

  /// Days this barber works (1 = Mon ... 7 = Sun). Null = the shop's days.
  final List<int>? workingDays;

  /// Personal hours (Addis local, 0-24). Null = the shop's hours.
  final int? startHour;
  final int? endHour;

  // --- barber commission ---
  /// The barber's share of each completed booking's price, 0..100. Null =
  /// not set ([effectiveCommissionPercent] then uses 50). Set by the owner.
  final int? commissionPercent;

  /// [commissionPercent], or the default 50 when it is not set.
  int get effectiveCommissionPercent => (commissionPercent ?? 50).clamp(0, 100);
  // --- end barber commission ---

  /// [ratingSum], or for legacy docs without it round(rating * reviewCount)
  /// (the same fallback firestore.rules uses for the first new review).
  int get effectiveRatingSum => ratingSum ?? (reviewCount <= 0 ? 0 : (rating * reviewCount).round());

  /// A legacy public doc that still carries `phone` or `email` (see
  /// AppRepository.migrateLegacyBarberContacts).
  bool get hasLegacyContactFields =>
      (phone != null && phone!.isNotEmpty) || (email != null && email!.isNotEmpty);

  Barber({
    required this.id,
    required this.shopId,
    required this.name,
    required this.title,
    this.avatarUrl,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.ratingSum,
    this.isAvailable = true,
    this.email,
    this.phone,
    this.specialties = const ['Skin Fade', 'Beard Trim', 'Scissor Cut'],
    this.workingDays,
    this.startHour,
    this.endHour,
    this.commissionPercent, // barber commission
  });

  /// Full public document, used when the profile is created. Contact
  /// details (phone, email) are never part of it.
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'title': title,
      'avatarUrl': avatarUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      if (ratingSum != null) 'ratingSum': ratingSum,
      'isAvailable': isAvailable,
      'specialties': specialties,
      if (workingDays != null) 'workingDays': workingDays,
      if (startHour != null) 'startHour': startHour,
      if (endHour != null) 'endHour': endHour,
      if (commissionPercent != null) 'commissionPercent': commissionPercent, // barber commission
    };
  }

  /// The fields an owner may edit (never rating/reviewCount/ratingSum/shopId,
  /// never the private phone or the email). Null schedule fields are
  /// returned as null; the data layer turns them into field deletes.
  Map<String, dynamic> toProfileMap() {
    return {
      'name': name,
      'title': title,
      'avatarUrl': avatarUrl,
      'isAvailable': isAvailable,
      'specialties': specialties,
      'workingDays': workingDays,
      'startHour': startHour,
      'endHour': endHour,
      'commissionPercent': commissionPercent, // barber commission (null = field delete)
    };
  }

  Barber copyWith({
    String? id,
    String? shopId,
    String? name,
    String? title,
    String? avatarUrl,
    double? rating,
    int? reviewCount,
    int? ratingSum,
    bool? isAvailable,
    String? email,
    String? phone,
    List<String>? specialties,
    List<int>? workingDays,
    int? startHour,
    int? endHour,
    bool clearSchedule = false,
    int? commissionPercent, // barber commission
    bool clearContact = false,
  }) {
    return Barber(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      ratingSum: ratingSum ?? this.ratingSum,
      isAvailable: isAvailable ?? this.isAvailable,
      email: clearContact ? null : (email ?? this.email),
      phone: clearContact ? null : (phone ?? this.phone),
      specialties: specialties ?? this.specialties,
      workingDays: clearSchedule ? null : (workingDays ?? this.workingDays),
      startHour: clearSchedule ? null : (startHour ?? this.startHour),
      endHour: clearSchedule ? null : (endHour ?? this.endHour),
      commissionPercent: commissionPercent ?? this.commissionPercent, // barber commission
    );
  }

  factory Barber.fromMap(Map<String, dynamic> map, String id) {
    return Barber(
      id: id,
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      title: map['title'] ?? 'Barber',
      avatarUrl: map['avatarUrl'],
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      ratingSum: (map['ratingSum'] as num?)?.toInt(),
      isAvailable: map['isAvailable'] ?? true,
      email: map['email'] is String ? map['email'] as String : null,
      phone: map['phone'] is String ? map['phone'] as String : null,
      specialties: (map['specialties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Skin Fade', 'Beard Trim'],
      workingDays: (map['workingDays'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
      startHour: (map['startHour'] as num?)?.toInt(),
      endHour: (map['endHour'] as num?)?.toInt(),
      commissionPercent: (map['commissionPercent'] as num?)?.toInt(), // barber commission
    );
  }
}
