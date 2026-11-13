import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/addis_time.dart';
import '../models/app_notification.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import 'app_repository.dart';

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
    _onRepositoryChanged();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepositoryChanged);
    if (_repo.beforeSignOut == _beforeSignOut) _repo.beforeSignOut = null;
    _inboxSub?.cancel();
    _push?.stop();
    super.dispose();
  }

  void _onRepositoryChanged() {
    final user = _repo.authStatus == AuthStatus.signedIn ? _repo.currentUser : null;

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
    final fresh = _firstSnapshot ? const <AppNotification>[] : items.where((n) => !known.contains(n.id) && !n.read);
    _firstSnapshot = false;
    _items = items;
    notifyListeners();
    for (final n in fresh) {
      _announce(n);
    }
  }

  void _announce(AppNotification n) {
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
      action: SnackBarAction(label: 'View', onPressed: openInbox),
    ));
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
    // ignore: deprecated_member_use
    final token = await _messaging.getToken(vapidKey: platform == 'web' ? kFcmVapidKey : null);
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

  /// Newest first.
  List<AppNotification> inboxFor(String uid) => List.unmodifiable(_inboxes[uid] ?? const []);

  void clear() {
    _inboxes.clear();
    _known = null;
  }

  void markRead(String uid, String id) {
    final list = _inboxes[uid];
    if (list == null) return;
    final i = list.indexWhere((n) => n.id == id);
    if (i >= 0) list[i] = list[i].copyWith(read: true);
  }

  /// Compares the repository's bookings with the last call and delivers the
  /// resulting notifications. With nobody signed in ([actor] null) changes
  /// are not notified (that is a dataset load), only remembered.
  List<DeliveredNotification> observe(AppRepository repo, {required AppUser? actor, DateTime? now}) {
    final bookings = repo.getAllBookings();
    final previous = _known;
    _known = {for (final b in bookings) b.id: b.status};
    if (previous == null || actor == null) return const [];

    final delivered = <DeliveredNotification>[];
    for (final booking in bookings) {
      final type = bookingEventType(previous[booking.id], booking.status, isNew: !previous.containsKey(booking.id));
      if (type == null) continue;
      delivered.addAll(deliver(
        booking,
        type,
        users: repo.getAllUsers(),
        shop: repo.getShopById(booking.shopId),
        actor: actor,
        now: now,
      ));
    }
    return delivered;
  }

  /// Delivers [type] for [booking] to its recipients' inboxes (idempotent per
  /// user, like the Cloud Function's `{bookingId}_{type}` doc id).
  List<DeliveredNotification> deliver(
    Booking booking,
    String type, {
    required List<AppUser> users,
    required Barbershop? shop,
    required AppUser? actor,
    DateTime? now,
  }) {
    final recipients = bookingRecipients(booking, users: users, shop: shop);
    final cancelActor = type == NotificationTypes.cancelled && actor != null
        ? cancelActorFor(actor, booking, recipients)
        : null;

    final delivered = <DeliveredNotification>[];
    for (final r in recipients) {
      if (type == NotificationTypes.cancelled && r.uid == actor?.uid) continue;
      final id = '${booking.id}_$type';
      final inbox = _inboxes.putIfAbsent(r.uid, () => []);
      if (inbox.any((n) => n.id == id)) continue;
      final text = renderBookingNotification(type, r.audience, booking, cancelledBy: cancelActor);
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

/// English copy matching functions/notifications/src/templates.ts.
({String title, String body}) renderBookingNotification(
  String type,
  NotificationAudience audience,
  Booking b, {
  String? cancelledBy,
}) {
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
              title: 'Booking request received',
              body: 'Your $service with $barber at $shop on $when is waiting for confirmation.$price'
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
    default:
      return (title: 'Booking update', body: '$service with $barber on $when.');
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 'Fri 13 Nov 2026, 10:30' on the Addis Ababa wall clock.
String formatAddisWhen(DateTime instant) {
  final t = toAddisWallClock(instant);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} ${t.year}, ${two(t.hour)}:${two(t.minute)}';
}

/// '1,250 ETB'.
String formatEtb(double amount) {
  final rounded = (amount * 100).round() / 100;
  final isWhole = rounded == rounded.roundToDouble();
  final fixed = rounded.toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${parts.length > 1 ? '$grouped.${parts[1]}' : grouped} ETB';
}
