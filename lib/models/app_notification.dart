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

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.bookingId,
    this.read = false,
    required this.createdAt,
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
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        if (bookingId != null) 'bookingId': bookingId,
        'read': read,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (value is DateTime) return value.toUtc();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
