import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/customize_shop_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
    loadTestSeed();
  });
  test('Admin registers a new Barbershop and provisions Owner account', () async {
    final repo = AppRepository.instance;
    final initialCount = repo.getShops().length;

    final newShopId = await repo.registerBarbershopByAdmin(
      shopName: 'Summit Fade Lounge',
      ownerName: 'Girma Tadesse',
      ownerEmail: ' Girma.Tadesse@Gmail.com ',
      shopPhone: '0912 345 678',
      address: 'Summit Condominium Road',
      city: 'Addis Ababa',
      subCity: 'Bole',
      landmark: 'Near Summit Fiyel Bet',
      description: 'Modern cuts and beard grooming in Summit.',
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
    expect(shop!.name, 'Summit Fade Lounge');
    expect(shop.address, 'Summit Condominium Road');
    expect(shop.city, 'Addis Ababa');
    expect(shop.subCity, 'Bole');
    expect(shop.landmark, 'Near Summit Fiyel Bet');
    expect(shop.isVerified, true);
    // New shops start on the free trial.
    expect(shop.subscriptionPlan, 'trial');
    expect(shop.subscriptionStatus, SubscriptionStatus.trialing);
    expect(shop.subscriptionEndsAt!.isAfter(DateTime.now().toUtc().add(const Duration(days: 29))), true);

    // The owner is invited by (lowercased) email; no account exists until
    // they sign in with Google.
    final invite = repo.getPendingOwnerInvite(newShopId);
    expect(invite, isNotNull);
    expect(invite!.email, 'girma.tadesse@gmail.com');
    expect(invite.role, UserRole.barbershopOwner);
    expect(shop.ownerId, isEmpty);
    expect(shop.phone, '0912 345 678');
    expect(repo.getAllUsers().any((u) => u.email == 'girma.tadesse@gmail.com'), false);

    // The owner signs in with that Google account and gets the owner role.
    await signInWithGoogleAs('Girma.Tadesse@gmail.com', displayName: 'Girma T.');
    expect(repo.authStatus, AuthStatus.needsProfile);
    expect(repo.pendingInvite?.shopId, newShopId);
    await repo.completeProfile(name: 'Girma Tadesse', phone: '0912345678');

    final owner = repo.currentUser!;
    expect(owner.role, UserRole.barbershopOwner);
    expect(owner.shopId, newShopId);
    expect(owner.name, 'Girma Tadesse');
    expect(owner.email, 'girma.tadesse@gmail.com');
    expect(owner.phone, '+251912345678');
    expect(repo.getShopById(newShopId)!.ownerId, owner.uid);
    expect(repo.getPendingOwnerInvite(newShopId), isNull);
    await repo.signOut();

    // Verify starter services and starter lead barber
    final services = repo.getServicesForShop(newShopId);
    expect(services.isNotEmpty, true);
    final barbers = repo.getBarbersForShop(newShopId);
    expect(barbers.isNotEmpty, true);
    expect(barbers.first.name, 'Girma Tadesse');
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
      name: 'Mikias Fekadu',
      title: 'Master Scissor & Beard Sculptor',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    );

    final newBarbers = repo.getBarbersForShop(shop.id);
    expect(newBarbers.length, initialBarbers + 1);
    expect(newBarbers.any((b) => b.name == 'Mikias Fekadu'), true);
  });

  test('Customer searches across favorite barbershops and favorite barbers', () {
    final repo = AppRepository.instance;
    final allBarbersWithShops = repo.getAllBarbersWithShops();
    expect(allBarbersWithShops.isNotEmpty, true);

    // Search by barber name
    final searchName = 'Yonas';
    final matchingBarbers = allBarbersWithShops.where((item) =>
      item.barber.name.toLowerCase().contains(searchName.toLowerCase()) ||
      item.shop.name.toLowerCase().contains(searchName.toLowerCase())
    ).toList();
    expect(matchingBarbers.isNotEmpty, true);
    expect(matchingBarbers.first.barber.name.contains('Yonas'), true);
  });

  testWidgets('Test AdminDashboardScreen and AdminRegisterShopScreen rendering', (tester) async {
    final repo = AppRepository.instance;
    repo.switchRole(UserRole.admin);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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
    expect(find.text('1. Shop Profile & Branding'), findsOneWidget);
    expect(find.text('2. Barbershop Owner Account'), findsOneWidget);
    expect(find.text('3. Physical Location'), findsOneWidget);
  });

  testWidgets('Test CustomizeShopScreen rendering for owner', (tester) async {
    final repo = AppRepository.instance;
    final shop = repo.getShops().first;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: CustomizeShopScreen(shop: shop),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customize My Barbershop'), findsOneWidget);
    expect(find.text('Barbershop Branding & Info'), findsOneWidget);
    expect(find.text('Physical Location & Address'), findsOneWidget);
    expect(find.text('Publish Shop Customizations'), findsOneWidget);
  });
}
