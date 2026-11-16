/// Admin shop deletion: the cascade that removes everything a barbershop
/// leaves behind, run by the admin's app (works on the free Spark plan).
///
/// Order (each step is safe to run again; a failed step is retried by
/// running the whole cascade again):
///  1. [ShopDeletionStep.prepare]: record `shopDeletions/{shopId}` (who and
///     which staff accounts, for the Blaze-only `onShopDeleted` function)
///     and suspend the shop (no new bookings or queue joins meanwhile).
///  2. [ShopDeletionStep.bookings]: upcoming bookings (pending/confirmed,
///     starting now or later) are cancelled with
///     `cancelReason: 'shop_deleted'`, and each customer gets an inbox
///     notice `{bookingId}_shopDeleted`, in the same batch. Past bookings
///     stay for history.
///  3. [ShopDeletionStep.staff]: the owner and every barber
///     (`users where shopId == id`) become customers (role 'customer',
///     shopId/barberId removed) with an inbox notice `shopRemoved_{shopId}`
///     in the same batch; every invite of the shop is deleted.
///  4. [ShopDeletionStep.data]: the shop's subcollections, which Firestore
///     does not delete with the shop document ([kShopSubcollections], and
///     [kBarberSubcollections] under every barber), in chunks.
///  5. [ShopDeletionStep.shop]: the shop document itself, last (the rules
///     of the steps above may read it).
///
/// Firebase Auth logins of other users cannot be deleted from a client: on
/// Spark the staff keep their login, as customers. With Cloud Functions
/// (Blaze) functions/auth `onShopDeleted` repeats the cascade and deletes
/// the logins the owner created for barbers (temporary-password accounts).
///
/// Pure logic, no Flutter or Firebase (unit tested).
library;

import '../data/addis_time.dart';
import '../models/app_notification.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';

/// `bookings/{id}.cancelReason` of a booking cancelled because its shop was
/// deleted.
const String kShopDeletedCancelReason = 'shop_deleted';

/// The admin suspension reason set while the cascade runs.
const String kShopDeletionSuspendReason = 'This barbershop is being removed.';

/// Subcollections of `barbershops/{id}` deleted by the cascade (the
/// `barbers` subcollection is handled separately, see [kBarberSubcollections]).
const List<String> kShopSubcollections = [
  'services',
  'queue',
  'queueSummary',
  'reviews',
  'stats',
  'clients',
  'payouts',
  'blockedCustomers', // customer blocks
  'settings', // customer blocks: settings/customerBlocks
];

/// Subcollections of `barbershops/{id}/barbers/{barberId}` deleted before the
/// barber document.
const List<String> kBarberSubcollections = ['slotLocks', 'timeOff', 'private'];

/// Plain deletes per batch (well below Firestore's 500 writes per batch and
/// the rules' budget of evaluated expressions per request).
const int kShopDeletionDeleteChunk = 100;

/// Bookings cancelled per batch (each also writes its customer's notice).
const int kShopDeletionBookingChunk = 5;

/// Staff accounts downgraded per batch (each also writes its notice).
const int kShopDeletionStaffChunk = 5;

/// `shopDeletions/{shopId}`: the record the admin's app writes first.
const String kShopDeletionsCollection = 'shopDeletions';

/// The cascade's steps, in order.
enum ShopDeletionStep { prepare, bookings, staff, data, shop }

/// A step of the cascade failed. Everything done before it stays done; the
/// cascade can simply be run again.
class ShopDeletionException implements Exception {
  const ShopDeletionException(this.step, this.cause);
  final ShopDeletionStep step;
  final Object cause;

  @override
  String toString() => 'ShopDeletionException(${step.name}: $cause)';
}

/// What a delete will remove, for the confirmation dialog.
class ShopDeletionPreview {
  const ShopDeletionPreview({
    required this.barbers,
    required this.services,
    required this.staffAccounts,
    required this.pendingInvites,
    this.upcomingBookings,
  });

  final int barbers;
  final int services;

  /// Owner and barber accounts that become customers.
  final int staffAccounts;
  final int pendingInvites;

  /// Upcoming bookings to cancel; null when they could not be counted.
  final int? upcomingBookings;
}

/// `users/{uid}/notifications/{id}` written by the admin's app during the
/// cascade (see [toMap] for the exact keys).
class ShopDeletionNotice {
  const ShopDeletionNotice({
    required this.id,
    required this.recipientUid,
    required this.type,
    required this.title,
    required this.body,
    required this.shopId,
    required this.createdAt,
    this.bookingId,
  });

  final String id;
  final String recipientUid;

  /// [NotificationTypes.shopDeleted] or [NotificationTypes.shopRemoved].
  final String type;
  final String title;
  final String body;
  final String shopId;

  /// shopDeleted only: the cancelled booking.
  final String? bookingId;

  /// UTC.
  final DateTime createdAt;

  /// Exactly `{type, title, body, shopId, bookingId?, read: false, createdAt}`.
  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'body': body,
        'shopId': shopId,
        if (bookingId != null) 'bookingId': bookingId,
        'read': false,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  AppNotification toAppNotification() => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        bookingId: bookingId,
        createdAt: createdAt.toUtc(),
      );
}

/// An upcoming booking to cancel, with its customer's notice.
class ShopBookingCancellation {
  const ShopBookingCancellation(this.booking, this.notice);
  final Booking booking;
  final ShopDeletionNotice notice;
}

/// A staff account to downgrade, with its notice.
class ShopStaffRevocation {
  const ShopStaffRevocation(this.user, this.notice);

  /// The account as it is now (owner or barber of the shop).
  final AppUser user;
  final ShopDeletionNotice notice;
}

/// `shopDeletions/{shopId}`: written (merged) at the start of every run.
class ShopDeletionRecord {
  const ShopDeletionRecord({
    required this.shopId,
    required this.shopName,
    required this.requestedBy,
    required this.requestedAt,
    required this.staffUids,
    required this.barberAccountUids,
  });

  final String shopId;
  final String shopName;

  /// The admin's uid.
  final String requestedBy;

  /// UTC.
  final DateTime requestedAt;

  /// Owner and barber accounts of the shop (users with shopId == shopId).
  final List<String> staffUids;

  /// Barber logins (signed-in barbers and the `authUid` of pending barber
  /// invites): the function deletes those the owner created with a
  /// temporary password.
  final List<String> barberAccountUids;
}

/// Inbox id of the notice about [bookingId] (idempotent per booking).
String shopDeletedNoticeId(String bookingId) => '${bookingId}_shopDeleted';

/// Inbox id of the notice to a staff member of [shopId].
String shopRemovedNoticeId(String shopId) => 'shopRemoved_$shopId';

/// Whether [booking] is cancelled by deleting [shopId] at [nowUtc]: the
/// shop's pending or confirmed bookings starting at or after now.
bool isCancelledByShopDeletion(Booking booking, String shopId, DateTime nowUtc) =>
    booking.shopId == shopId &&
    (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed) &&
    !booking.startAt.isBefore(nowUtc.toUtc());

/// [user] as a customer: role 'customer', no shopId or barberId (the rules
/// require exactly that for customers). Everything else is kept.
AppUser downgradedToCustomer(AppUser user) => AppUser(
      uid: user.uid,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: UserRole.customer,
      createdAt: user.createdAt,
      language: user.language,
      mustChangePassword: user.mustChangePassword,
    );

/// The cancellations for [bookings] (only those [isCancelledByShopDeletion]),
/// soonest first. [languageOf] gives a customer's language ('en'; anything
/// else is Amharic).
List<ShopBookingCancellation> planShopBookingCancellations(
  String shopId,
  Iterable<Booking> bookings,
  DateTime nowUtc, {
  String? Function(String uid)? languageOf,
}) {
  final list = bookings.where((b) => isCancelledByShopDeletion(b, shopId, nowUtc) && b.customerId.isNotEmpty).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  return [
    for (final b in list)
      () {
        final text = renderShopDeletedText(b, language: languageOf?.call(b.customerId));
        return ShopBookingCancellation(
          b,
          ShopDeletionNotice(
            id: shopDeletedNoticeId(b.id),
            recipientUid: b.customerId,
            type: NotificationTypes.shopDeleted,
            title: text.title,
            body: text.body,
            shopId: shopId,
            bookingId: b.id,
            createdAt: nowUtc.toUtc(),
          ),
        );
      }(),
  ];
}

/// The revocations for the shop's staff accounts in [users] (owner and
/// barbers whose shopId is [shopId]; admins and customers are never
/// touched).
List<ShopStaffRevocation> planShopStaffRevocations(
  String shopId,
  String shopName,
  Iterable<AppUser> users,
  DateTime nowUtc,
) {
  return [
    for (final u in users)
      if (u.shopId == shopId && (u.role == UserRole.barbershopOwner || u.role == UserRole.barber))
        () {
          final text = renderShopRemovedText(shopName, language: u.language);
          return ShopStaffRevocation(
            u,
            ShopDeletionNotice(
              id: shopRemovedNoticeId(shopId),
              recipientUid: u.uid,
              type: NotificationTypes.shopRemoved,
              title: text.title,
              body: text.body,
              shopId: shopId,
              createdAt: nowUtc.toUtc(),
            ),
          );
        }(),
  ];
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Copy of the customer's notice (matches functions/auth shopDeletion.ts).
({String title, String body}) renderShopDeletedText(Booking booking, {String? language}) {
  final t = toAddisWallClock(booking.startAt);
  final when = '${_two(t.day)}/${_two(t.month)}/${t.year} ${_two(t.hour)}:${_two(t.minute)}';
  final shop = booking.shopName.trim().isEmpty ? null : booking.shopName.trim();
  if (language == 'en') {
    return (
      title: 'Appointment cancelled',
      body: '${shop ?? 'Your barbershop'} is no longer on Crown & Blade, so your appointment on $when '
          'was cancelled. Please book at another barbershop.',
    );
  }
  return (
    title: 'ቀጠሮዎ ተሰርዟል',
    body: '${shop ?? 'ፀጉር ቤቱ'} ከCrown & Blade ስለተወገደ በ$when የነበረዎት ቀጠሮ ተሰርዟል። '
        'እባክዎ በሌላ ፀጉር ቤት ቀጠሮ ይያዙ።',
  );
}

/// Copy of the staff notice (matches functions/auth shopDeletion.ts).
({String title, String body}) renderShopRemovedText(String shopName, {String? language}) {
  final shop = shopName.trim().isEmpty ? null : shopName.trim();
  if (language == 'en') {
    return (
      title: 'Your barbershop was removed',
      body: '${shop ?? 'Your barbershop'} was removed from Crown & Blade. '
          'You can keep using the app as a customer.',
    );
  }
  return (
    title: 'ፀጉር ቤትዎ ተወግዷል',
    body: '${shop ?? 'ፀጉር ቤትዎ'} ከCrown & Blade ተወግዷል። መተግበሪያውን እንደ ደንበኛ መጠቀም ይችላሉ።',
  );
}

/// Splits [items] into lists of at most [size].
List<List<T>> chunked<T>(List<T> items, int size) => [
      for (var i = 0; i < items.length; i += size) items.sublist(i, i + size > items.length ? items.length : i + size),
    ];
