import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_exception.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/payment_model.dart';
import '../models/plan_model.dart';
import '../models/user_model.dart';
import '../services/availability_service.dart' show SlotTakenException;
import '../services/email_auth_service.dart' show EmailAuthErrorCode, EmailAuthException;
import '../services/payment_service.dart' show PaymentErrorReason, PaymentException;
import 'gen/app_localizations.dart';

/// Amharic names of Addis Ababa's sub-cities (data values stay English).
const Map<String, String> kSubCityNamesAm = {
  'Addis Ababa': 'አዲስ አበባ',
  'Addis Ketema': 'አዲስ ከተማ',
  'Akaky Kaliti': 'አቃቂ ቃሊቲ',
  'Arada': 'አራዳ',
  'Bole': 'ቦሌ',
  'Gullele': 'ጉለሌ',
  'Kirkos': 'ቂርቆስ',
  'Kolfe Keranio': 'ኮልፌ ቀራንዮ',
  'Lemi Kura': 'ለሚ ኩራ',
  'Lideta': 'ልደታ',
  'Nifas Silk-Lafto': 'ንፋስ ስልክ ላፍቶ',
  'Yeka': 'የካ',
};

/// Display labels for model enums and place names.
extension AppLabels on AppLocalizations {
  bool get isAmharic => localeName.startsWith('am');

  /// Sub-city or city name in the active language.
  String placeName(String name) => isAmharic ? (kSubCityNamesAm[name] ?? name) : name;

  /// Street address, sub-city and city, with place names translated.
  String shopAddress(Barbershop shop) {
    final parts = [
      shop.address,
      if (shop.subCity.isNotEmpty) placeName(shop.subCity),
      placeName(shop.city),
    ].where((p) => p.isNotEmpty);
    return parts.join(isAmharic ? '፣ ' : ', ');
  }

  /// The sub-city (or city) shown on shop cards.
  String shopArea(Barbershop shop) => placeName(shop.subCity.isNotEmpty ? shop.subCity : shop.city);

  String roleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return roleAdmin;
      case UserRole.barbershopOwner:
        return roleOwner;
      case UserRole.barber:
        return roleBarber;
      case UserRole.customer:
        return roleCustomer;
    }
  }

  String bookingStatus(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return statusPending;
      case BookingStatus.confirmed:
        return statusConfirmed;
      case BookingStatus.inProgress:
        return statusInProgress;
      case BookingStatus.completed:
        return statusCompleted;
      case BookingStatus.cancelled:
        return statusCancelled;
      case BookingStatus.noShow:
        return statusNoShow;
    }
  }

  String subscriptionStatus(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.trialing:
        return subTrialing;
      case SubscriptionStatus.active:
        return subActive;
      case SubscriptionStatus.pastDue:
        return subPastDue;
      case SubscriptionStatus.suspended:
        return subSuspended;
    }
  }

  String paymentStatus(PaymentStatus status, {PaymentMethod method = PaymentMethod.cash}) {
    switch (status) {
      case PaymentStatus.unpaid:
        return method == PaymentMethod.chapa ? payUnpaid : payAtShop;
      case PaymentStatus.pending:
        return payPending;
      case PaymentStatus.paid:
        return payPaid;
      case PaymentStatus.refunded:
        return payRefunded;
    }
  }

  String paymentRecordStatus(PaymentRecordStatus status) {
    switch (status) {
      case PaymentRecordStatus.pending:
        return recordProcessing;
      case PaymentRecordStatus.success:
        return payPaid;
      case PaymentRecordStatus.failed:
        return recordFailed;
      case PaymentRecordStatus.refunded:
        return payRefunded;
    }
  }

  /// A plan's display name. Plan docs carry an admin-entered name; the known
  /// ids are translated when no doc is available (or in Amharic).
  String planName(String planId, [SubscriptionPlan? plan]) {
    String? known;
    switch (planId) {
      case 'trial':
        known = planTrial;
      case 'basic':
        known = planBasic;
      case 'pro':
        known = planPro;
    }
    if (plan != null && !(isAmharic && known != null)) return plan.name;
    return known ?? planId;
  }

  String barberLimit(SubscriptionPlan plan) =>
      plan.isUnlimited ? planUnlimitedBarbers : planUpToBarbers(plan.maxBarbers);

  /// User-facing text for any error a service throws, in the active
  /// language: [AppException] codes, slot conflicts, payment errors, Firebase
  /// errors; anything else becomes a generic message.
  String errorText(Object error) {
    if (error is AppException) return appError(error.code, error.args);
    if (error is SlotTakenException) return errSlotTaken;
    if (error is PaymentException) return paymentError(error);
    if (error is EmailAuthException) return emailAuthError(error);
    if (error is FirebaseAuthException) return authError(error);
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthenticated':
          return errPermissionDenied;
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return errOffline;
      }
      return errGeneric;
    }
    // Booking writes that failed for another reason (FirestoreDataStore).
    if (error is StateError && error.message.startsWith('Could not book')) return errBookingFailed;
    return errGeneric;
  }

  /// Text for an [AppErrorCode] with its [args].
  String appError(AppErrorCode code, [List<Object?> args = const []]) {
    Object? arg(int i) => i < args.length ? args[i] : null;
    switch (code) {
      case AppErrorCode.invalidPhone:
        return errInvalidPhone;
      case AppErrorCode.invalidEmail:
        return errInvalidEmail;
      case AppErrorCode.invalidOwnerEmail:
        return errInvalidOwnerEmail;
      case AppErrorCode.googleEmailMissing:
        return errGoogleEmailMissing;
      case AppErrorCode.emailNotVerified:
        return errEmailNotVerified;
      case AppErrorCode.invalidName:
        return errInvalidName;
      case AppErrorCode.signInRequired:
        return errSignInRequired;
      case AppErrorCode.accountLoadFailed:
        return errAccountLoadFailed;
      case AppErrorCode.emailAlreadyStaff:
        final role = arg(0);
        return errEmailAlreadyStaff(role is UserRole ? roleName(role) : '${role ?? ''}');
      case AppErrorCode.signInToBook:
        return errSignInToBook;
      case AppErrorCode.shopNotTakingBookings:
        return shopNotTakingBookings;
      case AppErrorCode.barberNotTakingBookings:
        return barberNotTakingBookings('${arg(0) ?? ''}');
      case AppErrorCode.invalidTimeSlot:
        return errInvalidTimeSlot;
      case AppErrorCode.serviceTooLong:
        final max = arg(0);
        return errServiceTooLong(max is int ? max : 0);
      case AppErrorCode.invalidService:
        return invalidServiceValues;
      case AppErrorCode.serverOnly:
        return errServerOnly;
      case AppErrorCode.noWorkingDays:
        return errNoWorkingDays;
      case AppErrorCode.invalidWorkingHours:
        return errInvalidWorkingHours;
      case AppErrorCode.bookingNotChangeable:
        return rescheduleErrNotChangeable;
      case AppErrorCode.cancellationCutoffPassed:
        final hours = arg(0);
        return rescheduleErrCancelCutoff(hours is int ? hours : 0);
      case AppErrorCode.rescheduleCutoffPassed:
        final hours = arg(0);
        return rescheduleErrCutoff(hours is int ? hours : 0);
      case AppErrorCode.rescheduleLimitReached:
        final max = arg(0);
        return rescheduleErrLimit(max is int ? max : 0);
      case AppErrorCode.rescheduleSameTime:
        return rescheduleErrSameTime;
      case AppErrorCode.noShowTooEarly:
        return noShowErrTooEarly;
      case AppErrorCode.policyCutoffInvalid:
        final max = arg(0);
        return policyErrCutoff(max is int ? max : 0);
      case AppErrorCode.policyMaxReschedulesInvalid:
        final max = arg(0);
        return policyErrMaxReschedules(max is int ? max : 0);
      case AppErrorCode.timeOffInvalidRange:
        return timeOffErrRange;
      case AppErrorCode.timeOffInPast:
        return timeOffErrPast;
      case AppErrorCode.timeOffReasonTooLong:
        final max = arg(0);
        return timeOffErrReasonTooLong(max is int ? max : 0);
      case AppErrorCode.timeOffConflict:
        return timeOffErrConflict;
      case AppErrorCode.timeOffNotAllowed:
        return timeOffErrNotAllowed;
      case AppErrorCode.planIdInvalid:
        return errPlanIdInvalid('${arg(0) ?? ''}');
      case AppErrorCode.planNameRequired:
        return errPlanNameRequired;
      case AppErrorCode.planPriceNegative:
        return errPlanPriceNegative;
      case AppErrorCode.planPriceRequired:
        return errPlanPriceRequired;
      case AppErrorCode.planMaxBarbersInvalid:
        return errPlanMaxBarbers;
    }
  }

  /// User-facing text for a [PaymentException]: its typed cause or
  /// recognised reason first, then the callable error code. In English an
  /// unrecognised backend message is shown as written.
  String paymentError(PaymentException error) {
    final cause = error.cause;
    if (cause != null) return appError(cause.code, cause.args);
    final reason = error.reason;
    if (reason != null) return paymentReason(reason, error.args);
    if (!isAmharic) return error.message;
    switch (error.code) {
      case 'unauthenticated':
        return payErrSignIn;
      case 'permission-denied':
        return payErrNotAllowed;
      case 'not-found':
        return payErrNotFound;
      case 'already-exists':
        return payErrAlreadyPaid;
      case 'unavailable':
      case 'deadline-exceeded':
        return payErrNetwork;
      case 'failed-precondition':
        return payErrPrecondition;
      case 'invalid-argument':
        return payErrInvalid;
      case 'aborted':
        return payErrBookingChanged;
      case 'launch-failed':
        return payErrLaunchFailed;
      default:
        return payErrGeneric;
    }
  }

  String paymentReason(PaymentErrorReason reason, [List<Object?> args = const []]) {
    int intArg(int i) => i < args.length && args[i] is int ? args[i] as int : 0;
    switch (reason) {
      case PaymentErrorReason.notSetUp:
        return payErrNotSetUp;
      case PaymentErrorReason.bookingNotFound:
        return payErrBookingNotFound;
      case PaymentErrorReason.bookingCancelled:
        return payErrBookingCancelled;
      case PaymentErrorReason.bookingRefunded:
        return payErrBookingRefunded;
      case PaymentErrorReason.cannotPayOnline:
        return payErrCannotPayOnline;
      case PaymentErrorReason.noValidPrice:
        return payErrNoValidPrice;
      case PaymentErrorReason.notYourBooking:
        return payErrNotYourBooking;
      case PaymentErrorReason.notYourPayment:
        return payErrNotYourPayment;
      case PaymentErrorReason.notShopOwner:
        return payErrNotShopOwner;
      case PaymentErrorReason.shopNotFound:
        return payErrShopNotFound;
      case PaymentErrorReason.planUnavailable:
        return payErrPlanUnavailable;
      case PaymentErrorReason.unknownPlan:
        return payErrUnknownPlan;
      case PaymentErrorReason.planTooSmall:
        return payErrPlanTooSmall(intArg(0), intArg(1));
      case PaymentErrorReason.bookingChanged:
        return payErrBookingChanged;
      case PaymentErrorReason.stillPreparing:
        return payErrStillPreparing;
      case PaymentErrorReason.adminsOnly:
        return payErrAdminsOnly;
      case PaymentErrorReason.paymentNotFound:
        return payErrPaymentNotFound;
      case PaymentErrorReason.reviewNotNeeded:
        return payErrReviewNotNeeded;
      case PaymentErrorReason.reviewNotRefundable:
        return payErrReviewNotRefundable;
    }
  }

  /// Sign-in error text for Google sign-in (Firebase Auth error codes) and
  /// the repository's [AppException]s, in the active language.
  String authError(Object error) {
    if (error is AppException) return appError(error.code, error.args);
    if (error is EmailAuthException) return emailAuthError(error);
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'operation-not-allowed':
        case 'configuration-not-found':
          return authErrNotEnabled;
        case 'network-request-failed':
          return authErrNetwork;
        case 'popup-blocked':
          return authErrPopupBlocked;
        case 'account-exists-with-different-credential':
          return authErrAccountExists;
        case 'unauthorized-domain':
          return authErrUnauthorizedDomain;
        case 'user-disabled':
          return authErrUserDisabled;
      }
      if ((error.message ?? '').contains('CONFIGURATION_NOT_FOUND')) return authErrNotEnabled;
      return authErrWithCode(error.code);
    }
    if (error is FirebaseException) return errorText(error);
    return authErrGeneric;
  }

  /// Text for email sign-in, registration and password-reset errors.
  String emailAuthError(EmailAuthException error) {
    switch (error.code) {
      case EmailAuthErrorCode.invalidEmail:
        return errInvalidEmail;
      case EmailAuthErrorCode.weakPassword:
        return emailErrWeakPassword;
      case EmailAuthErrorCode.invalidCode:
        final left = error.attemptsLeft;
        return left != null && left > 0 ? emailErrInvalidCodeAttempts(left) : emailErrInvalidCode;
      case EmailAuthErrorCode.codeExpired:
        return emailErrCodeExpired;
      case EmailAuthErrorCode.emailAlreadyRegistered:
        return emailErrAlreadyRegistered;
      case EmailAuthErrorCode.tooSoon:
        final seconds = error.retryAfterSeconds;
        return seconds != null && seconds > 0 ? emailErrTooSoonSeconds(seconds) : emailErrTooSoon;
      case EmailAuthErrorCode.rateLimited:
        final seconds = error.retryAfterSeconds;
        return seconds != null && seconds > 0 ? emailErrRateLimitedMinutes((seconds / 60).ceil()) : emailErrRateLimited;
      case EmailAuthErrorCode.tooManyRequests:
        return emailErrRateLimited;
      case EmailAuthErrorCode.emailNotConfigured:
        return emailErrNotConfigured;
      case EmailAuthErrorCode.emailSendFailed:
        return emailErrSendFailed;
      case EmailAuthErrorCode.invalidInput:
        return emailErrInvalidInput;
      case EmailAuthErrorCode.wrongCredentials:
        return emailErrWrongCredentials;
      case EmailAuthErrorCode.userDisabled:
        return authErrUserDisabled;
      case EmailAuthErrorCode.network:
        return authErrNetwork;
      case EmailAuthErrorCode.notEnabled:
        return emailErrNotEnabled;
      case EmailAuthErrorCode.serviceUnavailable:
        return emailErrServiceUnavailable;
      case EmailAuthErrorCode.unknown:
        final raw = error.rawCode;
        return raw == null ? authErrGeneric : authErrWithCode(raw);
    }
  }
}