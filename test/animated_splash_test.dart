import 'dart:io';
import 'dart:ui' as ui;

import 'package:barbershop_booking/core/brand/crown_blade_logo.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/features/splash/animated_splash.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'test_helpers.dart';

/// Language store for widget tests (no shared_preferences).
class _MemoryLanguageStore implements LanguageStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String code) async => value = code;
}

/// Readiness the tests flip by hand.
class _Ready extends ChangeNotifier {
  _Ready(this.value);
  bool value;
  void set(bool v) {
    value = v;
    notifyListeners();
  }
}

const _appKey = ValueKey('app-under-intro');

/// An app with one button under the intro.
Widget _harness(_Ready ready,
        {VoidCallback? onFinished, VoidCallback? onAppTap, Brightness? brightness}) =>
    MaterialApp(
      theme: ThemeData(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => AnimatedSplash(
        isReady: () => ready.value,
        readiness: ready,
        onFinished: onFinished,
        brightness: brightness,
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox.expand(
          child: TextButton(key: _appKey, onPressed: onAppTap, child: const Text('APP')),
        ),
      ),
    );

/// Pumps [widget] and the frame that starts the intro (t = 0).
Future<void> _start(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
}

/// Advances to [seconds] after the start, in 1/60 s frames.
Future<void> _advance(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(microseconds: 1000000 ~/ 60));
  }
}

Finder get _logo => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is IntroLogoPainter);

/// The painter of the intro logo.
IntroLogoPainter _drawn(WidgetTester tester) => tester.widget<CustomPaint>(_logo).painter! as IntroLogoPainter;

Finder get _overlay => find.byType(IntroScene);

/// The combined opacity of the FadeTransitions above the widget with [key].
double _fadeAbove(WidgetTester tester, Key key) {
  final fades = tester.widgetList<FadeTransition>(find.ancestor(of: find.byKey(key), matching: find.byType(FadeTransition)));
  return fades.fold(1.0, (a, f) => a * f.opacity.value);
}

const _fields = ['logoScale', 'twinkle', 'glint', 'gemShine', 'lift', 'wordmark', 'tagline'];
List<double> _values(IntroFrame f) => [f.logoScale, f.twinkle, f.glint, f.gemShine, f.lift, f.wordmark, f.tagline];

void main() {
  group('IntroFrame timeline', () {
    test('starts on exactly the native splash: the static logo, nothing else', () {
      final f = IntroFrame.at(0);
      expect(_values(f), [1, 0, 0, 0, 0, 0, 0]);
      // The painter draws the full static logo (no effect runs at 0).
      final p = f.painter(CrownBladeVariant.onLight);
      expect([p.crownProgress, p.bladeProgress, p.gemProgress], [1, 1, 1]);
      expect(p.padding, IntroTimeline.logoPadding);
    });

    test('values at key times', () {
      expect(IntroFrame.at(0.4).logoScale, closeTo(IntroTimeline.breathPeak, 1e-9));
      expect(IntroFrame.at(0.2).logoScale, inExclusiveRange(1, IntroTimeline.breathPeak));
      expect(IntroFrame.at(0.8).logoScale, closeTo(1, 1e-9));
      expect(IntroFrame.at(0.5).twinkle, inExclusiveRange(0, 1));
      expect(IntroFrame.at(0.7).glint, inExclusiveRange(0, 1));
      expect(IntroFrame.at(1.0).gemShine, inExclusiveRange(0, 1));
      expect(IntroFrame.at(0.8).lift, 0);
      expect(IntroFrame.at(1.3).lift, 1);
      expect(IntroFrame.at(0.9).wordmark, 0);
      expect(IntroFrame.at(1.2).wordmark, inExclusiveRange(0, 1));
      expect(IntroFrame.at(1.45).wordmark, 1);
      expect(IntroFrame.at(1.2).tagline, 0);
      expect(IntroFrame.at(1.65).tagline, 1);
    });

    test('ends on the finished frame and never goes past the breath peak', () {
      final end = IntroFrame.at(IntroTimeline.intro.inMilliseconds / 1000);
      expect(_values(end), _values(IntroFrame.finished));
      var peak = 0.0;
      for (var t = 0.0; t <= 2.0; t += 0.005) {
        final s = IntroFrame.at(t).logoScale;
        if (s > peak) peak = s;
      }
      expect(peak, lessThanOrEqualTo(IntroTimeline.breathPeak + 1e-9));
    });

    test('is smooth: no value jumps between two 60 Hz frames', () {
      // Largest change allowed per 1/60 s for each value.
      const maxStep = {
        'logoScale': 0.004, // < 1.2 dp on the 288 dp canvas
        'twinkle': 0.03,
        'glint': 0.05,
        'gemShine': 0.06,
        'lift': 0.11, // < 4.4 dp
        'wordmark': 0.09,
        'tagline': 0.11,
      };
      var prev = _values(IntroFrame.at(0));
      for (var i = 1; i <= 120; i++) {
        final cur = _values(IntroFrame.at(i / 60));
        for (var k = 0; k < cur.length; k++) {
          expect((cur[k] - prev[k]).abs(), lessThan(maxStep[_fields[k]]!), reason: '${_fields[k]} at frame $i');
        }
        prev = cur;
      }
      // The exit too: no step larger than 12 % of the whole move.
      final frames = (IntroTimeline.exit.inMilliseconds / 1000 * 60).ceil();
      for (final a in [IntroTimeline.exitOpacity, IntroTimeline.exitScale, IntroTimeline.exitRise]) {
        final range = (a.transform(1) - a.transform(0)).abs();
        var p = a.transform(0);
        for (var i = 1; i <= frames; i++) {
          final v = a.transform((i / frames).clamp(0.0, 1.0));
          expect((v - p).abs() / range, lessThan(0.12));
          p = v;
        }
      }
    });
  });

  group('AnimatedSplash', () {
    testWidgets('first frame: the native splash logo, same size and place', (tester) async {
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(tester.getRect(_logo), Rect.fromCenter(center: screen.center, width: 288, height: 288));
      expect(_values(_drawn(tester).frame), _values(IntroFrame.at(0)));
      expect(_fadeAbove(tester, const ValueKey('intro-wordmark')), 0);
    });

    for (final (brightness, background, variant) in [
      (Brightness.light, const Color(0xFFFFFFFF), CrownBladeVariant.onLight),
      (Brightness.dark, const Color(0xFF0A0A0A), CrownBladeVariant.onDark),
    ]) {
      testWidgets('follows the device brightness (${brightness.name})', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _start(tester, _harness(_Ready(true)));
        final material = tester.widget<Material>(find.descendant(of: _overlay, matching: find.byType(Material)).first);
        expect(material.color, background);
        expect(_drawn(tester).variant, variant);
        expect(SystemChrome.latestStyle?.statusBarIconBrightness,
            brightness == Brightness.dark ? Brightness.light : Brightness.dark);
      });
    }

    testWidgets('plays the timeline over the app, which builds underneath', (tester) async {
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      expect(_overlay, findsOneWidget);
      expect(find.byKey(_appKey), findsOneWidget); // built under the intro

      await _advance(tester, 0.7);
      final f = _drawn(tester).frame;
      expect(f.glint, closeTo(IntroFrame.at(0.7).glint, 0.03));
      expect(f.glint, inExclusiveRange(0, 1));

      await _advance(tester, 0.8); // 1.5 s
      expect(find.text('CROWN & BLADE'), findsOneWidget);
      expect(_fadeAbove(tester, const ValueKey('intro-wordmark')), closeTo(1, 1e-6));

      await _advance(tester, 0.2); // 1.7 s
      expect(find.text('Book your barber in Addis Ababa'), findsOneWidget);
      expect(_fadeAbove(tester, const ValueKey('intro-tagline')), closeTo(1, 1e-6));
      expect(_overlay, findsOneWidget);
    });

    testWidgets('leaves after the animation when the app is ready, and the app takes taps', (tester) async {
      final ready = _Ready(true);
      var finished = 0;
      var appTaps = 0;
      await _start(tester, _harness(ready, onFinished: () => finished++, onAppTap: () => appTaps++));

      await _advance(tester, 0.3);
      expect(_overlay, findsOneWidget);
      await _advance(tester, 1.6); // 1.9 s: not finished yet
      expect(_overlay, findsOneWidget);

      await _advance(tester, 0.1 + 0.25); // mid-exit: the logo rises and grows
      expect(_overlay, findsOneWidget);
      final scales = tester
          .widgetList<ScaleTransition>(find.ancestor(of: _logo, matching: find.byType(ScaleTransition)))
          .map((s) => s.scale.value);
      expect(scales.any((s) => s > 1.02), isTrue);

      await _advance(tester, 0.25); // 2.0 s + the exit
      expect(_overlay, findsNothing);
      expect(finished, 1);
      await tester.tap(find.byKey(_appKey));
      expect(appTaps, 1);
      // The app's style after the intro.
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('holds on the finished logo until the app is ready', (tester) async {
      final ready = _Ready(false);
      var finished = 0;
      await _start(tester, _harness(ready, onFinished: () => finished++));
      await _advance(tester, 3);
      expect(_overlay, findsOneWidget);
      expect(find.byKey(const ValueKey('intro-progress')), findsOneWidget);
      expect(_values(_drawn(tester).frame), _values(IntroFrame.finished));

      ready.set(true);
      await _advance(tester, 0.5);
      expect(_overlay, findsNothing);
      expect(finished, 1);
    });

    testWidgets('a ready app never waits longer than the cap', (tester) async {
      // A slow device: everything runs at a fifth of the speed.
      timeDilation = 5;
      addTearDown(() => timeDilation = 1);
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      await _advance(tester, IntroTimeline.readyCap.inMilliseconds / 1000 - 0.1);
      expect(_overlay, findsOneWidget);
      expect(tester.widget<IgnorePointer>(_ignorePointer).ignoring, isFalse);
      await _advance(tester, 0.2);
      // Exiting: the app already takes taps while the intro fades.
      expect(tester.widget<IgnorePointer>(_ignorePointer).ignoring, isTrue);
      timeDilation = 1;
      await _advance(tester, 0.5);
      expect(_overlay, findsNothing);
    });

    testWidgets('steps aside after the hold limit even if the app never gets ready', (tester) async {
      final ready = _Ready(false);
      await _start(tester, _harness(ready));
      await _advance(tester, IntroTimeline.maxHold.inMilliseconds / 1000 - 0.2);
      expect(_overlay, findsOneWidget);
      await _advance(tester, 0.75);
      expect(_overlay, findsNothing);
    });

    testWidgets('tap skips to the exit once the app is ready', (tester) async {
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      await _advance(tester, 0.3);
      await tester.tapAt(const Offset(200, 200));
      await _advance(tester, 0.5);
      expect(_overlay, findsNothing);

      // Not ready: the tap is remembered and the intro leaves when ready.
      final notReady = _Ready(false);
      await tester.pumpWidget(const SizedBox());
      await _start(tester, _harness(notReady));
      await _advance(tester, 0.3);
      await tester.tapAt(const Offset(200, 200));
      await _advance(tester, 0.5);
      expect(_overlay, findsOneWidget);
      notReady.set(true);
      await _advance(tester, 0.5);
      expect(_overlay, findsNothing);
    });

    testWidgets('reduce motion: the static logo, then a plain fade', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      expect(_values(_drawn(tester).frame), _values(IntroFrame.finished));
      expect(find.text('CROWN & BLADE'), findsOneWidget);
      expect(_fadeAbove(tester, const ValueKey('intro-wordmark')), 1);

      await _advance(tester, 0.7); // past the short hold: fading
      expect(_overlay, findsOneWidget);
      // No zoom while it fades.
      expect(
        find.descendant(of: find.byType(AnimatedSplash), matching: find.byType(Transform)).evaluate().where((e) {
          final t = e.widget as Transform;
          return t.transform.getMaxScaleOnAxis() > 1.0001;
        }),
        isEmpty,
      );
      await _advance(tester, 0.5);
      expect(_overlay, findsNothing);
    });

    testWidgets('is labelled for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _start(tester, _harness(_Ready(true)));
      expect(find.bySemanticsLabel('Crown & Blade'), findsOneWidget);
      expect(find.bySemanticsLabel('APP'), findsNothing); // the app is hidden
      await _advance(tester, 2.6);
      expect(find.bySemanticsLabel('APP'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('disabled: only the app', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => AnimatedSplash(enabled: false, child: child!),
        home: const Text('APP'),
      ));
      expect(_overlay, findsNothing);
      expect(find.text('APP'), findsOneWidget);
    });

    testWidgets('StartupHoldScreen: the finished logo with a progress bar, in the theme brightness', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: Brightness.dark), home: const StartupHoldScreen()));
      expect(find.byKey(const ValueKey('intro-progress')), findsOneWidget);
      expect(find.text('CROWN & BLADE'), findsOneWidget);
      expect(_drawn(tester).variant, CrownBladeVariant.onDark);
    });
  });

  testWidgets('BarbershopApp: the intro plays once on start, then the sign-in screen', (tester) async {
    loadTestSeed();
    final previous = LocaleController.instance;
    // In memory: shared_preferences never answers inside a widget test.
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'), store: _MemoryLanguageStore());
    addTearDown(() => LocaleController.instance = previous);

    await _start(tester, const BarbershopApp());
    expect(_overlay, findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget); // built underneath
    await _advance(tester, 2.6);
    expect(_overlay, findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);

    // A rebuild (language change) doesn't replay it.
    await LocaleController.instance.setLanguage('am');
    await tester.pump();
    await tester.pump();
    expect(_overlay, findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Frames for review (not part of the normal suite: 'brand' is skipped).
  //   flutter test --tags brand --run-skipped test/animated_splash_test.dart
  // Writes 30 frames of the intro and its exit, light and dark, at 360 x 640
  // into $SPLASH_FRAMES_DIR/{light,dark} (default build/splash_frames).
  // ---------------------------------------------------------------------------
  for (final brightness in Brightness.values) {
    testWidgets('render intro frames to PNG (${brightness.name})', (tester) async {
      final outDir = '${Platform.environment['SPLASH_FRAMES_DIR'] ?? 'build/splash_frames'}/${brightness.name}';
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final boundary = GlobalKey();
      Future<void> shot(int i, double t) async {
        await tester.runAsync(() async {
          final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File('$outDir/f${i.toString().padLeft(2, '0')}_t${t.toStringAsFixed(3)}.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(Uint8List.view(data!.buffer));
        });
      }

      final dark = brightness == Brightness.dark;
      final app = MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: brightness, colorSchemeSeed: const Color(0xFF16A34A)),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => AnimatedSplash(child: child!),
        home: Scaffold(
          backgroundColor: dark ? const Color(0xFF0A0A0A) : Colors.white,
          appBar: AppBar(title: const Text('App')),
          body: const Center(child: Text('The app')),
        ),
      );
      await _start(tester, RepaintBoundary(key: boundary, child: app));
      // 30 frames from 0 to 2.45 s (the 2.0 s intro and the 0.45 s exit).
      var shown = 0.0;
      for (var i = 0; i < 30; i++) {
        final t = i * 2.45 / 29;
        await _advance(tester, t - shown);
        shown = (t * 60).round() / 60;
        await shot(i, t);
      }
      await tester.pumpWidget(const SizedBox());
    }, tags: ['brand']);
  }
}

Finder get _ignorePointer => find.descendant(
      of: find.byType(AnimatedSplash),
      matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.child is GestureDetector),
    );

// Fonts for the frames: Inter (the app's Google Font) from the store
// screenshot cache, or Roboto from the SDK, plus Material Icons.
String? _sdkArtifacts() {
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final i = exe.indexOf('/bin/cache/artifacts/');
  return i < 0 ? null : '${exe.substring(0, i)}/bin/cache/artifacts';
}

Future<void> _loadFamily(String family, List<String> files) async {
  final loader = FontLoader(family);
  var any = false;
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
    any = true;
  }
  if (any) await loader.load();
}

Future<void> _loadFonts() async {
  final sdk = _sdkArtifacts();
  String inter(int w) => 'build/store_cache/fonts/Inter-$w.ttf';
  String roboto(String n) => '$sdk/material_fonts/roboto-$n.ttf';
  final haveInter = File(inter(400)).existsSync();
  String pick(int w) {
    if (haveInter) {
      for (final c in [w, if (w > 400) w - 100, 700, 400]) {
        if (File(inter(c)).existsSync()) return inter(c);
      }
    }
    return roboto(switch (w) { <= 400 => 'regular', 500 || 600 => 'medium', 700 => 'bold', _ => 'black' });
  }

  const weights = {100: 400, 200: 400, 300: 400, 400: 400, 500: 500, 600: 600, 700: 700, 800: 800, 900: 800};
  for (final e in weights.entries) {
    final name = e.key == 400 ? 'regular' : '${e.key}';
    await _loadFamily('Inter_$name', [pick(e.value)]);
  }
  final all = [for (final w in [400, 500, 600, 700, 800]) pick(w)];
  await _loadFamily('Inter', all);
  await _loadFamily('Roboto', all);
  if (sdk != null) await _loadFamily('MaterialIcons', ['$sdk/material_fonts/materialicons-regular.otf']);
}
