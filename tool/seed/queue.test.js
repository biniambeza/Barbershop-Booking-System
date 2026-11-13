'use strict';
// node --test: the seeded walk-in queue and its summary (formula of functions/queue).
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0));
const get = (docs, p) => docs.find((d) => d.path === p)?.data;

test('users mode writes the shop_1 queue with resolved times', () => {
  const docs = buildDocuments(seed, { now });
  const serving = get(docs, 'barbershops/shop_1/queue/queue_1_1');
  assert.strictEqual(serving.status, 'serving');
  assert.strictEqual(serving.createdAt, '2026-11-20T06:20:00.000Z');
  assert.strictEqual(serving.servingStartedAt, '2026-11-20T06:45:00.000Z');
  assert.strictEqual(serving.shopId, undefined, 'shopId is in the path');
  const remote = get(docs, 'barbershops/shop_1/queue/queue_1_3');
  assert.strictEqual(remote.source, 'remote');
  assert.strictEqual(remote.addedBy, 'user_cust_1');
  assert.match(remote.phone, /^\+251[79]\d{8}$/);
  for (const d of docs.filter((x) => x.path.includes('/queue/'))) {
    assert.ok(d.data.name.length <= 60);
    assert.ok(['waiting', 'serving', 'done', 'left'].includes(d.data.status));
    assert.ok(['walkIn', 'remote'].includes(d.data.source));
  }
});

test('queue summary: 3 waiting at shop_1 with 3 barbers', () => {
  const docs = buildDocuments(seed, { now });
  // queue_1_2 beard (30), queue_1_3 fade (45), queue_1_4 no service (30); 3 available barbers.
  assert.deepStrictEqual(get(docs, 'barbershops/shop_1/queueSummary/current'), {
    waitingCount: 3,
    estimatedWaitMinutes: 35,
    positions: {
      queue_1_2: { position: 1, waitMinutes: 0 },
      queue_1_3: { position: 2, waitMinutes: 10 },
      queue_1_4: { position: 3, waitMinutes: 25 },
    },
    updatedAt: now.toISOString(),
  });
});

test('invites mode writes no queue', () => {
  const docs = buildDocuments(seed, { now, mode: 'invites' });
  assert.ok(!docs.some((d) => d.path.includes('/queue')));
});
