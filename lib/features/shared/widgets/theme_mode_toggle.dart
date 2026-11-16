import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// Sun / moon button that switches between light and dark mode. Long-press
/// opens a small menu that also offers "System default". Key
/// `theme-mode-toggle`.
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key, this.controller, this.size = 22, this.color});

  /// Defaults to [ThemeController.instance].
  final ThemeController? controller;

  final double size;

  /// Icon colour; defaults to [AppTheme.textPrimary].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? ThemeController.instance;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final l = context.l10n;
        final dark = ctrl.isDark;
        final tooltip = dark ? l.themeSwitchToLight : l.themeSwitchToDark;
        return Semantics(
          button: true,
          toggled: dark,
          label: l.darkModeMenu,
          excludeSemantics: true,
          child: Tooltip(
            message: tooltip,
            child: InkResponse(
              key: const ValueKey('theme-mode-toggle'),
              radius: 22,
              onTap: ctrl.toggle,
              onLongPress: () => showThemeModeMenu(context, controller: ctrl),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(begin: -0.35, end: 0).animate(animation),
                      child: ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    child: Icon(
                      dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      key: ValueKey(dark),
                      size: size,
                      color: color ?? (dark ? AppTheme.primary : AppTheme.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet with System default / Light / Dark.
Future<void> showThemeModeMenu(BuildContext context, {ThemeController? controller}) {
  final ctrl = controller ?? ThemeController.instance;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => ListenableBuilder(
      listenable: ctrl,
      builder: (sheetContext, _) {
        final l = sheetContext.l10n;
        Widget option(ThemeMode mode, IconData icon, String label) {
          final selected = ctrl.mode == mode;
          return ListTile(
            key: ValueKey('theme-mode-${mode.name}'),
            leading: Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSecondary),
            title: Text(label),
            trailing: selected ? Icon(Icons.check_rounded, color: AppTheme.primary) : null,
            onTap: () {
              Navigator.of(sheetContext).pop();
              ctrl.setMode(mode);
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l.themeModeTitle,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ),
                option(ThemeMode.system, Icons.brightness_auto_rounded, l.themeModeSystem),
                option(ThemeMode.light, Icons.light_mode_rounded, l.themeModeLight),
                option(ThemeMode.dark, Icons.dark_mode_rounded, l.themeModeDark),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Compact switch used as the trailing widget of the "Dark mode" menu row.
class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key, this.controller});

  final ThemeController? controller;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? ThemeController.instance;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => Transform.scale(
        scale: 0.8,
        child: Switch(
          value: ctrl.isDark,
          onChanged: (v) => ctrl.setMode(v ? ThemeMode.dark : ThemeMode.light),
          thumbIcon: WidgetStateProperty.resolveWith(
            (s) => Icon(
              s.contains(WidgetState.selected) ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 14,
              color: s.contains(WidgetState.selected) ? AppTheme.primary : const Color(0xFFF59E0B),
            ),
          ),
        ),
      ),
    );
  }
}
