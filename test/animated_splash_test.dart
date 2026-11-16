import 'dart:io';
import 'dart:ui' as ui;

import 'package:barbershop_booking/core/brand/crown_blade_logo.dart';
import 'package:barbershop_booking/core/theme/app_theme.dart';
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
Widget _harness(_Ready ready, {VoidCallback? onFinished, VoidCallback? onAppTap}) => MaterialApp(
      theme: ThemeData(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => AnimatedSplash(
        isReady: () => ready.value,
        readiness: ready,
        onFinished: onFinished,
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

/// The painter of the drawn (animated) mark.
CrownBladeLogoPainter _drawn(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((c) => c.painter).whereType<CrownBladeLogoPainter>().last;

Finder get _overlay => find.byType(IntroScene);

void main() {
  group('IntroFrame timeline', () {
    test('starts on the native splash mark', () {
      final f = IntroFrame.at(0);
      expect(f.afterimage, 1);
      expect(f.logoScale, 1);
      expect(f.crown, 0);
      expect(f.blade, 0);
      expect(f.gem, 0);
      expect(f.glint, 0);
      expect(f.wordmark, 0);
      expect(f.tagline, 0);
    });

    test('values at key times', () {
      final a = IntroFrame.at(0.2);
      expect(a.logoScale, closeTo(0.9, 1e-9));
      expect(a.crown, inExclusiveRange(0, 0.5));
      expect(a.afterimage, lessThan(0.2));

      final b = IntroFrame.at(0.6);
      expect(b.crown, inExclusiveRange(0.8, 1));
      expect(b.blade, closeTo(0.2, 1e-9));
      expect(b.gem, 0);

      final c = IntroFrame.at(0.7);
      expect(c.crown, 1);
      expect(c.afterimage, 0);

      final d = IntroFrame.at(1.0);
      expect(d.blade, 1);
      expect(d.gem, inExclusiveRange(0, 1));
      expect(d.glint, inExclusiveRange(0, 1));
      expect(d.wordmark, inExclusiveRange(0, 1));
      expect(d.tagline, 0);

      final e = IntroFrame.at(1.4);
      expect(e.gem, 1);
      expect(e.glint, 1);
      expect(e.lift, 1);
      expect(e.wordmark, 1);
      expect(e.tagline, inExclusiveRange(0, 1));

      expect(IntroFrame.at(1.6).tagline, 1);
    });

    test('the logo settles with a soft overshoot and ends on the finished frame', () {
      var peak = 0.0;
      for (var t = 0.2; t <= 2.0; t += 0.01) {
        final s = IntroFrame.at(t).logoScale;
        if (s > peak) peak = s;
      }
      expect(peak, inInclusiveRange(1.0, 1.02));
      final end = IntroFrame.at(IntroTimeline.intro.inMilliseconds / 1000);
      const fin = IntroFrame.finished;
      expect(end.logoScale, closeTo(fin.logoScale, 1e-9));
      for (final pair in [
        [end.afterimage, fin.afterimage],
        [end.crown, fin.crown],
        [end.blade, fin.blade],
        [end.gem, fin.gem],
        [end.glint, fin.glint],
        [end.lift, fin.lift],
        [end.wordmark, fin.wordmark],
        [end.tagline, fin.tagline],
      ]) {
        expect(pair[0], pair[1]);
      }
    });
  });

  group('AnimatedSplash', () {
    testWidgets('plays the timeline over the app, which builds underneath', (tester) async {
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      expect(_overlay, findsOneWidget);
      expect(find.byKey(_appKey), findsOneWidget); // built under the intro
      expect(_drawn(tester).crownProgress, 0);

      await _advance(tester, 0.6);
      final p = _drawn(tester);
      expect(p.crownProgress, closeTo(IntroFrame.at(0.6).crown, 0.02));
      expect(p.bladeProgress, closeTo(0.2, 0.02));
      expect(p.gemProgress, 0);

      await _advance(tester, 0.4); // 1.0 s
      expect(_drawn(tester).bladeProgress, closeTo(1, 1e-3));
      expect(_drawn(tester).gemProgress, greaterThan(0));
      expect(find.text('CROWN & BLADE'), findsOneWidget);

      await _advance(tester, 0.6); // 1.6 s
      expect(find.text('Book your barber in Addis Ababa'), findsOneWidget);
      expect(_overlay, findsOneWidget);
    });

    testWidgets('leaves after the animation when the app is ready, and the app takes taps', (tester) async {
      final ready = _Ready(true);
      var finished = 0;
      var appTaps = 0;
      await _start(tester, _harness(ready, onFinished: () => finished++, onAppTap: () => appTaps++));

      // While the intro plays, taps don't reach the app.
      await _advance(tester, 0.3);
      expect(_overlay, findsOneWidget);
      await _advance(tester, 1.6); // 1.9 s: not finished yet
      expect(_overlay, findsOneWidget);

      await _advance(tester, 0.1 + 0.4); // 2.0 s + the exit
      expect(_overlay, findsNothing);
      expect(finished, 1);
      await tester.tap(find.byKey(_appKey));
      expect(appTaps, 1);
      // Light status bar icons during the intro; the app's style after.
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('holds on the finished logo until the app is ready', (tester) async {
      final ready = _Ready(false);
      var finished = 0;
      await _start(tester, _harness(ready, onFinished: () => finished++));
      await _advance(tester, 3);
      expect(_overlay, findsOneWidget);
      expect(find.byKey(const ValueKey('intro-progress')), findsOneWidget);
      expect(_drawn(tester).crownProgress, 1);
      expect(_drawn(tester).gemProgress, 1);

      ready.set(true);
      await _advance(tester, 0.4);
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
      await _advance(tester, 0.7);
      expect(_overlay, findsNothing);
    });

    testWidgets('tap skips to the exit once the app is ready', (tester) async {
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      await _advance(tester, 0.3);
      await tester.tapAt(const Offset(200, 200));
      await _advance(tester, 0.4);
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
      await _advance(tester, 0.4);
      expect(_overlay, findsNothing);
    });

    testWidgets('reduce motion: the static logo, then a plain fade', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final ready = _Ready(true);
      await _start(tester, _harness(ready));
      final p = _drawn(tester);
      expect([p.crownProgress, p.bladeProgress, p.gemProgress, p.glintProgress], [1, 1, 1, 1]);
      expect(find.text('CROWN & BLADE'), findsOneWidget);

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
      await _advance(tester, 0.4);
      expect(_overlay, findsNothing);
    });

    testWidgets('is labelled for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _start(tester, _harness(_Ready(true)));
      expect(find.bySemanticsLabel('Crown & Blade'), findsOneWidget);
      expect(find.bySemanticsLabel('APP'), findsNothing); // the app is hidden
      await _advance(tester, 2.5);
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

    testWidgets('StartupHoldScreen shows the finished logo with a progress bar', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(), home: const StartupHoldScreen()));
      expect(find.byKey(const ValueKey('intro-progress')), findsOneWidget);
      expect(find.text('CROWN & BLADE'), findsOneWidget);
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
    await _advance(tester, 2.5);
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
  // ---------------------------------------------------------------------------
  testWidgets('render intro frames to PNG', (tester) async {
    final outDir = Platform.environment['SPLASH_FRAMES_DIR'] ?? 'build/splash_frames';
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(_loadFonts);
    loadTestSeed();
    final previous = LocaleController.instance;
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'));
    addTearDown(() => LocaleController.instance = previous);

    tester.view.physicalSize = const Size(412 * 2.5, 892 * 2.5);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final boundary = GlobalKey();
    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('$outDir/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(Uint8List.view(data!.buffer));
      });
    }

    await _start(tester, RepaintBoundary(key: boundary, child: const BarbershopApp()));
    await shot('t0.00');
    var t = 0.0;
    for (final at in [0.1, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.7, 1.98]) {
      await _advance(tester, at - t);
      t = at;
      await shot('t${at.toStringAsFixed(2)}');
    }
    for (final at in [2.15, 2.3, 2.5]) {
      await _advance(tester, at - t);
      t = at;
      await shot('t${at.toStringAsFixed(2)}-exit');
    }

    // The "still loading" hold (RootGate while the session is restored).
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(theme: AppTheme.lightTheme, home: const StartupHoldScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await shot('hold');
    await tester.pumpWidget(const SizedBox());
  }, tags: ['brand']);
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
