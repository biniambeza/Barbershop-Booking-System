import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;

import '../../../core/config/app_config.dart';
import '../../../data/seed_dataset.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/l10n.dart' show AppFormats;
import '../../../models/app_notification.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/subscription_payment.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/notification_service.dart';
import '../../../services/subscription_pricing.dart';
import '../../../services/payment_receivers.dart'; // receivers setup

export '../../../models/subscription_payment.dart';
export '../../../services/subscription_pricing.dart';
export '../../../services/payment_receivers.dart'; // receivers setup

/// Collection of the receipts and the pricing document.
const String kSubscriptionPaymentsCollection = 'subscriptionPayments';
const String kPricingConfigPath = 'platformConfig/subscriptionPricing';

/// Inbox entry types written when an admin decides a receipt.
abstract final class ReceiptNotificationTypes {
  static const approved = 'receiptApproved';
  static const rejected = 'receiptRejected';
}

/// Inbox entry id of a decision: `{paymentDocId}_receipt`.
String receiptNotificationId(String paymentId) => '${paymentId}_receipt';

/// An admin decision: the payment update, plus (approve only) the shop's
/// new subscription fields, plus the owner's inbox entry. Firestore writes
/// all of it in ONE batch.
class ReceiptDecision {
  const ReceiptDecision({
    required this.payment,
    required this.paymentFields,
    this.shopFields,
    this.notification,
  });

  final SubscriptionPayment payment;

  /// approve: {status 'verified', verifiedBy, verifiedAmount, durationDays,
  /// decidedAt}; reject: {status 'rejected', verifiedBy, decisionReason,
  /// decidedAt}.
  final Map<String, dynamic> paymentFields;

  /// approve only: {subscriptionStatus 'active', subscriptionEndsAt,
  /// subscriptionReceiptId}.
  final Map<String, dynamic>? shopFields;
  final AppNotification? notification;
}

/// Storage of receipts and the pricing config: [FirestoreReceiptStore] in
/// production, [LocalReceiptStore] in DEMO_MODE builds and tests.
abstract class ReceiptStore {
  Stream<SubscriptionPricing> watchPricing();
  Future<SubscriptionPricing> getPricing();
  Future<void> savePricing(SubscriptionPricing pricing);

  /// Owner: their own receipts, newest first, live.
  Stream<List<SubscriptionPayment>> watchOwner(String ownerId);

  /// Admin: every open receipt plus the [decidedLimit] latest decided ones.
  Stream<List<SubscriptionPayment>> watchForAdmin({int decidedLimit = 20});

  Future<SubscriptionPayment?> get(String id);

  /// Creates the document; throws [ReceiptException] duplicate when a
  /// receipt with the same id already exists (anyone's).
  Future<void> create(SubscriptionPayment payment);

  /// Applies [decision]. Firestore: one batch (payment update, shop update
  /// on approve, owner inbox entry). Local: the payment only (the service
  /// updates the shop and the inbox).
  Future<void> decide(ReceiptDecision decision);
}

/// Firestore access:
///
///  * pricing:  get / snapshots of `platformConfig/subscriptionPricing`
///              (owner, admin); set (admin) with [SubscriptionPricing.toMap].
///  * owner:    query `subscriptionPayments` where ownerId == uid (single
///              field, no composite index), snapshots; get of
///              `subscriptionPayments/{id}` before creating (the rules let an
///              owner get a doc that does not exist or is their own; a
///              permission error means someone else's receipt = duplicate);
///              set (create) with [SubscriptionPayment.toCreateMap].
///  * admin:    query where status in ['pending','needs_review'];
///              query orderBy decidedAt desc limit n; get; batch:
///              update payment, update `barbershops/{shopId}` (approve),
///              set `users/{ownerId}/notifications/{id}_receipt`.
class FirestoreReceiptStore implements ReceiptStore {
  FirestoreReceiptStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(kSubscriptionPaymentsCollection);
  DocumentReference<Map<String, dynamic>> get _pricing => _db.doc(kPricingConfigPath);

  static List<SubscriptionPayment> _read(QuerySnapshot<Map<String, dynamic>> qs) =>
      [for (final d in qs.docs) SubscriptionPayment.fromMap(d.data(), d.id)];

  @override
  Stream<SubscriptionPricing> watchPricing() => _pricing.snapshots().map((s) => SubscriptionPricing.fromMap(s.data()));

  @override
  Future<SubscriptionPricing> getPricing() async => SubscriptionPricing.fromMap((await _pricing.get()).data());

  @override
  Future<void> savePricing(SubscriptionPricing pricing) => _pricing.set(pricing.toMap());

  @override
  Stream<List<SubscriptionPayment>> watchOwner(String ownerId) => _col
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((qs) => _read(qs)..sort(SubscriptionPayment.newestFirst));

  @override
  Stream<List<SubscriptionPayment>> watchForAdmin({int decidedLimit = 20}) {
    late StreamController<List<SubscriptionPayment>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? openSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? decidedSub;
    List<SubscriptionPayment>? open;
    List<SubscriptionPayment>? decided;
    void emit() {
      if (open == null || decided == null || controller.isClosed) return;
      final byId = <String, SubscriptionPayment>{
        for (final p in decided!) p.id: p,
        for (final p in open!) p.id: p,
      };
      controller.add(byId.values.toList()..sort(SubscriptionPayment.adminOrder));
    }

    controller = StreamController<List<SubscriptionPayment>>(
      onListen: () {
        openSub = _col
            .where('status', whereIn: [ReceiptStatus.pending.value, ReceiptStatus.needsReview.value])
            .snapshots()
            .listen((qs) {
          open = _read(qs);
          emit();
        }, onError: controller.addError);
        decidedSub = _col.orderBy('decidedAt', descending: true).limit(decidedLimit).snapshots().listen((qs) {
          decided = _read(qs).where((p) => !p.status.isOpen).toList();
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await openSub?.cancel();
        await decidedSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<SubscriptionPayment?> get(String id) async {
    final snap = await _col.doc(id).get();
    return snap.exists ? SubscriptionPayment.fromMap(snap.data()!, snap.id) : null;
  }

  @override
  Future<void> create(SubscriptionPayment payment) async {
    final ref = _col.doc(payment.id);
    try {
      final existing = await ref.get();
      if (existing.exists) throw ReceiptException(ReceiptErrorCode.duplicate);
    } on FirebaseException catch (e) {
      // Another owner's receipt: the rules hide it, so it exists.
      if (e.code == 'permission-denied') throw ReceiptException(ReceiptErrorCode.duplicate);
      rethrow;
    }
    try {
      await ref.set(payment.toCreateMap());
    } on FirebaseException catch (e) {
      // Created by someone else between the get and the set: the set became
      // an update, which owners may not make.
      if (e.code == 'permission-denied') {
        final again = await ref.get().then((s) => s.exists, onError: (_) => true);
        if (again) throw ReceiptException(ReceiptErrorCode.duplicate);
      }
      rethrow;
    }
  }

  @override
  Future<void> decide(ReceiptDecision d) async {
    final batch = _db.batch();
    batch.update(_col.doc(d.payment.id), d.paymentFields);
    if (d.shopFields != null) {
      batch.update(_db.collection('barbershops').doc(d.payment.shopId), d.shopFields!);
    }
    final n = d.notification;
    if (n != null && d.payment.ownerId.isNotEmpty) {
      batch.set(
        _db.collection('users').doc(d.payment.ownerId).collection('notifications').doc(n.id),
        {...n.toMap(), 'shopId': d.payment.shopId, 'paymentId': d.payment.id},
      );
    }
    await batch.commit();
  }
}

/// In-memory receipts for DEMO_MODE builds and tests. In DEMO_MODE it
/// loads the dataset's `subscriptionPricing` and `subscriptionPayments`.
class LocalReceiptStore implements ReceiptStore {
  LocalReceiptStore({this.seedFromAssets = false});

  final bool seedFromAssets;

  final Map<String, SubscriptionPayment> _byId = {};
  SubscriptionPricing _pricing = SubscriptionPricing.defaults;
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  bool _seeded = false;
  Future<void>? _seeding;

  /// Replaces everything with the dataset's receipts and pricing.
  void loadSeedJson(Map<String, dynamic> json, {DateTime? now}) {
    _pricing = subscriptionPricingFromSeedJson(json);
    _byId
      ..clear()
      ..addEntries(subscriptionPaymentsFromSeedJson(json, now: now).map((p) => MapEntry(p.id, p)));
    _seeded = true;
    _changes.add(null);
  }

  /// Empties the store and restores the default pricing (tests).
  void clear() {
    _byId.clear();
    _pricing = SubscriptionPricing.defaults;
    _seeded = true;
    _changes.add(null);
  }

  /// Every receipt, newest first (tests).
  List<SubscriptionPayment> get all => _byId.values.toList()..sort(SubscriptionPayment.newestFirst);

  Future<void> _ensureSeeded() {
    if (_seeded || !seedFromAssets) return Future.value();
    return _seeding ??= () async {
      try {
        final text = await rootBundle.loadString(kSeedAssetPath);
        if (!_seeded) loadSeedJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not load the demo subscription receipts: $e');
        _seeded = true;
      }
    }();
  }

  Stream<T> _watch<T>(T Function() read) {
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
  Stream<SubscriptionPricing> watchPricing() => _watch(() => _pricing);

  @override
  Future<SubscriptionPricing> getPricing() async {
    await _ensureSeeded();
    return _pricing;
  }

  @override
  Future<void> savePricing(SubscriptionPricing pricing) async {
    await _ensureSeeded();
    _pricing = pricing;
    _changes.add(null);
  }

  @override
  Stream<List<SubscriptionPayment>> watchOwner(String ownerId) =>
      _watch(() => all.where((p) => p.ownerId == ownerId).toList());

  @override
  Stream<List<SubscriptionPayment>> watchForAdmin({int decidedLimit = 20}) => _watch(() {
        final open = _byId.values.where((p) => p.status.isOpen);
        final decided =
            (_byId.values.where((p) => !p.status.isOpen).toList()..sort(SubscriptionPayment.adminOrder)).take(decidedLimit);
        return [...open, ...decided]..sort(SubscriptionPayment.adminOrder);
      });

  @override
  Future<SubscriptionPayment?> get(String id) async {
    await _ensureSeeded();
    return _byId[id];
  }

  @override
  Future<void> create(SubscriptionPayment payment) async {
    await _ensureSeeded();
    if (_byId.containsKey(payment.id)) throw ReceiptException(ReceiptErrorCode.duplicate);
    _byId[payment.id] = payment;
    _changes.add(null);
  }

  @override
  Future<void> decide(ReceiptDecision d) async {
    await _ensureSeeded();
    final current = _byId[d.payment.id];
    if (current == null) throw ReceiptException(ReceiptErrorCode.notFound);
    if (!current.status.isOpen) throw ReceiptException(ReceiptErrorCode.notOpen);
    final f = d.paymentFields;
    _byId[current.id] = current.copyWith(
      status: ReceiptStatus.fromValue(f['status']),
      durationDays: (f['durationDays'] as num?)?.toInt(),
      verifiedAmount: (f['verifiedAmount'] as num?)?.toDouble(),
      verifiedBy: f['verifiedBy'] as String?,
      decisionReason: f['decisionReason'] as String?,
      decidedAt: DateTime.tryParse((f['decidedAt'] as String?) ?? '')?.toUtc(),
    );
    _changes.add(null);
  }
}

/// The dataset's `subscriptionPricing` object (defaults when absent).
SubscriptionPricing subscriptionPricingFromSeedJson(Map<String, dynamic> json) {
  final raw = json['subscriptionPricing'];
  return raw is Map ? SubscriptionPricing.fromMap(Map<String, dynamic>.from(raw)) : SubscriptionPricing.defaults;
}

/// The dataset's `subscriptionPayments`. Each entry: `{shopId, method,
/// transactionId, amount, status, durationDays?, verifiedAmount?,
/// verifiedBy?, decisionReason?, payerAccountSuffix?, createdHoursAgo,
/// decidedHoursAgo?}`; ownerId is the shop's ownerId and the id is
/// `{method}_{normalized transactionId}`. Entries naming an unknown shop
/// are skipped. tool/seed/seed.js applies the same rules.
List<SubscriptionPayment> subscriptionPaymentsFromSeedJson(Map<String, dynamic> json, {DateTime? now}) {
  final raw = json['subscriptionPayments'] as List<dynamic>? ?? const [];
  if (raw.isEmpty) return const [];
  final nowUtc = (now ?? DateTime.now()).toUtc();
  final owners = {
    for (final s in (json['shops'] as List<dynamic>? ?? const []))
      (s as Map)['id'] as String: (s['ownerId'] as String?) ?? '',
  };
  DateTime ago(Object? hours) => nowUtc.subtract(Duration(minutes: (((hours as num?) ?? 0) * 60).round()));
  final out = <SubscriptionPayment>[];
  for (final entry in raw) {
    final m = Map<String, dynamic>.from(entry as Map);
    final shopId = m['shopId'];
    if (shopId is! String || !owners.containsKey(shopId) || m['transactionId'] is! String) continue;
    final method = ReceiptMethod.fromName(m['method']);
    final tx = normalizeTransactionId(m['transactionId'] as String);
    final status = ReceiptStatus.fromValue(m['status']);
    out.add(SubscriptionPayment(
      id: receiptDocId(method, tx),
      shopId: shopId,
      ownerId: owners[shopId]!,
      method: method,
      transactionId: tx,
      amount: (m['amount'] as num).toDouble(),
      payerAccountSuffix: m['payerAccountSuffix'] as String?,
      status: status,
      durationDays: (m['durationDays'] as num?)?.toInt() ?? 0,
      verifiedAmount: (m['verifiedAmount'] as num?)?.toDouble(),
      verifiedBy: m['verifiedBy'] as String?,
      decisionReason: m['decisionReason'] as String?,
      createdAt: ago(m['createdHoursAgo']),
      decidedAt: status.isOpen ? null : ago(m['decidedHoursAgo'] ?? m['createdHoursAgo']),
    ));
  }
  return out;
}

/// Result of an admin approval.
class ReceiptApproval {
  const ReceiptApproval({required this.durationDays, required this.newEndsAt});
  final int durationDays;
  final DateTime newEndsAt;
}

/// Subscription payment by bank / mobile-money transfer with a receipt.
///
///  * Owners: [watchPricing], [submit] (creates a 'pending' receipt; one
///    per transaction number platform-wide), [watchMine].
///  * Verification: automatic with the payments Cloud Function on the
///    Blaze plan; otherwise an admin uses [watchForAdmin], [approve]
///    (receipt verified + shop subscription extended + owner notified, one
///    batch) and [reject].
///  * Admins: [savePricing] edits the tiers and where to pay.
class SubscriptionReceiptsService {
  SubscriptionReceiptsService({
    AppRepository? repository,
    ReceiptStore? cloud,
    LocalReceiptStore? local,
    void Function(String uid, AppNotification notification)? localInbox,
  })  : _repo = repository ?? AppRepository.instance,
        _cloudOverride = cloud,
        _localInbox = localInbox {
    this.local = local ?? LocalReceiptStore(seedFromAssets: kDemoMode);
  }

  static SubscriptionReceiptsService? _instance;
  static SubscriptionReceiptsService get instance => _instance ??= SubscriptionReceiptsService();

  /// Tests: replaces the shared instance (null restores a fresh default).
  @visibleForTesting
  static set instance(SubscriptionReceiptsService? service) => _instance = service;

  final AppRepository _repo;
  final ReceiptStore? _cloudOverride;
  final void Function(String uid, AppNotification notification)? _localInbox;
  ReceiptStore? _cloud;

  /// The in-memory store (DEMO_MODE and tests).
  late final LocalReceiptStore local;

  ReceiptStore get store {
    if (_cloudOverride != null) return _cloudOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestoreReceiptStore(FirebaseFirestore.instance);
  }

  DateTime _now() => _repo.nowUtc();

  // --- pricing ---

  Stream<SubscriptionPricing> watchPricing() => store.watchPricing();

  Future<SubscriptionPricing> loadPricing() => store.getPricing();

  /// Admin: validates and saves the tiers and receivers.
  Future<SubscriptionPricing> savePricing(SubscriptionPricing pricing) async {
    final admin = _requireAdmin();
    if (validatePricing(pricing) != null) throw ReceiptException(ReceiptErrorCode.invalidPricing);
    // --- receivers setup: valid telebirr / CBE accounts or '' (not offered);
    // a leftover 'XXXX' placeholder is saved as ''. ---
    final withReceivers = normalizePricingReceivers(pricing);
    if (withReceivers == null) throw ReceiptException(ReceiptErrorCode.invalidPricing);
    // --- end receivers setup ---
    final saved = withReceivers.copyWith(tiers: sortTiers(pricing.tiers), updatedAt: _now(), updatedBy: admin.uid);
    await store.savePricing(saved);
    return saved;
  }

  // --- owner ---

  AppUser _requireOwnerOf(String shopId) {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (user.role != UserRole.barbershopOwner || user.shopId != shopId) {
      throw ReceiptException(ReceiptErrorCode.ownerOnly);
    }
    return user;
  }

  /// The signed-in owner's receipts for [shopId], newest first.
  Stream<List<SubscriptionPayment>> watchMine(String shopId) {
    final uid = _repo.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return store.watchOwner(uid).map((list) => list.where((p) => p.shopId == shopId).toList());
  }

  /// Creates a 'pending' receipt for the owner's shop. [receiptImageBase64]
  /// is a compressed JPEG (see receipt_image.dart). Throws
  /// [ReceiptException] for bad input, an amount below the cheapest tier, or
  /// a transaction number that was already submitted (by anyone).
  Future<SubscriptionPayment> submit({
    required String shopId,
    required ReceiptMethod method,
    required String transactionId,
    required Object amount,
    String? receiptImageBase64,
    String? payerAccountSuffix,
  }) async {
    final user = _requireOwnerOf(shopId);
    if (_repo.getShopById(shopId) == null) throw ReceiptException(ReceiptErrorCode.shopNotFound);
    final tx = normalizeTransactionId(transactionId);
    if (!isValidTransactionId(method, tx)) throw ReceiptException(ReceiptErrorCode.invalidTransactionId);
    final value = normalizeReceiptAmount(amount);
    if (value == null) throw ReceiptException(ReceiptErrorCode.invalidAmount);
    final pricing = await store.getPricing();
    if (pricing.durationDaysFor(value) == null) throw ReceiptException(ReceiptErrorCode.amountTooLow);
    final image = receiptImageBase64?.trim();
    if (image != null && image.length > kMaxReceiptImageChars) throw ReceiptException(ReceiptErrorCode.imageTooLarge);
    final payment = SubscriptionPayment(
      id: receiptDocId(method, tx),
      shopId: shopId,
      ownerId: user.uid,
      method: method,
      transactionId: tx,
      amount: value,
      receiptImage: image == null || image.isEmpty ? null : image,
      payerAccountSuffix: method == ReceiptMethod.cbe ? normalizePayerAccountSuffix(payerAccountSuffix) : null,
      createdAt: _now(),
    );
    await store.create(payment);
    return payment;
  }

  // --- admin ---

  bool get isAdmin => _repo.currentUser?.role == UserRole.admin;

  AppUser _requireAdmin() {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (user.role != UserRole.admin) throw ReceiptException(ReceiptErrorCode.adminOnly);
    return user;
  }

  Stream<List<SubscriptionPayment>> watchForAdmin({int decidedLimit = 20}) {
    if (!isAdmin) return Stream.value(const []);
    return store.watchForAdmin(decidedLimit: decidedLimit);
  }

  Future<SubscriptionPayment> _requireOpen(String paymentId) async {
    final payment = await store.get(paymentId);
    if (payment == null) throw ReceiptException(ReceiptErrorCode.notFound);
    if (!payment.status.isOpen) throw ReceiptException(ReceiptErrorCode.notOpen);
    return payment;
  }

  /// What approving would grant for [verifiedAmount] (null: too low).
  int? previewDuration(SubscriptionPricing pricing, double verifiedAmount) => pricing.durationDaysFor(verifiedAmount);

  /// Admin: the receipt checked out. Marks it verified with the duration
  /// for [verifiedAmount] (defaults to the claimed amount), extends the
  /// shop's subscription from max(now, current end) by that many days,
  /// sets it 'active' (a subscription-suspended shop is reactivated; an
  /// admin suspension is separate and stays), and notifies the owner - all
  /// in one batch.
  Future<ReceiptApproval> approve(String paymentId, {double? verifiedAmount}) async {
    final admin = _requireAdmin();
    final payment = await _requireOpen(paymentId);
    final amount = normalizeReceiptAmount(verifiedAmount ?? payment.amount);
    if (amount == null) throw ReceiptException(ReceiptErrorCode.invalidAmount);
    final pricing = await store.getPricing();
    final days = pricing.durationDaysFor(amount);
    if (days == null) throw ReceiptException(ReceiptErrorCode.amountTooLow);
    final shop = _repo.getShopById(payment.shopId);
    if (shop == null) throw ReceiptException(ReceiptErrorCode.shopNotFound);
    final now = _now();
    final newEnd = extendSubscriptionByDays(shop.subscriptionEndsAt, now, days);
    final notification = _notification(
      payment,
      ReceiptNotificationTypes.approved,
      now,
      (l, fmt) => (l.rcptNotifApprovedTitle, l.rcptNotifApprovedBody(days, fmt.addisDateMedium(newEnd))),
    );
    final decision = ReceiptDecision(
      payment: payment,
      paymentFields: {
        'status': ReceiptStatus.verified.value,
        'verifiedBy': admin.uid,
        'verifiedAmount': amount,
        'durationDays': days,
        'decidedAt': now.toIso8601String(),
      },
      shopFields: {
        'subscriptionStatus': SubscriptionStatus.active.value,
        'subscriptionEndsAt': newEnd.toIso8601String(),
        'subscriptionReceiptId': payment.id,
      },
      notification: notification,
    );
    await store.decide(decision);
    if (store is! FirestoreReceiptStore) {
      // Local mode: the shop and the inbox are updated here.
      await _repo.updateShopSubscription(shop.id,
          plan: shop.subscriptionPlan, status: SubscriptionStatus.active, endsAt: newEnd);
      _deliverLocally(payment.ownerId, notification);
    }
    return ReceiptApproval(durationDays: days, newEndsAt: newEnd);
  }

  /// Admin: the receipt is not valid. [reason] (1..300 characters) is shown
  /// to the owner.
  Future<void> reject(String paymentId, String reason) async {
    final admin = _requireAdmin();
    final text = reason.trim();
    if (text.isEmpty || text.length > kMaxReceiptReasonLength) throw ReceiptException(ReceiptErrorCode.reasonRequired);
    final payment = await _requireOpen(paymentId);
    final now = _now();
    final notification = _notification(
      payment,
      ReceiptNotificationTypes.rejected,
      now,
      (l, _) => (l.rcptNotifRejectedTitle, l.rcptNotifRejectedBody(payment.transactionId, text)),
    );
    await store.decide(ReceiptDecision(
      payment: payment,
      paymentFields: {
        'status': ReceiptStatus.rejected.value,
        'verifiedBy': admin.uid,
        'decisionReason': text,
        'decidedAt': now.toIso8601String(),
      },
      notification: notification,
    ));
    if (store is! FirestoreReceiptStore) _deliverLocally(payment.ownerId, notification);
  }

  /// The owner's inbox entry, in the owner's language.
  AppNotification _notification(
    SubscriptionPayment payment,
    String type,
    DateTime now,
    (String, String) Function(AppLocalizations l, AppFormats fmt) text,
  ) {
    final language = _repo.getAllUsers().where((u) => u.uid == payment.ownerId).firstOrNull?.language;
    final l = lookupAppLocalizations(Locale(language == 'am' ? 'am' : 'en'));
    final (title, body) = text(l, AppFormats(l.localeName));
    return AppNotification(
      id: receiptNotificationId(payment.id),
      title: title,
      body: body,
      type: type,
      createdAt: now,
    );
  }

  void _deliverLocally(String ownerId, AppNotification n) {
    if (ownerId.isEmpty) return;
    final deliver = _localInbox ?? NotificationService.instance.local.addDirect;
    deliver(ownerId, n);
  }
}
