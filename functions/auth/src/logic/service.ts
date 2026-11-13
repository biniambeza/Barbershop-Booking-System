/**
 * The three email-code flows, written against small ports (store, users,
 * mailer) so they can be tested with in-memory fakes.
 */
import { buildCodeDoc, checkCode, CODE_TTL_SECONDS, codeDocId, CodeDoc, generateCode } from './codes';
import { FlowError } from './errors';
import {
  asObject,
  normalizeEmail,
  parseCode,
  parseLanguage,
  parseName,
  parsePassword,
  parsePurpose,
  Purpose,
} from './input';
import {
  bumpWindow,
  cooldownRemaining,
  DAY_MS,
  EMAIL_SENDS_PER_DAY,
  emailRateKey,
  HOUR_MS,
  IP_SENDS_PER_HOUR,
  ipRateKey,
  RateDoc,
  RESEND_COOLDOWN_SECONDS,
} from './rateLimit';
import { buildCodeEmail, EmailMessage } from './templates';

/** One Firestore transaction attempt: all reads before writes. */
export interface AuthTx {
  getCode(id: string): Promise<CodeDoc | null>;
  getRate(key: string): Promise<RateDoc | null>;
  setCode(id: string, doc: CodeDoc): void;
  setCodeAttempts(id: string, attempts: number): void;
  deleteCode(id: string): void;
  setRate(key: string, doc: RateDoc): void;
}

export interface AuthStore {
  run<T>(fn: (tx: AuthTx) => Promise<T>): Promise<T>;
  deleteCode(id: string): Promise<void>;
}

export interface UserRecordLite {
  uid: string;
  providerIds: string[];
}

export interface AuthUsers {
  findByEmail(email: string): Promise<UserRecordLite | null>;
  /** Creates a verified email/password user; 'exists' if the email is taken. */
  create(user: { email: string; password: string; displayName?: string }): Promise<'created' | 'exists'>;
  setPassword(uid: string, password: string): Promise<void>;
  revokeSessions(uid: string): Promise<void>;
}

export interface Mailer {
  send(to: string, message: EmailMessage): Promise<void>;
}

export interface Logger {
  info(msg: string, data?: Record<string, unknown>): void;
  warn(msg: string, data?: Record<string, unknown>): void;
  error(msg: string, data?: Record<string, unknown>): void;
}

export interface Deps {
  store: AuthStore;
  users: AuthUsers;
  /** null when the SMTP secrets are missing. */
  mailer: Mailer | null;
  now?: () => Date;
  randomCode?: () => string;
  log?: Logger;
}

const silent: Logger = { info() {}, warn() {}, error() {} };

export interface RequestCodeResult {
  ok: true;
  resendAfterSeconds: number;
  expiresInSeconds: number;
}

export async function requestEmailCode(deps: Deps, data: unknown, ip: string | null): Promise<RequestCodeResult> {
  const input = asObject(data);
  const email = normalizeEmail(input.email);
  const purpose = parsePurpose(input.purpose);
  const language = parseLanguage(input.language);
  const log = deps.log ?? silent;
  const now = (deps.now ?? (() => new Date()))();

  if (!deps.mailer) {
    log.error('email codes: SMTP secrets are not configured (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM)');
    throw new FlowError('email-not-configured');
  }

  const user = await deps.users.findByEmail(email);
  if (purpose === 'register' && user) throw new FlowError('email-already-registered');
  // Reset: same answer whether or not the account exists; mail only real
  // email/password accounts (Google-only accounts get nothing).
  const shouldSend = purpose === 'register' || (user !== null && user.providerIds.includes('password'));

  const id = codeDocId(purpose, email);
  const code = (deps.randomCode ?? generateCode)();
  await deps.store.run(async (tx) => {
    const existing = await tx.getCode(id);
    const emailKey = emailRateKey(email);
    const ipKey = ip ? ipRateKey(ip) : null;
    const emailRate = await tx.getRate(emailKey);
    const ipRate = ipKey ? await tx.getRate(ipKey) : null;

    const wait = cooldownRemaining(existing?.lastSentAt, now);
    if (wait > 0) throw new FlowError('too-soon', { retryAfterSeconds: wait });

    const byEmail = bumpWindow(emailRate, now, DAY_MS, EMAIL_SENDS_PER_DAY);
    const byIp = ipKey ? bumpWindow(ipRate, now, HOUR_MS, IP_SENDS_PER_HOUR) : null;
    if (!byEmail.allowed || (byIp && !byIp.allowed)) {
      const retryAfterSeconds = Math.max(byEmail.retryAfterSeconds, byIp?.retryAfterSeconds ?? 0);
      throw new FlowError('rate-limited', { retryAfterSeconds });
    }

    tx.setRate(emailKey, byEmail.next);
    if (ipKey && byIp) tx.setRate(ipKey, byIp.next);
    tx.setCode(id, buildCodeDoc(purpose, email, code, now));
  });

  if (shouldSend) {
    try {
      await deps.mailer.send(email, buildCodeEmail(purpose, language, code));
    } catch (e) {
      log.error('email codes: sending failed', { purpose, error: String(e) });
      // Let the person retry straight away (the send counters stay used).
      await deps.store.deleteCode(id).catch(() => undefined);
      throw new FlowError('email-send-failed');
    }
  }
  log.info('email code issued', { purpose, sent: shouldSend });
  return { ok: true, resendAfterSeconds: RESEND_COOLDOWN_SECONDS, expiresInSeconds: CODE_TTL_SECONDS };
}

/** Checks and consumes the code in one transaction (single use). */
async function consumeCode(deps: Deps, purpose: Purpose, email: string, code: string): Promise<void> {
  const now = (deps.now ?? (() => new Date()))();
  const id = codeDocId(purpose, email);
  // Wrong attempts must be stored even though the call then fails, so the
  // transaction returns the outcome and the error is thrown afterwards.
  const outcome = await deps.store.run(async (tx) => {
    const doc = await tx.getCode(id);
    const check = checkCode(doc, purpose, code, now);
    if (check.result === 'ok' || (check.result === 'expired' && doc)) tx.deleteCode(id);
    if (check.result === 'wrong') tx.setCodeAttempts(id, check.attempts);
    return check;
  });
  if (outcome.result === 'expired') throw new FlowError('code-expired');
  if (outcome.result === 'wrong') throw new FlowError('invalid-code', { attemptsLeft: outcome.attemptsLeft });
}

export async function completeEmailRegistration(deps: Deps, data: unknown): Promise<{ ok: true }> {
  const input = asObject(data);
  const email = normalizeEmail(input.email);
  const code = parseCode(input.code);
  const password = parsePassword(input.password);
  const name = parseName(input.name);

  await consumeCode(deps, 'register', email, code);
  const created = await deps.users.create({ email, password, displayName: name });
  if (created === 'exists') throw new FlowError('email-already-registered');
  (deps.log ?? silent).info('email account registered');
  return { ok: true };
}

export async function resetPasswordWithCode(deps: Deps, data: unknown): Promise<{ ok: true }> {
  const input = asObject(data);
  const email = normalizeEmail(input.email);
  const code = parseCode(input.code);
  const password = parsePassword(input.newPassword);

  await consumeCode(deps, 'reset', email, code);
  const user = await deps.users.findByEmail(email);
  if (!user) throw new FlowError('invalid-code', { attemptsLeft: 0 });
  await deps.users.setPassword(user.uid, password);
  await deps.users.revokeSessions(user.uid);
  (deps.log ?? silent).info('password reset with email code', { uid: user.uid });
  return { ok: true };
}
