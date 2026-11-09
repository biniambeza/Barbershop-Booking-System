class Barber {
  final String id;
  final String shopId;
  final String name;
  final String title;
  final String? avatarUrl;
  final double rating;
  final int reviewCount;
  final bool isAvailable;

  Barber({
    required this.id,
    required this.shopId,
    required this.name,
    required this.title,
    this.avatarUrl,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.isAvailable = true,
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
    };
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
    );
  }
}
