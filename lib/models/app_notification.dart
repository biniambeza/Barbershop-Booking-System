import 'package:cloud_firestore/cloud_firestore.dart';

/// Kinds of booking notification. The string values match the `type` field
/// written by the notifications Cloud Functions (functions/notifications).
abstract final class NotificationTypes {
  static const created = 'created';
  static const confirmed = 'confirmed';
  static const cancelled = 'cancelled';
  static const started = 'started';
  static const completed = 'completed';
  static const reminder24h = 'reminder24h';
  static const reminder2h = 'reminder2h';

  /// The booking was cancelled by the server because its slot was taken.
  static const slotTaken = 'slotTaken';
  static const paymentReceived = 'paymentReceived';
  static const paymentRefunded = 'paymentRefunded';
  static const paymentFailed = 'paymentFailed';
  static const subscriptionPaid = 'subscriptionPaid';
  static const subscriptionFailed = 'subscriptionFailed';

  /// The customer moved the booking to a new time.
  static const rescheduled = 'rescheduled';

  /// Staff marked the customer as a no-show (customer only).
  static const noShow = 'noShow';

  /// Walk-in queue: a remote customer is next in line (functions/queue).
  /// Carries shopId and queueEntryId instead of a bookingId.
  static const queueNext = 'queueNext';

  // --- shop applications --- the applicant's shop application was
  // reviewed (functions/notifications applications.ts). Carry shopId when
  // approved; no bookingId.
  static const applicationApproved = 'applicationApproved';
  static const applicationRejected = 'applicationRejected';

  // --- barber acceptance --- outcome of a 'pending' booking request
  // (functions/notifications events.ts).
  static const accepted = 'accepted';
  static const requestDeclined = 'requestDeclined';
  static const requestExpired = 'requestExpired';

  // --- early finish --- the barber finished an earlier appointment ahead
  // of schedule (lib/services/early_finish_service.dart, functions/
  // notifications earlyFinish.ts). Id `{bookingId}_early_{sourceBookingId}`;
  // bookingId is the recipient's own booking.
  /// The next customer: the barber is free now, come in early.
  static const barberFreeEarly = 'barberFreeEarly';

  /// Later customers that day: the barber is running ahead of schedule.
  static const runningEarly = 'runningEarly';
  // --- end early finish ---

  // --- subscription receipts --- an admin (or the payments function)
  // decided the owner's transfer receipt. Id `{paymentDocId}_receipt`;
  // carries shopId and paymentId, no bookingId.
  static const receiptApproved = 'receiptApproved';
  static const receiptRejected = 'receiptRejected';
  // --- end subscription receipts ---

  static const all = [
    created,
    confirmed,
    cancelled,
    started,
    completed,
    reminder24h,
    reminder2h,
    slotTaken,
    paymentReceived,
    paymentRefunded,
    paymentFailed,
    subscriptionPaid,
    subscriptionFailed,
    rescheduled,
    noShow,
    queueNext,
    applicationApproved, // shop applications
    applicationRejected, // shop applications
    accepted, // barber acceptance
    requestDeclined, // barber acceptance
    requestExpired, // barber acceptance
    barberFreeEarly, // early finish
    runningEarly, // early finish
    receiptApproved, // subscription receipts
    receiptRejected, // subscription receipts
  ];
}

/// One entry of a user's in-app inbox: `users/{uid}/notifications/{id}`.
///
/// Cloud Functions create these (id `{bookingId}_{type}`, or `{paymentId}_{type}`
/// for paymentFailed and subscription events); the user may only
/// read them and set [read] to true.
class AppNotification {
  final String id;
  final String title;
  final String body;

  /// One of [NotificationTypes] (unknown values are kept as-is).
  final String type;
  final String? bookingId;
  final bool read;

  /// UTC.
  final DateTime createdAt;

  /// Early finish only: how many minutes ahead of schedule the barber is
  /// (lets the app re-render the copy in the viewer's language).
  final int? minutesEarly;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.bookingId,
    this.read = false,
    required this.createdAt,
    this.minutesEarly, // early finish
  });

  bool get isReminder => type == NotificationTypes.reminder24h || type == NotificationTypes.reminder2h;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        bookingId: bookingId,
        read: read ?? this.read,
        createdAt: createdAt,
        minutesEarly: minutesEarly, // early finish
      );

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: (map['type'] as String?) ?? '',
      bookingId: map['bookingId'] as String?,
      read: map['read'] == true,
      createdAt: _parseDate(map['createdAt']),
      minutesEarly: (map['minutesEarly'] as num?)?.toInt(), // early finish
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        if (bookingId != null) 'bookingId': bookingId,
        'read': read,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (minutesEarly != null) 'minutesEarly': minutesEarly, // early finish
      };

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (value is DateTime) return value.toUtc();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
