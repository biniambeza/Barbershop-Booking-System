import 'package:flutter/material.dart';

/// Every colour of the Crown & Blade design system, once for the light
/// (white + green) and once for the dark (black + green) theme.
///
/// Widgets do not read this directly: they use the `AppTheme.xxx` getters,
/// which return the value from the palette of the active brightness
/// ([AppPalette.light] or [AppPalette.dark], chosen by the ThemeController).
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.heroStart,
    required this.heroEnd,
    required this.heroBorder,
    required this.onHero,
    required this.onHeroMuted,
    required this.navBar,
    required this.navBarBorder,
    required this.navSelected,
    required this.onNavSelected,
    required this.navIcon,
    required this.background,
    required this.card,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.outline,
    required this.track,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.disabledFill,
    required this.green,
    required this.greenSoft,
    required this.success,
    required this.orange,
    required this.orangeSoft,
    required this.warning,
    required this.blue,
    required this.blueSoft,
    required this.red,
    required this.redSoft,
    required this.danger,
    required this.purple,
    required this.purpleSoft,
    required this.teal,
    required this.tealSoft,
    required this.slate,
    required this.slateSoft,
    required this.metallicStart,
    required this.metallicEnd,
    required this.shadow,
    required this.heroShadow,
    required this.photoBackdrop,
  });

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // --- Brand -----------------------------------------------------------------

  /// Brand green fill: primary buttons, selected chips / days / slots, the
  /// active tab indicator, brand icons. (`AppTheme.ink` / `AppTheme.primary`.)
  final Color primary;

  /// Deeper green: pressed states, gradient ends.
  final Color primaryDeep;

  /// Text / icons on a [primary] fill. White in light mode, near-black in
  /// dark mode (the dark-mode green is bright).
  final Color onPrimary;

  /// Hero card gradient (green in light mode, dark green into black in dark).
  final Color heroStart;
  final Color heroEnd;

  /// Hairline around hero cards (transparent in light mode).
  final Color heroBorder;

  /// Text / icons on a hero card or on a photo: white in both modes.
  final Color onHero;

  /// Secondary text on a hero card.
  final Color onHeroMuted;

  // --- Floating navigation bar ----------------------------------------------

  final Color navBar;
  final Color navBarBorder;
  final Color navSelected;
  final Color onNavSelected;
  final Color navIcon;

  // --- Surfaces ----------------------------------------------------------------

  /// Page (scaffold) background.
  final Color background;

  /// Content cards, dialogs, sheets, inputs.
  final Color card;

  /// Panels inside cards, unselected fills, image placeholders.
  final Color surface;

  /// A step above [surface] (pressed / hovered panels).
  final Color surfaceHigh;

  /// Hairline borders and dividers.
  final Color hairline;

  /// Stronger outline (checkbox borders, outlined inputs when needed).
  final Color outline;

  /// Progress bar / slider track.
  final Color track;

  // --- Text --------------------------------------------------------------------

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Background of disabled buttons.
  final Color disabledFill;

  // --- Accents & status ----------------------------------------------------------

  /// Accent green: progress bars, positive fills, accent icons.
  final Color green;
  final Color greenSoft;

  /// Green for text / small icons on cards (AA).
  final Color success;

  final Color orange;
  final Color orangeSoft;

  /// Orange for text / small icons on cards (AA).
  final Color warning;

  final Color blue;
  final Color blueSoft;

  final Color red;
  final Color redSoft;

  /// Red for text / small icons on cards (AA).
  final Color danger;

  final Color purple;
  final Color purpleSoft;

  final Color teal;
  final Color tealSoft;

  /// Neutral grey for "no-show" / inactive states.
  final Color slate;
  final Color slateSoft;

  // --- Effects -------------------------------------------------------------------

  /// Round "metallic" buttons on hero cards (icon colour: [primary]).
  final Color metallicStart;
  final Color metallicEnd;

  /// Soft card shadow colour.
  final Color shadow;

  /// Hero card shadow / glow colour.
  final Color heroShadow;

  /// Full-screen photo viewer background (near-black in both modes).
  final Color photoBackdrop;

  /// White + green.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF16A34A),
    primaryDeep: Color(0xFF15803D),
    onPrimary: Color(0xFFFFFFFF),
    heroStart: Color(0xFF16A34A),
    heroEnd: Color(0xFF15803D),
    heroBorder: Color(0x00000000),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xD9FFFFFF),
    navBar: Color(0xFFFFFFFF),
    navBarBorder: Color(0xFFE7ECE9),
    navSelected: Color(0xFF16A34A),
    onNavSelected: Color(0xFFFFFFFF),
    navIcon: Color(0xFF64748B),
    background: Color(0xFFF7FAF8),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F6F3),
    surfaceHigh: Color(0xFFEAF0EC),
    hairline: Color(0xFFE7ECE9),
    outline: Color(0xFFCBD5CF),
    track: Color(0xFFE4EAE6),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textTertiary: Color(0xFF94A3B8),
    disabledFill: Color(0xFFE2E8E4),
    green: Color(0xFF16A34A),
    greenSoft: Color(0xFFE8F7EE),
    success: Color(0xFF15803D),
    orange: Color(0xFFF08A24),
    orangeSoft: Color(0xFFFDEFE0),
    warning: Color(0xFFB45A06),
    blue: Color(0xFF4F6BED),
    blueSoft: Color(0xFFE8ECFD),
    red: Color(0xFFE5484D),
    redSoft: Color(0xFFFDE9EA),
    danger: Color(0xFFCC2F35),
    purple: Color(0xFF7A4FD6),
    purpleSoft: Color(0xFFF0EAFC),
    teal: Color(0xFF0E8577),
    tealSoft: Color(0xFFE0F3F0),
    slate: Color(0xFF5F6168),
    slateSoft: Color(0xFFEEF0F2),
    metallicStart: Color(0xFFFFFFFF),
    metallicEnd: Color(0xFFE6F4EB),
    shadow: Color(0x120F2A1A),
    heroShadow: Color(0x4D15803D),
    photoBackdrop: Color(0xFF0A0A0A),
  );

  /// Black + green.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF22C55E),
    primaryDeep: Color(0xFF16A34A),
    onPrimary: Color(0xFF0A0A0A),
    heroStart: Color(0xFF14532D),
    heroEnd: Color(0xFF0D1A12),
    heroBorder: Color(0x4022C55E),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xB3FFFFFF),
    navBar: Color(0xFF171717),
    navBarBorder: Color(0xFF2A2A2A),
    navSelected: Color(0xFF22C55E),
    onNavSelected: Color(0xFF0A0A0A),
    navIcon: Color(0xFFA3A3A3),
    background: Color(0xFF0A0A0A),
    card: Color(0xFF151515),
    surface: Color(0xFF1E1E1E),
    surfaceHigh: Color(0xFF262626),
    hairline: Color(0xFF2A2A2A),
    outline: Color(0xFF3F3F3F),
    track: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA3A3A3),
    textTertiary: Color(0xFF737373),
    disabledFill: Color(0xFF262626),
    green: Color(0xFF22C55E),
    greenSoft: Color(0xFF0F2A1A),
    success: Color(0xFF4ADE80),
    orange: Color(0xFFFB923C),
    orangeSoft: Color(0xFF2E1D0C),
    warning: Color(0xFFFDBA74),
    blue: Color(0xFF7B93FF),
    blueSoft: Color(0xFF161E3A),
    red: Color(0xFFEF4444),
    redSoft: Color(0xFF2E1214),
    danger: Color(0xFFF05252),
    purple: Color(0xFFB197FC),
    purpleSoft: Color(0xFF231B38),
    teal: Color(0xFF2DD4BF),
    tealSoft: Color(0xFF0D2724),
    slate: Color(0xFFA1A1AA),
    slateSoft: Color(0xFF232326),
    metallicStart: Color(0xFF2B2B2B),
    metallicEnd: Color(0xFF171717),
    shadow: Color(0x66000000),
    heroShadow: Color(0x3322C55E),
    photoBackdrop: Color(0xFF0A0A0A),
  );
}
