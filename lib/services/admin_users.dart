/// Admin user management: changing someone's role and disabling accounts.
///
/// Pure logic (no Flutter or Firebase, unit tested). The writes are in
/// admin_user_writes.dart; AppRepository wires them up
/// ([AppRepository.adminChangeUserRole], [AppRepository.adminSetUserDisabled]).
///
/// Where roles live:
///  * `users/{uid}`: role, shopId (owner, barber), barberId (barber). The
///    rules require exactly those links per role.
///  * `invites/{email}`: a pending role for an email that has not signed in
///    yet (or a customer who was invited later). A role change by the admin
///    deletes the person's own pending invite, so a later sign-in does not
///    silently change the role again.
///  * `barbershops/{id}.ownerId`: the owner's uid ('' until the invited
///    owner signs in).
///  * `barbershops/{id}/barbers/{barberId}`: the public barber profile a
///    barber account is linked to.
///
/// Disabling: `users/{uid}.disabled = true` plus disabledAt (ISO UTC),
/// disabledBy (admin uid) and disabledReason (optional). The app signs a
/// disabled user out at once (live listener on their own profile) and
/// refuses sign-in. With Cloud Functions (Blaze) functions/auth
/// `onUserDisabledChanged` mirrors it to Firebase Auth.
library;

import '../data/addis_time.dart';
import '../models/app_notification.dart';
import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/invite_model.dart';
import '../models/user_model.dart';
import '../core/utils/email_utils.dart';
import '../core/utils/phone_utils.dart';
import 'shop_deletion.dart' show ShopDeletionNotice;

/// Longest reason an admin may give when disabling an account.
const int kDisableReasonMaxLength = 300;

/// `bookings/{id}.cancelReason` of a booking cancelled because an account
/// was disabled (the admin ticked "cancel upcoming bookings").
const String kAccountDisabledCancelReason = 'account_disabled';

/// Title of a barber profile the admin creates when making someone a barber.
const String kAdminNewBarberTitle = 'Barber';

/// Why an admin user action was refused.
enum AdminUserError {
  /// Only admins manage users.
  notAdmin,

  /// The user is not loaded (or was deleted meanwhile).
  userNotFound,

  /// Admins cannot change their own role or disable themselves.
  cannotChangeSelf,

  /// The platform must keep at least one (enabled) admin.
  lastAdmin,

  /// Owner and barber need a shop.
  shopRequired,
  shopNotFound,

  /// The chosen barber profile belongs to another account or invite.
  barberProfileTaken,

  /// Nothing would change.
  noChange,

  /// args: max characters.
  reasonTooLong,
}

class AdminUserException implements Exception {
  const AdminUserException(this.code);
  final AdminUserError code;

  @override
  String toString() => 'AdminUserException(${code.name})';
}

// ---------------------------------------------------------------------------
// List: masking, search, filter
// ---------------------------------------------------------------------------

/// `se***@gmail.com`: the first two characters of the local part (one if it
/// is that short), then `***`, then the domain.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email.length <= 2 ? '***' : '${email.substring(0, 2)}***';
  final local = email.substring(0, at);
  final keep = local.length <= 2 ? 1 : 2;
  return '${local.substring(0, keep)}***${email.substring(at)}';
}

/// `+251 91 *** **44`: the operator prefix and the last two digits of an
/// Ethiopian mobile; other numbers keep only their last two characters.
String maskPhone(String phone) {
  final normalized = normalizeEthiopianPhone(phone);
  if (normalized == null) {
    final t = phone.trim();
    return t.length <= 2 ? '***' : '***${t.substring(t.length - 2)}';
  }
  final local = normalized.substring(4); // 9 digits
  return '+251 ${local.substring(0, 2)} *** **${local.substring(7)}';
}

/// Digits of a phone-ish [query] in the stored E.164 form's local part
/// ("0911 22" -> "91122"), or null when [query] has fewer than 3 digits.
String? _phoneDigits(String query) {
  var digits = query.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 3) return null;
  if (digits.startsWith('251')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits.isEmpty ? null : digits;
}

/// Whether [user] matches the search [query]: part of the name or email
/// (case-insensitive), or of the phone number in any common spelling
/// (`0911...`, `+251 911...`, `911...`). An empty query matches everyone.
bool matchesUserSearch(AppUser user, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (user.name.toLowerCase().contains(q)) return true;
  if ((user.email ?? '').toLowerCase().contains(q)) return true;
  final digits = _phoneDigits(q);
  final phone = user.phone;
  if (digits != null && phone != null) {
    final normalized = normalizeEthiopianPhone(phone) ?? phone.replaceAll(RegExp(r'[^0-9]'), '');
    final localDigits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (localDigits.contains(digits)) return true;
  }
  return false;
}

/// The filter chips of the Users tab.
enum AdminUserFilter { all, customer, barbershopOwner, barber, admin, disabled }

bool matchesUserFilter(AppUser user, AdminUserFilter filter) {
  switch (filter) {
    case AdminUserFilter.all:
      return true;
    case AdminUserFilter.customer:
      return user.role == UserRole.customer;
    case AdminUserFilter.barbershopOwner:
      return user.role == UserRole.barbershopOwner;
    case AdminUserFilter.barber:
      return user.role == UserRole.barber;
    case AdminUserFilter.admin:
      return user.role == UserRole.admin;
    case AdminUserFilter.disabled:
      return user.disabled;
  }
}

/// [users] matching [query] and [filter], sorted by name (case-insensitive).
List<AppUser> filterAdminUsers(Iterable<AppUser> users, {String query = '', AdminUserFilter filter = AdminUserFilter.all}) {
  return users.where((u) => matchesUserFilter(u, filter) && matchesUserSearch(u, query)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Number of users per filter chip.
Map<AdminUserFilter, int> countUsersByFilter(Iterable<AppUser> users) => {
      for (final f in AdminUserFilter.values) f: users.where((u) => matchesUserFilter(u, f)).length,
    };

// ---------------------------------------------------------------------------
// Role changes
// ---------------------------------------------------------------------------

/// The role the admin picked on the edit screen. For a barber, [barberId]
/// links an existing (unlinked) barber profile of [shopId]; null creates a
/// new profile named after the user.
class RoleTarget {
  const RoleTarget(this.role, {this.shopId, this.barberId});
  const RoleTarget.customer() : this(UserRole.customer);
  const RoleTarget.admin() : this(UserRole.admin);
  const RoleTarget.owner(String shopId) : this(UserRole.barbershopOwner, shopId: shopId);
  const RoleTarget.barber(String shopId, {String? barberId}) : this(UserRole.barber, shopId: shopId, barberId: barberId);

  final UserRole role;
  final String? shopId;
  final String? barberId;
}

/// Everything one role change writes, in one batch:
///  * `users/{uid}` of [after] (role, shopId, barberId);
///  * [newBarber]: a barber profile created in the shop;
///  * [makeAvailableBarberId]: the linked existing profile's isAvailable
///    set back to true (it was switched off when its account was unlinked);
///  * [unlinkedBarber]: the person's old barber profile, isAvailable false
///    (kept for the shop's history and ratings; the owner may delete it);
///  * [claimShopId]: `barbershops/{id}.ownerId = uid`;
///  * [releaseShopId]: `barbershops/{id}.ownerId = ''` (the person owned it);
///  * [previousOwners]: other owners of the new shop, now customers;
///  * [deleteInviteEmails]: the person's own pending invite and other
///    pending owner invites of the new shop.
class RoleChangePlan {
  const RoleChangePlan({
    required this.before,
    required this.after,
    this.newBarber,
    this.makeAvailableBarberId,
    this.unlinkedBarber,
    this.claimShopId,
    this.releaseShopId,
    this.previousOwners = const [],
    this.deleteInviteEmails = const [],
  });

  final AppUser before;
  final AppUser after;
  final Barber? newBarber;
  final String? makeAvailableBarberId;
  final Barber? unlinkedBarber;
  final String? claimShopId;
  final String? releaseShopId;
  final List<AppUser> previousOwners;
  final List<String> deleteInviteEmails;
}

/// [user] with [role] and exactly the links that role needs (the rules
/// require customers and admins to have none, owners only a shopId).
/// Everything else (including the disabled fields) is kept.
AppUser withRole(AppUser user, UserRole role, {String? shopId, String? barberId}) => AppUser(
      uid: user.uid,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: role,
      shopId: role == UserRole.barbershopOwner || role == UserRole.barber ? shopId : null,
      barberId: role == UserRole.barber ? barberId : null,
      createdAt: user.createdAt,
      language: user.language,
      mustChangePassword: user.mustChangePassword,
      disabled: user.disabled,
      disabledAt: user.disabledAt,
      disabledBy: user.disabledBy,
      disabledReason: user.disabledReason,
    );

void _requireAdmin(AppUser? actor) {
  if (actor == null || actor.role != UserRole.admin) throw const AdminUserException(AdminUserError.notAdmin);
}

/// Barber profiles of [shopId] the admin may link an account to: not linked
/// to another account and without another person's pending invite.
List<Barber> linkableBarbers(
  String shopId, {
  required Iterable<Barber> barbers,
  required Iterable<AppUser> users,
  required Iterable<UserInvite> invites,
  String? forUid,
  String? forEmail,
}) {
  final email = forEmail == null ? null : normalizeEmail(forEmail);
  final linked = {
    for (final u in users)
      if (u.uid != forUid && u.role == UserRole.barber && u.barberId != null) u.barberId!,
    for (final i in invites)
      if (i.role == UserRole.barber && i.barberId != null && i.email != email) i.barberId!,
  };
  return [
    for (final b in barbers)
      if (b.shopId == shopId && !linked.contains(b.id)) b,
  ];
}

/// Plans changing [target]'s role to [to], or throws [AdminUserException].
/// [newId] makes the id of a new barber profile.
RoleChangePlan planRoleChange({
  required AppUser? actor,
  required AppUser target,
  required RoleTarget to,
  required Iterable<AppUser> users,
  required Map<String, Barbershop> shops,
  required Map<String, Barber> barbers,
  required Iterable<UserInvite> invites,
  required String Function() newId,
}) {
  _requireAdmin(actor);
  if (target.uid == actor!.uid) throw const AdminUserException(AdminUserError.cannotChangeSelf);
  final everyone = users.toList();
  if (target.role == UserRole.admin && to.role != UserRole.admin) {
    final admins = everyone.where((u) => u.role == UserRole.admin && u.uid != target.uid);
    if (admins.isEmpty) throw const AdminUserException(AdminUserError.lastAdmin);
  }

  final needsShop = to.role == UserRole.barbershopOwner || to.role == UserRole.barber;
  final shopId = needsShop ? to.shopId : null;
  if (needsShop) {
    if (shopId == null || shopId.isEmpty) throw const AdminUserException(AdminUserError.shopRequired);
    if (!shops.containsKey(shopId)) throw const AdminUserException(AdminUserError.shopNotFound);
  }

  // Barber: link an existing profile or create one.
  Barber? newBarber;
  String? barberId;
  String? makeAvailable;
  if (to.role == UserRole.barber) {
    final wanted = to.barberId;
    if (wanted == null) {
      if (target.role == UserRole.barber && target.shopId == shopId && target.barberId != null) {
        throw const AdminUserException(AdminUserError.noChange);
      }
      final name = target.name.trim().isEmpty ? (target.email ?? 'Barber') : target.name.trim();
      newBarber = Barber(
        id: newId(),
        shopId: shopId!,
        name: name.length > 100 ? name.substring(0, 100) : name,
        title: kAdminNewBarberTitle,
        specialties: const [],
      );
      barberId = newBarber.id;
    } else {
      final profile = barbers[wanted];
      if (profile == null || profile.shopId != shopId) throw const AdminUserException(AdminUserError.shopNotFound);
      final free = linkableBarbers(shopId!,
          barbers: [profile], users: everyone, invites: invites, forUid: target.uid, forEmail: target.email);
      if (free.isEmpty) throw const AdminUserException(AdminUserError.barberProfileTaken);
      barberId = wanted;
      if (!profile.isAvailable && wanted != target.barberId) makeAvailable = wanted;
    }
  }

  final after = withRole(target, to.role, shopId: shopId, barberId: barberId);
  if (after.role == target.role && after.shopId == target.shopId && after.barberId == target.barberId) {
    throw const AdminUserException(AdminUserError.noChange);
  }

  // The old barber profile is unlinked (kept, switched off).
  Barber? unlinked;
  if (target.role == UserRole.barber && target.barberId != null && target.barberId != after.barberId) {
    final old = barbers[target.barberId];
    if (old != null && old.isAvailable) unlinked = old;
  }

  // Ownership.
  String? claim;
  String? release;
  final previousOwners = <AppUser>[];
  final deleteInvites = <String>{};
  if (target.role == UserRole.barbershopOwner && target.shopId != null && target.shopId != after.shopId) {
    if (shops[target.shopId]?.ownerId == target.uid) release = target.shopId;
  }
  if (after.role == UserRole.barbershopOwner) {
    if (shops[shopId]?.ownerId != target.uid) claim = shopId;
    previousOwners.addAll(everyone.where(
        (u) => u.uid != target.uid && u.role == UserRole.barbershopOwner && u.shopId == shopId));
    for (final i in invites) {
      if (i.role == UserRole.barbershopOwner && i.shopId == shopId) deleteInvites.add(i.email);
    }
  }

  // The person's own pending invite would change the role again at sign-in.
  final email = target.email == null ? null : normalizeEmail(target.email!);
  if (email != null && invites.any((i) => i.email == email)) deleteInvites.add(email);

  return RoleChangePlan(
    before: target,
    after: after,
    newBarber: newBarber,
    makeAvailableBarberId: makeAvailable,
    unlinkedBarber: unlinked,
    claimShopId: claim,
    releaseShopId: release,
    previousOwners: previousOwners,
    deleteInviteEmails: deleteInvites.toList(),
  );
}

// ---------------------------------------------------------------------------
// Disable / enable
// ---------------------------------------------------------------------------

/// [reason] trimmed (null when blank), or throws when too long.
String? normalizeDisableReason(String? reason) {
  final r = reason?.trim() ?? '';
  if (r.isEmpty) return null;
  if (r.length > kDisableReasonMaxLength) throw const AdminUserException(AdminUserError.reasonTooLong);
  return r;
}

/// Checks that [actor] may disable [target] (an admin, not themselves, and
/// never the last enabled admin), or throws [AdminUserException].
void checkCanDisable({required AppUser? actor, required AppUser target, required Iterable<AppUser> users}) {
  _requireAdmin(actor);
  if (target.uid == actor!.uid) throw const AdminUserException(AdminUserError.cannotChangeSelf);
  if (target.disabled) throw const AdminUserException(AdminUserError.noChange);
  if (target.role == UserRole.admin &&
      !users.any((u) => u.role == UserRole.admin && !u.disabled && u.uid != target.uid)) {
    throw const AdminUserException(AdminUserError.lastAdmin);
  }
}

/// The `users/{uid}` fields a disable writes (exactly these keys).
Map<String, dynamic> disableFields({required DateTime at, required String by, String? reason}) => {
      'disabled': true,
      'disabledAt': at.toUtc().toIso8601String(),
      'disabledBy': by,
      if (reason != null) 'disabledReason': reason,
    };

/// The keys an enable removes from `users/{uid}`.
const List<String> kDisableFieldKeys = ['disabled', 'disabledAt', 'disabledBy', 'disabledReason'];

/// Whether [booking] is one of [user]'s upcoming bookings that a disable
/// with "cancel upcoming bookings" cancels: pending or confirmed, starting
/// at or after [nowUtc], and booked by them or (a barber) with them.
bool isCancelledByDisable(Booking booking, AppUser user, DateTime nowUtc) {
  if (booking.status != BookingStatus.pending && booking.status != BookingStatus.confirmed) return false;
  if (booking.startAt.isBefore(nowUtc.toUtc())) return false;
  if (booking.customerId == user.uid) return true;
  return user.role == UserRole.barber &&
      user.barberId != null &&
      booking.barberId == user.barberId &&
      booking.shopId == user.shopId;
}

/// A booking to cancel, with the customer's notice (null when the disabled
/// person is the customer).
class DisableCancellation {
  const DisableCancellation(this.booking, this.notice);
  final Booking booking;
  final ShopDeletionNotice? notice;
}

/// Inbox id of the notice about [bookingId] (idempotent per booking).
String accountDisabledNoticeId(String bookingId) => '${bookingId}_accountDisabled';

String _two(int n) => n.toString().padLeft(2, '0');

/// The customer's notice when their barber's account was disabled.
({String title, String body}) renderBarberUnavailableText(Booking booking, {String? language}) {
  final t = toAddisWallClock(booking.startAt);
  final when = '${_two(t.day)}/${_two(t.month)}/${t.year} ${_two(t.hour)}:${_two(t.minute)}';
  final barber = booking.barberName.trim().isEmpty ? null : booking.barberName.trim();
  if (language == 'en') {
    return (
      title: 'Appointment cancelled',
      body: '${barber ?? 'Your barber'} is no longer available, so your appointment on $when was cancelled. '
          'Please book again.',
    );
  }
  return (
    title: 'ቀጠሮዎ ተሰርዟል',
    body: '${barber ?? 'ፀጉር አስተካካዩ'} ስለማይገኙ በ$when የነበረዎት ቀጠሮ ተሰርዟል። እባክዎ እንደገና ቀጠሮ ይያዙ።',
  );
}

/// The cancellations for [user]'s upcoming [bookings] (soonest first).
List<DisableCancellation> planDisableCancellations(
  AppUser user,
  Iterable<Booking> bookings,
  DateTime nowUtc, {
  String? Function(String uid)? languageOf,
}) {
  final list = bookings.where((b) => isCancelledByDisable(b, user, nowUtc)).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  return [
    for (final b in list)
      DisableCancellation(
        b,
        b.customerId == user.uid || b.customerId.isEmpty
            ? null
            : () {
                final text = renderBarberUnavailableText(b, language: languageOf?.call(b.customerId));
                return ShopDeletionNotice(
                  id: accountDisabledNoticeId(b.id),
                  recipientUid: b.customerId,
                  type: NotificationTypes.cancelled,
                  title: text.title,
                  body: text.body,
                  shopId: b.shopId,
                  bookingId: b.id,
                  createdAt: nowUtc.toUtc(),
                );
              }(),
      ),
  ];
}
