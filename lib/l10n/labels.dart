import 'package:firebase_auth/firebase_auth.dart';

import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/payment_model.dart';
import '../models/plan_model.dart';
import '../models/user_model.dart';
import '../services/phone_auth_service.dart';
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

  /// User-facing text for a payments error code (PaymentException.code).
  /// English keeps the backend's own message.
  String paymentError(String code, String englishMessage) {
    if (!isAmharic) return englishMessage;
    if (englishMessage.contains('Online payments are not set up')) return payErrNotSetUp;
    switch (code) {
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
      default:
        return payErrGeneric;
    }
  }

  /// Sign-in error text. English keeps describeAuthError's wording; Amharic
  /// translates the Firebase Auth error codes (other errors stay as given).
  String authError(Object error) {
    if (!isAmharic) return describeAuthError(error);
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return authErrInvalidPhone;
        case 'invalid-verification-code':
          return authErrWrongCode;
        case 'session-expired':
        case 'code-expired':
          return authErrCodeExpired;
        case 'too-many-requests':
          return authErrTooMany;
        case 'quota-exceeded':
          return authErrQuota;
        case 'network-request-failed':
          return authErrNetwork;
        case 'operation-not-allowed':
          return authErrNotEnabled;
      }
      return authErrGeneric;
    }
    if (error is FormatException || error is StateError) return describeAuthError(error);
    return authErrGeneric;
  }
}
