import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildCodeDoc,
  checkCode,
  CODE_TTL_SECONDS,
  codeDocId,
  codeMatches,
  generateCode,
  hashCode,
  MAX_ATTEMPTS,
  newSalt,
  sha256Hex,
} from '../src/logic/codes';

const NOW = new Date('2026-11-20T07:00:00.000Z');
const at = (seconds: number) => new Date(NOW.getTime() + seconds * 1000);

test('codes are always six digits, zero padded', () => {
  assert.equal(generateCode(() => 0), '000000');
  assert.equal(generateCode(() => 42), '000042');
  assert.equal(generateCode(() => 999_999), '999999');
  for (let i = 0; i < 2000; i++) assert.match(generateCode(), /^[0-9]{6}$/);
});

test('generateCode asks for the full 0..999999 range', () => {
  let args: number[] = [];
  generateCode((min, max) => {
    args = [min, max];
    return 5;
  });
  assert.deepEqual(args, [0, 1_000_000]);
});

test('codes are not predictable (many distinct values)', () => {
  const seen = new Set<string>();
  for (let i = 0; i < 500; i++) seen.add(generateCode());
  assert.ok(seen.size > 450);
});

test('hashes are salted, hex SHA-256 and deterministic', () => {
  const salt = newSalt();
  assert.match(salt, /^[0-9a-f]{32}$/);
  assert.notEqual(newSalt(), salt);
  const h = hashCode('123456', salt);
  assert.match(h, /^[0-9a-f]{64}$/);
  assert.equal(hashCode('123456', salt), h);
  assert.notEqual(hashCode('123456', newSalt()), h);
  assert.notEqual(hashCode('123457', salt), h);
});

test('codeMatches accepts the right code only', () => {
  const salt = newSalt();
  const stored = hashCode('012345', salt);
  assert.equal(codeMatches('012345', salt, stored), true);
  assert.equal(codeMatches('012346', salt, stored), false);
  assert.equal(codeMatches('012345', 'other', stored), false);
  assert.equal(codeMatches('012345', salt, ''), false);
  assert.equal(codeMatches('012345', salt, 'abcd'), false);
});

test('doc ids separate purposes and never contain the email', () => {
  const r = codeDocId('register', 'a@b.co');
  const s = codeDocId('reset', 'a@b.co');
  assert.notEqual(r, s);
  assert.equal(r, `register_${sha256Hex('a@b.co')}`);
  assert.equal(s, `reset_${sha256Hex('a@b.co')}`);
  assert.ok(!r.includes('a@b.co'));
});

test('the stored doc holds only a hash of the code', () => {
  const doc = buildCodeDoc('register', 'a@b.co', '654321', NOW);
  assert.equal(doc.purpose, 'register');
  assert.equal(doc.emailHash, sha256Hex('a@b.co'));
  assert.equal(doc.attempts, 0);
  assert.equal(doc.createdAt, NOW.toISOString());
  assert.equal(doc.lastSentAt, NOW.toISOString());
  assert.equal(doc.expiresAt, at(CODE_TTL_SECONDS).toISOString());
  assert.ok(!JSON.stringify(doc).includes('654321'));
  assert.ok(!JSON.stringify(doc).includes('a@b.co'));
  assert.equal(codeMatches('654321', doc.salt, doc.codeHash), true);
});

test('checkCode: right code inside 10 minutes', () => {
  const doc = buildCodeDoc('register', 'a@b.co', '111111', NOW);
  assert.deepEqual(checkCode(doc, 'register', '111111', at(CODE_TTL_SECONDS - 1)), { result: 'ok' });
});

test('checkCode: expired at 10 minutes, missing doc, wrong purpose', () => {
  const doc = buildCodeDoc('register', 'a@b.co', '111111', NOW);
  assert.deepEqual(checkCode(doc, 'register', '111111', at(CODE_TTL_SECONDS)), { result: 'expired' });
  assert.deepEqual(checkCode(null, 'register', '111111', NOW), { result: 'expired' });
  assert.deepEqual(checkCode(doc, 'reset', '111111', NOW), { result: 'expired' });
});

test('checkCode: wrong codes count attempts; the fifth wrong one expires the code', () => {
  const doc = buildCodeDoc('reset', 'a@b.co', '111111', NOW);
  for (let i = 1; i < MAX_ATTEMPTS; i++) {
    const r = checkCode(doc, 'reset', '222222', NOW);
    assert.deepEqual(r, { result: 'wrong', attempts: i, attemptsLeft: MAX_ATTEMPTS - i });
    doc.attempts = i;
  }
  assert.deepEqual(checkCode(doc, 'reset', '222222', NOW), { result: 'expired' });
  // Out of attempts: even the right code no longer works.
  doc.attempts = MAX_ATTEMPTS;
  assert.deepEqual(checkCode(doc, 'reset', '111111', NOW), { result: 'expired' });
});
