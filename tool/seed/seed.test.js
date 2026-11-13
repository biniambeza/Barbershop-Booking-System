'use strict';
// node --test (no Firebase needed): checks the seed resolves like lib/data/seed_dataset.dart.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments, formatTimeSlot } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0)); // 10:00 in Addis
const get = (docs, p) => docs.find((d) => d.path === p)?.data;

test('formats time slots like the app', () => {
  assert.strictEqual(formatTimeSlot(14, 15), '02:15 PM');
  assert.strictEqual(formatTimeSlot(0, 5), '12:05 AM');
  assert.strictEqual(formatTimeSlot(12, 0), '12:00 PM');
});

test('users mode resolves bookings in Addis time', () => {
  const docs = buildDocuments(seed, { now });
  const b2 = get(docs, 'bookings/book_2');
  assert.strictEqual(b2.startAt, '2026-11-20T11:15:00.000Z');
  assert.strictEqual(b2.endAt, '2026-11-20T11:45:00.000Z');
  assert.strictEqual(b2.date, '2026-11-20T00:00:00.000');
  assert.strictEqual(b2.timeSlot, '02:15 PM');
  assert.strictEqual(b2.price, 300);
  assert.strictEqual(b2.customerName, 'Natnael Assefa');
  assert.strictEqual(get(docs, 'bookings/book_1').startAt, '2026-11-21T08:15:00.000Z');
  assert.strictEqual(get(docs, 'users/owner_1').shopId, 'shop_1');
  assert.strictEqual(get(docs, 'barbershops/shop_1').subscriptionEndsAt, '2026-12-15T07:00:00.000Z');
  assert.strictEqual(get(docs, 'barbershops/shop_1').services, undefined);
  assert.strictEqual(get(docs, 'barbershops/shop_1/barbers/barber_1').shopId, 'shop_1');
  assert.strictEqual(get(docs, 'plans/pro').priceMonthlyEtb, 1200);
});

test('invites mode writes no fake accounts or bookings', () => {
  const docs = buildDocuments(seed, { now, mode: 'invites' });
  assert.ok(!docs.some((d) => d.path.startsWith('users/') || d.path.startsWith('bookings/')));
  assert.strictEqual(get(docs, 'barbershops/shop_1').ownerId, '');
  assert.deepStrictEqual(get(docs, 'invites/+251911000201'), {
    phone: '+251911000201',
    role: 'barber',
    name: 'Yonas Tadesse',
    createdBy: 'seed',
    createdAt: '2026-08-27T07:00:00.000Z',
    shopId: 'shop_1',
    barberId: 'barber_1',
  });
  assert.strictEqual(get(docs, 'invites/+251911000301'), undefined); // customers need no invite
});

test('active bookings get slot locks like the app writes them', () => {
  const docs = buildDocuments(seed, { now });
  const locks = docs.filter((d) => d.path.includes('/slotLocks/'));
  // book_2: barber_1, 14:15-14:45 Addis on 2026-11-20 (30 min) -> two 15-minute blocks.
  assert.deepStrictEqual(get(docs, 'barbershops/shop_1/barbers/barber_1/slotLocks/20261120-1415'), {
    bookingId: 'book_2',
    customerId: 'user_cust_2',
    startAt: '2026-11-20T11:15:00.000Z',
  });
  assert.ok(get(docs, 'barbershops/shop_1/barbers/barber_1/slotLocks/20261120-1430'));
  assert.strictEqual(get(docs, 'barbershops/shop_1/barbers/barber_1/slotLocks/20261120-1445'), undefined);
  // Completed bookings keep their locks; cancelled ones (book_7) have none.
  assert.ok(!locks.some((d) => d.data.bookingId === 'book_7'));
  // invites mode writes no bookings, so no locks.
  assert.ok(!buildDocuments(seed, { now, mode: 'invites' }).some((d) => d.path.includes('/slotLocks/')));
});
