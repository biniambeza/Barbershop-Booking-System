/// Pure logic of the admin "Shops" management screens: search/filter,
/// suspension reason and edit validation, typed-name delete confirmation,
/// the read-only opening-hours summary and owner lookup. No Flutter, no Firebase (unit tested in
/// test/admin_shops_test.dart).
library;

import '../models/barbershop_model.dart';
import '../models/invite_model.dart';
import '../models/user_model.dart';

/// Longest admin suspension reason (the rules accept 1..300 characters).
const int kMaxShopSuspendReasonLength = 300;

/// Longest shop name / address / description the admin edit accepts.
const int kMaxShopNameLength = 80;
const int kMaxShopAddressLength = 200;
const int kMaxShopDescriptionLength = 1000;

/// Shop list filter chips of the admin Shops tab.
enum AdminShopFilter {
  all,

  /// Customers can see and book it ([Barbershop.isBlocked] false).
  active,

  /// Suspended by the admin or for an unpaid subscription.
  suspended,
  verified,
  unverified,
}

/// Why an admin shop write was refused (mapped to text by the screens).
enum AdminShopError {
  reasonRequired,
  reasonTooLong,
  nameRequired,
  nameTooLong,
  addressRequired,
  textTooLong,
  invalidPlan,
  shopNotFound,
  notAdmin,
  nameMismatch,
}

class AdminShopException implements Exception {
  const AdminShopException(this.error);
  final AdminShopError error;

  @override
  String toString() => 'AdminShopException(${error.name})';
}

/// Shops matching [query] (name, sub-city, address or city, ignoring case
/// and surrounding spaces) and [filter], in the given order.
List<Barbershop> filterAdminShops(
  Iterable<Barbershop> shops, {
  String query = '',
  AdminShopFilter filter = AdminShopFilter.all,
}) {
  final q = query.trim().toLowerCase();
  bool matches(Barbershop s) =>
      q.isEmpty ||
      s.name.toLowerCase().contains(q) ||
      s.subCity.toLowerCase().contains(q) ||
      s.address.toLowerCase().contains(q) ||
      s.city.toLowerCase().contains(q);
  bool passes(Barbershop s) {
    switch (filter) {
      case AdminShopFilter.all:
        return true;
      case AdminShopFilter.active:
        return !s.isBlocked;
      case AdminShopFilter.suspended:
        return s.isBlocked;
      case AdminShopFilter.verified:
        return s.isVerified;
      case AdminShopFilter.unverified:
        return !s.isVerified;
    }
  }

  return [for (final s in shops) if (matches(s) && passes(s)) s];
}

/// Counts for the admin hero card.
class AdminShopCounts {
  const AdminShopCounts({required this.total, required this.active, required this.suspended});
  final int total;
  final int active;
  final int suspended;

  factory AdminShopCounts.of(Iterable<Barbershop> shops) {
    var total = 0, blocked = 0;
    for (final s in shops) {
      total++;
      if (s.isBlocked) blocked++;
    }
    return AdminShopCounts(total: total, active: total - blocked, suspended: blocked);
  }
}

/// The trimmed suspension reason, or throws [AdminShopException].
String validateSuspendReason(String reason) {
  final r = reason.trim();
  if (r.isEmpty) throw const AdminShopException(AdminShopError.reasonRequired);
  if (r.length > kMaxShopSuspendReasonLength) throw const AdminShopException(AdminShopError.reasonTooLong);
  return r;
}

/// True when [typed] (trimmed) is exactly the shop's name (trimmed): the
/// typed-name confirmation of a shop delete.
bool deleteConfirmationMatches(String typed, String shopName) {
  final t = typed.trim();
  return t.isNotEmpty && t == shopName.trim();
}

/// Checks the admin edit of a shop; returns the shop with trimmed text
/// fields (an empty landmark becomes null) or throws [AdminShopException].
Barbershop validateAdminShopEdit(Barbershop shop, {Iterable<String> planIds = const []}) {
  final name = shop.name.trim();
  final address = shop.address.trim();
  final description = shop.description.trim();
  final landmark = shop.landmark?.trim();
  if (name.isEmpty) throw const AdminShopException(AdminShopError.nameRequired);
  if (name.length > kMaxShopNameLength) throw const AdminShopException(AdminShopError.nameTooLong);
  if (address.isEmpty) throw const AdminShopException(AdminShopError.addressRequired);
  if (address.length > kMaxShopAddressLength ||
      description.length > kMaxShopDescriptionLength ||
      (landmark?.length ?? 0) > kMaxShopAddressLength) {
    throw const AdminShopException(AdminShopError.textTooLong);
  }
  // Opening hours are not checked: the admin edit never writes them (only
  // the shop owner sets them, see Barbershop.toAdminEditMap).
  final plans = planIds.toSet();
  if (plans.isNotEmpty && !plans.contains(shop.subscriptionPlan)) {
    throw const AdminShopException(AdminShopError.invalidPlan);
  }
  return shop.copyWith(
    name: name,
    address: address,
    description: description,
    subCity: shop.subCity.trim(),
    phone: shop.phone.trim(),
    landmark: (landmark == null || landmark.isEmpty) ? null : landmark,
    clearLandmark: landmark == null || landmark.isEmpty,
  );
}

/// Short text for a set of ISO weekdays (1 = Mon .. 7 = Sun): runs of three
/// or more days are joined with an en dash, e.g. `Mon–Sat` or
/// `Mon–Wed, Fri, Sun`. [name] gives a weekday's (short) name.
String weekdaysSummary(Iterable<int> days, String Function(int weekday) name) {
  final sorted = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
  final parts = <String>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    if (j - i >= 2) {
      parts.add('${name(sorted[i])}–${name(sorted[j])}');
    } else {
      for (var k = i; k <= j; k++) {
        parts.add(name(sorted[k]));
      }
    }
    i = j + 1;
  }
  return parts.join(', ');
}

/// The shop's owner: their account if they have signed in, otherwise the
/// pending owner invite (or neither).
class ShopOwnerInfo {
  const ShopOwnerInfo({this.user, this.invite});
  final AppUser? user;
  final UserInvite? invite;

  bool get hasAccount => user != null;
  bool get isInvitePending => user == null && invite != null;
  bool get isUnassigned => user == null && invite == null;

  String? get email => user?.email ?? invite?.email;
  String? get name => user?.name ?? invite?.name;

  static ShopOwnerInfo find(
    Barbershop shop, {
    required Iterable<AppUser> users,
    required Iterable<UserInvite> invites,
  }) {
    AppUser? user;
    for (final u in users) {
      if (u.role != UserRole.barbershopOwner) continue;
      if (u.shopId == shop.id || (shop.ownerId.isNotEmpty && u.uid == shop.ownerId)) {
        user = u;
        break;
      }
    }
    if (user != null) return ShopOwnerInfo(user: user);
    for (final i in invites) {
      if (i.role == UserRole.barbershopOwner && i.shopId == shop.id) return ShopOwnerInfo(invite: i);
    }
    return const ShopOwnerInfo();
  }
}
