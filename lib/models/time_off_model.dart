/// A range of time a barber is not taking bookings:
/// `barbershops/{shopId}/barbers/{barberId}/timeOff/{id}`.
///
/// Created and deleted by the shop owner or by that barber, in the same
/// batch as one slot lock `{timeOffId, startAt, expiresAt}` per 15-minute
/// block of `[startAt, endAt)` (see lib/services/time_off_service.dart), so
/// customers see the time as busy and no booking can take it.
class TimeOff {
  const TimeOff({
    required this.id,
    required this.shopId,
    required this.barberId,
    required this.startAt,
    required this.endAt,
    this.reason,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;

  /// Path parents (not stored as fields).
  final String shopId;
  final String barberId;

  /// UTC, on the 15-minute grid, `[startAt, endAt)`.
  final DateTime startAt;
  final DateTime endAt;

  /// Optional note (up to [kMaxTimeOffReasonLength] characters).
  final String? reason;

  /// uid of the owner or barber who added it.
  final String createdBy;
  final DateTime createdAt;

  Duration get duration => endAt.difference(startAt);

  Map<String, dynamic> toMap() => {
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory TimeOff.fromMap(Map<String, dynamic> map, String id, {required String shopId, required String barberId}) {
    DateTime parse(Object? raw) =>
        (raw is String ? DateTime.tryParse(raw) : null)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final reason = map['reason'];
    return TimeOff(
      id: id,
      shopId: shopId,
      barberId: barberId,
      startAt: parse(map['startAt']),
      endAt: parse(map['endAt']),
      reason: reason is String && reason.isNotEmpty ? reason : null,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parse(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TimeOff &&
      other.id == id &&
      other.shopId == shopId &&
      other.barberId == barberId &&
      other.startAt == startAt &&
      other.endAt == endAt &&
      other.reason == reason &&
      other.createdBy == createdBy;

  @override
  int get hashCode => Object.hash(id, shopId, barberId, startAt, endAt, reason, createdBy);
}

/// Longest time-off note.
const int kMaxTimeOffReasonLength = 200;
