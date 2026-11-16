import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'app_check_setup.dart' show isRunningUnderFlutterTest;

/// Whether Crashlytics should be set up at all on this build.
///
/// Crashlytics has no web SDK, the demo build has no Firebase, and tests must
/// never report. Debug builds are set up (so the native SDK hears
/// `setCrashlyticsCollectionEnabled(false)`) but see
/// [crashlyticsCollectionEnabled].
bool shouldSetUpCrashlytics({
  required bool isWeb,
  required bool demoMode,
  required bool isTest,
}) =>
    !isWeb && !demoMode && !isTest;

/// Whether reports are actually sent: never from a debug build.
bool crashlyticsCollectionEnabled({required bool isDebugBuild}) => !isDebugBuild;

/// Sends uncaught Flutter and platform errors to Crashlytics (free on the
/// Spark plan). Call after `Firebase.initializeApp` succeeded. Never throws.
///
/// Native collection also defaults to off in AndroidManifest.xml
/// (`firebase_crashlytics_collection_enabled`) and Info.plist
/// (`FirebaseCrashlyticsCollectionEnabled`), so demo and debug builds never
/// report a native crash either; this call turns it on for release builds.
Future<void> setupCrashReporting() async {
  if (!shouldSetUpCrashlytics(isWeb: kIsWeb, demoMode: kDemoMode, isTest: isRunningUnderFlutterTest)) {
    return;
  }
  final enabled = crashlyticsCollectionEnabled(isDebugBuild: kDebugMode);
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(enabled);
    if (!enabled) return; // Debug: keep Flutter's own error output only.

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // recordFlutterError also prints the error (FlutterError.presentError).
      crashlytics.recordFlutterFatalError(details);
      if (previousFlutterOnError != null && previousFlutterOnError != FlutterError.presentError) {
        previousFlutterOnError(details);
      }
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      // Report as handled unless an earlier handler says otherwise.
      return previousPlatformOnError?.call(error, stack) ?? true;
    };
  } catch (e) {
    debugPrint('Crashlytics setup failed: $e');
  }
}
