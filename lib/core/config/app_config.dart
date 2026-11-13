/// Build-time configuration.
///
/// DEMO_MODE runs the app fully offline with in-memory demo data and one-tap
/// role personas (no real Google sign-in). It must never be enabled for a
/// production build:
///
///   flutter run --dart-define=DEMO_MODE=true
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
