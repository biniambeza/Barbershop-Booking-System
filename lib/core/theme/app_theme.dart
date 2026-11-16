import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';
import 'theme_controller.dart';

export 'app_palette.dart';
export 'theme_controller.dart';

/// Crown & Blade design system: white + green (light) and black + green
/// (dark).
///
/// Every colour below is a getter that reads the palette of the active
/// brightness ([ThemeController.instance]), so `AppTheme.textPrimary` is
/// near-black in light mode and near-white in dark mode. Because they are not
/// compile-time constants, do not put them inside `const` expressions or use
/// them as default parameter values (make the parameter nullable and fall
/// back in `build`).
///
/// Token meanings (see also [AppPalette]):
/// - [primary] / [ink]: brand green fill: primary buttons, selected chips /
///   days / slots, tab indicators, brand icons. Text on it: [onPrimary] /
///   [onInk] (white in light mode, near-black in dark mode).
/// - Hero cards: [heroDecoration] (green gradient in light mode, dark green
///   into black in dark mode). Text on them: [onHero] / [onHeroMuted] (white
///   in both modes); never [onInk] for hero text.
/// - Photos / image overlays: [onHero] (white), viewer backdrop
///   [photoBackdrop].
/// - Pages: [background]; cards: [card] / [cardDecoration]; panels inside
///   cards: [surface] / [panelDecoration]; borders: [hairline].
/// - Status colours ([success], [warning], [danger], [blue], ...) keep their
///   meaning; [softOf] gives the matching pale (light) / dark (dark mode)
///   chip background.
class AppTheme {
  AppTheme._();

  /// The palette of the active brightness.
  static AppPalette get palette => ThemeController.instance.palette;
  static AppPalette get _p => palette;

  /// True while the app is drawn in dark mode.
  static bool get isDark => _p.isDark;

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// Brand green fill (buttons, selected states, brand icons).
  static Color get primary => _p.primary;

  /// Deeper green (pressed states, gradient ends).
  static Color get primaryDeep => _p.primaryDeep;

  /// Text / icons on a [primary] fill.
  static Color get onPrimary => _p.onPrimary;

  /// Legacy name of [primary] (was near-black before the green theme).
  static Color get ink => _p.primary;

  /// Legacy name of [onPrimary]. Only for content on an [ink] fill; use
  /// [onHero] on hero cards and photos.
  static Color get onInk => _p.onPrimary;

  /// Hero gradient start (was the charcoal hero colour).
  static Color get heroStart => _p.heroStart;

  /// Hero gradient end.
  static Color get heroEnd => _p.heroEnd;

  /// Legacy name of [heroStart].
  static Color get charcoal => _p.heroStart;

  /// Legacy name of [heroEnd].
  static Color get charcoalDeep => _p.heroEnd;

  /// Text / icons on hero cards and photos (white in both modes).
  static Color get onHero => _p.onHero;

  /// Secondary text on hero cards.
  static Color get onHeroMuted => _p.onHeroMuted;

  /// Legacy name of [onHeroMuted].
  static Color get onInkMuted => _p.onHeroMuted;

  /// Floating navigation bar fill.
  static Color get navBar => _p.navBar;
  static Color get navBarBorder => _p.navBarBorder;
  static Color get navSelected => _p.navSelected;
  static Color get onNavSelected => _p.onNavSelected;
  static Color get navIcon => _p.navIcon;

  /// Full-screen photo viewer background (near-black in both modes).
  static Color get photoBackdrop => _p.photoBackdrop;

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Page background.
  static Color get background => _p.background;

  /// Alias of [background].
  static Color get pageBackground => _p.background;

  /// Content cards.
  static Color get card => _p.card;

  /// Nested panels inside cards, unselected fills, image placeholders.
  static Color get surface => _p.surface;

  /// A step above [surface].
  static Color get surfaceHigh => _p.surfaceHigh;

  /// Hairline borders and dividers.
  static Color get hairline => _p.hairline;

  /// Stronger outline.
  static Color get outline => _p.outline;

  /// Progress-bar / slider track.
  static Color get track => _p.track;

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static Color get textPrimary => _p.textPrimary;

  /// Secondary text (AA on cards and pages in both modes).
  static Color get textSecondary => _p.textSecondary;

  /// Tertiary text / disabled / placeholder.
  static Color get textTertiary => _p.textTertiary;

  // ---------------------------------------------------------------------------
  // Accents & semantic colours
  // ---------------------------------------------------------------------------

  /// Accent green: progress bars, positive fills, accent icons. Text on a
  /// green fill: [onPrimary].
  static Color get green => _p.green;

  /// Pale (light) / dark (dark mode) green chip background.
  static Color get greenSoft => _p.greenSoft;

  /// Green for text / small icons on cards (AA).
  static Color get success => _p.success;

  static Color get orange => _p.orange;
  static Color get orangeSoft => _p.orangeSoft;

  /// Orange for text / small icons on cards (AA).
  static Color get warning => _p.warning;

  static Color get blue => _p.blue;
  static Color get blueSoft => _p.blueSoft;

  static Color get red => _p.red;
  static Color get redSoft => _p.redSoft;

  /// Red for text / small icons on cards (AA).
  static Color get danger => _p.danger;

  static Color get purple => _p.purple;
  static Color get purpleSoft => _p.purpleSoft;

  static Color get teal => _p.teal;
  static Color get tealSoft => _p.tealSoft;

  /// Neutral grey for "no-show" / inactive states.
  static Color get slate => _p.slate;
  static Color get slateSoft => _p.slateSoft;

  // ---------------------------------------------------------------------------
  // Shapes, gradients, shadows
  // ---------------------------------------------------------------------------

  static const double radiusCard = 22;
  static const double radiusPanel = 16;
  static const double radiusTile = 12;
  static const double radiusInput = 14;
  static const double radiusHero = 24;

  /// Hero card gradient.
  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_p.heroStart, _p.heroEnd],
      );

  /// Green button gradient.
  static LinearGradient get buttonGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_p.primary, _p.primaryDeep],
      );

  /// Round buttons on the hero card (icon colour: [primary]).
  static LinearGradient get metallicGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_p.metallicStart, _p.metallicEnd],
      );

  static List<BoxShadow> get softShadow => [
        BoxShadow(color: _p.shadow, blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 8)),
      ];

  static List<BoxShadow> get heroShadow => [
        BoxShadow(color: _p.heroShadow, blurRadius: 28, spreadRadius: -8, offset: const Offset(0, 14)),
      ];

  /// Rounded card decoration (hairline border + very soft shadow).
  static BoxDecoration cardDecoration({double radius = radiusCard, Color? color, Color? borderColor}) =>
      BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? hairline),
        boxShadow: softShadow,
      );

  /// Inner panel decoration (inside a card).
  static BoxDecoration panelDecoration({double radius = radiusPanel, Color? color, Color? borderColor}) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? hairline),
      );

  /// Hero card decoration: green gradient (light) / dark green into black
  /// with a green hairline (dark).
  static BoxDecoration get heroDecoration => BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(radiusHero),
        border: _p.isDark ? Border.all(color: _p.heroBorder) : null,
        boxShadow: heroShadow,
      );

  /// Pale (light) / dark (dark mode) background for a status chip whose
  /// foreground is [strong].
  static Color softOf(Color strong) {
    final p = _p;
    if (strong == p.success || strong == p.green || strong == p.primary) return p.greenSoft;
    if (strong == p.warning || strong == p.orange) return p.orangeSoft;
    if (strong == p.blue) return p.blueSoft;
    if (strong == p.danger || strong == p.red) return p.redSoft;
    if (strong == p.purple) return p.purpleSoft;
    if (strong == p.teal) return p.tealSoft;
    if (strong == p.slate) return p.slateSoft;
    return strong.withValues(alpha: p.isDark ? 0.18 : 0.12);
  }

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData? _light;
  static ThemeData? _dark;

  /// White + green.
  static ThemeData get lightTheme => _light ??= _build(AppPalette.light);

  /// Black + green.
  static ThemeData get darkTheme => _dark ??= _build(AppPalette.dark);

  /// The theme of the active brightness.
  static ThemeData get currentTheme => isDark ? darkTheme : lightTheme;

  static ThemeData _build(AppPalette p) {
    final dark = p.isDark;
    final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );
    TextStyle inter(double size, FontWeight weight, {Color? color, double? letterSpacing}) => GoogleFonts.inter(
        fontSize: size, fontWeight: weight, color: color ?? p.textPrimary, letterSpacing: letterSpacing);

    const pill = StadiumBorder();
    final colorScheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.greenSoft,
      onPrimaryContainer: p.success,
      secondary: p.green,
      onSecondary: p.onPrimary,
      secondaryContainer: p.greenSoft,
      onSecondaryContainer: p.success,
      tertiary: p.blue,
      onTertiary: dark ? const Color(0xFF0A0A0A) : Colors.white,
      error: p.danger,
      onError: dark ? const Color(0xFF0A0A0A) : Colors.white,
      errorContainer: p.redSoft,
      onErrorContainer: p.danger,
      surface: p.card,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: dark ? p.background : p.card,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceHigh,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.outline,
      outlineVariant: p.hairline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? const Color(0xFFF5F5F5) : const Color(0xFF0F172A),
      onInverseSurface: dark ? const Color(0xFF0A0A0A) : Colors.white,
      inversePrimary: dark ? p.primaryDeep : const Color(0xFF4ADE80),
      surfaceTint: Colors.transparent,
    );

    final overlay = ThemeController.overlayStyleFor(p.brightness);

    OutlineInputBorder inputBorder(Color color, [double width = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      cardColor: p.card,
      dividerColor: p.hairline,
      disabledColor: p.textTertiary,
      hintColor: p.textTertiary,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.copyWith(
        displaySmall: inter(34, FontWeight.w700, letterSpacing: -0.8),
        headlineLarge: inter(30, FontWeight.w700, letterSpacing: -0.6),
        headlineMedium: inter(26, FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: inter(22, FontWeight.w700, letterSpacing: -0.3),
        titleLarge: inter(20, FontWeight.w600, letterSpacing: -0.2),
        titleMedium: inter(16, FontWeight.w600),
        titleSmall: inter(14, FontWeight.w600),
        bodyLarge: inter(16, FontWeight.w400),
        bodyMedium: inter(14, FontWeight.w400),
        bodySmall: inter(12, FontWeight.w400, color: p.textSecondary),
        labelLarge: inter(15, FontWeight.w600),
        labelMedium: inter(12, FontWeight.w600, color: p.textSecondary),
        labelSmall: inter(11, FontWeight.w500, color: p.textSecondary),
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlay,
        titleTextStyle: inter(18, FontWeight.w700),
        iconTheme: IconThemeData(color: p.textPrimary),
        actionsIconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadow,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: p.hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.disabledFill,
          disabledForegroundColor: p.textTertiary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: pill,
          textStyle: inter(15, FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.disabledFill,
          disabledForegroundColor: p.textTertiary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: pill,
          textStyle: inter(15, FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.card,
          side: BorderSide(color: p.hairline, width: 1.2),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: pill,
          textStyle: inter(15, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.success,
          shape: pill,
          textStyle: inter(14, FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: const StadiumBorder(),
        extendedTextStyle: inter(15, FontWeight.w700, color: p.onPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: inter(14, FontWeight.w400, color: p.textTertiary),
        labelStyle: inter(14, FontWeight.w500, color: p.textSecondary),
        floatingLabelStyle: inter(14, FontWeight.w600, color: p.success),
        prefixIconColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.focused) ? p.primary : p.textSecondary),
        suffixIconColor: p.textSecondary,
        border: inputBorder(p.outline),
        enabledBorder: inputBorder(dark ? p.outline : p.hairline),
        focusedBorder: inputBorder(p.primary, 1.8),
        disabledBorder: inputBorder(p.hairline),
        errorBorder: inputBorder(p.danger),
        focusedErrorBorder: inputBorder(p.danger, 1.8),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.3),
        selectionHandleColor: p.primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: p.primary,
        disabledColor: p.surface,
        checkmarkColor: p.onPrimary,
        side: BorderSide(color: p.hairline),
        shape: const StadiumBorder(),
        labelStyle: inter(13, FontWeight.w600).copyWith(
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary),
        ),
        secondaryLabelStyle: inter(13, FontWeight.w600, color: p.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        color: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.card),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.card),
          foregroundColor:
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary),
          side: WidgetStatePropertyAll(BorderSide(color: p.hairline)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(inter(13, FontWeight.w600)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.navBar,
        indicatorColor: p.navSelected,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.onNavSelected : p.navIcon),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => inter(11, FontWeight.w600, color: s.contains(WidgetState.selected) ? p.textPrimary : p.navIcon),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.navBar,
        indicatorColor: p.navSelected,
        selectedIconTheme: IconThemeData(color: p.onNavSelected),
        unselectedIconTheme: IconThemeData(color: p.navIcon),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.primary,
        dividerColor: p.hairline,
        labelStyle: inter(14, FontWeight.w600),
        unselectedLabelStyle: inter(14, FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: dark ? BorderSide(color: p.hairline) : BorderSide.none,
        ),
        titleTextStyle: inter(19, FontWeight.w700),
        contentTextStyle: inter(14, FontWeight.w400, color: p.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.card,
        showDragHandle: false,
        dragHandleColor: p.outline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
          side: BorderSide(color: p.hairline),
        ),
        textStyle: inter(14, FontWeight.w500),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF262626) : const Color(0xFF0F172A),
        contentTextStyle: inter(14, FontWeight.w500, color: dark ? const Color(0xFFF5F5F5) : Colors.white),
        actionTextColor: dark ? p.primary : const Color(0xFF4ADE80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPanel)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.track,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.track,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (dark ? p.onPrimary : Colors.white) : (dark ? p.textSecondary : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : (dark ? p.surfaceHigh : const Color(0xFFD5DDD8)),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) || !dark ? Colors.transparent : p.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor:
            WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        side: BorderSide(color: p.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.outline),
      ),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textPrimary,
        textColor: p.textPrimary,
        titleTextStyle: inter(15, FontWeight.w600),
        subtitleTextStyle: inter(13, FontWeight.w400, color: p.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPanel)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.textPrimary,
        collapsedIconColor: p.textSecondary,
        textColor: p.textPrimary,
        collapsedTextColor: p.textPrimary,
      ),
      badgeTheme: BadgeThemeData(backgroundColor: p.red, textColor: Colors.white),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2A2A2A) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: inter(12, FontWeight.w500, color: dark ? const Color(0xFFF5F5F5) : Colors.white),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        headerBackgroundColor: p.primary,
        headerForegroundColor: p.onPrimary,
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return p.onPrimary;
          if (s.contains(WidgetState.disabled)) return p.textTertiary;
          return p.textPrimary;
        }),
        dayBackgroundColor:
            WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : null),
        todayForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.success),
        todayBackgroundColor:
            WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : null),
        todayBorder: BorderSide(color: p.primary),
        yearForegroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary),
        yearBackgroundColor:
            WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : null),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.success),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.textSecondary),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        dialHandColor: p.primary,
        dialBackgroundColor: p.surface,
        hourMinuteColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.greenSoft : p.surface),
        hourMinuteTextColor:
            WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.success : p.textPrimary),
        dayPeriodColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.greenSoft : p.card),
        dayPeriodTextColor:
            WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.success : p.textSecondary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.success),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.textSecondary),
      ),
    );
  }
}

/// Brand colours that never change with the theme, for `const` contexts
/// (launcher icon / splash art, the intro). Prefer the `AppTheme.xxx`
/// getters everywhere else.
class BrandColors {
  BrandColors._();

  /// Brand green (light-mode primary).
  static const Color green = Color(0xFF16A34A);

  /// Deeper brand green.
  static const Color greenDeep = Color(0xFF15803D);

  /// Bright brand green (dark-mode primary).
  static const Color greenBright = Color(0xFF22C55E);

  /// Dark green (dark-mode hero start).
  static const Color greenNight = Color(0xFF14532D);

  /// Splash / intro background, light mode.
  static const Color splashLight = Color(0xFFFFFFFF);

  /// Splash / intro background, dark mode; also the near-black of the brand.
  static const Color black = Color(0xFF0A0A0A);

  /// Old charcoal brand colours (kept for brand art that still uses them).
  static const Color charcoal = Color(0xFF2B2B2E);
  static const Color charcoalDeep = Color(0xFF111113);
  static const Color ink = Color(0xFF18181B);
}
