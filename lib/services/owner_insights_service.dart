/// Data for the owner's Busy hours and No-shows tabs (reports screen).
///
///  * Busy hours: the last 30 / 90 days come from the bookings the owner's
///    app already listens to (the last [kReportFallbackDays] days plus
///    upcoming). A chosen month that starts before that window is read with
///    one query, `bookings where shopId == s and startAt >= start and
///    startAt < end` (index bookings (shopId, startAt)), at most
///    [monthQueryLimit] documents, merged with the cache. Works on Spark.
///  * No-shows: the cached bookings, merged with the all-time `clients`
///    docs of functions/insights when the report has them (Blaze).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/shop_report.dart' show ShopClient;
import 'app_repository.dart';
import 'busy_hours.dart';
import 'customer_insights.dart';
import 'report_fallback.dart' show kReportFallbackDays;

export 'busy_hours.dart';
export 'customer_insights.dart';

class OwnerInsightsService {
  OwnerInsightsService({AppRepository? repository, FirebaseFirestore? firestore})
      : _repo = repository ?? AppRepository.instance,
        _firestore = firestore;

  final AppRepository _repo;
  final FirebaseFirestore? _firestore;

  /// Most bookings read for one month older than the cached window.
  static const int monthQueryLimit = 3000;

  bool get usesFirestore => _firestore != null || _repo.isFirebaseAttached;

  /// Whether the cached bookings cover [period] (it starts within the last
  /// [kReportFallbackDays] days, give or take a day).
  static bool cacheCovers(BusyHoursPeriod period, DateTime nowUtc) =>
      !period.startUtc.isBefore(nowUtc.toUtc().subtract(const Duration(days: kReportFallbackDays + 1)));

  /// Whether [busyHours] needs a Firestore read for [period].
  bool needsQuery(BusyHoursPeriod period, DateTime nowUtc) => usesFirestore && !cacheCovers(period, nowUtc);

  /// The heatmap from the cached bookings only (synchronous).
  BusyHoursHeatmap cachedBusyHours(String shopId, BusyHoursPeriod period) =>
      busyHoursFromBookings(_repo.getShopBookings(shopId), shopId: shopId, period: period);

  /// The heatmap of [period]; reads Firestore when the cache does not cover
  /// it ([needsQuery]).
  Future<BusyHoursHeatmap> busyHours(String shopId, BusyHoursPeriod period, {DateTime? now}) async {
    final nowUtc = (now ?? _repo.nowUtc()).toUtc();
    if (!needsQuery(period, nowUtc)) return cachedBusyHours(shopId, period);
    final db = _firestore ?? FirebaseFirestore.instance;
    final snap = await db
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('startAt', isGreaterThanOrEqualTo: period.startUtc.toUtc().toIso8601String())
        .where('startAt', isLessThan: period.endUtc.toUtc().toIso8601String())
        .limit(monthQueryLimit)
        .get();
    final byId = <String, Booking>{for (final d in snap.docs) d.id: Booking.fromMap(d.data(), d.id)};
    for (final b in _repo.getShopBookings(shopId)) {
      byId[b.id] = b; // the listener's copy is the freshest
    }
    return busyHoursFromBookings(byId.values, shopId: shopId, period: period);
  }

  /// The No-shows tab's rows, sorted by no-show rate. [clientDocs] are the
  /// report's function-maintained client docs (empty on Spark).
  List<CustomerNoShowRow> customerRows(String shopId, {Iterable<ShopClient> clientDocs = const []}) {
    final rows = customerRowsFromBookings(_repo.getShopBookings(shopId), shopId: shopId);
    return sortByNoShowRate(mergeWithClientDocs(rows, clientDocs));
  }
}
