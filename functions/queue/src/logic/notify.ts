/**
 * Tells a remote customer they are next: an in-app inbox entry at
 * users/{uid}/notifications/{id} (same shape the notifications codebase
 * writes) and, only if that entry was new, a push to their devices.
 */
import type { QueueEntry } from './estimate';
import { queueNextNotificationId } from './recompute';
import { QUEUE_NEXT_TYPE, normalizeLanguage, renderQueueNext } from './templates';

export interface InboxDoc {
  title: string;
  body: string;
  type: string;
  shopId: string;
  queueEntryId: string;
  read: boolean;
  createdAt: string;
}

export interface NotifyPorts {
  /** users/{uid}.language (anything; normalized here). */
  userLanguage(uid: string): Promise<unknown>;
  /** create(); false when the doc already exists (a retry or a later recompute). */
  createInbox(uid: string, id: string, doc: InboxDoc): Promise<boolean>;
  sendPush(uid: string, message: { title: string; body: string }, data: Record<string, string>): Promise<void>;
}

export type NotifyOutcome = 'sent' | 'duplicate' | 'skipped';

export async function notifyQueueNext(
  shopId: string,
  shopName: string | null,
  entry: QueueEntry,
  now: Date,
  ports: NotifyPorts,
): Promise<NotifyOutcome> {
  const uid = entry.addedBy;
  if (entry.source !== 'remote' || !uid || entry.status !== 'waiting') return 'skipped';
  const language = normalizeLanguage(await ports.userLanguage(uid), 'en');
  const message = renderQueueNext(language, shopName);
  const id = queueNextNotificationId(entry.id, entry.createdAt);
  const created = await ports.createInbox(uid, id, {
    ...message,
    type: QUEUE_NEXT_TYPE,
    shopId,
    queueEntryId: entry.id,
    read: false,
    createdAt: now.toISOString(),
  });
  if (!created) return 'duplicate';
  await ports.sendPush(uid, message, { type: QUEUE_NEXT_TYPE, notificationId: id, shopId, queueEntryId: entry.id });
  return 'sent';
}
