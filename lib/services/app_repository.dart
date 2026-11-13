import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/config/app_config.dart';
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
import 'firestore_data_store.dart';
import 'phone_auth_service.dart';
import 'time_off_service.dart';

export '../models/app_exception.dart';

/// Where the signed-in session currently stands.
enum AuthStatus {
  /// Checking Firebase for an existing session / loading the user's profile.
  initializing,
  signedOut,

  /// Phone verified, but no `users/{uid}` profile yet (first sign-in).
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
  PhoneAuthService? _phoneAuth;
  StreamSubscription<User?>? _authSub;

  bool get isFirebaseAttached => _firebaseReady;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Connects the repository to Firebase Auth and Firestore. Call once after
  /// `Firebase.initializeApp` succeeds.
  void attachFirebase() {
    if (_firebaseReady) return;
    _firebaseReady = true;
    _phoneAuth = PhoneAuthService(FirebaseAuth.instance);
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
    _pendingPhone = null;
    _pendingInvite = null;
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

  /// The phone number being verified / just verified (E.164).
  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  /// Invite matching the verified phone number, shown on profile setup.
  UserInvite? _pendingInvite;
  UserInvite? get pendingInvite => _pendingInvite;

  /// Last session-level error (e.g. profile could not be loaded).
  AppException? _authError;
  AppException? get authError => _authError;

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

  /// Sends a one-time SMS code to an Ethiopian mobile number.
  /// Throws [AppFormatException] ([AppErrorCode.invalidPhone]) if the number
  /// is not valid.
  Future<void> sendOtp(String phoneInput) async {
    final phone = normalizeEthiopianPhone(phoneInput);
    if (phone == null) {
      throw AppFormatException(AppErrorCode.invalidPhone);
    }
    _authError = null;
    if (_firebaseReady) {
      await _phoneAuth!.sendCode(phone);
    }
    _pendingPhone = phone;
  }

  /// Confirms the SMS code. On success the session moves to
  /// [AuthStatus.signedIn] (existing account) or [AuthStatus.needsProfile]
  /// (first sign-in).
  Future<void> verifyOtp(String code) async {
    final trimmed = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      throw AppFormatException(AppErrorCode.invalidOtpCode);
    }

    if (_firebaseReady) {
      // Firebase signs in; _onFirebaseAuthChanged then loads the profile.
      await _phoneAuth!.verifyCode(trimmed);
      return;
    }

    // Local (demo / test) verification.
    final phone = _pendingPhone;
    if (phone == null) throw AppStateException(AppErrorCode.requestCodeFirst);
    if (trimmed != kDemoOtpCode) {
      throw AppFormatException(AppErrorCode.wrongDemoCode, [kDemoOtpCode]);
    }

    final existing = _cache.users.values.where((u) => u.phone == phone).firstOrNull;
    final invite = _cache.invites[phone];
    if (existing != null) {
      var user = existing;
      if (invite != null && existing.role == UserRole.customer) {
        user = _withInviteRole(existing, invite);
        _cache.invites.remove(phone);
        _cache.users[user.uid] = user;
        _claimShopLocally(user);
      }
      _currentUser = user;
      _authStatus = AuthStatus.signedIn;
    } else {
      _pendingInvite = invite;
      _authStatus = AuthStatus.needsProfile;
    }
    notifyListeners();
  }

  /// Creates the profile for a first-time user. The role comes from the
  /// pending invite for their phone number, or is `customer` without one.
  Future<void> completeProfile({required String name}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw AppFormatException(AppErrorCode.invalidName);
    }
    final phone = _pendingPhone;
    if (_authStatus != AuthStatus.needsProfile || phone == null) {
      throw AppStateException(AppErrorCode.verifyPhoneFirst);
    }
    final invite = _pendingInvite;

    final uid = _firebaseReady ? FirebaseAuth.instance.currentUser!.uid : _uuid.v4();
    final user = AppUser(
      uid: uid,
      name: cleanName,
      phone: phone,
      role: invite?.role ?? UserRole.customer,
      shopId: invite?.shopId,
      barberId: invite?.barberId,
      createdAt: DateTime.now(),
    );

    if (_firebaseReady) {
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), user.toMap());
      if (invite != null) batch.delete(_db.collection('invites').doc(phone));
      await batch.commit();
      await _claimShopInCloud(user);
      await _cloud!.start(user);
    } else {
      _cache.invites.remove(phone);
      _claimShopLocally(user);
    }

    _cache.users[user.uid] = user;
    _currentUser = user;
    _pendingInvite = null;
    _authStatus = AuthStatus.signedIn;
    notifyListeners();
  }

  /// Updates the signed-in user's own name and/or language ('en' | 'am').
  Future<void> updateMyProfile({String? name, String? language}) async {
    final user = _currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    final cleanName = name?.trim();
    if (cleanName != null && (cleanName.isEmpty || cleanName.length > 100)) {
      throw AppFormatException(AppErrorCode.invalidName);
    }
    if (language != null && language != 'en' && language != 'am') {
      throw ArgumentError.value(language, 'language', "must be 'en' or 'am'");
    }
    final updated = user.copyWith(name: cleanName, language: language);
    _currentUser = updated;
    final write = _store.updateUserProfile(user.uid, name: cleanName, language: language);
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
    _pendingPhone = null;
    _pendingInvite = null;
    _authError = null;
    if (_firebaseReady) {
      _phoneAuth?.reset();
      await FirebaseAuth.instance.signOut();
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
      _pendingInvite = null;
      _authStatus = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _authStatus = AuthStatus.initializing;
    notifyListeners();

    try {
      final phone = fbUser.phoneNumber;
      _pendingPhone = phone;

      UserInvite? invite;
      if (phone != null) {
        final inviteSnap = await _db.collection('invites').doc(phone).get();
        if (inviteSnap.exists) invite = UserInvite.fromMap(inviteSnap.data()!, inviteSnap.id);
      }

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
        batch.delete(_db.collection('invites').doc(invite.phone));
        await batch.commit();
        await _claimShopInCloud(upgraded);
        user = upgraded;
      }

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

  /// Throws if [phone] already belongs to a staff, owner or admin account
  /// (an invite must never silently move that person to another role).
  /// With Firestore this checks the users the caller can see (all for the
  /// admin, the shop's staff for an owner); the security rules and the
  /// sign-in flow enforce it for everyone else (invites only upgrade
  /// customers).
  void _assertPhoneCanBeInvited(String phone) {
    final existing = _cache.users.values.where((u) => u.phone == phone).firstOrNull;
    if (existing != null && existing.role != UserRole.customer) {
      throw AppFormatException(AppErrorCode.phoneAlreadyStaff, [existing.role]);
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

  /// Registers a shop and invites its owner by phone number. The owner gets
  /// the barbershopOwner role when they first sign in with that number.
  Future<String> registerBarbershopByAdmin({
    required String shopName,
    required String ownerName,
    required String ownerPhone,
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
    final phone = normalizeEthiopianPhone(ownerPhone);
    if (phone == null) {
      throw AppFormatException(AppErrorCode.invalidOwnerPhone);
    }
    _assertPhoneCanBeInvited(phone);

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
      phone: (shopPhone == null || shopPhone.trim().isEmpty) ? phone : shopPhone.trim(),
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
      phone: phone,
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      specialties: ['Skin Fade', 'Beard Sculpting', 'Hot Shave'],
    );

    final ownerInvite = UserInvite(
      phone: phone,
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

  /// Adds a barber profile to a shop. If [phone] is given, the barber is also
  /// invited to sign in: the first sign-in with that number gets the barber
  /// role linked to this profile.
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
    String? normalizedPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      normalizedPhone = normalizeEthiopianPhone(phone);
      if (normalizedPhone == null) {
        throw AppFormatException(AppErrorCode.invalidPhone);
      }
      _assertPhoneCanBeInvited(normalizedPhone);
    }

    final id = _uuid.v4();
    final barber = Barber(
      id: id,
      shopId: shopId,
      name: name,
      title: title,
      email: email,
      phone: normalizedPhone,
      specialties: specialties ?? const ['Skin Fade', 'Beard Trim'],
      avatarUrl: avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      workingDays: workingDays,
      startHour: startHour,
      endHour: endHour,
    );

    final invite = normalizedPhone == null
        ? null
        : UserInvite(
            phone: normalizedPhone,
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
