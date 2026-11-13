/**
 * Monthly shop stats and per-shop client history, maintained from bookings.
 *
 * Every booking contributes to exactly one month doc
 * (barbershops/{shopId}/stats/{yyyy-MM}, the Addis month of startAt) and one
 * client doc (barbershops/{shopId}/clients/{customerId}). The contribution
 * that is currently counted is remembered in insightsApplied/{bookingId}
 * (functions only; never on the booking, which clients write and the rules
 * validate). On every booking write the function reads the booking as it is
 * NOW, subtracts the remembered contribution, adds the current one and stores
 * the new one, all in one transaction. That makes the trigger:
 *  - correct for create, status changes (old -> new), reschedules into
 *    another month and deletes;
 *  - idempotent under retries and duplicate deliveries (a second run finds
 *    the marker equal to the booking and writes nothing);
 *  - independent of event order (it never trusts the event's before/after).
 */

import { addisMonthKey } from './time';

/** The booking fields the aggregation reads (bookings/{bookingId}). */
export interface BookingData {
  shopId?: unknown;
  barberId?: unknown;
  barberName?: unknown;
  customerId?: unknown;
  customerName?: unknown;
  customerPhone?: unknown;
  serviceId?: unknown;
  serviceName?: unknown;
  price?: unknown;
  status?: unknown;
  startAt?: unknown;
  cancelledBy?: unknown;
  cancelReason?: unknown;
}

/** What one booking adds to its month and client docs. */
export interface Contribution {
  shopId: string;
  month: string;
  startAt: string;
  status: string;
  customerId: string;
  customerName: string;
  customerPhone: string;
  serviceId: string;
  serviceName: string;
  barberId: string;
  barberName: string;
  bookings: number;
  completed: number;
  cancelled: number;
  noShows: number;
  revenueEtb: number;
}

export interface ServiceStat {
  name: string;
  /** Completed bookings of this service. */
  count: number;
  revenueEtb: number;
}

export interface BarberStat {
  name: string;
  completed: number;
  revenueEtb: number;
}

/** barbershops/{shopId}/stats/{yyyy-MM}. */
export interface StatsDoc {
  month: string;
  bookings: number;
  completed: number;
  cancelled: number;
  noShows: number;
  /** Sum of the prices of completed bookings, ETB. */
  revenueEtb: number;
  byService: Record<string, ServiceStat>;
  byBarber: Record<string, BarberStat>;
  updatedAt: string;
}

/** barbershops/{shopId}/clients/{customerId}. */
export interface ClientDoc {
  customerId: string;
  name: string;
  phone: string;
  completedCount: number;
  noShowCount: number;
  cancelledCount: number;
  /** startAt (UTC ISO) of the latest completed booking, or null. */
  lastVisitAt: string | null;
}

/** insightsApplied/{bookingId}: the contribution currently counted. */
export interface Marker {
  shopId: string;
  contribution: Contribution;
  updatedAt: string;
}

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const num = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

/** Rounds an ETB amount to cents (avoids float drift from +/- updates). */
export const roundEtb = (v: number): number => Math.round(v * 100) / 100;

/**
 * What [booking] contributes, or null when it counts for nothing: missing
 * booking, missing shop / customer / start time, or a booking the system
 * cancelled because it lost a slot race (it never really existed).
 */
export function contributionOf(booking: BookingData | null | undefined): Contribution | null {
  if (!booking) return null;
  const shopId = str(booking.shopId);
  const customerId = str(booking.customerId);
  const startAt = str(booking.startAt);
  const month = addisMonthKey(startAt);
  if (!shopId || !customerId || !month) return null;
  const status = str(booking.status) || 'pending';
  if (status === 'cancelled' && booking.cancelledBy === 'system' && booking.cancelReason === 'slot_conflict') {
    return null;
  }
  const completed = status === 'completed' ? 1 : 0;
  return {
    shopId,
    month,
    startAt,
    status,
    customerId,
    customerName: str(booking.customerName),
    customerPhone: str(booking.customerPhone),
    serviceId: str(booking.serviceId),
    serviceName: str(booking.serviceName),
    barberId: str(booking.barberId),
    barberName: str(booking.barberName),
    bookings: 1,
    completed,
    cancelled: status === 'cancelled' ? 1 : 0,
    noShows: status === 'noShow' ? 1 : 0,
    revenueEtb: completed ? roundEtb(Math.max(0, num(booking.price))) : 0,
  };
}

/** True when two contributions would write exactly the same counts. */
export function sameContribution(a: Contribution | null, b: Contribution | null): boolean {
  if (a === null || b === null) return a === b;
  const keys = Object.keys(a) as (keyof Contribution)[];
  return keys.every((k) => a[k] === b[k]) && Object.keys(b).length === keys.length;
}

export function emptyStats(month: string, nowIso: string): StatsDoc {
  return {
    month,
    bookings: 0,
    completed: 0,
    cancelled: 0,
    noShows: 0,
    revenueEtb: 0,
    byService: {},
    byBarber: {},
    updatedAt: nowIso,
  };
}

/** Normalizes a stored stats doc (missing or malformed fields become 0). */
export function readStats(raw: Record<string, unknown> | null | undefined, month: string, nowIso: string): StatsDoc {
  const doc = emptyStats(month, nowIso);
  if (!raw) return doc;
  doc.bookings = num(raw.bookings);
  doc.completed = num(raw.completed);
  doc.cancelled = num(raw.cancelled);
  doc.noShows = num(raw.noShows);
  doc.revenueEtb = num(raw.revenueEtb);
  const services = (raw.byService ?? {}) as Record<string, Record<string, unknown>>;
  for (const [id, s] of Object.entries(services)) {
    if (s && typeof s === 'object') doc.byService[id] = { name: str(s.name), count: num(s.count), revenueEtb: num(s.revenueEtb) };
  }
  const barbers = (raw.byBarber ?? {}) as Record<string, Record<string, unknown>>;
  for (const [id, b] of Object.entries(barbers)) {
    if (b && typeof b === 'object') doc.byBarber[id] = { name: str(b.name), completed: num(b.completed), revenueEtb: num(b.revenueEtb) };
  }
  return doc;
}

/** Normalizes a stored client doc. */
export function readClient(raw: Record<string, unknown> | null | undefined, customerId: string): ClientDoc {
  return {
    customerId,
    name: str(raw?.name),
    phone: str(raw?.phone),
    completedCount: num(raw?.completedCount),
    noShowCount: num(raw?.noShowCount),
    cancelledCount: num(raw?.cancelledCount),
    lastVisitAt: typeof raw?.lastVisitAt === 'string' ? (raw.lastVisitAt as string) : null,
  };
}

const clamp = (v: number): number => Math.max(0, v);

/**
 * Adds (sign 1) or removes (sign -1) [c] to/from a month doc. Returns a new
 * doc; counters never go below 0, and per-service / per-barber entries that
 * drop to zero are removed.
 */
export function applyToStats(doc: StatsDoc, c: Contribution, sign: 1 | -1, nowIso: string): StatsDoc {
  const next: StatsDoc = {
    ...doc,
    bookings: clamp(doc.bookings + sign * c.bookings),
    completed: clamp(doc.completed + sign * c.completed),
    cancelled: clamp(doc.cancelled + sign * c.cancelled),
    noShows: clamp(doc.noShows + sign * c.noShows),
    revenueEtb: clamp(roundEtb(doc.revenueEtb + sign * c.revenueEtb)),
    byService: { ...doc.byService },
    byBarber: { ...doc.byBarber },
    updatedAt: nowIso,
  };
  if (c.completed && c.serviceId) {
    const prev = next.byService[c.serviceId] ?? { name: c.serviceName, count: 0, revenueEtb: 0 };
    const entry: ServiceStat = {
      name: sign > 0 && c.serviceName ? c.serviceName : prev.name,
      count: clamp(prev.count + sign * c.completed),
      revenueEtb: clamp(roundEtb(prev.revenueEtb + sign * c.revenueEtb)),
    };
    if (entry.count === 0 && entry.revenueEtb === 0) delete next.byService[c.serviceId];
    else next.byService[c.serviceId] = entry;
  }
  if (c.completed && c.barberId) {
    const prev = next.byBarber[c.barberId] ?? { name: c.barberName, completed: 0, revenueEtb: 0 };
    const entry: BarberStat = {
      name: sign > 0 && c.barberName ? c.barberName : prev.name,
      completed: clamp(prev.completed + sign * c.completed),
      revenueEtb: clamp(roundEtb(prev.revenueEtb + sign * c.revenueEtb)),
    };
    if (entry.completed === 0 && entry.revenueEtb === 0) delete next.byBarber[c.barberId];
    else next.byBarber[c.barberId] = entry;
  }
  return next;
}

/**
 * Adds or removes [c] to/from a client doc. `lastVisitStale` is true when a
 * completed visit equal to the stored lastVisitAt was removed: the caller
 * must then look up the latest remaining completed booking.
 */
export function applyToClient(doc: ClientDoc, c: Contribution, sign: 1 | -1): { doc: ClientDoc; lastVisitStale: boolean } {
  const next: ClientDoc = {
    ...doc,
    completedCount: clamp(doc.completedCount + sign * c.completed),
    noShowCount: clamp(doc.noShowCount + sign * c.noShows),
    cancelledCount: clamp(doc.cancelledCount + sign * c.cancelled),
  };
  let lastVisitStale = false;
  if (sign > 0) {
    if (c.customerName) next.name = c.customerName;
    if (c.customerPhone) next.phone = c.customerPhone;
    if (c.completed && (next.lastVisitAt === null || Date.parse(c.startAt) > Date.parse(next.lastVisitAt))) {
      next.lastVisitAt = c.startAt;
    }
  } else if (c.completed && next.lastVisitAt !== null && Date.parse(c.startAt) >= Date.parse(next.lastVisitAt)) {
    lastVisitStale = true;
  }
  return { doc: next, lastVisitStale };
}

/** Transaction port for [aggregateBookingInTx]: all reads come before writes. */
export interface AggregateTx {
  getBooking(): Promise<BookingData | null>;
  getMarker(): Promise<Marker | null>;
  getStats(shopId: string, month: string): Promise<Record<string, unknown> | null>;
  getClient(shopId: string, customerId: string): Promise<Record<string, unknown> | null>;
  /** startAt of the customer's latest completed booking in the shop, or null. */
  latestCompletedVisit(shopId: string, customerId: string): Promise<string | null>;
  setStats(shopId: string, month: string, doc: StatsDoc): void;
  setClient(shopId: string, customerId: string, doc: ClientDoc): void;
  setMarker(marker: Marker): void;
  deleteMarker(): void;
}

export type AggregateOutcome =
  | { result: 'unchanged' }
  | { result: 'applied'; months: string[]; clients: string[] };

/**
 * Brings the stats and client docs in line with the booking's current state
 * (see the file comment). Reads first, then writes.
 */
export async function aggregateBookingInTx(tx: AggregateTx, nowIso: string): Promise<AggregateOutcome> {
  const booking = await tx.getBooking();
  const marker = await tx.getMarker();
  const oldC = marker?.contribution ?? null;
  const newC = contributionOf(booking);
  if (sameContribution(oldC, newC)) return { result: 'unchanged' };

  // Reads: every touched month and client doc.
  const statsKey = (c: Contribution) => `${c.shopId}/${c.month}`;
  const clientKey = (c: Contribution) => `${c.shopId}/${c.customerId}`;
  const stats = new Map<string, StatsDoc>();
  const clients = new Map<string, ClientDoc>();
  for (const c of [oldC, newC]) {
    if (!c) continue;
    if (!stats.has(statsKey(c))) stats.set(statsKey(c), readStats(await tx.getStats(c.shopId, c.month), c.month, nowIso));
    if (!clients.has(clientKey(c))) clients.set(clientKey(c), readClient(await tx.getClient(c.shopId, c.customerId), c.customerId));
  }

  const staleClients = new Set<string>();
  if (oldC) {
    stats.set(statsKey(oldC), applyToStats(stats.get(statsKey(oldC))!, oldC, -1, nowIso));
    const r = applyToClient(clients.get(clientKey(oldC))!, oldC, -1);
    clients.set(clientKey(oldC), r.doc);
    if (r.lastVisitStale) staleClients.add(clientKey(oldC));
  }
  if (newC) {
    stats.set(statsKey(newC), applyToStats(stats.get(statsKey(newC))!, newC, 1, nowIso));
    const before = clients.get(clientKey(newC))!;
    const r = applyToClient(before, newC, 1);
    clients.set(clientKey(newC), r.doc);
    // Re-adding a visit at least as recent as the removed one settles lastVisitAt.
    if (staleClients.has(clientKey(newC)) && newC.completed && oldC && Date.parse(newC.startAt) >= Date.parse(oldC.startAt)) {
      staleClients.delete(clientKey(newC));
      r.doc.lastVisitAt = newC.startAt;
    }
  }
  for (const key of staleClients) {
    const [shopId, customerId] = key.split('/');
    const doc = clients.get(key)!;
    doc.lastVisitAt = await tx.latestCompletedVisit(shopId, customerId);
  }

  // Writes.
  for (const [key, doc] of stats) tx.setStats(key.split('/')[0], doc.month, doc);
  for (const [key, doc] of clients) tx.setClient(key.split('/')[0], doc.customerId, doc);
  if (newC) tx.setMarker({ shopId: newC.shopId, contribution: newC, updatedAt: nowIso });
  else tx.deleteMarker();
  return {
    result: 'applied',
    months: [...stats.values()].map((s) => s.month),
    clients: [...clients.values()].map((c) => c.customerId),
  };
}
