// Barber portfolio screens: the customer's gallery and full-screen viewer
// (swipe, "Book this style with ..."), the shop page section (counts only,
// photos load when a gallery opens), the booking flow link, and the staff
// manage screen (add with a style name, delete, the 12-photo cap).
import 'dart:convert';
import 'dart:typed_data';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/portfolio/portfolio_service.dart';
import 'package:barbershop_booking/features/portfolio/screens/portfolio_gallery_screen.dart';
import 'package:barbershop_booking/features/portfolio/screens/portfolio_manage_screen.dart';
import 'package:barbershop_booking/features/portfolio/widgets/portfolio_entries.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 15, 9, 0);
final String _b64 = base64Encode(Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8))));

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  final repo = AppRepository.instance;
  late LocalPortfolioStore store;
  late PortfolioService service;

  setUp(() {
    loadTestSeed(now: _now);
    store = LocalPortfolioStore();
    service = PortfolioService(repository: repo, local: store);
    PortfolioService.instance = service;
  });

  tearDown(() => PortfolioService.instance = null);

  Barber barber(String id) => repo.getBarberById(id)!;

  Future<void> seed(String barberId, List<String?> captions) async {
    for (var i = 0; i < captions.length; i++) {
      await store.create(PortfolioPhoto(
        id: portfolioSlotId(i + 1),
        shopId: 'shop_1',
        barberId: barberId,
        createdAt: _now.subtract(Duration(hours: i)),
        caption: captions[i],
        image: _b64,
      ));
    }
  }

  testWidgets('gallery grid, swipe in the viewer, and "Book this style" returns to the caller', (tester) async {
    await seed('barber_1', ['Low fade', 'Taper', null]);
    final yonas = barber('barber_1');
    bool? booked;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async =>
                booked = await openPortfolioGallery(context, shopId: 'shop_1', barber: yonas, canBook: true),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text("Yonas Tadesse's work"), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
    expect(find.byKey(const ValueKey('portfolio-tile-p01')), findsOneWidget);
    expect(find.text('Low fade'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('portfolio-tile-p01')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('portfolio-viewer-caption')), findsOneWidget);
    expect(find.text('Low fade'), findsWidgets);

    await tester.drag(find.byKey(const ValueKey('portfolio-viewer-pages')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Taper'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('portfolio-book-style')));
    await tester.pumpAndSettle();
    expect(find.text('Book this style with Yonas Tadesse'), findsNothing);
    expect(find.text('open'), findsOneWidget, reason: 'viewer and gallery closed');
    expect(booked, isTrue);
  });

  testWidgets('viewer without booking (barber not bookable) has no book button; empty gallery', (tester) async {
    await tester.pumpWidget(_app(PortfolioGalleryScreen(shopId: 'shop_1', barber: barber('barber_2'))));
    await tester.pumpAndSettle();
    expect(find.text('No photos yet.'), findsOneWidget);

    await seed('barber_1', ['Low fade']);
    await tester.pumpWidget(_app(PortfolioGalleryScreen(shopId: 'shop_1', barber: barber('barber_1'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-tile-p01')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('portfolio-book-style')), findsNothing);
  });

  testWidgets('shop page section: counts only, one card per barber with photos, gallery on tap', (tester) async {
    await seed('barber_1', ['Low fade', 'Taper']);
    store.listCalls = 0;
    Barber? bookWith;
    await tester.pumpWidget(_app(Scaffold(
      body: ShopPortfolioSection(
        shopId: 'shop_1',
        barbers: repo.getBarbersForShop('shop_1'),
        onBookStyle: (b) => bookWith = b,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('See their work'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-portfolio-barber_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-portfolio-barber_2')), findsNothing);
    expect(find.text('2 photos'), findsOneWidget);
    expect(store.listCalls, 0, reason: 'no photos are fetched for the shop page');

    await tester.tap(find.byKey(const ValueKey('shop-portfolio-barber_1')));
    await tester.pumpAndSettle();
    expect(store.listCalls, 1);
    await tester.tap(find.byKey(const ValueKey('portfolio-tile-p02')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('portfolio-book-style')));
    await tester.pumpAndSettle();
    expect(bookWith?.id, 'barber_1');
  });

  testWidgets('shop page section is hidden while nobody has photos', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: ShopPortfolioSection(shopId: 'shop_1', barbers: repo.getBarbersForShop('shop_1')),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-portfolio-section')), findsNothing);
  });

  testWidgets('booking flow link: shown for a barber with photos, "Book this style" picks them', (tester) async {
    await seed('barber_1', ['Low fade']);
    Barber? picked;
    Widget link(String id) => _app(Scaffold(
          body: BarberPortfolioLink(shopId: 'shop_1', barber: barber(id), onBookStyle: (b) => picked = b),
        ));
    await tester.pumpWidget(link('barber_2'));
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);

    await tester.pumpWidget(link('barber_1'));
    await tester.pumpAndSettle();
    expect(find.text("See Yonas Tadesse's work · 1 photo"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('barber-portfolio-link-barber_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-tile-p01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-book-style')));
    await tester.pumpAndSettle();
    expect(picked?.id, 'barber_1');
  });

  testWidgets('barber adds a photo with a style name, then deletes it', (tester) async {
    repo.signInAsDemoUser('barber1.shop1@example.com');
    var picks = 0;
    await tester.pumpWidget(_app(PortfolioManageScreen(
      shopId: 'shop_1',
      barber: barber('barber_1'),
      picker: ({required bool camera}) async {
        picks++;
        return _b64;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('0 of 12 photos'), findsOneWidget);
    expect(find.textContaining('Portfolio photos are public'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('portfolio-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-pick-gallery')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    await tester.enterText(find.byKey(const ValueKey('portfolio-caption-field')), 'Low fade');
    await tester.tap(find.byKey(const ValueKey('portfolio-caption-save')));
    await tester.pumpAndSettle();
    expect(find.text('Photo added.'), findsOneWidget);
    expect(find.text('1 of 12 photos'), findsOneWidget);
    expect((await store.list('shop_1', 'barber_1')).single.caption, 'Low fade');

    await tester.tap(find.byKey(const ValueKey('portfolio-tile-p01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Photo deleted.'), findsOneWidget);
    expect(find.text('0 of 12 photos'), findsOneWidget);
    expect(await store.list('shop_1', 'barber_1'), isEmpty);
  });

  testWidgets('owner edits a caption; a full portfolio has no add tile', (tester) async {
    await seed('barber_2', List.filled(kMaxPortfolioPhotos, null));
    repo.signInAsDemoUser('owner.shop1@example.com');
    await tester.pumpWidget(_app(PortfolioManageScreen(shopId: 'shop_1', barber: barber('barber_2'))));
    await tester.pumpAndSettle();
    expect(find.text('12 of 12 photos'), findsOneWidget);
    expect(find.byKey(const ValueKey('portfolio-full')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('portfolio-tile-p12')), 300);
    await tester.ensureVisible(find.byKey(const ValueKey('portfolio-tile-p12')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('portfolio-add')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('portfolio-tile-p12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-action-caption')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('portfolio-caption-field')), 'Afro');
    await tester.tap(find.byKey(const ValueKey('portfolio-caption-save')));
    await tester.pumpAndSettle();
    expect(find.text('Style name saved.'), findsOneWidget);
    expect((await store.list('shop_1', 'barber_2')).firstWhere((p) => p.id == 'p12').caption, 'Afro');
  });

  testWidgets('a customer opening the manage screen cannot add (Amharic message)', (tester) async {
    repo.signInAsDemoUser('liya@example.com');
    await tester.pumpWidget(_app(
      PortfolioManageScreen(shopId: 'shop_1', barber: barber('barber_1'), picker: ({required bool camera}) async => _b64),
      locale: const Locale('am'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-pick-camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('portfolio-caption-save')));
    await tester.pumpAndSettle();
    expect(find.text('ይህን የሥራ ማሳያ መቀየር የሚችሉት ፀጉር አስተካካዩ እና የቤቱ ባለቤት ብቻ ናቸው።'), findsOneWidget);
    expect(await store.list('shop_1', 'barber_1'), isEmpty);
  });
}
