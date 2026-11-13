/** Subscription period math. All instants are ISO-8601 UTC strings in Firestore. */

const DAY_MS = 24 * 60 * 60 * 1000;

export function parseIso(value: unknown): Date | null {
  if (typeof value !== 'string' || value.length === 0) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * DAY_MS);
}

/** Adds calendar months in UTC, clamping the day (Jan 31 + 1 month = Feb 28/29). */
export function addMonthsUtc(date: Date, months: number): Date {
  const m = date.getUTCMonth() + months;
  const targetYear = date.getUTCFullYear() + Math.floor(m / 12);
  const targetMonth = ((m % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
  const day = Math.min(date.getUTCDate(), lastDay);
  return new Date(
    Date.UTC(
      targetYear,
      targetMonth,
      day,
      date.getUTCHours(),
      date.getUTCMinutes(),
      date.getUTCSeconds(),
      date.getUTCMilliseconds(),
    ),
  );
}

/**
 * New end after paying for `months`: extends from the current end when it is
 * still in the future (paying early never loses days), otherwise from now.
 */
export function extendSubscriptionEnd(currentEnd: unknown, now: Date, months = 1): Date {
  const current = parseIso(currentEnd);
  const base = current && current.getTime() > now.getTime() ? current : now;
  return addMonthsUtc(base, months);
}

/**
 * Trial end for a shop with no subscription fields yet: trialDays from its
 * creation, or trialDays from now when that date already passed (shops that
 * existed before subscriptions were introduced are not suspended at once).
 */
export function initialTrialEnd(createdAt: unknown, now: Date, trialDays: number): Date {
  const created = parseIso(createdAt);
  if (created) {
    const end = addDays(created, trialDays);
    if (end.getTime() > now.getTime()) return end;
  }
  return addDays(now, trialDays);
}
