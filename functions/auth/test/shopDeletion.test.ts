import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  AuthAccount,
  BookingRow,
  cascadeShopDeletion,
  DeletionRecord,
  InviteRow,
  isOwnerCreatedLogin,
  NoticeDoc,
  shopDeletedText,
  shopRemovedText,
  ShopDeletionStore,
  UserRow,
} from '../src/logic/shopDeletion';

const NOW = new Date('2026-11-20T09:00:00.000Z');

interface World {
  record: DeletionRecord | null;
  bookings: Map<string, BookingRow & { cancelledBy?: string; cancelReason?: string }>;
  users: Map<string, UserRow & { barberId?: string }>;
  invites: Map<string, InviteRow & { shopId: string }>;
  notices: Map<string, NoticeDoc>; // `${uid}/${id}`
  shopDocs: string[];
  auth: Map<string, AuthAccount>;
  done: number;
}

function world(): World {
  return {
    record: { shopName: 'Crown Cuts', staffUids: ['owner', 'b1'], barberAccountUids: ['b1'] },
    bookings: new Map([
      ['past', { id: 'past', shopId: 's1', status: 'confirmed', startAt: '2026-11-19T09:00:00.000Z', customerId: 'c1' }],
      ['soon', { id: 'soon', shopId: 's1', status: 'pending', startAt: '2026-11-20T10:00:00.000Z', customerId: 'c1', shopName: 'Crown Cuts' }],
      ['later', { id: 'later', shopId: 's1', status: 'confirmed', startAt: '2026-11-21T07:30:00.000Z', customerId: 'c2' }],
      ['done', { id: 'done', shopId: 's1', status: 'completed', startAt: '2026-11-21T08:00:00.000Z', customerId: 'c2' }],
      ['other', { id: 'other', shopId: 's2', status: 'confirmed', startAt: '2026-11-21T08:00:00.000Z', customerId: 'c2' }],
    ]),
    users: new Map([
      ['owner', { uid: 'owner', role: 'barbershopOwner', shopId: 's1', language: 'en' }],
      ['b1', { uid: 'b1', role: 'barber', shopId: 's1', barberId: 'x1' }],
      ['b2', { uid: 'b2', role: 'barber', shopId: 's1', barberId: 'x2', language: 'en' }],
      ['c1', { uid: 'c1', role: 'customer', language: 'en' }],
      ['c2', { uid: 'c2', role: 'customer' }],
      ['other', { uid: 'other', role: 'barber', shopId: 's2' }],
    ]),
    invites: new Map([
      ['new@x.et', { email: 'new@x.et', role: 'barber', authUid: 'b3', shopId: 's1' }],
      ['keep@x.et', { email: 'keep@x.et', role: 'barber', shopId: 's2' }],
    ]),
    notices: new Map(),
    shopDocs: ['barbers/x1', 'barbers/x1/timeOff/t', 'services/a', 'queue/q'],
    auth: new Map([
      ['owner', { uid: 'owner', emailVerified: true, providerIds: ['google.com'] }],
      ['b1', { uid: 'b1', emailVerified: false, providerIds: ['password'] }], // owner-created
      ['b2', { uid: 'b2', emailVerified: true, providerIds: ['password'] }], // self-registered
      ['b3', { uid: 'b3', emailVerified: false, providerIds: ['password'] }], // pending invite login
    ]),
    done: 0,
  };
}

function storeOf(w: World): ShopDeletionStore {
  return {
    async getRecord() {
      return w.record;
    },
    async upcomingBookings(shopId, nowIso) {
      return [...w.bookings.values()].filter((b) => b.shopId === shopId && b.startAt! >= nowIso).map((b) => ({ ...b }));
    },
    async cancelBookings(items) {
      assert.ok(items.length <= 200);
      for (const { bookingId, notice } of items) {
        const b = w.bookings.get(bookingId)!;
        w.bookings.set(bookingId, { ...b, status: 'cancelled', cancelledBy: 'system', cancelReason: 'shop_deleted' });
        w.notices.set(`${notice.uid}/${notice.id}`, notice.doc);
      }
    },
    async usersOfShop(shopId) {
      return [...w.users.values()].filter((u) => u.shopId === shopId);
    },
    async getUsers(uids) {
      return uids.filter((u) => w.users.has(u)).map((u) => w.users.get(u)!);
    },
    async downgrade(items) {
      for (const { uid, notice } of items) {
        const u = w.users.get(uid)!;
        w.users.set(uid, { uid, role: 'customer', language: u.language });
        w.notices.set(`${notice.uid}/${notice.id}`, notice.doc);
      }
    },
    async invitesOfShop(shopId) {
      return [...w.invites.values()].filter((i) => i.shopId === shopId);
    },
    async deleteInvites(emails) {
      for (const e of emails) w.invites.delete(e);
    },
    async deleteShopTree() {
      w.shopDocs = [];
    },
    async getAuthAccount(uid) {
      return w.auth.get(uid) ?? null;
    },
    async deleteAuthAccount(uid) {
      w.auth.delete(uid);
    },
    async deleteUserProfile(uid) {
      w.users.delete(uid);
    },
    async markDone() {
      w.done++;
    },
  };
}

test('cancels upcoming bookings, downgrades staff, deletes data and owner-created logins', async () => {
  const w = world();
  const result = await cascadeShopDeletion('s1', undefined, storeOf(w), NOW);

  assert.equal(result.cancelledBookings, 2);
  assert.equal(w.bookings.get('soon')!.status, 'cancelled');
  assert.equal(w.bookings.get('soon')!.cancelReason, 'shop_deleted');
  assert.equal(w.bookings.get('later')!.status, 'cancelled');
  assert.equal(w.bookings.get('past')!.status, 'confirmed'); // history kept
  assert.equal(w.bookings.get('done')!.status, 'completed');
  assert.equal(w.bookings.get('other')!.status, 'confirmed'); // other shop

  const c1 = w.notices.get('c1/soon_shopDeleted')!;
  assert.equal(c1.type, 'shopDeleted');
  assert.equal(c1.bookingId, 'soon');
  assert.equal(c1.title, 'Appointment cancelled');
  assert.match(c1.body, /20\/11\/2026 13:00/); // Addis wall clock
  assert.equal(w.notices.get('c2/later_shopDeleted')!.title, 'ቀጠሮዎ ተሰርዟል');

  assert.equal(result.downgradedStaff, 3);
  assert.deepEqual(w.users.get('owner'), { uid: 'owner', role: 'customer', language: 'en' });
  assert.equal(w.users.get('b2')!.role, 'customer');
  assert.equal(w.users.get('other')!.role, 'barber'); // other shop untouched
  assert.equal(w.notices.get('owner/shopRemoved_s1')!.title, 'Your barbershop was removed');
  assert.equal(w.notices.get('owner/shopRemoved_s1')!.shopId, 's1');

  assert.deepEqual([...w.invites.keys()], ['keep@x.et']);
  assert.deepEqual(w.shopDocs, []);

  // Owner-created (unverified, password-only) logins only.
  assert.deepEqual(result.deletedLogins.sort(), ['b1', 'b3']);
  assert.ok(!w.auth.has('b1') && !w.auth.has('b3'));
  assert.ok(w.auth.has('owner') && w.auth.has('b2'));
  assert.ok(!w.users.has('b1'));
  assert.equal(w.done, 1);
});

test('is idempotent: a second run (or a run after the app cascade) changes nothing more', async () => {
  const w = world();
  await cascadeShopDeletion('s1', 'Crown Cuts', storeOf(w), NOW);
  const notices = w.notices.size;
  const again = await cascadeShopDeletion('s1', 'Crown Cuts', storeOf(w), NOW);
  assert.equal(again.cancelledBookings, 0);
  assert.equal(again.downgradedStaff, 0);
  assert.equal(again.deletedInvites, 0);
  assert.deepEqual(again.deletedLogins, []);
  assert.equal(w.notices.size, notices);
});

test('after the admin app already downgraded the staff, the record still finds the barber login', async () => {
  const w = world();
  for (const uid of ['owner', 'b1', 'b2']) w.users.set(uid, { uid, role: 'customer' });
  w.invites.clear();
  const result = await cascadeShopDeletion('s1', undefined, storeOf(w), NOW);
  assert.equal(result.downgradedStaff, 0);
  assert.deepEqual(result.deletedLogins, ['b1']);
});

test('isOwnerCreatedLogin', () => {
  assert.equal(isOwnerCreatedLogin({ uid: 'a', emailVerified: false, providerIds: ['password'] }), true);
  assert.equal(isOwnerCreatedLogin({ uid: 'a', emailVerified: true, providerIds: ['password'] }), false);
  assert.equal(isOwnerCreatedLogin({ uid: 'a', emailVerified: false, providerIds: ['password', 'google.com'] }), false);
  assert.equal(isOwnerCreatedLogin({ uid: 'a', emailVerified: false, providerIds: [] }), false);
});

test('texts match the app (lib/services/shop_deletion.dart)', () => {
  assert.deepEqual(shopRemovedText('  ', 'en'), {
    title: 'Your barbershop was removed',
    body: 'Your barbershop was removed from Crown & Blade. You can keep using the app as a customer.',
  });
  assert.equal(shopRemovedText('Crown Cuts').title, 'ፀጉር ቤትዎ ተወግዷል');
  assert.equal(
    shopDeletedText('2026-11-21T07:30:00.000Z', 'Crown Cuts', 'en').body,
    'Crown Cuts is no longer on Crown & Blade, so your appointment on 21/11/2026 10:30 was cancelled. Please book at another barbershop.',
  );
});
