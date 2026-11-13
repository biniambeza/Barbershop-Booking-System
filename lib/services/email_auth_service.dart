import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/email_utils.dart';
import '../core/utils/password_utils.dart';

/// Region of the `functions/auth` callables.
const String kAuthFunctionsRegion = 'europe-west1';

/// Why a 6-digit code is emailed.
enum EmailCodePurpose { register, reset }

/// Result of asking the server to email a code.
class EmailCodeSent {
  const EmailCodeSent({this.resendAfterSeconds = 60, this.expiresInSeconds = 600});

  /// Seconds before another code can be requested.
  final int resendAfterSeconds;

  /// Seconds the code stays valid.
  final int expiresInSeconds;
}

/// The account that just signed in with email and password.
class EmailIdentity {
  EmailIdentity({required String email, this.displayName, this.uid}) : email = normalizeEmail(email);

  final String email;
  final String? displayName;

  /// Firebase Auth uid (null in local / demo mode).
  final String? uid;
}

/// Everything that can go wrong with email sign-in, registration and
/// password reset (server codes, Firebase Auth codes and client checks).
enum EmailAuthErrorCode {
  invalidEmail,
  weakPassword,

  /// Wrong code; see [EmailAuthException.attemptsLeft].
  invalidCode,

  /// Expired, never requested, or too many wrong guesses: request a new code.
  codeExpired,
  emailAlreadyRegistered,

  /// A code was sent moments ago; see [EmailAuthException.retryAfterSeconds].
  tooSoon,
  rateLimited,

  /// The server cannot send email (no mail provider configured).
  emailNotConfigured,

  /// The mail provider failed to send this email; trying again may work.
  emailSendFailed,

  /// The server rejected the request's fields.
  invalidInput,

  /// Wrong password, or no account with that email (deliberately the same).
  wrongCredentials,
  tooManyRequests,
  userDisabled,
  network,

  /// Email/password sign-in is disabled in Firebase Auth.
  notEnabled,

  /// The auth callables are not deployed or failed internally.
  serviceUnavailable,
  unknown,
}

class EmailAuthException implements Exception {
  const EmailAuthException(this.code, {this.retryAfterSeconds, this.attemptsLeft, this.rawCode});

  final EmailAuthErrorCode code;

  /// For [EmailAuthErrorCode.tooSoon] and [EmailAuthErrorCode.rateLimited].
  final int? retryAfterSeconds;

  /// For [EmailAuthErrorCode.invalidCode]: wrong guesses left before the code
  /// is invalidated (after that the server answers 'code-expired').
  final int? attemptsLeft;

  /// The original Firebase / server error code, for logs.
  final String? rawCode;

  @override
  String toString() => 'EmailAuthException(${code.name}${rawCode == null ? '' : ', $rawCode'})';
}

/// Email + password sign-in with emailed 6-digit codes for registration and
/// password reset, as an injectable service so the repository can run
/// without Firebase (demo builds and tests).
abstract class EmailAuthService {
  /// Emails a code to [email]. [language] is 'en' or 'am'.
  Future<EmailCodeSent> requestCode({
    required String email,
    required EmailCodePurpose purpose,
    String language = 'en',
  });

  /// Checks the registration code and creates the (verified) account. Does
  /// not sign in.
  Future<void> completeRegistration({
    required String email,
    required String code,
    required String password,
    String? name,
  });

  /// Checks the reset code and sets a new password.
  Future<void> resetPassword({required String email, required String code, required String newPassword});

  Future<EmailIdentity> signIn({required String email, required String password});

  Future<void> signOut();
}

// ---------------------------------------------------------------------------
// Firebase
// ---------------------------------------------------------------------------

/// Calls the `functions/auth` callables and Firebase Auth.
class FirebaseEmailAuthService implements EmailAuthService {
  FirebaseEmailAuthService(this._auth, {FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: kAuthFunctionsRegion);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  static const _timeout = Duration(seconds: 30);

  Future<Map<String, Object?>> _call(String name, Map<String, Object?> data) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data).timeout(_timeout);
      final value = result.data;
      return value is Map ? value.map((k, v) => MapEntry('$k', v)) : const {};
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
  }

  @override
  Future<EmailCodeSent> requestCode({
    required String email,
    required EmailCodePurpose purpose,
    String language = 'en',
  }) async {
    final data = await _call('requestEmailCode', {
      'email': normalizeEmail(email),
      'purpose': purpose.name,
      'language': language == 'am' ? 'am' : 'en',
    });
    int intOr(Object? v, int fallback) => v is num ? v.toInt() : fallback;
    return EmailCodeSent(
      resendAfterSeconds: intOr(data['resendAfterSeconds'], 60),
      expiresInSeconds: intOr(data['expiresInSeconds'], 600),
    );
  }

  @override
  Future<void> completeRegistration({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    await _call('completeEmailRegistration', {
      'email': normalizeEmail(email),
      'code': code,
      'password': password,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
  }

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _call('resetPasswordWithCode', {
      'email': normalizeEmail(email),
      'code': code,
      'newPassword': newPassword,
    });
  }

  @override
  Future<EmailIdentity> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: normalizeEmail(email), password: password);
      final user = credential.user;
      return EmailIdentity(email: user?.email ?? email, displayName: user?.displayName, uid: user?.uid);
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// `details.code` values sent by the `functions/auth` callables.
const _serverCodes = {
  'invalid-email': EmailAuthErrorCode.invalidEmail,
  'invalid-input': EmailAuthErrorCode.invalidInput,
  'weak-password': EmailAuthErrorCode.weakPassword,
  'invalid-code': EmailAuthErrorCode.invalidCode,
  'code-expired': EmailAuthErrorCode.codeExpired,
  'email-already-registered': EmailAuthErrorCode.emailAlreadyRegistered,
  'email-already-in-use': EmailAuthErrorCode.emailAlreadyRegistered,
  'too-soon': EmailAuthErrorCode.tooSoon,
  'rate-limited': EmailAuthErrorCode.rateLimited,
  'email-not-configured': EmailAuthErrorCode.emailNotConfigured,
  'email-send-failed': EmailAuthErrorCode.emailSendFailed,
  'internal': EmailAuthErrorCode.serviceUnavailable,
};

const _authCodes = {
  'wrong-password': EmailAuthErrorCode.wrongCredentials,
  'invalid-credential': EmailAuthErrorCode.wrongCredentials,
  'invalid-login-credentials': EmailAuthErrorCode.wrongCredentials,
  'user-not-found': EmailAuthErrorCode.wrongCredentials,
  'invalid-email': EmailAuthErrorCode.invalidEmail,
  'too-many-requests': EmailAuthErrorCode.tooManyRequests,
  'user-disabled': EmailAuthErrorCode.userDisabled,
  'network-request-failed': EmailAuthErrorCode.network,
  'operation-not-allowed': EmailAuthErrorCode.notEnabled,
  'configuration-not-found': EmailAuthErrorCode.notEnabled,
};

/// Normalises any error from the email auth calls into an
/// [EmailAuthException].
EmailAuthException emailAuthExceptionFrom(Object error) {
  if (error is EmailAuthException) return error;
  if (error is TimeoutException) return const EmailAuthException(EmailAuthErrorCode.network, rawCode: 'timeout');
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    if (details is Map) {
      final serverCode = details['code'];
      final known = serverCode is String ? _serverCodes[serverCode] : null;
      if (known != null) {
        final retry = details['retryAfterSeconds'];
        final attempts = details['attemptsLeft'];
        return EmailAuthException(
          known,
          retryAfterSeconds: retry is num ? retry.toInt() : null,
          attemptsLeft: attempts is num ? attempts.toInt() : null,
          rawCode: serverCode as String,
        );
      }
    }
    final code = error.code.toLowerCase().replaceAll('_', '-');
    switch (code) {
      case 'unavailable':
      case 'internal':
      case 'not-found':
      case 'unimplemented':
        return EmailAuthException(EmailAuthErrorCode.serviceUnavailable, rawCode: code);
      case 'deadline-exceeded':
        return EmailAuthException(EmailAuthErrorCode.network, rawCode: code);
      case 'resource-exhausted':
        return EmailAuthException(EmailAuthErrorCode.rateLimited, rawCode: code);
      case 'invalid-argument':
        return EmailAuthException(EmailAuthErrorCode.invalidInput, rawCode: code);
    }
    return EmailAuthException(EmailAuthErrorCode.unknown, rawCode: code);
  }
  if (error is FirebaseAuthException) {
    final code = error.code.toLowerCase().replaceAll('_', '-');
    final known = _authCodes[code];
    if (known != null) return EmailAuthException(known, rawCode: code);
    final message = error.message ?? '';
    if (message.contains('INVALID_LOGIN_CREDENTIALS')) {
      return EmailAuthException(EmailAuthErrorCode.wrongCredentials, rawCode: code);
    }
    if (message.contains('CONFIGURATION_NOT_FOUND')) {
      return EmailAuthException(EmailAuthErrorCode.notEnabled, rawCode: code);
    }
    return EmailAuthException(EmailAuthErrorCode.unknown, rawCode: code);
  }
  return const EmailAuthException(EmailAuthErrorCode.unknown);
}

// ---------------------------------------------------------------------------
// Local (demo / tests)
// ---------------------------------------------------------------------------

/// Offline stand-in for the auth callables (same rules and error codes):
/// accounts live in memory and the emailed code is always [demoCode].
/// Seeded demo accounts (see [isExistingAccount]) log in with
/// [demoPassword].
class LocalEmailAuthService implements EmailAuthService {
  LocalEmailAuthService({this.isExistingAccount, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const demoCode = '123456';
  static const demoPassword = 'demo1234';
  static const resendAfter = Duration(seconds: 60);
  static const codeLifetime = Duration(minutes: 10);
  static const maxAttempts = 5;

  /// Whether a seeded account (one without a stored password) uses [email].
  final bool Function(String email)? isExistingAccount;
  final DateTime Function() _clock;

  /// email → password.
  final Map<String, String> _passwords = {};

  /// '${purpose.name}:email' → the outstanding code.
  final Map<String, _PendingCode> _codes = {};

  bool _exists(String email) => _passwords.containsKey(email) || (isExistingAccount?.call(email) ?? false);

  String _validEmail(String email) {
    final valid = validEmailOrNull(email);
    if (valid == null) throw const EmailAuthException(EmailAuthErrorCode.invalidEmail);
    return valid;
  }

  /// Like the server: a missing, expired or used-up code is 'code-expired';
  /// a wrong guess is 'invalid-code' with the attempts left.
  void _checkCode(EmailCodePurpose purpose, String email, String code) {
    final key = '${purpose.name}:$email';
    final pending = _codes[key];
    if (pending == null || _clock().difference(pending.sentAt) > codeLifetime) {
      _codes.remove(key);
      throw const EmailAuthException(EmailAuthErrorCode.codeExpired);
    }
    if (normalizeEmailCode(code) != demoCode) {
      pending.failures++;
      final left = maxAttempts - pending.failures;
      if (left <= 0) {
        _codes.remove(key);
        throw const EmailAuthException(EmailAuthErrorCode.codeExpired);
      }
      throw EmailAuthException(EmailAuthErrorCode.invalidCode, attemptsLeft: left);
    }
  }

  @override
  Future<EmailCodeSent> requestCode({
    required String email,
    required EmailCodePurpose purpose,
    String language = 'en',
  }) async {
    final normalized = _validEmail(email);
    if (purpose == EmailCodePurpose.register && _exists(normalized)) {
      throw const EmailAuthException(EmailAuthErrorCode.emailAlreadyRegistered);
    }
    final key = '${purpose.name}:$normalized';
    final now = _clock();
    final last = _codes[key];
    if (last != null) {
      final wait = resendAfter - now.difference(last.sentAt);
      if (wait > Duration.zero) {
        throw EmailAuthException(EmailAuthErrorCode.tooSoon, retryAfterSeconds: (wait.inMilliseconds / 1000).ceil());
      }
    }
    // Reset never reveals whether the account exists.
    if (purpose == EmailCodePurpose.register || _exists(normalized)) _codes[key] = _PendingCode(now);
    return EmailCodeSent(resendAfterSeconds: resendAfter.inSeconds, expiresInSeconds: codeLifetime.inSeconds);
  }

  @override
  Future<void> completeRegistration({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    final normalized = _validEmail(email);
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    _checkCode(EmailCodePurpose.register, normalized, code);
    if (_exists(normalized)) throw const EmailAuthException(EmailAuthErrorCode.emailAlreadyRegistered);
    _codes.remove('${EmailCodePurpose.register.name}:$normalized');
    _passwords[normalized] = password;
  }

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    final normalized = _validEmail(email);
    if (!isValidPassword(newPassword)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    _checkCode(EmailCodePurpose.reset, normalized, code);
    _codes.remove('${EmailCodePurpose.reset.name}:$normalized');
    _passwords[normalized] = newPassword;
  }

  @override
  Future<EmailIdentity> signIn({required String email, required String password}) async {
    final normalized = validEmailOrNull(email);
    if (normalized == null) throw const EmailAuthException(EmailAuthErrorCode.invalidEmail);
    final stored = _passwords[normalized];
    final ok = stored != null
        ? stored == password
        : (isExistingAccount?.call(normalized) ?? false) && password == demoPassword;
    if (!ok) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    return EmailIdentity(email: normalized);
  }

  @override
  Future<void> signOut() async {}
}

class _PendingCode {
  _PendingCode(this.sentAt);

  final DateTime sentAt;
  int failures = 0;
}
