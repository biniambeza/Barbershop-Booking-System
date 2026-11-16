import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/email_utils.dart';
import '../core/utils/password_utils.dart';
import '../core/utils/phone_utils.dart';
import '../data/addis_time.dart';
import '../data/seed_dataset.dart';
import '../models/app_exception.dart';
import '../models/user_model.dart';
import '../models/barbershop_model.dart';
import '../models/service_model.dart';
import '../models/barber_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/plan_model.dart';
import '../models/review_model.dart' show RatingSummary;
import '../models/shop_application.dart' show ShopApplicationApproval; // shop applications
import 'availability_service.dart';
import 'booking_policy.dart' as policy;
import 'booking_acceptance.dart' as acceptance;
import 'rating_service.dart';
import 'data_cache.dart';
import 'data_store.dart';
import 'early_finish_service.dart' as early_finish; // early finish
import 'email_auth_service.dart';
import 'firestore_data_store.dart';
import 'google_auth_service.dart';
import 'staff_account_service.dart'; // barber accounts
import 'time_off_service.dart';
import 'vacation_service.dart'; // vacation
import 'admin_shops_logic.dart'; // admin shop management
import 'subscription_state.dart'; // subscription expiry (client-side)
import 'shop_deletion.dart'; // shop deletion
import 'shop_maps.dart' show isValidShopCoordinate; // shop location (maps)
import 'refunds.dart'; // refunds
import 'admin_users.dart'; // admin users
import 'admin_user_writes.dart'; // admin users
import 'account_auth_service.dart'; // account deletion
import 'account_deletion.dart'; // account deletion
import 'account_deletion_writes.dart'; // account deletion
import '../models/app_notification.dart' show AppNotification, NotificationTypes; // account deletion
import 'customer_blocks.dart' show CustomerBlockService; // customer blocks
import 'favorite_barbers_store.dart'; // favourite barbers & rebook
import 'rebook_service.dart' as rebook; // favourite barbers & rebook

export '../models/app_exception.dart';
export 'admin_shops_logic.dart'; // admin shop management
export 'admin_users.dart'; // admin users
export 'account_deletion.dart'; // account deletion
export 'account_auth_service.dart' show ReauthMethod; // account deletion
export 'shop_deletion.dart' show ShopDeletionStep, ShopDeletionException, ShopDeletionPreview, ShopDeletionNotice; // shop deletion
export 'email_auth_service.dart'
    show EmailAuthException, EmailAuthErrorCode, EmailCodeSent, EmailCodeVerified, EmailFlowStart, VerificationLinkResult;

/// Where the signed-in session currently stands.
enum AuthStatus {
  /// Checking Firebase for an existing session / loading the user's profile.
  initializing,
  signedOut,

  /// Signed in with Google, but no `users/{uid}` profile yet (first
  /// sign-in): the profile setup screen asks for a name and phone number.
  needsProfile,
  signedIn,
}

/// The app's single data facade (a [ChangeNotifier] singleton).
///
/// Screens read through synchronous getters inside a `ListenableBuilder`.
/// The getters read a [DataCache]:
///  * With Firebase attached ([attachFirebase]), Firestore is the source of
///    truth. When a user signs in, [FirestoreDataStore] opens snapshot
///    listeners scoped to their role and keeps the cache in sync; they are
///    closed (and the cache emptied) on sign-out. All writes go to Firestore
///    and come back through the listeners.
///  * Without Firebase (DEMO_MODE builds and tests) the cache is loaded from
///    the seed dataset ([loadDemoData] / [loadSeed]) and [LocalDataStore]
///    writes to it directly.
class AppRepository extends ChangeNotifier {
  static final AppRepository instance = AppRepository._internal();
  AppRepository._internal() {
    _store = LocalDataStore(_cache);
    subscriptionClock = _nowUtc; // subscription expiry: Barbershop.isBlocked uses the app clock
  }

  final _uuid = const Uuid();
  final DataCache _cache = DataCache();
  late DataStore _store;
  FirestoreDataStore? _cloud;

  // --- Firebase wiring ---
  bool _firebaseReady = false;
  GoogleAuthService _googleAuth = _defaultLocalGoogleAuth();
  StreamSubscription<User?>? _authSub;

  /// The account "Continue with Google" signs in as without Firebase (demo
  /// builds and tests): a new customer, so the profile setup step shows.
  static final GoogleIdentity demoGoogleIdentity =
      GoogleIdentity(email: 'demo.customer@gmail.com', displayName: 'Selam Bekele');

  static GoogleAuthService _defaultLocalGoogleAuth() => FakeGoogleAuthService(demoGoogleIdentity);

  /// Tests: replaces the Google sign-in used in local mode. [loadSeed]
  /// restores the default demo account.
  @visibleForTesting
  set googleAuthService(GoogleAuthService service) => _googleAuth = service;

  /// Email + password sign-in and the emailed-code flows. Local mode uses an
  /// in-memory fake (code 123456; seeded accounts log in with "demo1234").
  late EmailAuthService _emailAuth = _defaultLocalEmailAuth();

  EmailAuthService _defaultLocalEmailAuth() =>
      LocalEmailAuthService(isExistingAccount: (email) => _findUserByEmail(email) != null)
        ..allowUnverifiedSignIn = _localUnverifiedAllowed; // barber accounts

  /// Tests: replaces the email sign-in service used in local mode. [loadSeed]
  /// restores a fresh in-memory one.
  @visibleForTesting
  set emailAuthService(EmailAuthService service) {
    _emailAuth = service;
    if (service is LocalEmailAuthService) service.allowUnverifiedSignIn ??= _localUnverifiedAllowed; // barber accounts
    _resetEmailFallback();
  }

  /// Free-plan fallback, per flow and for this session only: once
  /// `requestEmailCode` failed like an undeployed function, registration /
  /// password reset use Firebase Auth's emailed links instead of codes.
  bool _registerUsesLink = false;
  bool _resetUsesLink = false;

  /// Registration continues with "create password" + a verification link.
  bool get registerUsesLink => _registerUsesLink;

  /// Forgot password sends Firebase's reset link.
  bool get resetUsesLink => _resetUsesLink;

  void _resetEmailFallback() {
    _registerUsesLink = false;
    _resetUsesLink = false;
  }

  /// Emails whose brief Firebase sign-in belongs to a fallback flow
  /// (create account + send link, resend link): the auth listener ignores
  /// them, the flow signs out itself.
  final Set<String> _quietAuthEmails = {};

  /// Emails logged in with a password this session: if the address turns
  /// out to be unverified the login form explains it (with "Resend
  /// verification link") instead of the auth listener.
  final Set<String> _emailLoginEmails = {};

  bool get isFirebaseAttached => _firebaseReady;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Connects the repository to Firebase Auth and Firestore. Call once after
  /// `Firebase.initializeApp` succeeds.
  void attachFirebase() {
    if (_firebaseReady) return;
    _firebaseReady = true;
    final google = FirebaseGoogleAuthService(FirebaseAuth.instance);
    _googleAuth = google;
    _emailAuth = FirebaseEmailAuthService(FirebaseAuth.instance)
      ..allowUnverifiedSignIn = _cloudUnverifiedAllowed; // barber accounts
    _staffAccounts = FirebaseStaffAccountService(); // barber accounts
    _adminUserWrites = FirestoreAdminUserWrites(FirebaseFirestore.instance); // admin users
    _accountDeletionWrites = FirestoreAccountDeletionWrites(FirebaseFirestore.instance); // account deletion
    _accountAuth = FirebaseAccountAuthService(FirebaseAuth.instance); // account deletion
    _resetEmailFallback();
    // Web: report a failed redirect sign-in (used when the popup is blocked).
    google.redirectError().then((error) {
      if (error == null) return;
      _authError = error;
      notifyListeners();
    });
    _cache.clear();
    final cloud = FirestoreDataStore(
      cache: _cache,
      onChanged: notifyListeners,
      onCurrentUserChanged: _onCurrentUserDocChanged,
    );
    _cloud = cloud;
    _store = cloud;
    _currentUser = null;
    _authStatus = AuthStatus.initializing;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onFirebaseAuthChanged);
  }

  /// Demo builds: loads the bundled Addis Ababa dataset. No-op with Firebase.
  Future<void> loadDemoData() async {
    if (_firebaseReady) return;
    final json = await rootBundle.loadString(kSeedAssetPath);
    loadSeed(SeedDataset.fromJsonString(json));
    loadDemoTimeOff(timeOffFromSeedJson(json));
  }

  /// Replaces all local data with [seed] and signs out. Local mode only
  /// (demo builds and tests); ignored once Firebase is attached.
  void loadSeed(SeedDataset seed) {
    if (_firebaseReady) return;
    _cache.loadSeed(seed);
    final local = _store;
    if (local is LocalDataStore) local.loadTimeOff(const []);
    _favoriteShopIds
      ..clear()
      ..addAll(seed.favoriteShopIds);
    _favoriteBarberIds
      ..clear()
      ..addAll(seed.favoriteBarberIds);
    _favoriteBarbers.clear(); // favourite barbers & rebook
    _favoriteBarberLoads.clear();
    _favoriteBarbersRead.clear();
    _currentUser = null;
    _authStatus = AuthStatus.signedOut;
    _googleAuth = _defaultLocalGoogleAuth();
    _emailAuth = _defaultLocalEmailAuth();
    _staffAccounts = _defaultLocalStaffAccounts(); // barber accounts
    _resetLocalAccountDeletion(); // account deletion
    CustomerBlockService.resetLocal(); // customer blocks
    _resetEmailFallback();
    _clearPending();
    _authError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cloud?.stop();
    super.dispose();
  }

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  AuthStatus _authStatus = AuthStatus.signedOut;
  AuthStatus get authStatus => _authStatus;

  /// The signed-in Google email (lowercased) while the profile is set up.
  String? _pendingEmail;
  String? get pendingEmail => _pendingEmail;

  /// The Google display name, used to prefill the profile name.
  String? _pendingDisplayName;
  String? get pendingDisplayName => _pendingDisplayName;

  /// Invite matching the signed-in email, shown on profile setup.
  UserInvite? _pendingInvite;
  UserInvite? get pendingInvite => _pendingInvite;

  void _clearPending() {
    _pendingEmail = null;
    _pendingDisplayName = null;
    _pendingInvite = null;
    _pendingPhone = null; // barber accounts
  }

  /// Last session-level error: an [AppException] (e.g. the profile could not
  /// be loaded) or a FirebaseAuthException from a redirect sign-in.
  Object? _authError;
  Object? get authError => _authError;

  /// Last Firestore listener error (e.g. permission denied), if any.
  String? get syncError => _cloud?.lastError;

  final Set<String> _favoriteShopIds = {};
  final Set<String> _favoriteBarberIds = {};

  // --- Auth & User Management ---

  /// Users visible to the current user: everyone for the admin, the shop's
  /// staff for an owner (plus themselves). All demo users in local mode.
  List<AppUser> getAllUsers() => List.unmodifiable(_cache.users.values);

  List<UserInvite> getPendingInvites() => List.unmodifiable(_cache.invites.values);

  /// The not-yet-accepted owner invite for a shop, if any.
  UserInvite? getPendingOwnerInvite(String shopId) {
    return _cache.invites.values
        .where((i) => i.role == UserRole.barbershopOwner && i.shopId == shopId)
        .firstOrNull;
  }

  /// The not-yet-accepted login invite for a barber profile, if any.
  UserInvite? getPendingBarberInvite(String barberId) {
    return _cache.invites.values.where((i) => i.role == UserRole.barber && i.barberId == barberId).firstOrNull;
  }

  /// Signs in with Google (popup / redirect on web, the native account
  /// picker on Android and iOS). Cancelling does nothing. On success the
  /// session moves to [AuthStatus.signedIn] (existing account) or
  /// [AuthStatus.needsProfile] (first sign-in).
  ///
  /// Without Firebase (demo builds and tests) the injected
  /// [GoogleAuthService] supplies the account.
  Future<void> signInWithGoogle() async {
    _authError = null;
    final identity = await _googleAuth.signIn();
    if (identity == null) return; // Cancelled (or redirecting on web).
    // With Firebase, _onFirebaseAuthChanged loads the profile.
    if (_firebaseReady) return;
    final emailAuth = _emailAuth;
    if (emailAuth is LocalEmailAuthService) emailAuth.noteGoogleSignIn(identity.email);
    _signInLocally(identity.email, identity.displayName);
  }

  // --- Email + password ---

  static String _validEmailOrThrow(String email) {
    final valid = validEmailOrNull(email);
    if (valid == null) throw const EmailAuthException(EmailAuthErrorCode.invalidEmail);
    return valid;
  }

  static void _checkPassword(String password) {
    if (!isValidPassword(password)) throw const EmailAuthException(EmailAuthErrorCode.weakPassword);
  }

  static String _codeOrThrow(String code) {
    final valid = normalizeEmailCode(code);
    if (valid == null) throw const EmailAuthException(EmailAuthErrorCode.invalidCode);
    return valid;
  }

  /// Registration step 1: checks [email] locally, then emails a 6-digit
  /// code. [language] ('en' | 'am') picks the email's language.
  Future<EmailCodeSent> registerRequestCode({required String email, String language = 'en'}) async {
    final normalized = _validEmailOrThrow(email);
    return _emailAuth.requestCode(email: normalized, purpose: EmailCodePurpose.register, language: language);
  }

  /// Registration step 2: checks the emailed [code]. A correct code returns
  /// the verification token for [registerComplete].
  Future<EmailCodeVerified> registerVerifyCode({required String email, required String code}) async {
    final normalized = _validEmailOrThrow(email);
    final validCode = _codeOrThrow(code);
    return _emailAuth.verifyCode(email: normalized, code: validCode, purpose: EmailCodePurpose.register);
  }

  /// Registration step 3: creates the account with [password] (its email is
  /// verified by [verificationToken]) and signs in. A new account continues
  /// at [AuthStatus.needsProfile], where email invites apply as usual.
  Future<void> registerComplete({
    required String email,
    required String verificationToken,
    required String password,
    String? name,
  }) async {
    final normalized = _validEmailOrThrow(email);
    _checkPassword(password);
    await _emailAuth.completeRegistration(
      email: normalized,
      verificationToken: verificationToken,
      password: password,
      name: name,
    );
    await loginWithEmail(email: normalized, password: password);
  }

  /// Signs in with email and password. With Firebase the auth listener loads
  /// the profile; locally the session switches immediately. An unverified
  /// address (free-plan accounts) throws [EmailAuthErrorCode.emailNotVerified]
  /// and stays signed out; [resendVerificationLink] sends a new link.
  Future<void> loginWithEmail({required String email, required String password}) async {
    _authError = null;
    final normalized = _validEmailOrThrow(email);
    if (password.isEmpty) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    _emailLoginEmails.add(normalized);
    final identity = await _emailAuth.signIn(email: normalized, password: password);
    if (_firebaseReady) {
      await _resumeStaffLogin(identity); // barber accounts
      return;
    }
    final existing = _findUserByEmail(identity.email);
    _signInLocally(identity.email, identity.displayName ?? existing?.name);
  }

  /// Forgot password step 1: emails a reset code. Succeeds whether or not an
  /// account exists for [email].
  Future<EmailCodeSent> resetRequestCode({required String email, String language = 'en'}) {
    final normalized = _validEmailOrThrow(email);
    return _emailAuth.requestCode(email: normalized, purpose: EmailCodePurpose.reset, language: language);
  }

  /// Forgot password step 2: checks the emailed [code]. A correct code
  /// returns the verification token for [resetComplete].
  Future<EmailCodeVerified> resetVerifyCode({required String email, required String code}) async {
    final normalized = _validEmailOrThrow(email);
    final validCode = _codeOrThrow(code);
    return _emailAuth.verifyCode(email: normalized, code: validCode, purpose: EmailCodePurpose.reset);
  }

  /// Forgot password step 3: sets [newPassword] with the token from
  /// [resetVerifyCode]. Does not sign in.
  Future<void> resetComplete({
    required String email,
    required String verificationToken,
    required String newPassword,
  }) async {
    final normalized = _validEmailOrThrow(email);
    _checkPassword(newPassword);
    await _emailAuth.resetPassword(email: normalized, verificationToken: verificationToken, newPassword: newPassword);
  }

  // --- Free-plan fallback (Firebase Auth emailed links) ---

  /// Whether [error] from `requestEmailCode` means the auth callables are not
  /// deployed: not-found / unimplemented / internal without a server code
  /// right away; unavailable or a network-level failure only while Firebase
  /// Auth itself is reachable (otherwise the device is just offline).
  Future<bool> _functionsMissing(Object error) async {
    if (error is! EmailAuthException) return false;
    if (error.functionsMissing && error.rawCode != 'unavailable') return true;
    if (error.functionsMissing || error.code == EmailAuthErrorCode.network) {
      try {
        return await _emailAuth.isAuthReachable();
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Registration step 1. Emails a 6-digit code ([EmailFlowStart.sent]), or,
  /// when the auth callables are not deployed (free plan), switches
  /// registration to the link fallback for this session and returns
  /// [EmailFlowStart.link]: continue with [registerWithLink].
  Future<EmailFlowStart> registerStart({required String email, String language = 'en'}) async {
    final normalized = _validEmailOrThrow(email);
    if (_registerUsesLink) return const EmailFlowStart.link();
    try {
      final sent = await _emailAuth.requestCode(email: normalized, purpose: EmailCodePurpose.register, language: language);
      return EmailFlowStart.code(sent);
    } catch (e) {
      if (!await _functionsMissing(e)) rethrow;
      debugPrint('Email code functions unavailable ($e): registration uses verification links.');
      _registerUsesLink = true;
      return const EmailFlowStart.link();
    }
  }

  /// Registration fallback: creates the account with [password], emails a
  /// verification link and stays signed out (log in after opening the
  /// link). Returns whether the link was sent; the account exists either
  /// way. An existing account throws emailAlreadyRegistered.
  Future<bool> registerWithLink({required String email, required String password, String language = 'en'}) async {
    _authError = null;
    final normalized = _validEmailOrThrow(email);
    _checkPassword(password);
    _quietAuthEmails.add(normalized);
    try {
      return await _emailAuth.registerWithVerificationLink(email: normalized, password: password, language: language);
    } finally {
      _quietAuthEmails.remove(normalized);
    }
  }

  /// Sends a new verification link to an unverified password account
  /// (signs in briefly with [password], then out again). Works whether or
  /// not the auth callables are deployed.
  Future<VerificationLinkResult> resendVerificationLink({
    required String email,
    required String password,
    String language = 'en',
  }) async {
    _authError = null;
    final normalized = _validEmailOrThrow(email);
    if (password.isEmpty) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    _quietAuthEmails.add(normalized);
    try {
      return await _emailAuth.resendVerificationLink(email: normalized, password: password, language: language);
    } finally {
      _quietAuthEmails.remove(normalized);
    }
  }

  /// Forgot password step 1. Emails a reset code ([EmailFlowStart.sent]),
  /// or, when the auth callables are not deployed, switches password reset
  /// to Firebase's reset link for this session and sends it
  /// ([EmailFlowStart.link]). Succeeds whether or not an account exists.
  Future<EmailFlowStart> resetStart({required String email, String language = 'en'}) async {
    final normalized = _validEmailOrThrow(email);
    if (!_resetUsesLink) {
      try {
        final sent = await _emailAuth.requestCode(email: normalized, purpose: EmailCodePurpose.reset, language: language);
        return EmailFlowStart.code(sent);
      } catch (e) {
        if (!await _functionsMissing(e)) rethrow;
        debugPrint('Email code functions unavailable ($e): password reset uses reset links.');
        _resetUsesLink = true;
      }
    }
    await _emailAuth.sendPasswordResetLink(email: normalized, language: language);
    return const EmailFlowStart.link();
  }

  /// Forgot password fallback: (re)sends Firebase's password reset link.
  Future<void> resetSendLink({required String email, String language = 'en'}) {
    final normalized = _validEmailOrThrow(email);
    return _emailAuth.sendPasswordResetLink(email: normalized, language: language);
  }

  // --- change password ---

  /// Whether the signed-in account has a password (email/password
  /// provider) that [changePassword] can change. Google-only accounts get
  /// the "Set a password" guidance instead.
  bool get canChangePassword {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) return false;
    return _emailAuth.hasPassword(email);
  }

  /// Signed-in user: re-authenticates with [currentPassword], then sets
  /// [newPassword] (8–128 characters with a letter and a digit).
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) throw AppStateException(AppErrorCode.signInRequired);
    if (currentPassword.isEmpty) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    _checkPassword(newPassword);
    await _emailAuth.changePassword(email: email, currentPassword: currentPassword, newPassword: newPassword);
  }

  /// Email to open "Forgot password" with after [signOutToSetPassword].
  String? _setPasswordEmail;

  /// The auth screen: the email of a Google-only user who signed out to
  /// create a password (read once), else null.
  String? takeSetPasswordEmail() {
    final email = _setPasswordEmail;
    _setPasswordEmail = null;
    return email;
  }

  /// Google-only user: signs out so the login screen opens "Forgot
  /// password" with their Gmail, which emails a code to create a password.
  Future<void> signOutToSetPassword() async {
    // Set first: the auth screen may appear before signOut returns.
    _setPasswordEmail = _currentUser?.email;
    await signOut();
  }
  // --- end change password ---

  // --- barber accounts (owner-created login with a temporary password) ---

  /// Creates the Auth account for barbers the owner adds with a temporary
  /// password (a secondary Firebase app; an in-memory fake locally).
  late StaffAccountService _staffAccounts = _defaultLocalStaffAccounts();

  StaffAccountService _defaultLocalStaffAccounts() => LocalStaffAccountService(() => _emailAuth);

  StaffAccountService get staffAccountService => _staffAccounts;

  /// Tests: replaces the account creation. [loadSeed] restores the fake.
  @visibleForTesting
  set staffAccountService(StaffAccountService service) => _staffAccounts = service;

  /// Profile setup: the contact number on the invited barber's profile.
  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  /// Unverified accounts already accepted this session (owner-created
  /// barber logins).
  final Set<String> _staffUnverifiedUids = {};

  /// An unverified email login the auth listener skipped while
  /// [EmailAuthService.signIn] was still deciding; [loginWithEmail] resumes
  /// it once the account is accepted.
  String? _ignoredUnverifiedUid;

  /// The signed-in barber still uses the owner's temporary password: the
  /// app shows "Choose your new password" before any dashboard. (A login
  /// without a password provider, e.g. Google, has nothing to change.)
  bool get mustChangePassword => (_currentUser?.mustChangePassword ?? false) && canChangePassword;

  /// Local mode: an unverified address may log in when it has a profile or
  /// an invite carrying the uid its account was created with.
  Future<bool> _localUnverifiedAllowed(String email) async {
    final normalized = normalizeEmail(email);
    final staff = _staffAccounts;
    final uid = staff is LocalStaffAccountService ? staff.uidFor(normalized) : null;
    final profile = _findUserByEmail(normalized);
    return unverifiedSignInAllowed(
      uid: profile?.uid ?? uid ?? '',
      profileExists: profile != null,
      invite: _cache.invites[normalized],
    );
  }

  /// Firebase: reads `users/{uid}` and, without a profile,
  /// `invites/{token email}` (rules: readable by the account whose uid is
  /// in `authUid`). Remembers an accepted uid for the auth listener.
  Future<bool> _cloudUnverifiedAllowed(User user) async {
    final email = normalizeEmail(user.email ?? '');
    if (email.isEmpty) return false;
    var profileExists = false;
    try {
      profileExists = (await _db.collection('users').doc(user.uid).get()).exists;
    } catch (e) {
      debugPrint('Profile check failed: $e');
    }
    UserInvite? invite;
    if (!profileExists) {
      try {
        final snap = await _db.collection('invites').doc(email).get();
        if (snap.exists) invite = UserInvite.fromMap(snap.data()!, snap.id);
      } catch (_) {
        // Denied: no invite for this uid.
      }
    }
    final allowed = unverifiedSignInAllowed(uid: user.uid, profileExists: profileExists, invite: invite);
    if (allowed) _staffUnverifiedUids.add(user.uid);
    return allowed;
  }

  /// Auth listener: an unverified session (e.g. restored at app start) may
  /// continue only for an accepted email/password staff account.
  Future<bool> _staffUnverifiedOk(User user) async {
    if (!user.providerData.any((p) => p.providerId == 'password')) return false;
    if (_staffUnverifiedUids.contains(user.uid)) return true;
    return _cloudUnverifiedAllowed(user);
  }

  /// After an accepted unverified login: load the session the auth listener
  /// skipped (it fired before the account was accepted).
  Future<void> _resumeStaffLogin(EmailIdentity identity) async {
    final uid = identity.uid;
    if (uid == null || _ignoredUnverifiedUid != uid) return;
    _ignoredUnverifiedUid = null;
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null || fbUser.uid != uid) return;
    await _onFirebaseAuthChanged(fbUser);
  }

  /// The invited barber's private contact number
  /// (`barbers/{id}/private/contact`, readable by the invitee through their
  /// invite), to prefill setup. Null when it cannot be read.
  Future<String?> _loadBarberPhone(UserInvite? invite) async {
    final shopId = invite?.shopId;
    final barberId = invite?.barberId;
    if (shopId == null || barberId == null) return null;
    final cached = _cache.barberPhones[barberId];
    if (cached != null) return cached;
    try {
      final snap = await _db.doc(FirestoreDataStore.barberContactPath(shopId, barberId)).get();
      final phone = snap.data()?['phone'];
      return phone is String && phone.isNotEmpty ? phone : null;
    } catch (_) {
      return null;
    }
  }

  /// First login with a temporary password: proves [temporaryPassword],
  /// sets [newPassword] (8–128 characters with a letter and a digit) and
  /// clears `users/{uid}.mustChangePassword` (a self-update of that one
  /// field to false).
  Future<void> completeRequiredPasswordChange({
    required String temporaryPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    await changePassword(currentPassword: temporaryPassword, newPassword: newPassword);
    if (_firebaseReady) {
      await _db.collection('users').doc(user.uid).update({'mustChangePassword': false});
    } else {
      final cached = _cache.users[user.uid];
      if (cached != null) _cache.users[user.uid] = cached.copyWith(mustChangePassword: false);
    }
    final current = _currentUser;
    if (current != null && current.uid == user.uid) _currentUser = current.copyWith(mustChangePassword: false);
    notifyListeners();
  }

  /// Owner: adds a barber profile AND creates their login: an email/password
  /// account for [email] with [temporaryPassword] (8–128 characters with a
  /// letter and a digit). The barber profile and `invites/{email}` (role
  /// barber, `authUid` = the new uid, `mustChangePassword: true`) are written
  /// in ONE batch; if that fails the new account is deleted again.
  ///
  /// Throws [EmailAuthException] emailAlreadyRegistered when [email]
  /// already has an account: offer [addBarber] with that email (an
  /// invitation) instead.
  Future<BarberAccountCreated> addBarberWithAccount({
    required String shopId,
    required String name,
    required String title,
    required String email,
    required String temporaryPassword,
    String? phone,
    List<String>? specialties,
    String? avatarUrl,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 100) throw AppFormatException(AppErrorCode.invalidName);
    final login = validEmailOrNull(email);
    if (login == null) throw AppFormatException(AppErrorCode.invalidEmail);
    _assertEmailCanBeInvited(login);
    String? normalizedPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      normalizedPhone = normalizeEthiopianPhone(phone);
      if (normalizedPhone == null) throw AppFormatException(AppErrorCode.invalidPhone);
    }
    _checkPassword(temporaryPassword);

    final barberId = _uuid.v4();
    final barber = Barber(
      id: barberId,
      shopId: shopId,
      name: cleanName,
      title: title.trim(),
      specialties: specialties ?? const ['Skin Fade', 'Beard Trim'],
      avatarUrl: avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    );
    final uid = await _staffAccounts.createAccount(
      email: login,
      password: temporaryPassword,
      persist: (uid) => _store.addBarber(
        barber,
        phone: normalizedPhone, // private barber phone (private/contact)
        UserInvite(
          email: login,
          role: UserRole.barber,
          name: cleanName,
          shopId: shopId,
          barberId: barberId,
          createdBy: _currentUser?.uid ?? 'system',
          createdAt: DateTime.now(),
          authUid: uid,
          mustChangePassword: true,
        ),
      ),
    );
    notifyListeners();
    return BarberAccountCreated(barberId: barberId, uid: uid, email: login, temporaryPassword: temporaryPassword);
  }
  // --- end barber accounts ---

  /// Demo builds: one-tap sign-in as the seeded account with [email] (the
  /// "Continue as ..." persona buttons). Does nothing once Firebase is
  /// attached, so it cannot bypass real sign-in.
  void signInAsDemoUser(String email) {
    if (_firebaseReady) return;
    final normalized = normalizeEmail(email);
    final user = _findUserByEmail(normalized);
    _authError = null;
    _signInLocally(normalized, user?.name);
  }

  AppUser? _findUserByEmail(String email) =>
      _cache.users.values.where((u) => u.email != null && normalizeEmail(u.email!) == email).firstOrNull;

  /// Local (demo / test) equivalent of [_onFirebaseAuthChanged].
  void _signInLocally(String email, String? displayName) {
    _pendingEmail = email;
    _pendingDisplayName = displayName;

    final existing = _findUserByEmail(email);
    final invite = _cache.invites[email];
    // admin users: a disabled account cannot sign in.
    if (existing != null && existing.disabled) {
      _clearPending();
      _currentUser = null;
      _authError = AppStateException(AppErrorCode.accountDisabled);
      _authStatus = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    if (existing != null) {
      var user = existing;
      if (invite != null && existing.role == UserRole.customer) {
        user = _withInviteRole(existing, invite);
        _cache.invites.remove(email);
        _cache.users[user.uid] = user;
        _claimShopLocally(user);
      }
      _clearPending();
      _currentUser = user;
      _authStatus = AuthStatus.signedIn;
    } else {
      _pendingInvite = invite;
      _pendingPhone = invite?.barberId == null ? null : _cache.barberPhones[invite!.barberId]; // barber accounts
      _authStatus = AuthStatus.needsProfile;
    }
    notifyListeners();
  }

  /// Creates the profile for a first-time user: [name] and an Ethiopian
  /// mobile [phone] (for SMS reminders, payments and bookings; not
  /// verified). The email is the signed-in Google email. The role comes
  /// from the pending invite for that email, or is `customer` without one;
  /// the invite is consumed in the same write.
  Future<void> completeProfile({required String name, required String phone}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw AppFormatException(AppErrorCode.invalidName);
    }
    final normalizedPhone = normalizeEthiopianPhone(phone);
    if (normalizedPhone == null) {
      throw AppFormatException(AppErrorCode.invalidPhone);
    }
    final email = _pendingEmail;
    if (_authStatus != AuthStatus.needsProfile || email == null) {
      throw AppStateException(AppErrorCode.signInRequired);
    }
    final invite = _pendingInvite;

    // Barber accounts: locally the uid the owner's account creation issued.
    final uid = _firebaseReady ? FirebaseAuth.instance.currentUser!.uid : (invite?.authUid ?? _uuid.v4());
    final user = AppUser(
      uid: uid,
      email: email,
      name: cleanName,
      phone: normalizedPhone,
      role: invite?.role ?? UserRole.customer,
      shopId: invite?.shopId,
      barberId: invite?.barberId,
      createdAt: DateTime.now(),
      mustChangePassword: invite?.mustChangePassword ?? false, // barber accounts
    );

    if (_firebaseReady) {
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), user.toMap());
      if (invite != null) batch.delete(_db.collection('invites').doc(email));
      await batch.commit();
      await _claimShopInCloud(user);
      await _cloud!.start(user);
    } else {
      _cache.invites.remove(email);
      _claimShopLocally(user);
    }

    _cache.users[user.uid] = user;
    _currentUser = user;
    _clearPending();
    _authStatus = AuthStatus.signedIn;
    notifyListeners();
  }

  /// Updates the signed-in user's own name, language ('en' | 'am') and/or
  /// mobile [phone] (validated, stored as E.164).
  Future<void> updateMyProfile({String? name, String? language, String? phone}) async {
    final user = _currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    final cleanName = name?.trim();
    if (cleanName != null && (cleanName.isEmpty || cleanName.length > 100)) {
      throw AppFormatException(AppErrorCode.invalidName);
    }
    if (language != null && language != 'en' && language != 'am') {
      throw ArgumentError.value(language, 'language', "must be 'en' or 'am'");
    }
    String? normalizedPhone;
    if (phone != null) {
      normalizedPhone = normalizeEthiopianPhone(phone);
      if (normalizedPhone == null) throw AppFormatException(AppErrorCode.invalidPhone);
    }
    final updated = user.copyWith(name: cleanName, language: language, phone: normalizedPhone);
    _currentUser = updated;
    final write = _store.updateUserProfile(user.uid, name: cleanName, language: language, phone: normalizedPhone);
    notifyListeners();
    await write;
  }

  /// Runs at the start of [signOut] while the user is still authenticated
  /// (NotificationService uses it to delete this device's push token).
  Future<void> Function()? beforeSignOut;

  Future<void> signOut() async {
    final hook = beforeSignOut;
    if (hook != null && _currentUser != null) {
      try {
        await hook().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('beforeSignOut failed: $e');
      }
    }
    _clearPending();
    _authError = null;
    _forgetPendingAccountDeletion(); // account deletion
    if (_firebaseReady) {
      await _googleAuth.signOut();
      return; // _onFirebaseAuthChanged resets the session.
    }
    _currentUser = null;
    _authStatus = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _onFirebaseAuthChanged(User? fbUser) async {
    if (fbUser == null) {
      await _cloud?.stop();
      _forgetPendingAccountDeletion(); // account deletion
      _currentUser = null;
      _clearPending();
      _authStatus = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    final signedInEmail = normalizeEmail(fbUser.email ?? '');
    // A fallback flow signs in briefly and out again itself.
    if (_quietAuthEmails.contains(signedInEmail)) return;
    // The login form explains an unverified address (with "Resend link").
    if (!fbUser.emailVerified &&
        _emailLoginEmails.contains(signedInEmail) &&
        !_staffUnverifiedUids.contains(fbUser.uid)) {
      _ignoredUnverifiedUid = fbUser.uid; // barber accounts: loginWithEmail resumes it
      return;
    }
    // Superseded by a later sign-out / sign-in (its own event follows).
    if (FirebaseAuth.instance.currentUser?.uid != fbUser.uid) return;

    _authStatus = AuthStatus.initializing;
    notifyListeners();

    try {
      final rawEmail = fbUser.email;
      // Barber accounts: an owner-created login (unverified) may continue.
      if (rawEmail == null || rawEmail.isEmpty || (!fbUser.emailVerified && !await _staffUnverifiedOk(fbUser))) {
        // Only verified emails can sign in (the rules check
        // request.auth.token.email_verified too): Google accounts, and
        // email/password accounts created with an emailed code or whose
        // verification link was opened. Sessions from the old phone sign-in
        // end here quietly.
        final providers = fbUser.providerData.map((p) => p.providerId).toSet();
        if (providers.contains('google.com')) {
          _authError = AppStateException(AppErrorCode.googleEmailMissing);
        } else if (providers.contains('password')) {
          _authError = AppStateException(AppErrorCode.emailNotVerified);
        }
        await FirebaseAuth.instance.signOut();
        return;
      }
      final email = normalizeEmail(rawEmail);
      _pendingEmail = email;
      _pendingDisplayName = fbUser.displayName;

      UserInvite? invite;
      try {
        final inviteSnap = await _db.collection('invites').doc(email).get();
        if (inviteSnap.exists) invite = UserInvite.fromMap(inviteSnap.data()!, inviteSnap.id);
      } catch (e) {
        // Barber accounts: an unverified login may read only an invite that
        // carries its uid; any other (or a missing) invite is denied.
        if (fbUser.emailVerified) rethrow;
      }

      final userSnap = await _db.collection('users').doc(fbUser.uid).get();
      if (!userSnap.exists) {
        _pendingInvite = invite;
        _pendingPhone = await _loadBarberPhone(invite); // barber accounts
        _authStatus = AuthStatus.needsProfile;
        notifyListeners();
        return;
      }

      var user = AppUser.fromMap(userSnap.data()!, userSnap.id);
      // admin users: a disabled account is signed out with a clear message
      // (on Blaze Firebase Auth refuses it before this: 'user-disabled').
      if (user.disabled) {
        _clearPending();
        _authError = AppStateException(AppErrorCode.accountDisabled);
        await FirebaseAuth.instance.signOut();
        return;
      }
      // A customer who was later invited as staff/owner is upgraded once.
      // Existing staff, owners and admins are never changed by an invite.
      if (invite != null && user.role == UserRole.customer) {
        final upgraded = _withInviteRole(user, invite);
        final batch = _db.batch();
        batch.set(_db.collection('users').doc(user.uid), upgraded.toMap());
        batch.delete(_db.collection('invites').doc(invite.email));
        await batch.commit();
        await _claimShopInCloud(upgraded);
        user = upgraded;
      }

      _clearPending();
      _currentUser = user;
      // Open the role-scoped listeners and wait for the first data so the
      // dashboards do not flash empty.
      await _cloud!.start(user);
      _authError = null;
      _authStatus = AuthStatus.signedIn;
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load user profile: $e');
      _authError = AppStateException(AppErrorCode.accountLoadFailed);
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Tests: simulates the own-profile listener delivering [user].
  @visibleForTesting
  void debugCurrentUserDocChanged(AppUser? user) => _onCurrentUserDocChanged(user);

  /// The signed-in user's own profile document changed in Firestore.
  void _onCurrentUserDocChanged(AppUser? user) {
    if (_deletingAccount) return; // account deletion: the profile goes away on purpose
    final current = _currentUser;
    if (current == null || _authStatus != AuthStatus.signedIn) return;
    if (user == null) {
      // Profile removed (e.g. by an admin): end the session.
      signOut();
      return;
    }
    if (user.disabled) {
      // admin users: disabled while signed in: sign out now, with a message.
      signOut().then((_) {
        _authError = AppStateException(AppErrorCode.accountDisabled);
        notifyListeners();
      });
      return;
    }
    _currentUser = user;
    if (user.role != current.role || user.shopId != current.shopId || user.barberId != current.barberId) {
      // Role or shop changed: re-scope the listeners.
      _cloud?.start(user);
    }
  }

  AppUser _withInviteRole(AppUser user, UserInvite invite) {
    return AppUser(
      uid: user.uid,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: invite.role,
      shopId: invite.shopId,
      barberId: invite.barberId,
      createdAt: user.createdAt,
      language: user.language,
    );
  }

  /// Shops registered by the admin start with an empty ownerId; the invited
  /// owner fills it in on first sign-in.
  void _claimShopLocally(AppUser user) {
    if (user.role != UserRole.barbershopOwner || user.shopId == null) return;
    final shop = _cache.shops[user.shopId];
    if (shop != null && shop.ownerId.isEmpty) _cache.shops[shop.id] = shop.copyWith(ownerId: user.uid);
  }

  Future<void> _claimShopInCloud(AppUser user) async {
    if (user.role != UserRole.barbershopOwner || user.shopId == null) return;
    try {
      final ref = _db.collection('barbershops').doc(user.shopId);
      final snap = await ref.get();
      if (snap.exists && (snap.data()?['ownerId'] ?? '') == '') {
        await ref.update({'ownerId': user.uid});
      }
    } catch (e) {
      debugPrint('Could not link shop owner: $e');
    }
  }

  /// Throws if [email] already belongs to a staff, owner or admin account
  /// (an invite must never silently move that person to another role).
  /// With Firestore this checks the users the caller can see (all for the
  /// admin, the shop's staff for an owner); the security rules and the
  /// sign-in flow enforce it for everyone else (invites only upgrade
  /// customers).
  void _assertEmailCanBeInvited(String email) {
    final existing = _findUserByEmail(email);
    if (existing != null && existing.role != UserRole.customer) {
      throw AppFormatException(AppErrorCode.emailAlreadyStaff, [existing.role]);
    }
  }

  /// Demo / test helper: instantly become a demo persona of [role].
  /// Does nothing once Firebase is attached, so it cannot bypass real sign-in.
  void switchRole(UserRole role, {String? targetShopId, String? targetBarberId}) {
    if (_firebaseReady) return;
    final users = _cache.users.values;
    AppUser? match;
    switch (role) {
      case UserRole.admin:
      case UserRole.customer:
        match = users.where((u) => u.role == role).firstOrNull;
      case UserRole.barbershopOwner:
        match = users
                .where((u) => u.role == role && (targetShopId == null || u.shopId == targetShopId))
                .firstOrNull ??
            users.where((u) => u.role == role).firstOrNull;
      case UserRole.barber:
        match = users
                .where((u) => u.role == role && (targetBarberId == null || u.barberId == targetBarberId))
                .firstOrNull ??
            users.where((u) => u.role == role).firstOrNull;
    }
    if (match == null) return; // No demo data loaded.
    _currentUser = match;
    _authStatus = AuthStatus.signedIn;
    notifyListeners();
  }

  // --- Platform Admin: SaaS Barbershop Registration & Metrics ---

  /// Length of the free trial given to newly registered shops.
  static const Duration trialPeriod = Duration(days: 30);

  /// Registers a shop and invites its owner by Google email address. The
  /// owner gets the barbershopOwner role when they first sign in with
  /// Google using that email. The shop starts with the default opening
  /// hours (09:00-20:00, every day); only the owner changes them.
  Future<String> registerBarbershopByAdmin({
    required String shopName,
    required String ownerName,
    required String ownerEmail,
    required String address,
    required String city,
    required String description,
    required String imageUrl,
    required bool isVerified,
    String subCity = '',
    String? landmark,
    // shop location (maps): optional map pin, both or neither.
    double? latitude,
    double? longitude,
    String? shopPhone,
    // --- shop applications --- set when approving a ShopApplication: the
    // application update is committed with the shop.
    ShopApplicationApproval? fromApplication,
  }) async {
    final email = validEmailOrNull(ownerEmail);
    if (email == null) {
      throw AppFormatException(AppErrorCode.invalidOwnerEmail);
    }
    _assertEmailCanBeInvited(email);
    final contactPhone = shopPhone?.trim() ?? '';

    final shopId = _uuid.v4();
    final leadBarberId = _uuid.v4();
    final now = DateTime.now();

    final shop = Barbershop(
      id: shopId,
      ownerId: '', // Filled in when the invited owner signs in.
      name: shopName,
      description: description,
      address: address,
      city: city,
      subCity: subCity,
      landmark: (landmark == null || landmark.trim().isEmpty) ? null : landmark.trim(),
      latitude: isValidShopCoordinate(latitude, longitude) ? latitude : null,
      longitude: isValidShopCoordinate(latitude, longitude) ? longitude : null,
      phone: contactPhone,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      rating: 5.0,
      reviewCount: 0,
      // Default opening hours; the owner sets the real ones after sign-in.
      openingHour: 9,
      closingHour: 20,
      workingDays: const [1, 2, 3, 4, 5, 6, 7],
      isVerified: isVerified,
      subscriptionPlan: 'trial',
      subscriptionStatus: SubscriptionStatus.trialing,
      subscriptionEndsAt: now.toUtc().add(trialPeriod),
    );

    final starterServices = [
      BarbershopService(
        id: _uuid.v4(),
        shopId: shopId,
        name: 'Haircut & Style',
        description: 'Precision cut, neck razor clean-up and styling.',
        price: 400,
        durationMinutes: 40,
      ),
      BarbershopService(
        id: _uuid.v4(),
        shopId: shopId,
        name: 'Beard Trim & Hot Towel',
        description: 'Beard shaping, hot towel and straight-razor line-up.',
        price: 250,
        durationMinutes: 30,
      ),
    ];

    // The owner also appears as the shop's lead barber profile.
    final leadBarber = Barber(
      id: leadBarberId,
      shopId: shopId,
      name: ownerName,
      title: 'Master Barber / Lead Stylist',
      // Barber profiles are public: the sign-in email lives only in the
      // invite and the private users/{uid} profile.
      phone: normalizeEthiopianPhone(contactPhone),
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      specialties: ['Skin Fade', 'Beard Sculpting', 'Hot Shave'],
    );

    final ownerInvite = UserInvite(
      email: email,
      role: UserRole.barbershopOwner,
      name: ownerName,
      shopId: shopId,
      createdBy: _currentUser?.uid ?? 'system',
      createdAt: now,
    );

    // --- shop applications ---
    if (fromApplication != null) {
      await _createShopForApplication(fromApplication,
          shop: shop, services: starterServices, barbers: [leadBarber], ownerInvite: ownerInvite);
      return shopId;
    }
    // --- end shop applications ---
    await _write(_store.createShop(
      shop: shop,
      services: starterServices,
      barbers: [leadBarber],
      ownerInvite: ownerInvite,
    ));
    return shopId;
  }

  /// Saves a shop's profile (name, description, address, sub-city, landmark,
  /// phone, image, hours, working days). Ownership, verification, rating and
  /// subscription fields in [updatedShop] are ignored.
  Future<void> updateShop(Barbershop updatedShop) async {
    if (!_cache.shops.containsKey(updatedShop.id)) return;
    await _write(_store.updateShopProfile(updatedShop));
  }

  Future<void> toggleShopVerification(String shopId) async {
    final shop = _cache.shops[shopId];
    if (shop == null) return;
    await _write(_store.setShopVerified(shopId, !shop.isVerified));
  }

  /// Admin: sets a shop's plan and subscription status (normally the
  /// payments Cloud Functions do this).
  Future<void> updateShopSubscription(
    String shopId, {
    required String plan,
    required SubscriptionStatus status,
    DateTime? endsAt,
  }) async {
    if (!_cache.shops.containsKey(shopId)) return;
    await _write(_store.updateShopSubscription(shopId, plan: plan, status: status, endsAt: endsAt));
  }

  /// Deletes a shop with the full cascade (see shop_deletion.dart): upcoming
  /// bookings cancelled and their customers notified, the owner and
  /// barbers downgraded to customers (with a notice), invites revoked, the
  /// shop's subcollections and finally the shop document deleted. Past
  /// bookings stay. [onStep] reports each step as it starts. Throws
  /// [ShopDeletionException] naming the failed step; everything before it
  /// stays done and running it again continues safely.
  Future<void> deleteShop(String shopId, {void Function(ShopDeletionStep step)? onStep}) async {
    final shop = _cache.shops[shopId];
    final shopName = shop?.name ?? '';
    final adminUid = _currentUser?.uid ?? 'system';
    final now = _nowUtc();

    Future<T> step<T>(ShopDeletionStep s, Future<T> Function() run) async {
      onStep?.call(s);
      try {
        return await run();
      } catch (e) {
        debugPrint('Shop deletion failed at ${s.name}: $e');
        throw ShopDeletionException(s, e);
      }
    }

    // 1. Record who goes (for the Blaze function) and stop new bookings.
    await step(ShopDeletionStep.prepare, () async {
      final staff = await _store.staffOfShop(shopId);
      final invites = await _store.invitesOfShop(shopId);
      await _store.recordShopDeletion(ShopDeletionRecord(
        shopId: shopId,
        shopName: shopName,
        requestedBy: adminUid,
        requestedAt: now,
        staffUids: [for (final u in staff) u.uid],
        barberAccountUids: {
          for (final u in staff)
            if (u.role == UserRole.barber) u.uid,
          for (final i in invites)
            if (i.role == UserRole.barber && i.authUid != null) i.authUid!,
        }.toList(),
      ));
      if (shop != null && !shop.adminSuspended) {
        await _store.setShopAdminSuspension(
          shopId,
          Barbershop.adminSuspensionFields(suspended: true, reason: kShopDeletionSuspendReason, at: now, by: adminUid),
        );
      }
    });

    // 2. Upcoming bookings: cancelled, customers notified.
    final notices = <ShopDeletionNotice>[];
    await step(ShopDeletionStep.bookings, () async {
      final items = planShopBookingCancellations(
        shopId,
        await _store.upcomingBookingsOfShop(shopId, now),
        now,
        languageOf: (uid) => _cache.users[uid]?.language,
      );
      await _store.cancelBookingsForShopDeletion(
        items,
        cancelledBy: adminUid,
        // refunds: paid bookings are flagged for a full refund in the same batch.
        refund: RefundContext(
          by: RefundCanceller.admin,
          nowUtc: now,
          reason: RefundReasons.shopDeleted,
          languageOf: (uid) => _cache.users[uid]?.language,
        ),
      );
      notices.addAll(items.map((i) => i.notice));
    });

    // 3. Owner and barbers become customers; invites revoked.
    await step(ShopDeletionStep.staff, () async {
      final items = planShopStaffRevocations(shopId, shopName, await _store.staffOfShop(shopId), now);
      await _store.revokeShopStaff(shopId, items);
      notices.addAll(items.map((i) => i.notice));
    });

    // 4. Subcollections, 5. the shop document (last).
    await step(ShopDeletionStep.data, () => _store.deleteShopData(shopId));
    await step(ShopDeletionStep.shop, () => _store.deleteShopDoc(shopId));

    if (!_firebaseReady) {
      final sink = onLocalNotice;
      for (final n in notices) {
        sink?.call(n);
      }
    }
    notifyListeners();
  }

  /// Local mode (demo, tests): receives the inbox notices the shop-deletion
  /// cascade writes (NotificationService puts them in the local inboxes).
  void Function(ShopDeletionNotice notice)? onLocalNotice;

  /// Admin: what deleting [shopId] removes, for the confirmation dialog.
  /// Upcoming bookings are counted with a query (null if that fails).
  Future<ShopDeletionPreview> previewShopDeletion(String shopId) async {
    _requireAdmin();
    int? upcoming;
    try {
      final now = _nowUtc();
      upcoming = planShopBookingCancellations(shopId, await _store.upcomingBookingsOfShop(shopId, now), now).length;
    } catch (e) {
      debugPrint('Could not count upcoming bookings: $e');
    }
    return ShopDeletionPreview(
      barbers: _cache.barbers.values.where((b) => b.shopId == shopId).length,
      services: _cache.services.values.where((s) => s.shopId == shopId).length,
      staffAccounts: _cache.users.values
          .where((u) => u.shopId == shopId && (u.role == UserRole.barbershopOwner || u.role == UserRole.barber))
          .length,
      pendingInvites: _cache.invites.values.where((i) => i.shopId == shopId).length,
      upcomingBookings: upcoming,
    );
  }

  // --- admin shop management (logic in features/admin/admin_shops_logic.dart) ---

  void _requireAdmin() {
    if (_currentUser?.role != UserRole.admin) throw const AdminShopException(AdminShopError.notAdmin);
  }

  /// Admin: saves the edit screen in one write (profile, verified flag and
  /// the subscription override: plan, status, end date). The opening hours
  /// (openingHour, closingHour, workingDays) are never written: only the
  /// shop owner sets them ([updateShop]).
  Future<void> adminUpdateShop(Barbershop edited) async {
    _requireAdmin();
    if (!_cache.shops.containsKey(edited.id)) throw const AdminShopException(AdminShopError.shopNotFound);
    // Any loaded plan id (or 'trial'); not checked when no plans are loaded.
    final planIds = _cache.plans.isEmpty ? const <String>[] : {..._cache.plans.keys, 'trial'};
    final shop = validateAdminShopEdit(edited, planIds: planIds);
    await _write(_store.adminUpdateShop(shop));
  }

  /// Admin: suspends a shop (hidden from customers, no new bookings) with
  /// a reason of 1..[kMaxShopSuspendReasonLength] characters.
  Future<void> suspendShop(String shopId, String reason) async {
    _requireAdmin();
    final r = validateSuspendReason(reason);
    if (!_cache.shops.containsKey(shopId)) throw const AdminShopException(AdminShopError.shopNotFound);
    await _write(_store.setShopAdminSuspension(
      shopId,
      Barbershop.adminSuspensionFields(suspended: true, reason: r, at: _nowUtc(), by: _currentUser!.uid),
    ));
  }

  /// Admin: lifts an admin suspension.
  Future<void> reactivateShop(String shopId) async {
    _requireAdmin();
    if (!_cache.shops.containsKey(shopId)) throw const AdminShopException(AdminShopError.shopNotFound);
    await _write(_store.setShopAdminSuspension(shopId, Barbershop.adminSuspensionFields(suspended: false)));
  }

  /// Admin: deletes the shop after the typed-name confirmation, with the
  /// full cascade of [deleteShop] (past bookings stay).
  Future<void> deleteShopConfirmed(String shopId, String typedName,
      {void Function(ShopDeletionStep step)? onStep}) async {
    _requireAdmin();
    final shop = _cache.shops[shopId];
    if (shop == null) throw const AdminShopException(AdminShopError.shopNotFound);
    if (!deleteConfirmationMatches(typedName, shop.name)) {
      throw const AdminShopException(AdminShopError.nameMismatch);
    }
    await deleteShop(shopId, onStep: onStep);
  }

  /// Admin: the shop's owner account, or the pending owner invite.
  ShopOwnerInfo getShopOwnerInfo(String shopId) {
    final shop = _cache.shops[shopId];
    if (shop == null) return const ShopOwnerInfo();
    return ShopOwnerInfo.find(shop, users: _cache.users.values, invites: _cache.invites.values);
  }
  // --- end admin shop management ---

  // --- Plans ---

  /// Subscription plans (loaded for owners and admins).
  List<SubscriptionPlan> getPlans() => List.unmodifiable(_cache.plans.values);

  SubscriptionPlan? getPlan(String planId) => _cache.plans[planId];

  /// Admin: creates or replaces `plans/{plan.id}` (see PaymentService).
  Future<void> savePlan(SubscriptionPlan plan) async {
    if (_firebaseReady) {
      await _db.collection('plans').doc(plan.id).set(plan.toMap());
    } else {
      _cache.plans[plan.id] = plan;
    }
    notifyListeners();
  }

  /// Local mode only (demo builds, tests): records the outcome of a
  /// simulated Chapa payment on a booking. With Firebase the payments Cloud
  /// Functions write paymentStatus and this throws.
  void applySimulatedBookingPayment(String bookingId, PaymentStatus status, {String? paymentId}) {
    if (_firebaseReady) throw AppStateException(AppErrorCode.serverOnly);
    final booking = _cache.bookings[bookingId];
    if (booking == null) return;
    _cache.bookings[bookingId] =
        booking.copyWith(paymentStatus: status, paymentMethod: PaymentMethod.chapa, paymentId: paymentId);
    notifyListeners();
  }

  // --- Barbershop Management ---

  /// Shops the current user may browse. Suspended shops are hidden from
  /// everyone except the admin and the shop's own staff.
  List<Barbershop> getShops() {
    final user = _currentUser;
    return _cache.shops.values
        // admin shop management: isBlocked = admin-suspended or unpaid.
        .where((s) => !s.isBlocked || user?.role == UserRole.admin || (user?.shopId != null && user!.shopId == s.id))
        .toList(growable: false);
  }

  Barbershop? getShopById(String shopId) => _cache.shops[shopId];

  List<BarberWithShop> getAllBarbersWithShops() {
    final list = <BarberWithShop>[];
    for (final shop in getShops()) {
      for (final b in _cache.barbers.values.where((b) => b.shopId == shop.id)) {
        list.add(BarberWithShop(barber: b, shop: shop));
      }
    }
    return list;
  }

  // --- Services ---
  List<BarbershopService> getServicesForShop(String shopId) {
    return _cache.services.values.where((s) => s.shopId == shopId).toList();
  }

  BarbershopService? getServiceById(String serviceId) => _cache.services[serviceId];

  Future<void> addService({
    required String shopId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
  }) async {
    _validateService(name: name, price: price, durationMinutes: durationMinutes);
    final service = BarbershopService(
      id: _uuid.v4(),
      shopId: shopId,
      name: name,
      description: description,
      price: price,
      durationMinutes: durationMinutes,
    );
    await _write(_store.addService(service));
  }

  Future<void> updateService(BarbershopService service) async {
    if (!_cache.services.containsKey(service.id)) return;
    _validateService(name: service.name, price: service.price, durationMinutes: service.durationMinutes);
    await _write(_store.updateService(service));
  }

  /// Same limits as `isValidService` in firestore.rules.
  static void _validateService({required String name, required double price, required int durationMinutes}) {
    if (name.trim().isEmpty || price.isNaN || price < 0 || durationMinutes < 5) {
      throw AppFormatException(AppErrorCode.invalidService);
    }
    if (durationMinutes > kMaxServiceDurationMinutes) {
      throw AppFormatException(AppErrorCode.serviceTooLong, [kMaxServiceDurationMinutes]);
    }
  }

  Future<void> deleteService(String serviceId) async {
    final service = _cache.services[serviceId];
    if (service == null) return;
    await _write(_store.deleteService(service));
  }

  // --- Barbers & Staff ---
  List<Barber> getBarbersForShop(String shopId) {
    return _cache.barbers.values.where((b) => b.shopId == shopId).toList();
  }

  List<Barber> getAllBarbers() => List.unmodifiable(_cache.barbers.values);

  Barber? getBarberById(String barberId) => _cache.barbers[barberId];

  /// The barber profile linked to the signed-in barber account, if any.
  Barber? getBarberForCurrentUser() {
    final barberId = _currentUser?.barberId;
    if (barberId == null) return null;
    return getBarberById(barberId);
  }

  /// Adds a barber profile to a shop. If [email] is given, the barber is also
  /// invited to sign in: the first Google sign-in with that email gets the
  /// barber role linked to this profile. [phone] is an optional contact
  /// number (validated when given).
  Future<void> addBarber({
    required String shopId,
    required String name,
    required String title,
    String? email,
    String? phone,
    List<String>? specialties,
    String? avatarUrl,
    List<int>? workingDays,
    int? startHour,
    int? endHour,
  }) async {
    String? inviteEmail;
    if (email != null && email.trim().isNotEmpty) {
      inviteEmail = validEmailOrNull(email);
      if (inviteEmail == null) {
        throw AppFormatException(AppErrorCode.invalidEmail);
      }
      _assertEmailCanBeInvited(inviteEmail);
    }
    String? normalizedPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      normalizedPhone = normalizeEthiopianPhone(phone);
      if (normalizedPhone == null) {
        throw AppFormatException(AppErrorCode.invalidPhone);
      }
    }

    final id = _uuid.v4();
    final barber = Barber(
      id: id,
      shopId: shopId,
      name: name,
      title: title,
      specialties: specialties ?? const ['Skin Fade', 'Beard Trim'],
      avatarUrl: avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      workingDays: workingDays,
      startHour: startHour,
      endHour: endHour,
    );

    final invite = inviteEmail == null
        ? null
        : UserInvite(
            email: inviteEmail,
            role: UserRole.barber,
            name: name,
            shopId: shopId,
            barberId: id,
            createdBy: _currentUser?.uid ?? 'system',
            createdAt: DateTime.now(),
          );

    // private barber phone: the phone goes to private/contact, not the profile.
    await _write(_store.addBarber(barber, invite, phone: normalizedPhone));
  }

  /// Saves a barber's profile fields (not shopId or ratings).
  Future<void> updateBarber(Barber barber) async {
    if (!_cache.barbers.containsKey(barber.id)) return;
    await _write(_store.updateBarberProfile(barber));
  }

  /// Owner: sets a barber's own working days and hours (Addis time).
  /// Pass all three as null to follow the shop's days and hours again.
  /// Throws [AppFormatException] for an empty day list or hours where the
  /// end is not after the start.
  Future<void> updateBarberSchedule(
    String barberId, {
    required List<int>? workingDays,
    required int? startHour,
    required int? endHour,
  }) async {
    final barber = _cache.barbers[barberId];
    if (barber == null) return;
    final days = workingDays == null ? null : (workingDays.toSet().toList()..sort());
    if (days != null && (days.isEmpty || days.any((d) => d < 1 || d > 7))) {
      throw AppFormatException(AppErrorCode.noWorkingDays);
    }
    if ((startHour == null) != (endHour == null) ||
        (startHour != null && (startHour < 0 || endHour! > 24 || endHour <= startHour))) {
      throw AppFormatException(AppErrorCode.invalidWorkingHours);
    }
    final updated = barber.copyWith(clearSchedule: true).copyWith(
          workingDays: days,
          startHour: startHour,
          endHour: endHour,
        );
    await _write(_store.updateBarberProfile(updated));
  }

  Future<void> updateBarberAvailability(String barberId, bool isAvailable) async {
    final barber = _cache.barbers[barberId];
    if (barber == null) return;
    await _write(_store.setBarberAvailability(barber, isAvailable));
  }

  /// Removes a barber profile. Deleting the profile also revokes the linked
  /// barber account's access (the rules require the profile to exist).
  Future<void> deleteBarber(String barberId) async {
    final barber = getBarberById(barberId);
    if (barber == null) return;
    await _write(_store.deleteBarber(barber, getPendingBarberInvite(barberId)));
  }

  // --- Bookings ---

  /// Newest appointment first.
  List<Booking> _sorted(Iterable<Booking> bookings) =>
      bookings.toList()..sort((a, b) => b.startAt.compareTo(a.startAt));

  /// Every booking the current user can see (with Firebase the admin loads
  /// no bookings; in local/demo mode this is the whole dataset).
  List<Booking> getAllBookings() => List.unmodifiable(_cache.bookings.values);

  Booking? getBookingById(String bookingId) => _cache.bookings[bookingId];

  List<Booking> getCustomerBookings(String customerId) =>
      _sorted(_cache.bookings.values.where((b) => b.customerId == customerId));

  List<Booking> getShopBookings(String shopId) => _sorted(_cache.bookings.values.where((b) => b.shopId == shopId));

  List<Booking> getBookingsForBarber(String barberId) =>
      _sorted(_cache.bookings.values.where((b) => b.barberId == barberId));

  /// Books an appointment for the signed-in customer.
  ///
  /// [date]'s calendar day and [timeSlot] (e.g. '02:30 PM') are read as Addis
  /// Ababa local time; [startAt] (UTC) overrides them when given.
  /// [durationMinutes] defaults to the service's duration.
  ///
  /// This builds the [Booking] and hands it to [DataStore.createBooking],
  /// the single write path for new bookings (wrap that for slot locking).
  Future<Booking> createBooking({
    required String shopId,
    required String shopName,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String serviceName,
    required double price,
    required DateTime date,
    required String timeSlot,
    DateTime? startAt,
    int? durationMinutes,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    final user = _currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInToBook);
    final shop = _cache.shops[shopId];
    if (shop != null && shop.isBlocked) { // admin shop management: isBlocked
      throw AppStateException(AppErrorCode.shopNotTakingBookings);
    }
    final barber = _cache.barbers[barberId];
    if (barber != null && !barber.isAvailable) {
      throw AppStateException(AppErrorCode.barberNotTakingBookings, [barber.name]);
    }
    // customer blocks: a customer the owner blocked books nothing here
    await CustomerBlockService.instance.assertCurrentUserCanBook(shopId);
    final start = (startAt ?? appointmentStartUtc(date, timeSlot))?.toUtc();
    if (start == null) throw AppFormatException(AppErrorCode.invalidTimeSlot, [timeSlot]);
    final duration = durationMinutes ?? _cache.services[serviceId]?.durationMinutes ?? 30;

    final booking = Booking(
      id: _uuid.v4(),
      shopId: shopId,
      shopName: shopName,
      barberId: barberId,
      barberName: barberName,
      customerId: user.uid,
      customerName: user.name,
      customerPhone: user.phone ?? '',
      serviceId: serviceId,
      serviceName: serviceName,
      price: price,
      date: date,
      timeSlot: timeSlot,
      // barber acceptance: 'pending' when the shop requires it.
      status: acceptance.initialBookingStatus(shop),
      createdAt: DateTime.now().toUtc(),
      startAt: start,
      endAt: start.add(Duration(minutes: duration)),
      durationMinutes: duration,
      paymentStatus: PaymentStatus.unpaid,
      paymentMethod: paymentMethod,
    );

    await _write(_store.createBooking(booking));
    return booking;
  }

  /// Live busy times of [barberId] on the Addis calendar day [addisDate]:
  /// the barber's non-cancelled bookings visible to this user plus the
  /// slot locks of everyone else's (Firestore mode). Emits again whenever
  /// either changes. Feed it to `availableSlotStarts` (availability_service).
  /// [excludeBookingId] (reschedule) leaves that booking and its own locks
  /// out, so it can move into blocks it already holds. Time-off locks are
  /// always busy.
  Stream<List<BusyInterval>> watchBarberBusyTimes(String shopId, String barberId, DateTime addisDate,
      {String? excludeBookingId}) {
    late StreamController<List<BusyInterval>> controller;
    StreamSubscription<List<SlotLock>>? lockSub;
    var locks = const <SlotLock>[];
    void emit() {
      if (controller.isClosed) return;
      controller.add([
        ...busyIntervalsFromBookings(_cache.bookings.values, barberId, excludeBookingId: excludeBookingId),
        for (final l in locks)
          if (excludeBookingId == null || l.isTimeOff || l.bookingId != excludeBookingId) l.interval,
      ]);
    }

    controller = StreamController<List<BusyInterval>>(
      onListen: () {
        addListener(emit);
        lockSub = _store.watchSlotLocks(shopId, barberId, addisDate).listen(
          (value) {
            locks = value;
            emit();
          },
          onError: (Object e) {
            debugPrint('Slot lock listener error: $e');
            emit();
          },
        );
        emit();
      },
      onCancel: () async {
        removeListener(emit);
        await lockSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Changes a booking's status. Cancelling also releases the booking's
  /// slot locks. In local mode the change is visible immediately (before
  /// the returned future completes).
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final booking = _cache.bookings[bookingId];
    if (booking == null) return;
    _checkStatusPolicy(booking, newStatus);
    final gate = debugWriteGate;
    if (gate != null) await gate();
    // --- early finish: completing records completedAt and may notify ---
    if (newStatus == BookingStatus.completed) {
      await _completeBooking(booking);
      return;
    }
    // --- end early finish ---
    await _write(_store.updateBookingStatus(
      booking,
      newStatus,
      cancelledBy: newStatus == BookingStatus.cancelled ? _currentUser?.uid : null,
      refund: newStatus == BookingStatus.cancelled ? _refundContextFor(booking) : null, // refunds
    ));
    // customer blocks: auto-block after N no-shows (best effort, never throws)
    if (newStatus == BookingStatus.noShow) await CustomerBlockService.instance.afterNoShow(booking);
  }

  // --- early finish (logic in early_finish_service.dart) ---

  final Map<String, int> _earlyFinishNoticeCounts = {};

  /// How many later customers were told they can come early when this
  /// session completed [bookingId] (0 when it was not early or nobody was
  /// waiting).
  int earlyFinishNoticeCount(String bookingId) => _earlyFinishNoticeCounts[bookingId] ?? 0;

  /// Writes `{status: completed, completedAt}`; if that was before the
  /// booking's scheduled end and the signed-in user is its barber or the
  /// shop owner, the barber's later confirmed customers today get an inbox
  /// notice (one batch, fire-and-forget: a failure never fails the finish).
  /// In local mode the notices come from LocalNotificationInbox instead.
  Future<void> _completeBooking(Booking booking) async {
    final completedAt = _nowUtc();
    await _write(_store.completeBooking(booking, completedAt: completedAt));
    final user = _currentUser;
    final isStaff = user != null &&
        ((user.role == UserRole.barber && user.barberId == booking.barberId) ||
            (user.role == UserRole.barbershopOwner && user.shopId == booking.shopId));
    if (!isStaff) return;
    final source = booking.copyWith(status: BookingStatus.completed, completedAt: completedAt);
    final notices = early_finish.planEarlyFinishNotices(
      source,
      _cache.bookings.values,
      completedAt,
      languageOf: (uid) => _cache.users[uid]?.language,
    );
    _earlyFinishNoticeCounts[booking.id] = notices.length;
    if (notices.isEmpty) return;
    unawaited(_store.writeEarlyFinishNotices(notices).catchError((Object e) {
      // e.g. permission-denied when the notifications function already
      // created these docs: the customers are told either way.
      debugPrint('Early finish notices not written: $e');
    }));
  }
  // --- end early finish ---

  /// Tests only: awaited before a booking status change is written, so a
  /// test can hold the write in flight or make it fail.
  @visibleForTesting
  Future<void> Function()? debugWriteGate;

  // --- Reschedule, cancellation policy, no-show, time off ---
  // (logic in booking_policy.dart and time_off_service.dart)

  /// Tests only: overrides the clock used for the policy checks.
  @visibleForTesting
  DateTime Function()? debugClock;

  DateTime _nowUtc() => (debugClock?.call() ?? DateTime.now()).toUtc();

  /// The clock the policy checks use (screens show the same verdict).
  DateTime nowUtc() => _nowUtc();

  // --- subscription expiry (client-side; logic in subscription_state.dart) ---
  // No Cloud Functions on the free plan: when the owner's or the admin's app
  // holds a shop whose stored status lags behind the effective one (trial /
  // paid period over), it writes the downgrade once. The function's daily
  // job writes the same values on Blaze, so either side may go first.

  bool _subscriptionSyncScheduled = false;
  final Set<String> _subscriptionSyncInFlight = {};

  /// '$shopId:$status' writes that failed (e.g. permission denied); not
  /// retried this session.
  final Set<String> _subscriptionSyncFailed = {};

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleBarberContactSync(); // private barber phone
    final role = _currentUser?.role;
    if (_subscriptionSyncScheduled || (role != UserRole.admin && role != UserRole.barbershopOwner)) return;
    _subscriptionSyncScheduled = true;
    scheduleMicrotask(() {
      _subscriptionSyncScheduled = false;
      syncSubscriptionTransitions();
    });
  }

  /// Owner (own shop) / admin (every loaded shop): persists lapsed trial /
  /// paid periods (trialing/active -> past_due -> suspended) with
  /// [DataStore.setShopSubscriptionTransition]. Idempotent; returns how many
  /// shops were written. Runs automatically after every data change.
  Future<int> syncSubscriptionTransitions() async {
    final user = _currentUser;
    if (user == null) return 0;
    final Iterable<Barbershop> shops;
    if (user.role == UserRole.admin) {
      shops = _cache.shops.values.toList(growable: false);
    } else if (user.role == UserRole.barbershopOwner && user.shopId != null) {
      final own = _cache.shops[user.shopId];
      shops = own == null ? const [] : [own];
    } else {
      return 0;
    }
    final now = _nowUtc();
    var written = 0;
    for (final shop in shops) {
      final patch = subscriptionTransitionPatch(shop, now);
      if (patch == null) continue;
      final key = '${shop.id}:${patch['subscriptionStatus']}';
      if (_subscriptionSyncInFlight.contains(shop.id) || _subscriptionSyncFailed.contains(key)) continue;
      _subscriptionSyncInFlight.add(shop.id);
      try {
        await _store.setShopSubscriptionTransition(shop.id, patch);
        written++;
      } catch (e) {
        _subscriptionSyncFailed.add(key);
        debugPrint('Subscription status update for ${shop.id} failed: $e');
      } finally {
        _subscriptionSyncInFlight.remove(shop.id);
      }
    }
    if (written > 0) notifyListeners();
    return written;
  }
  // --- end subscription expiry ---

  /// Customers cancel only before the shop's cutoff (staff and admins may
  /// cancel any time); no-show only after the start.
  void _checkStatusPolicy(Booking booking, BookingStatus newStatus) {
    final user = _currentUser;
    final shop = _cache.shops[booking.shopId];
    if (newStatus == BookingStatus.cancelled && user?.role == UserRole.customer && shop != null) {
      policy.assertCustomerCanCancel(booking, shop, _nowUtc());
    }
    if (newStatus == BookingStatus.noShow) policy.assertCanMarkNoShow(booking, _nowUtc());
  }

  // --- barber cancel ---

  /// Whether the signed-in barber may cancel [booking] now: their own
  /// pending/confirmed booking, before it starts.
  bool canBarberCancelBooking(Booking booking) {
    final user = _currentUser;
    return user != null &&
        user.role == UserRole.barber &&
        user.barberId != null &&
        user.barberId == booking.barberId &&
        policy.canBarberCancel(booking, _nowUtc());
  }

  /// Barber: cancels one of their own pending/confirmed bookings before it
  /// starts, with an optional [reason] (<= 200 characters). Same write as
  /// any other cancel ([DataStore.updateBookingStatus]: status 'cancelled',
  /// cancelledBy = the barber's uid, slot locks released) plus
  /// `cancelReasonNote` when a reason is given. The customer is notified
  /// through the usual 'cancelled' path.
  Future<void> cancelBookingAsBarber(String bookingId, {String? reason}) async {
    final booking = _cache.bookings[bookingId];
    if (booking == null) throw AppStateException(AppErrorCode.bookingNotChangeable);
    final user = _currentUser;
    if (user == null || user.role != UserRole.barber || user.barberId == null || user.barberId != booking.barberId) {
      throw AppStateException(AppErrorCode.barberCancelNotAllowed);
    }
    policy.assertBarberCanCancel(booking, _nowUtc());
    final note = policy.normalizeCancelReasonNote(reason);
    final gate = debugWriteGate;
    if (gate != null) await gate();
    await _write(_store.updateBookingStatus(
      booking,
      BookingStatus.cancelled,
      cancelledBy: user.uid,
      cancelReasonNote: note,
      refund: _refundContextFor(booking), // refunds
    ));
  }
  // --- end barber cancel ---

  // --- refunds (logic in refunds.dart, writes in refund_writes.dart) ---
  // Every cancellation path passes a RefundContext down to the data store,
  // which flags a paid booking's refund in the same write as the cancel
  // (free plan). On Blaze, functions/bookings flagRefundOnCancel also flags
  // any paid + cancelled booking that is still unflagged.

  /// What the store needs to flag a refund when the signed-in user cancels
  /// [booking] ([reason] fixes the reason, e.g. a declined request).
  RefundContext _refundContextFor(Booking booking, {String? reason}) {
    return RefundContext(
      by: refundCancellerFor(_currentUser, booking),
      nowUtc: _nowUtc(),
      cutoffHours: _cache.shops[booking.shopId]?.cancellationCutoffHours,
      reason: reason,
      languageOf: (uid) => _cache.users[uid]?.language,
    );
  }

  /// Whether the signed-in user may see and settle [shopId]'s refunds (its
  /// owner) or every shop's (an admin, [shopId] null or any).
  bool canManageRefunds({String? shopId}) {
    final user = _currentUser;
    if (user == null) return false;
    if (user.role == UserRole.admin) return true;
    return user.role == UserRole.barbershopOwner && shopId != null && user.shopId == shopId;
  }

  /// Live "Refunds due" (oldest flag first): the owner's shop ([shopId])
  /// or, for an admin with [shopId] null, every shop. Local mode re-reads
  /// the cache on every change.
  Stream<List<Booking>> watchRefundsDue({String? shopId}) {
    if (!canManageRefunds(shopId: shopId)) return Stream.value(const []);
    if (_firebaseReady) return _store.watchRefundsDue(shopId: shopId);
    late StreamController<List<Booking>> controller;
    void emit() {
      if (!controller.isClosed) controller.add(refundsDue(_cache.bookings.values, shopId: shopId));
    }

    controller = StreamController<List<Booking>>(
      onListen: () {
        addListener(emit);
        emit();
      },
      onCancel: () => removeListener(emit),
    );
    return controller.stream;
  }

  /// Owner/admin: records that the money of [booking]'s due refund went
  /// back ([method], optional [reference] up to 100 characters):
  /// refundStatus 'refunded', refundedAt/By, paymentStatus 'refunded', and
  /// the customer's "Payment refunded" notice, in one write.
  Future<void> markRefunded(Booking booking, {required RefundMethod method, String? reference}) async {
    final user = _currentUser;
    if (user == null || !canManageRefunds(shopId: booking.shopId)) {
      throw AppStateException(AppErrorCode.bookingNotChangeable);
    }
    final due = booking.refund;
    if (due == null || !due.isDue) throw AppStateException(AppErrorCode.bookingNotChangeable);
    final String? ref;
    try {
      ref = normalizeRefundReference(reference);
    } on ArgumentError {
      throw AppFormatException(AppErrorCode.declineReasonTooLong, [kMaxRefundReferenceLength]);
    }
    final now = _nowUtc();
    final fields = refundCompletionFields(refundedAt: now, refundedBy: user.uid, method: method, reference: ref);
    final notice = booking.customerId.isEmpty
        ? null
        : refundedNotice(booking, due.amount, now, language: _cache.users[booking.customerId]?.language);
    await _write(_store.markRefunded(booking, fields, notice));
  }

  final Set<String> _refundSweepTried = {};

  /// Owner (own shop) / admin: flags cancelled + paid bookings in the cache
  /// that have no refund yet (cancelled by an older app version). Each
  /// booking is tried once per session; returns how many were flagged and
  /// never throws.
  Future<int> flagMissingRefunds({String? shopId}) async {
    final user = _currentUser;
    final id = shopId ?? user?.shopId;
    if (id == null || !canManageRefunds(shopId: id)) return 0;
    var flagged = 0;
    final now = _nowUtc();
    for (final b in cancelledPaidUnflagged(_cache.bookings.values, shopId: id)) {
      if (!_refundSweepTried.add(b.id)) continue;
      final ctx = refundContextForPastCancel(b, now, languageOf: (uid) => _cache.users[uid]?.language);
      final flag = refundFlagFor(b, ctx);
      if (flag == null) continue;
      try {
        await _store.flagRefund(b, flag, b.customerId.isEmpty ? null : refundDueNotice(b, flag, language: ctx.languageOf?.call(b.customerId)));
        flagged++;
      } catch (e) {
        debugPrint('Could not flag the refund of ${b.id}: $e');
      }
    }
    if (flagged > 0) notifyListeners();
    return flagged;
  }
  // --- end refunds ---

  /// Staff: marks a pending/confirmed booking whose start has passed as a
  /// no-show. Its slot locks are kept (they expire on their own).
  Future<void> markNoShow(String bookingId) => updateBookingStatus(bookingId, BookingStatus.noShow);

  /// Customer: moves their booking to [newStartUtc] (same barber, service
  /// and duration), enforcing the shop's cutoff and reschedule limit.
  /// Throws [SlotTakenException] if the new time was just taken.
  Future<Booking> rescheduleBooking(String bookingId, DateTime newStartUtc) async {
    final booking = _cache.bookings[bookingId];
    final user = _currentUser;
    if (booking == null || user == null || booking.customerId != user.uid) {
      throw AppStateException(AppErrorCode.bookingNotChangeable);
    }
    final now = _nowUtc();
    final shop = _cache.shops[booking.shopId];
    if (shop != null) policy.assertCanReschedule(booking, shop, now);
    if (newStartUtc.toUtc() == booking.startAt) throw AppFormatException(AppErrorCode.rescheduleSameTime);
    final updated = policy.rescheduledBooking(booking, newStartUtc, now);
    await _write(_store.rescheduleBooking(booking, updated));
    return updated;
  }

  /// Owner: sets the shop's cancellation cutoff and reschedule limit.
  /// [requireBarberAcceptance] (barber acceptance) is written with them when given.
  Future<void> updateShopPolicy(String shopId,
      {required int cancellationCutoffHours, required int maxReschedules, bool? requireBarberAcceptance}) async {
    policy.validatePolicy(cancellationCutoffHours: cancellationCutoffHours, maxReschedules: maxReschedules);
    if (!_cache.shops.containsKey(shopId)) return;
    await _write(_store.updateShopPolicy(shopId,
        cancellationCutoffHours: cancellationCutoffHours,
        maxReschedules: maxReschedules,
        requireBarberAcceptance: requireBarberAcceptance));
  }

  // --- barber acceptance (rules in booking_acceptance.dart) ---

  /// Pending requests of [barberId] that can still be accepted, soonest first.
  List<Booking> getBookingRequestsForBarber(String barberId) =>
      acceptance.openRequestsForBarber(_cache.bookings.values, barberId, _nowUtc());

  /// Pending requests of [shopId] that can still be accepted, soonest first.
  List<Booking> getBookingRequestsForShop(String shopId) =>
      acceptance.openRequestsForShop(_cache.bookings.values, shopId, _nowUtc());

  /// Whether the signed-in user may accept/decline [booking] (its barber,
  /// the shop owner or an admin).
  bool canRespondToBookingRequest(Booking booking) => acceptance.canRespondToRequest(_currentUser, booking);

  /// Barber/owner: confirms a pending request (status 'confirmed' +
  /// acceptedAt), then shares the barber's private phone with the customer
  /// (`barberPhone`, a separate best-effort update: a failure never fails
  /// the accept). Throws [AppStateException] if not allowed, no longer
  /// pending or already inside the expiry window.
  Future<void> acceptBookingRequest(String bookingId) async {
    final booking = _cache.bookings[bookingId];
    if (booking == null) throw AppStateException(AppErrorCode.bookingNotChangeable);
    final now = _nowUtc();
    acceptance.assertCanRespond(_currentUser, booking, now, accept: true);
    await _write(_store.acceptBookingRequest(booking, acceptedAt: now));
    await _shareBarberPhone(booking.copyWith(status: BookingStatus.confirmed)); // private barber phone
  }

  /// Barber/owner: declines a pending request (status 'cancelled',
  /// cancelledBy 'barber', optional [reason] up to 200 characters) and
  /// releases its slot locks.
  Future<void> declineBookingRequest(String bookingId, {String? reason}) async {
    final booking = _cache.bookings[bookingId];
    if (booking == null) throw AppStateException(AppErrorCode.bookingNotChangeable);
    acceptance.assertCanRespond(_currentUser, booking, _nowUtc(), accept: false);
    final note = acceptance.normalizeDeclineReason(reason);
    await _write(_store.declineBookingRequest(
      booking,
      reason: note,
      refund: _refundContextFor(booking, reason: RefundReasons.requestDeclined), // refunds
    ));
  }

  // --- free plan: staff app closes expired requests (booking_acceptance.dart) ---
  DateTime? _lastExpiredRequestSweep;

  /// Barber/owner (free plan, no `expirePendingBookings` function): closes
  /// the pending requests they may answer whose start is within
  /// `kPendingExpiryLead - kClientExpiryGrace` (or past), with the existing
  /// decline write (status 'cancelled', cancelledBy 'barber', declineReason
  /// 'not_accepted', slot locks released). At most once a minute unless
  /// [force]. A request the function (or another device) already closed is
  /// skipped. Returns how many were closed; never throws.
  Future<int> closeExpiredBookingRequests({bool force = false}) async {
    final user = _currentUser;
    if (user == null || (user.role != UserRole.barber && user.role != UserRole.barbershopOwner)) return 0;
    final now = _nowUtc();
    final last = _lastExpiredRequestSweep;
    if (!force && last != null && now.difference(last) < const Duration(minutes: 1)) return 0;
    _lastExpiredRequestSweep = now;
    final expired = _cache.bookings.values
        .where((b) => acceptance.shouldClientCloseExpiredRequest(b, now) && acceptance.canRespondToRequest(user, b))
        .toList();
    var closed = 0;
    for (final b in expired) {
      try {
        await _store.declineBookingRequest(
          b,
          reason: acceptance.kNotAcceptedReason,
          refund: _refundContextFor(b, reason: RefundReasons.requestExpired), // refunds
        );
        closed++;
      } catch (e) {
        debugPrint('Could not close expired request ${b.id}: $e');
      }
    }
    if (closed > 0) notifyListeners();
    return closed;
  }

  /// Dashboards (barber, owner): runs [closeExpiredBookingRequests] now and
  /// every minute while the returned timer lives (cancel it in dispose).
  /// Null without Firebase (DEMO_MODE, tests), where nothing expires.
  Timer? startExpiredRequestSweep() {
    if (!isFirebaseAttached) return null;
    unawaited(closeExpiredBookingRequests());
    return Timer.periodic(const Duration(minutes: 1), (_) => unawaited(closeExpiredBookingRequests()));
  }
  // --- end free plan ---
  // --- end barber acceptance ---

  // --- private barber phone ---
  // Barber profiles (barbershops/{shopId}/barbers/{id}) are public, so the
  // barber's phone lives in barbers/{id}/private/contact {phone}: readable
  // by the shop's owner, admins and that barber. A customer sees it only on
  // their own confirmed booking: the staff app copies it in as
  // `barberPhone` when it accepts a request, and (free plan, no Cloud
  // Functions) whenever it sees an upcoming confirmed booking without it.

  /// Whether the signed-in user may see [barber]'s private phone: an admin,
  /// the owner of the barber's shop, or that barber.
  bool _canSeeBarberPhone(Barber barber) {
    final user = _currentUser;
    if (user == null) return false;
    switch (user.role) {
      case UserRole.admin:
        return true;
      case UserRole.barbershopOwner:
        return user.shopId != null && user.shopId == barber.shopId;
      case UserRole.barber:
        return user.barberId == barber.id && user.shopId == barber.shopId;
      case UserRole.customer:
        return false;
    }
  }

  /// The barber's private phone (E.164) for staff and admins (see
  /// [_canSeeBarberPhone]); null for everyone else or when none is set.
  /// Customers use [Booking.visibleBarberPhone] instead. Until a legacy
  /// public doc is migrated its old `phone` field is used.
  String? getBarberPhone(String barberId) {
    final barber = _cache.barbers[barberId];
    if (barber == null || !_canSeeBarberPhone(barber)) return null;
    final phone = _cache.barberPhones[barberId] ?? barber.phone;
    return phone == null || phone.trim().isEmpty ? null : phone;
  }

  /// The phone the staff app may copy into a booking: only a real private
  /// contact (never a legacy public field, which the rules would not match).
  String? _shareablePhone(String barberId) {
    final barber = _cache.barbers[barberId];
    if (barber == null || !_canSeeBarberPhone(barber)) return null;
    final phone = _cache.barberPhones[barberId];
    return phone == null || phone.isEmpty ? null : phone;
  }

  /// Owner (own shop), admin or the barber themself: sets the barber's
  /// private phone (validated, stored as E.164), or removes it when [phone]
  /// is null or blank. Bookings already confirmed get the new number on the
  /// next sync ([shareBarberPhonesWithBookings]). Does nothing for anyone
  /// else.
  Future<void> updateBarberPhone(String barberId, String? phone) async {
    final barber = _cache.barbers[barberId];
    if (barber == null || !_canSeeBarberPhone(barber)) return;
    String? normalized;
    if (phone != null && phone.trim().isNotEmpty) {
      normalized = normalizeEthiopianPhone(phone);
      if (normalized == null) throw AppFormatException(AppErrorCode.invalidPhone);
    }
    await _write(_store.setBarberPhone(barber.shopId, barberId, normalized));
  }

  bool _barberContactSyncScheduled = false;
  final Set<String> _contactMigrationsInFlight = {};

  /// Barber ids whose migration failed (e.g. permission denied); not
  /// retried this session.
  final Set<String> _contactMigrationsFailed = {};
  final Set<String> _phoneSharesInFlight = {};

  /// '$bookingId:$phone' shares that failed; not retried this session.
  final Set<String> _phoneSharesFailed = {};

  /// After every data change (staff and admins): [migrateLegacyBarberContacts]
  /// and [shareBarberPhonesWithBookings], once per microtask.
  void _scheduleBarberContactSync() {
    final role = _currentUser?.role;
    if (_barberContactSyncScheduled || role == null || role == UserRole.customer) return;
    _barberContactSyncScheduled = true;
    scheduleMicrotask(() {
      _barberContactSyncScheduled = false;
      unawaited(migrateLegacyBarberContacts());
      unawaited(shareBarberPhonesWithBookings());
    });
  }

  /// Owner (own shop) / admin (every loaded barber): moves the `phone` (and
  /// legacy `email`) of public barber docs that still carry them into the
  /// private contact and deletes them from the public doc
  /// ([DataStore.migrateBarberContact]). An existing contact is kept. A
  /// phone that is not a valid Ethiopian mobile is dropped. Idempotent and
  /// never throws; returns how many barbers were migrated.
  Future<int> migrateLegacyBarberContacts() async {
    final user = _currentUser;
    if (user == null) return 0;
    final Iterable<Barber> barbers;
    if (user.role == UserRole.admin) {
      barbers = _cache.barbers.values;
    } else if (user.role == UserRole.barbershopOwner && user.shopId != null) {
      barbers = _cache.barbers.values.where((b) => b.shopId == user.shopId);
    } else {
      return 0;
    }
    final legacy = barbers
        .where((b) =>
            b.hasLegacyContactFields &&
            !_contactMigrationsInFlight.contains(b.id) &&
            !_contactMigrationsFailed.contains(b.id))
        .toList();
    var migrated = 0;
    for (final barber in legacy) {
      final raw = barber.phone?.trim() ?? '';
      final phone = raw.isEmpty ? null : normalizeEthiopianPhone(raw);
      if (raw.isNotEmpty && phone == null) debugPrint('Dropping invalid phone of barber ${barber.id}');
      _contactMigrationsInFlight.add(barber.id);
      try {
        await _store.migrateBarberContact(barber, phone: phone);
        migrated++;
      } catch (e) {
        _contactMigrationsFailed.add(barber.id);
        debugPrint('Barber contact migration for ${barber.id} failed: $e');
      } finally {
        _contactMigrationsInFlight.remove(barber.id);
      }
    }
    if (migrated > 0) notifyListeners();
    return migrated;
  }

  /// Copies the barber's private phone into [booking] (`barberPhone`) when
  /// the signed-in barber/owner may, the booking is confirmed or in
  /// progress and not over, and it does not carry that number yet. Never
  /// throws; returns whether it wrote.
  Future<bool> _shareBarberPhone(Booking booking) async {
    final user = _currentUser;
    if (user == null || (user.role != UserRole.barber && user.role != UserRole.barbershopOwner)) return false;
    if (booking.status != BookingStatus.confirmed && booking.status != BookingStatus.inProgress) return false;
    if (!booking.endAt.isAfter(_nowUtc())) return false;
    if (!acceptance.canRespondToRequest(user, booking)) return false;
    final phone = _shareablePhone(booking.barberId);
    if (phone == null || booking.barberPhone == phone) return false;
    final key = '${booking.id}:$phone';
    if (_phoneSharesInFlight.contains(key) || _phoneSharesFailed.contains(key)) return false;
    _phoneSharesInFlight.add(key);
    try {
      await _store.shareBarberPhone(booking, phone);
      return true;
    } catch (e) {
      _phoneSharesFailed.add(key);
      debugPrint('Could not share the barber phone on ${booking.id}: $e');
      return false;
    } finally {
      _phoneSharesInFlight.remove(key);
    }
  }

  /// Barber (own bookings) / owner (shop's bookings), free plan: copies the
  /// barber's private phone into every upcoming confirmed or in-progress
  /// booking that lacks it (or has an old number), so the customer can call
  /// once the booking is confirmed, also when the shop confirms bookings
  /// automatically. Idempotent and never throws; returns how many were
  /// written.
  Future<int> shareBarberPhonesWithBookings() async {
    final user = _currentUser;
    if (user == null || (user.role != UserRole.barber && user.role != UserRole.barbershopOwner)) return 0;
    var shared = 0;
    for (final booking in _cache.bookings.values.toList()) {
      if (await _shareBarberPhone(booking)) shared++;
    }
    if (shared > 0) notifyListeners();
    return shared;
  }
  // --- end private barber phone ---

  /// Live time off of one barber (soonest first).
  Stream<List<TimeOff>> watchTimeOff(String shopId, String barberId) => _store.watchTimeOff(shopId, barberId);

  /// Whether the signed-in user may add/remove [barber]'s time off.
  bool canManageTimeOffFor(Barber barber) => canManageTimeOff(_currentUser, barber);

  /// Owner (any barber of their shop) or the barber themself: blocks
  /// `[startUtc, endUtc)` (one Addis day, 15-minute grid). Throws
  /// [AppErrorCode.timeOffConflict] if it overlaps a booking or time off.
  Future<TimeOff> addTimeOff({
    required String barberId,
    required DateTime startUtc,
    required DateTime endUtc,
    String? reason,
  }) async {
    final barber = _cache.barbers[barberId];
    final user = _currentUser;
    if (barber == null || user == null || !canManageTimeOff(user, barber)) {
      throw AppStateException(AppErrorCode.timeOffNotAllowed);
    }
    final note = reason?.trim();
    validateTimeOff(startUtc: startUtc, endUtc: endUtc, reason: note, nowUtc: _nowUtc());
    final entry = TimeOff(
      id: _uuid.v4(),
      shopId: barber.shopId,
      barberId: barber.id,
      startAt: startUtc.toUtc(),
      endAt: endUtc.toUtc(),
      reason: note == null || note.isEmpty ? null : note,
      createdBy: user.uid,
      createdAt: _nowUtc(),
    );
    await _write(_store.addTimeOff(entry));
    return entry;
  }

  Future<void> deleteTimeOff(TimeOff entry) async {
    final barber = _cache.barbers[entry.barberId];
    if (barber == null || !canManageTimeOff(_currentUser, barber)) {
      throw AppStateException(AppErrorCode.timeOffNotAllowed);
    }
    await _write(_store.deleteTimeOff(entry));
  }

  /// Demo builds: the dataset's sample time off (local mode only).
  void loadDemoTimeOff(List<TimeOff> entries) {
    final local = _store;
    if (local is LocalDataStore) local.loadTimeOff(entries);
  }

  // --- vacation: time off from date to date (logic in vacation_service.dart) ---

  /// The time [addVacation] would block for [barberId] (working hours of
  /// each day from [fromDate] to [toDate], Addis dates, inclusive), before
  /// leaving out blocks that are already taken.
  List<(DateTime, DateTime)> vacationRangesFor({
    required String barberId,
    required DateTime fromDate,
    required DateTime toDate,
    int? firstDayFromMinute,
    int? lastDayToMinute,
  }) {
    final barber = _cache.barbers[barberId];
    final shop = barber == null ? null : _cache.shops[barber.shopId];
    if (barber == null || shop == null) return const [];
    if (toDate.isBefore(fromDate) || vacationLengthDays(fromDate, toDate) > kMaxVacationDays) return const [];
    return vacationDayRanges(shop, barber, fromDate, toDate,
        firstDayFromMinute: firstDayFromMinute, lastDayToMinute: lastDayToMinute, nowUtc: _nowUtc());
  }

  /// The barber's upcoming pending/confirmed bookings inside the vacation
  /// (the ones the owner or barber may cancel for it), soonest first.
  List<Booking> vacationConflictsFor({
    required String barberId,
    required DateTime fromDate,
    required DateTime toDate,
    int? firstDayFromMinute,
    int? lastDayToMinute,
  }) {
    final barber = _cache.barbers[barberId];
    if (barber == null) return const [];
    return vacationConflicts(
      _cache.bookings.values,
      shopId: barber.shopId,
      barberId: barberId,
      ranges: vacationRangesFor(
          barberId: barberId,
          fromDate: fromDate,
          toDate: toDate,
          firstDayFromMinute: firstDayFromMinute,
          lastDayToMinute: lastDayToMinute),
      nowUtc: _nowUtc(),
    );
  }

  /// Owner (any barber of their shop) or the barber themself: blocks every
  /// working day from [fromDate] to [toDate] (Addis dates, inclusive, at
  /// most [kMaxVacationDays] days; optionally starting at
  /// [firstDayFromMinute] on the first day and ending at [lastDayToMinute]
  /// on the last, Addis minutes of the day).
  ///
  /// Bookings in [cancelBookingIds] (from [vacationConflictsFor]) are
  /// cancelled first, through the same write as any staff cancel (slot
  /// locks released, a paid booking refund-flagged by flagRefundIfPaid in
  /// that write), and each customer gets an inbox notice. Every other
  /// booking is kept: its blocks are left out of the vacation.
  ///
  /// Then one time-off document per free stretch (usually one per working
  /// day) is written, each in its own batch with its slot locks. If one of
  /// them fails, the parts already written are removed again (best effort)
  /// and the error is rethrown; cancelled bookings stay cancelled.
  Future<VacationResult> addVacation({
    required String barberId,
    required DateTime fromDate,
    required DateTime toDate,
    int? firstDayFromMinute,
    int? lastDayToMinute,
    String? reason,
    Iterable<String> cancelBookingIds = const [],
  }) async {
    final barber = _cache.barbers[barberId];
    final user = _currentUser;
    if (barber == null || user == null || !canManageTimeOff(user, barber)) {
      throw AppStateException(AppErrorCode.timeOffNotAllowed);
    }
    final shop = _cache.shops[barber.shopId];
    if (shop == null) throw AppStateException(AppErrorCode.timeOffNotAllowed);
    final note = reason?.trim();
    final now = _nowUtc();
    validateVacation(
      fromDate: fromDate,
      toDate: toDate,
      firstDayFromMinute: firstDayFromMinute,
      lastDayToMinute: lastDayToMinute,
      reason: note,
      nowUtc: now,
    );
    final ranges = vacationDayRanges(shop, barber, fromDate, toDate,
        firstDayFromMinute: firstDayFromMinute, lastDayToMinute: lastDayToMinute, nowUtc: now);
    if (ranges.isEmpty) throw AppStateException(AppErrorCode.vacationNothingToBlock);

    final wanted = cancelBookingIds.toSet();
    final toCancel = vacationConflicts(_cache.bookings.values,
            shopId: barber.shopId, barberId: barber.id, ranges: ranges, nowUtc: now)
        .where((b) => wanted.contains(b.id))
        .toList();
    final locks = await _store.slotLocksBetween(barber.shopId, barber.id, ranges.first.$1, ranges.last.$2);
    List<(DateTime, DateTime)> segmentsWith(Set<String> cancelledIds) => freeVacationSegments(
        ranges,
        vacationTakenBlocks(
          shopId: barber.shopId,
          barberId: barber.id,
          bookings: _cache.bookings.values,
          cancelledIds: cancelledIds,
          locks: locks,
        ));
    if (segmentsWith({for (final b in toCancel) b.id}).isEmpty) {
      throw AppStateException(AppErrorCode.vacationNothingToBlock);
    }

    // 1. Cancel the chosen bookings (each in its own transaction).
    final cancelled = <Booking>[];
    final notices = <AppNotification>[];
    var noticeFailures = 0;
    final cancelNote = note == null || note.isEmpty ? null : policy.normalizeCancelReasonNote(note);
    for (final b in toCancel) {
      try {
        if (user.role == UserRole.barber) policy.assertBarberCanCancel(b, now);
        await _store.updateBookingStatus(
          b,
          BookingStatus.cancelled,
          cancelledBy: user.uid,
          cancelReasonNote: cancelNote,
          refund: _refundContextFor(b), // refunds: flagRefundIfPaid runs in this same write
        );
        cancelled.add(b);
      } catch (e) {
        debugPrint('Vacation: could not cancel ${b.id}: $e');
        continue;
      }
      try {
        final language = _cache.users[b.customerId]?.language;
        final notice = vacationCancelNotice(b, nowUtc: _nowUtc(), language: language ?? 'am');
        await _store.writeVacationCancelNotice(b.customerId, notice);
        notices.add(notice);
      } catch (e) {
        noticeFailures++;
        debugPrint('Vacation: could not notify the customer of ${b.id}: $e');
      }
    }
    if (cancelled.isNotEmpty) notifyListeners();

    // 2. The time-off parts around whatever is still booked.
    final segments = segmentsWith({for (final b in cancelled) b.id});
    if (segments.isEmpty) throw AppStateException(AppErrorCode.vacationNothingToBlock);
    final parts = buildVacationParts(
      groupId: _uuid.v4(),
      idFor: (_) => _uuid.v4(),
      shopId: barber.shopId,
      barberId: barber.id,
      segments: segments,
      fromDate: fromDate,
      toDate: toDate,
      reason: note,
      createdBy: user.uid,
      createdAt: now,
    );
    final written = <TimeOff>[];
    try {
      for (final part in parts) {
        await _store.addTimeOff(part);
        written.add(part);
      }
    } catch (_) {
      for (final part in written) {
        try {
          await _store.deleteTimeOff(part);
        } catch (e) {
          debugPrint('Vacation: could not roll back ${part.id}: $e');
        }
      }
      notifyListeners();
      rethrow;
    }
    notifyListeners();
    return VacationResult(parts: written, cancelled: cancelled, notices: notices, noticeFailures: noticeFailures);
  }

  /// Removes one row of the time-off list: a single entry, or every loaded
  /// part of a vacation (each part in its own batch with its locks).
  Future<void> deleteTimeOffItem(TimeOffItem item) async {
    for (final part in item.parts) {
      await deleteTimeOff(part);
    }
  }
  // --- end vacation ---

  // --- Reviews (logic in reviews_service.dart) ---

  /// Local mode only (demo builds, tests): adds a new review's [stars] to
  /// the barber's `ratingSum` and 1 to `reviewCount`, as the review
  /// transaction does in Firestore. Ignored once Firebase is attached (the
  /// barber listener brings the new counters).
  void applyLocalBarberReview(String barberId, int stars) =>
      applyLocalBarberReviewChange(barberId, ratingSumDelta: stars, reviewCountDelta: 1);

  /// Local mode only: a review was created (+stars, +1), edited (+new -
  /// old, 0) or deleted (-stars, -1); the barber's counters follow, as the
  /// review transaction does in Firestore. Ignored once Firebase is
  /// attached.
  void applyLocalBarberReviewChange(String barberId, {required int ratingSumDelta, required int reviewCountDelta}) {
    if (_firebaseReady) return;
    final barber = _cache.barbers[barberId];
    if (barber == null) return;
    _cache.barbers[barberId] = barber.copyWith(
      ratingSum: barber.effectiveRatingSum + ratingSumDelta,
      reviewCount: barber.reviewCount + reviewCountDelta,
    );
    notifyListeners();
  }

  /// A barber's average and review count (lib/services/rating_service.dart);
  /// "New" ([RatingSummary.empty]) for an unknown barber or no reviews.
  RatingSummary barberRatingOf(String barberId) {
    final barber = _cache.barbers[barberId];
    return barber == null ? RatingSummary.empty : barberRatingSummary(barber);
  }

  /// The shop rating: the average of its rated barbers' averages, from the
  /// loaded barbers (customers and admins load all barbers, owners and
  /// barbers their own shop's).
  ShopRating shopRatingOf(String shopId) => shopRatingFromBarbers(getBarbersForShop(shopId));

  // --- admin users (logic in admin_users.dart, writes in admin_user_writes.dart) ---

  /// Local mode writes the cache; [attachFirebase] switches to Firestore.
  late AdminUserWrites _adminUserWrites = LocalAdminUserWrites(_cache, onNotice: (item) {
    final notice = item.notice;
    if (notice != null) onLocalNotice?.call(notice);
  });

  /// Admin: the user with [uid], if loaded.
  AppUser? getUserById(String uid) => _cache.users[uid];

  /// Admin: barber profiles of [shopId] that [user] could be linked to.
  List<Barber> linkableBarbersFor(String shopId, AppUser user) => linkableBarbers(shopId,
      barbers: _cache.barbers.values,
      users: _cache.users.values,
      invites: _cache.invites.values,
      forUid: user.uid,
      forEmail: user.email);

  /// Admin: what changing [uid]'s role to [to] writes (for the confirm
  /// dialog). Throws [AdminUserException] when it is not allowed.
  RoleChangePlan previewRoleChange(String uid, RoleTarget to) {
    final target = _cache.users[uid];
    if (target == null) throw const AdminUserException(AdminUserError.userNotFound);
    return planRoleChange(
      actor: _currentUser,
      target: target,
      to: to,
      users: _cache.users.values,
      shops: _cache.shops,
      barbers: _cache.barbers,
      invites: _cache.invites.values,
      newId: _uuid.v4,
    );
  }

  /// Admin: changes [uid]'s role to [to] in one batch (users doc, barber
  /// profile, shop ownerId, stale invites; see [RoleChangePlan]). The
  /// admin cannot change their own role or remove the last admin.
  Future<void> adminChangeUserRole(String uid, RoleTarget to) async {
    final plan = previewRoleChange(uid, to);
    await _write(_adminUserWrites.applyRoleChange(plan));
  }

  /// Admin: [uid]'s upcoming bookings (as customer, or as barber), for
  /// the disable dialog. Null when they cannot be loaded.
  Future<int?> countUpcomingBookingsOf(String uid) async {
    final user = _cache.users[uid];
    if (user == null) return null;
    try {
      return (await _adminUserWrites.upcomingBookingsOf(user, _nowUtc())).length;
    } catch (e) {
      debugPrint('Could not count upcoming bookings: $e');
      return null;
    }
  }

  /// Admin: disables [uid] (`disabled`, `disabledAt`, `disabledBy`,
  /// `disabledReason`). Their app signs out at once and sign-in is refused.
  /// Upcoming bookings stay unless [cancelUpcoming]; then they are
  /// cancelled (paid ones flagged for a refund) and, for a barber, each
  /// customer is notified. Returns the number of cancelled bookings.
  Future<int> adminDisableUser(String uid, {String? reason, bool cancelUpcoming = false}) async {
    final target = _cache.users[uid];
    if (target == null) throw const AdminUserException(AdminUserError.userNotFound);
    checkCanDisable(actor: _currentUser, target: target, users: _cache.users.values);
    final cleanReason = normalizeDisableReason(reason);
    final admin = _currentUser!.uid;
    final now = _nowUtc();
    await _adminUserWrites.disable(uid, disableFields(at: now, by: admin, reason: cleanReason));
    var cancelled = 0;
    if (cancelUpcoming) {
      String? languageOf(String id) => _cache.users[id]?.language;
      final items = planDisableCancellations(target, await _adminUserWrites.upcomingBookingsOf(target, now), now,
          languageOf: languageOf);
      await _adminUserWrites.cancelBookings(items,
          adminUid: admin,
          refund: RefundContext(by: RefundCanceller.admin, nowUtc: now, languageOf: languageOf));
      cancelled = items.length;
    }
    notifyListeners();
    return cancelled;
  }

  /// Admin: enables [uid] again (removes the disable fields).
  Future<void> adminEnableUser(String uid) async {
    if (_currentUser?.role != UserRole.admin) throw const AdminUserException(AdminUserError.notAdmin);
    final target = _cache.users[uid];
    if (target == null) throw const AdminUserException(AdminUserError.userNotFound);
    if (!target.disabled) throw const AdminUserException(AdminUserError.noChange);
    await _write(_adminUserWrites.enable(uid));
  }
  // --- end admin users ---

  /// Awaits a store write, then notifies listeners. (With Firestore the
  /// listeners have usually notified already via latency compensation.)
  Future<void> _write(Future<void> write) async {
    await write;
    notifyListeners();
  }

  // --- Financial & SaaS Performance Metrics (ETB) ---
  static bool _countsAsRevenue(Booking b) =>
      b.status == BookingStatus.completed || b.status == BookingStatus.confirmed;

  double getPlatformTotalRevenue() =>
      _cache.bookings.values.where(_countsAsRevenue).fold(0.0, (total, b) => total + b.price);

  double getShopRevenue(String shopId) => _cache.bookings.values
      .where((b) => b.shopId == shopId && _countsAsRevenue(b))
      .fold(0.0, (total, b) => total + b.price);

  double getBarberTotalEarnings(String barberId) => _cache.bookings.values
      .where((b) => b.barberId == barberId && _countsAsRevenue(b))
      .fold(0.0, (total, b) => total + b.price);

  int getBarberCompletedCutsCount(String barberId) =>
      _cache.bookings.values.where((b) => b.barberId == barberId && b.status == BookingStatus.completed).length;

  // --- shop applications (lib/features/applications) ---

  /// registerBarbershopByAdmin for an approved application. Firestore: ONE
  /// batch with the same writes as [FirestoreDataStore.createShop] (shop,
  /// services, lead barber, owner invite) plus the update of
  /// `shopApplications/{uid}` ([ShopApplicationApproval.fieldsFor]).
  /// Local mode: the local createShop, then [ShopApplicationApproval.applyLocally].
  Future<void> _createShopForApplication(
    ShopApplicationApproval approval, {
    required Barbershop shop,
    required List<BarbershopService> services,
    required List<Barber> barbers,
    required UserInvite ownerInvite,
  }) async {
    if (_firebaseReady) {
      Map<String, dynamic> noNulls(Map<String, dynamic> m) => {
            for (final e in m.entries)
              if (e.value != null) e.key: e.value,
          };
      final shopRef = _db.collection('barbershops').doc(shop.id);
      final batch = _db.batch();
      batch.set(shopRef, noNulls(shop.toMap()));
      for (final s in services) {
        batch.set(shopRef.collection('services').doc(s.id), s.toMap());
      }
      for (final b in barbers) {
        batch.set(shopRef.collection('barbers').doc(b.id), noNulls(b.toMap()));
        final phone = b.phone; // private barber phone
        if (phone != null && phone.isNotEmpty) {
          batch.set(_db.doc(FirestoreDataStore.barberContactPath(shop.id, b.id)), {'phone': phone});
        }
      }
      batch.set(_db.collection('invites').doc(ownerInvite.email), ownerInvite.toMap());
      batch.update(_db.doc(approval.path), approval.fieldsFor(shop.id));
      await batch.commit();
    } else {
      await _store.createShop(shop: shop, services: services, barbers: barbers, ownerInvite: ownerInvite);
      await approval.applyLocally?.call(shop.id);
    }
    notifyListeners();
  }

  /// A signed-in customer who has just been invited (e.g. their shop
  /// application was approved) gets the invite's role now, without signing
  /// out: the same one-time upgrade as at sign-in (users/{uid} rewritten with
  /// the invite's role/shopId/barberId and invites/{email} deleted in one
  /// batch, then the shop's empty ownerId claimed). Returns true when the
  /// role changed; RootGate then shows the new dashboard.
  Future<bool> applyPendingInviteForCurrentUser() async {
    final user = _currentUser;
    if (user == null || user.role != UserRole.customer || _authStatus != AuthStatus.signedIn) return false;
    final rawEmail = user.email;
    if (rawEmail == null || rawEmail.trim().isEmpty) return false;
    final email = normalizeEmail(rawEmail);
    if (_firebaseReady) {
      final snap = await _db.collection('invites').doc(email).get();
      if (!snap.exists) return false;
      final upgraded = _withInviteRole(user, UserInvite.fromMap(snap.data()!, snap.id));
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(user.uid), upgraded.toMap());
      batch.delete(_db.collection('invites').doc(email));
      await batch.commit();
      _currentUser = upgraded;
      await _claimShopInCloud(upgraded);
      await _cloud!.start(upgraded);
    } else {
      final invite = _cache.invites[email];
      if (invite == null) return false;
      final upgraded = _withInviteRole(user, invite);
      _cache.invites.remove(email);
      _cache.users[upgraded.uid] = upgraded;
      _claimShopLocally(upgraded);
      _currentUser = upgraded;
    }
    notifyListeners();
    return true;
  }
  // --- end shop applications ---

  // --- account deletion (logic in account_deletion.dart, writes in account_deletion_writes.dart) ---
  // Settings > Delete account, on the free Spark plan: the person's own app
  // cancels their bookings, anonymises their reviews and bookings, removes a
  // barber from their shop, deletes their personal documents and users/{uid},
  // then the Firebase Auth login. functions/auth onUserProfileDeleted
  // (Blaze) repeats the clean-up on the server.

  late AccountDeletionWrites _accountDeletionWrites = LocalAccountDeletionWrites(_cache);
  late AccountAuthService _accountAuth = _defaultLocalAccountAuth();

  AccountAuthService _defaultLocalAccountAuth() => LocalAccountAuthService(
        hasPassword: (email) => _emailAuth.hasPassword(email),
        verifyPassword: (email, password) => _emailAuth.signIn(email: email, password: password),
        onDeleteLogin: (email) {
          final local = _emailAuth;
          if (local is LocalEmailAuthService) local.deleteAccount(email);
        },
      );

  void _resetLocalAccountDeletion() {
    _accountDeletionWrites = LocalAccountDeletionWrites(_cache);
    _accountAuth = _defaultLocalAccountAuth();
    _deletingAccount = false;
    _profileDeleted = false;
    _accountDeletedNotice = false;
  }

  /// Tests: the deletion writes in use (local mode: [LocalAccountDeletionWrites]).
  @visibleForTesting
  AccountDeletionWrites get accountDeletionWrites => _accountDeletionWrites;

  /// Tests: the re-authentication / login deletion in use.
  @visibleForTesting
  AccountAuthService get accountAuthService => _accountAuth;
  @visibleForTesting
  set accountAuthService(AccountAuthService service) => _accountAuth = service;

  /// The cascade is running: the own-profile listener must not sign out.
  bool _deletingAccount = false;

  /// The session ended (sign-out or deleted login): a half-finished
  /// deletion must not carry over to the next account signed in here.
  void _forgetPendingAccountDeletion() {
    _deletingAccount = false;
    _profileDeleted = false;
  }

  /// users/{uid} is gone; only the login is left to delete (after a new
  /// sign-in when Firebase asked for one).
  bool _profileDeleted = false;

  bool _accountDeletedNotice = false;

  /// What the last deletion could not remove (e.g. rules not deployed yet).
  List<String> _deletionLeftovers = const [];
  List<String> get lastAccountDeletionLeftovers => _deletionLeftovers;

  /// The sign-in screen: whether an account was just deleted (read once).
  bool takeAccountDeletedNotice() {
    final notice = _accountDeletedNotice;
    _accountDeletedNotice = false;
    return notice;
  }

  /// How the signed-in person can confirm it is them before deleting.
  Set<ReauthMethod> get reauthMethods {
    final email = _currentUser?.email ?? '';
    return _accountAuth.methodsFor(email);
  }

  /// Whether the account's data is already deleted and only the login is
  /// left (sign in again, then [deleteMyAccount] finishes).
  bool get accountDeletionPending => _profileDeleted;

  /// What deleting the signed-in account would do, or why it cannot yet.
  AccountDeletionPreview previewAccountDeletion() {
    final user = _currentUser;
    if (user == null) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    return planAccountDeletion(
      user: user,
      bookings: _cache.bookings.values,
      shops: _cache.shops,
      users: _cache.users.values,
      nowUtc: _nowUtc(),
    );
  }

  /// Signs in again with the account's password (needed before deleting).
  Future<void> reauthenticateWithPassword(String password) async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    await _accountAuth.reauthenticateWithPassword(email, password);
  }

  /// Signs in again with Google (needed before deleting).
  Future<void> reauthenticateWithGoogle() async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    await _accountAuth.reauthenticateWithGoogle(email);
  }

  static bool _isPermissionDenied(Object e) => e is FirebaseException && e.code == 'permission-denied';

  /// Deletes the signed-in account after [confirmation] ("DELETE") and a
  /// re-authentication: see account_deletion.dart for every step. [onStep]
  /// reports each step as it starts. Throws [AccountDeletionException]:
  /// ownsShop / lastAdmin (nothing changed), stepFailed (retry continues
  /// safely), reauthRequired (data deleted, sign in again and call this
  /// again to delete the login). On success the session ends.
  Future<void> deleteMyAccount({
    required String confirmation,
    void Function(AccountDeletionStep step)? onStep,
  }) async {
    final user = _currentUser;
    if (user == null) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    if (!isDeleteConfirmation(confirmation)) {
      throw const AccountDeletionException(AccountDeletionError.confirmationMismatch);
    }
    if (!_profileDeleted) {
      switch (previewAccountDeletion().blocker) {
        case AccountDeletionBlocker.ownsShop:
          throw const AccountDeletionException(AccountDeletionError.ownsShop);
        case AccountDeletionBlocker.lastAdmin:
          throw const AccountDeletionException(AccountDeletionError.lastAdmin);
        case null:
          break;
      }
      _deletingAccount = true;
      try {
        _deletionLeftovers = await _runAccountCleanup(user, onStep);
      } catch (e) {
        _deletingAccount = false;
        rethrow;
      }
      _profileDeleted = true;
    }

    onStep?.call(AccountDeletionStep.deleteLogin);
    try {
      await _accountAuth.deleteCurrentLogin();
    } on AccountDeletionException {
      rethrow; // reauthRequired: the screen asks for a new sign-in and calls again
    } catch (e) {
      throw AccountDeletionException(AccountDeletionError.stepFailed, step: AccountDeletionStep.deleteLogin, cause: e);
    }
    await _forgetDeletedAccount(user.uid);
    _profileDeleted = false;
    _deletingAccount = false;
    _accountDeletedNotice = true;
    _clearPending();
    _authError = null;
    if (_firebaseReady) {
      // Deleting the login signs out (the auth listener resets the session).
      try {
        await _googleAuth.signOut();
      } catch (e) {
        debugPrint('Sign out after account deletion: $e');
      }
      return;
    }
    _currentUser = null;
    _authStatus = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Favourites kept on this device for [uid] (best effort).
  Future<void> _forgetDeletedAccount(String uid) async {
    _favoriteShopIds.clear();
    _favoriteBarberIds.clear();
    _favoriteBarbers.remove(uid);
    _favoriteBarberLoads.remove(uid);
    _favoriteBarbersRead.remove(uid);
    try {
      await _favoriteStore?.save(uid, const []);
    } catch (e) {
      debugPrint('Could not clear saved favourites: $e');
    }
  }

  /// Steps 1-6 (everything but the login). Returns the parts that could not
  /// be removed because the rules refused them (Blaze cleans them up).
  Future<List<String>> _runAccountCleanup(AppUser user, void Function(AccountDeletionStep step)? onStep) async {
    final now = _nowUtc();
    final leftovers = <String>[];
    Never fail(AccountDeletionStep step, Object e) =>
        throw AccountDeletionException(AccountDeletionError.stepFailed, step: step, cause: e);

    // All of the person's bookings as a customer (the app keeps 90 days).
    final byId = {for (final b in _cache.bookings.values) b.id: b};
    try {
      for (final b in await _accountDeletionWrites.bookingsOfCustomer(user.uid)) {
        byId[b.id] = b;
      }
    } catch (e) {
      debugPrint('Account deletion: could not load all bookings: $e');
    }
    final plan = planAccountDeletion(
      user: user,
      bookings: byId.values,
      shops: _cache.shops,
      users: _cache.users.values,
      nowUtc: now,
    );
    String? languageOf(String uid) => _cache.users[uid]?.language;

    // 1. Cancel upcoming bookings (customer cancel; barber cancel + notice).
    onStep?.call(AccountDeletionStep.cancelBookings);
    final keepContact = <String>{};
    for (final b in plan.toCancel) {
      try {
        await _store.updateBookingStatus(
          b,
          BookingStatus.cancelled,
          cancelledBy: user.uid,
          refund: RefundContext(
            by: RefundCanceller.customer,
            nowUtc: now,
            cutoffHours: _cache.shops[b.shopId]?.cancellationCutoffHours,
            languageOf: languageOf,
          ),
        );
        // A paid booking now has a refund due: the shop needs the phone.
        if (needsRefundFlag(b)) keepContact.add(b.id);
      } catch (e) {
        // e.g. the cutoff passed meanwhile: the booking stays, anonymised.
        if (!_isPermissionDenied(e)) fail(AccountDeletionStep.cancelBookings, e);
        debugPrint('Account deletion: could not cancel ${b.id}: $e');
      }
    }
    for (final b in plan.barberToCancel) {
      try {
        await _store.updateBookingStatus(
          b,
          BookingStatus.cancelled,
          cancelledBy: user.uid,
          refund: RefundContext(by: RefundCanceller.barber, nowUtc: now, languageOf: languageOf),
        );
      } catch (e) {
        if (!_isPermissionDenied(e)) fail(AccountDeletionStep.cancelBookings, e);
        debugPrint('Account deletion: could not cancel ${b.id}: $e');
        continue;
      }
      if (b.customerId.isEmpty) continue;
      try {
        final text = renderBarberLeftText(b, language: languageOf(b.customerId) ?? 'am');
        await _store.writeVacationCancelNotice(
          b.customerId,
          AppNotification(
            id: '${b.id}_cancelled',
            title: text.title,
            body: text.body,
            type: NotificationTypes.cancelled,
            bookingId: b.id,
            createdAt: now,
          ),
        );
      } catch (e) {
        debugPrint('Account deletion: could not notify the customer of ${b.id}: $e');
      }
    }
    if (plan.toCancel.isNotEmpty || plan.barberToCancel.isNotEmpty) notifyListeners();

    // 2. Reviews: "Former customer", comment removed, stars kept.
    onStep?.call(AccountDeletionStep.anonymizeReviews);
    final completed = [
      for (final b in byId.values)
        if (b.customerId == user.uid && b.status == BookingStatus.completed) b,
    ];
    try {
      await _accountDeletionWrites.anonymizeReviews(user.uid, completed);
    } catch (e) {
      if (!_isPermissionDenied(e)) fail(AccountDeletionStep.anonymizeReviews, e);
      leftovers.add('reviews');
    }

    // 3. Bookings: "Former customer", no phone (not while a refund is due).
    onStep?.call(AccountDeletionStep.anonymizeBookings);
    final anonymize = [
      for (final b in byId.values)
        if (needsBookingAnonymizing(b, user.uid) && !keepContact.contains(b.id)) b,
    ];
    try {
      await _accountDeletionWrites.anonymizeBookings(anonymize);
    } catch (e) {
      if (!_isPermissionDenied(e)) fail(AccountDeletionStep.anonymizeBookings, e);
      leftovers.add('bookings');
    }

    // 4. A barber leaves the shop (profile and private contact).
    final shopId = user.shopId;
    final barberId = user.barberId;
    if (user.role == UserRole.barber && shopId != null && barberId != null) {
      onStep?.call(AccountDeletionStep.leaveShop);
      try {
        await _accountDeletionWrites.removeBarberProfile(shopId, barberId);
      } catch (e) {
        if (!_isPermissionDenied(e)) fail(AccountDeletionStep.leaveShop, e);
        leftovers.add('barberProfile');
      }
    }

    // 5. Invite, application, removal request, inbox, device tokens.
    onStep?.call(AccountDeletionStep.deletePersonalData);
    leftovers.addAll(await _accountDeletionWrites.deletePersonalData(user));

    // 6. users/{uid}. The listeners stop first (the own-profile listener
    // would end the session as soon as the document is gone).
    onStep?.call(AccountDeletionStep.deleteProfile);
    await _cloud?.stop();
    try {
      await _accountDeletionWrites.deleteProfile(user.uid);
    } catch (e) {
      final cloud = _cloud;
      if (cloud != null) unawaited(cloud.start(user).catchError((Object _) {}));
      fail(AccountDeletionStep.deleteProfile, e);
    }
    _cache.users.remove(user.uid);
    return leftovers;
  }

  // --- shop removal requests (an owner who wants to delete their account) ---

  /// The signed-in owner's request, live (null when none).
  Stream<ShopRemovalRequest?> watchMyShopRemovalRequest() {
    final user = _currentUser;
    if (user == null) return Stream.value(null);
    return _accountDeletionWrites.watchMyRemovalRequest(user.uid);
  }

  /// Owner: asks the admin to remove their shop (so they can then delete
  /// their account), with an optional [note] (up to 500 characters).
  Future<void> requestShopRemoval({String? note}) async {
    final user = _currentUser;
    if (user == null) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    final shop = ownedShopOf(user, _cache.shops);
    if (shop == null) throw const AccountDeletionException(AccountDeletionError.stepFailed);
    await _accountDeletionWrites.createRemovalRequest(ShopRemovalRequest(
      uid: user.uid,
      email: user.email ?? '',
      name: user.name,
      shopId: shop.id,
      shopName: shop.name,
      note: normalizeShopRemovalNote(note),
      createdAt: _nowUtc(),
    ));
    notifyListeners();
  }

  /// Owner: withdraws their request.
  Future<void> withdrawShopRemovalRequest() async {
    final user = _currentUser;
    if (user == null) throw const AccountDeletionException(AccountDeletionError.notSignedIn);
    await _write(_accountDeletionWrites.withdrawRemovalRequest(user.uid));
  }

  /// Admin: every shop removal request, newest first (empty for others).
  Stream<List<ShopRemovalRequest>> watchShopRemovalRequests() {
    if (_currentUser?.role != UserRole.admin) return Stream.value(const []);
    return _accountDeletionWrites.watchRemovalRequests();
  }

  /// Admin: marks a request done (the shop was removed) or dismissed.
  Future<void> resolveShopRemovalRequest(String uid, ShopRemovalStatus status) async {
    _requireAdmin();
    await _write(_accountDeletionWrites.resolveRemovalRequest(
      uid,
      ShopRemovalRequest.resolveFields(status, at: _nowUtc(), by: _currentUser!.uid),
    ));
  }
  // --- end account deletion ---

  // --- Favorites Management (kept on this device) ---
  bool isShopFavorite(String shopId) => _favoriteShopIds.contains(shopId);
  void toggleFavoriteShop(String shopId) {
    if (_favoriteShopIds.contains(shopId)) {
      _favoriteShopIds.remove(shopId);
    } else {
      _favoriteShopIds.add(shopId);
    }
    notifyListeners();
  }

  // --- favourite barbers & rebook (logic in rebook_service.dart) ---
  // Favourite barbers belong to the signed-in customer and are kept on this
  // device (shared_preferences, one key per account; nothing in Firestore,
  // so no rules and it works on the free plan). In local/demo mode without
  // a store, a customer starts with the seed's favourites.

  /// uid -> barberId -> favourite, for the accounts used this session.
  final Map<String, Map<String, rebook.FavoriteBarber>> _favoriteBarbers = {};

  /// uid -> the read of that account's saved favourites.
  final Map<String, Future<void>> _favoriteBarberLoads = {};

  /// Barbers toggled while the saved list was still loading (their new
  /// state wins over the saved one).
  final Set<String> _favoriteBarbersToggledEarly = {};

  /// Accounts whose saved favourites have been read.
  final Set<String> _favoriteBarbersRead = {};

  FavoriteBarbersStore? _favoriteBarbersStoreOverride;
  FavoriteBarbersStore? _prefsFavoriteBarbersStore;

  /// Tests: keeps favourites in [store] (also in local mode). Null restores
  /// the default (shared_preferences with Firebase, none locally).
  @visibleForTesting
  set favoriteBarbersStore(FavoriteBarbersStore? store) {
    _favoriteBarbersStoreOverride = store;
    _favoriteBarbers.clear();
    _favoriteBarberLoads.clear();
    _favoriteBarbersRead.clear();
  }

  FavoriteBarbersStore? get _favoriteStore =>
      _favoriteBarbersStoreOverride ??
      (_firebaseReady ? (_prefsFavoriteBarbersStore ??= PrefsFavoriteBarbersStore()) : null);

  /// The signed-in customer's favourites (null for anyone else). The first
  /// call for an account starts reading its saved list.
  Map<String, rebook.FavoriteBarber>? _customerFavoriteBarbers() {
    final user = _currentUser;
    if (user == null || user.role != UserRole.customer) return null;
    final existing = _favoriteBarbers[user.uid];
    if (existing != null) return existing;
    final favs = <String, rebook.FavoriteBarber>{};
    _favoriteBarbers[user.uid] = favs;
    final store = _favoriteStore;
    if (store == null) {
      for (final id in _favoriteBarberIds) {
        final b = _cache.barbers[id];
        if (b != null) favs[id] = rebook.FavoriteBarber(barberId: id, shopId: b.shopId, barberName: b.name);
      }
    } else {
      _favoriteBarberLoads[user.uid] = _readSavedFavoriteBarbers(user.uid, store, favs);
    }
    return favs;
  }

  Future<void> _readSavedFavoriteBarbers(
      String uid, FavoriteBarbersStore store, Map<String, rebook.FavoriteBarber> favs) async {
    final saved = await store.load(uid);
    if (!identical(_favoriteBarbers[uid], favs)) return; // reset meanwhile
    var changed = false;
    for (final f in saved) {
      if (_favoriteBarbersToggledEarly.contains(f.barberId) || favs.containsKey(f.barberId)) continue;
      favs[f.barberId] = f;
      changed = true;
    }
    _favoriteBarbersToggledEarly.clear();
    _favoriteBarbersRead.add(uid);
    if (changed) notifyListeners();
  }

  /// Waits until the signed-in customer's saved favourites are read.
  Future<void> loadFavoriteBarbers() async {
    _customerFavoriteBarbers();
    final uid = _currentUser?.uid;
    final load = uid == null ? null : _favoriteBarberLoads[uid];
    if (load != null) await load;
  }

  bool isBarberFavorite(String barberId) => _customerFavoriteBarbers()?.containsKey(barberId) ?? false;

  /// The signed-in customer's favourite barbers, oldest first.
  List<rebook.FavoriteBarber> getFavoriteBarbers() =>
      List.unmodifiable(_customerFavoriteBarbers()?.values ?? const <rebook.FavoriteBarber>[]);

  /// Adds or removes a favourite barber of the signed-in customer and
  /// returns whether it is now a favourite. [shopId] and [barberName]
  /// default to the barber's live profile. Anyone but a signed-in customer
  /// gets false and nothing changes.
  bool toggleFavoriteBarber(String barberId, {String? shopId, String? barberName}) {
    final favs = _customerFavoriteBarbers();
    if (favs == null || barberId.isEmpty) return false;
    final uid = _currentUser!.uid;
    if (favs.remove(barberId) == null) {
      final b = _cache.barbers[barberId];
      favs[barberId] = rebook.FavoriteBarber(
        barberId: barberId,
        shopId: shopId ?? b?.shopId ?? '',
        barberName: barberName ?? b?.name ?? '',
      );
    }
    if (_favoriteBarberLoads.containsKey(uid) && !_favoriteBarbersRead.contains(uid)) {
      _favoriteBarbersToggledEarly.add(barberId);
    }
    final store = _favoriteStore;
    if (store != null) unawaited(store.save(uid, favs.values.toList()));
    notifyListeners();
    return favs.containsKey(barberId);
  }

  /// The "Your barbers" row of the signed-in customer: favourites, then the
  /// barbers of recent completed bookings. Empty for anyone else.
  List<rebook.RebookCandidate> getYourBarbers() {
    final user = _currentUser;
    final favs = _customerFavoriteBarbers();
    if (user == null || favs == null) return const [];
    return rebook.buildYourBarbers(
      favorites: favs.values,
      bookings: getCustomerBookings(user.uid),
      barberById: getBarberById,
      shopById: getShopById,
      nowUtc: _nowUtc(),
    );
  }

  /// "Book again" from a past booking.
  rebook.RebookCandidate rebookCandidateFor(Booking booking) =>
      rebook.RebookCandidate.fromBooking(booking, isFavorite: isBarberFavorite(booking.barberId));

  /// Whether [candidate] can open the booking flow, or which fallback to
  /// show (shop gone or suspended, barber left or unavailable, service gone).
  rebook.RebookCheck checkRebook(rebook.RebookCandidate candidate) => rebook.checkRebook(
        candidate,
        shopById: getShopById,
        barberById: getBarberById,
        servicesForShop: getServicesForShop,
      );
  // --- end favourite barbers & rebook ---
}

class BarberWithShop {
  final Barber barber;
  final Barbershop shop;

  BarberWithShop({
    required this.barber,
    required this.shop,
  });
}
