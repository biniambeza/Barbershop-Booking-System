/// Barber commission and payouts: pure calculations (no I/O).
///
///  * A barber's share of a completed booking is
///    `round(price * commissionPercent / 100)` Birr, with the booking's
///    stored price. Nothing is stored per booking: shares are computed from
///    the bookings whose status is `completed`.
///  * A booking belongs to the Addis calendar month of its `startAt`; a
///    payout belongs to the month of its `periodStart` date.
///  * Balance owed for a month = share - payouts recorded for that month.
library;

import 'dart:math' as math;

import '../data/addis_time.dart';
import '../models/barber_model.dart';
import '../models/booking_model.dart';
import '../models/payout.dart';

export '../models/payout.dart';

/// Payout and commission failures. Screens show them with
/// `payoutsErrorText` (lib/features/payouts/payouts_l10n.dart).
enum PayoutErrorCode {
  /// Only the shop's owner records or deletes payouts and sets commission.
  ownerOnly,

  /// The payout or barber does not exist (any more).
  notFound,

  /// The barber is not one of the shop's barbers.
  unknownBarber,

  /// Amount not > 0 or above [kMaxPayoutAmount].
  invalidAmount,

  /// Period start after its end.
  invalidPeriod,

  /// Note longer than [kMaxPayoutNoteLength].
  noteTooLong,

  /// Commission outside 0..100.
  invalidCommission,

  /// The payout was recorded more than [kPayoutDeleteWindow] ago (or by
  /// someone else).
  deleteWindowPassed,
}

class PayoutException implements Exception {
  PayoutException(this.code);

  final PayoutErrorCode code;

  @override
  String toString() => 'PayoutException(${code.name})';
}

/// Whether [percent] is a valid commission (whole number 0..100).
bool isValidCommissionPercent(int percent) => percent >= 0 && percent <= 100;

/// The commission of [barber] (default [kDefaultCommissionPercent]).
int commissionOf(Barber barber) {
  final p = barber.commissionPercent;
  return p == null || !isValidCommissionPercent(p) ? kDefaultCommissionPercent : p;
}

/// The barber's share of one booking price, rounded to whole Birr.
double barberShareOf(double price, int commissionPercent) =>
    (price * commissionPercent / 100).round().toDouble();

/// An Addis calendar month.
class PayoutMonth implements Comparable<PayoutMonth> {
  PayoutMonth(int year, int month)
      : year = DateTime.utc(year, month).year,
        month = DateTime.utc(year, month).month;

  final int year;
  final int month;

  /// The Addis month containing the UTC instant [instantUtc].
  factory PayoutMonth.ofInstant(DateTime instantUtc) {
    final wall = toAddisWallClock(instantUtc);
    return PayoutMonth(wall.year, wall.month);
  }

  /// The month of a calendar date (its year/month fields).
  factory PayoutMonth.ofDate(DateTime date) => PayoutMonth(date.year, date.month);

  /// Parses 'yyyy-MM'; null if malformed.
  static PayoutMonth? tryParse(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
    if (m == null) return null;
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    return PayoutMonth(int.parse(m.group(1)!), month);
  }

  /// 'yyyy-MM'.
  String get key => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  PayoutMonth previous([int months = 1]) => PayoutMonth(year, month - months);
  PayoutMonth next([int months = 1]) => PayoutMonth(year, month + months);

  /// First and last calendar day (UTC midnight; the fields are the Addis
  /// date), the default period of a payout for this month.
  DateTime get firstDay => DateTime.utc(year, month, 1);
  DateTime get lastDay => DateTime.utc(year, month + 1, 0);

  /// The UTC instants bounding the month in Addis time: `[startUtc, endUtc)`.
  DateTime get startUtc => addisLocalToUtc(year, month, 1);
  DateTime get endUtc => addisLocalToUtc(year, month + 1, 1);

  /// Whether [instantUtc] falls in this Addis month.
  bool containsInstant(DateTime instantUtc) => !instantUtc.isBefore(startUtc) && instantUtc.isBefore(endUtc);

  /// Whether the calendar date [date] (year/month/day fields) is in it.
  bool containsDate(DateTime date) => date.year == year && date.month == month;

  /// The [count] months ending with the Addis month of [nowUtc], newest first.
  static List<PayoutMonth> recent(DateTime nowUtc, int count) {
    final current = PayoutMonth.ofInstant(nowUtc);
    return [for (var i = 0; i < count; i++) current.previous(i)];
  }

  @override
  int compareTo(PayoutMonth other) => year != other.year ? year - other.year : month - other.month;

  @override
  bool operator ==(Object other) => other is PayoutMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}

/// One barber's figures for one month.
class BarberPayoutSummary {
  const BarberPayoutSummary({
    required this.barberId,
    required this.barberName,
    required this.commissionPercent,
    required this.completedJobs,
    required this.gross,
    required this.share,
    required this.paid,
  });

  final String barberId;
  final String barberName;
  final int commissionPercent;

  /// Completed bookings in the month.
  final int completedJobs;

  /// Sum of their prices (Birr).
  final double gross;

  /// The barber's share of them (sum of per-booking rounded shares).
  final double share;

  /// Payouts recorded for the month.
  final double paid;

  /// What the shop still owes for the month (negative = overpaid).
  double get balance => share - paid;

  /// The amount to prefill when recording a payout (never negative).
  double get suggestedPayout => math.max(0, balance);
}

/// Shop-wide totals of [BarberPayoutSummary]s.
class ShopPayoutTotals {
  const ShopPayoutTotals({required this.gross, required this.share, required this.paid, required this.owed});

  factory ShopPayoutTotals.of(Iterable<BarberPayoutSummary> rows) {
    var gross = 0.0, share = 0.0, paid = 0.0, owed = 0.0;
    for (final r in rows) {
      gross += r.gross;
      share += r.share;
      paid += r.paid;
      owed += r.suggestedPayout;
    }
    return ShopPayoutTotals(gross: gross, share: share, paid: paid, owed: owed);
  }

  final double gross;
  final double share;
  final double paid;

  /// Sum of the positive balances (what the shop owes in total; one
  /// barber's overpayment does not offset another's balance).
  final double owed;
}

/// The month's figures for [barber] from [bookings] and [payouts] (both
/// may contain other barbers' or months' entries; they are filtered here).
BarberPayoutSummary summarizeBarberMonth({
  required Barber barber,
  required Iterable<Booking> bookings,
  required Iterable<Payout> payouts,
  required PayoutMonth month,
}) {
  final percent = commissionOf(barber);
  var jobs = 0;
  var gross = 0.0;
  var share = 0.0;
  for (final b in bookings) {
    if (b.barberId != barber.id || b.shopId != barber.shopId) continue;
    if (b.status != BookingStatus.completed || !month.containsInstant(b.startAt)) continue;
    jobs++;
    gross += b.price;
    share += barberShareOf(b.price, percent);
  }
  var paid = 0.0;
  for (final p in payouts) {
    if (p.barberId == barber.id && p.shopId == barber.shopId && month.containsDate(p.periodStart)) paid += p.amount;
  }
  return BarberPayoutSummary(
    barberId: barber.id,
    barberName: barber.name,
    commissionPercent: percent,
    completedJobs: jobs,
    gross: gross,
    share: share,
    paid: paid,
  );
}

/// [summarizeBarberMonth] for each of [barbers], in their order.
List<BarberPayoutSummary> summarizeShopMonth({
  required Iterable<Barber> barbers,
  required Iterable<Booking> bookings,
  required Iterable<Payout> payouts,
  required PayoutMonth month,
}) {
  final bookingList = bookings.toList();
  final payoutList = payouts.toList();
  return [
    for (final b in barbers) summarizeBarberMonth(barber: b, bookings: bookingList, payouts: payoutList, month: month),
  ];
}

/// Merges a fetched month of bookings with the live cache (cache wins, as
/// it reflects status changes made since the fetch).
List<Booking> mergeBookings(Iterable<Booking> fetched, Iterable<Booking> live) {
  final byId = <String, Booking>{for (final b in fetched) b.id: b};
  for (final b in live) {
    byId[b.id] = b;
  }
  return byId.values.toList();
}

/// Rounds a Birr amount to cents.
double roundBirr(double amount) => (amount * 100).round() / 100;

/// The first problem with a payout's input, or null if it is valid.
PayoutErrorCode? validatePayoutInput({
  required double amount,
  required DateTime periodStart,
  required DateTime periodEnd,
  String? note,
}) {
  if (amount.isNaN || amount.isInfinite || amount <= 0 || amount > kMaxPayoutAmount) {
    return PayoutErrorCode.invalidAmount;
  }
  final start = DateTime.utc(periodStart.year, periodStart.month, periodStart.day);
  final end = DateTime.utc(periodEnd.year, periodEnd.month, periodEnd.day);
  if (start.isAfter(end)) return PayoutErrorCode.invalidPeriod;
  if ((note?.trim().length ?? 0) > kMaxPayoutNoteLength) return PayoutErrorCode.noteTooLong;
  return null;
}

/// Parses an amount typed by the owner ("1,250", "300.5"); null if it is
/// not a number.
double? parsePayoutAmount(String text) {
  final cleaned = text.replaceAll(',', '').replaceAll(' ', '').trim();
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  return value == null || value.isNaN || value.isInfinite ? null : value;
}

/// Whether [payout] is still inside its delete window at [nowUtc] (less
/// than [kPayoutDeleteWindow] since it was recorded). Only the shop owner
/// deletes; that check is the caller's.
bool isWithinPayoutDeleteWindow(Payout payout, DateTime nowUtc) =>
    nowUtc.toUtc().difference(payout.createdAt.toUtc()) < kPayoutDeleteWindow;
