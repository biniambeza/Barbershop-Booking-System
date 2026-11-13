/**
 * Crown & Blade notifications codebase (firebase.json codebase "notifications").
 *
 * Exports:
 *   onBookingWritten        Firestore trigger on bookings/{bookingId}
 *                           (status events incl. noShow, reschedules,
 *                           paymentStatus paid/refunded)
 *   onPaymentWritten        Firestore trigger on payments/{paymentId}
 *                           (booking payment failed, subscription paid/failed)
 *   sendBookingReminders    every 15 minutes (Africa/Addis_Ababa)
 *
 * Secrets (firebase functions:secrets:set NAME). Set AFROMESSAGE_TOKEN to
 * "none" to keep SMS in log-only mode:
 *   AFROMESSAGE_TOKEN, AFROMESSAGE_IDENTIFIER_ID, AFROMESSAGE_SENDER
 */

import { initializeApp, getApps } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { logger } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret } from 'firebase-functions/params';

import { notifyBooking, notifyPayment } from './dispatch';
import {
  detectBookingEvents,
  detectPaymentEvent,
  rescheduleEntityId,
  staleReminderFlags,
  type BookingDoc,
  type PaymentDoc,
} from './events';
import { parseIso } from './time';
import { runReminderSweep } from './reminders';
import { createSmsProvider, type SmsProvider } from './sms';

if (getApps().length === 0) initializeApp();

const REGION = 'europe-west1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

const AFROMESSAGE_TOKEN = defineSecret('AFROMESSAGE_TOKEN');
const AFROMESSAGE_IDENTIFIER_ID = defineSecret('AFROMESSAGE_IDENTIFIER_ID');
const AFROMESSAGE_SENDER = defineSecret('AFROMESSAGE_SENDER');
const SMS_SECRETS = [AFROMESSAGE_TOKEN, AFROMESSAGE_IDENTIFIER_ID, AFROMESSAGE_SENDER];

const DISABLED = new Set(['', 'none', 'disabled', '-']);

function smsProvider(): SmsProvider {
  const token = AFROMESSAGE_TOKEN.value()?.trim() ?? '';
  return createSmsProvider({
    token: DISABLED.has(token.toLowerCase()) ? '' : token,
    identifierId: AFROMESSAGE_IDENTIFIER_ID.value(),
    sender: AFROMESSAGE_SENDER.value(),
  });
}

export const onBookingWritten = onDocumentWritten(
  { document: 'bookings/{bookingId}', secrets: SMS_SECRETS, retry: false },
  async (event) => {
    const before = event.data?.before.exists ? (event.data.before.data() as BookingDoc) : null;
    const after = event.data?.after.exists ? (event.data.after.data() as BookingDoc) : null;
    if (!after) return;
    // A paymentStatus-only write yields only the payment event; each event
    // has its own idempotency key ({bookingId}_{type}).
    const types = detectBookingEvents(before, after);
    if (types.length === 0) return;
    const bookingId = event.params.bookingId;
    const sms = smsProvider();
    for (const type of types) {
      logger.info('booking event', { bookingId, type });
      try {
        if (type === 'rescheduled') {
          // One notification per move ({bookingId}_r{count}), new time in
          // Addis local, the old one alongside.
          await notifyBooking(bookingId, after, type, sms, {
            entityId: rescheduleEntityId(bookingId, after),
            previousStart: parseIso(before?.startAt),
          });
          // Reminders already sent for the old time must go out again.
          const stale = staleReminderFlags(after);
          if (stale.length > 0) {
            await getFirestore()
              .doc(`bookings/${bookingId}`)
              .update(Object.fromEntries(stale.map((f) => [f, FieldValue.delete()])));
          }
        } else {
          await notifyBooking(bookingId, after, type, sms);
        }
      } catch (err) {
        logger.error('booking notification failed', { bookingId, type, err: String(err) });
      }
    }
  },
);

export const onPaymentWritten = onDocumentWritten(
  { document: 'payments/{paymentId}', secrets: SMS_SECRETS, retry: false },
  async (event) => {
    const before = event.data?.before.exists ? (event.data.before.data() as PaymentDoc) : null;
    const after = event.data?.after.exists ? (event.data.after.data() as PaymentDoc) : null;
    const type = detectPaymentEvent(before, after);
    if (!type || !after) return;
    const paymentId = event.params.paymentId;
    logger.info('payment event', { paymentId, type });
    await notifyPayment(paymentId, after, type, smsProvider());
  },
);

export const sendBookingReminders = onSchedule(
  { schedule: 'every 15 minutes', timeZone: 'Africa/Addis_Ababa', secrets: SMS_SECRETS },
  async () => {
    const result = await runReminderSweep(new Date(), smsProvider());
    logger.info('reminder sweep done', result);
  },
);
