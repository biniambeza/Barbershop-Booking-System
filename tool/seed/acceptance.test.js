'use strict';
// Barber acceptance seed: shop_2 requires barbers to accept each booking and
// has one pending request (book_21) that still holds its slot locks.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0)); // 10:00 in Addis
const get = (docs, p) => docs.find((d) => d.path === p)?.data;

test('shop_2 requires barber acceptance; other shops do not', () => {
  const docs = buildDocuments(seed, { now });
  assert.strictEqual(get(docs, 'barbershops/shop_2').requireBarberAcceptance, true);
  assert.strictEqual(get(docs, 'barbershops/shop_1').requireBarberAcceptance, undefined);
  // invites mode keeps the setting too
  const inv = buildDocuments(seed, { now, mode: 'invites' });
  assert.strictEqual(get(inv, 'barbershops/shop_2').requireBarberAcceptance, true);
});

test('book_21 is a pending request for a shop_2 barber holding its locks', () => {
  const docs = buildDocuments(seed, { now });
  const b = get(docs, 'bookings/book_21');
  assert.strictEqual(b.shopId, 'shop_2');
  assert.strictEqual(b.barberId, 'barber_2_2');
  assert.strictEqual(b.status, 'pending');
  assert.strictEqual(b.paymentStatus, 'unpaid');
  assert.strictEqual(b.acceptedAt, undefined);
  // 10:00 Addis two days later, 35-minute shave -> 3 blocks.
  assert.strictEqual(b.startAt, '2026-11-22T07:00:00.000Z');
  const locks = docs.filter(
    (d) => d.path.startsWith('barbershops/shop_2/barbers/barber_2_2/slotLocks/') && d.data.bookingId === 'book_21',
  );
  assert.deepStrictEqual(
    locks.map((l) => l.path.split('/').pop()),
    ['20261122-1000', '20261122-1015', '20261122-1030'],
  );
});
