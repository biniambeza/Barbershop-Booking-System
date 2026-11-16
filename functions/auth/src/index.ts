/**
 * Crown & Blade auth codebase: email + password accounts verified by a
 * 6-digit code sent by email. App order: email -> code (verifyEmailCode) ->
 * password (completeEmailRegistration / resetPasswordWithCode with the token).
 *
 *  - requestEmailCode({email, purpose: 'register'|'reset', language?})
 *      -> {ok, resendAfterSeconds: 60, expiresInSeconds: 600}
 *  - verifyEmailCode({email, code, purpose}) -> {ok, verificationToken, expiresInSeconds: 900}
 *      checks the code without using it up and marks it verified; the
 *      token then finishes one of the two flows below within 15 minutes.
 *  - completeEmailRegistration({email, code | verificationToken, password, name?}) -> {ok}
 *      creates a verified email/password Auth user. The app then signs in
 *      with signInWithEmailAndPassword and runs its normal profile setup
 *      (users/{uid}, invites) - this function does not touch users/*.
 *  - resetPasswordWithCode({email, code | verificationToken, newPassword}) -> {ok}
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
 * onInviteCreated (Firestore trigger on invites/{email}) emails the invited
 * person how to register (bilingual, see src/logic/inviteEmail.ts). One
 * email per invite document: inviteEmails/{email}_{createdAt} is created
 * before sending (closed to clients by firestore.rules).
 *
 * onUserDisabledChanged (Firestore trigger on users/{uid} writes, Blaze
 * only) mirrors the admin's users/{uid}.disabled flag to Firebase Auth:
 * disabled -> Auth user disabled + refresh tokens revoked; enabled again ->
 * Auth user enabled. See src/logic/accountDisable.ts.
 *
 * onShopDeleted (Firestore trigger on barbershops/{shopId} delete, Blaze
 * only) repeats the admin app's shop-deletion cascade idempotently and
 * deletes the logins the owner created for barbers (password-only accounts
 * whose email was never verified). See src/logic/shopDeletion.ts.
 *
 * onUserProfileDeleted (Firestore trigger on users/{uid} delete, Blaze
 * only) finishes an in-app account deletion on the server: it cancels the
 * person's upcoming bookings the app could not (inside the cutoff; paid
 * ones get their refund flag), anonymises the rest of their bookings and
 * reviews, removes a deleted barber's profile tree (portfolio photos, time
 * off, slot locks) and Storage photos, and deletes leftover personal
 * documents. See src/logic/accountDeletion.ts. On Spark the app does all it
 * can without it.
 *
 * Email goes out over SMTP using the secrets SMTP_HOST, SMTP_PORT,
 * SMTP_USER, SMTP_PASS and MAIL_FROM (see readme.md).
 */
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { DocumentReference, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { logger, setGlobalOptions } from 'firebase-functions/v2';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentDeleted, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { authDisableAction, mirrorDisabledToAuth } from './logic/accountDisable'; // admin users
import { getStorage } from 'firebase-admin/storage'; // account deletion
import {
  AccountDeletionStore,
  BookingRow,
  cleanupDeletedAccount,
  DeletedProfile,
  FORMER_CUSTOMER_NAME,
} from './logic/accountDeletion'; // account deletion
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { sweepExpired } from './logic/cleanup';
import { cascadeShopDeletion, SHOP_DELETED_REASON, SHOP_DELETIONS_COLLECTION, ShopDeletionStore } from './logic/shopDeletion';
import type { CodeDoc } from './logic/codes';
import { FlowError } from './logic/errors';
import { buildInviteEmail, inviteEmailDocId, isInviteRole } from './logic/inviteEmail';
import type { RateDoc } from './logic/rateLimit';
import {
  AuthStore,
  AuthUsers,
  completeEmailRegistration as completeRegistrationFlow,
  Deps,
  Mailer,
  requestEmailCode as requestCodeFlow,
  resetPasswordWithCode as resetPasswordFlow,
  verifyEmailCode as verifyCodeFlow,
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
        updateCode(id, patch) {
          tx.update(codeRef(id), patch);
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

function configuredMailer(context: string): Mailer | null {
  const { config, missing } = smtpConfigFrom({
    SMTP_HOST: SMTP_HOST.value(),
    SMTP_PORT: SMTP_PORT.value(),
    SMTP_USER: SMTP_USER.value(),
    SMTP_PASS: SMTP_PASS.value(),
    MAIL_FROM: MAIL_FROM.value(),
  });
  if (config) return smtpMailer(config);
  logger.error(`${context}: missing SMTP secrets - set them with \`firebase functions:secrets:set\``, { missing });
  return null;
}

function deps(withMailer: boolean): Deps {
  return { store, users, mailer: withMailer ? configuredMailer('email codes') : null, log: logger };
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

export const verifyEmailCode = onCall(callableOptions, (req) =>
  handle('verifyEmailCode', () => verifyCodeFlow(deps(false), req.data)),
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

const str = (v: unknown): string | null => (typeof v === 'string' && v.trim() !== '' ? v : null);

export const onInviteCreated = onDocumentCreated(
  { document: 'invites/{email}', secrets: [SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM], timeoutSeconds: 60 },
  async (event) => {
    const invite = event.data?.data();
    const email = event.params.email;
    if (!invite || !isInviteRole(invite.role) || invite.email !== email) {
      logger.warn('invite email: skipped (not a valid invite)', { role: invite?.role ?? null });
      return;
    }
    const mailer = configuredMailer('invite email');
    if (!mailer) return; // logged above; nothing is recorded so a later invite can still be emailed

    const [shopSnap, inviterSnap] = await Promise.all([
      str(invite.shopId) ? db().doc(`barbershops/${invite.shopId}`).get() : Promise.resolve(null),
      str(invite.createdBy) ? db().doc(`users/${invite.createdBy}`).get() : Promise.resolve(null),
    ]);
    const message = buildInviteEmail({
      role: invite.role,
      email,
      shopName: str(shopSnap?.get('name')),
      inviterName: str(inviterSnap?.get('name')),
      inviterLanguage: str(inviterSnap?.get('language')),
    });

    // Idempotency: claim the marker first; a retry or duplicate event finds it.
    const marker = db().doc(`inviteEmails/${inviteEmailDocId(email, invite.createdAt)}`);
    try {
      await marker.create({ role: invite.role, shopId: str(invite.shopId), status: 'sending', createdAt: new Date().toISOString() });
    } catch (e) {
      if (authCode(e) === '6' || /already exists/i.test(String(e))) {
        logger.info('invite email: already sent for this invite', { role: invite.role });
        return;
      }
      throw e;
    }
    try {
      await mailer.send(email, message);
    } catch (e) {
      await marker.delete().catch(() => undefined); // let a retry send it
      logger.error('invite email: sending failed', { role: invite.role, error: String(e) });
      throw e;
    }
    await marker.update({ status: 'sent', sentAt: new Date().toISOString() });
    logger.info('invite email sent', { role: invite.role, eventId: event.id });
  },
);

// --- shop deletion ---
const shopDeletionStore: ShopDeletionStore = {
  async getRecord(shopId) {
    const snap = await db().doc(`${SHOP_DELETIONS_COLLECTION}/${shopId}`).get();
    return snap.exists ? (snap.data() as { shopName?: string; staffUids?: string[]; barberAccountUids?: string[] }) : null;
  },
  async upcomingBookings(shopId, nowIso) {
    const snap = await db().collection('bookings').where('shopId', '==', shopId).where('startAt', '>=', nowIso).get();
    return snap.docs.map((d) => ({ id: d.id, ...(d.data() as Record<string, string>) }));
  },
  async cancelBookings(items) {
    const batch = db().batch();
    for (const { bookingId, notice } of items) {
      batch.update(db().doc(`bookings/${bookingId}`), {
        status: 'cancelled',
        cancelledBy: 'system',
        cancelReason: SHOP_DELETED_REASON,
      });
      batch.set(db().doc(`users/${notice.uid}/notifications/${notice.id}`), notice.doc);
    }
    await batch.commit();
  },
  async usersOfShop(shopId) {
    const snap = await db().collection('users').where('shopId', '==', shopId).get();
    return snap.docs.map((d) => ({ uid: d.id, ...(d.data() as Record<string, string>) }));
  },
  async getUsers(uids) {
    if (uids.length === 0) return [];
    const snaps = await db().getAll(...uids.map((uid) => db().doc(`users/${uid}`)));
    return snaps.filter((s) => s.exists).map((s) => ({ uid: s.id, ...(s.data() as Record<string, string>) }));
  },
  async downgrade(items) {
    const batch = db().batch();
    for (const { uid, notice } of items) {
      batch.update(db().doc(`users/${uid}`), {
        role: 'customer',
        shopId: FieldValue.delete(),
        barberId: FieldValue.delete(),
      });
      batch.set(db().doc(`users/${notice.uid}/notifications/${notice.id}`), notice.doc);
    }
    await batch.commit();
  },
  async invitesOfShop(shopId) {
    const snap = await db().collection('invites').where('shopId', '==', shopId).get();
    return snap.docs.map((d) => ({ email: d.id, role: d.get('role'), authUid: d.get('authUid') }));
  },
  async deleteInvites(emails) {
    for (let i = 0; i < emails.length; i += 400) {
      const batch = db().batch();
      for (const email of emails.slice(i, i + 400)) batch.delete(db().doc(`invites/${email}`));
      await batch.commit();
    }
  },
  async deleteShopTree(shopId) {
    // Deletes every descendant of the (already deleted) shop document.
    await db().recursiveDelete(db().doc(`barbershops/${shopId}`));
  },
  async getAuthAccount(uid) {
    try {
      const u = await getAuth().getUser(uid);
      return { uid: u.uid, emailVerified: u.emailVerified, providerIds: u.providerData.map((p) => p.providerId) };
    } catch (e) {
      if (authCode(e) === 'auth/user-not-found') return null;
      throw e;
    }
  },
  async deleteAuthAccount(uid) {
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      if (authCode(e) !== 'auth/user-not-found') throw e;
    }
  },
  async deleteUserProfile(uid) {
    await db().recursiveDelete(db().doc(`users/${uid}`));
  },
  async markDone(shopId, result, nowIso) {
    await db()
      .doc(`${SHOP_DELETIONS_COLLECTION}/${shopId}`)
      .set(
        {
          shopId,
          serverCleanupAt: nowIso,
          ...(result.deletedLogins.length > 0 ? { deletedLogins: FieldValue.arrayUnion(...result.deletedLogins) } : {}),
        },
        { merge: true },
      );
  },
};

export const onShopDeleted = onDocumentDeleted({ document: 'barbershops/{shopId}', timeoutSeconds: 540, retry: true }, async (event) => {
  const shopId = event.params.shopId;
  const name = event.data?.get('name');
  const result = await cascadeShopDeletion(shopId, typeof name === 'string' ? name : undefined, shopDeletionStore, new Date());
  logger.info('shop deletion cascade done', {
    shopId,
    cancelledBookings: result.cancelledBookings,
    downgradedStaff: result.downgradedStaff,
    deletedInvites: result.deletedInvites,
    deletedLogins: result.deletedLogins.length,
  });
});
// --- end shop deletion ---

// --- admin users ---
// Blaze only: mirrors users/{uid}.disabled (written by an admin) to
// Firebase Auth. Spark: the app and firestore.rules enforce it alone.
export const onUserDisabledChanged = onDocumentWritten({ document: 'users/{uid}', retry: true }, async (event) => {
  const uid = event.params.uid;
  const action = authDisableAction(event.data?.before?.data(), event.data?.after?.data());
  if (action === 'none') return;
  const done = await mirrorDisabledToAuth(uid, action, {
    setDisabled: async (id, disabled) => {
      await getAuth().updateUser(id, { disabled });
    },
    revokeRefreshTokens: (id) => getAuth().revokeRefreshTokens(id),
  });
  logger.info('account disabled flag mirrored to Auth', { action: done });
});
// --- end admin users ---

// --- account deletion ---
// Blaze only: finishes an in-app account deletion (Settings > Delete
// account) when users/{uid} is deleted. Spark: the app does it alone.
const accountDeletionStore: AccountDeletionStore = {
  async bookingsOfCustomer(uid) {
    const snap = await db().collection('bookings').where('customerId', '==', uid).get();
    return snap.docs.map((d) => ({ ...(d.data() as Omit<BookingRow, 'id'>), id: d.id }));
  },
  async upcomingBookingsOfBarber(shopId, barberId, nowIso) {
    // Index shopId + barberId + startAt (firestore.indexes.json).
    const snap = await db()
      .collection('bookings')
      .where('shopId', '==', shopId)
      .where('barberId', '==', barberId)
      .where('startAt', '>=', nowIso)
      .get();
    return snap.docs.map((d) => ({ ...(d.data() as Omit<BookingRow, 'id'>), id: d.id }));
  },
  async cutoffHours(shopId) {
    const snap = await db().doc(`barbershops/${shopId}`).get();
    if (!snap.exists) return null;
    const v = snap.get('cancellationCutoffHours');
    return typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : 2;
  },
  async languageOf(uid) {
    const snap = await db().doc(`users/${uid}`).get();
    const v = snap.get('language');
    return typeof v === 'string' ? v : undefined;
  },
  async updateBooking(bookingId, plan) {
    const ref = db().doc(`bookings/${bookingId}`);
    return db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? ({ ...(snap.data() as Omit<BookingRow, 'id'>), id: snap.id } as BookingRow) : null;
      const write = plan(current);
      if (!write || !current) return false;
      let locks: DocumentReference[] = [];
      if (write.releaseLocks && typeof current.shopId === 'string' && typeof current.barberId === 'string') {
        const lockSnap = await tx.get(
          db().collection(`barbershops/${current.shopId}/barbers/${current.barberId}/slotLocks`).where('bookingId', '==', bookingId),
        );
        locks = lockSnap.docs.map((d) => d.ref);
      }
      tx.update(ref, write.fields);
      for (const lock of locks) tx.delete(lock);
      for (const n of write.notices) tx.set(db().doc(`users/${n.uid}/notifications/${n.id}`), n.doc);
      return true;
    });
  },
  async anonymizeReview(shopId, bookingId, uid) {
    const ref = db().doc(`barbershops/${shopId}/reviews/${bookingId}`);
    return db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.get('customerId') !== uid) return false;
      if (snap.get('customerName') === FORMER_CUSTOMER_NAME && snap.get('comment') === undefined) return false;
      tx.update(ref, { customerName: FORMER_CUSTOMER_NAME, comment: FieldValue.delete() });
      return true;
    });
  },
  async otherProfilesOfBarber(shopId, barberId, uid) {
    const snap = await db().collection('users').where('barberId', '==', barberId).get();
    return snap.docs.filter((d) => d.id !== uid && d.get('shopId') === shopId).length;
  },
  async deleteBarberTree(shopId, barberId) {
    await db().recursiveDelete(db().doc(`barbershops/${shopId}/barbers/${barberId}`));
  },
  async deletePortfolioFiles(shopId, barberId) {
    try {
      const bucket = getStorage().bucket();
      const [files] = await bucket.getFiles({ prefix: `portfolio/${shopId}/${barberId}/` });
      await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
      return files.length;
    } catch (e) {
      // No default bucket (Storage not set up): nothing to delete.
      logger.warn('account deletion: portfolio files not deleted', { error: String(e) });
      return 0;
    }
  },
  async deletePersonalData(uid, email) {
    if (email) await db().doc(`invites/${email}`).delete();
    const application = db().doc(`shopApplications/${uid}`);
    const app = await application.get();
    if (app.exists && app.get('status') !== 'approved') await application.delete();
    await db().doc(`shopRemovalRequests/${uid}`).delete();
    // The profile is gone; this removes its inbox and device tokens.
    await db().recursiveDelete(db().doc(`users/${uid}`));
  },
};

export const onUserProfileDeleted = onDocumentDeleted({ document: 'users/{uid}', timeoutSeconds: 540, retry: true }, async (event) => {
  const uid = event.params.uid;
  const profile = (event.data?.data() ?? null) as DeletedProfile | null;
  const result = await cleanupDeletedAccount(uid, profile, accountDeletionStore, new Date());
  logger.info('account deletion clean-up done', { ...result });
});
// --- end account deletion ---
