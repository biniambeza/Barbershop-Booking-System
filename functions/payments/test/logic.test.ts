import { test } from 'node:test';
import assert from 'node:assert/strict';

import { amountsMatch, normalizeAmount, toChapaAmount } from '../src/logic/money';
import { addMonthsUtc, extendSubscriptionEnd, initialTrialEnd } from '../src/logic/period';
import {
  buildManualChange,
  computeScheduledUpdate,
  paidSubscriptionPatch,
  statusForEnd,
} from '../src/logic/subscription';
import { hmacSha256Hex, verifyChapaSignature } from '../src/logic/signature';
import { evaluateVerification, mapChapaStatus } from '../src/logic/verification';
import {
  appendQuery,
  buildTxRef,
  firstNameOf,
  paymentIdFromTxRef,
  sanitizeCheckoutText,
  toChapaEmail,
  toChapaPhone,
} from '../src/logic/checkout';
import { checkBookingPayable, checkPlanFitsShop, checkShopOwner } from '../src/logic/eligibility';
import { CHECKOUT_TITLE, DEFAULT_PLANS } from '../src/config';

const NOW = new Date('2026-11-13T09:00:00.000Z');

// ------------------------------------------------------------- money
test('normalizeAmount rejects bad values and rounds to cents', () => {
  assert.equal(normalizeAmount(450), 450);
  assert.equal(normalizeAmount('450.004'), 450);
  assert.equal(normalizeAmount(0), null);
  assert.equal(normalizeAmount(-5), null);
  assert.equal(normalizeAmount(NaN), null);
  assert.equal(normalizeAmount('abc'), null);
  assert.equal(normalizeAmount(''), null);
  assert.equal(normalizeAmount(null), null);
  assert.equal(normalizeAmount(2_000_000), null);
});

test('toChapaAmount formats two decimals', () => {
  assert.equal(toChapaAmount(500), '500.00');
  assert.equal(toChapaAmount(99.5), '99.50');
  assert.throws(() => toChapaAmount(0));
});

test('amountsMatch compares to the cent', () => {
  assert.ok(amountsMatch(500, '500.00'));
  assert.ok(amountsMatch(500, 500));
  assert.ok(!amountsMatch(500, '499.99'));
  assert.ok(!amountsMatch(500, '5'));
  assert.ok(!amountsMatch(500, undefined));
});

// ------------------------------------------------------------- period
test('addMonthsUtc clamps month ends', () => {
  assert.equal(addMonthsUtc(new Date('2026-01-31T10:00:00Z'), 1).toISOString(), '2026-02-28T10:00:00.000Z');
  assert.equal(addMonthsUtc(new Date('2028-01-31T10:00:00Z'), 1).toISOString(), '2028-02-29T10:00:00.000Z');
  assert.equal(addMonthsUtc(new Date('2026-12-15T00:00:00Z'), 1).toISOString(), '2027-01-15T00:00:00.000Z');
  assert.equal(addMonthsUtc(new Date('2026-11-13T00:00:00Z'), 14).toISOString(), '2028-01-13T00:00:00.000Z');
});

test('extendSubscriptionEnd uses max(now, current end)', () => {
  assert.equal(extendSubscriptionEnd('2026-12-01T00:00:00Z', NOW).toISOString(), '2027-01-01T00:00:00.000Z');
  assert.equal(extendSubscriptionEnd('2026-10-01T00:00:00Z', NOW).toISOString(), '2026-12-13T09:00:00.000Z');
  assert.equal(extendSubscriptionEnd(undefined, NOW).toISOString(), '2026-12-13T09:00:00.000Z');
  assert.equal(extendSubscriptionEnd('garbage', NOW, 3).toISOString(), '2027-02-13T09:00:00.000Z');
});

test('initialTrialEnd: 30 days from creation, or from now when already passed', () => {
  assert.equal(initialTrialEnd('2026-11-01T00:00:00Z', NOW, 30).toISOString(), '2026-12-01T00:00:00.000Z');
  assert.equal(initialTrialEnd('2026-01-01T00:00:00Z', NOW, 30).toISOString(), '2026-12-13T09:00:00.000Z');
  assert.equal(initialTrialEnd(undefined, NOW, 30).toISOString(), '2026-12-13T09:00:00.000Z');
});

// ------------------------------------------------------------- subscription
test('statusForEnd transitions', () => {
  const end = new Date('2026-11-10T00:00:00Z');
  assert.equal(statusForEnd('active', end, NOW), 'past_due');
  assert.equal(statusForEnd('trialing', end, NOW), 'past_due');
  assert.equal(statusForEnd('past_due', end, NOW), 'past_due');
  assert.equal(statusForEnd('past_due', new Date('2026-11-06T09:00:00Z'), NOW), 'suspended');
  assert.equal(statusForEnd('active', new Date('2026-11-01T00:00:00Z'), NOW), 'suspended');
  assert.equal(statusForEnd('active', new Date('2026-12-01T00:00:00Z'), NOW), 'active');
  assert.equal(statusForEnd('past_due', new Date('2026-12-01T00:00:00Z'), NOW), 'active');
  assert.equal(statusForEnd('suspended', new Date('2026-12-01T00:00:00Z'), NOW), 'suspended');
});

test('computeScheduledUpdate starts trials for shops without fields', () => {
  assert.deepEqual(computeScheduledUpdate({ createdAt: '2026-11-01T00:00:00Z' }, NOW), {
    subscriptionPlan: 'trial',
    subscriptionStatus: 'trialing',
    subscriptionEndsAt: '2026-12-01T00:00:00.000Z',
  });
});

test('computeScheduledUpdate moves expired shops and leaves healthy ones', () => {
  assert.deepEqual(
    computeScheduledUpdate(
      { subscriptionPlan: 'basic', subscriptionStatus: 'active', subscriptionEndsAt: '2026-11-12T00:00:00Z' },
      NOW,
    ),
    { subscriptionStatus: 'past_due' },
  );
  assert.deepEqual(
    computeScheduledUpdate(
      { subscriptionPlan: 'basic', subscriptionStatus: 'past_due', subscriptionEndsAt: '2026-11-05T00:00:00Z' },
      NOW,
    ),
    { subscriptionStatus: 'suspended' },
  );
  assert.equal(
    computeScheduledUpdate(
      { subscriptionPlan: 'pro', subscriptionStatus: 'active', subscriptionEndsAt: '2026-12-12T00:00:00Z' },
      NOW,
    ),
    null,
  );
  assert.equal(
    computeScheduledUpdate({ subscriptionPlan: 'pro', subscriptionStatus: 'active', subscriptionEndsAt: 'bad' }, NOW),
    null,
  );
  assert.equal(
    computeScheduledUpdate(
      { subscriptionPlan: 'basic', subscriptionStatus: 'suspended', subscriptionEndsAt: '2026-01-01T00:00:00Z' },
      NOW,
    ),
    null,
  );
});

test('paidSubscriptionPatch activates and extends', () => {
  assert.deepEqual(paidSubscriptionPatch('pro', '2026-11-20T00:00:00Z', NOW), {
    subscriptionPlan: 'pro',
    subscriptionStatus: 'active',
    subscriptionEndsAt: '2026-12-20T00:00:00.000Z',
  });
  assert.equal(paidSubscriptionPatch('basic', '2026-01-01T00:00:00Z', NOW).subscriptionEndsAt, '2026-12-13T09:00:00.000Z');
});

test('buildManualChange validates admin input', () => {
  assert.deepEqual(buildManualChange({ status: 'suspended' }, {}, NOW), { patch: { subscriptionStatus: 'suspended' } });
  assert.deepEqual(buildManualChange({ plan: 'basic', months: 2 }, { subscriptionEndsAt: '2026-12-01T00:00:00Z' }, NOW), {
    patch: { subscriptionPlan: 'basic', subscriptionEndsAt: '2027-02-01T00:00:00.000Z', subscriptionStatus: 'active' },
  });
  assert.deepEqual(buildManualChange({ endsAt: '2027-01-01T00:00:00+03:00' }, {}, NOW), {
    patch: { subscriptionEndsAt: '2026-12-31T21:00:00.000Z' },
  });
  assert.ok('error' in buildManualChange({}, {}, NOW));
  assert.ok('error' in buildManualChange({ plan: 'gold' }, {}, NOW));
  assert.ok('error' in buildManualChange({ status: 'paid' }, {}, NOW));
  assert.ok('error' in buildManualChange({ endsAt: 'tomorrow' }, {}, NOW));
  assert.ok('error' in buildManualChange({ months: 0 }, {}, NOW));
  assert.ok('error' in buildManualChange({ months: 1.5 }, {}, NOW));
  assert.ok('error' in buildManualChange({ months: 1, endsAt: '2027-01-01T00:00:00Z' }, {}, NOW));
});

// ------------------------------------------------------------- signature
test('verifyChapaSignature accepts payload HMAC over raw body or JSON', () => {
  const secret = 'whsec';
  const body = { event: 'charge.success', tx_ref: 'cb-abc', status: 'success' };
  const raw = Buffer.from(JSON.stringify(body, null, 2));
  assert.deepEqual(
    verifyChapaSignature({ secret, rawBody: raw, parsedBody: body, xChapaSignature: hmacSha256Hex(secret, raw) }),
    { valid: true, payloadBound: true },
  );
  assert.deepEqual(
    verifyChapaSignature({
      secret,
      rawBody: raw,
      parsedBody: body,
      xChapaSignature: hmacSha256Hex(secret, JSON.stringify(body)).toUpperCase(),
    }),
    { valid: true, payloadBound: true },
  );
});

test('verifyChapaSignature accepts chapa-signature = HMAC(secret, secret) as non payload-bound', () => {
  const secret = 'whsec';
  assert.deepEqual(verifyChapaSignature({ secret, chapaSignature: hmacSha256Hex(secret, secret) }), {
    valid: true,
    payloadBound: false,
  });
});

test('verifyChapaSignature rejects missing, wrong and tampered signatures', () => {
  const secret = 'whsec';
  const body = { tx_ref: 'cb-abc' };
  const sig = hmacSha256Hex(secret, JSON.stringify(body));
  assert.equal(verifyChapaSignature({ secret, parsedBody: body }).valid, false);
  assert.equal(verifyChapaSignature({ secret, parsedBody: body, xChapaSignature: 'deadbeef' }).valid, false);
  assert.equal(verifyChapaSignature({ secret, parsedBody: { tx_ref: 'cb-xyz' }, xChapaSignature: sig }).valid, false);
  assert.equal(verifyChapaSignature({ secret: 'other', parsedBody: body, xChapaSignature: sig }).valid, false);
  assert.equal(verifyChapaSignature({ secret: '', parsedBody: body, xChapaSignature: sig }).valid, false);
  assert.equal(verifyChapaSignature({ secret, chapaSignature: hmacSha256Hex('other', 'other') }).valid, false);
});

// ------------------------------------------------------------- verification
test('mapChapaStatus', () => {
  assert.equal(mapChapaStatus('success'), 'success');
  assert.equal(mapChapaStatus('SUCCESS'), 'success');
  assert.equal(mapChapaStatus('failed'), 'failed');
  assert.equal(mapChapaStatus('cancelled'), 'failed');
  assert.equal(mapChapaStatus('pending'), 'pending');
  assert.equal(mapChapaStatus(undefined), 'pending');
});

test('evaluateVerification requires matching tx_ref, currency and amount', () => {
  const expected = { amount: 450, currency: 'ETB', txRef: 'cb-1' };
  assert.deepEqual(evaluateVerification(expected, null), { outcome: 'pending' });
  assert.deepEqual(evaluateVerification(expected, { status: 'pending' }), { outcome: 'pending' });
  assert.deepEqual(
    evaluateVerification(expected, { status: 'success', amount: '450.00', currency: 'ETB', tx_ref: 'cb-1' }),
    { outcome: 'success' },
  );
  assert.deepEqual(
    evaluateVerification(expected, { status: 'success', amount: '45.00', currency: 'ETB', tx_ref: 'cb-1' }),
    { outcome: 'failed', reason: 'amount_mismatch' },
  );
  assert.deepEqual(
    evaluateVerification(expected, { status: 'success', amount: 450, currency: 'USD', tx_ref: 'cb-1' }),
    { outcome: 'failed', reason: 'currency_mismatch' },
  );
  assert.deepEqual(
    evaluateVerification(expected, { status: 'success', amount: 450, currency: 'ETB', tx_ref: 'cb-2' }),
    { outcome: 'failed', reason: 'tx_ref_mismatch' },
  );
  assert.deepEqual(evaluateVerification(expected, { status: 'failed' }), {
    outcome: 'failed',
    reason: 'chapa_status_failed',
  });
});

// ------------------------------------------------------------- checkout helpers
test('tx_ref round trip', () => {
  assert.equal(buildTxRef('AbC123'), 'cb-AbC123');
  assert.equal(paymentIdFromTxRef('cb-AbC123'), 'AbC123');
  assert.equal(paymentIdFromTxRef('xx-AbC123'), null);
  assert.equal(paymentIdFromTxRef('cb-../x'), null);
  assert.equal(paymentIdFromTxRef(42), null);
});

test('toChapaPhone converts Ethiopian numbers to local 10-digit form', () => {
  assert.equal(toChapaPhone('+251911234567'), '0911234567');
  assert.equal(toChapaPhone('+251 711 234 567'), '0711234567');
  assert.equal(toChapaPhone('0911234567'), '0911234567');
  assert.equal(toChapaPhone('+15551234567'), undefined);
  assert.equal(toChapaPhone('+251811234567'), undefined);
  assert.equal(toChapaPhone(undefined), undefined);
});

test('toChapaEmail passes the profile email, lowercased, or nothing', () => {
  assert.equal(toChapaEmail('Owner.Shop1@Example.com'), 'owner.shop1@example.com');
  assert.equal(toChapaEmail(' a@b.co '), 'a@b.co');
  assert.equal(toChapaEmail('not-an-email'), undefined);
  assert.equal(toChapaEmail(''), undefined);
  assert.equal(toChapaEmail(undefined), undefined);
  assert.equal(toChapaEmail(42), undefined);
});

test('checkout text is sanitized for Chapa', () => {
  assert.ok(CHECKOUT_TITLE.length <= 16);
  assert.equal(sanitizeCheckoutText('Fade & Beard @ Bole!', 50), 'Fade Beard Bole');
  assert.equal(sanitizeCheckoutText('ፀጉር ቤት Haircut', 50), 'Haircut');
  assert.equal(sanitizeCheckoutText('a'.repeat(80), 50).length, 50);
  assert.equal(firstNameOf('Abebe Kebede'), 'Abebe');
  assert.equal(firstNameOf('አበበ'), 'Customer');
  assert.equal(
    appendQuery('https://app.example/pay-return', { paymentId: 'p1', txRef: 'cb-p1' }),
    'https://app.example/pay-return?paymentId=p1&txRef=cb-p1',
  );
});

// ------------------------------------------------------------- eligibility
test('checkBookingPayable', () => {
  const b = { customerId: 'u1', status: 'confirmed', price: 450 };
  assert.equal(checkBookingPayable(b, 'u1'), null);
  assert.equal(checkBookingPayable({ ...b, paymentStatus: 'pending' }, 'u1'), null);
  assert.equal(checkBookingPayable(undefined, 'u1')?.code, 'not-found');
  assert.equal(checkBookingPayable(b, 'u2')?.code, 'permission-denied');
  assert.equal(checkBookingPayable({ ...b, status: 'cancelled' }, 'u1')?.code, 'failed-precondition');
  assert.equal(checkBookingPayable({ ...b, paymentStatus: 'paid' }, 'u1')?.code, 'already-exists');
  assert.equal(checkBookingPayable({ ...b, paymentStatus: 'refunded' }, 'u1')?.code, 'failed-precondition');
});

test('checkShopOwner', () => {
  const owner = { role: 'barbershopOwner', shopId: 's1' };
  assert.equal(checkShopOwner(owner, { ownerId: 'u1' }, 'u1', 's1'), null);
  assert.equal(checkShopOwner(owner, { ownerId: 'u1' }, 'u1', 's2')?.code, 'permission-denied');
  assert.equal(checkShopOwner({ role: 'customer', shopId: 's1' }, { ownerId: 'u1' }, 'u1', 's1')?.code, 'permission-denied');
  assert.equal(checkShopOwner(owner, { ownerId: 'other' }, 'u1', 's1')?.code, 'permission-denied');
  assert.equal(checkShopOwner(owner, undefined, 'u1', 's1')?.code, 'not-found');
  assert.equal(checkShopOwner(undefined, { ownerId: 'u1' }, 'u1', 's1')?.code, 'permission-denied');
});

test('checkPlanFitsShop and default plans', () => {
  assert.equal(checkPlanFitsShop(3, 3), null);
  assert.equal(checkPlanFitsShop(3, 4)?.code, 'failed-precondition');
  assert.equal(checkPlanFitsShop(-1, 50), null);
  assert.equal(DEFAULT_PLANS.basic.priceMonthlyEtb, 500);
  assert.equal(DEFAULT_PLANS.basic.maxBarbers, 3);
  assert.equal(DEFAULT_PLANS.pro.priceMonthlyEtb, 1200);
  assert.equal(DEFAULT_PLANS.pro.maxBarbers, -1);
});
