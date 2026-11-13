import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/utils/phone_utils.dart';
import '../data/seed_dataset.dart' show kSeedAssetPath;
import '../models/queue_entry.dart';
import '../models/user_model.dart';
import 'app_repository.dart';
import 'queue_wait.dart';

export '../models/queue_entry.dart';
export 'queue_wait.dart';

/// Queue-specific failures. Screens show them with `queueErrorText`
/// (lib/features/queue/queue_l10n.dart); other errors thrown here are
/// [AppException]s (sign-in, phone) or Firestore errors.
enum QueueErrorCode {
  /// Only the shop's owner and barbers manage its queue.
  notStaff,

  /// Only signed-in customers join remotely.
  customersOnly,

  /// Name missing or longer than [kQueueNameMaxLength].
  nameRequired,

  /// args: [barber name]. The barber is already serving someone.
  barberBusy,

  /// The entry is no longer waiting (served, finished or gone).
  notWaiting,

  /// The entry is not being served.
  notServing,
}

class QueueException implements Exception {
  QueueException(this.code, [this.args = const []]);

  final QueueErrorCode code;
  final List<Object?> args;

  @override
  String toString() => 'QueueException(${code.name}${args.isEmpty ? '' : ', $args'})';
}

/// Storage of the walk-in queue: [FirestoreQueueStore] in production,
/// [LocalQueueStore] in DEMO_MODE builds and tests.
abstract class QueueStore {
  /// Entries with status waiting or serving, in arrival order (staff).
  Stream<List<QueueEntry>> watchActive(String shopId);

  /// The public `queueSummary/current` ([QueueSummary.empty] when missing).
  Stream<QueueSummary> watchSummary(String shopId);

  /// The newest entry [uid] added to the shop (a customer's own entry).
  Stream<QueueEntry?> watchLatestOwn(String shopId, String uid);

  Future<List<QueueEntry>> fetchActive(String shopId);
  Future<QueueEntry?> fetchLatestOwn(String shopId, String uid);

  String newId(String shopId);
  Future<void> add(QueueEntry entry);

  /// Updates fields of an existing entry (status changes).
  Future<void> update(QueueEntry entry, Map<String, dynamic> fields);
}

/// Firestore paths (all reads are snapshot listeners or one-off gets):
///
///  * staff:    `barbershops/{s}/queue` where status in [waiting, serving]
///              orderBy createdAt, limit 200 (index: status ASC, createdAt ASC)
///  * customer: `barbershops/{s}/queue` where addedBy == uid orderBy
///              createdAt desc limit 1 (index: addedBy ASC, createdAt DESC)
///  * anyone:   `barbershops/{s}/queueSummary/current`
class FirestoreQueueStore implements QueueStore {
  FirestoreQueueStore(this._db);

  final FirebaseFirestore _db;

  static const int activeLimit = 200;

  CollectionReference<Map<String, dynamic>> _queue(String shopId) =>
      _db.collection('barbershops').doc(shopId).collection('queue');

  Query<Map<String, dynamic>> _activeQuery(String shopId) => _queue(shopId)
      .where('status', whereIn: [QueueStatus.waiting.name, QueueStatus.serving.name])
      .orderBy('createdAt')
      .limit(activeLimit);

  Query<Map<String, dynamic>> _ownQuery(String shopId, String uid) =>
      _queue(shopId).where('addedBy', isEqualTo: uid).orderBy('createdAt', descending: true).limit(1);

  List<QueueEntry> _entries(String shopId, QuerySnapshot<Map<String, dynamic>> snap) =>
      queueArrivalOrder(snap.docs.map((d) => QueueEntry.fromMap(d.data(), d.id, shopId: shopId)));

  QueueEntry? _first(String shopId, QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.isEmpty ? null : QueueEntry.fromMap(snap.docs.first.data(), snap.docs.first.id, shopId: shopId);

  @override
  Stream<List<QueueEntry>> watchActive(String shopId) =>
      _activeQuery(shopId).snapshots().map((s) => _entries(shopId, s));

  @override
  Stream<QueueSummary> watchSummary(String shopId) => _db
      .collection('barbershops')
      .doc(shopId)
      .collection('queueSummary')
      .doc('current')
      .snapshots()
      .map((s) => s.exists ? QueueSummary.fromMap(s.data()!) : QueueSummary.empty);

  @override
  Stream<QueueEntry?> watchLatestOwn(String shopId, String uid) =>
      _ownQuery(shopId, uid).snapshots().map((s) => _first(shopId, s));

  @override
  Future<List<QueueEntry>> fetchActive(String shopId) async => _entries(shopId, await _activeQuery(shopId).get());

  @override
  Future<QueueEntry?> fetchLatestOwn(String shopId, String uid) async =>
      _first(shopId, await _ownQuery(shopId, uid).get());

  @override
  String newId(String shopId) => _queue(shopId).doc().id;

  @override
  Future<void> add(QueueEntry entry) => _queue(entry.shopId).doc(entry.id).set(entry.toMap());

  @override
  Future<void> update(QueueEntry entry, Map<String, dynamic> fields) =>
      _queue(entry.shopId).doc(entry.id).update(fields);
}

/// In-memory queue for DEMO_MODE builds and tests. It also plays the part of
/// the queue Cloud Function: after every change it recomputes the shop's
/// [QueueSummary] with [estimateQueueWait].
class LocalQueueStore implements QueueStore {
  LocalQueueStore({required this.summarize, this.seedFromAssets = false});

  /// Summary of a shop's entries (service durations and barbers come from
  /// the repository).
  final QueueSummary Function(String shopId, Iterable<QueueEntry> entries) summarize;

  /// DEMO_MODE: load the queue of the bundled dataset on first use.
  final bool seedFromAssets;

  final Map<String, Map<String, QueueEntry>> _byShop = {};
  final StreamController<String> _changes = StreamController<String>.broadcast(sync: true);
  final Uuid _uuid = const Uuid();
  bool _seeded = false;
  Future<void>? _seeding;

  /// Replaces all entries with the `queue` list of the demo dataset JSON.
  /// Relative times (`createdMinutesAgo`, `servingStartedMinutesAgo`) are
  /// resolved against [now]. tool/seed/seed.js applies the same rules.
  void loadSeedJson(Map<String, dynamic> json, {DateTime? now}) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    DateTime? ago(Object? minutes) => minutes is num ? nowUtc.subtract(Duration(minutes: minutes.toInt())) : null;
    _byShop.clear();
    for (final raw in (json['queue'] as List<dynamic>? ?? const [])) {
      final m = Map<String, dynamic>.from(raw as Map);
      final shopId = m['shopId'] as String;
      final entry = QueueEntry.fromMap({
        ...m,
        'createdAt': ago(m['createdMinutesAgo'])?.toIso8601String(),
        'servingStartedAt': ago(m['servingStartedMinutesAgo'])?.toIso8601String(),
      }, m['id'] as String, shopId: shopId);
      (_byShop[shopId] ??= {})[entry.id] = entry;
    }
    _seeded = true;
    for (final shopId in _byShop.keys.toList()) {
      _changes.add(shopId);
    }
  }

  /// Empties the queue (tests).
  void clear() {
    final shops = _byShop.keys.toList();
    _byShop.clear();
    _seeded = true;
    shops.forEach(_changes.add);
  }

  Future<void> _ensureSeeded() {
    if (_seeded || !seedFromAssets) return Future.value();
    return _seeding ??= () async {
      try {
        final text = await rootBundle.loadString(kSeedAssetPath);
        if (!_seeded) loadSeedJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not load the demo queue: $e');
        _seeded = true;
      }
    }();
  }

  Iterable<QueueEntry> _all(String shopId) => _byShop[shopId]?.values ?? const [];

  List<QueueEntry> _active(String shopId) => queueArrivalOrder(_all(shopId).where((e) => e.isActive));

  QueueEntry? _latestOwn(String shopId, String uid) {
    QueueEntry? latest;
    for (final e in _all(shopId)) {
      if (e.addedBy != uid) continue;
      if (latest == null || e.createdAt.isAfter(latest.createdAt)) latest = e;
    }
    return latest;
  }

  /// Emits [read] now and after every change of [shopId].
  Stream<T> _watch<T>(String shopId, T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<String>? sub;
    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.where((id) => id == shopId).listen((_) => controller.add(read()));
        if (_seeded || !seedFromAssets) {
          controller.add(read());
        } else {
          _ensureSeeded().then((_) {
            if (!controller.isClosed) controller.add(read());
          });
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<List<QueueEntry>> watchActive(String shopId) => _watch(shopId, () => _active(shopId));

  @override
  Stream<QueueSummary> watchSummary(String shopId) => _watch(shopId, () => summarize(shopId, _all(shopId)));

  @override
  Stream<QueueEntry?> watchLatestOwn(String shopId, String uid) => _watch(shopId, () => _latestOwn(shopId, uid));

  @override
  Future<List<QueueEntry>> fetchActive(String shopId) async {
    await _ensureSeeded();
    return _active(shopId);
  }

  @override
  Future<QueueEntry?> fetchLatestOwn(String shopId, String uid) async {
    await _ensureSeeded();
    return _latestOwn(shopId, uid);
  }

  /// Current summary of [shopId] (tests).
  QueueSummary summaryOf(String shopId) => summarize(shopId, _all(shopId));

  @override
  String newId(String shopId) => _uuid.v4();

  @override
  Future<void> add(QueueEntry entry) async {
    await _ensureSeeded();
    (_byShop[entry.shopId] ??= {})[entry.id] = entry;
    _changes.add(entry.shopId);
  }

  @override
  Future<void> update(QueueEntry entry, Map<String, dynamic> fields) async {
    await _ensureSeeded();
    final current = _byShop[entry.shopId]?[entry.id];
    if (current == null) throw QueueException(QueueErrorCode.notWaiting);
    _byShop[entry.shopId]![entry.id] =
        QueueEntry.fromMap({...current.toMap(), ...fields}, entry.id, shopId: entry.shopId);
    _changes.add(entry.shopId);
  }
}

/// The walk-in queue of a barbershop.
///
///  * Owner and barbers of the shop ([watchActiveQueue]) see every waiting
///    and serving entry, add walk-ins, call the next person, start serving,
///    finish and mark people as left.
///  * Customers see the public [QueueSummary] ([watchSummary]); signed-in
///    customers join remotely ([joinQueue], one active entry per shop),
///    follow their own entry ([watchMyEntry]) and leave ([leaveQueue]).
///
/// Listeners are opened per shop by the screens that need them and closed
/// with them. Firestore is used once [AppRepository.attachFirebase] ran;
/// otherwise [local].
class QueueService {
  QueueService({AppRepository? repository, QueueStore? cloud, LocalQueueStore? local})
      : _repo = repository ?? AppRepository.instance,
        _cloudOverride = cloud {
    this.local = local ?? LocalQueueStore(summarize: summarize, seedFromAssets: kDemoMode);
  }

  static QueueService? _instance;
  static QueueService get instance => _instance ??= QueueService();

  final AppRepository _repo;
  final QueueStore? _cloudOverride;
  QueueStore? _cloud;

  /// The in-memory store (DEMO_MODE and tests).
  late final LocalQueueStore local;

  QueueStore get store {
    if (_cloudOverride != null) return _cloudOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestoreQueueStore(FirebaseFirestore.instance);
  }

  // --- Reads ---

  Stream<List<QueueEntry>> watchActiveQueue(String shopId) => store.watchActive(shopId);

  Stream<QueueSummary> watchSummary(String shopId) => store.watchSummary(shopId);

  /// The signed-in user's latest entry at [shopId] while it is active, else
  /// null.
  Stream<QueueEntry?> watchMyEntry(String shopId) {
    final uid = _repo.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return store.watchLatestOwn(shopId, uid).map((e) => e != null && e.isActive ? e : null);
  }

  /// Service minutes by service id for [shopId].
  Map<String, int> serviceDurations(String shopId) => {
        for (final s in _repo.getServicesForShop(shopId)) s.id: s.durationMinutes,
      };

  /// Barbers of [shopId] who are taking customers.
  int availableBarberCount(String shopId) => _repo.getBarbersForShop(shopId).where((b) => b.isAvailable).length;

  /// Positions and waits of [entries] (staff screen; same formula as the
  /// Cloud Function).
  QueueSummary summarize(String shopId, Iterable<QueueEntry> entries) => estimateQueueWait(
        entries: entries,
        serviceDurations: serviceDurations(shopId),
        availableBarbers: availableBarberCount(shopId),
        now: DateTime.now(),
      );

  /// Barber id -> the entry they are serving.
  static Map<String, QueueEntry> servingByBarber(Iterable<QueueEntry> entries) => {
        for (final e in entries)
          if (e.status == QueueStatus.serving && e.barberId != null) e.barberId!: e,
      };

  /// Whether the signed-in user is the owner or a barber of [shopId].
  bool isStaffOf(String shopId) {
    final user = _repo.currentUser;
    if (user == null || user.shopId != shopId) return false;
    return user.role == UserRole.barbershopOwner || user.role == UserRole.barber;
  }

  // --- Staff actions ---

  AppUser _requireStaff(String shopId) {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (!isStaffOf(shopId)) throw QueueException(QueueErrorCode.notStaff);
    return user;
  }

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > kQueueNameMaxLength) {
      throw QueueException(QueueErrorCode.nameRequired, [kQueueNameMaxLength]);
    }
    return trimmed;
  }

  /// Adds a walk-in at the end of the queue. [phone] is optional; when given
  /// it must be an Ethiopian mobile number (stored as E.164).
  Future<QueueEntry> addWalkIn({
    required String shopId,
    required String name,
    String? phone,
    String? serviceId,
    String? barberId,
  }) async {
    final user = _requireStaff(shopId);
    final validName = _validName(name);
    String? e164;
    if (phone != null && phone.trim().isNotEmpty) {
      e164 = normalizeEthiopianPhone(phone);
      if (e164 == null) throw AppFormatException(AppErrorCode.invalidPhone);
    }
    final entry = QueueEntry(
      id: store.newId(shopId),
      shopId: shopId,
      name: validName,
      phone: e164,
      serviceId: serviceId,
      barberId: barberId,
      status: QueueStatus.waiting,
      createdAt: DateTime.now().toUtc(),
      addedBy: user.uid,
      source: QueueSource.walkIn,
    );
    await store.add(entry);
    return entry;
  }

  /// Starts serving [entry] with [barberId]. The entry must still be
  /// waiting and the barber must not be serving someone else.
  Future<QueueEntry> startServing(QueueEntry entry, String barberId) async {
    _requireStaff(entry.shopId);
    final active = await store.fetchActive(entry.shopId);
    final current = active.where((e) => e.id == entry.id).firstOrNull;
    if (current == null || current.status != QueueStatus.waiting) throw QueueException(QueueErrorCode.notWaiting);
    if (servingByBarber(active).containsKey(barberId)) {
      throw QueueException(QueueErrorCode.barberBusy, [_repo.getBarberById(barberId)?.name ?? '']);
    }
    final now = DateTime.now().toUtc();
    await store.update(current, {
      'status': QueueStatus.serving.name,
      'barberId': barberId,
      'servingStartedAt': now.toIso8601String(),
    });
    return current.copyWith(status: QueueStatus.serving, barberId: barberId, servingStartedAt: now);
  }

  /// Serves the first waiting person who has no preferred barber or prefers
  /// [barberId]. Returns null when nobody is waiting for them.
  Future<QueueEntry?> callNext(String shopId, String barberId) async {
    _requireStaff(shopId);
    final active = await store.fetchActive(shopId);
    if (servingByBarber(active).containsKey(barberId)) {
      throw QueueException(QueueErrorCode.barberBusy, [_repo.getBarberById(barberId)?.name ?? '']);
    }
    final next = nextFor(active, barberId);
    if (next == null) return null;
    return startServing(next, barberId);
  }

  /// The first waiting entry [barberId] may take (no preference, or prefers
  /// them).
  static QueueEntry? nextFor(Iterable<QueueEntry> entries, String barberId) => queueArrivalOrder(entries)
      .where((e) => e.status == QueueStatus.waiting && (e.barberId == null || e.barberId == barberId))
      .firstOrNull;

  Future<void> finish(QueueEntry entry) async {
    _requireStaff(entry.shopId);
    if (entry.status != QueueStatus.serving) throw QueueException(QueueErrorCode.notServing);
    await store.update(entry, {
      'status': QueueStatus.done.name,
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// The person left before being served.
  Future<void> markLeft(QueueEntry entry) async {
    _requireStaff(entry.shopId);
    if (entry.status != QueueStatus.waiting) throw QueueException(QueueErrorCode.notWaiting);
    await store.update(entry, {
      'status': QueueStatus.left.name,
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // --- Customer actions ---

  /// Joins [shopId]'s queue remotely as the signed-in customer, with their
  /// own name and phone. Returns their existing entry if they are already in
  /// line there.
  Future<QueueEntry> joinQueue({required String shopId, String? serviceId, String? barberId}) async {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (user.role != UserRole.customer) throw QueueException(QueueErrorCode.customersOnly);
    final existing = await store.fetchLatestOwn(shopId, user.uid);
    if (existing != null && existing.isActive) return existing;
    var name = user.name.trim();
    if (name.length > kQueueNameMaxLength) name = name.substring(0, kQueueNameMaxLength).trim();
    final entry = QueueEntry(
      id: store.newId(shopId),
      shopId: shopId,
      name: _validName(name),
      phone: user.phone == null ? null : normalizeEthiopianPhone(user.phone!),
      serviceId: serviceId,
      barberId: barberId,
      status: QueueStatus.waiting,
      createdAt: DateTime.now().toUtc(),
      addedBy: user.uid,
      source: QueueSource.remote,
    );
    await store.add(entry);
    return entry;
  }

  /// Leaves the queue (own waiting entry only).
  Future<void> leaveQueue(QueueEntry entry) async {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (entry.addedBy != user.uid || entry.source != QueueSource.remote) {
      throw QueueException(QueueErrorCode.customersOnly);
    }
    if (entry.status != QueueStatus.waiting) throw QueueException(QueueErrorCode.notWaiting);
    await store.update(entry, {
      'status': QueueStatus.left.name,
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
