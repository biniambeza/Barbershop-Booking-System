/**
 * Ratings, the same model as lib/services/rating_service.dart (keep both in
 * line):
 *
 *  - Barber: barbershops/{s}/barbers/{b} keeps ratingSum and reviewCount.
 *    The customer's app changes them in the transaction that creates
 *    (+stars, +1), edits (+new - old) or deletes (-stars, -1) the review
 *    (firestore.rules checks the maths; see reviewCounterChange), so this
 *    codebase never touches the barber counters (no double counting). Each
 *    of those barber writes re-runs aggregateShopRating, so edits and
 *    deletes reach the cached shop rating like new reviews. Legacy docs
 *    without ratingSum use round(rating * reviewCount). Average =
 *    ratingSum / reviewCount, one decimal.
 *  - Shop: the average of its rated barbers' (unrounded) averages, barbers
 *    with reviewCount > 0 only, taken in barber id order, one decimal; no
 *    rated barber = 0 ("New" in the app). The cached shop fields are
 *    rating = that average and reviewCount = the rated barbers' reviews.
 */

export interface BarberRatingData {
  rating?: unknown;
  reviewCount?: unknown;
  ratingSum?: unknown;
}

export interface ShopRatingSummary {
  /** Average of the rated barbers' averages, one decimal; 0 when none. */
  rating: number;
  /** Reviews of the rated barbers together. */
  reviewCount: number;
  /** Barbers with at least one review. */
  ratedBarbers: number;
}

export const isValidRating = (v: unknown): v is number =>
  typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= 5;

const nonNegativeInt = (v: unknown): number =>
  typeof v === 'number' && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;

/** One decimal, half up (ratings are never negative); same epsilon as Dart. */
export const roundRating = (v: number): number => Math.round(v * 10 + 1e-9) / 10;

/** The barber's review count (0 when missing or invalid). */
export const barberReviewCount = (b: BarberRatingData): number => nonNegativeInt(b.reviewCount);

/** ratingSum, or round(rating * reviewCount) on legacy docs without it. */
export function barberRatingSum(b: BarberRatingData): number {
  const count = barberReviewCount(b);
  if (typeof b.ratingSum === 'number' && Number.isFinite(b.ratingSum)) return Math.max(0, Math.floor(b.ratingSum));
  if (count === 0) return 0;
  const legacy = typeof b.rating === 'number' && Number.isFinite(b.rating) ? b.rating : 0;
  return Math.round(legacy * count);
}

/** The barber's average, one decimal; 0 without reviews. */
export function barberAverage(b: BarberRatingData): number {
  const count = barberReviewCount(b);
  return count === 0 ? 0 : roundRating(barberRatingSum(b) / count);
}

/** The shop rating from its barbers ({ id, data }). */
export function summarizeShopFromBarbers(barbers: { id: string; data: BarberRatingData }[]): ShopRatingSummary {
  const rated = barbers
    .filter((b) => barberReviewCount(b.data) > 0)
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  if (rated.length === 0) return { rating: 0, reviewCount: 0, ratedBarbers: 0 };
  let sum = 0;
  let reviews = 0;
  for (const b of rated) {
    const count = barberReviewCount(b.data);
    sum += barberRatingSum(b.data) / count;
    reviews += count;
  }
  return { rating: roundRating(sum / rated.length), reviewCount: reviews, ratedBarbers: rated.length };
}

/**
 * Whether a barber write can change the shop rating: created, deleted, or
 * ratingSum / reviewCount / rating changed. Profile edits and availability
 * toggles are skipped.
 */
export function barberRatingChanged(before: BarberRatingData | undefined, after: BarberRatingData | undefined): boolean {
  if (!before || !after) return before !== after;
  return (
    before.ratingSum !== after.ratingSum || before.reviewCount !== after.reviewCount || before.rating !== after.rating
  );
}

export interface ReviewRatingData {
  rating?: unknown;
}

/**
 * How a review write changes its barber's counters (what the customer's app
 * writes, lib/services/rating_service.dart): created -> +stars, +1; edited
 * -> +(new - old), 0; deleted -> -stars, -1. Invalid ratings count as no
 * review.
 */
export function reviewCounterChange(
  before: ReviewRatingData | undefined,
  after: ReviewRatingData | undefined,
): { ratingSumDelta: number; reviewCountDelta: number } {
  const b = before && isValidRating(before.rating) ? before.rating : null;
  const a = after && isValidRating(after.rating) ? after.rating : null;
  return {
    ratingSumDelta: (a ?? 0) - (b ?? 0),
    reviewCountDelta: (a === null ? 0 : 1) - (b === null ? 0 : 1),
  };
}

/** The barber counters after [change] (legacy docs start from barberRatingSum). */
export function applyReviewCounterChange(
  barber: BarberRatingData,
  change: { ratingSumDelta: number; reviewCountDelta: number },
): { ratingSum: number; reviewCount: number } {
  return {
    ratingSum: barberRatingSum(barber) + change.ratingSumDelta,
    reviewCount: barberReviewCount(barber) + change.reviewCountDelta,
  };
}
