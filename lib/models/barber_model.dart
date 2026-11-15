class Barber {
  final String id;
  final String shopId;
  final String name;
  final String title;
  final String? avatarUrl;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final String? email;
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

  Barber({
    required this.id,
    required this.shopId,
    required this.name,
    required this.title,
    this.avatarUrl,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.isAvailable = true,
    this.email,
    this.phone,
    this.specialties = const ['Skin Fade', 'Beard Trim', 'Scissor Cut'],
    this.workingDays,
    this.startHour,
    this.endHour,
    this.commissionPercent, // barber commission
  });

  /// Full document, used when the profile is created.
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'title': title,
      'avatarUrl': avatarUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'isAvailable': isAvailable,
      'email': email,
      'phone': phone,
      'specialties': specialties,
      if (workingDays != null) 'workingDays': workingDays,
      if (startHour != null) 'startHour': startHour,
      if (endHour != null) 'endHour': endHour,
      if (commissionPercent != null) 'commissionPercent': commissionPercent, // barber commission
    };
  }

  /// The fields an owner may edit (never rating/reviewCount/shopId).
  /// Null schedule fields are returned as null; the data layer turns them
  /// into field deletes.
  Map<String, dynamic> toProfileMap() {
    return {
      'name': name,
      'title': title,
      'avatarUrl': avatarUrl,
      'isAvailable': isAvailable,
      'email': email,
      'phone': phone,
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
    bool? isAvailable,
    String? email,
    String? phone,
    List<String>? specialties,
    List<int>? workingDays,
    int? startHour,
    int? endHour,
    bool clearSchedule = false,
    int? commissionPercent, // barber commission
  }) {
    return Barber(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isAvailable: isAvailable ?? this.isAvailable,
      email: email ?? this.email,
      phone: phone ?? this.phone,
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
      isAvailable: map['isAvailable'] ?? true,
      email: map['email'],
      phone: map['phone'],
      specialties: (map['specialties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Skin Fade', 'Beard Trim'],
      workingDays: (map['workingDays'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
      startHour: (map['startHour'] as num?)?.toInt(),
      endHour: (map['endHour'] as num?)?.toInt(),
      commissionPercent: (map['commissionPercent'] as num?)?.toInt(), // barber commission
    );
  }
}
