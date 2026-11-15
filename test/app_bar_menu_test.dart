import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/shared/widgets/app_bar_menu.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 20, 7, 0);

class _MemoryLanguageStore implements LanguageStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String code) async => value = code;
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  setUp(() {
    loadTestSeed(now: _now);
    AppRepository.instance.switchRole(UserRole.admin);
  });

  testWidgets('app-bar menu holds language, extra entries and sign out', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_app(Scaffold(
      appBar: AppBar(actions: [
        AppBarMenu(
          role: UserRole.admin,
          entries: [
            AppBarMenuEntry(
              key: const ValueKey('extra'),
              icon: Icons.star,
              label: 'Extra',
              onSelected: () => opened++,
            ),
          ],
        ),
      ]),
    )));

    await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Change language'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Extra'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('extra')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('the language entry toggles the app language', (tester) async {
    // In-memory store: shared_preferences has no platform channel in tests.
    final previous = LocaleController.instance;
    final ctrl = LocaleController(
        repository: AppRepository.instance, deviceLocale: const Locale('en'), store: _MemoryLanguageStore());
    LocaleController.instance = ctrl;
    addTearDown(() {
      LocaleController.instance = previous;
      ctrl.dispose();
    });
    final before = ctrl.languageCode;
    await tester.pumpWidget(_app(Scaffold(
      appBar: AppBar(actions: const [AppBarMenu(role: UserRole.admin)]),
    )));

    await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-bar-menu-language')));
    await tester.pumpAndSettle();
    expect(ctrl.languageCode, isNot(before));
  });

  testWidgets('sign out from the menu', (tester) async {
    final repo = AppRepository.instance;
    expect(repo.currentUser, isNotNull);
    await tester.pumpWidget(_app(Scaffold(
      appBar: AppBar(actions: const [AppBarMenu(role: UserRole.admin)]),
    )));

    await tester.tap(find.byKey(const ValueKey('app-bar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-bar-menu-signout')));
    await tester.pumpAndSettle();
    expect(repo.currentUser, isNull);
  });
}
