// Light and dark renders of the owner / barber / reports / payouts / refunds
// screens, to check the theme by eye. Tag 'screenshots' (skipped normally). Run:
//
//   THEME_RENDER_DIR=build/theme_renders/owner-barber \
//     flutter test --tags screenshots --run-skipped test/owner_barber_theme_renders_test.dart
//
// THEME_RENDER_ONLY=owner,payouts limits the screens.
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
import 'package:barbershop_booking/features/barber/screens/barber_schedule_screen.dart';
import 'package:barbershop_booking/features/payouts/payouts_screen.dart';
import 'package:barbershop_booking/features/refunds/refunds_screen.dart';
import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/customize_shop_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_services_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_subscription_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
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

String get _outDir => Platform.environment['THEME_RENDER_DIR'] ?? 'build/theme_renders/owner-barber';

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


/// The demo seed plus 30 days of paid history and a few no-shows (reports).
void _loadSeedWithHistory() {
  final now = _seedNow();
  final json = jsonDecode(readSeedJson()) as Map<String, dynamic>;
  final bookings = json['bookings'] as List<dynamic>;
  final random = Random(7);
  const barbers = ['barber_1', 'barber_2', 'barber_1_3'];
  const services = ['srv_1_1', 'srv_1_2', 'srv_1_3', 'srv_1_4'];
  const customers = ['user_cust_1', 'user_cust_2', 'user_cust_3', 'user_cust_4'];
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
      final noShow = random.nextInt(9) == 0;
      final minute = random.nextBool() ? '00' : '30';
      bookings.add({
        'id': 'render_hist_${n++}',
        'shopId': 'shop_1',
        'barberId': barbers[random.nextInt(barbers.length)],
        'customerId': customers[random.nextInt(customers.length)],
        'serviceId': services[random.nextInt(services.length)],
        'dayOffset': offset,
        'startTime': '${hour.toString().padLeft(2, '0')}:$minute',
        'status': noShow ? 'noShow' : 'completed',
        'paymentStatus': noShow ? 'unpaid' : 'paid',
        'paymentMethod': 'cash',
        'createdHoursAgo': -offset * 24 + 48,
      });
    }
  }
  // Prepaid upcoming bookings (the refunds render cancels them).
  for (var i = 0; i < 2; i++) {
    bookings.add({
      'id': 'render_prepaid_$i',
      'shopId': 'shop_1',
      'barberId': 'barber_1',
      'customerId': customers[i + 1],
      'serviceId': services[i],
      'dayOffset': 2 + i,
      'startTime': i == 0 ? '10:00' : '15:30',
      'status': 'confirmed',
      'paymentStatus': 'paid',
      'paymentMethod': 'chapa',
      'createdHoursAgo': 20,
    });
  }
  _repo.loadSeed(SeedDataset.fromJsonString(jsonEncode(json), now: now));
  _repo.debugClock = () => now;
}

void _render(String name, Future<Widget> Function() build,
    {double scroll = 0, Future<void> Function(WidgetTester tester)? after}) {
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
        if (after != null) {
          await after(tester);
          await _settle(tester, rounds: 3);
        }
        if (scroll > 0) {
          // The tallest vertical scrollable on screen (not a multi-line field).
          final vertical = find
              .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
              .hitTestable()
              .evaluate()
              .toList()
            ..sort((a, b) => b.size!.height.compareTo(a.size!.height));
          // Drag in the side gutter so no text field takes the gesture.
          final box = tester.getRect(find.byElementPredicate((e) => e == vertical.first));
          await tester.dragFrom(Offset(box.left + 6, box.center.dy), Offset(0, -scroll));
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

Future<void> Function(WidgetTester) _tab(String key) => (tester) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
    };

Future<void> Function(WidgetTester) _tap(String key) => (tester) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
    };

Future<Widget> _owner(Widget Function() build) async {
  _loadSeedWithHistory();
  _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
  return build();
}

Future<Widget> _barber(Widget Function() build) async {
  _loadSeedWithHistory();
  _repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
  return build();
}

Widget _reports() => OwnerReportsScreen(shopId: 'shop_1', now: _repo.nowUtc());

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  _render('owner', () => _owner(() => const OwnerDashboardScreen()));
  _render('owner_links', () => _owner(() => const OwnerDashboardScreen()), scroll: 480);
  _render('owner_mid', () => _owner(() => const OwnerDashboardScreen()), scroll: 900);
  _render('owner_end', () => _owner(() => const OwnerDashboardScreen()), scroll: 2200);
  _render('barbers', () => _owner(() => const ManageBarbersScreen(shopId: 'shop_1')));
  _render('barbers_hours', () => _owner(() => const ManageBarbersScreen(shopId: 'shop_1')),
      after: _tap('edit-hours-barber_1'));
  _render('barbers_add', () => _owner(() => const ManageBarbersScreen(shopId: 'shop_1')),
      after: (tester) async => tester.tap(find.byType(FloatingActionButton)));
  _render('services', () => _owner(() => const ManageServicesScreen(shopId: 'shop_1')));
  _render('customize', () => _owner(() => CustomizeShopScreen(shop: _repo.getShopById('shop_1')!)));
  _render('customize_end', () => _owner(() => CustomizeShopScreen(shop: _repo.getShopById('shop_1')!)),
      scroll: 1200);
  _render('subscription', () => _owner(() => const OwnerSubscriptionScreen(shopId: 'shop_1')));
  _render('reports', () => _owner(_reports));
  _render('reports_busy', () => _owner(_reports), after: _tab('reports-tab-busy-hours'));
  _render('reports_busy_end', () => _owner(_reports), after: _tab('reports-tab-busy-hours'), scroll: 700);
  _render('reports_clients', () => _owner(_reports), after: _tab('reports-tab-clients'));
  _render('reports_noshows', () => _owner(_reports), after: _tab('reports-tab-noshows'));
  _render('reports_totals', () => _owner(_reports), after: _tab('reports-tab-totals'));
  _render('payouts', () => _owner(() => const PayoutsScreen(shopId: 'shop_1')));
  _render('payouts_record', () => _owner(() => const PayoutsScreen(shopId: 'shop_1')),
      after: _tap('payout-record-barber_1'));
  _render('payouts_end', () => _owner(() => const PayoutsScreen(shopId: 'shop_1')), scroll: 900);
  _render('refunds', () async {
    _loadSeedWithHistory();
    _repo.switchRole(UserRole.barber, targetBarberId: 'barber_1');
    final now = _repo.nowUtc();
    final paid = _repo
        .getShopBookings('shop_1')
        .where((b) =>
            b.barberId == 'barber_1' &&
            b.status == BookingStatus.confirmed &&
            b.paymentStatus == PaymentStatus.paid &&
            b.startAt.isAfter(now))
        .toList();
    for (final b in paid) {
      try {
        await _repo.cancelBookingAsBarber(b.id, reason: 'Sick');
      } catch (_) {}
    }
    _repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    return const RefundsScreen(shopId: 'shop_1');
  });
  _render('barber', () => _barber(() => const BarberDashboardScreen()));
  _render('barber_mid', () => _barber(() => const BarberDashboardScreen()), scroll: 900);
  _render('barber_end', () => _barber(() => const BarberDashboardScreen()), scroll: 2200);
  _render('schedule', () => _barber(() => BarberScheduleScreen(barber: _repo.getBarberById('barber_1')!, clock: _repo.nowUtc)));
}
