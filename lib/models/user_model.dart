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

  // --- admin users ---
  /// Disabled by an admin (`users/{uid}.disabled`): the app signs the
  /// account out at once and refuses sign-in. Absent = false.
  final bool disabled;

  /// When ([disabledAt], UTC), by which admin uid ([disabledBy]) and why
  /// ([disabledReason], optional) the account was disabled.
  final DateTime? disabledAt;
  final String? disabledBy;
  final String? disabledReason;
  // --- end admin users ---

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
    this.disabled = false, // admin users
    this.disabledAt,
    this.disabledBy,
    this.disabledReason,
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
      // admin users: kept on full rewrites of the profile.
      if (disabled) 'disabled': true,
      if (disabled && disabledAt != null) 'disabledAt': disabledAt!.toUtc().toIso8601String(),
      if (disabled && disabledBy != null) 'disabledBy': disabledBy,
      if (disabled && disabledReason != null) 'disabledReason': disabledReason,
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
    // admin users: disabled == false clears disabledAt/By/Reason too.
    bool? disabled,
    DateTime? disabledAt,
    String? disabledBy,
    String? disabledReason,
  }) {
    final isDisabled = disabled ?? this.disabled;
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
      disabled: isDisabled, // admin users
      disabledAt: isDisabled ? disabledAt ?? this.disabledAt : null,
      disabledBy: isDisabled ? disabledBy ?? this.disabledBy : null,
      disabledReason: isDisabled ? disabledReason ?? this.disabledReason : null,
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
      // admin users
      disabled: map['disabled'] == true,
      disabledAt: map['disabledAt'] is String ? DateTime.tryParse(map['disabledAt'] as String)?.toUtc() : null,
      disabledBy: map['disabledBy'] is String ? map['disabledBy'] as String : null,
      disabledReason: map['disabledReason'] is String ? map['disabledReason'] as String : null,
    );
  }
}
