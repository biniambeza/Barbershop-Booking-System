// Refunds of paid bookings that were cancelled.
//
// The refund state lives on the booking itself (`bookings/{bookingId}`),
// written in the SAME write as the cancellation by whoever cancels (works
// on the free Spark plan, where no Cloud Function runs). On Blaze the
// bookings function `flagRefundOnCancel` (functions/bookings) flags any
// paid + cancelled booking the app did not flag, and mirrors the refund
// fields onto its `payments/{paymentId}` document.
//
// Booking fields:
//   refundStatus     'due' | 'refunded'
//   refundAmount     number (ETB, 2 decimals, 0 < amount <= price)
//   refundReason     one of [RefundReasons.all]
//   refundFlaggedAt  ISO UTC
//   refundedAt       ISO UTC          (refunded only)
//   refundedBy       uid              (refunded only: the owner or an admin)
//   refundMethod     [RefundMethod]   (refunded only)
//   refundReference  1..100 chars     (refunded only, optional)

/// 'due' (flagged, money still owed) or 'refunded' (the shop or an admin
/// sent it back).
enum RefundStatus {
  due,
  refunded;

  static RefundStatus? fromString(String? value) {
    switch (value) {
      case 'due':
        return RefundStatus.due;
      case 'refunded':
        return RefundStatus.refunded;
      default:
        return null;
    }
  }
}

/// Why a refund is due (`refundReason`). Same strings as
/// functions/bookings/src/logic/refund.ts.
abstract final class RefundReasons {
  /// The customer cancelled before the shop's cancellation cutoff: full refund.
  static const customerCancelled = 'customer_cancelled';

  /// The customer cancelled after the cutoff: kLateCancelRefundPercent %
  /// (lib/services/refunds.dart).
  static const customerLateCancel = 'customer_late_cancel';

  /// The booked barber cancelled: full refund.
  static const barberCancelled = 'barber_cancelled';

  /// The shop owner cancelled: full refund.
  static const shopCancelled = 'shop_cancelled';

  /// An admin cancelled: full refund.
  static const adminCancelled = 'admin_cancelled';

  /// The barber (or owner) declined the request: full refund.
  static const requestDeclined = 'request_declined';

  /// The request expired unanswered: full refund.
  static const requestExpired = 'request_expired';

  /// The shop was deleted: full refund.
  static const shopDeleted = 'shop_deleted';

  /// Cancelled by the system (e.g. a slot conflict): full refund.
  static const systemCancelled = 'system_cancelled';

  static const all = [
    customerCancelled,
    customerLateCancel,
    barberCancelled,
    shopCancelled,
    adminCancelled,
    requestDeclined,
    requestExpired,
    shopDeleted,
    systemCancelled,
  ];
}

/// How the money went back (`refundMethod`).
enum RefundMethod {
  telebirr,
  cbe,
  bank,
  cash,
  chapa,
  other;

  static RefundMethod? fromString(String? value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}

/// Longest payment reference accepted with "Mark refunded".
const int kMaxRefundReferenceLength = 100;

/// The refund part of a booking (null on a booking that owes nothing).
class BookingRefund {
  const BookingRefund({
    required this.status,
    required this.amount,
    required this.reason,
    required this.flaggedAt,
    this.refundedAt,
    this.refundedBy,
    this.method,
    this.reference,
  });

  final RefundStatus status;

  /// ETB.
  final double amount;

  /// One of [RefundReasons.all] (unknown values are kept as-is).
  final String reason;

  /// UTC.
  final DateTime flaggedAt;

  /// UTC; refunded only.
  final DateTime? refundedAt;
  final String? refundedBy;
  final RefundMethod? method;
  final String? reference;

  bool get isDue => status == RefundStatus.due;
  bool get isRefunded => status == RefundStatus.refunded;

  /// The four fields written with the cancellation.
  Map<String, dynamic> toFlagFields() => {
        'refundStatus': RefundStatus.due.name,
        'refundAmount': amount,
        'refundReason': reason,
        'refundFlaggedAt': flaggedAt.toUtc().toIso8601String(),
      };

  BookingRefund markedRefunded({
    required DateTime at,
    required String by,
    required RefundMethod method,
    String? reference,
  }) =>
      BookingRefund(
        status: RefundStatus.refunded,
        amount: amount,
        reason: reason,
        flaggedAt: flaggedAt,
        refundedAt: at.toUtc(),
        refundedBy: by,
        method: method,
        reference: reference,
      );

  /// Null unless [map] carries a known `refundStatus`.
  static BookingRefund? fromMap(Map<String, dynamic> map) {
    final status = RefundStatus.fromString(map['refundStatus'] as String?);
    if (status == null) return null;
    return BookingRefund(
      status: status,
      amount: (map['refundAmount'] as num?)?.toDouble() ?? 0,
      reason: map['refundReason'] is String ? map['refundReason'] as String : RefundReasons.systemCancelled,
      flaggedAt: _parse(map['refundFlaggedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      refundedAt: _parse(map['refundedAt']),
      refundedBy: map['refundedBy'] is String ? map['refundedBy'] as String : null,
      method: RefundMethod.fromString(map['refundMethod'] as String?),
      reference: map['refundReference'] is String ? map['refundReference'] as String : null,
    );
  }
}

DateTime? _parse(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is DateTime) return value.toUtc();
  try {
    return ((value as dynamic).toDate() as DateTime).toUtc();
  } catch (_) {
    return null;
  }
}
