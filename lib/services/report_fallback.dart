/// Free-plan fallback for owner reports.
///
/// The report figures normally come from `barbershops/{shopId}/stats/{yyyy-MM}`
/// and `.../clients/{customerId}`, written by functions/insights. On the
/// free Spark plan functions do not run, so those docs are missing (or, after
/// a downgrade, stop updating). The app then computes the report from the
/// shop's bookings it already listens to (FirestoreDataStore keeps the last
/// [kReportFallbackDays] days plus upcoming bookings), with the same rules as
/// the function (`ReportsService.reportFromBookings`). No Firestore writes.
///
/// Pure; the clock is a parameter.
library;

import '../models/shop_report.dart';

/// How far back the owner's booking listener reaches
/// (FirestoreDataStore.bookingHistoryDays). Shown in the screen's note.
const int kReportFallbackDays = 90;

/// Stats that disagree with the bookings are still trusted for this long
/// after their last update (the function is probably catching up).
const Duration kStatsFreshnessLag = Duration(minutes: 15);

/// Where a report's figures come from.
enum ReportSource {
  /// The function-maintained stats and clients docs.
  stats,

  /// Computed in the app from the cached bookings (free plan).
  bookings,
}

/// Newest `updatedAt` among [stats] (null when none has one).
DateTime? newestStatsUpdate(Iterable<ShopMonthStats> stats) {
  DateTime? newest;
  for (final s in stats) {
    final t = s.updatedAt;
    if (t != null && (newest == null || t.isAfter(newest))) newest = t;
  }
  return newest;
}

/// Whether [computed] (from bookings) shows activity [stored] has not
/// counted yet: any counter of the month is higher. Fewer bookings than the
/// stats is normal (the app only loads the last 90 days, at most 1000).
bool statsBehindBookings(ShopMonthStats stored, ShopMonthStats computed) =>
    computed.bookings > stored.bookings ||
    computed.completed > stored.completed ||
    computed.cancelled > stored.cancelled ||
    computed.noShows > stored.noShows;

/// Chooses between the stats docs that exist ([existingStats], by month key;
/// missing docs left out) and the report computed from bookings.
///
///  * no stats doc at all (functions never ran)          -> bookings;
///  * the current month's stats are behind the bookings and were not
///    updated within [lag] (functions stopped running)   -> bookings;
///  * otherwise (stats present and fresh)                 -> stats.
ReportSource chooseReportSource({
  required Map<String, ShopMonthStats> existingStats,
  required ShopReport fromBookings,
  required String currentMonth,
  required DateTime now,
  Duration lag = kStatsFreshnessLag,
}) {
  if (existingStats.isEmpty) return ReportSource.bookings;
  final stored = existingStats[currentMonth] ?? ShopMonthStats(month: currentMonth);
  if (!statsBehindBookings(stored, fromBookings.month(currentMonth))) return ReportSource.stats;
  final newest = newestStatsUpdate(existingStats.values);
  if (newest != null && now.toUtc().difference(newest.toUtc()) < lag) return ReportSource.stats;
  return ReportSource.bookings;
}
