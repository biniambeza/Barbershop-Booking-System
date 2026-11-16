import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
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
