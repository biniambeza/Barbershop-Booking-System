import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../core/utils/email_utils.dart';
import '../core/utils/phone_utils.dart';
import '../data/addis_locations.dart';

/// A customer's request to list their barbershop on the platform.
///
/// Stored at `shopApplications/{uid}` (doc id = the applicant's uid, so one
/// application per user). The applicant creates it (`pending`), may edit or
/// withdraw (delete) it while it is pending, and may overwrite it with a new
/// pending application after a rejection. The platform admin approves it
/// (the shop, its starter services and an owner invite for [email] are
/// created in the same batch, and the application gets `approved`,
/// `reviewedBy`, `reviewedAt` and `shopId`) or rejects it (`rejected`,
/// `reviewedBy`, `reviewedAt`, `rejectReason`).
class ShopApplication {
  /// Applicant uid; also the document id.
  final String uid;

  /// The applicant's profile email, lowercased. The owner invite is created
  /// for this address on approval.
  final String email;
  final String ownerName;
  final String shopName;
  final String address;

  /// One of [kAddisSubCities].
  final String subCity;

  /// Shop contact phone in E.164 (`+251...`), mobile or landline.
  final String phone;
  final String? description;
  final ShopApplicationStatus status;

  /// UTC.
  final DateTime createdAt;

  /// Admin uid (approved / rejected only).
  final String? reviewedBy;

  /// UTC (approved / rejected only).
  final DateTime? reviewedAt;

  /// The created shop (approved only).
  final String? shopId;

  /// Why the admin rejected it (rejected only).
  final String? rejectReason;

  const ShopApplication({
    required this.uid,
    required this.email,
    required this.ownerName,
    required this.shopName,
    required this.address,
    required this.subCity,
    required this.phone,
    this.description,
    this.status = ShopApplicationStatus.pending,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.shopId,
    this.rejectReason,
  });

  bool get isPending => status == ShopApplicationStatus.pending;
  bool get isApproved => status == ShopApplicationStatus.approved;
  bool get isRejected => status == ShopApplicationStatus.rejected;

  /// The fields the applicant writes on create / resubmit (status
  /// `pending`). Optional [description] is left out when empty.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'ownerName': ownerName,
        'shopName': shopName,
        'address': address,
        'subCity': subCity,
        'phone': phone,
        if (description != null && description!.isNotEmpty) 'description': description,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
        if (shopId != null) 'shopId': shopId,
        if (rejectReason != null) 'rejectReason': rejectReason,
      };

  factory ShopApplication.fromMap(Map<String, dynamic> map, String id) {
    final description = (map['description'] as String?)?.trim();
    return ShopApplication(
      uid: id,
      email: normalizeEmail((map['email'] as String?) ?? ''),
      ownerName: (map['ownerName'] as String?) ?? '',
      shopName: (map['shopName'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      subCity: (map['subCity'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      description: description == null || description.isEmpty ? null : description,
      status: ShopApplicationStatus.fromString(map['status'] as String?),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: _parseDate(map['reviewedAt']),
      shopId: map['shopId'] as String?,
      rejectReason: map['rejectReason'] as String?,
    );
  }

  ShopApplication copyWith({
    String? ownerName,
    String? shopName,
    String? address,
    String? subCity,
    String? phone,
    String? description,
    bool clearDescription = false,
    ShopApplicationStatus? status,
    DateTime? createdAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? shopId,
    String? rejectReason,
    bool clearReview = false,
  }) {
    return ShopApplication(
      uid: uid,
      email: email,
      ownerName: ownerName ?? this.ownerName,
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      subCity: subCity ?? this.subCity,
      phone: phone ?? this.phone,
      description: clearDescription ? null : (description ?? this.description),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedBy: clearReview ? null : (reviewedBy ?? this.reviewedBy),
      reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt),
      shopId: clearReview ? null : (shopId ?? this.shopId),
      rejectReason: clearReview ? null : (rejectReason ?? this.rejectReason),
    );
  }

  /// Pending first (oldest first, first come first served), then decided
  /// ones (most recently reviewed first).
  static int adminOrder(ShopApplication a, ShopApplication b) {
    if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
    if (a.isPending) return a.createdAt.compareTo(b.createdAt);
    return (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt);
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is Timestamp) return value.toDate().toUtc();
    return null;
  }
}

enum ShopApplicationStatus {
  pending,
  approved,
  rejected;

  static ShopApplicationStatus fromString(String? value) =>
      ShopApplicationStatus.values.where((s) => s.name == value).firstOrNull ?? ShopApplicationStatus.pending;
}

// --- Limits (the security rules must match) ---

const int kApplicationShopNameMin = 2;
const int kApplicationShopNameMax = 80;
const int kApplicationAddressMin = 2;
const int kApplicationAddressMax = 160;
const int kApplicationOwnerNameMax = 100;
const int kApplicationDescriptionMax = 500;
const int kApplicationRejectReasonMax = 300;

/// Why an application action was refused. Screens show these with
/// `applicationsErrorText` (lib/features/applications/applications_l10n.dart).
enum ShopApplicationErrorCode {
  ownerNameInvalid,
  shopNameInvalid,
  addressInvalid,
  subCityInvalid,
  phoneInvalid,

  /// args: [max characters].
  descriptionTooLong,

  /// args: [max characters].
  rejectReasonInvalid,

  /// Only signed-in customers apply (staff/owners/admins already have a role).
  customersOnly,

  /// The signed-in account has no email address (the invite needs one).
  emailMissing,

  /// A pending application exists: edit it instead.
  alreadyPending,

  /// The application was approved; nothing more to submit.
  alreadyApproved,

  /// Edit / withdraw / approve / reject need a pending application.
  notPending,
  notFound,
  adminOnly,
}

class ShopApplicationException implements Exception {
  ShopApplicationException(this.code, [this.args = const []]);

  final ShopApplicationErrorCode code;
  final List<Object?> args;

  @override
  String toString() => 'ShopApplicationException(${code.name}${args.isEmpty ? '' : ', $args'})';
}

/// The applicant's form input, validated and normalized.
class ShopApplicationInput {
  final String ownerName;
  final String shopName;
  final String address;
  final String subCity;

  /// E.164.
  final String phone;
  final String? description;

  const ShopApplicationInput._({
    required this.ownerName,
    required this.shopName,
    required this.address,
    required this.subCity,
    required this.phone,
    this.description,
  });

  /// Trims and checks every field (lengths, sub-city, Ethiopian contact
  /// phone). Throws [ShopApplicationException] for the first invalid one.
  factory ShopApplicationInput.validate({
    required String ownerName,
    required String shopName,
    required String address,
    required String subCity,
    required String phone,
    String? description,
  }) {
    final owner = ownerName.trim();
    if (owner.isEmpty || owner.length > kApplicationOwnerNameMax) {
      throw ShopApplicationException(ShopApplicationErrorCode.ownerNameInvalid);
    }
    final shop = shopName.trim();
    if (shop.length < kApplicationShopNameMin || shop.length > kApplicationShopNameMax) {
      throw ShopApplicationException(ShopApplicationErrorCode.shopNameInvalid);
    }
    final addr = address.trim();
    if (addr.length < kApplicationAddressMin || addr.length > kApplicationAddressMax) {
      throw ShopApplicationException(ShopApplicationErrorCode.addressInvalid);
    }
    if (!kAddisSubCities.contains(subCity)) {
      throw ShopApplicationException(ShopApplicationErrorCode.subCityInvalid);
    }
    final normalizedPhone = normalizeEthiopianContactPhone(phone);
    if (normalizedPhone == null) throw ShopApplicationException(ShopApplicationErrorCode.phoneInvalid);
    final desc = description?.trim() ?? '';
    if (desc.length > kApplicationDescriptionMax) {
      throw ShopApplicationException(ShopApplicationErrorCode.descriptionTooLong, [kApplicationDescriptionMax]);
    }
    return ShopApplicationInput._(
      ownerName: owner,
      shopName: shop,
      address: addr,
      subCity: subCity,
      phone: normalizedPhone,
      description: desc.isEmpty ? null : desc,
    );
  }
}

/// A trimmed reject reason of 1..[kApplicationRejectReasonMax] characters,
/// or throws [ShopApplicationErrorCode.rejectReasonInvalid].
String validateRejectReason(String reason) {
  final text = reason.trim();
  if (text.isEmpty || text.length > kApplicationRejectReasonMax) {
    throw ShopApplicationException(ShopApplicationErrorCode.rejectReasonInvalid, [kApplicationRejectReasonMax]);
  }
  return text;
}

/// What a submit means for the applicant's existing application (null =
/// none): `create` (none or rejected → a new pending one) or a refusal.
ShopApplicationErrorCode? submitBlocker(ShopApplication? existing) {
  if (existing == null || existing.isRejected) return null;
  if (existing.isApproved) return ShopApplicationErrorCode.alreadyApproved;
  return ShopApplicationErrorCode.alreadyPending;
}

/// Passed to `AppRepository.registerBarbershopByAdmin` when the shop comes
/// from an approved application: the application update is committed in the
/// same batch as the shop (Firestore), or by [applyLocally] right after it
/// (local mode).
class ShopApplicationApproval {
  ShopApplicationApproval({
    required this.applicantUid,
    required this.reviewedBy,
    required this.reviewedAt,
    this.applyLocally,
  });

  final String applicantUid;
  final String reviewedBy;
  final DateTime reviewedAt;

  /// Local mode: marks the application approved in the in-memory store.
  final Future<void> Function(String shopId)? applyLocally;

  /// Path of the application document.
  String get path => 'shopApplications/$applicantUid';

  /// The update written to the application: exactly these four fields.
  Map<String, dynamic> fieldsFor(String shopId) => {
        'status': ShopApplicationStatus.approved.name,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt.toUtc().toIso8601String(),
        'shopId': shopId,
      };
}
