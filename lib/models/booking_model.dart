enum BookingStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled;

  static BookingStatus fromString(String? status) {
    switch (status) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'inProgress':
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class Booking {
  final String id;
  final String shopId;
  final String shopName;
  final String barberId;
  final String barberName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String serviceId;
  final String serviceName;
  final double price;
  final DateTime date;
  final String timeSlot;
  final BookingStatus status;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.barberId,
    required this.barberName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.date,
    required this.timeSlot,
    this.status = BookingStatus.confirmed,
    required this.createdAt,
  });

  Booking copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? barberId,
    String? barberName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? serviceId,
    String? serviceName,
    double? price,
    DateTime? date,
    String? timeSlot,
    BookingStatus? status,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      barberId: barberId ?? this.barberId,
      barberName: barberName ?? this.barberName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      price: price ?? this.price,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'barberId': barberId,
      'barberName': barberName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'price': price,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map, String id) {
    return Booking(
      id: id,
      shopId: map['shopId'] ?? '',
      shopName: map['shopName'] ?? '',
      barberId: map['barberId'] ?? '',
      barberName: map['barberName'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null
          ? DateTime.tryParse(map['date']) ?? DateTime.now()
          : DateTime.now(),
      timeSlot: map['timeSlot'] ?? '',
      status: BookingStatus.fromString(map['status']),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
