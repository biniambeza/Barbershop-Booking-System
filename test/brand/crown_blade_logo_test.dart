import 'dart:ui' as ui;

import 'package:barbershop_booking/core/brand/crown_blade_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _paint(CrownBladeLogoPainter painter, [Size size = const Size(200, 200)]) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  test('painter paints at progress 0, mid-way and 1 without errors', () {
    for (final v in [0.0, 0.3, 0.5, 0.85, 1.0]) {
      for (final variant in CrownBladeVariant.values) {
        _paint(CrownBladeLogoPainter(
          crownProgress: v,
          bladeProgress: v,
          gemProgress: v,
          glintProgress: v,
          twinkleProgress: v,
          gemShineProgress: v,
          variant: variant,
          padding: 0.2,
          background: CrownBladeLogo.iconBackground,
        ));
      }
      _paint(CrownBladeLogoPainter(glintProgress: v, monochrome: true));
      _paint(CrownBladeLogoPainter(
          gemShineProgress: v, accentColor: const Color(0xFF2563EB)));
    }
    // Out-of-range values are clamped.
    _paint(const CrownBladeLogoPainter(crownProgress: -1, gemProgress: 2));
  });

  test('shouldRepaint compares every value', () {
    const base = CrownBladeLogoPainter();
    expect(base.shouldRepaint(const CrownBladeLogoPainter()), isFalse);
    expect(base.shouldRepaint(const CrownBladeLogoPainter(crownProgress: 0.5)),
        isTrue);
    expect(base.shouldRepaint(const CrownBladeLogoPainter(bladeProgress: 0.5)),
        isTrue);
    expect(base.shouldRepaint(const CrownBladeLogoPainter(gemProgress: 0.5)),
        isTrue);
    expect(base.shouldRepaint(const CrownBladeLogoPainter(glintProgress: 0.5)),
        isTrue);
    expect(base.shouldRepaint(const CrownBladeLogoPainter(monochrome: true)),
        isTrue);
    expect(
        base.shouldRepaint(const CrownBladeLogoPainter(twinkleProgress: 0.5)),
        isTrue);
    expect(
        base.shouldRepaint(const CrownBladeLogoPainter(gemShineProgress: 0.5)),
        isTrue);
    expect(
        base.shouldRepaint(
            const CrownBladeLogoPainter(variant: CrownBladeVariant.onDark)),
        isTrue);
    expect(
        base.shouldRepaint(const CrownBladeLogoPainter(padding: 0.1)), isTrue);
  });

  test('fit centres the mark and honours the padding', () {
    const size = Size(1000, 1000);
    final r = CrownBladeGeometry.fit(size, padding: 0.2);
    expect(r.center.dx, closeTo(500, 0.001));
    expect(r.center.dy, closeTo(500, 0.001));
    // The mark is wider than tall, so its width fills the padded square.
    expect(r.width, closeTo(600, 0.001));
    expect(r.height, lessThan(r.width));
    expect(CrownBladeGeometry.scaleFor(size, padding: 0.2),
        closeTo(600 / CrownBladeGeometry.bounds.width, 1e-9));
  });

  test('the jewels sit on the crown tips, in order, inside the bounds', () {
    final f = CrownBladeGeometry.tipFractions;
    expect(f[0], lessThan(f[1]));
    expect(f[1], lessThan(f[2]));
    expect(f[1], closeTo(0.5, 0.02)); // the crown is symmetric
    for (final c in CrownBladeGeometry.jewelCenters) {
      expect(CrownBladeGeometry.bounds.contains(c), isTrue);
    }
  });

  testWidgets('CrownBladeLogo.adaptive follows the theme brightness',
      (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: b),
        home: const Center(child: CrownBladeLogo.adaptive(size: 64)),
      ));
      await tester.pumpAndSettle(); // the theme animates
      final painter = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byType(CrownBladeLogo),
              matching: find.byType(CustomPaint)))
          .painter! as CrownBladeLogoPainter;
      expect(painter.variant, CrownBladeVariant.forBrightness(b));
    }
  });

  testWidgets('CrownBladeLogo widgets lay out at the requested size',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CrownBladeLogo(
              size: 48,
              crownProgress: 0,
              bladeProgress: 0,
              gemProgress: 0,
              glintProgress: 0),
          CrownBladeLogo.full(size: 120, monochrome: true),
        ]),
      ),
    ));
    final sizes = tester
        .widgetList<CrownBladeLogo>(find.byType(CrownBladeLogo))
        .map((w) => tester.getSize(find.byWidget(w)))
        .toList();
    expect(sizes, [const Size(48, 48), const Size(120, 120)]);
    expect(tester.takeException(), isNull);
  });
}
