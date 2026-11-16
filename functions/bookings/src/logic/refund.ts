/**
 * Refunds of paid bookings that get cancelled (Blaze backstop).
 *
 * The app flags the refund itself, in the same write as the cancellation
 * (lib/services/refunds.dart + refund_writes.dart), so it works on the free
 * Spark plan. On Blaze, `flagRefundOnCancel` (bookings/{bookingId} updated)
 * does the same for any booking that is cancelled and paid but still has no
 * `refundStatus` (an older app cancelled it, the system cancelled it, or
 * Chapa confirmed a payment after the cancel), idempotently: a booking that
 * already has a refundStatus is never touched. It also mirrors the
 * booking's refund fields onto its `payments/{paymentId}` document.
 *
 * Amount rules (mirror lib/services/refunds.dart):
 *  - the shop side cancelled (barber, owner, admin, declined / expired
 *    request, shop deleted, system): the full price;
 *  - the customer cancelled before the shop's cutoff: the full price;
 *  - the customer cancelled after the cutoff: LATE_CANCEL_REFUND_PERCENT %;
 *  - a no-show is not a cancellation: nothing.
 *
 * Booking fields written: refundStatus 'due', refundAmount (ETB, 2
 * decimals), refundReason, refundFlaggedAt (ISO). Customer inbox:
 * users/{customerId}/notifications/{bookingId}_refundDue (created only if
 * missing).
 */
import { toInstant } from './lockIds';
import { BookingData, SYSTEM_CANCELLER } from './verify';

export const LATE_CANCEL_REFUND_PERCENT = 50;

/** Default shop cancellation cutoff (kDefaultCancellationCutoffHours). */
export const DEFAULT_CUTOFF_HOURS = 2;

export const REFUND_REASONS = {
  customerCancelled: 'customer_cancelled',
  customerLateCancel: 'customer_late_cancel',
  barberCancelled: 'barber_cancelled',
  shopCancelled: 'shop_cancelled',
  adminCancelled: 'admin_cancelled',
  requestDeclined: 'request_declined',
  requestExpired: 'request_expired',
  shopDeleted: 'shop_deleted',
  systemCancelled: 'system_cancelled',
} as const;

/** Fields mirrored from the booking onto its payments/{paymentId} doc. */
export const MIRRORED_REFUND_FIELDS = [
  'refundStatus',
  'refundAmount',
  'refundReason',
  'refundFlaggedAt',
  'refundedAt',
  'refundedBy',
  'refundMethod',
  'refundReference',
] as const;

export interface RefundBookingData extends BookingData {
  customerId?: unknown;
  shopName?: unknown;
  price?: unknown;
  paymentStatus?: unknown;
  paymentId?: unknown;
  cancelledBy?: unknown;
  cancelReason?: unknown;
  declineReason?: unknown;
  refundStatus?: unknown;
}

const str = (v: unknown): string | null => (typeof v === 'string' && v.length > 0 ? v : null);

/** Rounds ETB to 2 decimals. */
export function roundEtb(value: number): number {
  return Math.round(value * 100) / 100;
}

/** Cancelled, paid and not flagged yet: a refund must be flagged. */
export function needsRefundFlag(b: RefundBookingData | null | undefined): boolean {
  if (!b) return false;
  const price = typeof b.price === 'number' ? b.price : NaN;
  return b.status === 'cancelled' && b.paymentStatus === 'paid' && b.refundStatus == null && price > 0;
}

/**
 * Whether this update needs the function: a refund to flag, or refund
 * fields that changed (to mirror onto the payment doc).
 */
export function shouldHandleRefund(before: RefundBookingData | null, after: RefundBookingData | null): boolean {
  if (!after) return false;
  if (needsRefundFlag(after)) return true;
  if (!before) return false;
  return MIRRORED_REFUND_FIELDS.some((k) => before[k] !== after[k]) && after.refundStatus != null;
}

/**
 * The refund reason of a cancelled booking. `cancelledAt` is the moment of
 * the cancel when this update is the cancel itself (null when unknown, e.g.
 * the payment arrived later: the customer is then treated as on time).
 */
export function refundReasonFor(b: RefundBookingData, cutoffHours: number | null, cancelledAt: Date | null): string {
  const by = str(b.cancelledBy);
  if (b.cancelReason === 'shop_deleted') return REFUND_REASONS.shopDeleted;
  if (b.cancelReason === 'not_accepted' || b.declineReason === 'not_accepted') return REFUND_REASONS.requestExpired;
  if (by === 'barber' || by === 'owner') return REFUND_REASONS.requestDeclined;
  if (by !== null && by === str(b.customerId)) {
    const start = toInstant(b.startAt);
    const cutoff = cutoffHours ?? DEFAULT_CUTOFF_HOURS;
    if (cancelledAt && start && cancelledAt.getTime() > start.getTime() - cutoff * 3600 * 1000) {
      return REFUND_REASONS.customerLateCancel;
    }
    return REFUND_REASONS.customerCancelled;
  }
  if (by === null || by === SYSTEM_CANCELLER) return REFUND_REASONS.systemCancelled;
  return REFUND_REASONS.shopCancelled;
}

/** ETB to refund for `reason` (0 when the price is not valid). */
export function refundAmountFor(price: unknown, reason: string): number {
  if (typeof price !== 'number' || !Number.isFinite(price) || price <= 0) return 0;
  if (reason === REFUND_REASONS.customerLateCancel) return roundEtb((price * LATE_CANCEL_REFUND_PERCENT) / 100);
  return roundEtb(price);
}

export interface RefundFlagFields {
  refundStatus: 'due';
  refundAmount: number;
  refundReason: string;
  refundFlaggedAt: string;
}

/** The four refund fields for `b`, or null when nothing is owed. */
export function planRefundFlag(
  b: RefundBookingData | null,
  opts: { now: Date; cutoffHours: number | null; cancelledAt: Date | null },
): RefundFlagFields | null {
  if (!b || !needsRefundFlag(b)) return null;
  const reason = refundReasonFor(b, opts.cutoffHours, opts.cancelledAt);
  const amount = refundAmountFor(b.price, reason);
  if (amount <= 0) return null;
  return { refundStatus: 'due', refundAmount: amount, refundReason: reason, refundFlaggedAt: opts.now.toISOString() };
}

/** Refund fields of `booking` that the payment doc lacks or has different. */
export function paymentMirrorPatch(
  booking: Record<string, unknown>,
  payment: Record<string, unknown> | null,
): Record<string, unknown> | null {
  if (!payment || booking.refundStatus == null) return null;
  const patch: Record<string, unknown> = {};
  for (const k of MIRRORED_REFUND_FIELDS) {
    if (booking[k] !== undefined && booking[k] !== payment[k]) patch[k] = booking[k];
  }
  return Object.keys(patch).length > 0 ? patch : null;
}

const two = (n: number) => String(n).padStart(2, '0');

/** Addis wall-clock 'dd/MM/yyyy HH:mm' (UTC+3, no DST). */
export function addisWhen(startAt: unknown): string {
  const start = toInstant(startAt);
  if (!start) return '';
  const a = new Date(start.getTime() + 3 * 3600 * 1000);
  return `${two(a.getUTCDate())}/${two(a.getUTCMonth() + 1)}/${a.getUTCFullYear()} ${two(a.getUTCHours())}:${two(a.getUTCMinutes())}`;
}

/** Same text as renderRefundDueText in lib/services/refunds.dart. */
export function renderRefundDue(
  b: RefundBookingData,
  amount: number,
  language: unknown,
): { title: string; body: string } {
  const shop = str(typeof b.shopName === 'string' ? b.shopName.trim() : null);
  const when = addisWhen(b.startAt);
  const etb = `ETB ${amount.toFixed(2)}`;
  if (language === 'en') {
    return {
      title: 'Refund due',
      body: `Your paid appointment on ${when} was cancelled. ${shop ?? 'The barbershop'} owes you a refund of ${etb}.`,
    };
  }
  return {
    title: 'ተመላሽ ገንዘብ አለዎት',
    body: `በ${when} የከፈሉበት ቀጠሮ ተሰርዟል። ${shop ?? 'ፀጉር ቤቱ'} ${etb} ተመላሽ ያደርግልዎታል።`,
  };
}

export function refundDueNoticeId(bookingId: string): string {
  return `${bookingId}_refundDue`;
}

/** The transaction operations, so the flow can be tested without Firestore. */
export interface RefundTx {
  getBooking(): Promise<RefundBookingData | null>;
  /** The shop's cancellationCutoffHours, or null. */
  getCutoffHours(shopId: string): Promise<number | null>;
  /** The customer's language ('en' | 'am' | undefined). */
  getLanguage(uid: string): Promise<unknown>;
  noticeExists(uid: string, noticeId: string): Promise<boolean>;
  getPayment(paymentId: string): Promise<Record<string, unknown> | null>;
  updateBooking(fields: Record<string, unknown>): void;
  createNotice(uid: string, noticeId: string, data: Record<string, unknown>): void;
  updatePayment(paymentId: string, fields: Record<string, unknown>): void;
}

export type RefundOutcome = {
  flagged: RefundFlagFields | null;
  notified: boolean;
  mirrored: boolean;
};

/**
 * One attempt (inside a transaction). Re-reads the booking: flags it when
 * it is cancelled, paid and unflagged (never overwrites an existing
 * refundStatus), creates the customer's notice if missing, and mirrors the
 * refund fields onto the payment doc. Safe to retry.
 */
export async function flagRefundInTx(
  bookingId: string,
  opts: { now: Date; cancelTransition: boolean },
  tx: RefundTx,
): Promise<RefundOutcome> {
  const booking = await tx.getBooking();
  const outcome: RefundOutcome = { flagged: null, notified: false, mirrored: false };
  if (!booking) return outcome;

  const shopId = str(booking.shopId);
  const customerId = str(booking.customerId);
  const paymentId = str(booking.paymentId);
  let flag: RefundFlagFields | null = null;
  let language: unknown;
  let noticeMissing = false;
  if (needsRefundFlag(booking)) {
    const cutoff = shopId ? await tx.getCutoffHours(shopId) : null;
    flag = planRefundFlag(booking, { now: opts.now, cutoffHours: cutoff, cancelledAt: opts.cancelTransition ? opts.now : null });
    if (flag && customerId) {
      language = await tx.getLanguage(customerId);
      noticeMissing = !(await tx.noticeExists(customerId, refundDueNoticeId(bookingId)));
    }
  }
  const payment = paymentId ? await tx.getPayment(paymentId) : null;

  // Writes (after every read).
  const merged: Record<string, unknown> = { ...booking, ...(flag ?? {}) };
  if (flag) {
    tx.updateBooking({ ...flag });
    outcome.flagged = flag;
    if (customerId && noticeMissing) {
      const text = renderRefundDue(booking, flag.refundAmount, language);
      tx.createNotice(customerId, refundDueNoticeId(bookingId), {
        type: 'refundDue',
        title: text.title,
        body: text.body,
        bookingId,
        read: false,
        createdAt: opts.now.toISOString(),
      });
      outcome.notified = true;
    }
  }
  const patch = paymentId ? paymentMirrorPatch(merged, payment) : null;
  if (paymentId && patch) {
    tx.updatePayment(paymentId, patch);
    outcome.mirrored = true;
  }
  return outcome;
}
