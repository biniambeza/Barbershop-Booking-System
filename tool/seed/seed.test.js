'use strict';
// node --test (no Firebase needed): checks the seed resolves like lib/data/seed_dataset.dart.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments, formatTimeSlot, emailOf } = require('./seed.js');
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
  assert.deepStrictEqual(get(docs, 'invites/barber1.shop1@example.com'), {
    email: 'barber1.shop1@example.com',
    role: 'barber',
    name: 'Yonas Tadesse',
    createdBy: 'seed',
    createdAt: '2026-08-27T07:00:00.000Z',
    shopId: 'shop_1',
    barberId: 'barber_1',
  });
  assert.strictEqual(get(docs, 'invites/liya@example.com'), undefined); // customers need no invite
  assert.ok(!docs.some((d) => d.path.startsWith('invites/+')), 'no phone-keyed invites');
  // Every invite id is its lowercased email field.
  const invites = docs.filter((d) => d.path.startsWith('invites/'));
  assert.strictEqual(invites.length, 9); // admin, 6 owners, 2 barbers
  for (const d of invites) {
    assert.strictEqual(d.path, `invites/${d.data.email}`);
    assert.strictEqual(d.data.email, d.data.email.toLowerCase());
    assert.strictEqual(d.data.phone, undefined);
  }
  assert.strictEqual(get(docs, 'invites/admin@example.com').role, 'admin');
});

test('users mode gives every user a lowercased email and keeps the phone', () => {
  const docs = buildDocuments(seed, { now });
  const users = docs.filter((d) => d.path.startsWith('users/'));
  assert.strictEqual(users.length, seed.users.length);
  for (const { data } of users) {
    assert.match(data.email, /^[a-z0-9._%+-]+@example\.com$/);
    assert.match(data.phone, /^\+251[79]\d{8}$/);
  }
  assert.strictEqual(get(docs, 'users/owner_1').email, 'owner.shop1@example.com');
  assert.strictEqual(get(docs, 'users/owner_1').phone, '+251911000101');
  // Emails are unique (one Google account per person).
  assert.strictEqual(new Set(users.map((d) => d.data.email)).size, users.length);
});

test('emailOf lowercases and rejects missing emails', () => {
  assert.strictEqual(emailOf({ uid: 'x', email: ' Owner.Shop1@Example.COM ' }), 'owner.shop1@example.com');
  assert.throws(() => emailOf({ uid: 'x' }), /valid email/);
  assert.throws(() => emailOf({ uid: 'x', email: '+251911000001' }), /valid email/);
  const noEmail = { ...seed, users: seed.users.map((u, i) => (i === 0 ? { ...u, email: undefined } : u)) };
  assert.throws(() => buildDocuments(noEmail, { now, mode: 'invites' }), /valid email/);
});

test('active bookings get slot locks like the app writes them', () => {
  const docs = buildDocuments(seed, { now });
  const locks = docs.filter((d) => d.path.includes('/slotLocks/'));
  // book_2: barber_1, 14:15-14:45 Addis on 2026-11-20 (30 min) -> two 15-minute blocks.
  assert.deepStrictEqual(get(docs, 'barbershops/shop_1/barbers/barber_1/slotLocks/20261120-1415'), {
    bookingId: 'book_2',
    startAt: '2026-11-20T11:15:00.000Z',
    // book_2 ends 14:45 Addis (11:45Z); locks expire a day later.
    expiresAt: '2026-11-21T11:45:00.000Z',
  });
  // No customer data in any lock, and every booking lock expires a day after its booking ends.
  for (const lock of locks.filter((d) => !('timeOffId' in d.data))) {
    assert.deepStrictEqual(Object.keys(lock.data).sort(), ['bookingId', 'expiresAt', 'startAt']);
    const bk = get(docs, `bookings/${lock.data.bookingId}`);
    assert.strictEqual(Date.parse(lock.data.expiresAt), Date.parse(bk.endAt) + 24 * 3600 * 1000);
  }
  assert.ok(get(docs, 'barbershops/shop_1/barbers/barber_1/slotLocks/20261120-1430'));
  assert.strictEqual(get(docs, 'barbershops/shop_1/barbers/barber_1/slotLocks/20261120-1445'), undefined);
  // Completed bookings keep their locks; cancelled ones (book_7) have none.
  assert.ok(!locks.some((d) => d.data.bookingId === 'book_7'));
  // invites mode writes no bookings, so no locks.
  assert.ok(!buildDocuments(seed, { now, mode: 'invites' }).some((d) => d.path.includes('/slotLocks/')));
});

test('every seeded service fits the rules cap of 120 minutes', () => {
  for (const shop of seed.shops) {
    for (const service of shop.services || []) {
      assert.ok(service.durationMinutes >= 5 && service.durationMinutes <= 120, `${service.id}: ${service.durationMinutes}`);
    }
  }
});

test('seeded time off gets a time-off doc and one lock per 15-minute block', () => {
  const docs = buildDocuments(seed, { now });
  // timeoff_1: barber_2, tomorrow (2026-11-21) 13:00-15:00 Addis = 10:00-12:00Z.
  assert.deepStrictEqual(get(docs, 'barbershops/shop_1/barbers/barber_2/timeOff/timeoff_1'), {
    startAt: '2026-11-21T10:00:00.000Z',
    endAt: '2026-11-21T12:00:00.000Z',
    reason: 'Family event',
    createdBy: 'owner_1',
    createdAt: '2026-11-20T01:00:00.000Z',
  });
  const locks = docs.filter((d) => d.path.startsWith('barbershops/shop_1/barbers/barber_2/slotLocks/') && d.data.timeOffId);
  assert.deepStrictEqual(locks.map((d) => d.path.split('/').pop()), [
    '20261121-1300', '20261121-1315', '20261121-1330', '20261121-1345',
    '20261121-1400', '20261121-1415', '20261121-1430', '20261121-1445',
  ]);
  assert.deepStrictEqual(locks[0].data, {
    timeOffId: 'timeoff_1',
    startAt: '2026-11-21T10:00:00.000Z',
    expiresAt: '2026-11-22T12:00:00.000Z',
  });
  // No lock id is written twice (time off never overlaps a seeded booking).
  const lockPaths = docs.filter((d) => d.path.includes('/slotLocks/')).map((d) => d.path);
  assert.strictEqual(new Set(lockPaths).size, lockPaths.length);
  // Shop booking policy.
  assert.strictEqual(get(docs, 'barbershops/shop_1').cancellationCutoffHours, 2);
  assert.strictEqual(get(docs, 'barbershops/shop_2').maxReschedules, 1);
  // invites mode writes no time off.
  assert.ok(!buildDocuments(seed, { now, mode: 'invites' }).some((d) => d.path.includes('/timeOff/')));
});
