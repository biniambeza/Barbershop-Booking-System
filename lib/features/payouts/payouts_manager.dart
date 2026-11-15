import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/config/app_config.dart';
import '../../data/seed_dataset.dart';
import '../../models/barber_model.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../services/app_repository.dart';
import '../../services/payout_service.dart';

export '../../services/payout_service.dart';

/// Storage of payouts: [FirestorePayoutStore] in production,
/// [LocalPayoutStore] in DEMO_MODE builds and tests.
abstract class PayoutStore {
  /// A new document id.
  String newId(String shopId);

  /// Owner: the shop's payouts whose `periodStart` is in [month], newest
  /// recorded first, live.
  Stream<List<Payout>> watchShopPayouts(String shopId, PayoutMonth month);

  /// Barber (or owner): every payout of one barber, newest recorded first,
  /// live.
  Stream<List<Payout>> watchBarberPayouts(String shopId, String barberId);

  Future<void> create(Payout payout);
  Future<void> delete(Payout payout);
}

/// Firestore access, all under `barbershops/{shopId}/payouts`:
///
///  * owner, month:  where periodStart >= 'yyyy-MM-01T00:00:00.000Z' and
///                   periodStart <= last day of the month (single-field
///                   range, no composite index), snapshots
///  * barber:        where barberId == own barberId, snapshots (sorted on
///                   the client, no composite index)
///  * create:        set `payouts/{autoId}` with [Payout.toMap]
///  * delete:        delete `payouts/{id}`
class FirestorePayoutStore implements PayoutStore {
  FirestorePayoutStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _payouts(String shopId) =>
      _db.collection('barbershops').doc(shopId).collection('payouts');

  List<Payout> _read(QuerySnapshot<Map<String, dynamic>> snap, String shopId) =>
      [for (final d in snap.docs) Payout.fromMap(d.data(), d.id, shopId: shopId)]..sort(Payout.newestFirst);

  @override
  String newId(String shopId) => _payouts(shopId).doc().id;

  @override
  Stream<List<Payout>> watchShopPayouts(String shopId, PayoutMonth month) => _payouts(shopId)
      .where('periodStart', isGreaterThanOrEqualTo: payoutDateIso(month.firstDay))
      .where('periodStart', isLessThanOrEqualTo: payoutDateIso(month.lastDay))
      .snapshots()
      .map((s) => _read(s, shopId));

  @override
  Stream<List<Payout>> watchBarberPayouts(String shopId, String barberId) =>
      _payouts(shopId).where('barberId', isEqualTo: barberId).snapshots().map((s) => _read(s, shopId));

  @override
  Future<void> create(Payout payout) => _payouts(payout.shopId).doc(payout.id).set(payout.toMap());

  @override
  Future<void> delete(Payout payout) => _payouts(payout.shopId).doc(payout.id).delete();
}

/// In-memory payouts for DEMO_MODE builds and tests. In DEMO_MODE it loads
/// the dataset's `payouts` on first use.
class LocalPayoutStore implements PayoutStore {
  LocalPayoutStore({this.seedFromAssets = false});

  final bool seedFromAssets;

  final Map<String, Payout> _byId = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  bool _seeded = false;
  Future<void>? _seeding;
  int _counter = 0;

  /// Replaces all payouts with the `payouts` of the demo dataset JSON.
  void loadSeedJson(Map<String, dynamic> json, {DateTime? now}) {
    _byId
      ..clear()
      ..addEntries(payoutsFromSeedJson(json, now: now).map((p) => MapEntry(p.id, p)));
    _seeded = true;
    _changes.add(null);
  }

  /// Empties the store (tests).
  void clear() {
    _byId.clear();
    _seeded = true;
    _changes.add(null);
  }

  /// Every payout (tests).
  List<Payout> get all => _byId.values.toList()..sort(Payout.newestFirst);

  Future<void> _ensureSeeded() {
    if (_seeded || !seedFromAssets) return Future.value();
    return _seeding ??= () async {
      try {
        final text = await rootBundle.loadString(kSeedAssetPath);
        if (!_seeded) loadSeedJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not load the demo payouts: $e');
        _seeded = true;
      }
    }();
  }

  Stream<List<Payout>> _watch(bool Function(Payout) test) {
    late StreamController<List<Payout>> controller;
    StreamSubscription<void>? sub;
    List<Payout> read() => all.where(test).toList();
    controller = StreamController<List<Payout>>(
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
  String newId(String shopId) => 'payout_local_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  @override
  Stream<List<Payout>> watchShopPayouts(String shopId, PayoutMonth month) =>
      _watch((p) => p.shopId == shopId && month.containsDate(p.periodStart));

  @override
  Stream<List<Payout>> watchBarberPayouts(String shopId, String barberId) =>
      _watch((p) => p.shopId == shopId && p.barberId == barberId);

  @override
  Future<void> create(Payout payout) async {
    await _ensureSeeded();
    _byId[payout.id] = payout;
    _changes.add(null);
  }

  @override
  Future<void> delete(Payout payout) async {
    await _ensureSeeded();
    if (_byId.remove(payout.id) == null) throw PayoutException(PayoutErrorCode.notFound);
    _changes.add(null);
  }
}

/// The demo dataset's payouts. Each entry: `{id, shopId, barberId, amount,
/// method, monthOffset, note?, createdBy, createdHoursAgo}`; the period is
/// the whole Addis month [monthOffset] months from the current one.
/// tool/seed/seed.js applies the same rules. Entries naming an unknown
/// barber of the shop are skipped.
List<Payout> payoutsFromSeedJson(Map<String, dynamic> json, {DateTime? now}) {
  final raw = json['payouts'] as List<dynamic>? ?? const [];
  if (raw.isEmpty) return const [];
  final nowUtc = (now ?? DateTime.now()).toUtc();
  final barbers = {for (final b in SeedDataset.fromJson(json, now: now).barbers) b.id: b};
  final current = PayoutMonth.ofInstant(nowUtc);
  final out = <Payout>[];
  for (final entry in raw) {
    final m = Map<String, dynamic>.from(entry as Map);
    final barber = barbers[m['barberId']];
    if (m['id'] is! String || barber == null || barber.shopId != m['shopId']) continue;
    final month = current.next(((m['monthOffset'] as num?) ?? 0).toInt());
    final note = (m['note'] as String?)?.trim();
    out.add(Payout(
      id: m['id'] as String,
      shopId: barber.shopId,
      barberId: barber.id,
      amount: (m['amount'] as num).toDouble(),
      periodStart: month.firstDay,
      periodEnd: month.lastDay,
      method: PayoutMethod.fromName(m['method']),
      note: note == null || note.isEmpty ? null : note,
      createdBy: m['createdBy'] as String? ?? '',
      createdAt: nowUtc.subtract(Duration(minutes: ((((m['createdHoursAgo'] as num?) ?? 0) * 60)).round())),
    ));
  }
  return out;
}

/// Barber commission and payouts.
///
///  * Owner: sets each barber's commission ([setCommission]), sees per
///    barber figures for a month ([summarizeMonth] over
///    [loadMonthBookings] and [watchShopPayouts]), records payouts
///    ([recordPayout]) and deletes one within 24 hours ([deletePayout]).
///  * Barber: their own share, payouts and balance ([watchBarberPayouts],
///    [summarizeMonth] over the cached bookings).
class PayoutsManager {
  PayoutsManager({AppRepository? repository, PayoutStore? cloud, LocalPayoutStore? local, DateTime Function()? clock})
      : _repo = repository ?? AppRepository.instance,
        _cloudOverride = cloud,
        _clock = clock {
    this.local = local ?? LocalPayoutStore(seedFromAssets: kDemoMode);
  }

  static PayoutsManager? _instance;
  static PayoutsManager get instance => _instance ??= PayoutsManager();

  /// Tests: replaces the shared instance (null restores a fresh default).
  @visibleForTesting
  static set instance(PayoutsManager? manager) => _instance = manager;

  /// Months offered in the owner's month picker.
  static const int monthsShown = 12;

  final AppRepository _repo;
  final PayoutStore? _cloudOverride;
  final DateTime Function()? _clock;
  PayoutStore? _cloud;
  FirebaseFirestore? _db;

  /// The in-memory store (DEMO_MODE and tests).
  late final LocalPayoutStore local;

  bool get _usesFirestore => _cloudOverride == null && _repo.isFirebaseAttached;

  PayoutStore get store {
    if (_cloudOverride != null) return _cloudOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestorePayoutStore(_db ??= FirebaseFirestore.instance);
  }

  DateTime nowUtc() => (_clock?.call() ?? _repo.nowUtc()).toUtc();

  PayoutMonth currentMonth() => PayoutMonth.ofInstant(nowUtc());

  List<PayoutMonth> recentMonths() => PayoutMonth.recent(nowUtc(), monthsShown);

  // --- Permissions ---

  /// Whether the signed-in user owns [shopId].
  bool isShopOwner(String shopId) {
    final user = _repo.currentUser;
    if (user == null || user.role != UserRole.barbershopOwner) return false;
    return user.shopId == shopId || _repo.getShopById(shopId)?.ownerId == user.uid;
  }

  /// Whether the signed-in owner may still delete [payout].
  bool canDelete(Payout payout) => isShopOwner(payout.shopId) && isWithinPayoutDeleteWindow(payout, nowUtc());

  // --- Reads ---

  Stream<List<Payout>> watchShopPayouts(String shopId, PayoutMonth month) => store.watchShopPayouts(shopId, month);

  Stream<List<Payout>> watchBarberPayouts(Barber barber) => store.watchBarberPayouts(barber.shopId, barber.id);

  /// The cached bookings of the shop (or one barber) in [month].
  List<Booking> cachedMonthBookings(String shopId, PayoutMonth month, {String? barberId}) => [
        for (final b in barberId == null ? _repo.getShopBookings(shopId) : _repo.getBookingsForBarber(barberId))
          if (b.shopId == shopId && month.containsInstant(b.startAt)) b,
      ];

  /// Every booking of the shop (or of [barberId]) that started in [month].
  ///
  /// With Firebase: one get of `bookings where shopId == s [and barberId ==
  /// b] and startAt >= month start and startAt < next month start` (the
  /// existing shopId/startAt and shopId/barberId/startAt indexes), merged
  /// with the live cache. Without Firebase: the cache.
  Future<List<Booking>> loadMonthBookings(String shopId, PayoutMonth month, {String? barberId}) async {
    final cached = cachedMonthBookings(shopId, month, barberId: barberId);
    if (!_usesFirestore) return cached;
    Query<Map<String, dynamic>> q =
        (_db ??= FirebaseFirestore.instance).collection('bookings').where('shopId', isEqualTo: shopId);
    if (barberId != null) q = q.where('barberId', isEqualTo: barberId);
    final snap = await q
        .where('startAt', isGreaterThanOrEqualTo: month.startUtc.toIso8601String())
        .where('startAt', isLessThan: month.endUtc.toIso8601String())
        .get();
    return mergeBookings([for (final d in snap.docs) Booking.fromMap(d.data(), d.id)], cached);
  }

  /// Per-barber figures of [shopId] for [month].
  List<BarberPayoutSummary> summarizeMonth(
    String shopId,
    PayoutMonth month, {
    required Iterable<Booking> bookings,
    required Iterable<Payout> payouts,
  }) =>
      summarizeShopMonth(
        barbers: _repo.getBarbersForShop(shopId),
        bookings: bookings,
        payouts: payouts,
        month: month,
      );

  // --- Owner writes ---

  /// Sets [barberId]'s commission (whole percent, 0..100).
  Future<void> setCommission(String barberId, int percent) async {
    if (_repo.currentUser == null) throw AppStateException(AppErrorCode.signInRequired);
    final barber = _repo.getBarberById(barberId);
    if (barber == null) throw PayoutException(PayoutErrorCode.notFound);
    if (!isShopOwner(barber.shopId)) throw PayoutException(PayoutErrorCode.ownerOnly);
    if (!isValidCommissionPercent(percent)) throw PayoutException(PayoutErrorCode.invalidCommission);
    await _repo.updateBarber(barber.copyWith(commissionPercent: percent));
  }

  /// Records a payout to [barberId] for the period [periodStart]..[periodEnd]
  /// (calendar dates; default: the whole of [month]).
  Future<Payout> recordPayout({
    required String shopId,
    required String barberId,
    required double amount,
    required PayoutMethod method,
    PayoutMonth? month,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? note,
  }) async {
    final user = _repo.currentUser;
    if (user == null) throw AppStateException(AppErrorCode.signInRequired);
    if (!isShopOwner(shopId)) throw PayoutException(PayoutErrorCode.ownerOnly);
    final barber = _repo.getBarberById(barberId);
    if (barber == null || barber.shopId != shopId) throw PayoutException(PayoutErrorCode.unknownBarber);
    final period = month ?? currentMonth();
    final start = periodStart ?? period.firstDay;
    final end = periodEnd ?? period.lastDay;
    final rounded = roundBirr(amount);
    final text = note?.trim() ?? '';
    final problem = validatePayoutInput(amount: rounded, periodStart: start, periodEnd: end, note: text);
    if (problem != null) throw PayoutException(problem);
    final payout = Payout(
      id: store.newId(shopId),
      shopId: shopId,
      barberId: barberId,
      amount: rounded,
      periodStart: DateTime.utc(start.year, start.month, start.day),
      periodEnd: DateTime.utc(end.year, end.month, end.day),
      method: method,
      note: text.isEmpty ? null : text,
      createdBy: user.uid,
      createdAt: nowUtc(),
    );
    await store.create(payout);
    return payout;
  }

  /// Deletes [payout] (owner, within 24 hours of recording it).
  Future<void> deletePayout(Payout payout) async {
    if (_repo.currentUser == null) throw AppStateException(AppErrorCode.signInRequired);
    if (!isShopOwner(payout.shopId)) throw PayoutException(PayoutErrorCode.ownerOnly);
    if (!isWithinPayoutDeleteWindow(payout, nowUtc())) throw PayoutException(PayoutErrorCode.deleteWindowPassed);
    await store.delete(payout);
  }
}
