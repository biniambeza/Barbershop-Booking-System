import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/brand/crown_blade_logo.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// Timing and layout of the start-up intro.
abstract final class IntroTimeline {
  /// The full intro, from the first frame to the finished logo with the
  /// wordmark and tagline (the exit can start after this).
  static const Duration intro = Duration(milliseconds: 2000);

  /// Fade / zoom out that reveals the app.
  static const Duration exit = Duration(milliseconds: 350);

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
}

/// The state of every animated value of the intro at one moment.
///
/// [IntroFrame.at] is a pure function of time, so the whole choreography can
/// be tested and rendered frame by frame.
@immutable
class IntroFrame {
  const IntroFrame({
    required this.afterimage,
    required this.logoScale,
    required this.crown,
    required this.blade,
    required this.gem,
    required this.glint,
    required this.lift,
    required this.wordmark,
    required this.tagline,
  });

  /// The finished logo with the wordmark and tagline (also the reduced
  /// motion and the "still loading" state).
  static const IntroFrame finished = IntroFrame(
    afterimage: 0,
    logoScale: 1,
    crown: 1,
    blade: 1,
    gem: 1,
    glint: 1,
    lift: 1,
    wordmark: 1,
    tagline: 1,
  );

  /// Opacity of the static mark the native splash showed; it fades away as
  /// the crown is drawn again over it.
  final double afterimage;

  /// Scale of the mark (1 = the native splash size).
  final double logoScale;

  /// Progress values of [CrownBladeLogoPainter].
  final double crown;
  final double blade;
  final double gem;
  final double glint;

  /// 0..1: how far the logo has risen to make room for the words.
  final double lift;

  /// 0..1: the wordmark sliding up and fading in.
  final double wordmark;

  /// 0..1: the tagline fading in.
  final double tagline;

  static double _span(double t, double begin, double end,
      [Curve curve = Curves.linear]) {
    final x = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(x);
  }

  /// The intro at [seconds] after it started.
  ///
  /// * 0.00-0.25 s: the native splash mark fades and the logo eases back to
  ///   90 % while the crown stroke starts drawing over it.
  /// * 0.05-0.70 s: the crown stroke draws on; the logo settles back to
  ///   100 % with a soft overshoot (by 0.8 s).
  /// * 0.50-1.00 s: the blade sweeps in; 0.82-1.12 s the green gem pops.
  /// * 0.90-1.40 s: a glint runs along the blade, the logo rises and the
  ///   wordmark slides up; 1.20-1.60 s the tagline fades in.
  /// * 1.60-2.00 s: a beat on the finished logo.
  factory IntroFrame.at(double seconds) {
    final t = seconds;
    final double scale;
    if (t < 0.2) {
      scale = 1 - 0.1 * _span(t, 0, 0.2, Curves.easeInOut);
    } else {
      // easeOutBack lands softly with a ~1 % overshoot.
      scale = 0.9 + 0.1 * _span(t, 0.2, 0.8, Curves.easeOutBack);
    }
    return IntroFrame(
      afterimage: 1 - _span(t, 0, 0.25, Curves.easeOut),
      logoScale: scale,
      crown: _span(t, 0.05, 0.7, Curves.easeInOutCubic),
      // The painter eases the blade (easeOutCubic) and the gem (easeOutBack).
      blade: _span(t, 0.5, 1.0),
      gem: _span(t, 0.82, 1.12),
      glint: _span(t, 0.9, 1.4, Curves.easeInOut),
      lift: _span(t, 0.9, 1.35, Curves.easeInOutCubic),
      wordmark: _span(t, 0.95, 1.4, Curves.easeOutCubic),
      tagline: _span(t, 1.2, 1.6, Curves.easeOut),
    );
  }
}

/// Status bar and navigation bar while the charcoal intro is on screen:
/// light icons on Android and iOS.
const SystemUiOverlayStyle introOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light, // Android
  statusBarBrightness: Brightness.dark, // iOS: dark background, light text
  systemNavigationBarColor: AppTheme.ink,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarDividerColor: Color(0x00000000),
);

/// The style the app uses outside the intro (its app bars' style).
SystemUiOverlayStyle _appOverlayStyle(BuildContext context) =>
    Theme.of(context).appBarTheme.systemOverlayStyle ??
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

/// The intro's picture at [frame]: the mark on the brand charcoal, with the
/// wordmark and tagline under it. Text is excluded from semantics (the
/// caller labels the whole scene).
class IntroScene extends StatelessWidget {
  const IntroScene({
    super.key,
    required this.frame,
    this.showProgress = false,
  });

  final IntroFrame frame;

  /// Shows a thin progress bar under the tagline (still loading).
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    const canvas = IntroTimeline.logoCanvas;
    final markHalfHeight = CrownBladeGeometry.fit(
          const Size.square(canvas),
          padding: IntroTimeline.logoPadding,
        ).height /
        2;

    // Material: theme text defaults (MaterialApp.builder has none).
    return Material(
      color: CrownBladeLogo.iconBackgroundColor,
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        final cx = size.width / 2;
        final markY = size.height / 2 - frame.lift * IntroTimeline.lift;
        final wordTop = markY +
            markHalfHeight +
            IntroTimeline.wordmarkGap +
            (1 - frame.wordmark) * IntroTimeline.wordmarkSlide;

        final wordStyle = (theme.textTheme.titleLarge ?? const TextStyle())
            .copyWith(
          color: Colors.white.withValues(alpha: frame.wordmark),
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 5,
          decoration: TextDecoration.none,
        );
        final taglineStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
            .copyWith(
          color: Colors.white.withValues(alpha: 0.62 * frame.tagline),
          fontSize: 13.5,
          height: 1.3,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          decoration: TextDecoration.none,
        );

        Widget logo(CrownBladeLogoPainter painter) => CustomPaint(
              size: const Size.square(canvas),
              painter: painter,
            );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: cx - canvas / 2,
              top: markY - canvas / 2,
              width: canvas,
              height: canvas,
              child: Transform.scale(
                scale: frame.logoScale,
                child: Stack(
                  children: [
                    if (frame.afterimage > 0)
                      Opacity(
                        opacity: frame.afterimage,
                        child: logo(const CrownBladeLogoPainter(
                            padding: IntroTimeline.logoPadding)),
                      ),
                    logo(CrownBladeLogoPainter(
                      padding: IntroTimeline.logoPadding,
                      crownProgress: frame.crown,
                      bladeProgress: frame.blade,
                      gemProgress: frame.gem,
                      glintProgress: frame.glint,
                    )),
                  ],
                ),
              ),
            ),
            if (frame.wordmark > 0)
              Positioned(
                left: 16,
                right: 16,
                top: wordTop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.brandUpper,
                      key: const ValueKey('intro-wordmark'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: wordStyle,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.introTagline,
                      key: const ValueKey('intro-tagline'),
                      textAlign: TextAlign.center,
                      style: taglineStyle,
                    ),
                    const SizedBox(height: 28),
                    AnimatedOpacity(
                      opacity: showProgress ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: SizedBox(
                        width: 96,
                        child: showProgress
                            ? const LinearProgressIndicator(
                                key: ValueKey('intro-progress'),
                                minHeight: 2,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(1)),
                                color: AppTheme.green,
                                backgroundColor: Color(0x1FFFFFFF),
                              )
                            : const SizedBox(height: 2),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Full-screen "still loading" state on the brand charcoal: the finished
/// intro picture with a thin progress bar. RootGate shows it while the
/// signed-in session is restored, so a slow start never flashes white.
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
    // Screens without an app bar would otherwise keep the light icons.
    SystemChrome.setSystemUIOverlayStyle(_restore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: introOverlayStyle,
      child: Semantics(
        container: true,
        label: context.l10n.brandName,
        child: const ExcludeSemantics(
          child: IntroScene(frame: IntroFrame.finished, showProgress: true),
        ),
      ),
    );
  }
}

enum _Phase { playing, exiting, done }

/// Plays the animated start-up intro over [child] (the app, which builds
/// underneath), then fades and zooms it away.
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
  });

  final Widget child;
  final bool enabled;

  /// Whether the app underneath is ready to be shown (null: always ready).
  final bool Function()? isReady;

  /// Notifies when [isReady] may have changed.
  final Listenable? readiness;

  /// Called once the intro has gone.
  final VoidCallback? onFinished;

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

  /// Zoom while leaving (off when leaving before the app is ready, or with
  /// reduce motion: then it only fades).
  bool _zoomOut = true;

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
    if (oldWidget.readiness != widget.readiness &&
        _phase != _Phase.done) {
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
    final label = context.l10n.brandName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: introOverlayStyle,
      // While it fades out, taps already reach the app.
      child: IgnorePointer(
        ignoring: _phase == _Phase.exiting,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _exit]),
                builder: (context, _) {
                  final e = Curves.easeInCubic.transform(_exit.value);
                  final frame = _reduceMotion
                      ? IntroFrame.finished
                      : IntroFrame.at(_intro.value *
                          IntroTimeline.intro.inMicroseconds /
                          Duration.microsecondsPerSecond);
                  final holding = _minDone && _phase == _Phase.playing;
                  final opacity = 1 - Curves.easeIn.transform(_exit.value);
                  Widget scene = IntroScene(frame: frame, showProgress: holding);
                  if (_zoomOut && e > 0) {
                    scene = Transform.scale(scale: 1 + 0.12 * e, child: scene);
                  }
                  return Opacity(
                    opacity: math.max(0.0, opacity),
                    child: scene,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
