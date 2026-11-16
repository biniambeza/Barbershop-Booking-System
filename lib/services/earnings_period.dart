/// Earnings and totals for any period: pure calculations (no I/O).
///
/// The app only keeps about 90 days of bookings in memory
/// (FirestoreDataStore.bookingHistoryDays), so screens that need a longer
/// period ask Firestore for aggregates instead (count() and sum('price') of
/// the completed bookings, see PayoutsManager.loadEarnings). In DEMO_MODE
/// and tests the same figures come from the in-memory bookings
/// ([earningsFromBookings]).
///
/// Rules (the same as the payouts screen):
///  * only bookings whose status is `completed` count;
///  * a booking belongs to the Addis calendar day of its `startAt`;
///  * revenue is the sum of the stored booking prices (ETB);
///  * a barber's share of a period is `round(revenue * commission / 100)`
///    at the barber's current commission.
library;

import '../data/addis_time.dart';
import '../models/booking_model.dart';
import 'payout_service.dart';

/// The periods offered by the earnings cards.
enum EarningsRange {
  thisMonth,
  lastMonth,

  /// One month the user picks.
  month,
  thisYear,
  allTime,
}

/// A period of completed bookings: `[startUtc, endUtc)`; null bounds are
/// open (all time).
class EarningsPeriod {
  const EarningsPeriod._(this.range, {this.startUtc, this.endUtc, this.month, this.year});

  /// The period [range] at [nowUtc] (Addis calendar). [month] is required
  /// for [EarningsRange.month] (defaults to the current month).
  factory EarningsPeriod.of(EarningsRange range, DateTime nowUtc, {PayoutMonth? month}) {
    final current = PayoutMonth.ofInstant(nowUtc.toUtc());
    switch (range) {
      case EarningsRange.thisMonth:
        return EarningsPeriod.ofMonth(current, range: range);
      case EarningsRange.lastMonth:
        return EarningsPeriod.ofMonth(current.previous(), range: range);
      case EarningsRange.month:
        return EarningsPeriod.ofMonth(month ?? current, range: range);
      case EarningsRange.thisYear:
        final y = current.year;
        return EarningsPeriod._(range, startUtc: addisLocalToUtc(y, 1, 1), endUtc: addisLocalToUtc(y + 1, 1, 1), year: y);
      case EarningsRange.allTime:
        return const EarningsPeriod._(EarningsRange.allTime);
    }
  }

  /// Any range `[startUtc, endUtc)` (e.g. the carry-over window).
  factory EarningsPeriod.between(DateTime startUtc, DateTime endUtc) =>
      EarningsPeriod._(EarningsRange.month, startUtc: startUtc.toUtc(), endUtc: endUtc.toUtc());

  /// One whole Addis month.
  factory EarningsPeriod.ofMonth(PayoutMonth month, {EarningsRange range = EarningsRange.month}) =>
      EarningsPeriod._(range, startUtc: month.startUtc, endUtc: month.endUtc, month: month);

  final EarningsRange range;

  /// Inclusive; null = no lower bound.
  final DateTime? startUtc;

  /// Exclusive; null = no upper bound.
  final DateTime? endUtc;

  /// The month, for the month ranges.
  final PayoutMonth? month;

  /// The Addis year, for [EarningsRange.thisYear].
  final int? year;

  bool get isAllTime => startUtc == null && endUtc == null;

  /// First and last Addis calendar day (for display); null for all time.
  DateTime? get firstDay => startUtc == null ? null : _addisDay(startUtc!);
  DateTime? get lastDay => endUtc == null ? null : _addisDay(endUtc!.subtract(const Duration(milliseconds: 1)));

  static DateTime _addisDay(DateTime utc) {
    final wall = toAddisWallClock(utc);
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// Whether the UTC instant [instantUtc] is in the period.
  bool contains(DateTime instantUtc) {
    final t = instantUtc.toUtc();
    if (startUtc != null && t.isBefore(startUtc!)) return false;
    if (endUtc != null && !t.isBefore(endUtc!)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is EarningsPeriod && other.range == range && other.startUtc == startUtc && other.endUtc == endUtc;

  @override
  int get hashCode => Object.hash(range, startUtc, endUtc);

  @override
  String toString() => 'EarningsPeriod(${range.name}, $startUtc, $endUtc)';
}

/// Completed bookings and their revenue in a period.
class EarningsTotals {
  const EarningsTotals({required this.completed, required this.revenue});

  static const EarningsTotals zero = EarningsTotals(completed: 0, revenue: 0);

  /// Completed bookings.
  final int completed;

  /// Sum of their prices (ETB).
  final double revenue;

  /// The barber's share at [commissionPercent] (whole Birr).
  double shareAt(int commissionPercent) => barberShareOf(revenue, commissionPercent);

  EarningsTotals operator +(EarningsTotals other) =>
      EarningsTotals(completed: completed + other.completed, revenue: revenue + other.revenue);

  @override
  bool operator ==(Object other) => other is EarningsTotals && other.completed == completed && other.revenue == revenue;

  @override
  int get hashCode => Object.hash(completed, revenue);

  @override
  String toString() => 'EarningsTotals($completed, $revenue)';
}

/// The completed bookings of [shopId] (and of [barberId] when given) in
/// [period], computed in memory (DEMO_MODE, tests). Matches the Firestore
/// aggregate `bookings where shopId == s [and barberId == b] and status ==
/// 'completed' and startAt >= start and startAt < end`.
EarningsTotals earningsFromBookings(
  Iterable<Booking> bookings, {
  required String shopId,
  String? barberId,
  required EarningsPeriod period,
}) {
  var count = 0;
  var revenue = 0.0;
  for (final b in bookings) {
    if (b.shopId != shopId || (barberId != null && b.barberId != barberId)) continue;
    if (b.status != BookingStatus.completed || !period.contains(b.startAt)) continue;
    count++;
    revenue += b.price;
  }
  return EarningsTotals(completed: count, revenue: revenue);
}

/// One barber's line in the shop totals.
class BarberEarnings {
  const BarberEarnings({
    required this.barberId,
    required this.barberName,
    required this.commissionPercent,
    required this.totals,
  });

  final String barberId;
  final String barberName;
  final int commissionPercent;
  final EarningsTotals totals;

  double get share => totals.shareAt(commissionPercent);
}

/// The shop's totals for a period: the whole shop plus each barber.
class ShopEarnings {
  const ShopEarnings({required this.shop, required this.barbers});

  /// All completed bookings of the shop (including barbers that were
  /// removed since).
  final EarningsTotals shop;

  /// The current barbers, by revenue (then name).
  final List<BarberEarnings> barbers;

  /// Sum of the current barbers' shares.
  double get barbersShare => barbers.fold(0.0, (sum, b) => sum + b.share);

  /// What the shop keeps after the current barbers' shares.
  double get shopKeeps => shop.revenue - barbersShare;

  /// Sorts [rows] by revenue (highest first), then name.
  static List<BarberEarnings> sorted(Iterable<BarberEarnings> rows) => rows.toList()
    ..sort((a, b) {
      final c = b.totals.revenue.compareTo(a.totals.revenue);
      return c != 0 ? c : a.barberName.compareTo(b.barberName);
    });
}
