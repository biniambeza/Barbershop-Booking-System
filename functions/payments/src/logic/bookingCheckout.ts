/**
 * createBookingPayment flow. Concurrent calls for the same booking must not
 * open two Chapa checkouts, so the payment document is reserved in a
 * transaction before Chapa is called:
 *
 *  1. (outside a transaction) a previous pending checkout is re-checked
 *     with Chapa, so a booking that was in fact paid is not charged again;
 *  2. a transaction re-reads the booking. If it points at a pending payment
 *     of this customer created less than [reuseMinutes] ago, that payment is
 *     reused. Otherwise a new pending payment (checkoutUrl '') is created
 *     and the booking is pointed at it;
 *  3. only the call that created the reservation calls Chapa and stores the
 *     checkoutUrl. A concurrent call that reused a reservation still being
 *     initialized waits briefly for its checkoutUrl.
 *
 * If Chapa fails, the reservation is marked failed ('checkout_init_failed')
 * and the booking goes back to unpaid.
 */
import { buildTxRef } from './checkout';
import { DocData, DocStore, DocTx, FlowError } from './docstore';
import { checkBookingPayable, Denial } from './eligibility';
import { normalizeAmount } from './money';

export interface CheckoutResult {
  checkoutUrl: string;
  paymentId: string;
  txRef: string;
}

export interface BookingCheckoutDeps {
  store: DocStore;
  uid: string;
  bookingId: string;
  currency: string;
  reuseMinutes: number;
  /** Calls Chapa initialize; returns the hosted checkout URL. */
  initCheckout(args: { paymentId: string; txRef: string; amount: number; booking: DocData }): Promise<string>;
  /** Re-checks a pending payment with Chapa; returns its status afterwards. */
  reverify?(paymentId: string): Promise<string>;
  now?: () => Date;
  sleep?: (ms: number) => Promise<void>;
  /** How often / how long a concurrent call waits for a checkoutUrl. */
  waitAttempts?: number;
  waitMs?: number;
}

export const CHECKOUT_INIT_FAILED = 'checkout_init_failed';

function denyIf(d: Denial | null): void {
  if (d) throw new FlowError(d.code, d.message);
}

/** True when [payment] is a pending checkout of [uid] for [bookingId] young enough to reuse. */
export function isReusablePending(
  payment: DocData | undefined,
  bookingId: string,
  uid: string,
  now: Date,
  reuseMinutes: number,
): boolean {
  if (!payment || payment.status !== 'pending') return false;
  if (payment.type !== 'booking' || payment.bookingId !== bookingId || payment.userId !== uid) return false;
  const created = Date.parse(String(payment.createdAt ?? ''));
  if (Number.isNaN(created)) return false;
  const age = now.getTime() - created;
  return age >= -60_000 && age < reuseMinutes * 60_000;
}

async function findReusable(
  tx: DocTx,
  booking: DocData,
  bookingId: string,
  uid: string,
  now: Date,
  reuseMinutes: number,
): Promise<{ id: string; data: DocData } | null> {
  if (booking.paymentStatus !== 'pending' || typeof booking.paymentId !== 'string' || !booking.paymentId) return null;
  const data = await tx.get('payments', booking.paymentId);
  return isReusablePending(data, bookingId, uid, now, reuseMinutes) ? { id: booking.paymentId, data: data! } : null;
}

export async function createBookingCheckout(deps: BookingCheckoutDeps): Promise<CheckoutResult> {
  const { store, uid, bookingId } = deps;
  const now = deps.now ?? (() => new Date());
  const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));

  // 1. Settle a previous pending checkout first (it may have been paid).
  const booking = await store.get('bookings', bookingId);
  denyIf(checkBookingPayable(booking, uid));
  if (deps.reverify && booking!.paymentStatus === 'pending' && typeof booking!.paymentId === 'string') {
    const prev = await store.get('payments', booking!.paymentId);
    // A reservation without a checkoutUrl is still being created: Chapa does
    // not know it yet, so there is nothing to verify.
    if (prev?.status === 'pending' && prev.checkoutUrl) {
      const status = await deps.reverify(booking!.paymentId);
      if (status === 'success') throw new FlowError('already-exists', 'This booking is already paid.');
    }
  }

  const amount = normalizeAmount(booking!.price);
  if (amount === null) throw new FlowError('failed-precondition', 'This booking has no valid price.');

  // 2. Reserve (or reuse) in a transaction.
  const newId = store.newId('payments');
  const decision = await store.runTransaction(async (tx) => {
    const fresh = await tx.get('bookings', bookingId);
    denyIf(checkBookingPayable(fresh, uid));
    if (normalizeAmount(fresh!.price) !== amount) {
      throw new FlowError('aborted', 'The booking changed. Please try again.');
    }
    const at = now();
    const reusable = await findReusable(tx, fresh!, bookingId, uid, at, deps.reuseMinutes);
    if (reusable) return { kind: 'reuse' as const, id: reusable.id, payment: reusable.data };

    const payment: DocData = {
      type: 'booking',
      bookingId,
      shopId: String(fresh!.shopId ?? ''),
      userId: uid,
      amount,
      currency: deps.currency,
      provider: 'chapa',
      txRef: buildTxRef(newId),
      status: 'pending',
      checkoutUrl: '',
      createdAt: at.toISOString(),
    };
    tx.create('payments', newId, payment);
    tx.update('bookings', bookingId, { paymentStatus: 'pending', paymentMethod: 'chapa', paymentId: newId });
    return { kind: 'create' as const, id: newId, payment, booking: fresh! };
  });

  if (decision.kind === 'reuse') {
    let payment: DocData | undefined = decision.payment;
    const attempts = deps.waitAttempts ?? 10;
    for (let i = 0; ; i++) {
      if (payment?.checkoutUrl) {
        return { checkoutUrl: String(payment.checkoutUrl), paymentId: decision.id, txRef: String(payment.txRef) };
      }
      if (!payment || payment.status !== 'pending' || i >= attempts) break;
      await sleep(deps.waitMs ?? 800);
      payment = await store.get('payments', decision.id);
    }
    throw new FlowError('aborted', 'Your payment is still being prepared. Please try again.');
  }

  // 3. This call owns the reservation: open the Chapa checkout.
  const txRef = String(decision.payment.txRef);
  let checkoutUrl: string;
  try {
    checkoutUrl = await deps.initCheckout({ paymentId: decision.id, txRef, amount, booking: decision.booking });
  } catch (err) {
    await releaseReservation(store, bookingId, decision.id, now()).catch(() => undefined);
    throw err;
  }
  await store.update('payments', decision.id, { checkoutUrl });
  return { checkoutUrl, paymentId: decision.id, txRef };
}

/** Marks a reservation whose Chapa checkout could not be opened as failed. */
export async function releaseReservation(store: DocStore, bookingId: string, paymentId: string, now: Date): Promise<void> {
  await store.runTransaction(async (tx) => {
    const payment = await tx.get('payments', paymentId);
    const booking = await tx.get('bookings', bookingId);
    if (payment && payment.status === 'pending' && !payment.checkoutUrl) {
      tx.update('payments', paymentId, {
        status: 'failed',
        failureReason: CHECKOUT_INIT_FAILED,
        verifiedAt: now.toISOString(),
      });
    }
    if (booking && booking.paymentStatus === 'pending' && booking.paymentId === paymentId) {
      tx.update('bookings', bookingId, { paymentStatus: 'unpaid' });
    }
  });
}
