// Payments made through Chapa (telebirr, CBE Birr, cards). The documents at
// `payments/{paymentId}` are written only by the payments Cloud Functions;
// the app reads them and calls the callables in PaymentService.

enum PaymentType {
  booking,
  subscription;

  static PaymentType fromString(String? value) =>
      value == 'subscription' ? PaymentType.subscription : PaymentType.booking;
}

/// Status of one Chapa charge ('pending' | 'success' | 'failed' |
/// 'refunded'). 'refunded' is set by an admin through resolvePaymentReview
/// after refunding the money in the Chapa dashboard.
enum PaymentRecordStatus {
  pending,
  success,
  failed,
  refunded;

  static PaymentRecordStatus fromString(String? value) {
    switch (value) {
      case 'success':
        return PaymentRecordStatus.success;
      case 'failed':
        return PaymentRecordStatus.failed;
      case 'refunded':
        return PaymentRecordStatus.refunded;
      default:
        return PaymentRecordStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentRecordStatus.pending:
        return 'Processing';
      case PaymentRecordStatus.success:
        return 'Paid';
      case PaymentRecordStatus.failed:
        return 'Failed';
      case PaymentRecordStatus.refunded:
        return 'Refunded';
    }
  }
}

/// How an admin closed a payment flagged needsReview
/// (resolvePaymentReview callable).
enum PaymentReviewResolution {
  /// The admin refunded the money in the Chapa dashboard.
  refundedInChapa('refunded_in_chapa'),

  /// Nothing to do.
  noAction('no_action');

  const PaymentReviewResolution(this.value);
  final String value;

  static PaymentReviewResolution? fromString(String? value) {
    for (final r in values) {
      if (r.value == value) return r;
    }
    return null;
  }
}

/// Prefix of checkout URLs produced by the offline payment simulator.
const String kSimulatedCheckoutScheme = 'demo://chapa/checkout/';

/// A `payments/{paymentId}` document.
class PaymentRecord {
  final String id;
  final PaymentType type;
  final String? bookingId;
  final String shopId;
  final String userId;

  /// Subscription payments only: 'basic' | 'pro'.
  final String? plan;
  final double amount;
  final String currency;
  final String provider;
  final String txRef;
  final PaymentRecordStatus status;
  final String checkoutUrl;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? failureReason;

  /// Subscription payments: the new subscriptionEndsAt.
  final DateTime? periodEndsAt;
  final DateTime? refundedAt;

  /// Chapa's own reference and payment method, once verified.
  final String? chapaReference;
  final String? chapaMethod;

  /// Flagged by the functions for an admin (paid for a cancelled or missing
  /// booking, paid twice, unconfirmed refund, subscription not applied).
  final bool needsReview;

  /// Set when an admin closes the review.
  final PaymentReviewResolution? resolution;
  final String? resolutionNote;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  const PaymentRecord({
    required this.id,
    required this.type,
    this.bookingId,
    required this.shopId,
    required this.userId,
    this.plan,
    required this.amount,
    this.currency = 'ETB',
    this.provider = 'chapa',
    required this.txRef,
    required this.status,
    required this.checkoutUrl,
    required this.createdAt,
    this.verifiedAt,
    this.failureReason,
    this.periodEndsAt,
    this.refundedAt,
    this.chapaReference,
    this.chapaMethod,
    this.needsReview = false,
    this.resolution,
    this.resolutionNote,
    this.resolvedBy,
    this.resolvedAt,
  });

  bool get isRefunded => refundedAt != null || status == PaymentRecordStatus.refunded;

  PaymentRecord copyWith({
    PaymentRecordStatus? status,
    DateTime? verifiedAt,
    String? failureReason,
    DateTime? periodEndsAt,
    DateTime? refundedAt,
    bool? needsReview,
    PaymentReviewResolution? resolution,
    String? resolutionNote,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return PaymentRecord(
      id: id,
      type: type,
      bookingId: bookingId,
      shopId: shopId,
      userId: userId,
      plan: plan,
      amount: amount,
      currency: currency,
      provider: provider,
      txRef: txRef,
      status: status ?? this.status,
      checkoutUrl: checkoutUrl,
      createdAt: createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      failureReason: failureReason ?? this.failureReason,
      periodEndsAt: periodEndsAt ?? this.periodEndsAt,
      refundedAt: refundedAt ?? this.refundedAt,
      chapaReference: chapaReference,
      chapaMethod: chapaMethod,
      needsReview: needsReview ?? this.needsReview,
      resolution: resolution ?? this.resolution,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (bookingId != null) 'bookingId': bookingId,
      'shopId': shopId,
      'userId': userId,
      if (plan != null) 'plan': plan,
      'amount': amount,
      'currency': currency,
      'provider': provider,
      'txRef': txRef,
      'status': status.name,
      'checkoutUrl': checkoutUrl,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (verifiedAt != null) 'verifiedAt': verifiedAt!.toUtc().toIso8601String(),
      if (failureReason != null) 'failureReason': failureReason,
      if (periodEndsAt != null) 'periodEndsAt': periodEndsAt!.toUtc().toIso8601String(),
      if (refundedAt != null) 'refundedAt': refundedAt!.toUtc().toIso8601String(),
      if (chapaReference != null) 'chapaReference': chapaReference,
      if (chapaMethod != null) 'chapaMethod': chapaMethod,
      if (needsReview) 'needsReview': true,
      if (resolution != null) 'resolution': resolution!.value,
      if (resolutionNote != null) 'resolutionNote': resolutionNote,
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toUtc().toIso8601String(),
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map, String id) {
    return PaymentRecord(
      id: id,
      type: PaymentType.fromString(map['type'] as String?),
      bookingId: map['bookingId'] as String?,
      shopId: (map['shopId'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      plan: map['plan'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: (map['currency'] as String?) ?? 'ETB',
      provider: (map['provider'] as String?) ?? 'chapa',
      txRef: (map['txRef'] as String?) ?? '',
      status: PaymentRecordStatus.fromString(map['status'] as String?),
      checkoutUrl: (map['checkoutUrl'] as String?) ?? '',
      createdAt: parsePaymentDate(map['createdAt']) ?? DateTime.now().toUtc(),
      verifiedAt: parsePaymentDate(map['verifiedAt']),
      failureReason: map['failureReason'] as String?,
      periodEndsAt: parsePaymentDate(map['periodEndsAt']),
      refundedAt: parsePaymentDate(map['refundedAt']),
      chapaReference: map['chapaReference'] as String?,
      chapaMethod: map['chapaMethod'] as String?,
      needsReview: map['needsReview'] == true,
      resolution: PaymentReviewResolution.fromString(map['resolution'] as String?),
      resolutionNote: map['resolutionNote'] as String?,
      resolvedBy: map['resolvedBy'] as String?,
      resolvedAt: parsePaymentDate(map['resolvedAt']),
    );
  }
}

/// Response of the resolvePaymentReview callable.
class PaymentReviewResult {
  final String paymentId;
  final PaymentReviewResolution resolution;
  final PaymentRecordStatus status;

  /// The booking's paymentStatus afterwards (booking payments only).
  final String? bookingPaymentStatus;
  final DateTime? resolvedAt;

  const PaymentReviewResult({
    required this.paymentId,
    required this.resolution,
    required this.status,
    this.bookingPaymentStatus,
    this.resolvedAt,
  });

  factory PaymentReviewResult.fromMap(Map<String, dynamic> map) {
    return PaymentReviewResult(
      paymentId: (map['paymentId'] as String?) ?? '',
      resolution: PaymentReviewResolution.fromString(map['resolution'] as String?) ?? PaymentReviewResolution.noAction,
      status: PaymentRecordStatus.fromString(map['status'] as String?),
      bookingPaymentStatus: map['bookingPaymentStatus'] as String?,
      resolvedAt: parsePaymentDate(map['resolvedAt']),
    );
  }
}

/// Response of the createBookingPayment / createSubscriptionPayment callables.
class PaymentCheckout {
  final String checkoutUrl;
  final String paymentId;
  final String txRef;

  const PaymentCheckout({required this.checkoutUrl, required this.paymentId, required this.txRef});

  /// True for checkouts created by the offline simulator (demo builds,
  /// tests): there is no web page to open.
  bool get isSimulated => checkoutUrl.startsWith(kSimulatedCheckoutScheme);

  factory PaymentCheckout.fromMap(Map<String, dynamic> map) {
    return PaymentCheckout(
      checkoutUrl: (map['checkoutUrl'] as String?) ?? '',
      paymentId: (map['paymentId'] as String?) ?? '',
      txRef: (map['txRef'] as String?) ?? '',
    );
  }
}

/// Response of the verifyPayment callable.
class PaymentVerification {
  final String paymentId;
  final PaymentType type;
  final PaymentRecordStatus status;
  final String? bookingId;
  final String shopId;
  final double amount;
  final String currency;
  final String? failureReason;
  final DateTime? periodEndsAt;

  const PaymentVerification({
    required this.paymentId,
    required this.type,
    required this.status,
    this.bookingId,
    required this.shopId,
    required this.amount,
    this.currency = 'ETB',
    this.failureReason,
    this.periodEndsAt,
  });

  bool get isSuccess => status == PaymentRecordStatus.success;
  bool get isPending => status == PaymentRecordStatus.pending;

  factory PaymentVerification.fromMap(Map<String, dynamic> map) {
    return PaymentVerification(
      paymentId: (map['paymentId'] as String?) ?? '',
      type: PaymentType.fromString(map['type'] as String?),
      status: PaymentRecordStatus.fromString(map['status'] as String?),
      bookingId: map['bookingId'] as String?,
      shopId: (map['shopId'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: (map['currency'] as String?) ?? 'ETB',
      failureReason: map['failureReason'] as String?,
      periodEndsAt: parsePaymentDate(map['periodEndsAt']),
    );
  }

  factory PaymentVerification.fromRecord(PaymentRecord p) {
    return PaymentVerification(
      paymentId: p.id,
      type: p.type,
      status: p.status,
      bookingId: p.bookingId,
      shopId: p.shopId,
      amount: p.amount,
      currency: p.currency,
      failureReason: p.failureReason,
      periodEndsAt: p.periodEndsAt,
    );
  }
}

/// Response of the setShopSubscription callable.
class ShopSubscriptionUpdate {
  final String shopId;
  final String? plan;
  final String? status;
  final DateTime? endsAt;

  const ShopSubscriptionUpdate({required this.shopId, this.plan, this.status, this.endsAt});

  factory ShopSubscriptionUpdate.fromMap(Map<String, dynamic> map) {
    return ShopSubscriptionUpdate(
      shopId: (map['shopId'] as String?) ?? '',
      plan: map['subscriptionPlan'] as String?,
      status: map['subscriptionStatus'] as String?,
      endsAt: parsePaymentDate(map['subscriptionEndsAt']),
    );
  }
}

DateTime? parsePaymentDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is DateTime) return value.toUtc();
  try {
    return ((value as dynamic).toDate() as DateTime).toUtc();
  } catch (_) {
    return null;
  }
}
