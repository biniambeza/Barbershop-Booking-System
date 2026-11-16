import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/shop_report.dart';
import 'app_repository.dart';
import 'report_fallback.dart';

export '../models/shop_report.dart';
export 'report_fallback.dart' show ReportSource, kReportFallbackDays;

/// Owner reports: monthly totals, revenue trend, top services, barber
/// performance and client history for one shop.
///
///  * With Firebase it reads the docs the `functions/insights` Cloud
///    Functions maintain: `barbershops/{shopId}/stats/{yyyy-MM}` (one get per
///    month) and `barbershops/{shopId}/clients` (most completed visits first).
///    The app never writes them.
///  * Without Firebase (DEMO_MODE, tests) it computes the same figures from
///    the shop's bookings in the repository cache.
///  * Free plan (functions do not run): when the stats docs are missing or
///    stale it computes the report from the cached bookings instead
///    ([ShopReport.fromBookings], see report_fallback.dart).
class ReportsService {
  ReportsService({AppRepository? repository, FirebaseFirestore? firestore})
      : _repo = repository ?? AppRepository.instance,
        _firestore = firestore;

  final AppRepository _repo;
  final FirebaseFirestore? _firestore;

  /// Months in the month picker (current month and the 11 before it).
  static const int monthsShown = 12;

  /// Bars in the revenue trend.
  static const int trendMonths = 6;

  /// Clients loaded for the Clients tab.
  static const int clientLimit = 100;

  /// True when figures come from the Cloud Functions' docs.
  bool get usesFirestore => _firestore != null || _repo.isFirebaseAttached;

  Future<ShopReport> loadShopReport(String shopId, {DateTime? now}) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    if (!usesFirestore) return computeLocalReport(shopId, now: nowUtc);
    // free plan: falls back to the cached bookings when the stats are missing or stale
    return loadWithBookingFallback(
      _firestore ?? FirebaseFirestore.instance,
      shopId,
      bookings: _repo.getShopBookings(shopId),
      now: nowUtc,
    );
  }

  /// Free plan: the report computed from the cached bookings, flagged
  /// [ShopReport.fromBookings] (the owner screen recomputes it live).
  ShopReport computeFallbackReport(String shopId, {DateTime? now}) =>
      _flagFromBookings(computeLocalReport(shopId, now: now));

  static ShopReport _flagFromBookings(ShopReport r) =>
      ShopReport(shopId: r.shopId, months: r.months, clients: r.clients, fromBookings: true);

  /// Reads the stats docs; uses them when they exist and are fresh
  /// ([chooseReportSource]), else returns the report computed from
  /// [bookings]. The clients docs are read only when the stats are used.
  /// A failed stats read also falls back to the bookings.
  static Future<ShopReport> loadWithBookingFallback(
    FirebaseFirestore db,
    String shopId, {
    required Iterable<Booking> bookings,
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final computed = reportFromBookings(shopId, bookings, now: nowUtc);
    final keys = recentMonthKeys(nowUtc, monthsShown);
    final List<DocumentSnapshot<Map<String, dynamic>>> snaps;
    try {
      snaps = await _monthSnaps(db, shopId, keys);
    } catch (_) {
      return _flagFromBookings(computed);
    }
    final existing = <String, ShopMonthStats>{
      for (var i = 0; i < keys.length; i++)
        if (snaps[i].exists) keys[i]: ShopMonthStats.fromMap(keys[i], snaps[i].data() ?? const {}),
    };
    final source = chooseReportSource(
      existingStats: existing,
      fromBookings: computed,
      currentMonth: keys.first,
      now: nowUtc,
    );
    if (source == ReportSource.bookings) return _flagFromBookings(computed);
    final clients = await _clientsQuery(db, shopId).get();
    return ShopReport(
      shopId: shopId,
      months: [for (final k in keys) existing[k] ?? ShopMonthStats(month: k)],
      clients: [for (final d in clients.docs) ShopClient.fromMap(d.id, d.data())]..sort(ShopClient.byFrequency),
    );
  }

  static Future<List<DocumentSnapshot<Map<String, dynamic>>>> _monthSnaps(
          FirebaseFirestore db, String shopId, List<String> keys) =>
      Future.wait([for (final k in keys) db.collection('barbershops').doc(shopId).collection('stats').doc(k).get()]);

  static Query<Map<String, dynamic>> _clientsQuery(FirebaseFirestore db, String shopId) => db
      .collection('barbershops')
      .doc(shopId)
      .collection('clients')
      .orderBy('completedCount', descending: true)
      .limit(clientLimit);

  /// Demo / tests: the report computed from the cached bookings.
  ShopReport computeLocalReport(String shopId, {DateTime? now}) =>
      reportFromBookings(shopId, _repo.getShopBookings(shopId), now: now);

  /// Builds a report from bookings with the same rules as the
  /// `aggregateBookingStats` Cloud Function.
  static ShopReport reportFromBookings(String shopId, Iterable<Booking> bookings, {DateTime? now}) {
    final acc = ReportAccumulator();
    for (final b in bookings) {
      if (b.shopId != shopId) continue;
      // Like functions/insights: bookings the system cancelled after a slot
      // clash never happened from the shop's point of view.
      if (b.status == BookingStatus.cancelled && b.cancelReason == 'slot_conflict') continue;
      acc.add(
        customerId: b.customerId,
        customerName: b.customerName,
        customerPhone: b.customerPhone,
        serviceId: b.serviceId,
        serviceName: b.serviceName,
        barberId: b.barberId,
        barberName: b.barberName,
        status: b.status.name,
        startAt: b.startAt,
        price: b.price,
      );
    }
    final keys = recentMonthKeys((now ?? DateTime.now()).toUtc(), monthsShown);
    final clients = acc.clients();
    return ShopReport(
      shopId: shopId,
      months: [for (final k in keys) acc.month(k)],
      clients: clients.length > clientLimit ? clients.sublist(0, clientLimit) : clients,
    );
  }

  /// Reads the shop's stats and clients docs.
  static Future<ShopReport> loadFromFirestore(FirebaseFirestore db, String shopId, {DateTime? now}) async {
    final shop = db.collection('barbershops').doc(shopId);
    final keys = recentMonthKeys((now ?? DateTime.now()).toUtc(), monthsShown);
    final monthSnaps = Future.wait([for (final k in keys) shop.collection('stats').doc(k).get()]);
    final clientSnap = shop.collection('clients').orderBy('completedCount', descending: true).limit(clientLimit).get();
    final months = await monthSnaps;
    final clients = await clientSnap;
    return ShopReport(
      shopId: shopId,
      months: [
        for (var i = 0; i < keys.length; i++)
          months[i].exists
              ? ShopMonthStats.fromMap(keys[i], months[i].data() ?? const {})
              : ShopMonthStats(month: keys[i]),
      ],
      clients: [for (final d in clients.docs) ShopClient.fromMap(d.id, d.data())]..sort(ShopClient.byFrequency),
    );
  }
}
