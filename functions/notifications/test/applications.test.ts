import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  applicationNotificationId,
  detectApplicationEvent,
  notifyApplication,
  renderApplicationNotification,
  type ShopApplicationDoc,
} from '../src/applications';
import { FakeFirestore } from './fake-firestore';

const pending: ShopApplicationDoc = {
  uid: 'cust1',
  email: 'abebe@example.com',
  ownerName: 'Abebe',
  shopName: 'Bole Fade House',
  status: 'pending',
  createdAt: '2026-11-10T08:00:00.000Z',
};
const approved: ShopApplicationDoc = {
  ...pending,
  status: 'approved',
  reviewedBy: 'admin1',
  reviewedAt: '2026-11-12T09:00:00.000Z',
  shopId: 'shop9',
};
const rejected: ShopApplicationDoc = {
  ...pending,
  status: 'rejected',
  reviewedBy: 'admin1',
  reviewedAt: '2026-11-12T09:00:00.000Z',
  rejectReason: 'Please add the street address.',
};

test('detects approval and rejection only on a status change', () => {
  assert.equal(detectApplicationEvent(pending, approved), 'applicationApproved');
  assert.equal(detectApplicationEvent(pending, rejected), 'applicationRejected');
  assert.equal(detectApplicationEvent(null, pending), null);
  assert.equal(detectApplicationEvent(pending, { ...pending, shopName: 'New name' }), null);
  assert.equal(detectApplicationEvent(approved, { ...approved }), null);
  assert.equal(detectApplicationEvent(pending, null), null);
  // Resubmitted after a rejection: silent until decided again.
  assert.equal(detectApplicationEvent(rejected, { ...pending, createdAt: '2026-11-13T08:00:00.000Z' }), null);
});

test('inbox id is per decision', () => {
  assert.equal(applicationNotificationId(approved, 'applicationApproved'), `application_${Date.parse(approved.reviewedAt!)}_applicationApproved`);
  assert.equal(applicationNotificationId({ ...rejected, reviewedAt: undefined }, 'applicationRejected'), 'application_0_applicationRejected');
});

test('renders English and Amharic copy with shop name and reason', () => {
  const en = renderApplicationNotification('applicationApproved', 'en', approved);
  assert.match(en.body, /Bole Fade House/);
  const am = renderApplicationNotification('applicationRejected', 'am', rejected);
  assert.match(am.body, /Please add the street address\./);
  assert.match(am.title, /አልጸደቀም/);
  const noReason = renderApplicationNotification('applicationRejected', 'en', { ...rejected, rejectReason: undefined });
  assert.doesNotMatch(noReason.body, /Reason/);
});

test('notifyApplication writes one inbox entry in the user language', async () => {
  const db = new FakeFirestore().put('users/cust1', { role: 'customer', language: 'am' });
  assert.equal(await notifyApplication(db.asFirestore(), 'cust1', approved, 'applicationApproved'), true);
  const id = applicationNotificationId(approved, 'applicationApproved');
  const doc = db.read(`users/cust1/notifications/${id}`)!;
  assert.equal(doc.type, 'applicationApproved');
  assert.equal(doc.shopId, 'shop9');
  assert.equal(doc.read, false);
  assert.match(String(doc.title), /ጸድቋል/);
  // Retry: no duplicate.
  assert.equal(await notifyApplication(db.asFirestore(), 'cust1', approved, 'applicationApproved'), false);
  assert.equal(db.paths('users/cust1/notifications/').length, 1);
});

test('rejection carries no shopId; a missing user is skipped', async () => {
  const db = new FakeFirestore().put('users/cust1', { role: 'customer' });
  assert.equal(await notifyApplication(db.asFirestore(), 'cust1', rejected, 'applicationRejected'), true);
  const [path] = db.paths('users/cust1/notifications/');
  const doc = db.read(path)!;
  assert.equal(doc.shopId, undefined);
  assert.match(String(doc.body), /Reason: Please add the street address\./);
  assert.equal(await notifyApplication(db.asFirestore(), 'ghost', rejected, 'applicationRejected'), false);
});
