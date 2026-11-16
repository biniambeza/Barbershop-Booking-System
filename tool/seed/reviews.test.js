'use strict';
// node --test: seeded reviews resolve like lib/services/reviews_service.dart
// (reviewsFromSeedJson) and the seeded barber counters (ratingSum,
// reviewCount) and shop ratings (average of the rated barbers' averages,
// lib/services/rating_service.dart) match them.
const test = require('node:test');
const assert = require('node:assert');
const { buildDocuments } = require('./seed.js');
const seed = require('../../assets/seed/addis_seed.json');

const now = new Date(Date.UTC(2026, 10, 20, 7, 0)); // 10:00 in Addis
const get = (docs, p) => docs.find((d) => d.path === p)?.data;

const summarize = (ratings) => {
  const valid = ratings.filter((r) => Number.isInteger(r) && r >= 1 && r <= 5);
  if (valid.length === 0) return { rating: 0, reviewCount: 0 };
  return { rating: Math.round((valid.reduce((a, b) => a + b, 0) / valid.length) * 10) / 10, reviewCount: valid.length };
};

test('reviews are written for completed bookings with the contract fields', () => {
  const docs = buildDocuments(seed, { now });
  const reviews = docs.filter((d) => /^barbershops\/[^/]+\/reviews\/[^/]+$/.test(d.path));
  assert.strictEqual(reviews.length, seed.reviews.filter((r) => r.bookingId).length);
  const allowed = ['bookingId', 'shopId', 'barberId', 'customerId', 'customerName', 'rating', 'comment', 'createdAt', 'reply', 'replyAt'];
  for (const r of reviews) {
    const id = r.path.split('/').pop();
    const booking = get(docs, `bookings/${id}`);
    assert.strictEqual(booking.status, 'completed', id);
    assert.strictEqual(r.path, `barbershops/${booking.shopId}/reviews/${id}`);
    assert.strictEqual(r.data.bookingId, id);
    assert.strictEqual(r.data.barberId, booking.barberId);
    assert.strictEqual(r.data.customerId, booking.customerId);
    assert.strictEqual(r.data.customerName, booking.customerName);
    assert.ok(Number.isInteger(r.data.rating) && r.data.rating >= 1 && r.data.rating <= 5, id);
    assert.ok(Object.keys(r.data).every((k) => allowed.includes(k)), id);
    assert.ok(Date.parse(r.data.createdAt) > Date.parse(booking.startAt), id);
    assert.ok(Date.parse(r.data.createdAt) < now.getTime(), id);
    if ('comment' in r.data) assert.ok(r.data.comment.length >= 1 && r.data.comment.length <= 500, id);
    assert.strictEqual('reply' in r.data, 'replyAt' in r.data, id);
    if (r.data.reply) {
      assert.ok(r.data.reply.length <= 500, id);
      assert.ok(Date.parse(r.data.replyAt) > Date.parse(r.data.createdAt), id);
    }
  }
  // book_3: today 2026-11-20 - 2 days, 10:30 Addis (07:30Z), reviewed 5 hours later.
  assert.deepStrictEqual(get(docs, 'barbershops/shop_1/reviews/book_3').createdAt, '2026-11-18T12:30:00.000Z');
  // book_5 is left unreviewed so the demo customer has a visit to rate.
  assert.strictEqual(get(docs, 'barbershops/shop_2/reviews/book_5'), undefined);
});

test('barber counters and shop ratings match the seeded reviews', () => {
  const docs = buildDocuments(seed, { now });
  const reviews = docs.filter((d) => d.path.includes('/reviews/')).map((d) => d.data);
  for (const shop of seed.shops) {
    const mine = reviews.filter((r) => r.shopId === shop.id);
    const averages = [];
    for (const b of shop.barbers) {
      const ratings = mine.filter((r) => r.barberId === b.id).map((r) => r.rating);
      const sum = ratings.reduce((a, c) => a + c, 0);
      assert.deepStrictEqual({ ratingSum: b.ratingSum, reviewCount: b.reviewCount }, { ratingSum: sum, reviewCount: ratings.length }, b.id);
      // The legacy average stays consistent (fallback for docs without ratingSum).
      assert.deepStrictEqual({ rating: b.rating, reviewCount: b.reviewCount }, summarize(ratings), b.id);
      const doc = get(docs, `barbershops/${shop.id}/barbers/${b.id}`);
      assert.strictEqual(doc.ratingSum, sum, b.id);
      assert.strictEqual(doc.reviewCount, ratings.length, b.id);
      if (ratings.length > 0) averages.push({ id: b.id, avg: sum / ratings.length });
    }
    averages.sort((a, c) => (a.id < c.id ? -1 : 1));
    const shopRating = averages.length === 0 ? 0 : Math.round((averages.reduce((a, c) => a + c.avg, 0) / averages.length) * 10 + 1e-9) / 10;
    assert.strictEqual(shop.rating, shopRating, shop.id);
    assert.strictEqual(shop.reviewCount, mine.length, shop.id);
  }
});

test('invites mode writes no reviews', () => {
  assert.ok(!buildDocuments(seed, { now, mode: 'invites' }).some((d) => d.path.includes('/reviews/')));
});
