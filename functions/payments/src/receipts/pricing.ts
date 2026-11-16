/**
 * Subscription receipts: pricing tiers, transaction numbers and receipt
 * URLs (pure). Mirrors lib/services/subscription_pricing.dart; keep the
 * two in step.
 */

export type ReceiptMethod = 'telebirr' | 'cbe' | 'other';
export const RECEIPT_METHODS: readonly ReceiptMethod[] = ['telebirr', 'cbe', 'other'];

export type ReceiptStatus = 'pending' | 'verified' | 'rejected' | 'needs_review';

/** decisionReason values the app translates (receipts_l10n.dart). */
export const ReceiptReasons = {
  amountTooLow: 'amount_too_low',
  duplicate: 'duplicate',
  receiptNotFound: 'receipt_not_found',
  notCompleted: 'not_completed',
  receiverMismatch: 'receiver_mismatch',
  amountMismatch: 'amount_mismatch',
  tooOld: 'too_old',
  fetchFailed: 'fetch_failed',
  unsupportedMethod: 'unsupported_method',
} as const;
export type ReceiptReason = (typeof ReceiptReasons)[keyof typeof ReceiptReasons];

export const RECEIPTS_COLLECTION = 'subscriptionPayments';
export const PRICING_COLLECTION = 'platformConfig';
export const PRICING_DOC = 'subscriptionPricing';

/** A receipt older than this is not accepted automatically. */
export const MAX_RECEIPT_AGE_DAYS = 30;

export const MAX_RECEIPT_AMOUNT = 1_000_000;
export const MAX_TIER_DAYS = 1825;

/**
 * Official receipt pages. `{id}` is the transaction number; for CBE
 * `{suffix}` is the last 8 digits of the PAYER's account (the current CBE
 * receipt service needs `?id=FT...` + those 8 digits; older links work
 * with the reference alone). Admins can override both templates in
 * `platformConfig/subscriptionPricing.receiptUrls` (https only), e.g. to
 * route telebirr through a relay hosted in Ethiopia, because
 * transactioninfo.ethiotelecom.et often blocks or times out requests from
 * foreign IPs (Cloud Functions run in europe-west1).
 */
export const TELEBIRR_RECEIPT_URL = 'https://transactioninfo.ethiotelecom.et/receipt/{id}';
export const CBE_RECEIPT_URL = 'https://apps.cbe.com.et:100/?id={id}{suffix}';

export interface PricingTier {
  days: number;
  amount: number;
}

export interface Receiver {
  account: string;
  name: string;
}

export interface Pricing {
  currency: string;
  tiers: PricingTier[];
  telebirr: Receiver;
  cbe: Receiver;
  telebirrReceiptUrl: string;
  cbeReceiptUrl: string;
}

export const DEFAULT_PRICING: Pricing = {
  currency: 'ETB',
  tiers: [
    { days: 30, amount: 500 },
    { days: 90, amount: 1400 },
    { days: 180, amount: 2700 },
    { days: 365, amount: 5000 },
  ],
  telebirr: { account: '+2519XXXXXXXX', name: 'Crown & Blade' },
  cbe: { account: '1000XXXXXXXXX', name: 'Crown & Blade' },
  telebirrReceiptUrl: TELEBIRR_RECEIPT_URL,
  cbeReceiptUrl: CBE_RECEIPT_URL,
};

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

function parseTier(raw: unknown): PricingTier | null {
  const r = asRecord(raw);
  const days = r.days;
  const amount = r.amount;
  if (typeof days !== 'number' || typeof amount !== 'number') return null;
  if (!Number.isInteger(days) || days < 1 || days > MAX_TIER_DAYS) return null;
  if (!Number.isFinite(amount) || amount <= 0 || amount > MAX_RECEIPT_AMOUNT) return null;
  return { days, amount };
}

function parseReceiver(raw: unknown, fallback: Receiver, accountKey: string): Receiver {
  const r = asRecord(raw);
  if (Object.keys(r).length === 0) return fallback;
  const account = r[accountKey] ?? r.account ?? r.number;
  return {
    account: typeof account === 'string' ? account.trim() : fallback.account,
    name: typeof r.name === 'string' ? r.name.trim() : fallback.name,
  };
}

function urlTemplate(v: unknown, fallback: string): string {
  return typeof v === 'string' && v.startsWith('https://') && v.includes('{id}') ? v : fallback;
}

/** Tolerant read of `platformConfig/subscriptionPricing` (like the app). */
export function parsePricing(doc: unknown): Pricing {
  const d = asRecord(doc);
  if (Object.keys(d).length === 0) return DEFAULT_PRICING;
  const tiers = (Array.isArray(d.tiers) ? d.tiers : []).map(parseTier).filter((t): t is PricingTier => t !== null);
  const receivers = asRecord(d.receivers);
  const urls = asRecord(d.receiptUrls);
  return {
    currency: typeof d.currency === 'string' ? d.currency : 'ETB',
    tiers: tiers.length === 0 ? DEFAULT_PRICING.tiers : [...tiers].sort((a, b) => a.days - b.days),
    telebirr: parseReceiver(receivers.telebirr, DEFAULT_PRICING.telebirr, 'number'),
    cbe: parseReceiver(receivers.cbe, DEFAULT_PRICING.cbe, 'account'),
    telebirrReceiptUrl: urlTemplate(urls.telebirr, TELEBIRR_RECEIPT_URL),
    cbeReceiptUrl: urlTemplate(urls.cbe, CBE_RECEIPT_URL),
  };
}

/** The LONGEST tier whose amount is <= paid (1400 -> 90, 2000 -> 90, 5000+ -> 365); null below the cheapest. */
export function tierForAmount(tiers: readonly PricingTier[], paid: number): PricingTier | null {
  let best: PricingTier | null = null;
  for (const t of tiers) {
    if (t.amount <= paid + 1e-9 && (best === null || t.days > best.days)) best = t;
  }
  return best;
}

/** Trimmed, uppercase, no whitespace. */
export function normalizeTransactionId(raw: string): string {
  return raw.trim().toUpperCase().replace(/\s+/g, '');
}

/** telebirr: 8-12 letters/digits with a letter (e.g. CHK1AB2CDE); CBE: FT + 8-20; other: 4-40 incl. dashes. */
export function isValidTransactionId(method: ReceiptMethod, normalized: string): boolean {
  switch (method) {
    case 'telebirr':
      return /^[A-Z0-9]{8,12}$/.test(normalized) && /[A-Z]/.test(normalized);
    case 'cbe':
      return /^FT[A-Z0-9]{8,20}$/.test(normalized);
    case 'other':
      return /^[A-Z0-9][A-Z0-9-]{3,39}$/.test(normalized);
  }
}

/** `subscriptionPayments/{method}_{normalizedTransactionId}`. */
export function receiptDocId(method: ReceiptMethod, normalizedTransactionId: string): string {
  return `${method}_${normalizedTransactionId}`;
}

/** Digits only, the last 8 (null when fewer than 4). */
export function normalizePayerAccountSuffix(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const digits = raw.replace(/\D/g, '');
  if (digits.length < 4) return null;
  return digits.length > 8 ? digits.slice(-8) : digits;
}

/** The official receipt URL for a transaction (null for 'other'). */
export function officialReceiptUrl(
  method: ReceiptMethod,
  transactionId: string,
  opts: { payerAccountSuffix?: unknown; telebirrTemplate?: string; cbeTemplate?: string } = {},
): string | null {
  const id = encodeURIComponent(normalizeTransactionId(transactionId));
  if (!id) return null;
  if (method === 'telebirr') return (opts.telebirrTemplate ?? TELEBIRR_RECEIPT_URL).split('{id}').join(id);
  if (method === 'cbe') {
    const suffix = normalizePayerAccountSuffix(opts.payerAccountSuffix) ?? '';
    return (opts.cbeTemplate ?? CBE_RECEIPT_URL).split('{id}').join(id).split('{suffix}').join(suffix);
  }
  return null;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** New end: from the current end while it is in the future, else from now. */
export function extendByDays(currentEnd: Date | null, now: Date, days: number): Date {
  const base = currentEnd && currentEnd.getTime() > now.getTime() ? currentEnd : now;
  return new Date(base.getTime() + days * DAY_MS);
}

/** ISO string, Firestore Timestamp-like ({toDate}) or Date -> Date. */
export function toDate(value: unknown): Date | null {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (value && typeof (value as { toDate?: unknown }).toDate === 'function') {
    return toDate((value as { toDate(): Date }).toDate());
  }
  return null;
}
