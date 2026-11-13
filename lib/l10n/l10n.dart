/// Localization entry point for widgets:
///
/// ```dart
/// Text(context.l10n.cancel)
/// Text(context.fmt.birr(service.price))
/// ```
library;

import 'package:flutter/widgets.dart';

import '../core/utils/formatters.dart';
import 'gen/app_localizations.dart';

export '../core/utils/formatters.dart' show AppFormats, formatBirr;
export 'gen/app_localizations.dart';
export 'labels.dart';
export 'locale_controller.dart';

AppLocalizations? _english;

extension L10nContext on BuildContext {
  /// Strings for the active locale. Falls back to English when the widget
  /// tree has no AppLocalizations delegate (e.g. bare MaterialApps in tests).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      (_english ??= lookupAppLocalizations(const Locale('en')));

  /// Number/date/time formatting for the active language.
  AppFormats get fmt => AppFormats(l10n.localeName);
}
