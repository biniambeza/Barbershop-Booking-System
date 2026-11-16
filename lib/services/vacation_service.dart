/// Barber vacations: time off from one Addis date to another (inclusive).
/// Pure (no Firebase, no clock reads), shared by the repository, the
/// schedule screen and the tests.
///
/// Storage: a vacation is NOT one big document. Each working day of the
/// range becomes an ordinary time-off document
/// (`barbershops/{s}/barbers/{b}/timeOff/{id}`, see time_off_service.dart)
/// with its own slot locks, written in its own batch exactly like a
/// single-day time off. The parts share `groupId` plus the vacation's
/// first/last Addis dates `groupFrom`/`groupTo` (`yyyy-MM-dd`), so the app
/// shows them as one item ("12-20 Dec") and deletes them together. Reasons:
///  * a batch holds at most ~96 lock writes before the rules hit their
///    per-request expression budget, so one day per batch is the safe size;
///  * customers never read time-off docs, only the locks, so availability
///    and the booking rules keep working unchanged on the free plan;
///  * older single-day documents (no group fields) read as before.
///
/// Days the barber does not work get no document (nobody can book them).
/// Blocks already held (a booking that is kept, other time off) are left
/// out, which may split a day into several parts.
library;

import '../data/addis_time.dart';
import '../models/app_exception.dart';
import '../models/app_notification.dart';
import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import 'availability_service.dart';
import 'time_off_service.dart';

export '../models/app_notification.dart' show AppNotification;

/// Longest vacation, in calendar days (inclusive of both ends).
const int kMaxVacationDays = 90;

String _two(int v) => v.toString().padLeft(2, '0');

/// `yyyy-MM-dd` of an Addis date (its year/month/day fields).
String addisDateKey(DateTime addisDate) =>
    '${addisDate.year.toString().padLeft(4, '0')}-${_two(addisDate.month)}-${_two(addisDate.day)}';

/// The Addis date named by a `yyyy-MM-dd` key, or null.
DateTime? parseAddisDateKey(String? key) {
  if (key == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final d = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  return addisDateKey(d) == key ? d : null;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Inclusive number of calendar days from [fromDate] to [toDate].
int vacationLengthDays(DateTime fromDate, DateTime toDate) =>
    DateTime.utc(toDate.year, toDate.month, toDate.day)
        .difference(DateTime.utc(fromDate.year, fromDate.month, fromDate.day))
        .inDays +
    1;

/// The Addis dates from [fromDate] to [toDate], inclusive.
List<DateTime> vacationDates(DateTime fromDate, DateTime toDate) {
  final n = vacationLengthDays(fromDate, toDate);
  return [for (var i = 0; i < n; i++) DateTime(fromDate.year, fromDate.month, fromDate.day + i)];
}

/// Throws an [AppException] unless [fromDate]..[toDate] is a valid new
/// vacation at [nowUtc]: the end not before the start, at most
/// [kMaxVacationDays] days, starting today or later (Addis), a note of at
/// most [kMaxTimeOffReasonLength], and partial-day minutes on the
/// 15-minute grid within the day.
void validateVacation({
  required DateTime fromDate,
  required DateTime toDate,
  int? firstDayFromMinute,
  int? lastDayToMinute,
  String? reason,
  required DateTime nowUtc,
}) {
  final from = _dateOnly(fromDate);
  final to = _dateOnly(toDate);
  if (to.isBefore(from)) throw AppFormatException(AppErrorCode.timeOffInvalidRange);
  if (vacationLengthDays(from, to) > kMaxVacationDays) {
    throw AppFormatException(AppErrorCode.vacationTooLong, [kMaxVacationDays]);
  }
  if (from.isBefore(addisToday(nowUtc))) throw AppFormatException(AppErrorCode.timeOffInPast);
  bool badMinute(int? m) => m != null && (m < 0 || m > 24 * 60 || m % kSlotStepMinutes != 0);
  if (badMinute(firstDayFromMinute) || badMinute(lastDayToMinute)) {
    throw AppFormatException(AppErrorCode.timeOffInvalidRange);
  }
  if (from == to && firstDayFromMinute != null && lastDayToMinute != null && lastDayToMinute <= firstDayFromMinute) {
    throw AppFormatException(AppErrorCode.timeOffInvalidRange);
  }
  if (reason != null && reason.length > kMaxTimeOffReasonLength) {
    throw AppFormatException(AppErrorCode.timeOffReasonTooLong, [kMaxTimeOffReasonLength]);
  }
}

/// The time to block on each working day of the vacation: the barber's
/// working hours that day (as "Whole day"), the first day starting no
/// earlier than [firstDayFromMinute] and the last day ending no later than
/// [lastDayToMinute] (Addis minutes of the day) when given. With [nowUtc],
/// time already over is left out (a range starting now begins at the next
/// quarter hour).
List<(DateTime, DateTime)> vacationDayRanges(
  Barbershop shop,
  Barber barber,
  DateTime fromDate,
  DateTime toDate, {
  int? firstDayFromMinute,
  int? lastDayToMinute,
  DateTime? nowUtc,
}) {
  final dates = vacationDates(fromDate, toDate);
  DateTime? floor;
  if (nowUtc != null) {
    final n = nowUtc.toUtc();
    final blocks = slotBlocksFor(n, n.add(const Duration(minutes: 1)));
    floor = blocks.first.isBefore(n) ? blocks.first.add(const Duration(minutes: kSlotStepMinutes)) : blocks.first;
  }
  final out = <(DateTime, DateTime)>[];
  for (var i = 0; i < dates.length; i++) {
    final day = dates[i];
    final whole = wholeDayTimeOffRange(shop, barber, day);
    if (whole == null) continue;
    var (start, end) = whole;
    final midnight = addisLocalToUtc(day.year, day.month, day.day);
    if (i == 0 && firstDayFromMinute != null) {
      final s = midnight.add(Duration(minutes: firstDayFromMinute));
      if (s.isAfter(start)) start = s;
    }
    if (i == dates.length - 1 && lastDayToMinute != null) {
      final e = midnight.add(Duration(minutes: lastDayToMinute));
      if (e.isBefore(end)) end = e;
    }
    if (floor != null && floor.isAfter(start)) start = floor;
    if (end.isAfter(start)) out.add((start, end));
  }
  return out;
}

/// [ranges] minus every 15-minute block whose start is in [takenBlocks]:
/// the maximal runs of free blocks, in order.
List<(DateTime, DateTime)> freeVacationSegments(List<(DateTime, DateTime)> ranges, Set<DateTime> takenBlocks) {
  const step = Duration(minutes: kSlotStepMinutes);
  final out = <(DateTime, DateTime)>[];
  for (final (start, end) in ranges) {
    DateTime? runStart;
    DateTime? runEnd;
    for (final block in slotBlocksFor(start, end)) {
      if (takenBlocks.contains(block)) {
        if (runStart != null) out.add((runStart, runEnd!));
        runStart = null;
        runEnd = null;
      } else {
        runStart ??= block;
        runEnd = block.add(step);
      }
    }
    if (runStart != null) out.add((runStart, runEnd!));
  }
  return out;
}

bool _overlapsAny(DateTime start, DateTime end, List<(DateTime, DateTime)> ranges) =>
    ranges.any((r) => start.isBefore(r.$2) && r.$1.isBefore(end));

/// The barber's upcoming bookings inside the vacation that the owner or
/// barber may cancel (pending or confirmed, not started at [nowUtc]),
/// soonest first. Other bookings in the range (in progress, finished) are
/// always kept: their blocks are simply left out of the vacation.
List<Booking> vacationConflicts(
  Iterable<Booking> bookings, {
  required String shopId,
  required String barberId,
  required List<(DateTime, DateTime)> ranges,
  required DateTime nowUtc,
}) {
  final now = nowUtc.toUtc();
  return bookings
      .where((b) =>
          b.shopId == shopId &&
          b.barberId == barberId &&
          (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) &&
          b.startAt.toUtc().isAfter(now) &&
          _overlapsAny(b.startAt.toUtc(), b.endAt.toUtc(), ranges))
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
}

/// Block starts the vacation must leave alone: every live booking of the
/// barber that is not in [cancelledIds], the [locks] of anyone else (in
/// Firestore they also cover bookings the caller cannot see), and other
/// time off of the barber.
Set<DateTime> vacationTakenBlocks({
  required String shopId,
  required String barberId,
  Iterable<Booking> bookings = const [],
  Set<String> cancelledIds = const {},
  Iterable<SlotLock> locks = const [],
  Iterable<TimeOff> otherTimeOff = const [],
}) {
  final taken = <DateTime>{};
  for (final b in bookings) {
    if (b.shopId != shopId || b.barberId != barberId || !occupiesSlot(b) || cancelledIds.contains(b.id)) continue;
    taken.addAll(slotBlocksFor(b.startAt, b.endAt));
  }
  for (final l in locks) {
    if (!l.isTimeOff && cancelledIds.contains(l.bookingId)) continue;
    taken.add(l.startAt.toUtc());
  }
  for (final t in otherTimeOff) {
    if (t.shopId != shopId || t.barberId != barberId) continue;
    taken.addAll(slotBlocksFor(t.startAt, t.endAt));
  }
  return taken;
}

/// The time-off documents of one vacation (one per free segment), sharing
/// [groupId] and the vacation's dates. [idFor] gives each part's id.
List<TimeOff> buildVacationParts({
  required String groupId,
  required String Function(int index) idFor,
  required String shopId,
  required String barberId,
  required List<(DateTime, DateTime)> segments,
  required DateTime fromDate,
  required DateTime toDate,
  String? reason,
  required String createdBy,
  required DateTime createdAt,
}) {
  final note = reason?.trim();
  return [
    for (var i = 0; i < segments.length; i++)
      TimeOff(
        id: idFor(i),
        shopId: shopId,
        barberId: barberId,
        startAt: segments[i].$1.toUtc(),
        endAt: segments[i].$2.toUtc(),
        reason: note == null || note.isEmpty ? null : note,
        createdBy: createdBy,
        createdAt: createdAt.toUtc(),
        groupId: groupId,
        groupFrom: addisDateKey(fromDate),
        groupTo: addisDateKey(toDate),
      ),
  ];
}

/// One row of the time-off list: a single time-off document, or every
/// loaded part of one vacation.
class TimeOffItem {
  TimeOffItem(List<TimeOff> parts)
      : assert(parts.isNotEmpty),
        parts = List.unmodifiable([...parts]..sort((a, b) => a.startAt.compareTo(b.startAt)));

  final List<TimeOff> parts;

  TimeOff get first => parts.first;
  bool get isVacation => first.isVacationPart;
  String? get groupId => first.groupId;
  String? get reason => first.reason;
  DateTime get startAt => parts.first.startAt;
  DateTime get endAt => parts.map((p) => p.endAt).reduce((a, b) => a.isAfter(b) ? a : b);

  /// The vacation's first / last Addis date (single entries: their day).
  DateTime get fromDate => parseAddisDateKey(first.groupFrom) ?? _dateOnly(toAddisWallClock(startAt));
  DateTime get toDate => parseAddisDateKey(first.groupTo) ?? _dateOnly(toAddisWallClock(startAt));

  /// Whether any part is still running or ahead at [nowUtc].
  bool isUpcoming(DateTime nowUtc) => parts.any((p) => p.endAt.isAfter(nowUtc.toUtc()));
}

/// Groups loaded time off into list rows: vacation parts by `groupId`,
/// every other document on its own. Sorted by start.
List<TimeOffItem> groupTimeOff(Iterable<TimeOff> entries) {
  final groups = <String, List<TimeOff>>{};
  final items = <TimeOffItem>[];
  for (final t in entries) {
    if (t.isVacationPart) {
      groups.putIfAbsent(t.groupId!, () => []).add(t);
    } else {
      items.add(TimeOffItem([t]));
    }
  }
  items.addAll(groups.values.map(TimeOffItem.new));
  items.sort((a, b) => a.startAt.compareTo(b.startAt));
  return items;
}

/// What [AppRepository.addVacation] did.
class VacationResult {
  const VacationResult({required this.parts, required this.cancelled, this.notices = const [], this.noticeFailures = 0});

  /// The time-off documents written.
  final List<TimeOff> parts;

  /// Bookings cancelled for the vacation.
  final List<Booking> cancelled;

  /// Customer notices written (one per cancelled booking).
  final List<AppNotification> notices;

  /// Customer notices that could not be written (the cancel still stands).
  final int noticeFailures;
}

/// Inbox id of the customer's notice for a booking cancelled because of a
/// vacation: the same `{bookingId}_cancelled` id the notifications Cloud
/// Function uses, so on Blaze the customer never gets two entries (the
/// second `create` fails as already existing).
String vacationCancelNoticeId(String bookingId) => '${bookingId}_cancelled';

/// Title and body of that notice, in the customer's language ('am' or
/// anything else = English).
({String title, String body}) renderVacationCancelText(Booking b, {String? language}) {
  final local = toAddisWallClock(b.startAt);
  final when = '${addisDateKey(local)} ${formatTimeSlot(local.hour, local.minute)}';
  if (language == 'am') {
    final shop = b.shopName.isEmpty ? 'Crown & Blade' : b.shopName;
    final barber = b.barberName.isEmpty ? 'ፀጉር አስተካካዩ' : b.barberName;
    final service = b.serviceName.isEmpty ? 'አገልግሎት' : b.serviceName;
    return (
      title: 'ቀጠሮዎ ተሰርዟል',
      body: '$shop ላይ $when የነበረዎት የ$service ቀጠሮ $barber በእረፍት ላይ ስለሚሆኑ ተሰርዟል። እባክዎ ሌላ ጊዜ ይያዙ።',
    );
  }
  final shop = b.shopName.isEmpty ? 'Crown & Blade' : b.shopName;
  final barber = b.barberName.isEmpty ? 'your barber' : b.barberName;
  final service = b.serviceName.isEmpty ? 'service' : b.serviceName;
  return (
    title: 'Booking cancelled',
    body: 'Your $service at $shop on $when was cancelled because $barber will be away. Please book another time.',
  );
}

/// The customer's inbox notice for [b] cancelled at [nowUtc]: exactly
/// `{type: 'cancelled', title, body, bookingId, read: false, createdAt}`.
AppNotification vacationCancelNotice(Booking b, {required DateTime nowUtc, String? language}) {
  final text = renderVacationCancelText(b, language: language);
  return AppNotification(
    id: vacationCancelNoticeId(b.id),
    title: text.title,
    body: text.body,
    type: NotificationTypes.cancelled,
    bookingId: b.id,
    createdAt: nowUtc.toUtc(),
  );
}
