// Renders the Crown & Blade logo mark (lib/core/brand/crown_blade_logo.dart)
// to the PNGs the launcher icons, splash screens and store listing use. Not
// part of the normal suite: the 'brand' tag is skipped by dart_test.yaml.
// Run it with
//
//   flutter test --tags brand --run-skipped test/brand/generate_brand_assets_test.dart
//
// and look at assets/brand/*.png (previews: build/brand_preview/*.png).
@Tags(['brand'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barbershop_booking/core/brand/crown_blade_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _outDir = 'assets/brand';
const _previewDir = 'build/brand_preview';

/// Padding (fraction of the side, each side) of every exported asset.
const double iconPadding = 0.19; // full-bleed icon: mark is 62% wide
const double foregroundPadding = 0.31; // adaptive foreground (108 dp canvas)
const double splashPadding = 0.29; // Android 12 splash (288 dp canvas)
const double plainPadding = 0.04; // iOS / web splash, mark only

Future<Uint8List> _render(CrownBladeLogoPainter painter, int px) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(px.toDouble(), px.toDouble());
  painter.paint(canvas, size);
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _write(WidgetTester tester, String path,
    CrownBladeLogoPainter painter, int px) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    bytes = await _render(painter, px);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  });
  return bytes;
}

/// Largest distance (as a fraction of the side) from the centre to any
/// pixel that is not fully transparent.
double _maxRadiusFraction(Uint8List png) {
  final image = img.decodePng(png)!;
  final c = image.width / 2;
  var max = 0.0;
  for (final p in image) {
    if (p.a > 8) {
      final d =
          math.sqrt(math.pow(p.x + 0.5 - c, 2) + math.pow(p.y + 0.5 - c, 2));
      if (d > max) max = d;
    }
  }
  return max / image.width;
}

void main() {
  testWidgets('export brand PNGs', (tester) async {
    const full = CrownBladeLogoPainter(
      padding: iconPadding,
      background: CrownBladeLogo.iconBackground,
    );
    await _write(tester, '$_outDir/icon-1024.png', full, 1024);
    await _write(tester, 'store/graphics/icon-512.png', full, 512);

    final fg = await _write(tester, '$_outDir/icon-foreground-1024.png',
        const CrownBladeLogoPainter(padding: foregroundPadding), 1024);
    // Adaptive icons: the safe zone is a 66 dp circle in the 108 dp canvas.
    expect(_maxRadiusFraction(fg), lessThan(33 / 108));
    debugPrint(
        'foreground max radius: ${_maxRadiusFraction(fg)} (limit ${33 / 108})');

    final mono = await _write(
        tester,
        '$_outDir/icon-monochrome-1024.png',
        const CrownBladeLogoPainter(
            padding: foregroundPadding, monochrome: true),
        1024);
    expect(_maxRadiusFraction(mono), lessThan(33 / 108));

    final splash = await _write(tester, '$_outDir/splash-logo-1152.png',
        const CrownBladeLogoPainter(padding: splashPadding), 1152);
    // Android 12 splash: the icon is masked to a circle 2/3 of the canvas.
    expect(_maxRadiusFraction(splash), lessThan(1 / 3 - 0.02));
    debugPrint(
        'splash max radius: ${_maxRadiusFraction(splash)} (limit ${1 / 3})');

    await _write(tester, '$_outDir/splash-logo-plain-512.png',
        const CrownBladeLogoPainter(padding: plainPadding), 512);

    // Previews (not shipped). The launcher shows the central 72 of the
    // 108 dp adaptive canvas, here masked to a circle.
    await tester.runAsync(() async {
      Future<void> masked(String name, double zoom, double padding) async {
        const px = 512;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(px * 1.0, px * 1.0);
        canvas.drawRect(
            Offset.zero & size, Paint()..color = const Color(0xFFEDEDED));
        canvas.clipPath(Path()..addOval(Offset.zero & size));
        canvas.drawRect(Offset.zero & size,
            Paint()..color = CrownBladeLogo.iconBackgroundColor);
        canvas.translate(px / 2, px / 2);
        canvas.scale(zoom);
        canvas.translate(-px / 2, -px / 2);
        CrownBladeLogoPainter(padding: padding).paint(canvas, size);
        final image = await recorder.endRecording().toImage(px, px);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_previewDir/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(data!.buffer.asUint8List());
      }

      await masked('adaptive-masked', 108 / 72, foregroundPadding);
      await masked('android12-splash-masked', 3 / 2, splashPadding);
    });

    await _write(tester, '$_previewDir/icon-48.png', full, 48);
    await _write(tester, '$_previewDir/icon-96.png', full, 96);
    for (final frame in <String, CrownBladeLogoPainter>{
      'crown-050': const CrownBladeLogoPainter(
          crownProgress: 0.5,
          bladeProgress: 0,
          gemProgress: 0,
          glintProgress: 0,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
      'blade-060': const CrownBladeLogoPainter(
          bladeProgress: 0.6,
          gemProgress: 0,
          glintProgress: 0,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
      'gem-070-glint-045': const CrownBladeLogoPainter(
          gemProgress: 0.7,
          glintProgress: 0.45,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
      'glint-088': const CrownBladeLogoPainter(
          glintProgress: 0.88,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
      'mono-on-ink': const CrownBladeLogoPainter(
          monochrome: true,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
    }.entries) {
      await _write(tester, '$_previewDir/${frame.key}.png', frame.value, 512);
    }
  });
}
