import assert from 'node:assert/strict';
import { test } from 'node:test';

import { slotLockIdsFor } from '../src/logic/lockIds';
import { intervalChanged, shouldVerifyUpdate } from '../src/logic/reschedule';
import { BookingData, LockData, judgeLocks, verifyBookingLocksInTx, VerifyTx } from '../src/logic/verify';

// Old: 10:00-10:30 Addis on 2026-11-20. New: 10:15-10:45 (overlaps one block).
const OLD = { startAt: '2026-11-20T07:00:00.000Z', endAt: '2026-11-20T07:30:00.000Z' };
const NEW = { startAt: '2026-11-20T07:15:00.000Z', endAt: '2026-11-20T07:45:00.000Z' };

function booking(extra: Partial<BookingData> = {}): BookingData {
  return { shopId: 's1', barberId: 'b1', status: 'confirmed', ...NEW, ...extra };
}

test('intervalChanged: startAt or endAt moved (string or Timestamp-like), nothing else', () => {
  assert.equal(intervalChanged(booking(OLD), booking()), true);
  assert.equal(intervalChanged(booking(), booking()), false);
  assert.equal(intervalChanged(booking(), booking({ status: 'cancelled', cancelledBy: 'u1' })), false);
  assert.equal(intervalChanged(booking(), booking({ paymentStatus: 'paid', reminder24hSentAt: 'x' })), false);
  // Same instant written differently is not a move.
  const ts = { toDate: () => new Date(NEW.startAt) };
  assert.equal(intervalChanged(booking(), booking({ startAt: ts })), false);
  assert.equal(intervalChanged(booking(), booking({ endAt: '2026-11-20T08:00:00.000Z' })), true);
  assert.equal(intervalChanged(null, booking()), false);
  assert.equal(intervalChanged(booking(), null), false);
});

test('shouldVerifyUpdate: only live bookings whose interval moved', () => {
  assert.equal(shouldVerifyUpdate(booking(OLD), booking()), true);
  assert.equal(shouldVerifyUpdate(booking({ ...OLD, status: 'pending' }), booking({ status: 'pending' })), true);
  // A reschedule that the trigger itself cancelled: no second check.
  assert.equal(shouldVerifyUpdate(booking(OLD), booking({ status: 'cancelled' })), false);
  // Status-only writes (cancel, no-show, complete) are ignored.
  assert.equal(shouldVerifyUpdate(booking(), booking({ status: 'noShow' })), false);
});

test('time-off locks count as held by someone else', () => {
  const ids = slotLockIdsFor(new Date(NEW.startAt), new Date(NEW.endAt));
  assert.deepEqual(ids, ['20261120-1015', '20261120-1030']);
  const verdict = judgeLocks('bk1', ids, [
    { bookingId: 'bk1', startAt: 'x', expiresAt: 'y' },
    { timeOffId: 'off1', startAt: 'x', expiresAt: 'y' },
  ]);
  assert.deepEqual(verdict, { ok: false, missing: [], foreign: ['20261120-1030'], own: ['20261120-1015'] });
});

/** Booking + locks with transaction-like semantics (reads before writes). */
class FakeDb {
  booking: BookingData | null = null;
  locks = new Map<string, LockData>();

  async run(bookingId: string) {
    const writes: (() => void)[] = [];
    let wrote = false;
    const tx: VerifyTx = {
      getBooking: async () => {
        assert.equal(wrote, false);
        return this.booking ? { ...this.booking } : null;
      },
      getLocks: async (_s, _b, ids) => {
        assert.equal(wrote, false);
        return ids.map((id) => this.locks.get(id) ?? null);
      },
      updateBooking: (fields) => {
        wrote = true;
        writes.push(() => (this.booking = { ...this.booking!, ...fields }));
      },
      deleteLocks: (_s, _b, ids) => {
        wrote = true;
        for (const id of ids) writes.push(() => this.locks.delete(id));
      },
    };
    const outcome = await verifyBookingLocksInTx(bookingId, tx);
    for (const w of writes) w();
    return outcome;
  }
}

test('a clean reschedule (kept + new locks held) passes', async () => {
  const db = new FakeDb();
  db.booking = booking({ rescheduleCount: 1 });
  // 10:15 kept from the old interval, 10:30 created by the reschedule.
  db.locks.set('20261120-1015', { bookingId: 'bk1' });
  db.locks.set('20261120-1030', { bookingId: 'bk1' });
  assert.deepEqual(await db.run('bk1'), { result: 'ok', locks: 2 });
  assert.equal(db.booking!.status, 'confirmed');
});

test('a reschedule into time off is cancelled as slot_conflict; the time-off lock stays', async () => {
  const db = new FakeDb();
  db.booking = booking({ rescheduleCount: 1 });
  db.locks.set('20261120-1015', { bookingId: 'bk1' });
  db.locks.set('20261120-1030', { timeOffId: 'off1' });
  // The old interval's released block is not looked at.
  db.locks.set('20261120-1000', { bookingId: 'someone-else' });
  const outcome = await db.run('bk1');
  assert.deepEqual(outcome, {
    result: 'cancelled',
    missing: [],
    foreign: ['20261120-1030'],
    released: ['20261120-1015'],
  });
  assert.equal(db.booking!.status, 'cancelled');
  assert.equal(db.booking!.cancelledBy, 'system');
  assert.equal(db.booking!.cancelReason, 'slot_conflict');
  assert.deepEqual(db.locks.get('20261120-1030'), { timeOffId: 'off1' });
  assert.equal(db.locks.has('20261120-1015'), false);
  assert.deepEqual(db.locks.get('20261120-1000'), { bookingId: 'someone-else' });
});

test('a reschedule missing a new lock is cancelled', async () => {
  const db = new FakeDb();
  db.booking = booking();
  db.locks.set('20261120-1015', { bookingId: 'bk1' });
  const outcome = await db.run('bk1');
  assert.equal(outcome.result, 'cancelled');
  assert.deepEqual(outcome.result === 'cancelled' && outcome.missing, ['20261120-1030']);
});
