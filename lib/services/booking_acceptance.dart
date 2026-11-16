/// Barber acceptance of booking requests: pure rules shared by the
/// repository, the dashboards and the tests.
///
/// When a shop has `requireBarberAcceptance`, new customer bookings are
/// created 'pending' (their slot locks are taken as usual, so the time stays
/// reserved). The booked barber, the shop owner or an admin then:
///  * accepts:  status 'confirmed' + acceptedAt (UTC ISO);
///  * declines: status 'cancelled' + cancelledBy 'barber' + declineReason?
///    and the booking's own slot locks are released (as a cancel does).
/// Requests still pending [kPendingExpiryLead] before the start are cancelled
/// by the `expirePendingBookings` function (functions/bookings) with
/// cancelledBy 'system' and cancelReason [kNotAcceptedReason].
library;

import '../models/app_exception.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';

/// Longest note a barber may give when declining (the rules check the same).
const int kMaxDeclineReasonLength = 200;

/// Unanswered requests expire this long before their start
/// (functions/bookings `PENDING_EXPIRY_LEAD_MINUTES`).
const Duration kPendingExpiryLead = Duration(minutes: 60);

/// cancelReason of a request that expired unanswered (written by the server).
const String kNotAcceptedReason = 'not_accepted';

/// cancelledBy of a declined request (a role literal, not a uid).
const String kDeclinedBy = 'barber';

/// Status a new customer booking at [shop] is created with.
BookingStatus initialBookingStatus(Barbershop? shop) =>
    shop?.requireBarberAcceptance == true ? BookingStatus.pending : BookingStatus.confirmed;

/// True once a pending request is inside the expiry window (or its start has
/// passed): it can no longer be accepted and the server will cancel it.
bool isRequestExpired(Booking booking, DateTime nowUtc) =>
    !booking.startAt.isAfter(nowUtc.toUtc().add(kPendingExpiryLead));

/// A pending booking that can still be accepted.
bool isOpenRequest(Booking booking, DateTime nowUtc) =>
    booking.status == BookingStatus.pending && !isRequestExpired(booking, nowUtc);

/// Open requests of one barber, soonest first.
List<Booking> openRequestsForBarber(Iterable<Booking> bookings, String barberId, DateTime nowUtc) =>
    bookings.where((b) => b.barberId == barberId && isOpenRequest(b, nowUtc)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

/// Open requests of one shop, soonest first.
List<Booking> openRequestsForShop(Iterable<Booking> bookings, String shopId, DateTime nowUtc) =>
    bookings.where((b) => b.shopId == shopId && isOpenRequest(b, nowUtc)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

/// The booked barber, the owner of the booking's shop, or an admin.
bool canRespondToRequest(AppUser? user, Booking booking) {
  if (user == null) return false;
  switch (user.role) {
    case UserRole.admin:
      return true;
    case UserRole.barbershopOwner:
      return user.shopId != null && user.shopId == booking.shopId;
    case UserRole.barber:
      return user.barberId != null && user.barberId == booking.barberId && user.shopId == booking.shopId;
    case UserRole.customer:
      return false;
  }
}

/// Trimmed reason, or null when blank. Throws [AppFormatException]
/// ([AppErrorCode.declineReasonTooLong]) when longer than
/// [kMaxDeclineReasonLength].
String? normalizeDeclineReason(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length > kMaxDeclineReasonLength) {
    throw AppFormatException(AppErrorCode.declineReasonTooLong, [kMaxDeclineReasonLength]);
  }
  return text;
}

/// Throws unless [user] may answer [booking] now: [AppErrorCode.bookingRequestNotAllowed]
/// for anyone but the barber/owner/admin, [AppErrorCode.bookingNotChangeable]
/// when it is no longer pending (or, for an accept, already expired).
void assertCanRespond(AppUser? user, Booking booking, DateTime nowUtc, {required bool accept}) {
  if (!canRespondToRequest(user, booking)) throw AppStateException(AppErrorCode.bookingRequestNotAllowed);
  if (booking.status != BookingStatus.pending) throw AppStateException(AppErrorCode.bookingNotChangeable);
  if (accept && isRequestExpired(booking, nowUtc)) throw AppStateException(AppErrorCode.bookingNotChangeable);
}

/// The fields an accept writes (and nothing else).
Map<String, dynamic> acceptFields(DateTime nowUtc) => {
      'status': BookingStatus.confirmed.name,
      'acceptedAt': nowUtc.toUtc().toIso8601String(),
    };

/// The fields a decline writes (and nothing else). [reason] must already be
/// normalized ([normalizeDeclineReason]).
Map<String, dynamic> declineFields(String? reason) => {
      'status': BookingStatus.cancelled.name,
      'cancelledBy': kDeclinedBy,
      if (reason != null) 'declineReason': reason,
    };

/// A request the barber declined (not one the staff app closed because it
/// expired, see [isClientExpiredClose]).
bool wasDeclined(Booking booking) =>
    booking.status == BookingStatus.cancelled && booking.cancelledBy == kDeclinedBy && !isClientExpiredClose(booking);

/// A request that expired unanswered: cancelled by functions/bookings
/// (cancelReason [kNotAcceptedReason]) or, on the free plan, closed by the
/// staff app ([isClientExpiredClose]).
bool wasNotAccepted(Booking booking) =>
    booking.status == BookingStatus.cancelled &&
    (booking.cancelReason == kNotAcceptedReason || isClientExpiredClose(booking));

// --- free plan: the staff app closes expired requests (no Cloud Functions) ---
//
// `expirePendingBookings` (functions/bookings, every 15 minutes) does not run
// on the Spark plan. The barber/owner app closes the expired requests it
// sees with the existing decline write (no security-rule change): status
// 'cancelled', cancelledBy 'barber', declineReason [kNotAcceptedReason] (the
// marker), slot locks released. It waits [kClientExpiryGrace] longer than the
// function, so on the Blaze plan the function always goes first.

/// Extra wait before the staff app closes an expired request itself.
const Duration kClientExpiryGrace = Duration(minutes: 15);

/// A pending request inside the expiry window that nobody closed yet: the
/// customer is told the barber didn't answer; it can no longer be accepted.
bool isUnansweredExpiredRequest(Booking booking, DateTime nowUtc) =>
    booking.status == BookingStatus.pending && isRequestExpired(booking, nowUtc);

/// Whether the staff app should close this request now (pending and its
/// start within `kPendingExpiryLead - kClientExpiryGrace`, or past).
bool shouldClientCloseExpiredRequest(Booking booking, DateTime nowUtc) =>
    booking.status == BookingStatus.pending &&
    !booking.startAt.isAfter(nowUtc.toUtc().add(kPendingExpiryLead - kClientExpiryGrace));

/// A request the staff app closed because it expired (decline + marker).
bool isClientExpiredClose(Booking booking) =>
    booking.status == BookingStatus.cancelled &&
    booking.cancelledBy == kDeclinedBy &&
    booking.declineReason == kNotAcceptedReason;
// --- end free plan ---

/// Online payment waits until the barber accepts (pending bookings may still
/// be declined or expire).
bool isAwaitingAcceptance(Booking booking) => booking.status == BookingStatus.pending;
