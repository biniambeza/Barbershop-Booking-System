import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  AccountDeletionStore,
  barberLeftText,
  barberOf,
  BookingRow,
  BookingWrite,
  cleanupDeletedAccount,
  isLateCustomerCancel,
  keepsContact,
  NoticeDoc,
  planOwnCancel,
  refundAmountFor,
  refundDueText,
} from '../src/logic/accountDeletion';

const NOW = new Date('2026-11-20T09:00:00.000Z'); // 12:00 Addis

type Row = BookingRow & Record<string, unknown>;

interface World {
  bookings: Map<string, Row>;
  /** `${shopId}/${barberId}` -> lock id -> bookingId */
  locks: Map<string, Map<string, string>>;
  reviews: Map<string, Record<string, unknown>>; // `${shopId}/${bookingId}`
  cutoffs: Map<string, number>;
  languages: Map<string, string>;
  profiles: { uid: string; shopId?: string; barberId?: string }[];
  barberTrees: Set<string>;
  portfolioFiles: Map<string, number>;
  notices: Map<string, NoticeDoc>; // `${uid}/${id}`
  personal: string[];
  writes: number;
}

const b = (id: string, extra: Partial<Row>): Row => ({
  id,
  status: 'confirmed',
  customerId: 'gone',
  customerName: 'Abebe Kebede',
  customerPhone: '+251911000111',
  shopId: 's1',
  shopName: 'Crown Cuts',
  barberId: 'x1',
  barberName: 'Dawit',
  price: 300,
  paymentStatus: 'unpaid',
  ...extra,
});

function world(): World {
  return {
    bookings: new Map(
      [
        // The deleted customer ('gone').
        b('soonPaid', { startAt: '2026-11-20T10:00:00.000Z', paymentStatus: 'paid' }), // inside the 2 h cutoff
        b('soonUnpaid', { startAt: '2026-11-20T10:30:00.000Z', status: 'pending' }),
        b('laterPaid', { startAt: '2026-11-25T10:00:00.000Z', paymentStatus: 'paid', shopId: 's2', barberId: 'y1' }),
        b('past', { startAt: '2026-11-10T10:00:00.000Z', status: 'completed' }),
        b('due', {
          startAt: '2026-11-11T10:00:00.000Z',
          status: 'cancelled',
          paymentStatus: 'paid',
          refundStatus: 'due',
          refundAmount: 300,
        }),
        b('anon', { startAt: '2026-11-09T10:00:00.000Z', status: 'completed', customerName: 'Former customer', customerPhone: '' }),
        // Other customers of barber x1 (the deleted user is not that barber here).
        b('otherCust', { customerId: 'c2', startAt: '2026-11-21T10:00:00.000Z' }),
      ].map((r) => [r.id, r]),
    ),
    locks: new Map([
      ['s1/x1', new Map([['20261120-1300', 'soonPaid'], ['20261120-1330', 'soonUnpaid'], ['20261121-1300', 'otherCust']])],
      ['s2/y1', new Map([['20261125-1300', 'laterPaid']])],
    ]),
    reviews: new Map([
      ['s1/past', { customerId: 'gone', customerName: 'Abebe', rating: 4, comment: 'Great', reply: 'Thanks' }],
      ['s1/anon', { customerId: 'gone', customerName: 'Former customer', rating: 5 }],
    ]),
    cutoffs: new Map([['s1', 2], ['s2', 2]]),
    languages: new Map([['c2', 'en']]),
    profiles: [],
    barberTrees: new Set(['s1/x1', 's1/x2']),
    portfolioFiles: new Map([['s1/x1', 3]]),
    notices: new Map(),
    personal: [],
    writes: 0,
  };
}

function storeOf(w: World): AccountDeletionStore {
  return {
    async bookingsOfCustomer(uid) {
      return [...w.bookings.values()].filter((r) => r.customerId === uid).map((r) => ({ ...r }));
    },
    async upcomingBookingsOfBarber(shopId, barberId, nowIso) {
      return [...w.bookings.values()]
        .filter((r) => r.shopId === shopId && r.barberId === barberId && (r.startAt as string) >= nowIso)
        .map((r) => ({ ...r }));
    },
    async cutoffHours(shopId) {
      return w.cutoffs.get(shopId) ?? null;
    },
    async languageOf(uid) {
      return w.languages.get(uid);
    },
    async updateBooking(id, plan: (current: BookingRow | null) => BookingWrite | null) {
      const current = w.bookings.get(id);
      const write = plan(current ? { ...current } : null);
      if (!write || !current) return false;
      w.writes++;
      w.bookings.set(id, { ...current, ...write.fields });
      if (write.releaseLocks) {
        const locks = w.locks.get(`${current.shopId}/${current.barberId}`);
        for (const [lockId, owner] of [...(locks?.entries() ?? [])]) if (owner === id) locks!.delete(lockId);
      }
      for (const n of write.notices) w.notices.set(`${n.uid}/${n.id}`, n.doc);
      return true;
    },
    async anonymizeReview(shopId, bookingId, uid) {
      const r = w.reviews.get(`${shopId}/${bookingId}`);
      if (!r || r.customerId !== uid) return false;
      if (r.customerName === 'Former customer' && !('comment' in r)) return false;
      const { comment: _comment, ...rest } = r;
      w.reviews.set(`${shopId}/${bookingId}`, { ...rest, customerName: 'Former customer' });
      return true;
    },
    async otherProfilesOfBarber(shopId, barberId, uid) {
      return w.profiles.filter((p) => p.uid !== uid && p.shopId === shopId && p.barberId === barberId).length;
    },
    async deleteBarberTree(shopId, barberId) {
      w.barberTrees.delete(`${shopId}/${barberId}`);
      w.locks.delete(`${shopId}/${barberId}`);
    },
    async deletePortfolioFiles(shopId, barberId) {
      const n = w.portfolioFiles.get(`${shopId}/${barberId}`) ?? 0;
      w.portfolioFiles.delete(`${shopId}/${barberId}`);
      return n;
    },
    async deletePersonalData(uid, email) {
      w.personal.push(`${uid}:${email ?? ''}`);
    },
  };
}

test('a deleted customer: open bookings cancelled with refund flags, the rest anonymised, reviews too', async () => {
  const w = world();
  const result = await cleanupDeletedAccount('gone', { role: 'customer', email: ' Gone@X.et ' }, storeOf(w), NOW);

  // Inside the cutoff, paid: late customer cancel = 50 %, contact kept for the refund.
  const soonPaid = w.bookings.get('soonPaid')!;
  assert.equal(soonPaid.status, 'cancelled');
  assert.equal(soonPaid.cancelledBy, 'system');
  assert.equal(soonPaid.cancelReason, 'account_deleted');
  assert.equal(soonPaid.refundStatus, 'due');
  assert.equal(soonPaid.refundAmount, 150);
  assert.equal(soonPaid.refundReason, 'customer_late_cancel');
  assert.equal(soonPaid.refundFlaggedAt, NOW.toISOString());
  assert.equal(soonPaid.customerPhone, '+251911000111');

  // Unpaid: cancelled and anonymised in the same write.
  const soonUnpaid = w.bookings.get('soonUnpaid')!;
  assert.equal(soonUnpaid.status, 'cancelled');
  assert.equal(soonUnpaid.refundStatus, undefined);
  assert.equal(soonUnpaid.customerName, 'Former customer');
  assert.equal(soonUnpaid.customerPhone, '');

  // Before the cutoff, paid: full refund.
  const laterPaid = w.bookings.get('laterPaid')!;
  assert.equal(laterPaid.refundAmount, 300);
  assert.equal(laterPaid.refundReason, 'customer_cancelled');

  // Their own slot locks are released; another customer's stay.
  assert.deepEqual([...w.locks.get('s1/x1')!.keys()], ['20261121-1300']);
  assert.equal(w.locks.get('s2/y1')!.size, 0);

  // History anonymised, except a refund still due.
  assert.equal(w.bookings.get('past')!.customerName, 'Former customer');
  assert.equal(w.bookings.get('past')!.status, 'completed');
  assert.equal(w.bookings.get('due')!.customerName, 'Abebe Kebede');
  assert.equal(w.bookings.get('otherCust')!.status, 'confirmed');

  assert.deepEqual(w.reviews.get('s1/past'), { customerId: 'gone', customerName: 'Former customer', rating: 4, reply: 'Thanks' });

  assert.deepEqual(result, {
    cancelledOwn: 3,
    refundsFlagged: 2,
    anonymizedBookings: 1,
    anonymizedReviews: 1,
    cancelledForBarber: 0,
    barberRemoved: false,
    portfolioFiles: 0,
  });
  assert.equal(w.notices.size, 0); // the deleted person has no inbox any more
  assert.deepEqual(w.personal, ['gone:gone@x.et']);
  assert.ok(w.barberTrees.has('s1/x1'));
});

test('is idempotent: after the app did its part (or a second run) nothing more changes', async () => {
  const w = world();
  await cleanupDeletedAccount('gone', { role: 'customer' }, storeOf(w), NOW);
  const writes = w.writes;
  const again = await cleanupDeletedAccount('gone', { role: 'customer' }, storeOf(w), NOW);
  assert.equal(w.writes, writes);
  assert.equal(again.cancelledOwn + again.anonymizedBookings + again.anonymizedReviews + again.refundsFlagged, 0);
  assert.deepEqual(w.personal, ['gone:', 'gone:']);
});

test('a booking cancelled meanwhile (re-read in the transaction) is not cancelled again', async () => {
  const w = world();
  const store = storeOf(w);
  const inner = store.updateBooking.bind(store);
  store.updateBooking = (id, plan) =>
    inner(id, (current) => plan(current && id === 'soonPaid' ? { ...current, status: 'cancelled', refundStatus: 'due' } : current));
  await cleanupDeletedAccount('gone', { role: 'customer' }, store, NOW);
  assert.equal(w.bookings.get('soonPaid')!.status, 'confirmed');
  assert.equal(w.bookings.get('soonPaid')!.refundStatus, undefined);
});

test('a deleted barber: customers notified and refunded, the barber tree and portfolio files removed', async () => {
  const w = world();
  w.bookings.set('cust3', b('cust3', { customerId: 'c3', startAt: '2026-11-22T07:30:00.000Z', paymentStatus: 'paid' }));
  w.bookings.set('oldX1', b('oldX1', { customerId: 'c3', startAt: '2026-11-19T07:30:00.000Z' }));
  const result = await cleanupDeletedAccount('barberUid', { role: 'barber', shopId: 's1', barberId: 'x1' }, storeOf(w), NOW);

  // Every customer's upcoming booking with x1 is cancelled with a notice.
  assert.equal(w.bookings.get('otherCust')!.status, 'cancelled');
  assert.equal(w.bookings.get('otherCust')!.cancelReason, 'account_deleted');
  assert.equal(w.bookings.get('otherCust')!.refundStatus, undefined); // unpaid
  const left = w.notices.get('c2/otherCust_cancelled')!;
  assert.equal(left.type, 'cancelled');
  assert.equal(left.title, 'Booking cancelled');
  assert.equal(left.body, 'Dawit no longer works at Crown Cuts, so your appointment was cancelled. Please book another time.');

  const cust3 = w.bookings.get('cust3')!;
  assert.equal(cust3.refundStatus, 'due');
  assert.equal(cust3.refundAmount, 300); // the shop side cancelled: full price
  assert.equal(cust3.refundReason, 'barber_cancelled');
  assert.equal(w.notices.get('c3/cust3_refundDue')!.title, 'ተመላሽ ገንዘብ አለዎት');
  assert.match(w.notices.get('c3/cust3_refundDue')!.body, /22\/11\/2026 10:30/);
  assert.equal(w.bookings.get('oldX1')!.status, 'confirmed'); // started already

  assert.ok(!w.barberTrees.has('s1/x1'));
  assert.ok(w.barberTrees.has('s1/x2'));
  assert.equal(result.barberRemoved, true);
  assert.equal(result.portfolioFiles, 3);
  assert.ok(result.cancelledForBarber >= 2);
});

test('a barber profile still linked to another account is left alone', async () => {
  const w = world();
  w.profiles.push({ uid: 'newOwnerOfX1', shopId: 's1', barberId: 'x1' });
  const result = await cleanupDeletedAccount('barberUid', { role: 'barber', shopId: 's1', barberId: 'x1' }, storeOf(w), NOW);
  assert.equal(result.barberRemoved, false);
  assert.ok(w.barberTrees.has('s1/x1'));
  assert.equal(w.bookings.get('otherCust')!.status, 'confirmed');
});

test('helpers match the app', () => {
  assert.deepEqual(barberOf({ role: 'barber', shopId: 's1', barberId: 'x1' }), { shopId: 's1', barberId: 'x1' });
  assert.equal(barberOf({ role: 'barber', shopId: '', barberId: 'x1' }), null);
  assert.equal(barberOf({ role: 'customer', shopId: 's1', barberId: 'x1' }), null);
  assert.equal(barberOf(null), null);

  const soon = b('s', { startAt: '2026-11-20T10:00:00.000Z' });
  assert.equal(isLateCustomerCancel(soon, 2, NOW), true);
  assert.equal(isLateCustomerCancel(soon, 0, NOW), false);
  assert.equal(isLateCustomerCancel(soon, null, NOW), false); // unknown shop: on time
  assert.equal(refundAmountFor(333.33, 'customer_late_cancel'), 166.67);
  assert.equal(refundAmountFor(0, 'customer_cancelled'), 0);

  assert.equal(keepsContact(b('k', { paymentStatus: 'paid' })), true);
  assert.equal(keepsContact(b('k', { paymentStatus: 'paid', status: 'completed' })), false);
  assert.equal(keepsContact(b('k', { status: 'cancelled', refundStatus: 'due' })), true);
  assert.equal(keepsContact(b('k', { status: 'cancelled', refundStatus: 'refunded', paymentStatus: 'refunded' })), false);

  // Not the person's, or already started: nothing.
  assert.equal(planOwnCancel(b('o', { customerId: 'c2', startAt: '2026-11-21T10:00:00.000Z' }), 'gone', 2, NOW), null);
  assert.equal(planOwnCancel(b('o', { startAt: '2026-11-20T08:00:00.000Z' }), 'gone', 2, NOW), null);
  assert.equal(planOwnCancel(null, 'gone', 2, NOW), null);

  assert.deepEqual(barberLeftText(b('t', { barberName: ' ', shopName: '' })), {
    title: 'ቀጠሮዎ ተሰርዟል',
    body: 'ፀጉር አስተካካዩ ከCrown & Blade ስለለቀቁ ቀጠሮዎ ተሰርዟል። እባክዎ ሌላ ጊዜ ይያዙ።',
  });
  assert.equal(
    refundDueText(b('t', { startAt: '2026-11-21T07:30:00.000Z' }), 300, 'en').body,
    'Your paid appointment on 21/11/2026 10:30 was cancelled. Crown Cuts owes you a refund of ETB 300.00.',
  );
});
