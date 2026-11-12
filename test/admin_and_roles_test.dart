import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/customize_shop_screen.dart';

class _TestHttpClientResponse extends Fake implements HttpClientResponse {
  static final _transparentImage = base64Decode(
    'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
  );

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
}

class _TestHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _TestHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });
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
    expect(shop.address, '500 W 33rd St');
    expect(shop.city, 'New York, NY');
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
    expect(find.text('1. Shop Profile & Branding'), findsOneWidget);
    expect(find.text('2. Barbershop Owner Account'), findsOneWidget);
    expect(find.text('3. Physical Location'), findsOneWidget);
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

    expect(find.text('Customize My Barbershop'), findsOneWidget);
    expect(find.text('Barbershop Branding & Info'), findsOneWidget);
    expect(find.text('Physical Location & Address'), findsOneWidget);
    expect(find.text('Publish Shop Customizations'), findsOneWidget);
  });
}
