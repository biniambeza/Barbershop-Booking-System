import assert from 'node:assert/strict';
import { test } from 'node:test';

import { sha256Hex } from '../src/logic/codes';
import { bumpWindow, cooldownRemaining, DAY_MS, emailRateKey, HOUR_MS, ipRateKey, RateDoc } from '../src/logic/rateLimit';

const NOW = new Date('2026-11-20T07:00:00.000Z');
const at = (ms: number) => new Date(NOW.getTime() + ms);

test('cooldown: 60 seconds after the last send', () => {
  assert.equal(cooldownRemaining(undefined, NOW), 0);
  assert.equal(cooldownRemaining('garbage', NOW), 0);
  const last = NOW.toISOString();
  assert.equal(cooldownRemaining(last, NOW), 60);
  assert.equal(cooldownRemaining(last, at(500)), 60);
  assert.equal(cooldownRemaining(last, at(59_001)), 1);
  assert.equal(cooldownRemaining(last, at(60_000)), 0);
});

test('a window allows max sends, then refuses until it ends', () => {
  let doc: RateDoc | null = null;
  for (let i = 1; i <= 5; i++) {
    const r = bumpWindow(doc, at(i * 1000), DAY_MS, 5);
    assert.equal(r.allowed, true);
    assert.equal(r.next.count, i);
    doc = r.next;
  }
  assert.equal(doc!.windowStart, at(1000).toISOString());
  assert.equal(doc!.expiresAt, at(1000 + DAY_MS).toISOString());
  const refused = bumpWindow(doc, at(3600_000), DAY_MS, 5);
  assert.equal(refused.allowed, false);
  assert.equal(refused.retryAfterSeconds, Math.ceil((DAY_MS + 1000 - 3600_000) / 1000));
  // A new window starts once the old one is over.
  const fresh = bumpWindow(doc, at(1000 + DAY_MS), DAY_MS, 5);
  assert.equal(fresh.allowed, true);
  assert.equal(fresh.next.count, 1);
});

test('hourly window', () => {
  let doc: RateDoc | null = null;
  for (let i = 0; i < 20; i++) doc = bumpWindow(doc, NOW, HOUR_MS, 20).next;
  assert.equal(bumpWindow(doc, at(HOUR_MS - 1), HOUR_MS, 20).allowed, false);
  assert.equal(bumpWindow(doc, at(HOUR_MS), HOUR_MS, 20).allowed, true);
});

test('a broken or future-dated counter starts over', () => {
  assert.equal(bumpWindow({ count: 99, windowStart: 'x', expiresAt: 'y' }, NOW, HOUR_MS, 20).allowed, true);
  assert.equal(bumpWindow({ count: 99, windowStart: at(5000).toISOString(), expiresAt: 'y' }, NOW, HOUR_MS, 20).allowed, true);
});

test('rate keys hash emails and IPs', () => {
  assert.equal(emailRateKey('a@b.co'), `email_${sha256Hex('a@b.co')}`);
  assert.equal(ipRateKey('10.0.0.1'), `ip_${sha256Hex('10.0.0.1')}`);
});
