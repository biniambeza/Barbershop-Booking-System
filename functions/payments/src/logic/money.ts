/** Amount handling. Amounts are always taken from Firestore, never the client. */

export const MAX_AMOUNT_ETB = 1_000_000;

/** Rounds to cents. Returns null for non-numeric, non-positive or absurd amounts. */
export function normalizeAmount(value: unknown): number | null {
  const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
  if (typeof n !== 'number' || !Number.isFinite(n)) return null;
  const rounded = Math.round(n * 100) / 100;
  if (rounded <= 0 || rounded > MAX_AMOUNT_ETB) return null;
  return rounded;
}

/** Chapa accepts the amount as a decimal string. */
export function toChapaAmount(amount: number): string {
  const n = normalizeAmount(amount);
  if (n === null) throw new Error(`Invalid amount: ${amount}`);
  return n.toFixed(2);
}

/** True when Chapa's reported amount equals what we asked for (to the cent). */
export function amountsMatch(expected: number, reported: unknown): boolean {
  const e = normalizeAmount(expected);
  const r = normalizeAmount(reported);
  if (e === null || r === null) return false;
  return Math.round(e * 100) === Math.round(r * 100);
}
