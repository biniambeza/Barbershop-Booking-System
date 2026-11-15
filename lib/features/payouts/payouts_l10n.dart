import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../services/payout_service.dart';

/// Payout texts in the active language.
extension PayoutsL10n on AppLocalizations {
  /// [PayoutException]s by code; everything else via [errorText].
  String payoutsErrorText(Object error) {
    if (error is! PayoutException) return errorText(error);
    switch (error.code) {
      case PayoutErrorCode.ownerOnly:
        return payoutsErrOwnerOnly;
      case PayoutErrorCode.notFound:
        return payoutsErrNotFound;
      case PayoutErrorCode.unknownBarber:
        return payoutsErrUnknownBarber;
      case PayoutErrorCode.invalidAmount:
        return payoutsErrInvalidAmount(NumberFormat('#,##0', 'en').format(kMaxPayoutAmount));
      case PayoutErrorCode.invalidPeriod:
        return payoutsErrInvalidPeriod;
      case PayoutErrorCode.noteTooLong:
        return payoutsErrNoteTooLong(kMaxPayoutNoteLength);
      case PayoutErrorCode.invalidCommission:
        return payoutsErrInvalidCommission;
      case PayoutErrorCode.deleteWindowPassed:
        return payoutsErrDeleteWindow;
    }
  }

  String payoutMethodLabel(PayoutMethod method) {
    switch (method) {
      case PayoutMethod.cash:
        return payoutsMethodCash;
      case PayoutMethod.telebirr:
        return payoutsMethodTelebirr;
      case PayoutMethod.bank:
        return payoutsMethodBank;
      case PayoutMethod.other:
        return payoutsMethodOther;
    }
  }
}

/// `November 2026` / Amharic equivalent.
String payoutMonthLabel(AppFormats fmt, PayoutMonth month) =>
    DateFormat.yMMMM(fmt.language).format(DateTime(month.year, month.month));

/// `Nov 1, 2026 - Nov 30, 2026`, or one date when start == end.
String payoutPeriodLabel(AppFormats fmt, Payout payout) {
  final start = fmt.dateMedium(payout.periodStart);
  final end = fmt.dateMedium(payout.periodEnd);
  return start == end ? start : '$start - $end';
}
