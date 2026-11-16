// Subscription receipts: pure pricing and transaction-number logic (no
// Flutter, no Firebase). The payments Cloud Function mirrors these rules in
// functions/payments/src/receipts/pricing.ts; keep the two in step.

/// How the shop owner paid the platform.
enum ReceiptMethod {
  telebirr,
  cbe,
  other;

  static ReceiptMethod fromName(Object? value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return ReceiptMethod.other;
  }
}

/// One subscription length on sale: [days] for [amount] ETB.
class PricingTier {
  const PricingTier({required this.days, required this.amount});

  final int days;
  final double amount;

  Map<String, dynamic> toMap() => {'days': days, 'amount': amount};

  static PricingTier? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final days = raw['days'];
    final amount = raw['amount'];
    if (days is! num || amount is! num) return null;
    if (days != days.roundToDouble() || days < 1 || days > kMaxTierDays) return null;
    if (amount <= 0 || amount > kMaxReceiptAmount) return null;
    return PricingTier(days: days.toInt(), amount: amount.toDouble());
  }

  @override
  bool operator ==(Object other) => other is PricingTier && other.days == days && other.amount == amount;

  @override
  int get hashCode => Object.hash(days, amount);

  @override
  String toString() => 'PricingTier($days days, $amount)';
}

/// Where owners send the money: a telebirr number or a CBE account, and
/// the name the receipt must show.
class PaymentReceiver {
  const PaymentReceiver({required this.account, required this.name});

  /// telebirr: '+2519XXXXXXXX'; CBE: the 13-digit account number.
  final String account;
  final String name;

  /// False while the account is still the 'XXXX' placeholder or empty.
  bool get isConfigured => account.trim().isNotEmpty && !account.toUpperCase().contains('X');

  Map<String, dynamic> toMap() => {'account': account, 'name': name};

  static PaymentReceiver fromMap(Object? raw, PaymentReceiver fallback, {String accountKey = 'account'}) {
    if (raw is! Map) return fallback;
    final account = raw[accountKey] ?? raw['account'] ?? raw['number'];
    final name = raw['name'];
    return PaymentReceiver(
      account: account is String ? account.trim() : fallback.account,
      name: name is String ? name.trim() : fallback.name,
    );
  }
}

/// Largest amount (ETB) an owner may claim on one receipt.
const double kMaxReceiptAmount = 1000000;

/// Longest tier the admin may configure (5 years).
const int kMaxTierDays = 1825;

/// At most this many tiers.
const int kMaxPricingTiers = 8;

/// Longest receiver name.
const int kMaxReceiverNameLength = 80;

/// Official receipt pages. `{id}` is the transaction number; for CBE
/// `{suffix}` is the last 8 digits of the PAYER's account (some receipt
/// links need it: https://apps.cbe.com.et:100/?id=FT24123ABC1212345678).
/// The admin can override both in `platformConfig/subscriptionPricing.receiptUrls`.
const String kTelebirrReceiptUrlTemplate = 'https://transactioninfo.ethiotelecom.et/receipt/{id}';
const String kCbeReceiptUrlTemplate = 'https://apps.cbe.com.et:100/?id={id}{suffix}';

/// `platformConfig/subscriptionPricing`: what each subscription length
/// costs and where to pay. Readable by owners and admins, written by admins.
class SubscriptionPricing {
  const SubscriptionPricing({
    this.currency = 'ETB',
    required this.tiers,
    required this.telebirr,
    required this.cbe,
    this.telebirrReceiptUrl = kTelebirrReceiptUrlTemplate,
    this.cbeReceiptUrl = kCbeReceiptUrlTemplate,
    this.updatedAt,
    this.updatedBy,
  });

  /// Used until the admin saves a config (and for unreadable documents).
  static const SubscriptionPricing defaults = SubscriptionPricing(
    tiers: [
      PricingTier(days: 30, amount: 500),
      PricingTier(days: 90, amount: 1400),
      PricingTier(days: 180, amount: 2700),
      PricingTier(days: 365, amount: 5000),
    ],
    telebirr: PaymentReceiver(account: '+2519XXXXXXXX', name: 'Crown & Blade'),
    cbe: PaymentReceiver(account: '1000XXXXXXXXX', name: 'Crown & Blade'),
  );

  final String currency;

  /// Sorted by [PricingTier.days], ascending.
  final List<PricingTier> tiers;
  final PaymentReceiver telebirr;
  final PaymentReceiver cbe;
  final String telebirrReceiptUrl;
  final String cbeReceiptUrl;
  final DateTime? updatedAt;
  final String? updatedBy;

  /// The cheapest tier's amount: less than this buys nothing.
  double get minimumAmount => tiers.isEmpty ? double.infinity : tiers.map((t) => t.amount).reduce((a, b) => a < b ? a : b);

  /// The LONGEST tier whose amount is <= [paid] (1400 -> 90 days, 2000 ->
  /// 90 days, 5000+ -> 365), or null below the cheapest tier.
  PricingTier? tierFor(double paid) => tierForAmount(tiers, paid);

  int? durationDaysFor(double paid) => tierFor(paid)?.days;

  PaymentReceiver receiverFor(ReceiptMethod method) => method == ReceiptMethod.cbe ? cbe : telebirr;

  SubscriptionPricing copyWith({
    List<PricingTier>? tiers,
    PaymentReceiver? telebirr,
    PaymentReceiver? cbe,
    DateTime? updatedAt,
    String? updatedBy,
  }) =>
      SubscriptionPricing(
        currency: currency,
        tiers: tiers ?? this.tiers,
        telebirr: telebirr ?? this.telebirr,
        cbe: cbe ?? this.cbe,
        telebirrReceiptUrl: telebirrReceiptUrl,
        cbeReceiptUrl: cbeReceiptUrl,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy ?? this.updatedBy,
      );

  /// The document the admin writes (exact keys: currency, tiers,
  /// receivers, receiptUrls, updatedAt, updatedBy).
  Map<String, dynamic> toMap() => {
        'currency': currency,
        'tiers': [for (final t in tiers) t.toMap()],
        'receivers': {
          'telebirr': {'number': telebirr.account, 'name': telebirr.name},
          'cbe': {'account': cbe.account, 'name': cbe.name},
        },
        'receiptUrls': {'telebirr': telebirrReceiptUrl, 'cbe': cbeReceiptUrl},
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (updatedBy != null) 'updatedBy': updatedBy,
      };

  /// Tolerant: invalid tiers are dropped (all invalid -> the default
  /// tiers), missing receivers fall back to the defaults.
  factory SubscriptionPricing.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    final rawTiers = map['tiers'];
    final tiers = <PricingTier>[
      if (rawTiers is List)
        for (final t in rawTiers)
          if (PricingTier.tryFromMap(t) case final PricingTier tier) tier,
    ];
    final receivers = map['receivers'] is Map ? map['receivers'] as Map : const {};
    final urls = map['receiptUrls'] is Map ? map['receiptUrls'] as Map : const {};
    String url(Object? v, String fallback) => v is String && v.startsWith('https://') && v.contains('{id}') ? v : fallback;
    final updated = map['updatedAt'];
    return SubscriptionPricing(
      currency: map['currency'] is String ? map['currency'] as String : 'ETB',
      tiers: tiers.isEmpty ? defaults.tiers : sortTiers(tiers),
      telebirr: PaymentReceiver.fromMap(receivers['telebirr'], defaults.telebirr, accountKey: 'number'),
      cbe: PaymentReceiver.fromMap(receivers['cbe'], defaults.cbe, accountKey: 'account'),
      telebirrReceiptUrl: url(urls['telebirr'], kTelebirrReceiptUrlTemplate),
      cbeReceiptUrl: url(urls['cbe'], kCbeReceiptUrlTemplate),
      updatedAt: updated is String ? DateTime.tryParse(updated)?.toUtc() : _toDate(updated),
      updatedBy: map['updatedBy'] is String ? map['updatedBy'] as String : null,
    );
  }

  /// Official receipt page for [transactionId], or null for 'other'.
  Uri? receiptUrl(ReceiptMethod method, String transactionId, {String? payerAccountSuffix}) =>
      officialReceiptUrl(method, transactionId,
          payerAccountSuffix: payerAccountSuffix,
          telebirrTemplate: telebirrReceiptUrl,
          cbeTemplate: cbeReceiptUrl);
}

DateTime? _toDate(Object? value) {
  try {
    return ((value as dynamic).toDate() as DateTime).toUtc();
  } catch (_) {
    return null;
  }
}

List<PricingTier> sortTiers(Iterable<PricingTier> tiers) => tiers.toList()..sort((a, b) => a.days.compareTo(b.days));

/// The LONGEST tier whose amount is <= [paid]; null when [paid] is below
/// every tier.
PricingTier? tierForAmount(List<PricingTier> tiers, double paid) {
  PricingTier? best;
  for (final t in tiers) {
    if (t.amount <= paid + 1e-9 && (best == null || t.days > best.days)) best = t;
  }
  return best;
}

/// Why an admin's pricing edit is invalid, or null.
enum PricingError { noTiers, tooManyTiers, invalidTier, duplicateDays, notIncreasing, receiverName }

PricingError? validatePricing(SubscriptionPricing p) {
  if (p.tiers.isEmpty) return PricingError.noTiers;
  if (p.tiers.length > kMaxPricingTiers) return PricingError.tooManyTiers;
  for (final t in p.tiers) {
    if (t.days < 1 || t.days > kMaxTierDays || t.amount <= 0 || t.amount > kMaxReceiptAmount) {
      return PricingError.invalidTier;
    }
  }
  final sorted = sortTiers(p.tiers);
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].days == sorted[i - 1].days) return PricingError.duplicateDays;
    // A longer tier must cost more, or the shorter one could never be chosen.
    if (sorted[i].amount <= sorted[i - 1].amount) return PricingError.notIncreasing;
  }
  for (final r in [p.telebirr, p.cbe]) {
    if (r.name.trim().length > kMaxReceiverNameLength || r.account.trim().length > 40) return PricingError.receiverName;
  }
  return null;
}

/// Transaction number as stored: trimmed, uppercase, no whitespace.
String normalizeTransactionId(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

final RegExp _telebirrId = RegExp(r'^[A-Z0-9]{8,12}$');
final RegExp _cbeId = RegExp(r'^FT[A-Z0-9]{8,20}$');
final RegExp _otherId = RegExp(r'^[A-Z0-9][A-Z0-9-]{3,39}$');

/// Whether a NORMALIZED transaction number has the shape of [method]'s
/// references: telebirr 8-12 letters/digits (usually 10, e.g. CHK1AB2CDE),
/// CBE 'FT' + 8-20 letters/digits (e.g. FT2412345ABC), other 4-40 letters,
/// digits or dashes.
bool isValidTransactionId(ReceiptMethod method, String normalized) {
  switch (method) {
    case ReceiptMethod.telebirr:
      return _telebirrId.hasMatch(normalized) && normalized.contains(RegExp(r'[A-Z]'));
    case ReceiptMethod.cbe:
      return _cbeId.hasMatch(normalized);
    case ReceiptMethod.other:
      return _otherId.hasMatch(normalized);
  }
}

/// `subscriptionPayments/{method}_{normalizedTransactionId}`: one document
/// per transaction platform-wide, so a receipt can be used only once.
String receiptDocId(ReceiptMethod method, String normalizedTransactionId) =>
    '${method.name}_$normalizedTransactionId';

/// Payer account suffix for CBE receipt links: digits only, 4..8 long.
String? normalizePayerAccountSuffix(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.length < 4) return null;
  return digits.length > 8 ? digits.substring(digits.length - 8) : digits;
}

/// The official receipt page for a transaction (null for 'other').
Uri? officialReceiptUrl(
  ReceiptMethod method,
  String transactionId, {
  String? payerAccountSuffix,
  String telebirrTemplate = kTelebirrReceiptUrlTemplate,
  String cbeTemplate = kCbeReceiptUrlTemplate,
}) {
  final id = Uri.encodeComponent(normalizeTransactionId(transactionId));
  if (id.isEmpty) return null;
  switch (method) {
    case ReceiptMethod.telebirr:
      return Uri.parse(telebirrTemplate.replaceAll('{id}', id));
    case ReceiptMethod.cbe:
      final suffix = normalizePayerAccountSuffix(payerAccountSuffix) ?? '';
      return Uri.parse(cbeTemplate.replaceAll('{id}', id).replaceAll('{suffix}', suffix));
    case ReceiptMethod.other:
      return null;
  }
}

/// A claimed amount: finite, > 0, <= [kMaxReceiptAmount], rounded to cents.
double? normalizeReceiptAmount(Object? raw) {
  double? v;
  if (raw is num) v = raw.toDouble();
  if (raw is String) v = double.tryParse(raw.trim().replaceAll(',', ''));
  if (v == null || !v.isFinite || v <= 0 || v > kMaxReceiptAmount) return null;
  return (v * 100).roundToDouble() / 100;
}

/// New subscription end after paying for [days]: counted from the current
/// end while it is still in the future (paying early never loses days),
/// otherwise from [now].
DateTime extendSubscriptionByDays(DateTime? currentEnd, DateTime now, int days) {
  final base = currentEnd != null && currentEnd.isAfter(now) ? currentEnd : now;
  return base.toUtc().add(Duration(days: days));
}
