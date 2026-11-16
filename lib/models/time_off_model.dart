/// A range of time a barber is not taking bookings:
/// `barbershops/{shopId}/barbers/{barberId}/timeOff/{id}`.
///
/// Created and deleted by the shop owner or by that barber, in the same
/// batch as one slot lock `{timeOffId, startAt, expiresAt}` per 15-minute
/// block of `[startAt, endAt)` (see lib/services/time_off_service.dart), so
/// customers see the time as busy and no booking can take it.
///
/// A vacation (several days, lib/services/vacation_service.dart) is stored
/// as several of these documents, one per working day (or part of a day
/// around a booking that is kept), sharing [groupId] plus the vacation's
/// first and last Addis dates [groupFrom]/[groupTo] (`yyyy-MM-dd`). Older
/// single-day documents have none of the three and read as before.
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
    this.groupId,
    this.groupFrom,
    this.groupTo,
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

  /// Vacation parts only: the id shared by every part of one vacation.
  final String? groupId;

  /// Vacation parts only: the vacation's first / last Addis date
  /// (`yyyy-MM-dd`, inclusive).
  final String? groupFrom;
  final String? groupTo;

  /// Whether this document is one part of a multi-day vacation.
  bool get isVacationPart => groupId != null && groupFrom != null && groupTo != null;

  Duration get duration => endAt.difference(startAt);

  Map<String, dynamic> toMap() => {
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (isVacationPart) ...{
          'groupId': groupId,
          'groupFrom': groupFrom,
          'groupTo': groupTo,
        },
      };

  factory TimeOff.fromMap(Map<String, dynamic> map, String id, {required String shopId, required String barberId}) {
    DateTime parse(Object? raw) =>
        (raw is String ? DateTime.tryParse(raw) : null)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final reason = map['reason'];
    String? text(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;
    final groupId = text(map['groupId']);
    final groupFrom = text(map['groupFrom']);
    final groupTo = text(map['groupTo']);
    final grouped = groupId != null && groupFrom != null && groupTo != null;
    return TimeOff(
      id: id,
      shopId: shopId,
      barberId: barberId,
      startAt: parse(map['startAt']),
      endAt: parse(map['endAt']),
      reason: reason is String && reason.isNotEmpty ? reason : null,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parse(map['createdAt']),
      groupId: grouped ? groupId : null,
      groupFrom: grouped ? groupFrom : null,
      groupTo: grouped ? groupTo : null,
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
      other.createdBy == createdBy &&
      other.groupId == groupId &&
      other.groupFrom == groupFrom &&
      other.groupTo == groupTo;

  @override
  int get hashCode => Object.hash(id, shopId, barberId, startAt, endAt, reason, createdBy, groupId, groupFrom, groupTo);
}

/// Longest time-off note.
const int kMaxTimeOffReasonLength = 200;
