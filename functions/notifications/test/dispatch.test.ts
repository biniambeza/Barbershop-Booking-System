import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  deliverInApp,
  notifyBooking,
  notifyPayment,
  recipientsFor,
  resolveShopOwner,
  sendSmsOnce,
} from '../src/dispatch';
import type { BookingDoc, PaymentDoc } from '../src/events';
import type { SmsProvider, SmsResult } from '../src/sms';
import { FakeFirestore } from './fake-firestore';

class RecordingSms implements SmsProvider {
  readonly name = 'test';
  readonly sent: { to: string; message: string }[] = [];
  async send(to: string, message: string): Promise<SmsResult> {
    this.sent.push({ to, message });
    return { ok: true, providerId: String(this.sent.length) };
  }
}

const BOOKING_ID = 'bk1';
const booking: BookingDoc = {
  shopId: 'shop1',
  shopName: 'Bole Fade House',
  barberId: 'barber1',
  barberName: 'Dawit',
  customerId: 'cust1',
  customerName: 'Abebe',
  serviceName: 'Skin Fade',
  price: 1250,
  startAt: '2026-11-13T07:30:00.000Z',
  status: 'confirmed',
  paymentStatus: 'paid',
};

function seed(): FakeFirestore {
  return new FakeFirestore()
    .put('barbershops/shop1', { ownerId: 'owner1', name: 'Bole Fade House', phone: '+251911000000' })
    .put('users/cust1', { role: 'customer', phone: '+251911234567', language: 'en' })
    .put('users/owner1', { role: 'barbershopOwner', shopId: 'shop1', phone: '+251922222222', language: 'am' })
    .put('users/barberUser1', { role: 'barber', barberId: 'barber1', shopId: 'shop1', language: 'en' })
    .put('plans/pro', { name: 'Pro', priceMonthlyEtb: 1500 });
}

const inbox = (db: FakeFirestore, uid: string) => db.paths(`users/${uid}/notifications/`);

test('recipientsFor respects roles and de-duplicates', () => {
  const people = { customerUid: 'c', ownerUid: 'o', barberUids: ['b', 'o'], shopName: null };
  assert.deepEqual(recipientsFor(people, null).map((r) => `${r.uid}:${r.audience}`), ['c:customer', 'b:barber', 'o:barber']);
  assert.deepEqual(recipientsFor(people, null, ['customer', 'owner']).map((r) => r.uid), ['c', 'o']);
  assert.deepEqual(recipientsFor(people, 'c', ['customer']).map((r) => r.uid), []);
});

test('paymentReceived: customer + owner inbox, customer SMS, idempotent', async () => {
  const db = seed();
  const sms = new RecordingSms();
  await notifyBooking(BOOKING_ID, booking, 'paymentReceived', sms, { db: db.asFirestore() });
  await notifyBooking(BOOKING_ID, booking, 'paymentReceived', sms, { db: db.asFirestore() }); // retry

  assert.deepEqual(inbox(db, 'cust1'), ['users/cust1/notifications/bk1_paymentReceived']);
  assert.deepEqual(inbox(db, 'owner1'), ['users/owner1/notifications/bk1_paymentReceived']);
  assert.deepEqual(inbox(db, 'barberUser1'), []);

  const c = db.read('users/cust1/notifications/bk1_paymentReceived')!;
  assert.equal(c.title, 'Payment received');
  assert.match(String(c.body), /1,250 ETB/);
  assert.equal(c.bookingId, BOOKING_ID);
  const o = db.read('users/owner1/notifications/bk1_paymentReceived')!;
  assert.equal(o.title, 'ቀጠሮ ተከፍሏል');
  assert.match(String(o.body), /1,250 ብር/);

  assert.equal(sms.sent.length, 1);
  assert.equal(sms.sent[0].to, '+251911234567');
  assert.match(sms.sent[0].message, /Payment of 1,250 ETB received/);
  const log = db.read('notificationLog/bk1_paymentReceived_sms')!;
  assert.equal(log.status, 'sent');
  assert.equal(log.bookingId, BOOKING_ID);
});

test('paymentRefunded: customer only, no SMS', async () => {
  const db = seed();
  const sms = new RecordingSms();
  await notifyBooking(BOOKING_ID, { ...booking, paymentStatus: 'refunded' }, 'paymentRefunded', sms, { db: db.asFirestore() });
  assert.deepEqual(inbox(db, 'cust1'), ['users/cust1/notifications/bk1_paymentRefunded']);
  assert.deepEqual(inbox(db, 'owner1'), []);
  assert.equal(sms.sent.length, 0);
});

test('slotTaken: clear customer message + SMS, staff told, no generic cancel', async () => {
  const db = seed();
  const sms = new RecordingSms();
  const cancelled: BookingDoc = {
    ...booking,
    status: 'cancelled',
    paymentStatus: 'unpaid',
    cancelledBy: 'system',
    cancelReason: 'slot_conflict',
  };
  await notifyBooking(BOOKING_ID, cancelled, 'slotTaken', sms, { db: db.asFirestore() });

  const c = db.read('users/cust1/notifications/bk1_slotTaken')!;
  assert.equal(c.title, 'That time was just taken');
  assert.match(String(c.body), /Please book another time/);
  assert.ok(db.read('users/barberUser1/notifications/bk1_slotTaken'));
  assert.ok(db.read('users/owner1/notifications/bk1_slotTaken'));
  assert.equal(db.paths('users/').filter((p) => p.endsWith('_cancelled')).length, 0);
  assert.equal(sms.sent.length, 1);
  assert.match(sms.sent[0].message, /was just taken/);
});

test('paymentFailed: customer inbox keyed by payment id, no SMS, once per attempt', async () => {
  const db = seed().put(`bookings/${BOOKING_ID}`, { ...booking, paymentStatus: 'unpaid' });
  const sms = new RecordingSms();
  const payment: PaymentDoc = {
    type: 'booking', bookingId: BOOKING_ID, shopId: 'shop1', userId: 'cust1', amount: 1250, status: 'failed',
    failureReason: 'chapa_status_failed',
  };
  await notifyPayment('pay1', payment, 'paymentFailed', sms, { db: db.asFirestore() });
  await notifyPayment('pay1', payment, 'paymentFailed', sms, { db: db.asFirestore() }); // retry
  await notifyPayment('pay2', payment, 'paymentFailed', sms, { db: db.asFirestore() }); // new attempt

  assert.deepEqual(inbox(db, 'cust1'), [
    'users/cust1/notifications/pay1_paymentFailed',
    'users/cust1/notifications/pay2_paymentFailed',
  ]);
  const doc = db.read('users/cust1/notifications/pay1_paymentFailed')!;
  assert.equal(doc.title, 'Payment failed');
  assert.match(String(doc.body), /pay at the shop/);
  assert.match(String(doc.body), /Skin Fade at Bole Fade House/);
  assert.equal(doc.bookingId, BOOKING_ID);
  assert.equal(doc.paymentId, 'pay1');
  assert.deepEqual(inbox(db, 'owner1'), []);
  assert.equal(sms.sent.length, 0);
});

test('paymentFailed is skipped when the booking is already paid', async () => {
  const db = seed().put(`bookings/${BOOKING_ID}`, booking);
  const sms = new RecordingSms();
  await notifyPayment('pay1', { type: 'booking', bookingId: BOOKING_ID, userId: 'cust1', amount: 1250, status: 'failed' },
    'paymentFailed', sms, { db: db.asFirestore() });
  assert.deepEqual(inbox(db, 'cust1'), []);
});

test('subscriptionPaid: owner inbox + SMS in Amharic with plan, amount and period end', async () => {
  const db = seed();
  const sms = new RecordingSms();
  const payment: PaymentDoc = {
    type: 'subscription', shopId: 'shop1', userId: 'owner1', plan: 'pro', amount: 1500, status: 'success',
    periodEndsAt: '2026-12-13T07:30:00.000Z',
  };
  await notifyPayment('sub1', payment, 'subscriptionPaid', sms, { db: db.asFirestore() });
  await notifyPayment('sub1', payment, 'subscriptionPaid', sms, { db: db.asFirestore() }); // retry

  assert.deepEqual(inbox(db, 'owner1'), ['users/owner1/notifications/sub1_subscriptionPaid']);
  const doc = db.read('users/owner1/notifications/sub1_subscriptionPaid')!;
  assert.equal(doc.title, 'የደንበኝነት ክፍያ ደርሷል');
  assert.match(String(doc.body), /ለPro ዕቅድ/);
  assert.match(String(doc.body), /1,500 ብር/);
  assert.match(String(doc.body), /እሁድ 13\/12\/2026/);
  assert.equal(doc.paymentId, 'sub1');
  assert.equal(doc.bookingId, undefined);
  assert.equal(sms.sent.length, 1);
  assert.equal(sms.sent[0].to, '+251922222222');
  assert.equal(db.read('notificationLog/sub1_subscriptionPaid_sms')!.paymentId, 'sub1');
});

test('subscriptionFailed: owner found via users query when ownerId is empty; no SMS', async () => {
  const db = seed().put('barbershops/shop1', { ownerId: '', name: 'Bole Fade House' });
  const sms = new RecordingSms();
  await notifyPayment('sub2', { type: 'subscription', shopId: 'shop1', userId: 'someoneElse', plan: 'basic', amount: 800, status: 'failed' },
    'subscriptionFailed', sms, { db: db.asFirestore() });
  const doc = db.read('users/owner1/notifications/sub2_subscriptionFailed')!;
  assert.equal(doc.title, 'የደንበኝነት ክፍያ አልተሳካም');
  assert.match(String(doc.body), /ለBasic ዕቅድ/); // no plans/basic doc: id is capitalised
  assert.equal(sms.sent.length, 0);
});

test('resolveShopOwner falls back to the payer', async () => {
  const db = new FakeFirestore();
  const r = await resolveShopOwner(db.asFirestore(), 'nope', 'payer1');
  assert.equal(r.ownerUid, 'payer1');
});

test('deliverInApp and sendSmsOnce are idempotent per (entity, event)', async () => {
  const db = seed();
  const sms = new RecordingSms();
  const ctx = { shopName: 'S', barberName: 'B', customerName: 'C', serviceName: 'X', price: 10, start: null };
  const r = { uid: 'cust1', audience: 'customer' as const };
  assert.equal(await deliverInApp(db.asFirestore(), r, 'confirmed', 'bk9', ctx, 'en'), true);
  assert.equal(await deliverInApp(db.asFirestore(), r, 'confirmed', 'bk9', ctx, 'en'), false);
  assert.equal(await deliverInApp(db.asFirestore(), r, 'paymentReceived', 'bk9', ctx, 'en'), true);
  assert.equal(await sendSmsOnce(db.asFirestore(), sms, 'bk9', 'confirmed', '+251911234567', 'hi'), 'sent');
  assert.equal(await sendSmsOnce(db.asFirestore(), sms, 'bk9', 'confirmed', '+251911234567', 'hi'), 'duplicate');
  assert.equal(sms.sent.length, 1);
});

test('rescheduled: customer + barber + owner inbox, customer SMS, once per move', async () => {
  const db = seed();
  const sms = new RecordingSms();
  const moved: BookingDoc = { ...booking, startAt: '2026-11-14T08:00:00.000Z', rescheduleCount: 1, paymentStatus: 'unpaid' };
  const opts = { db: db.asFirestore(), entityId: 'bk1_r1', previousStart: new Date('2026-11-13T07:30:00.000Z') };
  await notifyBooking(BOOKING_ID, moved, 'rescheduled', sms, opts);
  await notifyBooking(BOOKING_ID, moved, 'rescheduled', sms, opts); // retry

  assert.deepEqual(inbox(db, 'cust1'), ['users/cust1/notifications/bk1_r1_rescheduled']);
  assert.deepEqual(inbox(db, 'barberUser1'), ['users/barberUser1/notifications/bk1_r1_rescheduled']);
  assert.deepEqual(inbox(db, 'owner1'), ['users/owner1/notifications/bk1_r1_rescheduled']);
  const c = db.read('users/cust1/notifications/bk1_r1_rescheduled')!;
  assert.equal(c.bookingId, BOOKING_ID);
  assert.equal(c.type, 'rescheduled');
  assert.match(String(c.body), /now on Sat 14 Nov 2026, 11:00\. \(It was Fri 13 Nov 2026, 10:30\.\)/);
  // The owner reads Amharic.
  assert.equal(db.read('users/owner1/notifications/bk1_r1_rescheduled')!.title, 'ቀጠሮ ተዛውሯል');

  assert.equal(sms.sent.length, 1);
  assert.match(sms.sent[0].message, /was moved to Sat 14 Nov 2026, 11:00/);
  assert.equal(db.read('notificationLog/bk1_r1_rescheduled_sms')!.bookingId, BOOKING_ID);

  // A second move is a new notification.
  await notifyBooking(BOOKING_ID, { ...moved, rescheduleCount: 2 }, 'rescheduled', sms, { ...opts, entityId: 'bk1_r2' });
  assert.equal(inbox(db, 'cust1').length, 2);
  assert.equal(sms.sent.length, 2);
});

test('noShow: customer inbox only, no SMS', async () => {
  const db = seed();
  const sms = new RecordingSms();
  await notifyBooking(BOOKING_ID, { ...booking, status: 'noShow' }, 'noShow', sms, { db: db.asFirestore() });
  assert.deepEqual(inbox(db, 'cust1'), ['users/cust1/notifications/bk1_noShow']);
  assert.deepEqual(inbox(db, 'owner1'), []);
  assert.deepEqual(inbox(db, 'barberUser1'), []);
  assert.equal(db.read('users/cust1/notifications/bk1_noShow')!.title, 'Missed appointment');
  assert.equal(sms.sent.length, 0);
});
