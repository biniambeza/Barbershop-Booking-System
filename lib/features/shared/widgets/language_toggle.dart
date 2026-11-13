import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// EN / አማ switch for app bars and the sign-in screen. Changes the app
/// language at once and saves it to the signed-in user's profile.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.controller});

  /// Defaults to [LocaleController.instance].
  final LocaleController? controller;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? LocaleController.instance;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final amharic = ctrl.isAmharic;
        return Tooltip(
          message: context.l10n.languageTooltip,
          child: InkWell(
            key: const ValueKey('language-toggle'),
            borderRadius: BorderRadius.circular(16),
            onTap: ctrl.toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _segment('EN', !amharic),
                    _segment('አማ', amharic),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _segment(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryGold : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.black : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
