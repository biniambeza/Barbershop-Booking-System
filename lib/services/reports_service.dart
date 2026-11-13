import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/shop_report.dart';
import 'app_repository.dart';

export '../models/shop_report.dart';

/// Owner reports: monthly totals, revenue trend, top services, barber
/// performance and client history for one shop.
///
///  * With Firebase it reads the docs the `functions/insights` Cloud
///    Functions maintain: `barbershops/{shopId}/stats/{yyyy-MM}` (one get per
///    month) and `barbershops/{shopId}/clients` (most completed visits first).
///    The app never writes them.
///  * Without Firebase (DEMO_MODE, tests) it computes the same figures from
///    the shop's bookings in the repository cache.
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
    return loadFromFirestore(_firestore ?? FirebaseFirestore.instance, shopId, now: nowUtc);
  }

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
