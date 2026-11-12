enum UserRole {
  customer,
  barber,
  barbershopOwner,
  admin;

  static UserRole fromString(String? role) {
    switch (role) {
      case 'barber':
        return UserRole.barber;
      case 'barbershopOwner':
        return UserRole.barbershopOwner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Platform Admin';
      case UserRole.barbershopOwner:
        return 'Shop Owner';
      case UserRole.barber:
        return 'Barber';
      case UserRole.customer:
        return 'Customer';
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? phone;
  final UserRole role;
  final String? shopId;
  final String? barberId;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    this.shopId,
    this.barberId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role.name,
      'shopId': shopId,
      'barberId': barberId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    UserRole? role,
    String? shopId,
    String? barberId,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      barberId: barberId ?? this.barberId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      uid: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      role: UserRole.fromString(map['role']),
      shopId: map['shopId'],
      barberId: map['barberId'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
