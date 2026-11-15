import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildInviteEmail, inviteEmailDocId, inviteLanguageOrder, isInviteRole } from '../src/logic/inviteEmail';

const EMAIL = 'abel@example.com';

test('barber invite: Amharic first by default, both languages, shop and inviter named', () => {
  const m = buildInviteEmail({ role: 'barber', email: EMAIL, shopName: 'Bole Cuts', inviterName: 'Sara' });
  const en = 'Sara added you as a barber at Bole Cuts on Crown & Blade.';
  const am = 'Sara በCrown & Blade ላይ በBole Cuts ፀጉር አስተካካይ አድርጎ አክሎዎታል።';
  assert.ok(m.text.includes(en));
  assert.ok(m.text.includes(am));
  assert.ok(m.text.indexOf(am) < m.text.indexOf(en));
  assert.ok(m.subject.startsWith('ወደ Bole Cuts'));
  assert.ok(m.subject.includes('You are invited to Bole Cuts on Crown & Blade'));
  assert.ok(m.text.includes(`enter this email (${EMAIL})`));
  assert.ok(m.text.includes(`ይህን ኢሜይል (${EMAIL})`));
  assert.ok(m.text.includes('6-digit code'));
  assert.ok(m.text.includes("Then you'll see your bookings."));
  assert.ok(m.html.indexOf('lang="am"') < m.html.indexOf('lang="en"'));
});

test('English first when the inviter uses English', () => {
  const m = buildInviteEmail({ role: 'barber', email: EMAIL, shopName: 'Bole Cuts', inviterName: 'Sara', inviterLanguage: 'en' });
  assert.ok(m.text.indexOf('Sara added you') < m.text.indexOf('Sara በCrown'));
  assert.ok(m.subject.startsWith('You are invited to Bole Cuts'));
  assert.deepEqual(inviteLanguageOrder('am'), ['am', 'en']);
  assert.deepEqual(inviteLanguageOrder(undefined), ['am', 'en']);
  assert.deepEqual(inviteLanguageOrder('fr'), ['am', 'en']);
});

test('barber invite without inviter name uses the shop name', () => {
  const m = buildInviteEmail({ role: 'barber', email: EMAIL, shopName: 'Bole Cuts' });
  assert.ok(m.text.includes('Bole Cuts added you as a barber at Bole Cuts'));
});

test('missing shop name falls back to a generic phrase', () => {
  const m = buildInviteEmail({ role: 'barber', email: EMAIL, shopName: '  ', inviterName: null });
  assert.ok(m.text.includes('Crown & Blade added you as a barber at a barbershop on Crown & Blade.'));
  assert.ok(m.text.includes('አንድ ፀጉር ቤት'));
  assert.ok(m.subject.includes('You are invited to Crown & Blade as a barber'));
  assert.ok(!m.text.includes('undefined') && !m.text.includes('null'));
  const o = buildInviteEmail({ role: 'barbershopOwner', email: EMAIL });
  assert.ok(o.text.includes('as the owner of a barbershop'));
  assert.ok(!o.text.includes('undefined'));
});

test('owner invite', () => {
  const m = buildInviteEmail({ role: 'barbershopOwner', email: EMAIL, shopName: 'Piassa Kings', inviterName: 'Admin Team', inviterLanguage: 'en' });
  assert.ok(m.text.includes('Admin Team added you as the owner of Piassa Kings on Crown & Blade.'));
  assert.ok(m.text.includes('የPiassa Kings ባለቤት'));
  assert.ok(m.subject.startsWith('You are invited to manage Piassa Kings'));
  assert.ok(m.text.includes(`(${EMAIL})`));
});

test('admin invite is short and ignores the shop', () => {
  const m = buildInviteEmail({ role: 'admin', email: EMAIL, shopName: 'Ignored', inviterName: 'Hana' });
  assert.ok(m.text.includes('Hana added you as an admin on Crown & Blade.'));
  assert.ok(m.text.includes('አስተዳዳሪ'));
  assert.ok(!m.text.includes('Ignored'));
  assert.ok(m.subject.startsWith('ወደ Crown & Blade በአስተዳዳሪነት'));
});

test('HTML escapes names', () => {
  const m = buildInviteEmail({ role: 'barber', email: EMAIL, shopName: '<b>Shop</b>', inviterName: 'A & B' });
  assert.ok(m.html.startsWith('<!doctype html>'));
  assert.ok(m.html.includes('&lt;b&gt;Shop&lt;/b&gt;'));
  assert.ok(m.html.includes('A &amp; B'));
  assert.ok(!m.html.includes('<b>Shop'));
});

test('idempotency id and role guard', () => {
  assert.equal(inviteEmailDocId(EMAIL, '2026-11-15T10:00:00.000Z'), `${EMAIL}_2026-11-15T10:00:00.000Z`);
  assert.equal(inviteEmailDocId(EMAIL, { toDate: () => new Date('2026-11-15T10:00:00.000Z') }), `${EMAIL}_2026-11-15T10:00:00.000Z`);
  assert.equal(inviteEmailDocId(EMAIL, 'a/b'), `${EMAIL}_a_b`);
  assert.equal(inviteEmailDocId(EMAIL, undefined), `${EMAIL}_unknown`);
  assert.ok(isInviteRole('barber') && isInviteRole('admin') && isInviteRole('barbershopOwner'));
  assert.ok(!isInviteRole('customer'));
});
