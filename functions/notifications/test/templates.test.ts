import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  ethiopianClock,
  formatPrice,
  formatWhen,
  normalizeLanguage,
  renderNotification,
  renderSms,
  type TemplateContext,
} from '../src/templates';
import type { NotificationType } from '../src/events';

// 07:30 UTC = 10:30 in Addis, Friday 13 Nov 2026.
const start = new Date('2026-11-13T07:30:00.000Z');
const ctx: TemplateContext = {
  shopName: 'Bole Fade House',
  barberName: 'Dawit',
  customerName: 'Abebe',
  serviceName: 'Skin Fade',
  price: 1250,
  start,
};

test('formatWhen shows Addis local time (UTC+3)', () => {
  assert.equal(formatWhen(start, 'en'), 'Fri 13 Nov 2026, 10:30');
  assert.equal(formatWhen(start, 'am'), 'ዓርብ 13/11/2026 10:30 (ጠዋት 4:30)');
});

test('formatWhen crosses midnight correctly', () => {
  // 22:15 UTC Thursday = 01:15 Friday in Addis.
  assert.equal(formatWhen(new Date('2026-11-12T22:15:00Z'), 'en'), 'Fri 13 Nov 2026, 01:15');
});

test('ethiopian clock', () => {
  assert.equal(ethiopianClock(6, 0), 'ጠዋት 12:00');
  assert.equal(ethiopianClock(7, 0), 'ጠዋት 1:00');
  assert.equal(ethiopianClock(13, 5), 'ከሰዓት 7:05');
  assert.equal(ethiopianClock(19, 30), 'ማታ 1:30');
  assert.equal(ethiopianClock(0, 0), 'ሌሊት 6:00');
});

test('formatPrice in ETB / ብር', () => {
  assert.equal(formatPrice(1250, 'en'), '1,250 ETB');
  assert.equal(formatPrice(1250, 'am'), '1,250 ብር');
  assert.equal(formatPrice(99.5, 'en'), '99.50 ETB');
  assert.equal(formatPrice(null, 'en'), '');
});

test('normalizeLanguage falls back', () => {
  assert.equal(normalizeLanguage('am', 'en'), 'am');
  assert.equal(normalizeLanguage(undefined, 'am'), 'am');
  assert.equal(normalizeLanguage('fr', 'en'), 'en');
});

test('every type renders non-empty for every audience and language', () => {
  const types: NotificationType[] = ['created', 'confirmed', 'cancelled', 'started', 'completed', 'reminder24h', 'reminder2h'];
  for (const type of types) {
    for (const audience of ['customer', 'barber', 'owner'] as const) {
      for (const lang of ['en', 'am'] as const) {
        const msg = renderNotification(type, audience, lang, ctx);
        assert.ok(msg.title.length > 0, `${type}/${audience}/${lang} title`);
        assert.ok(msg.body.length > 0, `${type}/${audience}/${lang} body`);
        assert.ok(!msg.body.includes('undefined'), `${type}/${audience}/${lang}: ${msg.body}`);
      }
    }
  }
});

test('customer confirmation includes shop, time and price', () => {
  const en = renderNotification('confirmed', 'customer', 'en', ctx);
  assert.equal(en.title, 'Booking confirmed');
  assert.match(en.body, /Bole Fade House/);
  assert.match(en.body, /Fri 13 Nov 2026, 10:30/);
  assert.match(en.body, /1,250 ETB/);
  const am = renderNotification('confirmed', 'customer', 'am', ctx);
  assert.equal(am.title, 'ቀጠሮዎ ተረጋግጧል');
  assert.match(am.body, /1,250 ብር/);
});

test('cancellation says who cancelled', () => {
  const byShop = renderNotification('cancelled', 'customer', 'en', { ...ctx, cancelledBy: 'shop' });
  assert.match(byShop.body, /was cancelled by the shop\.$/);
  const byCustomer = renderNotification('cancelled', 'owner', 'en', { ...ctx, cancelledBy: 'customer' });
  assert.match(byCustomer.body, /cancelled by the customer/);
  const unknown = renderNotification('cancelled', 'customer', 'en', ctx);
  assert.match(unknown.body, /was cancelled\.$/);
  const am = renderNotification('cancelled', 'customer', 'am', { ...ctx, cancelledBy: 'barber' });
  assert.match(am.body, /በፀጉር አስተካካዩ ተሰርዟል/);
});

test('missing names fall back gracefully', () => {
  const msg = renderNotification('created', 'barber', 'en', {
    shopName: '', barberName: '', customerName: '', serviceName: '', price: null, start: null,
  });
  assert.equal(msg.body, 'A customer booked service with your barber on at the booked time.');
});

test('SMS texts', () => {
  assert.equal(
    renderSms('confirmed', 'en', ctx),
    'Crown & Blade: Booking confirmed at Bole Fade House, Fri 13 Nov 2026, 10:30 with Dawit. 1,250 ETB.',
  );
  assert.equal(
    renderSms('reminder2h', 'am', ctx),
    'Crown & Blade፦ ቀጠሮዎ በ2 ሰዓት ውስጥ ነው - Bole Fade House፣ ዓርብ 13/11/2026 10:30 (ጠዋት 4:30)።',
  );
  assert.match(renderSms('cancelled', 'am', { ...ctx, cancelledBy: 'shop' }), /በፀጉር ቤቱ ተሰርዟል/);
});
