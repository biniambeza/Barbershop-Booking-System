import '../../l10n/l10n.dart';
import 'portfolio_service.dart';

/// Portfolio texts in the active language.
extension PortfolioL10n on AppLocalizations {
  /// [PortfolioException]s and image errors; everything else via [errorText].
  String portfolioErrorText(Object error) {
    if (error is PortfolioImageException) return portfolioErrImage;
    if (error is! PortfolioException) return errorText(error);
    switch (error.code) {
      case PortfolioErrorCode.notAllowed:
        return portfolioErrNotAllowed;
      case PortfolioErrorCode.full:
        return portfolioFull(kMaxPortfolioPhotos);
      case PortfolioErrorCode.captionTooLong:
        return portfolioErrCaptionTooLong(kMaxPortfolioCaptionLength);
      case PortfolioErrorCode.invalidImage:
        return portfolioErrImage;
      case PortfolioErrorCode.slotTaken:
        return portfolioErrSlotTaken;
      case PortfolioErrorCode.notFound:
        return portfolioErrNotFound;
    }
  }
}
