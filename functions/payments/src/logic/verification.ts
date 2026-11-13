/** Interpreting Chapa's GET /transaction/verify result against our payment doc. */
import { CURRENCY } from '../config';
import { amountsMatch } from './money';

export type PaymentStatus = 'pending' | 'success' | 'failed';

export interface ChapaVerifyData {
  status?: unknown;
  amount?: unknown;
  currency?: unknown;
  tx_ref?: unknown;
  reference?: unknown;
  method?: unknown;
}

export interface ExpectedPayment {
  amount: number;
  currency: string;
  txRef: string;
}

export type VerifyOutcome =
  | { outcome: 'success' }
  | { outcome: 'pending' }
  | { outcome: 'failed'; reason: string };

export function mapChapaStatus(status: unknown): PaymentStatus {
  const s = typeof status === 'string' ? status.toLowerCase() : '';
  if (s === 'success' || s === 'successful' || s === 'completed') return 'success';
  if (s === 'failed' || s === 'cancelled' || s === 'canceled' || s === 'reversed' || s === 'expired') {
    return 'failed';
  }
  return 'pending';
}

/**
 * A payment is only successful when Chapa says success AND the tx_ref,
 * currency and amount all match what we created. A "success" with a wrong
 * amount/currency is recorded as failed (with a reason) for manual review.
 */
export function evaluateVerification(expected: ExpectedPayment, data: ChapaVerifyData | null): VerifyOutcome {
  if (!data) return { outcome: 'pending' };
  const status = mapChapaStatus(data.status);
  if (status === 'pending') return { outcome: 'pending' };
  if (status === 'failed') return { outcome: 'failed', reason: `chapa_status_${String(data.status)}` };

  if (typeof data.tx_ref === 'string' && data.tx_ref !== expected.txRef) {
    return { outcome: 'failed', reason: 'tx_ref_mismatch' };
  }
  const currency = typeof data.currency === 'string' ? data.currency.toUpperCase() : '';
  if (currency !== (expected.currency || CURRENCY).toUpperCase()) {
    return { outcome: 'failed', reason: 'currency_mismatch' };
  }
  if (!amountsMatch(expected.amount, data.amount)) {
    return { outcome: 'failed', reason: 'amount_mismatch' };
  }
  return { outcome: 'success' };
}
