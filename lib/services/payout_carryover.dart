/// Payout carry-over: what is left unpaid at the end of a month moves to
/// the next month. Pure calculations (no I/O).
///
/// Deterministic from the data, nothing is stored:
///
///   carried into month M = share of the barber's completed bookings in
///                          [kPayoutCarryOverStart, M)
///                        - payouts whose `periodStart` is in that range
///   balance owed for M   = carried into M + share in M - paid for M
///
/// So the balance owed at the end of a month is exactly what the next month
/// shows as `Carried over from {month}`, and paying part of it leaves the
/// rest for the next month. An overpayment carries over as a negative
/// amount (it reduces the next balance).
///
/// Notes:
///  * Months before [kPayoutCarryOverStart] (the month payouts were added
///    to the app) are not carried: owners settled those outside the app.
///    An owner can clear any remaining old balance by recording a payout
///    for one of the listed months.
///  * The carried share is `round(revenue * commission / 100)` over the whole
///    range at the barber's current commission (one Firestore aggregate,
///    see PayoutsManager.loadCarryOver), while a month's share rounds per
///    booking. The two differ by less than 0.5 Birr per booking only when
///    price x commission is not a whole number of Birr.
library;

import 'dart:math' as math;

import '../models/barber_model.dart';
import '../models/booking_model.dart';
import 'payout_service.dart';

/// The first month whose balance carries over (payouts were added to the
/// app in November 2026).
final PayoutMonth kPayoutCarryOverStart = PayoutMonth(2026, 11);

/// The earlier months whose balances carry into a month: `[from, to)`.
class CarryOverWindow {
  const CarryOverWindow(this.from, this.to);

  /// First month counted.
  final PayoutMonth from;

  /// The month the balance carries into (not counted).
  final PayoutMonth to;

  /// Bookings: `startAt >= startUtc and startAt < endUtc`.
  DateTime get startUtc => from.startUtc;
  DateTime get endUtc => to.startUtc;

  /// Payouts: `periodStart >= firstDay and periodStart < endDay` (calendar
  /// dates, UTC midnight).
  DateTime get firstDay => from.firstDay;
  DateTime get endDay => to.firstDay;

  bool containsInstant(DateTime instantUtc) => !instantUtc.isBefore(startUtc) && instantUtc.isBefore(endUtc);

  bool containsDate(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    return !d.isBefore(firstDay) && d.isBefore(endDay);
  }
}

/// The months carried into [month] (from [since], default
/// [kPayoutCarryOverStart]); null when nothing carries (month <= since).
CarryOverWindow? carryOverWindow(PayoutMonth month, {PayoutMonth? since}) {
  final from = since ?? kPayoutCarryOverStart;
  return month.compareTo(from) <= 0 ? null : CarryOverWindow(from, month);
}

/// What one barber carries into [month].
class PayoutCarryOver {
  const PayoutCarryOver({
    required this.month,
    required this.completedJobs,
    required this.revenue,
    required this.share,
    required this.paid,
  });

  /// Nothing carried into [month].
  const PayoutCarryOver.none(this.month)
      : completedJobs = 0,
        revenue = 0,
        share = 0,
        paid = 0;

  /// The month the balance carries into.
  final PayoutMonth month;

  /// Completed bookings in the earlier months.
  final int completedJobs;

  /// Their revenue (ETB).
  final double revenue;

  /// The barber's share of it.
  final double share;

  /// Payouts recorded for the earlier months.
  final double paid;

  /// The month the amount comes from (the one before [month]).
  PayoutMonth get from => month.previous();

  /// Unpaid (positive) or overpaid (negative) amount carried over.
  double get amount => share - paid;

  bool get isZero => amount == 0;
}

/// The carry-over from aggregates: [revenueBefore] of [completedBefore]
/// completed bookings and [paidBefore] in the window.
PayoutCarryOver carryOverOf({
  required PayoutMonth month,
  required int commissionPercent,
  required int completedBefore,
  required double revenueBefore,
  required double paidBefore,
}) =>
    PayoutCarryOver(
      month: month,
      completedJobs: completedBefore,
      revenue: revenueBefore,
      share: barberShareOf(revenueBefore, commissionPercent),
      paid: paidBefore,
    );

/// The carry-over of [barber] into [month] computed in memory from every
/// booking and payout (DEMO_MODE, tests). Matches the Firestore aggregates.
PayoutCarryOver carryOverFromData({
  required Barber barber,
  required Iterable<Booking> bookings,
  required Iterable<Payout> payouts,
  required PayoutMonth month,
  PayoutMonth? since,
}) {
  final window = carryOverWindow(month, since: since);
  if (window == null) return PayoutCarryOver.none(month);
  var jobs = 0;
  var revenue = 0.0;
  for (final b in bookings) {
    if (b.barberId != barber.id || b.shopId != barber.shopId) continue;
    if (b.status != BookingStatus.completed || !window.containsInstant(b.startAt)) continue;
    jobs++;
    revenue += b.price;
  }
  var paid = 0.0;
  for (final p in payouts) {
    if (p.barberId == barber.id && p.shopId == barber.shopId && window.containsDate(p.periodStart)) paid += p.amount;
  }
  return carryOverOf(
    month: month,
    commissionPercent: commissionOf(barber),
    completedBefore: jobs,
    revenueBefore: revenue,
    paidBefore: paid,
  );
}

/// A barber's month with what carried into it.
class BarberBalance {
  const BarberBalance({required this.summary, required this.carry});

  /// The month's own figures.
  final BarberPayoutSummary summary;

  /// Carried in from earlier months (zero when unknown).
  final PayoutCarryOver carry;

  String get barberId => summary.barberId;

  double get carriedOver => carry.amount;

  /// Carried over + the month's share - the month's payouts (negative =
  /// overpaid). This is what carries into the next month.
  double get balance => carriedOver + summary.balance;

  /// The amount to prefill when recording a payout (never negative).
  double get suggestedPayout => math.max(0, balance);
}

/// Pairs each month summary with its carry-over ([carries] by barber id;
/// missing = nothing carried).
List<BarberBalance> withCarryOver(
  Iterable<BarberPayoutSummary> rows,
  Map<String, PayoutCarryOver> carries,
  PayoutMonth month,
) =>
    [
      for (final r in rows) BarberBalance(summary: r, carry: carries[r.barberId] ?? PayoutCarryOver.none(month)),
    ];

/// Shop-wide totals of [BarberBalance]s.
class ShopBalanceTotals {
  const ShopBalanceTotals({
    required this.share,
    required this.paid,
    required this.carriedOver,
    required this.owed,
  });

  factory ShopBalanceTotals.of(Iterable<BarberBalance> rows) {
    var share = 0.0, paid = 0.0, carried = 0.0, owed = 0.0;
    for (final r in rows) {
      share += r.summary.share;
      paid += r.summary.paid;
      carried += r.carriedOver;
      owed += r.suggestedPayout;
    }
    return ShopBalanceTotals(share: share, paid: paid, carriedOver: carried, owed: owed);
  }

  /// The month's shares.
  final double share;

  /// The month's payouts.
  final double paid;

  /// Net amount carried in from earlier months.
  final double carriedOver;

  /// Sum of the positive running balances (one barber's overpayment does
  /// not offset another's balance).
  final double owed;
}
