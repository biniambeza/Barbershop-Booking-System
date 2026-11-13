/**
 * Shop and barber ratings from barbershops/{shopId}/reviews/{bookingId}.
 * Only whole-star ratings 1..5 count.
 */

export interface ReviewData {
  barberId?: unknown;
  rating?: unknown;
}

export interface RatingSummary {
  /** Average rating rounded to one decimal; 0 when there are no reviews. */
  rating: number;
  reviewCount: number;
}

export const isValidRating = (v: unknown): v is number =>
  typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= 5;

export function summarizeRatings(ratings: unknown[]): RatingSummary {
  const valid = ratings.filter(isValidRating);
  if (valid.length === 0) return { rating: 0, reviewCount: 0 };
  const sum = valid.reduce((a, b) => a + b, 0);
  return { rating: Math.round((sum / valid.length) * 10) / 10, reviewCount: valid.length };
}

/** The shop summary plus one summary per barber in [barberIds]. */
export function summarizeShopReviews(
  reviews: ReviewData[],
  barberIds: Iterable<string>,
): { shop: RatingSummary; barbers: Map<string, RatingSummary> } {
  const barbers = new Map<string, RatingSummary>();
  for (const id of barberIds) {
    if (!id) continue;
    barbers.set(id, summarizeRatings(reviews.filter((r) => r.barberId === id).map((r) => r.rating)));
  }
  return { shop: summarizeRatings(reviews.map((r) => r.rating)), barbers };
}
