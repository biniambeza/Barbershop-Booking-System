/**
 * Send limits for email codes.
 *  - 60 s cooldown per email + purpose (from the code doc's lastSentAt)
 *  - 5 sends per email per day (all purposes): authRateLimits/email_{sha256(email)}
 *  - 20 sends per caller IP per hour: authRateLimits/ip_{sha256(ip)}
 * Counters are fixed windows that start at the first send.
 */
import { sha256Hex } from './codes';

export const RESEND_COOLDOWN_SECONDS = 60;
export const EMAIL_SENDS_PER_DAY = 5;
export const IP_SENDS_PER_HOUR = 20;
export const DAY_MS = 24 * 3600 * 1000;
export const HOUR_MS = 3600 * 1000;

/** authRateLimits/{key} */
export interface RateDoc {
  count: number;
  windowStart: string;
  expiresAt: string;
}

/** Seconds until another code may be sent (0 = now). */
export function cooldownRemaining(lastSentAt: string | undefined, now: Date): number {
  if (!lastSentAt) return 0;
  const last = Date.parse(lastSentAt);
  if (!Number.isFinite(last)) return 0;
  const waitMs = last + RESEND_COOLDOWN_SECONDS * 1000 - now.getTime();
  return waitMs > 0 ? Math.ceil(waitMs / 1000) : 0;
}

/** Counts one more send in a fixed window, or refuses it if the window is full. */
export function bumpWindow(
  doc: RateDoc | null,
  now: Date,
  windowMs: number,
  max: number,
): { allowed: boolean; next: RateDoc; retryAfterSeconds: number } {
  const nowMs = now.getTime();
  const start = doc ? Date.parse(doc.windowStart) : NaN;
  const live = doc !== null && Number.isFinite(start) && nowMs < start + windowMs && nowMs >= start;
  if (!live) {
    return {
      allowed: true,
      next: { count: 1, windowStart: now.toISOString(), expiresAt: new Date(nowMs + windowMs).toISOString() },
      retryAfterSeconds: 0,
    };
  }
  const count = typeof doc.count === 'number' ? doc.count : max;
  if (count >= max) {
    return { allowed: false, next: doc, retryAfterSeconds: Math.ceil((start + windowMs - nowMs) / 1000) };
  }
  return { allowed: true, next: { ...doc, count: count + 1 }, retryAfterSeconds: 0 };
}

export const emailRateKey = (email: string): string => `email_${sha256Hex(email)}`;
export const ipRateKey = (ip: string): string => `ip_${sha256Hex(ip)}`;
