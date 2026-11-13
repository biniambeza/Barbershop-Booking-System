/// Time helpers for Addis Ababa (East Africa Time, UTC+3, no daylight saving).
///
/// Appointment intervals are stored as UTC instants (`startAt`/`endAt`,
/// ISO-8601 with `Z`). Opening hours, time slots and slot-lock ids are in
/// Addis local wall-clock time. These helpers convert between the two without
/// depending on the device's time zone.
library;

/// Addis Ababa's fixed offset from UTC.
const Duration kAddisUtcOffset = Duration(hours: 3);

/// The current wall-clock time in Addis Ababa, as a UTC-flagged [DateTime]
/// whose fields (year, month, day, hour, ...) read as Addis local time.
DateTime addisNow([DateTime? nowUtc]) => (nowUtc ?? DateTime.now()).toUtc().add(kAddisUtcOffset);

/// Converts a UTC instant to Addis wall-clock fields (see [addisNow]).
DateTime toAddisWallClock(DateTime instant) => instant.toUtc().add(kAddisUtcOffset);

/// The UTC instant for an Addis wall-clock date and time.
DateTime addisLocalToUtc(int year, int month, int day, [int hour = 0, int minute = 0]) {
  return DateTime.utc(year, month, day, hour, minute).subtract(kAddisUtcOffset);
}

/// Parses a display slot such as `'02:30 PM'`, `'2:30 pm'` or `'14:30'`.
/// Returns `(hour, minute)` in 24-hour form, or null if unparseable.
(int, int)? parseTimeSlot(String slot) {
  final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$').firstMatch(slot);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (minute > 59) return null;
  if (period != null) {
    if (hour < 1 || hour > 12) return null;
    if (period == 'AM' && hour == 12) hour = 0;
    if (period == 'PM' && hour != 12) hour += 12;
  } else if (hour > 23) {
    return null;
  }
  return (hour, minute);
}

/// Formats 24-hour fields as the app's display slot, e.g. `'02:30 PM'`.
String formatTimeSlot(int hour, int minute) {
  final period = hour < 12 ? 'AM' : 'PM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}

/// The UTC start instant of an appointment on the calendar day of [date]
/// (its year/month/day fields are used as the Addis date) at [timeSlot].
/// Returns null if [timeSlot] cannot be parsed.
DateTime? appointmentStartUtc(DateTime date, String timeSlot) {
  final parsed = parseTimeSlot(timeSlot);
  if (parsed == null) return null;
  return addisLocalToUtc(date.year, date.month, date.day, parsed.$1, parsed.$2);
}
