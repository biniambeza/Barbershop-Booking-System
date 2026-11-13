import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Shared visual building blocks for the light "fintech" design system.

/// White rounded content card with a hairline border and a soft shadow.
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

/// Near-black charcoal gradient card for the key summary of a screen.
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
        style: const TextStyle(color: AppTheme.onInk),
        child: IconTheme.merge(
          data: const IconThemeData(color: AppTheme.onInk),
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
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppTheme.onInk),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.onInk),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
                child: Icon(icon, size: 20, color: AppTheme.ink),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.onInkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44-48 px white rounded square with a coloured outline icon.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.color = AppTheme.ink, this.size = 46, this.background});

  final IconData icon;
  final Color color;
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
      child: Icon(icon, color: color, size: size * 0.48),
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
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2),
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pale-background status chip with strong-coloured text ("+112%" style).
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

/// Thin (6 px) rounded progress bar.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color = AppTheme.green, this.height = 6});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color,
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

/// Floating black pill navigation bar. The selected destination is a white
/// circle with a dark icon. Use with `Scaffold(extendBody: true)`.
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
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
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
              color: selected ? Colors.white : Colors.transparent,
            ),
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              size: 22,
              color: selected ? AppTheme.ink : const Color(0xFFA1A1A8),
            ),
          ),
        ),
      ),
    );
  }
}
