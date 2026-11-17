import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/reports/screens/owner_reports_screen.dart';
import 'package:barbershop_booking/features/shared/widgets/ui_kit.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_services_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/owner_dashboard_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  final repo = AppRepository.instance;

  setUp(() {
    loadTestSeed();
    repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
  });

  Future<void> pumpOwner(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const OwnerDashboardScreen(), locale: locale));
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('owner bottom bar switches between Home, Barbers, Services and Reports', (tester) async {
    await pumpOwner(tester);
    for (final label in ['Home', 'Barbers', 'Services', 'Reports']) {
      expect(find.descendant(of: find.byType(AppBottomNavBar), matching: find.text(label)), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('owner-summary')), findsOneWidget);

    await tapTab(tester, 'owner-tab-barbers');
    expect(find.byType(ManageBarbersScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('owner-summary')), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    await tapTab(tester, 'owner-tab-services');
    expect(find.byType(ManageServicesScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tapTab(tester, 'owner-tab-reports');
    expect(find.byType(OwnerReportsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tapTab(tester, 'owner-tab-home');
    expect(find.byKey(const ValueKey('owner-summary')), findsOneWidget);
    expect(find.byType(OwnerReportsScreen), findsNothing);
  });

  testWidgets('dashboard shortcut tiles open the matching tab', (tester) async {
    await pumpOwner(tester);
    final services = repo.getServicesForShop('shop_1').length;
    await tester.ensureVisible(find.text('Services ($services)'));
    await tester.tap(find.text('Services ($services)'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageServicesScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tapTab(tester, 'owner-tab-home');
    final barbers = repo.getBarbersForShop('shop_1').length;
    await tester.ensureVisible(find.text('Manage Barbers ($barbers)'));
    await tester.tap(find.text('Manage Barbers ($barbers)'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageBarbersScreen), findsOneWidget);

    await tapTab(tester, 'owner-tab-home');
    await tester.ensureVisible(find.byKey(const ValueKey('open-reports')));
    await tester.tap(find.byKey(const ValueKey('open-reports')));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerReportsScreen), findsOneWidget);
  });

  testWidgets('pushed on their own, tab screens still show a back arrow', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageBarbersScreen(shopId: 'shop_1')),
          ),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('bottom bar labels in Amharic', (tester) async {
    await pumpOwner(tester, locale: const Locale('am'));
    final bar = find.byType(AppBottomNavBar);
    for (final label in ['መነሻ', 'ሰራተኞች', 'አገልግሎቶች', 'ሪፖርቶች']) {
      expect(find.descendant(of: bar, matching: find.text(label)), findsOneWidget);
    }
  });
}
