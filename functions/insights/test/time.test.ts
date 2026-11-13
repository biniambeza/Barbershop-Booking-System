import assert from 'node:assert/strict';
import { test } from 'node:test';

import { addisMonthKey, isMonthKey } from '../src/logic/time';

test('month key uses Addis time (UTC+3)', () => {
  // 22:30 UTC on Oct 31 is 01:30 on Nov 1 in Addis.
  assert.equal(addisMonthKey('2026-10-31T22:30:00.000Z'), '2026-11');
  assert.equal(addisMonthKey('2026-10-31T20:59:00.000Z'), '2026-10');
  assert.equal(addisMonthKey('2026-12-31T21:00:00.000Z'), '2027-01');
});

test('month key rejects bad input', () => {
  assert.equal(addisMonthKey(''), null);
  assert.equal(addisMonthKey('not a date'), null);
  assert.equal(addisMonthKey(42), null);
  assert.equal(addisMonthKey(undefined), null);
});

test('isMonthKey', () => {
  assert.equal(isMonthKey('2026-11'), true);
  assert.equal(isMonthKey('2026-13'), false);
  assert.equal(isMonthKey('_applied'), false);
});
