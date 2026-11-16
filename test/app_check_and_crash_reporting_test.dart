import 'package:barbershop_booking/services/app_check_setup.dart';
import 'package:barbershop_booking/services/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

AppCheckDecision _decide({
  bool isWeb = false,
  TargetPlatform platform = TargetPlatform.android,
  bool isDebugBuild = false,
  bool demoMode = false,
  bool isTest = false,
  String recaptchaSiteKey = '',
}) =>
    decideAppCheck(
      isWeb: isWeb,
      platform: platform,
      isDebugBuild: isDebugBuild,
      demoMode: demoMode,
      isTest: isTest,
      recaptchaSiteKey: recaptchaSiteKey,
    );

void main() {
  group('decideAppCheck', () {
    test('Android release uses Play Integrity, debug uses the debug provider', () {
      expect(_decide().provider, AppCheckProviderKind.playIntegrity);
      expect(_decide(isDebugBuild: true).provider, AppCheckProviderKind.debug);
    });

    test('iOS and macOS release use App Attest with DeviceCheck fallback', () {
      for (final p in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(_decide(platform: p).provider, AppCheckProviderKind.appAttestWithDeviceCheckFallback);
        expect(_decide(platform: p, isDebugBuild: true).provider, AppCheckProviderKind.debug);
      }
    });

    test('web uses reCAPTCHA v3 only with a site key', () {
      final withKey = _decide(isWeb: true, recaptchaSiteKey: ' 6LcKey ');
      expect(withKey.provider, AppCheckProviderKind.recaptchaV3);
      expect(withKey.webSiteKey, '6LcKey');

      final noKey = _decide(isWeb: true);
      expect(noKey.activates, isFalse);
      expect(noKey.skipReason, contains('RECAPTCHA_SITE_KEY'));
      expect(_decide(isWeb: true, recaptchaSiteKey: '   ').activates, isFalse);
    });

    test('never activates in demo mode or tests, on any platform', () {
      for (final web in [false, true]) {
        expect(_decide(isWeb: web, demoMode: true, recaptchaSiteKey: 'k').activates, isFalse);
        expect(_decide(isWeb: web, isTest: true, recaptchaSiteKey: 'k').activates, isFalse);
      }
    });

    test('desktop platforms without a provider are skipped', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia]) {
        expect(_decide(platform: p).activates, isFalse);
      }
    });

    test('the test runner is detected', () {
      expect(isRunningUnderFlutterTest, isTrue);
    });

    test('setupAppCheck skips under flutter test without touching Firebase', () async {
      final decision = await setupAppCheck();
      expect(decision.activates, isFalse);
    });
  });

  group('Crashlytics', () {
    test('set up only on mobile production builds', () {
      expect(shouldSetUpCrashlytics(isWeb: false, demoMode: false, isTest: false), isTrue);
      expect(shouldSetUpCrashlytics(isWeb: true, demoMode: false, isTest: false), isFalse);
      expect(shouldSetUpCrashlytics(isWeb: false, demoMode: true, isTest: false), isFalse);
      expect(shouldSetUpCrashlytics(isWeb: false, demoMode: false, isTest: true), isFalse);
    });

    test('collection is off in debug builds', () {
      expect(crashlyticsCollectionEnabled(isDebugBuild: true), isFalse);
      expect(crashlyticsCollectionEnabled(isDebugBuild: false), isTrue);
    });

    test('setupCrashReporting is a no-op under flutter test', () async {
      final before = FlutterError.onError;
      await setupCrashReporting();
      expect(FlutterError.onError, same(before));
    });
  });
}
