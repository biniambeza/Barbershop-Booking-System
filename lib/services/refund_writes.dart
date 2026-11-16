import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import 'refunds.dart';

/// Creates a document inside the caller's batch or transaction
/// (`(ref, data) => batch.set(ref, data)` / `tx.set(ref, data)`).
typedef RefundDocWriter = void Function(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data);

/// The helper every cancellation path calls, inside the SAME batch or
/// transaction as its cancel write (works on the free Spark plan):
///
///  * when [booking] (its state as of this write: re-read in the
///    transaction where possible) is paid and not flagged yet, the four
///    refund fields ([BookingRefund.toFlagFields]: refundStatus 'due',
///    refundAmount, refundReason, refundFlaggedAt) are added to
///    [bookingUpdate], the map the caller passes to its own
///    `update(bookingRef, ...)` (one update of the booking, so the rules
///    see one write);
///  * and the customer's notice `users/{customerId}/notifications/
///    {bookingId}_refundDue` is created through [create].
///
/// Returns the flag, or null when nothing is owed (unpaid, already
/// flagged/refunded, no-show, no valid price).
BookingRefund? flagRefundIfPaid({
  required FirebaseFirestore db,
  required RefundDocWriter create,
  required Map<String, dynamic> bookingUpdate,
  required Booking booking,
  required RefundContext context,
}) {
  final flag = refundFlagFor(booking, context);
  if (flag == null) return null;
  bookingUpdate.addAll(flag.toFlagFields());
  if (booking.customerId.isNotEmpty) {
    final notice = refundDueNotice(booking, flag, language: context.languageOf?.call(booking.customerId));
    create(db.collection('users').doc(notice.recipientUid).collection('notifications').doc(notice.id), notice.toMap());
  }
  return flag;
}
