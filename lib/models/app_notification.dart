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

  // --- shop deletion --- written by the admin's app while it deletes a
  // shop (lib/services/shop_deletion.dart), or by functions/auth
  // onShopDeleted. Both carry shopId.
  /// A customer's upcoming booking was cancelled because its shop was
  /// deleted. Id `{bookingId}_shopDeleted`.
  static const shopDeleted = 'shopDeleted';

  /// The owner / a barber lost their shop and is now a customer. Id
  /// `shopRemoved_{shopId}`; no bookingId.
  static const shopRemoved = 'shopRemoved';
  // --- end shop deletion ---

  // --- refunds --- a paid booking was cancelled and the customer is owed
  // money (lib/services/refunds.dart; functions/bookings flagRefundOnCancel
  // on Blaze). Id `{bookingId}_refundDue`. When the shop marks it refunded
  // the customer gets [paymentRefunded] (`{bookingId}_paymentRefunded`).
  static const refundDue = 'refundDue';
  // --- end refunds ---

  // --- review notices --- a customer reviewed a visit at the shop
  // (lib/services/review_notices.dart; functions/notifications reviews.ts
  // pushes on Blaze). Id `review_{reviewId}_{createdAt digits}`; bookingId
  // is the reviewed booking (= review id), rating the stars.
  static const newReview = 'newReview';
  // --- end review notices ---

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
    shopDeleted, // shop deletion
    shopRemoved, // shop deletion
    refundDue, // refunds
    newReview, // review notices
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

  /// Review notices only: the review's stars (1..5), so the app can
  /// re-render the copy in the viewer's language.
  final int? rating; // review notices

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.bookingId,
    this.read = false,
    required this.createdAt,
    this.minutesEarly, // early finish
    this.rating, // review notices
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
        rating: rating, // review notices
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
      rating: (map['rating'] as num?)?.toInt(), // review notices
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
        if (rating != null) 'rating': rating, // review notices
      };

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (value is DateTime) return value.toUtc();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
