/// Favourite barbers and one-tap rebooking ("Book again with Dawit").
///
/// Pure logic (no Flutter, no Firebase) shared by the repository and the
/// customer screens, so it can be unit tested:
///  * [FavoriteBarber] is one favourite as kept on the customer's device.
///  * [buildYourBarbers] merges favourites with the barbers of the
///    customer's recent completed bookings (the "Your barbers" row).
///  * [checkRebook] decides whether a rebook can open the booking flow, or
///    which friendly fallback to show instead ([RebookProblem]).
library;

import 'dart:convert';

import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/service_model.dart';

/// Most entries the "Your barbers" row shows.
const int kYourBarbersLimit = 8;

/// Completed bookings older than this do not add a barber to the row
/// (favourites always show).
const Duration kYourBarbersRecentWindow = Duration(days: 180);

/// One favourite barber, kept on the customer's device. The shop and the
/// name are remembered with it, so the row can still explain a barber who
/// has left the shop (their profile is gone by then).
class FavoriteBarber {
  final String barberId;
  final String shopId;
  final String barberName;

  const FavoriteBarber({required this.barberId, required this.shopId, required this.barberName});

  Map<String, dynamic> toJson() => {'b': barberId, 's': shopId, 'n': barberName};

  static FavoriteBarber? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final b = raw['b'];
    if (b is! String || b.isEmpty) return null;
    final s = raw['s'];
    final n = raw['n'];
    return FavoriteBarber(barberId: b, shopId: s is String ? s : '', barberName: n is String ? n : '');
  }

  /// A JSON list of favourites (what the device store saves).
  static String encodeList(Iterable<FavoriteBarber> list) => jsonEncode([for (final f in list) f.toJson()]);

  /// Reads [encodeList]'s output; anything malformed is skipped.
  static List<FavoriteBarber> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (FavoriteBarber.fromJson(e) case final f?) f,
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// The first word of a name ("Dawit Mekonnen" -> "Dawit").
String firstNameOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.split(RegExp(r'\s+')).first;
}

/// One entry of the "Your barbers" row: a barber at a shop, and the
/// service to prefill (the last one booked with them, if any).
class RebookCandidate {
  final String barberId;
  final String shopId;
  final String barberName;
  final String shopName;

  /// The service of the last completed booking with this barber; null for a
  /// favourite never booked (the shop's first service is used then).
  final String? serviceId;
  final String? serviceName;

  final bool isFavorite;

  /// Start (UTC) of the last completed booking with this barber, if any.
  final DateTime? lastVisit;

  const RebookCandidate({
    required this.barberId,
    required this.shopId,
    required this.barberName,
    required this.shopName,
    this.serviceId,
    this.serviceName,
    this.isFavorite = false,
    this.lastVisit,
  });

  String get firstName => firstNameOf(barberName);

  /// The rebook of a past booking (completed booking cards).
  factory RebookCandidate.fromBooking(Booking booking, {bool isFavorite = false}) => RebookCandidate(
        barberId: booking.barberId,
        shopId: booking.shopId,
        barberName: booking.barberName,
        shopName: booking.shopName,
        serviceId: booking.serviceId,
        serviceName: booking.serviceName,
        isFavorite: isFavorite,
        lastVisit: booking.startAt,
      );
}

/// The "Your barbers" row: favourites first (most recently visited first,
/// never-visited ones after them in the order they were added), then the
/// barbers of the customer's completed bookings within [recentWindow],
/// newest first. One entry per barber, at most [limit].
///
/// [bookings] are the customer's own bookings (any status; only completed
/// ones count). Names come from the live profiles when they exist, else
/// from the favourite record or the booking.
List<RebookCandidate> buildYourBarbers({
  required Iterable<FavoriteBarber> favorites,
  required Iterable<Booking> bookings,
  required Barber? Function(String barberId) barberById,
  required Barbershop? Function(String shopId) shopById,
  required DateTime nowUtc,
  int limit = kYourBarbersLimit,
  Duration recentWindow = kYourBarbersRecentWindow,
}) {
  final completed = bookings.where((b) => b.status == BookingStatus.completed).toList()
    ..sort((a, b) => b.startAt.compareTo(a.startAt));
  final lastByBarber = <String, Booking>{};
  for (final b in completed) {
    lastByBarber.putIfAbsent(b.barberId, () => b);
  }

  RebookCandidate make(String barberId, String shopId, String fallbackName, bool favorite) {
    final last = lastByBarber[barberId];
    // The favourite's shop wins; a booking at another shop still gives the
    // last service only when it was at that same shop.
    final lastHere = last != null && last.shopId == shopId ? last : null;
    final barber = barberById(barberId);
    final shop = shopById(shopId);
    final liveName = barber != null && barber.shopId == shopId ? barber.name : '';
    return RebookCandidate(
      barberId: barberId,
      shopId: shopId,
      barberName: liveName.isNotEmpty ? liveName : (fallbackName.isNotEmpty ? fallbackName : (last?.barberName ?? '')),
      shopName: shop?.name ?? lastHere?.shopName ?? last?.shopName ?? '',
      serviceId: lastHere?.serviceId,
      serviceName: lastHere?.serviceName,
      isFavorite: favorite,
      lastVisit: lastHere?.startAt,
    );
  }

  final out = <RebookCandidate>[];
  final seen = <String>{};

  final favs = <RebookCandidate>[];
  for (final f in favorites) {
    if (!seen.add(f.barberId)) continue;
    final shopId = f.shopId.isNotEmpty ? f.shopId : (barberById(f.barberId)?.shopId ?? lastByBarber[f.barberId]?.shopId ?? '');
    favs.add(make(f.barberId, shopId, f.barberName, true));
  }
  // Visited favourites first (newest visit first); the sort is stable, so
  // never-visited ones keep the order they were added in.
  final order = {for (var i = 0; i < favs.length; i++) favs[i].barberId: i};
  favs.sort((a, b) {
    final av = a.lastVisit;
    final bv = b.lastVisit;
    if (av != null && bv != null) return bv.compareTo(av);
    if (av != null) return -1;
    if (bv != null) return 1;
    return order[a.barberId]!.compareTo(order[b.barberId]!);
  });
  out.addAll(favs);

  final cutoff = nowUtc.toUtc().subtract(recentWindow);
  for (final b in completed) {
    if (out.length >= limit) break;
    if (b.startAt.isBefore(cutoff)) break; // sorted newest first
    if (!seen.add(b.barberId)) continue;
    out.add(make(b.barberId, b.shopId, b.barberName, false));
  }
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// Why a rebook cannot go straight to the slot picker.
enum RebookProblem {
  /// The shop is not in the app any more (deleted or hidden).
  shopGone,

  /// The shop is suspended (by the admin or for an unpaid subscription).
  shopBlocked,

  /// The barber no longer works at that shop.
  barberGone,

  /// The barber is not taking bookings right now.
  barberUnavailable,

  /// The last service is no longer offered (other services exist).
  serviceGone,

  /// The shop lists no services at all.
  noServices,
}

/// Result of [checkRebook]: either everything needed to open the booking
/// flow ([problem] null), or the problem plus whatever is still known.
class RebookCheck {
  final RebookProblem? problem;
  final Barbershop? shop;
  final Barber? barber;

  /// The service to prefill: the last one, or (favourite never booked) the
  /// shop's first service. With [RebookProblem.serviceGone] it is the
  /// replacement offered by "Pick a service".
  final BarbershopService? service;

  const RebookCheck({this.problem, this.shop, this.barber, this.service});

  bool get ok => problem == null;
}

/// Checks a rebook against the live shop, barber and services.
RebookCheck checkRebook(
  RebookCandidate candidate, {
  required Barbershop? Function(String shopId) shopById,
  required Barber? Function(String barberId) barberById,
  required List<BarbershopService> Function(String shopId) servicesForShop,
}) {
  final shop = candidate.shopId.isEmpty ? null : shopById(candidate.shopId);
  if (shop == null) return const RebookCheck(problem: RebookProblem.shopGone);
  if (shop.isBlocked) return RebookCheck(problem: RebookProblem.shopBlocked, shop: shop);

  final barber = barberById(candidate.barberId);
  if (barber == null || barber.shopId != shop.id) {
    return RebookCheck(problem: RebookProblem.barberGone, shop: shop);
  }
  if (!barber.isAvailable) {
    return RebookCheck(problem: RebookProblem.barberUnavailable, shop: shop, barber: barber);
  }

  final services = servicesForShop(shop.id);
  if (services.isEmpty) return RebookCheck(problem: RebookProblem.noServices, shop: shop, barber: barber);
  final wanted = candidate.serviceId;
  if (wanted == null) return RebookCheck(shop: shop, barber: barber, service: services.first);
  final service = services.where((s) => s.id == wanted).firstOrNull;
  if (service == null) {
    return RebookCheck(problem: RebookProblem.serviceGone, shop: shop, barber: barber, service: services.first);
  }
  return RebookCheck(shop: shop, barber: barber, service: service);
}
