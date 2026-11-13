/**
 * All notification copy lives here, in English and Amharic.
 *
 * Times are shown on the Addis Ababa wall clock (UTC+3). Amharic messages
 * also give the traditional Ethiopian clock reading in brackets (the day
 * starts at 6:00, so 10:30 is "ጠዋት 4:30"), because many customers read time
 * that way. Prices are in Ethiopian Birr.
 */

import { SMS_TYPES, type CancelActor, type NotificationType } from './events';
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
  /** Amount paid/refunded/attempted in ETB; payment templates fall back to `price`. */
  amount?: number | null;
  /** Subscription plan display name. */
  planName?: string;
  /** End of the paid subscription period. */
  periodEnd?: Date | null;
  /** Reschedules: the appointment's previous start. */
  previousStart?: Date | null;
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

/** Calendar day on the Addis wall clock: "Sun 13 Dec 2026" / "እሁድ 13/12/2026". */
export function formatDate(day: Date | null, lang: Language): string {
  if (!day) return '';
  const p = toAddisParts(day);
  if (lang === 'am') return `${AM_WEEKDAYS[p.weekday - 1]} ${pad2(p.day)}/${pad2(p.month)}/${p.year}`;
  return `${EN_WEEKDAYS[p.weekday - 1]} ${p.day} ${EN_MONTHS[p.month - 1]} ${p.year}`;
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
      case 'system': return ' በራስ-ሰር';
      default: return '';
    }
  }
  switch (a) {
    case 'customer': return audience === 'customer' ? ' by you' : ' by the customer';
    case 'barber': return ' by the barber';
    case 'shop': return ' by the shop';
    case 'admin': return ' by an administrator';
    case 'system': return ' automatically';
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
  /** Payment amount (falls back to the booking price); '' when unknown. */
  amount: string;
  plan: string;
  /** Subscription period end date; '' when unknown. */
  until: string;
  by: string;
  /** Previous appointment time of a reschedule; '' when unknown. */
  previous: string;
}

function vars(ctx: TemplateContext, audience: Audience, lang: Language): Vars {
  const amount = ctx.amount ?? ctx.price;
  return {
    amount: formatPrice(amount ?? null, lang),
    plan: ctx.planName || (lang === 'am' ? 'ደንበኝነት' : 'subscription'),
    until: formatDate(ctx.periodEnd ?? null, lang),
    shop: ctx.shopName || APP_NAME,
    barber: ctx.barberName || (lang === 'am' ? 'ፀጉር አስተካካይ' : 'your barber'),
    customer: ctx.customerName || (lang === 'am' ? 'ደንበኛ' : 'A customer'),
    service: ctx.serviceName || (lang === 'am' ? 'አገልግሎት' : 'service'),
    when: formatWhen(ctx.start, lang),
    price: formatPrice(ctx.price, lang),
    by: cancelledByPhrase(ctx.cancelledBy, audience, lang),
    previous: ctx.previousStart ? formatWhen(ctx.previousStart, lang) : '',
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
  slotTaken: {
    customer: (v) => ({
      title: 'That time was just taken',
      body: `Sorry, ${v.when} with ${v.barber} at ${v.shop} was just booked by someone else, so your request was cancelled. Please book another time.`,
    }),
    staff: (v) => ({
      title: 'Booking request withdrawn',
      body: `${v.customer}'s request for ${v.service} with ${v.barber} on ${v.when} overlapped another booking and was cancelled automatically.`,
    }),
  },
  paymentReceived: {
    customer: (v) => ({
      title: 'Payment received',
      body: `We received your payment${v.amount ? ` of ${v.amount}` : ''} for ${v.service} at ${v.shop} on ${v.when}. Thank you!`,
    }),
    staff: (v) => ({
      title: 'Booking paid',
      body: `${v.customer} paid${v.amount ? ` ${v.amount}` : ''} for ${v.service} with ${v.barber} on ${v.when}.`,
    }),
  },
  paymentRefunded: {
    customer: (v) => ({
      title: 'Payment refunded',
      body: `Your payment${v.amount ? ` of ${v.amount}` : ''} for ${v.service} at ${v.shop} on ${v.when} has been refunded.`,
    }),
    staff: (v) => ({
      title: 'Payment refunded',
      body: `${v.customer}'s payment${v.amount ? ` of ${v.amount}` : ''} for ${v.service} on ${v.when} was refunded.`,
    }),
  },
  paymentFailed: {
    customer: (v) => ({
      title: 'Payment failed',
      body: `Your payment${v.amount ? ` of ${v.amount}` : ''} for ${v.service} at ${v.shop} on ${v.when} did not go through. You can try again in the app or pay at the shop.`,
    }),
    staff: (v) => ({
      title: 'Customer payment failed',
      body: `${v.customer}'s online payment for ${v.service} on ${v.when} did not go through. They may pay at the shop.`,
    }),
  },
  subscriptionPaid: {
    customer: (v) => subscriptionPaidEn(v),
    staff: (v) => subscriptionPaidEn(v),
  },
  subscriptionFailed: {
    customer: (v) => subscriptionFailedEn(v),
    staff: (v) => subscriptionFailedEn(v),
  },
  rescheduled: {
    customer: (v) => ({
      title: 'Booking moved',
      body: `Your ${v.service} with ${v.barber} at ${v.shop} is now on ${v.when}.${v.previous ? ` (It was ${v.previous}.)` : ''}`,
    }),
    staff: (v) => ({
      title: 'Booking moved',
      body: `${v.customer} moved ${v.service} with ${v.barber} to ${v.when}.${v.previous ? ` It was ${v.previous}.` : ''}`,
    }),
  },
  noShow: {
    customer: (v) => ({
      title: 'Missed appointment',
      body: `You were marked as a no-show for your ${v.service} at ${v.shop} on ${v.when}. Please book again when you are ready.`,
    }),
    staff: (v) => ({
      title: 'Customer did not come',
      body: `${v.customer} did not come to ${v.service} with ${v.barber} on ${v.when}.`,
    }),
  },
};

function subscriptionPaidEn(v: Vars): RenderedMessage {
  return {
    title: 'Subscription payment received',
    body: `${v.shop}: we received${v.amount ? ` ${v.amount}` : ' your payment'} for the ${v.plan} plan.${v.until ? ` Your subscription is active until ${v.until}.` : ''}`,
  };
}

function subscriptionFailedEn(v: Vars): RenderedMessage {
  return {
    title: 'Subscription payment failed',
    body: `${v.shop}: your payment${v.amount ? ` of ${v.amount}` : ''} for the ${v.plan} plan did not go through. Please try again from the Subscription page.`,
  };
}

function subscriptionPaidAm(v: Vars): RenderedMessage {
  return {
    title: 'የደንበኝነት ክፍያ ደርሷል',
    body: `${v.shop}፦ ለ${v.plan} ዕቅድ የከፈሉት${v.amount ? ` ${v.amount}` : ' ክፍያ'} ደርሶናል።${v.until ? ` የደንበኝነት ምዝገባዎ እስከ ${v.until} ድረስ ንቁ ነው።` : ''}`,
  };
}

function subscriptionFailedAm(v: Vars): RenderedMessage {
  return {
    title: 'የደንበኝነት ክፍያ አልተሳካም',
    body: `${v.shop}፦ ለ${v.plan} ዕቅድ ያደረጉት${v.amount ? ` የ${v.amount}` : ''} ክፍያ አልተሳካም። እባክዎ ከደንበኝነት ገጹ እንደገና ይሞክሩ።`,
  };
}

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
  slotTaken: {
    customer: (v) => ({
      title: 'ሰዓቱ ተይዟል',
      body: `ይቅርታ፣ ${v.shop} ላይ ከ${v.barber} ጋር ${v.when} ያለው ሰዓት አሁን በሌላ ሰው ስለተያዘ ጥያቄዎ ተሰርዟል። እባክዎ ሌላ ሰዓት ይያዙ።`,
    }),
    staff: (v) => ({
      title: 'የቀጠሮ ጥያቄ ተሰርዟል',
      body: `${v.customer} ከ${v.barber} ጋር ${v.when} ለ${v.service} ያቀረቡት ጥያቄ ከሌላ ቀጠሮ ጋር ስለተጋጨ በራስ-ሰር ተሰርዟል።`,
    }),
  },
  paymentReceived: {
    customer: (v) => ({
      title: 'ክፍያዎ ደርሷል',
      body: `${v.shop} ላይ ${v.when} ለ${v.service} የከፈሉት${v.amount ? ` ${v.amount}` : ' ክፍያ'} ደርሶናል። እናመሰግናለን!`,
    }),
    staff: (v) => ({
      title: 'ቀጠሮ ተከፍሏል',
      body: `${v.customer} ከ${v.barber} ጋር ${v.when} ለ${v.service}${v.amount ? ` ${v.amount}` : ''} ከፍለዋል።`,
    }),
  },
  paymentRefunded: {
    customer: (v) => ({
      title: 'ክፍያዎ ተመልሷል',
      body: `${v.shop} ላይ ${v.when} ለ${v.service} የከፈሉት${v.amount ? ` ${v.amount}` : ' ክፍያ'} ተመላሽ ተደርጓል።`,
    }),
    staff: (v) => ({
      title: 'ክፍያ ተመልሷል',
      body: `${v.customer} ለ${v.service} (${v.when}) የከፈሉት${v.amount ? ` ${v.amount}` : ' ክፍያ'} ተመላሽ ተደርጓል።`,
    }),
  },
  paymentFailed: {
    customer: (v) => ({
      title: 'ክፍያው አልተሳካም',
      body: `${v.shop} ላይ ${v.when} ለ${v.service} ያደረጉት${v.amount ? ` የ${v.amount}` : ''} ክፍያ አልተሳካም። በመተግበሪያው እንደገና መሞከር ወይም ፀጉር ቤቱ ላይ መክፈል ይችላሉ።`,
    }),
    staff: (v) => ({
      title: 'የደንበኛ ክፍያ አልተሳካም',
      body: `${v.customer} ለ${v.service} (${v.when}) ያደረጉት የኦንላይን ክፍያ አልተሳካም። ፀጉር ቤቱ ላይ ሊከፍሉ ይችላሉ።`,
    }),
  },
  subscriptionPaid: {
    customer: (v) => subscriptionPaidAm(v),
    staff: (v) => subscriptionPaidAm(v),
  },
  subscriptionFailed: {
    customer: (v) => subscriptionFailedAm(v),
    staff: (v) => subscriptionFailedAm(v),
  },
  rescheduled: {
    customer: (v) => ({
      title: 'ቀጠሮዎ ተዛውሯል',
      body: `${v.shop} ላይ ከ${v.barber} ጋር ያለዎት የ${v.service} ቀጠሮ ወደ ${v.when} ተዛውሯል።${v.previous ? ` (የቀድሞው ሰዓት፦ ${v.previous})` : ''}`,
    }),
    staff: (v) => ({
      title: 'ቀጠሮ ተዛውሯል',
      body: `${v.customer} ከ${v.barber} ጋር ያላቸውን የ${v.service} ቀጠሮ ወደ ${v.when} አዛውረዋል።${v.previous ? ` (የቀድሞው ሰዓት፦ ${v.previous})` : ''}`,
    }),
  },
  noShow: {
    customer: (v) => ({
      title: 'ቀጠሮ አምልጦዎታል',
      body: `${v.shop} ላይ ${v.when} የነበረዎት የ${v.service} ቀጠሮ ላይ እንዳልመጡ ተመዝግቧል። ሲመችዎ እንደገና ቀጠሮ ይያዙ።`,
    }),
    staff: (v) => ({
      title: 'ደንበኛው አልመጡም',
      body: `${v.customer} ከ${v.barber} ጋር ${v.when} ለነበረው የ${v.service} ቀጠሮ አልመጡም።`,
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
// SMS (kept short because Amharic SMS segments are 70 chars). Customer only,
// except subscriptionPaid which goes to the shop owner.
// ---------------------------------------------------------------------------

export type SmsType = Extract<
  NotificationType,
  | 'confirmed'
  | 'cancelled'
  | 'slotTaken'
  | 'reminder24h'
  | 'reminder2h'
  | 'paymentReceived'
  | 'subscriptionPaid'
  | 'rescheduled'
>;

export function isSmsType(type: NotificationType): type is SmsType {
  return SMS_TYPES.has(type);
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
      case 'slotTaken':
        return `${APP_NAME}፦ ይቅርታ፣ ${v.shop} ${v.when} ያለው ሰዓት ተይዟል። ጥያቄዎ ተሰርዟል፤ እባክዎ ሌላ ሰዓት ይያዙ።`;
      case 'paymentReceived':
        return `${APP_NAME}፦ ${v.shop} ${v.when} ለያዙት ቀጠሮ${v.amount ? ` የ${v.amount}` : ''} ክፍያ ደርሷል። እናመሰግናለን!`;
      case 'subscriptionPaid':
        return `${APP_NAME}፦ የ${v.shop} የደንበኝነት ክፍያ${v.amount ? ` ${v.amount}` : ''} ደርሷል።${v.until ? ` እስከ ${v.until} ንቁ ነው።` : ''}`;
      case 'rescheduled':
        return `${APP_NAME}፦ ${v.shop} ቀጠሮዎ ወደ ${v.when} ተዛውሯል፣ ${v.barber}።`;
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
    case 'slotTaken':
      return `${APP_NAME}: Sorry, ${v.when} at ${v.shop} was just taken. Your request was cancelled - please book another time.`;
    case 'paymentReceived':
      return `${APP_NAME}: Payment${v.amount ? ` of ${v.amount}` : ''} received for ${v.shop}, ${v.when}. Thank you!`;
    case 'subscriptionPaid':
      return `${APP_NAME}: ${v.shop} subscription payment${v.amount ? ` of ${v.amount}` : ''} received.${v.until ? ` Active until ${v.until}.` : ''}`;
    case 'rescheduled':
      return `${APP_NAME}: Your booking at ${v.shop} was moved to ${v.when} with ${v.barber}.`;
  }
}
