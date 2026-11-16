// Renders the Crown & Blade logo mark (lib/core/brand/crown_blade_logo.dart)
// to the PNGs the launcher icons, splash screens, web loader and store
// listing use. Not part of the normal suite: the 'brand' tag is skipped by
// dart_test.yaml. Run it with
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
import 'package:barbershop_booking/features/splash/animated_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _outDir = 'assets/brand';
const _previewDir = 'build/brand_preview';

/// Padding (fraction of the side, each side) of every exported asset.
const double iconPadding = 0.19; // full-bleed icon: mark is 62% wide
const double foregroundPadding = 0.29; // adaptive foreground (108 dp canvas)
const double splashPadding = IntroTimeline.logoPadding; // Android 12 (288 dp)

/// iOS / pre-Android 12 / web splash: a 512 px image shown at 128 dp, with
/// the mark exactly as wide as on the Android 12 splash and in the intro.
final double plainPadding =
    (1 - IntroTimeline.logoCanvas * (1 - 2 * IntroTimeline.logoPadding) / 128) /
        2;

Future<Uint8List> _render(CustomPainter painter, int px) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(px.toDouble(), px.toDouble());
  painter.paint(canvas, size);
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _write(
    WidgetTester tester, String path, CustomPainter painter, int px) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    bytes = await _render(painter, px);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  });
  return bytes;
}

/// The icon background gradient alone (adaptive icon background layer).
class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect,
        Paint()..shader = CrownBladeLogo.iconBackground.createShader(rect));
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => false;
}

/// Largest distance (as a fraction of the side) from the centre to any
/// pixel that is not (nearly) transparent.
double _maxRadiusFraction(Uint8List png) {
  final image = img.decodePng(png)!;
  final c = image.width / 2;
  var max = 0.0;
  for (final p in image) {
    if (p.a > 24) {
      final d =
          math.sqrt(math.pow(p.x + 0.5 - c, 2) + math.pow(p.y + 0.5 - c, 2));
      if (d > max) max = d;
    }
  }
  return max / image.width;
}

void main() {
  testWidgets('export brand PNGs', (tester) async {
    // App icon: the white mark on the brand green gradient.
    const full = CrownBladeLogoPainter(
      variant: CrownBladeVariant.onBrand,
      padding: iconPadding,
      background: CrownBladeLogo.iconBackground,
    );
    await _write(tester, '$_outDir/icon-1024.png', full, 1024);
    await _write(tester, 'store/graphics/icon-512.png', full, 512);
    await _write(tester, '$_outDir/icon-background-1024.png',
        const _BackgroundPainter(), 1024);

    final fg = await _write(
        tester,
        '$_outDir/icon-foreground-1024.png',
        const CrownBladeLogoPainter(
            variant: CrownBladeVariant.onBrand, padding: foregroundPadding),
        1024);
    // Adaptive icons: the safe zone is a 66 dp circle in the 108 dp canvas.
    debugPrint(
        'foreground max radius: ${_maxRadiusFraction(fg)} (limit ${33 / 108})');
    expect(_maxRadiusFraction(fg), lessThan(33 / 108));

    final mono = await _write(
        tester,
        '$_outDir/icon-monochrome-1024.png',
        const CrownBladeLogoPainter(
            variant: CrownBladeVariant.monochrome, padding: foregroundPadding),
        1024);
    expect(_maxRadiusFraction(mono), lessThan(33 / 108));

    // Splash screens: the green mark on white, and on near-black in dark
    // mode. Android 12+ (288 dp canvas, masked to a circle 2/3 wide).
    for (final (name, variant) in [
      ('splash-logo-1152', CrownBladeVariant.onLight),
      ('splash-logo-dark-1152', CrownBladeVariant.onDark),
    ]) {
      final splash = await _write(
          tester,
          '$_outDir/$name.png',
          CrownBladeLogoPainter(variant: variant, padding: splashPadding),
          1152);
      debugPrint('$name max radius: ${_maxRadiusFraction(splash)} '
          '(limit ${1 / 3})');
      expect(_maxRadiusFraction(splash), lessThan(1 / 3 - 0.02));
    }

    // iOS, Android < 12 and the web loader: the mark only.
    for (final (name, variant) in [
      ('splash-logo-plain-512', CrownBladeVariant.onLight),
      ('splash-logo-plain-dark-512', CrownBladeVariant.onDark),
    ]) {
      final painter =
          CrownBladeLogoPainter(variant: variant, padding: plainPadding);
      await _write(tester, '$_outDir/$name.png', painter, 512);
    }
    await _write(
        tester,
        'web/icons/logo-mark.png',
        CrownBladeLogoPainter(
            variant: CrownBladeVariant.onLight, padding: plainPadding),
        512);
    await _write(
        tester,
        'web/icons/logo-mark-dark.png',
        CrownBladeLogoPainter(
            variant: CrownBladeVariant.onDark, padding: plainPadding),
        512);

    // Previews (not shipped). The launcher shows the central 72 of the
    // 108 dp adaptive canvas, here masked to a circle.
    await tester.runAsync(() async {
      Future<void> masked(String name, double zoom, double padding,
          CrownBladeVariant variant, Color page,
          {Gradient? background}) async {
        const px = 512;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(px * 1.0, px * 1.0);
        canvas.drawRect(Offset.zero & size, Paint()..color = page);
        canvas.clipPath(Path()..addOval(Offset.zero & size));
        canvas.translate(px / 2, px / 2);
        canvas.scale(zoom);
        canvas.translate(-px / 2, -px / 2);
        CrownBladeLogoPainter(
                variant: variant, padding: padding, background: background)
            .paint(canvas, size);
        final image = await recorder.endRecording().toImage(px, px);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_previewDir/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(data!.buffer.asUint8List());
      }

      await masked('adaptive-masked', 108 / 72, foregroundPadding,
          CrownBladeVariant.onBrand, const Color(0xFFEDEDED),
          background: CrownBladeLogo.iconBackground);
      await masked('android12-splash-masked', 3 / 2, splashPadding,
          CrownBladeVariant.onLight, CrownBladeLogo.splashLight);
      await masked('android12-splash-dark-masked', 3 / 2, splashPadding,
          CrownBladeVariant.onDark, CrownBladeLogo.splashDark);
    });

    await _write(tester, '$_previewDir/icon-48.png', full, 48);
    await _write(tester, '$_previewDir/icon-96.png', full, 96);
    for (final frame in <String, CrownBladeLogoPainter>{
      'glint-050-twinkle-050': const CrownBladeLogoPainter(
          glintProgress: 0.5,
          twinkleProgress: 0.5,
          gemShineProgress: 0.6,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
      'mono-on-green': const CrownBladeLogoPainter(
          variant: CrownBladeVariant.monochrome,
          padding: iconPadding,
          background: CrownBladeLogo.iconBackground),
    }.entries) {
      await _write(tester, '$_previewDir/${frame.key}.png', frame.value, 512);
    }
  });
}
