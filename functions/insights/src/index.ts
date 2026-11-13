/**
 * Crown & Blade insights codebase: owner reports.
 *
 *  - aggregateBookingStats (bookings/{bookingId} written): keeps
 *    barbershops/{s}/stats/{yyyy-MM} (Addis month of startAt) and
 *    barbershops/{s}/clients/{customerId} in line with the booking. The
 *    contribution already counted is kept in insightsApplied/{bookingId}
 *    (functions only), which makes the trigger idempotent and correct for
 *    status changes, reschedules into another month, deletes and retries
 *    (see logic/stats.ts).
 *  - aggregateReviewRatings (barbershops/{s}/reviews/{id} written):
 *    recomputes rating (average, 1 decimal) and reviewCount on the shop and
 *    on the review's barber.
 *  - rebuildShopStats (callable, admin only, { shopId }): rebuilds a shop's
 *    stats, clients and markers from all of its bookings. Run it once after
 *    seeding or deploying, ideally while the shop is quiet.
 */
import { initializeApp } from 'firebase-admin/app';
import { DocumentReference, getFirestore, WriteBatch } from 'firebase-admin/firestore';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { rebuildShop } from './logic/backfill';
import { summarizeShopReviews, ReviewData } from './logic/ratings';
import { aggregateBookingInTx, BookingData, Marker } from './logic/stats';
import { isMonthKey } from './logic/time';

const REGION = 'europe-west1';
/** Firestore allows 500 writes per batch; stay below it. */
const BATCH_SIZE = 400;

initializeApp();
setGlobalOptions({ region: REGION, maxInstances: 10 });

const db = () => getFirestore();
const shopRef = (shopId: string) => db().doc(`barbershops/${shopId}`);
const statsRef = (shopId: string, month: string) => db().doc(`barbershops/${shopId}/stats/${month}`);
const clientRef = (shopId: string, customerId: string) => db().doc(`barbershops/${shopId}/clients/${customerId}`);
const markerRef = (bookingId: string) => db().doc(`insightsApplied/${bookingId}`);

export const aggregateBookingStats = onDocumentWritten(
  // Safe to retry: the marker makes a repeated run a no-op.
  { document: 'bookings/{bookingId}', retry: true },
  async (event) => {
    const bookingId = event.params.bookingId;
    const bookingRef = db().doc(`bookings/${bookingId}`);
    const outcome = await db().runTransaction(async (tx) => {
      const nowIso = new Date().toISOString();
      return aggregateBookingInTx(
        {
          async getBooking() {
            const snap = await tx.get(bookingRef);
            return snap.exists ? (snap.data() as BookingData) : null;
          },
          async getMarker() {
            const snap = await tx.get(markerRef(bookingId));
            return snap.exists ? (snap.data() as Marker) : null;
          },
          async getStats(shopId, month) {
            const snap = await tx.get(statsRef(shopId, month));
            return snap.exists ? (snap.data() as Record<string, unknown>) : null;
          },
          async getClient(shopId, customerId) {
            const snap = await tx.get(clientRef(shopId, customerId));
            return snap.exists ? (snap.data() as Record<string, unknown>) : null;
          },
          async latestCompletedVisit(shopId, customerId) {
            // Composite index: bookings (shopId, customerId, status, startAt desc).
            const snap = await tx.get(
              db()
                .collection('bookings')
                .where('shopId', '==', shopId)
                .where('customerId', '==', customerId)
                .where('status', '==', 'completed')
                .orderBy('startAt', 'desc')
                .limit(1),
            );
            const startAt = snap.docs[0]?.get('startAt');
            return typeof startAt === 'string' ? startAt : null;
          },
          setStats(shopId, month, doc) {
            tx.set(statsRef(shopId, month), doc);
          },
          setClient(shopId, customerId, doc) {
            tx.set(clientRef(shopId, customerId), doc);
          },
          setMarker(marker) {
            tx.set(markerRef(bookingId), marker);
          },
          deleteMarker() {
            tx.delete(markerRef(bookingId));
          },
        },
        nowIso,
      );
    });
    if (outcome.result === 'applied') logger.info('booking stats applied', { bookingId, ...outcome });
  },
);

/** Updates rating + reviewCount, ignoring a doc that no longer exists. */
async function updateRating(ref: DocumentReference, rating: number, reviewCount: number): Promise<void> {
  try {
    await ref.update({ rating, reviewCount });
  } catch (e) {
    if ((e as { code?: number }).code === 5) return; // NOT_FOUND: shop or barber removed.
    throw e;
  }
}

export const aggregateReviewRatings = onDocumentWritten(
  // Safe to retry: a full recompute.
  { document: 'barbershops/{shopId}/reviews/{reviewId}', retry: true },
  async (event) => {
    const shopId = event.params.shopId;
    const before = event.data?.before.data() as ReviewData | undefined;
    const after = event.data?.after.data() as ReviewData | undefined;
    const barberIds = new Set<string>();
    for (const r of [before, after]) if (typeof r?.barberId === 'string' && r.barberId) barberIds.add(r.barberId);

    const snap = await db().collection(`barbershops/${shopId}/reviews`).select('rating', 'barberId').get();
    const summary = summarizeShopReviews(
      snap.docs.map((d) => d.data() as ReviewData),
      barberIds,
    );
    await updateRating(shopRef(shopId), summary.shop.rating, summary.shop.reviewCount);
    for (const [barberId, s] of summary.barbers) {
      await updateRating(db().doc(`barbershops/${shopId}/barbers/${barberId}`), s.rating, s.reviewCount);
    }
    logger.info('review ratings updated', { shopId, ...summary.shop, barbers: [...barberIds] });
  },
);

async function commitInBatches(ops: ((batch: WriteBatch) => void)[]): Promise<void> {
  for (let i = 0; i < ops.length; i += BATCH_SIZE) {
    const batch = db().batch();
    for (const op of ops.slice(i, i + BATCH_SIZE)) op(batch);
    await batch.commit();
  }
}

export const rebuildShopStats = onCall({ timeoutSeconds: 540, memory: '512MiB' }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const user = await db().collection('users').doc(uid).get();
  if (user.get('role') !== 'admin') throw new HttpsError('permission-denied', 'Admins only.');
  const shopId = (req.data as { shopId?: unknown } | null)?.shopId;
  if (typeof shopId !== 'string' || !shopId || shopId.length > 128 || shopId.includes('/')) {
    throw new HttpsError('invalid-argument', 'shopId is required.');
  }
  if (!(await shopRef(shopId).get()).exists) throw new HttpsError('not-found', 'Shop not found.');

  const nowIso = new Date().toISOString();
  const bookings = await db().collection('bookings').where('shopId', '==', shopId).get();
  const result = rebuildShop(
    shopId,
    bookings.docs.map((d) => ({ id: d.id, data: d.data() as BookingData })),
    nowIso,
  );

  // Remove what the rebuild no longer produces, then write the fresh docs.
  const [oldStats, oldClients, oldMarkers] = await Promise.all([
    db().collection(`barbershops/${shopId}/stats`).select().get(),
    db().collection(`barbershops/${shopId}/clients`).select().get(),
    db().collection('insightsApplied').where('shopId', '==', shopId).select().get(),
  ]);
  const ops: ((b: WriteBatch) => void)[] = [];
  for (const d of oldStats.docs) if (isMonthKey(d.id) && !result.stats.has(d.id)) ops.push((b) => b.delete(d.ref));
  for (const d of oldClients.docs) if (!result.clients.has(d.id)) ops.push((b) => b.delete(d.ref));
  for (const d of oldMarkers.docs) if (!result.markers.has(d.id)) ops.push((b) => b.delete(d.ref));
  for (const [month, doc] of result.stats) ops.push((b) => b.set(statsRef(shopId, month), doc));
  for (const [customerId, doc] of result.clients) ops.push((b) => b.set(clientRef(shopId, customerId), doc));
  for (const [bookingId, marker] of result.markers) ops.push((b) => b.set(markerRef(bookingId), marker));
  await commitInBatches(ops);

  const summary = { shopId, bookings: result.markers.size, months: result.stats.size, clients: result.clients.size };
  logger.info('shop stats rebuilt', summary);
  return summary;
});
