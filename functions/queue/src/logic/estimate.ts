/**
 * Estimated-wait math for the walk-in queue. Pure (no Firebase).
 *
 * The Flutter staff screen uses the same formula
 * (lib/services/queue_wait.dart), so both must change together:
 *
 *   wait of an entry = ceil(sum of service minutes of the waiting entries
 *                      ahead of it / number of available barbers)
 *
 * An entry without a (known) service counts DEFAULT_SERVICE_MINUTES. The
 * summary's estimatedWaitMinutes is the wait of someone joining now (all
 * waiting entries are ahead). At least one barber is assumed, so a shop
 * whose barbers are all marked unavailable still gets an estimate.
 */

export const DEFAULT_SERVICE_MINUTES = 30;

export type QueueStatus = 'waiting' | 'serving' | 'done' | 'left';
export const ACTIVE_STATUSES: readonly QueueStatus[] = ['waiting', 'serving'];

/** barbershops/{shopId}/queue/{entryId} as stored. */
export interface QueueEntryDoc {
  name?: string;
  phone?: string | null;
  serviceId?: string | null;
  barberId?: string | null;
  status?: string;
  createdAt?: string;
  servingStartedAt?: string | null;
  finishedAt?: string | null;
  addedBy?: string;
  source?: string;
}

export interface QueueEntry extends QueueEntryDoc {
  id: string;
}

export interface QueuePosition {
  /** 1 = next in line. */
  position: number;
  waitMinutes: number;
}

export interface QueueEstimate {
  waitingCount: number;
  /** Wait for someone joining now. */
  estimatedWaitMinutes: number;
  /** Waiting entries by id. */
  positions: Record<string, QueuePosition>;
}

/** Arrival order: createdAt (ISO strings sort chronologically), then id. */
export function arrivalOrder<T extends { id: string; createdAt?: string }>(entries: readonly T[]): T[] {
  return [...entries].sort((a, b) => {
    const ca = a.createdAt ?? '';
    const cb = b.createdAt ?? '';
    if (ca !== cb) return ca < cb ? -1 : 1;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
}

export function serviceMinutes(
  serviceId: string | null | undefined,
  durations: Readonly<Record<string, number>>,
): number {
  if (!serviceId) return DEFAULT_SERVICE_MINUTES;
  const d = durations[serviceId];
  return typeof d === 'number' && Number.isFinite(d) && d > 0 ? d : DEFAULT_SERVICE_MINUTES;
}

/**
 * Positions and waits of the 'waiting' entries of `entries` (other statuses
 * are ignored), in arrival order.
 */
export function estimateQueue(
  entries: readonly QueueEntry[],
  durations: Readonly<Record<string, number>>,
  availableBarbers: number,
): QueueEstimate {
  const barbers = Math.max(1, Math.floor(Number.isFinite(availableBarbers) ? availableBarbers : 1));
  const waiting = arrivalOrder(entries.filter((e) => e.status === 'waiting'));
  const positions: Record<string, QueuePosition> = {};
  let ahead = 0;
  waiting.forEach((e, i) => {
    positions[e.id] = { position: i + 1, waitMinutes: Math.ceil(ahead / barbers) };
    ahead += serviceMinutes(e.serviceId, durations);
  });
  return { waitingCount: waiting.length, estimatedWaitMinutes: Math.ceil(ahead / barbers), positions };
}
