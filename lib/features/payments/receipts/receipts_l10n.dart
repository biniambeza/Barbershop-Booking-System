import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/subscription_payment.dart';
import 'receipt_image.dart';

/// Subscription receipt texts in the active language.
extension ReceiptsL10n on AppLocalizations {
  /// [ReceiptException]s by code; everything else via [errorText].
  String receiptsErrorText(Object error) {
    if (error is ReceiptImageException) return rcptPhotoFailed;
    if (error is! ReceiptException) return errorText(error);
    switch (error.code) {
      case ReceiptErrorCode.ownerOnly:
        return rcptErrOwnerOnly;
      case ReceiptErrorCode.adminOnly:
        return rcptErrAdminOnly;
      case ReceiptErrorCode.shopNotFound:
        return rcptErrShopNotFound;
      case ReceiptErrorCode.invalidTransactionId:
        return rcptErrTxId;
      case ReceiptErrorCode.invalidAmount:
        return rcptErrAmount;
      case ReceiptErrorCode.amountTooLow:
        return rcptReasonAmountTooLow;
      case ReceiptErrorCode.duplicate:
        return rcptErrDuplicate;
      case ReceiptErrorCode.imageTooLarge:
        return rcptErrImageTooLarge;
      case ReceiptErrorCode.notFound:
        return rcptErrNotFound;
      case ReceiptErrorCode.notOpen:
        return rcptErrNotOpen;
      case ReceiptErrorCode.reasonRequired:
        return rcptErrReason;
      case ReceiptErrorCode.invalidPricing:
        return rcptErrPricing;
    }
  }

  String receiptMethodLabel(ReceiptMethod method, {bool short = false}) {
    switch (method) {
      case ReceiptMethod.telebirr:
        return rcptMethodTelebirr;
      case ReceiptMethod.cbe:
        return short ? rcptMethodCbeShort : rcptMethodCbe;
      case ReceiptMethod.other:
        return rcptMethodOther;
    }
  }

  String receiptStatusLabel(ReceiptStatus status) {
    switch (status) {
      case ReceiptStatus.pending:
        return rcptStatusPending;
      case ReceiptStatus.verified:
        return rcptStatusVerified;
      case ReceiptStatus.rejected:
        return rcptStatusRejected;
      case ReceiptStatus.needsReview:
        return rcptStatusNeedsReview;
    }
  }

  /// A machine reason in words; an admin's free text as it is.
  String receiptReasonText(String reason) {
    switch (reason) {
      case ReceiptReasons.amountTooLow:
        return rcptReasonAmountTooLow;
      case ReceiptReasons.duplicate:
        return rcptReasonDuplicate;
      case ReceiptReasons.receiptNotFound:
        return rcptReasonNotFound;
      case ReceiptReasons.notCompleted:
        return rcptReasonNotCompleted;
      case ReceiptReasons.receiverMismatch:
        return rcptReasonReceiverMismatch;
      case ReceiptReasons.amountMismatch:
        return rcptReasonAmountMismatch;
      case ReceiptReasons.tooOld:
        return rcptReasonTooOld;
      case ReceiptReasons.fetchFailed:
        return rcptReasonFetchFailed;
      case ReceiptReasons.unsupportedMethod:
        return rcptReasonUnsupported;
      default:
        return reason;
    }
  }
}

/// Status chip colours and icons.
Color receiptStatusColor(ReceiptStatus status) {
  switch (status) {
    case ReceiptStatus.pending:
      return AppTheme.warning;
    case ReceiptStatus.verified:
      return AppTheme.success;
    case ReceiptStatus.rejected:
      return AppTheme.danger;
    case ReceiptStatus.needsReview:
      return AppTheme.blue;
  }
}

IconData receiptStatusIcon(ReceiptStatus status) {
  switch (status) {
    case ReceiptStatus.pending:
      return Icons.hourglass_top_rounded;
    case ReceiptStatus.verified:
      return Icons.verified_rounded;
    case ReceiptStatus.rejected:
      return Icons.cancel_rounded;
    case ReceiptStatus.needsReview:
      return Icons.manage_search_rounded;
  }
}

IconData receiptMethodIcon(ReceiptMethod method) {
  switch (method) {
    case ReceiptMethod.telebirr:
      return Icons.phone_android_rounded;
    case ReceiptMethod.cbe:
      return Icons.account_balance_rounded;
    case ReceiptMethod.other:
      return Icons.receipt_long_rounded;
  }
}
