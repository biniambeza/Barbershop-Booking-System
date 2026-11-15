'use strict';
// node --test: seeded shop applications resolve like
// lib/features/applications/shop_applications_service.dart
// (shopApplicationsFromSeedJson) and follow the shopApplications contract.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0));
const SUB_CITIES = [
  'Addis Ketema', 'Akaky Kaliti', 'Arada', 'Bole', 'Gullele', 'Kirkos',
  'Kolfe Keranio', 'Lemi Kura', 'Lideta', 'Nifas Silk-Lafto', 'Yeka',
];
const appDocs = (docs) => docs.filter((d) => /^shopApplications\/[^/]+$/.test(d.path));

test('one pending application per seeded entry, with the contract fields', () => {
  const docs = buildDocuments(seed, { now });
  const apps = appDocs(docs);
  const entries = (seed.shopApplications || []).filter((a) => a.uid);
  assert.strictEqual(apps.length, entries.length);
  assert.ok(apps.some((a) => a.data.status === 'pending'));
  const allowed = [
    'uid', 'email', 'ownerName', 'shopName', 'address', 'subCity', 'phone', 'description', 'status', 'createdAt',
    'reviewedBy', 'reviewedAt', 'shopId', 'rejectReason',
  ];
  for (const a of apps) {
    const uid = a.path.split('/')[1];
    const user = seed.users.find((u) => u.uid === uid);
    assert.ok(user, a.path);
    assert.strictEqual(user.role, 'customer', a.path);
    assert.strictEqual(a.data.uid, uid);
    assert.strictEqual(a.data.email, user.email.trim().toLowerCase());
    assert.ok(a.data.shopName.length >= 2 && a.data.shopName.length <= 80);
    assert.ok(a.data.address.length >= 2 && a.data.address.length <= 160);
    assert.ok(a.data.ownerName.length >= 1 && a.data.ownerName.length <= 100);
    assert.ok(SUB_CITIES.includes(a.data.subCity), a.data.subCity);
    assert.match(a.data.phone, /^\+251\d{9}$/);
    if ('description' in a.data) assert.ok(a.data.description.length <= 500);
    assert.ok(['pending', 'approved', 'rejected'].includes(a.data.status));
    assert.ok(Object.keys(a.data).every((k) => allowed.includes(k)), a.path);
  }
  const first = docs.find((d) => d.path === 'shopApplications/user_cust_2').data;
  assert.strictEqual(first.createdAt, '2026-11-19T11:00:00.000Z'); // 20 hours earlier
});

test('invites mode writes no applications', () => {
  const docs = buildDocuments(seed, { now, mode: 'invites' });
  assert.strictEqual(appDocs(docs).length, 0);
});

test('an application for an unknown user is rejected', () => {
  const bad = { ...seed, shopApplications: [{ uid: 'nobody', shopName: 'X shop', address: 'Here', subCity: 'Bole', phone: '+251911000000' }] };
  assert.throws(() => buildDocuments(bad, { now }), /missing user/);
});
