enum UserRole {
  customer,
  barbershopOwner,
  admin;

  static UserRole fromString(String? role) {
    switch (role) {
      case 'barbershopOwner':
        return UserRole.barbershopOwner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
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
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    this.shopId,
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      uid: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      role: UserRole.fromString(map['role']),
      shopId: map['shopId'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
