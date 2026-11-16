'use strict';
// node --test: seeded subscription pricing and receipts resolve like
// lib/features/payments/receipts/subscription_receipts_service.dart
// (subscriptionPricingFromSeedJson / subscriptionPaymentsFromSeedJson) and
// follow the subscriptionPayments contract.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0));
const receiptDocs = (docs) => docs.filter((d) => /^subscriptionPayments\/[^/]+$/.test(d.path));

test('pricing config is written in both modes with the contract keys', () => {
  for (const mode of ['users', 'invites']) {
    const docs = buildDocuments(seed, { now, mode });
    const pricing = docs.find((d) => d.path === 'platformConfig/subscriptionPricing');
    assert.ok(pricing, mode);
    assert.deepStrictEqual(Object.keys(pricing.data).sort(), ['currency', 'receivers', 'tiers', 'updatedAt', 'updatedBy']);
    assert.strictEqual(pricing.data.currency, 'ETB');
    assert.deepStrictEqual(pricing.data.tiers, [
      { days: 30, amount: 500 },
      { days: 90, amount: 1400 },
      { days: 180, amount: 2700 },
      { days: 365, amount: 5000 },
    ]);
    assert.ok(pricing.data.receivers.telebirr.number && pricing.data.receivers.telebirr.name);
    assert.ok(pricing.data.receivers.cbe.account && pricing.data.receivers.cbe.name);
    assert.strictEqual(pricing.data.updatedAt, now.toISOString());
  }
});

test('receipts are written with the contract fields (users mode)', () => {
  const docs = buildDocuments(seed, { now });
  const receipts = receiptDocs(docs);
  assert.strictEqual(receipts.length, seed.subscriptionPayments.filter((p) => p.transactionId).length);
  const allowed = [
    'shopId', 'ownerId', 'method', 'transactionId', 'amount', 'status', 'durationDays', 'createdAt',
    'verifiedAmount', 'verifiedBy', 'decisionReason', 'decidedAt', 'payerAccountSuffix', 'receiptImage',
  ];
  for (const r of receipts) {
    const shop = seed.shops.find((s) => s.id === r.data.shopId);
    assert.ok(shop, r.path);
    assert.strictEqual(r.data.ownerId, shop.ownerId, r.path);
    assert.ok(['telebirr', 'cbe', 'other'].includes(r.data.method), r.path);
    assert.strictEqual(r.path, `subscriptionPayments/${r.data.method}_${r.data.transactionId}`);
    assert.match(r.data.transactionId, /^[A-Z0-9-]+$/);
    assert.ok(['pending', 'verified', 'rejected', 'needs_review'].includes(r.data.status), r.path);
    assert.ok(Number.isInteger(r.data.durationDays), r.path);
    assert.ok(Object.keys(r.data).every((k) => allowed.includes(k)), r.path);
    if (r.data.status === 'pending') {
      assert.strictEqual(r.data.durationDays, 0);
      assert.ok(!('decidedAt' in r.data));
    }
  }
  const verified = docs.find((d) => d.path === 'subscriptionPayments/cbe_FT26300ABC12').data;
  assert.strictEqual(verified.status, 'verified');
  assert.strictEqual(verified.durationDays, 90);
  assert.strictEqual(verified.ownerId, 'owner_2');
  assert.strictEqual(verified.createdAt, '2026-11-10T07:00:00.000Z'); // 240 h earlier
  assert.strictEqual(verified.decidedAt, '2026-11-10T11:00:00.000Z'); // 236 h earlier
  const pending = docs.find((d) => d.path === 'subscriptionPayments/telebirr_CHK7QX2M9P').data;
  assert.strictEqual(pending.status, 'pending');
  assert.strictEqual(pending.ownerId, 'owner_5');
});

test('invites mode writes no receipts', () => {
  assert.strictEqual(receiptDocs(buildDocuments(seed, { now, mode: 'invites' })).length, 0);
});
