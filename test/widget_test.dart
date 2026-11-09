import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:barbershop_booking/main.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';

void main() {
  testWidgets('Barbershop smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BarbershopApp());
    expect(find.byType(BarbershopApp), findsOneWidget);
  });

  test('Barbershop coordinates and distance calculation', () {
    final shop = Barbershop(
      id: 'test_shop',
      ownerId: 'owner_1',
      name: 'Downtown Fade',
      description: 'Test shop',
      address: '100 Main St',
      city: 'New York, NY',
      phone: '555-1234',
      imageUrl: 'https://example.com/shop.jpg',
      latitude: 40.7527,
      longitude: -73.9772,
    );

    const userLoc = LatLng(40.7484, -73.9857);
    final distanceKm = shop.distanceInKmFrom(userLoc);
    expect(distanceKm, greaterThan(0));
    expect(distanceKm, lessThan(5.0));

    final formatted = shop.formattedDistanceFrom(userLoc);
    expect(formatted.contains('away'), isTrue);
  });

  test('AppRepository contains demo shops with coordinates', () {
    final repo = AppRepository.instance;
    final shops = repo.getShops();
    expect(shops.length, greaterThanOrEqualTo(5));

    for (final shop in shops) {
      expect(shop.latitude, isNotNull);
      expect(shop.longitude, isNotNull);
      expect(shop.coordinates.latitude, equals(shop.latitude));
      expect(shop.coordinates.longitude, equals(shop.longitude));
    }
  });
}
