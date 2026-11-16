// Expression budget of the heaviest client writes (firestore.rules is close
// to Firestore's limit of 1000 evaluated expressions per request).
//
// Needs a running Firestore emulator, e.g. from this folder:
//   npx firebase emulators:exec --only firestore --project demo-crownblade "node budget.mjs"
// or, with an emulator already running:
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node budget.mjs
//
// For each scenario and each kind of document it writes, it reports about
// how many of the 1000 expressions the rules of that document use (see
// "Measuring" below). It exits with 1 if a scenario is denied or a
// document uses more than BUDGET_WARN.
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, runTransaction, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

const PROJECT = 'demo-budget';
const BUDGET_WARN = 700;
const PAD_TERM = process.env.PAD_TERM ?? 'true';
const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const [hostName, port] = host.split(':');

const ADDIS_MS = 3 * 3600 * 1000;
const pad = (n) => String(n).padStart(2, '0');
const NOW = new Date().toISOString();
function addisSlot(days, hour, minute = 0) {
  const a = new Date(Date.now() + ADDIS_MS);
  return new Date(Date.UTC(a.getUTCFullYear(), a.getUTCMonth(), a.getUTCDate() + days, hour, minute) - ADDIS_MS).toISOString();
}
const plusMinutes = (iso, m) => new Date(Date.parse(iso) + m * 60000).toISOString();
function lockId(iso) {
  const a = new Date(Date.parse(iso) + ADDIS_MS);
  return `${a.getUTCFullYear()}${pad(a.getUTCMonth() + 1)}${pad(a.getUTCDate())}-${pad(a.getUTCHours())}${pad(a.getUTCMinutes())}`;
}
function blocks(startAt, minutes) {
  const out = [];
  for (let m = 0; m < minutes; m += 15) out.push(plusMinutes(startAt, m));
  return out;
}
function addisDate(iso) {
  const a = new Date(Date.parse(iso) + ADDIS_MS);
  return `${a.getUTCFullYear()}-${pad(a.getUTCMonth() + 1)}-${pad(a.getUTCDate())}T00:00:00.000`;
}

const env = await initializeTestEnvironment({
  projectId: PROJECT,
  firestore: { host: hostName, port: Number(port), rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
});

const as = (uid) => env.authenticatedContext(uid, { email: `${uid}@example.com`, email_verified: true }).firestore();

const START = addisSlot(3, 10);
const START2 = addisSlot(4, 14);
const LONG = 120;

function shop(ownerId, extra = {}) {
  return {
    ownerId,
    name: 'Shop',
    description: 'A barbershop in Bole',
    address: 'Bole Road',
    city: 'Addis Ababa',
    subCity: 'Bole',
    phone: '+251911000999',
    imageUrl: 'https://example.com/shop.jpg',
    rating: 4.5,
    reviewCount: 3,
    openingHour: 8,
    closingHour: 20,
    workingDays: [1, 2, 3, 4, 5, 6],
    isVerified: true,
    subscriptionPlan: 'basic',
    subscriptionStatus: 'active',
    subscriptionEndsAt: plusMinutes(NOW, 20 * 24 * 60),
    ...extra,
  };
}

function booking(startAt, minutes, extra = {}) {
  return {
    shopId: 'shop1', shopName: 'Shop', barberId: 'b1', barberName: 'Abel',
    customerId: 'customer', customerName: 'customer', customerPhone: '+251911000301',
    serviceId: 'srvLong', serviceName: 'Package', price: 1200,
    date: addisDate(startAt), timeSlot: '10:00 AM', status: 'confirmed', createdAt: NOW,
    startAt, endAt: plusMinutes(startAt, minutes), durationMinutes: minutes,
    paymentStatus: 'unpaid', paymentMethod: 'cash', ...extra,
  };
}

const lockDoc = (bookingId, s, endAt) => ({ bookingId, startAt: s, expiresAt: plusMinutes(endAt, 24 * 60) });
const locks = (db, b = 'b1') => `barbershops/shop1/barbers/${b}/slotLocks`;

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (uid, role, extra = {}) =>
      setDoc(doc(db, 'users', uid), { uid, email: `${uid}@example.com`, name: uid, phone: '+251911000001', role, createdAt: NOW, ...extra });
    await user('admin', 'admin');
    await user('owner1', 'barbershopOwner', { shopId: 'shop1' });
    await user('barber1', 'barber', { shopId: 'shop1', barberId: 'b1' });
    await user('customer', 'customer');
    await setDoc(doc(db, 'barbershops', 'shop1'), shop('owner1'));
    await setDoc(doc(db, 'barbershops/shop1/barbers', 'b1'), {
      shopId: 'shop1', name: 'Abel', title: 'Barber', rating: 5, reviewCount: 2, ratingSum: 9, isAvailable: true, specialties: [],
    });
    await setDoc(doc(db, 'barbershops/shop1/barbers/b1/private', 'contact'), { phone: '+251911000201' });
    await setDoc(doc(db, 'barbershops/shop1/services', 'srvLong'), {
      shopId: 'shop1', name: 'Package', description: 'Everything', price: 1200, durationMinutes: LONG,
    });
    // A 120-minute confirmed, PAID booking with its eight locks.
    const bk = booking(START, LONG, { paymentStatus: 'paid', paymentMethod: 'chapa' });
    await setDoc(doc(db, 'bookings', 'paid'), bk);
    for (const s of blocks(bk.startAt, LONG)) await setDoc(doc(db, locks(db), lockId(s)), lockDoc('paid', s, bk.endAt));
    // A pending receipt of shop1.
    await setDoc(doc(db, 'subscriptionPayments', 'telebirr_ABC12345'), {
      shopId: 'shop1', ownerId: 'owner1', method: 'telebirr', transactionId: 'ABC12345', amount: 500,
      status: 'pending', durationDays: 0, createdAt: NOW,
    });
    // A completed booking with a review (edit / delete).
    await setDoc(doc(db, 'bookings', 'done'), booking(addisSlot(-2, 10), LONG, { status: 'completed' }));
    await setDoc(doc(db, 'barbershops/shop1/reviews', 'done'), {
      bookingId: 'done', shopId: 'shop1', barberId: 'b1', customerId: 'customer', customerName: 'customer', rating: 4, createdAt: NOW,
    });
    await setDoc(doc(db, 'bookings', 'done2'), booking(addisSlot(-1, 10), LONG, { status: 'completed' }));
    // A 120-minute confirmed, UNPAID booking with its eight locks.
    const unpaid = booking(START2, LONG);
    await setDoc(doc(db, 'bookings', 'unpaid'), unpaid);
    for (const s of blocks(START2, LONG)) await setDoc(doc(db, locks(db), lockId(s)), lockDoc('unpaid', s, unpaid.endAt));
    // A pending request (barber acceptance).
    await setDoc(doc(db, 'bookings', 'request'), booking(addisSlot(3, 15), 40, { status: 'pending' }));
    // A cancelled, paid booking whose refund is due.
    await setDoc(doc(db, 'bookings', 'due'), booking(addisSlot(-3, 10), LONG, {
      status: 'cancelled', cancelledBy: 'customer', paymentStatus: 'paid', paymentMethod: 'chapa',
      refundStatus: 'due', refundAmount: 1200, refundReason: 'customer_cancelled', refundFlaggedAt: NOW,
    }));
    // An owner invite for a new account; a shop being deleted.
    await setDoc(doc(db, 'invites', 'new@example.com'), {
      email: 'new@example.com', role: 'barbershopOwner', name: 'New', shopId: 'shop1', createdBy: 'admin', createdAt: NOW,
    });
    await setDoc(doc(db, 'shopDeletions', 'shop1'), {
      shopId: 'shop1', shopName: 'Shop', requestedBy: 'admin', requestedAt: NOW, staffUids: ['owner1', 'barber1'], barberAccountUids: [],
    });
  });
}

// --- Measuring -------------------------------------------------------
// The emulator does not report the engine's own expression counter (the
// coverage report counts AST nodes, about 3x more). So the budget is
// measured by padding: a first `allow <method>: if budgetPad() && false;`
// in the target match evaluates N cheap terms before the real rules; the
// largest N for which the request still succeeds is the headroom. The cost
// of one term is calibrated on an empty match (N0 terms fill the whole
// limit), so used ~= 1000 * (N0 - N) / N0.

// RULES_FILE: measure another copy of the rules (e.g. a variant).
const RULES = readFileSync(process.env.RULES_FILE ?? new URL('../firestore.rules', import.meta.url), 'utf8');

function padFn(n) {
  // A balanced tree of && (a flat chain is "too complex" to compile).
  const tree = (k) => (k === 1 ? PAD_TERM : `(${tree(Math.ceil(k / 2))} && ${tree(Math.floor(k / 2))})`);
  const terms = n > 0 ? tree(n) : 'true';
  return `\n    function budgetPad() {\n      return ${terms};\n    }\n`;
}

// The rules with budgetPad() (N terms) as the first statement of
// `method` in the match block starting with `anchor`.
function paddedRules(anchor, method, n) {
  const top = 'match /databases/{database}/documents {';
  const j = RULES.indexOf(top) + top.length;
  const base = RULES.slice(0, j) + padFn(n) +
    '\n    match /budgetCalibration/{id} {\n      allow write: if true;\n    }\n' + RULES.slice(j);
  const i = base.indexOf(anchor);
  if (i < 0) throw new Error(`anchor not found: ${anchor}`);
  const at = i + anchor.length;
  return base.slice(0, at) + `\n      allow ${method}: if budgetPad() && false;` + base.slice(at);
}

async function loadRules(content) {
  const res = await fetch(`http://${host}/emulator/v1/projects/${PROJECT}:securityRules`, {
    method: 'PUT',
    body: JSON.stringify({ rules: { files: [{ content }] } }),
  });
  if (!res.ok) throw new Error(`rules load failed: ${await res.text()}`);
}

async function succeeds(run) {
  try {
    await run();
    return true;
  } catch (e) {
    return false;
  }
}

// Largest N in [0, hi] for which `run` succeeds with N pad terms (-1: it
// fails even without padding).
async function headroom(anchor, method, run, hi) {
  await loadRules(paddedRules(anchor, method, 0));
  await seed();
  if (!(await succeeds(run))) return -1;
  let lo = 0;
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2);
    await loadRules(paddedRules(anchor, method, mid));
    await seed();
    if (await succeeds(run)) lo = mid;
    else hi = mid - 1;
  }
  return lo;
}

const CALIBRATION_ANCHOR = 'match /budgetCalibration/{id} {';

const B = 'match /bookings/{bookingId} {';
const LOCKS = 'match /slotLocks/{lockId} {';
const SHOP = 'match /barbershops/{shopId} {';
const RECEIPT = 'match /subscriptionPayments/{paymentId} {';
const NOTICE = 'match /notifications/{notificationId} {';
const REVIEW = 'match /reviews/{reviewId} {';
const BARBER = 'match /barbers/{barberId} {';
const TIMEOFF = 'match /timeOff/{timeOffId} {';
const USERS = 'match /users/{userId} {';
const INVITES = 'match /invites/{email} {';

const scenarios = {
  'booking create, 120 min (booking + 8 locks)': async () => {
    const db = as('customer');
    const s = addisSlot(4, 9);
    const bk = booking(s, LONG);
    const batch = writeBatch(db);
    batch.set(doc(db, 'bookings', 'new'), bk);
    for (const b of blocks(s, LONG)) batch.set(doc(db, locks(db), lockId(b)), lockDoc('new', b, bk.endAt));
    await batch.commit();
  },
  'reschedule, 120 min (booking + 8 lock deletes + 8 creates)': async () => {
    const db = as('customer');
    const s = addisSlot(5, 9);
    const end = plusMinutes(s, LONG);
    const batch = writeBatch(db);
    batch.update(doc(db, 'bookings', 'paid'), {
      startAt: s, endAt: end, date: addisDate(s), timeSlot: '09:00 AM', rescheduleCount: 1, rescheduledAt: new Date().toISOString(),
    });
    for (const b of blocks(START, LONG)) batch.delete(doc(db, locks(db), lockId(b)));
    for (const b of blocks(s, LONG)) batch.set(doc(db, locks(db), lockId(b)), lockDoc('paid', b, end));
    await batch.commit();
  },
  'paid cancel by customer, 120 min (booking + refund flag + 8 lock deletes + notice)': async () => {
    const db = as('customer');
    const batch = writeBatch(db);
    batch.update(doc(db, 'bookings', 'paid'), {
      status: 'cancelled', cancelledBy: 'customer',
      refundStatus: 'due', refundAmount: 1200, refundReason: 'customer_cancelled', refundFlaggedAt: new Date().toISOString(),
    });
    for (const b of blocks(START, LONG)) batch.delete(doc(db, locks(db), lockId(b)));
    batch.set(doc(db, 'users/customer/notifications', 'paid_refundDue'), {
      type: 'refundDue', title: 'Refund due', body: 'You are owed a refund.', bookingId: 'paid', read: false, createdAt: new Date().toISOString(),
    });
    await batch.commit();
  },
  'paid staff cancel by barber, 120 min (booking + refund flag + 8 lock deletes + notice)': async () => {
    const db = as('barber1');
    const batch = writeBatch(db);
    batch.update(doc(db, 'bookings', 'paid'), {
      status: 'cancelled', cancelledBy: 'barber1', cancelReasonNote: 'Away',
      refundStatus: 'due', refundAmount: 1200, refundReason: 'barber_cancelled', refundFlaggedAt: new Date().toISOString(),
    });
    for (const b of blocks(START, LONG)) batch.delete(doc(db, locks(db), lockId(b)));
    batch.set(doc(db, 'users/customer/notifications', 'paid_refundDue'), {
      type: 'refundDue', title: 'Refund due', body: 'You are owed a refund.', bookingId: 'paid', read: false, createdAt: new Date().toISOString(),
    });
    await batch.commit();
  },
  'receipt approval (receipt + shop + owner notice)': async () => {
    const db = as('admin');
    const end = new Date(Date.parse(plusMinutes(NOW, 20 * 24 * 60)) + 30 * 86400000).toISOString();
    const batch = writeBatch(db);
    batch.update(doc(db, 'subscriptionPayments', 'telebirr_ABC12345'), {
      status: 'verified', verifiedBy: 'admin', verifiedAmount: 500, durationDays: 30, decidedAt: new Date().toISOString(),
    });
    batch.update(doc(db, 'barbershops', 'shop1'), {
      subscriptionStatus: 'active', subscriptionEndsAt: end, subscriptionReceiptId: 'telebirr_ABC12345', subscriptionPlan: 'basic',
    });
    batch.set(doc(db, 'users/owner1/notifications', 'telebirr_ABC12345_receipt'), {
      title: 'Approved', body: 'Your receipt was approved.', type: 'receiptApproved', read: false, createdAt: new Date().toISOString(),
      shopId: 'shop1', paymentId: 'telebirr_ABC12345',
    });
    await batch.commit();
  },
  'shop admin update (profile fields)': async () => {
    await updateDoc(doc(as('admin'), 'barbershops', 'shop1'), { name: 'Renamed', description: 'New text', isVerified: true });
  },
  'shop suspend (admin)': async () => {
    await updateDoc(doc(as('admin'), 'barbershops', 'shop1'), {
      adminSuspended: true, adminSuspendedReason: 'Complaints', adminSuspendedAt: new Date().toISOString(), adminSuspendedBy: 'admin',
    });
  },
  'shop owner profile update': async () => {
    await updateDoc(doc(as('owner1'), 'barbershops', 'shop1'), { description: 'Owner text', cancellationCutoffHours: 4 });
  },
  'review edit with new stars (review + barber counters)': async () => {
    const db = as('customer');
    await runTransaction(db, async (tx) => {
      tx.update(doc(db, 'barbershops/shop1/reviews', 'done'), { rating: 2, comment: 'Changed', editedAt: new Date().toISOString() });
      tx.update(doc(db, 'barbershops/shop1/barbers', 'b1'), { ratingSum: 7, lastReviewId: 'done' });
    });
  },
  'review create (review + barber counters + owner notice)': async () => {
    const db = as('customer');
    const createdAt = new Date().toISOString();
    const batch = writeBatch(db);
    batch.set(doc(db, 'barbershops/shop1/reviews', 'done2'), {
      bookingId: 'done2', shopId: 'shop1', barberId: 'b1', customerId: 'customer', customerName: 'customer', rating: 5, createdAt,
    });
    batch.update(doc(db, 'barbershops/shop1/barbers', 'b1'), { ratingSum: 14, reviewCount: 3, lastReviewId: 'done2' });
    batch.set(doc(db, 'users/owner1/notifications', `review_done2_${createdAt.replace(/[^0-9]/g, '')}`), {
      type: 'newReview', title: 'New review', body: '5 stars', bookingId: 'done2', shopId: 'shop1', barberId: 'b1', rating: 5,
      read: false, createdAt,
    });
    await batch.commit();
  },
  'unpaid cancel by customer, 120 min (booking + 8 lock deletes)': async () => {
    const db = as('customer');
    const batch = writeBatch(db);
    batch.update(doc(db, 'bookings', 'unpaid'), { status: 'cancelled', cancelledBy: 'customer' });
    for (const b of blocks(START2, LONG)) batch.delete(doc(db, locks(db), lockId(b)));
    await batch.commit();
  },
  'accept request (barber)': async () => {
    await updateDoc(doc(as('barber1'), 'bookings', 'request'), { status: 'confirmed', acceptedAt: new Date().toISOString() });
  },
  'barber phone share (barber)': async () => {
    await updateDoc(doc(as('barber1'), 'bookings', 'paid'), { barberPhone: '+251911000201' });
  },
  'mark refunded (owner, booking + notice)': async () => {
    const db = as('owner1');
    const batch = writeBatch(db);
    const at = new Date().toISOString();
    batch.update(doc(db, 'bookings', 'due'), {
      refundStatus: 'refunded', refundedAt: at, refundedBy: 'owner1', refundMethod: 'telebirr', refundReference: 'TX123', paymentStatus: 'refunded',
    });
    batch.set(doc(db, 'users/customer/notifications', 'due_paymentRefunded'), {
      type: 'paymentRefunded', title: 'Refunded', body: 'Your refund was sent.', bookingId: 'due', read: false, createdAt: at,
    });
    await batch.commit();
  },
  'shop deletion cancel (admin: paid booking + refund flag + 2 notices)': async () => {
    const db = as('admin');
    const at = new Date().toISOString();
    const batch = writeBatch(db);
    batch.update(doc(db, 'bookings', 'paid'), {
      status: 'cancelled', cancelledBy: 'admin', cancelReason: 'shop_deleted',
      refundStatus: 'due', refundAmount: 1200, refundReason: 'shop_deleted', refundFlaggedAt: at,
    });
    batch.set(doc(db, 'users/customer/notifications', 'paid_refundDue'), {
      type: 'refundDue', title: 'Refund due', body: 'You are owed a refund.', bookingId: 'paid', read: false, createdAt: at,
    });
    batch.set(doc(db, 'users/customer/notifications', 'paid_shopDeleted'), {
      type: 'shopDeleted', title: 'Shop closed', body: 'Your booking was cancelled.', shopId: 'shop1', bookingId: 'paid', read: false, createdAt: at,
    });
    await batch.commit();
  },
  'review delete (review + barber counters)': async () => {
    const db = as('customer');
    await runTransaction(db, async (tx) => {
      tx.delete(doc(db, 'barbershops/shop1/reviews', 'done'));
      tx.update(doc(db, 'barbershops/shop1/barbers', 'b1'), { ratingSum: 5, reviewCount: 1, lastReviewId: 'done' });
    });
  },
  'invite profile create (owner invite + invite delete)': async () => {
    const db = env.authenticatedContext('newOwner', { email: 'new@example.com', email_verified: true }).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'users', 'newOwner'), {
      uid: 'newOwner', email: 'new@example.com', name: 'New', phone: '+251911000777', role: 'barbershopOwner', shopId: 'shop1', createdAt: NOW,
    });
    batch.delete(doc(db, 'invites', 'new@example.com'));
    await batch.commit();
  },
  'whole-day time off (doc + 96 locks)': async () => {
    const db = as('barber1');
    const s = addisSlot(6, 0);
    const e = addisSlot(7, 0);
    const batch = writeBatch(db);
    batch.set(doc(db, 'barbershops/shop1/barbers/b1/timeOff', 'day'), { startAt: s, endAt: e, createdBy: 'barber1', createdAt: new Date().toISOString() });
    for (const b of blocks(s, 24 * 60)) batch.set(doc(db, locks(db), lockId(b)), { timeOffId: 'day', startAt: b, expiresAt: plusMinutes(e, 24 * 60) });
    await batch.commit();
  },
};


// Which documents of each request to measure: [anchor, method].
const targets = {
  'booking create': [[B, 'create'], [LOCKS, 'create']],
  'reschedule': [[B, 'update'], [LOCKS, 'create'], [LOCKS, 'delete']],
  'paid cancel by customer': [[B, 'update'], [LOCKS, 'delete'], [NOTICE, 'create']],
  'paid staff cancel': [[B, 'update'], [LOCKS, 'delete'], [NOTICE, 'create']],
  'receipt approval': [[RECEIPT, 'update'], [SHOP, 'update'], [NOTICE, 'create']],
  'shop admin update': [[SHOP, 'update']],
  'shop suspend': [[SHOP, 'update']],
  'shop owner profile': [[SHOP, 'update']],
  'review edit': [[REVIEW, 'update'], [BARBER, 'update']],
  'review create': [[REVIEW, 'create'], [BARBER, 'update'], [NOTICE, 'create']],
  'whole-day time off': [[TIMEOFF, 'create'], [LOCKS, 'create']],
  'unpaid cancel': [[B, 'update'], [LOCKS, 'delete']],
  'accept request': [[B, 'update']],
  'barber phone share': [[B, 'update']],
  'mark refunded': [[B, 'update'], [NOTICE, 'create']],
  'shop deletion cancel': [[B, 'update'], [NOTICE, 'create']],
  'review delete': [[REVIEW, 'delete'], [BARBER, 'update']],
  'invite profile create': [[USERS, 'create'], [INVITES, 'delete']],
};

const only = process.argv.slice(2);
let failed = false;

// Calibration: N0 pad terms fill the whole budget of an (almost) empty match.
const calibrate = () => setDoc(doc(as('admin'), 'budgetCalibration', 'x'), { a: 1 });
const n0 = await headroom(CALIBRATION_ANCHOR, 'write', calibrate, 2000);
console.log(`calibration: ${n0} pad terms fill the 1000-expression limit (~${(1000 / n0).toFixed(2)} expressions each)`);
const used = (n) => Math.round((1000 * (n0 - n)) / n0);

for (const [name, run] of Object.entries(scenarios)) {
  if (only.length && !only.some((o) => name.includes(o))) continue;
  const key = Object.keys(targets).find((k) => name.startsWith(k));
  const parts = [];
  for (const [anchor, method] of targets[key] ?? []) {
    const h = await headroom(anchor, method, run, n0);
    const label = `${anchor.replace(/^match \/|\/?\{.*$/g, '')}.${method}`;
    if (h < 0) {
      failed = true;
      parts.push(`${label}=DENIED`);
      break;
    }
    const u = used(h);
    if (u > BUDGET_WARN) failed = true;
    parts.push(`${label}=${u}${u > BUDGET_WARN ? '(!)' : ''}`);
  }
  console.log(`${name}: ${parts.join(', ')}`);
}
await env.cleanup();
process.exit(failed ? 1 : 0);
