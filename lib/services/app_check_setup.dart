import 'dart:io' show Platform;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// reCAPTCHA v3 site key for App Check on the web build:
///
///   flutter build web --dart-define=RECAPTCHA_SITE_KEY=6Lc...
///
/// Without it the web build skips App Check (and logs that once).
const String kRecaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Which attestation provider App Check uses on this build.
enum AppCheckProviderKind {
  /// Android release/profile builds: Play Integrity (only passes for apps
  /// installed from Google Play; a sideloaded APK gets no valid token).
  playIntegrity,

  /// iOS/macOS release builds: App Attest, falling back to DeviceCheck on
  /// devices without App Attest.
  appAttestWithDeviceCheckFallback,

  /// Debug builds (Android and Apple): the debug provider. The debug token is
  /// printed to the device log and can be registered in the Firebase console.
  debug,

  /// Web: reCAPTCHA v3 with [kRecaptchaSiteKey].
  recaptchaV3,
}

/// What [setupAppCheck] does on this build. Pure data, so it can be tested.
@immutable
class AppCheckDecision {
  const AppCheckDecision.activate(this.provider, {this.webSiteKey}) : skipReason = null;

  const AppCheckDecision.skip(this.skipReason)
      : provider = null,
        webSiteKey = null;

  /// Null when App Check is skipped.
  final AppCheckProviderKind? provider;

  /// The reCAPTCHA v3 site key, only for [AppCheckProviderKind.recaptchaV3].
  final String? webSiteKey;

  /// Why App Check is not activated (null when it is).
  final String? skipReason;

  bool get activates => provider != null;

  @override
  String toString() =>
      activates ? 'AppCheckDecision.activate($provider)' : 'AppCheckDecision.skip($skipReason)';
}

/// Decides whether and how to activate App Check.
///
/// App Check only attaches tokens to Firebase requests. Enforcement is OFF in
/// the console for every service, so a missing or invalid token (sideloaded
/// APK, emulator, web without a site key) never blocks a request; the
/// console's App Check metrics just count it as unverified.
AppCheckDecision decideAppCheck({
  required bool isWeb,
  required TargetPlatform platform,
  required bool isDebugBuild,
  required bool demoMode,
  required bool isTest,
  required String recaptchaSiteKey,
}) {
  if (demoMode) return const AppCheckDecision.skip('demo mode (no Firebase)');
  if (isTest) return const AppCheckDecision.skip('running under flutter test');

  if (isWeb) {
    final key = recaptchaSiteKey.trim();
    if (key.isEmpty) {
      return const AppCheckDecision.skip('web build without RECAPTCHA_SITE_KEY');
    }
    return AppCheckDecision.activate(AppCheckProviderKind.recaptchaV3, webSiteKey: key);
  }

  switch (platform) {
    case TargetPlatform.android:
      return AppCheckDecision.activate(
        isDebugBuild ? AppCheckProviderKind.debug : AppCheckProviderKind.playIntegrity,
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppCheckDecision.activate(
        isDebugBuild ? AppCheckProviderKind.debug : AppCheckProviderKind.appAttestWithDeviceCheckFallback,
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return AppCheckDecision.skip('no App Check provider set up for $platform');
  }
}

/// True under `flutter test` (the test runner sets FLUTTER_TEST).
bool get isRunningUnderFlutterTest {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

bool _loggedSkip = false;

/// Activates App Check for the current build. Call right after
/// `Firebase.initializeApp`. Never throws: a failure only means requests go
/// out without an App Check token, which is fine while enforcement is off.
Future<AppCheckDecision> setupAppCheck() async {
  final decision = decideAppCheck(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    isDebugBuild: kDebugMode,
    demoMode: kDemoMode,
    isTest: isRunningUnderFlutterTest,
    recaptchaSiteKey: kRecaptchaSiteKey,
  );
  final provider = decision.provider;
  if (provider == null) {
    if (!_loggedSkip) {
      _loggedSkip = true;
      debugPrint('App Check skipped: ${decision.skipReason}');
    }
    return decision;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: provider == AppCheckProviderKind.recaptchaV3
          ? ReCaptchaV3Provider(decision.webSiteKey!)
          : null,
      providerAndroid: provider == AppCheckProviderKind.debug
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: provider == AppCheckProviderKind.debug
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    // Refresh tokens in the background before they expire.
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } catch (e) {
    debugPrint('App Check activation failed (requests continue without a token): $e');
  }
  return decision;
}
