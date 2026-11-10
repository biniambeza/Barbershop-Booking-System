import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/customize_shop_screen.dart';

void main() {
  test('Admin registers a new Barbershop and provisions Owner account', () async {
    final repo = AppRepository.instance;
    final initialCount = repo.getShops().length;

    final newShopId = await repo.registerBarbershopByAdmin(
      shopName: 'Hudson Yards Fade Lounge',
      ownerName: 'Gregory King',
      ownerEmail: 'gregory@hudsonfade.com',
      ownerPhone: '+1 212-555-9988',
      address: '500 W 33rd St',
      city: 'New York, NY',
      latitude: 40.7538,
      longitude: -74.0022,
      description: 'Ultra-modern cuts and beard grooming in Hudson Yards.',
      imageUrl: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      openingHour: 8,
      closingHour: 21,
      workingDays: [1, 2, 3, 4, 5, 6, 7],
      isVerified: true,
    );

    // Verify shop was added
    expect(repo.getShops().length, initialCount + 1);
    final shop = repo.getShopById(newShopId);
    expect(shop, isNotNull);
    expect(shop!.name, 'Hudson Yards Fade Lounge');
    expect(shop.latitude, 40.7538);
    expect(shop.longitude, -74.0022);
    expect(shop.isVerified, true);

    // Verify owner account was created and linked to shopId
    final owner = repo.getAllUsers().firstWhere((u) => u.email == 'gregory@hudsonfade.com');
    expect(owner.role, UserRole.barbershopOwner);
    expect(owner.shopId, newShopId);
    expect(owner.name, 'Gregory King');

    // Verify starter services and starter lead barber
    final services = repo.getServicesForShop(newShopId);
    expect(services.isNotEmpty, true);
    final barbers = repo.getBarbersForShop(newShopId);
    expect(barbers.isNotEmpty, true);
    expect(barbers.first.name, 'Gregory King');
  });

  test('Barbershop Owner customizes their shop and adds their own barbers', () async {
    final repo = AppRepository.instance;
    final shop = repo.getShops().first;

    // 1. Customize shop branding & hours
    final updatedShop = shop.copyWith(
      name: 'The Royal Fade & Luxury Grooming Lounge',
      openingHour: 8,
      closingHour: 22,
    );
    await repo.updateShop(updatedShop);

    final refreshed = repo.getShopById(shop.id);
    expect(refreshed!.name, 'The Royal Fade & Luxury Grooming Lounge');
    expect(refreshed.openingHour, 8);
    expect(refreshed.closingHour, 22);

    // 2. Owner adds a new barber to their shop
    final initialBarbers = repo.getBarbersForShop(shop.id).length;
    await repo.addBarber(
      shopId: shop.id,
      name: 'Mateo Silva',
      title: 'Master Scissor & Beard Sculptor',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    );

    final newBarbers = repo.getBarbersForShop(shop.id);
    expect(newBarbers.length, initialBarbers + 1);
    expect(newBarbers.any((b) => b.name == 'Mateo Silva'), true);
  });

  test('Customer searches across favorite barbershops and favorite barbers', () {
    final repo = AppRepository.instance;
    final allBarbersWithShops = repo.getAllBarbersWithShops();
    expect(allBarbersWithShops.isNotEmpty, true);

    // Search by barber name
    final searchName = 'Marcus';
    final matchingBarbers = allBarbersWithShops.where((item) =>
      item.barber.name.toLowerCase().contains(searchName.toLowerCase()) ||
      item.shop.name.toLowerCase().contains(searchName.toLowerCase())
    ).toList();
    expect(matchingBarbers.isNotEmpty, true);
    expect(matchingBarbers.first.barber.name.contains('Marcus'), true);
  });

  testWidgets('Test AdminDashboardScreen and AdminRegisterShopScreen rendering', (tester) async {
    final repo = AppRepository.instance;
    repo.switchRole(UserRole.admin);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const AdminDashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CROWN & BLADE'), findsOneWidget);
    expect(find.text('Platform System Administration'), findsOneWidget);
    expect(find.text('Register Barbershop'), findsOneWidget);

    // Open Register Screen
    await tester.tap(find.text('Register Barbershop'));
    await tester.pumpAndSettle();

    expect(find.text('Register New Barbershop'), findsOneWidget);
    expect(find.text('1. Barbershop Business Info'), findsOneWidget);
    expect(find.text('2. Barbershop Owner Credentials'), findsOneWidget);
    expect(find.text('3. Location & Map Pin'), findsOneWidget);
  });

  testWidgets('Test CustomizeShopScreen rendering for owner', (tester) async {
    final repo = AppRepository.instance;
    final shop = repo.getShops().first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: CustomizeShopScreen(shop: shop),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customize Barbershop App'), findsOneWidget);
    expect(find.text('Shop Branding & Profile'), findsOneWidget);
    expect(find.text('Location & Pinned Map Coordinates'), findsOneWidget);
    expect(find.text('Save & Publish Customization'), findsOneWidget);
  });
}
