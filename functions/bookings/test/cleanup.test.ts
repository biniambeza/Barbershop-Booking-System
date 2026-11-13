import assert from 'node:assert/strict';
import { test } from 'node:test';

import { CLEANUP_MAX_PER_RUN, CLEANUP_PAGE_SIZE, sweepExpiredLocks } from '../src/logic/cleanup';

/** Locks as {id, expiresAt}; fetchExpired mimics the collection-group query. */
function store(locks: { id: string; expiresAt?: string }[]) {
  const live = new Map(locks.map((l) => [l.id, l]));
  const calls: { nowIso: string; limit: number }[] = [];
  return {
    live,
    calls,
    ports: {
      async fetchExpired(nowIso: string, limit: number) {
        calls.push({ nowIso, limit });
        return [...live.values()]
          .filter((l) => l.expiresAt !== undefined && l.expiresAt < nowIso)
          .sort((a, b) => a.expiresAt!.localeCompare(b.expiresAt!))
          .slice(0, limit)
          .map((l) => l.id);
      },
      async deleteAll(ids: string[]) {
        assert.ok(ids.length <= 500, 'a batch holds at most 500 writes');
        for (const id of ids) live.delete(id);
      },
    },
  };
}

const NOW = new Date('2026-11-13T01:00:00.000Z');

test('deletes only locks whose expiresAt has passed', async () => {
  const s = store([
    { id: 'old', expiresAt: '2026-11-12T08:00:00.000Z' },
    { id: 'just', expiresAt: '2026-11-13T00:59:59.999Z' },
    { id: 'now', expiresAt: '2026-11-13T01:00:00.000Z' },
    { id: 'future', expiresAt: '2026-11-20T08:00:00.000Z' },
    { id: 'legacy' },
  ]);
  const result = await sweepExpiredLocks(NOW, s.ports);
  assert.deepEqual(result, { deleted: 2, pages: 1, capped: false });
  assert.deepEqual([...s.live.keys()].sort(), ['future', 'legacy', 'now']);
  assert.equal(s.calls[0].nowIso, '2026-11-13T01:00:00.000Z');
});

test('pages through a backlog and stops at the per-run cap', async () => {
  const many = Array.from({ length: 25 }, (_, i) => ({
    id: `l${i}`,
    expiresAt: `2026-11-01T00:00:${String(i).padStart(2, '0')}.000Z`,
  }));
  const s = store(many);
  const result = await sweepExpiredLocks(NOW, s.ports, { pageSize: 10, maxPerRun: 22 });
  assert.deepEqual(result, { deleted: 22, pages: 3, capped: true });
  assert.deepEqual(
    s.calls.map((c) => c.limit),
    [10, 10, 2],
  );
  // Oldest first, so the newest three are left for the next run.
  assert.deepEqual([...s.live.keys()], ['l22', 'l23', 'l24']);
  const next = await sweepExpiredLocks(NOW, s.ports, { pageSize: 10, maxPerRun: 22 });
  assert.deepEqual(next, { deleted: 3, pages: 1, capped: false });
});

test('an exact multiple of the page size ends with an empty page', async () => {
  const s = store(Array.from({ length: 20 }, (_, i) => ({ id: `l${i}`, expiresAt: '2026-11-01T00:00:00.000Z' })));
  assert.deepEqual(await sweepExpiredLocks(NOW, s.ports, { pageSize: 10 }), { deleted: 20, pages: 2, capped: false });
  assert.equal(s.calls.length, 3);
});

test('nothing to do', async () => {
  const s = store([]);
  assert.deepEqual(await sweepExpiredLocks(NOW, s.ports), { deleted: 0, pages: 0, capped: false });
});

test('defaults fit a write batch', () => {
  assert.ok(CLEANUP_PAGE_SIZE <= 500);
  assert.ok(CLEANUP_MAX_PER_RUN >= CLEANUP_PAGE_SIZE);
});
