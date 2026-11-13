import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Crown & Blade design system: a light, fintech-style theme.
///
/// Soft grey pages, white rounded cards, a near-black charcoal brand colour
/// (pill buttons, hero cards, the floating nav bar) and a green accent for
/// progress and positive states.
class AppTheme {
  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// Near-black brand colour: primary buttons, selected chips, brand icons.
  static const Color ink = Color(0xFF18181B);

  /// Lighter charcoal (gradient end of buttons / hero card start).
  static const Color charcoal = Color(0xFF2B2B2E);

  /// Darkest charcoal (hero card gradient end).
  static const Color charcoalDeep = Color(0xFF111113);

  /// Floating navigation bar.
  static const Color navBar = Color(0xFF0E0E10);

  /// Text / icons placed on [ink] or the hero card.
  static const Color onInk = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Page background.
  static const Color background = Color(0xFFEDEDED);

  /// Content cards.
  static const Color card = Color(0xFFFFFFFF);

  /// Nested panels inside cards, unselected fills, image placeholders.
  static const Color surface = Color(0xFFF7F7F7);

  /// Hairline borders and dividers.
  static const Color hairline = Color(0xFFE6E6E6);

  /// Progress-bar / slider track.
  static const Color track = Color(0xFFECECEC);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFF111111);

  /// Secondary text. Darker than the reference #8A8A8E so small text passes
  /// WCAG AA (≈5:1 on white, ≈4.4:1 on the grey page).
  static const Color textSecondary = Color(0xFF6B6B70);

  /// Tertiary text / disabled / placeholder.
  static const Color textTertiary = Color(0xFF9A9AA0);

  /// White at 60% for small labels on the hero card.
  static const Color onInkMuted = Color(0x99FFFFFF);

  // ---------------------------------------------------------------------------
  // Accents & semantic colours
  // ---------------------------------------------------------------------------

  /// Brand green: progress bars, positive fills, accent icons.
  static const Color green = Color(0xFF22B14C);

  /// Pale green chip background.
  static const Color greenSoft = Color(0xFFE3F6E8);

  /// Green for text / small icons on white (AA).
  static const Color success = Color(0xFF16803C);

  static const Color orange = Color(0xFFF08A24);
  static const Color orangeSoft = Color(0xFFFDEFE0);

  /// Orange for text / small icons on white (AA).
  static const Color warning = Color(0xFFB45A06);

  static const Color blue = Color(0xFF4F6BED);
  static const Color blueSoft = Color(0xFFE8ECFD);

  static const Color red = Color(0xFFE5484D);
  static const Color redSoft = Color(0xFFFDE9EA);

  /// Red for text / small icons on white (AA).
  static const Color danger = Color(0xFFCC2F35);

  static const Color purple = Color(0xFF7A4FD6);
  static const Color purpleSoft = Color(0xFFF0EAFC);

  static const Color teal = Color(0xFF0E8577);
  static const Color tealSoft = Color(0xFFE0F3F0);

  /// Neutral grey for "no-show" / inactive states.
  static const Color slate = Color(0xFF5F6168);
  static const Color slateSoft = Color(0xFFEDEDEF);

  // ---------------------------------------------------------------------------
  // Shapes, gradients, shadows
  // ---------------------------------------------------------------------------

  static const double radiusCard = 22;
  static const double radiusPanel = 16;
  static const double radiusTile = 12;
  static const double radiusInput = 14;

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [charcoal, charcoalDeep],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [charcoal, ink],
  );

  /// Metallic light gradient for round buttons on the hero card.
  static const LinearGradient metallicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F5F5), Color(0xFFD9D9D9)],
  );

  static List<BoxShadow> get softShadow => const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 8)),
      ];

  static List<BoxShadow> get heroShadow => const [
        BoxShadow(color: Color(0x2E000000), blurRadius: 28, spreadRadius: -8, offset: Offset(0, 14)),
      ];

  /// White rounded card decoration (hairline border + very soft shadow).
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

  /// Charcoal hero card decoration.
  static BoxDecoration get heroDecoration => BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: heroShadow,
      );

  /// Style for a small status chip: pale background, strong foreground.
  static Color softOf(Color strong) {
    if (strong == success || strong == green) return greenSoft;
    if (strong == warning || strong == orange) return orangeSoft;
    if (strong == blue) return blueSoft;
    if (strong == danger || strong == red) return redSoft;
    if (strong == purple) return purpleSoft;
    if (strong == teal) return tealSoft;
    if (strong == slate) return slateSoft;
    return strong.withValues(alpha: 0.12);
  }

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  /// Legacy name kept so existing call sites keep working; the app is light now.
  static ThemeData get darkTheme => lightTheme;

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    TextStyle inter(double size, FontWeight weight, {Color color = textPrimary, double? letterSpacing}) =>
        GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

    const pill = StadiumBorder();
    final colorScheme = const ColorScheme.light(
      primary: ink,
      onPrimary: onInk,
      primaryContainer: Color(0xFFE9E9EC),
      onPrimaryContainer: ink,
      secondary: green,
      onSecondary: Colors.white,
      secondaryContainer: greenSoft,
      onSecondaryContainer: success,
      tertiary: blue,
      onTertiary: Colors.white,
      error: danger,
      onError: Colors.white,
      errorContainer: redSoft,
      onErrorContainer: danger,
      surface: card,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: card,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: Color(0xFFF2F2F2),
      surfaceContainerHighest: Color(0xFFEDEDED),
      outline: Color(0xFFD4D4D8),
      outlineVariant: hairline,
      shadow: Colors.black,
      inverseSurface: ink,
      onInverseSurface: onInk,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
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
        bodySmall: inter(12, FontWeight.w400, color: textSecondary),
        labelLarge: inter(15, FontWeight.w600),
        labelMedium: inter(12, FontWeight.w600, color: textSecondary),
        labelSmall: inter(11, FontWeight.w500, color: textSecondary),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: inter(18, FontWeight.w700),
        iconTheme: const IconThemeData(color: textPrimary),
        actionsIconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x14000000),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          disabledBackgroundColor: const Color(0xFFD9D9DC),
          disabledForegroundColor: textTertiary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: pill,
          textStyle: inter(15, FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          disabledBackgroundColor: const Color(0xFFD9D9DC),
          disabledForegroundColor: textTertiary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: pill,
          textStyle: inter(15, FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: card,
          side: const BorderSide(color: hairline, width: 1.2),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: pill,
          textStyle: inter(15, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          shape: pill,
          textStyle: inter(14, FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: onInk,
        elevation: 2,
        highlightElevation: 4,
        shape: const StadiumBorder(),
        extendedTextStyle: inter(15, FontWeight.w600, color: onInk),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: inter(14, FontWeight.w400, color: textTertiary),
        labelStyle: inter(14, FontWeight.w500, color: textSecondary),
        floatingLabelStyle: inter(14, FontWeight.w600, color: textPrimary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: ink,
        disabledColor: surface,
        checkmarkColor: onInk,
        side: const BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: inter(13, FontWeight.w600).copyWith(
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? onInk : textPrimary),
        ),
        secondaryLabelStyle: inter(13, FontWeight.w600, color: onInk),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        color: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : card),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : card),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onInk : textPrimary),
          side: const WidgetStatePropertyAll(BorderSide(color: hairline)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(inter(13, FontWeight.w600)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBar,
        indicatorColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? ink : const Color(0xFF9A9AA0)),
        ),
        labelTextStyle: WidgetStatePropertyAll(inter(11, FontWeight.w600, color: Colors.white)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: ink,
        dividerColor: hairline,
        labelStyle: inter(14, FontWeight.w600),
        unselectedLabelStyle: inter(14, FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: inter(19, FontWeight.w700),
        contentTextStyle: inter(14, FontWeight.w400, color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: card,
        showDragHandle: false,
        dragHandleColor: Color(0xFFD4D4D8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
          side: const BorderSide(color: hairline),
        ),
        textStyle: inter(14, FontWeight.w500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: inter(14, FontWeight.w500, color: onInk),
        actionTextColor: green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPanel)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: track,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: ink,
        inactiveTrackColor: track,
        thumbColor: ink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? green : const Color(0xFFD4D4D8),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(onInk),
        side: const BorderSide(color: Color(0xFFBDBDC2), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : const Color(0xFFBDBDC2)),
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: textPrimary,
        textColor: textPrimary,
        titleTextStyle: inter(15, FontWeight.w600),
        subtitleTextStyle: inter(13, FontWeight.w400, color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPanel)),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: red, textColor: Colors.white),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(10)),
        textStyle: inter(12, FontWeight.w500, color: onInk),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        headerBackgroundColor: ink,
        headerForegroundColor: onInk,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
