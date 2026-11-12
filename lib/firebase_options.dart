// PLACEHOLDER: replace this file by running `flutterfire configure`.
//
// That command connects the app to your Firebase project and overwrites this
// file with the real `DefaultFirebaseOptions`. Until then, a production build
// shows a "Firebase not configured" screen, and a demo build
// (--dart-define=DEMO_MODE=true) runs fully offline.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured. Run `flutterfire configure` to generate lib/firebase_options.dart.',
    );
  }
}
