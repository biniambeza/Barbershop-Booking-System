import assert from 'node:assert/strict';
import { test } from 'node:test';

import { sweepExpired } from '../src/logic/cleanup';

test('deletes expired docs of both collections page by page', async () => {
  const docs: Record<string, { id: string; expiresAt: string }[]> = {
    emailCodes: [
      { id: 'a', expiresAt: '2026-11-19T00:00:00.000Z' },
      { id: 'b', expiresAt: '2026-11-21T00:00:00.000Z' },
      { id: 'c', expiresAt: '2026-11-18T00:00:00.000Z' },
      { id: 'd', expiresAt: '2026-11-17T00:00:00.000Z' },
    ],
    authRateLimits: [{ id: 'r', expiresAt: '2026-11-19T23:59:59.000Z' }],
  };
  const deleted: string[] = [];
  const result = await sweepExpired(
    new Date('2026-11-20T00:00:00.000Z'),
    {
      async fetchExpired(collection, nowIso, limit) {
        return docs[collection].filter((d) => d.expiresAt < nowIso).slice(0, limit).map((d) => `${collection}/${d.id}`);
      },
      async deleteAll(refs) {
        for (const ref of refs) {
          const [c, id] = ref.split('/');
          docs[c] = docs[c].filter((d) => d.id !== id);
          deleted.push(ref);
        }
      },
    },
    2,
  );
  assert.deepEqual(result, { emailCodes: 3, authRateLimits: 1 });
  assert.deepEqual(docs.emailCodes.map((d) => d.id), ['b']);
  assert.equal(deleted.length, 4);
});
