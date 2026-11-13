/// Locale-aware display formatting for Ethiopian users: Birr amounts,
/// Addis Ababa (UTC+3) dates and times, and phone numbers.
///
/// Widgets normally use `context.fmt` (see `lib/l10n/l10n.dart`), which binds
/// an [AppFormats] to the active app language. The free functions here take
/// an explicit language and fall back to `Intl.getCurrentLocale()`.
library;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../data/addis_time.dart';
import '../../models/booking_model.dart';
import 'phone_utils.dart';

bool _dateDataReady = false;

/// Loads the intl date symbols for every locale (including 'am'). The data is
/// bundled with the app, so this completes synchronously; it is safe to call
/// repeatedly.
void ensureDateFormattingData() {
  if (_dateDataReady) return;
  initializeDateFormatting();
  _dateDataReady = true;
}

/// 'am' for Amharic locales, otherwise 'en'.
String appLanguageOf(String? locale) {
  final value = (locale ?? Intl.getCurrentLocale()).toLowerCase();
  return value.startsWith('am') ? 'am' : 'en';
}

/// Formats an amount of Ethiopian Birr: `ETB 1,200` in English and
/// `1,200 ብር` in Amharic. Decimals are shown only when the amount has cents.
String formatBirr(num amount, {String? locale}) {
  final whole = amount == amount.roundToDouble();
  final number = NumberFormat(whole ? '#,##0' : '#,##0.00', 'en').format(amount);
  return appLanguageOf(locale) == 'am' ? '$number ብር' : 'ETB $number';
}

/// Formatting bound to one app language ('en' or 'am').
class AppFormats {
  AppFormats(String language) : language = appLanguageOf(language) {
    ensureDateFormattingData();
  }

  final String language;

  bool get isAmharic => language == 'am';

  /// `ETB 450` / `450 ብር`.
  String birr(num amount) => formatBirr(amount, locale: language);

  /// Wall-clock date fields formatted with an intl skeleton.
  String _date(DateFormat format, DateTime fields) => format.format(fields);

  /// `Fri, Nov 20`.
  String dayShort(DateTime date) => _date(DateFormat.MMMEd(language), date);

  /// `Friday, November 20, 2026`.
  String dayLong(DateTime date) => _date(DateFormat.yMMMMEEEEd(language), date);

  /// `Friday, Nov 20`.
  String weekdayMonthDay(DateTime date) => _date(DateFormat('EEEE, MMM d', language), date);

  /// `Nov 20, 2026`.
  String dateMedium(DateTime date) => _date(DateFormat.yMMMd(language), date);

  /// `Nov 20`.
  String monthDay(DateTime date) => _date(DateFormat.MMMd(language), date);

  /// `Fri`.
  String weekdayShort(DateTime date) => _date(DateFormat.E(language), date);

  /// `Friday`.
  String weekdayLong(DateTime date) => _date(DateFormat.EEEE(language), date);

  /// Short weekday name for ISO weekday 1 (Monday) .. 7 (Sunday).
  String weekdayName(int weekday) => weekdayShort(DateTime(2024, 1, weekday)); // 2024-01-01 is a Monday.

  /// Addis-time calendar date of a UTC instant, e.g. `Nov 20, 2026`.
  String addisDateMedium(DateTime instantUtc) => dateMedium(toAddisWallClock(instantUtc));

  /// A wall-clock time: `02:30 PM` in English, `2:30 ከሰዓት` in Amharic.
  String time(int hour, int minute) {
    if (!isAmharic) return formatTimeSlot(hour, minute);
    return DateFormat.jm(language).format(DateTime(2000, 1, 1, hour, minute));
  }

  /// A whole hour, e.g. `09:00 AM`. Hours of 24 or more wrap (24 = midnight).
  String hour(int hour) => time(hour % 24, 0);

  /// Opening hours, e.g. `09:00 AM - 08:00 PM`.
  String hoursRange(int openingHour, int closingHour) => '${hour(openingHour)} - ${hour(closingHour)}';

  /// The Addis wall-clock time of a UTC instant.
  String addisTime(DateTime instantUtc) {
    final wall = toAddisWallClock(instantUtc);
    return time(wall.hour, wall.minute);
  }

  /// Re-renders a stored display slot such as `'02:30 PM'` in this language.
  String slot(String timeSlot) {
    final parsed = parseTimeSlot(timeSlot);
    return parsed == null ? timeSlot : time(parsed.$1, parsed.$2);
  }

  /// Addis calendar day of a booking (from its UTC start).
  DateTime bookingDay(Booking booking) {
    final wall = toAddisWallClock(booking.startAt);
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// Start time of a booking in Addis time.
  String bookingTime(Booking booking) => addisTime(booking.startAt);

  /// Start - end of a booking in Addis time.
  String bookingRange(Booking booking) => '${addisTime(booking.startAt)} - ${addisTime(booking.endAt)}';

  /// `+251 91 122 3344`.
  String phone(String phone) => formatEthiopianPhone(phone);
}
