/**
 * Crown & Blade queue codebase (firebase.json codebase "queue"): the walk-in
 * queue of each shop.
 *
 *  - onQueueEntryWritten (barbershops/{shopId}/queue/{entryId} written):
 *    in one transaction reads the shop's active entries (status 'waiting' or
 *    'serving'), its services (durations) and barbers (isAvailable), marks a
 *    customer's duplicate remote entries 'left', and writes
 *    barbershops/{shopId}/queueSummary/current
 *      {waitingCount, estimatedWaitMinutes, positions, updatedAt}.
 *    estimatedWaitMinutes = ceil(sum of service minutes of the waiting
 *    entries / available barbers), 30 minutes per entry without a service
 *    (logic/estimate.ts; the app's lib/services/queue_wait.dart matches).
 *    Then, if the first waiting entry was added remotely by a customer, it
 *    writes their inbox entry users/{uid}/notifications/{id} (type
 *    'queueNext') and sends a push, once per entry.
 *
 * Needs the composite index queue (status ASC, createdAt ASC)
 * (firestore.indexes.json).
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

import { ACTIVE_STATUSES, type QueueEntry, type QueueEntryDoc } from './logic/estimate';
import { notifyQueueNext } from './logic/notify';
import { affectsSummary, recomputeQueue } from './logic/recompute';

const REGION = 'europe-west1';

initializeApp();
setGlobalOptions({ region: REGION, maxInstances: 10 });

const db = (): Firestore => getFirestore();

const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

function isAlreadyExists(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  return code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

async function sendPush(
  uid: string,
  message: { title: string; body: string },
  data: Record<string, string>,
): Promise<void> {
  const devices = await db().collection('users').doc(uid).collection('devices').get();
  const entries = devices.docs
    .map((doc) => ({ ref: doc.ref, token: doc.get('token') as unknown }))
    .filter((e): e is { ref: typeof e.ref; token: string } => typeof e.token === 'string' && e.token.length > 0);
  for (let i = 0; i < entries.length; i += 500) {
    const chunk = entries.slice(i, i + 500);
    const res = await getMessaging().sendEachForMulticast({
      tokens: chunk.map((e) => e.token),
      notification: message,
      data,
      android: { priority: 'high', notification: { channelId: 'bookings' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    await Promise.all(
      res.responses
        .map((r, idx) => ({ r, entry: chunk[idx] }))
        .filter(({ r }) => !r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code))
        .map(({ entry }) => entry.ref.delete()),
    );
  }
}

export const onQueueEntryWritten = onDocumentWritten(
  // Safe to retry: the summary is recomputed from scratch and the inbox
  // entry is created at most once.
  { document: 'barbershops/{shopId}/queue/{entryId}', retry: true },
  async (event) => {
    const shopId = event.params.shopId;
    const before = event.data?.before.exists ? (event.data.before.data() as QueueEntryDoc) : null;
    const after = event.data?.after.exists ? (event.data.after.data() as QueueEntryDoc) : null;
    if (!affectsSummary(before, after)) return;

    const shopRef = db().collection('barbershops').doc(shopId);
    const queueRef = shopRef.collection('queue');
    const summaryRef = shopRef.collection('queueSummary').doc('current');

    const result = await db().runTransaction(async (tx) => {
      const now = new Date();
      return recomputeQueue(now, {
        async listActive() {
          const snap = await tx.get(
            queueRef.where('status', 'in', [...ACTIVE_STATUSES]).orderBy('createdAt').limit(500),
          );
          return snap.docs.map((d) => ({ id: d.id, ...(d.data() as QueueEntryDoc) }) as QueueEntry);
        },
        async serviceDurations() {
          const snap = await tx.get(shopRef.collection('services'));
          const out: Record<string, number> = {};
          for (const d of snap.docs) {
            const minutes = d.get('durationMinutes');
            if (typeof minutes === 'number') out[d.id] = minutes;
          }
          return out;
        },
        async availableBarbers() {
          const snap = await tx.get(shopRef.collection('barbers'));
          return snap.docs.filter((d) => d.get('isAvailable') !== false).length;
        },
        markLeft(ids, nowIso) {
          for (const id of ids) tx.update(queueRef.doc(id), { status: 'left', finishedAt: nowIso });
        },
        writeSummary(summary) {
          tx.set(summaryRef, summary);
        },
      });
    });

    if (result.duplicates.length > 0) {
      logger.info('duplicate remote queue entries closed', { shopId, ids: result.duplicates });
    }
    const next = result.nextRemote;
    if (!next) return;

    const shopSnap = await shopRef.get();
    const shopName = shopSnap.exists ? ((shopSnap.data() as DocumentData).name as string | undefined) ?? null : null;
    try {
      const outcome = await notifyQueueNext(shopId, shopName, next, new Date(), {
        async userLanguage(uid) {
          const snap = await db().collection('users').doc(uid).get();
          return snap.exists ? snap.get('language') : undefined;
        },
        async createInbox(uid, id, doc) {
          try {
            await db().collection('users').doc(uid).collection('notifications').doc(id).create(doc);
            return true;
          } catch (err) {
            if (isAlreadyExists(err)) return false;
            throw err;
          }
        },
        async sendPush(uid, message, data) {
          try {
            await sendPush(uid, message, data);
          } catch (err) {
            logger.warn('queue push failed', { uid, shopId, err: String(err) });
          }
        },
      });
      if (outcome === 'sent') logger.info('queueNext sent', { shopId, entryId: next.id });
    } catch (err) {
      logger.error('queueNext delivery failed', { shopId, entryId: next.id, err: String(err) });
    }
  },
);
