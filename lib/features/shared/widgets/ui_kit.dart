import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Shared visual building blocks of the Crown & Blade design system
/// (white + green light theme, black + green dark theme). Every widget here
/// reads the active palette through `AppTheme.xxx`, so it works in both modes.

/// Rounded content card (white / near-black) with a hairline border and a
/// soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = AppTheme.radiusCard,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: AppTheme.cardDecoration(radius: radius, color: color, borderColor: borderColor),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

/// Key summary card of a screen: green gradient (light) / dark green into
/// black (dark). Text and icons inside default to [AppTheme.onHero].
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.margin});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: AppTheme.heroDecoration,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: AppTheme.onHero),
        child: IconTheme.merge(
          data: IconThemeData(color: AppTheme.onHero),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small translucent pill shown on the hero card.
class HeroChip extends StatelessWidget {
  const HeroChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: AppTheme.isDark ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: AppTheme.isDark ? 0.12 : 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppTheme.onHero),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.onHero),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round metallic action button with a small label below (hero card).
class HeroActionButton extends StatelessWidget {
  const HeroActionButton({super.key, required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.metallicGradient,
                  border: AppTheme.isDark ? Border.all(color: AppTheme.hairline) : null,
                ),
                child: Icon(icon, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.onHeroMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44-48 px rounded square with a coloured outline icon.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.color, this.size = 46, this.background});

  final IconData icon;

  /// Icon colour; defaults to [AppTheme.primary].
  final Color? color;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Icon(icon, color: color ?? AppTheme.primary, size: size * 0.48),
    );
  }
}

/// "Title ........ View all >" section header.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.padding});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2),
            ),
          ),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success)),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.success),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft-background status chip with strong-coloured text ("+112%" style).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon, this.background});

  final String label;
  final Color color;
  final IconData? icon;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? AppTheme.softOf(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Selectable pill (filters, categories): green fill when selected, card
/// with a hairline otherwise.
class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppTheme.onPrimary : AppTheme.textPrimary;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? AppTheme.primary : AppTheme.card,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppTheme.primary : AppTheme.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? AppTheme.onPrimary : AppTheme.primary),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small metric tile: icon, big value, label (dashboards).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.color, this.onTap});

  final String label;
  final String value;
  final IconData? icon;

  /// Accent of the icon; defaults to [AppTheme.primary].
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.primary;
    return AppCard(
      radius: AppTheme.radiusPanel,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppTheme.softOf(accent), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.4),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Centered "nothing here yet" block: soft green circle with an icon, a
/// title, an optional message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppTheme.greenSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: AppTheme.textSecondary),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Thin (6 px) rounded progress bar.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color, this.height = 6});

  final double value;

  /// Defaults to [AppTheme.green].
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color ?? AppTheme.green,
        backgroundColor: AppTheme.track,
      ),
    );
  }
}

/// Item for [FloatingPillNavBar].
class PillNavItem {
  const PillNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating pill navigation bar (white in light mode, near-black in dark
/// mode). The selected destination is a green circle. Use with
/// `Scaffold(extendBody: true)`.
class FloatingPillNavBar extends StatelessWidget {
  const FloatingPillNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PillNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Space to leave at the bottom of scrollable content so it can scroll
  /// clear of the bar.
  static const double contentPadding = 100;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 14),
      child: Center(
        heightFactor: 1,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.navBar,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.navBarBorder),
            boxShadow: [
              BoxShadow(
                color: AppTheme.isDark ? const Color(0x80000000) : const Color(0x260F2A1A),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: _PillNavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item for [AppBottomNavBar].
class BottomNavItem {
  const BottomNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.key,
    this.wrapIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// Key on the tappable item (tests find tabs by it).
  final Key? key;

  /// Optional decoration around the icon, e.g. a badge dot.
  final Widget Function(Widget icon)? wrapIcon;
}

/// Full-width bottom navigation bar used by every role: icon + label per
/// destination, the selected one in green, no highlight box. White in light
/// mode, near-black in dark mode, with a hairline on top.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Space to leave at the bottom of scrollable content above the bar.
  static const double contentPadding = 24;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.navBar,
        border: Border(top: BorderSide(color: AppTheme.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({required this.item, required this.selected, required this.onTap});

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.success : AppTheme.textSecondary;
    Widget icon = Icon(selected ? (item.selectedIcon ?? item.icon) : item.icon, size: 24, color: color);
    if (item.wrapIcon != null) icon = item.wrapIcon!(icon);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: item.key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                // Based on the theme's text style so the app font is kept.
                style: (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0,
                ),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNavButton extends StatelessWidget {
  const _PillNavButton({required this.item, required this.selected, required this.onTap});

  final PillNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppTheme.navSelected : Colors.transparent,
            ),
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              size: 22,
              color: selected ? AppTheme.onNavSelected : AppTheme.navIcon,
            ),
          ),
        ),
      ),
    );
  }
}
