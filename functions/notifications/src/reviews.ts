/**
 * New-review notices (Blaze path): when a customer creates a review
 * (barbershops/{shopId}/reviews/{reviewId}), the shop's owner and the
 * reviewed barber's account(s) get an inbox entry and one FCM push.
 *
 * Mirrors lib/services/review_notices.dart (id, copy). The app works
 * without this function: on the free plan the customer's app writes the
 * owner's inbox entry in the review transaction itself (the customer cannot
 * see staff accounts, so the barber's entry and all pushes need this
 * function). Idempotent:
 *   - inbox doc id `review_{reviewId}_{digits of the review's createdAt}`
 *     (same as the app), created if missing, otherwise its title/body are
 *     refreshed in the recipient's language (read state kept);
 *   - push claimed once per inbox doc through notificationLog/{uid}_{id}_push
 *     (create() is atomic), then `pushedAt` is merged into the inbox doc.
 * Edits and deletes of a review notify nobody (the barber counters are
 * kept by the customer's app; functions/insights recomputes the cached
 * shop rating from them).
 *
 * Paths (Admin SDK):
 *   read   barbershops/{shopId}                           (ownerId)
 *   query  users where role == 'barber' and barberId == <barberId>
 *          (two equality filters: merged single-field indexes)
 *   read   users/{uid}                                    (language)
 *   read/create/update users/{uid}/notifications/review_{reviewId}_{digits}
 *   create notificationLog/{uid}_review_{reviewId}_{digits}_push
 *   read   users/{uid}/devices/*                          (via sendPush)
 */

import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import type { PushSender } from './earlyFinish';
import { normalizeLanguage, type Language } from './templates';
import { parseIso } from './time';

/** Reviews older than this when the trigger runs (seeding, retries) are not pushed. */
export const REVIEW_NOTICE_MAX_DELAY_MS = 30 * 60 * 1000;

export interface ReviewDoc {
  bookingId?: unknown;
  shopId?: unknown;
  barberId?: unknown;
  customerId?: unknown;
  customerName?: unknown;
  rating?: unknown;
  createdAt?: unknown;
}

/** `review_{reviewId}_{digits of createdAt}`, as reviewNotificationId in Dart. */
export function reviewNotificationId(reviewId: string, createdAtIso: string): string {
  return `review_${reviewId}_${createdAtIso.replace(/[^0-9]/g, '')}`;
}

/** "Liya Getachew" -> "Liya"; '' for an empty name (customerFirstName in Dart). */
export function firstName(name: string): string {
  const parts = name.trim().split(/\s+/).filter((p) => p.length > 0);
  return parts.length === 0 ? '' : parts[0];
}

/** The copy, as renderReviewNoticeText in Dart. */
export function renderReviewNotice(
  rating: number,
  customerName: string,
  barberName: string,
  language: Language,
): { title: string; body: string } {
  const first = firstName(customerName);
  const stars = '★'.repeat(Math.min(5, Math.max(1, Math.round(rating))));
  if (language === 'en') {
    const who = first === '' ? 'A customer' : first;
    return {
      title: `New review ${stars}`,
      body: barberName === '' ? `${who} rated their visit ${rating}/5.` : `${who} rated ${barberName} ${rating}/5.`,
    };
  }
  const who = first === '' ? 'አንድ ደንበኛ' : first;
  return {
    title: `አዲስ ግምገማ ${stars}`,
    body: barberName === '' ? `${who} ለጉብኝታቸው ${rating}/5 ሰጥተዋል።` : `${who} ለ${barberName} ${rating}/5 ሰጥተዋል።`,
  };
}

/** Owner first, then the barber accounts; each once, never the reviewer. */
export function reviewRecipients(ownerId: unknown, barberUids: string[], customerId: unknown): string[] {
  const out: string[] = [];
  for (const uid of [ownerId, ...barberUids]) {
    if (typeof uid !== 'string' || uid === '' || uid === customerId || out.includes(uid)) continue;
    out.push(uid);
  }
  return out;
}

export interface ReviewNoticeResult {
  recipients: number;
  pushed: number;
  skipped?: 'invalid' | 'stale';
}

function isAlreadyExists(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  return code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

const str = (v: unknown): string => (typeof v === 'string' ? v : '');

/**
 * Handles one new review. `push` is dispatch.ts's sendPush in production
 * (injected so tests need no FCM).
 */
export async function notifyNewReview(
  db: Firestore,
  shopId: string,
  reviewId: string,
  review: ReviewDoc | null,
  push: PushSender,
  now: Date = new Date(),
): Promise<ReviewNoticeResult> {
  const rating = review?.rating;
  const createdAtIso = str(review?.createdAt);
  const createdAt = parseIso(createdAtIso);
  if (!review || typeof rating !== 'number' || !Number.isInteger(rating) || rating < 1 || rating > 5 || !createdAt) {
    return { recipients: 0, pushed: 0, skipped: 'invalid' };
  }
  if (now.getTime() - createdAt.getTime() > REVIEW_NOTICE_MAX_DELAY_MS) {
    return { recipients: 0, pushed: 0, skipped: 'stale' };
  }
  const barberId = str(review.barberId);
  const shop = await db.collection('barbershops').doc(shopId).get();
  const barber = barberId ? await db.collection('barbershops').doc(shopId).collection('barbers').doc(barberId).get() : null;
  const barberName = str(barber?.exists ? (barber.data() as DocumentData).name : '');
  const staff = barberId
    ? await db.collection('users').where('role', '==', 'barber').where('barberId', '==', barberId).get()
    : { docs: [] as { id: string; data(): DocumentData | undefined }[] };
  const barberUids = staff.docs.filter((d) => str(d.data()?.shopId) === shopId).map((d) => d.id);
  const recipients = reviewRecipients(shop.exists ? (shop.data() as DocumentData).ownerId : null, barberUids, review.customerId);

  const id = reviewNotificationId(reviewId, createdAtIso);
  let pushed = 0;
  for (const uid of recipients) {
    try {
      if (await deliver(db, uid, id, { shopId, reviewId, barberId, rating, createdAtIso, barberName, review }, push)) {
        pushed++;
      }
    } catch (err) {
      logger.error('review notice failed', { reviewId, uid, err: String(err) });
    }
  }
  return { recipients: recipients.length, pushed };
}

interface NoticeInput {
  shopId: string;
  reviewId: string;
  barberId: string;
  rating: number;
  createdAtIso: string;
  barberName: string;
  review: ReviewDoc;
}

/** Inbox doc (create or refresh) + one push. True when this call pushed. */
async function deliver(db: Firestore, uid: string, id: string, n: NoticeInput, push: PushSender): Promise<boolean> {
  const userSnap = await db.collection('users').doc(uid).get();
  const language = normalizeLanguage(userSnap.exists ? (userSnap.data() as DocumentData).language : undefined, 'am');
  const msg = renderReviewNotice(n.rating, str(n.review.customerName), n.barberName, language);
  const ref = db.collection('users').doc(uid).collection('notifications').doc(id);
  try {
    await ref.create({
      type: 'newReview',
      title: msg.title,
      body: msg.body,
      bookingId: n.reviewId,
      shopId: n.shopId,
      barberId: n.barberId,
      rating: n.rating,
      read: false,
      createdAt: n.createdAtIso,
    });
  } catch (err) {
    if (!isAlreadyExists(err)) throw err;
    // Written by the customer's app (in Amharic by default): refresh the
    // copy, keep `read`.
    await ref.update({ title: msg.title, body: msg.body });
  }

  const claim = db.collection('notificationLog').doc(`${uid}_${id}_push`);
  try {
    await claim.create({
      uid,
      notificationId: id,
      bookingId: n.reviewId,
      type: 'newReview',
      channel: 'push',
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    if (isAlreadyExists(err)) return false;
    throw err;
  }
  try {
    await push(db, uid, msg, { type: 'newReview', notificationId: id, bookingId: n.reviewId, shopId: n.shopId });
  } catch (err) {
    logger.warn('review push failed', { uid, id, err: String(err) });
  }
  await ref.update({ pushedAt: new Date().toISOString() });
  return true;
}
