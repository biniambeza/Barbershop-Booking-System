/// Build-time configuration.
///
/// DEMO_MODE runs the app fully offline with in-memory demo data, one-tap role
/// personas and a fixed OTP code. It must never be enabled for a production
/// build:
///
///   flutter run --dart-define=DEMO_MODE=true
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

/// The OTP code accepted in demo mode (no SMS is sent).
const String kDemoOtpCode = '123456';
