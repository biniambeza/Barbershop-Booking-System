/**
 * Shop deletion cascade, server side (Blaze only). Mirrors the admin app's
 * cascade in lib/services/shop_deletion.dart, which does the same work from
 * the client on the free Spark plan; this runs again when
 * barbershops/{shopId} is deleted, so everything here is idempotent:
 *
 *  1. upcoming bookings (pending/confirmed, startAt >= now) -> cancelled
 *     {status:'cancelled', cancelledBy:'system', cancelReason:'shop_deleted'}
 *     and the customer gets users/{uid}/notifications/{bookingId}_shopDeleted;
 *  2. owner and barbers (users with shopId == id, plus shopDeletions
 *     staffUids still pointing at the shop) -> role 'customer' without
 *     shopId/barberId, with users/{uid}/notifications/shopRemoved_{shopId};
 *  3. every invites/{email} of the shop deleted;
 *  4. the shop's subcollections deleted (recursive delete of the shop path);
 *  5. Auth logins the owner created for barbers deleted (with their profile):
 *     only accounts that are password-only and whose email is NOT verified
 *     (owner-created staff accounts never verify an email); Google accounts
 *     and self-registered (verified) accounts are kept as customers.
 *
 * Pure logic over a small store interface (unit tested without Firebase).
 */

/** Same value as kShopDeletedCancelReason in lib/services/shop_deletion.dart. */
export const SHOP_DELETED_REASON = 'shop_deleted';
export const SHOP_DELETIONS_COLLECTION = 'shopDeletions';

/** Bookings per batch (2 writes each: well under 500). */
export const BOOKING_BATCH = 200;
/** Users per batch (2 writes each). */
export const STAFF_BATCH = 200;

const ADDIS_OFFSET_MS = 3 * 60 * 60 * 1000;

export interface BookingRow {
  id: string;
  status?: string;
  startAt?: string;
  customerId?: string;
  shopId?: string;
  shopName?: string;
}

export interface UserRow {
  uid: string;
  role?: string;
  shopId?: string;
  language?: string;
}

export interface InviteRow {
  email: string;
  role?: string;
  authUid?: string;
}

export interface AuthAccount {
  uid: string;
  emailVerified: boolean;
  providerIds: string[];
}

export interface DeletionRecord {
  shopName?: string;
  staffUids?: string[];
  barberAccountUids?: string[];
}

/** users/{uid}/notifications/{id}: same keys as ShopDeletionNotice.toMap. */
export interface NoticeDoc {
  type: 'shopDeleted' | 'shopRemoved';
  title: string;
  body: string;
  shopId: string;
  bookingId?: string;
  read: false;
  createdAt: string;
}

export interface Notice {
  uid: string;
  id: string;
  doc: NoticeDoc;
}

export interface ShopDeletionStore {
  getRecord(shopId: string): Promise<DeletionRecord | null>;
  /** bookings where shopId == shopId and startAt >= nowIso. */
  upcomingBookings(shopId: string, nowIso: string): Promise<BookingRow[]>;
  /** One batch: update each booking to the cancel fields, set each notice. */
  cancelBookings(items: { bookingId: string; notice: Notice }[]): Promise<void>;
  usersOfShop(shopId: string): Promise<UserRow[]>;
  getUsers(uids: string[]): Promise<UserRow[]>;
  /** One batch: role 'customer', shopId/barberId deleted, notice set. */
  downgrade(items: { uid: string; notice: Notice }[]): Promise<void>;
  invitesOfShop(shopId: string): Promise<InviteRow[]>;
  deleteInvites(emails: string[]): Promise<void>;
  /** Deletes every subcollection document under barbershops/{shopId}. */
  deleteShopTree(shopId: string): Promise<void>;
  getAuthAccount(uid: string): Promise<AuthAccount | null>;
  deleteAuthAccount(uid: string): Promise<void>;
  /** Deletes users/{uid} and its subcollections. */
  deleteUserProfile(uid: string): Promise<void>;
  markDone(shopId: string, result: ShopDeletionResult, nowIso: string): Promise<void>;
}

export interface ShopDeletionResult {
  cancelledBookings: number;
  downgradedStaff: number;
  deletedInvites: number;
  deletedLogins: string[];
}

const two = (n: number) => String(n).padStart(2, '0');

function addisWhen(startAtIso: string): string {
  const t = new Date(new Date(startAtIso).getTime() + ADDIS_OFFSET_MS);
  return `${two(t.getUTCDate())}/${two(t.getUTCMonth() + 1)}/${t.getUTCFullYear()} ${two(t.getUTCHours())}:${two(t.getUTCMinutes())}`;
}

/** Same copy as renderShopDeletedText in lib/services/shop_deletion.dart. */
export function shopDeletedText(startAtIso: string, shopName: string | undefined, language?: string): { title: string; body: string } {
  const when = addisWhen(startAtIso);
  const shop = shopName && shopName.trim() !== '' ? shopName.trim() : null;
  if (language === 'en') {
    return {
      title: 'Appointment cancelled',
      body: `${shop ?? 'Your barbershop'} is no longer on Crown & Blade, so your appointment on ${when} was cancelled. Please book at another barbershop.`,
    };
  }
  return {
    title: 'ቀጠሮዎ ተሰርዟል',
    body: `${shop ?? 'ፀጉር ቤቱ'} ከCrown & Blade ስለተወገደ በ${when} የነበረዎት ቀጠሮ ተሰርዟል። እባክዎ በሌላ ፀጉር ቤት ቀጠሮ ይያዙ።`,
  };
}

/** Same copy as renderShopRemovedText in lib/services/shop_deletion.dart. */
export function shopRemovedText(shopName: string | undefined, language?: string): { title: string; body: string } {
  const shop = shopName && shopName.trim() !== '' ? shopName.trim() : null;
  if (language === 'en') {
    return {
      title: 'Your barbershop was removed',
      body: `${shop ?? 'Your barbershop'} was removed from Crown & Blade. You can keep using the app as a customer.`,
    };
  }
  return {
    title: 'ፀጉር ቤትዎ ተወግዷል',
    body: `${shop ?? 'ፀጉር ቤትዎ'} ከCrown & Blade ተወግዷል። መተግበሪያውን እንደ ደንበኛ መጠቀም ይችላሉ።`,
  };
}

export const isStaffRole = (role: string | undefined) => role === 'barbershopOwner' || role === 'barber';

/** Whether [booking] is cancelled by the deletion (pending/confirmed, not started). */
export function isUpcomingActive(booking: BookingRow, shopId: string, nowIso: string): boolean {
  return (
    booking.shopId === shopId &&
    (booking.status === 'pending' || booking.status === 'confirmed') &&
    typeof booking.startAt === 'string' &&
    new Date(booking.startAt).getTime() >= new Date(nowIso).getTime() &&
    typeof booking.customerId === 'string' &&
    booking.customerId !== ''
  );
}

/** An owner-created staff login: password only, email never verified. */
export function isOwnerCreatedLogin(account: AuthAccount): boolean {
  return !account.emailVerified && account.providerIds.length > 0 && account.providerIds.every((p) => p === 'password');
}

function chunks<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** Runs the whole cascade for [shopId] (safe to run any number of times). */
export async function cascadeShopDeletion(
  shopId: string,
  shopNameFromDoc: string | undefined,
  store: ShopDeletionStore,
  now: Date,
): Promise<ShopDeletionResult> {
  const nowIso = now.toISOString();
  const record = await store.getRecord(shopId);
  const shopName = shopNameFromDoc ?? record?.shopName ?? '';

  // Staff: current members plus the record's (already downgraded ones are skipped).
  const byUid = new Map<string, UserRow>();
  for (const u of await store.usersOfShop(shopId)) byUid.set(u.uid, u);
  const recordStaff = (record?.staffUids ?? []).filter((uid) => !byUid.has(uid));
  if (recordStaff.length > 0) for (const u of await store.getUsers(recordStaff)) byUid.set(u.uid, u);
  const languages = new Map<string, string | undefined>();

  // 1. Bookings.
  const bookings = (await store.upcomingBookings(shopId, nowIso))
    .filter((b) => isUpcomingActive(b, shopId, nowIso))
    .sort((a, b) => (a.startAt! < b.startAt! ? -1 : 1));
  const customerUids = [...new Set(bookings.map((b) => b.customerId!))];
  if (customerUids.length > 0) for (const u of await store.getUsers(customerUids)) languages.set(u.uid, u.language);
  const cancellations = bookings.map((b) => {
    const text = shopDeletedText(b.startAt!, b.shopName || shopName, languages.get(b.customerId!));
    const id = `${b.id}_shopDeleted`;
    return {
      bookingId: b.id,
      notice: {
        uid: b.customerId!,
        id,
        doc: { type: 'shopDeleted', title: text.title, body: text.body, shopId, bookingId: b.id, read: false, createdAt: nowIso } as NoticeDoc,
      },
    };
  });
  for (const chunk of chunks(cancellations, BOOKING_BATCH)) await store.cancelBookings(chunk);

  // 2. Staff -> customers.
  const staff = [...byUid.values()].filter((u) => u.shopId === shopId && isStaffRole(u.role));
  const downgrades = staff.map((u) => {
    const text = shopRemovedText(shopName, u.language);
    return {
      uid: u.uid,
      notice: {
        uid: u.uid,
        id: `shopRemoved_${shopId}`,
        doc: { type: 'shopRemoved', title: text.title, body: text.body, shopId, read: false, createdAt: nowIso } as NoticeDoc,
      },
    };
  });
  for (const chunk of chunks(downgrades, STAFF_BATCH)) await store.downgrade(chunk);

  // 3. Invites (pending barber invites may carry the uid of an owner-created login).
  const invites = await store.invitesOfShop(shopId);
  if (invites.length > 0) await store.deleteInvites(invites.map((i) => i.email));

  // 4. Subcollections.
  await store.deleteShopTree(shopId);

  // 5. Owner-created barber logins.
  const candidates = new Set<string>([
    ...(record?.barberAccountUids ?? []),
    ...invites.filter((i) => i.role === 'barber' && i.authUid).map((i) => i.authUid!),
    ...[...byUid.values()].filter((u) => u.role === 'barber').map((u) => u.uid),
  ]);
  const deletedLogins: string[] = [];
  for (const uid of candidates) {
    const account = await store.getAuthAccount(uid);
    if (!account || !isOwnerCreatedLogin(account)) continue;
    await store.deleteUserProfile(uid);
    await store.deleteAuthAccount(uid);
    deletedLogins.push(uid);
  }

  const result: ShopDeletionResult = {
    cancelledBookings: cancellations.length,
    downgradedStaff: downgrades.length,
    deletedInvites: invites.length,
    deletedLogins,
  };
  await store.markDone(shopId, result, nowIso);
  return result;
}
