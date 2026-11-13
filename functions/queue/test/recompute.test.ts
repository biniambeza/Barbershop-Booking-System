import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { QueueEntry } from '../src/logic/estimate';
import {
  affectsSummary,
  findDuplicateRemoteEntries,
  queueNextNotificationId,
  recomputeQueue,
  type QueueSummaryDoc,
} from '../src/logic/recompute';

const NOW = new Date('2026-11-13T08:00:00.000Z');

function entry(id: string, minute: number, extra: Partial<QueueEntry> = {}): QueueEntry {
  return {
    id,
    name: id,
    status: 'waiting',
    source: 'walkIn',
    addedBy: 'owner_1',
    createdAt: `2026-11-13T07:${String(minute).padStart(2, '0')}:00.000Z`,
    ...extra,
  };
}

function fakePorts(active: QueueEntry[], durations: Record<string, number> = {}, barbers = 1) {
  const left: string[] = [];
  const summaries: QueueSummaryDoc[] = [];
  return {
    left,
    summaries,
    ports: {
      listActive: async () => active,
      serviceDurations: async () => durations,
      availableBarbers: async () => barbers,
      markLeft: (ids: string[], nowIso: string) => {
        assert.equal(nowIso, NOW.toISOString());
        left.push(...ids);
      },
      writeSummary: (s: QueueSummaryDoc) => summaries.push(s),
    },
  };
}

test('only writes touching an active entry affect the summary', () => {
  assert.equal(affectsSummary(null, { status: 'waiting' }), true);
  assert.equal(affectsSummary({ status: 'waiting' }, { status: 'serving' }), true);
  assert.equal(affectsSummary({ status: 'serving' }, { status: 'done' }), true);
  assert.equal(affectsSummary({ status: 'waiting' }, null), true);
  assert.equal(affectsSummary({ status: 'done' }, { status: 'done' }), false);
  assert.equal(affectsSummary({ status: 'left' }, null), false);
  assert.equal(affectsSummary(null, null), false);
});

test('writes the summary with positions and the wait for a new joiner', async () => {
  const f = fakePorts(
    [
      entry('s1', 0, { status: 'serving', barberId: 'b1', serviceId: 'full' }),
      entry('w1', 1, { serviceId: 'fade' }),
      entry('w2', 2),
    ],
    { fade: 45, full: 90 },
    2,
  );
  const r = await recomputeQueue(NOW, f.ports);
  assert.deepEqual(f.summaries, [
    {
      waitingCount: 2,
      estimatedWaitMinutes: 38,
      positions: { w1: { position: 1, waitMinutes: 0 }, w2: { position: 2, waitMinutes: 23 } },
      updatedAt: NOW.toISOString(),
    },
  ]);
  assert.deepEqual(r.duplicates, []);
  assert.equal(r.nextRemote, null, 'first waiting entry is a walk-in');
});

test('empty queue writes a zero summary', async () => {
  const f = fakePorts([]);
  const r = await recomputeQueue(NOW, f.ports);
  assert.deepEqual(r.summary, { waitingCount: 0, estimatedWaitMinutes: 0, positions: {}, updatedAt: NOW.toISOString() });
  assert.equal(r.nextRemote, null);
});

test('returns the first waiting entry when a remote customer added it', async () => {
  const remote = entry('r1', 1, { source: 'remote', addedBy: 'cust_1' });
  const f = fakePorts([entry('w2', 5), remote, entry('s', 0, { status: 'serving' })]);
  const r = await recomputeQueue(NOW, f.ports);
  assert.equal(r.nextRemote?.id, 'r1');
});

test('closes a customer’s later duplicate remote entries', async () => {
  const active = [
    entry('r1', 1, { source: 'remote', addedBy: 'cust_1' }),
    entry('r2', 2, { source: 'remote', addedBy: 'cust_1' }),
    entry('r3', 3, { source: 'remote', addedBy: 'cust_2' }),
    entry('w1', 4, { addedBy: 'cust_1' }), // walk-in added by staff is not a duplicate
  ];
  const f = fakePorts(active);
  const r = await recomputeQueue(NOW, f.ports);
  assert.deepEqual(r.duplicates, ['r2']);
  assert.deepEqual(f.left, ['r2']);
  assert.deepEqual(Object.keys(r.summary.positions), ['r1', 'r3', 'w1']);
  assert.equal(r.summary.waitingCount, 3);
});

test('a serving remote entry wins over an earlier waiting duplicate', () => {
  assert.deepEqual(
    findDuplicateRemoteEntries([
      entry('r1', 1, { source: 'remote', addedBy: 'c' }),
      entry('r2', 2, { source: 'remote', addedBy: 'c', status: 'serving' }),
      entry('r3', 3, { source: 'remote', addedBy: 'c' }),
    ]),
    ['r1', 'r3'],
  );
  assert.deepEqual(findDuplicateRemoteEntries([entry('r1', 1, { source: 'remote', addedBy: 'c' })]), []);
});

test('notification id is per entry and per join', () => {
  assert.equal(queueNextNotificationId('e1', '2026-11-13T07:00:00.000Z'), 'queue_e1-1794553200000_queueNext');
  assert.equal(queueNextNotificationId('e1', undefined), 'queue_e1-0_queueNext');
  assert.notEqual(
    queueNextNotificationId('e1', '2026-11-13T07:00:00.000Z'),
    queueNextNotificationId('e1', '2026-11-13T07:30:00.000Z'),
  );
});
