/**
 * Slot-lock ids, ported from lib/services/availability_service.dart
 * (slotLockId, slotBlocksFor, slotLockIdsFor). Both sides are checked
 * against the same fixture (test/fixtures/lock_ids.json, also read by
 * test/slot_lock_parity_test.dart in the Flutter app).
 *
 * A booking holds one lock per 15-minute block of [startAt, endAt), at
 * barbershops/{shopId}/barbers/{barberId}/slotLocks/{yyyyMMdd-HHmm}, where
 * the id is the Addis Ababa wall clock (UTC+3, no DST) of the block start.
 */

export const ADDIS_OFFSET_MS = 3 * 60 * 60 * 1000;
export const SLOT_STEP_MINUTES = 15;
const STEP_MS = SLOT_STEP_MINUTES * 60 * 1000;

/** How long a lock outlives its booking's end (Dart kSlotLockRetention). */
export const SLOT_LOCK_RETENTION_MS = 24 * 60 * 60 * 1000;

const pad = (n: number): string => String(n).padStart(2, '0');

/** `yyyyMMdd-HHmm` (Addis wall clock) of the block starting at `blockStart`. */
export function slotLockId(blockStart: Date): string {
  const a = new Date(blockStart.getTime() + ADDIS_OFFSET_MS);
  return (
    `${a.getUTCFullYear()}${pad(a.getUTCMonth() + 1)}${pad(a.getUTCDate())}` +
    `-${pad(a.getUTCHours())}${pad(a.getUTCMinutes())}`
  );
}

/**
 * Starts of every 15-minute block that [start, end) touches. Off-grid
 * appointments lock their partial blocks too, and a zero-length one still
 * holds its first block (same as the Dart do/while loop).
 */
export function slotBlocksFor(start: Date, end: Date): Date[] {
  const startMs = start.getTime();
  const endMs = end.getTime();
  let blockMs = startMs - (((startMs % STEP_MS) + STEP_MS) % STEP_MS);
  const blocks: Date[] = [];
  do {
    blocks.push(new Date(blockMs));
    blockMs += STEP_MS;
  } while (blockMs < endMs);
  return blocks;
}

export function slotLockIdsFor(start: Date, end: Date): string[] {
  return slotBlocksFor(start, end).map(slotLockId);
}

/** A lock's `expiresAt`: the booking's end plus one day, as a UTC ISO string. */
export function lockExpiresAt(bookingEnd: Date): string {
  return new Date(bookingEnd.getTime() + SLOT_LOCK_RETENTION_MS).toISOString();
}

/**
 * Reads a stored instant: an ISO-8601 string (the app's format) or a
 * Firestore Timestamp-like value with toDate(). Null if neither.
 */
export function toInstant(value: unknown): Date | null {
  if (typeof value === 'string' && value.length > 0) {
    const ms = Date.parse(value);
    return Number.isNaN(ms) ? null : new Date(ms);
  }
  if (value && typeof (value as { toDate?: unknown }).toDate === 'function') {
    const d = (value as { toDate: () => unknown }).toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  return null;
}
