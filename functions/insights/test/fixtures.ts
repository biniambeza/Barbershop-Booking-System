import { BookingData } from '../src/logic/stats';

/** A booking in shop s1 by customer c1, 10:00 Addis on 2026-11-10. */
export function booking(extra: Partial<BookingData> = {}): BookingData {
  return {
    shopId: 's1',
    barberId: 'b1',
    barberName: 'Yonas',
    customerId: 'c1',
    customerName: 'Liya',
    customerPhone: '+251911000301',
    serviceId: 'srv1',
    serviceName: 'Fade',
    price: 350,
    status: 'confirmed',
    startAt: '2026-11-10T07:00:00.000Z',
    ...extra,
  };
}
