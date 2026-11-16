/// Re-authentication and deletion of the signed-in Firebase Auth login, for
/// account deletion (account_deletion.dart). Firebase deletes a login only
/// after a recent sign-in, so the app asks for the password (email
/// accounts) or a Google sign-in first. Works on the free Spark plan.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/email_utils.dart';
import 'account_deletion.dart';
import 'email_auth_service.dart' show EmailAuthErrorCode, EmailAuthException, emailAuthExceptionFrom;
import 'google_auth_service.dart' show FirebaseGoogleAuthService;

/// How the signed-in person can prove it is them.
enum ReauthMethod { password, google }

abstract class AccountAuthService {
  /// The methods the current login has (password when it has the
  /// email/password provider, google when it has the Google provider).
  Set<ReauthMethod> methodsFor(String email);

  /// Signs in again with [password]. Wrong password: [EmailAuthException]
  /// wrongCredentials.
  Future<void> reauthenticateWithPassword(String email, String password);

  /// Signs in again with Google (popup on the web, the native flow on
  /// phones). Throws [AccountDeletionException] reauthCancelled when the
  /// window is closed, [EmailAuthException] wrongCredentials when another
  /// Google account was picked.
  Future<void> reauthenticateWithGoogle(String email);

  /// Deletes the signed-in login. Throws [AccountDeletionException]
  /// reauthRequired when Firebase wants a fresh sign-in first.
  Future<void> deleteCurrentLogin();
}

class FirebaseAccountAuthService implements AccountAuthService {
  FirebaseAccountAuthService(this._auth);

  final FirebaseAuth _auth;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    return user;
  }

  @override
  Set<ReauthMethod> methodsFor(String email) {
    final user = _auth.currentUser;
    if (user == null) return const {};
    final ids = user.providerData.map((p) => p.providerId).toSet();
    return {
      if (ids.contains(EmailAuthProvider.PROVIDER_ID)) ReauthMethod.password,
      if (ids.contains(GoogleAuthProvider.PROVIDER_ID)) ReauthMethod.google,
    };
  }

  @override
  Future<void> reauthenticateWithPassword(String email, String password) async {
    final user = _user;
    try {
      final credential = EmailAuthProvider.credential(email: user.email ?? normalizeEmail(email), password: password);
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      throw emailAuthExceptionFrom(e);
    }
  }

  @override
  Future<void> reauthenticateWithGoogle(String email) async {
    final user = _user;
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'login_hint': user.email ?? email});
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
    } catch (e) {
      if (FirebaseGoogleAuthService.isCancellation(e)) {
        throw const AccountDeletionException(AccountDeletionError.reauthCancelled);
      }
      throw emailAuthExceptionFrom(e);
    }
  }

  @override
  Future<void> deleteCurrentLogin() async {
    try {
      await _user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' || e.code == 'user-token-expired') {
        throw AccountDeletionException(AccountDeletionError.reauthRequired, cause: e);
      }
      rethrow;
    }
  }
}

/// Demo builds and tests: checks passwords with [verifyPassword] (the local
/// email service) and records deleted logins.
class LocalAccountAuthService implements AccountAuthService {
  LocalAccountAuthService({
    required this.hasPassword,
    required this.verifyPassword,
    this.onDeleteLogin,
  });

  final bool Function(String email) hasPassword;
  final Future<void> Function(String email, String password) verifyPassword;

  /// Called with the email of each deleted login.
  final void Function(String email)? onDeleteLogin;

  /// Tests: what [reauthenticateWithGoogle] does (null = succeed).
  Object? googleError;

  /// Tests: the next [deleteCurrentLogin] throws reauthRequired once.
  bool requireRecentLoginOnce = false;

  /// Whether a re-authentication happened since the last deletion.
  bool reauthenticated = false;

  /// Emails whose login was deleted, oldest first.
  final List<String> deletedLogins = [];

  String? _email;

  @override
  Set<ReauthMethod> methodsFor(String email) =>
      {if (hasPassword(email)) ReauthMethod.password, ReauthMethod.google};

  @override
  Future<void> reauthenticateWithPassword(String email, String password) async {
    if (password.isEmpty) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    await verifyPassword(email, password);
    reauthenticated = true;
    _email = normalizeEmail(email);
  }

  @override
  Future<void> reauthenticateWithGoogle(String email) async {
    final error = googleError;
    if (error != null) throw error;
    reauthenticated = true;
    _email = normalizeEmail(email);
  }

  @override
  Future<void> deleteCurrentLogin() async {
    if (requireRecentLoginOnce) {
      requireRecentLoginOnce = false;
      throw const AccountDeletionException(AccountDeletionError.reauthRequired);
    }
    final email = _email ?? '';
    deletedLogins.add(email);
    onDeleteLogin?.call(email);
    reauthenticated = false;
  }
}
