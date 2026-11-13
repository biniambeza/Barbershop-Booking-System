/** Addis Ababa is UTC+3 all year (no daylight saving). */
export const ADDIS_OFFSET_MS = 3 * 60 * 60 * 1000;

const pad = (n: number): string => String(n).padStart(2, '0');

/**
 * The Addis calendar month ('yyyy-MM') of a UTC ISO instant, or null when
 * the value is not a parseable date.
 */
export function addisMonthKey(iso: unknown): string | null {
  if (typeof iso !== 'string' || iso.length === 0) return null;
  const ms = Date.parse(iso);
  if (Number.isNaN(ms)) return null;
  const a = new Date(ms + ADDIS_OFFSET_MS);
  return `${a.getUTCFullYear()}-${pad(a.getUTCMonth() + 1)}`;
}

/** True for a 'yyyy-MM' month key. */
export function isMonthKey(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(value);
}
