import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

import { lockExpiresAt, slotLockId, slotLockIdsFor, toInstant } from '../src/logic/lockIds';

interface Case {
  name: string;
  startAt: string;
  endAt: string;
  lockIds: string[];
  expiresAt: string;
}

// Compiled to build-test/test; the fixture stays in test/fixtures (the
// Flutter parity test, test/slot_lock_parity_test.dart, reads the same file).
const fixture = JSON.parse(
  readFileSync(join(__dirname, '..', '..', 'test', 'fixtures', 'lock_ids.json'), 'utf8'),
) as { cases: Case[] };

test('fixture is not empty', () => {
  assert.ok(fixture.cases.length >= 8);
});

for (const c of fixture.cases) {
  test(`lock ids match the Dart port: ${c.name}`, () => {
    assert.deepEqual(slotLockIdsFor(new Date(c.startAt), new Date(c.endAt)), c.lockIds);
    assert.equal(lockExpiresAt(new Date(c.endAt)), c.expiresAt);
  });
}

test('slotLockId is the Addis wall clock of the block start', () => {
  assert.equal(slotLockId(new Date('2026-11-20T11:30:00.000Z')), '20261120-1430');
  assert.equal(slotLockId(new Date('2026-11-20T21:00:00.000Z')), '20261121-0000');
});

test('toInstant reads ISO strings and Timestamp-like values', () => {
  assert.equal(toInstant('2026-11-20T08:00:00.000Z')?.toISOString(), '2026-11-20T08:00:00.000Z');
  const ts = { toDate: () => new Date('2026-11-20T08:00:00.000Z') };
  assert.equal(toInstant(ts)?.toISOString(), '2026-11-20T08:00:00.000Z');
  assert.equal(toInstant('not a date'), null);
  assert.equal(toInstant(undefined), null);
  assert.equal(toInstant(42), null);
});
