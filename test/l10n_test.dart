import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/core/utils/phone_utils.dart';
import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/admin/screens/admin_register_shop_screen.dart';
import 'package:barbershop_booking/features/admin/screens/admin_subscriptions_screen.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/barber/screens/barber_schedule_screen.dart';
import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_main_nav.dart';
import 'package:barbershop_booking/features/shop_owner/screens/customize_shop_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_services_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_subscription_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/features/shared/widgets/language_toggle.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

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

  group('ARB files', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

    test('Amharic has every English message and nothing else', () {
      final en = read('app_en.arb').keys.where((k) => !k.startsWith('@')).toSet();
      final am = read('app_am.arb').keys.where((k) => !k.startsWith('@')).toSet();
      expect(am.difference(en), isEmpty);
      expect(en.difference(am), isEmpty);
    });

    test('no dollar prices in any message', () {
      for (final file in ['app_en.arb', 'app_am.arb']) {
        for (final value in read(file).values.whereType<String>()) {
          expect(value.contains(r'$'), isFalse, reason: '$file: $value');
        }
      }
    });
  });

  group('formatting', () {
    test('Birr amounts', () {
      expect(formatBirr(450, locale: 'en'), 'ETB 450');
      expect(formatBirr(1200, locale: 'en'), 'ETB 1,200');
      expect(formatBirr(1200, locale: 'am'), '1,200 ብር');
      expect(formatBirr(99.5, locale: 'am'), '99.50 ብር');
      expect(AppFormats('am_ET').birr(150), '150 ብር');
    });

    test('times: English keeps the slot format, Amharic uses intl am', () {
      expect(AppFormats('en').time(14, 30), '02:30 PM');
      expect(AppFormats('en').hoursRange(9, 20), '09:00 AM - 08:00 PM');
      final am = AppFormats('am').time(14, 30);
      expect(am, contains('2:30'));
      expect(am, isNot(contains('PM')));
    });

    test('dates use Addis wall-clock time and the active locale', () {
      // 22:30 UTC on Nov 19 is 01:30 on Nov 20 in Addis Ababa.
      final instant = DateTime.utc(2026, 11, 19, 22, 30);
      expect(AppFormats('en').addisDateMedium(instant), 'Nov 20, 2026');
      expect(AppFormats('en').addisTime(instant), '01:30 AM');
      expect(AppFormats('am').addisDateMedium(instant), contains('2026'));
      expect(AppFormats('am').addisDateMedium(instant), isNot(contains('Nov')));
      expect(AppFormats('en').weekdayName(1), 'Mon');
      expect(AppFormats('am').weekdayName(1), isNot('Mon'));
    });

    test('contact phones accept mobiles and Addis fixed lines', () {
      expect(normalizeEthiopianContactPhone('0911 22 33 44'), '+251911223344');
      expect(normalizeEthiopianContactPhone('011 551 2345'), '+251115512345');
      expect(normalizeEthiopianContactPhone('+1 212-555-7800'), isNull);
      expect(formatEthiopianContactPhone('0115512345'), '+251 11 551 2345');
    });
  });

  group('labels', () {
    test('place names and statuses translate in Amharic only', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final am = lookupAppLocalizations(const Locale('am'));
      expect(en.placeName('Bole'), 'Bole');
      expect(am.placeName('Bole'), 'ቦሌ');
      expect(am.placeName('Unknown Place'), 'Unknown Place');
      expect(en.roleName(UserRole.barber), 'Barber');
      expect(am.roleName(UserRole.barber), 'ፀጉር አስተካካይ');
      expect(am.planUpToBarbers(5), contains('5'));
    });
  });

  group('LocaleController', () {
    final repo = AppRepository.instance;
    setUp(() => loadTestSeed(now: _now));

    test('follows the device language, defaulting to English', () {
      expect(LocaleController(repository: repo, deviceLocale: const Locale('am', 'ET')).languageCode, 'am');
      expect(LocaleController(repository: repo, deviceLocale: const Locale('fr')).languageCode, 'en');
      expect(LocaleController(repository: repo, deviceLocale: const Locale('en', 'US')).languageCode, 'en');
    });

    test("adopts the signed-in user's saved language", () {
      final ctrl = LocaleController(repository: repo, deviceLocale: const Locale('en'))..start();
      addTearDown(ctrl.dispose);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1'); // owner_1 has language 'am'
      expect(repo.currentUser!.language, 'am');
      expect(ctrl.languageCode, 'am');
      expect(Intl.defaultLocale, 'am');
    });

    test('the switch saves the choice to the user profile', () async {
      final ctrl = LocaleController(repository: repo, deviceLocale: const Locale('en'))..start();
      addTearDown(ctrl.dispose);
      repo.switchRole(UserRole.customer); // user_cust_1 has language 'en'
      expect(ctrl.languageCode, 'en');
      await ctrl.setLanguage('am');
      expect(ctrl.languageCode, 'am');
      expect(repo.currentUser!.language, 'am');
      await ctrl.toggle();
      expect(repo.currentUser!.language, 'en');
      expect(() => ctrl.setLanguage('fr'), throwsArgumentError);
    });
  });

  group('widgets', () {
    setUp(() => loadTestSeed(now: _now));

    testWidgets('sign-in screen in Amharic', (tester) async {
      await tester.pumpWidget(_app(const AuthScreen(), locale: const Locale('am')));
      expect(find.text('ኮድ ላክ'), findsOneWidget);
      expect(find.text('Send Code'), findsNothing);
      expect(find.byType(LanguageToggle), findsOneWidget);
    });

    testWidgets('the EN / አማ switch changes the language', (tester) async {
      final ctrl = LocaleController(repository: AppRepository.instance, deviceLocale: const Locale('en'));
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(ListenableBuilder(
        listenable: ctrl,
        builder: (_, __) => _app(
          Scaffold(
            appBar: AppBar(actions: [LanguageToggle(controller: ctrl)]),
            body: Builder(builder: (context) => Text(context.l10n.sendCode)),
          ),
          locale: ctrl.locale,
        ),
      ));
      expect(find.text('Send Code'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-toggle')));
      await tester.pumpAndSettle();
      expect(ctrl.languageCode, 'am');
      expect(find.text('ኮድ ላክ'), findsOneWidget);
    });

    testWidgets('customer appointments show Birr and Amharic labels', (tester) async {
      AppRepository.instance.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(const CustomerBookingsScreen(), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('የእኔ ቀጠሮዎች'), findsOneWidget);
      expect(find.textContaining('ብር'), findsWidgets);
      expect(find.textContaining('ETB'), findsNothing);
    });
  });

  group('every screen renders in Amharic', () {
    final repo = AppRepository.instance;
    setUp(() => loadTestSeed(now: _now));

    Future<void> pumpAm(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(screen, locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ETB'), findsNothing);
    }

    testWidgets('admin', (tester) async {
      repo.switchRole(UserRole.admin);
      await pumpAm(tester, const AdminDashboardScreen());
      expect(find.text('የመድረክ ሲስተም አስተዳደር'), findsOneWidget);
      await pumpAm(tester, const AdminRegisterShopScreen());
      await pumpAm(tester, AdminSubscriptionsScreen(clock: () => _now));
    });

    testWidgets('owner', (tester) async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final shop = repo.getShopById('shop_1')!;
      await pumpAm(tester, const OwnerDashboardScreen());
      expect(find.textContaining('ብር'), findsWidgets);
      await pumpAm(tester, CustomizeShopScreen(shop: shop));
      await pumpAm(tester, const ManageServicesScreen(shopId: 'shop_1'));
      await pumpAm(tester, const ManageBarbersScreen(shopId: 'shop_1'));
      await pumpAm(tester, OwnerSubscriptionScreen(shopId: 'shop_1', clock: () => _now));
    });

    testWidgets('barber', (tester) async {
      repo.switchRole(UserRole.barber);
      await pumpAm(tester, const BarberDashboardScreen());
      await pumpAm(tester, BarberScheduleScreen(barber: repo.getBarberForCurrentUser()!, clock: () => _now));
    });

    testWidgets('customer', (tester) async {
      repo.switchRole(UserRole.customer);
      await pumpAm(tester, const CustomerMainNav());
      expect(find.text('ፀጉር ቤቶች'), findsWidgets);
      final shop = repo.getShopById('shop_1')!;
      await pumpAm(tester, BarbershopDetailScreen(shop: shop));
      await pumpAm(
        tester,
        BookingFlowScreen(
          shop: shop,
          initialService: repo.getServicesForShop('shop_1').first,
          initialBarber: repo.getBarbersForShop('shop_1').first,
          clock: () => _now,
        ),
      );
      expect(find.text('ጠዋት'), findsOneWidget);
    });
  });
}
