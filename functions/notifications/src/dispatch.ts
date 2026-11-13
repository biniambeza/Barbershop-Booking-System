/**
 * Firestore/FCM side of notifications: resolves recipients, writes the in-app
 * inbox, sends push and SMS, and keeps everything idempotent across retries.
 *
 * Paths touched (all via the Admin SDK):
 *   read   bookings/{bookingId}
 *   read   barbershops/{shopId}                         (ownerId, name)
 *   read   users/{uid}                                  (language, phone, role)
 *   query  users where barberId == <barberId>           (barber accounts)
 *   read   users/{uid}/devices/*                        (FCM tokens)
 *   delete users/{uid}/devices/{deviceId}               (tokens FCM rejects)
 *   create users/{uid}/notifications/{bookingId}_{type} (inbox; id = idempotency key)
 *   create/update notificationLog/{bookingId}_{type}_sms (SMS idempotency)
 */

import { getFirestore, type Firestore, type DocumentData } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions/v2';

import { deriveCancelActor, type BookingDoc, type CancelActor, type NotificationType } from './events';
import {
  isSmsType,
  normalizeLanguage,
  renderNotification,
  renderSms,
  type Audience,
  type Language,
  type TemplateContext,
} from './templates';
import { maskPhone, type SmsProvider } from './sms';
import { bookingStart } from './time';

export const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

const ETHIOPIAN_PHONE = /^\+251[79]\d{8}$/;

interface UserInfo {
  uid: string;
  role?: string;
  phone?: string;
  language?: unknown;
}

export interface Recipient {
  uid: string;
  audience: Audience;
}

export interface BookingPeople {
  customerUid: string | null;
  ownerUid: string | null;
  barberUids: string[];
  shopName: string | null;
}

/** Firestore "already exists" error from create(). */
function isAlreadyExists(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  return code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

async function getUser(db: Firestore, uid: string): Promise<UserInfo | null> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) return null;
  const d = snap.data() as DocumentData;
  return { uid, role: d.role, phone: d.phone, language: d.language };
}

export async function resolvePeople(db: Firestore, booking: BookingDoc): Promise<BookingPeople> {
  const people: BookingPeople = {
    customerUid: booking.customerId || null,
    ownerUid: null,
    barberUids: [],
    shopName: null,
  };
  const tasks: Promise<void>[] = [];
  if (booking.shopId) {
    tasks.push(
      db.collection('barbershops').doc(booking.shopId).get().then((snap) => {
        if (!snap.exists) return;
        const d = snap.data() as DocumentData;
        people.ownerUid = typeof d.ownerId === 'string' && d.ownerId ? d.ownerId : null;
        people.shopName = typeof d.name === 'string' ? d.name : null;
      }),
    );
  }
  if (booking.barberId) {
    // Equality on one field: served by the automatic single-field index.
    tasks.push(
      db.collection('users').where('barberId', '==', booking.barberId).limit(10).get().then((qs) => {
        people.barberUids = qs.docs
          .filter((doc) => {
            const d = doc.data();
            return d.role === 'barber' && (!booking.shopId || d.shopId === booking.shopId);
          })
          .map((doc) => doc.id);
      }),
    );
  }
  await Promise.all(tasks);
  return people;
}

/** Customer, barber(s) and owner, de-duplicated (an owner may also cut hair). */
export function recipientsFor(people: BookingPeople, exclude: string | null): Recipient[] {
  const out: Recipient[] = [];
  const seen = new Set<string>();
  const add = (uid: string | null, audience: Audience) => {
    if (!uid || seen.has(uid) || uid === exclude) return;
    seen.add(uid);
    out.push({ uid, audience });
  };
  add(people.customerUid, 'customer');
  for (const uid of people.barberUids) add(uid, 'barber');
  add(people.ownerUid, 'owner');
  return out;
}

export function buildContext(booking: BookingDoc, people: BookingPeople, cancelledBy?: CancelActor): TemplateContext {
  return {
    shopName: booking.shopName || people.shopName || '',
    barberName: booking.barberName || '',
    customerName: booking.customerName || '',
    serviceName: booking.serviceName || '',
    price: typeof booking.price === 'number' ? booking.price : null,
    start: bookingStart(booking),
    cancelledBy,
  };
}

/** Sends to every registered device of a user; prunes tokens FCM rejects. */
export async function sendPush(
  db: Firestore,
  uid: string,
  message: { title: string; body: string },
  data: Record<string, string>,
): Promise<{ sent: number; removed: number }> {
  const devices = await db.collection('users').doc(uid).collection('devices').get();
  const entries = devices.docs
    .map((doc) => ({ ref: doc.ref, token: doc.get('token') as unknown }))
    .filter((e): e is { ref: typeof e.ref; token: string } => typeof e.token === 'string' && e.token.length > 0);
  if (entries.length === 0) return { sent: 0, removed: 0 };

  let sent = 0;
  let removed = 0;
  // sendEachForMulticast accepts at most 500 tokens per call.
  for (let i = 0; i < entries.length; i += 500) {
    const chunk = entries.slice(i, i + 500);
    const res = await getMessaging().sendEachForMulticast({
      tokens: chunk.map((e) => e.token),
      notification: message,
      data,
      android: { priority: 'high', notification: { channelId: 'bookings' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    sent += res.successCount;
    const stale = res.responses
      .map((r, idx) => ({ r, entry: chunk[idx] }))
      .filter(({ r }) => !r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code));
    await Promise.all(stale.map(({ entry }) => entry.ref.delete()));
    removed += stale.length;
  }
  return { sent, removed };
}

/**
 * Writes the inbox entry and, only if this call created it, sends the push.
 * The inbox doc id `${bookingId}_${type}` makes retries no-ops.
 */
export async function deliverInApp(
  db: Firestore,
  recipient: Recipient,
  type: NotificationType,
  bookingId: string,
  ctx: TemplateContext,
  language: Language,
): Promise<boolean> {
  const msg = renderNotification(type, recipient.audience, language, ctx);
  const ref = db.collection('users').doc(recipient.uid).collection('notifications').doc(`${bookingId}_${type}`);
  try {
    await ref.create({
      title: msg.title,
      body: msg.body,
      type,
      bookingId,
      read: false,
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    if (isAlreadyExists(err)) return false;
    throw err;
  }
  try {
    await sendPush(db, recipient.uid, msg, { type, bookingId });
  } catch (err) {
    logger.warn('push failed', { uid: recipient.uid, bookingId, type, err: String(err) });
  }
  return true;
}

/**
 * Sends one SMS per (booking, type), at most once. The log doc is claimed
 * with create() before sending; a failed send is recorded and not retried, to
 * avoid paying for duplicates.
 */
export async function sendSmsOnce(
  db: Firestore,
  provider: SmsProvider,
  bookingId: string,
  type: NotificationType,
  to: string,
  text: string,
): Promise<'sent' | 'duplicate' | 'failed' | 'skipped'> {
  const ref = db.collection('notificationLog').doc(`${bookingId}_${type}_sms`);
  try {
    await ref.create({
      bookingId,
      type,
      channel: 'sms',
      to,
      provider: provider.name,
      status: 'sending',
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    if (isAlreadyExists(err)) return 'duplicate';
    throw err;
  }
  const result = await provider.send(to, text);
  const status = result.skipped ? 'skipped' : result.ok ? 'sent' : 'failed';
  await ref.update({
    status,
    providerId: result.providerId ?? null,
    error: result.error ?? null,
    finishedAt: new Date().toISOString(),
  });
  if (status === 'failed') {
    logger.error('SMS send failed', { bookingId, type, to: maskPhone(to), error: result.error });
  }
  return status;
}

/**
 * Full fan-out for one event: inbox + push for every recipient, SMS for the
 * customer when the type warrants it. `onlyCustomer` is used by reminders.
 */
export async function notifyBooking(
  bookingId: string,
  booking: BookingDoc,
  type: NotificationType,
  sms: SmsProvider,
  options: { onlyCustomer?: boolean } = {},
): Promise<void> {
  const db = getFirestore();
  const people = await resolvePeople(db, booking);

  let cancelActor: CancelActor | undefined;
  let actorUid: string | null = null;
  if (type === 'cancelled') {
    const by = typeof booking.cancelledBy === 'string' ? booking.cancelledBy : '';
    let byIsAdmin = false;
    if (by && by !== booking.customerId && !people.barberUids.includes(by) && by !== people.ownerUid) {
      byIsAdmin = (await getUser(db, by))?.role === 'admin';
    }
    cancelActor = deriveCancelActor(booking, {
      barberUids: people.barberUids,
      ownerUid: people.ownerUid,
      isAdmin: () => byIsAdmin,
    });
    // Don't notify the person who cancelled (when it is a uid we know).
    actorUid = by && cancelActor !== 'unknown' ? by : null;
  }

  const ctx = buildContext(booking, people, cancelActor);
  let recipients = recipientsFor(people, actorUid);
  if (options.onlyCustomer) recipients = recipients.filter((r) => r.audience === 'customer');

  const users = new Map<string, UserInfo | null>();
  await Promise.all(recipients.map(async (r) => users.set(r.uid, await getUser(db, r.uid))));

  await Promise.all(
    recipients.map(async (r) => {
      // App default is English for push/inbox; SMS defaults to Amharic.
      const lang = normalizeLanguage(users.get(r.uid)?.language, 'en');
      try {
        await deliverInApp(db, r, type, bookingId, ctx, lang);
      } catch (err) {
        logger.error('in-app delivery failed', { uid: r.uid, bookingId, type, err: String(err) });
      }
    }),
  );

  const customerUid = people.customerUid;
  if (isSmsType(type) && customerUid && customerUid !== actorUid) {
    const customer = users.get(customerUid) ?? (await getUser(db, customerUid));
    const phone = customer?.phone || booking.customerPhone || '';
    if (!ETHIOPIAN_PHONE.test(phone)) {
      logger.info('no valid Ethiopian phone for SMS', { bookingId, type });
      return;
    }
    const lang = normalizeLanguage(customer?.language, 'am');
    await sendSmsOnce(db, sms, bookingId, type, phone, renderSms(type, lang, ctx));
  }
}
