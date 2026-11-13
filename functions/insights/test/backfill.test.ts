import assert from 'node:assert/strict';
import { test } from 'node:test';

import { rebuildShop } from '../src/logic/backfill';
import { booking } from './fixtures';

const NOW = '2026-11-13T09:00:00.000Z';

test('rebuild groups by Addis month and ignores other shops', () => {
  const r = rebuildShop(
    's1',
    [
      { id: '1', data: booking({ status: 'completed', startAt: '2026-09-10T07:00:00.000Z', price: 300 }) },
      { id: '2', data: booking({ status: 'completed', startAt: '2026-10-10T07:00:00.000Z', price: 400 }) },
      // 21:30 UTC Oct 31 = Nov 1 in Addis.
      { id: '3', data: booking({ status: 'noShow', startAt: '2026-10-31T21:30:00.000Z' }) },
      { id: '4', data: booking({ shopId: 's2', status: 'completed' }) },
      { id: '5', data: booking({ status: 'cancelled', cancelledBy: 'system', cancelReason: 'slot_conflict' }) },
    ],
    NOW,
  );
  assert.deepEqual([...r.stats.keys()].sort(), ['2026-09', '2026-10', '2026-11']);
  assert.equal(r.stats.get('2026-09')!.revenueEtb, 300);
  assert.equal(r.stats.get('2026-11')!.noShows, 1);
  assert.deepEqual([...r.markers.keys()].sort(), ['1', '2', '3']);
  const client = r.clients.get('c1')!;
  assert.equal(client.completedCount, 2);
  assert.equal(client.noShowCount, 1);
  assert.equal(client.lastVisitAt, '2026-10-10T07:00:00.000Z');
});

test('client name comes from the latest booking', () => {
  const r = rebuildShop(
    's1',
    [
      { id: 'new', data: booking({ customerName: 'Liya Getachew', startAt: '2026-11-10T07:00:00.000Z' }) },
      { id: 'old', data: booking({ customerName: 'Liya', startAt: '2026-09-10T07:00:00.000Z' }) },
    ],
    NOW,
  );
  assert.equal(r.clients.get('c1')!.name, 'Liya Getachew');
});
