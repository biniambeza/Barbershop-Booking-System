import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/main.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(loadTestSeed);

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
      address: 'Bole Road',
      city: 'Addis Ababa',
      subCity: 'Bole',
      phone: '+251911223344',
      imageUrl: 'https://example.com/shop.jpg',
    );

    expect(shop.fullAddress, 'Bole Road, Bole, Addis Ababa');
    expect(shop.isOpenNow(), isA<bool>());
  });

  test('AppRepository contains the Addis Ababa demo shops', () {
    final repo = AppRepository.instance;
    repo.switchRole(UserRole.admin);
    final shops = repo.getShops();
    expect(shops.length, greaterThanOrEqualTo(5));

    for (final shop in shops) {
      expect(shop.name.isNotEmpty, true);
      expect(shop.address.isNotEmpty, true);
      expect(shop.city, 'Addis Ababa');
      expect(shop.subCity.isNotEmpty, true);
    }

    final barbers = repo.getAllBarbers();
    expect(barbers.isNotEmpty, true);
  });
}
