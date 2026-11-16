import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/customer/screens/customer_home_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'test_helpers.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _am = lookupAppLocalizations(const Locale('am'));

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => Intl.defaultLocale = null);

  setUp(() {
    loadTestSeed(now: DateTime.utc(2026, 11, 20, 7, 0));
    AppRepository.instance.switchRole(UserRole.customer);
  });

  /// A 360 px wide phone ([width] logical pixels).
  void usePhone(WidgetTester tester, {double width = 360}) {
    tester.view.physicalSize = Size(width * 3, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  int shopsIn(String subCity) => AppRepository.instance.getShops().where((s) => s.subCity == subCity).length;

  final dropdown = find.byKey(const ValueKey('subcity-filter'));

  /// Shop cards named [name] in the shop list (the "Your barbers" row above
  /// it names the shops of the customer's barbers too, whatever the filter).
  Finder listed(String name) => find.byWidgetPredicate((w) =>
      w is Text &&
      w.data == name &&
      find.descendant(of: find.byKey(const ValueKey('your-barbers')), matching: find.byWidget(w)).evaluate().isEmpty);

  Future<void> openMenu(WidgetTester tester) async {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
  }

  /// The entry for [city] in the open menu (the whole list fits on screen).
  Finder option(String city) =>
      find.descendant(of: find.byKey(ValueKey('subcity-option-$city')), matching: find.byType(Text)).last;

  Future<void> choose(WidgetTester tester, String city) async {
    await openMenu(tester);
    await tester.tap(option(city));
    await tester.pumpAndSettle();
  }

  testWidgets('choosing Bole from the sub-city dropdown filters the shops; All restores them', (tester) async {
    usePhone(tester);
    final shopCount = AppRepository.instance.getShops().length;
    await tester.pumpWidget(_app(const CustomerHomeScreen()));
    await tester.pumpAndSettle();

    // A dropdown (not chips) showing "All sub-cities".
    expect(dropdown, findsOneWidget);
    expect(find.text(_en.allSubCities), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text(_en.featuredBarbershops(shopCount)), findsOneWidget);

    // All 11 sub-cities are listed, with their shop counts.
    await openMenu(tester);
    expect(find.text(_en.subCityOptionCount('Addis Ketema', 0)).last, findsOneWidget);
    expect(find.text(_en.subCityOptionCount('Bole', 1)).last, findsOneWidget);
    expect(find.text(_en.subCityOptionCount('Yeka', shopsIn('Yeka'))).last, findsOneWidget);
    await tester.tap(option('Bole'));
    await tester.pumpAndSettle();

    expect(find.text(_en.featuredBarbershops(1)), findsOneWidget);
    expect(listed('Crown Cuts Bole'), findsOneWidget);
    expect(listed('Kazanchis Classic Barbers'), findsNothing);
    expect(find.text('Bole'), findsWidgets); // shown in the closed dropdown

    await choose(tester, 'All');
    expect(find.text(_en.featuredBarbershops(shopCount)), findsOneWidget);
    expect(find.text(_en.allSubCities), findsOneWidget);
  });

  testWidgets('search text combines with the sub-city', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(_app(const CustomerHomeScreen()));
    await tester.pumpAndSettle();

    await choose(tester, 'Kirkos');
    expect(find.text(_en.featuredBarbershops(1)), findsOneWidget);
    expect(listed('Kazanchis Classic Barbers'), findsOneWidget);

    // A shop from another sub-city: no match while Kirkos is chosen.
    await tester.enterText(find.byType(TextField).first, 'Crown Cuts');
    await tester.pumpAndSettle();
    expect(find.text(_en.featuredBarbershops(0)), findsOneWidget);

    await choose(tester, 'All');
    expect(find.text(_en.featuredBarbershops(1)), findsOneWidget);
    expect(listed('Crown Cuts Bole'), findsOneWidget);
  });

  testWidgets('sub-city names are in Amharic', (tester) async {
    // Wider: the shop cards' Amharic counts are wider than 360 px in the test font.
    usePhone(tester, width: 400);
    await tester.pumpWidget(_app(const CustomerHomeScreen(), locale: const Locale('am')));
    await tester.pumpAndSettle();
    expect(find.text(_am.allSubCities), findsOneWidget);

    await openMenu(tester);
    expect(find.text(_am.subCityOptionCount('ቦሌ', 1)).last, findsOneWidget);
    await tester.tap(option('Bole'));
    await tester.pumpAndSettle();
    expect(find.text(_am.featuredBarbershops(1)), findsOneWidget);
  });
}
