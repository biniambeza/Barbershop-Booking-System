/// Owner reports: monthly shop stats and per-shop client history.
///
/// With Firebase these mirror the docs the `functions/insights` Cloud
/// Functions maintain (the app never writes them):
///  * `barbershops/{shopId}/stats/{yyyy-MM}` ([ShopMonthStats])
///  * `barbershops/{shopId}/clients/{customerId}` ([ShopClient])
/// In demo mode and tests the same shapes are computed from the local
/// bookings (see `ReportsService`).
library;

import '../data/addis_time.dart';

/// 'yyyy-MM' of the Addis calendar month containing the UTC instant [utc].
String addisMonthKey(DateTime utc) {
  final wall = toAddisWallClock(utc);
  return '${wall.year.toString().padLeft(4, '0')}-${wall.month.toString().padLeft(2, '0')}';
}

/// The [count] month keys ending with the current Addis month, newest first.
List<String> recentMonthKeys(DateTime nowUtc, int count) {
  final wall = toAddisWallClock(nowUtc);
  return [
    for (var i = 0; i < count; i++) addisMonthKey(addisLocalToUtc(wall.year, wall.month - i, 1, 12)),
  ];
}

/// First day of the month of a 'yyyy-MM' key (for display), or null.
DateTime? monthKeyToDate(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
}

num _num(dynamic v) => v is num && v.isFinite ? v : 0;
int _int(dynamic v) => _num(v).toInt();
double _double(dynamic v) => _num(v).toDouble();
String _str(dynamic v) => v is String ? v : '';

double _roundEtb(double v) => (v * 100).roundToDouble() / 100;

class ServiceStat {
  const ServiceStat({required this.serviceId, required this.name, required this.count, required this.revenueEtb});

  final String serviceId;
  final String name;

  /// Completed bookings of this service in the month.
  final int count;
  final double revenueEtb;

  factory ServiceStat.fromMap(String id, Map<String, dynamic> map) => ServiceStat(
      serviceId: id, name: _str(map['name']), count: _int(map['count']), revenueEtb: _double(map['revenueEtb']));
}

class BarberStat {
  const BarberStat({required this.barberId, required this.name, required this.completed, required this.revenueEtb});

  final String barberId;
  final String name;
  final int completed;
  final double revenueEtb;

  factory BarberStat.fromMap(String id, Map<String, dynamic> map) => BarberStat(
      barberId: id, name: _str(map['name']), completed: _int(map['completed']), revenueEtb: _double(map['revenueEtb']));
}

/// One month of a shop's bookings (Addis month of each booking's start).
class ShopMonthStats {
  const ShopMonthStats({
    required this.month,
    this.bookings = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShows = 0,
    this.revenueEtb = 0,
    this.byService = const {},
    this.byBarber = const {},
    this.updatedAt,
  });

  /// 'yyyy-MM'.
  final String month;

  /// Every booking that starts in the month, whatever its status.
  final int bookings;
  final int completed;
  final int cancelled;
  final int noShows;

  /// Sum of the prices of completed bookings, ETB.
  final double revenueEtb;
  final Map<String, ServiceStat> byService;
  final Map<String, BarberStat> byBarber;
  final DateTime? updatedAt;

  bool get isEmpty => bookings == 0;

  /// Services by completed count, then revenue.
  List<ServiceStat> get topServices => byService.values.toList()
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : b.revenueEtb.compareTo(a.revenueEtb);
    });

  /// Barbers by revenue, then completed count.
  List<BarberStat> get barberPerformance => byBarber.values.toList()
    ..sort((a, b) {
      final c = b.revenueEtb.compareTo(a.revenueEtb);
      return c != 0 ? c : b.completed.compareTo(a.completed);
    });

  factory ShopMonthStats.fromMap(String month, Map<String, dynamic> map) {
    Map<String, dynamic> asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};
    return ShopMonthStats(
      month: month,
      bookings: _int(map['bookings']),
      completed: _int(map['completed']),
      cancelled: _int(map['cancelled']),
      noShows: _int(map['noShows']),
      revenueEtb: _double(map['revenueEtb']),
      byService: {
        for (final e in asMap(map['byService']).entries)
          if (e.value is Map) e.key: ServiceStat.fromMap(e.key, asMap(e.value)),
      },
      byBarber: {
        for (final e in asMap(map['byBarber']).entries)
          if (e.value is Map) e.key: BarberStat.fromMap(e.key, asMap(e.value)),
      },
      updatedAt: map['updatedAt'] is String ? DateTime.tryParse(map['updatedAt'] as String) : null,
    );
  }
}

/// A customer's history with one shop.
class ShopClient {
  const ShopClient({
    required this.customerId,
    required this.name,
    required this.phone,
    this.completedCount = 0,
    this.noShowCount = 0,
    this.cancelledCount = 0,
    this.lastVisitAt,
  });

  final String customerId;
  final String name;

  /// E.164 (+2519...).
  final String phone;
  final int completedCount;
  final int noShowCount;
  final int cancelledCount;

  /// Start (UTC) of the latest completed booking.
  final DateTime? lastVisitAt;

  factory ShopClient.fromMap(String id, Map<String, dynamic> map) => ShopClient(
        customerId: id,
        name: _str(map['name']),
        phone: _str(map['phone']),
        completedCount: _int(map['completedCount']),
        noShowCount: _int(map['noShowCount']),
        cancelledCount: _int(map['cancelledCount']),
        lastVisitAt: map['lastVisitAt'] is String ? DateTime.tryParse(map['lastVisitAt'] as String)?.toUtc() : null,
      );

  /// Most completed visits first, then the most recent visit, then name.
  static int byFrequency(ShopClient a, ShopClient b) {
    final c = b.completedCount.compareTo(a.completedCount);
    if (c != 0) return c;
    final av = a.lastVisitAt, bv = b.lastVisitAt;
    if (av != bv) {
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    }
    return a.name.compareTo(b.name);
  }
}

/// Everything the owner Reports screen shows.
class ShopReport {
  ShopReport({required this.shopId, required List<ShopMonthStats> months, required this.clients})
      : months = List.unmodifiable(months);

  final String shopId;

  /// The last months, newest first (empty months included).
  final List<ShopMonthStats> months;

  /// Clients, most frequent first.
  final List<ShopClient> clients;

  ShopMonthStats month(String key) =>
      months.firstWhere((m) => m.month == key, orElse: () => ShopMonthStats(month: key));

  /// The [count] months ending with [key], oldest first (for the trend bars).
  List<ShopMonthStats> trendEndingAt(String key, int count) {
    final start = months.indexWhere((m) => m.month == key);
    if (start < 0) return const [];
    return months.skip(start).take(count).toList().reversed.toList();
  }
}

/// Builds month stats and client docs from bookings, exactly like the
/// `aggregateBookingStats` Cloud Function (functions/insights/src/logic/stats.ts).
/// [bookings] are (shopId, customer, status name, start, price ...) records.
class ReportAccumulator {
  final Map<String, _MonthBuilder> _months = {};
  final Map<String, _ClientBuilder> _clients = {};

  void add({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String serviceId,
    required String serviceName,
    required String barberId,
    required String barberName,
    required String status,
    required DateTime startAt,
    required double price,
  }) {
    if (customerId.isEmpty) return;
    final completed = status == 'completed';
    final revenue = completed ? _roundEtb(price < 0 ? 0 : price) : 0.0;
    final m = _months.putIfAbsent(addisMonthKey(startAt), () => _MonthBuilder());
    m.bookings++;
    if (completed) m.completed++;
    if (status == 'cancelled') m.cancelled++;
    if (status == 'noShow') m.noShows++;
    m.revenue = _roundEtb(m.revenue + revenue);
    if (completed && serviceId.isNotEmpty) {
      final s = m.services.putIfAbsent(serviceId, () => _Entry(serviceName));
      s.count++;
      s.revenue = _roundEtb(s.revenue + revenue);
    }
    if (completed && barberId.isNotEmpty) {
      final b = m.barbers.putIfAbsent(barberId, () => _Entry(barberName));
      b.count++;
      b.revenue = _roundEtb(b.revenue + revenue);
    }

    final c = _clients.putIfAbsent(customerId, () => _ClientBuilder());
    // Name and phone from the customer's latest booking.
    if (c.latestStart == null || !startAt.isBefore(c.latestStart!)) {
      c.latestStart = startAt;
      if (customerName.isNotEmpty) c.name = customerName;
      if (customerPhone.isNotEmpty) c.phone = customerPhone;
    }
    if (completed) {
      c.completed++;
      if (c.lastVisit == null || startAt.isAfter(c.lastVisit!)) c.lastVisit = startAt;
    }
    if (status == 'noShow') c.noShows++;
    if (status == 'cancelled') c.cancelled++;
  }

  ShopMonthStats month(String key) {
    final m = _months[key];
    if (m == null) return ShopMonthStats(month: key);
    return ShopMonthStats(
      month: key,
      bookings: m.bookings,
      completed: m.completed,
      cancelled: m.cancelled,
      noShows: m.noShows,
      revenueEtb: m.revenue,
      byService: {
        for (final e in m.services.entries)
          e.key: ServiceStat(serviceId: e.key, name: e.value.name, count: e.value.count, revenueEtb: e.value.revenue),
      },
      byBarber: {
        for (final e in m.barbers.entries)
          e.key: BarberStat(barberId: e.key, name: e.value.name, completed: e.value.count, revenueEtb: e.value.revenue),
      },
    );
  }

  List<ShopClient> clients() => [
        for (final e in _clients.entries)
          ShopClient(
            customerId: e.key,
            name: e.value.name,
            phone: e.value.phone,
            completedCount: e.value.completed,
            noShowCount: e.value.noShows,
            cancelledCount: e.value.cancelled,
            lastVisitAt: e.value.lastVisit?.toUtc(),
          ),
      ]..sort(ShopClient.byFrequency);
}

class _MonthBuilder {
  int bookings = 0, completed = 0, cancelled = 0, noShows = 0;
  double revenue = 0;
  final Map<String, _Entry> services = {};
  final Map<String, _Entry> barbers = {};
}

class _Entry {
  _Entry(this.name);
  final String name;
  int count = 0;
  double revenue = 0;
}

class _ClientBuilder {
  String name = '';
  String phone = '';
  int completed = 0, noShows = 0, cancelled = 0;
  DateTime? lastVisit;
  DateTime? latestStart;
}
