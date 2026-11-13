/** Who may pay for what. Pure checks over Firestore document data. */

export type Denial = {
  code: 'permission-denied' | 'failed-precondition' | 'not-found' | 'already-exists' | 'invalid-argument';
  message: string;
};

export interface BookingData {
  customerId?: unknown;
  status?: unknown;
  paymentStatus?: unknown;
  price?: unknown;
  shopId?: unknown;
}

export function checkBookingPayable(booking: BookingData | undefined, uid: string): Denial | null {
  if (!booking) return { code: 'not-found', message: 'Booking not found.' };
  if (booking.customerId !== uid) {
    return { code: 'permission-denied', message: 'Only the customer who made this booking can pay for it.' };
  }
  if (booking.status === 'cancelled') {
    return { code: 'failed-precondition', message: 'This booking was cancelled.' };
  }
  const ps = booking.paymentStatus ?? 'unpaid';
  if (ps === 'paid') return { code: 'already-exists', message: 'This booking is already paid.' };
  if (ps === 'refunded') return { code: 'failed-precondition', message: 'This booking was refunded.' };
  if (ps !== 'unpaid' && ps !== 'pending') {
    return { code: 'failed-precondition', message: 'This booking cannot be paid online.' };
  }
  return null;
}

export interface UserData {
  role?: unknown;
  shopId?: unknown;
}

export interface ShopData {
  ownerId?: unknown;
}

export function checkShopOwner(
  user: UserData | undefined,
  shop: ShopData | undefined,
  uid: string,
  shopId: string,
): Denial | null {
  if (!user || user.role !== 'barbershopOwner' || user.shopId !== shopId) {
    return { code: 'permission-denied', message: 'Only the owner of this shop can pay its subscription.' };
  }
  if (!shop) return { code: 'not-found', message: 'Shop not found.' };
  if (shop.ownerId !== uid) {
    return { code: 'permission-denied', message: 'Only the owner of this shop can pay its subscription.' };
  }
  return null;
}

/** maxBarbers < 0 means unlimited. */
export function checkPlanFitsShop(maxBarbers: unknown, barberCount: number): Denial | null {
  if (typeof maxBarbers !== 'number' || maxBarbers < 0) return null;
  if (barberCount > maxBarbers) {
    return {
      code: 'failed-precondition',
      message: `This plan allows ${maxBarbers} barbers but the shop has ${barberCount}. Choose a bigger plan or remove barbers.`,
    };
  }
  return null;
}
