import 'user_model.dart';

/// A pending role assignment for a phone number.
///
/// Stored at `invites/{phone}` where the document id is the E.164 phone
/// number. When someone signs in with that phone number, the invite decides
/// which role (and which shop / barber profile) their account receives, and
/// is then deleted. Only admins (any role) and shop owners (barbers for their
/// own shop) can create invites, which is what stops people from giving
/// themselves a privileged role.
class UserInvite {
  final String phone;
  final UserRole role;
  final String name;
  final String? shopId;
  final String? barberId;
  final String createdBy;
  final DateTime createdAt;

  UserInvite({
    required this.phone,
    required this.role,
    required this.name,
    this.shopId,
    this.barberId,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'role': role.name,
      'name': name,
      if (shopId != null) 'shopId': shopId,
      if (barberId != null) 'barberId': barberId,
      'createdBy': createdBy,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory UserInvite.fromMap(Map<String, dynamic> map, String id) {
    return UserInvite(
      phone: id,
      role: UserRole.fromString(map['role']),
      name: map['name'] ?? '',
      shopId: map['shopId'],
      barberId: map['barberId'],
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
