import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/barbershop_model.dart';
import '../models/service_model.dart';
import '../models/barber_model.dart';
import '../models/booking_model.dart';

class AppRepository extends ChangeNotifier {
  static final AppRepository instance = AppRepository._internal();
  AppRepository._internal() {
    _initDemoData();
  }

  final _uuid = const Uuid();
  bool _useFirebase = false;

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  final List<AppUser> _mockUsers = [];
  final List<Barbershop> _mockShops = [];
  final List<BarbershopService> _mockServices = [];
  final List<Barber> _mockBarbers = [];
  final List<Booking> _mockBookings = [];

  final Set<String> _favoriteShopIds = {'shop_1'};
  final Set<String> _favoriteBarberIds = {'barber_1'};

  void _initDemoData() {
    // 1. Platform Superadmin
    final adminUser = AppUser(
      uid: 'user_admin_1',
      email: 'admin@crownblade.com',
      name: 'System Platform Admin',
      phone: '+1 212-555-0001',
      role: UserRole.admin,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );
    _mockUsers.add(adminUser);

    // 2. Barbershop Owner (The Gentleman's Quarter)
    final ownerUser1 = AppUser(
      uid: 'owner_1',
      email: 'marcus@royalcuts.com',
      name: 'Marcus Vance (Owner)',
      phone: '+1 212-555-8901',
      role: UserRole.barbershopOwner,
      shopId: 'shop_1',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );
    _mockUsers.add(ownerUser1);

    // 3. Dedicated Staff Barbers (Belong to Shop 1)
    final barberUser1 = AppUser(
      uid: 'barber_user_1',
      email: 'marcus.barber@gentlemansquarter.com',
      name: 'Marcus Vance',
      phone: '+1 212-555-8901',
      role: UserRole.barber,
      shopId: 'shop_1',
      barberId: 'barber_1',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );
    final barberUser2 = AppUser(
      uid: 'barber_user_2',
      email: 'david.barber@gentlemansquarter.com',
      name: 'David Rossi',
      phone: '+1 212-555-3344',
      role: UserRole.barber,
      shopId: 'shop_1',
      barberId: 'barber_2',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    );
    _mockUsers.addAll([barberUser1, barberUser2]);

    // 4. Customer
    final custUser = AppUser(
      uid: 'user_cust_1',
      email: 'alex@example.com',
      name: 'Alex Johnson',
      phone: '+1 555-0199',
      role: UserRole.customer,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    _mockUsers.add(custUser);
    _currentUser = custUser;

    // Additional Owners for multi-tenant network
    _mockUsers.addAll([
      AppUser(
        uid: 'owner_2',
        email: 'leo@classicblade.com',
        name: 'Leo Thorne',
        phone: '+1 718-555-4321',
        role: UserRole.barbershopOwner,
        shopId: 'shop_2',
        createdAt: DateTime.now().subtract(const Duration(days: 50)),
      ),
      AppUser(
        uid: 'owner_3',
        email: 'julian@empirebarber.com',
        name: 'Julian Hayes',
        phone: '+1 212-555-1212',
        role: UserRole.barbershopOwner,
        shopId: 'shop_3',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
      AppUser(
        uid: 'owner_4',
        email: 'samir@dumbosteel.com',
        name: 'Samir Brooks',
        phone: '+1 718-555-9800',
        role: UserRole.barbershopOwner,
        shopId: 'shop_4',
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
      AppUser(
        uid: 'owner_5',
        email: 'arthur@upperwestclub.com',
        name: 'Arthur Sterling',
        phone: '+1 212-555-7733',
        role: UserRole.barbershopOwner,
        shopId: 'shop_5',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ]);

    // Demo Shop 1
    const shop1Id = 'shop_1';
    _mockShops.add(Barbershop(
      id: shop1Id,
      ownerId: 'owner_1',
      name: "The Gentleman's Quarter",
      description: 'Award-winning master fades, hot towel straight-razor shaves, and executive beard grooming in Midtown.',
      address: '422 Lexington Ave, Floor 3',
      city: 'New York, NY',
      phone: '+1 212-555-8901',
      imageUrl: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      rating: 4.9,
      reviewCount: 142,
      openingHour: 9,
      closingHour: 20,
      isVerified: true,
    ));

    // Demo Shop 2
    const shop2Id = 'shop_2';
    _mockShops.add(Barbershop(
      id: shop2Id,
      ownerId: 'owner_2',
      name: 'Classic Blade Barber Studio',
      description: 'Traditional heritage barbering with cold towel finish and handcrafted pomades in the Village.',
      address: '784 Broadway St',
      city: 'New York, NY',
      phone: '+1 718-555-4321',
      imageUrl: 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
      rating: 4.7,
      reviewCount: 98,
      openingHour: 10,
      closingHour: 19,
      isVerified: true,
    ));

    // Demo Shop 3
    const shop3Id = 'shop_3';
    _mockShops.add(Barbershop(
      id: shop3Id,
      ownerId: 'owner_3',
      name: 'Empire Barber & Shave Parlor',
      description: 'Luxury grooming experiences located steps from Empire State with master straight razor artists.',
      address: '350 5th Avenue, Suite 12',
      city: 'New York, NY',
      phone: '+1 212-555-1212',
      imageUrl: 'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=800',
      rating: 5.0,
      reviewCount: 210,
      openingHour: 8,
      closingHour: 21,
      isVerified: true,
    ));

    // Demo Shop 4
    const shop4Id = 'shop_4';
    _mockShops.add(Barbershop(
      id: shop4Id,
      ownerId: 'owner_4',
      name: 'DUMBO Steel & Scissor Co.',
      description: 'Urban industrial barbershop specializing in modern textured crops, fades, and artisanal beard care.',
      address: '55 Water Street',
      city: 'Brooklyn, NY',
      phone: '+1 718-555-9800',
      imageUrl: 'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800',
      rating: 4.8,
      reviewCount: 115,
      openingHour: 10,
      closingHour: 20,
      isVerified: true,
    ));

    // Demo Shop 5
    const shop5Id = 'shop_5';
    _mockShops.add(Barbershop(
      id: shop5Id,
      ownerId: 'owner_5',
      name: 'Upper West Gentleman Club',
      description: 'Refined sanctuary for classic cuts, whiskey bar hospitality, and tailored executive hairstyles.',
      address: '2150 Broadway',
      city: 'New York, NY',
      phone: '+1 212-555-7733',
      imageUrl: 'https://images.unsplash.com/photo-1512690459411-b9245aed614b?w=800',
      rating: 4.9,
      reviewCount: 168,
      openingHour: 9,
      closingHour: 19,
      isVerified: true,
    ));

    // Services for Shop 1
    _mockServices.addAll([
      BarbershopService(
        id: 'srv_1',
        shopId: shop1Id,
        name: 'Signature Skin Fade & Style',
        description: 'Precision skin fade, clipper & scissor blend, finished with premium styling pomade.',
        price: 45.0,
        durationMinutes: 45,
      ),
      BarbershopService(
        id: 'srv_2',
        shopId: shop1Id,
        name: 'Beard Sculpt & Razor Edge',
        description: 'Full beard reshaping, steam treatment, straight razor line-up and organic beard oil.',
        price: 30.0,
        durationMinutes: 30,
      ),
      BarbershopService(
        id: 'srv_3',
        shopId: shop1Id,
        name: 'The Full Gentlemen Experience',
        description: 'Haircut, beard sculpt, hot towel aromatic treatment, charcoal nose mask, and scalp massage.',
        price: 75.0,
        durationMinutes: 60,
      ),
    ]);

    // Services for Shop 2
    _mockServices.addAll([
      BarbershopService(
        id: 'srv_2_1',
        shopId: shop2Id,
        name: 'Traditional Scissor Cut',
        description: 'Classic shears styling, taper neck cleanup, and hot lather shave around the ears.',
        price: 40.0,
        durationMinutes: 40,
      ),
      BarbershopService(
        id: 'srv_2_2',
        shopId: shop2Id,
        name: 'Straight Razor Hot Shave',
        description: 'Pre-shave eucalyptus oils, hot towels, badger brush foam, and soothing aftershave balm.',
        price: 35.0,
        durationMinutes: 35,
      ),
    ]);

    // Services for Shop 3
    _mockServices.addAll([
      BarbershopService(
        id: 'srv_3_1',
        shopId: shop3Id,
        name: 'Executive Cut & Beard Detail',
        description: 'Top-tier master cut with custom beard fade, razor crisp lines, and hair wash.',
        price: 60.0,
        durationMinutes: 50,
      ),
      BarbershopService(
        id: 'srv_3_2',
        shopId: shop3Id,
        name: 'Royal Hot Towel Shave',
        description: 'Double warm aromatic towels with ultra-close straight blade glide and cold stone finish.',
        price: 45.0,
        durationMinutes: 40,
      ),
    ]);

    // Services for Shop 4
    _mockServices.addAll([
      BarbershopService(
        id: 'srv_4_1',
        shopId: shop4Id,
        name: 'Textured Crop & Low Fade',
        description: 'Modern textured crop with powder styling and clean temple tapers.',
        price: 42.0,
        durationMinutes: 45,
      ),
      BarbershopService(
        id: 'srv_4_2',
        shopId: shop4Id,
        name: 'Beard Trim & Hydration Mask',
        description: 'Deep conditioning beard treatment, shaping, and razor edge.',
        price: 28.0,
        durationMinutes: 25,
      ),
    ]);

    // Services for Shop 5
    _mockServices.addAll([
      BarbershopService(
        id: 'srv_5_1',
        shopId: shop5Id,
        name: 'Gentleman Classic Trim',
        description: 'Precision scissor comb, neck razor finish, and complimentary single malt refreshment.',
        price: 55.0,
        durationMinutes: 45,
      ),
      BarbershopService(
        id: 'srv_5_2',
        shopId: shop5Id,
        name: 'Father & Son VIP Package',
        description: 'Two deluxe cuts side by side with custom styling advice and refreshments.',
        price: 85.0,
        durationMinutes: 60,
      ),
    ]);

    // Barbers for Shop 1
    _mockBarbers.addAll([
      Barber(
        id: 'barber_1',
        shopId: shop1Id,
        name: 'Marcus Vance',
        title: 'Master Barber / Fade Specialist',
        rating: 4.9,
        reviewCount: 88,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
        email: 'marcus.barber@gentlemansquarter.com',
        phone: '+1 212-555-8901',
        specialties: ['Skin Fade', 'Beard Sculpting', 'Hot Razor Shave'],
      ),
      Barber(
        id: 'barber_2',
        shopId: shop1Id,
        name: 'David Rossi',
        title: 'Senior Stylist & Shave Artist',
        rating: 4.8,
        reviewCount: 54,
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
        email: 'david.barber@gentlemansquarter.com',
        phone: '+1 212-555-3344',
        specialties: ['Scissor Cut', 'Hot Towel Shave', 'Kids Cuts'],
      ),
    ]);

    // Barbers for Shop 2
    _mockBarbers.addAll([
      Barber(
        id: 'barber_2_1',
        shopId: shop2Id,
        name: 'Leo Thorne',
        title: 'Heritage Barber',
        rating: 4.8,
        reviewCount: 62,
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
        email: 'leo@classicblade.com',
        phone: '+1 718-555-4321',
        specialties: ['Traditional Shears', 'Beard Trim'],
      ),
    ]);

    // Barbers for Shop 3
    _mockBarbers.addAll([
      Barber(
        id: 'barber_3_1',
        shopId: shop3Id,
        name: 'Julian Hayes',
        title: 'Creative Director / Master Barber',
        rating: 5.0,
        reviewCount: 140,
        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
        email: 'julian@empirebarber.com',
        phone: '+1 212-555-1212',
        specialties: ['Executive Cut', 'Straight Razor', 'Hair Design'],
      ),
    ]);

    // Barbers for Shop 4
    _mockBarbers.addAll([
      Barber(
        id: 'barber_4_1',
        shopId: shop4Id,
        name: 'Samir Brooks',
        title: 'Fade & Design Specialist',
        rating: 4.9,
        reviewCount: 78,
        avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
        email: 'samir@dumbosteel.com',
        phone: '+1 718-555-9800',
        specialties: ['Textured Crop', 'Low Taper Fade'],
      ),
    ]);

    // Barbers for Shop 5
    _mockBarbers.addAll([
      Barber(
        id: 'barber_5_1',
        shopId: shop5Id,
        name: 'Arthur Sterling',
        title: 'Senior Barbering Craftsman',
        rating: 4.9,
        reviewCount: 92,
        avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
        email: 'arthur@upperwestclub.com',
        phone: '+1 212-555-7733',
        specialties: ['Executive Styling', 'Aromatic Shave'],
      ),
    ]);

    // Demo Bookings
    _mockBookings.addAll([
      Booking(
        id: 'book_1',
        shopId: shop1Id,
        shopName: "The Gentleman's Quarter",
        barberId: 'barber_1',
        barberName: 'Marcus Vance',
        customerId: 'user_cust_1',
        customerName: 'Alex Johnson',
        customerPhone: '+1 555-0199',
        serviceId: 'srv_1',
        serviceName: 'Signature Skin Fade & Style',
        price: 45.0,
        date: DateTime.now().add(const Duration(days: 1)),
        timeSlot: '11:00 AM',
        status: BookingStatus.confirmed,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Booking(
        id: 'book_2',
        shopId: shop1Id,
        shopName: "The Gentleman's Quarter",
        barberId: 'barber_1',
        barberName: 'Marcus Vance',
        customerId: 'user_cust_2',
        customerName: 'Michael Chang',
        customerPhone: '+1 212-555-7890',
        serviceId: 'srv_2',
        serviceName: 'Beard Sculpt & Razor Edge',
        price: 30.0,
        date: DateTime.now(),
        timeSlot: '02:30 PM',
        status: BookingStatus.confirmed,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Booking(
        id: 'book_3',
        shopId: shop1Id,
        shopName: "The Gentleman's Quarter",
        barberId: 'barber_1',
        barberName: 'Marcus Vance',
        customerId: 'user_cust_3',
        customerName: 'Robert Martinez',
        customerPhone: '+1 917-555-4422',
        serviceId: 'srv_3',
        serviceName: 'The Full Gentlemen Experience',
        price: 75.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        timeSlot: '10:00 AM',
        status: BookingStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Booking(
        id: 'book_4',
        shopId: shop1Id,
        shopName: "The Gentleman's Quarter",
        barberId: 'barber_2',
        barberName: 'David Rossi',
        customerId: 'user_cust_4',
        customerName: 'Ethan Wright',
        customerPhone: '+1 646-555-8811',
        serviceId: 'srv_1',
        serviceName: 'Signature Skin Fade & Style',
        price: 45.0,
        date: DateTime.now(),
        timeSlot: '04:00 PM',
        status: BookingStatus.confirmed,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Booking(
        id: 'book_5',
        shopId: shop2Id,
        shopName: 'Classic Blade Barber Studio',
        barberId: 'barber_2_1',
        barberName: 'Leo Thorne',
        customerId: 'user_cust_1',
        customerName: 'Alex Johnson',
        customerPhone: '+1 555-0199',
        serviceId: 'srv_2_1',
        serviceName: 'Traditional Scissor Cut',
        price: 40.0,
        date: DateTime.now().subtract(const Duration(days: 7)),
        timeSlot: '01:00 PM',
        status: BookingStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
    ]);
  }

  // --- Auth & User Management ---
  List<AppUser> getAllUsers() {
    return List.unmodifiable(_mockUsers);
  }

  void switchRole(UserRole role, {String? targetShopId, String? targetBarberId}) {
    if (role == UserRole.admin) {
      _currentUser = _mockUsers.firstWhere(
        (u) => u.role == UserRole.admin,
        orElse: () => AppUser(
          uid: 'user_admin_1',
          email: 'admin@crownblade.com',
          name: 'System Platform Admin',
          role: UserRole.admin,
          createdAt: DateTime.now(),
        ),
      );
    } else if (role == UserRole.barbershopOwner) {
      final effectiveShopId = targetShopId ?? 'shop_1';
      final matchingOwner = _mockUsers.firstWhere(
        (u) => u.role == UserRole.barbershopOwner && (targetShopId == null || u.shopId == targetShopId),
        orElse: () => _mockUsers.firstWhere(
          (u) => u.role == UserRole.barbershopOwner,
          orElse: () => AppUser(
            uid: 'owner_1',
            email: 'marcus@royalcuts.com',
            name: 'Marcus Vance (Owner)',
            role: UserRole.barbershopOwner,
            shopId: effectiveShopId,
            createdAt: DateTime.now(),
          ),
        ),
      );
      _currentUser = matchingOwner;
    } else if (role == UserRole.barber) {
      final effectiveBarberId = targetBarberId ?? 'barber_1';
      final matchingBarber = _mockUsers.firstWhere(
        (u) => u.role == UserRole.barber && (targetBarberId == null || u.barberId == targetBarberId),
        orElse: () => _mockUsers.firstWhere(
          (u) => u.role == UserRole.barber,
          orElse: () => AppUser(
            uid: 'barber_user_1',
            email: 'marcus.barber@gentlemansquarter.com',
            name: 'Marcus Vance',
            phone: '+1 212-555-8901',
            role: UserRole.barber,
            shopId: 'shop_1',
            barberId: effectiveBarberId,
            createdAt: DateTime.now(),
          ),
        ),
      );
      _currentUser = matchingBarber;
    } else {
      _currentUser = _mockUsers.firstWhere(
        (u) => u.role == UserRole.customer,
        orElse: () => AppUser(
          uid: 'user_cust_1',
          email: 'alex@example.com',
          name: 'Alex Johnson',
          role: UserRole.customer,
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check existing mock users first
    final existingUser = _mockUsers.where((u) => u.email.toLowerCase() == cleanEmail).firstOrNull;
    if (existingUser != null) {
      _currentUser = existingUser;
      notifyListeners();
      return;
    }

    // 2. Role matching by email convention
    if (cleanEmail.contains('admin')) {
      switchRole(UserRole.admin);
      return;
    } else if (cleanEmail.contains('barber')) {
      switchRole(UserRole.barber);
      return;
    } else if (cleanEmail.contains('owner')) {
      switchRole(UserRole.barbershopOwner);
      return;
    }

    // 3. Fallback Mock Sign In (new customer)
    final newUser = AppUser(
      uid: _uuid.v4(),
      email: email,
      name: email.split('@').first,
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );
    _mockUsers.add(newUser);
    _currentUser = newUser;
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? shopName,
    String? shopAddress,
    String? shopCity,
    String? assignedShopId,
    String? barberTitle,
  }) async {
    final auth = _auth;
    String newUid = _uuid.v4();

    if (auth != null) {
      try {
        final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
        newUid = credential.user!.uid;
        _useFirebase = true;
      } catch (e) {
        debugPrint('Firebase signup notice: $e (running with local store)');
      }
    }

    String? createdShopId;
    String? createdBarberId;

    if (role == UserRole.barbershopOwner && shopName != null) {
      createdShopId = _uuid.v4();
    } else if (role == UserRole.barber) {
      createdShopId = assignedShopId ?? (_mockShops.isNotEmpty ? _mockShops.first.id : null);
      createdBarberId = _uuid.v4();
    }

    final user = AppUser(
      uid: newUid,
      email: email,
      name: name,
      role: role,
      shopId: createdShopId,
      barberId: createdBarberId,
      createdAt: DateTime.now(),
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('users').doc(newUid).set(user.toMap());
    }

    _mockUsers.add(user);

    if (role == UserRole.barbershopOwner && shopName != null && createdShopId != null) {
      await createShop(
        shopId: createdShopId,
        ownerId: newUid,
        name: shopName,
        address: shopAddress ?? '123 Downtown St',
        city: shopCity ?? 'New York, NY',
        description: 'New barbershop registered in Crown & Blade SaaS network.',
      );
    } else if (role == UserRole.barber && createdBarberId != null && createdShopId != null) {
      final newBarber = Barber(
        id: createdBarberId,
        shopId: createdShopId,
        name: name,
        title: barberTitle ?? 'Professional Barber',
        email: email,
        isAvailable: true,
      );
      _mockBarbers.add(newBarber);
    }

    _currentUser = user;
    notifyListeners();
  }

  void signOut() {
    _auth?.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // --- Platform Admin: SaaS Barbershop Registration & Metrics ---
  Future<String> registerBarbershopByAdmin({
    required String shopName,
    required String ownerName,
    required String ownerEmail,
    required String ownerPhone,
    required String address,
    required String city,
    required String description,
    required String imageUrl,
    required int openingHour,
    required int closingHour,
    required List<int> workingDays,
    required bool isVerified,
  }) async {
    final shopId = _uuid.v4();
    final ownerUid = _uuid.v4();
    final leadBarberId = _uuid.v4();

    // 1. Create and register the Barbershop Owner user
    final ownerUser = AppUser(
      uid: ownerUid,
      email: ownerEmail,
      name: ownerName,
      phone: ownerPhone,
      role: UserRole.barbershopOwner,
      shopId: shopId,
      createdAt: DateTime.now(),
    );
    _mockUsers.add(ownerUser);

    // 2. Create the Barbershop
    final shop = Barbershop(
      id: shopId,
      ownerId: ownerUid,
      name: shopName,
      description: description,
      address: address,
      city: city,
      phone: ownerPhone,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
      rating: 5.0,
      reviewCount: 1,
      openingHour: openingHour,
      closingHour: closingHour,
      workingDays: workingDays,
      isVerified: isVerified,
    );
    _mockShops.insert(0, shop);

    // 3. Add default starter services
    await addService(
      shopId: shopId,
      name: 'Signature Haircut & Style',
      description: 'Precision cut, neck razor cleanup, and bespoke styling with artisan product.',
      price: 45.0,
      durationMinutes: 40,
    );
    await addService(
      shopId: shopId,
      name: 'Beard Sculpt & Hot Towel',
      description: 'Full beard shaping, warm aromatic towels, and straight razor line-up.',
      price: 30.0,
      durationMinutes: 30,
    );

    // 4. Add the lead barber & create dedicated barber login account
    final leadBarber = Barber(
      id: leadBarberId,
      shopId: shopId,
      name: ownerName,
      title: 'Master Barber / Lead Stylist',
      email: ownerEmail,
      phone: ownerPhone,
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      specialties: ['Skin Fade', 'Beard Sculpting', 'Hot Shave'],
    );
    _mockBarbers.add(leadBarber);

    final barberUser = AppUser(
      uid: _uuid.v4(),
      email: 'barber.$ownerEmail',
      name: ownerName,
      phone: ownerPhone,
      role: UserRole.barber,
      shopId: shopId,
      barberId: leadBarberId,
      createdAt: DateTime.now(),
    );
    _mockUsers.add(barberUser);

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('users').doc(ownerUid).set(ownerUser.toMap());
      await _firestore!.collection('barbershops').doc(shopId).set(shop.toMap());
    }

    notifyListeners();
    return shopId;
  }

  Future<void> updateShop(Barbershop updatedShop) async {
    final index = _mockShops.indexWhere((s) => s.id == updatedShop.id);
    if (index != -1) {
      _mockShops[index] = updatedShop;
      if (_useFirebase && _firestore != null) {
        await _firestore!.collection('barbershops').doc(updatedShop.id).update(updatedShop.toMap());
      }
      notifyListeners();
    }
  }

  Future<void> toggleShopVerification(String shopId) async {
    final index = _mockShops.indexWhere((s) => s.id == shopId);
    if (index != -1) {
      final old = _mockShops[index];
      final updated = old.copyWith(isVerified: !old.isVerified);
      _mockShops[index] = updated;
      if (_useFirebase && _firestore != null) {
        await _firestore!.collection('barbershops').doc(shopId).update({'isVerified': updated.isVerified});
      }
      notifyListeners();
    }
  }

  Future<void> deleteShop(String shopId) async {
    _mockShops.removeWhere((s) => s.id == shopId);
    _mockBarbers.removeWhere((b) => b.shopId == shopId);
    _mockServices.removeWhere((s) => s.shopId == shopId);
    _mockBookings.removeWhere((b) => b.shopId == shopId);
    _mockUsers.removeWhere((u) => u.shopId == shopId);

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('barbershops').doc(shopId).delete();
    }
    notifyListeners();
  }

  // --- Barbershop Management ---
  List<Barbershop> getShops() {
    return List.unmodifiable(_mockShops);
  }

  Barbershop? getShopById(String shopId) {
    try {
      return _mockShops.firstWhere((s) => s.id == shopId);
    } catch (_) {
      return null;
    }
  }

  Future<String> createShop({
    String? shopId,
    required String ownerId,
    required String name,
    required String address,
    required String city,
    required String description,
  }) async {
    final finalShopId = shopId ?? _uuid.v4();
    final newShop = Barbershop(
      id: finalShopId,
      ownerId: ownerId,
      name: name,
      description: description,
      address: address,
      city: city,
      phone: '+1 555-0100',
      imageUrl: 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
      isVerified: true,
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('barbershops').doc(finalShopId).set(newShop.toMap());
    }

    _mockShops.add(newShop);
    notifyListeners();
    return finalShopId;
  }

  List<BarberWithShop> getAllBarbersWithShops() {
    final list = <BarberWithShop>[];
    for (final shop in _mockShops) {
      final shopBarbers = _mockBarbers.where((b) => b.shopId == shop.id);
      for (final b in shopBarbers) {
        list.add(BarberWithShop(barber: b, shop: shop));
      }
    }
    return list;
  }

  // --- Services ---
  List<BarbershopService> getServicesForShop(String shopId) {
    return _mockServices.where((s) => s.shopId == shopId).toList();
  }

  Future<void> addService({
    required String shopId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
  }) async {
    final id = _uuid.v4();
    final service = BarbershopService(
      id: id,
      shopId: shopId,
      name: name,
      description: description,
      price: price,
      durationMinutes: durationMinutes,
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('barbershops').doc(shopId).collection('services').doc(id).set(service.toMap());
    }

    _mockServices.add(service);
    notifyListeners();
  }

  Future<void> updateService(BarbershopService service) async {
    final index = _mockServices.indexWhere((s) => s.id == service.id);
    if (index != -1) {
      _mockServices[index] = service;
      if (_useFirebase && _firestore != null) {
        await _firestore!.collection('barbershops').doc(service.shopId).collection('services').doc(service.id).update(service.toMap());
      }
      notifyListeners();
    }
  }

  Future<void> deleteService(String serviceId) async {
    _mockServices.removeWhere((s) => s.id == serviceId);
    notifyListeners();
  }

  // --- Barbers & Staff ---
  List<Barber> getBarbersForShop(String shopId) {
    return _mockBarbers.where((b) => b.shopId == shopId).toList();
  }

  List<Barber> getAllBarbers() {
    return List.unmodifiable(_mockBarbers);
  }

  Barber? getBarberById(String barberId) {
    try {
      return _mockBarbers.firstWhere((b) => b.id == barberId);
    } catch (_) {
      return null;
    }
  }

  Barber? getBarberForCurrentUser() {
    if (_currentUser == null) return null;
    if (_currentUser!.barberId != null) {
      return getBarberById(_currentUser!.barberId!);
    }
    // Fallback: match by email or name in barbers
    try {
      return _mockBarbers.firstWhere((b) => b.email == _currentUser!.email || b.name == _currentUser!.name);
    } catch (_) {
      return _mockBarbers.isNotEmpty ? _mockBarbers.first : null;
    }
  }

  Future<void> addBarber({
    required String shopId,
    required String name,
    required String title,
    String? email,
    String? phone,
    List<String>? specialties,
    String? avatarUrl,
  }) async {
    final id = _uuid.v4();
    final barber = Barber(
      id: id,
      shopId: shopId,
      name: name,
      title: title,
      email: email,
      phone: phone,
      specialties: specialties ?? const ['Skin Fade', 'Beard Trim'],
      avatarUrl: avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('barbershops').doc(shopId).collection('barbers').doc(id).set(barber.toMap());
    }

    _mockBarbers.add(barber);

    // Also provision a dedicated Barber login account in SaaS platform
    final barberAccount = AppUser(
      uid: _uuid.v4(),
      email: email ?? 'barber.${name.toLowerCase().replaceAll(' ', '')}@crownblade.com',
      name: name,
      phone: phone,
      role: UserRole.barber,
      shopId: shopId,
      barberId: id,
      createdAt: DateTime.now(),
    );
    _mockUsers.add(barberAccount);

    notifyListeners();
  }

  Future<void> updateBarber(Barber barber) async {
    final index = _mockBarbers.indexWhere((b) => b.id == barber.id);
    if (index != -1) {
      _mockBarbers[index] = barber;
      if (_useFirebase && _firestore != null) {
        await _firestore!.collection('barbershops').doc(barber.shopId).collection('barbers').doc(barber.id).update(barber.toMap());
      }
      notifyListeners();
    }
  }

  Future<void> updateBarberAvailability(String barberId, bool isAvailable) async {
    final index = _mockBarbers.indexWhere((b) => b.id == barberId);
    if (index != -1) {
      _mockBarbers[index] = _mockBarbers[index].copyWith(isAvailable: isAvailable);
      notifyListeners();
    }
  }

  Future<void> deleteBarber(String barberId) async {
    _mockBarbers.removeWhere((b) => b.id == barberId);
    _mockUsers.removeWhere((u) => u.barberId == barberId);
    notifyListeners();
  }

  // --- Bookings ---
  List<Booking> getAllBookings() {
    return List.unmodifiable(_mockBookings);
  }

  List<Booking> getCustomerBookings(String customerId) {
    return _mockBookings.where((b) => b.customerId == customerId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Booking> getShopBookings(String shopId) {
    return _mockBookings.where((b) => b.shopId == shopId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Booking> getBookingsForBarber(String barberId) {
    return _mockBookings.where((b) => b.barberId == barberId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<Booking> createBooking({
    required String shopId,
    required String shopName,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String serviceName,
    required double price,
    required DateTime date,
    required String timeSlot,
  }) async {
    final bookingId = _uuid.v4();
    final booking = Booking(
      id: bookingId,
      shopId: shopId,
      shopName: shopName,
      barberId: barberId,
      barberName: barberName,
      customerId: _currentUser?.uid ?? 'anon_cust',
      customerName: _currentUser?.name ?? 'Guest Client',
      customerPhone: _currentUser?.phone ?? '+1 555-0000',
      serviceId: serviceId,
      serviceName: serviceName,
      price: price,
      date: date,
      timeSlot: timeSlot,
      status: BookingStatus.confirmed,
      createdAt: DateTime.now(),
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('bookings').doc(bookingId).set(booking.toMap());
    }

    _mockBookings.insert(0, booking);
    notifyListeners();
    return booking;
  }

  void updateBookingStatus(String bookingId, BookingStatus newStatus) {
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _mockBookings[index] = _mockBookings[index].copyWith(status: newStatus);

      if (_useFirebase && _firestore != null) {
        _firestore!.collection('bookings').doc(bookingId).update({'status': newStatus.name});
      }

      notifyListeners();
    }
  }

  // --- Financial & SaaS Performance Metrics ---
  double getPlatformTotalRevenue() {
    return _mockBookings
        .where((b) => b.status == BookingStatus.completed || b.status == BookingStatus.confirmed)
        .fold(0.0, (total, b) => total + b.price);
  }

  double getShopRevenue(String shopId) {
    return _mockBookings
        .where((b) => b.shopId == shopId && (b.status == BookingStatus.completed || b.status == BookingStatus.confirmed))
        .fold(0.0, (total, b) => total + b.price);
  }

  double getBarberTotalEarnings(String barberId) {
    return _mockBookings
        .where((b) => b.barberId == barberId && (b.status == BookingStatus.completed || b.status == BookingStatus.confirmed))
        .fold(0.0, (total, b) => total + b.price);
  }

  int getBarberCompletedCutsCount(String barberId) {
    return _mockBookings.where((b) => b.barberId == barberId && b.status == BookingStatus.completed).length;
  }

  // --- Favorites Management ---
  bool isShopFavorite(String shopId) => _favoriteShopIds.contains(shopId);
  void toggleFavoriteShop(String shopId) {
    if (_favoriteShopIds.contains(shopId)) {
      _favoriteShopIds.remove(shopId);
    } else {
      _favoriteShopIds.add(shopId);
    }
    notifyListeners();
  }

  bool isBarberFavorite(String barberId) => _favoriteBarberIds.contains(barberId);
  void toggleFavoriteBarber(String barberId) {
    if (_favoriteBarberIds.contains(barberId)) {
      _favoriteBarberIds.remove(barberId);
    } else {
      _favoriteBarberIds.add(barberId);
    }
    notifyListeners();
  }
}

class BarberWithShop {
  final Barber barber;
  final Barbershop shop;

  BarberWithShop({
    required this.barber,
    required this.shop,
  });
}
