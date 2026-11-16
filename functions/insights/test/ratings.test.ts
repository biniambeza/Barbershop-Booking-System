import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  applyReviewCounterChange,
  reviewCounterChange,
  barberAverage,
  barberRatingChanged,
  barberRatingSum,
  isValidRating,
  roundRating,
  summarizeShopFromBarbers,
} from '../src/logic/ratings';

test('valid review ratings are whole stars 1..5', () => {
  assert.equal(isValidRating(5), true);
  assert.equal(isValidRating(1), true);
  assert.equal(isValidRating(3.5), false);
  assert.equal(isValidRating('5'), false);
  assert.equal(isValidRating(0), false);
  assert.equal(isValidRating(6), false);
});

test('rounding to one decimal, half up', () => {
  assert.equal(roundRating(4.25), 4.3);
  assert.equal(roundRating(4.24), 4.2);
  assert.equal(roundRating(13 / 3), 4.3);
  assert.equal(roundRating(0), 0);
});

test('barber average is ratingSum / reviewCount, legacy rating as fallback', () => {
  assert.equal(barberAverage({ ratingSum: 9, reviewCount: 2 }), 4.5);
  assert.equal(barberAverage({ ratingSum: 13, reviewCount: 3 }), 4.3);
  assert.equal(barberAverage({ ratingSum: 0, reviewCount: 0 }), 0);
  assert.equal(barberAverage({ rating: 5, reviewCount: 0 }), 0); // new barber, default rating
  // Legacy doc: ratingSum = round(rating * reviewCount).
  assert.equal(barberRatingSum({ rating: 3.5, reviewCount: 2 }), 7);
  assert.equal(barberRatingSum({ rating: 4.3, reviewCount: 3 }), 13);
  assert.equal(barberRatingSum({ rating: 4.3, reviewCount: 3, ratingSum: 12 }), 12); // ratingSum wins
  assert.equal(barberAverage({ rating: 4.8 }), 0);
});

test('shop rating is the average of the rated barbers\' averages', () => {
  const s = summarizeShopFromBarbers([
    { id: 'b2', data: { ratingSum: 7, reviewCount: 2 } }, // 3.5
    { id: 'b1', data: { ratingSum: 10, reviewCount: 2 } }, // 5
    { id: 'b3', data: { ratingSum: 4, reviewCount: 1 } }, // 4
    { id: 'b4', data: { rating: 5, reviewCount: 0 } }, // new: ignored
  ]);
  assert.deepEqual(s, { rating: 4.2, reviewCount: 5, ratedBarbers: 3 });
  // Not the average of all reviews: 5,5,5,5 (b1) and 1 (b2) -> 3 (not 4.2).
  assert.deepEqual(
    summarizeShopFromBarbers([
      { id: 'b1', data: { ratingSum: 20, reviewCount: 4 } },
      { id: 'b2', data: { ratingSum: 1, reviewCount: 1 } },
    ]),
    { rating: 3, reviewCount: 5, ratedBarbers: 2 },
  );
});

test('a shop without rated barbers is new', () => {
  assert.deepEqual(summarizeShopFromBarbers([]), { rating: 0, reviewCount: 0, ratedBarbers: 0 });
  assert.deepEqual(summarizeShopFromBarbers([{ id: 'b1', data: { rating: 5, reviewCount: 0 } }]), {
    rating: 0,
    reviewCount: 0,
    ratedBarbers: 0,
  });
});

test('only rating changes trigger a recompute; barber counters are never written here', () => {
  const b = { ratingSum: 9, reviewCount: 2, rating: 5 };
  assert.equal(barberRatingChanged(b, { ...b }), false);
  assert.equal(barberRatingChanged(b, { ...b, isAvailable: false } as typeof b), false);
  assert.equal(barberRatingChanged(b, { ...b, ratingSum: 13, reviewCount: 3 }), true);
  assert.equal(barberRatingChanged(undefined, b), true);
  assert.equal(barberRatingChanged(b, undefined), true);
  assert.equal(barberRatingChanged(undefined, undefined), false);
});

test('review create / edit / delete change the barber counters like the app', () => {
  assert.deepEqual(reviewCounterChange(undefined, { rating: 4 }), { ratingSumDelta: 4, reviewCountDelta: 1 });
  assert.deepEqual(reviewCounterChange({ rating: 4 }, { rating: 2 }), { ratingSumDelta: -2, reviewCountDelta: 0 });
  assert.deepEqual(reviewCounterChange({ rating: 3 }, { rating: 3 }), { ratingSumDelta: 0, reviewCountDelta: 0 });
  assert.deepEqual(reviewCounterChange({ rating: 5 }, undefined), { ratingSumDelta: -5, reviewCountDelta: -1 });
  assert.deepEqual(reviewCounterChange({ rating: 9 }, undefined), { ratingSumDelta: 0, reviewCountDelta: 0 });

  // b1: 5 + 4 (sum 9, 2 reviews); b2: one 2. Shop = (4.5 + 2) / 2 = 3.3.
  let b1 = { ratingSum: 9, reviewCount: 2 };
  const b2 = { ratingSum: 2, reviewCount: 1 };
  const shop = () =>
    summarizeShopFromBarbers([
      { id: 'b1', data: b1 },
      { id: 'b2', data: b2 },
    ]);
  assert.deepEqual(shop(), { rating: 3.3, reviewCount: 3, ratedBarbers: 2 });
  // The 4 is edited to 1: b1 = 6 / 2 = 3 -> shop (3 + 2) / 2 = 2.5.
  b1 = applyReviewCounterChange(b1, reviewCounterChange({ rating: 4 }, { rating: 1 }));
  assert.deepEqual(b1, { ratingSum: 6, reviewCount: 2 });
  assert.deepEqual(shop(), { rating: 2.5, reviewCount: 3, ratedBarbers: 2 });
  // The 5 is deleted: b1 = 1 / 1 -> shop (1 + 2) / 2 = 1.5.
  b1 = applyReviewCounterChange(b1, reviewCounterChange({ rating: 5 }, undefined));
  assert.deepEqual(b1, { ratingSum: 1, reviewCount: 1 });
  assert.deepEqual(shop(), { rating: 1.5, reviewCount: 2, ratedBarbers: 2 });
  // The last one is deleted: b1 drops out of the shop average.
  b1 = applyReviewCounterChange(b1, reviewCounterChange({ rating: 1 }, undefined));
  assert.deepEqual(shop(), { rating: 2, reviewCount: 1, ratedBarbers: 1 });
  assert.equal(barberRatingChanged({ ratingSum: 9, reviewCount: 2 }, { ratingSum: 6, reviewCount: 2 }), true);
  // Legacy doc (no ratingSum): 3.5 x 2 = 7, minus a deleted 4.
  assert.deepEqual(applyReviewCounterChange({ rating: 3.5, reviewCount: 2 }, { ratingSumDelta: -4, reviewCountDelta: -1 }), {
    ratingSum: 3,
    reviewCount: 1,
  });
});
