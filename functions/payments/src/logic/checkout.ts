/** Helpers for building Chapa checkout requests. */
import { TX_REF_PREFIX } from '../config';

export function buildTxRef(paymentId: string): string {
  return `${TX_REF_PREFIX}${paymentId}`;
}

/** Inverse of buildTxRef; null when the reference is not one of ours. */
export function paymentIdFromTxRef(txRef: unknown): string | null {
  if (typeof txRef !== 'string' || !txRef.startsWith(TX_REF_PREFIX)) return null;
  const id = txRef.slice(TX_REF_PREFIX.length);
  return /^[A-Za-z0-9]{1,64}$/.test(id) ? id : null;
}

/** Chapa wants local 10-digit numbers: +2519XXXXXXXX -> 09XXXXXXXX. */
export function toChapaPhone(e164: unknown): string | undefined {
  if (typeof e164 !== 'string') return undefined;
  const digits = e164.replace(/[^\d+]/g, '');
  const m = /^(?:\+?251|0)?([79]\d{8})$/.exec(digits);
  return m ? `0${m[1]}` : undefined;
}

/**
 * Chapa rejects customization text with characters other than letters,
 * numbers, hyphens, underscores, spaces and dots.
 */
export function sanitizeCheckoutText(text: unknown, maxLength: number): string {
  const s = typeof text === 'string' ? text : '';
  return s
    .normalize('NFKD')
    .replace(/[^A-Za-z0-9\-_. ]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength)
    .trim();
}

/** First word of a name, ASCII-safe, for Chapa first_name. */
export function firstNameOf(name: unknown): string {
  const first = sanitizeCheckoutText(name, 50).split(' ')[0];
  return first || 'Customer';
}

export function appendQuery(url: string, params: Record<string, string>): string {
  const u = new URL(url);
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, v);
  return u.toString();
}
