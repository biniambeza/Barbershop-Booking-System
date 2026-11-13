/** Bilingual code emails: the selected language first, then the other. */
import type { Language, Purpose } from './input';

export interface EmailMessage {
  subject: string;
  text: string;
  html: string;
}

interface Copy {
  subject: string;
  intro: string;
  body: (code: string) => string;
}

const COPY: Record<Language, Record<Purpose, Copy>> = {
  en: {
    register: {
      subject: 'Your Crown & Blade sign-up code',
      intro: 'Use this code to finish creating your Crown & Blade account.',
      body: (code) =>
        `Your Crown & Blade code is ${code}. It expires in 10 minutes. If you did not ask for it, ignore this email.`,
    },
    reset: {
      subject: 'Your Crown & Blade password reset code',
      intro: 'Use this code to reset your Crown & Blade password.',
      body: (code) =>
        `Your Crown & Blade code is ${code}. It expires in 10 minutes. If you did not ask for it, ignore this email.`,
    },
  },
  am: {
    register: {
      subject: 'የCrown & Blade የምዝገባ ኮድዎ',
      intro: 'የCrown & Blade መለያዎን መፍጠር ለመጨረስ ይህን ኮድ ይጠቀሙ።',
      body: (code) =>
        `የCrown & Blade ኮድዎ ${code} ነው። በ10 ደቂቃ ውስጥ ጊዜው ያልፋል። ይህን ኮድ ካልጠየቁ ይህን ኢሜይል ችላ ይበሉ።`,
    },
    reset: {
      subject: 'የCrown & Blade የይለፍ ቃል መቀየሪያ ኮድዎ',
      intro: 'የCrown & Blade የይለፍ ቃልዎን ለመቀየር ይህን ኮድ ይጠቀሙ።',
      body: (code) =>
        `የCrown & Blade ኮድዎ ${code} ነው። በ10 ደቂቃ ውስጥ ጊዜው ያልፋል። ይህን ኮድ ካልጠየቁ ይህን ኢሜይል ችላ ይበሉ።`,
    },
  },
};

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

export function buildCodeEmail(purpose: Purpose, language: Language, code: string): EmailMessage {
  const order: Language[] = language === 'am' ? ['am', 'en'] : ['en', 'am'];
  const parts = order.map((l) => COPY[l][purpose]);
  const subject = parts.map((p) => p.subject).join(' / ');
  const text = parts.map((p) => `${p.intro}\n\n${p.body(code)}`).join('\n\n---\n\n') + '\n';
  const section = (p: Copy, lang: Language) =>
    `<div lang="${lang}" style="margin:0 0 24px">` +
    `<p style="margin:0 0 12px">${escapeHtml(p.intro)}</p>` +
    `<p style="font-size:28px;font-weight:bold;letter-spacing:6px;margin:0 0 12px">${escapeHtml(code)}</p>` +
    `<p style="margin:0">${escapeHtml(p.body(code))}</p>` +
    `</div>`;
  const html =
    `<!doctype html><html><body style="font-family:Arial,sans-serif;color:#222;max-width:520px">` +
    order.map((l, i) => section(parts[i], l)).join('<hr style="border:none;border-top:1px solid #ddd;margin:0 0 24px">') +
    `</body></html>`;
  return { subject, text, html };
}
