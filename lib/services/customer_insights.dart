/// Owner analytics: each customer's record with one shop (bookings,
/// completed, cancellations, no-shows, no-show rate). Pure (no I/O).
///
/// Only what the owner already sees on the shop's bookings is used: the
/// customer's id, name and phone as stored on the booking, and the
/// booking statuses. No profile, email or other shops' data.
///
/// No-show rate = no-shows / (completed + no-shows): of the appointments
/// that came due and were not cancelled, how many the customer missed.
/// Upcoming and cancelled bookings do not change it. Null (shown as a
/// dash) while the customer has neither.
library;

import '../models/booking_model.dart';
import '../models/shop_report.dart' show ShopClient;

/// One customer's line in the No-shows tab.
class CustomerNoShowRow {
  const CustomerNoShowRow({
    required this.customerId,
    required this.name,
    required this.phone,
    this.bookings = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShows = 0,
    this.lastBookingAt,
  });

  final String customerId;

  /// From the customer's latest booking at the shop.
  final String name;

  /// From the customer's latest booking at the shop (E.164 or '').
  final String phone;

  /// Every booking at the shop, whatever its status.
  final int bookings;
  final int completed;
  final int cancelled;
  final int noShows;

  /// Start (UTC) of the latest booking.
  final DateTime? lastBookingAt;

  /// noShows / (completed + noShows), 0..1; null when both are 0.
  double? get noShowRate {
    final due = completed + noShows;
    return due == 0 ? null : noShows / due;
  }

  /// The rate as a whole percentage (rounded), or null.
  int? get noShowPercent {
    final r = noShowRate;
    return r == null ? null : (r * 100).round();
  }
}

/// Whether [b] is left out of the customer counts: a booking the system
/// cancelled after a slot clash never happened from the shop's point of
/// view (same rule as the reports and functions/insights).
bool _ignored(Booking b) => b.status == BookingStatus.cancelled && b.cancelReason == 'slot_conflict';

/// One row per customer of [shopId] in [bookings].
List<CustomerNoShowRow> customerRowsFromBookings(Iterable<Booking> bookings, {required String shopId}) {
  final acc = <String, _RowBuilder>{};
  for (final b in bookings) {
    if (b.shopId != shopId || b.customerId.isEmpty || _ignored(b)) continue;
    final r = acc.putIfAbsent(b.customerId, () => _RowBuilder());
    r.bookings++;
    if (b.status == BookingStatus.completed) r.completed++;
    if (b.status == BookingStatus.cancelled) r.cancelled++;
    if (b.status == BookingStatus.noShow) r.noShows++;
    if (r.latest == null || !b.startAt.isBefore(r.latest!)) {
      r.latest = b.startAt;
      if (b.customerName.isNotEmpty) r.name = b.customerName;
      if (b.customerPhone.isNotEmpty) r.phone = b.customerPhone;
    }
  }
  return [
    for (final e in acc.entries)
      CustomerNoShowRow(
        customerId: e.key,
        name: e.value.name,
        phone: e.value.phone,
        bookings: e.value.bookings,
        completed: e.value.completed,
        cancelled: e.value.cancelled,
        noShows: e.value.noShows,
        lastBookingAt: e.value.latest?.toUtc(),
      ),
  ];
}

/// Merges [rows] (from the cached bookings, last 90 days) with the
/// all-time [clients] docs of functions/insights (Blaze). Per customer each
/// counter is the larger of the two (the docs are all-time, the bookings
/// may be newer than the docs); a customer in only one source is kept as
/// is. A client doc has no total, so its bookings are at least
/// completed + cancelled + no-shows.
List<CustomerNoShowRow> mergeWithClientDocs(List<CustomerNoShowRow> rows, Iterable<ShopClient> clients) {
  final byId = {for (final r in rows) r.customerId: r};
  for (final c in clients) {
    final r = byId[c.customerId];
    final docTotal = c.completedCount + c.cancelledCount + c.noShowCount;
    int max(int a, int b) => a > b ? a : b;
    if (r == null) {
      byId[c.customerId] = CustomerNoShowRow(
        customerId: c.customerId,
        name: c.name,
        phone: c.phone,
        bookings: docTotal,
        completed: c.completedCount,
        cancelled: c.cancelledCount,
        noShows: c.noShowCount,
        lastBookingAt: c.lastVisitAt,
      );
      continue;
    }
    byId[c.customerId] = CustomerNoShowRow(
      customerId: r.customerId,
      name: r.name.isNotEmpty ? r.name : c.name,
      phone: r.phone.isNotEmpty ? r.phone : c.phone,
      bookings: max(r.bookings, docTotal),
      completed: max(r.completed, c.completedCount),
      cancelled: max(r.cancelled, c.cancelledCount),
      noShows: max(r.noShows, c.noShowCount),
      lastBookingAt: r.lastBookingAt ?? c.lastVisitAt,
    );
  }
  return byId.values.toList();
}

/// Highest no-show rate first; then more no-shows, more bookings, name.
/// Customers without a rate (nothing due yet) go last.
int compareByNoShowRate(CustomerNoShowRow a, CustomerNoShowRow b) {
  final ar = a.noShowRate, br = b.noShowRate;
  if (ar != br) {
    if (ar == null) return 1;
    if (br == null) return -1;
    final c = br.compareTo(ar);
    if (c != 0) return c;
  }
  var c = b.noShows.compareTo(a.noShows);
  if (c != 0) return c;
  c = b.bookings.compareTo(a.bookings);
  if (c != 0) return c;
  c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return c != 0 ? c : a.customerId.compareTo(b.customerId);
}

/// [rows] sorted with [compareByNoShowRate] (a new list).
List<CustomerNoShowRow> sortByNoShowRate(Iterable<CustomerNoShowRow> rows) =>
    rows.toList()..sort(compareByNoShowRate);

/// The rows whose name contains [query] (case-insensitive, surrounding
/// spaces ignored). An empty query keeps every row.
List<CustomerNoShowRow> searchCustomersByName(Iterable<CustomerNoShowRow> rows, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows.toList();
  return rows.where((r) => r.name.toLowerCase().contains(q)).toList();
}

/// The customer's no-shows at [shopId] in [bookings]. [alsoNoShowId]
/// counts that booking as a no-show even if the list still has its old
/// status (the write that marked it may not be back yet).
int noShowCountOf(Iterable<Booking> bookings,
    {required String shopId, required String customerId, String? alsoNoShowId}) {
  var n = 0;
  var sawExtra = false;
  for (final b in bookings) {
    if (b.shopId != shopId || b.customerId != customerId) continue;
    if (b.id == alsoNoShowId) {
      sawExtra = true;
      n++;
    } else if (b.status == BookingStatus.noShow) {
      n++;
    }
  }
  if (alsoNoShowId != null && !sawExtra) n++;
  return n;
}

class _RowBuilder {
  String name = '';
  String phone = '';
  int bookings = 0, completed = 0, cancelled = 0, noShows = 0;
  DateTime? latest;
}
