import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

/// Where the theme mode picked on this device is remembered.
abstract class ThemeModeStore {
  Future<String?> read();
  Future<void> write(String mode);
}

/// [ThemeModeStore] backed by shared_preferences (key [key]).
class SharedPrefsThemeModeStore implements ThemeModeStore {
  const SharedPrefsThemeModeStore();

  static const String key = 'app_theme_mode';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String mode) async {
    await (await SharedPreferences.getInstance()).setString(key, mode);
  }
}

/// Light / dark / system theme mode of the app.
///
/// - [mode] is [ThemeMode.system] by default; the choice made with the
///   dark-mode button is kept on this device (shared_preferences) and
///   restored by [loadSaved].
/// - [brightness] is the effective brightness (the mode, or the device
///   setting for [ThemeMode.system]); `AppTheme.xxx` colours read the
///   [palette] of that brightness.
/// - [ThemeRebuilder] (under `MaterialApp.builder`) keeps the device
///   brightness in sync and rebuilds the tree when the brightness changes.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeModeStore? store, Brightness? platformBrightness})
      : _store = store ?? const SharedPrefsThemeModeStore(),
        _platformBrightness = platformBrightness ?? _devicePlatformBrightness();

  static ThemeController instance = ThemeController();

  static Brightness _devicePlatformBrightness() {
    try {
      return PlatformDispatcher.instance.platformBrightness;
    } catch (_) {
      return Brightness.light;
    }
  }

  final ThemeModeStore _store;
  ThemeMode _mode = ThemeMode.system;
  Brightness _platformBrightness;
  bool _userChose = false;

  ThemeMode get mode => _mode;

  /// The device's light / dark setting (used for [ThemeMode.system]).
  Brightness get platformBrightness => _platformBrightness;

  /// The brightness the app is drawn with.
  Brightness get brightness => switch (_mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => _platformBrightness,
      };

  bool get isDark => brightness == Brightness.dark;

  AppPalette get palette => isDark ? AppPalette.dark : AppPalette.light;

  static String _encode(ThemeMode mode) => mode.name; // system / light / dark

  static ThemeMode? _decode(String? value) {
    for (final m in ThemeMode.values) {
      if (m.name == value) return m;
    }
    return null;
  }

  /// Restores the mode last picked on this device. A mode chosen in the
  /// meantime wins.
  Future<void> loadSaved() async {
    String? saved;
    try {
      saved = await _store.read();
    } catch (e) {
      debugPrint('Could not read the saved theme mode: $e');
      return;
    }
    final mode = _decode(saved);
    if (mode == null || _userChose || mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// Switches the theme mode and saves it on this device.
  Future<void> setMode(ThemeMode mode) async {
    _userChose = true;
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
    try {
      await _store.write(_encode(mode));
    } catch (e) {
      debugPrint('Could not save the theme mode on this device: $e');
    }
  }

  /// The dark-mode button: light <-> dark (leaves "system").
  Future<void> toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  /// Records the device brightness. Returns true when the effective
  /// [brightness] changed. Listeners are notified after the current frame
  /// (this is called during build).
  bool syncPlatformBrightness(Brightness value) {
    if (value == _platformBrightness) return false;
    final before = brightness;
    _platformBrightness = value;
    final changed = before != brightness;
    if (changed) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
    return changed;
  }

  /// Status / navigation bar style for [brightness].
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    final dark = brightness == Brightness.dark;
    return (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: p.background,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
  }
}

/// Keeps the static `AppTheme.xxx` colours in step with the theme.
///
/// Put it under `MaterialApp.builder`. When the effective brightness changes
/// (the dark-mode button or the device setting), it marks every element below
/// it for rebuild once, so widgets that read `AppTheme.xxx` repaint with the
/// new palette while keeping their state and the navigation stack. It also
/// sets the status / navigation bar icon colours for the mode.
class ThemeRebuilder extends StatefulWidget {
  const ThemeRebuilder({super.key, required this.child, this.controller});

  final Widget child;

  /// Defaults to [ThemeController.instance].
  final ThemeController? controller;

  @override
  State<ThemeRebuilder> createState() => _ThemeRebuilderState();
}

class _ThemeRebuilderState extends State<ThemeRebuilder> {
  Brightness? _built;

  ThemeController get _controller => widget.controller ?? ThemeController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ThemeRebuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? ThemeController.instance;
    if (old != _controller) {
      old.removeListener(_onChanged);
      _controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted && _controller.brightness != _built) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final platform = MediaQuery.maybePlatformBrightnessOf(context);
    if (platform != null) _controller.syncPlatformBrightness(platform);
    final brightness = _controller.brightness;
    if (_built != null && _built != brightness) {
      // AppTheme.xxx are read at build time: rebuild everything below once.
      void markAll(Element e) {
        e.markNeedsBuild();
        e.visitChildren(markAll);
      }

      (context as Element).visitChildren(markAll);
    }
    _built = brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeController.overlayStyleFor(brightness),
      child: widget.child,
    );
  }
}
