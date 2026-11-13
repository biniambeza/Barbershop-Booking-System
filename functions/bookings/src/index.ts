/**
 * Crown & Blade bookings codebase: booking integrity.
 *
 *  - verifyBookingLocks (bookings/{bookingId} created): every 15-minute
 *    block of [startAt, endAt) must have a slot lock owned by this booking.
 *    The rules only check the first four blocks and the last one, so a
 *    modified client could skip middle locks. If a lock is missing or held
 *    by another booking, the booking is cancelled in a transaction
 *    (status 'cancelled', cancelledBy 'system', cancelReason 'slot_conflict')
 *    and only this booking's own locks are deleted.
 *  - verifyRescheduledBookingLocks (bookings/{bookingId} updated): the same
 *    check whenever a live booking's startAt/endAt change (a customer
 *    reschedule), against the new interval only. Time-off locks (timeOffId,
 *    no bookingId) count as held by someone else.
 *  - cleanupExpiredSlotLocks (daily, 04:00 Addis): deletes slot locks whose
 *    expiresAt (booking end + 1 day) has passed. Needs the collection-group
 *    single-field index on slotLocks.expiresAt (firestore.indexes.json).
 */
import { initializeApp } from 'firebase-admin/app';
import { DocumentReference, getFirestore } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { sweepExpiredLocks } from './logic/cleanup';
import { shouldVerifyUpdate } from './logic/reschedule';
import { BookingData, LockData, verifyBookingLocksInTx } from './logic/verify';

const REGION = 'europe-west1';

initializeApp();
setGlobalOptions({ region: REGION, maxInstances: 10 });

const db = () => getFirestore();

const lockRef = (shopId: string, barberId: string, id: string): DocumentReference =>
  db().doc(`barbershops/${shopId}/barbers/${barberId}/slotLocks/${id}`);

/** Runs the full lock check for one booking in a transaction. */
async function checkBookingLocks(bookingId: string, trigger: 'create' | 'reschedule'): Promise<void> {
  const bookingRef = db().doc(`bookings/${bookingId}`);
  const outcome = await db().runTransaction((tx) =>
    verifyBookingLocksInTx(bookingId, {
      async getBooking() {
        const snap = await tx.get(bookingRef);
        return snap.exists ? (snap.data() as BookingData) : null;
      },
      async getLocks(shopId, barberId, ids) {
        if (ids.length === 0) return [];
        const snaps = await tx.getAll(...ids.map((id) => lockRef(shopId, barberId, id)));
        return snaps.map((s) => (s.exists ? (s.data() as LockData) : null));
      },
      updateBooking(fields) {
        tx.update(bookingRef, fields);
      },
      deleteLocks(shopId, barberId, ids) {
        for (const id of ids) tx.delete(lockRef(shopId, barberId, id));
      },
    }),
  );
  if (outcome.result === 'cancelled') {
    logger.warn('booking cancelled: slot locks missing or taken', { bookingId, trigger, ...outcome });
  } else if (outcome.result === 'skipped' && outcome.reason !== 'cancelled') {
    logger.info('booking lock check skipped', { bookingId, trigger, reason: outcome.reason });
  }
}

export const verifyBookingLocks = onDocumentCreated(
  // Safe to retry: a booking that is already cancelled is skipped.
  { document: 'bookings/{bookingId}', retry: true },
  async (event) => {
    await checkBookingLocks(event.params.bookingId, 'create');
  },
);

export const verifyRescheduledBookingLocks = onDocumentUpdated(
  // Safe to retry: the check reads the booking's current interval in a
  // transaction, and a cancelled booking is skipped.
  { document: 'bookings/{bookingId}', retry: true },
  async (event) => {
    const before = event.data?.before.exists ? (event.data.before.data() as BookingData) : null;
    const after = event.data?.after.exists ? (event.data.after.data() as BookingData) : null;
    if (!shouldVerifyUpdate(before, after)) return;
    await checkBookingLocks(event.params.bookingId, 'reschedule');
  },
);

export const cleanupExpiredSlotLocks = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'Africa/Addis_Ababa', retryCount: 2, timeoutSeconds: 540 },
  async () => {
    const result = await sweepExpiredLocks<DocumentReference>(new Date(), {
      async fetchExpired(nowIso, limit) {
        const snap = await db()
          .collectionGroup('slotLocks')
          .where('expiresAt', '<', nowIso)
          .orderBy('expiresAt')
          .limit(limit)
          .select()
          .get();
        return snap.docs.map((d) => d.ref);
      },
      async deleteAll(refs) {
        const batch = db().batch();
        for (const ref of refs) batch.delete(ref);
        await batch.commit();
      },
    });
    logger.info('expired slot locks deleted', result);
  },
);
