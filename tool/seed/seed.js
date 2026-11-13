#!/usr/bin/env node
/*
 * Crown & Blade - Firestore seed script.
 *
 * Loads the same dataset the app uses in DEMO_MODE (assets/seed/addis_seed.json)
 * into Firestore, resolving the relative times exactly like
 * lib/data/seed_dataset.dart does (Addis Ababa = UTC+3, no DST).
 *
 * Usage (from tool/seed, after `npm install`):
 *   node seed.js --dry-run                 # print what would be written
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node seed.js
 *   GOOGLE_APPLICATION_CREDENTIALS=key.json node seed.js --invites --project <id> --yes
 *
 * Modes:
 *   (default) "users" mode: writes users/{uid} with the fixed demo uids
 *             (user_admin_1, owner_1, barber_user_1, user_cust_1, ...), the
 *             demo bookings, shops, services, barbers and plans. If the Auth
 *             emulator is running (FIREBASE_AUTH_EMULATOR_HOST) or --with-auth
 *             is passed, it also creates Firebase Auth users with the same uid
 *             and phone number, so signing in with a demo number lands on the
 *             seeded profile.
 *   --invites "invites" mode, for a real project: no fake accounts or
 *             bookings. Writes plans, shops (ownerId ''), services, barbers and
 *             invites/{phone} for the admin, owners and barbers. Each person
 *             gets their role when they first sign in with that number.
 *
 * Other flags:
 *   --project <id>  project id (default: GCLOUD_PROJECT, or demo-crownblade on
 *                   the emulator)
 *   --yes           required when not using the emulator
 *   --dry-run       no connection, just a summary
 */
'use strict';

const fs = require('fs');
const path = require('path');

const SEED_PATH = path.resolve(__dirname, '..', '..', 'assets', 'seed', 'addis_seed.json');
const ADDIS_OFFSET_MS = 3 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

function parseArgs(argv) {
  const args = { dryRun: false, invites: false, withAuth: false, yes: false, project: undefined, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') args.dryRun = true;
    else if (a === '--invites') args.invites = true;
    else if (a === '--with-auth') args.withAuth = true;
    else if (a === '--yes') args.yes = true;
    else if (a === '--project') args.project = argv[++i];
    else if (a === '--help' || a === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

const pad = (n) => String(n).padStart(2, '0');

/** '14:15' -> [14, 15] */
function parseTime(hhmm) {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm);
  if (!m) throw new Error(`Bad startTime ${hhmm}`);
  return [Number(m[1]), Number(m[2])];
}

/** 24h -> '02:15 PM' (same as formatTimeSlot in lib/data/addis_time.dart). */
function formatTimeSlot(h, m) {
  const period = h < 12 ? 'AM' : 'PM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${pad(h12)}:${pad(m)} ${period}`;
}

/**
 * Resolves the JSON into Firestore documents: [{ path, data }].
 * Pure (no I/O); `mode` is 'users' or 'invites'.
 */
function buildDocuments(seed, { now = new Date(), mode = 'users' } = {}) {
  const nowMs = now.getTime();
  const iso = (ms) => new Date(ms).toISOString();
  const docs = [];

  for (const p of seed.plans || []) {
    const { id, ...data } = p;
    docs.push({ path: `plans/${id}`, data });
  }

  const usersById = new Map(seed.users.map((u) => [u.uid, u]));
  for (const u of seed.users) {
    const createdAt = iso(nowMs - (u.createdDaysAgo || 0) * DAY_MS);
    if (mode === 'users') {
      const data = { uid: u.uid, name: u.name, phone: u.phone, role: u.role, createdAt };
      if (u.email) data.email = u.email;
      if (u.shopId) data.shopId = u.shopId;
      if (u.barberId) data.barberId = u.barberId;
      if (u.language) data.language = u.language;
      docs.push({ path: `users/${u.uid}`, data });
    } else if (u.role !== 'customer') {
      const data = { phone: u.phone, role: u.role, name: u.name, createdBy: 'seed', createdAt };
      if (u.shopId) data.shopId = u.shopId;
      if (u.barberId) data.barberId = u.barberId;
      docs.push({ path: `invites/${u.phone}`, data });
    }
  }

  const shops = new Map();
  const services = new Map();
  const barbers = new Map();
  for (const s of seed.shops) {
    const { id, services: svcs = [], barbers: brbs = [], subscriptionEndsInDays, ...shop } = s;
    if (mode === 'invites') shop.ownerId = '';
    if (subscriptionEndsInDays !== undefined && subscriptionEndsInDays !== null) {
      shop.subscriptionEndsAt = iso(nowMs + subscriptionEndsInDays * DAY_MS);
    }
    if (shop.landmark === undefined || shop.landmark === null) delete shop.landmark;
    shops.set(id, { id, ...shop });
    docs.push({ path: `barbershops/${id}`, data: shop });
    for (const sv of svcs) {
      const { id: svId, ...data } = sv;
      const doc = { shopId: id, ...data };
      services.set(svId, { id: svId, ...doc });
      docs.push({ path: `barbershops/${id}/services/${svId}`, data: doc });
    }
    for (const b of brbs) {
      const { id: bId, ...data } = b;
      const doc = { shopId: id, isAvailable: true, ...data };
      barbers.set(bId, { id: bId, ...doc });
      docs.push({ path: `barbershops/${id}/barbers/${bId}`, data: doc });
    }
  }

  if (mode === 'users') {
    // "Today" is the Addis calendar day.
    const addisNow = new Date(nowMs + ADDIS_OFFSET_MS);
    const todayUtcMidnight = Date.UTC(addisNow.getUTCFullYear(), addisNow.getUTCMonth(), addisNow.getUTCDate());
    for (const b of seed.bookings || []) {
      const shop = shops.get(b.shopId);
      const barber = barbers.get(b.barberId);
      const service = services.get(b.serviceId);
      const customer = usersById.get(b.customerId);
      if (!shop || !barber || !service || !customer) throw new Error(`Booking ${b.id} references missing data`);
      const day = new Date(todayUtcMidnight + b.dayOffset * DAY_MS);
      const [h, m] = parseTime(b.startTime);
      const startMs = Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), h, m) - ADDIS_OFFSET_MS;
      const duration = service.durationMinutes;
      docs.push({
        path: `bookings/${b.id}`,
        data: {
          shopId: shop.id,
          shopName: shop.name,
          barberId: barber.id,
          barberName: barber.name,
          customerId: customer.uid,
          customerName: customer.name,
          customerPhone: customer.phone,
          serviceId: service.id,
          serviceName: service.name,
          price: service.price,
          // Calendar day, written like Dart's DateTime(y, m, d).toIso8601String().
          date: `${day.getUTCFullYear()}-${pad(day.getUTCMonth() + 1)}-${pad(day.getUTCDate())}T00:00:00.000`,
          timeSlot: formatTimeSlot(h, m),
          status: b.status,
          createdAt: iso(nowMs - (b.createdHoursAgo || 0) * HOUR_MS),
          startAt: iso(startMs),
          endAt: iso(startMs + duration * 60 * 1000),
          durationMinutes: duration,
          paymentStatus: b.paymentStatus || 'unpaid',
          paymentMethod: b.paymentMethod || 'cash',
        },
      });
      // Slot locks (double-booking prevention, see lib/services/availability_service.dart):
      // one per 15-minute block, id yyyyMMdd-HHmm in Addis time, for bookings
      // that still hold the barber's time.
      if (b.status !== 'cancelled') {
        const step = 15 * 60 * 1000;
        const endMs = startMs + duration * 60 * 1000;
        for (let t = startMs - (startMs % step); t < endMs || t === startMs - (startMs % step); t += step) {
          const a = new Date(t + ADDIS_OFFSET_MS);
          const lockId = `${a.getUTCFullYear()}${pad(a.getUTCMonth() + 1)}${pad(a.getUTCDate())}-${pad(a.getUTCHours())}${pad(a.getUTCMinutes())}`;
          docs.push({
            path: `barbershops/${shop.id}/barbers/${barber.id}/slotLocks/${lockId}`,
            data: { bookingId: b.id, customerId: customer.uid, startAt: iso(t) },
          });
        }
      }
    }
  }
  return docs;
}

function summarize(docs) {
  const summary = {};
  for (const d of docs) {
    const collection = d.path.split('/').filter((_, i) => i % 2 === 0).join('/*/');
    summary[collection] = (summary[collection] || 0) + 1;
  }
  return summary;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]);
    return;
  }
  const seed = JSON.parse(fs.readFileSync(SEED_PATH, 'utf8'));
  const mode = args.invites ? 'invites' : 'users';
  const docs = buildDocuments(seed, { mode });
  const summary = summarize(docs);

  if (args.dryRun) {
    console.log(`Dry run (${mode} mode): ${docs.length} documents`);
    console.table(summary);
    return;
  }

  const onEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!onEmulator && !args.yes) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set, so this would write to a real project. Re-run with --yes to confirm.',
    );
  }
  const projectId =
    args.project ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    (onEmulator ? 'demo-crownblade' : undefined);

  const { initializeApp, applicationDefault } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const app = initializeApp(onEmulator ? { projectId } : { credential: applicationDefault(), projectId });
  const db = getFirestore(app);

  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    for (const d of docs.slice(i, i + 400)) batch.set(db.doc(d.path), d.data);
    await batch.commit();
  }
  const target = onEmulator ? `the emulator at ${process.env.FIRESTORE_EMULATOR_HOST}` : `project ${projectId}`;
  console.log(`Seeded ${docs.length} documents (${mode} mode) into ${target}.`);
  console.table(summary);

  const createAuth = mode === 'users' && (args.withAuth || Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST));
  if (createAuth) {
    const { getAuth } = require('firebase-admin/auth');
    const auth = getAuth(app);
    let created = 0;
    for (const u of seed.users) {
      try {
        await auth.createUser({ uid: u.uid, phoneNumber: u.phone, displayName: u.name });
        created++;
      } catch (e) {
        if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/phone-number-already-exists') throw e;
      }
    }
    console.log(`Auth: created ${created} phone users (existing ones were kept).`);
  } else if (mode === 'users') {
    console.log(
      'Auth users were not created (no Auth emulator and no --with-auth). Signing in with a demo number ' +
        'would create a new uid and ask for a profile.',
    );
  }
}

module.exports = { buildDocuments, formatTimeSlot };

if (require.main === module) {
  main().catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  });
}
