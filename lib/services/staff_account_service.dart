import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/email_utils.dart';
import '../core/utils/password_utils.dart';
import '../firebase_options.dart';
import '../models/invite_model.dart';
import 'email_auth_service.dart';

/// Owner-created barber logins ("staff accounts").
///
/// A shop owner adds a barber with a login email and a temporary password.
/// On the free Spark plan there are no Cloud Functions, so the Auth account
/// is created client-side in a SECONDARY Firebase app ([kStaffCreatorAppName])
/// — creating it in the default app would sign the owner out. The new
/// account's uid is written to `invites/{email}.authUid` (with
/// `mustChangePassword: true`) in the same batch as the barber profile.
///
/// Such an account's email is never verified (no email is sent), so the
/// usual "verified email only" sign-in check is relaxed for it: see
/// [unverifiedSignInAllowed]. At first login the barber must replace the
/// temporary password (`users/{uid}.mustChangePassword`).

/// Name of the secondary Firebase app that creates staff Auth accounts.
const String kStaffCreatorAppName = 'staffCreator';

/// Length of [generateTemporaryPassword]'s result ("Kx7m-Q2pab").
const int kTemporaryPasswordLength = 10;

/// Letters and digits that cannot be confused when read aloud or copied by
/// hand (no 0/O/o, 1/l/I).
const String _readableLetters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';
const String _readableDigits = '23456789';

/// A readable 10-character temporary password: four characters, a dash and
/// five more ("Kx7m-Q2pab"). Always satisfies [isValidPassword] (at least
/// one letter and one digit).
String generateTemporaryPassword({Random? random}) {
  final rng = random ?? Random.secure();
  const pool = _readableLetters + _readableDigits;
  while (true) {
    final chars = List<String>.generate(kTemporaryPasswordLength - 1, (_) => pool[rng.nextInt(pool.length)]);
    final candidate = '${chars.sublist(0, 4).join()}-${chars.sublist(4).join()}';
    if (isValidPassword(candidate) && candidate.contains(RegExp('[$_readableDigits]'))) return candidate;
  }
}

/// Whether an email/password sign-in whose address is NOT verified may
/// continue (everyone else must verify their email first):
///  * the account already has a profile (`users/{uid}` exists; the role
///    comes from the profile), or
///  * an invite at `invites/{token email}` carries `authUid == uid` (a
///    barber account an owner created with a temporary password).
bool unverifiedSignInAllowed({required String uid, required bool profileExists, UserInvite? invite}) {
  if (uid.isEmpty) return false;
  if (profileExists) return true;
  return invite != null && invite.authUid == uid;
}

/// The text the owner copies to hand the login details to the barber.
String staffLoginDetailsText({required String heading, required String emailLabel, required String email,
    required String passwordLabel, required String password, required String footer}) {
  return '$heading\n$emailLabel: $email\n$passwordLabel: $password\n$footer';
}

/// Result of `AppRepository.addBarberWithAccount`.
class BarberAccountCreated {
  const BarberAccountCreated({
    required this.barberId,
    required this.uid,
    required this.email,
    required this.temporaryPassword,
  });

  final String barberId;

  /// Firebase Auth uid of the new account (a local id in demo mode).
  final String uid;
  final String email;
  final String temporaryPassword;
}

/// Creates Auth accounts for staff without touching the signed-in session.
abstract class StaffAccountService {
  /// Creates an email/password account for [email] with [password], then
  /// runs [persist] with the new uid (write the profile + invite there). If
  /// [persist] throws, the new account is deleted again and the error is
  /// rethrown. Returns the uid.
  ///
  /// Throws [EmailAuthException] with [EmailAuthErrorCode.emailAlreadyRegistered]
  /// when the email already has an account (offer an invitation instead),
  /// [EmailAuthErrorCode.weakPassword], [EmailAuthErrorCode.invalidEmail] or
  /// [EmailAuthErrorCode.network].
  Future<String> createAccount({
    required String email,
    required String password,
    required Future<void> Function(String uid) persist,
  });
}

/// Free plan: creates the account in a secondary [FirebaseApp], so the
/// owner stays signed in to the default app. The secondary session is
/// signed out and the app deleted afterwards.
class FirebaseStaffAccountService implements StaffAccountService {
  FirebaseStaffAccountService({FirebaseOptions? options}) : _options = options;

  final FirebaseOptions? _options;

  static const Duration _timeout = Duration(seconds: 30);

  Future<FirebaseApp> _secondaryApp() async {
    // A leftover from an interrupted run is reused.
    for (final app in Firebase.apps) {
      if (app.name == kStaffCreatorAppName) return app;
    }
    return Firebase.initializeApp(
      name: kStaffCreatorAppName,
      options: _options ?? DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Future<String> createAccount({
    required String email,
    required String password,
    required Future<void> Function(String uid) persist,
  }) async {
    final normalized = validEmailOrNull(email);
    if (normalized == null) throw const EmailAuthException(EmailAuthErrorCode.invalidEmail);
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);

    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      final User user;
      try {
        final credential =
            await auth.createUserWithEmailAndPassword(email: normalized, password: password).timeout(_timeout);
        user = credential.user!;
      } catch (e) {
        throw emailAuthExceptionFrom(e);
      }
      try {
        await persist(user.uid);
      } catch (_) {
        // Don't leave an orphan login behind (it would block re-adding
        // the barber with this email).
        try {
          await user.delete().timeout(_timeout);
        } catch (_) {}
        rethrow;
      }
      return user.uid;
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
      try {
        await app.delete();
      } catch (_) {}
    }
  }
}

/// Demo builds and tests: the account is stored in the in-memory
/// [LocalEmailAuthService] (unverified, like the real one) under a
/// generated uid.
class LocalStaffAccountService implements StaffAccountService {
  LocalStaffAccountService(this._emailAuth);

  /// The repository's current email sign-in service (it can be swapped in
  /// tests).
  final EmailAuthService Function() _emailAuth;

  final _uuid = const Uuid();

  /// email → uid of the accounts created here.
  final Map<String, String> _uids = {};

  /// email → the temporary password it was created with (tests, demo).
  final Map<String, String> temporaryPasswords = {};

  /// The uid of the account created for [email], if any.
  String? uidFor(String email) => _uids[normalizeEmail(email)];

  @override
  Future<String> createAccount({
    required String email,
    required String password,
    required Future<void> Function(String uid) persist,
  }) async {
    final normalized = validEmailOrNull(email);
    if (normalized == null) throw const EmailAuthException(EmailAuthErrorCode.invalidEmail);
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
    final auth = _emailAuth();
    if (auth is! LocalEmailAuthService) {
      throw StateError('LocalStaffAccountService needs a LocalEmailAuthService');
    }
    auth.createUnverifiedAccount(normalized, password); // throws if taken
    final uid = 'local-${_uuid.v4()}';
    _uids[normalized] = uid;
    try {
      await persist(uid);
    } catch (_) {
      _uids.remove(normalized);
      auth.deleteAccount(normalized);
      rethrow;
    }
    temporaryPasswords[normalized] = password;
    return uid;
  }
}
