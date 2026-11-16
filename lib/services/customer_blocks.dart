/// Blocking customers at one shop (owner analytics).
///
/// A block is one document, `barbershops/{shopId}/blockedCustomers/{customerUid}`,
/// so the security rules can refuse a booking create or a remote queue join
/// with a single `exists()`. Shape (exactly these keys; the two optional
/// ones only when set):
///
/// ```
/// {
///   customerId:   string  (== the doc id)
///   customerName: string  (0..100, from the customer's bookings)
///   source:       'owner' | 'auto'
///   blockedBy:    string  (uid of the owner, or of the staff member whose
///                          no-show mark triggered an auto-block)
///   blockedAt:    string  (ISO-8601 UTC, client clock)
///   reason?:      string  (1..200, owner's note; not shown to the customer)
///   noShowCount?: int     (0..1000, auto-blocks: the count that triggered it)
/// }
/// ```
///
/// Unblocking deletes the document. The optional auto-block setting lives in
/// `barbershops/{shopId}/settings/customerBlocks`:
/// `{autoBlockNoShows: int (0 = off, 1..10), updatedBy: uid, updatedAt: ISO}`.
///
/// Blocked customers keep their existing bookings unless the owner chooses
/// to cancel them ([CustomerBlockService.cancelUpcomingBookings], which goes
/// through the normal owner cancel and so flags paid bookings for a refund).
///
/// Works on the free Spark plan: everything is written by the app.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'app_repository.dart';
import 'customer_insights.dart' show noShowCountOf;

/// Longest owner note on a block.
const int kMaxBlockReasonLength = 200;

/// The auto-block limit the switch starts with.
const int kDefaultAutoBlockNoShows = 3;

/// Highest auto-block limit the owner can pick.
const int kMaxAutoBlockNoShows = 10;

/// Who created a block.
enum CustomerBlockSource {
  /// The owner, by hand.
  owner,

  /// The auto-block setting, when a no-show was marked.
  auto;

  static CustomerBlockSource fromString(Object? v) => v == 'auto' ? auto : owner;
}

/// One blocked customer of a shop.
class CustomerBlock {
  const CustomerBlock({
    required this.shopId,
    required this.customerId,
    required this.customerName,
    required this.source,
    required this.blockedBy,
    required this.blockedAt,
    this.reason,
    this.noShowCount,
  });

  final String shopId;
  final String customerId;
  final String customerName;
  final CustomerBlockSource source;
  final String blockedBy;
  final DateTime blockedAt;
  final String? reason;
  final int? noShowCount;

  bool get isAuto => source == CustomerBlockSource.auto;

  /// The document (see the library doc for the exact shape).
  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'customerName': customerName.length > 100 ? customerName.substring(0, 100) : customerName,
        'source': source.name,
        'blockedBy': blockedBy,
        'blockedAt': blockedAt.toUtc().toIso8601String(),
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        if (noShowCount != null) 'noShowCount': noShowCount,
      };

  factory CustomerBlock.fromMap(String shopId, String id, Map<String, dynamic> map) => CustomerBlock(
        shopId: shopId,
        customerId: id,
        customerName: map['customerName'] is String ? map['customerName'] as String : '',
        source: CustomerBlockSource.fromString(map['source']),
        blockedBy: map['blockedBy'] is String ? map['blockedBy'] as String : '',
        blockedAt: (map['blockedAt'] is String ? DateTime.tryParse(map['blockedAt'] as String) : null)?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        reason: map['reason'] is String && (map['reason'] as String).isNotEmpty ? map['reason'] as String : null,
        noShowCount: map['noShowCount'] is num ? (map['noShowCount'] as num).toInt() : null,
      );
}

/// The shop's auto-block setting.
class CustomerBlockSettings {
  const CustomerBlockSettings({this.autoBlockNoShows = 0});

  static const CustomerBlockSettings off = CustomerBlockSettings();

  /// Block a customer once they have this many no-shows at the shop
  /// (0 = off).
  final int autoBlockNoShows;

  bool get autoBlockOn => autoBlockNoShows > 0;

  factory CustomerBlockSettings.fromMap(Map<String, dynamic>? map) {
    final v = map?['autoBlockNoShows'];
    final n = v is num ? v.toInt() : 0;
    return CustomerBlockSettings(autoBlockNoShows: n < 0 || n > kMaxAutoBlockNoShows ? 0 : n);
  }

  @override
  bool operator ==(Object other) => other is CustomerBlockSettings && other.autoBlockNoShows == autoBlockNoShows;

  @override
  int get hashCode => autoBlockNoShows.hashCode;
}

/// Whether a customer with [noShows] no-shows reaches the auto-block limit.
bool reachesAutoBlock(CustomerBlockSettings settings, int noShows) =>
    settings.autoBlockOn && noShows >= settings.autoBlockNoShows;

/// The owner's note, trimmed; null when empty. Throws
/// [AppFormatException] ([AppErrorCode.declineReasonTooLong]) when longer
/// than [kMaxBlockReasonLength].
String? normalizeBlockReason(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length > kMaxBlockReasonLength) {
    throw AppFormatException(AppErrorCode.declineReasonTooLong, [kMaxBlockReasonLength]);
  }
  return text;
}

/// Storage of blocks and the auto-block setting: [FirestoreCustomerBlockStore]
/// in production, [LocalCustomerBlockStore] in DEMO_MODE and tests.
abstract class CustomerBlockStore {
  /// The shop's blocks, newest first (staff).
  Stream<List<CustomerBlock>> watchBlocks(String shopId);

  /// Whether [customerId] is blocked at [shopId] (staff, or the customer
  /// themselves).
  Future<bool> isBlocked(String shopId, String customerId);

  Future<void> block(CustomerBlock block);

  Future<void> unblock(String shopId, String customerId);

  Stream<CustomerBlockSettings> watchSettings(String shopId);

  Future<CustomerBlockSettings> fetchSettings(String shopId);

  Future<void> saveSettings(String shopId, CustomerBlockSettings settings,
      {required String updatedBy, required DateTime updatedAt});

  /// The customer's no-shows at the shop over all time, or null when this
  /// store cannot tell (the caller then counts the cached bookings).
  Future<int?> countNoShows(String shopId, String customerId);
}

/// Firestore: see the library doc for the paths and shapes.
class FirestoreCustomerBlockStore implements CustomerBlockStore {
  FirestoreCustomerBlockStore(this._db);

  final FirebaseFirestore _db;

  /// Blocks loaded for the owner's list.
  static const int listLimit = 500;

  CollectionReference<Map<String, dynamic>> _blocks(String shopId) =>
      _db.collection('barbershops').doc(shopId).collection('blockedCustomers');

  DocumentReference<Map<String, dynamic>> _settings(String shopId) =>
      _db.collection('barbershops').doc(shopId).collection('settings').doc('customerBlocks');

  @override
  Stream<List<CustomerBlock>> watchBlocks(String shopId) => _blocks(shopId).limit(listLimit).snapshots().map(
      (s) => [for (final d in s.docs) CustomerBlock.fromMap(shopId, d.id, d.data())]
        ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt)));

  @override
  Future<bool> isBlocked(String shopId, String customerId) async =>
      (await _blocks(shopId).doc(customerId).get()).exists;

  @override
  Future<void> block(CustomerBlock block) => _blocks(block.shopId).doc(block.customerId).set(block.toMap());

  @override
  Future<void> unblock(String shopId, String customerId) => _blocks(shopId).doc(customerId).delete();

  @override
  Stream<CustomerBlockSettings> watchSettings(String shopId) =>
      _settings(shopId).snapshots().map((s) => CustomerBlockSettings.fromMap(s.data()));

  @override
  Future<CustomerBlockSettings> fetchSettings(String shopId) async =>
      CustomerBlockSettings.fromMap((await _settings(shopId).get()).data());

  @override
  Future<void> saveSettings(String shopId, CustomerBlockSettings settings,
          {required String updatedBy, required DateTime updatedAt}) =>
      _settings(shopId).set({
        'autoBlockNoShows': settings.autoBlockNoShows,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      });

  /// One aggregate count over `bookings where shopId == s and customerId ==
  /// c and status == 'noShow'` (index bookings (shopId, customerId, status,
  /// startAt desc)). Only the owner may run it (a barber's list access is
  /// limited to their own bookings); a refusal returns null.
  @override
  Future<int?> countNoShows(String shopId, String customerId) async {
    try {
      final snap = await _db
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where('customerId', isEqualTo: customerId)
          .where('status', isEqualTo: BookingStatus.noShow.name)
          .count()
          .get();
      return snap.count;
    } catch (e) {
      debugPrint('No-show count unavailable: $e');
      return null;
    }
  }
}

/// In memory (DEMO_MODE and tests).
class LocalCustomerBlockStore implements CustomerBlockStore {
  final Map<String, Map<String, CustomerBlock>> _blocks = {};
  final Map<String, CustomerBlockSettings> _settings = {};
  final StreamController<String> _changes = StreamController<String>.broadcast(sync: true);

  /// Removes every block and setting (tests, [AppRepository.loadSeed]).
  void clear() {
    final shops = {..._blocks.keys, ..._settings.keys};
    _blocks.clear();
    _settings.clear();
    shops.forEach(_changes.add);
  }

  /// Synchronous read (tests).
  List<CustomerBlock> blocksOf(String shopId) =>
      (_blocks[shopId]?.values.toList() ?? <CustomerBlock>[])..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));

  Stream<T> _watch<T>(String shopId, T Function() read) {
    late StreamController<T> controller;
    StreamSubscription<String>? sub;
    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.where((id) => id == shopId).listen((_) => controller.add(read()));
        controller.add(read());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<List<CustomerBlock>> watchBlocks(String shopId) => _watch(shopId, () => blocksOf(shopId));

  @override
  Future<bool> isBlocked(String shopId, String customerId) async => _blocks[shopId]?.containsKey(customerId) ?? false;

  @override
  Future<void> block(CustomerBlock block) async {
    (_blocks[block.shopId] ??= {})[block.customerId] = block;
    _changes.add(block.shopId);
  }

  @override
  Future<void> unblock(String shopId, String customerId) async {
    _blocks[shopId]?.remove(customerId);
    _changes.add(shopId);
  }

  @override
  Stream<CustomerBlockSettings> watchSettings(String shopId) =>
      _watch(shopId, () => _settings[shopId] ?? CustomerBlockSettings.off);

  @override
  Future<CustomerBlockSettings> fetchSettings(String shopId) async => _settings[shopId] ?? CustomerBlockSettings.off;

  @override
  Future<void> saveSettings(String shopId, CustomerBlockSettings settings,
      {required String updatedBy, required DateTime updatedAt}) async {
    _settings[shopId] = settings;
    _changes.add(shopId);
  }

  /// Local mode counts the cached bookings (they are the whole dataset).
  @override
  Future<int?> countNoShows(String shopId, String customerId) async => null;
}

/// Blocking customers at a shop, the auto-block setting and the checks on
/// the customer's side.
///
///  * The owner blocks / unblocks ([blockCustomer], [unblockCustomer]),
///    optionally cancelling the customer's upcoming bookings
///    ([cancelUpcomingBookings]), and sets auto-block ([setAutoBlock]).
///  * New bookings ([AppRepository.createBooking]) and remote queue joins
///    (QueueService.joinQueue) call [assertCurrentUserCanBook]; the rules
///    refuse them as well.
///  * Marking a no-show calls [afterNoShow], which blocks the customer when
///    the shop's auto-block limit is reached.
class CustomerBlockService {
  CustomerBlockService({AppRepository? repository, CustomerBlockStore? cloud, LocalCustomerBlockStore? local})
      : _repoOverride = repository,
        _cloudOverride = cloud,
        local = local ?? LocalCustomerBlockStore();

  static CustomerBlockService? _instance;
  static CustomerBlockService get instance => _instance ??= CustomerBlockService();

  /// Clears the shared local store if it was created (called by
  /// [AppRepository.loadSeed]).
  static void resetLocal() => _instance?.local.clear();

  final AppRepository? _repoOverride;
  final CustomerBlockStore? _cloudOverride;
  CustomerBlockStore? _cloud;

  AppRepository get _repo => _repoOverride ?? AppRepository.instance;

  /// The in-memory store (DEMO_MODE and tests).
  final LocalCustomerBlockStore local;

  CustomerBlockStore get store {
    if (_cloudOverride != null) return _cloudOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestoreCustomerBlockStore(FirebaseFirestore.instance);
  }

  /// Whether the signed-in user owns [shopId].
  bool canManage(String shopId) {
    final u = _repo.currentUser;
    return u != null && u.role == UserRole.barbershopOwner && u.shopId == shopId;
  }

  void _assertOwner(String shopId) {
    if (!canManage(shopId)) throw AppStateException(AppErrorCode.customerBlockNotAllowed);
  }

  Stream<List<CustomerBlock>> watchBlocks(String shopId) => store.watchBlocks(shopId);

  Stream<CustomerBlockSettings> watchSettings(String shopId) => store.watchSettings(shopId);

  // --- Owner ---

  /// Blocks [customerId] at [shopId] (owner). [reason] is optional (at most
  /// [kMaxBlockReasonLength] characters). Existing bookings stay.
  Future<CustomerBlock> blockCustomer({
    required String shopId,
    required String customerId,
    required String customerName,
    String? reason,
  }) async {
    _assertOwner(shopId);
    final block = CustomerBlock(
      shopId: shopId,
      customerId: customerId,
      customerName: customerName.trim(),
      source: CustomerBlockSource.owner,
      blockedBy: _repo.currentUser!.uid,
      blockedAt: _repo.nowUtc(),
      reason: normalizeBlockReason(reason),
    );
    await store.block(block);
    return block;
  }

  /// Removes the block (owner).
  Future<void> unblockCustomer(String shopId, String customerId) async {
    _assertOwner(shopId);
    await store.unblock(shopId, customerId);
  }

  /// Sets the auto-block limit (owner): 0 = off, 1..[kMaxAutoBlockNoShows].
  Future<void> setAutoBlock(String shopId, int noShows) async {
    _assertOwner(shopId);
    if (noShows < 0 || noShows > kMaxAutoBlockNoShows) {
      throw ArgumentError.value(noShows, 'noShows', '0..$kMaxAutoBlockNoShows');
    }
    await store.saveSettings(shopId, CustomerBlockSettings(autoBlockNoShows: noShows),
        updatedBy: _repo.currentUser!.uid, updatedAt: _repo.nowUtc());
  }

  /// The customer's pending / confirmed bookings at [shopId] that have not
  /// started yet (from the owner's loaded bookings), soonest first.
  List<Booking> upcomingBookingsOf(String shopId, String customerId) {
    final now = _repo.nowUtc();
    return _repo
        .getShopBookings(shopId)
        .where((b) =>
            b.customerId == customerId &&
            (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) &&
            b.startAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  /// Owner: cancels the customer's upcoming bookings at [shopId] with the
  /// normal owner cancel (slot locks released; paid ones flagged for a
  /// refund in the same write). Returns how many were cancelled; one that
  /// fails is skipped.
  Future<int> cancelUpcomingBookings(String shopId, String customerId) async {
    _assertOwner(shopId);
    var cancelled = 0;
    for (final b in upcomingBookingsOf(shopId, customerId)) {
      try {
        await _repo.updateBookingStatus(b.id, BookingStatus.cancelled);
        cancelled++;
      } catch (e) {
        debugPrint('Block: could not cancel ${b.id}: $e');
      }
    }
    return cancelled;
  }

  // --- Customer side ---

  /// Whether the signed-in customer is blocked at [shopId]. Fails open
  /// (false) when the check cannot be made: the rules still refuse the
  /// write of a blocked customer.
  Future<bool> isCurrentUserBlocked(String shopId) async {
    final u = _repo.currentUser;
    if (u == null || u.role != UserRole.customer) return false;
    try {
      return await store.isBlocked(shopId, u.uid);
    } catch (e) {
      debugPrint('Block check unavailable: $e');
      return false;
    }
  }

  /// Throws [AppStateException] ([AppErrorCode.customerBlockedAtShop]) when
  /// the signed-in customer is blocked at [shopId].
  Future<void> assertCurrentUserCanBook(String shopId) async {
    if (await isCurrentUserBlocked(shopId)) throw AppStateException(AppErrorCode.customerBlockedAtShop);
  }

  // --- Auto-block ---

  /// After [booking] was marked a no-show: blocks its customer when the
  /// shop's auto-block limit is reached and they are not blocked yet.
  /// Returns the new block, or null. Never throws (best effort; the no-show
  /// itself is already saved).
  ///
  /// The count is the larger of the cached bookings and, with Firebase,
  /// an aggregate count over all the shop's bookings (owner only; a
  /// barber's app sees only their own bookings, so it counts those).
  Future<CustomerBlock?> afterNoShow(Booking booking) async {
    final u = _repo.currentUser;
    if (u == null || u.shopId != booking.shopId || booking.customerId.isEmpty) return null;
    if (u.role != UserRole.barbershopOwner && u.role != UserRole.barber) return null;
    try {
      final settings = await store.fetchSettings(booking.shopId);
      if (!settings.autoBlockOn) return null;
      if (await store.isBlocked(booking.shopId, booking.customerId)) return null;
      final cached = noShowCountOf(_repo.getShopBookings(booking.shopId),
          shopId: booking.shopId, customerId: booking.customerId, alsoNoShowId: booking.id);
      final remote = await store.countNoShows(booking.shopId, booking.customerId);
      final count = remote != null && remote > cached ? remote : cached;
      if (!reachesAutoBlock(settings, count)) return null;
      final block = CustomerBlock(
        shopId: booking.shopId,
        customerId: booking.customerId,
        customerName: booking.customerName,
        source: CustomerBlockSource.auto,
        blockedBy: u.uid,
        blockedAt: _repo.nowUtc(),
        noShowCount: count > 1000 ? 1000 : count,
      );
      await store.block(block);
      return block;
    } catch (e) {
      debugPrint('Auto-block skipped: $e');
      return null;
    }
  }
}
