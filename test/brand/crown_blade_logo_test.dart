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
      for (final mono in [false, true]) {
        _paint(CrownBladeLogoPainter(
          crownProgress: v,
          bladeProgress: v,
          gemProgress: v,
          glintProgress: v,
          monochrome: mono,
          padding: 0.2,
          background: CrownBladeLogo.iconBackground,
        ));
      }
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
