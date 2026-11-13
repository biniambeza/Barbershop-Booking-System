import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isValidRating, summarizeRatings, summarizeShopReviews } from '../src/logic/ratings';

test('average rounded to one decimal', () => {
  assert.deepEqual(summarizeRatings([5, 4, 4]), { rating: 4.3, reviewCount: 3 });
  assert.deepEqual(summarizeRatings([5, 4]), { rating: 4.5, reviewCount: 2 });
  assert.deepEqual(summarizeRatings([1]), { rating: 1, reviewCount: 1 });
});

test('no reviews', () => {
  assert.deepEqual(summarizeRatings([]), { rating: 0, reviewCount: 0 });
});

test('invalid ratings are ignored', () => {
  assert.equal(isValidRating(3.5), false);
  assert.equal(isValidRating('5'), false);
  assert.equal(isValidRating(0), false);
  assert.equal(isValidRating(6), false);
  assert.deepEqual(summarizeRatings([5, 0, 6, 'x', null, 3]), { rating: 4, reviewCount: 2 });
});

test('shop and barber summaries', () => {
  const reviews = [
    { barberId: 'b1', rating: 5 },
    { barberId: 'b1', rating: 4 },
    { barberId: 'b2', rating: 2 },
  ];
  const s = summarizeShopReviews(reviews, ['b1', 'b2', 'b3', '']);
  assert.deepEqual(s.shop, { rating: 3.7, reviewCount: 3 });
  assert.deepEqual(s.barbers.get('b1'), { rating: 4.5, reviewCount: 2 });
  assert.deepEqual(s.barbers.get('b2'), { rating: 2, reviewCount: 1 });
  assert.deepEqual(s.barbers.get('b3'), { rating: 0, reviewCount: 0 });
  assert.equal(s.barbers.has(''), false);
});
