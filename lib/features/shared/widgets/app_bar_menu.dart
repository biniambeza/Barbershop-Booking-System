import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../auth/screens/change_password_screen.dart';
import 'language_toggle.dart';
import 'persona_switcher.dart';

/// An extra entry in [AppBarMenu] (e.g. the admin's subscriptions screen).
class AppBarMenuEntry {
  const AppBarMenuEntry({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.key,
    this.color = AppTheme.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final Key? key;
  final Color color;
}

/// Compact overflow menu for the role dashboards' app bars, so the title
/// stays readable on 360 px phones. Holds the secondary actions: the demo
/// persona switcher (DEMO_MODE only), the EN / አማ language switch, any
/// [entries] the screen adds, "Change password" (or "Set a password" for
/// Google-only accounts) and sign out. Key `app-bar-menu`.
class AppBarMenu extends StatelessWidget {
  const AppBarMenu({super.key, required this.role, this.entries = const []});

  /// The current persona, highlighted by the demo persona switcher.
  final UserRole role;

  final List<AppBarMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final actions = <String, VoidCallback>{};
    final items = <PopupMenuEntry<String>>[];

    void add(String id, IconData icon, String label, VoidCallback onSelected,
        {Key? key, Color color = AppTheme.textPrimary, Widget? trailing}) {
      actions[id] = onSelected;
      items.add(PopupMenuItem<String>(
        key: key,
        value: id,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ));
    }

    if (kDemoMode) {
      add('persona', Icons.swap_horiz_rounded, l.switchRole,
          () => showPersonaSwitcher(context, current: role),
          key: const ValueKey('app-bar-menu-persona'));
    }
    add('language', Icons.translate_rounded, l.languageTooltip, () => LocaleController.instance.toggle(),
        key: const ValueKey('app-bar-menu-language'),
        // Shows the current language; the whole row toggles it.
        trailing: const IgnorePointer(child: LanguageToggle()));
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      add('entry$i', e.icon, e.label, e.onSelected, key: e.key, color: e.color);
    }
    final repo = AppRepository.instance;
    if (repo.currentUser?.email?.isNotEmpty ?? false) {
      final hasPassword = repo.canChangePassword;
      add('password', hasPassword ? Icons.lock_reset_rounded : Icons.key_rounded,
          hasPassword ? l.changePasswordMenu : l.setPasswordMenu, () => openPasswordSettings(context),
          key: const ValueKey('app-bar-menu-password'));
    }
    items.add(const PopupMenuDivider());
    add('signout', Icons.logout_rounded, l.signOut, () => AppRepository.instance.signOut(),
        key: const ValueKey('app-bar-menu-signout'), color: AppTheme.danger);

    return PopupMenuButton<String>(
      key: const ValueKey('app-bar-menu'),
      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
      position: PopupMenuPosition.under,
      onSelected: (id) => actions[id]?.call(),
      itemBuilder: (_) => items,
    );
  }
}
