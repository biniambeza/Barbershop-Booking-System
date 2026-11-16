import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/admin/screens/admin_dashboard_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/admin_pricing_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/receipt_payment_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/receivers_setup.dart';
import 'package:barbershop_booking/features/payments/receipts/subscription_receipts_service.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 15, 9, 0);
const _admin = 'admin@example.com';
const _owner1 = 'owner.shop1@example.com'; // shop_1

const _telebirrOnly = PaymentReceiver(account: '+251911223344', name: 'Crown & Blade PLC');
const _cbeReal = PaymentReceiver(account: '1000123456789', name: 'Crown & Blade PLC');

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// Scrolls the pricing screen to its save button and taps it.
Future<void> _tapPricingSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('pricing-save'));
  await tester.scrollUntilVisible(save, 300,
      scrollable: find.descendant(of: find.byType(AdminPricingScreen), matching: find.byType(Scrollable)).first);
  // ensureVisible's jump lays out on the next frame: pump before tapping.
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());

  group('receiver validation (pure)', () {
    test('telebirr: Ethiopian mobile numbers only, never the XXXX sample', () {
      expect(normalizeTelebirrReceiver('0911 223344'), '+251911223344');
      expect(normalizeTelebirrReceiver('+251 91 122 3344'), '+251911223344');
      expect(normalizeTelebirrReceiver('251711223344'), '+251711223344');
      expect(normalizeTelebirrReceiver('+2519XXXXXXXX'), isNull);
      expect(normalizeTelebirrReceiver('0111551234'), isNull, reason: 'landline');
      expect(normalizeTelebirrReceiver('12345'), isNull);
    });

    test('CBE: 13 digits starting with 1000', () {
      expect(normalizeCbeReceiverAccount('1000123456789'), '1000123456789');
      expect(normalizeCbeReceiverAccount(' 1000 1234-56789 '), '1000123456789');
      expect(normalizeCbeReceiverAccount('1000XXXXXXXXX'), isNull);
      expect(normalizeCbeReceiverAccount('2000123456789'), isNull);
      expect(normalizeCbeReceiverAccount('100012345678'), isNull, reason: '12 digits');
      expect(normalizeCbeReceiverAccount('10001234567890'), isNull, reason: '14 digits');
    });

    test('checkReceiver: empty is allowed, placeholders and bad values are not', () {
      final empty = checkReceiver(ReceiptMethod.telebirr, account: '  ', name: '');
      expect(empty.ok, isTrue);
      expect(empty.receiver!.account, '');

      final sample = checkReceiver(ReceiptMethod.telebirr, account: '+2519XXXXXXXX', name: 'Crown');
      expect((sample.ok, sample.account), (false, ReceiverIssue.placeholder));
      final cbeSample = checkReceiver(ReceiptMethod.cbe, account: '1000xxxxxxxxx', name: 'Crown');
      expect(cbeSample.account, ReceiverIssue.placeholder);

      final bad = checkReceiver(ReceiptMethod.cbe, account: '12345', name: 'C');
      expect((bad.account, bad.name), (ReceiverIssue.invalidAccount, ReceiverIssue.nameTooShort));
      expect(bad.receiver, isNull);

      final long = checkReceiver(ReceiptMethod.telebirr, account: '0911223344', name: 'x' * 81);
      expect(long.name, ReceiverIssue.nameTooLong);

      final good = checkReceiver(ReceiptMethod.telebirr, account: '0911 223344', name: '  Crown & Blade  ');
      expect(good.ok, isTrue);
      expect(good.receiver!.account, '+251911223344');
      expect(good.receiver!.name, 'Crown & Blade');
      expect(checkReceiver(ReceiptMethod.cbe, account: '1000123456789', name: 'Ab').ok, isTrue);
    });

    test('normalizePricingReceivers blanks the sample and rejects bad accounts', () {
      final blank = normalizePricingReceivers(SubscriptionPricing.defaults)!;
      expect((blank.telebirr.account, blank.cbe.account), ('', ''));
      expect(blank.telebirr.name, 'Crown & Blade');
      expect(blank.hasReadyReceiver, isFalse);

      final bad = SubscriptionPricing.defaults.copyWith(cbe: const PaymentReceiver(account: '999', name: 'Crown'));
      expect(normalizePricingReceivers(bad), isNull);

      final ok = normalizePricingReceivers(SubscriptionPricing.defaults
          .copyWith(telebirr: const PaymentReceiver(account: '0911223344', name: 'Crown')))!;
      expect(ok.telebirr.account, '+251911223344');
      expect(ok.cbe.account, '');
    });

    test('payableMethods: only set-up receivers, plus "other" once one is', () {
      expect(SubscriptionPricing.defaults.payableMethods, isEmpty);
      expect(SubscriptionPricing.defaults.hasReadyReceiver, isFalse);
      final telebirr = SubscriptionPricing.defaults.copyWith(telebirr: _telebirrOnly);
      expect(telebirr.payableMethods, [ReceiptMethod.telebirr, ReceiptMethod.other]);
      expect(telebirr.canPayWith(ReceiptMethod.cbe), isFalse);
      final cbe = SubscriptionPricing.defaults.copyWith(cbe: _cbeReal);
      expect(cbe.payableMethods, [ReceiptMethod.cbe, ReceiptMethod.other]);
      final both = telebirr.copyWith(cbe: _cbeReal);
      expect(both.payableMethods, ReceiptMethod.values);
      // A saved empty account stays "not set up" after a round trip.
      final back = SubscriptionPricing.fromMap(normalizePricingReceivers(SubscriptionPricing.defaults)!.toMap());
      expect(back.hasReadyReceiver, isFalse);
      expect(back.telebirr.account, '');
    });
  });

  group('service + screens', () {
    final repo = AppRepository.instance;
    late SubscriptionReceiptsService service;

    setUp(() {
      loadTestSeed(now: _now);
      service = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (_, __) {},
      );
      SubscriptionReceiptsService.instance = service;
    });

    tearDown(() => SubscriptionReceiptsService.instance = null);

    test('savePricing stores normalized receivers and never the XXXX sample', () async {
      repo.signInAsDemoUser(_admin);
      final blank = await service.savePricing(SubscriptionPricing.defaults);
      expect((blank.telebirr.account, blank.cbe.account), ('', ''));
      final saved = await service.savePricing(SubscriptionPricing.defaults.copyWith(
        telebirr: const PaymentReceiver(account: '0911 223344', name: 'Crown'),
        cbe: const PaymentReceiver(account: '1000 1234 56789', name: 'Crown'),
      ));
      expect((saved.telebirr.account, saved.cbe.account), ('+251911223344', '1000123456789'));
      expect((await service.loadPricing()).payableMethods, ReceiptMethod.values);
      await expectLater(
        service.savePricing(SubscriptionPricing.defaults
            .copyWith(telebirr: const PaymentReceiver(account: '0111551234', name: 'Crown'))),
        throwsA(isA<ReceiptException>().having((e) => e.code, 'code', ReceiptErrorCode.invalidPricing)),
      );
      await expectLater(
        service.savePricing(SubscriptionPricing.defaults
            .copyWith(cbe: const PaymentReceiver(account: '1000123456789', name: 'C'))),
        throwsA(isA<ReceiptException>().having((e) => e.code, 'code', ReceiptErrorCode.invalidPricing)),
      );
    });

    testWidgets('admin dashboard: setup card and red dot until a receiver is saved', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(const AdminDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receivers-setup-card')), findsOneWidget);
      expect(find.text('Set up where shop owners pay you'), findsOneWidget);
      expect(find.byKey(const ValueKey('receivers-setup-dot')), findsOneWidget);

      // Shown above every tab.
      await tester.tap(find.byKey(const ValueKey('admin-tab-payments')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receivers-setup-card')), findsOneWidget);

      // The button opens the pricing screen; the sample shows as empty.
      await tester.tap(find.byKey(const ValueKey('receivers-setup-open')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPricingScreen), findsOneWidget);
      final number = find.byKey(const ValueKey('pricing-telebirr-number'));
      expect(tester.widget<TextField>(number).controller!.text, isEmpty);

      await tester.enterText(number, '0911 223344');
      await _tapPricingSave(tester);
      expect((await service.loadPricing()).telebirr.account, '+251911223344');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receivers-setup-card')), findsNothing);
      expect(find.byKey(const ValueKey('receivers-setup-dot')), findsNothing);
    });

    testWidgets('dashboard shows no setup card once receivers exist', (tester) async {
      repo.signInAsDemoUser(_admin);
      await service.savePricing(SubscriptionPricing.defaults.copyWith(cbe: _cbeReal));
      await tester.pumpWidget(_app(const ReceiversSetupBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receivers-setup-card')), findsNothing);
    });

    testWidgets('setup card in Amharic', (tester) async {
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(const Scaffold(body: ReceiversSetupBanner()), locale: const Locale('am')));
      await tester.pumpAndSettle();
      expect(find.text('የሱቅ ባለቤቶች የሚከፍሉዎትን ቦታ ያዘጋጁ'), findsOneWidget);
      expect(find.text('ያዘጋጁ'), findsOneWidget);
    });

    testWidgets('pricing screen rejects the sample, bad accounts and short names', (tester) async {
      // Tall enough that every field stays built.
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(AdminPricingScreen(service: service)));
      await tester.pumpAndSettle();

      Future<void> save() => _tapPricingSave(tester);

      await tester.enterText(find.byKey(const ValueKey('pricing-telebirr-number')), '+2519XXXXXXXX');
      await tester.enterText(find.byKey(const ValueKey('pricing-cbe-account')), '12345');
      await tester.enterText(find.byKey(const ValueKey('pricing-cbe-name')), 'C');
      await save();
      expect(find.text('Replace the XXXX sample with your real number.'), findsOneWidget);
      expect(find.text('Enter the 13-digit CBE account number that starts with 1000.'), findsOneWidget);
      expect(find.text("Enter the account holder's name (at least 2 characters)."), findsOneWidget);
      expect(find.text('Fix the highlighted fields.'), findsOneWidget);
      expect((await service.loadPricing()).hasReadyReceiver, isFalse);

      await tester.enterText(find.byKey(const ValueKey('pricing-telebirr-number')), '0911223');
      await save();
      expect(find.text('Enter an Ethiopian mobile number, e.g. 0911 223344.'), findsOneWidget);

      // Telebirr left empty (hidden from owners), CBE valid: saves.
      await tester.enterText(find.byKey(const ValueKey('pricing-telebirr-number')), '');
      await tester.enterText(find.byKey(const ValueKey('pricing-cbe-account')), '1000 1234 56789');
      await tester.enterText(find.byKey(const ValueKey('pricing-cbe-name')), 'Crown & Blade PLC');
      await save();
      final saved = await service.loadPricing();
      expect((saved.telebirr.account, saved.cbe.account), ('', '1000123456789'));
      expect(saved.payableMethods, [ReceiptMethod.cbe, ReceiptMethod.other]);
      expect(find.text('Enter the 13-digit CBE account number that starts with 1000.'), findsNothing);
    });

    testWidgets('owner: payments not open while no receiver is set up', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      repo.signInAsDemoUser(_owner1);
      await tester.pumpWidget(_app(ReceiptPaymentScreen(shopId: 'shop_1', service: service)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipt-payments-not-open')), findsOneWidget);
      expect(find.text("Payments aren't open yet — please check back soon."), findsOneWidget);
      expect(find.byKey(const ValueKey('copy-receiver-telebirr')), findsNothing);
      final submit = find.byKey(const ValueKey('receipt-submit'));
      await tester.ensureVisible(submit);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('receipt-tx'))).enabled, isFalse);
    });

    testWidgets('owner: only the set-up method is offered', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      repo.signInAsDemoUser(_admin);
      await service.savePricing(SubscriptionPricing.defaults.copyWith(cbe: _cbeReal));
      repo.signInAsDemoUser(_owner1);
      await tester.pumpWidget(_app(ReceiptPaymentScreen(shopId: 'shop_1', service: service)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipt-payments-not-open')), findsNothing);
      expect(find.byKey(const ValueKey('copy-receiver-cbe')), findsOneWidget);
      expect(find.byKey(const ValueKey('copy-receiver-telebirr')), findsNothing);
      final segments = tester
          .widget<SegmentedButton<ReceiptMethod>>(find.byKey(const ValueKey('receipt-method')))
          .segments
          .map((s) => s.value)
          .toList();
      expect(segments, [ReceiptMethod.cbe, ReceiptMethod.other]);
      // The default (telebirr) is not offered: CBE is selected instead.
      expect(tester.widget<SegmentedButton<ReceiptMethod>>(find.byKey(const ValueKey('receipt-method'))).selected,
          {ReceiptMethod.cbe});
      expect(find.byKey(const ValueKey('receipt-suffix')), findsOneWidget);
      final submit = find.byKey(const ValueKey('receipt-submit'));
      await tester.ensureVisible(submit);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);

      // Submitting goes through with CBE.
      await tester.enterText(find.byKey(const ValueKey('receipt-tx')), 'FT24123ABC12');
      await tester.enterText(find.byKey(const ValueKey('receipt-amount')), '500');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.local.all.any((p) => p.method == ReceiptMethod.cbe && p.transactionId == 'FT24123ABC12'), isTrue);
      await tester.pump(const Duration(seconds: 5)); // let the snack bar go
    });

    testWidgets('owner subscription entry card says when payments are not open', (tester) async {
      repo.signInAsDemoUser(_owner1);
      await tester.pumpWidget(_app(Scaffold(body: ReceiptPaymentEntryCard(shopId: 'shop_1', service: service))));
      await tester.pumpAndSettle();
      expect(find.text("Payments aren't open yet — please check back soon."), findsOneWidget);

      repo.signInAsDemoUser(_admin);
      await service.savePricing(SubscriptionPricing.defaults.copyWith(telebirr: _telebirrOnly));
      await tester.pumpAndSettle();
      expect(find.text("Payments aren't open yet — please check back soon."), findsNothing);
      expect(find.byKey(const ValueKey('receipt-entry-body')), findsOneWidget);
    });
  });
}
