/**
 * Firestore/FCM side of notifications: resolves recipients, writes the in-app
 * inbox, sends push and SMS, and keeps everything idempotent across retries.
 *
 * Idempotency is keyed by (entity, event): booking events use the booking id,
 * events that belong to one payment attempt (paymentFailed, subscription*)
 * use the payment id.
 *
 * Paths touched (all via the Admin SDK):
 *   read   bookings/{bookingId}
 *   read   payments/{paymentId}                         (via trigger data)
 *   read   barbershops/{shopId}                         (ownerId, name, phone)
 *   read   plans/{planId}                               (name)
 *   read   users/{uid}                                  (language, phone, role)
 *   query  users where barberId == <barberId>           (barber accounts)
 *   query  users where role == 'barbershopOwner' and shopId == <shopId>
 *                                                       (owner fallback)
 *   read   users/{uid}/devices/*                        (FCM tokens)
 *   delete users/{uid}/devices/{deviceId}               (tokens FCM rejects)
 *   create users/{uid}/notifications/{entityId}_{type}  (inbox; id = idempotency key)
 *   create/update notificationLog/{entityId}_{type}_sms (SMS idempotency)
 */

import { getFirestore, type Firestore, type DocumentData } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions/v2';

import {
  RECIPIENT_ROLES,
  deriveCancelActor,
  isCancelActorLiteral,
  smsRecipientRole,
  type BookingDoc,
  type CancelActor,
  type NotificationType,
  type PaymentDoc,
  type PaymentEvent,
  type RecipientRole,
} from './events';
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
import { bookingStart, parseIso } from './time';

export const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

export const ETHIOPIAN_PHONE = /^\+251[79]\d{8}$/;

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

/** Links stored on the inbox / log documents and sent as push data. */
export interface EntityRefs {
  bookingId?: string;
  paymentId?: string;
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

export async function resolvePeople(
  db: Firestore,
  booking: BookingDoc,
  options: { barbers?: boolean } = {},
): Promise<BookingPeople> {
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
  if (booking.barberId && options.barbers !== false) {
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

/**
 * Recipients for the given roles (default: customer, barber(s) and owner),
 * de-duplicated (an owner may also cut hair) and without `exclude`.
 */
export function recipientsFor(
  people: BookingPeople,
  exclude: string | null,
  roles: readonly RecipientRole[] = ['customer', 'barber', 'owner'],
): Recipient[] {
  const out: Recipient[] = [];
  const seen = new Set<string>();
  const add = (uid: string | null, audience: Audience) => {
    if (!uid || seen.has(uid) || uid === exclude) return;
    seen.add(uid);
    out.push({ uid, audience });
  };
  if (roles.includes('customer')) add(people.customerUid, 'customer');
  if (roles.includes('barber')) for (const uid of people.barberUids) add(uid, 'barber');
  if (roles.includes('owner')) add(people.ownerUid, 'owner');
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

/** Inbox / push idempotency key for one event of one entity. */
export function notificationId(entityId: string, type: NotificationType): string {
  return `${entityId}_${type}`;
}

/**
 * Writes the inbox entry and, only if this call created it, sends the push.
 * The inbox doc id `${entityId}_${type}` makes retries no-ops. `refs`
 * defaults to `{bookingId: entityId}` (booking events).
 */
export async function deliverInApp(
  db: Firestore,
  recipient: Recipient,
  type: NotificationType,
  entityId: string,
  ctx: TemplateContext,
  language: Language,
  refs: EntityRefs = { bookingId: entityId },
): Promise<boolean> {
  const msg = renderNotification(type, recipient.audience, language, ctx);
  const id = notificationId(entityId, type);
  const ref = db.collection('users').doc(recipient.uid).collection('notifications').doc(id);
  const links: Record<string, string> = {};
  if (refs.bookingId) links.bookingId = refs.bookingId;
  if (refs.paymentId) links.paymentId = refs.paymentId;
  try {
    await ref.create({
      title: msg.title,
      body: msg.body,
      type,
      ...links,
      read: false,
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    if (isAlreadyExists(err)) return false;
    throw err;
  }
  try {
    await sendPush(db, recipient.uid, msg, { type, notificationId: id, ...links });
  } catch (err) {
    logger.warn('push failed', { uid: recipient.uid, entityId, type, err: String(err) });
  }
  return true;
}

/**
 * Sends one SMS per (entity, type), at most once. The log doc is claimed
 * with create() before sending; a failed send is recorded and not retried, to
 * avoid paying for duplicates. `refs` defaults to `{bookingId: entityId}`.
 */
export async function sendSmsOnce(
  db: Firestore,
  provider: SmsProvider,
  entityId: string,
  type: NotificationType,
  to: string,
  text: string,
  refs: EntityRefs = { bookingId: entityId },
): Promise<'sent' | 'duplicate' | 'failed' | 'skipped'> {
  const ref = db.collection('notificationLog').doc(`${notificationId(entityId, type)}_sms`);
  try {
    await ref.create({
      entityId,
      ...refs,
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
    logger.error('SMS send failed', { entityId, type, to: maskPhone(to), error: result.error });
  }
  return status;
}

/** Inbox + push for every recipient; failures are logged per recipient. */
async function fanOutInApp(
  db: Firestore,
  recipients: Recipient[],
  users: Map<string, UserInfo | null>,
  type: NotificationType,
  entityId: string,
  ctx: TemplateContext,
  refs: EntityRefs,
): Promise<void> {
  await Promise.all(
    recipients.map(async (r) => {
      // App default is English for push/inbox; SMS defaults to Amharic.
      const lang = normalizeLanguage(users.get(r.uid)?.language, 'en');
      try {
        await deliverInApp(db, r, type, entityId, ctx, lang, refs);
      } catch (err) {
        logger.error('in-app delivery failed', { uid: r.uid, entityId, type, err: String(err) });
      }
    }),
  );
}

async function loadUsers(db: Firestore, uids: string[]): Promise<Map<string, UserInfo | null>> {
  const users = new Map<string, UserInfo | null>();
  await Promise.all(uids.map(async (uid) => users.set(uid, await getUser(db, uid))));
  return users;
}

export interface NotifyOptions {
  /** Reminders: customer only. */
  onlyCustomer?: boolean;
  /**
   * Idempotency entity (inbox `{entityId}_{type}`, SMS log
   * `{entityId}_{type}_sms`); defaults to the booking id. Reschedules use
   * `{bookingId}_r{rescheduleCount}` so every move is notified once.
   */
  entityId?: string;
  /** Reschedules: the old start, shown next to the new one. */
  previousStart?: Date | null;
  /** Injected in tests; defaults to getFirestore(). */
  db?: Firestore;
}

/**
 * Full fan-out for one booking event: inbox + push for the recipients of the
 * type (RECIPIENT_ROLES), SMS for the customer when the type warrants it.
 */
export async function notifyBooking(
  bookingId: string,
  booking: BookingDoc,
  type: NotificationType,
  sms: SmsProvider,
  options: NotifyOptions = {},
): Promise<void> {
  const db = options.db ?? getFirestore();
  let roles = RECIPIENT_ROLES[type];
  if (options.onlyCustomer) roles = roles.filter((r) => r === 'customer');
  const people = await resolvePeople(db, booking, { barbers: roles.includes('barber') });

  let cancelActor: CancelActor | undefined;
  let actorUid: string | null = null;
  if (type === 'cancelled' || type === 'slotTaken') {
    const by = typeof booking.cancelledBy === 'string' ? booking.cancelledBy : '';
    let byIsAdmin = false;
    if (
      by &&
      !isCancelActorLiteral(by) &&
      by !== booking.customerId &&
      !people.barberUids.includes(by) &&
      by !== people.ownerUid
    ) {
      byIsAdmin = (await getUser(db, by))?.role === 'admin';
    }
    cancelActor = deriveCancelActor(booking, {
      barberUids: people.barberUids,
      ownerUid: people.ownerUid,
      isAdmin: () => byIsAdmin,
    });
    // Don't notify the person who cancelled (when it is a uid we know).
    actorUid = by && cancelActor !== 'unknown' && !isCancelActorLiteral(by) ? by : null;
  }

  const ctx: TemplateContext = { ...buildContext(booking, people, cancelActor), previousStart: options.previousStart ?? null };
  const recipients = recipientsFor(people, actorUid, roles);
  const users = await loadUsers(db, recipients.map((r) => r.uid));
  const refs: EntityRefs = { bookingId };
  const entityId = options.entityId ?? bookingId;
  await fanOutInApp(db, recipients, users, type, entityId, ctx, refs);

  const customerUid = people.customerUid;
  if (
    isSmsType(type) &&
    smsRecipientRole(type) === 'customer' &&
    roles.includes('customer') &&
    customerUid &&
    customerUid !== actorUid
  ) {
    const customer = users.has(customerUid) ? users.get(customerUid) : await getUser(db, customerUid);
    const phone = customer?.phone || booking.customerPhone || '';
    if (!ETHIOPIAN_PHONE.test(phone)) {
      logger.info('no valid Ethiopian phone for SMS', { bookingId, type });
      return;
    }
    const lang = normalizeLanguage(customer?.language, 'am');
    await sendSmsOnce(db, sms, entityId, type, phone, renderSms(type, lang, ctx), refs);
  }
}

/**
 * Shop owner uid and shop info: barbershops/{shopId}.ownerId first, then a
 * users query (role == barbershopOwner, shopId == shopId), then `fallbackUid`.
 */
export async function resolveShopOwner(
  db: Firestore,
  shopId: string | undefined,
  fallbackUid?: string | null,
): Promise<{ ownerUid: string | null; shopName: string | null; shopPhone: string | null; subscriptionEndsAt: string | null }> {
  let ownerUid: string | null = null;
  let shopName: string | null = null;
  let shopPhone: string | null = null;
  let subscriptionEndsAt: string | null = null;
  if (shopId) {
    const snap = await db.collection('barbershops').doc(shopId).get();
    if (snap.exists) {
      const d = snap.data() as DocumentData;
      if (typeof d.ownerId === 'string' && d.ownerId) ownerUid = d.ownerId;
      if (typeof d.name === 'string') shopName = d.name;
      if (typeof d.phone === 'string') shopPhone = d.phone;
      if (typeof d.subscriptionEndsAt === 'string') subscriptionEndsAt = d.subscriptionEndsAt;
    }
    if (!ownerUid) {
      // Two equality filters: served by merging single-field indexes.
      const qs = await db
        .collection('users')
        .where('role', '==', 'barbershopOwner')
        .where('shopId', '==', shopId)
        .limit(1)
        .get();
      if (!qs.empty) ownerUid = qs.docs[0].id;
    }
  }
  return { ownerUid: ownerUid ?? fallbackUid ?? null, shopName, shopPhone, subscriptionEndsAt };
}

/** "pro" -> plans/pro.name, falling back to "Pro". */
async function planDisplayName(db: Firestore, planId: string | undefined): Promise<string> {
  if (!planId) return '';
  try {
    const snap = await db.collection('plans').doc(planId).get();
    const name = snap.exists ? snap.get('name') : null;
    if (typeof name === 'string' && name.trim()) return name.trim();
  } catch (err) {
    logger.warn('plan lookup failed', { planId, err: String(err) });
  }
  return planId.charAt(0).toUpperCase() + planId.slice(1);
}

/**
 * Notifications for events on payments/{paymentId}. Idempotency is keyed by
 * the payment id, so every failed attempt is reported once.
 * - paymentFailed: the booking's customer (push + inbox, no SMS)
 * - subscriptionPaid / subscriptionFailed: the shop owner (SMS for paid only)
 */
export async function notifyPayment(
  paymentId: string,
  payment: PaymentDoc,
  type: PaymentEvent,
  sms: SmsProvider,
  options: { db?: Firestore } = {},
): Promise<void> {
  const db = options.db ?? getFirestore();
  const amount = typeof payment.amount === 'number' ? payment.amount : null;

  if (type === 'paymentFailed') {
    const bookingId = typeof payment.bookingId === 'string' && payment.bookingId ? payment.bookingId : undefined;
    let booking: BookingDoc = { shopId: payment.shopId };
    if (bookingId) {
      const snap = await db.collection('bookings').doc(bookingId).get();
      if (snap.exists) booking = snap.data() as BookingDoc;
    }
    // A failure on a booking that has since been paid another way is noise.
    if (booking.paymentStatus === 'paid' || booking.status === 'cancelled') {
      logger.info('payment failure not notified', { paymentId, bookingId, paymentStatus: booking.paymentStatus });
      return;
    }
    if (!booking.customerId && payment.userId) booking = { ...booking, customerId: payment.userId };
    const people = await resolvePeople(db, booking, { barbers: false });
    const ctx: TemplateContext = { ...buildContext(booking, people), amount };
    const recipients = recipientsFor(people, null, RECIPIENT_ROLES[type]);
    const users = await loadUsers(db, recipients.map((r) => r.uid));
    await fanOutInApp(db, recipients, users, type, paymentId, ctx, { bookingId, paymentId });
    return;
  }

  // Subscription events go to the shop owner.
  const shop = await resolveShopOwner(db, payment.shopId, payment.userId);
  if (!shop.ownerUid) {
    logger.warn('no owner found for subscription payment', { paymentId, shopId: payment.shopId });
    return;
  }
  const ctx: TemplateContext = {
    shopName: shop.shopName ?? '',
    barberName: '',
    customerName: '',
    serviceName: '',
    price: null,
    start: null,
    amount,
    planName: await planDisplayName(db, payment.plan),
    periodEnd:
      type === 'subscriptionPaid' ? parseIso(payment.periodEndsAt) ?? parseIso(shop.subscriptionEndsAt) : null,
  };
  const recipients: Recipient[] = [{ uid: shop.ownerUid, audience: 'owner' }];
  const users = await loadUsers(db, [shop.ownerUid]);
  const refs: EntityRefs = { paymentId };
  await fanOutInApp(db, recipients, users, type, paymentId, ctx, refs);

  if (isSmsType(type) && smsRecipientRole(type) === 'owner') {
    const owner = users.get(shop.ownerUid);
    const phone = owner?.phone || shop.shopPhone || '';
    if (!ETHIOPIAN_PHONE.test(phone)) {
      logger.info('no valid Ethiopian phone for SMS', { paymentId, type });
      return;
    }
    const lang = normalizeLanguage(owner?.language, 'am');
    await sendSmsOnce(db, sms, paymentId, type, phone, renderSms(type, lang, ctx), refs);
  }
}
