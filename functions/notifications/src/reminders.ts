/**
 * Reminder sweep: confirmed bookings starting ~24h and ~2h from now.
 *
 * Query (needs composite index bookings: status ASC, startAt ASC):
 *   bookings where status == 'confirmed' and startAt > from and startAt <= to
 * startAt is an ISO-8601 UTC string, so string range comparison works as long
 * as every writer uses the same format (Dart toUtc().toIso8601String()).
 *
 * Each reminder is claimed in a transaction that sets reminder24hSentAt /
 * reminder2hSentAt on the booking before sending, so overlapping runs and
 * retries never send twice. That write changes no status, so the booking
 * trigger ignores it.
 */

import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import { notifyBooking } from './dispatch';
import type { BookingDoc } from './events';
import type { SmsProvider } from './sms';
import { REMINDER_WINDOWS, dueReminder, toIsoUtc, windowRange } from './time';

export async function runReminderSweep(now: Date, sms: SmsProvider): Promise<{ sent: number }> {
  const db = getFirestore();
  let sent = 0;

  for (const window of REMINDER_WINDOWS) {
    const { from, to } = windowRange(window, now);
    const qs = await db
      .collection('bookings')
      .where('status', '==', 'confirmed')
      .where('startAt', '>', toIsoUtc(from))
      .where('startAt', '<=', toIsoUtc(to))
      .get();

    for (const doc of qs.docs) {
      const booking = doc.data() as BookingDoc;
      const due = dueReminder(booking, now);
      if (!due || due.kind !== window.kind) continue;

      const claimed = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        const data = fresh.data() as BookingDoc | undefined;
        if (!data || data.status !== 'confirmed' || data[window.flagField]) return null;
        tx.update(doc.ref, { [window.flagField]: toIsoUtc(now) });
        return data;
      });
      if (!claimed) continue;

      try {
        await notifyBooking(doc.id, claimed, window.kind, sms, { onlyCustomer: true });
        sent++;
      } catch (err) {
        logger.error('reminder failed', { bookingId: doc.id, kind: window.kind, err: String(err) });
      }
    }
  }
  return { sent };
}
