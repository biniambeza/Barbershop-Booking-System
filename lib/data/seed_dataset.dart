import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/barber_model.dart';
import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/plan_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';
import 'addis_time.dart';

/// Asset path of the demo dataset (also read by tool/seed/seed.js).
const String kSeedAssetPath = 'assets/seed/addis_seed.json';

/// The demo dataset, resolved into models.
///
/// Relative fields in the JSON (`createdDaysAgo`, `subscriptionEndsInDays`,
/// booking `dayOffset` + `startTime`) are resolved against [now] so the demo
/// always has bookings today and tomorrow. Booking display fields (names,
/// phone, price, duration) are copied from the referenced documents. The
/// Node seed script (tool/seed/seed.js) applies the same rules.
class SeedDataset {
  final List<SubscriptionPlan> plans;
  final List<AppUser> users;
  final List<Barbershop> shops;
  final List<BarbershopService> services;
  final List<Barber> barbers;
  final List<Booking> bookings;
  final Set<String> favoriteShopIds;
  final Set<String> favoriteBarberIds;

  SeedDataset({
    required this.plans,
    required this.users,
    required this.shops,
    required this.services,
    required this.barbers,
    required this.bookings,
    this.favoriteShopIds = const {},
    this.favoriteBarberIds = const {},
  });

  /// Loads the bundled asset ([kSeedAssetPath]).
  static Future<SeedDataset> loadFromAssets({DateTime? now}) async {
    final json = await rootBundle.loadString(kSeedAssetPath);
    return SeedDataset.fromJsonString(json, now: now);
  }

  factory SeedDataset.fromJsonString(String json, {DateTime? now}) {
    return SeedDataset.fromJson(jsonDecode(json) as Map<String, dynamic>, now: now);
  }

  factory SeedDataset.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    DateTime daysAgo(dynamic days) => nowUtc.subtract(Duration(days: (days as num?)?.toInt() ?? 0));

    final plans = [
      for (final p in _list(json['plans'])) SubscriptionPlan.fromMap(p, p['id'] as String),
    ];

    final users = [
      for (final u in _list(json['users']))
        AppUser.fromMap({...u, 'createdAt': daysAgo(u['createdDaysAgo']).toIso8601String()}, u['uid'] as String),
    ];

    final shops = <Barbershop>[];
    final services = <BarbershopService>[];
    final barbers = <Barber>[];
    for (final s in _list(json['shops'])) {
      final shopId = s['id'] as String;
      final endsInDays = (s['subscriptionEndsInDays'] as num?)?.toInt();
      shops.add(Barbershop.fromMap({
        ...s,
        if (endsInDays != null) 'subscriptionEndsAt': nowUtc.add(Duration(days: endsInDays)).toIso8601String(),
      }, shopId));
      for (final sv in _list(s['services'])) {
        services.add(BarbershopService.fromMap({...sv, 'shopId': shopId}, sv['id'] as String));
      }
      for (final b in _list(s['barbers'])) {
        barbers.add(Barber.fromMap({...b, 'shopId': shopId}, b['id'] as String));
      }
    }

    final addisToday = addisNow(nowUtc);
    final bookings = <Booking>[];
    for (final b in _list(json['bookings'])) {
      final shop = shops.firstWhere((s) => s.id == b['shopId']);
      final barber = barbers.firstWhere((x) => x.id == b['barberId']);
      final service = services.firstWhere((x) => x.id == b['serviceId']);
      final customer = users.firstWhere((u) => u.uid == b['customerId']);
      final day = DateTime.utc(addisToday.year, addisToday.month, addisToday.day)
          .add(Duration(days: (b['dayOffset'] as num).toInt()));
      final time = parseTimeSlot(b['startTime'] as String)!;
      final startAt = addisLocalToUtc(day.year, day.month, day.day, time.$1, time.$2);
      bookings.add(Booking(
        id: b['id'] as String,
        shopId: shop.id,
        shopName: shop.name,
        barberId: barber.id,
        barberName: barber.name,
        customerId: customer.uid,
        customerName: customer.name,
        customerPhone: customer.phone ?? '',
        serviceId: service.id,
        serviceName: service.name,
        price: service.price,
        date: DateTime(day.year, day.month, day.day),
        timeSlot: formatTimeSlot(time.$1, time.$2),
        status: BookingStatus.fromString(b['status'] as String?),
        createdAt: nowUtc.subtract(Duration(hours: (b['createdHoursAgo'] as num?)?.toInt() ?? 0)),
        startAt: startAt,
        durationMinutes: service.durationMinutes,
        paymentStatus: PaymentStatus.fromString(b['paymentStatus'] as String?),
        paymentMethod: PaymentMethod.fromString(b['paymentMethod'] as String?),
      ));
    }

    final favorites = (json['favorites'] as Map<String, dynamic>?) ?? const {};
    return SeedDataset(
      plans: plans,
      users: users,
      shops: shops,
      services: services,
      barbers: barbers,
      bookings: bookings,
      favoriteShopIds: {for (final id in (favorites['shopIds'] as List<dynamic>? ?? const [])) id as String},
      favoriteBarberIds: {for (final id in (favorites['barberIds'] as List<dynamic>? ?? const [])) id as String},
    );
  }

  static List<Map<String, dynamic>> _list(dynamic value) =>
      (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
}
