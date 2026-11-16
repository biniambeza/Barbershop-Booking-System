/**
 * Account deletion clean-up, server side (Blaze only).
 *
 * The app deletes an account itself on the free Spark plan
 * (lib/services/account_deletion.dart, Settings > Delete account): it
 * cancels the person's upcoming bookings it may cancel, anonymises their
 * bookings and reviews, removes a barber's profile, deletes their personal
 * documents, then users/{uid} and the login. Some things a client cannot do
 * (the rules refuse them) or may leave half done (app closed, network
 * lost). `onUserProfileDeleted` (users/{uid} deleted) repeats the work
 * idempotently with the Admin SDK:
 *
 *  1. The person's own upcoming bookings (pending/confirmed, not started)
 *     that are still open - typically those inside the shop's cancellation
 *     cutoff - are cancelled {status: 'cancelled', cancelledBy: 'system',
 *     cancelReason: 'account_deleted'}, their own slot locks deleted. A paid
 *     one gets the refund flag of a customer cancel (same rules as
 *     refundFlagFor in lib/services/refunds.dart: full price before the
 *     cutoff, LATE_CANCEL_REFUND_PERCENT % after it) and keeps the
 *     customer's name and phone (the shop pays the money back); an unpaid
 *     one is anonymised in the same write.
 *  2. Every other booking of the person: name 'Former customer', phone ''
 *     (not while a refund is due, nor on a paid booking still open).
 *  3. Their reviews (review id = booking id, completed bookings): name
 *     'Former customer', comment removed, stars and reply kept.
 *  4. A barber (profile role 'barber' with shopId and barberId, and no other
 *     profile linked to that barber): their customers' upcoming bookings
 *     are cancelled like a barber cancel (full refund flag + 'Refund due'
 *     notice for paid ones, plus the "barber left" notice), then the whole
 *     barber document tree (portfolio photos, time off, slot locks, private
 *     contact) and the Storage copies of the portfolio photos are deleted.
 *  5. Leftover personal documents: invites/{email}, an unapproved
 *     shopApplications/{uid}, shopRemovalRequests/{uid} and the profile's
 *     subcollections (inbox, device tokens).
 *
 * The Firebase Auth login is NOT deleted here (the app deletes it after a
 * fresh sign-in; an admin removing a profile document must not delete a
 * login).
 *
 * Pure logic over a small store interface (unit tested without Firebase).
 */

/** Same value as kAccountDeletedCancelReason in lib/services/account_deletion.dart. */
export const ACCOUNT_DELETED_REASON = 'account_deleted';
/** Same value as kFormerCustomerName (firestore.rules accepts exactly this). */
export const FORMER_CUSTOMER_NAME = 'Former customer';
export const SYSTEM_CANCELLER = 'system';
/** kDefaultCancellationCutoffHours in lib/models/barbershop_model.dart. */
export const DEFAULT_CUTOFF_HOURS = 2;
/** kLateCancelRefundPercent in lib/services/refunds.dart. */
export const LATE_CANCEL_REFUND_PERCENT = 50;

export const REFUND_REASONS = {
  customerCancelled: 'customer_cancelled',
  customerLateCancel: 'customer_late_cancel',
  barberCancelled: 'barber_cancelled',
} as const;

const ADDIS_OFFSET_MS = 3 * 60 * 60 * 1000;

/** The deleted users/{uid} document (event "before" data). */
export interface DeletedProfile {
  role?: unknown;
  email?: unknown;
  shopId?: unknown;
  barberId?: unknown;
}

export interface BookingRow {
  id: string;
  status?: unknown;
  startAt?: unknown;
  customerId?: unknown;
  customerName?: unknown;
  customerPhone?: unknown;
  shopId?: unknown;
  shopName?: unknown;
  barberId?: unknown;
  barberName?: unknown;
  price?: unknown;
  paymentStatus?: unknown;
  refundStatus?: unknown;
}

/** users/{uid}/notifications/{id}: same keys as the app's notices. */
export interface NoticeDoc {
  type: 'cancelled' | 'refundDue';
  title: string;
  body: string;
  bookingId: string;
  read: false;
  createdAt: string;
}

export interface Notice {
  uid: string;
  id: string;
  doc: NoticeDoc;
}

/** What to write for one booking (computed from its current state). */
export interface BookingWrite {
  fields: Record<string, unknown>;
  /** Delete the booking's own slot locks (a cancellation). */
  releaseLocks: boolean;
  notices: Notice[];
}

export interface AccountDeletionStore {
  /** Every booking whose customerId is [uid]. */
  bookingsOfCustomer(uid: string): Promise<BookingRow[]>;
  /** Bookings of the barber with startAt >= nowIso. */
  upcomingBookingsOfBarber(shopId: string, barberId: string, nowIso: string): Promise<BookingRow[]>;
  /** The shop's cancellationCutoffHours (null when the shop or the field is missing). */
  cutoffHours(shopId: string): Promise<number | null>;
  languageOf(uid: string): Promise<string | undefined>;
  /**
   * In one transaction: reads the booking, asks [plan] what to write (null =
   * nothing), then updates it, deletes its own slot locks when asked and
   * sets the notices. Returns whether anything was written.
   */
  updateBooking(bookingId: string, plan: (current: BookingRow | null) => BookingWrite | null): Promise<boolean>;
  /**
   * barbershops/{shopId}/reviews/{bookingId}: when it is [uid]'s and not
   * anonymised yet, sets the name and removes the comment. Returns whether
   * it changed.
   */
  anonymizeReview(shopId: string, bookingId: string, uid: string): Promise<boolean>;
  /** Other users/{x} documents linked to this barber profile. */
  otherProfilesOfBarber(shopId: string, barberId: string, uid: string): Promise<number>;
  /** Deletes barbershops/{shopId}/barbers/{barberId} and everything under it. */
  deleteBarberTree(shopId: string, barberId: string): Promise<void>;
  /** Deletes the Storage objects under portfolio/{shopId}/{barberId}/; returns how many. */
  deletePortfolioFiles(shopId: string, barberId: string): Promise<number>;
  /** invites/{email}, unapproved shopApplications/{uid}, shopRemovalRequests/{uid}, users/{uid} subcollections. */
  deletePersonalData(uid: string, email: string | null): Promise<void>;
}

export interface AccountCleanupResult {
  cancelledOwn: number;
  refundsFlagged: number;
  anonymizedBookings: number;
  anonymizedReviews: number;
  cancelledForBarber: number;
  barberRemoved: boolean;
  portfolioFiles: number;
}

const str = (v: unknown): string | null => (typeof v === 'string' && v.trim() !== '' ? v : null);

function instant(v: unknown): Date | null {
  if (typeof v === 'string' && v.length > 0) {
    const ms = Date.parse(v);
    return Number.isNaN(ms) ? null : new Date(ms);
  }
  if (v && typeof (v as { toDate?: unknown }).toDate === 'function') {
    const d = (v as { toDate: () => unknown }).toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  return null;
}

const isOpen = (b: BookingRow) => b.status === 'pending' || b.status === 'confirmed';

/** Pending/confirmed and not started at [now]. */
export function isUpcoming(b: BookingRow, now: Date): boolean {
  const start = instant(b.startAt);
  return isOpen(b) && start !== null && start.getTime() >= now.getTime();
}

/** Paid, no refund recorded yet and a valid price (refunds.dart needsRefundFlag). */
export function isPaidUnflagged(b: BookingRow): boolean {
  return b.paymentStatus === 'paid' && b.refundStatus == null && typeof b.price === 'number' && b.price > 0;
}

/** keepsContactForRefund in account_deletion.dart. */
export function keepsContact(b: BookingRow): boolean {
  return b.refundStatus === 'due' || (b.paymentStatus === 'paid' && b.refundStatus == null && isOpen(b));
}

export function roundEtb(value: number): number {
  return Math.round(value * 100) / 100;
}

/** isLateCustomerCancel in refunds.dart (null cutoff = not late). */
export function isLateCustomerCancel(b: BookingRow, cutoffHours: number | null, now: Date): boolean {
  const start = instant(b.startAt);
  if (cutoffHours === null || !start) return false;
  return now.getTime() > start.getTime() - cutoffHours * 3600 * 1000;
}

export function refundAmountFor(price: unknown, reason: string): number {
  if (typeof price !== 'number' || !Number.isFinite(price) || price <= 0) return 0;
  if (reason === REFUND_REASONS.customerLateCancel) return roundEtb((price * LATE_CANCEL_REFUND_PERCENT) / 100);
  return roundEtb(price);
}

/** The four refund fields (BookingRefund.toFlagFields), or null when nothing is owed. */
export function refundFlag(b: BookingRow, reason: string, now: Date): Record<string, unknown> | null {
  if (!isPaidUnflagged(b)) return null;
  const amount = refundAmountFor(b.price, reason);
  if (amount <= 0) return null;
  return { refundStatus: 'due', refundAmount: amount, refundReason: reason, refundFlaggedAt: now.toISOString() };
}

const anonymized = (b: BookingRow) => b.customerName === FORMER_CUSTOMER_NAME && (b.customerPhone ?? '') === '';

export const ANONYMIZED_FIELDS = { customerName: FORMER_CUSTOMER_NAME, customerPhone: '' } as const;

/** Step 1: the deleted customer's own open booking. */
export function planOwnCancel(current: BookingRow | null, uid: string, cutoffHours: number | null, now: Date): BookingWrite | null {
  if (!current || current.customerId !== uid || !isUpcoming(current, now)) return null;
  const reason = isLateCustomerCancel(current, cutoffHours, now)
    ? REFUND_REASONS.customerLateCancel
    : REFUND_REASONS.customerCancelled;
  const refund = refundFlag(current, reason, now);
  const fields: Record<string, unknown> = {
    status: 'cancelled',
    cancelledBy: SYSTEM_CANCELLER,
    cancelReason: ACCOUNT_DELETED_REASON,
    ...(refund ?? {}),
    // Nothing owed: no reason to keep the name and phone.
    ...(refund || current.refundStatus === 'due' ? {} : ANONYMIZED_FIELDS),
  };
  return { fields, releaseLocks: true, notices: [] };
}

/** Step 2: any other booking of the deleted customer. */
export function planAnonymize(current: BookingRow | null, uid: string): BookingWrite | null {
  if (!current || current.customerId !== uid || keepsContact(current) || anonymized(current)) return null;
  return { fields: { ...ANONYMIZED_FIELDS }, releaseLocks: false, notices: [] };
}

const two = (n: number) => String(n).padStart(2, '0');

/** Addis wall clock 'dd/MM/yyyy HH:mm' (UTC+3, no DST). */
export function addisWhen(startAt: unknown): string {
  const start = instant(startAt);
  if (!start) return '';
  const a = new Date(start.getTime() + ADDIS_OFFSET_MS);
  return `${two(a.getUTCDate())}/${two(a.getUTCMonth() + 1)}/${a.getUTCFullYear()} ${two(a.getUTCHours())}:${two(a.getUTCMinutes())}`;
}

/** Same copy as renderBarberLeftText in lib/services/account_deletion.dart. */
export function barberLeftText(b: BookingRow, language?: string): { title: string; body: string } {
  const barber = str(typeof b.barberName === 'string' ? b.barberName.trim() : null);
  const shop = str(typeof b.shopName === 'string' ? b.shopName.trim() : null) ?? 'Crown & Blade';
  if (language === 'en') {
    return {
      title: 'Booking cancelled',
      body: `${barber ?? 'Your barber'} no longer works at ${shop}, so your appointment was cancelled. Please book another time.`,
    };
  }
  return {
    title: 'ቀጠሮዎ ተሰርዟል',
    body: `${barber ?? 'ፀጉር አስተካካዩ'} ከ${shop} ስለለቀቁ ቀጠሮዎ ተሰርዟል። እባክዎ ሌላ ጊዜ ይያዙ።`,
  };
}

/** Same copy as renderRefundDueText in lib/services/refunds.dart. */
export function refundDueText(b: BookingRow, amount: number, language?: string): { title: string; body: string } {
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

/** Step 4: a customer's upcoming booking with the deleted barber. */
export function planBarberCancel(
  current: BookingRow | null,
  barber: { uid: string; shopId: string; barberId: string },
  language: string | undefined,
  now: Date,
): BookingWrite | null {
  if (!current || current.shopId !== barber.shopId || current.barberId !== barber.barberId) return null;
  const customerId = str(current.customerId);
  if (!customerId || customerId === barber.uid || !isUpcoming(current, now)) return null;
  const nowIso = now.toISOString();
  const refund = refundFlag(current, REFUND_REASONS.barberCancelled, now);
  const left = barberLeftText(current, language);
  const notices: Notice[] = [
    {
      uid: customerId,
      id: `${current.id}_cancelled`,
      doc: { type: 'cancelled', title: left.title, body: left.body, bookingId: current.id, read: false, createdAt: nowIso },
    },
  ];
  if (refund) {
    const due = refundDueText(current, refund.refundAmount as number, language);
    notices.push({
      uid: customerId,
      id: `${current.id}_refundDue`,
      doc: { type: 'refundDue', title: due.title, body: due.body, bookingId: current.id, read: false, createdAt: nowIso },
    });
  }
  return {
    fields: { status: 'cancelled', cancelledBy: SYSTEM_CANCELLER, cancelReason: ACCOUNT_DELETED_REASON, ...(refund ?? {}) },
    releaseLocks: true,
    notices,
  };
}

/** The barber profile a deleted users/{uid} document pointed at, if any. */
export function barberOf(profile: DeletedProfile | null | undefined): { shopId: string; barberId: string } | null {
  if (!profile || profile.role !== 'barber') return null;
  const shopId = str(profile.shopId);
  const barberId = str(profile.barberId);
  return shopId && barberId ? { shopId, barberId } : null;
}

/** Runs the whole clean-up for the deleted users/{uid} (safe to run any number of times). */
export async function cleanupDeletedAccount(
  uid: string,
  profile: DeletedProfile | null | undefined,
  store: AccountDeletionStore,
  now: Date,
): Promise<AccountCleanupResult> {
  const result: AccountCleanupResult = {
    cancelledOwn: 0,
    refundsFlagged: 0,
    anonymizedBookings: 0,
    anonymizedReviews: 0,
    cancelledForBarber: 0,
    barberRemoved: false,
    portfolioFiles: 0,
  };

  // 1. Own upcoming bookings still open.
  const own = await store.bookingsOfCustomer(uid);
  const cutoffs = new Map<string, number | null>();
  for (const b of own.filter((x) => isUpcoming(x, now))) {
    const shopId = str(b.shopId);
    if (shopId && !cutoffs.has(shopId)) cutoffs.set(shopId, await store.cutoffHours(shopId));
    let flagged = false;
    const wrote = await store.updateBooking(b.id, (current) => {
      const write = planOwnCancel(current, uid, shopId ? cutoffs.get(shopId) ?? null : null, now);
      flagged = write !== null && write.fields.refundStatus === 'due';
      return write;
    });
    if (wrote) {
      result.cancelledOwn++;
      if (flagged) result.refundsFlagged++;
    }
  }

  // 2. Every other booking: anonymised (re-read: step 1 changed some).
  const after = await store.bookingsOfCustomer(uid);
  for (const b of after) {
    if (!planAnonymize(b, uid)) continue;
    if (await store.updateBooking(b.id, (current) => planAnonymize(current, uid))) result.anonymizedBookings++;
  }

  // 3. Reviews of completed bookings.
  for (const b of after) {
    const shopId = str(b.shopId);
    if (b.status !== 'completed' || !shopId) continue;
    if (await store.anonymizeReview(shopId, b.id, uid)) result.anonymizedReviews++;
  }

  // 4. A barber's profile and their customers' bookings.
  const barber = barberOf(profile);
  if (barber && (await store.otherProfilesOfBarber(barber.shopId, barber.barberId, uid)) === 0) {
    const ctx = { uid, ...barber };
    const languages = new Map<string, string | undefined>();
    const theirs = (await store.upcomingBookingsOfBarber(barber.shopId, barber.barberId, now.toISOString()))
      .filter((b) => planBarberCancel(b, ctx, undefined, now) !== null);
    for (const b of theirs) {
      const customerId = b.customerId as string;
      if (!languages.has(customerId)) languages.set(customerId, await store.languageOf(customerId));
      let flagged = false;
      const wrote = await store.updateBooking(b.id, (current) => {
        const write = planBarberCancel(current, ctx, languages.get(customerId), now);
        flagged = write !== null && write.fields.refundStatus === 'due';
        return write;
      });
      if (wrote) {
        result.cancelledForBarber++;
        if (flagged) result.refundsFlagged++;
      }
    }
    await store.deleteBarberTree(barber.shopId, barber.barberId);
    result.portfolioFiles = await store.deletePortfolioFiles(barber.shopId, barber.barberId);
    result.barberRemoved = true;
  }

  // 5. Leftover personal documents.
  const email = str(profile?.email);
  await store.deletePersonalData(uid, email ? email.trim().toLowerCase() : null);
  return result;
}
