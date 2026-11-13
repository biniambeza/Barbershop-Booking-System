/**
 * One-time email codes: generation, salted hashing and checking.
 * Only the salted SHA-256 hash is ever stored.
 */
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';

import type { Purpose } from './input';

export const CODE_TTL_SECONDS = 600;
export const MAX_ATTEMPTS = 5;

/** emailCodes/{purpose}_{sha256(email)} */
export interface CodeDoc {
  purpose: Purpose;
  emailHash: string;
  codeHash: string;
  salt: string;
  expiresAt: string;
  attempts: number;
  createdAt: string;
  lastSentAt: string;
}

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/** Cryptographically random, uniformly distributed 000000-999999. */
export function generateCode(rand: (min: number, max: number) => number = randomInt): string {
  return String(rand(0, 1_000_000)).padStart(6, '0');
}

export function newSalt(): string {
  return randomBytes(16).toString('hex');
}

export function hashCode(code: string, salt: string): string {
  return sha256Hex(`${salt}:${code}`);
}

/** Constant-time comparison of hash(code, salt) with the stored hex hash. */
export function codeMatches(code: string, salt: string, storedHash: string): boolean {
  const actual = Buffer.from(hashCode(code, salt), 'hex');
  const expected = Buffer.from(storedHash, 'hex');
  if (actual.length !== expected.length || expected.length === 0) return false;
  return timingSafeEqual(actual, expected);
}

export function codeDocId(purpose: Purpose, email: string): string {
  return `${purpose}_${sha256Hex(email)}`;
}

export function buildCodeDoc(purpose: Purpose, email: string, code: string, now: Date, salt = newSalt()): CodeDoc {
  const iso = now.toISOString();
  return {
    purpose,
    emailHash: sha256Hex(email),
    codeHash: hashCode(code, salt),
    salt,
    expiresAt: new Date(now.getTime() + CODE_TTL_SECONDS * 1000).toISOString(),
    attempts: 0,
    createdAt: iso,
    lastSentAt: iso,
  };
}

export type CodeCheck =
  | { result: 'ok' }
  | { result: 'expired' } // missing, expired or out of attempts: delete the doc
  | { result: 'wrong'; attempts: number; attemptsLeft: number }; // store attempts

/** Decides what a submitted code means for a stored code document. */
export function checkCode(doc: CodeDoc | null, purpose: Purpose, code: string, now: Date): CodeCheck {
  if (!doc || doc.purpose !== purpose) return { result: 'expired' };
  const attempts = typeof doc.attempts === 'number' ? doc.attempts : MAX_ATTEMPTS;
  if (attempts >= MAX_ATTEMPTS) return { result: 'expired' };
  const expiresAt = Date.parse(doc.expiresAt);
  if (!Number.isFinite(expiresAt) || now.getTime() >= expiresAt) return { result: 'expired' };
  if (codeMatches(code, doc.salt, doc.codeHash)) return { result: 'ok' };
  const next = attempts + 1;
  if (next >= MAX_ATTEMPTS) return { result: 'expired' };
  return { result: 'wrong', attempts: next, attemptsLeft: MAX_ATTEMPTS - next };
}
