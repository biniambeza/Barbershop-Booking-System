import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { QueueEntry } from '../src/logic/estimate';
import { notifyQueueNext, type InboxDoc } from '../src/logic/notify';
import { QUEUE_NEXT_TYPE, normalizeLanguage, renderQueueNext } from '../src/logic/templates';

const NOW = new Date('2026-11-13T08:00:00.000Z');

test('language codes', () => {
  assert.equal(normalizeLanguage('am'), 'am');
  assert.equal(normalizeLanguage('am_ET'), 'am');
  assert.equal(normalizeLanguage('EN-us'), 'en');
  assert.equal(normalizeLanguage('fr'), 'en');
  assert.equal(normalizeLanguage(undefined, 'am'), 'am');
});

test('English and Amharic texts name the shop', () => {
  const en = renderQueueNext('en', 'Fendika Cuts');
  assert.equal(en.title, "You're next");
  assert.match(en.body, /Fendika Cuts/);
  const am = renderQueueNext('am', 'Fendika Cuts');
  assert.match(am.body, /Fendika Cuts/);
  assert.match(am.title, /ቀጣዩ/);
  assert.doesNotMatch(am.body, /next/);
  assert.doesNotMatch(renderQueueNext('en', '  ').body, /at\s+\./);
});

function remoteEntry(extra: Partial<QueueEntry> = {}): QueueEntry {
  return {
    id: 'e1',
    name: 'Liya',
    status: 'waiting',
    source: 'remote',
    addedBy: 'cust_1',
    createdAt: '2026-11-13T07:00:00.000Z',
    ...extra,
  };
}

function ports(language: unknown) {
  const inbox = new Map<string, InboxDoc>();
  const pushes: { uid: string; title: string; data: Record<string, string> }[] = [];
  return {
    inbox,
    pushes,
    ports: {
      userLanguage: async () => language,
      createInbox: async (uid: string, id: string, doc: InboxDoc) => {
        const key = `${uid}/${id}`;
        if (inbox.has(key)) return false;
        inbox.set(key, doc);
        return true;
      },
      sendPush: async (uid: string, message: { title: string; body: string }, data: Record<string, string>) => {
        pushes.push({ uid, title: message.title, data });
      },
    },
  };
}

test('writes the inbox entry and pushes once, in the customer’s language', async () => {
  const p = ports('am');
  assert.equal(await notifyQueueNext('shop_1', 'Fendika Cuts', remoteEntry(), NOW, p.ports), 'sent');
  assert.equal(await notifyQueueNext('shop_1', 'Fendika Cuts', remoteEntry(), NOW, p.ports), 'duplicate');
  assert.equal(p.pushes.length, 1);
  const [[key, doc]] = [...p.inbox.entries()];
  assert.equal(key, 'cust_1/queue_e1-1794553200000_queueNext');
  assert.equal(doc.type, QUEUE_NEXT_TYPE);
  assert.equal(doc.read, false);
  assert.equal(doc.shopId, 'shop_1');
  assert.equal(doc.queueEntryId, 'e1');
  assert.equal(doc.createdAt, NOW.toISOString());
  assert.equal(doc.title, renderQueueNext('am', 'Fendika Cuts').title);
  assert.deepEqual(p.pushes[0].data, {
    type: QUEUE_NEXT_TYPE,
    notificationId: 'queue_e1-1794553200000_queueNext',
    shopId: 'shop_1',
    queueEntryId: 'e1',
  });
});

test('skips walk-ins and entries that are no longer waiting', async () => {
  const p = ports('en');
  assert.equal(await notifyQueueNext('s', null, remoteEntry({ source: 'walkIn' }), NOW, p.ports), 'skipped');
  assert.equal(await notifyQueueNext('s', null, remoteEntry({ status: 'serving' }), NOW, p.ports), 'skipped');
  assert.equal(await notifyQueueNext('s', null, remoteEntry({ addedBy: '' }), NOW, p.ports), 'skipped');
  assert.equal(p.inbox.size, 0);
});
