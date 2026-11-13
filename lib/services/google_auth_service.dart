import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/email_utils.dart';

/// The Google account that just signed in.
class GoogleIdentity {
  GoogleIdentity({required String email, this.displayName, this.uid}) : email = normalizeEmail(email);

  /// Verified Google email, lowercased.
  final String email;
  final String? displayName;

  /// Firebase Auth uid (null in local / demo mode).
  final String? uid;
}

/// Google sign-in, as a thin injectable wrapper so the repository can be
/// tested without Firebase.
abstract class GoogleAuthService {
  /// Opens the Google account picker. Returns the signed-in identity, or
  /// null when the user cancelled (or, on web, when the page is being
  /// redirected to Google because the popup was blocked).
  Future<GoogleIdentity?> signIn();

  Future<void> signOut();
}

/// Firebase Auth's Google provider: a popup on web (falling back to a full
/// page redirect when the popup is blocked) and the native provider flow on
/// Android / iOS. No `google_sign_in` package is needed.
class FirebaseGoogleAuthService implements GoogleAuthService {
  FirebaseGoogleAuthService(this._auth);

  final FirebaseAuth _auth;

  /// Error codes that just mean "the user closed the window".
  static const cancelledCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-cancelled',
    'web-context-canceled',
    'canceled',
    'cancelled',
    'user-cancelled',
  };

  static bool isCancellation(Object error) =>
      error is FirebaseAuthException && cancelledCodes.contains(error.code);

  GoogleAuthProvider _provider() => GoogleAuthProvider()
    ..addScope('email')
    ..setCustomParameters({'prompt': 'select_account'});

  @override
  Future<GoogleIdentity?> signIn() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        try {
          credential = await _auth.signInWithPopup(_provider());
        } on FirebaseAuthException catch (e) {
          if (e.code != 'popup-blocked') rethrow;
          // The page navigates to Google; authStateChanges fires on return.
          await _auth.signInWithRedirect(_provider());
          return null;
        }
      } else {
        credential = await _auth.signInWithProvider(_provider());
      }
      final user = credential.user;
      final email = user?.email;
      if (user == null || email == null) return null;
      return GoogleIdentity(email: email, displayName: user.displayName, uid: user.uid);
    } catch (e) {
      if (isCancellation(e)) return null;
      rethrow;
    }
  }

  /// Web: surfaces an error from a redirect sign-in (after the popup was
  /// blocked). Returns null when there is nothing to report.
  Future<Object?> redirectError() async {
    if (!kIsWeb) return null;
    try {
      await _auth.getRedirectResult();
      return null;
    } catch (e) {
      return isCancellation(e) ? null : e;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Local (demo / test) Google sign-in: always "picks" [identity].
class FakeGoogleAuthService implements GoogleAuthService {
  FakeGoogleAuthService(this.identity);

  /// The account returned by the next [signIn]; null simulates a cancel.
  GoogleIdentity? identity;

  @override
  Future<GoogleIdentity?> signIn() async => identity;

  @override
  Future<void> signOut() async {}
}
