import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase phone (SMS OTP) sign-in for both mobile and web.
///
/// Mobile uses `verifyPhoneNumber` (with Android SMS auto-retrieval); web uses
/// `signInWithPhoneNumber`, which shows an invisible reCAPTCHA.
class PhoneAuthService {
  PhoneAuthService(this._auth);

  final FirebaseAuth _auth;

  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  /// Sends an SMS code to [phoneE164]. Completes once the code has been sent
  /// (or, on Android, once the number was verified automatically).
  Future<void> sendCode(String phoneE164) async {
    if (kIsWeb) {
      _webConfirmation = await _auth.signInWithPhoneNumber(phoneE164);
      return;
    }

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android read the SMS automatically; sign in straight away.
        try {
          await _auth.signInWithCredential(credential);
        } catch (e) {
          debugPrint('Auto phone verification failed: $e');
        }
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
    return completer.future;
  }

  /// Confirms the 6-digit [code]. On success Firebase signs the user in and
  /// `authStateChanges` fires.
  Future<void> verifyCode(String code) async {
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) {
        throw StateError('Request a code first.');
      }
      await confirmation.confirm(code);
      return;
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      throw StateError('Request a code first.');
    }
    await _auth.signInWithCredential(
      PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
    );
  }

  void reset() {
    _verificationId = null;
    _webConfirmation = null;
  }
}

/// Turns auth errors into short messages that can be shown to users.
String describeAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'That phone number is not valid.';
      case 'invalid-verification-code':
        return 'Wrong code. Check the SMS and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'The code expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'quota-exceeded':
        return 'SMS limit reached. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled for this app yet.';
      default:
        return error.message ?? 'Sign-in failed (${error.code}).';
    }
  }
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  return 'Something went wrong. Please try again.';
}
