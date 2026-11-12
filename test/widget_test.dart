import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/main.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';

void main() {
  testWidgets('Barbershop smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BarbershopApp());
    expect(find.byType(BarbershopApp), findsOneWidget);
  });

  test('Barbershop location and address formatting', () {
    final shop = Barbershop(
      id: 'test_shop',
      ownerId: 'owner_1',
      name: 'Downtown Fade',
      description: 'Test shop',
      address: '100 Main St',
      city: 'New York, NY',
      phone: '555-1234',
      imageUrl: 'https://example.com/shop.jpg',
    );

    expect(shop.fullAddress, '100 Main St, New York, NY');
    expect(shop.isOpenNow(), isA<bool>());
  });

  test('AppRepository contains demo shops and multi-tenant SaaS data', () {
    final repo = AppRepository.instance;
    final shops = repo.getShops();
    expect(shops.length, greaterThanOrEqualTo(5));

    for (final shop in shops) {
      expect(shop.name.isNotEmpty, true);
      expect(shop.address.isNotEmpty, true);
      expect(shop.city.isNotEmpty, true);
    }

    final barbers = repo.getAllBarbers();
    expect(barbers.isNotEmpty, true);
  });
}
