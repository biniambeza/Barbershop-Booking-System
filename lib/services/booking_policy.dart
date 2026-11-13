/// Shop booking policy: cancellation cutoff, reschedule limit and no-show
/// timing. Pure functions (the clock is a parameter) shared by the
/// repository, the screens and the tests; the security rules enforce the
/// same math server-side.
///
/// Boundaries:
///  * A customer may cancel or reschedule while `now <= startAt - cutoff`
///    (exactly `cutoff` hours before the start is still allowed; one second
///    later is not). A cutoff of 0 allows changes until the start.
///  * A booking can be rescheduled while `rescheduleCount < maxReschedules`.
///  * A booking can be marked no-show once `now >= startAt`, while it is
///    still pending or confirmed.
library;

import '../data/addis_time.dart';
import '../models/app_exception.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';

/// Statuses a customer may cancel or reschedule, and staff may mark no-show.
bool isChangeableStatus(BookingStatus s) => s == BookingStatus.pending || s == BookingStatus.confirmed;

/// The latest instant the customer may still cancel or reschedule.
DateTime customerChangeDeadline(Booking booking, Barbershop shop) =>
    booking.startAt.toUtc().subtract(Duration(hours: shop.cancellationCutoffHours));

/// Whether the cutoff still allows a customer change at [nowUtc].
bool isBeforeCutoff(Booking booking, Barbershop shop, DateTime nowUtc) =>
    !nowUtc.toUtc().isAfter(customerChangeDeadline(booking, shop));

/// Reschedules left for this booking (never negative).
int reschedulesLeft(Booking booking, Barbershop shop) {
  final left = shop.maxReschedules - booking.rescheduleCount;
  return left < 0 ? 0 : left;
}

/// Throws unless the customer may cancel [booking] at [nowUtc].
void assertCustomerCanCancel(Booking booking, Barbershop shop, DateTime nowUtc) {
  if (!isChangeableStatus(booking.status)) throw AppStateException(AppErrorCode.bookingNotChangeable);
  if (!isBeforeCutoff(booking, shop, nowUtc)) {
    throw AppStateException(AppErrorCode.cancellationCutoffPassed, [shop.cancellationCutoffHours]);
  }
}

/// Throws unless the customer may reschedule [booking] at [nowUtc].
void assertCanReschedule(Booking booking, Barbershop shop, DateTime nowUtc) {
  if (!isChangeableStatus(booking.status)) throw AppStateException(AppErrorCode.bookingNotChangeable);
  if (!isBeforeCutoff(booking, shop, nowUtc)) {
    throw AppStateException(AppErrorCode.rescheduleCutoffPassed, [shop.cancellationCutoffHours]);
  }
  if (booking.rescheduleCount >= shop.maxReschedules) {
    throw AppStateException(AppErrorCode.rescheduleLimitReached, [shop.maxReschedules]);
  }
}

/// Null when the customer may reschedule now, else the reason.
AppException? rescheduleBlocker(Booking booking, Barbershop shop, DateTime nowUtc) {
  try {
    assertCanReschedule(booking, shop, nowUtc);
    return null;
  } on AppException catch (e) {
    return e;
  }
}

/// Null when the customer may cancel now, else the reason.
AppException? cancelBlocker(Booking booking, Barbershop shop, DateTime nowUtc) {
  try {
    assertCustomerCanCancel(booking, shop, nowUtc);
    return null;
  } on AppException catch (e) {
    return e;
  }
}

/// Whether staff may mark [booking] as a no-show at [nowUtc].
bool canMarkNoShow(Booking booking, DateTime nowUtc) =>
    isChangeableStatus(booking.status) && !nowUtc.toUtc().isBefore(booking.startAt.toUtc());

void assertCanMarkNoShow(Booking booking, DateTime nowUtc) {
  if (!isChangeableStatus(booking.status)) throw AppStateException(AppErrorCode.bookingNotChangeable);
  if (nowUtc.toUtc().isBefore(booking.startAt.toUtc())) throw AppStateException(AppErrorCode.noShowTooEarly);
}

/// The booking as it is after moving it to [newStartUtc]: same barber,
/// service and duration; new interval, display date and slot (Addis time),
/// `rescheduleCount + 1` and `rescheduledAt = nowUtc`.
Booking rescheduledBooking(Booking booking, DateTime newStartUtc, DateTime nowUtc) {
  final start = newStartUtc.toUtc();
  final local = toAddisWallClock(start);
  return booking.copyWith(
    startAt: start,
    endAt: start.add(Duration(minutes: booking.durationMinutes)),
    date: DateTime(local.year, local.month, local.day),
    timeSlot: formatTimeSlot(local.hour, local.minute),
    rescheduleCount: booking.rescheduleCount + 1,
    rescheduledAt: nowUtc.toUtc(),
  );
}

/// Validates owner policy values (same ranges as the rules).
void validatePolicy({required int cancellationCutoffHours, required int maxReschedules}) {
  if (cancellationCutoffHours < 0 || cancellationCutoffHours > kMaxCancellationCutoffHours) {
    throw AppFormatException(AppErrorCode.policyCutoffInvalid, [kMaxCancellationCutoffHours]);
  }
  if (maxReschedules < 0 || maxReschedules > kMaxMaxReschedules) {
    throw AppFormatException(AppErrorCode.policyMaxReschedulesInvalid, [kMaxMaxReschedules]);
  }
}
