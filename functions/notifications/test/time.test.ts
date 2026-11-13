import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  REMINDER_WINDOWS,
  bookingStart,
  dueReminder,
  isInReminderWindow,
  startFromLegacy,
  toAddisParts,
  windowRange,
} from '../src/time';

const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const now = new Date('2026-11-13T06:00:00.000Z'); // 09:00 Addis
const w24 = REMINDER_WINDOWS.find((w) => w.kind === 'reminder24h')!;
const w2 = REMINDER_WINDOWS.find((w) => w.kind === 'reminder2h')!;
const iso = (offsetMs: number) => new Date(now.getTime() + offsetMs).toISOString();
const longAgo = new Date(now.getTime() - 7 * 24 * HOUR).toISOString();

test('toAddisParts applies +3h and Monday=1 weekday', () => {
  const p = toAddisParts(new Date('2026-11-15T21:30:00Z')); // Sunday 21:30 UTC -> Monday 00:30
  assert.deepEqual(p, { year: 2026, month: 11, day: 16, weekday: 1, hour: 0, minute: 30 });
});

test('legacy date + timeSlot are read as Addis time', () => {
  assert.equal(startFromLegacy('2026-11-13T00:00:00.000', '10:30 AM')?.toISOString(), '2026-11-13T07:30:00.000Z');
  assert.equal(startFromLegacy('2026-11-13', '2:00 PM')?.toISOString(), '2026-11-13T11:00:00.000Z');
  assert.equal(startFromLegacy('2026-11-13', '12:15 AM')?.toISOString(), '2026-11-12T21:15:00.000Z');
  assert.equal(startFromLegacy('2026-11-13', '14:00')?.toISOString(), '2026-11-13T11:00:00.000Z');
  assert.equal(startFromLegacy('2026-11-13', 'soon'), null);
  assert.equal(bookingStart({ startAt: '2026-11-13T08:00:00.000Z', date: 'x', timeSlot: 'y' })?.toISOString(), '2026-11-13T08:00:00.000Z');
});

test('window range is (lead - 45min, lead]', () => {
  const r = windowRange(w2, now);
  assert.equal(r.to.getTime() - now.getTime(), 2 * HOUR);
  assert.equal(r.from.getTime() - now.getTime(), 2 * HOUR - 45 * MIN);
  assert.ok(isInReminderWindow(w2, new Date(now.getTime() + 2 * HOUR), now));
  assert.ok(!isInReminderWindow(w2, new Date(now.getTime() + 2 * HOUR + 1), now));
  assert.ok(!isInReminderWindow(w2, new Date(now.getTime() + 75 * MIN), now));
  assert.ok(isInReminderWindow(w2, new Date(now.getTime() + 76 * MIN), now));
});

test('every booking hits each window in at least one 15-minute run', () => {
  // Simulate runs every 15 minutes; a booking whose lead passes through the
  // window must be due at least once (flags then prevent duplicates).
  for (let offset = 0; offset < 15; offset++) {
    const startAt = new Date(now.getTime() + 30 * HOUR + offset * MIN).toISOString();
    const kinds = new Set<string>();
    for (let t = 0; t <= 30 * HOUR; t += 15 * MIN) {
      const due = dueReminder({ status: 'confirmed', startAt, createdAt: longAgo }, new Date(now.getTime() + t));
      if (due) kinds.add(due.kind);
    }
    assert.deepEqual([...kinds].sort(), ['reminder24h', 'reminder2h'], `offset ${offset}`);
  }
});

test('dueReminder picks the right window', () => {
  const base = { status: 'confirmed', createdAt: longAgo };
  assert.equal(dueReminder({ ...base, startAt: iso(24 * HOUR - 10 * MIN) }, now)?.kind, 'reminder24h');
  assert.equal(dueReminder({ ...base, startAt: iso(2 * HOUR - 10 * MIN) }, now)?.kind, 'reminder2h');
  assert.equal(dueReminder({ ...base, startAt: iso(10 * HOUR) }, now), null);
  assert.equal(dueReminder({ ...base, startAt: iso(-HOUR) }, now), null);
});

test('dueReminder respects flags and status', () => {
  const startAt = iso(2 * HOUR - 10 * MIN);
  assert.equal(dueReminder({ status: 'confirmed', startAt, createdAt: longAgo, reminder2hSentAt: iso(-5 * MIN) }, now), null);
  assert.equal(dueReminder({ status: 'pending', startAt, createdAt: longAgo }, now), null);
  assert.equal(dueReminder({ status: 'cancelled', startAt, createdAt: longAgo }, now), null);
  // The 24h flag does not block the 2h reminder.
  assert.equal(dueReminder({ status: 'confirmed', startAt, createdAt: longAgo, reminder24hSentAt: iso(-22 * HOUR) }, now)?.kind, 'reminder2h');
});

test('no reminder for a window the booking was made inside of', () => {
  // Booked 90 minutes ahead: no 2h reminder.
  assert.equal(dueReminder({ status: 'confirmed', startAt: iso(90 * MIN), createdAt: iso(-1 * MIN) }, now), null);
  // Booked 23.5h ahead: no 24h reminder (the 2h one still comes later).
  assert.equal(dueReminder({ status: 'confirmed', startAt: iso(23 * HOUR + 30 * MIN), createdAt: iso(-1 * MIN) }, now), null);
  // Booked 3 days ahead: gets it.
  assert.equal(dueReminder({ status: 'confirmed', startAt: iso(23 * HOUR + 30 * MIN), createdAt: iso(-2 * 24 * HOUR) }, now)?.kind, 'reminder24h');
});

test('24h window uses its own flag', () => {
  assert.equal(w24.flagField, 'reminder24hSentAt');
});
