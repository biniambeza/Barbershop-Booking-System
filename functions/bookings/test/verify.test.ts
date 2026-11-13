import assert from 'node:assert/strict';
import { test } from 'node:test';

import { BookingData, judgeLocks, LockData, planLockCheck, verifyBookingLocksInTx, VerifyTx } from '../src/logic/verify';

// 90 minutes from 10:00 Addis on 2026-11-20: six blocks.
const START = '2026-11-20T07:00:00.000Z';
const END = '2026-11-20T08:30:00.000Z';
const IDS = ['20261120-1000', '20261120-1015', '20261120-1030', '20261120-1045', '20261120-1100', '20261120-1115'];

function booking(extra: Partial<BookingData> = {}): BookingData {
  return { shopId: 's1', barberId: 'b1', status: 'confirmed', startAt: START, endAt: END, ...extra };
}

/** In-memory Firestore stand-in with transaction-like semantics. */
class FakeDb {
  bookings = new Map<string, BookingData>();
  locks = new Map<string, LockData>();

  static lockPath(shopId: string, barberId: string, id: string): string {
    return `${shopId}/${barberId}/${id}`;
  }

  lockAll(bookingId: string, ids: string[], shop = 's1', barber = 'b1'): void {
    for (const id of ids) this.locks.set(FakeDb.lockPath(shop, barber, id), { bookingId, startAt: 'x', expiresAt: 'y' });
  }

  /** One transaction attempt: reads first, writes buffered and applied at commit. */
  async run(bookingId: string) {
    const writes: (() => void)[] = [];
    let wrote = false;
    const tx: VerifyTx = {
      getBooking: async () => {
        assert.equal(wrote, false, 'reads must come before writes');
        const b = this.bookings.get(bookingId);
        return b ? { ...b } : null;
      },
      getLocks: async (shopId, barberId, ids) => {
        assert.equal(wrote, false, 'reads must come before writes');
        return ids.map((id) => this.locks.get(FakeDb.lockPath(shopId, barberId, id)) ?? null);
      },
      updateBooking: (fields) => {
        wrote = true;
        writes.push(() => this.bookings.set(bookingId, { ...this.bookings.get(bookingId)!, ...fields }));
      },
      deleteLocks: (shopId, barberId, ids) => {
        wrote = true;
        for (const id of ids) writes.push(() => this.locks.delete(FakeDb.lockPath(shopId, barberId, id)));
      },
    };
    const outcome = await verifyBookingLocksInTx(bookingId, tx);
    for (const w of writes) w();
    return outcome;
  }
}

test('planLockCheck: lock ids for every block, skips for missing/cancelled/legacy', () => {
  assert.deepEqual(planLockCheck(booking()), { shopId: 's1', barberId: 'b1', lockIds: IDS });
  assert.deepEqual(planLockCheck(null), { skip: 'missing' });
  assert.deepEqual(planLockCheck(booking({ status: 'cancelled' })), { skip: 'cancelled' });
  assert.deepEqual(planLockCheck(booking({ startAt: undefined })), { skip: 'no_interval' });
  assert.deepEqual(planLockCheck(booking({ endAt: '2026-11-20T06:00:00.000Z' })), { skip: 'no_interval' });
  assert.deepEqual(planLockCheck(booking({ shopId: 'a/b' })), { skip: 'bad_refs' });
  assert.deepEqual(planLockCheck(booking({ barberId: '' })), { skip: 'bad_refs' });
  assert.deepEqual(planLockCheck(booking({ endAt: '2026-11-25T07:00:00.000Z' })), { skip: 'too_long' });
  // Timestamp-like values (legacy/admin writes) work too.
  const ts = (iso: string) => ({ toDate: () => new Date(iso) });
  assert.deepEqual(planLockCheck(booking({ startAt: ts(START), endAt: ts(END) })), {
    shopId: 's1',
    barberId: 'b1',
    lockIds: IDS,
  });
});

test('judgeLocks sorts blocks into own, missing and foreign', () => {
  const v = judgeLocks('bk', ['a', 'b', 'c'], [{ bookingId: 'bk' }, null, { bookingId: 'other' }]);
  assert.deepEqual(v, { ok: false, missing: ['b'], foreign: ['c'], own: ['a'] });
  assert.equal(judgeLocks('bk', ['a'], [{ bookingId: 'bk' }]).ok, true);
});

test('a booking holding every lock is left alone', async () => {
  const db = new FakeDb();
  db.bookings.set('bk', booking());
  db.lockAll('bk', IDS);
  assert.deepEqual(await db.run('bk'), { result: 'ok', locks: 6 });
  assert.equal(db.bookings.get('bk')!.status, 'confirmed');
  assert.equal(db.locks.size, 6);
});

test('a missing middle lock cancels the booking and releases only its own locks', async () => {
  const db = new FakeDb();
  db.bookings.set('bk', booking());
  // The rules check blocks 0-3 and the last; block 4 (11:00) was skipped.
  db.lockAll('bk', IDS.filter((id) => id !== '20261120-1100'));
  // Another booking's lock elsewhere on the day is untouched.
  db.lockAll('other', ['20261120-1300']);
  const outcome = await db.run('bk');
  assert.deepEqual(outcome, {
    result: 'cancelled',
    missing: ['20261120-1100'],
    foreign: [],
    released: IDS.filter((id) => id !== '20261120-1100'),
  });
  const b = db.bookings.get('bk')!;
  assert.equal(b.status, 'cancelled');
  assert.equal(b.cancelledBy, 'system');
  assert.equal(b.cancelReason, 'slot_conflict');
  assert.deepEqual([...db.locks.keys()], ['s1/b1/20261120-1300']);
});

test('a block held by another booking cancels this one and keeps the other lock', async () => {
  const db = new FakeDb();
  db.bookings.set('bk', booking());
  db.bookings.set('first', booking({ startAt: '2026-11-20T08:00:00.000Z', endAt: '2026-11-20T08:15:00.000Z' }));
  db.lockAll('first', ['20261120-1100']);
  db.lockAll('bk', IDS.filter((id) => id !== '20261120-1100'));
  const outcome = await db.run('bk');
  assert.equal(outcome.result, 'cancelled');
  assert.deepEqual(outcome.result === 'cancelled' ? outcome.foreign : null, ['20261120-1100']);
  assert.deepEqual([...db.locks.entries()], [['s1/b1/20261120-1100', { bookingId: 'first', startAt: 'x', expiresAt: 'y' }]]);
  assert.equal(db.bookings.get('first')!.status, 'confirmed');
});

test('locks under another barber do not count', async () => {
  const db = new FakeDb();
  db.bookings.set('bk', booking());
  db.lockAll('bk', IDS, 's1', 'b2');
  const outcome = await db.run('bk');
  assert.equal(outcome.result, 'cancelled');
  // Nothing under b1 to release; the stray b2 locks are not touched.
  assert.equal(db.locks.size, 6);
});

test('idempotent: a retry after the cancellation is a no-op', async () => {
  const db = new FakeDb();
  db.bookings.set('bk', booking());
  db.lockAll('bk', IDS.slice(0, 4));
  assert.equal((await db.run('bk')).result, 'cancelled');
  const after = { ...db.bookings.get('bk')! };
  assert.deepEqual(await db.run('bk'), { result: 'skipped', reason: 'cancelled' });
  assert.deepEqual(db.bookings.get('bk'), after);
});

test('a booking the customer already cancelled is skipped', async () => {
  const db = new FakeDb();
  db.bookings.set('bk', booking({ status: 'cancelled', cancelledBy: 'cust' }));
  assert.deepEqual(await db.run('bk'), { result: 'skipped', reason: 'cancelled' });
  assert.equal(db.bookings.get('bk')!.cancelledBy, 'cust');
});

test('a deleted booking is skipped', async () => {
  const db = new FakeDb();
  assert.deepEqual(await db.run('gone'), { result: 'skipped', reason: 'missing' });
});
