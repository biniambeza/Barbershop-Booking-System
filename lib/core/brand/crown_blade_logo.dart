import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Geometry of the Crown & Blade mark, in design units.
///
/// The mark is a three-point crown drawn as one open stroke with a round
/// jewel on each tip, a straight razor blade lying under it as the crown's
/// band, and a faceted gem inside the crown. Everything is defined in a
/// design space whose visual bounds are [bounds] (stroke widths and jewels
/// included); [fit] maps that space into any canvas with a padding, keeping
/// the mark centred.
abstract final class CrownBladeGeometry {
  /// Width of the crown stroke.
  static const double strokeWidth = 10;

  /// The three crown tips (left, centre, right).
  static const List<Offset> tips = [
    Offset(6, 25),
    Offset(50, 12),
    Offset(94, 25),
  ];

  /// The crown outline as one open path, left foot to right foot. The feet
  /// end just inside the blade (which is painted over them), so the crown
  /// stands on the blade's spine and both read as one object.
  static Path crownPath() => Path()
    ..moveTo(16, bladeTop + 3)
    ..lineTo(tips[0].dx, tips[0].dy)
    ..lineTo(31, 48)
    ..lineTo(tips[1].dx, tips[1].dy)
    ..lineTo(69, 48)
    ..lineTo(tips[2].dx, tips[2].dy)
    ..lineTo(84, bladeTop + 3);

  /// Radius of the round jewels on the crown tips.
  static const double jewelRadius = 6.6;

  /// Where each jewel sits: on its tip, nudged outwards so it reads as a
  /// finial on top of the stroke rather than a blob in its corner.
  static const List<Offset> jewelCenters = [
    Offset(4.6, 21.4),
    Offset(50, 7.6),
    Offset(95.4, 21.4),
  ];

  /// Top (spine) and bottom (edge) of the blade, and where the honed bevel
  /// starts.
  static const double bladeTop = 76;
  static const double bladeBottom = 88;
  static const double bevelTop = 82.5;

  /// The razor blade: a squared heel on the left, a straight spine, and a
  /// point at the right where the edge curves up to meet the spine.
  static Path bladePath() => Path()
    ..moveTo(-5, bladeTop)
    ..lineTo(105, bladeTop)
    ..quadraticBezierTo(102, bladeBottom, 88, bladeBottom)
    ..lineTo(-3, bladeBottom)
    ..quadraticBezierTo(-5, bladeBottom, -5, bladeBottom - 2)
    ..close();

  /// The pivot pin near the heel of the razor.
  static const Offset pinCenter = Offset(2.2, 80.6);
  static const double pinRadius = 1.7;

  /// Centre and half-height of the gem (a diamond slightly taller than
  /// wide).
  static const Offset gemCenter = Offset(50, 61);
  static const double gemRadius = 11;
  static const double gemHalfWidth = 9.4;

  /// The gem: a diamond (rhombus on its point).
  static Path gemPath() => Path()
    ..moveTo(gemCenter.dx, gemCenter.dy - gemRadius)
    ..lineTo(gemCenter.dx + gemHalfWidth, gemCenter.dy)
    ..lineTo(gemCenter.dx, gemCenter.dy + gemRadius)
    ..lineTo(gemCenter.dx - gemHalfWidth, gemCenter.dy)
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

  /// Visual bounds of the whole mark (crown stroke and jewels included).
  static final Rect bounds = () {
    var r = crownPath()
        .getBounds()
        .inflate(strokeWidth / 2)
        .expandToInclude(bladePath().getBounds())
        .expandToInclude(gemPath().getBounds());
    for (final c in jewelCenters) {
      r = r.expandToInclude(Rect.fromCircle(center: c, radius: jewelRadius));
    }
    return r;
  }();

  /// How far along the crown stroke (0..1) each tip is reached, so the
  /// jewels appear as the stroke draws past them.
  static final List<double> tipFractions = () {
    final metric = crownPath().computeMetrics().first;
    final total = metric.length;
    final result = <double>[];
    for (final tip in tips) {
      var best = 0.0;
      var bestD = double.infinity;
      for (var d = 0.0; d <= total; d += total / 400) {
        final p = metric.getTangentForOffset(d)!.position;
        final dist = (p - tip).distance;
        if (dist < bestD) {
          bestD = dist;
          best = d / total;
        }
      }
      result.add(best);
    }
    return result;
  }();

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

/// Which background the mark is drawn for.
enum CrownBladeVariant {
  /// White (or very light) backgrounds: green crown, gunmetal blade,
  /// emerald gem.
  onLight,

  /// Black (or very dark) backgrounds: luminous green crown, bright steel
  /// blade, emerald gem.
  onDark,

  /// The brand green (app icon, green hero cards): white crown, bright
  /// steel blade, white diamond.
  onBrand,

  /// One flat colour (CrownBladeLogoPainter.markColor) everywhere.
  monochrome;

  /// The variant for a page of the given brightness.
  static CrownBladeVariant forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? onDark : onLight;
}

/// Colours of one [CrownBladeVariant].
@immutable
class CrownBladePalette {
  const CrownBladePalette({
    required this.crownTop,
    required this.crownBottom,
    required this.crownShadow,
    required this.jewelLight,
    required this.jewelMid,
    required this.jewelDark,
    required this.gemTable,
    required this.gemTopLeft,
    required this.gemTopRight,
    required this.gemBottomLeft,
    required this.gemBottomRight,
    required this.bladeSpine,
    required this.bladeBody,
    required this.bladeHone,
    required this.bevelTop,
    required this.bevelBottom,
    required this.bladeEdge,
    required this.pin,
    required this.sparkle,
  });

  final Color crownTop;
  final Color crownBottom;

  /// Soft shadow (or glow on dark) under the crown and gem.
  final Color crownShadow;

  final Color jewelLight;
  final Color jewelMid;
  final Color jewelDark;

  final Color gemTable;
  final Color gemTopLeft;
  final Color gemTopRight;
  final Color gemBottomLeft;
  final Color gemBottomRight;

  final Color bladeSpine;
  final Color bladeBody;

  /// The crisp honed line where the bevel starts.
  final Color bladeHone;
  final Color bevelTop;
  final Color bevelBottom;

  /// The cutting edge (bottom line of the blade).
  final Color bladeEdge;
  final Color pin;

  /// Glint sparkles and twinkles.
  final Color sparkle;

  static const onLight = CrownBladePalette(
    crownTop: Color(0xFF22C55E),
    crownBottom: Color(0xFF15803D),
    crownShadow: Color(0x2915803D),
    jewelLight: Color(0xFFDCFCE7),
    jewelMid: Color(0xFF22C55E),
    jewelDark: Color(0xFF15803D),
    gemTable: Color(0xFF4ADE80),
    gemTopLeft: Color(0xFFBBF7D0),
    gemTopRight: Color(0xFF22C55E),
    gemBottomLeft: Color(0xFF16A34A),
    gemBottomRight: Color(0xFF14532D),
    bladeSpine: Color(0xFF5B6472),
    bladeBody: Color(0xFF1F2530),
    bladeHone: Color(0xFFF1F5F9),
    bevelTop: Color(0xFFB4BCC7),
    bevelBottom: Color(0xFF7D8794),
    bladeEdge: Color(0xFF475262),
    pin: Color(0xFF8B95A3),
    sparkle: Color(0xFF16A34A),
  );

  static const onDark = CrownBladePalette(
    crownTop: Color(0xFF4ADE80),
    crownBottom: Color(0xFF16A34A),
    crownShadow: Color(0x4022C55E),
    jewelLight: Color(0xFFF0FDF4),
    jewelMid: Color(0xFF4ADE80),
    jewelDark: Color(0xFF15803D),
    gemTable: Color(0xFF4ADE80),
    gemTopLeft: Color(0xFFDCFCE7),
    gemTopRight: Color(0xFF22C55E),
    gemBottomLeft: Color(0xFF16A34A),
    gemBottomRight: Color(0xFF166534),
    bladeSpine: Color(0xFFFFFFFF),
    bladeBody: Color(0xFFC9CFD8),
    bladeHone: Color(0xFFFFFFFF),
    bevelTop: Color(0xFF7C8592),
    bevelBottom: Color(0xFFAEB6C1),
    bladeEdge: Color(0xFFF8FAFC),
    pin: Color(0xFF6B7380),
    sparkle: Color(0xFFFFFFFF),
  );

  static const onBrand = CrownBladePalette(
    crownTop: Color(0xFFFFFFFF),
    crownBottom: Color(0xFFE6F6EC),
    crownShadow: Color(0x4D052E16),
    jewelLight: Color(0xFFFFFFFF),
    jewelMid: Color(0xFFFFFFFF),
    jewelDark: Color(0xFFD5EADD),
    gemTable: Color(0xFFFFFFFF),
    gemTopLeft: Color(0xFFFFFFFF),
    gemTopRight: Color(0xFFE3EEE7),
    gemBottomLeft: Color(0xFFF1F7F3),
    gemBottomRight: Color(0xFFBFD3C6),
    bladeSpine: Color(0xFFFFFFFF),
    bladeBody: Color(0xFFE2E7EC),
    bladeHone: Color(0xFFFFFFFF),
    bevelTop: Color(0xFF9AA5B1),
    bevelBottom: Color(0xFFC9D1D9),
    bladeEdge: Color(0xFFFFFFFF),
    pin: Color(0xFF8C97A3),
    sparkle: Color(0xFFFFFFFF),
  );

  /// Everything in one [color].
  factory CrownBladePalette.mono(Color color) => CrownBladePalette(
        crownTop: color,
        crownBottom: color,
        crownShadow: const Color(0x00000000),
        jewelLight: color,
        jewelMid: color,
        jewelDark: color,
        gemTable: color,
        gemTopLeft: color,
        gemTopRight: color,
        gemBottomLeft: color,
        gemBottomRight: color,
        bladeSpine: color,
        bladeBody: color,
        bladeHone: color,
        bevelTop: color,
        bevelBottom: color,
        bladeEdge: color,
        pin: const Color(0x00000000),
        sparkle: color,
      );
}

/// Paints the Crown & Blade mark (no text).
///
/// Every progress value runs 0..1 and 1.0 everywhere is the static logo:
/// * [crownProgress] draws the crown stroke on from the left foot to the
///   right foot (0 = nothing, 1 = full crown); each jewel pops in as the
///   stroke reaches its tip.
/// * [bladeProgress] slides the blade in from the left while it is revealed
///   and fades in (0 = hidden, 1 = in place).
/// * [gemProgress] pops the gem in with a slight overshoot (0 = hidden).
/// * [glintProgress] moves a light shine along the blade from left to right;
///   the shine is only visible strictly between 0 and 1.
/// * [twinkleProgress] twinkles the three jewels in turn, left to right
///   (only visible strictly between 0 and 1).
/// * [gemShineProgress] sweeps a light across the gem facets and flashes a
///   small star on it (only visible strictly between 0 and 1).
class CrownBladeLogoPainter extends CustomPainter {
  const CrownBladeLogoPainter({
    this.crownProgress = 1,
    this.bladeProgress = 1,
    this.gemProgress = 1,
    this.glintProgress = 1,
    this.twinkleProgress = 1,
    this.gemShineProgress = 1,
    this.variant = CrownBladeVariant.onBrand,
    this.monochrome = false,
    this.padding = 0,
    this.markColor = CrownBladeLogo.markWhite,
    this.accentColor,
    this.background,
  });

  final double crownProgress;
  final double bladeProgress;
  final double gemProgress;
  final double glintProgress;
  final double twinkleProgress;
  final double gemShineProgress;

  /// The colour scheme (see [CrownBladeVariant]).
  final CrownBladeVariant variant;

  /// Draw everything in [markColor] only (same as
  /// [CrownBladeVariant.monochrome]).
  final bool monochrome;

  /// Clear space on every side, as a fraction of the shorter side.
  final double padding;

  /// Colour of the monochrome mark.
  final Color markColor;

  /// Optional base colour of the gem (its facets are shaded from it).
  final Color? accentColor;

  /// Optional full-bleed background behind the mark.
  final Gradient? background;

  bool get _mono => monochrome || variant == CrownBladeVariant.monochrome;

  CrownBladePalette get _palette {
    if (_mono) return CrownBladePalette.mono(markColor);
    final base = switch (variant) {
      CrownBladeVariant.onLight => CrownBladePalette.onLight,
      CrownBladeVariant.onDark => CrownBladePalette.onDark,
      _ => CrownBladePalette.onBrand,
    };
    final a = accentColor;
    if (a == null) return base;
    Color mix(Color other, double t) => Color.lerp(a, other, t)!;
    return CrownBladePalette(
      crownTop: base.crownTop,
      crownBottom: base.crownBottom,
      crownShadow: base.crownShadow,
      jewelLight: base.jewelLight,
      jewelMid: base.jewelMid,
      jewelDark: base.jewelDark,
      gemTable: mix(Colors.white, 0.2),
      gemTopLeft: mix(Colors.white, 0.6),
      gemTopRight: a,
      gemBottomLeft: mix(Colors.black, 0.15),
      gemBottomRight: mix(Colors.black, 0.45),
      bladeSpine: base.bladeSpine,
      bladeBody: base.bladeBody,
      bladeHone: base.bladeHone,
      bevelTop: base.bevelTop,
      bevelBottom: base.bevelBottom,
      bladeEdge: base.bladeEdge,
      pin: base.pin,
      sparkle: base.sparkle,
    );
  }

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

    final palette = _palette;
    _paintCrown(canvas, palette, scale);
    _paintBlade(canvas, palette);
    _paintGem(canvas, palette);
    _paintTwinkles(canvas, palette);

    canvas.restore();
  }

  static Path _partial(Path path, double p) {
    if (p >= 1) return path;
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * p), Offset.zero);
    }
    return out;
  }

  void _paintCrown(Canvas canvas, CrownBladePalette c, double scale) {
    final p = crownProgress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final path = _partial(CrownBladeGeometry.crownPath(), p);
    const top = 4.0;
    const bottom = CrownBladeGeometry.bladeTop;

    // Depth: a soft shadow (a glow on dark) under the stroke.
    if (!_mono && c.crownShadow.a > 0) {
      canvas.drawPath(
        path.shift(const Offset(0, 2.2)),
        Paint()
          ..color = c.crownShadow
          ..style = PaintingStyle.stroke
          ..strokeWidth = CrownBladeGeometry.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CrownBladeGeometry.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    if (_mono) {
      paint.color = c.crownTop;
    } else {
      paint.shader = ui.Gradient.linear(
        const Offset(0, top),
        const Offset(0, bottom),
        [c.crownTop, c.crownBottom],
      );
    }
    canvas.drawPath(path, paint);

    // Jewels on the tips, each popping in as the stroke reaches it.
    for (var i = 0; i < 3; i++) {
      final reach = CrownBladeGeometry.tipFractions[i];
      final j = p >= 1 ? 1.0 : ((p - reach) / 0.12).clamp(0.0, 1.0);
      if (j <= 0) continue;
      final s = Curves.easeOutBack.transform(j);
      _paintJewel(canvas, c, CrownBladeGeometry.jewelCenters[i],
          CrownBladeGeometry.jewelRadius * s);
    }
  }

  void _paintJewel(Canvas canvas, CrownBladePalette c, Offset o, double r) {
    if (r <= 0.05) return;
    final paint = Paint()..isAntiAlias = true;
    if (_mono) {
      paint.color = c.jewelMid;
    } else {
      paint.shader = ui.Gradient.radial(
        o + Offset(-r * 0.35, -r * 0.4),
        r * 1.35,
        [c.jewelLight, c.jewelMid, c.jewelDark],
        const [0, 0.45, 1],
      );
    }
    canvas.drawCircle(o, r, paint);
    if (!_mono) {
      // Tiny specular highlight.
      canvas.drawCircle(
        o + Offset(-r * 0.32, -r * 0.36),
        r * 0.22,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..isAntiAlias = true,
      );
    }
  }

  void _paintBlade(Canvas canvas, CrownBladePalette c) {
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
    Color o(Color x) => x.withValues(alpha: x.a * opacity);

    if (_mono) {
      canvas.drawPath(
          blade,
          Paint()
            ..color = o(c.bladeBody)
            ..isAntiAlias = true);
    } else {
      const top = CrownBladeGeometry.bladeTop;
      const bevel = CrownBladeGeometry.bevelTop;
      const bottom = CrownBladeGeometry.bladeBottom;
      canvas.save();
      canvas.clipPath(blade);
      // Body: spine highlight down to the steel body.
      canvas.drawRect(
        Rect.fromLTRB(b.left - 1, top - 1, b.right + 1, bevel + 0.5),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, top),
            const Offset(0, bevel),
            [o(c.bladeSpine), o(c.bladeBody)],
            const [0, 0.55],
          ),
      );
      // Brushed steel: a few faint horizontal strokes.
      final brush = Paint()
        ..color = o(c.bladeSpine.withValues(alpha: 0.10))
        ..strokeWidth = 0.35;
      for (final y in [77.6, 79.0, 80.3, 81.4]) {
        canvas.drawLine(Offset(b.left, y), Offset(b.right, y), brush);
      }
      // The honed bevel.
      canvas.drawRect(
        Rect.fromLTRB(b.left - 1, bevel, b.right + 1, bottom + 1),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, bevel),
            const Offset(0, bottom),
            [o(c.bevelTop), o(c.bevelBottom)],
          ),
      );
      // Crisp hone line where the bevel starts.
      canvas.drawRect(
        Rect.fromLTRB(b.left - 1, bevel - 0.45, b.right + 1, bevel + 0.45),
        Paint()..color = o(c.bladeHone),
      );
      // The cutting edge.
      canvas.drawRect(
        Rect.fromLTRB(b.left - 1, bottom - 0.9, b.right + 1, bottom + 1),
        Paint()..color = o(c.bladeEdge),
      );
      canvas.restore();
      // Pivot pin near the heel.
      if (c.pin.a > 0) {
        canvas.drawCircle(
          CrownBladeGeometry.pinCenter,
          CrownBladeGeometry.pinRadius,
          Paint()
            ..color = o(c.pin)
            ..isAntiAlias = true,
        );
      }
    }

    final g = glintProgress.clamp(0.0, 1.0);
    if (!_mono && g > 0 && g < 1) {
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
    if (!_mono && g > 0.7 && g < 1) {
      final t = (g - 0.7) / 0.3;
      final r = CrownBladeGeometry.sparkleRadius * math.sin(math.pi * t);
      if (r > 0.1) {
        canvas.drawPath(
          CrownBladeGeometry.sparklePath(CrownBladeGeometry.sparkleCenter, r),
          Paint()
            ..color = c.sparkle
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintGem(Canvas canvas, CrownBladePalette c) {
    final p = gemProgress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final s = Curves.easeOutBack.transform(p);
    const ctr = CrownBladeGeometry.gemCenter;
    canvas.save();
    canvas.translate(ctr.dx, ctr.dy);
    canvas.scale(s);
    canvas.translate(-ctr.dx, -ctr.dy);

    final outline = CrownBladeGeometry.gemPath();
    if (_mono) {
      canvas.drawPath(
          outline,
          Paint()
            ..color = c.gemTable
            ..isAntiAlias = true);
      canvas.restore();
      return;
    }

    if (c.crownShadow.a > 0) {
      canvas.drawPath(
        outline.shift(const Offset(0, 1.6)),
        Paint()
          ..color = c.crownShadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    const r = CrownBladeGeometry.gemRadius;
    const w = CrownBladeGeometry.gemHalfWidth;
    final top = ctr + const Offset(0, -r);
    final right = ctr + const Offset(w, 0);
    final bottom = ctr + const Offset(0, r);
    final left = ctr + const Offset(-w, 0);
    // The table (flat top facet), a smaller diamond set a little high.
    const k = 0.42;
    final tc = ctr + const Offset(0, -1.2);
    final tTop = tc + const Offset(0, -r * k);
    final tRight = tc + const Offset(w * k, 0);
    final tBottom = tc + const Offset(0, r * k);
    final tLeft = tc + const Offset(-w * k, 0);

    Path quad(Offset a, Offset b, Offset d, Offset e) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy)
      ..close();
    final fill = Paint()..isAntiAlias = true;

    // Draw the whole gem in the mid tone first so no hairline gaps show
    // between the facets.
    canvas.drawPath(outline, fill..color = c.gemTopRight);
    canvas.drawPath(quad(left, top, tTop, tLeft), fill..color = c.gemTopLeft);
    canvas.drawPath(
        quad(top, right, tRight, tTop), fill..color = c.gemTopRight);
    canvas.drawPath(
        quad(right, bottom, tBottom, tRight), fill..color = c.gemBottomRight);
    canvas.drawPath(
        quad(bottom, left, tLeft, tBottom), fill..color = c.gemBottomLeft);
    canvas.drawPath(
        quad(tTop, tRight, tBottom, tLeft), fill..color = c.gemTable);

    // A light sweeping across the facets, with a star at its peak.
    final g = gemShineProgress.clamp(0.0, 1.0);
    if (g > 0 && g < 1) {
      final strength = math.sin(math.pi * g);
      final x = ctr.dx - w - 6 + (2 * w + 12) * g;
      canvas.save();
      canvas.clipPath(outline);
      canvas.drawRect(
        Rect.fromCircle(center: ctr, radius: r + 2),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x - 5, ctr.dy - r),
            Offset(x + 5, ctr.dy + r),
            [
              const Color(0x00FFFFFF),
              Colors.white.withValues(alpha: 0.85 * strength),
              const Color(0x00FFFFFF),
            ],
            const [0, 0.5, 1],
          ),
      );
      canvas.restore();
      if (g > 0.35 && g < 0.95) {
        final t = (g - 0.35) / 0.6;
        final sr = 7.5 * math.sin(math.pi * t);
        if (sr > 0.1) {
          canvas.drawPath(
            CrownBladeGeometry.sparklePath(
                ctr + Offset(-w * 0.38, -r * 0.42), sr),
            Paint()
              ..color = c.sparkle
              ..isAntiAlias = true,
          );
        }
      }
    }
    canvas.restore();
  }

  void _paintTwinkles(Canvas canvas, CrownBladePalette c) {
    final t = twinkleProgress.clamp(0.0, 1.0);
    if (_mono || t <= 0 || t >= 1) return;
    // Each jewel twinkles for 50% of the run, starting 25% apart.
    for (var i = 0; i < 3; i++) {
      final local = (t - i * 0.25) / 0.5;
      if (local <= 0 || local >= 1) continue;
      final env = math.sin(math.pi * local);
      final o = CrownBladeGeometry.jewelCenters[i] +
          const Offset(-CrownBladeGeometry.jewelRadius * 0.32,
              -CrownBladeGeometry.jewelRadius * 0.36);
      canvas.drawCircle(
        CrownBladeGeometry.jewelCenters[i],
        CrownBladeGeometry.jewelRadius * (1 + 0.9 * env),
        Paint()
          ..color = c.jewelLight.withValues(alpha: 0.28 * env)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawPath(
        CrownBladeGeometry.sparklePath(o, 7.5 * env),
        Paint()
          ..color = Colors.white.withValues(alpha: env)
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(CrownBladeLogoPainter old) =>
      old.crownProgress != crownProgress ||
      old.bladeProgress != bladeProgress ||
      old.gemProgress != gemProgress ||
      old.glintProgress != glintProgress ||
      old.twinkleProgress != twinkleProgress ||
      old.gemShineProgress != gemShineProgress ||
      old.variant != variant ||
      old.monochrome != monochrome ||
      old.padding != padding ||
      old.markColor != markColor ||
      old.accentColor != accentColor ||
      old.background != background;
}

/// The Crown & Blade mark as a square widget.
///
/// `CrownBladeLogo(size: 120)` is the static logo; pass progress values
/// (0..1) from an animation to build an intro. [variant] picks the colours
/// for the background the mark sits on; when it is null the logo follows
/// the theme ([CrownBladeVariant.onLight] / [CrownBladeVariant.onDark]),
/// except over a [background] gradient, which gets
/// [CrownBladeVariant.onBrand].
class CrownBladeLogo extends StatelessWidget {
  const CrownBladeLogo({
    super.key,
    this.size = 96,
    this.crownProgress = 1,
    this.bladeProgress = 1,
    this.gemProgress = 1,
    this.glintProgress = 1,
    this.twinkleProgress = 1,
    this.gemShineProgress = 1,
    this.variant = CrownBladeVariant.onBrand,
    this.monochrome = false,
    this.padding = 0,
    this.markColor = markWhite,
    this.accentColor,
    this.background,
  });

  /// The full, static logo.
  const CrownBladeLogo.full({
    super.key,
    this.size = 96,
    this.variant = CrownBladeVariant.onBrand,
    this.monochrome = false,
    this.padding = 0,
    this.markColor = markWhite,
    this.accentColor,
    this.background,
  })  : crownProgress = 1,
        bladeProgress = 1,
        gemProgress = 1,
        glintProgress = 1,
        twinkleProgress = 1,
        gemShineProgress = 1;

  /// The full, static logo in the colours for the current theme (green on
  /// white in light mode, green and bright steel on black in dark mode).
  const CrownBladeLogo.adaptive({
    super.key,
    this.size = 96,
    this.padding = 0,
  })  : crownProgress = 1,
        bladeProgress = 1,
        gemProgress = 1,
        glintProgress = 1,
        twinkleProgress = 1,
        gemShineProgress = 1,
        variant = null,
        monochrome = false,
        markColor = markWhite,
        accentColor = null,
        background = null;

  /// White of the mark.
  static const Color markWhite = Color(0xFFFFFFFF);

  /// Brand greens (the logo's own, independent of the app theme).
  static const Color brandGreen = Color(0xFF16A34A);
  static const Color brandGreenLight = Color(0xFF22C55E);
  static const Color brandGreenDeep = Color(0xFF15803D);

  /// Cool steel grey of the blade's bevel.
  static const Color steel = Color(0xFFC4C7CD);

  /// App icon background: bright green at the top left to deep green at
  /// the bottom right.
  static const LinearGradient iconBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandGreenLight, brandGreenDeep],
  );

  /// Solid background for the Android adaptive icon (iOS has no alpha).
  static const Color iconBackgroundColor = brandGreen;

  /// Native splash / start-up intro backgrounds.
  static const Color splashLight = Color(0xFFFFFFFF);
  static const Color splashDark = Color(0xFF0A0A0A);

  /// The splash background for [brightness].
  static Color splashBackground(Brightness brightness) =>
      brightness == Brightness.dark ? splashDark : splashLight;

  final double size;
  final double crownProgress;
  final double bladeProgress;
  final double gemProgress;
  final double glintProgress;
  final double twinkleProgress;
  final double gemShineProgress;

  /// Null: follow the theme's brightness.
  final CrownBladeVariant? variant;
  final bool monochrome;
  final double padding;
  final Color markColor;
  final Color? accentColor;
  final Gradient? background;

  @override
  Widget build(BuildContext context) {
    final v = variant ??
        (background != null
            ? CrownBladeVariant.onBrand
            : CrownBladeVariant.forBrightness(Theme.of(context).brightness));
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CrownBladeLogoPainter(
          crownProgress: crownProgress,
          bladeProgress: bladeProgress,
          gemProgress: gemProgress,
          glintProgress: glintProgress,
          twinkleProgress: twinkleProgress,
          gemShineProgress: gemShineProgress,
          variant: v,
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
