/**
 * Rebuilds a shop's stats, client docs and applied-state markers from all of
 * its bookings (admin backfill). Uses the same per-booking contribution as
 * the trigger, so a rebuild and the incremental path always agree.
 */
import {
  applyToClient,
  applyToStats,
  BookingData,
  ClientDoc,
  contributionOf,
  emptyStats,
  Marker,
  readClient,
  StatsDoc,
} from './stats';

export interface RebuildResult {
  stats: Map<string, StatsDoc>;
  clients: Map<string, ClientDoc>;
  markers: Map<string, Marker>;
}

export function rebuildShop(
  shopId: string,
  bookings: Iterable<{ id: string; data: BookingData }>,
  nowIso: string,
): RebuildResult {
  const stats = new Map<string, StatsDoc>();
  const clients = new Map<string, ClientDoc>();
  const markers = new Map<string, Marker>();
  // Oldest first, so the client's name and phone come from their latest booking.
  const ordered = [...bookings]
    .map(({ id, data }) => ({ id, c: contributionOf(data) }))
    .filter((e): e is { id: string; c: NonNullable<ReturnType<typeof contributionOf>> } => e.c !== null && e.c.shopId === shopId)
    .sort((a, b) => Date.parse(a.c.startAt) - Date.parse(b.c.startAt) || a.id.localeCompare(b.id));
  for (const { id, c } of ordered) {
    stats.set(c.month, applyToStats(stats.get(c.month) ?? emptyStats(c.month, nowIso), c, 1, nowIso));
    // Additions never make lastVisitAt stale.
    clients.set(c.customerId, applyToClient(clients.get(c.customerId) ?? readClient(null, c.customerId), c, 1).doc);
    markers.set(id, { shopId, contribution: c, updatedAt: nowIso });
  }
  return { stats, clients, markers };
}
