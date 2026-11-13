/**
 * Crown & Blade notifications codebase (firebase.json codebase "notifications").
 *
 * Exports:
 *   onBookingWritten        Firestore trigger on bookings/{bookingId}
 *   sendBookingReminders    every 15 minutes (Africa/Addis_Ababa)
 *
 * Secrets (firebase functions:secrets:set NAME). Set AFROMESSAGE_TOKEN to
 * "none" to keep SMS in log-only mode:
 *   AFROMESSAGE_TOKEN, AFROMESSAGE_IDENTIFIER_ID, AFROMESSAGE_SENDER
 */

import { initializeApp, getApps } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';
import { logger } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret } from 'firebase-functions/params';

import { notifyBooking } from './dispatch';
import { detectBookingEvent, type BookingDoc } from './events';
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
    const type = detectBookingEvent(before, after);
    if (!type || !after) return;
    const bookingId = event.params.bookingId;
    logger.info('booking event', { bookingId, type });
    await notifyBooking(bookingId, after, type, smsProvider());
  },
);

export const sendBookingReminders = onSchedule(
  { schedule: 'every 15 minutes', timeZone: 'Africa/Addis_Ababa', secrets: SMS_SECRETS },
  async () => {
    const result = await runReminderSweep(new Date(), smsProvider());
    logger.info('reminder sweep done', result);
  },
);
