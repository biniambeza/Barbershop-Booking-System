import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  ethiopianClock,
  formatDate,
  formatPrice,
  formatWhen,
  normalizeLanguage,
  renderNotification,
  renderSms,
  type TemplateContext,
} from '../src/templates';
import { ALL_NOTIFICATION_TYPES } from '../src/events';

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
  for (const type of ALL_NOTIFICATION_TYPES) {
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

test('formatDate is the Addis calendar day', () => {
  assert.equal(formatDate(new Date('2026-12-13T07:30:00Z'), 'en'), 'Sun 13 Dec 2026');
  assert.equal(formatDate(new Date('2026-12-13T07:30:00Z'), 'am'), 'እሁድ 13/12/2026');
  // 22:00 UTC is already the next day in Addis
  assert.equal(formatDate(new Date('2026-12-12T22:00:00Z'), 'en'), 'Sun 13 Dec 2026');
  assert.equal(formatDate(null, 'en'), '');
});

test('payment received / refunded / failed (both languages)', () => {
  const paid = renderNotification('paymentReceived', 'customer', 'en', { ...ctx, amount: 1250 });
  assert.equal(paid.title, 'Payment received');
  assert.equal(
    paid.body,
    'We received your payment of 1,250 ETB for Skin Fade at Bole Fade House on Fri 13 Nov 2026, 10:30. Thank you!',
  );
  const paidAm = renderNotification('paymentReceived', 'customer', 'am', ctx);
  assert.equal(paidAm.title, 'ክፍያዎ ደርሷል');
  assert.match(paidAm.body, /1,250 ብር ደርሶናል/);
  assert.match(paidAm.body, /ጠዋት 4:30/);

  const owner = renderNotification('paymentReceived', 'owner', 'en', ctx);
  assert.equal(owner.title, 'Booking paid');
  assert.equal(owner.body, 'Abebe paid 1,250 ETB for Skin Fade with Dawit on Fri 13 Nov 2026, 10:30.');
  assert.equal(renderNotification('paymentReceived', 'owner', 'am', ctx).title, 'ቀጠሮ ተከፍሏል');

  const refunded = renderNotification('paymentRefunded', 'customer', 'en', ctx);
  assert.equal(refunded.title, 'Payment refunded');
  assert.match(refunded.body, /1,250 ETB .* has been refunded\.$/);
  assert.match(renderNotification('paymentRefunded', 'customer', 'am', ctx).body, /ተመላሽ ተደርጓል/);

  const failed = renderNotification('paymentFailed', 'customer', 'en', { ...ctx, amount: 1250 });
  assert.equal(failed.title, 'Payment failed');
  assert.match(failed.body, /did not go through\. You can try again in the app or pay at the shop\.$/);
  const failedAm = renderNotification('paymentFailed', 'customer', 'am', ctx);
  assert.equal(failedAm.title, 'ክፍያው አልተሳካም');
  assert.match(failedAm.body, /ፀጉር ቤቱ ላይ መክፈል ይችላሉ/);
});

test('payment templates without an amount read naturally', () => {
  const noPrice = { ...ctx, price: null };
  assert.equal(
    renderNotification('paymentReceived', 'customer', 'en', noPrice).body,
    'We received your payment for Skin Fade at Bole Fade House on Fri 13 Nov 2026, 10:30. Thank you!',
  );
  assert.match(renderNotification('paymentReceived', 'customer', 'am', noPrice).body, /የከፈሉት ክፍያ ደርሶናል/);
  assert.ok(!renderNotification('paymentFailed', 'customer', 'en', noPrice).body.includes('  '));
});

test('subscription templates (owner)', () => {
  const sub = { ...ctx, amount: 1500, planName: 'Pro', periodEnd: new Date('2026-12-13T07:30:00Z') };
  const paid = renderNotification('subscriptionPaid', 'owner', 'en', sub);
  assert.equal(paid.title, 'Subscription payment received');
  assert.equal(
    paid.body,
    'Bole Fade House: we received 1,500 ETB for the Pro plan. Your subscription is active until Sun 13 Dec 2026.',
  );
  const paidAm = renderNotification('subscriptionPaid', 'owner', 'am', sub);
  assert.match(paidAm.body, /ለPro ዕቅድ የከፈሉት 1,500 ብር ደርሶናል/);
  assert.match(paidAm.body, /እስከ እሁድ 13\/12\/2026 ድረስ/);
  const failed = renderNotification('subscriptionFailed', 'owner', 'en', sub);
  assert.equal(failed.title, 'Subscription payment failed');
  assert.match(failed.body, /1,500 ETB for the Pro plan did not go through/);
  assert.equal(renderNotification('subscriptionFailed', 'owner', 'am', sub).title, 'የደንበኝነት ክፍያ አልተሳካም');
  // no period end -> no "active until"
  assert.ok(!renderNotification('subscriptionPaid', 'owner', 'en', { ...sub, periodEnd: null }).body.includes('until'));
});

test('slot taken (both languages) and system cancel phrase', () => {
  const en = renderNotification('slotTaken', 'customer', 'en', { ...ctx, cancelledBy: 'system' });
  assert.equal(en.title, 'That time was just taken');
  assert.equal(
    en.body,
    'Sorry, Fri 13 Nov 2026, 10:30 with Dawit at Bole Fade House was just booked by someone else, so your request was cancelled. Please book another time.',
  );
  const am = renderNotification('slotTaken', 'customer', 'am', ctx);
  assert.equal(am.title, 'ሰዓቱ ተይዟል');
  assert.match(am.body, /እባክዎ ሌላ ሰዓት ይያዙ/);
  assert.match(renderNotification('slotTaken', 'owner', 'en', ctx).body, /cancelled automatically/);
  assert.match(renderNotification('cancelled', 'customer', 'en', { ...ctx, cancelledBy: 'system' }).body, /cancelled automatically\.$/);
  assert.match(renderNotification('cancelled', 'customer', 'am', { ...ctx, cancelledBy: 'system' }).body, /በራስ-ሰር ተሰርዟል/);
});

test('payment and slot SMS texts', () => {
  assert.equal(
    renderSms('paymentReceived', 'en', ctx),
    'Crown & Blade: Payment of 1,250 ETB received for Bole Fade House, Fri 13 Nov 2026, 10:30. Thank you!',
  );
  assert.match(renderSms('paymentReceived', 'am', ctx), /የ1,250 ብር ክፍያ ደርሷል/);
  assert.equal(
    renderSms('slotTaken', 'en', ctx),
    'Crown & Blade: Sorry, Fri 13 Nov 2026, 10:30 at Bole Fade House was just taken. Your request was cancelled - please book another time.',
  );
  assert.match(renderSms('slotTaken', 'am', ctx), /ሌላ ሰዓት ይያዙ/);
  const sub = { ...ctx, amount: 1500, periodEnd: new Date('2026-12-13T07:30:00Z') };
  assert.equal(
    renderSms('subscriptionPaid', 'en', sub),
    'Crown & Blade: Bole Fade House subscription payment of 1,500 ETB received. Active until Sun 13 Dec 2026.',
  );
  assert.equal(
    renderSms('subscriptionPaid', 'am', sub),
    'Crown & Blade፦ የBole Fade House የደንበኝነት ክፍያ 1,500 ብር ደርሷል። እስከ እሁድ 13/12/2026 ንቁ ነው።',
  );
});

test('reschedule: new time in Addis local with the old one, both languages, and the SMS', () => {
  const moved: TemplateContext = { ...ctx, previousStart: new Date('2026-11-12T11:00:00.000Z') };
  const en = renderNotification('rescheduled', 'customer', 'en', moved);
  assert.equal(en.title, 'Booking moved');
  assert.equal(
    en.body,
    'Your Skin Fade with Dawit at Bole Fade House is now on Fri 13 Nov 2026, 10:30. (It was Thu 12 Nov 2026, 14:00.)',
  );
  const staff = renderNotification('rescheduled', 'barber', 'en', moved);
  assert.match(staff.body, /^Abebe moved Skin Fade with Dawit to Fri 13 Nov 2026, 10:30\./);
  const am = renderNotification('rescheduled', 'customer', 'am', moved);
  assert.equal(am.title, 'ቀጠሮዎ ተዛውሯል');
  assert.match(am.body, /ወደ ዓርብ 13\/11\/2026 10:30 \(ጠዋት 4:30\) ተዛውሯል/);
  assert.match(am.body, /የቀድሞው ሰዓት፦ ሐሙስ 12\/11\/2026 14:00/);
  assert.equal(
    renderSms('rescheduled', 'en', moved),
    'Crown & Blade: Your booking at Bole Fade House was moved to Fri 13 Nov 2026, 10:30 with Dawit.',
  );
  assert.equal(
    renderSms('rescheduled', 'am', moved),
    'Crown & Blade፦ Bole Fade House ቀጠሮዎ ወደ ዓርብ 13/11/2026 10:30 (ጠዋት 4:30) ተዛውሯል፣ Dawit።',
  );
  // Without the previous time the sentence still reads naturally.
  assert.equal(
    renderNotification('rescheduled', 'customer', 'en', ctx).body,
    'Your Skin Fade with Dawit at Bole Fade House is now on Fri 13 Nov 2026, 10:30.',
  );
});

test('no-show (both languages)', () => {
  const en = renderNotification('noShow', 'customer', 'en', ctx);
  assert.equal(en.title, 'Missed appointment');
  assert.match(en.body, /marked as a no-show for your Skin Fade at Bole Fade House on Fri 13 Nov 2026, 10:30/);
  const am = renderNotification('noShow', 'customer', 'am', ctx);
  assert.equal(am.title, 'ቀጠሮ አምልጦዎታል');
  assert.match(am.body, /እንዳልመጡ ተመዝግቧል/);
});
