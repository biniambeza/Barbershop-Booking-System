import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

/// Shared look of the sign-in screens: entrance animations, the press
/// scale of the big buttons, the log in / sign up switch, the "OR" divider,
/// the Google "G" and the soft notice banners.

/// Inter at [size] / [weight] (for button and switch labels, whose
/// `textStyle` replaces the theme's instead of merging with it).
TextStyle authFont(double size, FontWeight weight, {Color? color, double? letterSpacing, double? height}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing, height: height);

/// Whether the platform asks for reduced motion.
bool authReduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Plays [child] in once when it is first built: a short fade with a small
/// upward slide, after [delay]. Give it a new key to play it again (the
/// log in / sign up forms do, so switching between them animates).
class AuthFadeSlideIn extends StatefulWidget {
  const AuthFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 16,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// How far below its place [child] starts, in logical pixels.
  final double offset;

  @override
  State<AuthFadeSlideIn> createState() => _AuthFadeSlideInState();
}

class _AuthFadeSlideInState extends State<AuthFadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.delay + widget.duration);
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delayFraction,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  double get _delayFraction {
    final total = (widget.delay + widget.duration).inMicroseconds;
    return total == 0 ? 0 : widget.delay.inMicroseconds / total;
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (authReduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: child,
      builder: (context, child) {
        // Same widgets at every frame (only the values change), so the
        // child keeps its state when the animation ends.
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child),
        );
      },
    );
  }
}

/// Scales [child] down a little while it is pressed (the big buttons).
class AuthPressScale extends StatefulWidget {
  const AuthPressScale({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<AuthPressScale> createState() => _AuthPressScaleState();
}

class _AuthPressScaleState extends State<AuthPressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down && widget.enabled;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        duration: Duration(milliseconds: pressed ? 90 : 160),
        curve: pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Bold label above a field (the field itself shows a hint, not a label).
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.2),
      ),
    );
  }
}

/// Input look of the sign-in forms: taller, 16 px corners, a clearly
/// visible outline in both modes and a green focus ring.
InputDecorationThemeData authInputTheme(InputDecorationThemeData base) {
  final dark = AppTheme.isDark;
  OutlineInputBorder border(Color color, [double width = 1.3]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  final idle = dark ? AppTheme.outline : AppTheme.outline.withValues(alpha: 0.8);
  return base.copyWith(
    filled: true,
    fillColor: dark ? const Color(0xFF111111) : AppTheme.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(idle),
    enabledBorder: border(idle),
    focusedBorder: border(AppTheme.primary, 2),
    disabledBorder: border(AppTheme.hairline),
    errorBorder: border(AppTheme.danger),
    focusedErrorBorder: border(AppTheme.danger, 2),
  );
}

/// "──── OR ────".
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: AppTheme.hairline));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Two-option pill switch with a sliding green thumb (log in / sign up).
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.labels,
    required this.labelKeys,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final List<Key> labelKeys;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final duration = authReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 280);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? AppTheme.card : AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional(selected == 0 ? -1 : 1, 0).resolve(Directionality.of(context)),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, Color.lerp(AppTheme.primary, AppTheme.primaryDeep, 0.6)!],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: dark
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: i == selected ? null : () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: authFont(
                            14.5,
                            FontWeight.w700,
                            color: i == selected ? AppTheme.onPrimary : AppTheme.textSecondary,
                          ),
                          child: Text(
                            labels[i],
                            key: labelKeys[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft tinted notice with an icon (errors, confirmations).
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.child, required this.color, required this.icon});

  final Widget child;

  /// The strong colour (danger, success...): used for the icon and text;
  /// the background is its soft tint.
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.softOf(color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: AppTheme.isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The multicolour Google "G", drawn (no network image or bundled asset).
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: size, child: const CustomPaint(painter: _GoogleGPainter()));
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = s * 0.2;
    final r = s / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;
    double deg(double d) => d * math.pi / 180;

    // Clockwise from the right (0°): blue, green, yellow, red; the gap is at
    // the upper right.
    canvas.drawArc(rect, deg(-2), deg(47), false, paint..color = _blue);
    canvas.drawArc(rect, deg(44), deg(92), false, paint..color = _green);
    canvas.drawArc(rect, deg(135), deg(91), false, paint..color = _yellow);
    canvas.drawArc(rect, deg(225), deg(94), false, paint..color = _red);

    // The blue bar into the middle.
    final bar = Rect.fromLTRB(c.dx - s * 0.02, c.dy - stroke / 2, c.dx + s / 2, c.dy + stroke / 2);
    canvas.drawRect(bar, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;
}
