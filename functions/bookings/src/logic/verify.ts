/**
 * Server-side check that a new booking holds a slot lock for EVERY one of
 * its 15-minute blocks. The security rules only check the first four and
 * the last block (per-request limits on document reads), so a modified
 * client could create a long booking without its middle locks and overlap
 * someone else. This runs in the onCreate trigger, inside a transaction.
 */
import { slotLockIdsFor, toInstant } from './lockIds';

export const SYSTEM_CANCELLER = 'system';
export const SLOT_CONFLICT_REASON = 'slot_conflict';

/** Upper bound on the locks one booking may need (a 24h booking). */
export const MAX_LOCKS_PER_BOOKING = 96;

export interface BookingData {
  shopId?: unknown;
  barberId?: unknown;
  status?: unknown;
  startAt?: unknown;
  endAt?: unknown;
  [key: string]: unknown;
}

export interface LockData {
  bookingId?: unknown;
  [key: string]: unknown;
}

/** Where a booking's locks live and which ids it needs. */
export interface LockPlan {
  shopId: string;
  barberId: string;
  lockIds: string[];
}

export type SkipReason = 'missing' | 'cancelled' | 'no_interval' | 'bad_refs' | 'too_long';

/**
 * The locks to read for a booking, or why the booking is not checked:
 * already gone or cancelled (idempotent re-runs), a legacy booking without
 * an interval, or unusable shop/barber ids.
 */
export function planLockCheck(booking: BookingData | null): LockPlan | { skip: SkipReason } {
  if (!booking) return { skip: 'missing' };
  if (booking.status === 'cancelled') return { skip: 'cancelled' };
  const { shopId, barberId } = booking;
  if (!isDocId(shopId) || !isDocId(barberId)) return { skip: 'bad_refs' };
  const start = toInstant(booking.startAt);
  const end = toInstant(booking.endAt);
  if (!start || !end || end.getTime() < start.getTime()) return { skip: 'no_interval' };
  const lockIds = slotLockIdsFor(start, end);
  if (lockIds.length > MAX_LOCKS_PER_BOOKING) return { skip: 'too_long' };
  return { shopId, barberId, lockIds };
}

export interface LockVerdict {
  ok: boolean;
  /** Blocks with no lock at all. */
  missing: string[];
  /** Blocks locked by a different booking. */
  foreign: string[];
  /** Locks held by this booking (deleted when it is cancelled). */
  own: string[];
}

/** `locks[i]` is the lock document for `lockIds[i]`, or null if absent. */
export function judgeLocks(bookingId: string, lockIds: string[], locks: (LockData | null)[]): LockVerdict {
  const missing: string[] = [];
  const foreign: string[] = [];
  const own: string[] = [];
  lockIds.forEach((id, i) => {
    const lock = locks[i];
    if (!lock) missing.push(id);
    else if (lock.bookingId === bookingId) own.push(id);
    else foreign.push(id);
  });
  return { ok: missing.length === 0 && foreign.length === 0, missing, foreign, own };
}

/** Fields written to a booking cancelled for a lock conflict. */
export function conflictCancellation(): Record<string, string> {
  return { status: 'cancelled', cancelledBy: SYSTEM_CANCELLER, cancelReason: SLOT_CONFLICT_REASON };
}

/**
 * The transaction operations the check needs, so the flow can be unit
 * tested without Firestore. Reads must all happen before writes.
 */
export interface VerifyTx {
  getBooking(): Promise<BookingData | null>;
  getLocks(shopId: string, barberId: string, lockIds: string[]): Promise<(LockData | null)[]>;
  updateBooking(fields: Record<string, string>): void;
  deleteLocks(shopId: string, barberId: string, lockIds: string[]): void;
}

export type VerifyOutcome =
  | { result: 'skipped'; reason: SkipReason }
  | { result: 'ok'; locks: number }
  | { result: 'cancelled'; missing: string[]; foreign: string[]; released: string[] };

/**
 * One attempt of the check (run inside a transaction; safe to repeat:
 * a booking that is already cancelled is skipped).
 */
export async function verifyBookingLocksInTx(bookingId: string, tx: VerifyTx): Promise<VerifyOutcome> {
  const plan = planLockCheck(await tx.getBooking());
  if ('skip' in plan) return { result: 'skipped', reason: plan.skip };
  const locks = await tx.getLocks(plan.shopId, plan.barberId, plan.lockIds);
  const verdict = judgeLocks(bookingId, plan.lockIds, locks);
  if (verdict.ok) return { result: 'ok', locks: plan.lockIds.length };
  tx.updateBooking(conflictCancellation());
  if (verdict.own.length > 0) tx.deleteLocks(plan.shopId, plan.barberId, verdict.own);
  return { result: 'cancelled', missing: verdict.missing, foreign: verdict.foreign, released: verdict.own };
}

function isDocId(v: unknown): v is string {
  return typeof v === 'string' && v.length > 0 && v.length <= 128 && !v.includes('/');
}
