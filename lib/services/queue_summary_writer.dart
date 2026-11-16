/// Free-plan fallback for the walk-in queue summary.
///
/// `barbershops/{shopId}/queueSummary/current` is written by the queue Cloud
/// Function (functions/queue, `onQueueEntryWritten`). On the free Spark plan
/// functions do not run, so the staff app (the shop's owner or a barber, who
/// can read every active entry) recomputes and writes the same document:
///
///  * after every staff queue action (add, start serving, finish, left);
///  * whenever the staff's live queue listener emits (the queue screen or
///    dashboard card opening, a customer joining or leaving).
///
/// Calls are debounced per shop. The computation is the function's
/// (functions/queue/src/logic/recompute.ts + estimate.ts), ported here and in
/// queue_wait.dart, and the document has exactly its key set:
///
///   {waitingCount: int, estimatedWaitMinutes: int,
///    positions: {entryId: {position: int, waitMinutes: int}},
///    updatedAt: UTC ISO string with milliseconds ('...Z')}
///
/// Idempotent and compatible with the function: before writing it reads the
/// current document and skips the write when everything but `updatedAt` is
/// already equal (on the Blaze plan the function has usually written it
/// first). Duplicate remote entries of one customer are closed ('left') with
/// the staff "left" update the function would make.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/queue_entry.dart';
import 'queue_wait.dart';

/// Debounce of [QueueSummaryWriter.schedule].
const Duration kQueueSummaryDebounce = Duration(milliseconds: 800);

/// Remote entries closed because the same customer already holds an active
/// entry (functions/queue `findDuplicateRemoteEntries`): the entry being
/// served, else the earliest, is kept; later waiting ones are duplicates.
List<String> findDuplicateRemoteEntries(Iterable<QueueEntry> active) {
  final byCustomer = <String, List<QueueEntry>>{};
  for (final e in active) {
    if (e.source != QueueSource.remote || e.addedBy.isEmpty || !e.isActive) continue;
    (byCustomer[e.addedBy] ??= []).add(e);
  }
  final duplicates = <String>[];
  for (final list in byCustomer.values) {
    if (list.length < 2) continue;
    final ordered = queueArrivalOrder(list);
    final keep = ordered.where((e) => e.status == QueueStatus.serving).firstOrNull ?? ordered.first;
    for (final e in ordered) {
      if (e.id != keep.id && e.status == QueueStatus.waiting) duplicates.add(e.id);
    }
  }
  return duplicates;
}

/// UTC ISO string with millisecond precision, like JavaScript's
/// `Date.toISOString()` ('2026-11-16T07:00:00.000Z').
String isoMillisUtc(DateTime time) {
  final utc = time.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(utc.millisecondsSinceEpoch, isUtc: true).toIso8601String();
}

/// The `queueSummary/current` document for [summary] (exact function shape).
Map<String, dynamic> queueSummaryDoc(QueueSummary summary, DateTime now) => {
      'waitingCount': summary.waitingCount,
      'estimatedWaitMinutes': summary.estimatedWaitMinutes,
      'positions': {
        for (final e in summary.positions.entries)
          e.key: {'position': e.value.position, 'waitMinutes': e.value.waitMinutes},
      },
      'updatedAt': isoMillisUtc(now),
    };

/// Result of [planQueueSummary]: the document to write and the duplicate
/// remote entries to close.
class QueueSummaryPlan {
  const QueueSummaryPlan({required this.summary, required this.doc, required this.duplicates});

  final QueueSummary summary;
  final Map<String, dynamic> doc;
  final List<String> duplicates;
}

/// Pure: what the function would write for the shop's [active] entries
/// (status waiting or serving), given its services' durations and the number
/// of barbers taking customers.
QueueSummaryPlan planQueueSummary({
  required Iterable<QueueEntry> active,
  required Map<String, int> serviceDurations,
  required int availableBarbers,
  required DateTime now,
}) {
  final list = active.where((e) => e.isActive).toList();
  final duplicates = findDuplicateRemoteEntries(list);
  final remaining = list.where((e) => !duplicates.contains(e.id));
  final summary = estimateQueueWait(
    entries: remaining,
    serviceDurations: serviceDurations,
    availableBarbers: availableBarbers,
    now: now,
  );
  return QueueSummaryPlan(summary: summary, doc: queueSummaryDoc(summary, now), duplicates: duplicates);
}

/// Whether two summary documents say the same thing (`updatedAt` ignored).
bool sameQueueSummaryContent(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (a == null || b == null) return false;
  int? asInt(Object? v) => v is num ? v.toInt() : null;
  if (asInt(a['waitingCount']) != asInt(b['waitingCount'])) return false;
  if (asInt(a['estimatedWaitMinutes']) != asInt(b['estimatedWaitMinutes'])) return false;
  final pa = a['positions'];
  final pb = b['positions'];
  if (pa is! Map || pb is! Map || pa.length != pb.length) return false;
  for (final key in pa.keys) {
    final x = pa[key];
    final y = pb[key];
    if (x is! Map || y is! Map) return false;
    if (asInt(x['position']) != asInt(y['position']) || asInt(x['waitMinutes']) != asInt(y['waitMinutes'])) {
      return false;
    }
  }
  // Extra keys (an older or foreign shape) force a rewrite.
  const keys = {'waitingCount', 'estimatedWaitMinutes', 'positions', 'updatedAt'};
  return a.keys.every(keys.contains) && b.keys.every(keys.contains);
}

/// What one recompute did.
enum QueueSummaryWriteOutcome {
  /// The document was written.
  written,

  /// The stored document already had the same content.
  unchanged,

  /// Reading or writing failed (offline, rules not deployed yet...).
  failed,
}

/// Recomputes and writes `queueSummary/current` from the staff app. All
/// Firestore access goes through the injected functions (see QueueService).
class QueueSummaryWriter {
  QueueSummaryWriter({
    required this.fetchActive,
    required this.readSummary,
    required this.writeSummary,
    required this.markLeft,
    required this.serviceDurations,
    required this.availableBarbers,
    this.debounce = kQueueSummaryDebounce,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Active entries (waiting + serving) of a shop.
  final Future<List<QueueEntry>> Function(String shopId) fetchActive;

  /// The stored summary document, or null when missing.
  final Future<Map<String, dynamic>?> Function(String shopId) readSummary;

  /// Sets (replaces) the summary document.
  final Future<void> Function(String shopId, Map<String, dynamic> doc) writeSummary;

  /// Closes a duplicate remote entry: {status: 'left', finishedAt}.
  final Future<void> Function(QueueEntry entry, String finishedAtIso) markLeft;

  final Map<String, int> Function(String shopId) serviceDurations;
  final int Function(String shopId) availableBarbers;
  final Duration debounce;
  final DateTime Function() _clock;

  final Map<String, Timer> _timers = {};
  final Map<String, List<QueueEntry>?> _pendingEntries = {};
  final Map<String, Future<QueueSummaryWriteOutcome>> _running = {};

  /// Recomputes [shopId]'s summary after [debounce]. [entries], when given,
  /// are the shop's active entries as the staff listener saw them (saves a
  /// read); otherwise they are fetched.
  void schedule(String shopId, {List<QueueEntry>? entries}) {
    _timers[shopId]?.cancel();
    // The latest call wins: a listener's fresh entries, or null (fetch).
    _pendingEntries[shopId] = entries;
    _timers[shopId] = Timer(debounce, () {
      _timers.remove(shopId);
      final pending = _pendingEntries.remove(shopId);
      unawaited(recomputeNow(shopId, entries: pending));
    });
  }

  /// Whether a debounced recompute is waiting for [shopId].
  bool isScheduled(String shopId) => _timers.containsKey(shopId);

  /// Recomputes now (after any recompute already running for the shop).
  /// Never throws: failures are logged and reported as
  /// [QueueSummaryWriteOutcome.failed].
  Future<QueueSummaryWriteOutcome> recomputeNow(String shopId, {List<QueueEntry>? entries}) {
    final previous = _running[shopId];
    final next = (previous ?? Future<QueueSummaryWriteOutcome>.value(QueueSummaryWriteOutcome.unchanged))
        .then((_) => _recompute(shopId, entries));
    _running[shopId] = next;
    next.whenComplete(() {
      if (identical(_running[shopId], next)) _running.remove(shopId);
    });
    return next;
  }

  Future<QueueSummaryWriteOutcome> _recompute(String shopId, List<QueueEntry>? entries) async {
    try {
      final active = entries ?? await fetchActive(shopId);
      final now = _clock().toUtc();
      final plan = planQueueSummary(
        active: active,
        serviceDurations: serviceDurations(shopId),
        availableBarbers: availableBarbers(shopId),
        now: now,
      );
      final nowIso = isoMillisUtc(now);
      for (final id in plan.duplicates) {
        final entry = active.firstWhere((e) => e.id == id);
        try {
          await markLeft(entry, nowIso);
        } catch (e) {
          debugPrint('Could not close duplicate queue entry $id: $e');
        }
      }
      final current = await readSummary(shopId);
      if (sameQueueSummaryContent(current, plan.doc)) return QueueSummaryWriteOutcome.unchanged;
      await writeSummary(shopId, plan.doc);
      return QueueSummaryWriteOutcome.written;
    } catch (e) {
      debugPrint('Could not update the queue summary of $shopId: $e');
      return QueueSummaryWriteOutcome.failed;
    }
  }

  /// Cancels pending debounced recomputes.
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pendingEntries.clear();
  }
}
