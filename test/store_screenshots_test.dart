// Google Play phone screenshots (1080 x 1920) of real screens with the
// bundled Addis Ababa demo data. Not part of the normal suite: the
// 'screenshots' tag is skipped by dart_test.yaml. Run it with
//
//   bash store/tool/fetch_screenshot_assets.sh   (once; fonts, photos, map tiles)
//   flutter test --tags screenshots --run-skipped test/store_screenshots_test.dart
//
// (--tags alone is not enough: a tag skipped in dart_test.yaml stays skipped
// until --run-skipped) and look at store/screenshots/*.png. The demo data is
// extended for the screenshots only: barber_1 gets three portfolio photos and
// the owner reports get a month of completed visits. Without the downloaded
// files the test still runs (Roboto from the Flutter SDK, grey photos, an
// empty map background).
@Tags(['screenshots'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/data/seed_dataset.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_main_nav.dart';
import 'package:barbershop_booking/features/portfolio/portfolio_service.dart';
import 'package:barbershop_booking/features/portfolio/screens/portfolio_gallery_screen.dart';
import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import 'test_helpers.dart';

const _outDir = 'store/screenshots';
const _cacheDir = 'build/store_cache';

/// 1080 x 1920 px at a common phone density (411 x 731 logical pixels).
const _physical = Size(1080, 1920);
const _dpr = 2.625;

final _boundary = GlobalKey();

/// How far (logical pixels) some screens are scrolled before the capture.
const double _homeScroll = 850;
const double _bookingScroll = 345;
const double _barberScroll = 1000;
final _repo = AppRepository.instance;

/// Today at 10:00 in Addis Ababa (07:00 UTC), so the seed's "today"
/// bookings match the screens that read the real clock.
DateTime _seedNow() {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day, 7);
}

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

/// The Flutter SDK's bin/cache/artifacts (flutter_tester runs from it).
String? _sdkArtifacts() {
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final i = exe.indexOf('/bin/cache/artifacts/');
  return i < 0 ? null : '${exe.substring(0, i)}/bin/cache/artifacts';
}

Future<void> _loadFamily(String family, List<String> files) async {
  final loader = FontLoader(family);
  var any = false;
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    any = true;
  }
  if (any) await loader.load();
}

/// Inter (the app's Google Font) under the family names google_fonts uses
/// ("Inter_700", ...), or Roboto from the SDK when Inter isn't downloaded,
/// plus Material Icons so icons aren't boxes.
Future<void> _loadFonts() async {
  final sdk = _sdkArtifacts();
  String inter(int w) => '$_cacheDir/fonts/Inter-$w.ttf';
  String roboto(String n) => '$sdk/material_fonts/roboto-$n.ttf';
  final haveInter = File(inter(400)).existsSync();
  String pick(int w) {
    if (haveInter) {
      for (final c in [w, if (w > 400) w - 100, 700, 400]) {
        if (File(inter(c)).existsSync()) return inter(c);
      }
    }
    return roboto(switch (w) { <= 400 => 'regular', 500 || 600 => 'medium', 700 => 'bold', _ => 'black' });
  }

  final weights = {100: 400, 200: 400, 300: 400, 400: 400, 500: 500, 600: 600, 700: 700, 800: 800, 900: 800};
  for (final e in weights.entries) {
    final name = e.key == 400 ? 'regular' : '${e.key}';
    await _loadFamily('Inter_$name', [pick(e.value)]);
    await _loadFamily('Inter_${e.key == 400 ? '' : e.key}italic', [pick(e.value)]);
  }
  // Fallback family of every google_fonts style, and the default family of
  // plain TextStyles.
  final all = [for (final w in [400, 500, 600, 700, 800]) pick(w)];
  await _loadFamily('Inter', all);
  await _loadFamily('Roboto', all);
  if (sdk != null) {
    await _loadFamily('MaterialIcons', ['$sdk/material_fonts/materialicons-regular.otf']);
  }
}

// ---------------------------------------------------------------------------
// Network: photos and map tiles from build/store_cache, a grey pixel otherwise
// ---------------------------------------------------------------------------

// 1x1 light grey PNG.
final _greyPixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, //
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x78, 0xF1, 0xE2, 0x05, //
  0x00, 0x05, 0x74, 0x02, 0xB9, 0xD9, 0xC2, 0xC7, 0x65, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Demo photos swapped for the screenshots: the seed gives Yonas (barber_1,
/// the barber in most screenshots) a portrait that doesn't fit the name.
const _photoSwaps = {'photo-1534528741775-53994a69daeb': 'photo-1506794778202-cad84cf45f1d'};

Uint8List _bytesFor(Uri url) {
  String? path;
  if (url.host == 'images.unsplash.com' && url.pathSegments.isNotEmpty) {
    final id = url.pathSegments.last;
    path = '$_cacheDir/img/${_photoSwaps[id] ?? id}.jpg';
  } else if (url.host == 'tile.openstreetmap.org' && url.pathSegments.length == 3) {
    final s = url.pathSegments;
    path = '$_cacheDir/tiles/${s[0]}_${s[1]}_${s[2]}';
  }
  final file = path == null ? null : File(path);
  if (file != null && file.existsSync()) return file.readAsBytesSync();
  return _greyPixel;
}

class _StoreHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client();
}

class _Client extends Fake implements HttpClient {
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
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request(url);
  @override
  void close({bool force = false}) {}
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.url);
  final Uri url;

  @override
  final HttpHeaders headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _Response(_bytesFor(url));
  @override
  Future<HttpClientResponse> get done => close();
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this._bytes);
  final Uint8List _bytes;

  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => true;
  @override
  HttpHeaders get headers => _Headers();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  String? value(String name) => null;
}

// ---------------------------------------------------------------------------
// Portfolio: the seed has no photos, so give barber_1 three haircut photos
// (the cached demo shop photos, stored inline like on the free plan).
// ---------------------------------------------------------------------------

const _portfolio = {
  'photo-1622286342621-4bd786c2447c': 'Textured crop',
  'photo-1599351431202-1e0f0137899a': 'Skin fade',
  'photo-1503951914875-452162b0f3f1': 'Beard sculpting',
};

Future<void> _seedPortfolio() async {
  PortfolioService.instance = null;
  final local = PortfolioService.instance.local;
  var slot = 1;
  for (final e in _portfolio.entries) {
    final file = File('$_cacheDir/img/${e.key}.jpg');
    if (!file.existsSync()) continue;
    await local.create(PortfolioPhoto(
      id: portfolioSlotId(slot),
      shopId: 'shop_1',
      barberId: 'barber_1',
      caption: e.value,
      image: base64Encode(file.readAsBytesSync()),
      createdAt: DateTime.utc(2026, 11, 1).subtract(Duration(days: slot)),
    ));
    slot++;
  }
}

// ---------------------------------------------------------------------------
// Owner reports: the seed has only a handful of past bookings, so the busy
// hours heatmap gets a month of completed visits at Crown Cuts Bole (busier
// in the evenings and at the weekend, like a real shop).
// ---------------------------------------------------------------------------

void _loadSeedWithHistory() {
  final now = _seedNow();
  final json = jsonDecode(readSeedJson()) as Map<String, dynamic>;
  final bookings = json['bookings'] as List<dynamic>;
  final random = Random(7);
  const barbers = ['barber_1', 'barber_2', 'barber_1_3'];
  const services = ['srv_1_1', 'srv_1_2', 'srv_1_3', 'srv_1_4'];
  const customers = ['user_cust_1', 'user_cust_2', 'user_cust_3', 'user_cust_4'];
  // Bookings per weekday (Mon..Sun) and relative weight of each hour 08..19.
  const perDay = [2, 2, 3, 3, 5, 7, 4];
  const hourWeights = [1, 2, 3, 3, 2, 2, 3, 4, 5, 6, 6, 4];
  final totalWeight = hourWeights.reduce((a, b) => a + b);
  final today = DateTime.utc(now.year, now.month, now.day);
  var n = 0;
  for (var offset = -30; offset <= -1; offset++) {
    final weekday = today.add(Duration(days: offset)).weekday;
    for (var i = 0; i < perDay[weekday - 1]; i++) {
      var pick = random.nextInt(totalWeight);
      var hour = 8;
      while (pick >= hourWeights[hour - 8]) {
        pick -= hourWeights[hour - 8];
        hour++;
      }
      bookings.add({
        'id': 'store_hist_${n++}',
        'shopId': 'shop_1',
        'barberId': barbers[random.nextInt(barbers.length)],
        'customerId': customers[random.nextInt(customers.length)],
        'serviceId': services[random.nextInt(services.length)],
        'dayOffset': offset,
        'startTime': '${hour.toString().padLeft(2, '0')}:${random.nextBool() ? '00' : '30'}',
        'status': 'completed',
        'paymentStatus': 'paid',
        'paymentMethod': 'cash',
        'createdHoursAgo': -offset * 24 + 48,
      });
    }
  }
  _repo.loadSeed(SeedDataset.fromJsonString(jsonEncode(json), now: now));
  _repo.debugClock = () => now;
}

// ---------------------------------------------------------------------------
// Pump and capture
// ---------------------------------------------------------------------------

Widget _app(Widget home) => RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );

/// Lets real async work (image decoding) finish between frames.
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _show(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home));
  await _settle(tester);
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _settle(tester, rounds: 3);
  final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$_outDir/$name.png')
      ..createSync(recursive: true)
      // Play wants 24-bit PNGs (no alpha channel).
      ..writeAsBytesSync(img.encodePng(img.decodePng(data!.buffer.asUint8List())!.convert(numChannels: 3)));
  });
}

Future<void> _scroll(WidgetTester tester, Finder scrollable, double dy) async {
  await tester.drag(scrollable.first, Offset(0, -dy));
  await _settle(tester, rounds: 2);
}

/// google_fonts prints a long note for every font it can't fetch (the fonts
/// are already loaded under its family names). The filter is set and undone
/// inside the test body: flutter_test checks right after the body that
/// debugPrint is back to normal.
void _shot(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    final savedPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.contains('google_fonts')) return;
      if (message != null && message.contains('There is likely something wrong with your test')) return;
      if (message != null && message.contains("If troubleshooting doesn't solve the problem")) return;
      savedPrint(message, wrapWidth: wrapWidth);
    };
    try {
      await body(tester);
    } finally {
      debugPrint = savedPrint;
    }
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_map's tile cache asks path_provider for a folder; give it one
    // under build/ so the cached OpenStreetMap tiles are drawn.
    final mapCache = Directory('build/store_cache/map_cache');
    if (mapCache.existsSync()) mapCache.deleteSync(recursive: true);
    mapCache.createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => mapCache.absolute.path,
    );
    HttpOverrides.global = _StoreHttpOverrides();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  setUp(() async {
    loadTestSeed(now: _seedNow());
    await _seedPortfolio();
  });
  tearDown(() => PortfolioService.instance = null);

  _shot('01 customer home: shops with landmarks', (tester) async {
    _repo.switchRole(UserRole.customer);
    await _show(tester, const CustomerMainNav());
    final notNow = find.text('Not now');
    if (notNow.evaluate().isNotEmpty) {
      await tester.tap(notNow.first);
      await _settle(tester, rounds: 2);
    }
    await _scroll(tester, find.byType(Scrollable), _homeScroll);
    await _capture(tester, '01_customer_home');
  });

  _shot('02 shop page: map, landmark and barbers', (tester) async {
    _repo.switchRole(UserRole.customer);
    final shop = _repo.getShopById('shop_1')!;
    await _show(tester, BarbershopDetailScreen(shop: shop));
    await _scroll(tester, find.byType(Scrollable), 150);
    await _capture(tester, '02_shop_page');
  });

  _shot('03 booking flow: pick a barber and a time', (tester) async {
    _repo.switchRole(UserRole.customer);
    final shop = _repo.getShopById('shop_1')!;
    final service = _repo.getServicesForShop(shop.id).first;
    final barber = _repo.getBarbersForShop(shop.id).first;
    await _show(
      tester,
      BookingFlowScreen(shop: shop, initialService: service, initialBarber: barber, clock: _repo.nowUtc),
    );
    await _scroll(tester, find.byType(Scrollable), _bookingScroll);
    final slot = find.text('11:00 AM');
    if (slot.evaluate().isNotEmpty) {
      await tester.tap(slot.first);
      await _settle(tester, rounds: 2);
    }
    await _capture(tester, '03_booking_flow');
  });

  _shot('04 barber dashboard: today and the walk-in queue', (tester) async {
    _repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
    await _show(tester, const BarberDashboardScreen());
    await _scroll(tester, find.byType(Scrollable), _barberScroll);
    await _capture(tester, '04_barber_dashboard');
  });

  _shot('05 owner reports: revenue and busy hours', (tester) async {
    _loadSeedWithHistory();
    _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    await _show(tester, OwnerReportsScreen(shopId: 'shop_1', now: _repo.nowUtc()));
    await tester.tap(find.text('Busy hours').first);
    await _settle(tester);
    await _capture(tester, '05_owner_reports');
  });

  _shot('06 portfolio: haircut photos of a barber', (tester) async {
    _repo.switchRole(UserRole.customer);
    final barber = _repo.getBarbersForShop('shop_1').firstWhere((b) => b.id == 'barber_1');
    await _show(tester, PortfolioGalleryScreen(shopId: 'shop_1', barber: barber, canBook: true));
    await tester.tap(find.text('Textured crop').first);
    await _settle(tester);
    await _capture(tester, '06_portfolio');
  });
}
