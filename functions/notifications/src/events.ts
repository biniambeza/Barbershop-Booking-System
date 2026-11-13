/**
 * Pure event detection for booking and payment documents: given the document
 * before and after a write, which notification event(s) (if any) happened.
 */

export type BookingStatus = 'pending' | 'confirmed' | 'inProgress' | 'completed' | 'cancelled' | 'noShow';

export type BookingEvent =
  | 'created'
  | 'confirmed'
  | 'cancelled'
  | 'started'
  | 'completed'
  | 'slotTaken'
  | 'rescheduled'
  | 'noShow';

/** Payment events seen on a booking (paymentStatus changes). */
export type BookingPaymentEvent = 'paymentReceived' | 'paymentRefunded';
/** Payment events seen on payments/{paymentId}. */
export type PaymentEvent = 'paymentFailed' | 'subscriptionPaid' | 'subscriptionFailed';

export type NotificationType = BookingEvent | BookingPaymentEvent | PaymentEvent | 'reminder24h' | 'reminder2h';

/** Every notification type, in a stable order (tests, exhaustiveness). */
export const ALL_NOTIFICATION_TYPES: readonly NotificationType[] = [
  'created',
  'confirmed',
  'cancelled',
  'started',
  'completed',
  'slotTaken',
  'reminder24h',
  'reminder2h',
  'paymentReceived',
  'paymentRefunded',
  'paymentFailed',
  'subscriptionPaid',
  'subscriptionFailed',
  'rescheduled',
  'noShow',
];

/** Who cancelled, as far as we can tell. 'system' = a Cloud Function. */
export type CancelActor = 'customer' | 'barber' | 'shop' | 'admin' | 'system' | 'unknown';

/** cancelledBy / cancelReason written by the booking-integrity function. */
export const SYSTEM_CANCEL = 'system';
export const SLOT_CONFLICT_REASON = 'slot_conflict';

export interface BookingDoc {
  shopId?: string;
  shopName?: string;
  barberId?: string;
  barberName?: string;
  customerId?: string;
  customerName?: string;
  customerPhone?: string;
  serviceId?: string;
  serviceName?: string;
  price?: number;
  date?: string;
  timeSlot?: string;
  startAt?: string;
  endAt?: string;
  durationMinutes?: number;
  status?: string;
  paymentStatus?: string;
  paymentMethod?: string;
  paymentId?: string;
  paidAt?: string;
  createdAt?: string;
  /** Optional: uid of the user who cancelled (written by the client on cancel), or 'system'. */
  cancelledBy?: string;
  /** Optional machine reason, e.g. 'slot_conflict' (with cancelledBy 'system'). */
  cancelReason?: string;
  reminder24hSentAt?: string;
  reminder2hSentAt?: string;
  /** Times the customer moved the booking (absent = 0). */
  rescheduleCount?: number;
  /** UTC ISO time of the last reschedule. */
  rescheduledAt?: string;
  [key: string]: unknown;
}

/** Fields of payments/{paymentId} we read (written by functions/payments). */
export interface PaymentDoc {
  type?: string; // 'booking' | 'subscription'
  bookingId?: string;
  shopId?: string;
  userId?: string;
  plan?: string;
  amount?: number;
  currency?: string;
  status?: string; // 'pending' | 'success' | 'failed' | 'refunded'
  failureReason?: string | null;
  periodEndsAt?: string;
  [key: string]: unknown;
}

/** failureReason written by functions/payments when Chapa initialize fails. */
export const CHECKOUT_INIT_FAILED = 'checkout_init_failed';

const STATUS_EVENT: Record<string, BookingEvent | undefined> = {
  confirmed: 'confirmed',
  cancelled: 'cancelled',
  inProgress: 'started',
  completed: 'completed',
  noShow: 'noShow',
};

/** True for the automatic cancel of a booking that lost a race for its slot. */
export function isSlotConflictCancel(booking: BookingDoc): boolean {
  return (
    booking.status === 'cancelled' &&
    booking.cancelledBy === SYSTEM_CANCEL &&
    booking.cancelReason === SLOT_CONFLICT_REASON
  );
}

/**
 * Status events only:
 * - create with status pending        -> 'created'
 * - create with status confirmed      -> 'confirmed' (auto-confirmed shops)
 * - update whose status changed to X  -> event for X (pending -> nothing);
 *   a system cancel for a slot conflict -> 'slotTaken' instead of 'cancelled'
 * - delete, or update without a status change (e.g. our own reminder flags,
 *   payment fields) -> null
 */
export function detectBookingEvent(
  before: BookingDoc | undefined | null,
  after: BookingDoc | undefined | null,
): BookingEvent | null {
  if (!after) return null;
  if (!before) {
    if (after.status === 'confirmed') return 'confirmed';
    if (after.status === 'pending' || after.status === undefined) return 'created';
    return null; // created already cancelled/completed: nothing useful to say
  }
  if (before.status === after.status) return null;
  const event = STATUS_EVENT[after.status ?? ''] ?? null;
  if (event === 'cancelled' && isSlotConflictCancel(after)) return 'slotTaken';
  return event;
}

/**
 * Payment events on a booking update: paymentStatus changed to 'paid' or
 * 'refunded'. pending/unpaid transitions are silent (a failed attempt is
 * reported from its payments/{id} document instead, once per attempt).
 */
export function detectBookingPaymentEvent(
  before: BookingDoc | undefined | null,
  after: BookingDoc | undefined | null,
): BookingPaymentEvent | null {
  if (!before || !after) return null;
  if (before.paymentStatus === after.paymentStatus) return null;
  if (after.paymentStatus === 'paid') return 'paymentReceived';
  if (after.paymentStatus === 'refunded') return 'paymentRefunded';
  return null;
}

function instantMs(value: unknown): number | null {
  if (typeof value !== 'string' || !value) return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : ms;
}

/**
 * A customer reschedule: the booking is still pending/confirmed and its
 * startAt moved. (The client writes startAt, endAt, date, timeSlot,
 * rescheduleCount + 1 and rescheduledAt in one transaction.)
 */
export function detectReschedule(
  before: BookingDoc | undefined | null,
  after: BookingDoc | undefined | null,
): 'rescheduled' | null {
  if (!before || !after) return null;
  if (after.status !== 'pending' && after.status !== 'confirmed') return null;
  const was = instantMs(before.startAt);
  const now = instantMs(after.startAt);
  if (was === null || now === null || was === now) return null;
  return 'rescheduled';
}

/**
 * Idempotency entity of a reschedule notification: one per reschedule, so
 * `{bookingId}_r{rescheduleCount}` (inbox `{bookingId}_r2_rescheduled`,
 * SMS log `{bookingId}_r2_rescheduled_sms`). Falls back to the new startAt
 * when the count is missing.
 */
export function rescheduleEntityId(bookingId: string, after: BookingDoc): string {
  const count = after.rescheduleCount;
  if (typeof count === 'number' && Number.isInteger(count) && count > 0) return `${bookingId}_r${count}`;
  return `${bookingId}_r${instantMs(after.startAt) ?? 0}`;
}

/**
 * Reminder flags set for the old time of a rescheduled booking (sent before
 * rescheduledAt, or any flag when rescheduledAt is unknown). The
 * notifications function deletes them so the new time gets its reminders.
 */
export function staleReminderFlags(after: BookingDoc): ('reminder24hSentAt' | 'reminder2hSentAt')[] {
  const movedAt = instantMs(after.rescheduledAt);
  const out: ('reminder24hSentAt' | 'reminder2hSentAt')[] = [];
  for (const flag of ['reminder24hSentAt', 'reminder2hSentAt'] as const) {
    const sentAt = after[flag];
    if (sentAt === undefined || sentAt === null) continue;
    const sentMs = instantMs(sentAt);
    if (movedAt === null || sentMs === null || sentMs <= movedAt) out.push(flag);
  }
  return out;
}

/**
 * Everything one booking write should notify about. Each event has its own
 * idempotency key, so a write that changes both status and paymentStatus
 * yields both; a paymentStatus-only write yields only the payment event.
 */
export function detectBookingEvents(
  before: BookingDoc | undefined | null,
  after: BookingDoc | undefined | null,
): (BookingEvent | BookingPaymentEvent)[] {
  const out: (BookingEvent | BookingPaymentEvent)[] = [];
  const status = detectBookingEvent(before, after);
  if (status) out.push(status);
  const moved = detectReschedule(before, after);
  if (moved) out.push(moved);
  const payment = detectBookingPaymentEvent(before, after);
  if (payment) out.push(payment);
  return out;
}

/**
 * Events on payments/{paymentId}:
 * - booking payment whose status changed to 'failed'       -> 'paymentFailed'
 * - subscription payment whose status changed to 'success' -> 'subscriptionPaid'
 * - subscription payment whose status changed to 'failed'  -> 'subscriptionFailed'
 * A booking payment's success is reported from the booking (paymentStatus
 * 'paid'), so it is ignored here.
 */
export function detectPaymentEvent(
  before: PaymentDoc | undefined | null,
  after: PaymentDoc | undefined | null,
): PaymentEvent | null {
  if (!after) return null;
  if (before && before.status === after.status) return null;
  // Chapa never opened a checkout (functions/payments bookingCheckout.ts):
  // no card was declined and the app already showed the callable's error.
  if (after.failureReason === CHECKOUT_INIT_FAILED) return null;
  if (after.type === 'booking') {
    return after.status === 'failed' ? 'paymentFailed' : null;
  }
  if (after.type === 'subscription') {
    if (after.status === 'success') return 'subscriptionPaid';
    if (after.status === 'failed') return 'subscriptionFailed';
  }
  return null;
}

const ACTOR_LITERALS: ReadonlySet<string> = new Set(['customer', 'barber', 'shop', 'admin', 'system']);

/** cancelledBy values that name a role rather than a uid. */
export function isCancelActorLiteral(by: unknown): by is Exclude<CancelActor, 'unknown'> {
  return typeof by === 'string' && ACTOR_LITERALS.has(by);
}

/**
 * Who cancelled. Uses `cancelledBy` (a uid, or a literal such as 'system')
 * compared against the people on the booking. `barberUids`/`ownerUid` are the
 * resolved accounts; `adminUids` is optional.
 */
export function deriveCancelActor(
  after: BookingDoc,
  people: { barberUids: string[]; ownerUid?: string | null; isAdmin?: (uid: string) => boolean },
): CancelActor {
  const by = after.cancelledBy;
  if (typeof by !== 'string' || by.length === 0) return 'unknown';
  if (isCancelActorLiteral(by)) return by;
  if (by === after.customerId) return 'customer';
  if (people.barberUids.includes(by)) return 'barber';
  if (people.ownerUid && by === people.ownerUid) return 'shop';
  if (people.isAdmin?.(by)) return 'admin';
  return 'unknown';
}

/**
 * SMS only for these (cost control). Booking events go to the customer;
 * subscriptionPaid goes to the shop owner.
 */
export const SMS_TYPES: ReadonlySet<NotificationType> = new Set<NotificationType>([
  'confirmed',
  'cancelled',
  'slotTaken',
  'rescheduled',
  'reminder24h',
  'reminder2h',
  'paymentReceived',
  'subscriptionPaid',
]);

export type RecipientRole = 'customer' | 'barber' | 'owner';

/** Who gets push + inbox for each type (before excluding the actor). */
export const RECIPIENT_ROLES: Record<NotificationType, readonly RecipientRole[]> = {
  created: ['customer', 'barber', 'owner'],
  confirmed: ['customer', 'barber', 'owner'],
  cancelled: ['customer', 'barber', 'owner'],
  started: ['customer', 'barber', 'owner'],
  completed: ['customer', 'barber', 'owner'],
  slotTaken: ['customer', 'barber', 'owner'],
  reminder24h: ['customer', 'barber', 'owner'],
  reminder2h: ['customer', 'barber', 'owner'],
  paymentReceived: ['customer', 'owner'],
  paymentRefunded: ['customer'],
  paymentFailed: ['customer'],
  subscriptionPaid: ['owner'],
  subscriptionFailed: ['owner'],
  // The customer moved it themselves; they still get the new time (and an SMS).
  rescheduled: ['customer', 'barber', 'owner'],
  // Inbox/push only, to the customer.
  noShow: ['customer'],
};

/** Who gets the SMS for a type, or null when the type has no SMS. */
export function smsRecipientRole(type: NotificationType): RecipientRole | null {
  if (!SMS_TYPES.has(type)) return null;
  return type === 'subscriptionPaid' ? 'owner' : 'customer';
}
