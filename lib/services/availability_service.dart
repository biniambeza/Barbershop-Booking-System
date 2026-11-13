/// Appointment availability: slot generation and slot-lock ids.
///
/// Everything here is pure (no Firebase, no clock reads unless a `now` is
/// omitted), so it can be unit tested and shared by the booking flow, the
/// barber schedule and both [DataStore] implementations.
///
/// Times:
///  * Instants (booking `startAt`/`endAt`, the values returned by
///    [availableSlotStarts]) are UTC.
///  * Opening hours, working days, displayed slots and slot-lock ids are
///    Addis Ababa wall-clock time (UTC+3, no DST); see `lib/data/addis_time.dart`.
///  * An "Addis date" parameter is any [DateTime] whose year/month/day fields
///    name the Addis calendar day (its time and zone are ignored).
library;

import '../data/addis_time.dart';
import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';

/// Booking grid and slot-lock granularity.
const int kSlotStepMinutes = 15;

/// The earliest bookable slot is at least this far in the future.
const Duration kBookingLeadTime = Duration(minutes: 30);

/// How many days ahead (including today) customers can book.
const int kMaxBookingDaysAhead = 30;

/// Longest service the rules accept (`isValidService` in firestore.rules).
/// A booking writes one slot lock per 15-minute block in the same
/// transaction, and the rules read the booking for every lock, so this
/// keeps a booking's writes and rule document reads within Firestore's
/// per-request limits (8 locks at most).
const int kMaxServiceDurationMinutes = 120;

/// How long a slot lock outlives its booking's end (`expiresAt`).
const Duration kSlotLockRetention = Duration(days: 1);

/// Thrown when a booking overlaps an existing one for the same barber, either
/// caught locally or by the Firestore transaction (another customer took the
/// slot first).
class SlotTakenException implements Exception {
  const SlotTakenException([this.message = 'Sorry, that time was just taken. Please pick another slot.']);

  final String message;

  @override
  String toString() => message;
}

/// A half-open UTC interval `[start, end)` during which a barber is busy.
class BusyInterval {
  BusyInterval(DateTime start, DateTime end)
      : start = start.toUtc(),
        end = end.toUtc();

  final DateTime start;
  final DateTime end;

  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      start.isBefore(otherEnd) && otherStart.isBefore(end);

  @override
  bool operator ==(Object other) => other is BusyInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'BusyInterval($start - $end)';
}

/// One `barbershops/{shopId}/barbers/{barberId}/slotLocks/{id}` document:
/// a 15-minute block of a barber's day held by a booking or by a time-off
/// range.
///
/// Every signed-in user can read locks (the booking screen shows other
/// customers' busy times), so a lock carries no personal data: a booking
/// lock is `{bookingId, startAt, expiresAt}` and the rules bind it to its
/// booking through `bookingId`; a time-off lock is `{timeOffId, startAt,
/// expiresAt}` (no bookingId) and belongs to
/// `barbers/{barberId}/timeOff/{timeOffId}`. `expiresAt` (the booking's or
/// time off's end plus [kSlotLockRetention]) lets the daily
/// `cleanupExpiredSlotLocks` function in functions/bookings delete it.
class SlotLock {
  const SlotLock({
    required this.id,
    this.bookingId = '',
    this.timeOffId,
    required this.startAt,
    required this.expiresAt,
  });

  /// `yyyyMMdd-HHmm`, Addis wall-clock start of the block.
  final String id;

  /// The booking holding the block ('' for a time-off lock).
  final String bookingId;

  /// The time-off range holding the block, if this is a time-off lock.
  final String? timeOffId;

  /// UTC start of the block.
  final DateTime startAt;

  /// UTC instant after which the lock may be deleted.
  final DateTime expiresAt;

  bool get isTimeOff => timeOffId != null;

  BusyInterval get interval => BusyInterval(startAt, startAt.add(const Duration(minutes: kSlotStepMinutes)));

  Map<String, dynamic> toMap() => {
        if (timeOffId != null) 'timeOffId': timeOffId else 'bookingId': bookingId,
        'startAt': startAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  factory SlotLock.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parse(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
    final start = (parse(map['startAt']) ?? slotLockStartUtc(id) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)).toUtc();
    final timeOffId = map['timeOffId'];
    return SlotLock(
      id: id,
      bookingId: map['bookingId'] as String? ?? '',
      timeOffId: timeOffId is String && timeOffId.isNotEmpty ? timeOffId : null,
      startAt: start,
      // Locks written before expiresAt existed: a day after the block.
      expiresAt: parse(map['expiresAt']) ?? start.add(kSlotLockRetention),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

/// The lock id (`yyyyMMdd-HHmm`, Addis wall clock) of the block starting at
/// [blockStartUtc].
String slotLockId(DateTime blockStartUtc) {
  final t = toAddisWallClock(blockStartUtc);
  return '${t.year}${_two(t.month)}${_two(t.day)}-${_two(t.hour)}${_two(t.minute)}';
}

/// Parses a lock id back to its UTC block start (null if malformed).
DateTime? slotLockStartUtc(String id) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})$').firstMatch(id);
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  return addisLocalToUtc(g(1), g(2), g(3), g(4), g(5));
}

/// UTC starts of every 15-minute block that `[startUtc, endUtc)` touches.
/// Addis is a whole number of hours from UTC, so the grid is the same in
/// both. An appointment that is not on the grid locks the partial blocks too.
List<DateTime> slotBlocksFor(DateTime startUtc, DateTime endUtc) {
  final start = startUtc.toUtc();
  final end = endUtc.toUtc();
  const stepMs = kSlotStepMinutes * 60 * 1000;
  var blockMs = start.millisecondsSinceEpoch - start.millisecondsSinceEpoch % stepMs;
  final blocks = <DateTime>[];
  // A zero-length appointment still holds its starting block.
  do {
    blocks.add(DateTime.fromMillisecondsSinceEpoch(blockMs, isUtc: true));
    blockMs += stepMs;
  } while (blockMs < end.millisecondsSinceEpoch);
  return blocks;
}

/// Lock ids for every block of `[startUtc, endUtc)`.
List<String> slotLockIdsFor(DateTime startUtc, DateTime endUtc) =>
    slotBlocksFor(startUtc, endUtc).map(slotLockId).toList();

/// The slot-lock documents a booking creates (one per block it covers).
List<SlotLock> slotLocksForBooking(Booking booking) => [
      for (final block in slotBlocksFor(booking.startAt, booking.endAt))
        SlotLock(
          id: slotLockId(block),
          bookingId: booking.id,
          startAt: block,
          expiresAt: booking.endAt.toUtc().add(kSlotLockRetention),
        ),
    ];

/// True when two bookings would hold a common slot lock (the same rule the
/// Firestore transaction enforces).
bool bookingsConflict(Booking a, Booking b) {
  if (a.barberId != b.barberId || a.shopId != b.shopId) return false;
  final blocksA = slotLockIdsFor(a.startAt, a.endAt).toSet();
  return slotLockIdsFor(b.startAt, b.endAt).any(blocksA.contains);
}

/// Bookings that still occupy the barber's time (anything not cancelled;
/// no-show and completed bookings keep their locks until they expire).
bool occupiesSlot(Booking b) => b.status != BookingStatus.cancelled;

/// Busy intervals for [barberId] from the bookings the caller can see.
/// Intervals are widened to whole lock blocks so the client matches the
/// server's check exactly. [excludeBookingId] leaves one booking out (the
/// booking being rescheduled may move into its own blocks).
List<BusyInterval> busyIntervalsFromBookings(Iterable<Booking> bookings, String barberId, {String? excludeBookingId}) {
  final out = <BusyInterval>[];
  for (final b in bookings) {
    if (b.barberId != barberId || !occupiesSlot(b) || b.id == excludeBookingId) continue;
    final blocks = slotBlocksFor(b.startAt, b.endAt);
    out.add(BusyInterval(blocks.first, blocks.last.add(const Duration(minutes: kSlotStepMinutes))));
  }
  return out;
}

/// A barber's effective schedule: their own days/hours where set, limited
/// to the shop's.
class WorkingSchedule {
  const WorkingSchedule({required this.days, required this.startHour, required this.endHour});

  /// 1 = Mon ... 7 = Sun.
  final Set<int> days;

  /// Addis local hours, `[startHour, endHour)`; endHour may be 24.
  final int startHour;
  final int endHour;

  bool get isEmpty => days.isEmpty || endHour <= startHour;

  factory WorkingSchedule.of(Barbershop shop, Barber barber) {
    final shopDays = shop.workingDays.toSet();
    final days = barber.workingDays == null ? shopDays : barber.workingDays!.toSet().intersection(shopDays);
    final start = barber.startHour == null || barber.startHour! < shop.openingHour ? shop.openingHour : barber.startHour!;
    final end = barber.endHour == null || barber.endHour! > shop.closingHour ? shop.closingHour : barber.endHour!;
    return WorkingSchedule(days: days, startHour: start.clamp(0, 24), endHour: end.clamp(0, 24));
  }

  bool worksOn(DateTime addisDate) => days.contains(DateTime.utc(addisDate.year, addisDate.month, addisDate.day).weekday);
}

/// The Addis calendar date of [nowUtc], as `DateTime(y, m, d)`.
DateTime addisToday([DateTime? nowUtc]) {
  final t = addisNow(nowUtc);
  return DateTime(t.year, t.month, t.day);
}

/// The next [count] Addis dates starting today, as `DateTime(y, m, d)`.
List<DateTime> upcomingAddisDates({DateTime? nowUtc, int count = kMaxBookingDaysAhead}) {
  final today = addisToday(nowUtc);
  return [for (var i = 0; i < count; i++) DateTime(today.year, today.month, today.day + i)];
}

/// Whether [addisDate] can be picked in the booking calendar: within the
/// booking window and a working day for the barber at this shop. (It may
/// still have no free slot left.)
bool isBookableDate({
  required Barbershop shop,
  required Barber barber,
  required DateTime addisDate,
  DateTime? nowUtc,
  int maxDaysAhead = kMaxBookingDaysAhead,
}) {
  if (shop.isSuspended || !barber.isAvailable) return false;
  final today = addisToday(nowUtc);
  final day = DateTime(addisDate.year, addisDate.month, addisDate.day);
  final offset = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (offset < 0 || offset >= maxDaysAhead) return false;
  final schedule = WorkingSchedule.of(shop, barber);
  return !schedule.isEmpty && schedule.worksOn(day);
}

/// Free appointment start times (UTC) for [barber] at [shop] on the Addis
/// calendar day [addisDate], for a service of [durationMinutes].
///
/// A start time is offered when it is on the 15-minute grid, the whole
/// service fits before the barber's/shop's closing time, it is at least
/// [leadTime] after [nowUtc], it does not overlap any [busy] interval, the
/// day is a working day within [maxDaysAhead], the shop is not suspended and
/// the barber is available.
List<DateTime> availableSlotStarts({
  required Barbershop shop,
  required Barber barber,
  required int durationMinutes,
  required DateTime addisDate,
  Iterable<BusyInterval> busy = const [],
  DateTime? nowUtc,
  Duration leadTime = kBookingLeadTime,
  int maxDaysAhead = kMaxBookingDaysAhead,
}) {
  final now = (nowUtc ?? DateTime.now()).toUtc();
  if (!isBookableDate(shop: shop, barber: barber, addisDate: addisDate, nowUtc: now, maxDaysAhead: maxDaysAhead)) {
    return const [];
  }
  final schedule = WorkingSchedule.of(shop, barber);
  final duration = Duration(minutes: durationMinutes <= 0 ? kSlotStepMinutes : durationMinutes);
  final open = addisLocalToUtc(addisDate.year, addisDate.month, addisDate.day, schedule.startHour);
  final close = addisLocalToUtc(addisDate.year, addisDate.month, addisDate.day).add(Duration(hours: schedule.endHour));
  final earliest = now.add(leadTime);
  final busyList = busy.toList();

  final slots = <DateTime>[];
  for (var start = open; !start.add(duration).isAfter(close); start = start.add(const Duration(minutes: kSlotStepMinutes))) {
    if (start.isBefore(earliest)) continue;
    final end = start.add(duration);
    if (busyList.any((b) => b.overlaps(start, end))) continue;
    slots.add(start);
  }
  return slots;
}

/// Whether a specific appointment `[startUtc, startUtc + durationMinutes)`
/// is still offered by [availableSlotStarts].
bool isSlotAvailable({
  required Barbershop shop,
  required Barber barber,
  required int durationMinutes,
  required DateTime startUtc,
  Iterable<BusyInterval> busy = const [],
  DateTime? nowUtc,
}) {
  final day = toAddisWallClock(startUtc);
  return availableSlotStarts(
    shop: shop,
    barber: barber,
    durationMinutes: durationMinutes,
    addisDate: DateTime(day.year, day.month, day.day),
    busy: busy,
    nowUtc: nowUtc,
  ).contains(startUtc.toUtc());
}

/// UTC bounds `[start, end)` of an Addis calendar day.
(DateTime, DateTime) addisDayBoundsUtc(DateTime addisDate) {
  final start = addisLocalToUtc(addisDate.year, addisDate.month, addisDate.day);
  return (start, start.add(const Duration(days: 1)));
}
