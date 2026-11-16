// Light and dark renders of key screens, to check the theme by eye. Not part
// of the normal suite (tag 'screenshots', skipped by dart_test.yaml). Run:
//
//   bash store/tool/fetch_screenshot_assets.sh   (once; Inter + photos; optional)
//   THEME_RENDER_DIR=build/theme_renders \
//     flutter test --tags screenshots --run-skipped test/theme_renders_test.dart
//
// and look at <THEME_RENDER_DIR>/<screen>_<light|dark>.png (default folder
// build/theme_renders). THEME_RENDER_ONLY=home,shop limits the screens.
@Tags(['screenshots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_main_nav.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'test_helpers.dart';

const _cacheDir = 'build/store_cache';
const _physical = Size(1080, 1920);
const _dpr = 2.625;
final _boundary = GlobalKey();
final _repo = AppRepository.instance;

String get _outDir => Platform.environment['THEME_RENDER_DIR'] ?? 'build/theme_renders';

bool _wanted(String name) {
  final only = Platform.environment['THEME_RENDER_ONLY'];
  if (only == null || only.isEmpty) return true;
  return only.split(',').map((s) => s.trim()).contains(name);
}

DateTime _seedNow() {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day, 7);
}

class _MemoryThemeStore implements ThemeModeStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String mode) async => value = mode;
}

// --- fonts (as in store_screenshots_test.dart) -------------------------------

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
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
    any = true;
  }
  if (any) await loader.load();
}

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
  final all = [for (final w in [400, 500, 600, 700, 800]) pick(w)];
  await _loadFamily('Inter', all);
  await _loadFamily('Roboto', all);
  if (sdk != null) {
    await _loadFamily('MaterialIcons', ['$sdk/material_fonts/materialicons-regular.otf']);
  }
}

// --- network: cached photos, a grey pixel otherwise --------------------------

final _greyPixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, //
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x78, 0xF1, 0xE2, 0x05, //
  0x00, 0x05, 0x74, 0x02, 0xB9, 0xD9, 0xC2, 0xC7, 0x65, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Uint8List _bytesFor(Uri url) {
  String? path;
  if (url.host == 'images.unsplash.com' && url.pathSegments.isNotEmpty) {
    path = '$_cacheDir/img/${url.pathSegments.last}.jpg';
  } else if (url.host == 'tile.openstreetmap.org' && url.pathSegments.length == 3) {
    final s = url.pathSegments;
    path = '$_cacheDir/tiles/${s[0]}_${s[1]}_${s[2]}';
  }
  final file = path == null ? null : File(path);
  if (file != null && file.existsSync()) return file.readAsBytesSync();
  return _greyPixel;
}

class _Overrides extends HttpOverrides {
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

// --- pump and capture --------------------------------------------------------

/// Same wiring as BarbershopApp: theme, darkTheme, themeMode, ThemeRebuilder.
Widget _app(Widget home) => RepaintBoundary(
      key: _boundary,
      child: ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.mode,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => ThemeRebuilder(child: child ?? const SizedBox.shrink()),
          home: home,
        ),
      ),
    );

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 300));
  }
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
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _dismissPrompts(WidgetTester tester) async {
  final notNow = find.text('Not now');
  if (notNow.evaluate().isNotEmpty) {
    await tester.tap(notNow.first);
    await _settle(tester, rounds: 2);
  }
}

void _render(String name, Future<Widget> Function() build, {double scroll = 0}) {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('$name ${mode.name}', (tester) async {
      if (!_wanted(name)) return;
      final savedPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && message.contains('google_fonts')) return;
        savedPrint(message, wrapWidth: wrapWidth);
      };
      try {
        ThemeController.instance = ThemeController(store: _MemoryThemeStore(), platformBrightness: Brightness.light);
        await ThemeController.instance.setMode(mode);
        tester.view.physicalSize = _physical;
        tester.view.devicePixelRatio = _dpr;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(await build()));
        await _settle(tester);
        await _dismissPrompts(tester);
        if (scroll > 0) {
          await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
          await _settle(tester, rounds: 2);
        }
        await _capture(tester, '${name}_${mode.name}');
      } finally {
        debugPrint = savedPrint;
        ThemeController.instance = ThemeController(store: _MemoryThemeStore(), platformBrightness: Brightness.light);
      }
    });
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_map's tile cache asks path_provider for a folder.
    final mapCache = Directory('build/theme_renders_map_cache')..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => mapCache.absolute.path,
    );
    HttpOverrides.global = _Overrides();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  setUp(() => loadTestSeed(now: _seedNow()));

  _render('signin', () async {
    _repo.signOut();
    return const AuthScreen();
  });
  _render('home', () async {
    _repo.switchRole(UserRole.customer);
    return const CustomerMainNav();
  });
  _render('home_scrolled', () async {
    _repo.switchRole(UserRole.customer);
    return const CustomerMainNav();
  }, scroll: 850);
  _render('shop', () async {
    _repo.switchRole(UserRole.customer);
    return BarbershopDetailScreen(shop: _repo.getShopById('shop_1')!);
  });
  _render('booking', () async {
    _repo.switchRole(UserRole.customer);
    final shop = _repo.getShopById('shop_1')!;
    return BookingFlowScreen(
      shop: shop,
      initialService: _repo.getServicesForShop(shop.id).first,
      initialBarber: _repo.getBarbersForShop(shop.id).first,
      clock: _repo.nowUtc,
    );
  }, scroll: 345);
  _render('owner', () async {
    _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    return const OwnerDashboardScreen();
  });
  _render('admin', () async {
    _repo.switchRole(UserRole.admin);
    return const AdminDashboardScreen();
  });
  _render('barber', () async {
    _repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
    return const BarberDashboardScreen();
  });

  // The dark-mode button flips a live screen: everything must repaint.
  testWidgets('live toggle repaints the whole tree', (tester) async {
    if (!_wanted('toggle')) return;
    ThemeController.instance = ThemeController(store: _MemoryThemeStore(), platformBrightness: Brightness.light);
    tester.view.physicalSize = _physical;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    _repo.switchRole(UserRole.customer);
    await tester.pumpWidget(_app(const CustomerMainNav()));
    await _settle(tester);
    await _dismissPrompts(tester);
    await ThemeController.instance.toggle();
    await _settle(tester);
    await _capture(tester, 'toggle_light_to_dark');
    ThemeController.instance = ThemeController(store: _MemoryThemeStore(), platformBrightness: Brightness.light);
  });
}
