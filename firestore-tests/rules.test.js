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
      await setDoc(doc(db, 'barbershops/shop1/barbers/b1/slotLocks', lockId(b)), {
        bookingId: 'bk1',
        customerId: 'customer',
        startAt: b,
      });
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

function lockDoc(bookingId, startAt, customerId = 'customer') {
  return { bookingId, customerId, startAt };
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
      tx.set(doc(locksOf(db, data.shopId, data.barberId), lockId(s)), lockDoc(id, s, data.customerId));
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
    batch.set(doc(locksOf(db, data.shopId, data.barberId), lockId(s)), lockDoc(id, s, data.customerId));
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
    await assertSucceeds(setDoc(doc(as('admin', PHONES.admin), 'barbershops', 'new'), shop('')));
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
    await assertFails(setDoc(doc(locksOf(db2), lockId(later)), lockDoc('bk1', later, 'customer2')));
    await assertFails(setDoc(doc(locksOf(db), lockId(later)), lockDoc('bk1', later, 'customer2')));
    // Outside the booking's interval.
    await assertFails(setDoc(doc(locksOf(db), lockId(later)), lockDoc('bk1', later)));
    // Lock id does not match startAt (the booking itself is valid).
    const batch = writeBatch(db);
    batch.set(doc(db, 'bookings', 'm1'), data);
    for (const s of blocks(at, 40)) batch.set(doc(locksOf(db), lockId(s)), lockDoc('m1', s));
    batch.set(doc(locksOf(db), lockId(plusMinutes(at, 120))), lockDoc('m1', at));
    await assertFails(batch.commit());
    // Under another barber.
    const batch2 = writeBatch(db);
    batch2.set(doc(db, 'bookings', 'm2'), data);
    for (const s of blocks(at, 40)) batch2.set(doc(locksOf(db), lockId(s)), lockDoc('m2', s));
    batch2.set(doc(locksOf(db, 'shop1', 'b2'), lockId(at)), lockDoc('m2', at));
    await assertFails(batch2.commit());
    // Extra fields.
    const batch3 = writeBatch(db);
    batch3.set(doc(db, 'bookings', 'm3'), data);
    for (const s of blocks(at, 40)) batch3.set(doc(locksOf(db), lockId(s)), { ...lockDoc('m3', s), name: 'x' });
    await assertFails(batch3.commit());
    // The same booking with correct locks is fine.
    await assertSucceeds(bookBatch(db, 'm4', data));
  });

  test('locks can never be overwritten', async () => {
    const ref = (db) => doc(locksOf(db), lockId(START));
    await assertFails(setDoc(ref(cust()), lockDoc('bk1', START)));
    await assertFails(updateDoc(ref(cust()), { bookingId: 'other' }));
    await assertFails(updateDoc(ref(as('admin', PHONES.admin)), { bookingId: 'other' }));
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
      for (const b of blocks(START, 40)) await setDoc(doc(locksOf(ctx.firestore()), lockId(b)), lockDoc('bk1', b));
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
