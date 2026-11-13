/** Firestore side of payments: applying verified outcomes idempotently. */
import { getFirestore, DocumentReference, Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { verifyTransaction } from './chapa';
import { paymentIdFromTxRef } from './logic/checkout';
import { isPlan, paidSubscriptionPatch } from './logic/subscription';
import { ChapaVerifyData, evaluateVerification, PaymentStatus, VerifyOutcome } from './logic/verification';

export const db = (): Firestore => getFirestore();

export interface PaymentDoc {
  type: 'booking' | 'subscription';
  bookingId?: string;
  shopId: string;
  userId: string;
  plan?: string;
  amount: number;
  currency: string;
  provider: 'chapa';
  txRef: string;
  status: PaymentStatus;
  checkoutUrl: string;
  createdAt: string;
  verifiedAt?: string;
  failureReason?: string;
  chapaReference?: string;
  chapaMethod?: string;
  needsReview?: boolean;
  refundedAt?: string;
}

export async function findPaymentByTxRef(txRef: string): Promise<DocumentReference | null> {
  const id = paymentIdFromTxRef(txRef);
  if (id) {
    const ref = db().collection('payments').doc(id);
    const snap = await ref.get();
    if (snap.exists && snap.get('txRef') === txRef) return ref;
  }
  const q = await db().collection('payments').where('txRef', '==', txRef).limit(1).get();
  return q.empty ? null : q.docs[0].ref;
}

/**
 * Writes the outcome of a Chapa verification. Idempotent:
 * - success is final (never overwritten);
 * - pending -> success|failed; failed -> success (money actually arrived).
 * Returns the payment status after the write.
 */
export async function applyOutcome(
  paymentRef: DocumentReference,
  outcome: VerifyOutcome,
  data: ChapaVerifyData | null,
  now = new Date(),
): Promise<PaymentStatus> {
  if (outcome.outcome === 'pending') {
    const snap = await paymentRef.get();
    return (snap.get('status') as PaymentStatus) ?? 'pending';
  }

  return db().runTransaction(async (tx) => {
    const paySnap = await tx.get(paymentRef);
    if (!paySnap.exists) throw new Error(`payment ${paymentRef.id} vanished`);
    const payment = paySnap.data() as PaymentDoc;
    if (payment.status === 'success') return 'success';
    if (payment.status === 'failed' && outcome.outcome === 'failed') return 'failed';

    const nowIso = now.toISOString();
    const bookingRef =
      payment.type === 'booking' && payment.bookingId ? db().collection('bookings').doc(payment.bookingId) : null;
    const shopRef = payment.type === 'subscription' ? db().collection('barbershops').doc(payment.shopId) : null;
    const bookingSnap = bookingRef ? await tx.get(bookingRef) : null;
    const shopSnap = shopRef ? await tx.get(shopRef) : null;

    const chapaFields: Partial<PaymentDoc> = {};
    if (typeof data?.reference === 'string') chapaFields.chapaReference = data.reference;
    if (typeof data?.method === 'string') chapaFields.chapaMethod = data.method;

    if (outcome.outcome === 'failed') {
      tx.update(paymentRef, { status: 'failed', failureReason: outcome.reason, verifiedAt: nowIso, ...chapaFields });
      if (bookingRef && bookingSnap?.exists) {
        const b = bookingSnap.data()!;
        if (b.paymentStatus === 'pending' && b.paymentId === paymentRef.id) {
          tx.update(bookingRef, { paymentStatus: 'unpaid' });
        }
      }
      if (outcome.reason.endsWith('_mismatch')) {
        logger.error('Chapa reported success with mismatching details', { paymentId: paymentRef.id, reason: outcome.reason });
      }
      return 'failed';
    }

    // success
    const update: Record<string, unknown> = { status: 'success', verifiedAt: nowIso, failureReason: null, ...chapaFields };

    if (bookingRef) {
      if (bookingSnap?.exists) {
        const b = bookingSnap.data()!;
        if (b.status === 'cancelled') {
          update.needsReview = true; // paid for a cancelled booking: admin should refund
          logger.warn('Payment succeeded for a cancelled booking', { paymentId: paymentRef.id, bookingId: bookingRef.id });
        }
        tx.update(bookingRef, {
          paymentStatus: 'paid',
          paymentMethod: 'chapa',
          paymentId: paymentRef.id,
          paidAt: nowIso,
        });
      } else {
        update.needsReview = true;
        logger.warn('Payment succeeded for a missing booking', { paymentId: paymentRef.id });
      }
    }

    if (shopRef) {
      if (shopSnap?.exists && isPlan(payment.plan)) {
        const patch = paidSubscriptionPatch(payment.plan, shopSnap.get('subscriptionEndsAt'), now);
        tx.update(shopRef, { ...patch });
        update.periodEndsAt = patch.subscriptionEndsAt;
      } else {
        update.needsReview = true;
        logger.warn('Subscription payment could not be applied', { paymentId: paymentRef.id, plan: payment.plan });
      }
    }

    tx.update(paymentRef, update);
    return 'success';
  });
}

/** Re-checks one payment with Chapa and records the result. */
export async function reverifyPayment(secretKey: string, paymentRef: DocumentReference): Promise<PaymentStatus> {
  const snap = await paymentRef.get();
  if (!snap.exists) throw new Error('payment not found');
  const payment = snap.data() as PaymentDoc;
  if (payment.status === 'success') return 'success';
  const data = await verifyTransaction(secretKey, payment.txRef);
  const outcome = evaluateVerification(
    { amount: payment.amount, currency: payment.currency, txRef: payment.txRef },
    data,
  );
  return applyOutcome(paymentRef, outcome, data);
}

/** Booking refunds reported by a payload-signed charge.refunded/charge.reversed webhook. */
export async function markRefunded(paymentRef: DocumentReference, now = new Date()): Promise<void> {
  await db().runTransaction(async (tx) => {
    const paySnap = await tx.get(paymentRef);
    if (!paySnap.exists) return;
    const payment = paySnap.data() as PaymentDoc;
    if (payment.status !== 'success' || payment.refundedAt) return;
    const bookingRef =
      payment.type === 'booking' && payment.bookingId ? db().collection('bookings').doc(payment.bookingId) : null;
    const bookingSnap = bookingRef ? await tx.get(bookingRef) : null;
    tx.update(paymentRef, { refundedAt: now.toISOString(), needsReview: payment.type === 'subscription' });
    if (bookingRef && bookingSnap?.exists && bookingSnap.get('paymentId') === paymentRef.id) {
      tx.update(bookingRef, { paymentStatus: 'refunded' });
    }
  });
}
