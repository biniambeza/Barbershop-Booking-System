import { test } from 'node:test';
import assert from 'node:assert/strict';

import { deriveCancelActor, detectBookingEvent, SMS_TYPES } from '../src/events';

test('create: pending -> created, confirmed -> confirmed', () => {
  assert.equal(detectBookingEvent(null, { status: 'pending' }), 'created');
  assert.equal(detectBookingEvent(undefined, { status: 'confirmed' }), 'confirmed');
  assert.equal(detectBookingEvent(null, {}), 'created');
  assert.equal(detectBookingEvent(null, { status: 'cancelled' }), null);
});

test('update: status transitions map to events', () => {
  const cases: [string, string, string | null][] = [
    ['pending', 'confirmed', 'confirmed'],
    ['pending', 'cancelled', 'cancelled'],
    ['confirmed', 'cancelled', 'cancelled'],
    ['confirmed', 'inProgress', 'started'],
    ['inProgress', 'completed', 'completed'],
    ['confirmed', 'completed', 'completed'],
    ['confirmed', 'pending', null],
  ];
  for (const [from, to, expected] of cases) {
    assert.equal(detectBookingEvent({ status: from }, { status: to }), expected, `${from} -> ${to}`);
  }
});

test('update without status change (reminder flags, payment) is ignored', () => {
  assert.equal(
    detectBookingEvent(
      { status: 'confirmed' },
      { status: 'confirmed', reminder24hSentAt: '2026-11-13T07:00:00.000Z', paymentStatus: 'paid' },
    ),
    null,
  );
});

test('delete is ignored', () => {
  assert.equal(detectBookingEvent({ status: 'confirmed' }, null), null);
});

test('cancel actor from cancelledBy uid', () => {
  const people = { barberUids: ['b1'], ownerUid: 'o1', isAdmin: (uid: string) => uid === 'a1' };
  const base = { customerId: 'c1', status: 'cancelled' };
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'c1' }, people), 'customer');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'b1' }, people), 'barber');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'o1' }, people), 'shop');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'a1' }, people), 'admin');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'zzz' }, people), 'unknown');
  assert.equal(deriveCancelActor(base, people), 'unknown');
});

test('SMS only for confirmed, cancelled and reminders', () => {
  assert.deepEqual([...SMS_TYPES].sort(), ['cancelled', 'confirmed', 'reminder24h', 'reminder2h']);
});
