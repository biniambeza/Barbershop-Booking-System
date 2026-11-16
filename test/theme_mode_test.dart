import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/shared/widgets/app_bar_menu.dart';
import 'package:barbershop_booking/features/shared/widgets/theme_mode_toggle.dart';
import 'package:barbershop_booking/features/shared/widgets/ui_kit.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _MemoryThemeStore implements ThemeModeStore {
  _MemoryThemeStore([this.value]);
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String mode) async {
    writes++;
    value = mode;
  }
}

/// A const widget that reads AppTheme at build time (like most screens).
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) =>
      Text('probe', key: const ValueKey('probe'), style: TextStyle(color: AppTheme.textPrimary));
}

/// Wired like BarbershopApp: theme, darkTheme, themeMode and ThemeRebuilder.
Widget _app(Widget home) => ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.mode,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => ThemeRebuilder(child: child!),
        home: home,
      ),
    );

Color? _probeColor(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('probe'))).style?.color;

void main() {
  late _MemoryThemeStore store;

  setUp(() {
    store = _MemoryThemeStore();
    ThemeController.instance = ThemeController(store: store, platformBrightness: Brightness.light);
  });

  tearDown(() {
    ThemeController.instance = ThemeController(store: _MemoryThemeStore(), platformBrightness: Brightness.light);
  });

  group('ThemeController', () {
    test('defaults to system and follows the device brightness', () {
      final c = ThemeController(store: store, platformBrightness: Brightness.dark);
      expect(c.mode, ThemeMode.system);
      expect(c.isDark, isTrue);
      expect(c.palette, AppPalette.dark);
      final light = ThemeController(store: store, platformBrightness: Brightness.light);
      expect(light.isDark, isFalse);
      expect(light.palette, AppPalette.light);
    });

    test('setMode saves the choice and loadSaved restores it', () async {
      final c = ThemeController(store: store, platformBrightness: Brightness.light);
      var notified = 0;
      c.addListener(() => notified++);
      await c.setMode(ThemeMode.dark);
      expect(c.isDark, isTrue);
      expect(store.value, 'dark');
      expect(notified, 1);

      final restored = ThemeController(store: store, platformBrightness: Brightness.light);
      await restored.loadSaved();
      expect(restored.mode, ThemeMode.dark);

      await restored.setMode(ThemeMode.system);
      expect(store.value, 'system');
      expect(restored.isDark, isFalse);
    });

    test('a choice made before loadSaved finishes wins; junk is ignored', () async {
      final c = ThemeController(store: _MemoryThemeStore('dark'), platformBrightness: Brightness.light);
      await c.setMode(ThemeMode.light);
      await c.loadSaved();
      expect(c.mode, ThemeMode.light);

      final junk = ThemeController(store: _MemoryThemeStore('purple'), platformBrightness: Brightness.light);
      await junk.loadSaved();
      expect(junk.mode, ThemeMode.system);
    });

    test('toggle flips light and dark', () async {
      final c = ThemeController(store: store, platformBrightness: Brightness.dark);
      await c.toggle();
      expect(c.mode, ThemeMode.light);
      await c.toggle();
      expect(c.mode, ThemeMode.dark);
    });

    test('AppTheme colours follow the active palette', () async {
      expect(AppTheme.background, AppPalette.light.background);
      expect(AppTheme.ink, AppPalette.light.primary);
      expect(AppTheme.onInk, Colors.white);
      await ThemeController.instance.setMode(ThemeMode.dark);
      expect(AppTheme.background, const Color(0xFF0A0A0A));
      expect(AppTheme.textPrimary, AppPalette.dark.textPrimary);
      expect(AppTheme.softOf(AppTheme.success), AppPalette.dark.greenSoft);
      // Hero text stays white on the dark hero card.
      expect(AppTheme.onHero, Colors.white);
    });

    test('light and dark ThemeData use the palettes', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppPalette.light.background);
      expect(AppTheme.lightTheme.colorScheme.primary, AppPalette.light.primary);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppPalette.dark.background);
      expect(AppTheme.darkTheme.colorScheme.primary, AppPalette.dark.primary);
      expect(AppTheme.darkTheme.colorScheme.onPrimary, AppPalette.dark.onPrimary);
    });
  });

  group('ThemeRebuilder', () {
    testWidgets('repaints const widgets when the mode changes, keeping state', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: Center(child: _Probe()))));
      expect(_probeColor(tester), AppPalette.light.textPrimary);

      await ThemeController.instance.setMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(_probeColor(tester), AppPalette.dark.textPrimary);
      expect(Theme.of(tester.element(find.byKey(const ValueKey('probe')))).brightness, Brightness.dark);

      await ThemeController.instance.setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(_probeColor(tester), AppPalette.light.textPrimary);
    });

    testWidgets('follows the device setting in system mode', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(_app(const Scaffold(body: Center(child: _Probe()))));
      expect(_probeColor(tester), AppPalette.light.textPrimary);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(ThemeController.instance.isDark, isTrue);
      expect(_probeColor(tester), AppPalette.dark.textPrimary);
    });

    testWidgets('sets light status bar icons in dark mode', (tester) async {
      await ThemeController.instance.setMode(ThemeMode.dark);
      await tester.pumpWidget(_app(const Scaffold(body: _Probe())));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarColor, AppPalette.dark.background);
    });
  });

  group('dark mode button', () {
    testWidgets('ThemeModeToggle switches light / dark; long-press offers System default', (tester) async {
      await tester.pumpWidget(_app(Scaffold(appBar: AppBar(actions: const [ThemeModeToggle()]), body: const _Probe())));
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('theme-mode-toggle')));
      await tester.pumpAndSettle();
      expect(ThemeController.instance.mode, ThemeMode.dark);
      expect(store.value, 'dark');
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(_probeColor(tester), AppPalette.dark.textPrimary);

      await tester.longPress(find.byKey(const ValueKey('theme-mode-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('System default'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-mode-system')));
      await tester.pumpAndSettle();
      expect(ThemeController.instance.mode, ThemeMode.system);
      expect(store.value, 'system');
    });

    testWidgets('the app-bar menu has a Dark mode switch for every role', (tester) async {
      loadTestSeed(now: DateTime.utc(2026, 11, 20, 7));
      for (final role in UserRole.values) {
        AppRepository.instance.switchRole(role);
        await ThemeController.instance.setMode(ThemeMode.light);
        await tester.pumpWidget(_app(Scaffold(appBar: AppBar(actions: [AppBarMenu(role: role)]))));
        await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
        await tester.pumpAndSettle();
        expect(find.text('Dark mode'), findsOneWidget, reason: role.name);
        await tester.tap(find.byKey(const ValueKey('app-bar-menu-theme')));
        await tester.pumpAndSettle();
        expect(ThemeController.instance.isDark, isTrue, reason: role.name);
      }
    });

    testWidgets('ui kit widgets render in dark mode', (tester) async {
      await ThemeController.instance.setMode(ThemeMode.dark);
      await tester.pumpWidget(_app(Scaffold(
        body: ListView(children: [
          const AppCard(child: Text('card')),
          const HeroCard(child: Text('hero')),
          const SectionHeader(title: 'Section', actionLabel: 'All'),
          StatusChip(label: 'ok', color: AppTheme.success),
          const AppPill(label: 'pill', selected: true),
          const StatTile(label: 'Bookings', value: '9', icon: Icons.event),
          const EmptyState(icon: Icons.inbox, title: 'Nothing yet', message: 'Come back later'),
        ]),
        bottomNavigationBar: FloatingPillNavBar(
          items: const [
            PillNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
            PillNavItem(icon: Icons.event_outlined, selectedIcon: Icons.event, label: 'Bookings'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      )));
      expect(tester.takeException(), isNull);
      final heroText = tester.widget<DefaultTextStyle>(
          find.ancestor(of: find.text('hero'), matching: find.byType(DefaultTextStyle)).first);
      expect(heroText.style.color, Colors.white);
      expect(find.text('Nothing yet'), findsOneWidget);
    });
  });
}
