import { test } from 'node:test';
import assert from 'node:assert/strict';

import type { Firestore } from 'firebase-admin/firestore';

import type { BookingDoc } from '../src/events';
import {
  EARLY_FINISH_MAX_MINUTES,
  earlyFinishNotificationId,
  isCompletionTransition,
  isSameAddisDay,
  minutesEarly,
  notifyEarlyFinish,
  planEarlyFinish,
  renderEarlyFinish,
  selectEarlyFinishRecipients,
  type BookingRef,
  type PushSender,
} from '../src/earlyFinish';
import { FakeFirestore } from './fake-firestore';

const MIN = 60 * 1000;
/** Fri 20 Nov 2026 at hh:mm on the Addis wall clock (+dayOffset). */
const addis = (h: number, m: number, dayOffset = 0) =>
  new Date(Date.UTC(2026, 10, 20 + dayOffset, h, m) - 3 * 60 * MIN);
const now = addis(10, 0); // 07:00 UTC

function booking(start: Date, extra: Partial<BookingDoc> = {}, minutes = 30): BookingDoc {
  return {
    shopId: 'shop_1',
    shopName: 'Crown Cuts',
    barberId: 'barber_1',
    barberName: 'Yonas',
    customerId: 'cust',
    serviceName: 'Skin Fade',
    status: 'confirmed',
    startAt: start.toISOString(),
    endAt: new Date(start.getTime() + minutes * MIN).toISOString(),
    durationMinutes: minutes,
    ...extra,
  };
}

const SOURCE_ID = 'src';
const source = booking(addis(9, 40), { status: 'completed', customerId: 'c_src', completedAt: now.toISOString() }, 50);

function day(): BookingRef[] {
  const ref = (id: string, start: Date, extra: Partial<BookingDoc> = {}): BookingRef => ({
    id,
    data: booking(start, { customerId: `cust_${id}`, ...extra }),
  });
  return [
    { id: SOURCE_ID, data: source },
    ref('b1400', addis(14, 0)), // 6th: over the limit
    ref('b1030', addis(10, 30)),
    ref('b1300', addis(13, 0)),
    ref('b1100', addis(11, 0)),
    ref('b1230', addis(12, 30)),
    ref('b1330', addis(13, 30)),
    ref('pending', addis(11, 30), { status: 'pending' }),
    ref('cancelled', addis(12, 0), { status: 'cancelled' }),
    ref('otherBarber', addis(10, 45), { barberId: 'barber_2' }),
    ref('otherShop', addis(10, 50), { shopId: 'shop_2' }),
    ref('earlier', addis(8, 0)),
    ref('tomorrow', addis(9, 0, 1)),
    ref('noCustomer', addis(15, 0), { customerId: '' }),
  ];
}

const EXPECTED = ['b1030', 'b1100', 'b1230', 'b1300', 'b1330'];

test('minutes early: rounded down to 5 and clamped', () => {
  const end = addis(10, 30);
  assert.equal(minutesEarly(end, addis(10, 0)), 30);
  assert.equal(minutesEarly(end, addis(10, 3)), 25);
  assert.equal(minutesEarly(end, addis(10, 28)), 0);
  assert.equal(minutesEarly(end, addis(10, 45)), 0);
  assert.equal(minutesEarly(addis(20, 0), addis(9, 0)), EARLY_FINISH_MAX_MINUTES);
});

test('completion transitions only', () => {
  assert.equal(isCompletionTransition({ status: 'inProgress' }, { status: 'completed' }), true);
  assert.equal(isCompletionTransition(null, { status: 'completed' }), true);
  assert.equal(isCompletionTransition({ status: 'completed' }, { status: 'completed' }), false);
  assert.equal(isCompletionTransition({ status: 'confirmed' }, { status: 'cancelled' }), false);
});

test('selection: same barber + shop, confirmed, later the same Addis day, soonest first, max 5', () => {
  const picked = selectEarlyFinishRecipients(SOURCE_ID, source, day(), now).map((r) => r.id);
  assert.deepEqual(picked, EXPECTED);
});

test('the Addis day is UTC+3', () => {
  assert.equal(isSameAddisDay(addis(23, 30), addis(0, 30, 1)), false); // same UTC day
  assert.equal(isSameAddisDay(addis(0, 30), addis(23, 30)), true); // different UTC days
});

test('plan: next customer barberFreeEarly, others runningEarly, idempotent ids', () => {
  const plans = planEarlyFinish(SOURCE_ID, source, day(), now);
  assert.deepEqual(plans.map((p) => p.bookingId), EXPECTED);
  assert.equal(plans[0].type, 'barberFreeEarly');
  assert.deepEqual([...new Set(plans.slice(1).map((p) => p.type))], ['runningEarly']);
  assert.equal(plans[0].id, 'b1030_early_src');
  assert.equal(earlyFinishNotificationId('b1030', 'src'), 'b1030_early_src');
  assert.equal(plans[0].recipientUid, 'cust_b1030');
  assert.equal(plans[0].minutesEarly, 30);
  assert.equal(plans[0].createdAt, '2026-11-20T07:00:00.000Z');
  // On time / late: nothing.
  assert.deepEqual(planEarlyFinish(SOURCE_ID, source, day(), addis(10, 30)), []);
  assert.deepEqual(planEarlyFinish(SOURCE_ID, source, day(), addis(10, 40)), []);
});

test('copy matches the app (EN + AM)', () => {
  const b = booking(addis(10, 30));
  assert.deepEqual(renderEarlyFinish('barberFreeEarly', b, 30, 'en'), {
    title: 'Your barber is free now',
    body: 'Yonas at Crown Cuts is free now — you can come in early for your 10:30 appointment.',
  });
  assert.equal(
    renderEarlyFinish('runningEarly', booking(addis(13, 0)), 25, 'en').body,
    'Yonas is running about 25 min ahead of schedule today; your 13:00 appointment may start earlier.',
  );
  const am = renderEarlyFinish('runningEarly', booking(addis(11, 0)), 30, 'am');
  assert.equal(am.title, 'ከፕሮግራሙ ቀድመው እየሰሩ ነው');
  assert.ok(am.body.includes('30 ደቂቃ'));
  assert.ok(am.body.includes('11:00 (ጠዋት 5:00)'));
});

function seeded(): FakeFirestore {
  const db = new FakeFirestore();
  for (const r of day()) db.put(`bookings/${r.id}`, r.data as Record<string, unknown>);
  db.put('users/cust_b1030', { language: 'en' });
  db.put('users/cust_b1100', { language: 'am' });
  return db;
}

function recordingPush(): { push: PushSender; sent: { uid: string; title: string; data: Record<string, string> }[] } {
  const sent: { uid: string; title: string; data: Record<string, string> }[] = [];
  const push: PushSender = async (_db, uid, message, data) => {
    sent.push({ uid, title: message.title, data });
    return { sent: 1, removed: 0 };
  };
  return { push, sent };
}

test('trigger: inbox docs + one push each, idempotent across retries', async () => {
  const db = seeded();
  const { push, sent } = recordingPush();
  const before = { ...source, status: 'inProgress' };
  const fs = db.asFirestore() as Firestore;

  const first = await notifyEarlyFinish(fs, SOURCE_ID, before, source, push, new Date(now.getTime() + MIN));
  assert.deepEqual(first, { planned: 5, pushed: 5 });
  assert.deepEqual(
    sent.map((s) => s.uid),
    EXPECTED.map((id) => `cust_${id}`),
  );
  const next = db.read('users/cust_b1030/notifications/b1030_early_src')!;
  assert.equal(next.type, 'barberFreeEarly');
  assert.equal(next.title, 'Your barber is free now'); // English user
  assert.equal(next.sourceBookingId, 'src');
  assert.equal(next.minutesEarly, 30);
  assert.equal(next.read, false);
  assert.equal(typeof next.pushedAt, 'string');
  assert.equal(sent[0].data.notificationId, 'b1030_early_src');
  // Unknown language: Amharic.
  assert.equal(db.read('users/cust_b1230/notifications/b1230_early_src')!.title, 'ከፕሮግራሙ ቀድመው እየሰሩ ነው');

  const again = await notifyEarlyFinish(fs, SOURCE_ID, before, source, push, new Date(now.getTime() + 2 * MIN));
  assert.deepEqual(again, { planned: 5, pushed: 0 });
  assert.equal(sent.length, 5);
});

test('trigger: a doc already written by the staff app is kept (read state) and gets the right language', async () => {
  const db = seeded();
  db.put('users/cust_b1030/notifications/b1030_early_src', {
    type: 'barberFreeEarly',
    title: 'ፀጉር አስተካካይዎ አሁን ነፃ ናቸው',
    body: 'am',
    bookingId: 'b1030',
    shopId: 'shop_1',
    barberId: 'barber_1',
    sourceBookingId: 'src',
    minutesEarly: 30,
    read: true,
    createdAt: now.toISOString(),
  });
  const { push, sent } = recordingPush();
  await notifyEarlyFinish(db.asFirestore() as Firestore, SOURCE_ID, { status: 'inProgress' }, source, push, now);
  const doc = db.read('users/cust_b1030/notifications/b1030_early_src')!;
  assert.equal(doc.read, true);
  assert.equal(doc.title, 'Your barber is free now');
  assert.equal(typeof doc.pushedAt, 'string');
  assert.equal(sent.length, 5);
});

test('trigger: nothing when on time, late, stale or not a completion', async () => {
  const { push, sent } = recordingPush();
  const fs = seeded().asFirestore() as Firestore;
  const onTime = { ...source, completedAt: addis(10, 30).toISOString() };
  assert.equal((await notifyEarlyFinish(fs, SOURCE_ID, { status: 'inProgress' }, onTime, push, addis(10, 31))).skipped, 'not-early');
  const late = { ...source, completedAt: addis(10, 50).toISOString() };
  assert.equal((await notifyEarlyFinish(fs, SOURCE_ID, { status: 'inProgress' }, late, push, addis(10, 51))).skipped, 'not-early');
  assert.equal((await notifyEarlyFinish(fs, SOURCE_ID, { status: 'inProgress' }, source, push, addis(11, 0))).skipped, 'stale');
  assert.equal((await notifyEarlyFinish(fs, SOURCE_ID, { status: 'completed' }, source, push, now)).skipped, 'not-completed');
  assert.equal(sent.length, 0);
});
