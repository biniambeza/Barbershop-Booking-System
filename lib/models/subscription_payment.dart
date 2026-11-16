// A shop owner's subscription payment by bank / mobile-money transfer:
// `subscriptionPayments/{method}_{normalizedTransactionId}`. The owner
// creates it 'pending' with the transaction number, amount and a receipt
// photo; it is then verified automatically (payments Cloud Function, Blaze
// plan) or by an admin, which extends the shop's subscription.

import '../services/subscription_pricing.dart';

export '../services/subscription_pricing.dart' show ReceiptMethod;

enum ReceiptStatus {
  pending('pending'),
  verified('verified'),
  rejected('rejected'),
  needsReview('needs_review');

  const ReceiptStatus(this.value);

  /// Firestore value.
  final String value;

  static ReceiptStatus fromValue(Object? value) {
    for (final s in values) {
      if (s.value == value) return s;
    }
    return ReceiptStatus.pending;
  }

  /// Waiting for a decision (an admin may approve or reject).
  bool get isOpen => this == ReceiptStatus.pending || this == ReceiptStatus.needsReview;
}

/// Who verified a payment when it was not an admin.
const String kReceiptVerifiedByAuto = 'auto';

/// Machine reasons (decisionReason) written by the app or the Cloud
/// Function; anything else is an admin's free text.
abstract final class ReceiptReasons {
  static const amountTooLow = 'amount_too_low';
  static const duplicate = 'duplicate';
  static const receiptNotFound = 'receipt_not_found';
  static const notCompleted = 'not_completed';
  static const receiverMismatch = 'receiver_mismatch';
  static const amountMismatch = 'amount_mismatch';
  static const tooOld = 'too_old';
  static const fetchFailed = 'fetch_failed';
  static const unsupportedMethod = 'unsupported_method';
}

/// Largest stored receipt photo: base64 of a JPEG of at most ~250 KB.
/// (Firestore documents are limited to 1 MiB.)
const int kMaxReceiptImageChars = 350000;

/// Longest admin reject reason.
const int kMaxReceiptReasonLength = 300;

class SubscriptionPayment {
  const SubscriptionPayment({
    required this.id,
    required this.shopId,
    required this.ownerId,
    required this.method,
    required this.transactionId,
    required this.amount,
    this.receiptImage,
    this.imagePath,
    this.payerAccountSuffix,
    this.status = ReceiptStatus.pending,
    this.durationDays = 0,
    this.verifiedAmount,
    this.verifiedBy,
    this.decisionReason,
    required this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String shopId;

  /// The owner's uid.
  final String ownerId;
  final ReceiptMethod method;

  /// Normalized (trimmed, uppercase, no spaces).
  final String transactionId;

  /// ETB the owner says they paid.
  final double amount;

  /// JPEG, base64 (no data: prefix), <= [kMaxReceiptImageChars] characters.
  final String? receiptImage;

  /// Firebase Storage object of the photo, `receipts/{shopId}/{id}.jpg`
  /// (Blaze plan, admin switch `storageReceipts`); then [receiptImage] is
  /// null. See receipt_photo_storage.dart.
  final String? imagePath;

  /// CBE: last digits of the payer's account (some receipt links need it).
  final String? payerAccountSuffix;
  final ReceiptStatus status;

  /// Days granted (0 until verified).
  final int durationDays;
  final double? verifiedAmount;

  /// 'auto' or the admin's uid.
  final String? verifiedBy;
  final String? decisionReason;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// A photo is attached, inline or in Storage.
  bool get hasImage => hasInlineImage || hasStoredImage;

  /// The photo is stored inline (base64 in the document; free plan).
  bool get hasInlineImage => receiptImage != null && receiptImage!.isNotEmpty;

  /// The photo is in Firebase Storage at [imagePath].
  bool get hasStoredImage => imagePath != null && imagePath!.isNotEmpty;
  bool get isAutoVerified => verifiedBy == kReceiptVerifiedByAuto;

  /// Newest first.
  static int newestFirst(SubscriptionPayment a, SubscriptionPayment b) => b.createdAt.compareTo(a.createdAt);

  /// Admin list: open ones first (oldest first, so nobody waits longest),
  /// then decided ones, newest decision first.
  static int adminOrder(SubscriptionPayment a, SubscriptionPayment b) {
    if (a.status.isOpen != b.status.isOpen) return a.status.isOpen ? -1 : 1;
    if (a.status.isOpen) return a.createdAt.compareTo(b.createdAt);
    return (b.decidedAt ?? b.createdAt).compareTo(a.decidedAt ?? a.createdAt);
  }

  SubscriptionPayment copyWith({
    ReceiptStatus? status,
    int? durationDays,
    double? verifiedAmount,
    String? verifiedBy,
    String? decisionReason,
    DateTime? decidedAt,
  }) =>
      SubscriptionPayment(
        id: id,
        shopId: shopId,
        ownerId: ownerId,
        method: method,
        transactionId: transactionId,
        amount: amount,
        receiptImage: receiptImage,
        imagePath: imagePath,
        payerAccountSuffix: payerAccountSuffix,
        status: status ?? this.status,
        durationDays: durationDays ?? this.durationDays,
        verifiedAmount: verifiedAmount ?? this.verifiedAmount,
        verifiedBy: verifiedBy ?? this.verifiedBy,
        decisionReason: decisionReason ?? this.decisionReason,
        createdAt: createdAt,
        decidedAt: decidedAt ?? this.decidedAt,
      );

  /// This receipt with its photo in Firebase Storage at [path] instead of
  /// inline (no `receiptImage` bytes).
  SubscriptionPayment withStoredImage(String path) => SubscriptionPayment(
        id: id,
        shopId: shopId,
        ownerId: ownerId,
        method: method,
        transactionId: transactionId,
        amount: amount,
        imagePath: path,
        payerAccountSuffix: payerAccountSuffix,
        status: status,
        durationDays: durationDays,
        verifiedAmount: verifiedAmount,
        verifiedBy: verifiedBy,
        decisionReason: decisionReason,
        createdAt: createdAt,
        decidedAt: decidedAt,
      );

  /// The owner's create (exact keys: shopId, ownerId, method,
  /// transactionId, amount, status 'pending', durationDays 0, createdAt,
  /// and optionally receiptImage OR imagePath, payerAccountSuffix).
  Map<String, dynamic> toCreateMap() => {
        'shopId': shopId,
        'ownerId': ownerId,
        'method': method.name,
        'transactionId': transactionId,
        'amount': amount,
        'status': ReceiptStatus.pending.value,
        'durationDays': 0,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (hasInlineImage) 'receiptImage': receiptImage,
        if (hasStoredImage) 'imagePath': imagePath,
        if (payerAccountSuffix != null) 'payerAccountSuffix': payerAccountSuffix,
      };

  /// Every field (seed / tests).
  Map<String, dynamic> toMap() => {
        ...toCreateMap(),
        'status': status.value,
        'durationDays': durationDays,
        if (verifiedAmount != null) 'verifiedAmount': verifiedAmount,
        if (verifiedBy != null) 'verifiedBy': verifiedBy,
        if (decisionReason != null) 'decisionReason': decisionReason,
        if (decidedAt != null) 'decidedAt': decidedAt!.toUtc().toIso8601String(),
      };

  factory SubscriptionPayment.fromMap(Map<String, dynamic> map, String id) {
    final image = map['receiptImage'];
    final path = map['imagePath'];
    return SubscriptionPayment(
      id: id,
      shopId: (map['shopId'] as String?) ?? '',
      ownerId: (map['ownerId'] as String?) ?? '',
      method: ReceiptMethod.fromName(map['method']),
      transactionId: (map['transactionId'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      receiptImage: image is String && image.isNotEmpty ? image : null,
      imagePath: path is String && path.isNotEmpty ? path : null,
      payerAccountSuffix: map['payerAccountSuffix'] as String?,
      status: ReceiptStatus.fromValue(map['status']),
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 0,
      verifiedAmount: (map['verifiedAmount'] as num?)?.toDouble(),
      verifiedBy: map['verifiedBy'] as String?,
      decisionReason: map['decisionReason'] as String?,
      createdAt: _date(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      decidedAt: _date(map['decidedAt']),
    );
  }
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is DateTime) return value.toUtc();
  try {
    return ((value as dynamic).toDate() as DateTime).toUtc();
  } catch (_) {
    return null;
  }
}

/// Errors of the receipt flows (shown via `receiptsErrorText`).
enum ReceiptErrorCode {
  ownerOnly,
  adminOnly,
  shopNotFound,
  invalidTransactionId,
  invalidAmount,
  amountTooLow,
  duplicate,
  imageTooLarge,
  notFound,
  notOpen,
  reasonRequired,
  invalidPricing,
}

class ReceiptException implements Exception {
  ReceiptException(this.code);
  final ReceiptErrorCode code;

  @override
  String toString() => 'ReceiptException(${code.name})';
}
