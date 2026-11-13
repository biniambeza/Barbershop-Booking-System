/// Walk-in queue documents.
///
///  * `barbershops/{shopId}/queue/{entryId}`: one person in (or once in) the
///    shop's walk-in queue. Added by the owner or a barber of the shop
///    ([QueueSource.walkIn]) or by a signed-in customer from the app
///    ([QueueSource.remote], with their own name and phone and `addedBy` ==
///    their uid).
///  * `barbershops/{shopId}/queueSummary/current`: public summary
///    ([QueueSummary]), written only by the queue Cloud Functions
///    (functions/queue).
///
/// All times are stored as UTC ISO-8601 strings.
library;

enum QueueStatus {
  waiting,
  serving,
  done,
  left;

  bool get isActive => this == waiting || this == serving;

  static QueueStatus fromString(String? value) =>
      QueueStatus.values.firstWhere((s) => s.name == value, orElse: () => QueueStatus.waiting);
}

enum QueueSource {
  walkIn,
  remote;

  static QueueSource fromString(String? value) =>
      QueueSource.values.firstWhere((s) => s.name == value, orElse: () => QueueSource.walkIn);
}

/// Longest name stored on an entry.
const int kQueueNameMaxLength = 60;

class QueueEntry {
  final String id;
  final String shopId;
  final String name;

  /// E.164 (`+2519XXXXXXXX`), optional.
  final String? phone;
  final String? serviceId;

  /// The preferred barber while waiting; the serving barber once serving.
  final String? barberId;
  final QueueStatus status;

  /// UTC.
  final DateTime createdAt;
  final DateTime? servingStartedAt;
  final DateTime? finishedAt;

  /// uid of whoever added the entry (staff member, or the remote customer).
  final String addedBy;
  final QueueSource source;

  const QueueEntry({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.serviceId,
    this.barberId,
    this.status = QueueStatus.waiting,
    required this.createdAt,
    this.servingStartedAt,
    this.finishedAt,
    required this.addedBy,
    this.source = QueueSource.walkIn,
  });

  bool get isActive => status.isActive;
  bool get isRemote => source == QueueSource.remote;

  /// Firestore fields (no `shopId`: it is in the path). Null optionals are
  /// left out.
  Map<String, dynamic> toMap() => {
        'name': name,
        if (phone != null) 'phone': phone,
        if (serviceId != null) 'serviceId': serviceId,
        if (barberId != null) 'barberId': barberId,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (servingStartedAt != null) 'servingStartedAt': servingStartedAt!.toUtc().toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt!.toUtc().toIso8601String(),
        'addedBy': addedBy,
        'source': source.name,
      };

  factory QueueEntry.fromMap(Map<String, dynamic> map, String id, {required String shopId}) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    return QueueEntry(
      id: id,
      shopId: shopId,
      name: (map['name'] as String?) ?? '',
      phone: str(map['phone']),
      serviceId: str(map['serviceId']),
      barberId: str(map['barberId']),
      status: QueueStatus.fromString(map['status'] as String?),
      createdAt: date(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      servingStartedAt: date(map['servingStartedAt']),
      finishedAt: date(map['finishedAt']),
      addedBy: (map['addedBy'] as String?) ?? '',
      source: QueueSource.fromString(map['source'] as String?),
    );
  }

  QueueEntry copyWith({
    QueueStatus? status,
    String? barberId,
    DateTime? servingStartedAt,
    DateTime? finishedAt,
  }) =>
      QueueEntry(
        id: id,
        shopId: shopId,
        name: name,
        phone: phone,
        serviceId: serviceId,
        barberId: barberId ?? this.barberId,
        status: status ?? this.status,
        createdAt: createdAt,
        servingStartedAt: servingStartedAt ?? this.servingStartedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        addedBy: addedBy,
        source: source,
      );
}

/// Place of one waiting entry in line.
class QueuePosition {
  /// 1 = next.
  final int position;
  final int waitMinutes;

  const QueuePosition({required this.position, required this.waitMinutes});

  Map<String, dynamic> toMap() => {'position': position, 'waitMinutes': waitMinutes};

  @override
  bool operator ==(Object other) =>
      other is QueuePosition && other.position == position && other.waitMinutes == waitMinutes;

  @override
  int get hashCode => Object.hash(position, waitMinutes);

  @override
  String toString() => 'QueuePosition($position, $waitMinutes min)';
}

/// `barbershops/{shopId}/queueSummary/current`.
class QueueSummary {
  final int waitingCount;

  /// Wait for someone joining now.
  final int estimatedWaitMinutes;

  /// Waiting entries by id (random ids, no personal data), so a remote
  /// customer can see their own place without reading the queue.
  final Map<String, QueuePosition> positions;
  final DateTime? updatedAt;

  const QueueSummary({
    required this.waitingCount,
    required this.estimatedWaitMinutes,
    this.positions = const {},
    this.updatedAt,
  });

  static const empty = QueueSummary(waitingCount: 0, estimatedWaitMinutes: 0);

  Map<String, dynamic> toMap() => {
        'waitingCount': waitingCount,
        'estimatedWaitMinutes': estimatedWaitMinutes,
        'positions': {for (final e in positions.entries) e.key: e.value.toMap()},
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  factory QueueSummary.fromMap(Map<String, dynamic> map) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final raw = map['positions'];
    final positions = <String, QueuePosition>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is String && value is Map) {
          positions[key] = QueuePosition(position: asInt(value['position']), waitMinutes: asInt(value['waitMinutes']));
        }
      });
    }
    final updated = map['updatedAt'];
    return QueueSummary(
      waitingCount: asInt(map['waitingCount']),
      estimatedWaitMinutes: asInt(map['estimatedWaitMinutes']),
      positions: positions,
      updatedAt: updated is String ? DateTime.tryParse(updated)?.toUtc() : null,
    );
  }
}
