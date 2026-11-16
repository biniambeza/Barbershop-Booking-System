/// Refunds of paid bookings that get cancelled. Pure functions (the clock
/// is a parameter) shared by the repository, both data stores, the screens
/// and the tests. functions/bookings/src/logic/refund.ts mirrors the amount
/// rules and the notice text for the Blaze function.
///
/// Amount rules (the existing cancellation policy):
///  * The shop's side cancelled (barber, owner, admin, a declined or
///    expired request, the shop was deleted, a system cancel): the full
///    price.
///  * The customer cancelled before the shop's cancellation cutoff
///    (`now <= startAt - cancellationCutoffHours`): the full price.
///  * The customer cancelled after the cutoff (only possible through staff
///    or a server path; the app stops customers at the cutoff):
///    [kLateCancelRefundPercent] % of the price.
///  * A no-show is not a cancellation: nothing is refunded.
///
/// Only a booking whose paymentStatus is 'paid' and that has no refund yet
/// is flagged; an amount of 0 is never flagged.
library;

import '../data/addis_time.dart';
import '../models/app_notification.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';

/// Share of the price refunded when the customer cancels after the cutoff.
const int kLateCancelRefundPercent = 50;

/// Who is cancelling.
enum RefundCanceller { customer, barber, owner, admin, system }

/// The canceller for [user] cancelling [booking] (null user = system).
RefundCanceller refundCancellerFor(AppUser? user, Booking booking) {
  if (user == null) return RefundCanceller.system;
  switch (user.role) {
    case UserRole.admin:
      return RefundCanceller.admin;
    case UserRole.barbershopOwner:
      return RefundCanceller.owner;
    case UserRole.barber:
      return RefundCanceller.barber;
    case UserRole.customer:
      return user.uid == booking.customerId ? RefundCanceller.customer : RefundCanceller.system;
  }
}

/// What a cancellation path knows when it cancels: passed down to the data
/// store, which flags the refund in the same write (from the booking as it
/// is in that write, e.g. re-read in its transaction).
class RefundContext {
  const RefundContext({
    required this.by,
    required this.nowUtc,
    this.cutoffHours,
    this.reason,
    this.languageOf,
  });

  final RefundCanceller by;
  final DateTime nowUtc;

  /// The shop's cancellationCutoffHours (customer cancels only; null =
  /// treat as before the cutoff).
  final int? cutoffHours;

  /// Fixed [RefundReasons] value for special paths (shop deleted, declined
  /// or expired request); otherwise derived from [by].
  final String? reason;

  /// The recipient's language ('en' / 'am') for the inbox notice.
  final String? Function(String uid)? languageOf;
}

/// Whether the customer's cancel at [nowUtc] is after the cutoff.
bool isLateCustomerCancel(Booking booking, int? cutoffHours, DateTime nowUtc) {
  if (cutoffHours == null) return false;
  final deadline = booking.startAt.toUtc().subtract(Duration(hours: cutoffHours));
  return nowUtc.toUtc().isAfter(deadline);
}

/// The [RefundReasons] value for cancelling [booking] in [ctx].
String refundReasonFor(Booking booking, RefundContext ctx) {
  final fixed = ctx.reason;
  if (fixed != null) return fixed;
  switch (ctx.by) {
    case RefundCanceller.customer:
      return isLateCustomerCancel(booking, ctx.cutoffHours, ctx.nowUtc)
          ? RefundReasons.customerLateCancel
          : RefundReasons.customerCancelled;
    case RefundCanceller.barber:
      return RefundReasons.barberCancelled;
    case RefundCanceller.owner:
      return RefundReasons.shopCancelled;
    case RefundCanceller.admin:
      return RefundReasons.adminCancelled;
    case RefundCanceller.system:
      return RefundReasons.systemCancelled;
  }
}

/// Rounds ETB to 2 decimals.
double roundEtb(double value) => (value * 100).roundToDouble() / 100;

/// The refund for [booking] under [reason] ('paid' price; 0 for a no-show
/// or a booking without a valid price).
double refundAmountFor(Booking booking, String reason) {
  if (booking.status == BookingStatus.noShow) return 0;
  final price = booking.price;
  if (!(price > 0) || price.isNaN || price.isInfinite) return 0;
  if (reason == RefundReasons.customerLateCancel) return roundEtb(price * kLateCancelRefundPercent / 100);
  return roundEtb(price);
}

/// Whether [booking] has money that a cancel would have to refund: paid
/// and not refunded or flagged yet.
bool needsRefundFlag(Booking booking) =>
    booking.paymentStatus == PaymentStatus.paid && booking.refund == null;

/// The refund to flag when [booking] (its state as of this write) is
/// cancelled in [ctx], or null when nothing is owed.
BookingRefund? refundFlagFor(Booking booking, RefundContext ctx) {
  if (!needsRefundFlag(booking) || booking.status == BookingStatus.noShow) return null;
  final reason = refundReasonFor(booking, ctx);
  final amount = refundAmountFor(booking, reason);
  if (amount <= 0) return null;
  return BookingRefund(status: RefundStatus.due, amount: amount, reason: reason, flaggedAt: ctx.nowUtc.toUtc());
}

/// The fields "Mark refunded" writes (one update; the rules accept exactly
/// these keys): refundStatus 'refunded', refundedAt, refundedBy,
/// refundMethod, refundReference (when given) and paymentStatus 'refunded'.
Map<String, dynamic> refundCompletionFields({
  required DateTime refundedAt,
  required String refundedBy,
  required RefundMethod method,
  String? reference,
}) =>
    {
      'refundStatus': RefundStatus.refunded.name,
      'refundedAt': refundedAt.toUtc().toIso8601String(),
      'refundedBy': refundedBy,
      'refundMethod': method.name,
      if (reference != null) 'refundReference': reference,
      'paymentStatus': PaymentStatus.refunded.name,
    };

/// The trimmed reference, or null when empty. Throws [ArgumentError] above
/// [kMaxRefundReferenceLength].
String? normalizeRefundReference(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length > kMaxRefundReferenceLength) {
    throw ArgumentError.value(raw, 'reference', 'at most $kMaxRefundReferenceLength characters');
  }
  return text;
}

// ---------------------------------------------------------------------------
// Inbox notices
// ---------------------------------------------------------------------------

/// `users/{customerId}/notifications/{bookingId}_refundDue`.
String refundDueNoticeId(String bookingId) => '${bookingId}_${NotificationTypes.refundDue}';

/// `users/{customerId}/notifications/{bookingId}_paymentRefunded` (the same
/// id the notifications function uses, so a Blaze project never shows it
/// twice).
String refundedNoticeId(String bookingId) => '${bookingId}_${NotificationTypes.paymentRefunded}';

/// One inbox entry for the booking's customer.
class RefundNotice {
  const RefundNotice({
    required this.id,
    required this.recipientUid,
    required this.type,
    required this.title,
    required this.body,
    required this.bookingId,
    required this.createdAt,
  });

  final String id;
  final String recipientUid;

  /// [NotificationTypes.refundDue] or [NotificationTypes.paymentRefunded].
  final String type;
  final String title;
  final String body;
  final String bookingId;

  /// UTC.
  final DateTime createdAt;

  /// Exactly `{type, title, body, bookingId, read: false, createdAt}`.
  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'body': body,
        'bookingId': bookingId,
        'read': false,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  AppNotification toAppNotification() => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        bookingId: bookingId,
        createdAt: createdAt.toUtc(),
      );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _etb(double amount) => 'ETB ${amount.toStringAsFixed(2)}';

String _when(Booking b) {
  final t = toAddisWallClock(b.startAt);
  return '${_two(t.day)}/${_two(t.month)}/${t.year} ${_two(t.hour)}:${_two(t.minute)}';
}

/// Notice text (matches functions/bookings/src/logic/refund.ts). Amharic
/// unless [language] is 'en'.
({String title, String body}) renderRefundDueText(Booking booking, double amount, {String? language}) {
  final shop = booking.shopName.trim().isEmpty ? null : booking.shopName.trim();
  if (language == 'en') {
    return (
      title: 'Refund due',
      body: 'Your paid appointment on ${_when(booking)} was cancelled. '
          '${shop ?? 'The barbershop'} owes you a refund of ${_etb(amount)}.',
    );
  }
  return (
    title: 'ተመላሽ ገንዘብ አለዎት',
    body: 'በ${_when(booking)} የከፈሉበት ቀጠሮ ተሰርዟል። '
        '${shop ?? 'ፀጉር ቤቱ'} ${_etb(amount)} ተመላሽ ያደርግልዎታል።',
  );
}

({String title, String body}) renderRefundedText(Booking booking, double amount, {String? language}) {
  final shop = booking.shopName.trim().isEmpty ? null : booking.shopName.trim();
  if (language == 'en') {
    return (
      title: 'Payment refunded',
      body: '${shop ?? 'The barbershop'} refunded ${_etb(amount)} for your appointment on ${_when(booking)}.',
    );
  }
  return (
    title: 'ክፍያዎ ተመልሷል',
    body: '${shop ?? 'ፀጉር ቤቱ'} በ${_when(booking)} ለነበረዎት ቀጠሮ ${_etb(amount)} መልሷል።',
  );
}

/// The customer's "Refund due" notice for [flag].
RefundNotice refundDueNotice(Booking booking, BookingRefund flag, {String? language}) {
  final text = renderRefundDueText(booking, flag.amount, language: language);
  return RefundNotice(
    id: refundDueNoticeId(booking.id),
    recipientUid: booking.customerId,
    type: NotificationTypes.refundDue,
    title: text.title,
    body: text.body,
    bookingId: booking.id,
    createdAt: flag.flaggedAt,
  );
}

/// The customer's "Payment refunded" notice.
RefundNotice refundedNotice(Booking booking, double amount, DateTime at, {String? language}) {
  final text = renderRefundedText(booking, amount, language: language);
  return RefundNotice(
    id: refundedNoticeId(booking.id),
    recipientUid: booking.customerId,
    type: NotificationTypes.paymentRefunded,
    title: text.title,
    body: text.body,
    bookingId: booking.id,
    createdAt: at.toUtc(),
  );
}

/// Refunds still owed, oldest flag first.
List<Booking> refundsDue(Iterable<Booking> bookings, {String? shopId}) => bookings
    .where((b) => b.refund?.isDue == true && (shopId == null || b.shopId == shopId))
    .toList()
  ..sort((a, b) => a.refund!.flaggedAt.compareTo(b.refund!.flaggedAt));

/// Cancelled + paid bookings without a refund flag (e.g. cancelled by an
/// older app version): the owner's app flags them ([refundFlagFor] with
/// the cancellation's own facts).
List<Booking> cancelledPaidUnflagged(Iterable<Booking> bookings, {required String shopId}) => bookings
    .where((b) => b.shopId == shopId && b.status == BookingStatus.cancelled && needsRefundFlag(b) && b.price > 0)
    .toList();

/// The context of a cancellation that already happened (sweep): derived
/// from the booking's cancelledBy / cancelReason / declineReason.
RefundContext refundContextForPastCancel(Booking booking, DateTime nowUtc,
    {String? Function(String uid)? languageOf}) {
  String reason;
  final by = booking.cancelledBy;
  if (booking.cancelReason == 'shop_deleted') {
    reason = RefundReasons.shopDeleted;
  } else if (booking.cancelReason == 'not_accepted' || booking.declineReason == 'not_accepted') {
    reason = RefundReasons.requestExpired;
  } else if (by == 'barber' || by == 'owner') {
    reason = RefundReasons.requestDeclined;
  } else if (by != null && by == booking.customerId) {
    // When they cancelled is unknown here: treated as on time (full).
    reason = RefundReasons.customerCancelled;
  } else if (by == null || by == 'system') {
    reason = RefundReasons.systemCancelled;
  } else {
    reason = RefundReasons.shopCancelled;
  }
  return RefundContext(by: RefundCanceller.system, nowUtc: nowUtc, reason: reason, languageOf: languageOf);
}
