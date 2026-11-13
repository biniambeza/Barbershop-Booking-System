import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  ALL_NOTIFICATION_TYPES,
  RECIPIENT_ROLES,
  SMS_TYPES,
  deriveCancelActor,
  detectBookingEvent,
  detectBookingEvents,
  detectBookingPaymentEvent,
  detectPaymentEvent,
  detectReschedule,
  rescheduleEntityId,
  smsRecipientRole,
  staleReminderFlags,
} from '../src/events';

test('create: pending -> created, confirmed -> confirmed', () => {
  assert.equal(detectBookingEvent(null, { status: 'pending' }), 'created');
  assert.equal(detectBookingEvent(undefined, { status: 'confirmed' }), 'confirmed');
  assert.equal(detectBookingEvent(null, {}), 'created');
  assert.equal(detectBookingEvent(null, { status: 'cancelled' }), null);
});

test('update: status transitions map to events', () => {
  const cases: [string, string, string | null][] = [
    ['pending', 'confirmed', 'confirmed'],
    ['pending', 'cancelled', 'cancelled'],
    ['confirmed', 'cancelled', 'cancelled'],
    ['confirmed', 'inProgress', 'started'],
    ['inProgress', 'completed', 'completed'],
    ['confirmed', 'completed', 'completed'],
    ['confirmed', 'pending', null],
  ];
  for (const [from, to, expected] of cases) {
    assert.equal(detectBookingEvent({ status: from }, { status: to }), expected, `${from} -> ${to}`);
  }
});

test('update without status change (reminder flags, payment) is ignored', () => {
  assert.equal(
    detectBookingEvent(
      { status: 'confirmed' },
      { status: 'confirmed', reminder24hSentAt: '2026-11-13T07:00:00.000Z', paymentStatus: 'paid' },
    ),
    null,
  );
});

test('delete is ignored', () => {
  assert.equal(detectBookingEvent({ status: 'confirmed' }, null), null);
});

test('cancel actor from cancelledBy uid', () => {
  const people = { barberUids: ['b1'], ownerUid: 'o1', isAdmin: (uid: string) => uid === 'a1' };
  const base = { customerId: 'c1', status: 'cancelled' };
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'c1' }, people), 'customer');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'b1' }, people), 'barber');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'o1' }, people), 'shop');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'a1' }, people), 'admin');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'zzz' }, people), 'unknown');
  assert.equal(deriveCancelActor(base, people), 'unknown');
  assert.equal(deriveCancelActor({ ...base, cancelledBy: 'system' }, people), 'system');
});

test('SMS only for the booking essentials, booking payment success and subscription success', () => {
  assert.deepEqual([...SMS_TYPES].sort(), [
    'cancelled', 'confirmed', 'paymentReceived', 'reminder24h', 'reminder2h', 'rescheduled', 'slotTaken', 'subscriptionPaid',
  ]);
  assert.equal(smsRecipientRole('rescheduled'), 'customer');
  assert.equal(smsRecipientRole('noShow'), null);
  assert.equal(smsRecipientRole('paymentReceived'), 'customer');
  assert.equal(smsRecipientRole('subscriptionPaid'), 'owner');
  assert.equal(smsRecipientRole('paymentFailed'), null);
  assert.equal(smsRecipientRole('subscriptionFailed'), null);
  assert.equal(smsRecipientRole('paymentRefunded'), null);
});

test('payment recipients', () => {
  assert.deepEqual(RECIPIENT_ROLES.paymentReceived, ['customer', 'owner']);
  assert.deepEqual(RECIPIENT_ROLES.paymentRefunded, ['customer']);
  assert.deepEqual(RECIPIENT_ROLES.paymentFailed, ['customer']);
  assert.deepEqual(RECIPIENT_ROLES.subscriptionPaid, ['owner']);
  assert.deepEqual(RECIPIENT_ROLES.subscriptionFailed, ['owner']);
  assert.equal(Object.keys(RECIPIENT_ROLES).length, ALL_NOTIFICATION_TYPES.length);
});

test('slot conflict cancel -> slotTaken instead of cancelled', () => {
  const before = { status: 'pending' };
  assert.equal(
    detectBookingEvent(before, { status: 'cancelled', cancelledBy: 'system', cancelReason: 'slot_conflict' }),
    'slotTaken',
  );
  // other system cancels and other reasons stay generic
  assert.equal(detectBookingEvent(before, { status: 'cancelled', cancelledBy: 'system', cancelReason: 'expired' }), 'cancelled');
  assert.equal(detectBookingEvent(before, { status: 'cancelled', cancelledBy: 'c1', cancelReason: 'slot_conflict' }), 'cancelled');
  assert.deepEqual(
    detectBookingEvents(before, { status: 'cancelled', cancelledBy: 'system', cancelReason: 'slot_conflict' }),
    ['slotTaken'],
  );
});

test('booking paymentStatus changes', () => {
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'pending' }, { paymentStatus: 'paid' }), 'paymentReceived');
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'unpaid' }, { paymentStatus: 'paid' }), 'paymentReceived');
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'paid' }, { paymentStatus: 'refunded' }), 'paymentRefunded');
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'unpaid' }, { paymentStatus: 'pending' }), null);
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'pending' }, { paymentStatus: 'unpaid' }), null);
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'paid' }, { paymentStatus: 'paid' }), null);
  assert.equal(detectBookingPaymentEvent(null, { paymentStatus: 'paid' }), null);
  assert.equal(detectBookingPaymentEvent({ paymentStatus: 'paid' }, null), null);
});

test('paymentStatus-only write yields only the payment event', () => {
  assert.deepEqual(
    detectBookingEvents(
      { status: 'confirmed', paymentStatus: 'pending' },
      { status: 'confirmed', paymentStatus: 'paid', paidAt: '2026-11-13T07:00:00.000Z' },
    ),
    ['paymentReceived'],
  );
  assert.deepEqual(
    detectBookingEvents({ status: 'completed', paymentStatus: 'paid' }, { status: 'completed', paymentStatus: 'refunded' }),
    ['paymentRefunded'],
  );
  assert.deepEqual(detectBookingEvents({ status: 'confirmed', paymentStatus: 'pending' }, { status: 'confirmed', paymentStatus: 'unpaid' }), []);
  // both in one write: both events, each with its own key
  assert.deepEqual(
    detectBookingEvents({ status: 'inProgress', paymentStatus: 'unpaid' }, { status: 'completed', paymentStatus: 'paid' }),
    ['completed', 'paymentReceived'],
  );
});

test('payments/{id} events', () => {
  const b = { type: 'booking', bookingId: 'bk1' };
  const s = { type: 'subscription', shopId: 'shop1' };
  assert.equal(detectPaymentEvent({ ...b, status: 'pending' }, { ...b, status: 'failed' }), 'paymentFailed');
  assert.equal(detectPaymentEvent({ ...b, status: 'pending' }, { ...b, status: 'success' }), null); // reported via booking
  assert.equal(detectPaymentEvent({ ...b, status: 'failed' }, { ...b, status: 'failed', verifiedAt: 'x' }), null);
  assert.equal(detectPaymentEvent(null, { ...b, status: 'pending' }), null);
  // Checkout never started (Chapa initialize failed): not a declined payment.
  assert.equal(
    detectPaymentEvent({ ...b, status: 'pending' }, { ...b, status: 'failed', failureReason: 'checkout_init_failed' }),
    null,
  );
  assert.equal(detectPaymentEvent({ ...s, status: 'pending' }, { ...s, status: 'success' }), 'subscriptionPaid');
  assert.equal(detectPaymentEvent({ ...s, status: 'failed' }, { ...s, status: 'success' }), 'subscriptionPaid');
  assert.equal(detectPaymentEvent({ ...s, status: 'pending' }, { ...s, status: 'failed' }), 'subscriptionFailed');
  assert.equal(detectPaymentEvent({ ...s, status: 'success' }, { ...s, status: 'success', refundedAt: 'x' }), null);
  assert.equal(detectPaymentEvent({ ...s, status: 'pending' }, null), null);
});

test('noShow: status event for the customer only, no SMS', () => {
  assert.equal(detectBookingEvent({ status: 'confirmed' }, { status: 'noShow' }), 'noShow');
  assert.equal(detectBookingEvent({ status: 'noShow' }, { status: 'noShow' }), null);
  assert.deepEqual(RECIPIENT_ROLES.noShow, ['customer']);
  assert.equal(SMS_TYPES.has('noShow'), false);
});

test('reschedule: startAt moved on a live booking', () => {
  const before = { status: 'confirmed', startAt: '2026-11-20T07:00:00.000Z', rescheduleCount: 0 };
  const after = { ...before, startAt: '2026-11-21T08:15:00.000Z', endAt: '2026-11-21T08:45:00.000Z', rescheduleCount: 1 };
  assert.equal(detectReschedule(before, after), 'rescheduled');
  assert.deepEqual(detectBookingEvents(before, after), ['rescheduled']);
  assert.deepEqual(RECIPIENT_ROLES.rescheduled, ['customer', 'barber', 'owner']);
  // Same instant, other writes, cancels and creates are not reschedules.
  assert.equal(detectReschedule(before, { ...before, reminder2hSentAt: 'x' }), null);
  assert.equal(
    detectReschedule(before, { ...after, status: 'cancelled', cancelledBy: 'system', cancelReason: 'slot_conflict' }),
    null,
  );
  assert.equal(detectReschedule(null, after), null);
  assert.equal(detectReschedule({ status: 'pending' }, { status: 'pending', startAt: after.startAt }), null);
});

test('reschedule idempotency key: one per move', () => {
  assert.equal(rescheduleEntityId('bk1', { rescheduleCount: 2 }), 'bk1_r2');
  assert.equal(
    rescheduleEntityId('bk1', { startAt: '2026-11-21T08:15:00.000Z' }),
    `bk1_r${Date.parse('2026-11-21T08:15:00.000Z')}`,
  );
});

test('staleReminderFlags: only reminders sent before the reschedule', () => {
  assert.deepEqual(
    staleReminderFlags({
      rescheduledAt: '2026-11-20T09:00:00.000Z',
      reminder24hSentAt: '2026-11-20T07:00:00.000Z',
      reminder2hSentAt: '2026-11-20T09:30:00.000Z',
    }),
    ['reminder24hSentAt'],
  );
  assert.deepEqual(staleReminderFlags({ reminder2hSentAt: '2026-11-20T09:30:00.000Z' }), ['reminder2hSentAt']);
  assert.deepEqual(staleReminderFlags({ rescheduledAt: '2026-11-20T09:00:00.000Z' }), []);
});
