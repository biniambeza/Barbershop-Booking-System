import '../data/addis_time.dart';

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

/// Payment state of a booking. Written only by Cloud Functions (and admin).
enum PaymentStatus {
  unpaid,
  pending,
  paid,
  refunded;

  static PaymentStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

enum PaymentMethod {
  cash,
  chapa;

  static PaymentMethod fromString(String? value) =>
      value == 'chapa' ? PaymentMethod.chapa : PaymentMethod.cash;
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
  final double price; // ETB
  /// Calendar day of the appointment (display / back-compat; see [startAt]).
  final DateTime date;

  /// Display slot such as '02:30 PM', Addis local time (display / back-compat).
  final String timeSlot;
  final BookingStatus status;
  final DateTime createdAt;

  /// The real appointment interval, UTC.
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final PaymentStatus paymentStatus;
  final PaymentMethod paymentMethod;

  /// If [startAt] is omitted it is derived from [date] + [timeSlot] (Addis
  /// local time); [endAt] defaults to [startAt] + [durationMinutes].
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
    DateTime? startAt,
    DateTime? endAt,
    this.durationMinutes = 30,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod = PaymentMethod.cash,
  })  : startAt = (startAt ?? appointmentStartUtc(date, timeSlot) ?? addisLocalToUtc(date.year, date.month, date.day)).toUtc(),
        endAt = (endAt ??
                (startAt ?? appointmentStartUtc(date, timeSlot) ?? addisLocalToUtc(date.year, date.month, date.day))
                    .add(Duration(minutes: durationMinutes)))
            .toUtc();

  /// Still to come and not cancelled/completed.
  bool get isActive => status == BookingStatus.pending || status == BookingStatus.confirmed || status == BookingStatus.inProgress;

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
    DateTime? startAt,
    DateTime? endAt,
    int? durationMinutes,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
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
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
      'createdAt': createdAt.toUtc().toIso8601String(),
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'paymentStatus': paymentStatus.name,
      'paymentMethod': paymentMethod.name,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map, String id) {
    final date = _parseDate(map['date'])?.toLocal() ?? DateTime.now();
    final duration = (map['durationMinutes'] as num?)?.toInt() ?? 30;
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
      date: date,
      timeSlot: map['timeSlot'] ?? '',
      status: BookingStatus.fromString(map['status']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      startAt: _parseDate(map['startAt']),
      endAt: _parseDate(map['endAt']),
      durationMinutes: duration,
      paymentStatus: PaymentStatus.fromString(map['paymentStatus']),
      paymentMethod: PaymentMethod.fromString(map['paymentMethod']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
