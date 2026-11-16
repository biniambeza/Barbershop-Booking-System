/// Early finish: when a barber completes an appointment before its scheduled
/// end, that barber's later customers today are told they can come sooner.
///
/// Pure logic (no Firebase, no Flutter), mirrored by
/// functions/notifications/src/earlyFinish.ts:
///  * [minutesEarly] / [isEarlyFinish]: how early (endAt - completedAt,
///    rounded down to 5 minutes, 0..[kEarlyFinishMaxMinutes]).
///  * [earlyFinishRecipients]: the barber's remaining bookings of the same
///    Addis day (UTC+3): same barber and shop, status confirmed, starting
///    after the finish, soonest first, at most [kEarlyFinishMaxRecipients].
///  * [planEarlyFinishNotices]: one inbox entry per recipient booking at
///    `users/{customerId}/notifications/{bookingId}_early_{sourceBookingId}`;
///    the next customer gets 'barberFreeEarly', the others 'runningEarly'.
///  * [renderEarlyFinishText]: the copy, in English or Amharic.
library;

import '../data/addis_time.dart';
import '../models/app_notification.dart' show NotificationTypes;
import '../models/booking_model.dart';

/// Most customers told about one early finish.
const int kEarlyFinishMaxRecipients = 5;

/// Upper bound of the stored `minutesEarly` (the rules accept 0..240).
const int kEarlyFinishMaxMinutes = 240;

/// How long the "your barber is free now" banner stays on the booking card.
const Duration kEarlyFinishBannerWindow = Duration(minutes: 60);

/// Inbox doc id of the notice for [recipientBookingId] caused by finishing
/// [sourceBookingId] early. Idempotent: finishing the same booking twice (or
/// the client and the Cloud Function both writing it) targets the same doc.
String earlyFinishNotificationId(String recipientBookingId, String sourceBookingId) =>
    '${recipientBookingId}_early_$sourceBookingId';

/// Whether [completedAtUtc] is before the booking's scheduled end.
bool isEarlyFinish(Booking source, DateTime completedAtUtc) => completedAtUtc.toUtc().isBefore(source.endAt);

/// endAt - completedAt in whole minutes, rounded down to a multiple of 5 and
/// clamped to 0..[kEarlyFinishMaxMinutes] (0 when not early).
int minutesEarly(Booking source, DateTime completedAtUtc) {
  final diff = source.endAt.difference(completedAtUtc.toUtc()).inMinutes;
  if (diff <= 0) return 0;
  final rounded = diff - diff % 5;
  return rounded > kEarlyFinishMaxMinutes ? kEarlyFinishMaxMinutes : rounded;
}

/// Same calendar day on the Addis Ababa wall clock.
bool isSameAddisDay(DateTime a, DateTime b) {
  final x = toAddisWallClock(a);
  final y = toAddisWallClock(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// The bookings to tell about [source] finishing early at [nowUtc]: same
/// barber and shop, not [source] itself, status confirmed (pending requests
/// and in-progress chairs are not told), a customer, `startAt > nowUtc` on
/// the same Addis day as [nowUtc]; soonest first, at most
/// [kEarlyFinishMaxRecipients].
List<Booking> earlyFinishRecipients(Booking source, Iterable<Booking> bookings, DateTime nowUtc) {
  final now = nowUtc.toUtc();
  final result = bookings
      .where((b) =>
          b.id != source.id &&
          b.barberId == source.barberId &&
          b.shopId == source.shopId &&
          b.status == BookingStatus.confirmed &&
          b.customerId.isNotEmpty &&
          b.startAt.isAfter(now) &&
          isSameAddisDay(b.startAt, now))
      .toList()
    ..sort((a, b) {
      final byStart = a.startAt.compareTo(b.startAt);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });
  return result.length > kEarlyFinishMaxRecipients ? result.sublist(0, kEarlyFinishMaxRecipients) : result;
}

/// One inbox entry to write for an early finish.
class EarlyFinishNotice {
  const EarlyFinishNotice({
    required this.id,
    required this.recipientUid,
    required this.type,
    required this.bookingId,
    required this.shopId,
    required this.barberId,
    required this.sourceBookingId,
    required this.minutesEarly,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  /// `{bookingId}_early_{sourceBookingId}`.
  final String id;

  /// The customer: `users/{recipientUid}/notifications/{id}`.
  final String recipientUid;

  /// [NotificationTypes.barberFreeEarly] or [NotificationTypes.runningEarly].
  final String type;

  /// The recipient's own booking.
  final String bookingId;
  final String shopId;
  final String barberId;

  /// The booking that was just completed.
  final String sourceBookingId;
  final int minutesEarly;
  final String title;
  final String body;

  /// UTC.
  final DateTime createdAt;

  /// Exactly the keys the rules accept for a staff-created early notice.
  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'body': body,
        'bookingId': bookingId,
        'shopId': shopId,
        'barberId': barberId,
        'sourceBookingId': sourceBookingId,
        'minutesEarly': minutesEarly,
        'read': false,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

/// The inbox entries for [source] completed at [completedAtUtc], or none
/// when it was not finished early. [languageOf] gives a recipient's
/// `users/{uid}.language` when known (staff usually cannot read customers'
/// profiles); unknown means Amharic. The customer's app re-renders the copy
/// in its own language ([renderEarlyFinishText]).
List<EarlyFinishNotice> planEarlyFinishNotices(
  Booking source,
  Iterable<Booking> bookings,
  DateTime completedAtUtc, {
  String? Function(String uid)? languageOf,
}) {
  final completedAt = completedAtUtc.toUtc();
  if (!isEarlyFinish(source, completedAt)) return const [];
  final minutes = minutesEarly(source, completedAt);
  final recipients = earlyFinishRecipients(source, bookings, completedAt);
  return [
    for (var i = 0; i < recipients.length; i++)
      () {
        final b = recipients[i];
        final type = i == 0 ? NotificationTypes.barberFreeEarly : NotificationTypes.runningEarly;
        final text = renderEarlyFinishText(type, b, minutes, language: languageOf?.call(b.customerId));
        return EarlyFinishNotice(
          id: earlyFinishNotificationId(b.id, source.id),
          recipientUid: b.customerId,
          type: type,
          bookingId: b.id,
          shopId: b.shopId,
          barberId: b.barberId,
          sourceBookingId: source.id,
          minutesEarly: minutes,
          title: text.title,
          body: text.body,
          createdAt: completedAt,
        );
      }(),
  ];
}

/// Copy for an early-finish notice about [booking] (the recipient's own
/// booking), in [language] ('en'; anything else, including null, is
/// Amharic, the default for customers). Matches earlyFinish.ts.
({String title, String body}) renderEarlyFinishText(
  String type,
  Booking booking,
  int minutesEarly, {
  String? language,
}) {
  final t = toAddisWallClock(booking.startAt);
  final hhmm = '${_two(t.hour)}:${_two(t.minute)}';
  final free = type == NotificationTypes.barberFreeEarly;
  if (language == 'en') {
    final barber = booking.barberName.isEmpty ? 'Your barber' : booking.barberName;
    final shop = booking.shopName.isEmpty ? 'Crown & Blade' : booking.shopName;
    return free
        ? (
            title: 'Your barber is free now',
            body: '$barber at $shop is free now — you can come in early for your $hhmm appointment.',
          )
        : (
            title: 'Running ahead of schedule',
            body: '$barber is running about $minutesEarly min ahead of schedule today; '
                'your $hhmm appointment may start earlier.',
          );
  }
  final barber = booking.barberName.isEmpty ? 'ፀጉር አስተካካይዎ' : booking.barberName;
  final shop = booking.shopName.isEmpty ? 'Crown & Blade' : booking.shopName;
  final time = '$hhmm (${_ethiopianClock(t.hour, t.minute)})';
  return free
      ? (
          title: 'ፀጉር አስተካካይዎ አሁን ነፃ ናቸው',
          body: '$barber ($shop) አሁን ነፃ ናቸው — ለ$time ቀጠሮዎ ቀድመው መምጣት ይችላሉ።',
        )
      : (
          title: 'ከፕሮግራሙ ቀድመው እየሰሩ ነው',
          body: '$barber ዛሬ ከፕሮግራማቸው $minutesEarly ደቂቃ ያህል ቀድመው እየሰሩ ነው፤ የ$time ቀጠሮዎ ቀደም ብሎ ሊጀምር ይችላል።',
        );
}

/// Whether the booking card should show the "your barber is free now"
/// banner: a 'barberFreeEarly' notice for [bookingId] created less than
/// [kEarlyFinishBannerWindow] before [nowUtc].
bool showsEarlyFinishBanner({
  required String bookingId,
  required String? notificationBookingId,
  required String notificationType,
  required DateTime notificationCreatedAt,
  required DateTime nowUtc,
}) {
  if (notificationType != NotificationTypes.barberFreeEarly || notificationBookingId != bookingId) return false;
  final age = nowUtc.toUtc().difference(notificationCreatedAt.toUtc());
  return !age.isNegative && age < kEarlyFinishBannerWindow;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Traditional Ethiopian clock reading (same as notification_service.dart's
/// `ethiopianClock`; duplicated to keep this file free of Flutter/Firebase).
String _ethiopianClock(int hour, int minute) {
  final ethHour = (hour + 6) % 12 == 0 ? 12 : (hour + 6) % 12;
  final period = hour < 6
      ? 'ሌሊት'
      : hour < 12
          ? 'ጠዋት'
          : hour < 18
              ? 'ከሰዓት'
              : 'ማታ';
  return '$period $ethHour:${_two(minute)}';
}
