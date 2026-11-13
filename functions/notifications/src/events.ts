/**
 * Pure event detection for booking documents: given the document before and
 * after a write, which notification event (if any) happened.
 */

export type BookingStatus = 'pending' | 'confirmed' | 'inProgress' | 'completed' | 'cancelled';

export type BookingEvent = 'created' | 'confirmed' | 'cancelled' | 'started' | 'completed';
export type NotificationType = BookingEvent | 'reminder24h' | 'reminder2h';

/** Who cancelled, as far as we can tell. */
export type CancelActor = 'customer' | 'barber' | 'shop' | 'admin' | 'unknown';

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
  createdAt?: string;
  /** Optional: uid of the user who cancelled (written by the client on cancel). */
  cancelledBy?: string;
  reminder24hSentAt?: string;
  reminder2hSentAt?: string;
  [key: string]: unknown;
}

const STATUS_EVENT: Record<string, BookingEvent | undefined> = {
  confirmed: 'confirmed',
  cancelled: 'cancelled',
  inProgress: 'started',
  completed: 'completed',
};

/**
 * - create with status pending        -> 'created'
 * - create with status confirmed      -> 'confirmed' (auto-confirmed shops)
 * - update whose status changed to X  -> event for X (pending -> nothing)
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
  return STATUS_EVENT[after.status ?? ''] ?? null;
}

/**
 * Who cancelled. Uses `cancelledBy` (a uid) when the client wrote one,
 * compared against the people on the booking. `barberUids`/`ownerUid` are the
 * resolved accounts; `adminUids` is optional.
 */
export function deriveCancelActor(
  after: BookingDoc,
  people: { barberUids: string[]; ownerUid?: string | null; isAdmin?: (uid: string) => boolean },
): CancelActor {
  const by = after.cancelledBy;
  if (typeof by !== 'string' || by.length === 0) return 'unknown';
  if (by === 'customer' || by === 'barber' || by === 'shop' || by === 'admin') return by;
  if (by === after.customerId) return 'customer';
  if (people.barberUids.includes(by)) return 'barber';
  if (people.ownerUid && by === people.ownerUid) return 'shop';
  if (people.isAdmin?.(by)) return 'admin';
  return 'unknown';
}

/** SMS goes to the customer only, and only for these (cost control). */
export const SMS_TYPES: ReadonlySet<NotificationType> = new Set<NotificationType>([
  'confirmed',
  'cancelled',
  'reminder24h',
  'reminder2h',
]);
