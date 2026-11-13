import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  DEFAULT_SERVICE_MINUTES,
  arrivalOrder,
  estimateQueue,
  serviceMinutes,
  type QueueEntry,
} from '../src/logic/estimate';

const durations = { fade: 45, beard: 30, full: 90 };

function entry(id: string, minute: number, extra: Partial<QueueEntry> = {}): QueueEntry {
  return {
    id,
    status: 'waiting',
    createdAt: `2026-11-13T07:${String(minute).padStart(2, '0')}:00.000Z`,
    ...extra,
  };
}

test('empty queue: nobody waiting, no wait', () => {
  assert.deepEqual(estimateQueue([], durations, 2), { waitingCount: 0, estimatedWaitMinutes: 0, positions: {} });
});

test('waits add up the services ahead, divided by available barbers, rounded up', () => {
  const entries = [
    entry('a', 0, { serviceId: 'fade' }), // 45
    entry('b', 5, { serviceId: 'beard' }), // 30
    entry('c', 10), // no service: 30
    entry('d', 15, { serviceId: 'full' }), // 90
  ];
  const r = estimateQueue(entries, durations, 2);
  assert.equal(r.waitingCount, 4);
  assert.deepEqual(r.positions, {
    a: { position: 1, waitMinutes: 0 },
    b: { position: 2, waitMinutes: 23 }, // ceil(45 / 2)
    c: { position: 3, waitMinutes: 38 }, // ceil(75 / 2)
    d: { position: 4, waitMinutes: 53 }, // ceil(105 / 2)
  });
  assert.equal(r.estimatedWaitMinutes, 98); // ceil(195 / 2)
});

test('arrival order is createdAt, then id; non-waiting entries are ignored', () => {
  const entries = [
    entry('z', 10),
    entry('b', 0),
    entry('a', 0),
    entry('s', 1, { status: 'serving', serviceId: 'full' }),
    entry('d', 2, { status: 'done' }),
    entry('l', 3, { status: 'left' }),
  ];
  const r = estimateQueue(entries, durations, 1);
  assert.deepEqual(
    Object.entries(r.positions).map(([id, p]) => [id, p.position, p.waitMinutes]),
    [
      ['a', 1, 0],
      ['b', 2, 30],
      ['z', 3, 60],
    ],
  );
  assert.equal(r.estimatedWaitMinutes, 90);
  assert.deepEqual(
    arrivalOrder(entries).map((e) => e.id),
    ['a', 'b', 's', 'd', 'l', 'z'],
  );
});

test('at least one barber is assumed', () => {
  const entries = [entry('a', 0, { serviceId: 'fade' })];
  assert.equal(estimateQueue(entries, durations, 0).estimatedWaitMinutes, 45);
  assert.equal(estimateQueue(entries, durations, -3).estimatedWaitMinutes, 45);
  assert.equal(estimateQueue(entries, durations, Number.NaN).estimatedWaitMinutes, 45);
  assert.equal(estimateQueue(entries, durations, 2.9).estimatedWaitMinutes, 23);
});

test('unknown or invalid service durations fall back to the default', () => {
  assert.equal(serviceMinutes(undefined, durations), DEFAULT_SERVICE_MINUTES);
  assert.equal(serviceMinutes(null, durations), DEFAULT_SERVICE_MINUTES);
  assert.equal(serviceMinutes('gone', durations), DEFAULT_SERVICE_MINUTES);
  assert.equal(serviceMinutes('bad', { bad: 0 }), DEFAULT_SERVICE_MINUTES);
  assert.equal(serviceMinutes('beard', durations), 30);
  assert.equal(DEFAULT_SERVICE_MINUTES, 30);
});
