import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  addisWhen,
  flagRefundInTx,
  LATE_CANCEL_REFUND_PERCENT,
  needsRefundFlag,
  paymentMirrorPatch,
  planRefundFlag,
  REFUND_REASONS,
  refundAmountFor,
  refundReasonFor,
  RefundBookingData,
  renderRefundDue,
  shouldHandleRefund,
} from '../src/logic/refund';

const NOW = new Date('2026-11-20T07:00:00.000Z'); // 10:00 Addis
const hours = (h: number) => new Date(NOW.getTime() + h * 3600 * 1000);

function cancelled(extra: Partial<RefundBookingData> = {}): RefundBookingData {
  return {
    shopId: 'shop_1',
    shopName: 'Fade Lab',
    barberId: 'barber_1',
    customerId: 'cust_1',
    price: 300,
    status: 'cancelled',
    paymentStatus: 'paid',
    paymentId: 'pay_1',
    cancelledBy: 'owner_uid',
    startAt: hours(24).toISOString(),
    endAt: hours(24.5).toISOString(),
    ...extra,
  };
}

test('only cancelled + paid + unflagged bookings with a price need a flag', () => {
  assert.equal(needsRefundFlag(cancelled()), true);
  assert.equal(needsRefundFlag(cancelled({ paymentStatus: 'unpaid' })), false);
  assert.equal(needsRefundFlag(cancelled({ paymentStatus: 'refunded' })), false);
  assert.equal(needsRefundFlag(cancelled({ status: 'noShow' })), false);
  assert.equal(needsRefundFlag(cancelled({ status: 'confirmed' })), false);
  assert.equal(needsRefundFlag(cancelled({ refundStatus: 'due' })), false);
  assert.equal(needsRefundFlag(cancelled({ refundStatus: 'refunded' })), false);
  assert.equal(needsRefundFlag(cancelled({ price: 0 })), false);
  assert.equal(needsRefundFlag(null), false);
});

test('reasons follow who cancelled', () => {
  assert.equal(refundReasonFor(cancelled({ cancelReason: 'shop_deleted', cancelledBy: 'admin' }), 2, NOW), REFUND_REASONS.shopDeleted);
  assert.equal(refundReasonFor(cancelled({ cancelledBy: 'system', cancelReason: 'not_accepted' }), 2, NOW), REFUND_REASONS.requestExpired);
  assert.equal(refundReasonFor(cancelled({ cancelledBy: 'barber', declineReason: 'not_accepted' }), 2, NOW), REFUND_REASONS.requestExpired);
  assert.equal(refundReasonFor(cancelled({ cancelledBy: 'barber' }), 2, NOW), REFUND_REASONS.requestDeclined);
  assert.equal(refundReasonFor(cancelled({ cancelledBy: 'system', cancelReason: 'slot_conflict' }), 2, NOW), REFUND_REASONS.systemCancelled);
  assert.equal(refundReasonFor(cancelled({ cancelledBy: undefined }), 2, NOW), REFUND_REASONS.systemCancelled);
  assert.equal(refundReasonFor(cancelled({ cancelledBy: 'owner_uid' }), 2, NOW), REFUND_REASONS.shopCancelled);
});

test('the customer: on time before the cutoff, late after it, on time when the cancel time is unknown', () => {
  const b = cancelled({ cancelledBy: 'cust_1', startAt: hours(5).toISOString() });
  assert.equal(refundReasonFor(b, 2, hours(3)), REFUND_REASONS.customerCancelled); // exactly at the deadline
  assert.equal(refundReasonFor(b, 2, new Date(hours(3).getTime() + 1000)), REFUND_REASONS.customerLateCancel);
  assert.equal(refundReasonFor(b, null, hours(4)), REFUND_REASONS.customerLateCancel); // default cutoff 2 h
  assert.equal(refundReasonFor(b, 2, null), REFUND_REASONS.customerCancelled);
});

test('amounts: full, late share, none for bad prices', () => {
  assert.equal(refundAmountFor(300, REFUND_REASONS.shopCancelled), 300);
  assert.equal(refundAmountFor(250, REFUND_REASONS.customerLateCancel), (250 * LATE_CANCEL_REFUND_PERCENT) / 100);
  assert.equal(refundAmountFor(99.99, REFUND_REASONS.customerLateCancel), 50);
  assert.equal(refundAmountFor(0, REFUND_REASONS.shopCancelled), 0);
  assert.equal(refundAmountFor('300', REFUND_REASONS.shopCancelled), 0);
  assert.equal(refundAmountFor(NaN, REFUND_REASONS.shopCancelled), 0);
});

test('planRefundFlag writes the four fields', () => {
  assert.deepEqual(planRefundFlag(cancelled(), { now: NOW, cutoffHours: 2, cancelledAt: NOW }), {
    refundStatus: 'due',
    refundAmount: 300,
    refundReason: REFUND_REASONS.shopCancelled,
    refundFlaggedAt: NOW.toISOString(),
  });
  assert.equal(planRefundFlag(cancelled({ refundStatus: 'due' }), { now: NOW, cutoffHours: 2, cancelledAt: NOW }), null);
});

test('shouldHandleRefund: flag needed, or refund fields changed', () => {
  assert.equal(shouldHandleRefund(cancelled({ status: 'confirmed' }), cancelled()), true);
  assert.equal(shouldHandleRefund(null, null), false);
  const due = cancelled({ refundStatus: 'due', refundAmount: 300 });
  assert.equal(shouldHandleRefund(due, due), false);
  assert.equal(shouldHandleRefund(due, { ...due, refundStatus: 'refunded', refundedAt: NOW.toISOString() }), true);
  assert.equal(shouldHandleRefund(cancelled({ paymentStatus: 'unpaid' }), cancelled({ paymentStatus: 'unpaid', status: 'cancelled' })), false);
});

test('payment mirror only writes differences', () => {
  const booking = { ...cancelled(), refundStatus: 'due', refundAmount: 300, refundReason: 'shop_cancelled', refundFlaggedAt: 'x' };
  assert.deepEqual(paymentMirrorPatch(booking, { status: 'success' }), {
    refundStatus: 'due',
    refundAmount: 300,
    refundReason: 'shop_cancelled',
    refundFlaggedAt: 'x',
  });
  assert.equal(paymentMirrorPatch(booking, { refundStatus: 'due', refundAmount: 300, refundReason: 'shop_cancelled', refundFlaggedAt: 'x' }), null);
  assert.equal(paymentMirrorPatch(booking, null), null);
  assert.equal(paymentMirrorPatch(cancelled(), { status: 'success' }), null);
});

test('notice text matches the app (English and Amharic default)', () => {
  const b = cancelled({ startAt: '2026-11-21T08:15:00.000Z' });
  assert.equal(addisWhen(b.startAt), '21/11/2026 11:15');
  const en = renderRefundDue(b, 300, 'en');
  assert.equal(en.title, 'Refund due');
  assert.equal(en.body, 'Your paid appointment on 21/11/2026 11:15 was cancelled. Fade Lab owes you a refund of ETB 300.00.');
  assert.equal(renderRefundDue(b, 300, undefined).title, 'ተመላሽ ገንዘብ አለዎት');
});

function fakeTx(booking: RefundBookingData | null, opts: { noticeExists?: boolean; payment?: Record<string, unknown> | null } = {}) {
  const writes: {
    booking?: Record<string, unknown>;
    notice?: { uid: string; id: string; data: Record<string, unknown> };
    payment?: { id: string; fields: Record<string, unknown> };
  } = {};
  return {
    writes,
    tx: {
      getBooking: async () => booking,
      getCutoffHours: async () => 2,
      getLanguage: async () => 'en',
      noticeExists: async () => opts.noticeExists ?? false,
      getPayment: async () => (opts.payment === undefined ? { status: 'success' } : opts.payment),
      updateBooking(fields: Record<string, unknown>) {
        writes.booking = fields;
      },
      createNotice(uid: string, id: string, data: Record<string, unknown>) {
        writes.notice = { uid, id, data };
      },
      updatePayment(id: string, fields: Record<string, unknown>) {
        writes.payment = { id, fields };
      },
    },
  };
}

test('flagRefundInTx flags, notifies and mirrors once', async () => {
  const { tx, writes } = fakeTx(cancelled());
  const out = await flagRefundInTx('b1', { now: NOW, cancelTransition: true }, tx);
  assert.equal(out.flagged?.refundAmount, 300);
  assert.deepEqual(writes.booking, {
    refundStatus: 'due',
    refundAmount: 300,
    refundReason: 'shop_cancelled',
    refundFlaggedAt: NOW.toISOString(),
  });
  assert.equal(writes.notice?.uid, 'cust_1');
  assert.equal(writes.notice?.id, 'b1_refundDue');
  assert.equal(writes.notice?.data.type, 'refundDue');
  assert.equal(writes.notice?.data.read, false);
  assert.deepEqual(Object.keys(writes.notice!.data).sort(), ['body', 'bookingId', 'createdAt', 'read', 'title', 'type']);
  assert.equal(writes.payment?.id, 'pay_1');
  assert.equal(writes.payment?.fields.refundStatus, 'due');
});

test('flagRefundInTx is idempotent: an already-flagged booking is only mirrored', async () => {
  const flagged = cancelled({
    refundStatus: 'due',
    refundAmount: 150,
    refundReason: 'customer_late_cancel',
    refundFlaggedAt: 'then',
  });
  const { tx, writes } = fakeTx(flagged, { payment: { refundStatus: 'due', refundAmount: 150, refundReason: 'customer_late_cancel', refundFlaggedAt: 'then' } });
  const out = await flagRefundInTx('b1', { now: NOW, cancelTransition: false }, tx);
  assert.deepEqual(out, { flagged: null, notified: false, mirrored: false });
  assert.deepEqual(writes, {});
});

test('flagRefundInTx skips an existing notice, unpaid bookings and missing docs', async () => {
  const a = fakeTx(cancelled(), { noticeExists: true, payment: null });
  const out = await flagRefundInTx('b1', { now: NOW, cancelTransition: false }, a.tx);
  assert.ok(out.flagged);
  assert.equal(a.writes.notice, undefined);
  assert.equal(a.writes.payment, undefined);

  const b = fakeTx(cancelled({ paymentStatus: 'unpaid', paymentId: undefined }));
  assert.deepEqual(await flagRefundInTx('b1', { now: NOW, cancelTransition: true }, b.tx), {
    flagged: null,
    notified: false,
    mirrored: false,
  });
  assert.deepEqual(b.writes, {});

  const c = fakeTx(null);
  assert.equal((await flagRefundInTx('b1', { now: NOW, cancelTransition: true }, c.tx)).flagged, null);
});

test('a late customer cancel seen as the cancel itself gets the late share', async () => {
  const { tx, writes } = fakeTx(cancelled({ cancelledBy: 'cust_1', startAt: hours(1).toISOString() }));
  await flagRefundInTx('b1', { now: NOW, cancelTransition: true }, tx);
  assert.equal(writes.booking?.refundReason, REFUND_REASONS.customerLateCancel);
  assert.equal(writes.booking?.refundAmount, 150);
});
