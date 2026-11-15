import '../../l10n/l10n.dart';
import '../../models/shop_application.dart';

/// Shop application texts in the active language.
extension ApplicationsL10n on AppLocalizations {
  /// [ShopApplicationException]s by code; everything else via [errorText].
  String applicationsErrorText(Object error) {
    if (error is! ShopApplicationException) return errorText(error);
    final first = error.args.isEmpty ? null : error.args.first;
    switch (error.code) {
      case ShopApplicationErrorCode.ownerNameInvalid:
        return applErrOwnerName;
      case ShopApplicationErrorCode.shopNameInvalid:
        return applErrShopName;
      case ShopApplicationErrorCode.addressInvalid:
        return applErrAddress;
      case ShopApplicationErrorCode.subCityInvalid:
        return applErrSubCity;
      case ShopApplicationErrorCode.phoneInvalid:
        return applErrPhone;
      case ShopApplicationErrorCode.descriptionTooLong:
        return applErrDescriptionTooLong(first is int ? first : kApplicationDescriptionMax);
      case ShopApplicationErrorCode.rejectReasonInvalid:
        return applErrRejectReason(first is int ? first : kApplicationRejectReasonMax);
      case ShopApplicationErrorCode.customersOnly:
        return applErrCustomersOnly;
      case ShopApplicationErrorCode.emailMissing:
        return applErrEmailMissing;
      case ShopApplicationErrorCode.alreadyPending:
        return applErrAlreadyPending;
      case ShopApplicationErrorCode.alreadyApproved:
        return applErrAlreadyApproved;
      case ShopApplicationErrorCode.notPending:
        return applErrNotPending;
      case ShopApplicationErrorCode.notFound:
        return applErrNotFound;
      case ShopApplicationErrorCode.adminOnly:
        return applErrAdminOnly;
    }
  }

  String applicationStatusLabel(ShopApplicationStatus status) {
    switch (status) {
      case ShopApplicationStatus.pending:
        return applStatusPending;
      case ShopApplicationStatus.approved:
        return applStatusApproved;
      case ShopApplicationStatus.rejected:
        return applStatusRejected;
    }
  }
}
