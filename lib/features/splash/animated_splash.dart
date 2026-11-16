import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/brand/crown_blade_logo.dart';
import '../../l10n/l10n.dart';

/// Timing and layout of the start-up intro.
///
/// The whole choreography is a set of [Animatable]s over the intro
/// controller's value (0..1 = 0..[intro]), so the widgets animate with
/// transitions (no rebuild per frame) and [IntroFrame.at] can evaluate the
/// very same curves in tests.
abstract final class IntroTimeline {
  /// The full intro, from the first frame to the finished logo with the
  /// wordmark and tagline (the exit can start after this).
  static const Duration intro = Duration(milliseconds: 2000);

  /// The exit: the logo rises and grows while the app fades in underneath.
  static const Duration exit = Duration(milliseconds: 450);

  /// Reduce motion: how long the static logo stays before it fades.
  static const Duration reducedMotionHold = Duration(milliseconds: 600);

  /// The intro never keeps a ready app waiting longer than this.
  static const Duration readyCap = Duration(milliseconds: 3500);

  /// If the app is still not ready after this long, the intro steps aside
  /// anyway; RootGate then shows [StartupHoldScreen], which looks the same.
  static const Duration maxHold = Duration(seconds: 10);

  /// The logo is painted in a [logoCanvas] dp square with [logoPadding] clear
  /// on every side, centred on the screen: the same place and size as the
  /// native splash image (assets/brand/splash-logo-1152.png = 288 dp at 4x,
  /// padding 0.29), so the hand-off from the native splash is seamless.
  static const double logoCanvas = 288;
  static const double logoPadding = 0.29;

  /// How far (dp) the logo rises to make room for the wordmark.
  static const double lift = 40;

  /// Gap between the mark and the wordmark, and the wordmark's slide (dp).
  static const double wordmarkGap = 26;
  static const double wordmarkSlide = 14;

  /// The tagline's slide (dp).
  static const double taglineSlide = 8;

  /// Peak of the gentle "breath" of the logo.
  static const double breathPeak = 1.04;

  static double get _total => intro.inMicroseconds / 1e6;

  /// An interval of the intro given in seconds.
  static Interval _at(double begin, double end,
          [Curve curve = Curves.linear]) =>
      Interval(begin / _total, end / _total, curve: curve);

  /// 0.00-0.80 s: the logo breathes in and out (1.0 -> 1.04 -> 1.0).
  static final Animatable<double> breath = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: breathPeak)
          .chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 0.4,
    ),
    TweenSequenceItem(
      tween: Tween(begin: breathPeak, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 0.4,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: _total - 0.8),
  ]);

  /// 0.15-0.85 s: the three jewels twinkle in turn.
  static final Animatable<double> twinkle = CurveTween(curve: _at(0.15, 0.85));

  /// 0.40-1.05 s: a glint runs along the blade (sparkle at its point).
  static final Animatable<double> glint =
      CurveTween(curve: _at(0.40, 1.05, Curves.easeInOutSine));

  /// 0.75-1.25 s: a light sweeps across the gem facets.
  static final Animatable<double> gemShine =
      CurveTween(curve: _at(0.75, 1.25, Curves.easeInOut));

  /// 0.80-1.30 s: the logo rises to make room for the words.
  static final Animatable<double> rise =
      CurveTween(curve: _at(0.80, 1.30, Curves.easeInOutCubic));

  /// 0.90-1.45 s: the wordmark slides up, fades in and is wiped on from
  /// the left.
  static final Animatable<double> wordmark =
      CurveTween(curve: _at(0.90, 1.45, Curves.easeOutCubic));

  /// 1.20-1.65 s: the tagline fades in and slides up a little.
  static final Animatable<double> tagline =
      CurveTween(curve: _at(1.20, 1.65, Curves.easeOutCubic));

  // --- The exit (over the exit controller, 0..1) ---------------------------

  /// The app fades in underneath while the whole intro fades out.
  static final Animatable<double> exitOpacity = Tween(begin: 1.0, end: 0.0)
      .chain(CurveTween(
          curve: const Interval(0.12, 1, curve: Curves.easeInOutCubic)));

  /// The words fade out first.
  static final Animatable<double> exitTextOpacity = Tween(begin: 1.0, end: 0.0)
      .chain(CurveTween(curve: const Interval(0, 0.55, curve: Curves.easeOut)));

  /// The logo grows ...
  static final Animatable<double> exitScale = Tween(begin: 1.0, end: 1.22)
      .chain(CurveTween(curve: Curves.easeInOutCubic));

  /// ... and moves up (dp).
  static final Animatable<double> exitRise = Tween(begin: 0.0, end: -36.0)
      .chain(CurveTween(curve: Curves.easeInOutCubic));
}

/// The state of every animated value of the intro at one moment.
///
/// [IntroFrame.at] is a pure function of time, so the whole choreography can
/// be tested and rendered frame by frame. At t = 0 it is exactly the native
/// splash: the full, static logo, centred, with nothing else.
@immutable
class IntroFrame {
  const IntroFrame({
    required this.logoScale,
    required this.twinkle,
    required this.glint,
    required this.gemShine,
    required this.lift,
    required this.wordmark,
    required this.tagline,
  });

  /// The finished logo with the wordmark and tagline (also the reduced
  /// motion and the "still loading" state).
  static const IntroFrame finished = IntroFrame(
    logoScale: 1,
    twinkle: 1,
    glint: 1,
    gemShine: 1,
    lift: 1,
    wordmark: 1,
    tagline: 1,
  );

  /// Scale of the mark (1 = the native splash size).
  final double logoScale;

  /// Progress of the jewel twinkles, the blade glint and the gem shine
  /// ([CrownBladeLogoPainter]; their effects only show strictly between 0
  /// and 1).
  final double twinkle;
  final double glint;
  final double gemShine;

  /// 0..1: how far the logo has risen to make room for the words.
  final double lift;

  /// 0..1: the wordmark sliding up, fading in and being wiped on.
  final double wordmark;

  /// 0..1: the tagline fading in.
  final double tagline;

  /// The intro at controller value [v] (0..1).
  factory IntroFrame.ofValue(double v) {
    final t = v.clamp(0.0, 1.0);
    return IntroFrame(
      logoScale: IntroTimeline.breath.transform(t),
      twinkle: IntroTimeline.twinkle.transform(t),
      glint: IntroTimeline.glint.transform(t),
      gemShine: IntroTimeline.gemShine.transform(t),
      lift: IntroTimeline.rise.transform(t),
      wordmark: IntroTimeline.wordmark.transform(t),
      tagline: IntroTimeline.tagline.transform(t),
    );
  }

  /// The intro at [seconds] after it started.
  factory IntroFrame.at(double seconds) =>
      IntroFrame.ofValue(seconds / IntroTimeline._total);

  /// The logo painter for this frame.
  CrownBladeLogoPainter painter(CrownBladeVariant variant) =>
      CrownBladeLogoPainter(
        variant: variant,
        padding: IntroTimeline.logoPadding,
        twinkleProgress: twinkle,
        glintProgress: glint,
        gemShineProgress: gemShine,
      );
}

/// Colours of the intro for one brightness (they match the native splash).
@immutable
class IntroColors {
  const IntroColors._({
    required this.background,
    required this.variant,
    required this.word,
    required this.accent,
    required this.tagline,
    required this.track,
    required this.overlay,
  });

  final Color background;
  final CrownBladeVariant variant;
  final Color word;
  final Color accent;
  final Color tagline;
  final Color track;
  final SystemUiOverlayStyle overlay;

  static const light = IntroColors._(
    background: CrownBladeLogo.splashLight,
    variant: CrownBladeVariant.onLight,
    word: Color(0xFF0F172A),
    accent: Color(0xFF16A34A),
    tagline: Color(0xFF64748B),
    track: Color(0x1F0F172A),
    overlay: SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS: light background
      systemNavigationBarColor: CrownBladeLogo.splashLight,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0x00000000),
    ),
  );

  static const dark = IntroColors._(
    background: CrownBladeLogo.splashDark,
    variant: CrownBladeVariant.onDark,
    word: Color(0xFFF5F5F5),
    accent: Color(0xFF22C55E),
    tagline: Color(0xFFA3A3A3),
    track: Color(0x1FFFFFFF),
    overlay: SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS: dark background
      systemNavigationBarColor: CrownBladeLogo.splashDark,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0x00000000),
    ),
  );

  static IntroColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Status bar and navigation bar while the intro is on screen.
SystemUiOverlayStyle introOverlayStyleFor(Brightness brightness) =>
    IntroColors.of(brightness).overlay;

/// The style the app uses outside the intro (its app bars' style).
SystemUiOverlayStyle _appOverlayStyle(BuildContext context) {
  final style = Theme.of(context).appBarTheme.systemOverlayStyle;
  if (style != null) return style;
  return Theme.of(context).brightness == Brightness.dark
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);
}

/// Paints the intro logo straight from the intro controller: it repaints on
/// every tick without rebuilding any widget.
class IntroLogoPainter extends CustomPainter {
  IntroLogoPainter({required this.intro, required this.variant})
      : super(repaint: intro);

  final Animation<double> intro;
  final CrownBladeVariant variant;

  /// The intro at this moment.
  IntroFrame get frame => IntroFrame.ofValue(intro.value);

  @override
  void paint(Canvas canvas, Size size) =>
      frame.painter(variant).paint(canvas, size);

  @override
  bool shouldRepaint(IntroLogoPainter old) =>
      old.intro != intro || old.variant != variant;
}

/// Moves its child vertically by [animation].value dp.
class _TranslateY extends AnimatedWidget {
  const _TranslateY({required Animation<double> animation, required this.child})
      : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset(0, (listenable as Animation<double>).value),
        child: child,
      );
}

/// Wipes its child on from the left with a soft edge.
class _Wipe extends AnimatedWidget {
  const _Wipe({required Animation<double> animation, required this.child})
      : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = (listenable as Animation<double>).value;
    // Fully shown (or hidden by the fade): no extra layer.
    if (v <= 0 || v >= 1) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        // A 35 % wide soft edge travelling from left to right.
        final edge = -0.35 + 1.35 * v;
        return LinearGradient(
          colors: const [Colors.white, Color(0x00FFFFFF)],
          stops: [edge.clamp(0.0, 1.0), (edge + 0.35).clamp(0.0, 1.0)],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// The intro's picture: the mark on white (light) or near-black (dark),
/// with the wordmark and tagline under it. Everything moves with
/// transitions driven by [intro] (0..1, see [IntroTimeline]) and [exit];
/// the layout itself never changes while it plays. Text is excluded from
/// semantics (the caller labels the whole scene).
class IntroScene extends StatelessWidget {
  const IntroScene({
    super.key,
    this.intro = kAlwaysCompleteAnimation,
    this.exit = kAlwaysDismissedAnimation,
    this.brightness = Brightness.light,
    this.zoomOut = true,
    this.showProgress = false,
  });

  /// The intro controller (complete: the finished logo).
  final Animation<double> intro;

  /// The exit controller (0 = shown, 1 = gone).
  final Animation<double> exit;

  final Brightness brightness;

  /// Whether the logo rises and grows on the way out (else only a fade).
  final bool zoomOut;

  /// Shows a thin progress bar under the tagline (still loading).
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = IntroColors.of(brightness);
    const canvas = IntroTimeline.logoCanvas;
    final markHalfHeight = CrownBladeGeometry.fit(
          const Size.square(canvas),
          padding: IntroTimeline.logoPadding,
        ).height /
        2;

    final wordStyle =
        (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      color: colors.word,
      fontSize: 21,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: 5,
      decoration: TextDecoration.none,
    );
    final taglineStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: colors.tagline,
      fontSize: 13.5,
      height: 1.3,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      decoration: TextDecoration.none,
    );

    // "CROWN & BLADE" with the ampersand in green.
    final brand = l.brandUpper;
    final amp = brand.indexOf('&');
    final wordmark = Text.rich(
      amp < 0
          ? TextSpan(text: brand)
          : TextSpan(children: [
              TextSpan(text: brand.substring(0, amp)),
              TextSpan(text: '&', style: TextStyle(color: colors.accent)),
              TextSpan(text: brand.substring(amp + 1)),
            ]),
      key: const ValueKey('intro-wordmark'),
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: wordStyle,
    );

    final liftDp = intro.drive(Tween<double>(begin: 0, end: -IntroTimeline.lift)
        .chain(IntroTimeline.rise));
    final exitScale = zoomOut
        ? exit.drive(IntroTimeline.exitScale)
        : kAlwaysCompleteAnimation; // value 1.0: no zoom
    final exitRise = zoomOut
        ? exit.drive(IntroTimeline.exitRise)
        : kAlwaysDismissedAnimation; // value 0.0: no move

    // Material: theme text defaults (MaterialApp.builder has none).
    return FadeTransition(
      opacity: exit.drive(IntroTimeline.exitOpacity),
      child: Material(
        color: colors.background,
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          final cx = size.width / 2;
          final cy = size.height / 2;
          final wordTop = cy -
              IntroTimeline.lift +
              markHalfHeight +
              IntroTimeline.wordmarkGap;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: cx - canvas / 2,
                top: cy - canvas / 2,
                width: canvas,
                height: canvas,
                child: _TranslateY(
                  animation: exitRise,
                  child: ScaleTransition(
                    scale: exitScale,
                    child: _TranslateY(
                      animation: liftDp,
                      child: ScaleTransition(
                        scale: intro.drive(IntroTimeline.breath),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: const Size.square(canvas),
                            painter: IntroLogoPainter(
                                intro: intro, variant: colors.variant),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: wordTop,
                child: FadeTransition(
                  opacity: exit.drive(IntroTimeline.exitTextOpacity),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: intro.drive(IntroTimeline.wordmark),
                        child: _TranslateY(
                          animation: intro.drive(Tween<double>(
                                  begin: IntroTimeline.wordmarkSlide, end: 0)
                              .chain(IntroTimeline.wordmark)),
                          child: _Wipe(
                            animation: intro.drive(IntroTimeline.wordmark),
                            child: wordmark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: intro.drive(IntroTimeline.tagline),
                        child: _TranslateY(
                          animation: intro.drive(Tween<double>(
                                  begin: IntroTimeline.taglineSlide, end: 0)
                              .chain(IntroTimeline.tagline)),
                          child: Text(
                            l.introTagline,
                            key: const ValueKey('intro-tagline'),
                            textAlign: TextAlign.center,
                            style: taglineStyle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedOpacity(
                        opacity: showProgress ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: SizedBox(
                          width: 96,
                          child: showProgress
                              ? LinearProgressIndicator(
                                  key: const ValueKey('intro-progress'),
                                  minHeight: 2,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(1)),
                                  color: colors.accent,
                                  backgroundColor: colors.track,
                                )
                              : const SizedBox(height: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Full-screen "still loading" state: the finished intro picture with a
/// thin progress bar, on white or near-black like the theme. RootGate shows
/// it while the signed-in session is restored, so a slow start never
/// flashes a blank page.
class StartupHoldScreen extends StatefulWidget {
  const StartupHoldScreen({super.key});

  @override
  State<StartupHoldScreen> createState() => _StartupHoldScreenState();
}

class _StartupHoldScreenState extends State<StartupHoldScreen> {
  late SystemUiOverlayStyle _restore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restore = _appOverlayStyle(context);
  }

  @override
  void dispose() {
    // Screens without an app bar would otherwise keep the intro's style.
    SystemChrome.setSystemUIOverlayStyle(_restore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: introOverlayStyleFor(brightness),
      child: Semantics(
        container: true,
        label: context.l10n.brandName,
        child: ExcludeSemantics(
          child: IntroScene(brightness: brightness, showProgress: true),
        ),
      ),
    );
  }
}

enum _Phase { playing, exiting, done }

/// Plays the animated start-up intro over [child] (the app, which builds
/// underneath), then lifts the logo away while the app fades in.
///
/// The first frame is exactly the native splash (same logo, size, place and
/// background for the device's light / dark setting); the logo then
/// breathes, its jewels twinkle, a glint runs along the blade and the
/// wordmark is revealed.
///
/// The intro leaves when both the animation has finished and [isReady]
/// returns true (checked whenever [readiness] notifies). While the app is
/// not ready, it holds on the finished logo with a thin progress bar. It
/// never keeps a ready app waiting longer than [IntroTimeline.readyCap].
/// A tap skips to the exit (as soon as the app is ready). With reduce motion
/// on, it shows the static logo and simply fades.
///
/// It plays once per instance: put it high in the tree (MaterialApp.builder)
/// so it only runs on a cold start. [enabled] false shows [child] alone
/// (tests).
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({
    super.key,
    required this.child,
    this.enabled = true,
    this.isReady,
    this.readiness,
    this.onFinished,
    this.brightness,
  });

  final Widget child;
  final bool enabled;

  /// Whether the app underneath is ready to be shown (null: always ready).
  final bool Function()? isReady;

  /// Notifies when [isReady] may have changed.
  final Listenable? readiness;

  /// Called once the intro has gone.
  final VoidCallback? onFinished;

  /// Light or dark intro. Null (the default): the device setting, which is
  /// what the native splash used, so the hand-off is seamless.
  final Brightness? brightness;

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with TickerProviderStateMixin {
  // Created in initState (also when disabled), never lazily: a lazy
  // controller would first be created in dispose(), where looking up
  // TickerMode is no longer allowed.
  late final AnimationController _intro;
  late final AnimationController _exit;

  _Phase _phase = _Phase.playing;
  bool _started = false;
  bool _reduceMotion = false;
  bool _minDone = false;
  bool _wasReady = false;
  bool _skipRequested = false;

  /// Rise and zoom while leaving (off when leaving before the app is
  /// ready, or with reduce motion: then it only fades).
  bool _zoomOut = true;

  /// Fixed for the whole intro (the native splash's brightness).
  Brightness? _brightness;

  Timer? _minTimer;
  Timer? _readyCapTimer;
  Timer? _maxHoldTimer;
  Listenable? _listening;

  bool get _ready => widget.isReady?.call() ?? true;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: IntroTimeline.intro,
      animationBehavior: AnimationBehavior.preserve,
    );
    _exit = AnimationController(
      vsync: this,
      duration: IntroTimeline.exit,
      animationBehavior: AnimationBehavior.preserve,
    );
    if (!widget.enabled) {
      _phase = _Phase.done;
      return;
    }
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onMinDone();
    });
    _exit.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    _listen(widget.readiness);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _brightness ??=
        widget.brightness ?? MediaQuery.maybePlatformBrightnessOf(context);
    if (_started || _phase == _Phase.done) return;
    _started = true;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Start after the first frame, which matches the native splash: the
    // app's first build underneath doesn't eat the opening of the motion.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _phase != _Phase.playing) return;
      _maxHoldTimer = Timer(IntroTimeline.maxHold, () => _beginExit());
      _checkReady();
      if (_reduceMotion) {
        _minTimer = Timer(IntroTimeline.reducedMotionHold, _onMinDone);
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readiness != widget.readiness && _phase != _Phase.done) {
      _listen(widget.readiness);
      _checkReady();
    }
  }

  void _listen(Listenable? listenable) {
    _listening?.removeListener(_checkReady);
    _listening = listenable;
    _listening?.addListener(_checkReady);
  }

  void _checkReady() {
    if (!mounted || _phase != _Phase.playing || !_started) return;
    final ready = _ready;
    if (ready && !_wasReady) {
      _wasReady = true;
      _readyCapTimer?.cancel();
      _readyCapTimer = Timer(IntroTimeline.readyCap, () => _beginExit());
      if (_skipRequested) {
        _beginExit();
        return;
      }
    } else if (!ready && _wasReady) {
      // Went back to loading before the intro finished: wait again.
      _wasReady = false;
      _readyCapTimer?.cancel();
    }
    if (_minDone && ready) _beginExit();
  }

  void _onMinDone() {
    if (!mounted || _minDone) return;
    _minDone = true;
    if (_phase != _Phase.playing) return;
    if (_ready) {
      _beginExit();
    } else {
      setState(() {}); // show the progress bar
    }
  }

  void _onTap() {
    if (_phase != _Phase.playing) return;
    if (_ready) {
      _beginExit();
    } else {
      _skipRequested = true;
    }
  }

  void _beginExit() {
    if (!mounted || _phase != _Phase.playing) return;
    _minTimer?.cancel();
    _readyCapTimer?.cancel();
    _maxHoldTimer?.cancel();
    _intro.stop();
    setState(() {
      _phase = _Phase.exiting;
      _zoomOut = !_reduceMotion && _ready;
    });
    _exit.forward();
  }

  void _finish() {
    if (!mounted || _phase == _Phase.done) return;
    _listen(null);
    setState(() => _phase = _Phase.done);
    SystemChrome.setSystemUIOverlayStyle(_appOverlayStyle(context));
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _readyCapTimer?.cancel();
    _maxHoldTimer?.cancel();
    _listen(null);
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showIntro = _phase != _Phase.done;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The app builds underneath from the start; it is hidden from
        // screen readers while the intro covers it.
        ExcludeSemantics(excluding: showIntro, child: widget.child),
        if (showIntro) _buildOverlay(context),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final brightness = _brightness ?? Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: introOverlayStyleFor(brightness),
      // While it fades out, taps already reach the app.
      child: IgnorePointer(
        ignoring: _phase == _Phase.exiting,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Semantics(
            container: true,
            label: context.l10n.brandName,
            child: ExcludeSemantics(
              child: IntroScene(
                // Reduce motion: the finished, static picture.
                intro: _reduceMotion ? kAlwaysCompleteAnimation : _intro,
                exit: _exit,
                brightness: brightness,
                zoomOut: _zoomOut,
                showProgress: _minDone && _phase == _Phase.playing,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
