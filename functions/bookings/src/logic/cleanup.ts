/**
 * Expired slot-lock cleanup. Each lock carries `expiresAt` (its booking's
 * end plus one day, UTC ISO string); the daily job deletes locks whose
 * expiresAt is before now with a collection-group query on slotLocks,
 * page by page, up to a fixed number per run (the next run continues).
 */

/** Documents per query page and delete batch (a batch allows 500 writes). */
export const CLEANUP_PAGE_SIZE = 400;

/** Most locks deleted in one run. */
export const CLEANUP_MAX_PER_RUN = 10000;

export interface CleanupPorts<Ref> {
  /** Up to `limit` locks with expiresAt < `nowIso`, oldest first. */
  fetchExpired(nowIso: string, limit: number): Promise<Ref[]>;
  /** Deletes the given locks atomically. */
  deleteAll(refs: Ref[]): Promise<void>;
}

export interface CleanupResult {
  deleted: number;
  pages: number;
  /** True when the per-run cap stopped the sweep (more may be left). */
  capped: boolean;
}

export async function sweepExpiredLocks<Ref>(
  now: Date,
  ports: CleanupPorts<Ref>,
  opts: { pageSize?: number; maxPerRun?: number } = {},
): Promise<CleanupResult> {
  const pageSize = opts.pageSize ?? CLEANUP_PAGE_SIZE;
  const maxPerRun = opts.maxPerRun ?? CLEANUP_MAX_PER_RUN;
  const nowIso = now.toISOString();
  let deleted = 0;
  let pages = 0;
  while (deleted < maxPerRun) {
    const limit = Math.min(pageSize, maxPerRun - deleted);
    const refs = await ports.fetchExpired(nowIso, limit);
    if (refs.length === 0) return { deleted, pages, capped: false };
    await ports.deleteAll(refs);
    deleted += refs.length;
    pages += 1;
    // A short page means nothing else matched.
    if (refs.length < limit) return { deleted, pages, capped: false };
  }
  return { deleted, pages, capped: true };
}
