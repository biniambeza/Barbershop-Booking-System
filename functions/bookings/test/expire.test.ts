import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  expireRequestInTx,
  expiryCutoff,
  isExpiredRequest,
  notAcceptedCancellation,
  NOT_ACCEPTED_REASON,
  PENDING_EXPIRY_LEAD_MINUTES,
  selectExpiredRequests,
} from '../src/logic/expire';
import { slotLockIdsFor } from '../src/logic/lockIds';
import { BookingData, LockData } from '../src/logic/verify';

const NOW = new Date('2026-11-13T07:00:00.000Z'); // 10:00 Addis
const minutes = (m: number) => new Date(NOW.getTime() + m * 60 * 1000);

function pending(startInMinutes: number, extra: Partial<BookingData> = {}): BookingData {
  const start = minutes(startInMinutes);
  return {
    shopId: 'shop_2',
    barberId: 'barber_2_1',
    status: 'pending',
    startAt: start.toISOString(),
    endAt: new Date(start.getTime() + 30 * 60 * 1000).toISOString(),
    ...extra,
  };
}

test('expiry lead is 60 minutes', () => {
  assert.equal(PENDING_EXPIRY_LEAD_MINUTES, 60);
  assert.equal(expiryCutoff(NOW).toISOString(), '2026-11-13T08:00:00.000Z');
});

test('pending requests within 60 minutes of their start (or past it) expire', () => {
  assert.equal(isExpiredRequest(pending(30), NOW), true);
  assert.equal(isExpiredRequest(pending(60), NOW), true); // exactly at the boundary
  assert.equal(isExpiredRequest(pending(-15), NOW), true); // already started
  assert.equal(isExpiredRequest(pending(61), NOW), false);
  assert.equal(isExpiredRequest(pending(24 * 60), NOW), false);
});

test('only pending bookings with a readable start are selected', () => {
  assert.equal(isExpiredRequest(pending(10, { status: 'confirmed' }), NOW), false);
  assert.equal(isExpiredRequest(pending(10, { status: 'cancelled' }), NOW), false);
  assert.equal(isExpiredRequest(pending(10, { startAt: undefined }), NOW), false);
  assert.equal(isExpiredRequest(pending(10, { startAt: 'not a date' }), NOW), false);
  assert.equal(isExpiredRequest(null, NOW), false);
  // Timestamp-like values work too.
  assert.equal(isExpiredRequest(pending(0, { startAt: { toDate: () => minutes(5) } }), NOW), true);
});

test('selectExpiredRequests keeps order and filters', () => {
  const ids = selectExpiredRequests(
    [
      { id: 'soon', data: pending(20) },
      { id: 'later', data: pending(180) },
      { id: 'past', data: pending(-120) },
      { id: 'accepted', data: pending(20, { status: 'confirmed' }) },
    ],
    NOW,
  );
  assert.deepEqual(ids, ['soon', 'past']);
});

test('cancellation fields', () => {
  assert.deepEqual(notAcceptedCancellation(), {
    status: 'cancelled',
    cancelledBy: 'system',
    cancelReason: NOT_ACCEPTED_REASON,
  });
  assert.equal(NOT_ACCEPTED_REASON, 'not_accepted');
});

function fakeTx(booking: BookingData | null, locks: Record<string, LockData>) {
  const writes: { updated?: Record<string, string>; deleted: string[] } = { deleted: [] };
  return {
    writes,
    tx: {
      async getBooking() {
        return booking;
      },
      async getLocks(_s: string, _b: string, ids: string[]) {
        return ids.map((id) => locks[id] ?? null);
      },
      updateBooking(fields: Record<string, string>) {
        writes.updated = fields;
      },
      deleteLocks(_s: string, _b: string, ids: string[]) {
        writes.deleted.push(...ids);
      },
    },
  };
}

test('expireRequestInTx cancels and frees only its own locks', async () => {
  const b = pending(30);
  const ids = slotLockIdsFor(new Date(b.startAt as string), new Date(b.endAt as string));
  assert.equal(ids.length, 2);
  const { tx, writes } = fakeTx(b, { [ids[0]]: { bookingId: 'b1' }, [ids[1]]: { bookingId: 'other' } });
  const outcome = await expireRequestInTx('b1', NOW, tx);
  assert.deepEqual(outcome, { result: 'expired', released: [ids[0]] });
  assert.deepEqual(writes.updated, notAcceptedCancellation());
  assert.deepEqual(writes.deleted, [ids[0]]);
});

test('expireRequestInTx leaves a request answered in the meantime alone', async () => {
  for (const status of ['confirmed', 'cancelled']) {
    const { tx, writes } = fakeTx(pending(30, { status }), {});
    assert.deepEqual(await expireRequestInTx('b1', NOW, tx), { result: 'skipped', reason: 'not_expired' });
    assert.equal(writes.updated, undefined);
    assert.deepEqual(writes.deleted, []);
  }
  const far = fakeTx(pending(120), {});
  assert.equal((await expireRequestInTx('b1', NOW, far.tx)).result, 'skipped');
  const gone = fakeTx(null, {});
  assert.equal((await expireRequestInTx('b1', NOW, gone.tx)).result, 'skipped');
});

test('expireRequestInTx without usable refs still cancels', async () => {
  const { tx, writes } = fakeTx(pending(30, { shopId: 'a/b' }), {});
  assert.deepEqual(await expireRequestInTx('b1', NOW, tx), { result: 'expired', released: [] });
  assert.deepEqual(writes.updated, notAcceptedCancellation());
});
