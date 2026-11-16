/// In-app account deletion (Settings > Delete account; Google Play and the
/// App Store require it). Pure logic (the clock is a parameter) shared by
/// AppRepository, the screens and the tests. The writes are in
/// account_deletion_writes.dart; functions/auth `onUserProfileDeleted`
/// (Blaze only) repeats the clean-up on the server.
///
/// What deleting an account does (works on the free Spark plan):
///  1. The person confirms by typing DELETE and signs in again (Firebase
///     only deletes a login after a recent sign-in: Google or password).
///  2. Their upcoming bookings are cancelled with the normal customer cancel
///     (before the shop's cutoff; a paid one gets its refund flag in the same
///     write). Bookings already inside the cutoff cannot be cancelled by a
///     customer; they stay with the shop (anonymised, see 4) and, on Blaze,
///     the server cancels them.
///  3. Barbers: their own upcoming bookings are cancelled as a barber cancel
///     (customers get an inbox notice), then their portfolio photos, barber
///     profile and its private contact are removed from the shop.
///  4. Reviews they wrote keep their stars (barber ratings stay correct) and
///     the owner's reply, but the name becomes "Former customer" and the
///     comment is removed: free text can identify the person, and nobody
///     could edit or delete it after the account is gone. Their bookings
///     keep the visit (the shop's history and earnings) with the name
///     "Former customer" and no phone, except bookings with a refund still
///     due (the shop needs the phone to send the money back).
///  5. Their invite, shop application, inbox, device tokens and favourites
///     are deleted, then `users/{uid}`, then the Firebase Auth login.
///
/// Who cannot delete yet:
///  * A shop owner while their shop exists: they ask the admin to remove the
///    shop ([ShopRemovalRequest]); once the shop is deleted they are a
///    customer and can delete the account.
///  * The last enabled admin.
library;

import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/review_model.dart' show kFormerCustomerReviewName;
import '../models/user_model.dart';
import 'booking_policy.dart' as policy;

/// The name that replaces a deleted person's name on their bookings and
/// reviews. Firestore rules accept exactly this value (see the handoff).
const String kFormerCustomerName = kFormerCustomerReviewName;

/// What the person types to confirm (any letter case, surrounding spaces
/// ignored).
const String kDeleteConfirmationWord = 'DELETE';

/// cancelReason the Blaze function writes when it cancels a deleted
/// customer's bookings that the app could not (inside the cutoff).
const String kAccountDeletedCancelReason = 'account_deleted';

/// Bookings / reviews anonymised per batch (one update each).
const int kAccountDeletionChunk = 100;

/// Longest note an owner adds to a shop removal request.
const int kShopRemovalNoteMaxLength = 500;

/// Firestore collection of owners' "please remove my shop" requests.
const String kShopRemovalRequestsCollection = 'shopRemovalRequests';

bool isDeleteConfirmation(String typed) => typed.trim().toUpperCase() == kDeleteConfirmationWord;

/// Why an account cannot be deleted right now.
enum AccountDeletionBlocker {
  /// A shop owner whose shop still exists.
  ownsShop,

  /// The only enabled admin.
  lastAdmin,
}

/// The parts of the deletion, in order (for progress and errors).
enum AccountDeletionStep {
  cancelBookings,
  anonymizeReviews,
  anonymizeBookings,
  leaveShop,
  deletePersonalData,
  deleteProfile,
  deleteLogin,
}

enum AccountDeletionError {
  notSignedIn,
  confirmationMismatch,
  ownsShop,
  lastAdmin,

  /// Firebase wants a fresh sign-in before deleting the login.
  reauthRequired,

  /// The re-authentication was cancelled (Google window closed).
  reauthCancelled,

  /// A step failed; [AccountDeletionException.step] names it.
  stepFailed,

  /// Shop removal requests: the note is too long.
  noteTooLong,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.error, {this.step, this.cause});

  final AccountDeletionError error;
  final AccountDeletionStep? step;
  final Object? cause;

  @override
  String toString() => 'AccountDeletionException($error, step: $step, cause: $cause)';
}

/// Whether [booking] is one of [uid]'s own upcoming bookings (as the
/// customer): pending or confirmed and not started yet.
bool isOwnUpcoming(Booking booking, String uid, DateTime nowUtc) =>
    booking.customerId == uid &&
    policy.isChangeableStatus(booking.status) &&
    !booking.startAt.toUtc().isBefore(nowUtc.toUtc());

/// Whether a barber ([user]) cancels [booking] when deleting their account:
/// one of their own pending/confirmed bookings that has not started.
bool isBarberUpcoming(Booking booking, AppUser user, DateTime nowUtc) =>
    user.role == UserRole.barber &&
    user.barberId != null &&
    booking.barberId == user.barberId &&
    booking.shopId == user.shopId &&
    booking.customerId != user.uid &&
    policy.canBarberCancel(booking, nowUtc);

/// Whether a booking keeps its customer's name and phone: a refund is still
/// due, and the shop needs the number to send the money back. That includes
/// a paid booking that is still pending/confirmed (inside the cutoff, so the
/// app could not cancel it): it is refunded when it gets cancelled (on
/// Blaze by functions/auth onUserProfileDeleted, which flags the refund).
bool keepsContactForRefund(Booking booking) =>
    (booking.refund?.isDue ?? false) ||
    (booking.paymentStatus == PaymentStatus.paid &&
        booking.refund == null &&
        policy.isChangeableStatus(booking.status));

/// The shop [user] owns that blocks the deletion, if any: the shop on their
/// profile, or any loaded shop whose ownerId is theirs.
Barbershop? ownedShopOf(AppUser user, Map<String, Barbershop> shops) {
  if (user.role != UserRole.barbershopOwner) return null;
  final own = user.shopId == null ? null : shops[user.shopId];
  if (own != null) return own;
  for (final shop in shops.values) {
    if (shop.ownerId == user.uid) return shop;
  }
  return null;
}

/// What deleting [user]'s account would do, for the confirmation screen.
class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.user,
    this.blocker,
    this.ownedShop,
    this.toCancel = const [],
    this.keptInsideCutoff = const [],
    this.barberToCancel = const [],
  });

  final AppUser user;
  final AccountDeletionBlocker? blocker;

  /// The owner's shop (blocker [AccountDeletionBlocker.ownsShop]).
  final Barbershop? ownedShop;

  /// Own upcoming bookings the app cancels (before the shop's cutoff).
  final List<Booking> toCancel;

  /// Own upcoming bookings inside the cutoff: customers cannot cancel them,
  /// so they stay with the shop (anonymised).
  final List<Booking> keptInsideCutoff;

  /// Barbers: their customers' upcoming bookings, cancelled with a notice.
  final List<Booking> barberToCancel;

  bool get canDelete => blocker == null;

  /// Paid bookings among the cancellations (each gets a refund flag).
  int get paidToCancel => [...toCancel, ...barberToCancel].where((b) => b.paymentStatus == PaymentStatus.paid).length;
}

/// Plans [user]'s deletion from the loaded data. [bookings] are the cached
/// bookings (every upcoming booking of the user is loaded by their role's
/// listeners); [users] is used for the last-admin check (admins load all).
AccountDeletionPreview planAccountDeletion({
  required AppUser user,
  required Iterable<Booking> bookings,
  required Map<String, Barbershop> shops,
  required Iterable<AppUser> users,
  required DateTime nowUtc,
}) {
  final owned = ownedShopOf(user, shops);
  if (owned != null) {
    return AccountDeletionPreview(user: user, blocker: AccountDeletionBlocker.ownsShop, ownedShop: owned);
  }
  if (user.role == UserRole.admin &&
      !users.any((u) => u.role == UserRole.admin && !u.disabled && u.uid != user.uid)) {
    return AccountDeletionPreview(user: user, blocker: AccountDeletionBlocker.lastAdmin);
  }
  int bySoonest(Booking a, Booking b) => a.startAt.compareTo(b.startAt);
  final toCancel = <Booking>[];
  final kept = <Booking>[];
  for (final b in bookings) {
    if (!isOwnUpcoming(b, user.uid, nowUtc)) continue;
    final shop = shops[b.shopId];
    // Unknown shop (e.g. deleted): treat as cancellable; the rules decide.
    if (shop == null || policy.isBeforeCutoff(b, shop, nowUtc)) {
      toCancel.add(b);
    } else {
      kept.add(b);
    }
  }
  final barber = [
    for (final b in bookings)
      if (isBarberUpcoming(b, user, nowUtc)) b,
  ];
  return AccountDeletionPreview(
    user: user,
    toCancel: toCancel..sort(bySoonest),
    keptInsideCutoff: kept..sort(bySoonest),
    barberToCancel: barber..sort(bySoonest),
  );
}

/// The `bookings/{id}` update that anonymises a deleted customer's booking:
/// exactly `{customerName: 'Former customer', customerPhone: ''}`.
const Map<String, String> kAnonymizedBookingFields = {
  'customerName': kFormerCustomerName,
  'customerPhone': '',
};

/// Whether [booking] of [uid] still needs anonymising.
bool needsBookingAnonymizing(Booking booking, String uid) =>
    booking.customerId == uid &&
    !keepsContactForRefund(booking) &&
    (booking.customerName != kFormerCustomerName || booking.customerPhone.isNotEmpty);

/// Status of a [ShopRemovalRequest].
enum ShopRemovalStatus {
  pending,
  done,
  dismissed;

  static ShopRemovalStatus fromString(String? v) =>
      ShopRemovalStatus.values.where((s) => s.name == v).firstOrNull ?? ShopRemovalStatus.pending;
}

/// An owner's "please remove my shop so I can delete my account" request:
/// `shopRemovalRequests/{uid}`. The owner creates it (status 'pending') and
/// may withdraw it (delete); the admin lists them, removes the shop with the
/// existing shop deletion and marks the request done or dismissed.
class ShopRemovalRequest {
  const ShopRemovalRequest({
    required this.uid,
    required this.email,
    required this.name,
    required this.shopId,
    required this.shopName,
    this.note,
    this.status = ShopRemovalStatus.pending,
    required this.createdAt,
    this.handledAt,
    this.handledBy,
  });

  /// Also the document id.
  final String uid;
  final String email;
  final String name;
  final String shopId;
  final String shopName;
  final String? note;
  final ShopRemovalStatus status;
  final DateTime createdAt;
  final DateTime? handledAt;
  final String? handledBy;

  bool get isPending => status == ShopRemovalStatus.pending;

  /// The document the owner creates: exactly these keys (`note` only when
  /// given).
  Map<String, dynamic> toCreateMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'shopId': shopId,
        'shopName': shopName,
        if (note != null) 'note': note,
        'status': ShopRemovalStatus.pending.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// The admin's update: exactly `{status, handledAt, handledBy}`.
  static Map<String, dynamic> resolveFields(ShopRemovalStatus status, {required DateTime at, required String by}) => {
        'status': status.name,
        'handledAt': at.toUtc().toIso8601String(),
        'handledBy': by,
      };

  factory ShopRemovalRequest.fromMap(Map<String, dynamic> map, String id) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
    final note = (map['note'] as String?)?.trim();
    return ShopRemovalRequest(
      uid: id,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      note: note == null || note.isEmpty ? null : note,
      status: ShopRemovalStatus.fromString(map['status'] as String?),
      createdAt: date(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      handledAt: date(map['handledAt']),
      handledBy: map['handledBy'] as String?,
    );
  }

  ShopRemovalRequest resolved(ShopRemovalStatus status, {required DateTime at, required String by}) =>
      ShopRemovalRequest(
        uid: uid,
        email: email,
        name: name,
        shopId: shopId,
        shopName: shopName,
        note: note,
        status: status,
        createdAt: createdAt,
        handledAt: at.toUtc(),
        handledBy: by,
      );
}

/// [note] trimmed (null when blank), or throws when too long.
String? normalizeShopRemovalNote(String? note) {
  final n = note?.trim() ?? '';
  if (n.isEmpty) return null;
  if (n.length > kShopRemovalNoteMaxLength) {
    throw const AccountDeletionException(AccountDeletionError.noteTooLong);
  }
  return n;
}

/// The customer's notice when their barber deleted their account
/// (`users/{customerId}/notifications/{bookingId}_cancelled`, the staff
/// cancel notice the rules already accept).
({String title, String body}) renderBarberLeftText(Booking booking, {String? language}) {
  final barber = booking.barberName.trim().isEmpty ? null : booking.barberName.trim();
  final shop = booking.shopName.trim().isEmpty ? 'Crown & Blade' : booking.shopName.trim();
  if (language == 'en') {
    return (
      title: 'Booking cancelled',
      body: '${barber ?? 'Your barber'} no longer works at $shop, so your appointment was cancelled. '
          'Please book another time.',
    );
  }
  return (
    title: 'ቀጠሮዎ ተሰርዟል',
    body: '${barber ?? 'ፀጉር አስተካካዩ'} ከ$shop ስለለቀቁ ቀጠሮዎ ተሰርዟል። እባክዎ ሌላ ጊዜ ይያዙ።',
  );
}
