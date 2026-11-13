import '../models/queue_entry.dart';

/// Minutes counted for a waiting entry without a (known) service.
const int kQueueDefaultServiceMinutes = 30;

/// Estimated waits of a walk-in queue. Pure; the same formula as the queue
/// Cloud Function (functions/queue/src/logic/estimate.ts):
///
///   wait of an entry = ceil(sum of service minutes of the waiting entries
///                      ahead of it / number of available barbers)
///
/// Only [QueueStatus.waiting] entries count, in arrival order ([createdAt],
/// then id). [QueueSummary.estimatedWaitMinutes] is the wait of someone
/// joining now. At least one barber is assumed.
QueueSummary estimateQueueWait({
  required Iterable<QueueEntry> entries,
  required Map<String, int> serviceDurations,
  required int availableBarbers,
  DateTime? now,
}) {
  final barbers = availableBarbers < 1 ? 1 : availableBarbers;
  final waiting = queueArrivalOrder(entries.where((e) => e.status == QueueStatus.waiting));
  final positions = <String, QueuePosition>{};
  var ahead = 0;
  for (var i = 0; i < waiting.length; i++) {
    final e = waiting[i];
    positions[e.id] = QueuePosition(position: i + 1, waitMinutes: _ceilDiv(ahead, barbers));
    ahead += queueServiceMinutes(e.serviceId, serviceDurations);
  }
  return QueueSummary(
    waitingCount: waiting.length,
    estimatedWaitMinutes: _ceilDiv(ahead, barbers),
    positions: positions,
    updatedAt: now?.toUtc(),
  );
}

int queueServiceMinutes(String? serviceId, Map<String, int> serviceDurations) {
  if (serviceId == null) return kQueueDefaultServiceMinutes;
  final d = serviceDurations[serviceId];
  return d != null && d > 0 ? d : kQueueDefaultServiceMinutes;
}

/// Arrival order: [QueueEntry.createdAt], then id.
List<QueueEntry> queueArrivalOrder(Iterable<QueueEntry> entries) {
  final list = entries.toList();
  list.sort((a, b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}

int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;
