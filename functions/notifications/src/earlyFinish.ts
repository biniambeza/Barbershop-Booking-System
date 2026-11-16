/**
 * Early finish (Blaze path): when a booking turns 'completed' before its
 * scheduled end (completedAt < endAt), the barber's later confirmed
 * customers of the same Addis day get an FCM push (and the inbox entry, if
 * the barber's app has not written it already).
 *
 * Mirrors lib/services/early_finish_service.dart (selection, ids, copy). The
 * app works without this function: the staff app writes the inbox docs
 * itself on the free plan. This function only adds push and the recipient's
 * language, and is idempotent:
 *   - inbox doc id `{bookingId}_early_{sourceBookingId}` (same as the app),
 *     created if missing, otherwise its title/body are refreshed in the
 *     recipient's language (read state kept);
 *   - push claimed once per inbox doc through notificationLog/{uid}_{id}_push
 *     (create() is atomic), then `pushedAt` is merged into the inbox doc.
 *
 * Paths (Admin SDK):
 *   query  bookings where barberId == <barberId> and status == 'confirmed'
 *          (two equality filters: merged single-field indexes, no composite)
 *   read   users/{uid}                                   (language)
 *   read/create/update users/{uid}/notifications/{bookingId}_early_{sourceId}
 *   create notificationLog/{uid}_{bookingId}_early_{sourceId}_push
 *   read   users/{uid}/devices/*                         (via sendPush)
 */

import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import type { BookingDoc } from './events';
import { ethiopianClock, normalizeLanguage, type Language } from './templates';
import { bookingStart, parseIso, toAddisParts } from './time';

export type EarlyFinishType = 'barberFreeEarly' | 'runningEarly';

export const EARLY_FINISH_MAX_RECIPIENTS = 5;
export const EARLY_FINISH_MAX_MINUTES = 240;

/** A completion older than this when the trigger runs is not announced. */
export const EARLY_FINISH_MAX_DELAY_MS = 30 * 60 * 1000;

const MINUTE = 60 * 1000;

export interface BookingRef {
  id: string;
  data: BookingDoc;
}

export interface EarlyNoticePlan {
  /** `{bookingId}_early_{sourceBookingId}`. */
  id: string;
  recipientUid: string;
  type: EarlyFinishType;
  bookingId: string;
  shopId: string;
  barberId: string;
  sourceBookingId: string;
  minutesEarly: number;
  /** UTC ISO (the completion time). */
  createdAt: string;
  /** The recipient's booking (for the copy). */
  booking: BookingDoc;
}

export function earlyFinishNotificationId(recipientBookingId: string, sourceBookingId: string): string {
  return `${recipientBookingId}_early_${sourceBookingId}`;
}

/** The write moved the booking into 'completed'. */
export function isCompletionTransition(before: BookingDoc | null, after: BookingDoc | null): boolean {
  return !!after && after.status === 'completed' && before?.status !== 'completed';
}

/** Scheduled end: endAt, else start + durationMinutes (default 30). */
export function bookingEnd(b: BookingDoc): Date | null {
  const end = parseIso(b.endAt);
  if (end) return end;
  const start = bookingStart(b);
  if (!start) return null;
  const minutes = typeof b.durationMinutes === 'number' ? b.durationMinutes : 30;
  return new Date(start.getTime() + minutes * MINUTE);
}

/** endAt - completedAt in minutes, rounded down to 5, clamped to 0..240. */
export function minutesEarly(endAt: Date, completedAt: Date): number {
  const diff = Math.floor((endAt.getTime() - completedAt.getTime()) / MINUTE);
  if (diff <= 0) return 0;
  return Math.min(diff - (diff % 5), EARLY_FINISH_MAX_MINUTES);
}

export function isSameAddisDay(a: Date, b: Date): boolean {
  const x = toAddisParts(a);
  const y = toAddisParts(b);
  return x.year === y.year && x.month === y.month && x.day === y.day;
}

/**
 * Same barber and shop, not the source, status confirmed, a customer,
 * starting after `now` on the same Addis day; soonest first (then id), at
 * most 5.
 */
export function selectEarlyFinishRecipients(
  sourceId: string,
  source: BookingDoc,
  candidates: BookingRef[],
  now: Date,
): BookingRef[] {
  return candidates
    .map((c) => ({ c, start: bookingStart(c.data) }))
    .filter(
      ({ c, start }) =>
        c.id !== sourceId &&
        c.data.barberId === source.barberId &&
        c.data.shopId === source.shopId &&
        c.data.status === 'confirmed' &&
        typeof c.data.customerId === 'string' &&
        c.data.customerId.length > 0 &&
        start !== null &&
        start.getTime() > now.getTime() &&
        isSameAddisDay(start, now),
    )
    .sort((a, b) => a.start!.getTime() - b.start!.getTime() || (a.c.id < b.c.id ? -1 : a.c.id > b.c.id ? 1 : 0))
    .slice(0, EARLY_FINISH_MAX_RECIPIENTS)
    .map(({ c }) => c);
}

/** The notices for `source` completed at `completedAt` (empty unless early). */
export function planEarlyFinish(
  sourceId: string,
  source: BookingDoc,
  candidates: BookingRef[],
  completedAt: Date,
): EarlyNoticePlan[] {
  const end = bookingEnd(source);
  if (!end || completedAt.getTime() >= end.getTime()) return [];
  const minutes = minutesEarly(end, completedAt);
  return selectEarlyFinishRecipients(sourceId, source, candidates, completedAt).map((r, i) => ({
    id: earlyFinishNotificationId(r.id, sourceId),
    recipientUid: r.data.customerId as string,
    type: i === 0 ? 'barberFreeEarly' : 'runningEarly',
    bookingId: r.id,
    shopId: r.data.shopId ?? '',
    barberId: r.data.barberId ?? '',
    sourceBookingId: sourceId,
    minutesEarly: minutes,
    createdAt: completedAt.toISOString(),
    booking: r.data,
  }));
}

const pad2 = (n: number): string => String(n).padStart(2, '0');

/** Same copy as early_finish_service.dart's renderEarlyFinishText. */
export function renderEarlyFinish(
  type: EarlyFinishType,
  booking: BookingDoc,
  minutes: number,
  lang: Language,
): { title: string; body: string } {
  const start = bookingStart(booking);
  const p = start ? toAddisParts(start) : null;
  const hhmm = p ? `${pad2(p.hour)}:${pad2(p.minute)}` : '';
  const free = type === 'barberFreeEarly';
  if (lang === 'en') {
    const barber = booking.barberName || 'Your barber';
    const shop = booking.shopName || 'Crown & Blade';
    return free
      ? {
          title: 'Your barber is free now',
          body: `${barber} at ${shop} is free now — you can come in early for your ${hhmm} appointment.`,
        }
      : {
          title: 'Running ahead of schedule',
          body: `${barber} is running about ${minutes} min ahead of schedule today; your ${hhmm} appointment may start earlier.`,
        };
  }
  const barber = booking.barberName || 'ፀጉር አስተካካይዎ';
  const shop = booking.shopName || 'Crown & Blade';
  const time = p ? `${hhmm} (${ethiopianClock(p.hour, p.minute)})` : '';
  return free
    ? {
        title: 'ፀጉር አስተካካይዎ አሁን ነፃ ናቸው',
        body: `${barber} (${shop}) አሁን ነፃ ናቸው — ለ${time} ቀጠሮዎ ቀድመው መምጣት ይችላሉ።`,
      }
    : {
        title: 'ከፕሮግራሙ ቀድመው እየሰሩ ነው',
        body: `${barber} ዛሬ ከፕሮግራማቸው ${minutes} ደቂቃ ያህል ቀድመው እየሰሩ ነው፤ የ${time} ቀጠሮዎ ቀደም ብሎ ሊጀምር ይችላል።`,
      };
}

/** Firestore "already exists" error from create(). */
function isAlreadyExists(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  return code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

export type PushSender = (
  db: Firestore,
  uid: string,
  message: { title: string; body: string },
  data: Record<string, string>,
) => Promise<{ sent: number; removed: number }>;

export interface EarlyFinishResult {
  planned: number;
  pushed: number;
  skipped?: 'not-completed' | 'not-early' | 'stale' | 'no-barber';
}

/**
 * Handles one booking write. `push` is dispatch.ts's sendPush in
 * production (injected so tests need no FCM).
 */
export async function notifyEarlyFinish(
  db: Firestore,
  sourceId: string,
  before: BookingDoc | null,
  after: BookingDoc | null,
  push: PushSender,
  now: Date = new Date(),
): Promise<EarlyFinishResult> {
  if (!after || !isCompletionTransition(before, after)) return { planned: 0, pushed: 0, skipped: 'not-completed' };
  if (!after.barberId) return { planned: 0, pushed: 0, skipped: 'no-barber' };
  const completedAt = parseIso(after.completedAt) ?? now;
  if (now.getTime() - completedAt.getTime() > EARLY_FINISH_MAX_DELAY_MS) {
    return { planned: 0, pushed: 0, skipped: 'stale' };
  }
  const end = bookingEnd(after);
  if (!end || completedAt.getTime() >= end.getTime()) return { planned: 0, pushed: 0, skipped: 'not-early' };

  // Two equality filters: served by merging single-field indexes.
  const qs = await db
    .collection('bookings')
    .where('barberId', '==', after.barberId)
    .where('status', '==', 'confirmed')
    .get();
  const candidates: BookingRef[] = qs.docs.map((d) => ({ id: d.id, data: d.data() as BookingDoc }));
  const plans = planEarlyFinish(sourceId, after, candidates, completedAt);

  let pushed = 0;
  for (const plan of plans) {
    try {
      if (await deliverEarlyNotice(db, plan, push)) pushed++;
    } catch (err) {
      logger.error('early finish notice failed', { sourceId, id: plan.id, err: String(err) });
    }
  }
  return { planned: plans.length, pushed };
}

/** Inbox doc (create or refresh) + one push. True when this call pushed. */
async function deliverEarlyNotice(db: Firestore, plan: EarlyNoticePlan, push: PushSender): Promise<boolean> {
  const userSnap = await db.collection('users').doc(plan.recipientUid).get();
  const language = normalizeLanguage(userSnap.exists ? (userSnap.data() as DocumentData).language : undefined, 'am');
  const msg = renderEarlyFinish(plan.type, plan.booking, plan.minutesEarly, language);
  const ref = db.collection('users').doc(plan.recipientUid).collection('notifications').doc(plan.id);
  const doc = {
    type: plan.type,
    title: msg.title,
    body: msg.body,
    bookingId: plan.bookingId,
    shopId: plan.shopId,
    barberId: plan.barberId,
    sourceBookingId: plan.sourceBookingId,
    minutesEarly: plan.minutesEarly,
    read: false,
    createdAt: plan.createdAt,
  };
  let created = false;
  try {
    await ref.create(doc);
    created = true;
  } catch (err) {
    if (!isAlreadyExists(err)) throw err;
  }
  if (!created) {
    // Written by the staff app (maybe in the wrong language): refresh the
    // copy, keep `read`.
    await ref.update({ title: msg.title, body: msg.body });
  }

  // Claim the push exactly once.
  const claim = db.collection('notificationLog').doc(`${plan.recipientUid}_${plan.id}_push`);
  try {
    await claim.create({
      uid: plan.recipientUid,
      notificationId: plan.id,
      bookingId: plan.bookingId,
      type: plan.type,
      channel: 'push',
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    if (isAlreadyExists(err)) return false;
    throw err;
  }
  try {
    await push(db, plan.recipientUid, msg, { type: plan.type, notificationId: plan.id, bookingId: plan.bookingId });
  } catch (err) {
    logger.warn('early finish push failed', { uid: plan.recipientUid, id: plan.id, err: String(err) });
  }
  await ref.update({ pushedAt: new Date().toISOString() });
  return true;
}
