import 'package:latlong2/latlong.dart';

class Barbershop {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String city;
  final String phone;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int openingHour; // e.g. 9 for 09:00
  final int closingHour; // e.g. 20 for 20:00
  final List<int> workingDays; // 1 = Mon ... 7 = Sun
  final bool isVerified;
  final double latitude;
  final double longitude;

  Barbershop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.phone,
    required this.imageUrl,
    this.rating = 4.8,
    this.reviewCount = 0,
    this.openingHour = 9,
    this.closingHour = 20,
    this.workingDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isVerified = false,
    this.latitude = 40.7527,
    this.longitude = -73.9772,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  double distanceInKmFrom(LatLng userLocation) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, userLocation, coordinates);
  }

  String formattedDistanceFrom(LatLng userLocation) {
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, userLocation, coordinates);
    if (km < 1.0) {
      final meters = distance.as(LengthUnit.Meter, userLocation, coordinates).round();
      return '${meters}m away';
    }
    return '${km.toStringAsFixed(1)} km away';
  }

  bool isOpenNow({DateTime? now}) {
    final current = now ?? DateTime.now();
    if (!workingDays.contains(current.weekday)) return false;
    final hour = current.hour;
    return hour >= openingHour && hour < closingHour;
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'phone': phone,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'openingHour': openingHour,
      'closingHour': closingHour,
      'workingDays': workingDays,
      'isVerified': isVerified,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Barbershop copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? address,
    String? city,
    String? phone,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    int? openingHour,
    int? closingHour,
    List<int>? workingDays,
    bool? isVerified,
    double? latitude,
    double? longitude,
  }) {
    return Barbershop(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      openingHour: openingHour ?? this.openingHour,
      closingHour: closingHour ?? this.closingHour,
      workingDays: workingDays ?? this.workingDays,
      isVerified: isVerified ?? this.isVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
      phone: map['phone'] ?? '',
      imageUrl: map['imageUrl'] ?? 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      openingHour: (map['openingHour'] as num?)?.toInt() ?? 9,
      closingHour: (map['closingHour'] as num?)?.toInt() ?? 20,
      workingDays: List<int>.from(map['workingDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
      isVerified: map['isVerified'] ?? false,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 40.7527,
      longitude: (map['longitude'] as num?)?.toDouble() ?? -73.9772,
    );
  }
}
