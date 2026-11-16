// Storage rules tests (storage.rules: receipt photos, Blaze plan only).
// Needs the Storage AND Firestore emulators (the rules read users/ and
// barbershops/ from Firestore):
//   firebase emulators:exec --only firestore,storage --project demo-crownblade "node --test storage.test.js"
// Skipped when no Storage emulator is running (the Firestore-only `npm test`).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { deleteObject, getBytes, getMetadata, listAll, ref, updateMetadata, uploadBytes } from 'firebase/storage';

const enabled = Boolean(process.env.FIREBASE_STORAGE_EMULATOR_HOST && process.env.FIRESTORE_EMULATOR_HOST);

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0xff, 0xd9]);
const PATH = 'receipts/shop_1/telebirr_CHK1AB2CDE.jpg';
const jpeg = { contentType: 'image/jpeg' };

let env;

describe('storage.rules: receipts/{shopId}/{file}', { skip: !enabled && 'no Storage emulator' }, () => {
  before(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-crownblade',
      firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
      storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
    });
  });

  after(async () => {
    await env?.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.clearStorage();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/admin_1'), { role: 'admin' });
      await setDoc(doc(db, 'users/owner_1'), { role: 'barbershopOwner', shopId: 'shop_1' });
      await setDoc(doc(db, 'users/owner_2'), { role: 'barbershopOwner', shopId: 'shop_2' });
      await setDoc(doc(db, 'users/barber_1'), { role: 'barber', shopId: 'shop_1' });
      await setDoc(doc(db, 'users/customer_1'), { role: 'customer' });
      // Claims shop_1 in their profile but does not own it.
      await setDoc(doc(db, 'users/owner_x'), { role: 'barbershopOwner', shopId: 'shop_1' });
      await setDoc(doc(db, 'barbershops/shop_1'), { ownerId: 'owner_1' });
      await setDoc(doc(db, 'barbershops/shop_2'), { ownerId: 'owner_2' });
    });
  });

  const as = (uid) => env.authenticatedContext(uid).storage();
  const seedObject = (path = PATH) =>
    env.withSecurityRulesDisabled((ctx) => uploadBytes(ref(ctx.storage(), path), JPEG, jpeg));

  test('the shop owner uploads a receipt photo once', async () => {
    await assertSucceeds(uploadBytes(ref(as('owner_1'), PATH), JPEG, jpeg));
    // No overwrite, no metadata change, no delete.
    await assertFails(uploadBytes(ref(as('owner_1'), PATH), JPEG, jpeg));
    await assertFails(updateMetadata(ref(as('owner_1'), PATH), { customMetadata: { a: 'b' } }));
    await assertFails(deleteObject(ref(as('owner_1'), PATH)));
    await assertFails(deleteObject(ref(as('admin_1'), PATH)));
  });

  test('only images under 2 MB named {method}_{tx}.jpg', async () => {
    const owner = as('owner_1');
    await assertFails(uploadBytes(ref(owner, PATH), JPEG, { contentType: 'application/pdf' }));
    await assertFails(uploadBytes(ref(owner, PATH), new Uint8Array(2 * 1024 * 1024), jpeg));
    await assertSucceeds(uploadBytes(ref(owner, 'receipts/shop_1/cbe_FT2412345ABC.jpg'), new Uint8Array(2 * 1024 * 1024 - 1), jpeg));
    await assertFails(uploadBytes(ref(owner, 'receipts/shop_1/evil.html'), JPEG, jpeg));
    await assertFails(uploadBytes(ref(owner, 'receipts/shop_1/telebirr_chk1.jpg'), JPEG, jpeg));
    await assertFails(uploadBytes(ref(owner, 'receipts/shop_1/sub/telebirr_CHK1AB2CDE.jpg'), JPEG, jpeg));
  });

  test('nobody else may upload into a shop folder', async () => {
    await assertFails(uploadBytes(ref(as('owner_2'), PATH), JPEG, jpeg));
    await assertFails(uploadBytes(ref(as('owner_x'), PATH), JPEG, jpeg));
    await assertFails(uploadBytes(ref(as('barber_1'), PATH), JPEG, jpeg));
    await assertFails(uploadBytes(ref(as('customer_1'), PATH), JPEG, jpeg));
    await assertFails(uploadBytes(ref(as('admin_1'), PATH), JPEG, jpeg));
    await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(), PATH), JPEG, jpeg));
    await assertFails(uploadBytes(ref(as('no_profile'), PATH), JPEG, jpeg));
  });

  test('the owner reads their shop receipts; admins read all; others nothing', async () => {
    await seedObject();
    await assertSucceeds(getBytes(ref(as('owner_1'), PATH)));
    await assertSucceeds(getMetadata(ref(as('owner_1'), PATH)));
    await assertSucceeds(getBytes(ref(as('admin_1'), PATH)));
    await assertSucceeds(listAll(ref(as('admin_1'), 'receipts/shop_1')));
    await assertFails(getBytes(ref(as('owner_2'), PATH)));
    await assertFails(getBytes(ref(as('owner_x'), PATH)));
    await assertFails(getBytes(ref(as('barber_1'), PATH)));
    await assertFails(getBytes(ref(as('customer_1'), PATH)));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), PATH)));
  });

  test('everything outside receipts/ is closed', async () => {
    await seedObject('other/file.jpg');
    await assertFails(getBytes(ref(as('admin_1'), 'other/file.jpg')));
    await assertFails(uploadBytes(ref(as('admin_1'), 'other/new.jpg'), JPEG, jpeg));
    await assertFails(uploadBytes(ref(as('owner_1'), 'receipts/telebirr_CHK1AB2CDE.jpg'), JPEG, jpeg));
  });
});

describe('storage.rules: portfolio/{shopId}/{barberId}/{pNN}.jpg', { skip: !enabled && 'no Storage emulator' }, () => {
  const P = 'portfolio/shop_1/b_1/p01.jpg';

  before(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-crownblade',
      firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
      storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
    });
  });

  after(async () => {
    await env?.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.clearStorage();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/admin_1'), { role: 'admin' });
      await setDoc(doc(db, 'users/owner_1'), { role: 'barbershopOwner', shopId: 'shop_1' });
      await setDoc(doc(db, 'users/owner_2'), { role: 'barbershopOwner', shopId: 'shop_2' });
      await setDoc(doc(db, 'users/barber_1'), { role: 'barber', shopId: 'shop_1', barberId: 'b_1' });
      await setDoc(doc(db, 'users/barber_2'), { role: 'barber', shopId: 'shop_1', barberId: 'b_2' });
      await setDoc(doc(db, 'users/customer_1'), { role: 'customer' });
      await setDoc(doc(db, 'barbershops/shop_1'), { ownerId: 'owner_1' });
      await setDoc(doc(db, 'barbershops/shop_2'), { ownerId: 'owner_2' });
    });
  });

  const as = (uid) => env.authenticatedContext(uid).storage();
  const seedObject = (path = P) =>
    env.withSecurityRulesDisabled((ctx) => uploadBytes(ref(ctx.storage(), path), JPEG, jpeg));

  test('anyone reads a portfolio photo, signed out too', async () => {
    await seedObject();
    await assertSucceeds(getBytes(ref(env.unauthenticatedContext().storage(), P)));
    await assertSucceeds(getBytes(ref(as('customer_1'), P)));
  });

  test('the owner and that barber upload and overwrite (slot reuse); nobody else', async () => {
    await assertSucceeds(uploadBytes(ref(as('barber_1'), P), JPEG, jpeg));
    await assertSucceeds(uploadBytes(ref(as('owner_1'), P), JPEG, jpeg));
    await assertSucceeds(uploadBytes(ref(as('owner_1'), 'portfolio/shop_1/b_1/p12.jpg'), JPEG, jpeg));
    for (const uid of ['barber_2', 'owner_2', 'customer_1', 'admin_1', 'no_profile']) {
      await assertFails(uploadBytes(ref(as(uid), P), JPEG, jpeg), uid);
    }
    await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(), P), JPEG, jpeg));
  });

  test('only p01..p12 .jpg images under 1 MB', async () => {
    const owner = as('owner_1');
    for (const name of ['p00.jpg', 'p13.jpg', 'p1.jpg', 'p01.png', 'evil.html']) {
      await assertFails(uploadBytes(ref(owner, `portfolio/shop_1/b_1/${name}`), JPEG, jpeg), name);
    }
    await assertFails(uploadBytes(ref(owner, P), JPEG, { contentType: 'text/html' }));
    await assertFails(uploadBytes(ref(owner, P), new Uint8Array(1024 * 1024), jpeg));
    await assertFails(uploadBytes(ref(owner, P), new Uint8Array(0), jpeg));
    await assertSucceeds(uploadBytes(ref(owner, P), new Uint8Array(1024 * 1024 - 1), jpeg));
  });

  test('the owner, that barber or an admin deletes', async () => {
    for (const n of ['p01', 'p02', 'p03']) await seedObject(`portfolio/shop_1/b_1/${n}.jpg`);
    await assertFails(deleteObject(ref(as('barber_2'), P)));
    await assertFails(deleteObject(ref(as('owner_2'), P)));
    await assertFails(deleteObject(ref(as('customer_1'), P)));
    await assertSucceeds(deleteObject(ref(as('barber_1'), P)));
    await assertSucceeds(deleteObject(ref(as('owner_1'), 'portfolio/shop_1/b_1/p02.jpg')));
    await assertSucceeds(deleteObject(ref(as('admin_1'), 'portfolio/shop_1/b_1/p03.jpg')));
  });
});
