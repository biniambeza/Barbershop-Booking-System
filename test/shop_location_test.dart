// Shop location (maps): the map pin on the Barbershop model, the pure
// directions / distance helpers, the stores, and the customer's
// landmark + map + Directions block.

import 'package:barbershop_booking/features/customer/widgets/shop_location_block.dart';
import 'package:barbershop_booking/features/shared/widgets/shop_map.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/device_location.dart';
import 'package:barbershop_booking/services/shop_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Barbershop _shop({double? lat, double? lng, String? landmark = 'Near Edna Mall'}) => Barbershop(
      id: 's1',
      ownerId: 'o1',
      name: 'Crown Cuts Bole',
      description: 'Fades',
      address: 'Bole Road, Getu Building',
      city: 'Addis Ababa',
      subCity: 'Bole',
      landmark: landmark,
      latitude: lat,
      longitude: lng,
      phone: '+251911223301',
      imageUrl: 'https://example.com/a.jpg',
    );

class _FakeLocator implements DeviceLocator {
  _FakeLocator(this.result);
  final DeviceLocationResult result;
  int calls = 0;

  @override
  Future<DeviceLocationResult> currentPosition() async {
    calls++;
    return result;
  }

  @override
  Future<bool> openSettings() async => true;
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  setUpAll(() => ShopMapTiles.enabled = false);
  tearDownAll(() => ShopMapTiles.enabled = true);

  group('Barbershop map pin', () {
    test('round-trips through toMap / fromMap and copyWith', () {
      final shop = _shop(lat: 8.99633, lng: 38.78776);
      expect(shop.hasLocation, isTrue);
      final map = shop.toMap();
      expect(map['latitude'], 8.99633);
      expect(map['longitude'], 38.78776);
      final back = Barbershop.fromMap(map, 's1');
      expect(back.latitude, 8.99633);
      expect(back.longitude, 38.78776);
      expect(back.landmark, 'Near Edna Mall');

      // The owner's profile update and the admin edit both carry the pin.
      expect(shop.toProfileMap()['latitude'], 8.99633);
      expect(shop.toAdminEditMap()['longitude'], 38.78776);

      final moved = shop.copyWith(latitude: 9.0, longitude: 38.75);
      expect((moved.latitude, moved.longitude), (9.0, 38.75));
      final cleared = shop.copyWith(clearLocation: true);
      expect(cleared.hasLocation, isFalse);
      expect(cleared.latitude, isNull);
      // Unrelated copyWith keeps the pin.
      expect(shop.copyWith(name: 'x').latitude, 8.99633);
    });

    test('no pin: null in the update maps (= delete), left out on create', () {
      final shop = _shop();
      expect(shop.hasLocation, isFalse);
      final profile = shop.toProfileMap();
      expect(profile.containsKey('latitude'), isTrue);
      expect(profile['latitude'], isNull);
      expect(profile['longitude'], isNull);
      final created = shop.toMap()..removeWhere((_, v) => v == null);
      expect(created.containsKey('latitude'), isFalse);
      expect(created.containsKey('longitude'), isFalse);
    });

    test('fromMap drops a half or out-of-range pin and accepts ints', () {
      final base = _shop().toMap();
      expect(Barbershop.fromMap({...base, 'latitude': 9.0}, 'x').hasLocation, isFalse);
      expect(Barbershop.fromMap({...base, 'latitude': 91, 'longitude': 38}, 'x').hasLocation, isFalse);
      expect(Barbershop.fromMap({...base, 'latitude': '9', 'longitude': '38'}, 'x').hasLocation, isFalse);
      final ints = Barbershop.fromMap({...base, 'latitude': 9, 'longitude': 38}, 'x');
      expect((ints.latitude, ints.longitude), (9.0, 38.0));
    });

    test('every seeded shop has a pin in Addis Ababa', () {
      final shops = loadSeedDataset().shops;
      expect(shops, isNotEmpty);
      for (final s in shops) {
        expect(s.hasLocation, isTrue, reason: s.id);
        expect(distanceKm(kAddisCenterLat, kAddisCenterLng, s.latitude!, s.longitude!), lessThan(15), reason: s.id);
      }
    });

    test('owner update and admin edit set and remove the pin (local store)', () async {
      loadTestSeed();
      final repo = AppRepository.instance;
      repo.switchRole(UserRole.barbershopOwner);
      final shop = repo.getShopById('shop_1')!;
      await repo.updateShop(shop.copyWith(latitude: 9.001, longitude: 38.79));
      expect(repo.getShopById('shop_1')!.latitude, 9.001);
      await repo.updateShop(repo.getShopById('shop_1')!.copyWith(clearLocation: true));
      expect(repo.getShopById('shop_1')!.hasLocation, isFalse);

      repo.switchRole(UserRole.admin);
      await repo.adminUpdateShop(repo.getShopById('shop_2')!.copyWith(latitude: 9.02, longitude: 38.77));
      expect(repo.getShopById('shop_2')!.longitude, 38.77);

      final id = await repo.registerBarbershopByAdmin(
        shopName: 'Pin Test',
        ownerName: 'Owner',
        ownerEmail: 'pin.owner@example.com',
        address: 'Megenagna',
        city: 'Addis Ababa',
        description: '',
        imageUrl: '',
        isVerified: true,
        landmark: 'Next to Zefmesh Mall',
        latitude: 9.02006,
        longitude: 38.80218,
      );
      final created = repo.getShopById(id)!;
      expect((created.latitude, created.longitude), (9.02006, 38.80218));
      loadTestSeed();
    });
  });

  group('directions links', () {
    test('with a pin: Google Maps directions to the exact point', () {
      final uri = directionsUri(latitude: 8.99633, longitude: 38.78776, address: 'Bole Road', landmark: 'Edna');
      expect(uri.toString(), 'https://www.google.com/maps/dir/?api=1&destination=8.99633%2C38.78776');
      expect(uri.queryParameters['destination'], '8.99633,38.78776');
      expect(shopDirectionsUri(_shop(lat: 9.0108, lng: 38.7613)).queryParameters['destination'], '9.0108,38.7613');
    });

    test('without a pin: a search for landmark, address, sub-city and city', () {
      final uri = shopDirectionsUri(_shop());
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'Near Edna Mall, Bole Road, Getu Building, Bole, Addis Ababa');
      // No landmark, duplicates and blanks dropped.
      expect(shopSearchQuery(address: 'Piassa', landmark: ' ', subCity: 'Arada', city: 'arada'), 'Piassa, Arada');
      // An invalid pin counts as none.
      expect(directionsUri(latitude: 200, longitude: 38, address: 'X').path, '/maps/search/');
    });

    test('geo: fallback for the default maps app', () {
      expect(geoUri(latitude: 9.0, longitude: 38.75, address: 'x', label: 'Crown Cuts').toString(),
          'geo:9.0,38.75?q=9.0%2C38.75%28Crown+Cuts%29');
      expect(geoUri(address: 'Bole Road', landmark: 'Near Edna Mall').toString(),
          'geo:0,0?q=Near+Edna+Mall%2C+Bole+Road');
    });

    test('distance and "near me" order', () {
      // Edna Mall to Meskel Square is about 3.4 km.
      expect(distanceKm(8.99633, 38.78776, kAddisCenterLat, kAddisCenterLng), closeTo(3.4, 0.3));
      expect(distanceKm(9, 38, 9, 38), 0);
      final items = <String, (double, double)?>{
        'far': (9.03322, 38.75221),
        'none': null,
        'near': (8.99633, 38.78776),
        'mid': (9.01826, 38.76958),
      };
      final sorted = sortByDistance(items.keys, 8.995, 38.787, (k) => items[k]);
      expect(sorted, ['near', 'mid', 'far', 'none']);
      expect(isValidShopCoordinate(null, 38), isFalse);
      expect(isValidShopCoordinate(double.nan, 38), isFalse);
      expect(isInEthiopia(9.0, 38.7), isTrue);
      expect(isInEthiopia(51.5, -0.1), isFalse);
    });

    test('distance labels', () {
      final l = lookupAppLocalizations(const Locale('en'));
      expect(formatShopDistance(l, 0.348), '350 m away');
      expect(formatShopDistance(l, 2.345), '2.3 km away');
      expect(formatShopDistance(l, 12.6), '13 km away');
    });
  });

  group('ShopLocationBlock', () {
    testWidgets('landmark first, address, map and Directions to the pin', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(_app(ShopLocationBlock(
        shop: _shop(lat: 8.99633, lng: 38.78776),
        launcher: (uri) async {
          opened.add(uri);
          return true;
        },
      )));
      await tester.pumpAndSettle();

      expect(find.text('Near Edna Mall'), findsOneWidget);
      expect(find.text('LANDMARK'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-map')), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      // The landmark is above the address and in a bigger font.
      final landmarkY = tester.getTopLeft(find.byKey(const ValueKey('shop-landmark'))).dy;
      final addressY = tester.getTopLeft(find.byKey(const ValueKey('shop-address'))).dy;
      expect(landmarkY, lessThan(addressY));
      final landmarkText = tester.widget<Text>(find.text('Near Edna Mall'));
      final addressText = tester.widget<Text>(find.byKey(const ValueKey('shop-address')));
      expect(landmarkText.style!.fontSize!, greaterThan(addressText.style!.fontSize!));

      await tester.tap(find.byKey(const ValueKey('shop-directions')));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://www.google.com/maps/dir/?api=1&destination=8.99633%2C38.78776');
    });

    testWidgets('no pin: no map, Directions searches; falls back to geo: then a message', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(_app(ShopLocationBlock(
        shop: _shop(),
        launcher: (uri) async {
          opened.add(uri);
          return false; // nothing can open it
        },
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shop-map')), findsNothing);
      expect(find.text('Near Edna Mall'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shop-directions')));
      await tester.pumpAndSettle();
      expect(opened.length, 2);
      expect(opened[0].path, '/maps/search/');
      expect(opened[1].scheme, 'geo');
      expect(find.text('Could not open a maps app.'), findsOneWidget);
    });

    testWidgets('no landmark: no landmark line; Amharic labels', (tester) async {
      await tester.pumpWidget(_app(ShopLocationBlock(shop: _shop(landmark: null)), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shop-landmark')), findsNothing);
      expect(find.text('አቅጣጫ'), findsOneWidget);
    });
  });

  group('ShopLocationPicker', () {
    late DeviceLocator original;
    setUp(() => original = DeviceLocator.instance);
    tearDown(() => DeviceLocator.instance = original);

    testWidgets('"Use my current location" sets the pin; remove clears it', (tester) async {
      DeviceLocator.instance = _FakeLocator(const DeviceLocationResult.ok(9.0123456, 38.7654321));
      final changes = <(double?, double?)>[];
      await tester.pumpWidget(_app(ShopLocationPicker(onChanged: (a, b) => changes.add((a, b)))));
      await tester.pumpAndSettle();
      expect(find.text('No pin yet. Directions will search for the address and landmark instead.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shop-location-use-current')));
      await tester.pumpAndSettle();
      expect(changes.last, (9.012346, 38.765432));
      expect(find.text('Pin: 9.01235, 38.76543'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shop-location-remove')));
      await tester.pumpAndSettle();
      expect(changes.last, (null, null));
    });

    testWidgets('denied permission shows a message and keeps the pin', (tester) async {
      DeviceLocator.instance = _FakeLocator(const DeviceLocationResult.failed(DeviceLocationStatus.deniedForever));
      final changes = <(double?, double?)>[];
      await tester.pumpWidget(_app(ShopLocationPicker(
        latitude: 9.0,
        longitude: 38.7,
        onChanged: (a, b) => changes.add((a, b)),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shop-location-use-current')));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.text('Location is blocked for Crown & Blade. Allow it in Settings.'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Pin: 9.00000, 38.70000'), findsOneWidget);
    });
  });
}
