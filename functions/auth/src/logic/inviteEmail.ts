/**
 * Invitation emails (onInviteCreated): tells an invited barber, owner or
 * admin how to sign up. Bilingual, Amharic first unless the inviter's
 * language is English. Pure: no Firestore, no secrets, no tokens.
 */
import type { Language } from './input';
import type { EmailMessage } from './templates';

export type InviteRole = 'admin' | 'barbershopOwner' | 'barber';

export interface InviteEmailInput {
  role: InviteRole;
  /** The invited (lowercased) address. */
  email: string;
  /** barbershops/{shopId}.name, when known. */
  shopName?: string | null;
  /** users/{createdBy}.name, when known. */
  inviterName?: string | null;
  /** users/{createdBy}.language; anything but 'en' puts Amharic first. */
  inviterLanguage?: string | null;
}

export function isInviteRole(v: unknown): v is InviteRole {
  return v === 'admin' || v === 'barbershopOwner' || v === 'barber';
}

/** Amharic first by default; English first only for an English-speaking inviter. */
export function inviteLanguageOrder(inviterLanguage?: string | null): Language[] {
  return inviterLanguage === 'en' ? ['en', 'am'] : ['am', 'en'];
}

/**
 * Id of the inviteEmails/{id} marker that makes the trigger idempotent:
 * one email per invite document (email + createdAt). Slashes are not
 * allowed in document ids, so they are replaced.
 */
export function inviteEmailDocId(email: string, createdAt: unknown): string {
  let stamp: string;
  if (typeof createdAt === 'string') stamp = createdAt;
  else if (createdAt && typeof (createdAt as { toDate?: unknown }).toDate === 'function') {
    stamp = (createdAt as { toDate: () => Date }).toDate().toISOString();
  } else if (createdAt instanceof Date) stamp = createdAt.toISOString();
  else stamp = 'unknown';
  return `${email}_${stamp}`.replace(/\//g, '_').slice(0, 1400);
}

const clean = (s?: string | null): string => (typeof s === 'string' ? s.trim().replace(/\s+/g, ' ').slice(0, 120) : '');

interface Copy {
  subject: string;
  paragraphs: string[];
}

function englishCopy(role: InviteRole, email: string, shop: string, inviter: string): Copy {
  const steps =
    `Install or open the Crown & Blade app, tap Register, enter this email (${email}), ` +
    'type the 6-digit code we send you and create your password.';
  if (role === 'admin') {
    return {
      subject: 'You are invited to Crown & Blade as an admin',
      paragraphs: [`${inviter || 'Crown & Blade'} added you as an admin on Crown & Blade.`, steps, 'Then you will see the admin dashboard.'],
    };
  }
  const shopLabel = shop || 'a barbershop';
  const who = inviter || shop || 'Crown & Blade';
  if (role === 'barbershopOwner') {
    return {
      subject: shop ? `You are invited to manage ${shop} on Crown & Blade` : 'You are invited to Crown & Blade as a shop owner',
      paragraphs: [`${who} added you as the owner of ${shopLabel} on Crown & Blade.`, steps, 'Then you can manage your shop, barbers and bookings.'],
    };
  }
  return {
    subject: shop ? `You are invited to ${shop} on Crown & Blade` : 'You are invited to Crown & Blade as a barber',
    paragraphs: [`${who} added you as a barber at ${shopLabel} on Crown & Blade.`, steps, "Then you'll see your bookings."],
  };
}

function amharicCopy(role: InviteRole, email: string, shop: string, inviter: string): Copy {
  const steps =
    `የCrown & Blade መተግበሪያን ይጫኑ ወይም ይክፈቱ፣ «ይመዝገቡ» የሚለውን ይንኩ፣ ይህን ኢሜይል (${email}) ያስገቡ፣ ` +
    'የምንልክልዎትን ባለ 6 አሃዝ ኮድ ይጻፉ እና የይለፍ ቃልዎን ይፍጠሩ።';
  if (role === 'admin') {
    return {
      subject: 'ወደ Crown & Blade በአስተዳዳሪነት ተጋብዘዋል',
      paragraphs: [`${inviter || 'Crown & Blade'} በCrown & Blade ላይ አስተዳዳሪ አድርጎ አክሎዎታል።`, steps, 'ከዚያ የአስተዳዳሪ ገጹን ያያሉ።'],
    };
  }
  const shopLabel = shop || 'አንድ ፀጉር ቤት';
  const who = inviter || shop || 'Crown & Blade';
  if (role === 'barbershopOwner') {
    return {
      subject: shop ? `${shop}ን በCrown & Blade ላይ እንዲያስተዳድሩ ተጋብዘዋል` : 'ወደ Crown & Blade በፀጉር ቤት ባለቤትነት ተጋብዘዋል',
      paragraphs: [`${who} በCrown & Blade ላይ የ${shopLabel} ባለቤት አድርጎ አክሎዎታል።`, steps, 'ከዚያ ፀጉር ቤትዎን፣ ፀጉር አስተካካዮችዎን እና ቀጠሮዎችን ማስተዳደር ይችላሉ።'],
    };
  }
  return {
    subject: shop ? `ወደ ${shop} በCrown & Blade ላይ ተጋብዘዋል` : 'ወደ Crown & Blade በፀጉር አስተካካይነት ተጋብዘዋል',
    paragraphs: [`${who} በCrown & Blade ላይ በ${shopLabel} ፀጉር አስተካካይ አድርጎ አክሎዎታል።`, steps, 'ከዚያ ቀጠሮዎችዎን ያያሉ።'],
  };
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

export function buildInviteEmail(input: InviteEmailInput): EmailMessage {
  const shop = input.role === 'admin' ? '' : clean(input.shopName);
  const inviter = clean(input.inviterName);
  const order = inviteLanguageOrder(input.inviterLanguage);
  const copies = order.map((l) =>
    l === 'am' ? amharicCopy(input.role, input.email, shop, inviter) : englishCopy(input.role, input.email, shop, inviter),
  );
  const subject = copies.map((c) => c.subject).join(' / ');
  const text = copies.map((c) => c.paragraphs.join('\n\n')).join('\n\n---\n\n') + '\n';
  const section = (c: Copy, lang: Language) =>
    `<div lang="${lang}" style="margin:0 0 24px">` +
    c.paragraphs.map((p) => `<p style="margin:0 0 12px">${escapeHtml(p)}</p>`).join('') +
    `</div>`;
  const html =
    `<!doctype html><html><body style="font-family:Arial,sans-serif;color:#222;max-width:520px">` +
    order.map((l, i) => section(copies[i], l)).join('<hr style="border:none;border-top:1px solid #ddd;margin:0 0 24px">') +
    `</body></html>`;
  return { subject, text, html };
}
