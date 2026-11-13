/**
 * Recomputes barbershops/{shopId}/queueSummary/current after any change to
 * the shop's queue. Pure orchestration over injected ports, so it runs
 * inside a Firestore transaction (index.ts) or against fakes (tests).
 */
import {
  ACTIVE_STATUSES,
  arrivalOrder,
  estimateQueue,
  type QueueEntry,
  type QueueEntryDoc,
  type QueuePosition,
} from './estimate';

export interface QueueSummaryDoc {
  waitingCount: number;
  estimatedWaitMinutes: number;
  /**
   * Waiting entries by id (ids are random and carry no personal data), so a
   * remote customer can show their own position without reading the queue.
   */
  positions: Record<string, QueuePosition>;
  updatedAt: string;
}

export interface RecomputePorts {
  /** Entries with status 'waiting' or 'serving'. */
  listActive(): Promise<QueueEntry[]>;
  /** serviceId -> durationMinutes for the shop's services. */
  serviceDurations(): Promise<Record<string, number>>;
  /** Barbers of the shop with isAvailable != false. */
  availableBarbers(): Promise<number>;
  /** Marks duplicate remote entries as left. */
  markLeft(ids: string[], nowIso: string): void;
  writeSummary(summary: QueueSummaryDoc): void;
}

export interface RecomputeResult {
  summary: QueueSummaryDoc;
  /** Remote entries closed because the customer already had one. */
  duplicates: string[];
  /** The first waiting entry, when a remote customer added it. */
  nextRemote: QueueEntry | null;
}

const isActive = (status: string | undefined): boolean =>
  status !== undefined && (ACTIVE_STATUSES as readonly string[]).includes(status);

/** Whether a write to a queue entry can change the summary. */
export function affectsSummary(
  before: QueueEntryDoc | null | undefined,
  after: QueueEntryDoc | null | undefined,
): boolean {
  return isActive(before?.status) || isActive(after?.status);
}

/**
 * A customer may hold one active remote entry per shop. The app checks this
 * before joining; joins racing each other are resolved here: the entry
 * already being served, else the earliest, is kept and later waiting ones
 * are marked left.
 */
export function findDuplicateRemoteEntries(active: readonly QueueEntry[]): string[] {
  const byCustomer = new Map<string, QueueEntry[]>();
  for (const e of active) {
    if (e.source !== 'remote' || !e.addedBy || !isActive(e.status)) continue;
    const list = byCustomer.get(e.addedBy) ?? [];
    list.push(e);
    byCustomer.set(e.addedBy, list);
  }
  const duplicates: string[] = [];
  for (const list of byCustomer.values()) {
    if (list.length < 2) continue;
    const ordered = arrivalOrder(list);
    const keep = ordered.find((e) => e.status === 'serving') ?? ordered[0];
    for (const e of ordered) if (e !== keep && e.status === 'waiting') duplicates.push(e.id);
  }
  return duplicates;
}

export async function recomputeQueue(now: Date, ports: RecomputePorts): Promise<RecomputeResult> {
  const [active, durations, barbers] = await Promise.all([
    ports.listActive(),
    ports.serviceDurations(),
    ports.availableBarbers(),
  ]);
  const nowIso = now.toISOString();
  const duplicates = findDuplicateRemoteEntries(active);
  if (duplicates.length > 0) ports.markLeft(duplicates, nowIso);
  const remaining = active.filter((e) => !duplicates.includes(e.id));
  const estimate = estimateQueue(remaining, durations, barbers);
  const summary: QueueSummaryDoc = { ...estimate, updatedAt: nowIso };
  ports.writeSummary(summary);

  const first = arrivalOrder(remaining.filter((e) => e.status === 'waiting'))[0];
  const nextRemote = first && first.source === 'remote' && first.addedBy ? first : null;
  return { summary, duplicates, nextRemote };
}

/**
 * Inbox doc id (and push idempotency key) for "you're next". It includes the
 * entry's createdAt so the customer is told once per entry.
 */
export function queueNextNotificationId(entryId: string, createdAt: string | undefined): string {
  const ms = createdAt ? Date.parse(createdAt) : NaN;
  return `queue_${entryId}-${Number.isFinite(ms) ? ms : 0}_queueNext`;
}
