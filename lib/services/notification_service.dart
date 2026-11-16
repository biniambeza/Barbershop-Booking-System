import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/addis_time.dart';
import '../l10n/gen/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../models/app_notification.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'app_repository.dart';
import 'early_finish_service.dart' show planEarlyFinishNotices; // early finish
import 'refunds.dart' show refundDueNotice, refundedNotice; // refunds
import 'shop_deletion.dart' show ShopDeletionNotice, kShopDeletedCancelReason; // shop deletion

/// Web push needs a VAPID key from the Firebase console (Project settings >
/// Cloud Messaging > Web Push certificates):
///
///   flutter build web --dart-define=FCM_VAPID_KEY=...
///
/// Without it, web clients still get the in-app inbox but no push.
const String kFcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Android notification channel the Cloud Functions send to (created
/// natively in MainActivity).
const String kBookingsChannelId = 'bookings';

/// How many inbox entries are loaded (newest first).
const int kInboxLimit = 50;

/// Booking notifications for the signed-in user: the in-app inbox, the
/// unread badge, foreground banners and (with Firebase) FCM push
/// registration.
///
///  * With Firebase attached the inbox is `users/{uid}/notifications`,
///    written by the notifications Cloud Functions; this class only reads it
///    and sets `read: true`. The device's FCM token is stored at
///    `users/{uid}/devices/{deviceId}` and removed again on sign-out.
///  * In local mode (DEMO_MODE builds and tests) [LocalNotificationInbox]
///    generates the same notifications from booking changes it observes in
///    [AppRepository], so the demo behaves like production.
class NotificationService extends ChangeNotifier {
  NotificationService({
    AppRepository? repository,
    FirebaseFirestore? firestore,
    PushRegistrar? push,
  })  : _repo = repository ?? AppRepository.instance,
        _firestoreOverride = firestore,
        _pushOverride = push;

  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService();

  /// Given to MaterialApp so banners and notification taps work from
  /// anywhere.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Builds the inbox screen; set by the app (avoids a service -> UI import).
  static WidgetBuilder? inboxRouteBuilder;

  final AppRepository _repo;
  final FirebaseFirestore? _firestoreOverride;
  final PushRegistrar? _pushOverride;

  /// Local-mode inboxes of every demo user (kept across persona switches).
  final LocalNotificationInbox local = LocalNotificationInbox();

  bool _started = false;
  String? _uid;
  List<AppNotification> _items = const [];
  StreamSubscription<List<AppNotification>>? _inboxSub;
  bool _firstSnapshot = true;
  PushRegistrar? _push;
  bool _openInboxWhenSignedIn = false;

  // --- shop deletion ---
  /// Role of the signed-in user at the last repository change: when it
  /// changes for the same account (e.g. a deleted shop's owner or barber
  /// became a customer) pushed staff screens are closed.
  UserRole? _lastRole;

  /// shopRemoved notices already shown as a banner in this app session.
  final Set<String> _shownShopRemoved = {};
  // --- end shop deletion ---

  /// Called for every notification that arrives while the app is open
  /// (after the inbox's initial load). Defaults to a SnackBar banner.
  void Function(AppNotification notification)? onNewNotification;

  bool get _cloud => _repo.isFirebaseAttached;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  /// The signed-in user's notifications, newest first.
  List<AppNotification> get notifications => _items;
  int get unreadCount => _items.where((n) => !n.read).length;

  /// Starts following the repository's session. Safe to call twice.
  void start() {
    if (_started) return;
    _started = true;
    _repo.addListener(_onRepositoryChanged);
    _repo.beforeSignOut = _beforeSignOut;
    _repo.onLocalNotice = _onLocalShopDeletionNotice; // shop deletion
    _onRepositoryChanged();
  }

  // --- shop deletion ---
  /// Local mode: the admin's shop-deletion cascade wrote [notice].
  void _onLocalShopDeletionNotice(ShopDeletionNotice notice) {
    local.addDirect(notice.recipientUid, notice.toAppNotification());
    if (notice.recipientUid == _uid) {
      _items = local.inboxFor(notice.recipientUid);
      notifyListeners();
    }
  }

  /// Shows an unread "Your barbershop was removed" notice once per app
  /// session (also when it was written while the user was signed out).
  void _showUnreadShopRemoved(List<AppNotification> items) {
    for (final n in items) {
      if (n.type != NotificationTypes.shopRemoved || n.read || !_shownShopRemoved.add(n.id)) continue;
      _announce(n);
    }
  }

  /// The same account's role changed (a removed shop's staff became a
  /// customer): close the staff screens pushed above the home screen.
  void _onRoleChanged() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }
  // --- end shop deletion ---

  @override
  void dispose() {
    _repo.removeListener(_onRepositoryChanged);
    if (_repo.beforeSignOut == _beforeSignOut) _repo.beforeSignOut = null;
    if (_repo.onLocalNotice == _onLocalShopDeletionNotice) _repo.onLocalNotice = null; // shop deletion
    _inboxSub?.cancel();
    _push?.stop();
    super.dispose();
  }

  void _onRepositoryChanged() {
    final user = _repo.authStatus == AuthStatus.signedIn ? _repo.currentUser : null;

    // --- shop deletion ---
    final role = user?.role;
    if (user != null && user.uid == _uid && _lastRole != null && role != _lastRole) _onRoleChanged();
    _lastRole = role;
    // --- end shop deletion ---

    if (!_cloud) {
      // Local mode: turn booking changes into notifications first, so a
      // change made by this user shows up in the right inboxes.
      final added = local.observe(_repo, actor: user);
      if (user != null && added.any((e) => e.uid == user.uid)) {
        _setUser(user.uid, force: true);
        for (final e in added.where((e) => e.uid == user.uid)) {
          _announce(e.notification);
        }
        return;
      }
    }
    _setUser(user?.uid);
  }

  void _setUser(String? uid, {bool force = false}) {
    if (uid == _uid && !force) return;
    final changed = uid != _uid;
    _uid = uid;

    if (!_cloud) {
      _items = uid == null ? const [] : local.inboxFor(uid);
      notifyListeners();
      if (changed) _showUnreadShopRemoved(_items); // shop deletion
      return;
    }

    if (!changed) return;
    _inboxSub?.cancel();
    _inboxSub = null;
    _items = const [];
    _firstSnapshot = true;
    if (uid != null) {
      _inboxSub = FirestoreInbox(_db).watch(uid).listen(
        _onCloudInbox,
        onError: (Object e) => debugPrint('Notification inbox error: $e'),
      );
      _push ??= _pushOverride ?? FcmPushRegistrar(_db);
      unawaited(_push!.start(uid, onOpened: _onPushOpened).catchError((Object e) {
        debugPrint('Push registration failed: $e');
      }));
      if (_openInboxWhenSignedIn) {
        _openInboxWhenSignedIn = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => openInbox());
      }
    }
    notifyListeners();
  }

  void _onCloudInbox(List<AppNotification> items) {
    final known = {for (final n in _items) n.id};
    final first = _firstSnapshot;
    final fresh = _firstSnapshot ? const <AppNotification>[] : items.where((n) => !known.contains(n.id) && !n.read);
    _firstSnapshot = false;
    _items = items;
    notifyListeners();
    for (final n in fresh) {
      if (n.type == NotificationTypes.shopRemoved) _shownShopRemoved.add(n.id); // shop deletion
      _announce(n);
    }
    if (first) _showUnreadShopRemoved(items); // shop deletion
  }

  void _announce(AppNotification n) {
    // --- shop deletion --- in the app's language (the stored copy follows
    // the profile's language, which may be unset).
    if (n.type == NotificationTypes.shopRemoved) {
      final l = _l10n();
      n = AppNotification(
          id: n.id, title: l.shopRemovedNoticeTitle, body: l.shopRemovedNoticeBody, type: n.type, createdAt: n.createdAt);
    }
    // --- end shop deletion ---
    final handler = onNewNotification;
    if (handler != null) {
      handler(n);
      return;
    }
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (n.body.isNotEmpty) Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: _viewLabel(), onPressed: openInbox),
    ));
  }

  /// 'View' in the app's language (the snack bar has no BuildContext of its own).
  String _viewLabel() => _l10n().viewAction;

  AppLocalizations _l10n() {
    final ctx = messengerKey.currentContext ?? navigatorKey.currentContext;
    final l = ctx == null ? null : Localizations.of<AppLocalizations>(ctx, AppLocalizations);
    return l ?? lookupAppLocalizations(Locale(LocaleController.instance.languageCode));
  }

  /// A push notification was tapped (app in background or terminated).
  void _onPushOpened(String? notificationId) {
    if (notificationId != null) unawaited(markRead(notificationId));
    if (_uid == null) {
      _openInboxWhenSignedIn = true;
    } else {
      openInbox();
    }
  }

  /// Opens the inbox screen on top of the current route.
  void openInbox() {
    final nav = navigatorKey.currentState;
    final builder = inboxRouteBuilder;
    if (nav == null || builder == null) return;
    nav.push(MaterialPageRoute(builder: builder));
  }

  /// Marks one notification read (only the `read` field is written).
  Future<void> markRead(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final index = _items.indexWhere((n) => n.id == id);
    if (index >= 0 && _items[index].read) return;
    if (index >= 0) {
      _items = [..._items]..[index] = _items[index].copyWith(read: true);
      notifyListeners();
    }
    if (_cloud) {
      await FirestoreInbox(_db).markRead(uid, id);
    } else {
      local.markRead(uid, id);
    }
  }

  /// Marks every loaded notification read.
  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unread = _items.where((n) => !n.read).map((n) => n.id).toList();
    if (unread.isEmpty) return;
    _items = [for (final n in _items) n.read ? n : n.copyWith(read: true)];
    notifyListeners();
    if (_cloud) {
      await FirestoreInbox(_db).markAllRead(uid, unread);
    } else {
      for (final id in unread) {
        local.markRead(uid, id);
      }
    }
  }

  /// Runs inside [AppRepository.signOut] while the user is still signed in,
  /// so the device token can be deleted under their credentials.
  Future<void> _beforeSignOut() async {
    final uid = _uid;
    final push = _push;
    if (uid == null || push == null) return;
    await push.stop(uid: uid);
  }
}

// ---------------------------------------------------------------------------
// Firestore inbox
// ---------------------------------------------------------------------------

/// Reads and acknowledges `users/{uid}/notifications`.
class FirestoreInbox {
  FirestoreInbox(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      db.collection('users').doc(uid).collection('notifications');

  /// Newest first (createdAt is an ISO-8601 UTC string, so it sorts as text).
  Stream<List<AppNotification>> watch(String uid, {int limit = kInboxLimit}) {
    return _col(uid).orderBy('createdAt', descending: true).limit(limit).snapshots().map(
          (snap) => [for (final d in snap.docs) AppNotification.fromMap(d.data(), d.id)],
        );
  }

  Future<void> markRead(String uid, String id) => _col(uid).doc(id).update({'read': true});

  Future<void> markAllRead(String uid, List<String> ids) async {
    // Batches hold at most 500 writes.
    for (var i = 0; i < ids.length; i += 450) {
      final batch = db.batch();
      for (final id in ids.skip(i).take(450)) {
        batch.update(_col(uid).doc(id), {'read': true});
      }
      await batch.commit();
    }
  }
}

// ---------------------------------------------------------------------------
// Push (FCM) registration
// ---------------------------------------------------------------------------

/// Registers this device for push for a signed-in user.
abstract class PushRegistrar {
  /// Requests permission, stores the token and follows token refreshes.
  /// [onOpened] receives the inbox notification id of a tapped push.
  Future<void> start(String uid, {required void Function(String? notificationId) onOpened});

  /// Stops listening; with [uid], also deletes this device's token doc.
  Future<void> stop({String? uid});
}

/// The `platform` value for `users/{uid}/devices`, or null where FCM is not
/// supported (desktop).
String? currentPushPlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return null;
  }
}

/// Stable document id for an FCM token (64-bit FNV-1a as 16 hex chars), so
/// the same token always maps to the same `devices/{deviceId}` doc.
String deviceIdForToken(String token) {
  String fnv(int seed) {
    var hash = seed;
    for (final unit in token.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  return '${fnv(0x811C9DC5)}${fnv(0x050C5D1F)}';
}

/// The device document written for a token (exactly the contract keys).
Map<String, dynamic> deviceDocument(String token, String platform, DateTime nowUtc) => {
      'token': token,
      'platform': platform,
      'updatedAt': nowUtc.toUtc().toIso8601String(),
    };

/// Inbox id of a push, from its data payload {type, bookingId}.
String? notificationIdFromPushData(Map<String, dynamic> data) {
  // Every push from functions/notifications carries the inbox doc id; payment
  // and subscription notifications are keyed by paymentId, not bookingId.
  final notificationId = data['notificationId'];
  if (notificationId is String && notificationId.isNotEmpty) return notificationId;
  final bookingId = data['bookingId'];
  final type = data['type'];
  if (bookingId is! String || type is! String || bookingId.isEmpty || type.isEmpty) return null;
  return '${bookingId}_$type';
}

class FcmPushRegistrar implements PushRegistrar {
  FcmPushRegistrar(this.db, {FirebaseMessaging? messaging}) : _messagingOverride = messaging;

  final FirebaseFirestore db;
  final FirebaseMessaging? _messagingOverride;
  FirebaseMessaging get _messaging => _messagingOverride ?? FirebaseMessaging.instance;

  String? _uid;
  String? _token;
  final List<StreamSubscription<Object?>> _subs = [];

  DocumentReference<Map<String, dynamic>> _doc(String uid, String token) =>
      db.collection('users').doc(uid).collection('devices').doc(deviceIdForToken(token));

  @override
  Future<void> start(String uid, {required void Function(String? notificationId) onOpened}) async {
    final platform = currentPushPlatform();
    if (platform == null) return;
    if (platform == 'web' && kFcmVapidKey.isEmpty) {
      debugPrint('FCM_VAPID_KEY not set: web push disabled (the in-app inbox still works).');
      return;
    }
    await _cancelSubs();
    _uid = uid;

    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // iOS: let the OS show pushes while the app is open is not needed - the
    // inbox listener shows an in-app banner instead.

    // getToken/onTokenRefresh/deleteToken are deprecated in v17 in favour of
    // register()/onRegistered, which yield an installation id (FID). The
    // notifications backend sends to classic registration tokens, so keep
    // these until it moves to FID direct-send.
    // iOS: FCM can only issue a token once Apple has handed the app its APNs
    // token, which arrives a moment after permission is granted; asking
    // earlier throws `apns-token-not-set`. On a simulator, or before the APNs
    // key is uploaded to Firebase, it never arrives: skip the token then
    // (onTokenRefresh below still saves it if it turns up later).
    final apnsReady = platform != 'ios' || await _waitForApnsToken();
    // ignore: deprecated_member_use
    final token = apnsReady ? await _messaging.getToken(vapidKey: platform == 'web' ? kFcmVapidKey : null) : null;
    if (_uid != uid) return; // Signed out meanwhile.
    if (token != null) await _save(uid, token, platform);

    // ignore: deprecated_member_use
    _subs.add(_messaging.onTokenRefresh.listen((newToken) async {
      final current = _uid;
      if (current == null) return;
      final old = _token;
      try {
        await _save(current, newToken, platform);
        if (old != null && old != newToken) await _doc(current, old).delete();
      } catch (e) {
        debugPrint('Could not update FCM token: $e');
      }
    }));
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpened(notificationIdFromPushData(m.data))));
    final initial = await _messaging.getInitialMessage();
    if (initial != null) onOpened(notificationIdFromPushData(initial.data));
  }

  /// Polls for the iOS APNs token for up to about 10 seconds.
  Future<bool> _waitForApnsToken() async {
    for (var i = 0; i < 10; i++) {
      try {
        if (await _messaging.getAPNSToken() != null) return true;
      } catch (_) {
        // Not ready yet.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    debugPrint('No APNs token (simulator, or push not set up yet): iOS push token skipped.');
    return false;
  }

  Future<void> _save(String uid, String token, String platform) async {
    _token = token;
    await _doc(uid, token).set(deviceDocument(token, platform, DateTime.now()));
  }

  Future<void> _cancelSubs() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  @override
  Future<void> stop({String? uid}) async {
    final token = _token;
    _uid = null;
    _token = null;
    await _cancelSubs();
    if (uid == null || token == null) return;
    try {
      await _doc(uid, token).delete();
      // A fresh token is issued for the next account on this device.
      // ignore: deprecated_member_use
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Could not remove FCM token: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Local (demo / test) inbox
// ---------------------------------------------------------------------------

/// A notification delivered to one user.
class DeliveredNotification {
  const DeliveredNotification(this.uid, this.notification);
  final String uid;
  final AppNotification notification;
}

/// In-memory inboxes for local mode. Mirrors the notifications Cloud
/// Function (functions/notifications/src/events.ts): a new pending booking
/// is 'created', a new confirmed one 'confirmed', and status changes become
/// confirmed / cancelled / started / completed. The customer, the barber's
/// account(s) and the shop owner are notified, except that whoever cancels
/// is not told about their own cancellation. Reminders are server-only.
class LocalNotificationInbox {
  final Map<String, List<AppNotification>> _inboxes = {};

  /// Last seen status of every booking; null until the first [observe].
  Map<String, BookingStatus>? _known;

  /// Last seen reschedule count of every booking (reschedule notifications).
  final Map<String, int> _knownReschedules = {};

  /// Last seen refund status of every booking (refund notices).
  final Map<String, RefundStatus?> _knownRefunds = {}; // refunds

  /// Newest first.
  List<AppNotification> inboxFor(String uid) => List.unmodifiable(_inboxes[uid] ?? const []);

  void clear() {
    _inboxes.clear();
    _known = null;
    _knownReschedules.clear();
    _knownRefunds.clear(); // refunds
  }

  void markRead(String uid, String id) {
    final list = _inboxes[uid];
    if (list == null) return;
    final i = list.indexWhere((n) => n.id == id);
    if (i >= 0) list[i] = list[i].copyWith(read: true);
  }

  // --- subscription receipts ---
  /// Puts [notification] in [uid]'s inbox (newest first; ignored when an
  /// entry with the same id is already there). Used for entries that are
  /// not booking events, e.g. an admin's receipt decision.
  void addDirect(String uid, AppNotification notification) {
    final inbox = _inboxes.putIfAbsent(uid, () => []);
    if (inbox.any((n) => n.id == notification.id)) return;
    inbox.insert(0, notification);
  }
  // --- end subscription receipts ---

  /// Compares the repository's bookings with the last call and delivers the
  /// resulting notifications. With nobody signed in ([actor] null) changes
  /// are not notified (that is a dataset load), only remembered.
  List<DeliveredNotification> observe(AppRepository repo, {required AppUser? actor, DateTime? now}) {
    final bookings = repo.getAllBookings();
    final previous = _known;
    _known = {for (final b in bookings) b.id: b.status};
    final previousReschedules = Map.of(_knownReschedules);
    _knownReschedules
      ..clear()
      ..addAll({for (final b in bookings) b.id: b.rescheduleCount});
    final previousRefunds = Map.of(_knownRefunds); // refunds
    _knownRefunds
      ..clear()
      ..addAll({for (final b in bookings) b.id: b.refund?.status});
    if (previous == null || actor == null) return const [];

    final delivered = <DeliveredNotification>[];
    for (final booking in bookings) {
      // --- refunds: the customer hears when a refund is due / was sent ---
      final refund = booking.refund;
      if (refund != null && previousRefunds[booking.id] != refund.status && booking.customerId.isNotEmpty) {
        final language = repo.getAllUsers().where((u) => u.uid == booking.customerId).firstOrNull?.language;
        final notice = refund.isDue
            ? refundDueNotice(booking, refund, language: language)
            : refundedNotice(booking, refund.amount, refund.refundedAt ?? DateTime.now(), language: language);
        final inbox = _inboxes.putIfAbsent(notice.recipientUid, () => []);
        if (!inbox.any((n) => n.id == notice.id)) {
          final n = notice.toAppNotification();
          inbox.insert(0, n);
          delivered.add(DeliveredNotification(notice.recipientUid, n));
        }
      }
      // --- end refunds ---
      final before = previousReschedules[booking.id];
      if (before != null && booking.rescheduleCount > before && booking.status != BookingStatus.cancelled) {
        // One notification per reschedule (functions: {bookingId}_r{count}).
        delivered.addAll(deliver(
          booking,
          NotificationTypes.rescheduled,
          users: repo.getAllUsers(),
          shop: repo.getShopById(booking.shopId),
          actor: actor,
          now: now,
          entityId: '${booking.id}_r${booking.rescheduleCount}',
        ));
      }
      final type = bookingEventType(previous[booking.id], booking.status, isNew: !previous.containsKey(booking.id));
      if (type == null) continue;
      // Shop deletion: the cascade already wrote the customer a notice.
      if (type == NotificationTypes.cancelled && booking.cancelReason == kShopDeletedCancelReason) continue;
      delivered.addAll(deliver(
        booking,
        type,
        users: repo.getAllUsers(),
        shop: repo.getShopById(booking.shopId),
        actor: actor,
        now: now,
      ));
      // --- early finish ---
      if (type == NotificationTypes.completed && booking.completedAt != null) {
        delivered.addAll(deliverEarlyFinish(booking, bookings, users: repo.getAllUsers()));
      }
      // --- end early finish ---
    }
    return delivered;
  }

  // --- early finish ---
  /// Local mirror of the staff app's early-finish batch: when [completed]
  /// was finished before its scheduled end, the barber's later confirmed
  /// customers today get `{bookingId}_early_{completedId}` (idempotent).
  List<DeliveredNotification> deliverEarlyFinish(Booking completed, Iterable<Booking> bookings,
      {required List<AppUser> users}) {
    final completedAt = completed.completedAt;
    if (completedAt == null) return const [];
    final languages = {for (final u in users) u.uid: u.language};
    final delivered = <DeliveredNotification>[];
    for (final notice in planEarlyFinishNotices(completed, bookings, completedAt, languageOf: (uid) => languages[uid])) {
      final inbox = _inboxes.putIfAbsent(notice.recipientUid, () => []);
      if (inbox.any((n) => n.id == notice.id)) continue;
      final n = AppNotification(
        id: notice.id,
        title: notice.title,
        body: notice.body,
        type: notice.type,
        bookingId: notice.bookingId,
        createdAt: notice.createdAt,
        minutesEarly: notice.minutesEarly,
      );
      inbox.insert(0, n);
      delivered.add(DeliveredNotification(notice.recipientUid, n));
    }
    return delivered;
  }
  // --- end early finish ---

  /// Delivers [type] for [booking] to its recipients' inboxes (idempotent per
  /// user, like the Cloud Function's `{bookingId}_{type}` doc id).
  List<DeliveredNotification> deliver(
    Booking booking,
    String type, {
    required List<AppUser> users,
    required Barbershop? shop,
    required AppUser? actor,
    DateTime? now,
    String? entityId,
  }) {
    var recipients = bookingRecipients(booking, users: users, shop: shop);
    // No-show: the customer only (inbox/push, no SMS).
    if (type == NotificationTypes.noShow) {
      recipients = recipients.where((r) => r.audience == NotificationAudience.customer).toList();
    }
    final cancelActor = type == NotificationTypes.cancelled && actor != null
        ? cancelActorFor(actor, booking, recipients)
        : null;

    final delivered = <DeliveredNotification>[];
    for (final r in recipients) {
      if ((type == NotificationTypes.cancelled || type == NotificationTypes.rescheduled) && r.uid == actor?.uid) {
        continue;
      }
      final id = '${entityId ?? booking.id}_$type';
      final inbox = _inboxes.putIfAbsent(r.uid, () => []);
      if (inbox.any((n) => n.id == id)) continue;
      final language = users.where((u) => u.uid == r.uid).firstOrNull?.language;
      final text = renderBookingNotification(type, r.audience, booking, cancelledBy: cancelActor, language: language);
      final n = AppNotification(
        id: id,
        title: text.title,
        body: text.body,
        type: type,
        bookingId: booking.id,
        createdAt: (now ?? DateTime.now()).toUtc(),
      );
      inbox.insert(0, n);
      delivered.add(DeliveredNotification(r.uid, n));
    }
    return delivered;
  }
}

/// The notification for a booking status transition, or null.
String? bookingEventType(BookingStatus? before, BookingStatus after, {required bool isNew}) {
  if (isNew) {
    switch (after) {
      case BookingStatus.pending:
        return NotificationTypes.created;
      case BookingStatus.confirmed:
        return NotificationTypes.confirmed;
      default:
        return null;
    }
  }
  if (before == after) return null;
  switch (after) {
    case BookingStatus.confirmed:
      return NotificationTypes.confirmed;
    case BookingStatus.cancelled:
      return NotificationTypes.cancelled;
    case BookingStatus.inProgress:
      return NotificationTypes.started;
    case BookingStatus.completed:
      return NotificationTypes.completed;
    case BookingStatus.noShow:
      return NotificationTypes.noShow;
    case BookingStatus.pending:
      return null;
  }
}

enum NotificationAudience { customer, barber, owner }

class NotificationRecipient {
  const NotificationRecipient(this.uid, this.audience);
  final String uid;
  final NotificationAudience audience;
}

/// Customer, the barber's user account(s) and the shop owner, de-duplicated
/// (first role wins).
List<NotificationRecipient> bookingRecipients(Booking booking, {required List<AppUser> users, Barbershop? shop}) {
  final result = <NotificationRecipient>[];
  final seen = <String>{};
  void add(String uid, NotificationAudience audience) {
    if (uid.isEmpty || !seen.add(uid)) return;
    result.add(NotificationRecipient(uid, audience));
  }

  add(booking.customerId, NotificationAudience.customer);
  for (final u in users) {
    if (u.role == UserRole.barber && u.barberId == booking.barberId && u.shopId == booking.shopId) {
      add(u.uid, NotificationAudience.barber);
    }
  }
  if (shop != null) add(shop.ownerId, NotificationAudience.owner);
  return result;
}

/// 'customer' | 'barber' | 'shop' | 'admin' | null, as in the backend.
String? cancelActorFor(AppUser actor, Booking booking, List<NotificationRecipient> recipients) {
  if (actor.uid == booking.customerId) return 'customer';
  for (final r in recipients) {
    if (r.uid != actor.uid) continue;
    if (r.audience == NotificationAudience.barber) return 'barber';
    if (r.audience == NotificationAudience.owner) return 'shop';
  }
  if (actor.role == UserRole.admin) return 'admin';
  return null;
}

/// Copy matching functions/notifications/src/templates.ts, in the
/// recipient's language ('en' or 'am'; anything else is English).
({String title, String body}) renderBookingNotification(
  String type,
  NotificationAudience audience,
  Booking b, {
  String? cancelledBy,
  String? language,
}) {
  if (language == 'am') return _renderAmharic(type, audience, b, cancelledBy: cancelledBy);
  final customer = audience == NotificationAudience.customer;
  final shop = b.shopName.isEmpty ? 'Crown & Blade' : b.shopName;
  final barber = b.barberName.isEmpty ? 'your barber' : b.barberName;
  final client = b.customerName.isEmpty ? 'A customer' : b.customerName;
  final service = b.serviceName.isEmpty ? 'service' : b.serviceName;
  final when = formatAddisWhen(b.startAt);
  final price = ' Price: ${formatEtb(b.price)}.';
  final by = switch (cancelledBy) {
    'customer' => customer ? ' by you' : ' by the customer',
    'barber' => ' by the barber',
    'shop' => ' by the shop',
    'admin' => ' by an administrator',
    _ => '',
  };

  switch (type) {
    case NotificationTypes.created:
      return customer
          ? (
              // barber acceptance: matches templates.ts 'created'
              title: 'Booking request sent',
              body: "Your request for $service with $barber at $shop on $when has been sent. We'll let you know when $barber accepts.$price"
            )
          : (title: 'New booking request', body: '$client booked $service with $barber on $when.');
    case NotificationTypes.confirmed:
      return customer
          ? (title: 'Booking confirmed', body: 'Your $service with $barber at $shop on $when is confirmed.$price')
          : (title: 'Booking confirmed', body: '$client - $service with $barber on $when.');
    case NotificationTypes.cancelled:
      return customer
          ? (title: 'Booking cancelled', body: 'Your $service at $shop on $when was cancelled$by.')
          : (title: 'Booking cancelled', body: '$client: $service with $barber on $when was cancelled$by.');
    case NotificationTypes.started:
      return customer
          ? (title: 'Your appointment has started', body: '$barber has started your $service at $shop.')
          : (title: 'Appointment started', body: '$barber started $service for $client.');
    case NotificationTypes.completed:
      return customer
          ? (
              title: 'Thanks for visiting',
              body: 'Your $service at $shop is complete.$price We hope to see you again!'
            )
          : (title: 'Appointment completed', body: '$barber completed $service for $client.$price');
    case NotificationTypes.rescheduled:
      return customer
          ? (title: 'Booking moved', body: 'Your $service with $barber at $shop is now on $when.')
          : (title: 'Booking moved', body: '$client moved $service with $barber to $when.');
    case NotificationTypes.noShow:
      return (
        title: 'Missed appointment',
        body: 'You were marked as a no-show for your $service at $shop on $when. Please book again when you are ready.'
      );
    default:
      return (title: 'Booking update', body: '$service with $barber on $when.');
  }
}

({String title, String body}) _renderAmharic(
  String type,
  NotificationAudience audience,
  Booking b, {
  String? cancelledBy,
}) {
  final customer = audience == NotificationAudience.customer;
  final shop = b.shopName.isEmpty ? 'Crown & Blade' : b.shopName;
  final barber = b.barberName.isEmpty ? 'ፀጉር አስተካካይ' : b.barberName;
  final client = b.customerName.isEmpty ? 'ደንበኛ' : b.customerName;
  final service = b.serviceName.isEmpty ? 'አገልግሎት' : b.serviceName;
  final when = formatAddisWhen(b.startAt, language: 'am');
  final price = ' ዋጋ፦ ${formatEtb(b.price, language: 'am')}።';
  final by = switch (cancelledBy) {
    'customer' => customer ? ' በእርስዎ' : ' በደንበኛው',
    'barber' => ' በፀጉር አስተካካዩ',
    'shop' => ' በፀጉር ቤቱ',
    'admin' => ' በአስተዳዳሪ',
    _ => '',
  };

  switch (type) {
    case NotificationTypes.created:
      return customer
          ? (
              title: 'የቀጠሮ ጥያቄዎ ተልኳል',
              body: '$shop ላይ ከ$barber ጋር $when ለ$service ያቀረቡት ጥያቄ ተልኳል። $barber ሲቀበሉ እናሳውቅዎታለን።$price'
            )
          : (title: 'አዲስ የቀጠሮ ጥያቄ', body: '$client ከ$barber ጋር $when ለ$service ቀጠሮ ጠይቀዋል።');
    case NotificationTypes.confirmed:
      return customer
          ? (title: 'ቀጠሮዎ ተረጋግጧል', body: '$shop ላይ ከ$barber ጋር $when ያለዎት የ$service ቀጠሮ ተረጋግጧል።$price')
          : (title: 'ቀጠሮ ተረጋግጧል', body: '$client - $service ከ$barber ጋር $when።');
    case NotificationTypes.cancelled:
      return customer
          ? (title: 'ቀጠሮዎ ተሰርዟል', body: '$shop ላይ $when የነበረዎት የ$service ቀጠሮ$by ተሰርዟል።')
          : (title: 'ቀጠሮ ተሰርዟል', body: '$client፦ የ$service ቀጠሮ ($barber፣ $when)$by ተሰርዟል።');
    case NotificationTypes.started:
      return customer
          ? (title: 'አገልግሎትዎ ተጀምሯል', body: '$barber $shop ላይ የ$service አገልግሎትዎን ጀምረዋል።')
          : (title: 'አገልግሎት ተጀምሯል', body: '$barber ለ$client የ$service አገልግሎት ጀምረዋል።');
    case NotificationTypes.completed:
      return customer
          ? (title: 'ስለመጡ እናመሰግናለን', body: '$shop ላይ የ$service አገልግሎትዎ ተጠናቋል።$price በድጋሚ እንጠብቅዎታለን!')
          : (title: 'አገልግሎት ተጠናቋል', body: '$barber ለ$client የ$service አገልግሎት አጠናቀዋል።$price');
    case NotificationTypes.rescheduled:
      return customer
          ? (title: 'ቀጠሮዎ ተዛውሯል', body: '$shop ላይ ከ$barber ጋር ያለዎት የ$service ቀጠሮ ወደ $when ተዛውሯል።')
          : (title: 'ቀጠሮ ተዛውሯል', body: '$client ከ$barber ጋር ያላቸውን የ$service ቀጠሮ ወደ $when አዛውረዋል።');
    case NotificationTypes.noShow:
      return (
        title: 'ቀጠሮ አምልጦዎታል',
        body: '$shop ላይ $when የነበረዎት የ$service ቀጠሮ ላይ እንዳልመጡ ተመዝግቧል። ሲመችዎ እንደገና ቀጠሮ ይያዙ።'
      );
    default:
      return (title: 'የቀጠሮ ለውጥ', body: '$service ከ$barber ጋር $when።');
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysAm = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሁድ'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Traditional Ethiopian clock reading (the day starts at 6:00): 10:30 is
/// 'ጠዋት 4:30'.
String ethiopianClock(int hour, int minute) {
  final ethHour = (hour + 6) % 12 == 0 ? 12 : (hour + 6) % 12;
  final period = hour < 6
      ? 'ሌሊት'
      : hour < 12
          ? 'ጠዋት'
          : hour < 18
              ? 'ከሰዓት'
              : 'ማታ';
  return '$period $ethHour:${_two(minute)}';
}

/// 'Fri 13 Nov 2026, 10:30' on the Addis Ababa wall clock; in Amharic
/// 'ዓርብ 13/11/2026 10:30 (ጠዋት 4:30)'.
String formatAddisWhen(DateTime instant, {String? language}) {
  final t = toAddisWallClock(instant);
  final time = '${_two(t.hour)}:${_two(t.minute)}';
  if (language == 'am') {
    return '${_weekdaysAm[t.weekday - 1]} ${_two(t.day)}/${_two(t.month)}/${t.year} $time (${ethiopianClock(t.hour, t.minute)})';
  }
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} ${t.year}, $time';
}

/// '1,250 ETB' (Amharic: '1,250 ብር').
String formatEtb(double amount, {String? language}) {
  final rounded = (amount * 100).round() / 100;
  final isWhole = rounded == rounded.roundToDouble();
  final fixed = rounded.toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final number = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  return language == 'am' ? '$number ብር' : '$number ETB';
}
