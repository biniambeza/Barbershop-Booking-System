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
  });

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
    );
  }
}
