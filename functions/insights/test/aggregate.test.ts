import assert from 'node:assert/strict';
import { test } from 'node:test';

import { rebuildShop } from '../src/logic/backfill';
import { aggregateBookingInTx, AggregateTx, BookingData, ClientDoc, Marker, StatsDoc } from '../src/logic/stats';
import { booking } from './fixtures';

const NOW = '2026-11-13T09:00:00.000Z';

/** In-memory Firestore stand-in: reads first, writes applied at commit. */
class FakeDb {
  bookings = new Map<string, BookingData>();
  stats = new Map<string, StatsDoc>();
  clients = new Map<string, ClientDoc>();
  markers = new Map<string, Marker>();
  writes = 0;

  async run(bookingId: string) {
    const pending: (() => void)[] = [];
    let wrote = false;
    const read = () => assert.equal(wrote, false, 'reads must come before writes');
    const clone = <T>(v: T | undefined): T | null => (v === undefined ? null : JSON.parse(JSON.stringify(v)));
    const tx: AggregateTx = {
      getBooking: async () => (read(), clone(this.bookings.get(bookingId))),
      getMarker: async () => (read(), clone(this.markers.get(bookingId))),
      getStats: async (shop, month) => (read(), clone(this.stats.get(`${shop}/${month}`)) as Record<string, unknown> | null),
      getClient: async (shop, cid) => (read(), clone(this.clients.get(`${shop}/${cid}`)) as Record<string, unknown> | null),
      latestCompletedVisit: async (shop, cid) => {
        read();
        const visits = [...this.bookings.values()]
          .filter((b) => b.shopId === shop && b.customerId === cid && b.status === 'completed')
          .map((b) => b.startAt as string)
          .sort();
        return visits.at(-1) ?? null;
      },
      setStats: (shop, month, doc) => {
        wrote = true;
        pending.push(() => this.stats.set(`${shop}/${month}`, doc));
      },
      setClient: (shop, cid, doc) => {
        wrote = true;
        pending.push(() => this.clients.set(`${shop}/${cid}`, doc));
      },
      setMarker: (m) => {
        wrote = true;
        pending.push(() => this.markers.set(bookingId, m));
      },
      deleteMarker: () => {
        wrote = true;
        pending.push(() => this.markers.delete(bookingId));
      },
    };
    const outcome = await aggregateBookingInTx(tx, NOW);
    for (const p of pending) p();
    this.writes += pending.length;
    return outcome;
  }

  month(m: string, shop = 's1') {
    return this.stats.get(`${shop}/${m}`)!;
  }
  client(cid = 'c1', shop = 's1') {
    return this.clients.get(`${shop}/${cid}`)!;
  }
}

test('create, status change, retry', async () => {
  const db = new FakeDb();
  db.bookings.set('bk1', booking());
  assert.equal((await db.run('bk1')).result, 'applied');
  assert.equal(db.month('2026-11').bookings, 1);
  assert.equal(db.month('2026-11').completed, 0);
  assert.equal(db.client().name, 'Liya');

  db.bookings.set('bk1', booking({ status: 'completed' }));
  await db.run('bk1');
  assert.equal(db.month('2026-11').bookings, 1);
  assert.equal(db.month('2026-11').completed, 1);
  assert.equal(db.month('2026-11').revenueEtb, 350);
  assert.equal(db.client().completedCount, 1);
  assert.equal(db.client().lastVisitAt, '2026-11-10T07:00:00.000Z');

  // A retry (or duplicate event) writes nothing.
  const before = db.writes;
  assert.equal((await db.run('bk1')).result, 'unchanged');
  assert.equal(db.writes, before);
  assert.equal(db.month('2026-11').completed, 1);
});

test('reschedule into another month moves the booking', async () => {
  const db = new FakeDb();
  db.bookings.set('bk1', booking({ startAt: '2026-11-29T07:00:00.000Z' }));
  await db.run('bk1');
  db.bookings.set('bk1', booking({ startAt: '2026-12-02T07:00:00.000Z' }));
  await db.run('bk1');
  assert.equal(db.month('2026-11').bookings, 0);
  assert.equal(db.month('2026-12').bookings, 1);
  assert.equal(db.markers.get('bk1')!.contribution.month, '2026-12');
});

test('no-show, cancel and delete', async () => {
  const db = new FakeDb();
  db.bookings.set('bk1', booking({ status: 'noShow' }));
  db.bookings.set('bk2', booking({ status: 'cancelled' }));
  await db.run('bk1');
  await db.run('bk2');
  assert.equal(db.month('2026-11').noShows, 1);
  assert.equal(db.month('2026-11').cancelled, 1);
  assert.equal(db.client().noShowCount, 1);
  assert.equal(db.client().cancelledCount, 1);

  db.bookings.delete('bk1');
  await db.run('bk1');
  assert.equal(db.month('2026-11').bookings, 1);
  assert.equal(db.month('2026-11').noShows, 0);
  assert.equal(db.client().noShowCount, 0);
  assert.equal(db.markers.has('bk1'), false);
});

test('undoing the latest completed visit recomputes lastVisitAt', async () => {
  const db = new FakeDb();
  db.bookings.set('old', booking({ status: 'completed', startAt: '2026-10-05T07:00:00.000Z' }));
  db.bookings.set('new', booking({ status: 'completed', startAt: '2026-11-10T07:00:00.000Z' }));
  await db.run('old');
  await db.run('new');
  assert.equal(db.client().lastVisitAt, '2026-11-10T07:00:00.000Z');

  db.bookings.set('new', booking({ status: 'noShow', startAt: '2026-11-10T07:00:00.000Z' }));
  await db.run('new');
  assert.equal(db.client().lastVisitAt, '2026-10-05T07:00:00.000Z');
  assert.equal(db.client().completedCount, 1);
  assert.equal(db.client().noShowCount, 1);
});

test('events processed late or twice converge to the current booking', async () => {
  const db = new FakeDb();
  // Create + complete happen before either event is processed.
  db.bookings.set('bk1', booking({ status: 'completed' }));
  await db.run('bk1'); // "create" event: already sees completed
  await db.run('bk1'); // "update" event: nothing left to do
  const m = db.month('2026-11');
  assert.equal(m.bookings, 1);
  assert.equal(m.completed, 1);
  assert.equal(m.revenueEtb, 350);
});

test('incremental path matches a full rebuild', async () => {
  const db = new FakeDb();
  const history: [string, Partial<BookingData>][] = [
    ['a', { status: 'confirmed', startAt: '2026-09-03T07:00:00.000Z' }],
    ['b', { status: 'confirmed', customerId: 'c2', customerName: 'Hanna', price: 500, serviceId: 'srv2', serviceName: 'Cut' }],
    ['a', { status: 'completed', startAt: '2026-09-03T07:00:00.000Z' }],
    ['c', { status: 'confirmed', startAt: '2026-10-20T07:00:00.000Z', barberId: 'b2', barberName: 'Kaleab' }],
    ['c', { status: 'confirmed', startAt: '2026-11-01T07:00:00.000Z', barberId: 'b2', barberName: 'Kaleab' }],
    ['c', { status: 'completed', startAt: '2026-11-01T07:00:00.000Z', barberId: 'b2', barberName: 'Kaleab' }],
    ['b', { status: 'cancelled', customerId: 'c2', customerName: 'Hanna', price: 500, serviceId: 'srv2', serviceName: 'Cut' }],
    ['d', { status: 'noShow', customerId: 'c2', customerName: 'Hanna' }],
  ];
  for (const [id, extra] of history) {
    db.bookings.set(id, booking(extra));
    await db.run(id);
  }
  const rebuilt = rebuildShop(
    's1',
    [...db.bookings].map(([id, data]) => ({ id, data })),
    NOW,
  );
  const incremental = new Map([...db.stats].filter(([, s]) => s.bookings > 0).map(([k, s]) => [k.split('/')[1], s]));
  assert.deepEqual(incremental, rebuilt.stats);
  for (const [cid, doc] of rebuilt.clients) assert.deepEqual(db.client(cid), doc);
  assert.deepEqual(db.markers, rebuilt.markers);
});
