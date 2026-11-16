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
 *  - expirePendingBookings (every 15 minutes): barber acceptance. Booking
 *    requests still 'pending' within 60 minutes of their start (or past it)
 *    are cancelled (cancelledBy 'system', cancelReason 'not_accepted') and
 *    their own slot locks deleted, one transaction per booking. Query:
 *    bookings where status == 'pending' and startAt <= now + 60 min
 *    (composite index status+startAt), re-checked in code and in the tx.
 *  - flagRefundOnCancel (bookings/{bookingId} updated): refunds. A booking
 *    that is cancelled and paid but has no refundStatus (the app normally
 *    flags it in the cancel write) gets refundStatus 'due', refundAmount,
 *    refundReason, refundFlaggedAt and the customer's
 *    users/{uid}/notifications/{bookingId}_refundDue, in one transaction;
 *    an existing refundStatus is never overwritten. The booking's refund
 *    fields are mirrored onto payments/{paymentId}.
 */
import { initializeApp } from 'firebase-admin/app';
import { DocumentReference, getFirestore } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { sweepExpiredLocks } from './logic/cleanup';
import { EXPIRE_MAX_PER_RUN, expireRequestInTx, expiryCutoff, selectExpiredRequests } from './logic/expire';
import { shouldVerifyUpdate } from './logic/reschedule';
import { flagRefundInTx, RefundBookingData, shouldHandleRefund } from './logic/refund'; // refunds
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

// --- barber acceptance: expire unanswered requests ---
export const expirePendingBookings = onSchedule(
  { schedule: 'every 15 minutes', timeZone: 'Africa/Addis_Ababa', retryCount: 1, timeoutSeconds: 300 },
  async () => {
    const now = new Date();
    // Composite index bookings (status ASC, startAt ASC) (firestore.indexes.json).
    const snap = await db()
      .collection('bookings')
      .where('status', '==', 'pending')
      .where('startAt', '<=', expiryCutoff(now).toISOString())
      .orderBy('startAt')
      .limit(EXPIRE_MAX_PER_RUN)
      .get();
    const ids = selectExpiredRequests(
      snap.docs.map((d) => ({ id: d.id, data: d.data() as BookingData })),
      now,
    );
    let expired = 0;
    let failed = 0;
    for (const bookingId of ids) {
      const bookingRef = db().doc(`bookings/${bookingId}`);
      try {
        const outcome = await db().runTransaction((tx) =>
          expireRequestInTx(bookingId, now, {
            async getBooking() {
              const s = await tx.get(bookingRef);
              return s.exists ? (s.data() as BookingData) : null;
            },
            async getLocks(shopId, barberId, lockIds) {
              if (lockIds.length === 0) return [];
              const snaps = await tx.getAll(...lockIds.map((id) => lockRef(shopId, barberId, id)));
              return snaps.map((s) => (s.exists ? (s.data() as LockData) : null));
            },
            updateBooking(fields) {
              tx.update(bookingRef, fields);
            },
            deleteLocks(shopId, barberId, lockIds) {
              for (const id of lockIds) tx.delete(lockRef(shopId, barberId, id));
            },
          }),
        );
        if (outcome.result === 'expired') expired++;
      } catch (e) {
        failed++;
        logger.error('expiring booking request failed', { bookingId, error: String(e) });
      }
    }
    logger.info('pending booking requests expired', { scanned: snap.size, expired, failed });
  },
);

// --- refunds: flag paid bookings that were cancelled (backstop for the app) ---
export const flagRefundOnCancel = onDocumentUpdated(
  // Safe to retry: the transaction re-reads the booking and never touches
  // one that already has a refundStatus; the notice is created only if
  // missing and the payment mirror only writes differences.
  { document: 'bookings/{bookingId}', retry: true },
  async (event) => {
    const before = event.data?.before.exists ? (event.data.before.data() as RefundBookingData) : null;
    const after = event.data?.after.exists ? (event.data.after.data() as RefundBookingData) : null;
    if (!shouldHandleRefund(before, after)) return;
    const bookingId = event.params.bookingId;
    const bookingRef = db().doc(`bookings/${bookingId}`);
    const now = new Date();
    const cancelTransition = before?.status !== 'cancelled' && after?.status === 'cancelled';
    const outcome = await db().runTransaction((tx) =>
      flagRefundInTx(bookingId, { now, cancelTransition }, {
        async getBooking() {
          const s = await tx.get(bookingRef);
          return s.exists ? (s.data() as RefundBookingData) : null;
        },
        async getCutoffHours(shopId) {
          const s = await tx.get(db().doc(`barbershops/${shopId}`));
          const v = s.exists ? s.get('cancellationCutoffHours') : null;
          return typeof v === 'number' ? v : null;
        },
        async getLanguage(uid) {
          const s = await tx.get(db().doc(`users/${uid}`));
          return s.exists ? s.get('language') : undefined;
        },
        async noticeExists(uid, noticeId) {
          return (await tx.get(db().doc(`users/${uid}/notifications/${noticeId}`))).exists;
        },
        async getPayment(paymentId) {
          const s = await tx.get(db().doc(`payments/${paymentId}`));
          return s.exists ? (s.data() as Record<string, unknown>) : null;
        },
        updateBooking(fields) {
          tx.update(bookingRef, fields);
        },
        createNotice(uid, noticeId, data) {
          tx.create(db().doc(`users/${uid}/notifications/${noticeId}`), data);
        },
        updatePayment(paymentId, fields) {
          tx.update(db().doc(`payments/${paymentId}`), fields);
        },
      }),
    );
    if (outcome.flagged || outcome.mirrored) {
      logger.info('booking refund handled', { bookingId, ...outcome });
    }
  },
);
