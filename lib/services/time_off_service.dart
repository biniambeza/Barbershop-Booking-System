/// Barber time off: validation, the slot locks a time-off range holds,
/// conflict checks and permissions. Pure (no Firebase, no clock reads), so
/// both [DataStore] implementations, the schedule screen and the tests share
/// it.
///
/// A time-off range is `barbershops/{s}/barbers/{b}/timeOff/{id}` with
/// `startAt`/`endAt` on the 15-minute grid, within one Addis calendar day.
/// It is written in ONE batch together with a slot lock
/// `{timeOffId, startAt, expiresAt}` for every 15-minute block of
/// `[startAt, endAt)` (expiresAt = endAt + [kSlotLockRetention]). The lock
/// ids are the same `yyyyMMdd-HHmm` ids bookings use, so a time-off range
/// and a booking can never hold the same block: a collision makes the
/// batch fail (locks are never updated). "Whole day" is the barber's working
/// hours on that day (at most 96 blocks, usually around 40).
library;

import 'dart:convert';

import '../data/addis_time.dart';
import '../models/app_exception.dart';
import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/time_off_model.dart';
import '../models/user_model.dart';
import 'availability_service.dart';

export '../models/time_off_model.dart';

bool _onGrid(DateTime t) {
  final u = t.toUtc();
  return u.minute % kSlotStepMinutes == 0 && u.second == 0 && u.millisecond == 0 && u.microsecond == 0;
}

/// Throws an [AppException] unless `[startUtc, endUtc)` is a valid new
/// time-off range at [nowUtc]: on the 15-minute grid, end after start,
/// within one Addis calendar day (the end may be that day's midnight),
/// ending in the future, and a note of at most [kMaxTimeOffReasonLength].
void validateTimeOff({
  required DateTime startUtc,
  required DateTime endUtc,
  String? reason,
  required DateTime nowUtc,
}) {
  final start = startUtc.toUtc();
  final end = endUtc.toUtc();
  if (!_onGrid(start) || !_onGrid(end) || !end.isAfter(start)) {
    throw AppFormatException(AppErrorCode.timeOffInvalidRange);
  }
  final day = toAddisWallClock(start);
  final (_, dayEnd) = addisDayBoundsUtc(DateTime(day.year, day.month, day.day));
  if (end.isAfter(dayEnd)) throw AppFormatException(AppErrorCode.timeOffInvalidRange);
  if (!end.isAfter(nowUtc.toUtc())) throw AppFormatException(AppErrorCode.timeOffInPast);
  if (reason != null && reason.length > kMaxTimeOffReasonLength) {
    throw AppFormatException(AppErrorCode.timeOffReasonTooLong, [kMaxTimeOffReasonLength]);
  }
}

/// The slot locks a time-off range creates (one per 15-minute block).
List<SlotLock> slotLocksForTimeOff(TimeOff timeOff) => [
      for (final block in slotBlocksFor(timeOff.startAt, timeOff.endAt))
        SlotLock(
          id: slotLockId(block),
          timeOffId: timeOff.id,
          startAt: block,
          expiresAt: timeOff.endAt.toUtc().add(kSlotLockRetention),
        ),
    ];

/// Lock ids of a time-off range.
List<String> timeOffLockIds(TimeOff timeOff) => slotLockIdsFor(timeOff.startAt, timeOff.endAt);

/// The "whole day" range of [barber] on the Addis date [addisDate]: their
/// working hours that day (within the shop's), or null on a day off.
(DateTime, DateTime)? wholeDayTimeOffRange(Barbershop shop, Barber barber, DateTime addisDate) {
  final schedule = WorkingSchedule.of(shop, barber);
  if (schedule.isEmpty || !schedule.worksOn(addisDate)) return null;
  final midnight = addisLocalToUtc(addisDate.year, addisDate.month, addisDate.day);
  return (midnight.add(Duration(hours: schedule.startHour)), midnight.add(Duration(hours: schedule.endHour)));
}

/// `[from, to)` on the Addis date [addisDate], from wall-clock minutes of
/// the day (`to` may be 24 * 60 = midnight).
(DateTime, DateTime) timeOffRangeOnDay(DateTime addisDate, int fromMinuteOfDay, int toMinuteOfDay) {
  final midnight = addisLocalToUtc(addisDate.year, addisDate.month, addisDate.day);
  return (midnight.add(Duration(minutes: fromMinuteOfDay)), midnight.add(Duration(minutes: toMinuteOfDay)));
}

/// Whether [timeOff] shares a 15-minute block with a live booking of the
/// same barber, another time-off range, or any of [locks] (Firestore: the
/// day's locks, which also cover bookings the caller cannot see).
bool timeOffConflicts(
  TimeOff timeOff, {
  Iterable<Booking> bookings = const [],
  Iterable<TimeOff> otherTimeOff = const [],
  Iterable<SlotLock> locks = const [],
}) {
  final ids = timeOffLockIds(timeOff).toSet();
  for (final b in bookings) {
    if (b.shopId != timeOff.shopId || b.barberId != timeOff.barberId || !occupiesSlot(b)) continue;
    if (slotLockIdsFor(b.startAt, b.endAt).any(ids.contains)) return true;
  }
  for (final t in otherTimeOff) {
    if (t.id == timeOff.id || t.shopId != timeOff.shopId || t.barberId != timeOff.barberId) continue;
    if (timeOffLockIds(t).any(ids.contains)) return true;
  }
  return locks.any((l) => ids.contains(l.id) && l.timeOffId != timeOff.id);
}

/// Busy intervals (for [availableSlotStarts]) from time-off ranges of
/// [barberId], widened to whole lock blocks.
List<BusyInterval> busyIntervalsFromTimeOff(Iterable<TimeOff> timeOff, String barberId) => [
      for (final t in timeOff)
        if (t.barberId == barberId)
          BusyInterval(
            slotBlocksFor(t.startAt, t.endAt).first,
            slotBlocksFor(t.startAt, t.endAt).last.add(const Duration(minutes: kSlotStepMinutes)),
          ),
    ];

/// The shop's owner and the barber themself manage a barber's time off.
bool canManageTimeOff(AppUser? user, Barber barber) {
  if (user == null) return false;
  switch (user.role) {
    case UserRole.barbershopOwner:
      return user.shopId == barber.shopId;
    case UserRole.barber:
      return user.barberId == barber.id && user.shopId == barber.shopId;
    case UserRole.admin:
    case UserRole.customer:
      return false;
  }
}

/// Time-off entries of the demo dataset (`timeOff` in
/// assets/seed/addis_seed.json): `dayOffset` (0 = today in Addis) plus
/// `startTime`/`endTime` (Addis wall clock, 24h). tool/seed/seed.js writes
/// the same entries, with their locks, to Firestore.
List<TimeOff> timeOffFromSeedJson(String json, {DateTime? now}) {
  final nowUtc = (now ?? DateTime.now()).toUtc();
  final data = jsonDecode(json);
  if (data is! Map<String, dynamic>) return const [];
  final today = addisNow(nowUtc);
  final out = <TimeOff>[];
  for (final raw in (data['timeOff'] as List<dynamic>? ?? const [])) {
    if (raw is! Map<String, dynamic>) continue;
    final from = parseTimeSlot(raw['startTime'] as String? ?? '');
    final to = parseTimeSlot(raw['endTime'] as String? ?? '');
    if (from == null || to == null) continue;
    final day = DateTime.utc(today.year, today.month, today.day).add(Duration(days: (raw['dayOffset'] as num? ?? 0).toInt()));
    final (start, end) = timeOffRangeOnDay(day, from.$1 * 60 + from.$2, to.$1 * 60 + to.$2);
    out.add(TimeOff(
      id: raw['id'] as String,
      shopId: raw['shopId'] as String,
      barberId: raw['barberId'] as String,
      startAt: start,
      endAt: end,
      reason: raw['reason'] as String?,
      createdBy: raw['createdBy'] as String? ?? '',
      createdAt: nowUtc.subtract(Duration(hours: (raw['createdHoursAgo'] as num? ?? 0).toInt())),
    ));
  }
  return out;
}
