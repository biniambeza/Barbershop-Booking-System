/**
 * Rescheduled bookings. A customer moves a booking in one client
 * transaction: the booking's startAt/endAt (plus date, timeSlot,
 * rescheduleCount, rescheduledAt) change, the old interval's locks that the
 * new one does not reuse are deleted and the new blocks' locks are created.
 * The rules check only some of the new locks (per-request limits), so the
 * update trigger runs the same full check as on create
 * (verifyBookingLocksInTx) against the booking's CURRENT interval: if any
 * new block has no lock or is held by someone else (another booking, or a
 * time-off lock, which has timeOffId and no bookingId) the booking is
 * cancelled with cancelReason 'slot_conflict'. The old interval is never
 * checked, and nothing is done for writes that leave the interval alone
 * (status changes, payment fields, reminder flags, the cancel itself).
 */
import { BookingData } from './verify';
import { toInstant } from './lockIds';

function instantMs(value: unknown): number | null {
  const d = toInstant(value);
  return d ? d.getTime() : null;
}

/** True when the appointment interval (startAt or endAt) changed. */
export function intervalChanged(before: BookingData | null | undefined, after: BookingData | null | undefined): boolean {
  if (!before || !after) return false;
  return instantMs(before.startAt) !== instantMs(after.startAt) || instantMs(before.endAt) !== instantMs(after.endAt);
}

/**
 * Whether an update of bookings/{id} needs the lock check: the interval
 * moved and the booking is still live (a cancelled booking holds no locks).
 */
export function shouldVerifyUpdate(before: BookingData | null | undefined, after: BookingData | null | undefined): boolean {
  if (!intervalChanged(before, after)) return false;
  return after!.status !== 'cancelled';
}
