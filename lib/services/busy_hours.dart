/// Owner analytics: when a shop is busy. A weekday x hour heatmap of the
/// shop's bookings in Addis Ababa time, plus the "busiest day", "busiest
/// time" and "quietest hour" callouts.
///
/// Pure (no I/O); the clock is a parameter. Rules:
///  * a booking counts in the Addis weekday and hour its `startAt` falls in
///    (a 60-minute booking at 10:30 counts once, at 10:00-10:59);
///  * cancelled bookings are left out (they never took the chair); pending,
///    confirmed, in-progress, completed and no-show bookings count;
///  * only bookings of the shop whose start is in `[startUtc, endUtc)`.
library;

import '../data/addis_time.dart';
import '../models/booking_model.dart';
import '../models/shop_report.dart' show addisMonthKey;

/// The periods the Busy hours tab offers.
enum BusyHoursRange {
  /// The 30 days up to now.
  last30Days,

  /// The 90 days up to now (as far back as the app's booking listeners go).
  last90Days,

  /// One Addis calendar month ('yyyy-MM').
  month,
}

/// A period `[startUtc, endUtc)`.
class BusyHoursPeriod {
  const BusyHoursPeriod._(this.range, this.startUtc, this.endUtc, this.month);

  /// [month] ('yyyy-MM') is used for [BusyHoursRange.month] and defaults to
  /// the current Addis month.
  factory BusyHoursPeriod.of(BusyHoursRange range, DateTime nowUtc, {String? month}) {
    final now = nowUtc.toUtc();
    switch (range) {
      case BusyHoursRange.last30Days:
        return BusyHoursPeriod._(range, now.subtract(const Duration(days: 30)), now, null);
      case BusyHoursRange.last90Days:
        return BusyHoursPeriod._(range, now.subtract(const Duration(days: 90)), now, null);
      case BusyHoursRange.month:
        final key = month ?? addisMonthKey(now);
        final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
        if (m == null) throw ArgumentError.value(month, 'month', 'expected yyyy-MM');
        final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
        return BusyHoursPeriod._(range, addisLocalToUtc(y, mo, 1), addisLocalToUtc(y, mo + 1, 1), key);
    }
  }

  final BusyHoursRange range;

  /// Inclusive.
  final DateTime startUtc;

  /// Exclusive.
  final DateTime endUtc;

  /// 'yyyy-MM' for [BusyHoursRange.month].
  final String? month;

  bool contains(DateTime instant) {
    final t = instant.toUtc();
    return !t.isBefore(startUtc) && t.isBefore(endUtc);
  }

  @override
  bool operator ==(Object other) =>
      other is BusyHoursPeriod && other.range == range && other.startUtc == startUtc && other.endUtc == endUtc;

  @override
  int get hashCode => Object.hash(range, startUtc, endUtc);
}

/// Whether [b] counts as demand in the heatmap (not cancelled).
bool countsForBusyHours(Booking b) => b.status != BookingStatus.cancelled;

/// Booking counts per Addis weekday (1 = Monday ... 7 = Sunday) and hour
/// (0-23).
class BusyHoursHeatmap {
  BusyHoursHeatmap._(this._counts);

  /// An empty map.
  factory BusyHoursHeatmap.empty() => BusyHoursHeatmap._(List.generate(7, (_) => List.filled(24, 0)));

  /// Tests / callers: from a `[weekday-1][hour]` grid.
  factory BusyHoursHeatmap.fromGrid(List<List<int>> grid) {
    if (grid.length != 7 || grid.any((row) => row.length != 24)) {
      throw ArgumentError('expected a 7 x 24 grid');
    }
    return BusyHoursHeatmap._([for (final row in grid) List<int>.of(row)]);
  }

  final List<List<int>> _counts;

  /// Bookings starting on [weekday] (1-7) in [hour] (0-23).
  int at(int weekday, int hour) => _counts[weekday - 1][hour];

  int get total => _counts.fold(0, (sum, row) => sum + row.fold(0, (s, c) => s + c));

  bool get isEmpty => total == 0;

  /// The largest cell.
  int get maxCell => _counts.fold(0, (m, row) => row.fold(m, (mm, c) => c > mm ? c : mm));

  /// Totals per weekday, Monday first.
  List<int> get byWeekday => [for (final row in _counts) row.fold(0, (s, c) => s + c)];

  /// Totals per hour of the day (all weekdays).
  List<int> get byHour => [for (var h = 0; h < 24; h++) _counts.fold(0, (s, row) => s + row[h])];

  /// The weekday (1-7) with the most bookings; the earlier day on a tie.
  /// Null when there are none.
  int? get busiestWeekday {
    if (isEmpty) return null;
    final days = byWeekday;
    var best = 0;
    for (var i = 1; i < 7; i++) {
      if (days[i] > days[best]) best = i;
    }
    return best + 1;
  }

  /// The busiest single cell as (weekday, hour); the earlier one on a tie.
  /// Null when there are none.
  (int, int)? get busiestSlot {
    if (isEmpty) return null;
    var bestDay = 1, bestHour = 0, best = -1;
    for (var d = 1; d <= 7; d++) {
      for (var h = 0; h < 24; h++) {
        if (at(d, h) > best) {
          best = at(d, h);
          bestDay = d;
          bestHour = h;
        }
      }
    }
    return (bestDay, bestHour);
  }

  /// The hour of the shop's day (`[openingHour, closingHour)`, Addis time)
  /// with the fewest bookings over the whole period; the earlier hour on a
  /// tie. Null when there are no bookings or no opening hours. Hours
  /// outside the opening hours are not candidates (the shop is closed).
  int? quietestHour({required int openingHour, required int closingHour}) {
    if (isEmpty) return null;
    final (from, to) = _openRange(openingHour, closingHour);
    if (to <= from) return null;
    final hours = byHour;
    var best = from;
    for (var h = from + 1; h < to; h++) {
      if (hours[h] < hours[best]) best = h;
    }
    return best;
  }

  /// The hours to draw `[from, to)`: the opening hours, widened to include
  /// any hour that has bookings.
  (int, int) visibleHours({required int openingHour, required int closingHour}) {
    var (from, to) = _openRange(openingHour, closingHour);
    final hours = byHour;
    for (var h = 0; h < 24; h++) {
      if (hours[h] == 0) continue;
      if (h < from) from = h;
      if (h + 1 > to) to = h + 1;
    }
    if (to <= from) return (0, 24);
    return (from, to);
  }

  static (int, int) _openRange(int openingHour, int closingHour) {
    final from = openingHour.clamp(0, 23);
    final to = closingHour.clamp(1, 24);
    // Unusual hours (closing before opening): the whole day.
    if (to <= from) return (0, 24);
    return (from, to);
  }
}

/// Builds the heatmap of [shopId]'s bookings in [period].
BusyHoursHeatmap busyHoursFromBookings(
  Iterable<Booking> bookings, {
  required String shopId,
  required BusyHoursPeriod period,
}) {
  final grid = List.generate(7, (_) => List.filled(24, 0));
  for (final b in bookings) {
    if (b.shopId != shopId || !countsForBusyHours(b) || !period.contains(b.startAt)) continue;
    final wall = toAddisWallClock(b.startAt);
    grid[wall.weekday - 1][wall.hour]++;
  }
  return BusyHoursHeatmap._(grid);
}
