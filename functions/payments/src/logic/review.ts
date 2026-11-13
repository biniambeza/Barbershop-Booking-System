/**
 * resolvePaymentReview: an admin closes a payment flagged needsReview
 * (paid for a cancelled or missing booking, paid twice, refund reported
 * without a signed payload, subscription that could not be applied).
 *
 * - 'refunded_in_chapa': the admin refunded the money in the Chapa
 *   dashboard. The payment becomes status 'refunded' (refundedAt set) and,
 *   if the booking still points at this payment, booking.paymentStatus
 *   becomes 'refunded'.
 * - 'no_action': nothing to do (e.g. the customer kept the booking).
 *
 * Both clear needsReview and record resolution, resolutionNote, resolvedBy
 * and resolvedAt.
 */
import { DocStore, FlowError } from './docstore';

export const REVIEW_RESOLUTIONS = ['refunded_in_chapa', 'no_action'] as const;
export type ReviewResolution = (typeof REVIEW_RESOLUTIONS)[number];

export const MAX_REVIEW_NOTE = 500;

export interface ReviewRequest {
  paymentId: string;
  resolution: ReviewResolution;
  note: string | null;
}

export function isReviewResolution(v: unknown): v is ReviewResolution {
  return typeof v === 'string' && (REVIEW_RESOLUTIONS as readonly string[]).includes(v);
}

/** Validates callable input; throws FlowError('invalid-argument') when bad. */
export function parseReviewRequest(data: unknown): ReviewRequest {
  const d = (data ?? {}) as Record<string, unknown>;
  const paymentId = d.paymentId;
  if (typeof paymentId !== 'string' || !paymentId || paymentId.length > 128 || paymentId.includes('/')) {
    throw new FlowError('invalid-argument', 'paymentId is required.');
  }
  if (!isReviewResolution(d.resolution)) {
    throw new FlowError('invalid-argument', `resolution must be one of ${REVIEW_RESOLUTIONS.join(', ')}.`);
  }
  let note: string | null = null;
  if (d.note !== undefined && d.note !== null) {
    if (typeof d.note !== 'string') throw new FlowError('invalid-argument', 'note must be text.');
    const trimmed = d.note.trim();
    if (trimmed.length > MAX_REVIEW_NOTE) {
      throw new FlowError('invalid-argument', `note must be at most ${MAX_REVIEW_NOTE} characters.`);
    }
    note = trimmed || null;
  }
  return { paymentId, resolution: d.resolution, note };
}

export interface ReviewResult {
  paymentId: string;
  resolution: ReviewResolution;
  status: string;
  bookingPaymentStatus: string | null;
  resolvedAt: string;
}

export async function resolvePaymentReview(
  store: DocStore,
  req: ReviewRequest,
  adminUid: string,
  now = new Date(),
): Promise<ReviewResult> {
  return store.runTransaction(async (tx) => {
    const payment = await tx.get('payments', req.paymentId);
    if (!payment) throw new FlowError('not-found', 'Payment not found.');
    if (payment.needsReview !== true) {
      throw new FlowError('failed-precondition', 'This payment is not waiting for review.');
    }
    const bookingId = payment.type === 'booking' && typeof payment.bookingId === 'string' ? payment.bookingId : null;
    const booking = bookingId ? await tx.get('bookings', bookingId) : undefined;

    const nowIso = now.toISOString();
    const patch: Record<string, unknown> = {
      needsReview: false,
      resolution: req.resolution,
      resolutionNote: req.note,
      resolvedBy: adminUid,
      resolvedAt: nowIso,
    };
    let status = String(payment.status ?? '');
    let bookingPaymentStatus: string | null = booking ? String(booking.paymentStatus ?? 'unpaid') : null;

    if (req.resolution === 'refunded_in_chapa') {
      if (payment.status !== 'success' && payment.status !== 'refunded') {
        throw new FlowError('failed-precondition', 'Only a successful payment can be marked as refunded.');
      }
      status = 'refunded';
      patch.status = 'refunded';
      if (!payment.refundedAt) patch.refundedAt = nowIso;
      if (bookingId && booking && booking.paymentId === req.paymentId) {
        tx.update('bookings', bookingId, { paymentStatus: 'refunded' });
        bookingPaymentStatus = 'refunded';
      }
    }

    tx.update('payments', req.paymentId, patch);
    return { paymentId: req.paymentId, resolution: req.resolution, status, bookingPaymentStatus, resolvedAt: nowIso };
  });
}
