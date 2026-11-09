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

  final List<Barbershop> _mockShops = [];
  final List<BarbershopService> _mockServices = [];
  final List<Barber> _mockBarbers = [];
  final List<Booking> _mockBookings = [];

  void _initDemoData() {
    // Demo User
    _currentUser = AppUser(
      uid: 'user_cust_1',
      email: 'alex@example.com',
      name: 'Alex Johnson',
      phone: '+1 555-0199',
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );

    // Demo Shop 1
    const shop1Id = 'shop_1';
    _mockShops.add(Barbershop(
      id: shop1Id,
      ownerId: 'owner_1',
      name: 'The Royal Fade & Grooming Lounge',
      description: 'Handcrafted precision cuts, beard sculpting, and hot towel facial treatments in a premium atmosphere.',
      address: '422 Lexington Ave, Suite 101',
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
      name: 'Classic Blade Barbers',
      description: 'Vintage styled barbershop dedicated to classic trims, razor fades, and timeless gentlemen styling.',
      address: '784 Broadway St',
      city: 'Brooklyn, NY',
      phone: '+1 718-555-4321',
      imageUrl: 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
      rating: 4.8,
      reviewCount: 98,
      openingHour: 10,
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
      ),
      Barber(
        id: 'barber_2',
        shopId: shop1Id,
        name: 'David Rossi',
        title: 'Senior Stylist & Shave Artist',
        rating: 4.8,
        reviewCount: 54,
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      ),
    ]);

    // Demo Bookings
    _mockBookings.add(Booking(
      id: 'book_1',
      shopId: shop1Id,
      shopName: 'The Royal Fade & Grooming Lounge',
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
    ));
  }

  // --- Auth & User Management ---
  void switchRole(UserRole role) {
    if (_currentUser == null) return;
    String? shopId = role == UserRole.barbershopOwner ? 'shop_1' : null;
    _currentUser = AppUser(
      uid: _currentUser!.uid,
      email: _currentUser!.email,
      name: role == UserRole.barbershopOwner ? 'Marcus (Owner)' : 'Alex Johnson',
      phone: _currentUser!.phone,
      role: role,
      shopId: shopId,
      createdAt: _currentUser!.createdAt,
    );
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final auth = _auth;
    if (auth != null) {
      try {
        final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
        final doc = await _firestore?.collection('users').doc(credential.user!.uid).get();
        if (doc != null && doc.exists) {
          _currentUser = AppUser.fromMap(doc.data()!, doc.id);
          _useFirebase = true;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Firebase login fallback: $e');
      }
    }

    // Fallback Mock Sign In
    _currentUser = AppUser(
      uid: _uuid.v4(),
      email: email,
      name: email.split('@').first,
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? shopName,
    String? shopAddress,
  }) async {
    final auth = _auth;
    String newUid = _uuid.v4();

    if (auth != null) {
      try {
        final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
        newUid = credential.user!.uid;
        _useFirebase = true;
      } catch (e) {
        debugPrint('Firebase signup fallback: $e');
      }
    }

    String? createdShopId;
    if (role == UserRole.barbershopOwner && shopName != null) {
      createdShopId = _uuid.v4();
    }

    final user = AppUser(
      uid: newUid,
      email: email,
      name: name,
      role: role,
      shopId: createdShopId,
      createdAt: DateTime.now(),
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('users').doc(newUid).set(user.toMap());
    }

    if (role == UserRole.barbershopOwner && shopName != null && createdShopId != null) {
      await createShop(
        shopId: createdShopId,
        ownerId: newUid,
        name: shopName,
        address: shopAddress ?? '123 Downtown St',
        description: 'New barbershop ready to serve clients.',
      );
    }

    _currentUser = user;
    notifyListeners();
  }

  void signOut() {
    _auth?.signOut();
    _currentUser = null;
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
    required String description,
  }) async {
    final finalShopId = shopId ?? _uuid.v4();
    final newShop = Barbershop(
      id: finalShopId,
      ownerId: ownerId,
      name: name,
      description: description,
      address: address,
      city: 'Downtown',
      phone: '+1 555-0100',
      imageUrl: 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('barbershops').doc(finalShopId).set(newShop.toMap());
    }

    _mockShops.add(newShop);
    notifyListeners();
    return finalShopId;
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

  // --- Barbers ---
  List<Barber> getBarbersForShop(String shopId) {
    return _mockBarbers.where((b) => b.shopId == shopId).toList();
  }

  Future<void> addBarber({
    required String shopId,
    required String name,
    required String title,
    String? avatarUrl,
  }) async {
    final id = _uuid.v4();
    final barber = Barber(
      id: id,
      shopId: shopId,
      name: name,
      title: title,
      avatarUrl: avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    );

    if (_useFirebase && _firestore != null) {
      await _firestore!.collection('barbershops').doc(shopId).collection('barbers').doc(id).set(barber.toMap());
    }

    _mockBarbers.add(barber);
    notifyListeners();
  }

  // --- Bookings ---
  List<Booking> getCustomerBookings(String customerId) {
    return _mockBookings.where((b) => b.customerId == customerId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Booking> getShopBookings(String shopId) {
    return _mockBookings.where((b) => b.shopId == shopId).toList()
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
      final old = _mockBookings[index];
      _mockBookings[index] = Booking(
        id: old.id,
        shopId: old.shopId,
        shopName: old.shopName,
        barberId: old.barberId,
        barberName: old.barberName,
        customerId: old.customerId,
        customerName: old.customerName,
        customerPhone: old.customerPhone,
        serviceId: old.serviceId,
        serviceName: old.serviceName,
        price: old.price,
        date: old.date,
        timeSlot: old.timeSlot,
        status: newStatus,
        createdAt: old.createdAt,
      );

      if (_useFirebase && _firestore != null) {
        _firestore!.collection('bookings').doc(bookingId).update({'status': newStatus.name});
      }

      notifyListeners();
    }
  }
}
