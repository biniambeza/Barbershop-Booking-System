import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Geometry of the Crown & Blade mark, in design units.
///
/// The mark is a three-point crown drawn as one open stroke, a slim straight
/// razor blade lying under it as the crown's band, and a small green gem
/// inside the crown. Everything is defined in a design space whose visual
/// bounds are [bounds] (stroke widths included); [fit] maps that space into
/// any canvas with a padding, keeping the mark centred.
abstract final class CrownBladeGeometry {
  /// Width of the crown stroke.
  static const double strokeWidth = 9;

  /// The crown outline as one open path, left foot to right foot. The feet
  /// end just inside the blade (which is painted over them), so the crown
  /// stands on the blade's spine and both read as one object.
  static Path crownPath() => Path()
    ..moveTo(15.6, bladeTop + 3)
    ..lineTo(5, 24)
    ..lineTo(31, 47)
    ..lineTo(50, 10)
    ..lineTo(69, 47)
    ..lineTo(95, 24)
    ..lineTo(84.4, bladeTop + 3);

  /// Top (spine) and bottom (edge) of the blade, and where the honed bevel
  /// (painted steel grey in colour mode) starts.
  static const double bladeTop = 76;
  static const double bladeBottom = 87;
  static const double bevelTop = 82;

  /// The razor blade: a squared heel on the left, a straight spine, and a
  /// point at the right where the edge curves up to meet the spine.
  static Path bladePath() => Path()
    ..moveTo(-6, bladeTop)
    ..lineTo(106, bladeTop)
    ..quadraticBezierTo(101, bladeBottom, 88, bladeBottom)
    ..lineTo(-3, bladeBottom)
    ..close();

  /// Centre and half-diagonal of the diamond gem.
  static const Offset gemCenter = Offset(50, 59);
  static const double gemRadius = 9;

  /// The gem: a diamond (square on its point).
  static Path gemPath() => Path()
    ..moveTo(gemCenter.dx, gemCenter.dy - gemRadius)
    ..lineTo(gemCenter.dx + gemRadius, gemCenter.dy)
    ..lineTo(gemCenter.dx, gemCenter.dy + gemRadius)
    ..lineTo(gemCenter.dx - gemRadius, gemCenter.dy)
    ..close();

  /// Where the glint's sparkle flashes: just above the blade's point.
  static const Offset sparkleCenter = Offset(101, bladeTop - 4);

  /// Largest half-size of the sparkle. It reaches a few units past the right
  /// of [bounds], and is only drawn while the glint runs (0 < glint < 1).
  static const double sparkleRadius = 12;

  /// A four-point star, centred on [c].
  static Path sparklePath(Offset c, double r) {
    final k = r * 0.18;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k * 0.4, c.dy - k * 0.4, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k * 0.4, c.dy + k * 0.4, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k * 0.4, c.dy + k * 0.4, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k * 0.4, c.dy - k * 0.4, c.dx, c.dy - r)
      ..close();
  }

  /// Visual bounds of the whole mark (crown stroke included).
  static final Rect bounds = crownPath()
      .getBounds()
      .inflate(strokeWidth / 2)
      .expandToInclude(bladePath().getBounds())
      .expandToInclude(gemPath().getBounds());

  /// Where the mark lands in a canvas of [size] when [padding] (a fraction
  /// of the shorter side, on every side) is kept clear. The mark is scaled
  /// uniformly so its larger dimension fills the remaining square, and
  /// centred.
  static Rect fit(Size size, {double padding = 0}) {
    final side = size.shortestSide;
    final avail = side * (1 - 2 * padding);
    final scale = avail / math.max(bounds.width, bounds.height);
    final w = bounds.width * scale;
    final h = bounds.height * scale;
    return Rect.fromCenter(
        center: size.center(Offset.zero), width: w, height: h);
  }

  /// Scale factor from design units to canvas pixels for [fit].
  static double scaleFor(Size size, {double padding = 0}) =>
      fit(size, padding: padding).width / bounds.width;
}

/// Paints the Crown & Blade mark (no text).
///
/// Every progress value runs 0..1 and 1.0 everywhere is the static logo:
/// * [crownProgress] draws the crown stroke on from the left foot to the
///   right foot (0 = nothing, 1 = full crown).
/// * [bladeProgress] slides the blade in from the left while it is revealed
///   and fades in (0 = hidden, 1 = in place).
/// * [gemProgress] pops the gem in with a slight overshoot (0 = hidden).
/// * [glintProgress] moves a light shine along the blade from left to right;
///   the shine is only visible strictly between 0 and 1.
class CrownBladeLogoPainter extends CustomPainter {
  const CrownBladeLogoPainter({
    this.crownProgress = 1,
    this.bladeProgress = 1,
    this.gemProgress = 1,
    this.glintProgress = 1,
    this.monochrome = false,
    this.padding = 0,
    this.markColor = CrownBladeLogo.markWhite,
    this.accentColor = AppTheme.green,
    this.background,
  });

  final double crownProgress;
  final double bladeProgress;
  final double gemProgress;
  final double glintProgress;

  /// Draw everything (gem and blade included) in [markColor] only.
  final bool monochrome;

  /// Clear space on every side, as a fraction of the shorter side.
  final double padding;

  final Color markColor;
  final Color accentColor;

  /// Optional full-bleed background behind the mark.
  final Gradient? background;

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      final rect = Offset.zero & size;
      canvas.drawRect(rect, Paint()..shader = background!.createShader(rect));
    }

    final target = CrownBladeGeometry.fit(size, padding: padding);
    final scale = target.width / CrownBladeGeometry.bounds.width;
    canvas.save();
    canvas.translate(target.left, target.top);
    canvas.scale(scale);
    canvas.translate(
        -CrownBladeGeometry.bounds.left, -CrownBladeGeometry.bounds.top);

    _paintCrown(canvas);
    _paintBlade(canvas);
    _paintGem(canvas);

    canvas.restore();
  }

  void _paintCrown(Canvas canvas) {
    final p = crownProgress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final paint = Paint()
      ..color = markColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = CrownBladeGeometry.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final path = CrownBladeGeometry.crownPath();
    if (p >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * p), paint);
    }
  }

  void _paintBlade(Canvas canvas) {
    final p = bladeProgress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final eased = Curves.easeOutCubic.transform(p);
    final blade = CrownBladeGeometry.bladePath();
    final b = blade.getBounds();

    canvas.save();
    if (p < 1) {
      // Slide in from the left and reveal from the left edge.
      canvas.translate(-(1 - eased) * b.width * 0.35, 0);
      canvas.clipRect(Rect.fromLTRB(
          b.left - 1, b.top - 1, b.left + b.width * eased + 1, b.bottom + 1));
    }
    final opacity = (p * 2.5).clamp(0.0, 1.0);

    final fill = Paint()
      ..isAntiAlias = true
      ..color = markColor.withValues(alpha: markColor.a * opacity);
    canvas.drawPath(blade, fill);
    if (!monochrome) {
      // The honed bevel along the edge, in steel grey.
      canvas.save();
      canvas.clipPath(blade);
      canvas.drawRect(
        Rect.fromLTRB(
            b.left - 1, CrownBladeGeometry.bevelTop, b.right + 1, b.bottom + 1),
        Paint()..color = CrownBladeLogo.steel.withValues(alpha: opacity),
      );
      canvas.restore();
    }

    final g = glintProgress.clamp(0.0, 1.0);
    if (!monochrome && g > 0 && g < 1) {
      // A soft diagonal band of light travelling left to right.
      final x = b.left - 20 + (b.width + 40) * g;
      final strength = math.sin(math.pi * g);
      canvas.save();
      canvas.clipPath(blade);
      final band = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - 10, b.top),
          Offset(x + 10, b.bottom),
          [
            const Color(0x00FFFFFF),
            Colors.white.withValues(alpha: 0.95 * strength),
            const Color(0x00FFFFFF),
          ],
          const [0, 0.5, 1],
        );
      canvas.drawRect(b.inflate(2), band);
      canvas.restore();
    }
    canvas.restore();

    // As the shine leaves the point, a small sparkle flashes there.
    if (!monochrome && g > 0.7 && g < 1) {
      final t = (g - 0.7) / 0.3;
      final r = CrownBladeGeometry.sparkleRadius * math.sin(math.pi * t);
      if (r > 0.1) {
        canvas.drawPath(
          CrownBladeGeometry.sparklePath(CrownBladeGeometry.sparkleCenter, r),
          Paint()
            ..color = Colors.white
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintGem(Canvas canvas) {
    final p = gemProgress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final s = Curves.easeOutBack.transform(p);
    const c = CrownBladeGeometry.gemCenter;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawPath(
      CrownBladeGeometry.gemPath(),
      Paint()
        ..color = monochrome ? markColor : accentColor
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CrownBladeLogoPainter old) =>
      old.crownProgress != crownProgress ||
      old.bladeProgress != bladeProgress ||
      old.gemProgress != gemProgress ||
      old.glintProgress != glintProgress ||
      old.monochrome != monochrome ||
      old.padding != padding ||
      old.markColor != markColor ||
      old.accentColor != accentColor ||
      old.background != background;
}

/// The Crown & Blade mark as a square widget.
///
/// `CrownBladeLogo(size: 120)` is the static logo; pass progress values
/// (0..1) from an animation to build the intro.
class CrownBladeLogo extends StatelessWidget {
  const CrownBladeLogo({
    super.key,
    this.size = 96,
    this.crownProgress = 1,
    this.bladeProgress = 1,
    this.gemProgress = 1,
    this.glintProgress = 1,
    this.monochrome = false,
    this.padding = 0,
    this.markColor = markWhite,
    this.accentColor = AppTheme.green,
    this.background,
  });

  /// The full, static logo.
  const CrownBladeLogo.full({
    super.key,
    this.size = 96,
    this.monochrome = false,
    this.padding = 0,
    this.markColor = markWhite,
    this.accentColor = AppTheme.green,
    this.background,
  })  : crownProgress = 1,
        bladeProgress = 1,
        gemProgress = 1,
        glintProgress = 1;

  /// White of the mark.
  static const Color markWhite = Color(0xFFFFFFFF);

  /// Cool steel grey the blade fades to at its edge (colour mode only).
  static const Color steel = Color(0xFFC4C7CD);

  /// App icon background: charcoal at the top left to the darkest charcoal
  /// at the bottom right.
  static const LinearGradient iconBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.charcoal, AppTheme.charcoalDeep],
  );

  /// Solid background for the Android adaptive icon and the splash screen.
  static const Color iconBackgroundColor = AppTheme.ink;

  final double size;
  final double crownProgress;
  final double bladeProgress;
  final double gemProgress;
  final double glintProgress;
  final bool monochrome;
  final double padding;
  final Color markColor;
  final Color accentColor;
  final Gradient? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CrownBladeLogoPainter(
          crownProgress: crownProgress,
          bladeProgress: bladeProgress,
          gemProgress: gemProgress,
          glintProgress: glintProgress,
          monochrome: monochrome,
          padding: padding,
          markColor: markColor,
          accentColor: accentColor,
          background: background,
        ),
      ),
    );
  }
}
