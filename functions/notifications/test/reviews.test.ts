import { test } from 'node:test';
import assert from 'node:assert/strict';

import type { Firestore } from 'firebase-admin/firestore';

import type { PushSender } from '../src/earlyFinish';
import {
  firstName,
  notifyNewReview,
  renderReviewNotice,
  reviewNotificationId,
  reviewRecipients,
  type ReviewDoc,
} from '../src/reviews';
import { FakeFirestore } from './fake-firestore';

const now = new Date('2026-11-20T07:00:00.000Z');
const CREATED = '2026-11-20T06:59:00.000Z';
const ID = 'review_bk1_20261120065900000';

const review: ReviewDoc = {
  bookingId: 'bk1',
  shopId: 'shop_1',
  barberId: 'barber_1',
  customerId: 'cust_1',
  customerName: 'Liya Getachew',
  rating: 4,
  createdAt: CREATED,
};

function seeded(): FakeFirestore {
  return new FakeFirestore()
    .put('barbershops/shop_1', { name: 'Crown Cuts', ownerId: 'owner_1' })
    .put('barbershops/shop_1/barbers/barber_1', { shopId: 'shop_1', name: 'Yonas' })
    .put('users/owner_1', { role: 'barbershopOwner', shopId: 'shop_1', language: 'en' })
    .put('users/barber_u1', { role: 'barber', shopId: 'shop_1', barberId: 'barber_1' })
    .put('users/other_shop', { role: 'barber', shopId: 'shop_9', barberId: 'barber_1' });
}

function recordingPush(): { push: PushSender; sent: { uid: string; title: string; data: Record<string, string> }[] } {
  const sent: { uid: string; title: string; data: Record<string, string> }[] = [];
  const push: PushSender = async (_db, uid, message, data) => {
    sent.push({ uid, title: message.title, data });
    return { sent: 1, removed: 0 };
  };
  return { push, sent };
}

test('ids, names and copy match the app', () => {
  assert.equal(reviewNotificationId('bk1', CREATED), ID);
  assert.equal(reviewNotificationId('bk1', '2026-11-20T06:59:00.123456Z'), 'review_bk1_20261120065900123456');
  assert.equal(firstName('  Liya  Getachew '), 'Liya');
  assert.equal(firstName(''), '');
  assert.deepEqual(renderReviewNotice(4, 'Liya Getachew', 'Yonas', 'en'), {
    title: 'New review ★★★★',
    body: 'Liya rated Yonas 4/5.',
  });
  assert.deepEqual(renderReviewNotice(5, '', '', 'en'), {
    title: 'New review ★★★★★',
    body: 'A customer rated their visit 5/5.',
  });
  assert.deepEqual(renderReviewNotice(3, 'ራሄል ደስታ', 'ዮናስ', 'am'), {
    title: 'አዲስ ግምገማ ★★★',
    body: 'ራሄል ለዮናስ 3/5 ሰጥተዋል።',
  });
});

test('recipients: owner first, then barbers, once each, never the reviewer', () => {
  assert.deepEqual(reviewRecipients('o', ['b1', 'o', 'b2', 'b1'], 'c'), ['o', 'b1', 'b2']);
  assert.deepEqual(reviewRecipients(undefined, ['c', ''], 'c'), []);
});

test('trigger: owner and the shop\'s barber get one inbox entry and one push each', async () => {
  const db = seeded();
  const fs = db.asFirestore() as Firestore;
  const { push, sent } = recordingPush();
  const result = await notifyNewReview(fs, 'shop_1', 'bk1', review, push, now);
  assert.deepEqual(result, { recipients: 2, pushed: 2 });
  assert.deepEqual(sent.map((s) => s.uid), ['owner_1', 'barber_u1']);
  const owner = db.read(`users/owner_1/notifications/${ID}`)!;
  assert.equal(owner.type, 'newReview');
  assert.equal(owner.title, 'New review ★★★★'); // English owner
  assert.equal(owner.body, 'Liya rated Yonas 4/5.');
  assert.equal(owner.bookingId, 'bk1');
  assert.equal(owner.rating, 4);
  assert.equal(owner.read, false);
  assert.equal(owner.createdAt, CREATED);
  assert.equal(typeof owner.pushedAt, 'string');
  // Unknown language: Amharic. A barber of another shop with the same id is skipped.
  assert.equal(db.read(`users/barber_u1/notifications/${ID}`)!.title, 'አዲስ ግምገማ ★★★★');
  assert.equal(db.read(`users/other_shop/notifications/${ID}`), undefined);

  // A retry pushes nothing new.
  assert.deepEqual(await notifyNewReview(fs, 'shop_1', 'bk1', review, push, now), { recipients: 2, pushed: 0 });
  assert.equal(sent.length, 2);
});

test('trigger: the entry the customer\'s app wrote is kept (read) and gets the owner\'s language', async () => {
  const db = seeded().put(`users/owner_1/notifications/${ID}`, {
    type: 'newReview',
    title: 'አዲስ ግምገማ ★★★★',
    body: 'Liya ለYonas 4/5 ሰጥተዋል።',
    bookingId: 'bk1',
    shopId: 'shop_1',
    barberId: 'barber_1',
    rating: 4,
    read: true,
    createdAt: CREATED,
  });
  const { push, sent } = recordingPush();
  await notifyNewReview(db.asFirestore() as Firestore, 'shop_1', 'bk1', review, push, now);
  const doc = db.read(`users/owner_1/notifications/${ID}`)!;
  assert.equal(doc.read, true);
  assert.equal(doc.title, 'New review ★★★★');
  assert.equal(sent.filter((s) => s.uid === 'owner_1').length, 1); // still one push, no second entry
  assert.deepEqual(db.paths('users/owner_1/notifications/'), [`users/owner_1/notifications/${ID}`]);
});

test('trigger: invalid or old reviews notify nobody', async () => {
  const fs = seeded().asFirestore() as Firestore;
  const { push, sent } = recordingPush();
  assert.equal((await notifyNewReview(fs, 'shop_1', 'bk1', null, push, now)).skipped, 'invalid');
  assert.equal((await notifyNewReview(fs, 'shop_1', 'bk1', { ...review, rating: 6 }, push, now)).skipped, 'invalid');
  const later = new Date(now.getTime() + 2 * 60 * 60 * 1000);
  assert.equal((await notifyNewReview(fs, 'shop_1', 'bk1', review, push, later)).skipped, 'stale');
  assert.equal(sent.length, 0);
});
