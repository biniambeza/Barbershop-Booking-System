/**
 * One-time email codes: generation, salted hashing and checking.
 * Only the salted SHA-256 hash is ever stored.
 */
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';

import type { Purpose } from './input';

export const CODE_TTL_SECONDS = 600;
export const MAX_ATTEMPTS = 5;
/** How long a verified code's token can be used to finish the flow. */
export const VERIFIED_TTL_SECONDS = 900;

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
  /** Set by verifyEmailCode: SHA-256 hex of the current verification token. */
  tokenHash?: string;
  verifiedAt?: string;
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

/** 32 random bytes, base64url (43 characters). Only its SHA-256 is stored. */
export function generateVerificationToken(): string {
  return randomBytes(32).toString('base64url');
}

export function hashToken(token: string): string {
  return sha256Hex(token);
}

/** Constant-time comparison of sha256(token) with the stored hex hash. */
export function tokenMatches(token: string, storedHash: unknown): boolean {
  if (typeof storedHash !== 'string' || !/^[0-9a-f]{64}$/.test(storedHash)) return false;
  const actual = Buffer.from(hashToken(token), 'hex');
  const expected = Buffer.from(storedHash, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/**
 * Fields written when a code is verified. The doc is kept (attempts and code
 * hash unchanged) and gets a fresh 15-minute expiry; re-verifying the same
 * code inside that window rotates the token and restarts the 15 minutes.
 */
export function verifiedPatch(tokenHash: string, now: Date): Pick<CodeDoc, 'tokenHash' | 'verifiedAt' | 'expiresAt'> {
  return {
    tokenHash,
    verifiedAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + VERIFIED_TTL_SECONDS * 1000).toISOString(),
  };
}

export type TokenCheck =
  | { result: 'ok' }
  | { result: 'invalid'; deleteDoc: boolean }; // verification-expired; delete only an expired doc

/** Decides whether a verification token may finish the flow for this doc. */
export function checkToken(doc: CodeDoc | null, purpose: Purpose, token: string, now: Date): TokenCheck {
  if (!doc) return { result: 'invalid', deleteDoc: false };
  const expiresAt = Date.parse(doc.expiresAt);
  if (!Number.isFinite(expiresAt) || now.getTime() >= expiresAt) return { result: 'invalid', deleteDoc: true };
  if (doc.purpose !== purpose || !doc.verifiedAt) return { result: 'invalid', deleteDoc: false };
  if (!tokenMatches(token, doc.tokenHash)) return { result: 'invalid', deleteDoc: false };
  return { result: 'ok' };
}
