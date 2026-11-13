/** Daily sweep of expired emailCodes and authRateLimits documents. */
export const CLEANUP_COLLECTIONS = ['emailCodes', 'authRateLimits'] as const;
export type CleanupCollection = (typeof CLEANUP_COLLECTIONS)[number];

export interface CleanupPort<Ref> {
  fetchExpired(collection: CleanupCollection, nowIso: string, limit: number): Promise<Ref[]>;
  deleteAll(refs: Ref[]): Promise<void>;
}

export async function sweepExpired<Ref>(
  now: Date,
  port: CleanupPort<Ref>,
  pageSize = 400,
  maxPages = 50,
): Promise<Record<CleanupCollection, number>> {
  const nowIso = now.toISOString();
  const deleted = { emailCodes: 0, authRateLimits: 0 };
  for (const collection of CLEANUP_COLLECTIONS) {
    for (let page = 0; page < maxPages; page++) {
      const refs = await port.fetchExpired(collection, nowIso, pageSize);
      if (refs.length === 0) break;
      await port.deleteAll(refs);
      deleted[collection] += refs.length;
      if (refs.length < pageSize) break;
    }
  }
  return deleted;
}
