/**
 * Time helpers. Addis Ababa is UTC+3 all year (no DST), so we do the offset
 * arithmetic ourselves instead of relying on the ICU data in the runtime.
 */

export const ADDIS_OFFSET_MS = 3 * 60 * 60 * 1000;
const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

/** Parts of an instant as seen on a wall clock in Addis Ababa. */
export interface AddisParts {
  year: number;
  month: number; // 1..12
  day: number; // 1..31
  weekday: number; // 1 = Monday .. 7 = Sunday (same as Dart DateTime.weekday)
  hour: number; // 0..23
  minute: number; // 0..59
}

export function toAddisParts(instant: Date): AddisParts {
  const local = new Date(instant.getTime() + ADDIS_OFFSET_MS);
  const jsDay = local.getUTCDay(); // 0 = Sunday
  return {
    year: local.getUTCFullYear(),
    month: local.getUTCMonth() + 1,
    day: local.getUTCDate(),
    weekday: jsDay === 0 ? 7 : jsDay,
    hour: local.getUTCHours(),
    minute: local.getUTCMinutes(),
  };
}

/**
 * Parses an ISO-8601 string (the contract stores startAt/endAt as UTC
 * strings). Returns null when missing or unparseable.
 */
export function parseIso(value: unknown): Date | null {
  if (typeof value !== 'string' || value.length === 0) return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : new Date(ms);
}

/**
 * Fallback for legacy bookings without startAt: `date` (ISO string, the day)
 * plus `timeSlot` such as "10:30 AM" or "14:00", interpreted in Addis time.
 */
export function startFromLegacy(date: unknown, timeSlot: unknown): Date | null {
  if (typeof date !== 'string' || typeof timeSlot !== 'string') return null;
  const dayMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(date);
  const slotMatch = /^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$/.exec(timeSlot);
  if (!dayMatch || !slotMatch) return null;
  let hour = Number(slotMatch[1]);
  const minute = Number(slotMatch[2]);
  const ampm = slotMatch[3]?.toUpperCase();
  if (ampm === 'PM' && hour < 12) hour += 12;
  if (ampm === 'AM' && hour === 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  const utcMs =
    Date.UTC(Number(dayMatch[1]), Number(dayMatch[2]) - 1, Number(dayMatch[3]), hour, minute) -
    ADDIS_OFFSET_MS;
  return new Date(utcMs);
}

/** Best-effort start instant of a booking document. */
export function bookingStart(data: { startAt?: unknown; date?: unknown; timeSlot?: unknown }): Date | null {
  return parseIso(data.startAt) ?? startFromLegacy(data.date, data.timeSlot);
}

// ---------------------------------------------------------------------------
// Reminder windows
// ---------------------------------------------------------------------------

export type ReminderKind = 'reminder24h' | 'reminder2h';

export interface ReminderWindow {
  kind: ReminderKind;
  /** Booking field (ISO string) that marks the reminder as sent. */
  flagField: 'reminder24hSentAt' | 'reminder2hSentAt';
  /** Nominal lead time before the appointment. */
  leadMs: number;
  /**
   * How far below the nominal lead we still send. The scheduler runs every
   * 15 minutes; a 45-minute window survives two missed runs, and the flag
   * field stops duplicates.
   */
  graceMs: number;
}

export const REMINDER_WINDOWS: readonly ReminderWindow[] = [
  { kind: 'reminder24h', flagField: 'reminder24hSentAt', leadMs: 24 * HOUR, graceMs: 45 * MINUTE },
  { kind: 'reminder2h', flagField: 'reminder2hSentAt', leadMs: 2 * HOUR, graceMs: 45 * MINUTE },
];

/** Range of start instants a window covers at `now`: (from, to]. */
export function windowRange(window: ReminderWindow, now: Date): { from: Date; to: Date } {
  return {
    from: new Date(now.getTime() + window.leadMs - window.graceMs),
    to: new Date(now.getTime() + window.leadMs),
  };
}

/** True when an appointment starting at `start` is due for `window` at `now`. */
export function isInReminderWindow(window: ReminderWindow, start: Date, now: Date): boolean {
  const { from, to } = windowRange(window, now);
  return start.getTime() > from.getTime() && start.getTime() <= to.getTime();
}

/**
 * Decides which reminder (if any) a confirmed booking should get now.
 * - Already-sent flags are respected.
 * - A 24h reminder is skipped if the 2h one is also due (late bookings).
 * - A booking made less than 15 minutes before a window's nominal lead
 *   (e.g. booked 1.5h ahead) does not get that reminder: the booking and
 *   confirmation messages have just told the customer.
 */
export function dueReminder(
  booking: {
    status?: unknown;
    startAt?: unknown;
    date?: unknown;
    timeSlot?: unknown;
    createdAt?: unknown;
    reminder24hSentAt?: unknown;
    reminder2hSentAt?: unknown;
  },
  now: Date,
): ReminderWindow | null {
  if (booking.status !== 'confirmed') return null;
  const start = bookingStart(booking);
  if (!start || start.getTime() <= now.getTime()) return null;
  const created = parseIso(booking.createdAt);

  // Check the nearest window first so a late booking gets the 2h one only.
  const ordered = [...REMINDER_WINDOWS].sort((a, b) => a.leadMs - b.leadMs);
  for (const window of ordered) {
    if (!isInReminderWindow(window, start, now)) continue;
    if (booking[window.flagField]) return null;
    if (created && start.getTime() - created.getTime() < window.leadMs + 15 * MINUTE) {
      return null;
    }
    return window;
  }
  return null;
}

/** Same ISO format Dart's DateTime.toUtc().toIso8601String() produces for ms precision. */
export function toIsoUtc(d: Date): string {
  return d.toISOString();
}
