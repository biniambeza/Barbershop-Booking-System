/** Decides a transfer receipt from the parsed official receipt (pure). */
import { ParsedReceipt, receiverMatches } from './parse';
import {
  MAX_RECEIPT_AGE_DAYS,
  Pricing,
  ReceiptMethod,
  ReceiptReason,
  ReceiptReasons,
  ReceiptStatus,
  normalizeTransactionId,
  tierForAmount,
} from './pricing';

export interface ReceiptClaim {
  method: ReceiptMethod;
  /** Normalized. */
  transactionId: string;
  /** ETB the owner says they paid. */
  amount: number;
}

export type ReceiptCheck =
  | { kind: 'fetched'; receipt: ParsedReceipt }
  /** Network error, timeout, non-2xx (other than 404) or unreadable body. */
  | { kind: 'fetch_failed' }
  /** The page answered but has no such transaction (404 / empty page). */
  | { kind: 'not_found' }
  /** Not fetched ('other' method, or decided before fetching). */
  | { kind: 'skipped' };

export interface ReceiptVerdict {
  status: Exclude<ReceiptStatus, 'pending'>;
  reason: ReceiptReason | null;
  /** Granted days (verified only). */
  durationDays: number;
  /** Amount shown on the official receipt (verified only). */
  verifiedAmount: number | null;
}

const DAY_MS = 24 * 60 * 60 * 1000;
/** Receipt clocks and ours may disagree a little. */
const FUTURE_TOLERANCE_MS = 60 * 60 * 1000;

const review = (reason: ReceiptReason): ReceiptVerdict => ({
  status: 'needs_review',
  reason,
  durationDays: 0,
  verifiedAmount: null,
});

const reject = (reason: ReceiptReason): ReceiptVerdict => ({
  status: 'rejected',
  reason,
  durationDays: 0,
  verifiedAmount: null,
});

/**
 * Decisions that need no receipt: below the cheapest tier -> rejected
 * amount_too_low; the same transaction already used -> rejected duplicate;
 * 'other' -> needs_review. Null: fetch the receipt and call [evaluateReceipt].
 */
export function precheckReceipt(claim: ReceiptClaim, pricing: Pricing, duplicate: boolean): ReceiptVerdict | null {
  if (!tierForAmount(pricing.tiers, claim.amount)) return reject(ReceiptReasons.amountTooLow);
  if (duplicate) return reject(ReceiptReasons.duplicate);
  if (claim.method === 'other') return review(ReceiptReasons.unsupportedMethod);
  return null;
}

/**
 * Accepts only when: the receipt was found, its reference (when shown) is
 * the claimed transaction, its status is completed/success, the receiver
 * is the configured account, the amount covers the claimed tier, and it is
 * at most MAX_RECEIPT_AGE_DAYS old. Then the claimed tier's days are
 * granted. Anything else -> needs_review with the reason (an admin decides).
 */
export function evaluateReceipt(
  claim: ReceiptClaim,
  pricing: Pricing,
  check: ReceiptCheck,
  now: Date,
  duplicate = false,
): ReceiptVerdict {
  const pre = precheckReceipt(claim, pricing, duplicate);
  if (pre) return pre;
  const tier = tierForAmount(pricing.tiers, claim.amount)!;
  if (check.kind === 'fetch_failed' || check.kind === 'skipped') return review(ReceiptReasons.fetchFailed);
  if (check.kind === 'not_found' || !check.receipt.found) return review(ReceiptReasons.receiptNotFound);
  const r = check.receipt;
  if (r.reference && normalizeTransactionId(r.reference) !== claim.transactionId) {
    return review(ReceiptReasons.receiptNotFound);
  }
  if (!r.status || !/^(completed?|success(ful)?|paid|approved)$/i.test(r.status.trim())) {
    return review(ReceiptReasons.notCompleted);
  }
  const receiver = claim.method === 'cbe' ? pricing.cbe : pricing.telebirr;
  if (!receiverMatches(r, receiver)) return review(ReceiptReasons.receiverMismatch);
  if (r.amount === null || r.amount + 1e-9 < tier.amount) return review(ReceiptReasons.amountMismatch);
  if (
    !r.paidAt ||
    r.paidAt.getTime() < now.getTime() - MAX_RECEIPT_AGE_DAYS * DAY_MS ||
    r.paidAt.getTime() > now.getTime() + FUTURE_TOLERANCE_MS
  ) {
    return review(ReceiptReasons.tooOld);
  }
  return { status: 'verified', reason: null, durationDays: tier.days, verifiedAmount: r.amount };
}

/**
 * Whether another receipt for the same transaction number (any method)
 * blocks this one: a verified one, or an open one created earlier.
 * Rejected ones do not (the owner may resubmit under the right method).
 */
export function isDuplicateTransaction(
  self: { id: string; createdAt: Date | null },
  others: readonly { id: string; status: unknown; createdAt: Date | null }[],
): boolean {
  return others.some((o) => {
    if (o.id === self.id) return false;
    if (o.status === 'verified') return true;
    if (o.status !== 'pending' && o.status !== 'needs_review') return false;
    const mine = self.createdAt?.getTime() ?? Number.MAX_SAFE_INTEGER;
    const theirs = o.createdAt?.getTime() ?? Number.MAX_SAFE_INTEGER;
    return theirs < mine || (theirs === mine && o.id < self.id);
  });
}
