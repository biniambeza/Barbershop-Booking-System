import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

/// Result of a correct code: a short-lived token that proves the email was
/// verified. It replaces the code in the final registration / reset call.
class EmailCodeVerified {
  const EmailCodeVerified({required this.verificationToken, this.expiresInSeconds = 900});

  final String verificationToken;

  /// Seconds the token stays valid.
  final int expiresInSeconds;
}

/// How a registration / password-reset flow continues after step 1.
///
/// With the `functions/auth` callables deployed, a 6-digit code was emailed
/// ([sent] is set). On the free Spark plan the callables are missing, so the
/// flow falls back to Firebase Auth's own emailed links ([usesLink]).
class EmailFlowStart {
  const EmailFlowStart.code(EmailCodeSent this.sent);
  const EmailFlowStart.link() : sent = null;

  final EmailCodeSent? sent;
  bool get usesLink => sent == null;
}

/// Result of [EmailAuthService.resendVerificationLink].
enum VerificationLinkResult {
  sent,

  /// The address is verified already: nothing was sent, just log in.
  alreadyVerified,
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

  /// The verification token from [EmailAuthService.verifyCode] expired (or is
  /// unknown): start again with a new code.
  verificationExpired,

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

  /// Email/password account whose address is not verified yet (free-plan
  /// fallback accounts until their verification link is opened).
  emailNotVerified,

  /// Firebase wants a fresh sign-in before changing the password.
  requiresRecentLogin,

  /// The signed-in account has no password (Google-only).
  noPassword,
  unknown,
}

class EmailAuthException implements Exception {
  const EmailAuthException(
    this.code, {
    this.retryAfterSeconds,
    this.attemptsLeft,
    this.rawCode,
    this.functionsMissing = false,
  });

  final EmailAuthErrorCode code;

  /// For [EmailAuthErrorCode.tooSoon] and [EmailAuthErrorCode.rateLimited].
  final int? retryAfterSeconds;

  /// For [EmailAuthErrorCode.invalidCode]: wrong guesses left before the code
  /// is invalidated (after that the server answers 'code-expired').
  final int? attemptsLeft;

  /// The original Firebase / server error code, for logs.
  final String? rawCode;

  /// The callable failed the way an undeployed function does (`not-found`,
  /// `unimplemented`, `unavailable`, or `internal` without a server code),
  /// e.g. on the free Spark plan. The repository then switches the flow to
  /// Firebase Auth's emailed links.
  final bool functionsMissing;

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

  /// Checks the emailed [code]. A correct code returns a verification token
  /// for [completeRegistration] / [resetPassword].
  Future<EmailCodeVerified> verifyCode({
    required String email,
    required String code,
    required EmailCodePurpose purpose,
  });

  /// Creates the (verified) account with the token from [verifyCode]. Does
  /// not sign in.
  Future<void> completeRegistration({
    required String email,
    required String verificationToken,
    required String password,
    String? name,
  });

  /// Sets a new password with the token from [verifyCode].
  Future<void> resetPassword({
    required String email,
    required String verificationToken,
    required String newPassword,
  });

  Future<EmailIdentity> signIn({required String email, required String password});

  /// Whether the signed-in account [email] can sign in with a password
  /// (has the email/password provider), i.e. can change it.
  bool hasPassword(String email);

  /// Signed-in user: proves [currentPassword] (re-authentication), then
  /// sets [newPassword]. Wrong current password → wrongCredentials.
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  // --- Free-plan fallback (Firebase Auth's own emails, no functions) ---

  /// Whether Firebase Auth itself answers (tells "functions not deployed"
  /// apart from "offline" after a network-level callable failure).
  Future<bool> isAuthReachable();

  /// Emails Firebase's password reset link. Succeeds whether or not an
  /// account exists for [email].
  Future<void> sendPasswordResetLink({required String email, String language = 'en'});

  /// Creates an (unverified) email/password account, emails Firebase's
  /// verification link, then signs out again. Returns whether the link was
  /// sent (the account exists either way).
  Future<bool> registerWithVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  });

  /// Signs in briefly with [email] / [password], emails a new verification
  /// link, then signs out.
  Future<VerificationLinkResult> resendVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  });
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

  // --- barber accounts ---
  /// Decides whether a signed-in account whose email is NOT verified may
  /// stay signed in (barber accounts an owner created with a temporary
  /// password). Null or false: signed out with emailNotVerified, as before.
  Future<bool> Function(User user)? allowUnverifiedSignIn;
  // --- end barber accounts ---

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
  Future<EmailCodeVerified> verifyCode({
    required String email,
    required String code,
    required EmailCodePurpose purpose,
  }) async {
    final data = await _call('verifyEmailCode', {
      'email': normalizeEmail(email),
      'code': code,
      'purpose': purpose.name,
    });
    final token = data['verificationToken'];
    if (token is! String || token.isEmpty) {
      throw const EmailAuthException(EmailAuthErrorCode.unknown, rawCode: 'missing-verification-token');
    }
    final expires = data['expiresInSeconds'];
    return EmailCodeVerified(verificationToken: token, expiresInSeconds: expires is num ? expires.toInt() : 900);
  }

  @override
  Future<void> completeRegistration({
    required String email,
    required String verificationToken,
    required String password,
    String? name,
  }) async {
    await _call('completeEmailRegistration', {
      'email': normalizeEmail(email),
      'verificationToken': verificationToken,
      'password': password,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) async {
    await _call('resetPasswordWithCode', {
      'email': normalizeEmail(email),
      'verificationToken': verificationToken,
      'newPassword': newPassword,
    });
  }

  @override
  Future<EmailIdentity> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: normalizeEmail(email), password: password);
      final user = credential.user;
      if (user != null && !user.emailVerified && !await _unverifiedAllowed(user)) {
        // Free-plan accounts stay unverified until their link is opened.
        await _signOutQuietly();
        throw const EmailAuthException(EmailAuthErrorCode.emailNotVerified);
      }
      return EmailIdentity(email: user?.email ?? email, displayName: user?.displayName, uid: user?.uid);
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
  }

  // --- barber accounts ---
  Future<bool> _unverifiedAllowed(User user) async {
    final check = allowUnverifiedSignIn;
    if (check == null) return false;
    try {
      return await check(user);
    } catch (_) {
      return false;
    }
  }
  // --- end barber accounts ---

  @override
  bool hasPassword(String email) {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID);
  }

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const EmailAuthException(EmailAuthErrorCode.requiresRecentLogin, rawCode: 'no-current-user');
    if (!hasPassword(email)) throw const EmailAuthException(EmailAuthErrorCode.noPassword);
    try {
      final credential = EmailAuthProvider.credential(email: user.email ?? normalizeEmail(email), password: currentPassword);
      await user.reauthenticateWithCredential(credential).timeout(_timeout);
      await user.updatePassword(newPassword).timeout(_timeout);
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _signOutQuietly() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('signOut failed: $e');
    }
  }

  /// Firebase's emails use the app language.
  Future<void> _setLanguage(String language) async {
    try {
      await _auth.setLanguageCode(language == 'am' ? 'am' : 'en');
    } catch (e) {
      debugPrint('setLanguageCode failed: $e');
    }
  }

  @override
  Future<bool> isAuthReachable() async {
    try {
      // Any answer from the Auth server (here: "invalid action code") means
      // it is reachable; only a network failure means it is not.
      await _auth.checkActionCode('reachability-probe').timeout(const Duration(seconds: 10));
      return true;
    } on FirebaseAuthException catch (e) {
      return e.code != 'network-request-failed';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sendPasswordResetLink({required String email, String language = 'en'}) async {
    await _setLanguage(language);
    try {
      await _auth.sendPasswordResetEmail(email: normalizeEmail(email)).timeout(_timeout);
    } on FirebaseAuthException catch (e) {
      // Never reveal whether the account exists.
      if (e.code == 'user-not-found') return;
      throw emailAuthExceptionFrom(e);
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
  }

  @override
  Future<bool> registerWithVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  }) async {
    await _setLanguage(language);
    final UserCredential credential;
    try {
      credential = await _auth
          .createUserWithEmailAndPassword(email: normalizeEmail(email), password: password)
          .timeout(_timeout);
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
    try {
      final user = credential.user;
      if (user == null) return false;
      await user.sendEmailVerification().timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('sendEmailVerification failed: $e');
      return false;
    } finally {
      await _signOutQuietly();
    }
  }

  @override
  Future<VerificationLinkResult> resendVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  }) async {
    await _setLanguage(language);
    var signedIn = false;
    try {
      final credential = await _auth
          .signInWithEmailAndPassword(email: normalizeEmail(email), password: password)
          .timeout(_timeout);
      signedIn = true;
      final user = credential.user;
      if (user == null) throw const EmailAuthException(EmailAuthErrorCode.unknown, rawCode: 'no-user');
      if (user.emailVerified) return VerificationLinkResult.alreadyVerified;
      await user.sendEmailVerification().timeout(_timeout);
      return VerificationLinkResult.sent;
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    } finally {
      if (signedIn) await _signOutQuietly();
    }
  }
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
  'verification-expired': EmailAuthErrorCode.verificationExpired,
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
  'email-already-in-use': EmailAuthErrorCode.emailAlreadyRegistered,
  'invalid-email': EmailAuthErrorCode.invalidEmail,
  'too-many-requests': EmailAuthErrorCode.tooManyRequests,
  'user-disabled': EmailAuthErrorCode.userDisabled,
  'network-request-failed': EmailAuthErrorCode.network,
  'operation-not-allowed': EmailAuthErrorCode.notEnabled,
  'weak-password': EmailAuthErrorCode.weakPassword,
  'requires-recent-login': EmailAuthErrorCode.requiresRecentLogin,
  'user-mismatch': EmailAuthErrorCode.wrongCredentials,
  'user-token-expired': EmailAuthErrorCode.requiresRecentLogin,
  'configuration-not-found': EmailAuthErrorCode.notEnabled,
};

/// Normalises any error from the email auth calls into an
/// [EmailAuthException].
EmailAuthException emailAuthExceptionFrom(Object error) {
  if (error is EmailAuthException) return error;
  if (error is TimeoutException) return const EmailAuthException(EmailAuthErrorCode.network, rawCode: 'timeout');
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    final hasServerCode = details is Map && details['code'] is String;
    if (details is Map) {
      final serverCode = details['code'];
      var known = serverCode is String ? _serverCodes[serverCode] : null;
      if (known == EmailAuthErrorCode.invalidInput &&
          (details['field'] == 'password' || details['field'] == 'newPassword')) {
        known = EmailAuthErrorCode.weakPassword;
      }
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
        // Without a server code this is what an undeployed function gives.
        return EmailAuthException(EmailAuthErrorCode.serviceUnavailable, rawCode: code, functionsMissing: !hasServerCode);
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
/// accounts live in memory and the emailed code is always [demoCode]; a
/// correct code returns a random verification token valid for
/// [verificationLifetime].
/// Seeded demo accounts (see [isExistingAccount]) log in with
/// [demoPassword].
///
/// `functionsAvailable: false` (or a specific [functionsError]) simulates
/// the free Spark plan: the code-flow calls fail like undeployed callables
/// and only the Firebase Auth link fallback works. [authReachable] is what
/// [isAuthReachable] answers. Links "sent" are recorded in [sentLinks];
/// [markEmailVerified] stands in for opening a verification link.
class LocalEmailAuthService implements EmailAuthService {
  LocalEmailAuthService({
    this.isExistingAccount,
    DateTime Function()? clock,
    bool functionsAvailable = true,
    Object? functionsError,
    this.authReachable = true,
  })  : _clock = clock ?? DateTime.now,
        functionsError =
            functionsError ?? (functionsAvailable ? null : FirebaseFunctionsException(message: 'NOT_FOUND', code: 'not-found'));

  static const demoCode = '123456';
  static const demoPassword = 'demo1234';
  static const resendAfter = Duration(seconds: 60);
  static const codeLifetime = Duration(minutes: 10);
  static const maxAttempts = 5;
  static const verificationLifetime = Duration(minutes: 15);

  /// Whether a seeded account (one without a stored password) uses [email].
  final bool Function(String email)? isExistingAccount;
  final DateTime Function() _clock;

  /// Thrown (through [emailAuthExceptionFrom]) by every code-flow call; null
  /// when the callables are "deployed".
  final Object? functionsError;

  /// What [isAuthReachable] answers.
  bool authReachable;

  /// Every link the fallback "emailed", oldest first.
  final List<SentAuthLink> sentLinks = [];

  /// Accounts created with [registerWithVerificationLink] whose link has not
  /// been opened yet.
  final Set<String> _unverified = {};

  /// Simulates opening the verification link sent to [email].
  void markEmailVerified(String email) => _unverified.remove(normalizeEmail(email));

  // --- barber accounts ---
  /// Whether an unverified address may still log in (barber accounts an
  /// owner created with a temporary password). Set by AppRepository.
  Future<bool> Function(String email)? allowUnverifiedSignIn;

  /// Like creating the account in a secondary Firebase app: stores
  /// [password] for [email], unverified (no email is sent). Throws
  /// emailAlreadyRegistered when [email] already has an account.
  void createUnverifiedAccount(String email, String password) {
    final normalized = _validEmail(email);
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    if (_exists(normalized)) throw const EmailAuthException(EmailAuthErrorCode.emailAlreadyRegistered);
    _passwords[normalized] = password;
    _unverified.add(normalized);
  }

  /// Removes an account made with [createUnverifiedAccount] (rollback).
  void deleteAccount(String email) {
    final normalized = normalizeEmail(email);
    _passwords.remove(normalized);
    _unverified.remove(normalized);
  }
  // --- end barber accounts ---

  void _checkFunctions() {
    final error = functionsError;
    if (error != null) throw emailAuthExceptionFrom(error);
  }

  /// email → password.
  final Map<String, String> _passwords = {};

  /// Accounts created through Google sign-in: no password until one is set
  /// with "Forgot password" (like Firebase linking the password provider).
  final Set<String> _googleOnly = {};

  /// Local mode: records a Google sign-in. A new account (not seeded and
  /// without a password) is Google-only.
  void noteGoogleSignIn(String email) {
    final normalized = normalizeEmail(email);
    if (!_exists(normalized)) _googleOnly.add(normalized);
  }

  /// '${purpose.name}:email' → the outstanding code.
  final Map<String, _PendingCode> _codes = {};

  /// '${purpose.name}:email' → the token issued for a correct code.
  final Map<String, _Verification> _verifications = {};

  final Random _random = Random.secure();

  bool _exists(String email) =>
      _passwords.containsKey(email) || _googleOnly.contains(email) || (isExistingAccount?.call(email) ?? false);

  /// Seeded accounts use [demoPassword] until changed; Google-only ones
  /// have none.
  String? _passwordOf(String email) {
    final stored = _passwords[email];
    if (stored != null) return stored;
    if (_googleOnly.contains(email)) return null;
    return (isExistingAccount?.call(email) ?? false) ? demoPassword : null;
  }

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
    _checkFunctions();
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
    // Reset never reveals whether the account exists: unknown emails get a
    // (never delivered) code that verifies but fails at the last step.
    _codes[key] = _PendingCode(now);
    return EmailCodeSent(resendAfterSeconds: resendAfter.inSeconds, expiresInSeconds: codeLifetime.inSeconds);
  }

  @override
  Future<EmailCodeVerified> verifyCode({
    required String email,
    required String code,
    required EmailCodePurpose purpose,
  }) async {
    _checkFunctions();
    final normalized = _validEmail(email);
    if (normalizeEmailCode(code) == null) throw const EmailAuthException(EmailAuthErrorCode.invalidInput);
    // Like the server: checked before the code.
    if (purpose == EmailCodePurpose.register && _exists(normalized)) {
      throw const EmailAuthException(EmailAuthErrorCode.emailAlreadyRegistered);
    }
    _checkCode(purpose, normalized, code);
    // The code stays valid until the last step; verifying it again issues a
    // new token and the previous one stops working.
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    _verifications['${purpose.name}:$normalized'] = _Verification(token, _clock());
    return EmailCodeVerified(verificationToken: token, expiresInSeconds: verificationLifetime.inSeconds);
  }

  /// Like the server: an unknown, mismatched or expired token is
  /// 'verification-expired'.
  void _checkToken(EmailCodePurpose purpose, String email, String token) {
    final key = '${purpose.name}:$email';
    final verification = _verifications[key];
    if (verification == null || verification.token != token) {
      throw const EmailAuthException(EmailAuthErrorCode.verificationExpired);
    }
    if (_clock().difference(verification.issuedAt) > verificationLifetime) {
      _verifications.remove(key);
      throw const EmailAuthException(EmailAuthErrorCode.verificationExpired);
    }
  }

  @override
  Future<void> completeRegistration({
    required String email,
    required String verificationToken,
    required String password,
    String? name,
  }) async {
    _checkFunctions();
    final normalized = _validEmail(email);
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    _checkToken(EmailCodePurpose.register, normalized, verificationToken);
    _verifications.remove('${EmailCodePurpose.register.name}:$normalized');
    _codes.remove('${EmailCodePurpose.register.name}:$normalized');
    if (_exists(normalized)) throw const EmailAuthException(EmailAuthErrorCode.emailAlreadyRegistered);
    _passwords[normalized] = password;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) async {
    _checkFunctions();
    final normalized = _validEmail(email);
    if (!isValidPassword(newPassword)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    _checkToken(EmailCodePurpose.reset, normalized, verificationToken);
    _verifications.remove('${EmailCodePurpose.reset.name}:$normalized');
    _codes.remove('${EmailCodePurpose.reset.name}:$normalized');
    // Unknown accounts fail only here, like an expired verification.
    if (!_exists(normalized)) throw const EmailAuthException(EmailAuthErrorCode.verificationExpired);
    _passwords[normalized] = newPassword;
  }

  @override
  Future<EmailIdentity> signIn({required String email, required String password}) async {
    final normalized = validEmailOrNull(email);
    if (normalized == null) throw const EmailAuthException(EmailAuthErrorCode.invalidEmail);
    final stored = _passwordOf(normalized);
    if (stored == null || stored != password) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    if (_unverified.contains(normalized) && !(await allowUnverifiedSignIn?.call(normalized) ?? false)) {
      throw const EmailAuthException(EmailAuthErrorCode.emailNotVerified);
    }
    return EmailIdentity(email: normalized);
  }

  @override
  bool hasPassword(String email) => _passwordOf(normalizeEmail(email)) != null;

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final normalized = _validEmail(email);
    final stored = _passwordOf(normalized);
    if (stored == null) throw const EmailAuthException(EmailAuthErrorCode.noPassword);
    if (stored != currentPassword) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    if (!isValidPassword(newPassword)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    _passwords[normalized] = newPassword;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> isAuthReachable() async => authReachable;

  @override
  Future<void> sendPasswordResetLink({required String email, String language = 'en'}) async {
    final normalized = _validEmail(email);
    // Like Firebase with enumeration protection: unknown emails "succeed"
    // but nothing is sent.
    if (!_exists(normalized)) return;
    sentLinks.add(SentAuthLink(SentAuthLinkKind.passwordReset, normalized, language));
  }

  @override
  Future<bool> registerWithVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  }) async {
    final normalized = _validEmail(email);
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    if (_exists(normalized)) throw const EmailAuthException(EmailAuthErrorCode.emailAlreadyRegistered);
    _passwords[normalized] = password;
    _unverified.add(normalized);
    sentLinks.add(SentAuthLink(SentAuthLinkKind.verification, normalized, language));
    return true;
  }

  @override
  Future<VerificationLinkResult> resendVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  }) async {
    final normalized = _validEmail(email);
    final stored = _passwordOf(normalized);
    if (stored == null || stored != password) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    if (!_unverified.contains(normalized)) return VerificationLinkResult.alreadyVerified;
    sentLinks.add(SentAuthLink(SentAuthLinkKind.verification, normalized, language));
    return VerificationLinkResult.sent;
  }
}

enum SentAuthLinkKind { verification, passwordReset }

/// A link [LocalEmailAuthService] "emailed" in fallback mode.
class SentAuthLink {
  const SentAuthLink(this.kind, this.email, this.language);

  final SentAuthLinkKind kind;
  final String email;
  final String language;

  @override
  String toString() => 'SentAuthLink(${kind.name}, $email, $language)';
}

class _PendingCode {
  _PendingCode(this.sentAt);

  final DateTime sentAt;
  int failures = 0;
}

class _Verification {
  const _Verification(this.token, this.issuedAt);

  final String token;
  final DateTime issuedAt;
}
