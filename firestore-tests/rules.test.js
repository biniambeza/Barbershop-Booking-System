// Security rules tests. Run from this folder with `npm test`
// (starts the Firestore emulator; needs Java).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const NOW = '2026-11-13T10:00:00.000Z';

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

    await setDoc(doc(db, 'barbershops', 'shop1'), shop('owner1'));
    await setDoc(doc(db, 'barbershops', 'shop2'), shop('owner2'));
    await setDoc(doc(db, 'barbershops', 'shop3'), shop('')); // registered, owner not signed in yet

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

    await setDoc(doc(db, 'bookings', 'bk1'), booking({ status: 'confirmed' }));
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
    timeSlot: '10:30 AM',
    status: 'confirmed',
    createdAt: NOW,
    ...overrides,
  };
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
    await assertSucceeds(setDoc(doc(db, 'bookings', 'bk2'), booking()));
    await assertFails(setDoc(doc(db, 'bookings', 'bk3'), booking({ price: 1 })));
  });

  test('cannot book for someone else, as completed, or with a fake barber/service', async () => {
    const db = as('customer', PHONES.customer);
    await assertFails(setDoc(doc(db, 'bookings', 'bk4'), booking({ customerId: 'customer2' })));
    await assertFails(setDoc(doc(db, 'bookings', 'bk5'), booking({ status: 'completed' })));
    await assertFails(setDoc(doc(db, 'bookings', 'bk6'), booking({ barberId: 'b3' })));
    await assertFails(setDoc(doc(db, 'bookings', 'bk7'), booking({ serviceId: 'nope' })));
  });

  test('a signed-in phone without a profile cannot book', async () => {
    await assertFails(setDoc(doc(as('new', PHONES.newPerson), 'bookings', 'bk8'), booking({ customerId: 'new' })));
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

  test('removing a barber profile revokes that barber\'s access', async () => {
    await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'barbershops/shop1/barbers', 'b1')));
    await assertFails(getDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1')));
    await assertFails(updateDoc(doc(as('barber1', PHONES.barber1), 'bookings', 'bk1'), { status: 'completed' }));
  });

  test('only admins delete bookings', async () => {
    await assertFails(deleteDoc(doc(as('owner1', PHONES.owner1), 'bookings', 'bk1')));
    await assertSucceeds(deleteDoc(doc(as('admin', PHONES.admin), 'bookings', 'bk1')));
  });
});

test('unknown collections are closed', async () => {
  await assertFails(setDoc(doc(as('admin', PHONES.admin), 'anything', 'x'), { a: 1 }));
});
