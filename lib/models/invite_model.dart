import '../core/utils/email_utils.dart';
import 'user_model.dart';

/// A pending role assignment for a Google account.
///
/// Stored at `invites/{email}` where the document id is the lowercased email
/// address. When someone signs in with Google using that (verified) email,
/// the invite decides which role (and which shop / barber profile) their
/// account receives, and is then deleted. Only admins (any role) and shop
/// owners (barbers for their own shop) can create invites, which is what
/// stops people from giving themselves a privileged role.
class UserInvite {
  /// Lowercased email address; also the document id.
  final String email;
  final UserRole role;
  final String name;
  final String? shopId;
  final String? barberId;
  final String createdBy;
  final DateTime createdAt;

  UserInvite({
    required String email,
    required this.role,
    required this.name,
    this.shopId,
    this.barberId,
    required this.createdBy,
    required this.createdAt,
  }) : email = normalizeEmail(email);

  Map<String, dynamic> toMap() {
    return {
      'email': email,
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
      email: id,
      role: UserRole.fromString(map['role']),
      name: map['name'] ?? '',
      shopId: map['shopId'],
      barberId: map['barberId'],
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
