/**
 * Barber acceptance: expiry of unanswered booking requests.
 *
 * When a shop has `requireBarberAcceptance`, new customer bookings start
 * with status 'pending' (holding their slot locks). A request that is still
 * pending once its start is within PENDING_EXPIRY_LEAD_MINUTES (or already
 * past) is cancelled by the scheduled `expirePendingBookings` function:
 * `{status: 'cancelled', cancelledBy: 'system', cancelReason: 'not_accepted'}`,
 * and the booking's own slot locks are deleted (as any cancellation does).
 *
 * Mirrors lib/services/booking_acceptance.dart (kPendingExpiryLead,
 * kNotAcceptedReason, isRequestExpired).
 */
import { BookingData, LockData, judgeLocks, planLockCheck, SYSTEM_CANCELLER } from './verify';
import { toInstant } from './lockIds';

/** Unanswered requests expire this long before their start. */
export const PENDING_EXPIRY_LEAD_MINUTES = 60;

/** cancelReason of a request that expired unanswered. */
export const NOT_ACCEPTED_REASON = 'not_accepted';

/** Most pending bookings read per run (the next run, 15 minutes later, continues). */
export const EXPIRE_MAX_PER_RUN = 500;

/** Requests starting at or before this instant are expired. */
export function expiryCutoff(now: Date): Date {
  return new Date(now.getTime() + PENDING_EXPIRY_LEAD_MINUTES * 60 * 1000);
}

/**
 * True for a 'pending' booking whose start is within the expiry lead of
 * `now` (or already passed). A booking without a readable startAt is left
 * alone (legacy data; nothing to compare).
 */
export function isExpiredRequest(booking: BookingData | null | undefined, now: Date): boolean {
  if (!booking || booking.status !== 'pending') return false;
  const start = toInstant(booking.startAt);
  if (!start) return false;
  return start.getTime() <= expiryCutoff(now).getTime();
}

/** Ids of the expired requests among `docs` (from a `status == 'pending'` query). */
export function selectExpiredRequests(docs: { id: string; data: BookingData }[], now: Date): string[] {
  return docs.filter((d) => isExpiredRequest(d.data, now)).map((d) => d.id);
}

/** Fields written to an expired request. */
export function notAcceptedCancellation(): Record<string, string> {
  return { status: 'cancelled', cancelledBy: SYSTEM_CANCELLER, cancelReason: NOT_ACCEPTED_REASON };
}

/** The transaction operations, so the flow can be tested without Firestore. */
export interface ExpireTx {
  getBooking(): Promise<BookingData | null>;
  getLocks(shopId: string, barberId: string, lockIds: string[]): Promise<(LockData | null)[]>;
  updateBooking(fields: Record<string, string>): void;
  deleteLocks(shopId: string, barberId: string, lockIds: string[]): void;
}

export type ExpireOutcome =
  | { result: 'skipped'; reason: 'not_expired' }
  | { result: 'expired'; released: string[] };

/**
 * One attempt (inside a transaction): re-reads the booking so a request the
 * barber accepted or declined in the meantime is left alone, then cancels
 * it and deletes only the locks it owns.
 */
export async function expireRequestInTx(bookingId: string, now: Date, tx: ExpireTx): Promise<ExpireOutcome> {
  const booking = await tx.getBooking();
  if (!isExpiredRequest(booking, now)) return { result: 'skipped', reason: 'not_expired' };
  const plan = planLockCheck(booking);
  let own: string[] = [];
  if (!('skip' in plan)) {
    const locks = await tx.getLocks(plan.shopId, plan.barberId, plan.lockIds);
    own = judgeLocks(bookingId, plan.lockIds, locks).own;
  }
  tx.updateBooking(notAcceptedCancellation());
  if (own.length > 0 && !('skip' in plan)) tx.deleteLocks(plan.shopId, plan.barberId, own);
  return { result: 'expired', released: own };
}
