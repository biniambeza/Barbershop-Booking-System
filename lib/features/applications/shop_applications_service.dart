import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/config/app_config.dart';
import '../../core/utils/email_utils.dart';
import '../../data/addis_locations.dart';
import '../../data/seed_dataset.dart';
import '../../models/shop_application.dart';
import '../../models/user_model.dart';
import '../../services/app_repository.dart';

export '../../models/shop_application.dart';

/// Storage of `shopApplications/{uid}`: [FirestoreShopApplicationStore] in
/// production, [LocalShopApplicationStore] in DEMO_MODE builds and tests.
abstract class ShopApplicationStore {
  /// One applicant's application (null when there is none), live.
  Stream<ShopApplication?> watch(String uid);

  Future<ShopApplication?> get(String uid);

  /// Admin: every pending application plus the [decidedLimit] most recently
  /// reviewed ones, in [ShopApplication.adminOrder], live.
  Stream<List<ShopApplication>> watchForAdmin({int decidedLimit = 20});

  /// Creates the application, or overwrites a rejected one (full document,
  /// status `pending`, no review fields).
  Future<void> submit(ShopApplication application);

  /// Applicant, while pending: the six editable fields only.
  Future<void> updatePending(ShopApplication application);

  /// Applicant, while pending: deletes the document.
  Future<void> withdraw(String uid);

  /// Admin: {status: 'rejected', reviewedBy, reviewedAt, rejectReason}.
  Future<void> reject(String uid, {required String reviewedBy, required DateTime reviewedAt, required String reason});

  /// Local mode only: {status: 'approved', reviewedBy, reviewedAt, shopId}.
  /// (With Firestore the repository writes this in the shop's batch.)
  Future<void> markApproved(String uid, Map<String, dynamic> fields);
}

/// Firestore access (all on the `shopApplications` collection):
///
///  * applicant:  doc `shopApplications/{uid}` snapshots / get; set (create
///                or overwrite after rejection); update of ownerName,
///                shopName, address, subCity, phone, description (deleted
///                when empty) while pending; delete while pending
///  * admin:      query where status == 'pending' (single-field index) and
///                query orderBy reviewedAt desc limit n (single-field
///                index); update {status, reviewedBy, reviewedAt,
///                rejectReason} on reject. Approval is written by
///                AppRepository in the shop-creation batch.
class FirestoreShopApplicationStore implements ShopApplicationStore {
  FirestoreShopApplicationStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('shopApplications');

  static ShopApplication? _fromSnap(DocumentSnapshot<Map<String, dynamic>> s) =>
      s.exists ? ShopApplication.fromMap(s.data()!, s.id) : null;

  @override
  Stream<ShopApplication?> watch(String uid) => _col.doc(uid).snapshots().map(_fromSnap);

  @override
  Future<ShopApplication?> get(String uid) async => _fromSnap(await _col.doc(uid).get());

  @override
  Stream<List<ShopApplication>> watchForAdmin({int decidedLimit = 20}) {
    late StreamController<List<ShopApplication>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? pendingSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? decidedSub;
    List<ShopApplication>? pending;
    List<ShopApplication>? decided;
    List<ShopApplication> read(QuerySnapshot<Map<String, dynamic>> qs) =>
        [for (final d in qs.docs) ShopApplication.fromMap(d.data(), d.id)];
    void emit() {
      if (pending == null || decided == null || controller.isClosed) return;
      final byId = <String, ShopApplication>{
        for (final a in decided!) a.uid: a,
        for (final a in pending!) a.uid: a,
      };
      controller.add(byId.values.toList()..sort(ShopApplication.adminOrder));
    }

    controller = StreamController<List<ShopApplication>>(
      onListen: () {
        pendingSub = _col.where('status', isEqualTo: ShopApplicationStatus.pending.name).snapshots().listen((qs) {
          pending = read(qs);
          emit();
        }, onError: controller.addError);
        decidedSub = _col.orderBy('reviewedAt', descending: true).limit(decidedLimit).snapshots().listen((qs) {
          decided = read(qs).where((a) => !a.isPending).toList();
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await pendingSub?.cancel();
        await decidedSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> submit(ShopApplication application) => _col.doc(application.uid).set(application.toMap());

  @override
  Future<void> updatePending(ShopApplication a) => _col.doc(a.uid).update({
        'ownerName': a.ownerName,
        'shopName': a.shopName,
        'address': a.address,
        'subCity': a.subCity,
        'phone': a.phone,
        'description': a.description ?? FieldValue.delete(),
      });

  @override
  Future<void> withdraw(String uid) => _col.doc(uid).delete();

  @override
  Future<void> reject(String uid, {required String reviewedBy, required DateTime reviewedAt, required String reason}) =>
      _col.doc(uid).update({
        'status': ShopApplicationStatus.rejected.name,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt.toUtc().toIso8601String(),
        'rejectReason': reason,
      });

  @override
  Future<void> markApproved(String uid, Map<String, dynamic> fields) => _col.doc(uid).update(fields);
}

/// In-memory applications for DEMO_MODE builds and tests. In DEMO_MODE it
/// loads the dataset's `shopApplications` on first use.
class LocalShopApplicationStore implements ShopApplicationStore {
  LocalShopApplicationStore({this.seedFromAssets = false});

  final bool seedFromAssets;

  final Map<String, ShopApplication> _apps = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  bool _seeded = false;
  Future<void>? _seeding;

  /// Replaces all applications with the dataset's `shopApplications`.
  void loadSeedJson(Map<String, dynamic> json, {DateTime? now}) {
    _apps
      ..clear()
      ..addEntries(shopApplicationsFromSeedJson(json, now: now).map((a) => MapEntry(a.uid, a)));
    _seeded = true;
    _changes.add(null);
  }

  void clear() {
    _apps.clear();
    _seeded = true;
    _changes.add(null);
  }

  /// Every application (tests).
  List<ShopApplication> get all => List.unmodifiable(_apps.values);

  Future<void> _ensureSeeded() {
    if (_seeded || !seedFromAssets) return Future.value();
    return _seeding ??= () async {
      try {
        final text = await rootBundle.loadString(kSeedAssetPath);
        if (!_seeded) loadSeedJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not load the demo shop applications: $e');
        _seeded = true;
      }
    }();
  }

  Stream<T> _watchState<T>(T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.listen((_) {
          if (!controller.isClosed) controller.add(read());
        });
        _ensureSeeded().then((_) {
          if (!controller.isClosed) controller.add(read());
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<ShopApplication?> watch(String uid) => _watchState(() => _apps[uid]);

  @override
  Future<ShopApplication?> get(String uid) async {
    await _ensureSeeded();
    return _apps[uid];
  }

  @override
  Stream<List<ShopApplication>> watchForAdmin({int decidedLimit = 20}) => _watchState(() {
        final pending = _apps.values.where((a) => a.isPending);
        final decided = (_apps.values.where((a) => !a.isPending).toList()..sort(ShopApplication.adminOrder))
            .take(decidedLimit);
        return [...pending, ...decided]..sort(ShopApplication.adminOrder);
      });

  @override
  Future<void> submit(ShopApplication application) async {
    await _ensureSeeded();
    _apps[application.uid] = application;
    _changes.add(null);
  }

  @override
  Future<void> updatePending(ShopApplication a) async {
    await _ensureSeeded();
    final current = _apps[a.uid];
    if (current == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    _apps[a.uid] = current.copyWith(
      ownerName: a.ownerName,
      shopName: a.shopName,
      address: a.address,
      subCity: a.subCity,
      phone: a.phone,
      description: a.description,
      clearDescription: a.description == null,
    );
    _changes.add(null);
  }

  @override
  Future<void> withdraw(String uid) async {
    await _ensureSeeded();
    if (_apps.remove(uid) != null) _changes.add(null);
  }

  @override
  Future<void> reject(String uid, {required String reviewedBy, required DateTime reviewedAt, required String reason}) async {
    await _ensureSeeded();
    final current = _apps[uid];
    if (current == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    _apps[uid] = current.copyWith(
      status: ShopApplicationStatus.rejected,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt.toUtc(),
      rejectReason: reason,
    );
    _changes.add(null);
  }

  @override
  Future<void> markApproved(String uid, Map<String, dynamic> fields) async {
    await _ensureSeeded();
    final current = _apps[uid];
    if (current == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    _apps[uid] = current.copyWith(
      status: ShopApplicationStatus.approved,
      reviewedBy: fields['reviewedBy'] as String?,
      reviewedAt: DateTime.tryParse((fields['reviewedAt'] as String?) ?? '')?.toUtc(),
      shopId: fields['shopId'] as String?,
    );
    _changes.add(null);
  }
}

/// The demo dataset's `shopApplications`: {uid (a seeded user), ownerName?,
/// shopName, address, subCity, phone, description?, status?,
/// createdHoursAgo?}. The email comes from the user; entries naming an
/// unknown user are skipped. tool/seed/seed.js applies the same rules.
List<ShopApplication> shopApplicationsFromSeedJson(Map<String, dynamic> json, {DateTime? now}) {
  final raw = json['shopApplications'] as List<dynamic>? ?? const [];
  if (raw.isEmpty) return const [];
  final nowUtc = (now ?? DateTime.now()).toUtc();
  final users = {
    for (final u in (json['users'] as List<dynamic>? ?? const []))
      (u as Map)['uid'] as String: Map<String, dynamic>.from(u),
  };
  final out = <ShopApplication>[];
  for (final entry in raw) {
    final m = Map<String, dynamic>.from(entry as Map);
    final user = users[m['uid']];
    final email = (user?['email'] as String?)?.trim();
    if (user == null || email == null || email.isEmpty) continue;
    final hours = (m['createdHoursAgo'] as num?) ?? 0;
    out.add(ShopApplication.fromMap({
      ...m,
      'email': normalizeEmail(email),
      'ownerName': m['ownerName'] ?? user['name'],
      'createdAt': nowUtc.subtract(Duration(minutes: (hours * 60).round())).toIso8601String(),
    }, m['uid'] as String));
  }
  return out;
}

/// Barbershop owners apply to join the platform; the admin approves.
///
///  * Customers: [watchMine], [submit], [update], [withdraw] (one
///    application per account, `shopApplications/{uid}`).
///  * Admin: [watchForAdmin], [approve] (creates the shop through
///    [AppRepository.registerBarbershopByAdmin], owner invite for the
///    applicant's email, application update in the same batch), [reject].
///  * After approval the applicant is upgraded to owner without signing out
///    ([watchMine] calls [AppRepository.applyPendingInviteForCurrentUser]
///    as soon as it sees the approval).
class ShopApplicationsService {
  ShopApplicationsService({AppRepository? repository, ShopApplicationStore? cloud, LocalShopApplicationStore? local})
      : _repo = repository ?? AppRepository.instance,
        _cloudOverride = cloud {
    this.local = local ?? LocalShopApplicationStore(seedFromAssets: kDemoMode);
  }

  static ShopApplicationsService? _instance;
  static ShopApplicationsService get instance => _instance ??= ShopApplicationsService();

  /// Tests: replaces the shared instance (null restores a fresh default).
  @visibleForTesting
  static set instance(ShopApplicationsService? service) => _instance = service;

  final AppRepository _repo;
  final ShopApplicationStore? _cloudOverride;
  ShopApplicationStore? _cloud;

  /// The in-memory store (DEMO_MODE and tests).
  late final LocalShopApplicationStore local;

  ShopApplicationStore get store {
    if (_cloudOverride != null) return _cloudOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestoreShopApplicationStore(FirebaseFirestore.instance);
  }

  DateTime _now() => _repo.nowUtc();

  /// Set by the profile setup screen when a new customer ticked "I own a
  /// barbershop": the customer home opens the form once.
  bool openFormAfterSignUp = false;

  // --- Applicant ---

  /// Whether the signed-in user may apply (customers only).
  bool get canApply => _repo.currentUser?.role == UserRole.customer;

  AppUser _requireCustomer() {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (user.role != UserRole.customer) throw ShopApplicationException(ShopApplicationErrorCode.customersOnly);
    return user;
  }

  /// The signed-in user's application, live. Seeing it approved while the
  /// user is still a customer applies their owner invite.
  Stream<ShopApplication?> watchMine() {
    final uid = _repo.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return store.watch(uid).map((app) {
      if (app != null && app.isApproved) unawaited(syncApprovedInvite(app));
      return app;
    });
  }

  Future<ShopApplication?> loadMine() async {
    final uid = _repo.currentUser?.uid;
    return uid == null ? null : store.get(uid);
  }

  bool _syncing = false;

  /// Applies the owner invite of an approved [application] to the signed-in
  /// customer (no-op otherwise). Returns true when the role changed.
  Future<bool> syncApprovedInvite(ShopApplication? application) async {
    final user = _repo.currentUser;
    if (_syncing || application == null || !application.isApproved) return false;
    if (user == null || user.uid != application.uid || user.role != UserRole.customer) return false;
    _syncing = true;
    try {
      return await _repo.applyPendingInviteForCurrentUser();
    } catch (e) {
      debugPrint('Could not apply the owner invite: $e');
      return false;
    } finally {
      _syncing = false;
    }
  }

  /// Creates the signed-in customer's application, or replaces a rejected
  /// one. Throws [ShopApplicationException] for invalid input, a pending or
  /// approved application, or a non-customer account.
  Future<ShopApplication> submit({
    required String ownerName,
    required String shopName,
    required String address,
    required String subCity,
    required String phone,
    String? description,
  }) async {
    final user = _requireCustomer();
    final email = user.email == null ? null : validEmailOrNull(user.email!);
    if (email == null) throw ShopApplicationException(ShopApplicationErrorCode.emailMissing);
    final input = ShopApplicationInput.validate(
      ownerName: ownerName,
      shopName: shopName,
      address: address,
      subCity: subCity,
      phone: phone,
      description: description,
    );
    final blocker = submitBlocker(await store.get(user.uid));
    if (blocker != null) throw ShopApplicationException(blocker);
    final application = ShopApplication(
      uid: user.uid,
      email: email,
      ownerName: input.ownerName,
      shopName: input.shopName,
      address: input.address,
      subCity: input.subCity,
      phone: input.phone,
      description: input.description,
      status: ShopApplicationStatus.pending,
      createdAt: _now(),
    );
    await store.submit(application);
    return application;
  }

  /// Edits the signed-in customer's pending application.
  Future<ShopApplication> update({
    required String ownerName,
    required String shopName,
    required String address,
    required String subCity,
    required String phone,
    String? description,
  }) async {
    final user = _requireCustomer();
    final input = ShopApplicationInput.validate(
      ownerName: ownerName,
      shopName: shopName,
      address: address,
      subCity: subCity,
      phone: phone,
      description: description,
    );
    final current = await store.get(user.uid);
    if (current == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    if (!current.isPending) throw ShopApplicationException(ShopApplicationErrorCode.notPending);
    final updated = current.copyWith(
      ownerName: input.ownerName,
      shopName: input.shopName,
      address: input.address,
      subCity: input.subCity,
      phone: input.phone,
      description: input.description,
      clearDescription: input.description == null,
    );
    await store.updatePending(updated);
    return updated;
  }

  /// Deletes the signed-in customer's pending application.
  Future<void> withdraw() async {
    final user = _requireCustomer();
    final current = await store.get(user.uid);
    if (current == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    if (!current.isPending) throw ShopApplicationException(ShopApplicationErrorCode.notPending);
    await store.withdraw(user.uid);
  }

  // --- Admin ---

  bool get isAdmin => _repo.currentUser?.role == UserRole.admin;

  AppUser _requireAdmin() {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (user.role != UserRole.admin) throw ShopApplicationException(ShopApplicationErrorCode.adminOnly);
    return user;
  }

  /// Pending applications (oldest first) then recently decided ones.
  Stream<List<ShopApplication>> watchForAdmin({int decidedLimit = 20}) {
    if (!isAdmin) return Stream.value(const []);
    return store.watchForAdmin(decidedLimit: decidedLimit);
  }

  /// Approves a pending application: registers the shop exactly like the
  /// admin's "Register barbershop" form (trial plan, two starter services,
  /// the applicant as lead barber, owner invite for the applicant's email)
  /// and marks the application approved in the same batch. Returns the new
  /// shop id.
  Future<String> approve(String applicantUid) async {
    final admin = _requireAdmin();
    final app = await store.get(applicantUid);
    if (app == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    if (!app.isPending) throw ShopApplicationException(ShopApplicationErrorCode.notPending);
    final target = store;
    late final ShopApplicationApproval approval;
    approval = ShopApplicationApproval(
      applicantUid: app.uid,
      reviewedBy: admin.uid,
      reviewedAt: _now(),
      // With Firestore the repository writes the update in the shop batch.
      applyLocally: target is FirestoreShopApplicationStore
          ? null
          : (shopId) => target.markApproved(app.uid, approval.fieldsFor(shopId)),
    );
    return _repo.registerBarbershopByAdmin(
      shopName: app.shopName,
      ownerName: app.ownerName,
      ownerEmail: app.email,
      address: app.address,
      city: kDefaultCity,
      subCity: app.subCity,
      shopPhone: app.phone,
      description: app.description ?? '',
      imageUrl: '',
      openingHour: 9,
      closingHour: 20,
      workingDays: const [1, 2, 3, 4, 5, 6, 7],
      isVerified: true,
      fromApplication: approval,
    );
  }

  /// Rejects a pending application with a reason the applicant sees.
  Future<void> reject(String applicantUid, String reason) async {
    final admin = _requireAdmin();
    final text = validateRejectReason(reason);
    final app = await store.get(applicantUid);
    if (app == null) throw ShopApplicationException(ShopApplicationErrorCode.notFound);
    if (!app.isPending) throw ShopApplicationException(ShopApplicationErrorCode.notPending);
    await store.reject(applicantUid, reviewedBy: admin.uid, reviewedAt: _now(), reason: text);
  }
}
