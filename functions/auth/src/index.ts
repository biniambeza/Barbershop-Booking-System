/**
 * Crown & Blade auth codebase: email + password accounts verified by a
 * 6-digit code sent by email.
 *
 *  - requestEmailCode({email, purpose: 'register'|'reset', language?})
 *      -> {ok, resendAfterSeconds: 60, expiresInSeconds: 600}
 *  - completeEmailRegistration({email, code, password, name?}) -> {ok}
 *      creates a verified email/password Auth user. The app then signs in
 *      with signInWithEmailAndPassword and runs its normal profile setup
 *      (users/{uid}, invites) - this function does not touch users/*.
 *  - resetPasswordWithCode({email, code, newPassword}) -> {ok}
 *      sets the password and revokes existing sessions.
 *  - cleanupEmailCodes (daily, 04:30 Addis): deletes expired emailCodes and
 *    authRateLimits documents.
 *
 * Errors are HttpsErrors whose details.code is one of the codes in
 * src/logic/errors.ts. Codes are stored only as salted SHA-256 hashes in
 * emailCodes/{purpose}_{sha256(email)}; send counters live in
 * authRateLimits/{email_|ip_}{sha256}. Both collections are closed to
 * clients by firestore.rules.
 *
 * Email goes out over SMTP using the secrets SMTP_HOST, SMTP_PORT,
 * SMTP_USER, SMTP_PASS and MAIL_FROM (see readme.md).
 */
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { DocumentReference, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { sweepExpired } from './logic/cleanup';
import type { CodeDoc } from './logic/codes';
import { FlowError } from './logic/errors';
import type { RateDoc } from './logic/rateLimit';
import {
  AuthStore,
  AuthUsers,
  completeEmailRegistration as completeRegistrationFlow,
  Deps,
  Mailer,
  requestEmailCode as requestCodeFlow,
  resetPasswordWithCode as resetPasswordFlow,
} from './logic/service';
import { smtpConfigFrom, smtpMailer } from './mailer';

const REGION = 'europe-west1';

initializeApp();
setGlobalOptions({ region: REGION, maxInstances: 10 });

const SMTP_HOST = defineSecret('SMTP_HOST');
const SMTP_PORT = defineSecret('SMTP_PORT');
const SMTP_USER = defineSecret('SMTP_USER');
const SMTP_PASS = defineSecret('SMTP_PASS');
const MAIL_FROM = defineSecret('MAIL_FROM');

const db = () => getFirestore();
const codeRef = (id: string) => db().doc(`emailCodes/${id}`);
const rateRef = (key: string) => db().doc(`authRateLimits/${key}`);

const store: AuthStore = {
  run(fn) {
    return db().runTransaction((tx) =>
      fn({
        async getCode(id) {
          const snap = await tx.get(codeRef(id));
          return snap.exists ? (snap.data() as CodeDoc) : null;
        },
        async getRate(key) {
          const snap = await tx.get(rateRef(key));
          return snap.exists ? (snap.data() as RateDoc) : null;
        },
        setCode(id, doc) {
          tx.set(codeRef(id), doc);
        },
        setCodeAttempts(id, attempts) {
          tx.update(codeRef(id), { attempts });
        },
        deleteCode(id) {
          tx.delete(codeRef(id));
        },
        setRate(key, doc) {
          tx.set(rateRef(key), doc);
        },
      }),
    );
  },
  async deleteCode(id) {
    await codeRef(id).delete();
  },
};

const authCode = (e: unknown): string =>
  typeof e === 'object' && e !== null && 'code' in e ? String((e as { code: unknown }).code) : '';

const users: AuthUsers = {
  async findByEmail(email) {
    try {
      const u = await getAuth().getUserByEmail(email);
      return { uid: u.uid, providerIds: u.providerData.map((p) => p.providerId) };
    } catch (e) {
      if (authCode(e) === 'auth/user-not-found') return null;
      throw e;
    }
  },
  async create({ email, password, displayName }) {
    try {
      await getAuth().createUser({ email, password, emailVerified: true, ...(displayName ? { displayName } : {}) });
      return 'created';
    } catch (e) {
      if (authCode(e) === 'auth/email-already-exists') return 'exists';
      throw e;
    }
  },
  async setPassword(uid, password) {
    await getAuth().updateUser(uid, { password });
  },
  async revokeSessions(uid) {
    await getAuth().revokeRefreshTokens(uid);
  },
};

function deps(withMailer: boolean): Deps {
  let mailer: Mailer | null = null;
  if (withMailer) {
    const { config, missing } = smtpConfigFrom({
      SMTP_HOST: SMTP_HOST.value(),
      SMTP_PORT: SMTP_PORT.value(),
      SMTP_USER: SMTP_USER.value(),
      SMTP_PASS: SMTP_PASS.value(),
      MAIL_FROM: MAIL_FROM.value(),
    });
    if (config) mailer = smtpMailer(config);
    else logger.error('email codes: missing SMTP secrets - set them with `firebase functions:secrets:set`', { missing });
  }
  return { store, users, mailer, log: logger };
}

function callerIp(req: CallableRequest): string | null {
  const raw = req.rawRequest;
  const ip = raw?.ip || String(raw?.headers?.['x-forwarded-for'] ?? '').split(',')[0].trim();
  return ip ? ip : null;
}

/** Maps flow errors to HttpsError with details.code; hides anything else. */
async function handle<T>(name: string, run: () => Promise<T>): Promise<T> {
  try {
    return await run();
  } catch (e) {
    if (e instanceof FlowError) throw new HttpsError(e.status, e.message, { code: e.code, ...e.details });
    logger.error(`${name} failed`, { error: e instanceof Error ? e.stack ?? e.message : String(e) });
    throw new HttpsError('internal', 'Something went wrong. Try again.', { code: 'internal' });
  }
}

const callableOptions = { enforceAppCheck: false, timeoutSeconds: 30 };

export const requestEmailCode = onCall(
  { ...callableOptions, secrets: [SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM] },
  (req) => handle('requestEmailCode', () => requestCodeFlow(deps(true), req.data, callerIp(req))),
);

export const completeEmailRegistration = onCall(callableOptions, (req) =>
  handle('completeEmailRegistration', () => completeRegistrationFlow(deps(false), req.data)),
);

export const resetPasswordWithCode = onCall(callableOptions, (req) =>
  handle('resetPasswordWithCode', () => resetPasswordFlow(deps(false), req.data)),
);

export const cleanupEmailCodes = onSchedule(
  { schedule: 'every day 04:30', timeZone: 'Africa/Addis_Ababa', retryCount: 2, timeoutSeconds: 540 },
  async () => {
    const result = await sweepExpired<DocumentReference>(new Date(), {
      async fetchExpired(collection, nowIso, limit) {
        const snap = await db().collection(collection).where('expiresAt', '<', nowIso).limit(limit).select().get();
        return snap.docs.map((d) => d.ref);
      },
      async deleteAll(refs) {
        const batch = db().batch();
        for (const ref of refs) batch.delete(ref);
        await batch.commit();
      },
    });
    logger.info('expired email codes and rate limits deleted', result);
  },
);
