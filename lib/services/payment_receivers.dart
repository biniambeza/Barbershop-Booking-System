// Where shop owners pay the platform: validation of the telebirr number and
// CBE account the admin types in (platformConfig/subscriptionPricing
// `receivers`), and which payment methods owners may use. Pure Dart: no
// Flutter, no Firebase.
//
// Stored shape (unchanged): receivers.telebirr.number is '' or an E.164
// Ethiopian mobile number ('+2519XXXXXXXX' with real digits);
// receivers.cbe.account is '' or 13 digits starting with 1000. An empty
// account means "this method is not offered" and owners do not see it.

import '../core/utils/phone_utils.dart';
import 'subscription_pricing.dart';

/// Shortest account-holder name the admin may save.
const int kMinReceiverNameLength = 2;

final RegExp _cbeAccount = RegExp(r'^1000\d{9}$');

/// Still the 'XXXX' sample from the defaults / seed.
bool isPlaceholderReceiverAccount(String account) => account.toUpperCase().contains('X');

/// A telebirr receiver number in E.164 form, or null.
String? normalizeTelebirrReceiver(String raw) =>
    isPlaceholderReceiverAccount(raw) ? null : normalizeEthiopianPhone(raw.trim());

/// A CBE account number (13 digits starting with 1000; spaces, dashes and
/// dots are ignored), or null.
String? normalizeCbeReceiverAccount(String raw) {
  final compact = raw.trim().replaceAll(RegExp(r'[\s\-.]'), '');
  return _cbeAccount.hasMatch(compact) ? compact : null;
}

/// [raw] normalized for [method]; null when invalid or for 'other'.
String? normalizeReceiverAccount(ReceiptMethod method, String raw) {
  switch (method) {
    case ReceiptMethod.telebirr:
      return normalizeTelebirrReceiver(raw);
    case ReceiptMethod.cbe:
      return normalizeCbeReceiverAccount(raw);
    case ReceiptMethod.other:
      return null;
  }
}

/// True when [receiver] holds a real, valid account for [method].
bool isReceiverReady(ReceiptMethod method, PaymentReceiver receiver) =>
    normalizeReceiverAccount(method, receiver.account) != null;

/// What is wrong with one field of a receiver.
enum ReceiverIssue { placeholder, invalidAccount, nameTooShort, nameTooLong }

/// The result of checking one receiver the admin typed in.
class ReceiverCheck {
  const ReceiverCheck({this.account, this.name, this.receiver});

  final ReceiverIssue? account;
  final ReceiverIssue? name;

  /// The normalized receiver to save (account '' = method not offered);
  /// null when there is an issue.
  final PaymentReceiver? receiver;

  bool get ok => account == null && name == null;
}

/// Checks a receiver typed by the admin. An empty account is allowed (the
/// method is then hidden from owners); otherwise the account must be valid
/// for [method] and the name 2..80 characters.
ReceiverCheck checkReceiver(ReceiptMethod method, {required String account, required String name}) {
  final a = account.trim();
  final n = name.trim();
  if (a.isEmpty) {
    if (n.length > kMaxReceiverNameLength) return const ReceiverCheck(name: ReceiverIssue.nameTooLong);
    return ReceiverCheck(receiver: PaymentReceiver(account: '', name: n));
  }
  ReceiverIssue? accountIssue;
  String? normalized;
  if (isPlaceholderReceiverAccount(a)) {
    accountIssue = ReceiverIssue.placeholder;
  } else {
    normalized = normalizeReceiverAccount(method, a);
    if (normalized == null) accountIssue = ReceiverIssue.invalidAccount;
  }
  ReceiverIssue? nameIssue;
  if (n.length < kMinReceiverNameLength) {
    nameIssue = ReceiverIssue.nameTooShort;
  } else if (n.length > kMaxReceiverNameLength) {
    nameIssue = ReceiverIssue.nameTooLong;
  }
  if (accountIssue != null || nameIssue != null) return ReceiverCheck(account: accountIssue, name: nameIssue);
  return ReceiverCheck(receiver: PaymentReceiver(account: normalized!, name: n));
}

/// The pricing with both receivers normalized for saving, or null when a
/// receiver is invalid. A leftover 'XXXX' placeholder is saved as '' (not
/// offered) so the sample number never reaches the database.
SubscriptionPricing? normalizePricingReceivers(SubscriptionPricing pricing) {
  PaymentReceiver? clean(ReceiptMethod method, PaymentReceiver r) {
    final account = isPlaceholderReceiverAccount(r.account) ? '' : r.account;
    return checkReceiver(method, account: account, name: r.name).receiver;
  }

  final telebirr = clean(ReceiptMethod.telebirr, pricing.telebirr);
  final cbe = clean(ReceiptMethod.cbe, pricing.cbe);
  if (telebirr == null || cbe == null) return null;
  return pricing.copyWith(telebirr: telebirr, cbe: cbe);
}

/// Which payment methods owners can use with this pricing.
extension PricingReceivers on SubscriptionPricing {
  bool get telebirrReady => isReceiverReady(ReceiptMethod.telebirr, telebirr);
  bool get cbeReady => isReceiverReady(ReceiptMethod.cbe, cbe);

  /// At least one place to pay is set up: payments are open.
  bool get hasReadyReceiver => telebirrReady || cbeReady;

  /// telebirr / CBE when set up; 'other' (any other transfer, checked by
  /// the admin) once at least one is. Empty: payments are not open.
  List<ReceiptMethod> get payableMethods => [
        if (telebirrReady) ReceiptMethod.telebirr,
        if (cbeReady) ReceiptMethod.cbe,
        if (hasReadyReceiver) ReceiptMethod.other,
      ];

  bool canPayWith(ReceiptMethod method) => payableMethods.contains(method);
}
