/**
 * All notification copy lives here, in English and Amharic.
 *
 * Times are shown on the Addis Ababa wall clock (UTC+3). Amharic messages
 * also give the traditional Ethiopian clock reading in brackets (the day
 * starts at 6:00, so 10:30 is "ጠዋት 4:30"), because many customers read time
 * that way. Prices are in Ethiopian Birr.
 */

import type { CancelActor, NotificationType } from './events';
import { toAddisParts } from './time';

export type Language = 'en' | 'am';
export type Audience = 'customer' | 'barber' | 'owner';

export interface TemplateContext {
  shopName: string;
  barberName: string;
  customerName: string;
  serviceName: string;
  price: number | null;
  start: Date | null;
  cancelledBy?: CancelActor;
}

export interface RenderedMessage {
  title: string;
  body: string;
}

export const APP_NAME = 'Crown & Blade';

export function normalizeLanguage(value: unknown, fallback: Language): Language {
  return value === 'en' || value === 'am' ? value : fallback;
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

const EN_WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const EN_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const AM_WEEKDAYS = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሁድ'];

const pad2 = (n: number): string => String(n).padStart(2, '0');

/** Traditional Ethiopian clock: 6:00 is 12 o'clock "in the morning". */
export function ethiopianClock(hour: number, minute: number): string {
  const ethHour = (hour + 6) % 12 || 12;
  let period: string;
  if (hour < 6) period = 'ሌሊት';
  else if (hour < 12) period = 'ጠዋት';
  else if (hour < 18) period = 'ከሰዓት';
  else period = 'ማታ';
  return `${period} ${ethHour}:${pad2(minute)}`;
}

/** Appointment time on the Addis wall clock. */
export function formatWhen(start: Date | null, lang: Language): string {
  if (!start) return lang === 'am' ? 'በተያዘው ሰዓት' : 'at the booked time';
  const p = toAddisParts(start);
  const time = `${pad2(p.hour)}:${pad2(p.minute)}`;
  if (lang === 'am') {
    return `${AM_WEEKDAYS[p.weekday - 1]} ${pad2(p.day)}/${pad2(p.month)}/${p.year} ${time} (${ethiopianClock(p.hour, p.minute)})`;
  }
  return `${EN_WEEKDAYS[p.weekday - 1]} ${p.day} ${EN_MONTHS[p.month - 1]} ${p.year}, ${time}`;
}

/** "1,250 ETB" / "1,250 ብር". */
export function formatPrice(price: number | null, lang: Language): string {
  if (price === null || !Number.isFinite(price)) return '';
  const rounded = Math.round(price * 100) / 100;
  const digits = Number.isInteger(rounded) ? 0 : 2;
  const [whole, frac] = rounded.toFixed(digits).split('.');
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const amount = frac ? `${grouped}.${frac}` : grouped;
  return lang === 'am' ? `${amount} ብር` : `${amount} ETB`;
}

function cancelledByPhrase(actor: CancelActor | undefined, audience: Audience, lang: Language): string {
  const a = actor ?? 'unknown';
  if (lang === 'am') {
    switch (a) {
      case 'customer': return audience === 'customer' ? ' በእርስዎ' : ' በደንበኛው';
      case 'barber': return ' በፀጉር አስተካካዩ';
      case 'shop': return ' በፀጉር ቤቱ';
      case 'admin': return ' በአስተዳዳሪ';
      default: return '';
    }
  }
  switch (a) {
    case 'customer': return audience === 'customer' ? ' by you' : ' by the customer';
    case 'barber': return ' by the barber';
    case 'shop': return ' by the shop';
    case 'admin': return ' by an administrator';
    default: return '';
  }
}

// ---------------------------------------------------------------------------
// Push / in-app inbox
// ---------------------------------------------------------------------------

interface Vars {
  shop: string;
  barber: string;
  customer: string;
  service: string;
  when: string;
  price: string;
  by: string;
}

function vars(ctx: TemplateContext, audience: Audience, lang: Language): Vars {
  return {
    shop: ctx.shopName || APP_NAME,
    barber: ctx.barberName || (lang === 'am' ? 'ፀጉር አስተካካይ' : 'your barber'),
    customer: ctx.customerName || (lang === 'am' ? 'ደንበኛ' : 'A customer'),
    service: ctx.serviceName || (lang === 'am' ? 'አገልግሎት' : 'service'),
    when: formatWhen(ctx.start, lang),
    price: formatPrice(ctx.price, lang),
    by: cancelledByPhrase(ctx.cancelledBy, audience, lang),
  };
}

const priceSuffix = (v: Vars, lang: Language): string =>
  v.price ? (lang === 'am' ? ` ዋጋ፦ ${v.price}።` : ` Price: ${v.price}.`) : '';

type Builder = (v: Vars) => RenderedMessage;
type Table = Record<NotificationType, { customer: Builder; staff: Builder }>;

const EN: Table = {
  created: {
    customer: (v) => ({
      title: 'Booking request received',
      body: `Your ${v.service} with ${v.barber} at ${v.shop} on ${v.when} is waiting for confirmation.${priceSuffix(v, 'en')}`,
    }),
    staff: (v) => ({
      title: 'New booking request',
      body: `${v.customer} booked ${v.service} with ${v.barber} on ${v.when}.`,
    }),
  },
  confirmed: {
    customer: (v) => ({
      title: 'Booking confirmed',
      body: `Your ${v.service} with ${v.barber} at ${v.shop} on ${v.when} is confirmed.${priceSuffix(v, 'en')}`,
    }),
    staff: (v) => ({
      title: 'Booking confirmed',
      body: `${v.customer} - ${v.service} with ${v.barber} on ${v.when}.`,
    }),
  },
  cancelled: {
    customer: (v) => ({
      title: 'Booking cancelled',
      body: `Your ${v.service} at ${v.shop} on ${v.when} was cancelled${v.by}.`,
    }),
    staff: (v) => ({
      title: 'Booking cancelled',
      body: `${v.customer}: ${v.service} with ${v.barber} on ${v.when} was cancelled${v.by}.`,
    }),
  },
  started: {
    customer: (v) => ({
      title: 'Your appointment has started',
      body: `${v.barber} has started your ${v.service} at ${v.shop}.`,
    }),
    staff: (v) => ({
      title: 'Appointment started',
      body: `${v.barber} started ${v.service} for ${v.customer}.`,
    }),
  },
  completed: {
    customer: (v) => ({
      title: 'Thanks for visiting',
      body: `Your ${v.service} at ${v.shop} is complete.${priceSuffix(v, 'en')} We hope to see you again!`,
    }),
    staff: (v) => ({
      title: 'Appointment completed',
      body: `${v.barber} completed ${v.service} for ${v.customer}.${priceSuffix(v, 'en')}`,
    }),
  },
  reminder24h: {
    customer: (v) => ({
      title: 'Appointment reminder',
      body: `Reminder: ${v.service} with ${v.barber} at ${v.shop} on ${v.when}.`,
    }),
    staff: (v) => ({
      title: 'Upcoming appointment',
      body: `${v.customer} - ${v.service} with ${v.barber} on ${v.when}.`,
    }),
  },
  reminder2h: {
    customer: (v) => ({
      title: 'Your appointment is in 2 hours',
      body: `${v.service} with ${v.barber} at ${v.shop} on ${v.when}. See you soon!`,
    }),
    staff: (v) => ({
      title: 'Appointment in 2 hours',
      body: `${v.customer} - ${v.service} with ${v.barber} on ${v.when}.`,
    }),
  },
};

const AM: Table = {
  created: {
    customer: (v) => ({
      title: 'የቀጠሮ ጥያቄዎ ደርሷል',
      body: `${v.shop} ላይ ከ${v.barber} ጋር ${v.when} ለ${v.service} ያቀረቡት ጥያቄ ማረጋገጫ በመጠባበቅ ላይ ነው።${priceSuffix(v, 'am')}`,
    }),
    staff: (v) => ({
      title: 'አዲስ የቀጠሮ ጥያቄ',
      body: `${v.customer} ከ${v.barber} ጋር ${v.when} ለ${v.service} ቀጠሮ ጠይቀዋል።`,
    }),
  },
  confirmed: {
    customer: (v) => ({
      title: 'ቀጠሮዎ ተረጋግጧል',
      body: `${v.shop} ላይ ከ${v.barber} ጋር ${v.when} ያለዎት የ${v.service} ቀጠሮ ተረጋግጧል።${priceSuffix(v, 'am')}`,
    }),
    staff: (v) => ({
      title: 'ቀጠሮ ተረጋግጧል',
      body: `${v.customer} - ${v.service} ከ${v.barber} ጋር ${v.when}።`,
    }),
  },
  cancelled: {
    customer: (v) => ({
      title: 'ቀጠሮዎ ተሰርዟል',
      body: `${v.shop} ላይ ${v.when} የነበረዎት የ${v.service} ቀጠሮ${v.by} ተሰርዟል።`,
    }),
    staff: (v) => ({
      title: 'ቀጠሮ ተሰርዟል',
      body: `${v.customer}፦ የ${v.service} ቀጠሮ (${v.barber}፣ ${v.when})${v.by} ተሰርዟል።`,
    }),
  },
  started: {
    customer: (v) => ({
      title: 'አገልግሎትዎ ተጀምሯል',
      body: `${v.barber} ${v.shop} ላይ የ${v.service} አገልግሎትዎን ጀምረዋል።`,
    }),
    staff: (v) => ({
      title: 'አገልግሎት ተጀምሯል',
      body: `${v.barber} ለ${v.customer} የ${v.service} አገልግሎት ጀምረዋል።`,
    }),
  },
  completed: {
    customer: (v) => ({
      title: 'ስለመጡ እናመሰግናለን',
      body: `${v.shop} ላይ የ${v.service} አገልግሎትዎ ተጠናቋል።${priceSuffix(v, 'am')} በድጋሚ እንጠብቅዎታለን!`,
    }),
    staff: (v) => ({
      title: 'አገልግሎት ተጠናቋል',
      body: `${v.barber} ለ${v.customer} የ${v.service} አገልግሎት አጠናቀዋል።${priceSuffix(v, 'am')}`,
    }),
  },
  reminder24h: {
    customer: (v) => ({
      title: 'የቀጠሮ ማስታወሻ',
      body: `ማስታወሻ፦ ${v.when} ${v.shop} ላይ ከ${v.barber} ጋር የ${v.service} ቀጠሮ አለዎት።`,
    }),
    staff: (v) => ({
      title: 'የሚመጣ ቀጠሮ',
      body: `${v.customer} - ${v.service} ከ${v.barber} ጋር ${v.when}።`,
    }),
  },
  reminder2h: {
    customer: (v) => ({
      title: 'ቀጠሮዎ በ2 ሰዓት ውስጥ ነው',
      body: `${v.when} ${v.shop} ላይ ከ${v.barber} ጋር የ${v.service} ቀጠሮ አለዎት። እንጠብቅዎታለን!`,
    }),
    staff: (v) => ({
      title: 'ቀጠሮ በ2 ሰዓት ውስጥ',
      body: `${v.customer} - ${v.service} ከ${v.barber} ጋር ${v.when}።`,
    }),
  },
};

/** Title and body for push notifications and the in-app inbox. */
export function renderNotification(
  type: NotificationType,
  audience: Audience,
  lang: Language,
  ctx: TemplateContext,
): RenderedMessage {
  const entry = (lang === 'am' ? AM : EN)[type];
  const builder = audience === 'customer' ? entry.customer : entry.staff;
  return builder(vars(ctx, audience, lang));
}

// ---------------------------------------------------------------------------
// SMS (customer only; kept short because Amharic SMS segments are 70 chars)
// ---------------------------------------------------------------------------

export type SmsType = 'confirmed' | 'cancelled' | 'reminder24h' | 'reminder2h';

export function isSmsType(type: NotificationType): type is SmsType {
  return type === 'confirmed' || type === 'cancelled' || type === 'reminder24h' || type === 'reminder2h';
}

export function renderSms(type: SmsType, lang: Language, ctx: TemplateContext): string {
  const v = vars(ctx, 'customer', lang);
  if (lang === 'am') {
    const price = v.price ? ` ዋጋ ${v.price}።` : '';
    switch (type) {
      case 'confirmed':
        return `${APP_NAME}፦ ${v.shop} ቀጠሮዎ ተረጋግጧል - ${v.when}፣ ${v.barber}።${price}`;
      case 'cancelled':
        return `${APP_NAME}፦ ${v.shop} ${v.when} የነበረዎት ቀጠሮ${v.by} ተሰርዟል።`;
      case 'reminder24h':
        return `${APP_NAME}፦ ማስታወሻ - ${v.shop} ቀጠሮ ${v.when}፣ ${v.barber}።`;
      case 'reminder2h':
        return `${APP_NAME}፦ ቀጠሮዎ በ2 ሰዓት ውስጥ ነው - ${v.shop}፣ ${v.when}።`;
    }
  }
  const price = v.price ? ` ${v.price}.` : '';
  switch (type) {
    case 'confirmed':
      return `${APP_NAME}: Booking confirmed at ${v.shop}, ${v.when} with ${v.barber}.${price}`;
    case 'cancelled':
      return `${APP_NAME}: Your booking at ${v.shop} on ${v.when} was cancelled${v.by}.`;
    case 'reminder24h':
      return `${APP_NAME}: Reminder - ${v.shop}, ${v.when} with ${v.barber}.`;
    case 'reminder2h':
      return `${APP_NAME}: Your appointment at ${v.shop} is in 2 hours (${v.when}).`;
  }
}
