/**
 * Shop applications (shopApplications/{uid}): the applicant hears about the
 * admin's decision (inbox + push, no SMS).
 *
 *   pending -> approved   'applicationApproved'  (carries shopId)
 *   pending -> rejected   'applicationRejected'  (carries the reason)
 *
 * Paths touched (Admin SDK):
 *   read   users/{uid}                                   (language)
 *   read   users/{uid}/devices/*                         (FCM tokens, via sendPush)
 *   delete users/{uid}/devices/{deviceId}                (tokens FCM rejects)
 *   create users/{uid}/notifications/application_{reviewedAtMs}_{type}
 *          {title, body, type, shopId?, read: false, createdAt}
 *
 * The inbox id includes the review time, so a resubmitted application that
 * is decided again gets a new notification, while retries are no-ops.
 */

import type { Firestore, DocumentData } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import { sendPush } from './dispatch';
import { APP_NAME, normalizeLanguage, type Language, type RenderedMessage } from './templates';

export type ApplicationEvent = 'applicationApproved' | 'applicationRejected';

export interface ShopApplicationDoc {
  uid?: string;
  email?: string;
  ownerName?: string;
  shopName?: string;
  status?: string;
  reviewedBy?: string;
  reviewedAt?: string;
  shopId?: string;
  rejectReason?: string;
  [key: string]: unknown;
}

/**
 * The decision, if this write made one: the status changed to 'approved' or
 * 'rejected' (create/delete/edits and unchanged status are silent).
 */
export function detectApplicationEvent(
  before: ShopApplicationDoc | undefined | null,
  after: ShopApplicationDoc | undefined | null,
): ApplicationEvent | null {
  if (!after) return null;
  if (before && before.status === after.status) return null;
  if (after.status === 'approved') return 'applicationApproved';
  if (after.status === 'rejected') return 'applicationRejected';
  return null;
}

/** Inbox doc id: one per decision (`application_{reviewedAtMs}_{type}`). */
export function applicationNotificationId(after: ShopApplicationDoc, type: ApplicationEvent): string {
  const ms = typeof after.reviewedAt === 'string' ? Date.parse(after.reviewedAt) : NaN;
  return `application_${Number.isNaN(ms) ? 0 : ms}_${type}`;
}

export function renderApplicationNotification(
  type: ApplicationEvent,
  lang: Language,
  app: ShopApplicationDoc,
): RenderedMessage {
  const shop = (app.shopName || '').trim() || (lang === 'am' ? 'ሱቅዎ' : 'your shop');
  const reason = (app.rejectReason || '').trim();
  if (type === 'applicationApproved') {
    return lang === 'am'
      ? {
          title: 'የሱቅ ማመልከቻዎ ጸድቋል',
          body: `${shop} በ${APP_NAME} ላይ ተመዝግቧል። የባለቤት ዳሽቦርድዎን ለመክፈት መተግበሪያውን ይክፈቱ።`,
        }
      : {
          title: 'Your shop application was approved',
          body: `${shop} is now on ${APP_NAME}. Open the app to manage it from your owner dashboard.`,
        };
  }
  if (lang === 'am') {
    return {
      title: 'የሱቅ ማመልከቻዎ አልጸደቀም',
      body: reason
        ? `ለ${shop} ያቀረቡት ማመልከቻ አልጸደቀም። ምክንያት፦ ${reason}`
        : `ለ${shop} ያቀረቡት ማመልከቻ አልጸደቀም።`,
    };
  }
  return {
    title: 'Your shop application was not approved',
    body: reason
      ? `Your application for ${shop} was not approved. Reason: ${reason}`
      : `Your application for ${shop} was not approved.`,
  };
}

function isAlreadyExists(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  return code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

/**
 * Inbox entry + push to the applicant (`uid` = the document id). Returns
 * false when the inbox entry already existed (retry) or the user is gone.
 */
export async function notifyApplication(
  db: Firestore,
  uid: string,
  after: ShopApplicationDoc,
  type: ApplicationEvent,
): Promise<boolean> {
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) return false;
  const user = userSnap.data() as DocumentData;
  const msg = renderApplicationNotification(type, normalizeLanguage(user.language, 'en'), after);
  const id = applicationNotificationId(after, type);
  const links: Record<string, string> = {};
  if (type === 'applicationApproved' && typeof after.shopId === 'string' && after.shopId) links.shopId = after.shopId;
  try {
    await db.collection('users').doc(uid).collection('notifications').doc(id).create({
      title: msg.title,
      body: msg.body,
      type,
      ...links,
      read: false,
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    if (isAlreadyExists(err)) return false;
    throw err;
  }
  try {
    await sendPush(db, uid, msg, { type, notificationId: id, ...links });
  } catch (err) {
    logger.warn('push failed', { uid, type, err: String(err) });
  }
  return true;
}
