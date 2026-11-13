import { test } from 'node:test';
import assert from 'node:assert/strict';

import { CHECKOUT_INIT_FAILED, createBookingCheckout, isReusablePending } from '../src/logic/bookingCheckout';
import { DocData, DocStore, DocTx, FlowError } from '../src/logic/docstore';
import { parseReviewRequest, resolvePaymentReview } from '../src/logic/review';

const NOW = new Date('2026-11-13T09:00:00.000Z');
const minutesAgo = (m: number) => new Date(NOW.getTime() - m * 60_000).toISOString();

/**
 * In-memory DocStore. Transactions are serialized (like Firestore's
 * pessimistic server transactions) and their writes are applied on commit.
 */
class MemoryStore implements DocStore {
  docs = new Map<string, DocData>();
  private seq = 0;
  private lock: Promise<void> = Promise.resolve();

  key(c: string, id: string) {
    return `${c}/${id}`;
  }
  set(c: string, id: string, data: DocData) {
    this.docs.set(this.key(c, id), { ...data });
  }
  doc(c: string, id: string) {
    return this.docs.get(this.key(c, id));
  }
  all(c: string) {
    return [...this.docs.entries()].filter(([k]) => k.startsWith(`${c}/`)).map(([, v]) => v);
  }

  async get(c: string, id: string) {
    await Promise.resolve();
    const d = this.doc(c, id);
    return d ? { ...d } : undefined;
  }
  async update(c: string, id: string, data: DocData) {
    const d = this.doc(c, id);
    if (!d) throw new Error(`no ${c}/${id}`);
    this.docs.set(this.key(c, id), { ...d, ...data });
  }
  newId() {
    return `pay${++this.seq}`;
  }
  async runTransaction<T>(fn: (tx: DocTx) => Promise<T>): Promise<T> {
    const previous = this.lock;
    let release!: () => void;
    this.lock = new Promise<void>((r) => (release = r));
    await previous;
    try {
      const writes: Array<() => void> = [];
      const tx: DocTx = {
        get: (c, id) => this.get(c, id),
        create: (c, id, data) =>
          writes.push(() => {
            if (this.doc(c, id)) throw new Error(`already exists: ${c}/${id}`);
            this.set(c, id, data);
          }),
        update: (c, id, data) =>
          writes.push(() => {
            const d = this.doc(c, id);
            if (!d) throw new Error(`no ${c}/${id}`);
            this.set(c, id, { ...d, ...data });
          }),
      };
      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    } finally {
      release();
    }
  }
}

function bookingStore(extra: DocData = {}): MemoryStore {
  const store = new MemoryStore();
  store.set('bookings', 'b1', {
    customerId: 'u1',
    shopId: 's1',
    status: 'confirmed',
    paymentStatus: 'unpaid',
    price: 450,
    serviceName: 'Haircut',
    shopName: 'Crown Cuts',
    ...extra,
  });
  return store;
}

function deps(store: MemoryStore, over: Partial<Parameters<typeof createBookingCheckout>[0]> = {}) {
  let chapaCalls = 0;
  const d = {
    store,
    uid: 'u1',
    bookingId: 'b1',
    currency: 'ETB',
    reuseMinutes: 30,
    now: () => NOW,
    sleep: async () => {
      await new Promise((r) => setTimeout(r, 2));
    },
    initCheckout: async ({ paymentId }: { paymentId: string }) => {
      chapaCalls++;
      // Let other calls interleave while "Chapa" answers.
      await new Promise((r) => setTimeout(r, 5));
      return `https://checkout.chapa.co/${paymentId}`;
    },
    ...over,
  };
  return { d, calls: () => chapaCalls };
}

// ------------------------------------------------------------- double checkout
test('createBookingCheckout reserves a payment and points the booking at it', async () => {
  const store = bookingStore();
  const { d, calls } = deps(store);
  const result = await createBookingCheckout(d);
  assert.equal(calls(), 1);
  assert.equal(result.txRef, `cb-${result.paymentId}`);
  assert.equal(result.checkoutUrl, `https://checkout.chapa.co/${result.paymentId}`);
  const payment = store.doc('payments', result.paymentId)!;
  assert.equal(payment.status, 'pending');
  assert.equal(payment.checkoutUrl, result.checkoutUrl);
  assert.equal(payment.amount, 450);
  assert.equal(payment.bookingId, 'b1');
  assert.equal(payment.createdAt, NOW.toISOString());
  const booking = store.doc('bookings', 'b1')!;
  assert.equal(booking.paymentStatus, 'pending');
  assert.equal(booking.paymentId, result.paymentId);
  assert.equal(booking.paymentMethod, 'chapa');
});

test('concurrent createBookingCheckout calls share one Chapa checkout', async () => {
  const store = bookingStore();
  const { d, calls } = deps(store);
  const results = await Promise.all([createBookingCheckout(d), createBookingCheckout(d), createBookingCheckout(d)]);
  assert.equal(calls(), 1);
  assert.equal(store.all('payments').length, 1);
  for (const r of results) {
    assert.equal(r.paymentId, results[0].paymentId);
    assert.equal(r.checkoutUrl, results[0].checkoutUrl);
  }
});

test('a fresh pending checkout is reused, an old one is replaced', async () => {
  const store = bookingStore({ paymentStatus: 'pending', paymentId: 'old' });
  store.set('payments', 'old', {
    type: 'booking',
    bookingId: 'b1',
    userId: 'u1',
    status: 'pending',
    txRef: 'cb-old',
    checkoutUrl: 'https://checkout.chapa.co/old',
    createdAt: minutesAgo(10),
  });
  let reverified = 0;
  const { d, calls } = deps(store, {
    reverify: async () => {
      reverified++;
      return 'pending';
    },
  });
  const reused = await createBookingCheckout(d);
  assert.equal(reused.paymentId, 'old');
  assert.equal(reused.checkoutUrl, 'https://checkout.chapa.co/old');
  assert.equal(calls(), 0);
  assert.equal(reverified, 1);

  store.set('payments', 'old', { ...store.doc('payments', 'old')!, createdAt: minutesAgo(45) });
  const fresh = await createBookingCheckout(d);
  assert.notEqual(fresh.paymentId, 'old');
  assert.equal(calls(), 1);
  assert.equal(store.doc('bookings', 'b1')!.paymentId, fresh.paymentId);
});

test('a pending checkout that Chapa reports paid is not charged again', async () => {
  const store = bookingStore({ paymentStatus: 'pending', paymentId: 'old' });
  store.set('payments', 'old', {
    type: 'booking',
    bookingId: 'b1',
    userId: 'u1',
    status: 'pending',
    txRef: 'cb-old',
    checkoutUrl: 'https://checkout.chapa.co/old',
    createdAt: minutesAgo(2),
  });
  const { d, calls } = deps(store, { reverify: async () => 'success' });
  await assert.rejects(createBookingCheckout(d), (e: unknown) => e instanceof FlowError && e.code === 'already-exists');
  assert.equal(calls(), 0);
});

test('a reservation still being created is waited for, then reused', async () => {
  const store = bookingStore({ paymentStatus: 'pending', paymentId: 'busy' });
  store.set('payments', 'busy', {
    type: 'booking',
    bookingId: 'b1',
    userId: 'u1',
    status: 'pending',
    txRef: 'cb-busy',
    checkoutUrl: '',
    createdAt: minutesAgo(0),
  });
  let slept = 0;
  const { d, calls } = deps(store, {
    reverify: async () => assert.fail('nothing to verify yet'),
    sleep: async () => {
      if (++slept === 2) store.set('payments', 'busy', { ...store.doc('payments', 'busy')!, checkoutUrl: 'https://x/busy' });
    },
  });
  const result = await createBookingCheckout(d);
  assert.equal(result.paymentId, 'busy');
  assert.equal(result.checkoutUrl, 'https://x/busy');
  assert.equal(calls(), 0);

  // Never finishes: the caller is asked to try again.
  store.set('payments', 'busy', { ...store.doc('payments', 'busy')!, checkoutUrl: '' });
  const stuck = deps(store, { sleep: async () => undefined, waitAttempts: 3 }).d;
  await assert.rejects(createBookingCheckout(stuck), (e: unknown) => e instanceof FlowError && e.code === 'aborted');
});

test('a failed Chapa initialize releases the reservation', async () => {
  const store = bookingStore();
  const { d } = deps(store, {
    initCheckout: async () => {
      throw new Error('chapa down');
    },
  });
  await assert.rejects(createBookingCheckout(d), /chapa down/);
  const [payment] = store.all('payments');
  assert.equal(payment.status, 'failed');
  assert.equal(payment.failureReason, CHECKOUT_INIT_FAILED);
  assert.equal(store.doc('bookings', 'b1')!.paymentStatus, 'unpaid');
});

test('createBookingCheckout enforces who may pay', async () => {
  const cases: Array<[DocData, string, string]> = [
    [{ status: 'cancelled' }, 'u1', 'failed-precondition'],
    [{ paymentStatus: 'paid' }, 'u1', 'already-exists'],
    [{}, 'someone-else', 'permission-denied'],
    [{ price: 0 }, 'u1', 'failed-precondition'],
  ];
  for (const [extra, uid, code] of cases) {
    const store = bookingStore(extra);
    const { d } = deps(store, { uid });
    await assert.rejects(createBookingCheckout(d), (e: unknown) => e instanceof FlowError && e.code === code);
    assert.equal(store.all('payments').length, 0);
  }
  const missing = deps(new MemoryStore()).d;
  await assert.rejects(createBookingCheckout(missing), (e: unknown) => e instanceof FlowError && e.code === 'not-found');
});

test('isReusablePending checks owner, booking, status and age', () => {
  const p = { type: 'booking', bookingId: 'b1', userId: 'u1', status: 'pending', createdAt: minutesAgo(5) };
  assert.equal(isReusablePending(p, 'b1', 'u1', NOW, 30), true);
  assert.equal(isReusablePending({ ...p, status: 'failed' }, 'b1', 'u1', NOW, 30), false);
  assert.equal(isReusablePending({ ...p, userId: 'u2' }, 'b1', 'u1', NOW, 30), false);
  assert.equal(isReusablePending({ ...p, bookingId: 'b2' }, 'b1', 'u1', NOW, 30), false);
  assert.equal(isReusablePending({ ...p, createdAt: minutesAgo(31) }, 'b1', 'u1', NOW, 30), false);
  assert.equal(isReusablePending({ ...p, createdAt: 'garbage' }, 'b1', 'u1', NOW, 30), false);
  assert.equal(isReusablePending(undefined, 'b1', 'u1', NOW, 30), false);
});

// ------------------------------------------------------------- payment review
function reviewStore(payment: DocData, booking: DocData = {}): MemoryStore {
  const store = new MemoryStore();
  store.set('payments', 'p1', {
    type: 'booking',
    bookingId: 'b1',
    shopId: 's1',
    userId: 'u1',
    status: 'success',
    needsReview: true,
    ...payment,
  });
  store.set('bookings', 'b1', { status: 'cancelled', paymentStatus: 'paid', paymentId: 'p1', ...booking });
  return store;
}

test('refunded_in_chapa refunds the payment and the booking', async () => {
  const store = reviewStore({});
  const result = await resolvePaymentReview(
    store,
    { paymentId: 'p1', resolution: 'refunded_in_chapa', note: 'Refunded in dashboard' },
    'admin1',
    NOW,
  );
  assert.deepEqual(result, {
    paymentId: 'p1',
    resolution: 'refunded_in_chapa',
    status: 'refunded',
    bookingPaymentStatus: 'refunded',
    resolvedAt: NOW.toISOString(),
  });
  const p = store.doc('payments', 'p1')!;
  assert.equal(p.needsReview, false);
  assert.equal(p.status, 'refunded');
  assert.equal(p.refundedAt, NOW.toISOString());
  assert.equal(p.resolution, 'refunded_in_chapa');
  assert.equal(p.resolutionNote, 'Refunded in dashboard');
  assert.equal(p.resolvedBy, 'admin1');
  assert.equal(p.resolvedAt, NOW.toISOString());
  assert.equal(store.doc('bookings', 'b1')!.paymentStatus, 'refunded');
});

test('refunding a duplicate payment leaves the booking paid', async () => {
  const store = reviewStore({}, { status: 'confirmed', paymentId: 'p0' });
  const result = await resolvePaymentReview(store, { paymentId: 'p1', resolution: 'refunded_in_chapa', note: null }, 'a', NOW);
  assert.equal(result.bookingPaymentStatus, 'paid');
  assert.equal(store.doc('bookings', 'b1')!.paymentStatus, 'paid');
  assert.equal(store.doc('payments', 'p1')!.status, 'refunded');
});

test('no_action only clears the flag', async () => {
  const store = reviewStore({});
  const result = await resolvePaymentReview(store, { paymentId: 'p1', resolution: 'no_action', note: null }, 'a', NOW);
  assert.equal(result.status, 'success');
  const p = store.doc('payments', 'p1')!;
  assert.equal(p.needsReview, false);
  assert.equal(p.status, 'success');
  assert.equal(p.resolution, 'no_action');
  assert.equal(p.resolutionNote, null);
  assert.equal(p.refundedAt, undefined);
  assert.equal(store.doc('bookings', 'b1')!.paymentStatus, 'paid');
});

test('resolvePaymentReview rejects payments not under review, missing or unpaid', async () => {
  const notFlagged = reviewStore({ needsReview: false });
  await assert.rejects(
    resolvePaymentReview(notFlagged, { paymentId: 'p1', resolution: 'no_action', note: null }, 'a', NOW),
    (e: unknown) => e instanceof FlowError && e.code === 'failed-precondition',
  );
  await assert.rejects(
    resolvePaymentReview(new MemoryStore(), { paymentId: 'p1', resolution: 'no_action', note: null }, 'a', NOW),
    (e: unknown) => e instanceof FlowError && e.code === 'not-found',
  );
  const failed = reviewStore({ status: 'failed' });
  await assert.rejects(
    resolvePaymentReview(failed, { paymentId: 'p1', resolution: 'refunded_in_chapa', note: null }, 'a', NOW),
    (e: unknown) => e instanceof FlowError && e.code === 'failed-precondition',
  );
  assert.equal(failed.doc('payments', 'p1')!.needsReview, true);
});

test('subscription payments can be resolved without a booking', async () => {
  const store = new MemoryStore();
  store.set('payments', 'p2', { type: 'subscription', shopId: 's1', status: 'success', needsReview: true });
  const result = await resolvePaymentReview(store, { paymentId: 'p2', resolution: 'refunded_in_chapa', note: null }, 'a', NOW);
  assert.equal(result.bookingPaymentStatus, null);
  assert.equal(store.doc('payments', 'p2')!.status, 'refunded');
});

test('parseReviewRequest validates input', () => {
  assert.deepEqual(parseReviewRequest({ paymentId: 'p1', resolution: 'no_action' }), {
    paymentId: 'p1',
    resolution: 'no_action',
    note: null,
  });
  assert.equal(parseReviewRequest({ paymentId: 'p1', resolution: 'no_action', note: '  ok  ' }).note, 'ok');
  assert.equal(parseReviewRequest({ paymentId: 'p1', resolution: 'no_action', note: '   ' }).note, null);
  const bad = [
    {},
    { paymentId: 'p1' },
    { paymentId: 'p1', resolution: 'refund' },
    { paymentId: 'a/b', resolution: 'no_action' },
    { paymentId: 'p1', resolution: 'no_action', note: 5 },
    { paymentId: 'p1', resolution: 'no_action', note: 'x'.repeat(501) },
    null,
  ];
  for (const data of bad) {
    assert.throws(() => parseReviewRequest(data), (e: unknown) => e instanceof FlowError && e.code === 'invalid-argument');
  }
});
