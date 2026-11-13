// Security rules tests. Run from this folder with `npm test`
// (starts the Firestore emulator; needs Java).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  deleteField,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const NOW = new Date().toISOString();

// --- Addis time helpers (UTC+3, no DST), mirroring lib/data/addis_time.dart
// and lib/services/availability_service.dart. ---
const ADDIS_MS = 3 * 3600 * 1000;
const pad = (n) => String(n).padStart(2, '0');

// UTC ISO instant of an Addis wall-clock time `days` days after today.
function addisSlot(days, hour, minute = 0) {
  const a = new Date(Date.now() + ADDIS_MS);
  return new Date(Date.UTC(a.getUTCFullYear(), a.getUTCMonth(), a.getUTCDate() + days, hour, minute) - ADDIS_MS).toISOString();
}

function plusMinutes(iso, minutes) {
  return new Date(Date.parse(iso) + minutes * 60000).toISOString();
}

// Slot-lock id: Addis yyyyMMdd-HHmm of a block start.
function lockId(iso) {
  const a = new Date(Date.parse(iso) + ADDIS_MS);
  return `${a.getUTCFullYear()}${pad(a.getUTCMonth() + 1)}${pad(a.getUTCDate())}-${pad(a.getUTCHours())}${pad(a.getUTCMinutes())}`;
}

// Block starts covered by [startAt, startAt + minutes).
function blocks(startAt, minutes) {
  const out = [];
  for (let m = 0; m < minutes; m += 15) out.push(plusMinutes(startAt, m));
  return out;
}

// Default appointment: 3 days ahead, 10:00 Addis, 40 minutes (srv1).
const START = addisSlot(3, 10, 0);
const BK1_END = plusMinutes(START, 40);

const PHONES = {
  admin: '+251911000001',
  owner1: '+251911000101',
  owner2: '+251911000102',
  barber1: '+251911000201',
  barber2: '+251911000202',
  customer: '+251911000301',
  customer2: '+251911000302',
  newPerson: '+251933445566',
};

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-crownblade',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (uid, phone, role, extra = {}) =>
      setDoc(doc(db, 'users', uid), { uid, name: uid, phone, role, createdAt: NOW, ...extra });

    await user('admin', PHONES.admin, 'admin');
    await user('owner1', PHONES.owner1, 'barbershopOwner', { shopId: 'shop1' });
    await user('owner2', PHONES.owner2, 'barbershopOwner', { shopId: 'shop2' });
    await user('barber1', PHONES.barber1, 'barber', { shopId: 'shop1', barberId: 'b1' });
    await user('barber2', PHONES.barber2, 'barber', { shopId: 'shop1', barberId: 'b2' });
    await user('customer', PHONES.customer, 'customer');
    await user('customer2', PHONES.customer2, 'customer');

    await setDoc(doc(db, 'barbershops', 'shop1'), { ...shop('owner1'), subscriptionStatus: 'active' });
    await setDoc(doc(db, 'barbershops', 'shop2'), { ...shop('owner2'), subscriptionStatus: 'active' });
    // Registered, owner not signed in yet; a legacy doc without subscription fields.
    await setDoc(doc(db, 'barbershops', 'shop3'), shop(''));

    await setDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), barber('shop1', 'Abel'));
    await setDoc(doc(db, 'barbershops/shop1/barbers', 'b2'), barber('shop1', 'Biruk'));
    await setDoc(doc(db, 'barbershops/shop2/barbers', 'b3'), barber('shop2', 'Kidus'));

    await setDoc(doc(db, 'barbershops/shop1/services', 'srv1'), {
      shopId: 'shop1',
      name: 'Haircut',
      description: 'Classic cut',
      price: 450,
      durationMinutes: 40,
    });
    await setDoc(doc(db, 'barbershops/shop1/services', 'srvLong'), {
      shopId: 'shop1',
      name: 'Full Grooming Package',
      description: 'Everything',
      price: 1200,
      durationMinutes: 90,
    });

    // bk1: customer's confirmed booking holding its slot locks.
    await setDoc(doc(db, 'bookings', 'bk1'), booking({ status: 'confirmed' }));
    for (const b of blocks(START, 40)) {
      await setDoc(doc(db, 'barbershops/shop1/barbers/b1/slotLocks', lockId(b)), lockDoc('bk1', b, BK1_END));
    }
  });
});

function shop(ownerId) {
  return {
    ownerId,
    name: 'Shop',
    description: 'A barbershop in Bole',
    address: 'Bole Road',
    city: 'Addis Ababa',
    phone: '+251911000999',
    imageUrl: 'https://example.com/shop.jpg',
    rating: 4.5,
    reviewCount: 3,
    openingHour: 8,
    closingHour: 20,
    workingDays: [1, 2, 3, 4, 5, 6],
    isVerified: true,
  };
}

// A shop as the admin app registers it today.
function newShop(ownerId, extra = {}) {
  return {
    ...shop(ownerId),
    subCity: 'Bole',
    landmark: 'Near Edna Mall',
    rating: 5,
    reviewCount: 0,
    isVerified: false,
    subscriptionPlan: 'trial',
    subscriptionStatus: 'trialing',
    subscriptionEndsAt: plusMinutes(NOW, 30 * 24 * 60),
    ...extra,
  };
}

function barber(shopId, name) {
  return {
    shopId,
    name,
    title: 'Barber',
    avatarUrl: null,
    rating: 5,
    reviewCount: 0,
    isAvailable: true,
    email: null,
    phone: null,
    specialties: ['Fade'],
  };
}

function booking(overrides = {}) {
  return {
    shopId: 'shop1',
    shopName: 'Shop',
    barberId: 'b1',
    barberName: 'Abel',
    customerId: 'customer',
    customerName: 'customer',
    customerPhone: PHONES.customer,
    serviceId: 'srv1',
    serviceName: 'Haircut',
    price: 450,
    date: '2026-11-20T00:00:00.000',
    timeSlot: '10:00 AM',
    status: 'confirmed',
    createdAt: NOW,
    startAt: START,
    endAt: plusMinutes(START, 40),
    durationMinutes: 40,
    paymentStatus: 'unpaid',
    paymentMethod: 'cash',
    ...overrides,
  };
}

// A booking as the app writes it, for `startAt` and the service's duration.
function newBooking(startAt, overrides = {}) {
  const minutes = overrides.durationMinutes ?? 40;
  return booking({ startAt, endAt: plusMinutes(startAt, minutes), durationMinutes: minutes, ...overrides });
}

// A slot lock as the app writes it: no customer data, and expiresAt one
// day after the booking's end (bookingEndAt; the block start when the test
// booking has no endAt).
function lockDoc(bookingId, startAt, bookingEndAt) {
  return { bookingId, startAt, expiresAt: plusMinutes(bookingEndAt ?? startAt, 24 * 60) };
}

const locksOf = (db, shopId = 'shop1', barberId = 'b1') =>
  collection(db, `barbershops/${shopId}/barbers/${barberId}/slotLocks`);

// FirestoreDataStore.createBooking: one transaction that reads every lock,
// then writes the booking and its locks. `lockStarts` defaults to every
// block of the booking.
function bookTx(db, id, data, lockStarts) {
  const starts = lockStarts ?? blocks(data.startAt, data.durationMinutes);
  return runTransaction(db, async (tx) => {
    for (const s of starts) {
      const snap = await tx.get(doc(locksOf(db, data.shopId, data.barberId), lockId(s)));
      if (snap.exists()) throw new Error('slot taken');
    }
    tx.set(doc(db, 'bookings', id), data);
    for (const s of starts) {
      tx.set(doc(locksOf(db, data.shopId, data.barberId), lockId(s)), lockDoc(id, s, data.endAt));
    }
  });
}

// Same writes as a batch (no reads), to test the rules without the
// client-side "slot taken" check.
function bookBatch(db, id, data, lockStarts) {
  const starts = lockStarts ?? blocks(data.startAt, data.durationMinutes);
  const batch = writeBatch(db);
  batch.set(doc(db, 'bookings', id), data);
  for (const s of starts) {
    batch.set(doc(locksOf(db, data.shopId, data.barberId), lockId(s)), lockDoc(id, s, data.endAt));
  }
  return batch.commit();
}

// FirestoreDataStore.updateBookingStatus(cancelled).
function cancelTx(db, bookingId, startAt, minutes, extra = {}) {
  return runTransaction(db, async (tx) => {
    const mine = [];
    for (const s of blocks(startAt, minutes)) {
      const ref = doc(locksOf(db), lockId(s));
      const snap = await tx.get(ref);
      if (snap.exists() && snap.data().bookingId === bookingId) mine.push(ref);
    }
    tx.update(doc(db, 'bookings', bookingId), { status: 'cancelled', ...extra });
    for (const ref of mine) tx.delete(ref);
  });
}

function invite(phone, role, extra = {}, createdBy = 'admin') {
  return { phone, role, name: 'Invited', createdBy, createdAt: NOW, ...extra };
}

// A signed-in client. Phone sign-in puts phone_number in the token.
function as(uid, phone) {
  return env.authenticatedContext(uid, { phone_number: phone }).firestore();
}

const anon = () => env.unauthenticatedContext().firestore();

async function seed(path, id, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path, id), data));
}

describe('users: self sign-up', () => {
  test('a new phone user can create a customer profile', async () => {
    const db = as('new', PHONES.newPerson);
    await assertSucceeds(
      setDoc(doc(db, 'users', 'new'), {
        uid: 'new',
        name: 'Hanna',
        phone: PHONES.newPerson,
        role: 'customer',
        createdAt: NOW,
      }),
    );
  });

  test('cannot give yourself a privileged role', async () => {
    const db = as('new', PHONES.newPerson);
    for (const [role, extra] of [
      ['admin', {}],
      ['barbershopOwner', { shopId: 'shop3' }],
      ['barber', { shopId: 'shop1', barberId: 'b1' }],
    ]) {
      await assertFails(
        setDoc(doc(db, 'users', 'new'), {
          uid: 'new',
          name: 'X',
          phone: PHONES.newPerson,
          role,
          createdAt: NOW,
          ...extra,
        }),
      );
    }
  });

  test('profile phone must be the verified phone', async () => {
    const db = as('new', PHONES.newPerson);
    await assertFails(
      setDoc(doc(db, 'users', 'new'), {
        uid: 'new',
        name: 'X',
        phone: PHONES.customer2,
        role: 'customer',
        createdAt: NOW,
      }),
    );
  });

  test('cannot create a profile for another uid', async () => {
    const db = as('new', PHONES.newPerson);
    await assertFails(
      setDoc(doc(db, 'users', 'someoneElse'), {
        uid: 'someoneElse',
        name: 'X',
        phone: PHONES.newPerson,
        role: 'customer',
        createdAt: NOW,
      }),
    );
  });

  test('a customer profile cannot carry a shopId', async () => {
    const db = as('new', PHONES.newPerson);
    await assertFails(
      setDoc(doc(db, 'users', 'new'), {
        uid: 'new',
        name: 'X',
        phone: PHONES.newPerson,
        role: 'customer',
        shopId: 'shop1',
        createdAt: NOW,
      }),
    );
  });
});

describe('users: invites grant roles', () => {
  const ownerProfile = {
    uid: 'new',
    name: 'Owner Three',
    phone: PHONES.newPerson,
    role: 'barbershopOwner',
    shopId: 'shop3',
    createdAt: NOW,
  };

  test('invited owner gets the role when the invite is consumed in the same batch', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'shop3' }));
    const db = as('new', PHONES.newPerson);
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', 'new'), ownerProfile);
    batch.delete(doc(db, 'invites', PHONES.newPerson));
    await assertSucceeds(batch.commit());
  });

  test('invite cannot be used without deleting it', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'shop3' }));
    const db = as('new', PHONES.newPerson);
    await assertFails(setDoc(doc(db, 'users', 'new'), ownerProfile));
  });

  test('profile must match the invite (shop)', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'shop3' }));
    const db = as('new', PHONES.newPerson);
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', 'new'), { ...ownerProfile, shopId: 'shop1' });
    batch.delete(doc(db, 'invites', PHONES.newPerson));
    await assertFails(batch.commit());
  });

  test("someone else's invite cannot be used", async () => {
    await seed('invites', PHONES.customer2, invite(PHONES.customer2, 'barbershopOwner', { shopId: 'shop3' }));
    const db = as('new', PHONES.newPerson);
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', 'new'), ownerProfile);
    batch.delete(doc(db, 'invites', PHONES.customer2));
    await assertFails(batch.commit());
  });

  test('an existing customer can accept a barber invite once', async () => {
    await seed('invites', PHONES.customer, invite(PHONES.customer, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'owner1'));
    const db = as('customer', PHONES.customer);
    const batch = writeBatch(db);
    batch.update(doc(db, 'users', 'customer'), { role: 'barber', shopId: 'shop1', barberId: 'b2' });
    batch.delete(doc(db, 'invites', PHONES.customer));
    await assertSucceeds(batch.commit());
  });

  test('an invite cannot change an existing owner or barber', async () => {
    await seed('invites', PHONES.owner1, invite(PHONES.owner1, 'barber', { shopId: 'shop2', barberId: 'b3' }, 'owner2'));
    const db = as('owner1', PHONES.owner1);
    const batch = writeBatch(db);
    batch.update(doc(db, 'users', 'owner1'), { role: 'barber', shopId: 'shop2', barberId: 'b3' });
    batch.delete(doc(db, 'invites', PHONES.owner1));
    await assertFails(batch.commit());
  });

  test('users cannot change their own role or shop', async () => {
    await assertFails(updateDoc(doc(as('customer', PHONES.customer), 'users', 'customer'), { role: 'admin' }));
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'users', 'owner1'), { shopId: 'shop2' }));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'users', 'barber1'), { barberId: 'b2' }));
  });

  test('users can edit their own name', async () => {
    await assertSucceeds(updateDoc(doc(as('customer', PHONES.customer), 'users', 'customer'), { name: 'New Name' }));
  });

  test('admin can change roles', async () => {
    await assertSucceeds(
      updateDoc(doc(as('admin', PHONES.admin), 'users', 'customer2'), {
        role: 'barbershopOwner',
        shopId: 'shop3',
      }),
    );
  });
});

describe('users: reading profiles', () => {
  test('own profile and admin reads', async () => {
    await assertSucceeds(getDoc(doc(as('customer', PHONES.customer), 'users', 'customer')));
    await assertSucceeds(getDoc(doc(as('admin', PHONES.admin), 'users', 'customer')));
  });

  test('owners can read their own staff only', async () => {
    await assertSucceeds(getDoc(doc(as('owner1', PHONES.owner1), 'users', 'barber1')));
    await assertFails(getDoc(doc(as('owner2', PHONES.owner2), 'users', 'barber1')));
  });

  test('customers cannot read other users', async () => {
    await assertFails(getDoc(doc(as('customer', PHONES.customer), 'users', 'customer2')));
    await assertFails(getDoc(doc(anon(), 'users', 'customer')));
  });
});

describe('invites', () => {
  test('admin can invite an owner for an existing shop', async () => {
    await assertSucceeds(
      setDoc(doc(as('admin', PHONES.admin), 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'shop3' })),
    );
  });

  test('owner invite must point to a real shop', async () => {
    await assertFails(
      setDoc(doc(as('admin', PHONES.admin), 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'nope' })),
    );
  });

  test('owner can invite a barber for their own shop only', async () => {
    const db = as('owner1', PHONES.owner1);
    await assertSucceeds(
      setDoc(doc(db, 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'owner1')),
    );
    await assertFails(
      setDoc(doc(db, 'invites', PHONES.customer2), invite(PHONES.customer2, 'barber', { shopId: 'shop2', barberId: 'b3' }, 'owner1')),
    );
  });

  test('owner cannot invite owners or admins', async () => {
    const db = as('owner1', PHONES.owner1);
    await assertFails(
      setDoc(doc(db, 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'shop1' }, 'owner1')),
    );
    await assertFails(setDoc(doc(db, 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'admin', {}, 'owner1')));
  });

  test('owner cannot overwrite an admin-created owner invite', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'shop3' }));
    await assertFails(
      setDoc(doc(as('owner1', PHONES.owner1), 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'owner1')),
    );
  });

  test('customers and barbers cannot create invites', async () => {
    await assertFails(
      setDoc(doc(as('customer', PHONES.customer), 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'admin', {}, 'customer')),
    );
    await assertFails(
      setDoc(doc(as('barber1', PHONES.barber1), 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'barber1')),
    );
  });

  test('createdBy must be the caller', async () => {
    await assertFails(
      setDoc(doc(as('admin', PHONES.admin), 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'admin', {}, 'someoneElse')),
    );
  });

  test('only the invitee, admin or the shop owner can read an invite', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'owner1'));
    await assertSucceeds(getDoc(doc(as('new', PHONES.newPerson), 'invites', PHONES.newPerson)));
    await assertSucceeds(getDoc(doc(as('owner1', PHONES.owner1), 'invites', PHONES.newPerson)));
    await assertFails(getDoc(doc(as('owner2', PHONES.owner2), 'invites', PHONES.newPerson)));
    await assertFails(getDoc(doc(as('customer', PHONES.customer), 'invites', PHONES.newPerson)));
  });

  test('a user can check for their own invite even if none exists', async () => {
    await assertSucceeds(getDoc(doc(as('new', PHONES.newPerson), 'invites', PHONES.newPerson)));
  });
});

describe('barbershops', () => {
  test('anyone can browse shops', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'barbershops', 'shop1')));
  });

  test('legacy shops without subscription fields: staff and admin only', async () => {
    await assertFails(getDoc(doc(as('customer', PHONES.customer), 'barbershops', 'shop3')));
    await assertSucceeds(getDoc(doc(as('admin', PHONES.admin), 'barbershops', 'shop3')));
  });

  test('legacy shops without subscription fields can still be booked', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'barbershops', 'shop1'), shop('owner1'));
    });
    await assertSucceeds(bookTx(as('customer', PHONES.customer), 'legacyShop', newBooking(addisSlot(9, 9))));
  });

  test('only admins can register shops', async () => {
    await assertSucceeds(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'new'), { ...shop(''), reviewCount: 0 }));
    await assertFails(setDoc(doc(as('owner1', PHONES.owner1), 'barbershops', 'new2'), shop('owner1')));
    await assertFails(setDoc(doc(as('customer', PHONES.customer), 'barbershops', 'new3'), shop('customer')));
  });

  test('owner edits their own shop but not verification or rating', async () => {
    const db = as('owner1', PHONES.owner1);
    await assertSucceeds(updateDoc(doc(db, 'barbershops', 'shop1'), { name: 'Renamed', closingHour: 21 }));
    await assertFails(updateDoc(doc(db, 'barbershops', 'shop1'), { isVerified: false }));
    await assertFails(updateDoc(doc(db, 'barbershops', 'shop1'), { rating: 5 }));
    await assertFails(updateDoc(doc(db, 'barbershops', 'shop1'), { ownerId: 'owner2' }));
  });

  test("owner cannot edit another owner's shop", async () => {
    await assertFails(updateDoc(doc(as('owner2', PHONES.owner2), 'barbershops', 'shop1'), { name: 'Hacked' }));
  });

  test('the invited owner can claim an unowned shop', async () => {
    await seed('users', 'owner3', {
      uid: 'owner3',
      name: 'Owner Three',
      phone: PHONES.newPerson,
      role: 'barbershopOwner',
      shopId: 'shop3',
      createdAt: NOW,
    });
    await assertSucceeds(updateDoc(doc(as('owner3', PHONES.newPerson), 'barbershops', 'shop3'), { ownerId: 'owner3' }));
  });

  test('an owner of another shop cannot claim an unowned shop', async () => {
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'barbershops', 'shop3'), { ownerId: 'owner1' }));
  });

  test('admin verifies and deletes shops; owners cannot delete', async () => {
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'barbershops', 'shop2'), { isVerified: false }));
    await assertFails(deleteDoc(doc(as('owner1', PHONES.owner1), 'barbershops', 'shop1')));
    await assertSucceeds(deleteDoc(doc(as('admin', PHONES.admin), 'barbershops', 'shop2')));
  });

  test('service duration is 5 to 120 minutes', async () => {
    const db = as('owner1', PHONES.owner1);
    const service = (durationMinutes) => ({ shopId: 'shop1', name: 'Svc', description: 'Svc', price: 300, durationMinutes });
    await assertSucceeds(setDoc(doc(db, 'barbershops/shop1/services', 'd120'), service(120)));
    await assertSucceeds(setDoc(doc(db, 'barbershops/shop1/services', 'd5'), service(5)));
    await assertFails(setDoc(doc(db, 'barbershops/shop1/services', 'd121'), service(121)));
    await assertFails(setDoc(doc(db, 'barbershops/shop1/services', 'd180'), service(180)));
    await assertFails(setDoc(doc(db, 'barbershops/shop1/services', 'd4'), service(4)));
    await assertFails(updateDoc(doc(db, 'barbershops/shop1/services', 'srv1'), { durationMinutes: 240 }));
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'barbershops/shop1/services', 'a480'), service(480)));
  });

  test('owner manages services of their own shop only', async () => {
    const service = { shopId: 'shop1', name: 'Shave', description: 'Hot towel shave', price: 300, durationMinutes: 30 };
    await assertSucceeds(setDoc(doc(as('owner1', PHONES.owner1), 'barbershops/shop1/services', 'srv2'), service));
    await assertFails(setDoc(doc(as('owner2', PHONES.owner2), 'barbershops/shop1/services', 'srv3'), service));
    await assertFails(setDoc(doc(as('barber1', PHONES.barber1), 'barbershops/shop1/services', 'srv4'), service));
  });
});

describe('barber profiles', () => {
  test('owner adds and removes barbers in their own shop', async () => {
    const db = as('owner1', PHONES.owner1);
    await assertSucceeds(setDoc(doc(db, 'barbershops/shop1/barbers', 'b9'), barber('shop1', 'New')));
    await assertSucceeds(deleteDoc(doc(db, 'barbershops/shop1/barbers', 'b9')));
    await assertFails(setDoc(doc(db, 'barbershops/shop2/barbers', 'b9'), barber('shop2', 'New')));
  });

  test('owner cannot change barber ratings', async () => {
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'barbershops/shop1/barbers', 'b1'), { rating: 5, reviewCount: 99 }));
  });

  test('barber toggles only their own availability', async () => {
    const db = as('barber1', PHONES.barber1);
    await assertSucceeds(updateDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), { isAvailable: false }));
    await assertFails(updateDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), { name: 'Renamed' }));
    await assertFails(updateDoc(doc(db, 'barbershops/shop1/barbers', 'b2'), { isAvailable: false }));
  });
});

describe('bookings', () => {
  test('customer books at the real service price', async () => {
    const db = as('customer', PHONES.customer);
    await assertSucceeds(bookTx(db, 'bk2', newBooking(addisSlot(3, 14))));
    await assertFails(bookBatch(db, 'bk3', newBooking(addisSlot(3, 16), { price: 1 })));
  });

  test('cannot book for someone else, as completed, or with a fake barber/service', async () => {
    const db = as('customer', PHONES.customer);
    const at = addisSlot(4, 9);
    await assertFails(bookBatch(db, 'bk4', newBooking(at, { customerId: 'customer2' })));
    await assertFails(bookBatch(db, 'bk5', newBooking(at, { status: 'completed' })));
    await assertFails(bookBatch(db, 'bk6', newBooking(at, { barberId: 'b3' })));
    await assertFails(bookBatch(db, 'bk7', newBooking(at, { serviceId: 'nope' })));
  });

  test('a signed-in phone without a profile cannot book', async () => {
    await assertFails(bookBatch(as('new', PHONES.newPerson), 'bk8', newBooking(addisSlot(4, 9), { customerId: 'new' })));
  });

  test('who can read a booking', async () => {
    await assertSucceeds(getDoc(doc(as('customer', PHONES.customer), 'bookings', 'bk1')));
    await assertSucceeds(getDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bk1')));
    await assertSucceeds(getDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1')));
    await assertSucceeds(getDoc(doc(as('admin', PHONES.admin), 'bookings', 'bk1')));

    await assertFails(getDoc(doc(as('customer2', PHONES.customer2), 'bookings', 'bk1')));
    await assertFails(getDoc(doc(as('barber2', PHONES.barber2), 'bookings', 'bk1')));
    await assertFails(getDoc(doc(as('owner2', PHONES.owner2), 'bookings', 'bk1')));
    await assertFails(getDoc(doc(anon(), 'bookings', 'bk1')));
  });

  test('customer can cancel but not complete their booking', async () => {
    const db = as('customer', PHONES.customer);
    await assertFails(updateDoc(doc(db, 'bookings', 'bk1'), { status: 'completed' }));
    await assertFails(updateDoc(doc(db, 'bookings', 'bk1'), { price: 1 }));
    await assertSucceeds(updateDoc(doc(db, 'bookings', 'bk1'), { status: 'cancelled' }));
  });

  test('assigned barber runs the booking; other barbers cannot', async () => {
    await assertSucceeds(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'inProgress' }));
    await assertSucceeds(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'completed' }));
    await assertFails(updateDoc(doc(as('barber2', PHONES.barber2), 'bookings', 'bk1'), { status: 'cancelled' }));
  });

  test("removing a barber profile revokes that barber's access", async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'barbershops/shop1/barbers', 'b1')));
    await assertFails(getDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1')));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'completed' }));
  });

  test('only admins delete bookings', async () => {
    await assertFails(deleteDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bk1')));
    await assertSucceeds(deleteDoc(doc(as('admin', PHONES.admin), 'bookings', 'bk1')));
  });
});

describe('bookings: appointment interval and payment fields on create', () => {
  const db = () => as('customer', PHONES.customer);

  test('chapa as payment method is allowed, paid/pending payment status is not', async () => {
    await assertSucceeds(bookBatch(db(), 'c1', newBooking(addisSlot(5, 9), { paymentMethod: 'chapa' })));
    await assertFails(bookBatch(db(), 'c2', newBooking(addisSlot(5, 11), { paymentStatus: 'paid' })));
    await assertFails(bookBatch(db(), 'c3', newBooking(addisSlot(5, 11), { paymentStatus: 'pending' })));
    await assertFails(bookBatch(db(), 'c4', newBooking(addisSlot(5, 11), { paymentMethod: 'card' })));
  });

  test('startAt, endAt, durationMinutes and payment fields are required', async () => {
    for (const field of ['startAt', 'endAt', 'durationMinutes', 'paymentStatus', 'paymentMethod']) {
      const data = newBooking(addisSlot(5, 11));
      const starts = blocks(data.startAt, data.durationMinutes);
      delete data[field];
      await assertFails(bookBatch(db(), `missing-${field}`, data, starts));
    }
  });

  test('duration must be the service duration and endAt must match it', async () => {
    const at = addisSlot(5, 11);
    await assertFails(bookBatch(db(), 'd1', newBooking(at, { durationMinutes: 15 })));
    await assertFails(bookBatch(db(), 'd2', { ...newBooking(at), endAt: plusMinutes(at, 60) }, blocks(at, 40)));
    await assertFails(bookBatch(db(), 'd3', { ...newBooking(at), endAt: plusMinutes(at, 30) }, blocks(at, 40)));
  });

  test('start must be on the 15-minute grid, in the future and within 31 days', async () => {
    await assertFails(bookBatch(db(), 'g1', newBooking(addisSlot(5, 11, 10))));
    await assertFails(bookBatch(db(), 'g2', newBooking(addisSlot(-1, 11))));
    await assertFails(bookBatch(db(), 'g3', newBooking(addisSlot(40, 11))));
    // Not Dart's toIso8601String format.
    const at = addisSlot(5, 11);
    await assertFails(bookBatch(db(), 'g4', newBooking(at.replace('.000Z', 'Z')), blocks(at, 40)));
  });

  test('clients cannot write function-owned or cancel fields on create', async () => {
    for (const extra of [
      { reminder24hSentAt: NOW },
      { reminder2hSentAt: NOW },
      { paymentId: 'p1' },
      { paidAt: NOW },
      { cancelledBy: 'customer' },
    ]) {
      await assertFails(bookBatch(db(), `x-${Object.keys(extra)[0]}`, newBooking(addisSlot(6, 9), extra)));
    }
  });

  test('suspended shops and unavailable barbers cannot be booked', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'barbershops', 'shop1'), { subscriptionStatus: 'suspended' });
    });
    await assertFails(bookBatch(db(), 's1', newBooking(addisSlot(6, 9))));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'barbershops', 'shop1'), { subscriptionStatus: 'past_due' });
      await updateDoc(doc(ctx.firestore(), 'barbershops/shop1/barbers', 'b1'), { isAvailable: false });
    });
    await assertFails(bookBatch(db(), 's2', newBooking(addisSlot(6, 9))));
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'barbershops/shop1/barbers', 'b1'), { isAvailable: true }),
    );
    await assertSucceeds(bookBatch(db(), 's3', newBooking(addisSlot(6, 9))));
  });
});

describe('double-booking prevention (slot locks)', () => {
  const cust = () => as('customer', PHONES.customer);
  const cust2 = () => as('customer2', PHONES.customer2);

  test('a booking must hold every slot lock it covers', async () => {
    const at = addisSlot(7, 9);
    // No locks.
    await assertFails(bookBatch(cust(), 'l1', newBooking(at), []));
    // First block only (40 minutes = 3 blocks).
    await assertFails(bookBatch(cust(), 'l2', newBooking(at), [at]));
    // Missing the last block.
    await assertFails(bookBatch(cust(), 'l3', newBooking(at), blocks(at, 30)));
    // All three.
    await assertSucceeds(bookBatch(cust(), 'l4', newBooking(at)));
  });

  test('a 120-minute booking (the longest service) needs all eight locks', async () => {
    await seed('barbershops/shop1/services', 'srvMax', {
      shopId: 'shop1',
      name: 'Wedding Package',
      description: 'Everything',
      price: 1500,
      durationMinutes: 120,
    });
    const at = addisSlot(7, 15);
    const max = { serviceId: 'srvMax', serviceName: 'Wedding Package', price: 1500, durationMinutes: 120 };
    // The rules check blocks 1-4 and the last; the middle ones are left to
    // the verifyBookingLocks function.
    await assertFails(bookBatch(cust(), 'max1', newBooking(at, max), blocks(at, 105)));
    await assertSucceeds(bookTx(cust(), 'max2', newBooking(at, max)));
  });

  test('bookings longer than 120 minutes are rejected even for a legacy longer service', async () => {
    await seed('barbershops/shop1/services', 'srvLegacyLong', {
      shopId: 'shop1',
      name: 'Old long service',
      description: 'Written before the cap',
      price: 2000,
      durationMinutes: 135,
    });
    const at = addisSlot(7, 9);
    const long = { serviceId: 'srvLegacyLong', serviceName: 'Old long service', price: 2000, durationMinutes: 135 };
    await assertFails(bookBatch(cust(), 'tooLong', newBooking(at, long)));
  });

  test('a 90-minute booking with all six locks succeeds; skipping the last fails', async () => {
    const at = addisSlot(7, 13);
    const long = { serviceId: 'srvLong', serviceName: 'Full Grooming Package', price: 1200, durationMinutes: 90 };
    await assertFails(bookBatch(cust(), 'long1', newBooking(at, long), blocks(at, 75)));
    await assertSucceeds(bookTx(cust(), 'long2', newBooking(at, long)));
  });

  test('a second customer cannot book a taken slot or an overlapping one', async () => {
    // Same start as bk1.
    await assertFails(bookBatch(cust2(), 'dup', newBooking(START, { customerId: 'customer2' })));
    // Starts inside bk1 (10:15).
    await assertFails(bookBatch(cust2(), 'ovl1', newBooking(plusMinutes(START, 15), { customerId: 'customer2' })));
    // Ends inside bk1 (09:30 + 40 min covers the 10:00 block).
    await assertFails(bookBatch(cust2(), 'ovl2', newBooking(plusMinutes(START, -30), { customerId: 'customer2' })));
    // Back to back after bk1 (10:45) is fine.
    await assertSucceeds(bookTx(cust2(), 'next', newBooking(plusMinutes(START, 45), { customerId: 'customer2' })));
  });

  test('the transaction reports a taken slot', async () => {
    await assert.rejects(bookTx(cust2(), 'dupTx', newBooking(START, { customerId: 'customer2' })), /slot taken/);
  });

  test('lock ids roll over to the next Addis day before 03:00 Addis', async () => {
    // 01:00 Addis is 22:00 UTC the day before.
    await assertSucceeds(bookTx(cust(), 'night', newBooking(addisSlot(8, 1, 0))));
    await assertSucceeds(bookTx(cust(), 'evening', newBooking(addisSlot(8, 23, 0))));
  });

  test('bookings cannot run past Addis midnight', async () => {
    await assertFails(bookBatch(cust(), 'late', newBooking(addisSlot(8, 23, 45))));
  });

  test('locks must match their booking: customer, shop, barber, interval and id', async () => {
    const at = addisSlot(8, 9);
    const data = newBooking(at);
    const db = cust();
    const db2 = cust2();
    const later = plusMinutes(START, 60);
    // A lock for someone else's booking.
    await assertFails(setDoc(doc(locksOf(db2), lockId(later)), lockDoc('bk1', later, BK1_END)));
    // Outside the booking's interval.
    await assertFails(setDoc(doc(locksOf(db), lockId(later)), lockDoc('bk1', later, BK1_END)));
    // Lock id does not match startAt (the booking itself is valid).
    const batch = writeBatch(db);
    batch.set(doc(db, 'bookings', 'm1'), data);
    for (const s of blocks(at, 40)) batch.set(doc(locksOf(db), lockId(s)), lockDoc('m1', s, data.endAt));
    batch.set(doc(locksOf(db), lockId(plusMinutes(at, 120))), lockDoc('m1', at, data.endAt));
    await assertFails(batch.commit());
    // Under another barber.
    const batch2 = writeBatch(db);
    batch2.set(doc(db, 'bookings', 'm2'), data);
    for (const s of blocks(at, 40)) batch2.set(doc(locksOf(db), lockId(s)), lockDoc('m2', s, data.endAt));
    batch2.set(doc(locksOf(db, 'shop1', 'b2'), lockId(at)), lockDoc('m2', at, data.endAt));
    await assertFails(batch2.commit());
    // Extra fields.
    const batch3 = writeBatch(db);
    batch3.set(doc(db, 'bookings', 'm3'), data);
    for (const s of blocks(at, 40)) batch3.set(doc(locksOf(db), lockId(s)), { ...lockDoc('m3', s, data.endAt), name: 'x' });
    await assertFails(batch3.commit());
    // The same booking with correct locks is fine.
    await assertSucceeds(bookBatch(db, 'm4', data));
  });

  test('locks carry no customer data: customerId is rejected', async () => {
    const at = addisSlot(8, 15);
    const data = newBooking(at);
    const db = cust();
    const batch = writeBatch(db);
    batch.set(doc(db, 'bookings', 'priv1'), data);
    for (const s of blocks(at, 40)) {
      batch.set(doc(locksOf(db), lockId(s)), { ...lockDoc('priv1', s, data.endAt), customerId: 'customer' });
    }
    await assertFails(batch.commit());
    // The same booking without customerId is fine, and the locks a second
    // customer reads hold no uid.
    await assertSucceeds(bookBatch(db, 'priv2', data));
    const snap = await assertSucceeds(getDoc(doc(locksOf(cust2()), lockId(at))));
    assert.deepEqual(Object.keys(snap.data()).sort(), ['bookingId', 'expiresAt', 'startAt']);
  });

  test("a lock is bound to the caller's booking through the booking itself", async () => {
    // customer2 cannot attach a lock to customer's new booking in their own
    // write, even with a valid shape.
    const at = addisSlot(8, 17);
    const data = newBooking(at);
    await assertSucceeds(bookBatch(cust(), 'bind1', data));
    const extra = plusMinutes(at, 45);
    await assertFails(setDoc(doc(locksOf(cust2()), lockId(extra)), lockDoc('bind1', extra, data.endAt)));
    // A lock pointing at a booking that does not exist.
    await assertFails(setDoc(doc(locksOf(cust()), lockId(addisSlot(9, 9))), lockDoc('ghost', addisSlot(9, 9), addisSlot(9, 10))));
  });

  test('expiresAt must be exactly the booking end plus one day', async () => {
    const at = addisSlot(8, 19);
    const data = newBooking(at);
    for (const [name, expiresAt] of [
      ['missing', undefined],
      ['end', data.endAt],
      ['end+2d', plusMinutes(data.endAt, 2 * 24 * 60)],
      ['end+1d+1m', plusMinutes(data.endAt, 24 * 60 + 1)],
      ['no millis', plusMinutes(data.endAt, 24 * 60).replace('.000Z', 'Z')],
      ['timestamp-like number', 1234],
    ]) {
      const db = cust();
      const batch = writeBatch(db);
      batch.set(doc(db, 'bookings', `exp-${name}`), data);
      for (const s of blocks(at, 40)) {
        const lock = { ...lockDoc(`exp-${name}`, s, data.endAt), expiresAt };
        if (expiresAt === undefined) delete lock.expiresAt;
        batch.set(doc(locksOf(db), lockId(s)), lock);
      }
      await assertFails(batch.commit(), name);
    }
    await assertSucceeds(bookBatch(cust(), 'exp-ok', data));
  });

  test('locks can never be overwritten', async () => {
    const ref = (db) => doc(locksOf(db), lockId(START));
    await assertFails(setDoc(ref(cust()), lockDoc('bk1', START, BK1_END)));
    await assertFails(updateDoc(ref(cust()), { bookingId: 'other' }));
    await assertFails(updateDoc(ref(as('admin', PHONES.admin)), { bookingId: 'other' }));
  });

  test('clients cannot run the cleanup collection-group query on slotLocks', async () => {
    const q = (db) => query(collectionGroup(db, 'slotLocks'), where('expiresAt', '<', new Date().toISOString()));
    await assertFails(getDocs(q(cust())));
    await assertFails(getDocs(q(as('admin', PHONES.admin))));
  });

  test('any signed-in user can read a day of locks; anonymous cannot', async () => {
    const dayStart = addisSlot(3, 0);
    const dayEnd = addisSlot(4, 0);
    const q = (db) => query(locksOf(db), where('startAt', '>=', dayStart), where('startAt', '<', dayEnd));
    const snap = await assertSucceeds(getDocs(q(cust2())));
    assert.equal(snap.size, 3);
    await assertSucceeds(getDoc(doc(locksOf(cust2()), lockId(addisSlot(9, 9)))));
    await assertFails(getDocs(q(anon())));
  });

  test('customer cancels and releases the locks in one transaction', async () => {
    await assertSucceeds(cancelTx(cust(), 'bk1', START, 40, { cancelledBy: 'customer' }));
    // The slot is free again.
    await assertSucceeds(bookTx(cust2(), 'again', newBooking(START, { customerId: 'customer2' })));
  });

  test('locks of a live booking cannot be released by its customer or others', async () => {
    const ref = (db) => doc(locksOf(db), lockId(START));
    await assertFails(deleteDoc(ref(cust())));
    await assertFails(deleteDoc(ref(cust2())));
    await assertFails(deleteDoc(ref(as('barber1', PHONES.barber1))));
    await assertFails(deleteDoc(ref(as('owner2', PHONES.owner2))));
  });

  test('another customer cannot release locks even of a cancelled booking', async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'bookings', 'bk1'), { status: 'cancelled' }));
    await assertFails(deleteDoc(doc(locksOf(cust2()), lockId(START))));
    await assertFails(deleteDoc(doc(locksOf(as('barber2', PHONES.barber2)), lockId(START))));
    await assertSucceeds(deleteDoc(doc(locksOf(cust()), lockId(START))));
  });

  test('the assigned barber and the owner can cancel and release', async () => {
    await assertSucceeds(cancelTx(as('barber1', PHONES.barber1), 'bk1', START, 40, { cancelledBy: 'barber1' }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'bookings', 'bk1'), booking());
      for (const b of blocks(START, 40)) await setDoc(doc(locksOf(ctx.firestore()), lockId(b)), lockDoc('bk1', b, BK1_END));
    });
    await assertSucceeds(cancelTx(as('owner1', PHONES.owner1), 'bk1', START, 40));
  });

  test('owners and admins can clear locks of their shop at any time', async () => {
    await assertSucceeds(deleteDoc(doc(locksOf(as('owner1', PHONES.owner1)), lockId(START))));
    await assertSucceeds(deleteDoc(doc(locksOf(as('admin', PHONES.admin)), lockId(plusMinutes(START, 15)))));
  });
});

describe('bookings: status updates, cancelledBy and function-owned fields', () => {
  test('cancelledBy must be the caller and only on cancelling', async () => {
    const cust = as('customer', PHONES.customer);
    await assertFails(updateDoc(doc(cust, 'bookings', 'bk1'), { status: 'cancelled', cancelledBy: 'owner1' }));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'inProgress', cancelledBy: 'barber1' }));
    await assertSucceeds(updateDoc(doc(cust, 'bookings', 'bk1'), { status: 'cancelled', cancelledBy: 'customer' }));
    // Not again once cancelled.
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bk1'), { cancelledBy: 'owner1' }));
  });

  test('clients cannot write payment fields or reminder flags', async () => {
    for (const [uid, phone] of [
      ['customer', PHONES.customer],
      ['owner1', PHONES.owner1],
      ['barber1', PHONES.barber1],
    ]) {
      const ref = doc(as(uid, phone), 'bookings', 'bk1');
      await assertFails(updateDoc(ref, { paymentStatus: 'paid' }));
      await assertFails(updateDoc(ref, { paymentMethod: 'chapa' }));
      await assertFails(updateDoc(ref, { paymentId: 'p1' }));
      await assertFails(updateDoc(ref, { paidAt: NOW }));
      await assertFails(updateDoc(ref, { reminder24hSentAt: NOW }));
      await assertFails(updateDoc(ref, { reminder2hSentAt: NOW }));
      await assertFails(updateDoc(ref, { startAt: addisSlot(9, 9) }));
    }
  });

  test('admin may correct paymentStatus', async () => {
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'bookings', 'bk1'), { paymentStatus: 'refunded' }));
    await assertFails(updateDoc(doc(as('admin', PHONES.admin), 'bookings', 'bk1'), { paymentStatus: 'free' }));
  });

  test('status updates still work on documents carrying function-written fields', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'bookings', 'bk1'), {
        paymentStatus: 'paid',
        paymentMethod: 'chapa',
        paymentId: 'pay1',
        paidAt: NOW,
        reminder24hSentAt: NOW,
      }),
    );
    await assertSucceeds(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'inProgress' }));
  });

  test('cancelReason is written by functions only; such bookings still update', async () => {
    for (const [uid, phone] of [
      ['customer', PHONES.customer],
      ['owner1', PHONES.owner1],
      ['admin', PHONES.admin],
    ]) {
      await assertFails(updateDoc(doc(as(uid, phone), 'bookings', 'bk1'), { status: 'cancelled', cancelReason: 'slot_conflict' }));
    }
    await assertFails(bookBatch(as('customer', PHONES.customer), 'cr1', newBooking(addisSlot(6, 13), { cancelReason: 'x' })));
    // verifyBookingLocks cancelled it (Admin SDK).
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'bookings', 'bk1'), { status: 'cancelled', cancelledBy: 'system', cancelReason: 'slot_conflict' }),
    );
    await assertSucceeds(getDoc(doc(as('customer', PHONES.customer), 'bookings', 'bk1')));
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'bookings', 'bk1'), { paymentStatus: 'refunded' }));
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bk1'), { cancelReason: 'other' }));
  });

  test('legacy bookings without startAt can still change status', async () => {
    const legacy = booking();
    for (const k of ['startAt', 'endAt', 'durationMinutes', 'paymentStatus', 'paymentMethod']) delete legacy[k];
    await seed('bookings', 'legacy', legacy);
    await assertSucceeds(updateDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'legacy'), { status: 'completed' }));
  });

  test('staff cannot reopen a cancelled booking (its slot was released)', async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'bookings', 'bk1'), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bk1'), { status: 'confirmed' }));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'inProgress' }));
    await assertFails(updateDoc(doc(as('customer', PHONES.customer), 'bookings', 'bk1'), { status: 'confirmed' }));
  });
});

describe('booking listeners (list queries)', () => {
  const bookings = (db) => collection(db, 'bookings');

  beforeEach(async () => {
    await seed('bookings', 'bkOther', booking({ customerId: 'customer2', barberId: 'b2', barberName: 'Biruk' }));
    await seed('bookings', 'bkShop2', booking({ shopId: 'shop2', barberId: 'b3', customerId: 'customer2' }));
  });

  test('customer: where customerId == uid', async () => {
    const db = as('customer', PHONES.customer);
    const snap = await assertSucceeds(getDocs(query(bookings(db), where('customerId', '==', 'customer'))));
    assert.equal(snap.size, 1);
    await assertFails(getDocs(bookings(db)));
    await assertFails(getDocs(query(bookings(db), where('customerId', '==', 'customer2'))));
  });

  test('owner: where shopId == own shop', async () => {
    const db = as('owner1', PHONES.owner1);
    const snap = await assertSucceeds(getDocs(query(bookings(db), where('shopId', '==', 'shop1'))));
    assert.equal(snap.size, 2);
    await assertFails(getDocs(query(bookings(db), where('shopId', '==', 'shop2'))));
  });

  test('barber: where shopId == S and barberId == own profile', async () => {
    const db = as('barber1', PHONES.barber1);
    const snap = await assertSucceeds(
      getDocs(query(bookings(db), where('shopId', '==', 'shop1'), where('barberId', '==', 'b1'))),
    );
    assert.equal(snap.size, 1);
    await assertFails(getDocs(query(bookings(db), where('shopId', '==', 'shop1'))));
    await assertFails(getDocs(query(bookings(db), where('shopId', '==', 'shop1'), where('barberId', '==', 'b2'))));
  });

  // FirestoreDataStore.upcomingBookingsQuery / historyBookingsQuery.
  const windowed = (base) => {
    const now = new Date();
    now.setUTCSeconds(0, 0);
    const nowIso = now.toISOString();
    const cutoffIso = new Date(now.getTime() - 90 * 24 * 3600 * 1000).toISOString();
    return [
      query(base, where('startAt', '>=', nowIso), orderBy('startAt')),
      query(base, where('startAt', '>=', cutoffIso), where('startAt', '<', nowIso), orderBy('startAt', 'desc'), limit(200)),
    ];
  };

  test('bounded listeners: upcoming + 90 days of history for customer, owner and barber', async () => {
    await seed('bookings', 'bkPast', booking({ startAt: addisSlot(-10, 10), endAt: plusMinutes(addisSlot(-10, 10), 40) }));
    await seed('bookings', 'bkAncient', booking({ startAt: addisSlot(-120, 10), endAt: plusMinutes(addisSlot(-120, 10), 40) }));
    const cases = [
      [as('customer', PHONES.customer), [where('customerId', '==', 'customer')], ['bk1'], ['bkPast']],
      [as('owner1', PHONES.owner1), [where('shopId', '==', 'shop1')], ['bk1', 'bkOther'], ['bkPast']],
      [as('barber1', PHONES.barber1), [where('shopId', '==', 'shop1'), where('barberId', '==', 'b1')], ['bk1'], ['bkPast']],
    ];
    for (const [db, filters, upcoming, history] of cases) {
      const [up, past] = windowed(query(collection(db, 'bookings'), ...filters));
      const upSnap = await assertSucceeds(getDocs(up));
      assert.deepEqual(upSnap.docs.map((d) => d.id).sort(), upcoming);
      const pastSnap = await assertSucceeds(getDocs(past));
      assert.deepEqual(pastSnap.docs.map((d) => d.id), history);
    }
    // The same windows without the role filter are still denied.
    for (const q of windowed(collection(as('customer', PHONES.customer), 'bookings'))) await assertFails(getDocs(q));
    for (const q of windowed(query(collection(as('owner2', PHONES.owner2), 'bookings'), where('shopId', '==', 'shop1')))) {
      await assertFails(getDocs(q));
    }
    for (const q of windowed(
      query(collection(as('barber1', PHONES.barber1), 'bookings'), where('shopId', '==', 'shop1'), where('barberId', '==', 'b2')),
    )) {
      await assertFails(getDocs(q));
    }
  });

  test('admin: orderBy createdAt desc limit 500', async () => {
    const db = as('admin', PHONES.admin);
    const snap = await assertSucceeds(getDocs(query(bookings(db), orderBy('createdAt', 'desc'), limit(500))));
    assert.equal(snap.size, 3);
    await assertFails(getDocs(query(bookings(as('owner1', PHONES.owner1)), orderBy('createdAt', 'desc'), limit(500))));
  });
});

describe('users: language, profile edits and staff listener', () => {
  test('users can set their language to en or am only', async () => {
    const ref = doc(as('customer', PHONES.customer), 'users', 'customer');
    await assertSucceeds(updateDoc(ref, { language: 'am' }));
    await assertSucceeds(updateDoc(ref, { name: 'Liya', language: 'en' }));
    await assertFails(updateDoc(ref, { language: 'fr' }));
  });

  test('owners, barbers and admins can set their language too, nothing else changes', async () => {
    for (const [uid, phone] of [
      ['owner1', PHONES.owner1],
      ['barber1', PHONES.barber1],
      ['admin', PHONES.admin],
    ]) {
      const ref = doc(as(uid, phone), 'users', uid);
      await assertSucceeds(updateDoc(ref, { language: 'am' }), uid);
      await assertSucceeds(updateDoc(ref, { language: 'en' }), uid);
      await assertFails(updateDoc(ref, { language: 'AM' }), uid);
      await assertFails(updateDoc(ref, { language: 3 }), uid);
    }
    // Not someone else's.
    await assertFails(updateDoc(doc(as('customer', PHONES.customer), 'users', 'customer2'), { language: 'en' }));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'users', 'barber1'), { language: 'en', role: 'admin' }));
  });

  test('a new profile may carry a language', async () => {
    const db = as('new', PHONES.newPerson);
    await assertSucceeds(
      setDoc(doc(db, 'users', 'new'), {
        uid: 'new',
        name: 'Hanna',
        phone: PHONES.newPerson,
        role: 'customer',
        createdAt: NOW,
        language: 'am',
      }),
    );
  });

  test('profile edits cannot add unknown fields', async () => {
    await assertFails(updateDoc(doc(as('customer', PHONES.customer), 'users', 'customer'), { isVip: true }));
  });

  test('owner lists their staff: users where shopId == own shop', async () => {
    const users = (db) => collection(db, 'users');
    const snap = await assertSucceeds(getDocs(query(users(as('owner1', PHONES.owner1)), where('shopId', '==', 'shop1'))));
    assert.equal(snap.size, 3);
    await assertFails(getDocs(query(users(as('owner2', PHONES.owner2)), where('shopId', '==', 'shop1'))));
    await assertFails(getDocs(users(as('owner1', PHONES.owner1))));
    await assertSucceeds(getDocs(users(as('admin', PHONES.admin))));
  });

  test('owner lists pending barber invites of their shop', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'owner1'));
    const invites = (db) => collection(db, 'invites');
    const q = (db, shopId) => query(invites(db), where('shopId', '==', shopId), where('role', '==', 'barber'));
    const snap = await assertSucceeds(getDocs(q(as('owner1', PHONES.owner1), 'shop1')));
    assert.equal(snap.size, 1);
    await assertFails(getDocs(q(as('owner2', PHONES.owner2), 'shop1')));
    await assertSucceeds(getDocs(invites(as('admin', PHONES.admin))));
  });
});

describe('users/{uid}/devices (FCM tokens)', () => {
  const device = { token: 'fcm-token-abc', platform: 'android', updatedAt: NOW };
  const ref = (db, uid = 'customer', id = '0123456789abcdef') => doc(db, `users/${uid}/devices`, id);

  test('a user registers, refreshes and removes their own device', async () => {
    const db = as('customer', PHONES.customer);
    await assertSucceeds(setDoc(ref(db), device));
    await assertSucceeds(setDoc(ref(db), { ...device, token: 'fcm-token-new', updatedAt: NOW }));
    await assertSucceeds(getDoc(ref(db)));
    await assertSucceeds(deleteDoc(ref(db)));
  });

  test('device docs are validated', async () => {
    const db = as('customer', PHONES.customer);
    await assertFails(setDoc(ref(db), { ...device, platform: 'windows' }));
    await assertFails(setDoc(ref(db), { ...device, extra: 1 }));
    await assertFails(setDoc(ref(db), { token: 'x', platform: 'web' }));
    await assertFails(setDoc(ref(db), { ...device, token: '' }));
  });

  test("nobody else can touch a user's devices", async () => {
    await seed('users/customer/devices', '0123456789abcdef', device);
    for (const [uid, phone] of [
      ['customer2', PHONES.customer2],
      ['admin', PHONES.admin],
      ['owner1', PHONES.owner1],
    ]) {
      const db = as(uid, phone);
      await assertFails(getDoc(ref(db)));
      await assertFails(setDoc(ref(db), device));
      await assertFails(deleteDoc(ref(db)));
    }
    await assertFails(setDoc(ref(anon()), device));
  });
});

describe('users/{uid}/notifications (inbox)', () => {
  const note = { title: 'Booking confirmed', body: 'See you', type: 'confirmed', bookingId: 'bk1', read: false, createdAt: NOW };
  const inbox = (db, uid = 'customer') => collection(db, `users/${uid}/notifications`);

  beforeEach(async () => {
    await seed('users/customer/notifications', 'bk1_confirmed', note);
    await seed('users/customer/notifications', 'bk1_reminder24h', { ...note, type: 'reminder24h' });
  });

  test('a user reads their own inbox (newest first, limit 50)', async () => {
    const db = as('customer', PHONES.customer);
    const snap = await assertSucceeds(getDocs(query(inbox(db), orderBy('createdAt', 'desc'), limit(50))));
    assert.equal(snap.size, 2);
  });

  test("other users cannot read someone's inbox", async () => {
    await assertFails(getDocs(inbox(as('customer2', PHONES.customer2))));
    await assertFails(getDoc(doc(inbox(as('admin', PHONES.admin)), 'bk1_confirmed')));
    await assertFails(getDocs(inbox(anon())));
  });

  test('a user can only mark a notification as read', async () => {
    const db = as('customer', PHONES.customer);
    await assertSucceeds(updateDoc(doc(inbox(db), 'bk1_confirmed'), { read: true }));
    await assertFails(updateDoc(doc(inbox(db), 'bk1_reminder24h'), { read: false }));
    await assertFails(updateDoc(doc(inbox(db), 'bk1_reminder24h'), { read: true, title: 'Hacked' }));
    await assertFails(updateDoc(doc(inbox(as('customer2', PHONES.customer2), 'customer'), 'bk1_reminder24h'), { read: true }));
  });

  test('mark all read is a batch of read updates', async () => {
    const db = as('customer', PHONES.customer);
    const batch = writeBatch(db);
    batch.update(doc(inbox(db), 'bk1_confirmed'), { read: true });
    batch.update(doc(inbox(db), 'bk1_reminder24h'), { read: true });
    await assertSucceeds(batch.commit());
  });

  test('clients cannot create or delete notifications', async () => {
    const db = as('customer', PHONES.customer);
    await assertFails(setDoc(doc(inbox(db), 'fake'), note));
    await assertFails(deleteDoc(doc(inbox(db), 'bk1_confirmed')));
    await assertFails(setDoc(doc(inbox(as('admin', PHONES.admin)), 'fake'), note));
  });

  test('notificationLog is closed to clients', async () => {
    await seed('notificationLog', 'bk1_confirmed_sms', { bookingId: 'bk1', type: 'confirmed', channel: 'sms' });
    await assertFails(getDoc(doc(as('admin', PHONES.admin), 'notificationLog', 'bk1_confirmed_sms')));
    await assertFails(getDoc(doc(as('customer', PHONES.customer), 'notificationLog', 'bk1_confirmed_sms')));
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'notificationLog', 'x'), { a: 1 }));
  });
});

describe('barbershops: Addis location and subscriptions', () => {
  test('admin registers a shop with sub-city, landmark and a trial', async () => {
    await assertSucceeds(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'new'), newShop('')));
    const noLandmark = newShop('', { subCity: '' });
    delete noLandmark.landmark;
    await assertSucceeds(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'new2'), noLandmark));
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'bad1'), newShop('', { subscriptionStatus: 'free' })));
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'bad2'), newShop('', { subscriptionPlan: 'gold' })));
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'bad3'), newShop('', { workingDays: [0, 8] })));
  });

  test('registerBarbershopByAdmin batch: shop, services, lead barber, owner invite', async () => {
    const db = as('admin', PHONES.admin);
    const batch = writeBatch(db);
    batch.set(doc(db, 'barbershops', 'reg'), newShop(''));
    batch.set(doc(db, 'barbershops/reg/services', 's1'), { shopId: 'reg', name: 'Haircut', description: 'Cut', price: 300, durationMinutes: 30 });
    batch.set(doc(db, 'barbershops/reg/services', 's2'), { shopId: 'reg', name: 'Shave', description: 'Shave', price: 200, durationMinutes: 20 });
    batch.set(doc(db, 'barbershops/reg/barbers', 'lead'), { shopId: 'reg', name: 'Lead', title: 'Owner', rating: 5, reviewCount: 0, isAvailable: true, phone: PHONES.newPerson, specialties: [] });
    batch.set(doc(db, 'invites', PHONES.newPerson), invite(PHONES.newPerson, 'barbershopOwner', { shopId: 'reg' }));
    await assertSucceeds(batch.commit());
  });

  test('deleteShop batch (admin): services, barbers, invites and the shop', async () => {
    await seed('invites', PHONES.newPerson, invite(PHONES.newPerson, 'barber', { shopId: 'shop1', barberId: 'b2' }, 'owner1'));
    const db = as('admin', PHONES.admin);
    const batch = writeBatch(db);
    for (const id of ['srv1', 'srvLong']) batch.delete(doc(db, 'barbershops/shop1/services', id));
    for (const id of ['b1', 'b2']) batch.delete(doc(db, 'barbershops/shop1/barbers', id));
    batch.delete(doc(db, 'invites', PHONES.newPerson));
    batch.delete(doc(db, 'barbershops', 'shop1'));
    await assertSucceeds(batch.commit());
  });

  test("owner's profile update (toProfileMap) succeeds, including removing the landmark", async () => {
    await seed('barbershops', 'shop1', newShop('owner1'));
    const db = as('owner1', PHONES.owner1);
    await assertSucceeds(
      updateDoc(doc(db, 'barbershops', 'shop1'), {
        name: 'Crown Cuts Bole',
        description: 'Fades and shaves',
        address: 'Bole Road',
        city: 'Addis Ababa',
        subCity: 'Kirkos',
        landmark: deleteField(),
        phone: '+251911223301',
        imageUrl: 'https://example.com/a.jpg',
        openingHour: 8,
        closingHour: 20,
        workingDays: [1, 2, 3, 4, 5, 6, 7],
      }),
    );
  });

  test('shop phone: an Ethiopian mobile or fixed line in +251 form', async () => {
    const admin = as('admin', PHONES.admin);
    const ok = ['+251911223344', '+251711223344', '+251115512345', '+251221112233', '+251331112233', '+251461112233', '+251581112233'];
    for (const [i, phone] of ok.entries()) {
      await assertSucceeds(setDoc(doc(admin, 'barbershops', `ph${i}`), newShop('', { phone })), phone);
    }
    const bad = ['+251611223344', '+251811223344', '+25111551234', '+2511155123456', '0115512345', '+251 11 551 2345', '', '+1115512345'];
    for (const [i, phone] of bad.entries()) {
      await assertFails(setDoc(doc(admin, 'barbershops', `bad${i}`), newShop('', { phone })), phone);
    }
    // Owners can switch their shop to a landline, but not to junk.
    await seed('barbershops', 'shop1', newShop('owner1'));
    const owner = as('owner1', PHONES.owner1);
    await assertSucceeds(updateDoc(doc(owner, 'barbershops', 'shop1'), { phone: '+251115512345' }));
    await assertFails(updateDoc(doc(owner, 'barbershops', 'shop1'), { phone: 'call us' }));
  });

  test('owners cannot change subscription fields', async () => {
    await seed('barbershops', 'shop1', newShop('owner1'));
    const ref = doc(as('owner1', PHONES.owner1), 'barbershops', 'shop1');
    await assertFails(updateDoc(ref, { subscriptionStatus: 'active' }));
    await assertFails(updateDoc(ref, { subscriptionPlan: 'pro' }));
    await assertFails(updateDoc(ref, { subscriptionEndsAt: '2030-01-01T00:00:00.000Z' }));
    await assertFails(updateDoc(ref, { subscriptionEndsAt: deleteField() }));
  });

  test('admin updates subscriptions', async () => {
    const ref = doc(as('admin', PHONES.admin), 'barbershops', 'shop2');
    await assertSucceeds(
      updateDoc(ref, { subscriptionPlan: 'basic', subscriptionStatus: 'active', subscriptionEndsAt: '2027-01-01T00:00:00.000Z' }),
    );
    await assertSucceeds(updateDoc(ref, { subscriptionPlan: 'basic', subscriptionStatus: 'suspended', subscriptionEndsAt: deleteField() }));
  });

  test('suspended shops are hidden from customers but not from their staff or admins', async () => {
    await seed('barbershops', 'shop1', newShop('owner1', { subscriptionStatus: 'suspended' }));
    await assertFails(getDoc(doc(as('customer', PHONES.customer), 'barbershops', 'shop1')));
    await assertFails(getDoc(doc(anon(), 'barbershops', 'shop1')));
    await assertFails(getDoc(doc(as('owner2', PHONES.owner2), 'barbershops', 'shop1')));
    await assertSucceeds(getDoc(doc(as('owner1', PHONES.owner1), 'barbershops', 'shop1')));
    await assertSucceeds(getDoc(doc(as('barber1', PHONES.barber1), 'barbershops', 'shop1')));
    await assertSucceeds(getDoc(doc(as('admin', PHONES.admin), 'barbershops', 'shop1')));
  });

  test('customer listener: where subscriptionStatus in visible statuses', async () => {
    await seed('barbershops', 'shop1', newShop('owner1', { subscriptionStatus: 'active' }));
    await seed('barbershops', 'shop2', newShop('owner2', { subscriptionStatus: 'suspended' }));
    const db = as('customer', PHONES.customer);
    const shops = collection(db, 'barbershops');
    const snap = await assertSucceeds(
      getDocs(query(shops, where('subscriptionStatus', 'in', ['trialing', 'active', 'past_due']))),
    );
    assert.equal(snap.size, 1);
    await assertFails(getDocs(shops));
    await assertSucceeds(getDocs(collection(as('admin', PHONES.admin), 'barbershops')));
    await assertFails(getDocs(query(shops, where('subscriptionStatus', 'in', ['active', 'suspended']))));
  });

  test('collection-group reads of services and barbers are public', async () => {
    for (const db of [as('customer', PHONES.customer), as('admin', PHONES.admin), anon()]) {
      const services = await assertSucceeds(getDocs(collectionGroup(db, 'services')));
      assert.equal(services.size, 2);
      const barbers = await assertSucceeds(getDocs(collectionGroup(db, 'barbers')));
      assert.equal(barbers.size, 3);
    }
    await assertFails(getDocs(collectionGroup(anon(), 'slotLocks')));
  });
});

describe('barber working hours', () => {
  test('owner and admin edit a barber profile with working days and hours', async () => {
    const db = as('owner1', PHONES.owner1);
    await assertSucceeds(setDoc(doc(db, 'barbershops/shop1/barbers', 'b9'), { ...barber('shop1', 'New'), workingDays: [1, 2, 3], startHour: 9, endHour: 17 }));
    await assertSucceeds(
      updateDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), {
        name: 'Abel',
        title: 'Senior Barber',
        avatarUrl: deleteField(),
        isAvailable: true,
        email: deleteField(),
        phone: '+251911000201',
        specialties: ['Fade'],
        workingDays: [2, 3, 4, 5, 6],
        startHour: 10,
        endHour: 18,
      }),
    );
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'barbershops/shop1/barbers', 'b1'), { workingDays: deleteField(), startHour: deleteField() }));
  });

  test('working hours are validated', async () => {
    const ref = doc(as('owner1', PHONES.owner1), 'barbershops/shop1/barbers', 'b1');
    await assertFails(updateDoc(ref, { workingDays: [0] }));
    await assertFails(updateDoc(ref, { startHour: 24 }));
    await assertFails(updateDoc(ref, { endHour: 0 }));
    await assertFails(updateDoc(ref, { startHour: '9' }));
  });

  test('barbers cannot change their own hours, only availability', async () => {
    const ref = doc(as('barber1', PHONES.barber1), 'barbershops/shop1/barbers', 'b1');
    await assertFails(updateDoc(ref, { workingDays: [1] }));
    await assertFails(updateDoc(ref, { startHour: 6 }));
    await assertSucceeds(updateDoc(ref, { isAvailable: false }));
  });
});

describe('plans', () => {
  const plan = { name: 'Basic', priceMonthlyEtb: 500, maxBarbers: 3, features: ['Bookings'], active: true };

  test('anyone can read plans', async () => {
    await seed('plans', 'basic', plan);
    await assertSucceeds(getDoc(doc(anon(), 'plans', 'basic')));
    await assertSucceeds(getDocs(collection(as('owner1', PHONES.owner1), 'plans')));
  });

  test('only admins write plans', async () => {
    await assertSucceeds(setDoc(doc(as('admin', PHONES.admin), 'plans', 'pro'), { ...plan, name: 'Pro', maxBarbers: -1 }));
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'plans', 'bad'), { ...plan, priceMonthlyEtb: '500' }));
    await assertFails(setDoc(doc(as('owner1', PHONES.owner1), 'plans', 'cheap'), { ...plan, priceMonthlyEtb: 1 }));
    await assertFails(setDoc(doc(as('customer', PHONES.customer), 'plans', 'cheap'), plan));
    await assertSucceeds(deleteDoc(doc(as('admin', PHONES.admin), 'plans', 'pro')));
  });
});

describe('payments (Cloud Functions only)', () => {
  const payment = (extra = {}) => ({
    type: 'booking',
    bookingId: 'bk1',
    shopId: 'shop1',
    userId: 'customer',
    amount: 450,
    currency: 'ETB',
    provider: 'chapa',
    txRef: 'cb-pay1',
    status: 'pending',
    checkoutUrl: 'https://checkout.chapa.co/x',
    createdAt: NOW,
    ...extra,
  });

  beforeEach(async () => {
    await seed('payments', 'pay1', payment());
    await seed('payments', 'pay2', payment({ shopId: 'shop2', userId: 'customer2', bookingId: 'bkX' }));
    const sub = payment({ type: 'subscription', plan: 'basic', userId: 'owner1', amount: 500 });
    delete sub.bookingId;
    await seed('payments', 'sub1', sub);
  });

  test('payer, shop owner and admin can read a payment', async () => {
    await assertSucceeds(getDoc(doc(as('customer', PHONES.customer), 'payments', 'pay1')));
    await assertSucceeds(getDoc(doc(as('owner1', PHONES.owner1), 'payments', 'pay1')));
    await assertSucceeds(getDoc(doc(as('admin', PHONES.admin), 'payments', 'pay1')));
    await assertFails(getDoc(doc(as('customer2', PHONES.customer2), 'payments', 'pay1')));
    await assertFails(getDoc(doc(as('owner2', PHONES.owner2), 'payments', 'pay1')));
    await assertFails(getDoc(doc(as('barber1', PHONES.barber1), 'payments', 'pay1')));
    await assertFails(getDoc(doc(anon(), 'payments', 'pay1')));
  });

  test('history queries: where userId == uid, and owner where shopId == own shop', async () => {
    const payments = (db) => collection(db, 'payments');
    const mine = await assertSucceeds(getDocs(query(payments(as('customer', PHONES.customer)), where('userId', '==', 'customer'))));
    assert.equal(mine.size, 1);
    const shop = await assertSucceeds(getDocs(query(payments(as('owner1', PHONES.owner1)), where('shopId', '==', 'shop1'))));
    assert.equal(shop.size, 2);
    await assertFails(getDocs(query(payments(as('owner1', PHONES.owner1)), where('shopId', '==', 'shop2'))));
    await assertFails(getDocs(payments(as('customer', PHONES.customer))));
    await assertSucceeds(getDocs(payments(as('admin', PHONES.admin))));
  });

  test('no client can write payments', async () => {
    for (const [uid, phone] of [
      ['customer', PHONES.customer],
      ['owner1', PHONES.owner1],
      ['admin', PHONES.admin],
    ]) {
      const db = as(uid, phone);
      await assertFails(setDoc(doc(db, 'payments', 'new'), payment({ userId: uid })));
      await assertFails(updateDoc(doc(db, 'payments', 'pay1'), { status: 'success' }));
      await assertFails(deleteDoc(doc(db, 'payments', 'pay1')));
    }
  });
});

test('unknown collections are closed', async () => {
  await assertFails(setDoc(doc(as('admin', PHONES.admin), 'anything', 'x'), { a: 1 }));
});

// =====================================================================
// Wave 2: reschedule, cancellation policy, no-show, time off, walk-in
// queue, reviews, insights aggregates.
// =====================================================================

// Addis calendar day of an instant as Dart's DateTime(y, m, d).toIso8601String().
function addisDate(iso) {
  const a = new Date(Date.parse(iso) + ADDIS_MS);
  return `${a.getUTCFullYear()}-${pad(a.getUTCMonth() + 1)}-${pad(a.getUTCDate())}T00:00:00.000`;
}

// 'hh:mm AM/PM' in Addis.
function addisTimeSlot(iso) {
  const a = new Date(Date.parse(iso) + ADDIS_MS);
  const h = a.getUTCHours();
  return `${pad(h % 12 === 0 ? 12 : h % 12)}:${pad(a.getUTCMinutes())} ${h < 12 ? 'AM' : 'PM'}`;
}

// FirestoreDataStore.rescheduleBooking: one transaction that reads the
// booking, the old locks the new interval no longer covers and every new
// lock, then updates the booking, deletes the released locks and creates
// the missing ones. Options let tests drop or alter parts of it.
function rescheduleTx(db, id, newStart, opts = {}) {
  const { ignoreTaken = false, skipDelete = false, skipCreate = false, patch = {}, shopId = 'shop1', barberId = 'b1' } = opts;
  const locks = locksOf(db, shopId, barberId);
  return runTransaction(db, async (tx) => {
    const ref = doc(db, 'bookings', id);
    const b = (await tx.get(ref)).data();
    const minutes = b.durationMinutes;
    const newEnd = plusMinutes(newStart, minutes);
    const newBlocks = blocks(newStart, minutes);
    const newIds = newBlocks.map(lockId);
    const releasable = [];
    for (const s of blocks(b.startAt, minutes)) {
      if (newIds.includes(lockId(s))) continue;
      const snap = await tx.get(doc(locks, lockId(s)));
      if (snap.exists() && snap.data().bookingId === id) releasable.push(snap.ref);
    }
    const toCreate = [];
    for (const s of newBlocks) {
      const snap = await tx.get(doc(locks, lockId(s)));
      if (!snap.exists()) toCreate.push(s);
      else if (snap.data().bookingId !== id && !ignoreTaken) throw new Error('slot taken');
    }
    tx.update(ref, {
      startAt: newStart,
      endAt: newEnd,
      date: addisDate(newStart),
      timeSlot: addisTimeSlot(newStart),
      rescheduleCount: (b.rescheduleCount ?? 0) + 1,
      rescheduledAt: new Date().toISOString(),
      ...patch,
    });
    if (!skipDelete) for (const r of releasable) tx.delete(r);
    if (!skipCreate) for (const s of toCreate) tx.set(doc(locks, lockId(s)), lockDoc(id, s, newEnd));
  });
}

async function seedBookingWithLocks(id, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'bookings', id), data);
    for (const s of blocks(data.startAt, data.durationMinutes)) {
      await setDoc(doc(locksOf(db, data.shopId, data.barberId), lockId(s)), lockDoc(id, s, data.endAt));
    }
  });
}

async function setShopFields(fields, shopId = 'shop1') {
  await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'barbershops', shopId), fields));
}

describe('reschedule (customer transaction)', () => {
  const cust = () => as('customer', PHONES.customer);
  // withSecurityRulesDisabled does not return the callback's result.
  async function adminGet(path, id) {
    let snap;
    await env.withSecurityRulesDisabled(async (ctx) => {
      snap = await getDoc(doc(ctx.firestore(), path, id));
    });
    return snap;
  }
  const lockSnap = (iso, barberId = 'b1') => adminGet(`barbershops/shop1/barbers/${barberId}/slotLocks`, lockId(iso));

  test('moves to a free slot: booking updated, old locks released, new locks created', async () => {
    const to = addisSlot(4, 14);
    await assertSucceeds(rescheduleTx(cust(), 'bk1', to));
    const b = await adminGet('bookings', 'bk1');
    assert.equal(b.data().startAt, to);
    assert.equal(b.data().rescheduleCount, 1);
    for (const s of blocks(START, 40)) assert.equal((await lockSnap(s)).exists(), false);
    for (const s of blocks(to, 40)) assert.equal((await lockSnap(s)).data().bookingId, 'bk1');
    // The old time is free for someone else now.
    await assertSucceeds(bookTx(as('customer2', PHONES.customer2), 'took', newBooking(START, { customerId: 'customer2' })));
  });

  test('moves into an overlapping interval, keeping the shared locks', async () => {
    await assertSucceeds(rescheduleTx(cust(), 'bk1', plusMinutes(START, 15)));
    await assertSucceeds(rescheduleTx(cust(), 'bk1', plusMinutes(START, -15)));
  });

  test('a 120-minute booking moved to a disjoint interval (8 deletes + 8 creates)', async () => {
    await seed('barbershops/shop1/services', 'srvMax', {
      shopId: 'shop1',
      name: 'Wedding Package',
      description: 'Everything',
      price: 1500,
      durationMinutes: 120,
    });
    const at = addisSlot(5, 9);
    await seedBookingWithLocks(
      'bkMax',
      newBooking(at, { serviceId: 'srvMax', serviceName: 'Wedding Package', price: 1500, durationMinutes: 120 }),
    );
    await assertSucceeds(rescheduleTx(cust(), 'bkMax', addisSlot(6, 15)));
    // Worst case for the expression budget: both intervals between 00:00
    // and 03:00 Addis, where every lock id needs timestamp arithmetic.
    const night = addisSlot(8, 0, 15);
    await seedBookingWithLocks(
      'bkNight',
      newBooking(night, { serviceId: 'srvMax', serviceName: 'Wedding Package', price: 1500, durationMinutes: 120 }),
    );
    await assertSucceeds(rescheduleTx(cust(), 'bkNight', addisSlot(9, 0, 30)));
  });

  test('up to the shop maxReschedules (default 2)', async () => {
    await assertSucceeds(rescheduleTx(cust(), 'bk1', addisSlot(4, 9)));
    await assertSucceeds(rescheduleTx(cust(), 'bk1', addisSlot(4, 11)));
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 13)));
    await setShopFields({ maxReschedules: 3 });
    await assertSucceeds(rescheduleTx(cust(), 'bk1', addisSlot(4, 13)));
  });

  test('maxReschedules 0 blocks every reschedule; an out-of-range value reads as 2', async () => {
    await setShopFields({ maxReschedules: 0 });
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9)));
    await setShopFields({ maxReschedules: 99 });
    await assertSucceeds(rescheduleTx(cust(), 'bk1', addisSlot(4, 9)));
    await assertSucceeds(rescheduleTx(cust(), 'bk1', addisSlot(4, 11)));
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 13)));
  });

  test('rescheduleCount must go up by exactly one; rescheduledAt is required', async () => {
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { rescheduleCount: 2 } }));
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { rescheduleCount: 0 } }));
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { rescheduleCount: deleteField() } }));
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { rescheduledAt: deleteField() } }));
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { rescheduledAt: 'yesterday' } }));
  });

  test('inside the cancellation cutoff the customer cannot reschedule', async () => {
    const at = addisSlot(1, 10); // 10 to 34 hours from now
    await seedBookingWithLocks('bkSoon', newBooking(at));
    await setShopFields({ cancellationCutoffHours: 48 });
    await assertFails(rescheduleTx(cust(), 'bkSoon', addisSlot(4, 9)));
    await setShopFields({ cancellationCutoffHours: 0 });
    await assertSucceeds(rescheduleTx(cust(), 'bkSoon', addisSlot(4, 9)));
  });

  test('only the booking customer, and only the reschedule fields', async () => {
    await assertFails(rescheduleTx(as('customer2', PHONES.customer2), 'bk1', addisSlot(4, 9)));
    await assertFails(rescheduleTx(as('owner1', PHONES.owner1), 'bk1', addisSlot(4, 9)));
    await assertFails(rescheduleTx(as('barber1', PHONES.barber1), 'bk1', addisSlot(4, 9)));
    await assertFails(rescheduleTx(as('admin', PHONES.admin), 'bk1', addisSlot(4, 9)));
    for (const patch of [
      { price: 1 },
      { status: 'pending' },
      { serviceId: 'srvLong' },
      { durationMinutes: 15, endAt: plusMinutes(addisSlot(4, 9), 15) },
      { customerName: 'Someone' },
      { paymentStatus: 'paid' },
      { cancelledBy: 'customer' },
    ]) {
      await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch }), JSON.stringify(patch));
    }
  });

  test('a cancelled, started, completed or no-show booking cannot be moved', async () => {
    for (const status of ['cancelled', 'completed', 'noShow', 'inProgress']) {
      await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'bookings', 'bk1'), { status }));
      await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9)), status);
    }
  });

  test('the new interval must be valid as on create', async () => {
    // Not on the grid, in the past, too far ahead, past Addis midnight.
    for (const to of [addisSlot(4, 9, 10), addisSlot(-1, 9), addisSlot(40, 9), addisSlot(4, 23, 45)]) {
      await assertFails(rescheduleTx(cust(), 'bk1', to), to);
    }
    // endAt not start + duration.
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { endAt: plusMinutes(addisSlot(4, 9), 60) } }));
    // Not Dart's ISO format.
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { patch: { startAt: addisSlot(4, 9).replace('.000Z', 'Z') } }));
  });

  test('the new interval must hold its locks', async () => {
    await assertFails(rescheduleTx(cust(), 'bk1', addisSlot(4, 9), { skipCreate: true }));
  });

  test('a slot held by another booking or by time off cannot be taken', async () => {
    const other = addisSlot(4, 9);
    await seedBookingWithLocks('bkOther', newBooking(other, { customerId: 'customer2' }));
    await assertFails(rescheduleTx(cust(), 'bk1', other, { ignoreTaken: true }));
    await assertFails(rescheduleTx(cust(), 'bk1', plusMinutes(other, 30), { ignoreTaken: true }));
    await assert.rejects(rescheduleTx(cust(), 'bk1', other), /slot taken/);
    // A time-off lock.
    const off = addisSlot(4, 14);
    await seed('barbershops/shop1/barbers/b1/timeOff', 'to1', { startAt: off, endAt: plusMinutes(off, 60), createdBy: 'barber1', createdAt: NOW });
    for (const s of blocks(off, 60)) {
      await seed('barbershops/shop1/barbers/b1/slotLocks', lockId(s), { timeOffId: 'to1', startAt: s, expiresAt: plusMinutes(off, 60 + 24 * 60) });
    }
    await assertFails(rescheduleTx(cust(), 'bk1', off, { ignoreTaken: true }));
  });

  test('old locks are released only once the booking no longer covers them', async () => {
    const db = cust();
    // Standalone delete of a live booking's lock (inside its interval).
    await assertFails(deleteDoc(doc(locksOf(db), lockId(START))));
    // Deleting the old locks without moving the booking.
    const batch = writeBatch(db);
    for (const s of blocks(START, 40)) batch.delete(doc(locksOf(db), lockId(s)));
    await assertFails(batch.commit());
    // Another customer or the barber cannot release locks the move left behind.
    await assertSucceeds(rescheduleTx(db, 'bk1', addisSlot(4, 9), { skipDelete: true }));
    await assertFails(deleteDoc(doc(locksOf(as('customer2', PHONES.customer2)), lockId(START))));
    await assertFails(deleteDoc(doc(locksOf(as('barber1', PHONES.barber1)), lockId(START))));
    // The booking's customer can (the block is outside the new interval).
    await assertSucceeds(deleteDoc(doc(locksOf(db), lockId(START))));
    // But not a lock of the new interval.
    await assertFails(deleteDoc(doc(locksOf(db), lockId(addisSlot(4, 9)))));
  });

  test('clients cannot write rescheduleCount or rescheduledAt on create', async () => {
    await assertFails(bookBatch(cust(), 'rc1', newBooking(addisSlot(6, 9), { rescheduleCount: 0 })));
    await assertFails(bookBatch(cust(), 'rc2', newBooking(addisSlot(6, 9), { rescheduledAt: NOW })));
  });
});

describe('cancellation cutoff', () => {
  const at = addisSlot(1, 10); // 10 to 34 hours from now

  beforeEach(async () => {
    await seedBookingWithLocks('bkSoon', newBooking(at));
  });

  test('default cutoff (2 h) lets the customer cancel a booking a day ahead', async () => {
    await assertSucceeds(cancelTx(as('customer', PHONES.customer), 'bkSoon', at, 40, { cancelledBy: 'customer' }));
  });

  test('inside the cutoff the customer cannot cancel', async () => {
    await setShopFields({ cancellationCutoffHours: 48 });
    await assertFails(cancelTx(as('customer', PHONES.customer), 'bkSoon', at, 40, { cancelledBy: 'customer' }));
    await assertFails(updateDoc(doc(as('customer', PHONES.customer), 'bookings', 'bkSoon'), { status: 'cancelled' }));
  });

  test('the owner, the assigned barber and the admin still can', async () => {
    await setShopFields({ cancellationCutoffHours: 72 });
    await assertSucceeds(cancelTx(as('barber1', PHONES.barber1), 'bkSoon', at, 40, { cancelledBy: 'barber1' }));
    await seedBookingWithLocks('bkSoon', newBooking(at));
    await assertSucceeds(cancelTx(as('owner1', PHONES.owner1), 'bkSoon', at, 40, { cancelledBy: 'owner1' }));
    await seedBookingWithLocks('bkSoon', newBooking(at));
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'bookings', 'bkSoon'), { status: 'cancelled', cancelledBy: 'admin' }));
  });

  test('an out-of-range cutoff reads as the default', async () => {
    await setShopFields({ cancellationCutoffHours: 500 });
    await assertSucceeds(cancelTx(as('customer', PHONES.customer), 'bkSoon', at, 40));
  });
});

describe('no-show', () => {
  const past = addisSlot(-1, 10);

  beforeEach(async () => {
    await seedBookingWithLocks('bkPast', newBooking(past));
  });

  test('the assigned barber, the owner or an admin marks it after the start', async () => {
    for (const [uid, phone] of [
      ['barber1', PHONES.barber1],
      ['owner1', PHONES.owner1],
      ['admin', PHONES.admin],
    ]) {
      await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'bookings', 'bkPast'), { status: 'confirmed' }));
      await assertSucceeds(updateDoc(doc(as(uid, phone), 'bookings', 'bkPast'), { status: 'noShow' }), uid);
    }
    // From pending too.
    await seedBookingWithLocks('bkPast2', newBooking(past, { status: 'pending' }));
    await assertSucceeds(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bkPast2'), { status: 'noShow' }));
  });

  test('nobody else, and never before the start', async () => {
    for (const [uid, phone] of [
      ['customer', PHONES.customer],
      ['customer2', PHONES.customer2],
      ['barber2', PHONES.barber2],
      ['owner2', PHONES.owner2],
    ]) {
      await assertFails(updateDoc(doc(as(uid, phone), 'bookings', 'bkPast'), { status: 'noShow' }), uid);
    }
    for (const [uid, phone] of [
      ['barber1', PHONES.barber1],
      ['owner1', PHONES.owner1],
      ['admin', PHONES.admin],
    ]) {
      await assertFails(updateDoc(doc(as(uid, phone), 'bookings', 'bk1'), { status: 'noShow' }), uid);
    }
  });

  test('only from pending or confirmed, only the status, and it is final', async () => {
    const barber = doc(as('barber1', PHONES.barber1), 'bookings', 'bkPast');
    for (const status of ['completed', 'inProgress', 'cancelled']) {
      await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'bookings', 'bkPast'), { status }));
      await assertFails(updateDoc(barber, { status: 'noShow' }), status);
    }
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'bookings', 'bkPast'), { status: 'confirmed' }));
    await assertFails(updateDoc(barber, { status: 'noShow', cancelledBy: 'barber1' }));
    await assertSucceeds(updateDoc(barber, { status: 'noShow' }));
    await assertFails(updateDoc(barber, { status: 'completed' }));
    await assertFails(updateDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bkPast'), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(as('admin', PHONES.admin), 'bookings', 'bkPast'), { status: 'confirmed' }));
    // The admin's payment correction still works on a no-show booking.
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'bookings', 'bkPast'), { paymentStatus: 'refunded' }));
    // Its locks are kept and are not released by the customer.
    await assertFails(deleteDoc(doc(locksOf(as('customer', PHONES.customer)), lockId(past))));
  });

  test('existing status updates are unchanged (inProgress / completed)', async () => {
    await assertSucceeds(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bkPast'), { status: 'inProgress' }));
    await assertSucceeds(updateDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bkPast'), { status: 'completed' }));
  });
});

describe('shop booking policy', () => {
  const policy = (cancellationCutoffHours, maxReschedules) => ({ cancellationCutoffHours, maxReschedules });

  test('the owner and the admin set cutoff (0..72) and max reschedules (0..5)', async () => {
    const owner = doc(as('owner1', PHONES.owner1), 'barbershops', 'shop1');
    await assertSucceeds(updateDoc(owner, policy(24, 1)));
    await assertSucceeds(updateDoc(owner, policy(0, 0)));
    await assertSucceeds(updateDoc(owner, policy(72, 5)));
    await assertSucceeds(updateDoc(doc(as('admin', PHONES.admin), 'barbershops', 'shop1'), policy(2, 2)));
  });

  test('out-of-range or non-integer values are rejected', async () => {
    const owner = doc(as('owner1', PHONES.owner1), 'barbershops', 'shop1');
    for (const [c, m] of [[73, 2], [-1, 2], [2, 6], [2, -1], ['2', 2], [2.5, 2], [2, 1.5]]) {
      await assertFails(updateDoc(owner, policy(c, m)), `${c}/${m}`);
    }
  });

  test('other owners, barbers and customers cannot change it', async () => {
    await assertFails(updateDoc(doc(as('owner2', PHONES.owner2), 'barbershops', 'shop1'), policy(0, 5)));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'barbershops', 'shop1'), policy(0, 5)));
    await assertFails(updateDoc(doc(as('customer', PHONES.customer), 'barbershops', 'shop1'), policy(0, 5)));
  });

  test('admin createShop (toMap) carries the policy fields', async () => {
    const admin = as('admin', PHONES.admin);
    await assertSucceeds(setDoc(doc(admin, 'barbershops', 'pol1'), newShop('', policy(2, 2))));
    await assertFails(setDoc(doc(admin, 'barbershops', 'pol2'), newShop('', policy(100, 2))));
    await assertFails(setDoc(doc(admin, 'barbershops', 'pol3'), newShop('', policy(2, 9))));
  });
});

describe('rating and reviewCount are written by functions only', () => {
  test('no client changes shop or barber ratings, admin included', async () => {
    for (const [uid, phone] of [
      ['admin', PHONES.admin],
      ['owner1', PHONES.owner1],
    ]) {
      const db = as(uid, phone);
      await assertFails(updateDoc(doc(db, 'barbershops', 'shop1'), { rating: 1 }), uid);
      await assertFails(updateDoc(doc(db, 'barbershops', 'shop1'), { reviewCount: 99 }), uid);
      await assertFails(updateDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), { rating: 1 }), uid);
      await assertFails(updateDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), { reviewCount: 99 }), uid);
    }
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'barbershops/shop1/barbers', 'b1'), { rating: 1 }));
  });

  test('new shops and barbers start with no reviews', async () => {
    await assertFails(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'fake'), newShop('', { reviewCount: 500 })));
    await assertFails(setDoc(doc(as('owner1', PHONES.owner1), 'barbershops/shop1/barbers', 'b9'), { ...barber('shop1', 'New'), reviewCount: 40 }));
    await assertSucceeds(setDoc(doc(as('owner1', PHONES.owner1), 'barbershops/shop1/barbers', 'b9'), barber('shop1', 'New')));
  });
});

describe('barber time off', () => {
  const OFF = addisSlot(1, 13);
  const OFF_END = addisSlot(1, 15);

  // FirestoreDataStore.addTimeOff: one batch with the doc and its locks.
  function timeOffBatch(db, uid, opts = {}) {
    const {
      id = 'to1',
      barberId = 'b1',
      startAt = OFF,
      endAt = OFF_END,
      data = {},
      lockStarts,
      lockPatch = {},
      skipDoc = false,
    } = opts;
    const batch = writeBatch(db);
    if (!skipDoc) {
      batch.set(doc(db, `barbershops/shop1/barbers/${barberId}/timeOff`, id), {
        startAt,
        endAt,
        createdBy: uid,
        createdAt: new Date().toISOString(),
        ...data,
      });
    }
    const minutes = Math.max(0, (Date.parse(endAt) - Date.parse(startAt)) / 60000);
    for (const s of lockStarts ?? blocks(startAt, minutes)) {
      batch.set(doc(locksOf(db, 'shop1', barberId), lockId(s)), {
        timeOffId: id,
        startAt: s,
        expiresAt: plusMinutes(endAt, 24 * 60),
        ...lockPatch,
      });
    }
    return batch.commit();
  }

  const barber1 = () => as('barber1', PHONES.barber1);
  const owner1 = () => as('owner1', PHONES.owner1);

  test('the barber adds their own time off; customers can no longer book it', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1', { data: { reason: 'Doctor' } }));
    await assertFails(bookBatch(as('customer', PHONES.customer), 'inOff', newBooking(OFF)));
    await assertFails(bookBatch(as('customer', PHONES.customer), 'inOff2', newBooking(plusMinutes(OFF, -30))));
    await assertSucceeds(bookBatch(as('customer', PHONES.customer), 'afterOff', newBooking(OFF_END)));
  });

  test('the owner adds time off for any barber of the shop', async () => {
    await assertSucceeds(timeOffBatch(owner1(), 'owner1', { barberId: 'b2' }));
  });

  test('a whole Addis day (96 locks, across the UTC date change) fits in one batch', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1', { id: 'day', startAt: addisSlot(2, 0), endAt: addisSlot(3, 0) }));
  });

  test('other barbers, other owners, customers and admins cannot add it', async () => {
    await assertFails(timeOffBatch(as('barber2', PHONES.barber2), 'barber2'));
    await assertFails(timeOffBatch(as('owner2', PHONES.owner2), 'owner2'));
    await assertFails(timeOffBatch(as('customer', PHONES.customer), 'customer'));
    await assertFails(timeOffBatch(as('admin', PHONES.admin), 'admin'));
  });

  test('the doc and its locks go together', async () => {
    // Doc without locks, or without its last or first lock.
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockStarts: [] }));
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockStarts: blocks(OFF, 105) }));
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockStarts: blocks(plusMinutes(OFF, 15), 105) }));
    // Locks without the doc.
    await assertFails(timeOffBatch(barber1(), 'barber1', { skipDoc: true }));
  });

  test('locks must match the range, id, expiry and shape', async () => {
    // A lock outside the range.
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockStarts: [...blocks(OFF, 120), OFF_END] }));
    // Wrong expiresAt.
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockPatch: { expiresAt: plusMinutes(OFF_END, 48 * 60) } }));
    // Extra fields: a bookingId or customer data.
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockPatch: { bookingId: 'bk1' } }));
    await assertFails(timeOffBatch(barber1(), 'barber1', { lockPatch: { customerId: 'customer' } }));
    // Under another barber than the time off.
    const db = barber1();
    const batch = writeBatch(db);
    batch.set(doc(db, 'barbershops/shop1/barbers/b1/timeOff', 'x1'), { startAt: OFF, endAt: OFF_END, createdBy: 'barber1', createdAt: NOW });
    for (const s of blocks(OFF, 120)) {
      batch.set(doc(locksOf(db), lockId(s)), { timeOffId: 'x1', startAt: s, expiresAt: plusMinutes(OFF_END, 24 * 60) });
    }
    batch.set(doc(locksOf(db, 'shop1', 'b2'), lockId(OFF)), { timeOffId: 'x1', startAt: OFF, expiresAt: plusMinutes(OFF_END, 24 * 60) });
    await assertFails(batch.commit());
  });

  test('the time-off doc is validated', async () => {
    const b = barber1();
    // createdBy someone else; a reason over 200; an empty reason; unknown keys.
    await assertFails(timeOffBatch(b, 'barber1', { data: { createdBy: 'owner1' } }));
    await assertFails(timeOffBatch(b, 'barber1', { data: { reason: 'x'.repeat(201) } }));
    await assertFails(timeOffBatch(b, 'barber1', { data: { reason: '' } }));
    await assertFails(timeOffBatch(b, 'barber1', { data: { shopId: 'shop1' } }));
    await assertSucceeds(timeOffBatch(b, 'barber1', { data: { reason: 'x'.repeat(200) } }));
  });

  test('the range is on the grid, ends after it starts, within one Addis day and not over', async () => {
    const b = barber1();
    // Off the grid.
    await assertFails(timeOffBatch(b, 'barber1', { startAt: addisSlot(1, 13, 10), endAt: addisSlot(1, 15), lockStarts: [] }));
    // End before start.
    await assertFails(timeOffBatch(b, 'barber1', { startAt: OFF_END, endAt: OFF, lockStarts: [OFF] }));
    // Past Addis midnight (22:00 to 02:00).
    await assertFails(timeOffBatch(b, 'barber1', { startAt: addisSlot(1, 22), endAt: addisSlot(2, 2) }));
    // Already over.
    await assertFails(timeOffBatch(b, 'barber1', { startAt: addisSlot(-1, 9), endAt: addisSlot(-1, 11) }));
    // Up to midnight is fine.
    await assertSucceeds(timeOffBatch(b, 'barber1', { id: 'eve', startAt: addisSlot(1, 22), endAt: addisSlot(2, 0) }));
  });

  test('time off cannot overlap a booking or other time off (the lock ids collide)', async () => {
    await assertFails(timeOffBatch(barber1(), 'barber1', { startAt: plusMinutes(START, -30), endAt: plusMinutes(START, 30) }));
    await assertSucceeds(timeOffBatch(barber1(), 'barber1', { startAt: plusMinutes(START, 45), endAt: plusMinutes(START, 105) }));
    await assertFails(timeOffBatch(barber1(), 'barber1', { id: 'to2', startAt: plusMinutes(START, 90), endAt: plusMinutes(START, 120) }));
  });

  test('time off docs are never updated', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1'));
    await assertFails(updateDoc(doc(barber1(), 'barbershops/shop1/barbers/b1/timeOff', 'to1'), { endAt: addisSlot(1, 18) }));
    await assertFails(updateDoc(doc(owner1(), 'barbershops/shop1/barbers/b1/timeOff', 'to1'), { reason: 'x' }));
  });

  test('read: the owner and that barber (listener on endAt), nobody else', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1'));
    const since = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
    const q = (db) => query(collection(db, 'barbershops/shop1/barbers/b1/timeOff'), where('endAt', '>=', since), orderBy('endAt'));
    assert.equal((await assertSucceeds(getDocs(q(barber1())))).size, 1);
    assert.equal((await assertSucceeds(getDocs(q(owner1())))).size, 1);
    for (const [uid, phone] of [
      ['barber2', PHONES.barber2],
      ['owner2', PHONES.owner2],
      ['customer', PHONES.customer],
      ['admin', PHONES.admin],
    ]) {
      await assertFails(getDocs(q(as(uid, phone))), uid);
    }
    await assertFails(getDocs(q(anon())));
    // Customers still see the locks (busy times), which carry no reason.
    const locks = await assertSucceeds(getDocs(query(locksOf(as('customer', PHONES.customer)), where('timeOffId', '==', 'to1'))));
    assert.equal(locks.size, 8);
  });

  // FirestoreDataStore.deleteTimeOff: query its locks, delete them and the doc in one batch.
  async function deleteTimeOffBatch(db, id = 'to1', { keepDoc = false, keepLocks = false } = {}) {
    const locks = await getDocs(query(locksOf(db), where('timeOffId', '==', id)));
    const batch = writeBatch(db);
    if (!keepLocks) for (const d of locks.docs) batch.delete(d.ref);
    if (!keepDoc) batch.delete(doc(db, 'barbershops/shop1/barbers/b1/timeOff', id));
    return batch.commit();
  }

  test('the barber or the owner deletes the doc and its locks together', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1'));
    await assertSucceeds(deleteTimeOffBatch(barber1()));
    await assertSucceeds(bookBatch(as('customer', PHONES.customer), 'freed', newBooking(OFF)));
    await assertSucceeds(timeOffBatch(owner1(), 'owner1', { id: 'to3', startAt: addisSlot(2, 9), endAt: addisSlot(2, 12) }));
    await assertSucceeds(deleteTimeOffBatch(owner1(), 'to3'));
  });

  test('a whole-day time off (96 locks) is deleted in one batch', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1', { id: 'day', startAt: addisSlot(2, 0), endAt: addisSlot(3, 0) }));
    await assertSucceeds(deleteTimeOffBatch(barber1(), 'day'));
    await assertSucceeds(timeOffBatch(owner1(), 'owner1', { id: 'day2', startAt: addisSlot(2, 0), endAt: addisSlot(3, 0) }));
    await assertSucceeds(deleteTimeOffBatch(owner1(), 'day2'));
  });

  test('not separately (barber), and not by anyone else', async () => {
    await assertSucceeds(timeOffBatch(barber1(), 'barber1'));
    await assertFails(deleteTimeOffBatch(barber1(), 'to1', { keepLocks: true }));
    await assertFails(deleteTimeOffBatch(barber1(), 'to1', { keepDoc: true }));
    await assertFails(deleteDoc(doc(locksOf(barber1()), lockId(OFF))));
    for (const [uid, phone] of [
      ['barber2', PHONES.barber2],
      ['owner2', PHONES.owner2],
      ['customer', PHONES.customer],
    ]) {
      await assertFails(deleteTimeOffBatch(as(uid, phone)), uid);
      await assertFails(deleteDoc(doc(locksOf(as(uid, phone)), lockId(OFF))), uid);
    }
  });
});

describe('walk-in queue', () => {
  const queue = (db, shopId = 'shop1') => collection(db, `barbershops/${shopId}/queue`);
  const entry = (overrides = {}) => ({
    name: 'Dawit',
    status: 'waiting',
    createdAt: new Date().toISOString(),
    addedBy: 'owner1',
    source: 'walkIn',
    ...overrides,
  });

  beforeEach(async () => {
    await seed('barbershops/shop1/queue', 'w1', entry({ phone: '+251911555555', serviceId: 'srv1' }));
    await seed('barbershops/shop1/queue', 's1', entry({ status: 'serving', barberId: 'b2', servingStartedAt: NOW, addedBy: 'barber2' }));
    await seed('barbershops/shop1/queue', 'r1', entry({ name: 'customer', phone: PHONES.customer, addedBy: 'customer', source: 'remote' }));
    await seed('barbershops/shop1/queue', 'r2', entry({ name: 'customer2', phone: PHONES.customer2, addedBy: 'customer2', source: 'remote' }));
  });

  const activeQuery = (db) =>
    query(queue(db), where('status', 'in', ['waiting', 'serving']), orderBy('createdAt'), limit(200));
  const ownQuery = (db, uid) => query(queue(db), where('addedBy', '==', uid), orderBy('createdAt', 'desc'), limit(1));

  test('staff list every active entry of their shop', async () => {
    assert.equal((await assertSucceeds(getDocs(activeQuery(as('owner1', PHONES.owner1))))).size, 4);
    assert.equal((await assertSucceeds(getDocs(activeQuery(as('barber1', PHONES.barber1))))).size, 4);
    await assertFails(getDocs(activeQuery(as('owner2', PHONES.owner2))));
    await assertFails(getDocs(activeQuery(as('customer', PHONES.customer))));
    await assertFails(getDocs(activeQuery(as('admin', PHONES.admin))));
    await assertFails(getDocs(activeQuery(anon())));
  });

  test('a removed barber profile loses access', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'barbershops/shop1/barbers', 'b1')));
    await assertFails(getDocs(activeQuery(as('barber1', PHONES.barber1))));
  });

  test('customers read only their own entry', async () => {
    const db = as('customer', PHONES.customer);
    const snap = await assertSucceeds(getDocs(ownQuery(db, 'customer')));
    assert.deepEqual(snap.docs.map((d) => d.id), ['r1']);
    await assertSucceeds(getDoc(doc(queue(db), 'r1')));
    await assertFails(getDoc(doc(queue(db), 'r2')));
    await assertFails(getDoc(doc(queue(db), 'w1')));
    await assertFails(getDocs(ownQuery(db, 'customer2')));
  });

  test('staff add walk-ins', async () => {
    await assertSucceeds(setDoc(doc(queue(as('owner1', PHONES.owner1)), 'n1'), entry({ phone: '+251712345678', serviceId: 'srv1', barberId: 'b1' })));
    await assertSucceeds(setDoc(doc(queue(as('barber1', PHONES.barber1)), 'n2'), entry({ addedBy: 'barber1' })));
    await assertFails(setDoc(doc(queue(as('owner2', PHONES.owner2)), 'n3'), entry({ addedBy: 'owner2' })));
    await assertFails(setDoc(doc(queue(as('admin', PHONES.admin)), 'n4'), entry({ addedBy: 'admin' })));
  });

  test('walk-in entries are validated', async () => {
    const db = as('owner1', PHONES.owner1);
    for (const [name, overrides] of [
      ['long name', { name: 'x'.repeat(61) }],
      ['empty name', { name: '' }],
      ['bad phone', { phone: '0911223344' }],
      ['landline', { phone: '+251115512345' }],
      ['serving', { status: 'serving' }],
      ['servingStartedAt', { servingStartedAt: NOW }],
      ['finishedAt', { finishedAt: NOW }],
      ['addedBy', { addedBy: 'barber1' }],
      ['source', { source: 'web' }],
      ['unknown barber', { barberId: 'b3' }],
      ['unknown service', { serviceId: 'nope' }],
      ['extra', { shopId: 'shop1' }],
      ['createdAt', { createdAt: 'now' }],
    ]) {
      await assertFails(setDoc(doc(queue(db), `bad-${name.replace(' ', '-')}`), entry(overrides)), name);
    }
  });

  test('a signed-in customer joins remotely with their own phone', async () => {
    const db = as('customer2', PHONES.customer2);
    const mine = entry({ name: 'Liya', phone: PHONES.customer2, addedBy: 'customer2', source: 'remote', serviceId: 'srv1', barberId: 'b1' });
    await assertSucceeds(setDoc(doc(queue(db), 'j1'), mine));
    const noPhone = { ...mine };
    delete noPhone.phone;
    await assertSucceeds(setDoc(doc(queue(db), 'j2'), noPhone));
    // Someone else's phone, someone else's uid, a walk-in, or already serving.
    await assertFails(setDoc(doc(queue(db), 'j3'), { ...mine, phone: PHONES.customer }));
    await assertFails(setDoc(doc(queue(db), 'j4'), { ...mine, addedBy: 'customer' }));
    await assertFails(setDoc(doc(queue(db), 'j5'), { ...mine, source: 'walkIn' }));
    await assertFails(setDoc(doc(queue(db), 'j6'), { ...mine, status: 'serving' }));
    // Staff cannot join as remote customers; anonymous users cannot join.
    await assertFails(setDoc(doc(queue(as('barber1', PHONES.barber1)), 'j7'), { ...mine, addedBy: 'barber1', phone: PHONES.barber1 }));
    await assertFails(setDoc(doc(queue(anon()), 'j8'), mine));
  });

  test('customers cannot join the queue of a suspended shop', async () => {
    await setShopFields({ subscriptionStatus: 'suspended' });
    const mine = entry({ name: 'Liya', phone: PHONES.customer2, addedBy: 'customer2', source: 'remote' });
    await assertFails(setDoc(doc(queue(as('customer2', PHONES.customer2)), 'j1'), mine));
  });

  test('staff start serving, finish and mark left', async () => {
    const barber = queue(as('barber1', PHONES.barber1));
    const later = new Date().toISOString();
    await assertSucceeds(updateDoc(doc(barber, 'w1'), { status: 'serving', barberId: 'b1', servingStartedAt: later }));
    await assertSucceeds(updateDoc(doc(barber, 'w1'), { status: 'done', finishedAt: later }));
    const owner = queue(as('owner1', PHONES.owner1));
    await assertSucceeds(updateDoc(doc(owner, 's1'), { status: 'done', finishedAt: later }));
    await assertSucceeds(updateDoc(doc(owner, 'r2'), { status: 'left', finishedAt: later }));
  });

  test('staff updates follow the status flow and touch nothing else', async () => {
    const owner = queue(as('owner1', PHONES.owner1));
    const later = new Date().toISOString();
    // Serving with a barber of another shop or none.
    await assertFails(updateDoc(doc(owner, 'w1'), { status: 'serving', barberId: 'b3', servingStartedAt: later }));
    await assertFails(updateDoc(doc(owner, 'w1'), { status: 'serving', servingStartedAt: later }));
    // Wrong transitions.
    await assertFails(updateDoc(doc(owner, 'w1'), { status: 'done', finishedAt: later }));
    await assertFails(updateDoc(doc(owner, 's1'), { status: 'left', finishedAt: later }));
    await assertFails(updateDoc(doc(owner, 's1'), { status: 'waiting' }));
    // Other fields.
    await assertFails(updateDoc(doc(owner, 'w1'), { name: 'Renamed' }));
    await assertFails(updateDoc(doc(owner, 'w1'), { status: 'left', finishedAt: later, addedBy: 'x' }));
    await assertFails(updateDoc(doc(owner, 'w1'), { status: 'left' }));
    // Another shop's staff.
    await assertFails(updateDoc(doc(queue(as('owner2', PHONES.owner2)), 'w1'), { status: 'left', finishedAt: later }));
  });

  test('a customer leaves only their own waiting remote entry', async () => {
    const db = queue(as('customer', PHONES.customer));
    const later = new Date().toISOString();
    await assertFails(updateDoc(doc(db, 'r1'), { status: 'serving', barberId: 'b1', servingStartedAt: later }));
    await assertFails(updateDoc(doc(db, 'r1'), { status: 'done', finishedAt: later }));
    await assertFails(updateDoc(doc(db, 'r1'), { status: 'left', finishedAt: later, name: 'x' }));
    await assertFails(updateDoc(doc(db, 'r2'), { status: 'left', finishedAt: later }));
    await assertFails(updateDoc(doc(db, 'w1'), { status: 'left', finishedAt: later }));
    await assertSucceeds(updateDoc(doc(db, 'r1'), { status: 'left', finishedAt: later }));
    // Not back again.
    await assertFails(updateDoc(doc(db, 'r1'), { status: 'waiting' }));
  });

  test('nobody deletes queue entries', async () => {
    for (const [uid, phone] of [
      ['owner1', PHONES.owner1],
      ['barber1', PHONES.barber1],
      ['customer', PHONES.customer],
      ['admin', PHONES.admin],
    ]) {
      await assertFails(deleteDoc(doc(queue(as(uid, phone)), 'r1')), uid);
    }
  });

  test('queueSummary/current: public read, functions-only writes', async () => {
    await seed('barbershops/shop1/queueSummary', 'current', { waitingCount: 3, estimatedWaitMinutes: 35, updatedAt: NOW, positions: {} });
    await assertSucceeds(getDoc(doc(anon(), 'barbershops/shop1/queueSummary', 'current')));
    await assertSucceeds(getDoc(doc(as('customer', PHONES.customer), 'barbershops/shop1/queueSummary', 'current')));
    for (const [uid, phone] of [
      ['owner1', PHONES.owner1],
      ['barber1', PHONES.barber1],
      ['customer', PHONES.customer],
      ['admin', PHONES.admin],
    ]) {
      const ref = doc(as(uid, phone), 'barbershops/shop1/queueSummary', 'current');
      await assertFails(setDoc(ref, { waitingCount: 0, estimatedWaitMinutes: 0, updatedAt: NOW }), uid);
      await assertFails(updateDoc(ref, { waitingCount: 0 }), uid);
      await assertFails(deleteDoc(ref), uid);
    }
  });

  test('queueNext inbox entries: read and mark read like other notifications', async () => {
    const id = 'queue_r1-1700000000000_queueNext';
    await seed('users/customer/notifications', id, { title: 'You are next', body: 'Come in', type: 'queueNext', shopId: 'shop1', queueEntryId: 'r1', read: false, createdAt: NOW });
    const db = as('customer', PHONES.customer);
    await assertSucceeds(getDoc(doc(db, 'users/customer/notifications', id)));
    await assertSucceeds(updateDoc(doc(db, 'users/customer/notifications', id), { read: true }));
    await assertFails(setDoc(doc(db, 'users/customer/notifications', 'queue_x_queueNext'), { title: 'x', body: 'x', type: 'queueNext', read: false, createdAt: NOW }));
  });
});

describe('reviews', () => {
  const reviews = (db, shopId = 'shop1') => collection(db, `barbershops/${shopId}/reviews`);
  const review = (overrides = {}) => ({
    bookingId: 'bkDone',
    shopId: 'shop1',
    barberId: 'b1',
    customerId: 'customer',
    customerName: 'customer',
    rating: 5,
    comment: 'Great fade',
    createdAt: new Date().toISOString(),
    ...overrides,
  });

  beforeEach(async () => {
    await seed('bookings', 'bkDone', booking({ status: 'completed', startAt: addisSlot(-2, 10), endAt: plusMinutes(addisSlot(-2, 10), 40) }));
    await seed('bookings', 'bkDone2', booking({ customerId: 'customer2', customerName: 'Liya', status: 'completed', barberId: 'b2', barberName: 'Biruk' }));
    await seed('barbershops/shop1/reviews', 'bkDone2', review({ bookingId: 'bkDone2', customerId: 'customer2', customerName: 'Liya', barberId: 'b2', rating: 3 }));
  });

  // ReviewsService.submitReview: a transaction that aborts if the review exists.
  function createReviewTx(db, data, id = data.bookingId) {
    return runTransaction(db, async (tx) => {
      const ref = doc(reviews(db, 'shop1'), id);
      if ((await tx.get(ref)).exists()) throw new Error('already reviewed');
      tx.set(ref, data);
    });
  }

  test('the customer reviews a completed booking once', async () => {
    const db = as('customer', PHONES.customer);
    await assertSucceeds(createReviewTx(db, review()));
    await assert.rejects(createReviewTx(db, review()), /already reviewed/);
    // A blind second write is an update, which customers cannot make.
    await assertFails(setDoc(doc(reviews(db), 'bkDone'), review({ rating: 1 })));
    await assertFails(updateDoc(doc(reviews(db), 'bkDone'), { rating: 1 }));
    await assertFails(updateDoc(doc(reviews(db), 'bkDone'), { comment: 'Edited' }));
    await assertFails(deleteDoc(doc(reviews(db), 'bkDone')));
  });

  test('without a comment', async () => {
    const data = review();
    delete data.comment;
    await assertSucceeds(createReviewTx(as('customer', PHONES.customer), data));
  });

  test('only for their own completed booking, matching the booking', async () => {
    const cust = as('customer', PHONES.customer);
    await assertFails(createReviewTx(as('customer2', PHONES.customer2), review({ customerId: 'customer2' })));
    await assertFails(createReviewTx(as('owner1', PHONES.owner1), review({ customerId: 'owner1' })));
    await assertFails(createReviewTx(cust, review({ bookingId: 'bk1' })));
    await assertFails(createReviewTx(cust, review({ bookingId: 'nope' })));
    await assertFails(createReviewTx(cust, review(), 'other-id'));
    await assertFails(createReviewTx(cust, review({ barberId: 'b2' })));
    await assertFails(createReviewTx(cust, review({ customerName: 'Fake Name' })));
    await assertFails(createReviewTx(cust, review({ shopId: 'shop2' })));
    await assertFails(createReviewTx(anon(), review()));
  });

  test('rating is an integer 1..5; comment 1..500; no extra or reply fields', async () => {
    const cust = as('customer', PHONES.customer);
    for (const [name, overrides] of [
      ['0', { rating: 0 }],
      ['6', { rating: 6 }],
      ['4.5', { rating: 4.5 }],
      ['string', { rating: '5' }],
      ['empty comment', { comment: '' }],
      ['long comment', { comment: 'x'.repeat(501) }],
      ['reply', { reply: 'Thanks', replyAt: NOW }],
      ['extra', { photo: 'x' }],
      ['createdAt', { createdAt: 12 }],
    ]) {
      await assertFails(createReviewTx(cust, review(overrides)), name);
    }
    await assertSucceeds(createReviewTx(cust, review({ rating: 1, comment: 'x'.repeat(500) })));
  });

  test('public read: anyone lists, pages and counts reviews', async () => {
    for (const db of [anon(), as('customer', PHONES.customer), as('barber1', PHONES.barber1)]) {
      await assertSucceeds(getDocs(query(reviews(db), orderBy('createdAt', 'desc'), limit(4))));
      await assertSucceeds(getDocs(query(reviews(db), where('barberId', '==', 'b2'), orderBy('createdAt', 'desc'), limit(11))));
      await assertSucceeds(getDoc(doc(reviews(db), 'bkDone2')));
      await assertSucceeds(getDoc(doc(reviews(db), 'missing')));
      const count = await assertSucceeds(getCountFromServer(query(reviews(db), where('rating', '==', 3))));
      assert.equal(count.data().count, 1);
    }
  });

  test('the owner adds and edits a reply, nothing else', async () => {
    const ref = doc(reviews(as('owner1', PHONES.owner1)), 'bkDone2');
    await assertSucceeds(updateDoc(ref, { reply: 'Thank you!', replyAt: NOW }));
    await assertSucceeds(updateDoc(ref, { reply: 'Edited reply', replyAt: new Date().toISOString() }));
    await assertFails(updateDoc(ref, { reply: '', replyAt: NOW }));
    await assertFails(updateDoc(ref, { reply: 'x'.repeat(501), replyAt: NOW }));
    await assertFails(updateDoc(ref, { reply: 'No date', replyAt: deleteField() }));
    await assertFails(updateDoc(ref, { rating: 5 }));
    await assertFails(updateDoc(ref, { reply: 'Hi', replyAt: NOW, comment: 'Changed' }));
    await assertFails(deleteDoc(ref));
  });

  test('nobody else replies or deletes', async () => {
    for (const [uid, phone] of [
      ['owner2', PHONES.owner2],
      ['barber2', PHONES.barber2],
      ['customer2', PHONES.customer2],
      ['admin', PHONES.admin],
    ]) {
      const ref = doc(reviews(as(uid, phone)), 'bkDone2');
      await assertFails(updateDoc(ref, { reply: 'Hi', replyAt: NOW }), uid);
      await assertFails(deleteDoc(ref), uid);
    }
  });
});

describe('insights aggregates (functions only)', () => {
  beforeEach(async () => {
    await seed('barbershops/shop1/stats', '2026-11', { month: '2026-11', bookings: 3, completed: 2, cancelled: 1, noShows: 0, revenueEtb: 900, byService: {}, byBarber: {}, updatedAt: NOW });
    await seed('barbershops/shop1/clients', 'customer', { customerId: 'customer', name: 'customer', phone: PHONES.customer, completedCount: 2, noShowCount: 0, cancelledCount: 1, lastVisitAt: NOW });
    await seed('insightsApplied', 'bk1', { shopId: 'shop1', updatedAt: NOW, contribution: {} });
  });

  test('the owner and the admin read stats and clients', async () => {
    for (const [uid, phone] of [
      ['owner1', PHONES.owner1],
      ['admin', PHONES.admin],
    ]) {
      const db = as(uid, phone);
      await assertSucceeds(getDoc(doc(db, 'barbershops/shop1/stats', '2026-11')), uid);
      await assertSucceeds(getDoc(doc(db, 'barbershops/shop1/stats', '2026-10')), uid);
      await assertSucceeds(getDocs(query(collection(db, 'barbershops/shop1/clients'), orderBy('completedCount', 'desc'), limit(100))), uid);
    }
  });

  test('barbers, customers, other owners and anonymous users read nothing', async () => {
    for (const [uid, phone] of [
      ['barber1', PHONES.barber1],
      ['customer', PHONES.customer],
      ['owner2', PHONES.owner2],
    ]) {
      const db = as(uid, phone);
      await assertFails(getDoc(doc(db, 'barbershops/shop1/stats', '2026-11')), uid);
      await assertFails(getDoc(doc(db, 'barbershops/shop1/clients', 'customer')), uid);
      await assertFails(getDocs(collection(db, 'barbershops/shop1/clients')), uid);
    }
    await assertFails(getDoc(doc(anon(), 'barbershops/shop1/stats', '2026-11')));
  });

  test('no client writes stats, clients or insightsApplied', async () => {
    for (const [uid, phone] of [
      ['owner1', PHONES.owner1],
      ['admin', PHONES.admin],
      ['customer', PHONES.customer],
    ]) {
      const db = as(uid, phone);
      await assertFails(setDoc(doc(db, 'barbershops/shop1/stats', '2026-12'), { month: '2026-12' }), uid);
      await assertFails(updateDoc(doc(db, 'barbershops/shop1/stats', '2026-11'), { revenueEtb: 1 }), uid);
      await assertFails(deleteDoc(doc(db, 'barbershops/shop1/stats', '2026-11')), uid);
      await assertFails(updateDoc(doc(db, 'barbershops/shop1/clients', 'customer'), { noShowCount: 0 }), uid);
      await assertFails(deleteDoc(doc(db, 'barbershops/shop1/clients', 'customer')), uid);
      await assertFails(getDoc(doc(db, 'insightsApplied', 'bk1')), uid);
      await assertFails(setDoc(doc(db, 'insightsApplied', 'bk2'), { shopId: 'shop1' }), uid);
    }
  });
});
