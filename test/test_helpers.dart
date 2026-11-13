import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/google_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the bundled demo dataset straight from disk (tests run from the
/// project root).
String readSeedJson() => File(kSeedAssetPath).readAsStringSync();

SeedDataset loadSeedDataset({DateTime? now}) => SeedDataset.fromJsonString(readSeedJson(), now: now);

/// Resets [AppRepository.instance] to the Addis demo dataset, signed out.
void loadTestSeed({DateTime? now}) {
  AppRepository.instance.loadSeed(loadSeedDataset(now: now));
  // Policy checks (cancellation cutoff, no-show) use the seed's clock.
  AppRepository.instance.debugClock = now == null ? null : () => now;
}

/// Local-mode Google sign-in as [email] (the Google account picker is
/// replaced by a fake that returns this account). [loadTestSeed] restores
/// the default demo account.
Future<void> signInWithGoogleAs(String email, {String? displayName}) {
  final repo = AppRepository.instance;
  repo.googleAuthService = FakeGoogleAuthService(GoogleIdentity(email: email, displayName: displayName));
  return repo.signInWithGoogle();
}

/// Serves a 1x1 GIF for every network image, so widget tests don't hit the
/// network.
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

class _TestHttpClientResponse extends Fake implements HttpClientResponse {
  static final _transparentImage = base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
}

class _TestHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _TestHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
}
