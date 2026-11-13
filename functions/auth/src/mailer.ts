/** SMTP mailer (nodemailer). Works with Gmail app passwords, Brevo, Resend SMTP, ... */
import nodemailer from 'nodemailer';

import type { Mailer } from './logic/service';

export interface SmtpConfig {
  host: string;
  port: number;
  user: string;
  pass: string;
  from: string;
}

/** Null (and the names of the missing settings) when anything is unset. */
export function smtpConfigFrom(values: Record<string, string | undefined>): { config: SmtpConfig | null; missing: string[] } {
  const get = (k: string) => (values[k] ?? '').trim();
  const missing = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'MAIL_FROM'].filter((k) => get(k) === '');
  const port = Number(get('SMTP_PORT'));
  if (get('SMTP_PORT') !== '' && (!Number.isInteger(port) || port <= 0 || port > 65535)) missing.push('SMTP_PORT (not a port number)');
  if (missing.length > 0) return { config: null, missing };
  return {
    config: { host: get('SMTP_HOST'), port, user: get('SMTP_USER'), pass: get('SMTP_PASS'), from: get('MAIL_FROM') },
    missing,
  };
}

export function smtpMailer(config: SmtpConfig): Mailer {
  const transport = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.port === 465, // 465 = implicit TLS; 587/25 upgrade with STARTTLS
    auth: { user: config.user, pass: config.pass },
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 20_000,
  });
  return {
    async send(to, message) {
      await transport.sendMail({ from: config.from, to, subject: message.subject, text: message.text, html: message.html });
    },
  };
}
