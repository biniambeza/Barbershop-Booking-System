import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  applyToClient,
  applyToStats,
  contributionOf,
  emptyStats,
  readClient,
  readStats,
  sameContribution,
} from '../src/logic/stats';
import { booking } from './fixtures';

const NOW = '2026-11-13T09:00:00.000Z';


test('contribution per status', () => {
  assert.deepEqual(
    (['pending', 'confirmed', 'inProgress', 'completed', 'cancelled', 'noShow'] as const).map((status) => {
      const c = contributionOf(booking({ status }))!;
      return [status, c.bookings, c.completed, c.cancelled, c.noShows, c.revenueEtb];
    }),
    [
      ['pending', 1, 0, 0, 0, 0],
      ['confirmed', 1, 0, 0, 0, 0],
      ['inProgress', 1, 0, 0, 0, 0],
      ['completed', 1, 1, 0, 0, 350],
      ['cancelled', 1, 0, 1, 0, 0],
      ['noShow', 1, 0, 0, 1, 0],
    ],
  );
});

test('contribution: month in Addis time, missing fields, slot conflicts', () => {
  assert.equal(contributionOf(booking({ startAt: '2026-11-30T21:30:00.000Z' }))!.month, '2026-12');
  assert.equal(contributionOf(null), null);
  assert.equal(contributionOf(booking({ shopId: '' })), null);
  assert.equal(contributionOf(booking({ customerId: undefined })), null);
  assert.equal(contributionOf(booking({ startAt: 'garbage' })), null);
  assert.equal(
    contributionOf(booking({ status: 'cancelled', cancelledBy: 'system', cancelReason: 'slot_conflict' })),
    null,
  );
  // A customer cancel still counts.
  assert.equal(contributionOf(booking({ status: 'cancelled', cancelledBy: 'customer' }))!.cancelled, 1);
  // Bad prices never make negative revenue.
  assert.equal(contributionOf(booking({ status: 'completed', price: -5 }))!.revenueEtb, 0);
  assert.equal(contributionOf(booking({ status: 'completed', price: 'x' }))!.revenueEtb, 0);
});

test('sameContribution', () => {
  assert.equal(sameContribution(null, null), true);
  assert.equal(sameContribution(contributionOf(booking()), null), false);
  assert.equal(sameContribution(contributionOf(booking()), contributionOf(booking())), true);
  assert.equal(sameContribution(contributionOf(booking()), contributionOf(booking({ status: 'completed' }))), false);
});

test('applyToStats adds and removes, with per-service and per-barber totals', () => {
  const done = contributionOf(booking({ status: 'completed', price: 350.1 }))!;
  const done2 = contributionOf(booking({ status: 'completed', price: 200.2, serviceId: 'srv2', serviceName: 'Beard', barberId: 'b2', barberName: 'Kaleab' }))!;
  const cancelled = contributionOf(booking({ status: 'cancelled' }))!;
  let s = emptyStats('2026-11', NOW);
  s = applyToStats(s, done, 1, NOW);
  s = applyToStats(s, done2, 1, NOW);
  s = applyToStats(s, cancelled, 1, NOW);
  assert.equal(s.bookings, 3);
  assert.equal(s.completed, 2);
  assert.equal(s.cancelled, 1);
  assert.equal(s.revenueEtb, 550.3);
  assert.deepEqual(s.byService, {
    srv1: { name: 'Fade', count: 1, revenueEtb: 350.1 },
    srv2: { name: 'Beard', count: 1, revenueEtb: 200.2 },
  });
  assert.deepEqual(s.byBarber, {
    b1: { name: 'Yonas', completed: 1, revenueEtb: 350.1 },
    b2: { name: 'Kaleab', completed: 1, revenueEtb: 200.2 },
  });
  // Cancelled bookings never show up in byService/byBarber.
  s = applyToStats(s, done, -1, NOW);
  assert.equal(s.revenueEtb, 200.2);
  assert.equal(s.byService.srv1, undefined);
  assert.equal(s.byBarber.b1, undefined);
  // Never below zero.
  s = applyToStats(emptyStats('2026-11', NOW), done, -1, NOW);
  assert.equal(s.bookings, 0);
  assert.equal(s.revenueEtb, 0);
});

test('readStats normalizes stored docs', () => {
  const s = readStats({ bookings: 2, revenueEtb: 'x', byService: { a: { name: 'A', count: 1 } }, byBarber: null }, '2026-11', NOW);
  assert.equal(s.bookings, 2);
  assert.equal(s.revenueEtb, 0);
  assert.deepEqual(s.byService, { a: { name: 'A', count: 1, revenueEtb: 0 } });
  assert.deepEqual(s.byBarber, {});
});

test('applyToClient tracks counts, name and last visit', () => {
  const older = contributionOf(booking({ status: 'completed', startAt: '2026-10-01T07:00:00.000Z' }))!;
  const newer = contributionOf(booking({ status: 'completed', customerName: 'Liya G.' }))!;
  const noShow = contributionOf(booking({ status: 'noShow' }))!;
  let c = readClient(null, 'c1');
  c = applyToClient(c, newer, 1).doc;
  c = applyToClient(c, older, 1).doc;
  c = applyToClient(c, noShow, 1).doc;
  assert.equal(c.completedCount, 2);
  assert.equal(c.noShowCount, 1);
  assert.equal(c.lastVisitAt, newer.startAt);
  assert.equal(c.phone, '+251911000301');

  // Removing an older visit keeps lastVisitAt; removing the latest marks it stale.
  assert.equal(applyToClient(c, older, -1).lastVisitStale, false);
  const r = applyToClient(c, newer, -1);
  assert.equal(r.lastVisitStale, true);
  assert.equal(r.doc.completedCount, 1);
});
