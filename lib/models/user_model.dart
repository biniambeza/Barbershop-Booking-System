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
  final String? email;
  final String name;
  final String? phone;
  final UserRole role;
  final String? shopId;
  final String? barberId;
  final DateTime createdAt;

  /// Preferred language: 'en' or 'am'. Null means not chosen yet.
  final String? language;

  // --- barber accounts ---
  /// Signed in with a temporary password from the shop owner: must choose
  /// a new password before using the app. Absent = false.
  final bool mustChangePassword;
  // --- end barber accounts ---

  AppUser({
    required this.uid,
    this.email,
    required this.name,
    this.phone,
    required this.role,
    this.shopId,
    this.barberId,
    required this.createdAt,
    this.language,
    this.mustChangePassword = false, // barber accounts
  });

  /// Language for messages (SMS / push). Amharic unless chosen otherwise.
  String get preferredLanguage => language ?? 'am';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      if (email != null) 'email': email,
      'name': name,
      if (phone != null) 'phone': phone,
      'role': role.name,
      if (shopId != null) 'shopId': shopId,
      if (barberId != null) 'barberId': barberId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (language != null) 'language': language,
      if (mustChangePassword) 'mustChangePassword': true, // barber accounts
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
    String? language,
    bool? mustChangePassword, // barber accounts
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
      language: language ?? this.language,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword, // barber accounts
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      uid: id,
      email: map['email'],
      name: map['name'] ?? '',
      phone: map['phone'],
      role: UserRole.fromString(map['role']),
      shopId: map['shopId'],
      barberId: map['barberId'],
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      language: map['language'] == 'en' || map['language'] == 'am' ? map['language'] : null,
      mustChangePassword: map['mustChangePassword'] == true, // barber accounts
    );
  }
}
