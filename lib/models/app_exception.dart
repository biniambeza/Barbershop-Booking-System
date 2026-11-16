/// Typed, translatable errors thrown by the app's services.
///
/// Services throw an [AppException] with an [AppErrorCode] (plus [args] for
/// the placeholders); screens turn it into text in the active language with
/// `context.l10n.errorText(error)` (lib/l10n/labels.dart). The English
/// [message] is only for logs and tests.
///
/// The two concrete classes extend [FormatException] (bad input) and
/// [StateError] (not possible right now), so existing `on FormatException`
/// handlers and `throwsFormatException` / `throwsStateError` matchers keep
/// working.
library;

enum AppErrorCode {
  // --- Sign-in & profile
  invalidPhone,
  invalidEmail,
  invalidOwnerEmail,

  /// The Google account has no verified email address.
  googleEmailMissing,

  /// An email/password account whose email address is not verified.
  emailNotVerified,
  invalidName,
  signInRequired,
  accountLoadFailed,

  /// admin users: an admin disabled this account.
  accountDisabled,

  /// args: [UserRole] of the existing account.
  emailAlreadyStaff,

  // --- Bookings
  signInToBook,
  shopNotTakingBookings,

  /// args: [barber name].
  barberNotTakingBookings,
  invalidTimeSlot,

  /// args: [max minutes].
  serviceTooLong,
  invalidService,
  serverOnly,

  // --- Barber schedule
  noWorkingDays,
  invalidWorkingHours,

  // --- Reschedule, cancellation policy, no-show, time off
  /// Not pending/confirmed any more (cannot cancel, move or mark no-show).
  bookingNotChangeable,

  /// args: [cutoff hours].
  cancellationCutoffPassed,

  /// args: [cutoff hours].
  rescheduleCutoffPassed,

  /// args: [max reschedules].
  rescheduleLimitReached,
  rescheduleSameTime,
  noShowTooEarly,

  /// args: [max hours].
  policyCutoffInvalid,

  /// args: [max reschedules].
  policyMaxReschedulesInvalid,
  timeOffInvalidRange,
  timeOffInPast,

  /// args: [max characters].
  timeOffReasonTooLong,
  timeOffConflict,
  timeOffNotAllowed,

  // --- vacation (several days of time off)
  /// args: [max days].
  vacationTooLong,

  /// The range has no working time left to block.
  vacationNothingToBlock,

  // --- barber acceptance
  /// Only the booked barber, the shop owner or an admin may answer a request.
  bookingRequestNotAllowed,

  /// args: [max characters].
  declineReasonTooLong,

  // --- barber cancel
  /// Only the booked barber can cancel from the barber dashboard.
  barberCancelNotAllowed,

  /// The appointment already started: mark it no-show or finish it.
  barberCancelAfterStart,

  // --- Subscription plans
  /// args: [comma-separated plan ids].
  planIdInvalid,
  planNameRequired,
  planPriceNegative,
  planPriceRequired,
  planMaxBarbersInvalid;

  /// English text, for logs and tests (the UI uses the ARB strings).
  String englishMessage(List<Object?> args) {
    String arg(int i) => i < args.length ? '${args[i] is Enum ? (args[i] as Enum).name : args[i]}' : '';
    switch (this) {
      case AppErrorCode.invalidPhone:
        return 'Enter a valid Ethiopian mobile number (09... or 07...).';
      case AppErrorCode.invalidEmail:
        return 'Enter a valid email address.';
      case AppErrorCode.invalidOwnerEmail:
        return 'Enter a valid Gmail / email address for the owner.';
      case AppErrorCode.googleEmailMissing:
        return 'Your Google account has no verified email address.';
      case AppErrorCode.emailNotVerified:
        return 'Please verify your email first. Open the link we emailed you, then log in.';
      case AppErrorCode.invalidName:
        return 'Enter your name (up to 100 characters).';
      case AppErrorCode.signInRequired:
        return 'Sign in first.';
      case AppErrorCode.accountLoadFailed:
        return 'Could not load your account. Check your connection and try again.';
      case AppErrorCode.accountDisabled: // admin users
        return 'Your account has been disabled. Contact support.';
      case AppErrorCode.emailAlreadyStaff:
        return 'This email address already belongs to a ${arg(0)} account.';
      case AppErrorCode.signInToBook:
        return 'Sign in to book an appointment.';
      case AppErrorCode.shopNotTakingBookings:
        return 'This barbershop is not taking bookings right now.';
      case AppErrorCode.barberNotTakingBookings:
        return '${arg(0)} is not taking bookings right now.';
      case AppErrorCode.invalidTimeSlot:
        return 'Unrecognised time slot.';
      case AppErrorCode.serviceTooLong:
        return 'A service can be at most ${arg(0)} minutes long.';
      case AppErrorCode.invalidService:
        return 'Enter a name, a price and a duration for the service.';
      case AppErrorCode.serverOnly:
        return 'This is recorded by the server.';
      case AppErrorCode.noWorkingDays:
        return 'Pick at least one working day.';
      case AppErrorCode.invalidWorkingHours:
        return 'The end time must be after the start time.';
      case AppErrorCode.bookingNotChangeable:
        return 'This booking can no longer be changed.';
      case AppErrorCode.cancellationCutoffPassed:
        return 'Bookings can only be cancelled up to ${arg(0)} hours before the start.';
      case AppErrorCode.rescheduleCutoffPassed:
        return 'Bookings can only be moved up to ${arg(0)} hours before the start.';
      case AppErrorCode.rescheduleLimitReached:
        return 'This booking has already been moved the maximum of ${arg(0)} times.';
      case AppErrorCode.rescheduleSameTime:
        return 'Pick a different time.';
      case AppErrorCode.noShowTooEarly:
        return 'A booking can only be marked as a no-show after its start time.';
      case AppErrorCode.policyCutoffInvalid:
        return 'The cancellation cutoff must be between 0 and ${arg(0)} hours.';
      case AppErrorCode.policyMaxReschedulesInvalid:
        return 'Reschedules allowed must be between 0 and ${arg(0)}.';
      case AppErrorCode.timeOffInvalidRange:
        return 'Pick a time-off range within one day, with the end after the start.';
      case AppErrorCode.timeOffInPast:
        return 'Time off must end in the future.';
      case AppErrorCode.timeOffReasonTooLong:
        return 'The note can be at most ${arg(0)} characters.';
      case AppErrorCode.timeOffConflict:
        return 'This time overlaps a booking or other time off.';
      case AppErrorCode.timeOffNotAllowed:
        return 'You can only manage time off for your own schedule.';
      // --- vacation
      case AppErrorCode.vacationTooLong:
        return 'A vacation can be at most ${arg(0)} days long.';
      case AppErrorCode.vacationNothingToBlock:
        return 'There are no working hours to block in these days.';
      // --- barber acceptance
      case AppErrorCode.bookingRequestNotAllowed:
        return 'Only the booked barber or the shop owner can answer this request.';
      case AppErrorCode.declineReasonTooLong:
        return 'The reason can be at most ${arg(0)} characters.';
      case AppErrorCode.barberCancelNotAllowed:
        return 'You can only cancel your own bookings.';
      case AppErrorCode.barberCancelAfterStart:
        return 'This appointment has already started. Mark it as a no-show or finish it instead.';
      case AppErrorCode.planIdInvalid:
        return 'Plan id must be one of ${arg(0)}.';
      case AppErrorCode.planNameRequired:
        return 'Plan name is required.';
      case AppErrorCode.planPriceNegative:
        return 'Price must be 0 or more.';
      case AppErrorCode.planPriceRequired:
        return 'A paid plan needs a price above 0.';
      case AppErrorCode.planMaxBarbersInvalid:
        return 'Max barbers must be at least 1 (or -1 for unlimited).';
    }
  }
}

/// Common interface of [AppFormatException] and [AppStateException].
abstract interface class AppException implements Exception {
  AppErrorCode get code;
  List<Object?> get args;
}

/// Invalid input (extends [FormatException]).
class AppFormatException extends FormatException implements AppException {
  AppFormatException(this.code, [this.args = const []]) : super(code.englishMessage(args));

  @override
  final AppErrorCode code;
  @override
  final List<Object?> args;
}

/// Not possible in the current state (extends [StateError]).
class AppStateException extends StateError implements AppException {
  AppStateException(this.code, [this.args = const []]) : super(code.englishMessage(args));

  @override
  final AppErrorCode code;
  @override
  final List<Object?> args;
}
