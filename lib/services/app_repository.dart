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
import 'availability_service.dart';
import 'booking_policy.dart' as policy;
import 'data_cache.dart';
import 'data_store.dart';
import 'email_auth_service.dart';
import 'firestore_data_store.dart';
import 'google_auth_service.dart';
import 'time_off_service.dart';

export '../models/app_exception.dart';
export 'email_auth_service.dart' show EmailAuthException, EmailAuthErrorCode, EmailCodeSent;

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
      LocalEmailAuthService(isExistingAccount: (email) => _findUserByEmail(email) != null);

  /// Tests: replaces the email sign-in service used in local mode. [loadSeed]
  /// restores a fresh in-memory one.
  @visibleForTesting
  set emailAuthService(EmailAuthService service) => _emailAuth = service;

  bool get isFirebaseAttached => _firebaseReady;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Connects the repository to Firebase Auth and Firestore. Call once after
  /// `Firebase.initializeApp` succeeds.
  void attachFirebase() {
    if (_firebaseReady) return;
    _firebaseReady = true;
    final google = FirebaseGoogleAuthService(FirebaseAuth.instance);
    _googleAuth = google;
    _emailAuth = FirebaseEmailAuthService(FirebaseAuth.instance);
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
    _currentUser = null;
    _authStatus = AuthStatus.signedOut;
    _googleAuth = _defaultLocalGoogleAuth();
    _emailAuth = _defaultLocalEmailAuth();
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

  /// Registration step 1: checks [email] and [password] locally, then emails
  /// a 6-digit code. [language] ('en' | 'am') picks the email's language.
  Future<EmailCodeSent> registerRequestCode({
    required String email,
    required String password,
    String language = 'en',
  }) async {
    final normalized = _validEmailOrThrow(email);
    _checkPassword(password);
    return _emailAuth.requestCode(email: normalized, purpose: EmailCodePurpose.register, language: language);
  }

  /// Registration step 2: verifies [code], creates the account (its email is
  /// verified by the code) and signs in. A new account continues at
  /// [AuthStatus.needsProfile], where email invites apply as usual.
  Future<void> registerComplete({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    final normalized = _validEmailOrThrow(email);
    _checkPassword(password);
    final validCode = _codeOrThrow(code);
    await _emailAuth.completeRegistration(email: normalized, code: validCode, password: password, name: name);
    await loginWithEmail(email: normalized, password: password);
  }

  /// Signs in with email and password. With Firebase the auth listener loads
  /// the profile; locally the session switches immediately.
  Future<void> loginWithEmail({required String email, required String password}) async {
    _authError = null;
    final normalized = _validEmailOrThrow(email);
    if (password.isEmpty) throw const EmailAuthException(EmailAuthErrorCode.wrongCredentials);
    final identity = await _emailAuth.signIn(email: normalized, password: password);
    if (_firebaseReady) return;
    final existing = _findUserByEmail(identity.email);
    _signInLocally(identity.email, identity.displayName ?? existing?.name);
  }

  /// Forgot password step 1: emails a reset code. Succeeds whether or not an
  /// account exists for [email].
  Future<EmailCodeSent> resetRequestCode({required String email, String language = 'en'}) {
    final normalized = _validEmailOrThrow(email);
    return _emailAuth.requestCode(email: normalized, purpose: EmailCodePurpose.reset, language: language);
  }

  /// Forgot password step 2: verifies [code] and sets [newPassword]. Does not
  /// sign in.
  Future<void> resetComplete({required String email, required String code, required String newPassword}) async {
    final normalized = _validEmailOrThrow(email);
    _checkPassword(newPassword);
    final validCode = _codeOrThrow(code);
    await _emailAuth.resetPassword(email: normalized, code: validCode, newPassword: newPassword);
  }

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

    final uid = _firebaseReady ? FirebaseAuth.instance.currentUser!.uid : _uuid.v4();
    final user = AppUser(
      uid: uid,
      email: email,
      name: cleanName,
      phone: normalizedPhone,
      role: invite?.role ?? UserRole.customer,
      shopId: invite?.shopId,
      barberId: invite?.barberId,
      createdAt: DateTime.now(),
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
      _currentUser = null;
      _clearPending();
      _authStatus = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _authStatus = AuthStatus.initializing;
    notifyListeners();

    try {
      final rawEmail = fbUser.email;
      if (rawEmail == null || rawEmail.isEmpty || !fbUser.emailVerified) {
        // Only verified emails can sign in (the rules check
        // request.auth.token.email_verified too): Google accounts, and
        // email/password accounts created with an emailed code. Sessions
        // from the old phone sign-in end here quietly.
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
      final inviteSnap = await _db.collection('invites').doc(email).get();
      if (inviteSnap.exists) invite = UserInvite.fromMap(inviteSnap.data()!, inviteSnap.id);

      final userSnap = await _db.collection('users').doc(fbUser.uid).get();
      if (!userSnap.exists) {
        _pendingInvite = invite;
        _authStatus = AuthStatus.needsProfile;
        notifyListeners();
        return;
      }

      var user = AppUser.fromMap(userSnap.data()!, userSnap.id);
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

  /// The signed-in user's own profile document changed in Firestore.
  void _onCurrentUserDocChanged(AppUser? user) {
    final current = _currentUser;
    if (current == null || _authStatus != AuthStatus.signedIn) return;
    if (user == null) {
      // Profile removed (e.g. by an admin): end the session.
      signOut();
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
  /// Google using that email.
  Future<String> registerBarbershopByAdmin({
    required String shopName,
    required String ownerName,
    required String ownerEmail,
    required String address,
    required String city,
    required String description,
    required String imageUrl,
    required int openingHour,
    required int closingHour,
    required List<int> workingDays,
    required bool isVerified,
    String subCity = '',
    String? landmark,
    String? shopPhone,
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
      phone: contactPhone,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      rating: 5.0,
      reviewCount: 0,
      openingHour: openingHour,
      closingHour: closingHour,
      workingDays: workingDays,
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

  Future<void> deleteShop(String shopId) async {
    await _write(_store.deleteShop(shopId));
  }

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
        .where((s) => !s.isSuspended || user?.role == UserRole.admin || (user?.shopId != null && user!.shopId == s.id))
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
      phone: normalizedPhone,
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

    await _write(_store.addBarber(barber, invite));
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

  /// Every booking the current user can see (all for the admin, up to the
  /// latest [FirestoreDataStore.adminBookingLimit] with Firebase).
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
    if (shop != null && shop.isSuspended) {
      throw AppStateException(AppErrorCode.shopNotTakingBookings);
    }
    final barber = _cache.barbers[barberId];
    if (barber != null && !barber.isAvailable) {
      throw AppStateException(AppErrorCode.barberNotTakingBookings, [barber.name]);
    }
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
      status: BookingStatus.confirmed,
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
    await _write(_store.updateBookingStatus(
      booking,
      newStatus,
      cancelledBy: newStatus == BookingStatus.cancelled ? _currentUser?.uid : null,
    ));
  }

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
  Future<void> updateShopPolicy(String shopId, {required int cancellationCutoffHours, required int maxReschedules}) async {
    policy.validatePolicy(cancellationCutoffHours: cancellationCutoffHours, maxReschedules: maxReschedules);
    if (!_cache.shops.containsKey(shopId)) return;
    await _write(_store.updateShopPolicy(shopId,
        cancellationCutoffHours: cancellationCutoffHours, maxReschedules: maxReschedules));
  }

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

  // --- Reviews (logic in reviews_service.dart) ---

  /// Local mode only (demo builds, tests): sets the shop's and its barbers'
  /// `rating` / `reviewCount`, as the insights Cloud Function does with
  /// Firebase. Ignored once Firebase is attached.
  void applyLocalRatings(String shopId, RatingSummary shop, Map<String, RatingSummary> barbers) {
    if (_firebaseReady) return;
    final current = _cache.shops[shopId];
    if (current != null) _cache.shops[shopId] = current.copyWith(rating: shop.rating, reviewCount: shop.count);
    barbers.forEach((barberId, summary) {
      final barber = _cache.barbers[barberId];
      if (barber != null) _cache.barbers[barberId] = barber.copyWith(rating: summary.rating, reviewCount: summary.count);
    });
    notifyListeners();
  }

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

  bool isBarberFavorite(String barberId) => _favoriteBarberIds.contains(barberId);
  void toggleFavoriteBarber(String barberId) {
    if (_favoriteBarberIds.contains(barberId)) {
      _favoriteBarberIds.remove(barberId);
    } else {
      _favoriteBarberIds.add(barberId);
    }
    notifyListeners();
  }
}

class BarberWithShop {
  final Barber barber;
  final Barbershop shop;

  BarberWithShop({
    required this.barber,
    required this.shop,
  });
}
