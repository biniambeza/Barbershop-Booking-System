class BarbershopService {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;

  BarbershopService({
    required this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.price,
    this.durationMinutes = 30,
  });

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'description': description,
      'price': price,
      'durationMinutes': durationMinutes,
    };
  }

  BarbershopService copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    double? price,
    int? durationMinutes,
  }) {
    return BarbershopService(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  factory BarbershopService.fromMap(Map<String, dynamic> map, String id) {
    return BarbershopService(
      id: id,
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
    );
  }
}
