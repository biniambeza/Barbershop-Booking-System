/**
 * Crown & Blade payments codebase: Chapa checkout for bookings and shop
 * subscriptions, the Chapa webhook, and the subscription lifecycle job.
 *
 * Secrets: CHAPA_SECRET_KEY, CHAPA_WEBHOOK_SECRET (firebase functions:secrets:set).
 * Params:  PAYMENT_RETURN_URL (where Chapa sends the customer after paying;
 *          the app reads ?paymentId=&txRef= and calls verifyPayment),
 *          CHAPA_CALLBACK_URL (optional; defaults to this codebase's chapaWebhook URL).
 */
import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions, logger } from 'firebase-functions/v2';
import { CallableRequest, HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret, defineString } from 'firebase-functions/params';
import { FieldPath } from 'firebase-admin/firestore';

import {
  CHECKOUT_TITLE,
  CURRENCY,
  DEFAULT_PLANS,
  PENDING_REUSE_MINUTES,
  REGION,
} from './config';
import { ChapaError, initializeTransaction } from './chapa';
import { createBookingCheckout } from './logic/bookingCheckout';
import { appendQuery, buildTxRef, firstNameOf, sanitizeCheckoutText, toChapaEmail, toChapaPhone } from './logic/checkout';
import { FlowError } from './logic/docstore';
import { checkPlanFitsShop, checkShopOwner, Denial } from './logic/eligibility';
import { normalizeAmount, toChapaAmount } from './logic/money';
import { buildManualChange, computeScheduledUpdate, isPlan } from './logic/subscription';
import { verifyChapaSignature } from './logic/signature';
import { parseReviewRequest, resolvePaymentReview as resolveReview } from './logic/review';
import { db, findPaymentByTxRef, firestoreDocStore, markRefunded, PaymentDoc, reverifyPayment } from './store';

initializeApp();
setGlobalOptions({ region: REGION, maxInstances: 10 });

const CHAPA_SECRET_KEY = defineSecret('CHAPA_SECRET_KEY');
const CHAPA_WEBHOOK_SECRET = defineSecret('CHAPA_WEBHOOK_SECRET');
const PAYMENT_RETURN_URL = defineString('PAYMENT_RETURN_URL', {
  description: 'Page Chapa redirects to after checkout, e.g. https://<host>/payment-return',
});
const CHAPA_CALLBACK_URL = defineString('CHAPA_CALLBACK_URL', {
  default: '',
  description: 'Optional override for the Chapa callback/webhook URL',
});

// ---------------------------------------------------------------- helpers

function requireAuth(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  return uid;
}

function deny(d: Denial | null): void {
  if (d) throw new HttpsError(d.code, d.message);
}

function requireString(data: unknown, field: string): string {
  const v = (data as Record<string, unknown> | null)?.[field];
  if (typeof v !== 'string' || v.length === 0 || v.length > 128 || v.includes('/')) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  return v;
}

async function getUser(uid: string): Promise<Record<string, any> | undefined> {
  const snap = await db().collection('users').doc(uid).get();
  return snap.exists ? snap.data() : undefined;
}

async function requireAdmin(uid: string): Promise<void> {
  const user = await getUser(uid);
  if (user?.role !== 'admin') throw new HttpsError('permission-denied', 'Admins only.');
}

function callbackUrl(): string | undefined {
  const override = CHAPA_CALLBACK_URL.value();
  if (override) return override;
  const project = process.env.GCLOUD_PROJECT;
  return project ? `https://${REGION}-${project}.cloudfunctions.net/chapaWebhook` : undefined;
}

function returnUrl(paymentId: string, txRef: string): string {
  const base = PAYMENT_RETURN_URL.value();
  try {
    return appendQuery(base, { paymentId, txRef });
  } catch {
    throw new HttpsError('failed-precondition', 'Payments are not configured (PAYMENT_RETURN_URL).');
  }
}

/** FlowError (logic/) -> HttpsError; HttpsErrors pass through. */
function toHttpsError(err: unknown): unknown {
  if (err instanceof FlowError) return new HttpsError(err.code, err.message);
  return err;
}

function chapaFailure(err: unknown): HttpsError {
  if (err instanceof HttpsError) return err;
  logger.error('Chapa call failed', err instanceof ChapaError ? { status: err.httpStatus, body: err.body } : err);
  return new HttpsError('unavailable', 'The payment provider is unavailable. Please try again.');
}

interface CheckoutResult {
  checkoutUrl: string;
  paymentId: string;
  txRef: string;
}

/** Calls Chapa initialize for a new payment id. The payment doc is written by the caller. */
async function startCheckout(opts: {
  paymentId: string;
  amount: number;
  name: unknown;
  phone: unknown;
  email?: unknown;
  description: string;
  meta: Record<string, unknown>;
}): Promise<{ txRef: string; checkoutUrl: string }> {
  const txRef = buildTxRef(opts.paymentId);
  const checkoutUrl = await initializeTransaction(CHAPA_SECRET_KEY.value(), {
    amount: toChapaAmount(opts.amount),
    currency: CURRENCY,
    tx_ref: txRef,
    first_name: firstNameOf(opts.name),
    phone_number: toChapaPhone(opts.phone),
    email: toChapaEmail(opts.email),
    callback_url: callbackUrl(),
    return_url: returnUrl(opts.paymentId, txRef),
    customization: {
      title: CHECKOUT_TITLE,
      description: sanitizeCheckoutText(opts.description, 50) || 'Payment',
    },
    meta: opts.meta,
  });
  return { txRef, checkoutUrl };
}

// ---------------------------------------------------------------- callables

/**
 * createBookingPayment({bookingId}) -> {checkoutUrl, paymentId, txRef}
 * Caller must be the booking's customer; booking not cancelled, not paid.
 * Concurrent calls share one checkout: a pending payment of the same
 * booking created in the last PENDING_REUSE_MINUTES is reused (see
 * logic/bookingCheckout.ts).
 */
export const createBookingPayment = onCall({ secrets: [CHAPA_SECRET_KEY] }, async (req): Promise<CheckoutResult> => {
  const uid = requireAuth(req);
  const bookingId = requireString(req.data, 'bookingId');
  const secret = CHAPA_SECRET_KEY.value();
  try {
    return await createBookingCheckout({
      store: firestoreDocStore(),
      uid,
      bookingId,
      currency: CURRENCY,
      reuseMinutes: PENDING_REUSE_MINUTES,
      reverify: async (paymentId) => {
        try {
          return await reverifyPayment(secret, db().collection('payments').doc(paymentId));
        } catch (err) {
          throw chapaFailure(err);
        }
      },
      initCheckout: async ({ paymentId, amount, booking }) => {
        const user = await getUser(uid);
        try {
          const checkout = await startCheckout({
            paymentId,
            amount,
            name: user?.name ?? booking.customerName,
            phone: user?.phone ?? booking.customerPhone,
            email: user?.email,
            description: `${booking.serviceName ?? 'Booking'} ${booking.shopName ?? ''}`,
            meta: { paymentId, bookingId, type: 'booking' },
          });
          return checkout.checkoutUrl;
        } catch (err) {
          throw chapaFailure(err);
        }
      },
    });
  } catch (err) {
    throw toHttpsError(err);
  }
});

/**
 * createSubscriptionPayment({shopId, planId}) -> {checkoutUrl, paymentId, txRef}
 * Caller must be the shop's owner. Pays one month of plans/{planId}.
 */
export const createSubscriptionPayment = onCall(
  { secrets: [CHAPA_SECRET_KEY] },
  async (req): Promise<CheckoutResult> => {
    const uid = requireAuth(req);
    const shopId = requireString(req.data, 'shopId');
    const planId = requireString(req.data, 'planId');
    if (!isPlan(planId) || planId === 'trial') throw new HttpsError('invalid-argument', 'Unknown plan.');

    const shopRef = db().collection('barbershops').doc(shopId);
    const [user, shopSnap, planSnap] = await Promise.all([
      getUser(uid),
      shopRef.get(),
      db().collection('plans').doc(planId).get(),
    ]);
    deny(checkShopOwner(user, shopSnap.data(), uid, shopId));

    const plan = planSnap.data();
    if (!plan || plan.active !== true) throw new HttpsError('not-found', 'This plan is not available.');
    const amount = normalizeAmount(plan.priceMonthlyEtb);
    if (amount === null) throw new HttpsError('failed-precondition', 'This plan has no valid price.');

    const barberCount = (await shopRef.collection('barbers').count().get()).data().count;
    deny(checkPlanFitsShop(plan.maxBarbers, barberCount));

    const paymentRef = db().collection('payments').doc();
    let checkout: { txRef: string; checkoutUrl: string };
    try {
      checkout = await startCheckout({
        paymentId: paymentRef.id,
        amount,
        name: user?.name,
        phone: user?.phone,
        email: user?.email,
        description: `${plan.name ?? planId} plan 1 month`,
        meta: { paymentId: paymentRef.id, shopId, planId, type: 'subscription' },
      });
    } catch (err) {
      throw chapaFailure(err);
    }

    const payment: PaymentDoc = {
      type: 'subscription',
      shopId,
      userId: uid,
      plan: planId,
      amount,
      currency: CURRENCY,
      provider: 'chapa',
      txRef: checkout.txRef,
      status: 'pending',
      checkoutUrl: checkout.checkoutUrl,
      createdAt: new Date().toISOString(),
    };
    await paymentRef.create(payment);
    return { checkoutUrl: checkout.checkoutUrl, paymentId: paymentRef.id, txRef: checkout.txRef };
  },
);

/**
 * verifyPayment({paymentId}) -> {paymentId, type, status, bookingId?, shopId, amount, currency, failureReason?, periodEndsAt?}
 * For the app's return page. Re-checks pending payments with Chapa.
 * Allowed: the payer, the shop's owner, admins.
 */
export const verifyPayment = onCall({ secrets: [CHAPA_SECRET_KEY] }, async (req) => {
  const uid = requireAuth(req);
  const paymentId = requireString(req.data, 'paymentId');
  const ref = db().collection('payments').doc(paymentId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Payment not found.');
  const payment = snap.data() as PaymentDoc;

  if (payment.userId !== uid) {
    const user = await getUser(uid);
    const isOwner = user?.role === 'barbershopOwner' && user?.shopId === payment.shopId;
    if (user?.role !== 'admin' && !isOwner) throw new HttpsError('permission-denied', 'Not your payment.');
  }

  if (payment.status === 'pending' || payment.status === 'failed') {
    try {
      await reverifyPayment(CHAPA_SECRET_KEY.value(), ref);
    } catch (err) {
      throw chapaFailure(err);
    }
  }
  const latest = (await ref.get()).data() as PaymentDoc & { periodEndsAt?: string };
  return {
    paymentId,
    type: latest.type,
    status: latest.status,
    bookingId: latest.bookingId ?? null,
    shopId: latest.shopId,
    amount: latest.amount,
    currency: latest.currency,
    failureReason: latest.failureReason ?? null,
    periodEndsAt: latest.periodEndsAt ?? null,
  };
});

/**
 * setShopSubscription({shopId, plan?, status?, endsAt?, months?}) -> {shopId, subscriptionPlan, subscriptionStatus, subscriptionEndsAt}
 * Admin only; for cash/bank payments and manual fixes. `months` extends from
 * max(now, current end) and sets status active unless `status` is given.
 */
export const setShopSubscription = onCall(async (req) => {
  const uid = requireAuth(req);
  await requireAdmin(uid);
  const shopId = requireString(req.data, 'shopId');
  const data = (req.data ?? {}) as Record<string, unknown>;
  const shopRef = db().collection('barbershops').doc(shopId);

  return db().runTransaction(async (tx) => {
    const snap = await tx.get(shopRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Shop not found.');
    const result = buildManualChange(
      { plan: data.plan, status: data.status, endsAt: data.endsAt, months: data.months },
      snap.data() ?? {},
      new Date(),
    );
    if ('error' in result) throw new HttpsError('invalid-argument', result.error);
    tx.update(shopRef, { ...result.patch });
    logger.info('Admin changed subscription', { shopId, by: uid, patch: result.patch });
    const merged = { ...snap.data(), ...result.patch };
    return {
      shopId,
      subscriptionPlan: merged.subscriptionPlan ?? null,
      subscriptionStatus: merged.subscriptionStatus ?? null,
      subscriptionEndsAt: merged.subscriptionEndsAt ?? null,
    };
  });
});

/**
 * seedDefaultPlans({overwrite?: boolean}) -> {written: string[], skipped: string[]}
 * Admin only. Writes config DEFAULT_PLANS to plans/{basic,pro}.
 */
export const seedDefaultPlans = onCall(async (req) => {
  const uid = requireAuth(req);
  await requireAdmin(uid);
  const overwrite = (req.data as Record<string, unknown> | null)?.overwrite === true;
  const written: string[] = [];
  const skipped: string[] = [];
  for (const [id, plan] of Object.entries(DEFAULT_PLANS)) {
    const ref = db().collection('plans').doc(id);
    if (!overwrite && (await ref.get()).exists) {
      skipped.push(id);
      continue;
    }
    await ref.set(plan);
    written.push(id);
  }
  return { written, skipped };
});

/**
 * resolvePaymentReview({paymentId, resolution: 'refunded_in_chapa' | 'no_action', note?})
 *   -> {paymentId, resolution, status, bookingPaymentStatus, resolvedAt}
 * Admin only. Closes a payment flagged needsReview (see logic/review.ts).
 */
export const resolvePaymentReview = onCall(async (req) => {
  const uid = requireAuth(req);
  await requireAdmin(uid);
  try {
    const request = parseReviewRequest(req.data);
    const result = await resolveReview(firestoreDocStore(), request, uid);
    logger.info('Payment review resolved', { ...result, by: uid });
    return result;
  } catch (err) {
    throw toHttpsError(err);
  }
});

// ---------------------------------------------------------------- webhook

async function settleTxRef(txRef: string): Promise<string> {
  const ref = await findPaymentByTxRef(txRef);
  if (!ref) return 'unknown';
  return reverifyPayment(CHAPA_SECRET_KEY.value(), ref);
}

/**
 * chapaWebhook: POST from Chapa (signed) and GET from callback_url.
 * Never trusts the payload: every transaction is re-verified with
 * GET /transaction/verify. Returns 200 once handled (so Chapa stops
 * retrying), 401 on bad signature, 500 on transient errors (Chapa retries).
 */
export const chapaWebhook = onRequest(
  { secrets: [CHAPA_SECRET_KEY, CHAPA_WEBHOOK_SECRET], invoker: 'public' },
  async (req, res) => {
    try {
      if (req.method === 'GET') {
        // callback_url ping: ?trx_ref=...&status=... Unauthenticated, so only
        // used as a hint to re-verify a payment we already know about.
        const txRef = String(req.query.trx_ref ?? req.query.tx_ref ?? '');
        if (txRef) {
          const status = await settleTxRef(txRef);
          logger.info('Chapa callback handled', { txRef, status });
        }
        res.status(200).send('ok');
        return;
      }
      if (req.method !== 'POST') {
        res.status(405).send('method not allowed');
        return;
      }

      const sig = verifyChapaSignature({
        secret: CHAPA_WEBHOOK_SECRET.value(),
        rawBody: req.rawBody,
        parsedBody: req.body,
        chapaSignature: req.headers['chapa-signature'],
        xChapaSignature: req.headers['x-chapa-signature'],
      });
      if (!sig.valid) {
        logger.warn('Chapa webhook with invalid signature');
        res.status(401).send('invalid signature');
        return;
      }

      const body = (req.body ?? {}) as Record<string, unknown>;
      const event = typeof body.event === 'string' ? body.event : '';
      const txRef = typeof body.tx_ref === 'string' ? body.tx_ref : '';
      if (event.startsWith('payout.') || !txRef) {
        res.status(200).send('ignored');
        return;
      }

      if (event === 'charge.refunded' || event === 'charge.reversed') {
        const ref = await findPaymentByTxRef(txRef);
        if (ref && sig.payloadBound) {
          await markRefunded(ref);
        } else if (ref) {
          logger.warn('Refund event without payload signature; flag for review', { txRef, event });
          await ref.update({ needsReview: true });
        }
        res.status(200).send('ok');
        return;
      }

      const status = await settleTxRef(txRef);
      logger.info('Chapa webhook handled', { txRef, event, status });
      res.status(200).send('ok');
    } catch (err) {
      logger.error('Chapa webhook failed', err);
      res.status(500).send('error');
    }
  },
);

// ---------------------------------------------------------------- schedule

/**
 * Daily at 03:00 Addis time: start trials for shops without subscription
 * fields, trialing/active past end -> past_due, 7 days past end -> suspended.
 */
export const dailySubscriptionCheck = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Africa/Addis_Ababa', retryCount: 2 },
  async () => {
    const now = new Date();
    const writer = db().bulkWriter();
    let scanned = 0;
    let changed = 0;
    let last: string | undefined;
    for (;;) {
      let q = db()
        .collection('barbershops')
        .orderBy(FieldPath.documentId())
        .select('subscriptionPlan', 'subscriptionStatus', 'subscriptionEndsAt', 'createdAt')
        .limit(300);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      for (const doc of page.docs) {
        scanned++;
        const patch = computeScheduledUpdate(doc.data(), now);
        if (patch) {
          changed++;
          writer
            .update(doc.ref, { ...patch })
            .catch((err) => logger.error('Subscription update failed', { shopId: doc.id, err: String(err) }));
        }
      }
      last = page.docs[page.docs.length - 1].id;
      if (page.size < 300) break;
    }
    await writer.close();
    logger.info('Subscription check done', { scanned, changed });
  },
);
