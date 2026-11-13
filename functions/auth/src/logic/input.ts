/** Input validation for the auth callables. */
import { FlowError } from './errors';

export type Purpose = 'register' | 'reset';
export type Language = 'en' | 'am';

/** Same pattern as isValidEmail in firestore.rules. */
export const EMAIL_RE = /^[a-z0-9._%+-]+@[a-z0-9-]+([.][a-z0-9-]+)*[.][a-z]{2,}$/;

export const PASSWORD_MIN = 8;
export const PASSWORD_MAX = 128;
export const NAME_MAX = 80;

/** Trims and lowercases; throws invalid-email unless it matches the rules' pattern. */
export function normalizeEmail(raw: unknown): string {
  if (typeof raw !== 'string') throw new FlowError('invalid-email');
  const email = raw.trim().toLowerCase();
  if (email.length < 3 || email.length > 254 || !EMAIL_RE.test(email)) throw new FlowError('invalid-email');
  return email;
}

export function parsePurpose(raw: unknown): Purpose {
  if (raw === 'register' || raw === 'reset') return raw;
  throw new FlowError('invalid-input', { field: 'purpose' });
}

/** Optional; defaults to English. */
export function parseLanguage(raw: unknown): Language {
  if (raw === undefined || raw === null) return 'en';
  if (raw === 'en' || raw === 'am') return raw;
  throw new FlowError('invalid-input', { field: 'language' });
}

/** A six-digit string. Anything else is simply a wrong code (no attempt is counted). */
export function parseCode(raw: unknown): string {
  if (typeof raw !== 'string') throw new FlowError('invalid-code');
  const code = raw.trim();
  if (!/^[0-9]{6}$/.test(code)) throw new FlowError('invalid-code');
  return code;
}

/** True if the password has 8-128 characters, at least one letter and one digit. */
export function isStrongPassword(password: string): boolean {
  return (
    password.length >= PASSWORD_MIN &&
    password.length <= PASSWORD_MAX &&
    /\p{L}/u.test(password) &&
    /[0-9]/.test(password)
  );
}

export function parsePassword(raw: unknown): string {
  if (typeof raw !== 'string') throw new FlowError('invalid-input', { field: 'password' });
  if (!isStrongPassword(raw)) throw new FlowError('weak-password');
  return raw;
}

/** Optional display name: trimmed, 1-80 characters; blank means none. */
export function parseName(raw: unknown): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'string') throw new FlowError('invalid-input', { field: 'name' });
  const name = raw.trim();
  if (name.length === 0) return undefined;
  if (name.length > NAME_MAX) throw new FlowError('invalid-input', { field: 'name' });
  return name;
}

/** The callable's `data` must be a plain object. */
export function asObject(data: unknown): Record<string, unknown> {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) throw new FlowError('invalid-input');
  return data as Record<string, unknown>;
}
