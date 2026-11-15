'use strict';
// node --test: seeded barber payouts resolve like
// lib/features/payouts/payouts_manager.dart (payoutsFromSeedJson) and follow
// the payouts contract; seeded barbers carry a valid commissionPercent.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0)); // 10:00 in Addis, 20 Nov 2026
const payoutDocs = (docs) => docs.filter((d) => /^barbershops\/[^/]+\/payouts\/[^/]+$/.test(d.path));

test('payouts are written with the contract fields', () => {
  const docs = buildDocuments(seed, { now });
  const payouts = payoutDocs(docs);
  assert.strictEqual(payouts.length, seed.payouts.length);
  assert.ok(payouts.length >= 2);
  const allowed = ['barberId', 'amount', 'periodStart', 'periodEnd', 'method', 'note', 'createdBy', 'createdAt'];
  for (const p of payouts) {
    const [, shopId] = p.path.split('/');
    const shop = seed.shops.find((s) => s.id === shopId);
    assert.ok(shop.barbers.some((b) => b.id === p.data.barberId), p.path);
    assert.strictEqual(p.data.createdBy, shop.ownerId, p.path);
    assert.ok(typeof p.data.amount === 'number' && p.data.amount > 0 && p.data.amount <= 1000000, p.path);
    assert.ok(['cash', 'telebirr', 'bank', 'other'].includes(p.data.method), p.path);
    assert.match(p.data.periodStart, /^\d{4}-\d{2}-\d{2}T00:00:00\.000Z$/);
    assert.match(p.data.periodEnd, /^\d{4}-\d{2}-\d{2}T00:00:00\.000Z$/);
    assert.ok(p.data.periodStart <= p.data.periodEnd, p.path);
    if ('note' in p.data) assert.ok(p.data.note.length >= 1 && p.data.note.length <= 200, p.path);
    assert.ok(Date.parse(p.data.createdAt) <= now.getTime(), p.path);
    assert.ok(Object.keys(p.data).every((k) => allowed.includes(k)), p.path);
  }
  const first = docs.find((d) => d.path === 'barbershops/shop_1/payouts/payout_seed_1').data;
  assert.strictEqual(first.periodStart, '2026-11-01T00:00:00.000Z');
  assert.strictEqual(first.periodEnd, '2026-11-30T00:00:00.000Z');
  assert.strictEqual(first.createdAt, '2026-11-19T01:00:00.000Z'); // 30 hours earlier
});

test('the Addis month is used near a month boundary', () => {
  // 31 Dec 2026 22:30 UTC = 1 Jan 2027 01:30 in Addis.
  const docs = buildDocuments(seed, { now: new Date(Date.UTC(2026, 11, 31, 22, 30)) });
  const first = docs.find((d) => d.path === 'barbershops/shop_1/payouts/payout_seed_1').data;
  assert.strictEqual(first.periodStart, '2027-01-01T00:00:00.000Z');
  assert.strictEqual(first.periodEnd, '2027-01-31T00:00:00.000Z');
});

test('seeded barbers have a whole commissionPercent 0..100 when set', () => {
  const docs = buildDocuments(seed, { now });
  const barbers = docs.filter((d) => /^barbershops\/[^/]+\/barbers\/[^/]+$/.test(d.path));
  const withCommission = barbers.filter((b) => 'commissionPercent' in b.data);
  assert.ok(withCommission.length >= 3);
  for (const b of withCommission) {
    const p = b.data.commissionPercent;
    assert.ok(Number.isInteger(p) && p >= 0 && p <= 100, b.path);
  }
});

test('invites mode writes no payouts', () => {
  assert.strictEqual(payoutDocs(buildDocuments(seed, { now, mode: 'invites' })).length, 0);
});
