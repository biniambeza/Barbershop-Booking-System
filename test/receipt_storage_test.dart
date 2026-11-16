// Receipt photos in Firebase Storage (Blaze) with the inline fallback
// (free plan): the admin switch, the upload + fallback, and both sources in
// the owner and admin views.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/payments/receipts/admin_pricing_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/admin_receipts_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/receipt_payment_screen.dart';
import 'package:barbershop_booking/features/payments/receipts/receipt_photo.dart';
import 'package:barbershop_booking/features/payments/receipts/subscription_receipts_service.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 15, 9, 0);
const _admin = 'admin@example.com';
const _owner1 = 'owner.shop1@example.com'; // shop_1
const _path = 'receipts/shop_1/telebirr_CHK1AB2CDE.jpg';

final Uint8List _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
final String _b64 = base64Encode(_jpeg);

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// Completes downloads only when told to (shows the loading state).
class _SlowStorage extends MemoryReceiptImageStorage {
  final List<Completer<void>> gates = [];

  @override
  Future<Uint8List> download(String path) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return super.download(path);
  }
}

void main() {
  group('models', () {
    test('pricing: storageReceipts is off by default and written only when on', () {
      expect(SubscriptionPricing.defaults.storageReceipts, isFalse);
      expect(SubscriptionPricing.defaults.toMap().containsKey('storageReceipts'), isFalse);
      final on = SubscriptionPricing.defaults.copyWith(storageReceipts: true);
      expect(on.toMap()['storageReceipts'], true);
      expect(SubscriptionPricing.fromMap(on.toMap()).storageReceipts, isTrue);
      expect(SubscriptionPricing.fromMap({'storageReceipts': 'yes'}).storageReceipts, isFalse);
      // Other edits keep the switch.
      expect(on.copyWith(updatedBy: 'x').storageReceipts, isTrue);
    });

    test('payment: imagePath replaces the inline photo', () {
      final inline = SubscriptionPayment(
        id: 'telebirr_CHK1AB2CDE',
        shopId: 'shop_1',
        ownerId: 'owner_1',
        method: ReceiptMethod.telebirr,
        transactionId: 'CHK1AB2CDE',
        amount: 1400,
        receiptImage: _b64,
        createdAt: _now,
      );
      expect((inline.hasImage, inline.hasInlineImage, inline.hasStoredImage), (true, true, false));
      final stored = inline.withStoredImage(_path);
      expect((stored.hasImage, stored.hasInlineImage, stored.hasStoredImage), (true, false, true));
      expect(stored.toCreateMap(), {
        'shopId': 'shop_1',
        'ownerId': 'owner_1',
        'method': 'telebirr',
        'transactionId': 'CHK1AB2CDE',
        'amount': 1400.0,
        'status': 'pending',
        'durationDays': 0,
        'createdAt': '2026-11-15T09:00:00.000Z',
        'imagePath': _path,
      });
      final back = SubscriptionPayment.fromMap(stored.toMap(), stored.id);
      expect((back.imagePath, back.receiptImage), (_path, null));
      expect(back.copyWith(status: ReceiptStatus.verified).imagePath, _path);
      expect(receiptStoragePath('shop_1', 'telebirr_CHK1AB2CDE'), _path);
    });
  });

  group('service', () {
    final repo = AppRepository.instance;
    late SubscriptionReceiptsService service;
    late MemoryReceiptImageStorage storage;

    setUp(() {
      loadTestSeed(now: _now);
      storage = MemoryReceiptImageStorage();
      service = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (_, __) {},
        imageStorage: storage,
      );
      SubscriptionReceiptsService.instance = service;
    });

    tearDown(() => SubscriptionReceiptsService.instance = null);

    Future<void> setSwitch(bool on) async {
      repo.signInAsDemoUser(_admin);
      final saved = await service.savePricing((await service.loadPricing()).copyWith(storageReceipts: on));
      expect(saved.storageReceipts, on);
      expect((await service.loadPricing()).storageReceipts, on);
    }

    Future<SubscriptionPayment> submit({String tx = 'CHK1AB2CDE', String? image}) {
      repo.signInAsDemoUser(_owner1);
      return service.submit(
          shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: tx, amount: 1400, receiptImageBase64: image ?? _b64);
    }

    test('switch off (default, free plan): the photo stays inline, nothing is uploaded', () async {
      final p = await submit();
      expect((p.receiptImage, p.imagePath), (_b64, null));
      expect(storage.uploads, 0);
      expect((await service.store.get(p.id))!.receiptImage, _b64);
      expect(await service.loadReceiptPhoto(p), _jpeg);
    });

    test('switch on (Blaze): uploaded to receipts/{shopId}/{paymentId}.jpg, only imagePath saved', () async {
      await setSwitch(true);
      final p = await submit();
      expect((p.receiptImage, p.imagePath), (null, _path));
      expect(storage.objects[_path], _jpeg);
      final saved = (await service.store.get(p.id))!;
      expect((saved.receiptImage, saved.imagePath), (null, _path));
      expect(service.lastPhotoUploadError, isNull);

      // Admin and owner views read it from Storage, once (cached).
      repo.signInAsDemoUser(_admin);
      expect(await service.loadReceiptPhoto(saved), _jpeg);
      expect(await service.loadReceiptPhoto(saved), _jpeg);
      expect(storage.downloads, 1);
    });

    test('switch on but the upload fails (no bucket / permission): falls back to inline', () async {
      await setSwitch(true);
      storage.uploadError = StateError('storage/bucket-not-found');
      final p = await submit();
      expect((p.receiptImage, p.imagePath), (_b64, null));
      expect((await service.store.get(p.id))!.receiptImage, _b64);
      expect(service.lastPhotoUploadError, isA<StateError>());
      expect(storage.objects, isEmpty);
    });

    test('switch on without Storage (DEMO_MODE / not attached): inline', () async {
      final noStorage = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (_, __) {},
      );
      expect(noStorage.imageStorage, isNull, reason: 'tests run without Firebase');
      repo.signInAsDemoUser(_admin);
      await noStorage.savePricing((await noStorage.loadPricing()).copyWith(storageReceipts: true));
      repo.signInAsDemoUser(_owner1);
      final p = await noStorage.submit(
          shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: 'CHK1AB2CDE', amount: 1400, receiptImageBase64: _b64);
      expect((p.receiptImage, p.imagePath), (_b64, null));
    });

    test('a duplicate transaction is refused before anything is uploaded; no photo, no upload', () async {
      await setSwitch(true);
      await submit();
      expect(storage.uploads, 1);
      await expectLater(submit(), throwsA(isA<ReceiptException>().having((e) => e.code, 'code', ReceiptErrorCode.duplicate)));
      expect(storage.uploads, 1);
      repo.signInAsDemoUser(_owner1);
      final bare = await service.submit(
          shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: 'CHK9ZZ9ZZZ', amount: 1400);
      expect((bare.hasImage, storage.uploads), (false, 1));
    });

    test('a failed download is retried on the next load', () async {
      await setSwitch(true);
      final p = await submit();
      storage.downloadError = StateError('storage/unauthorized');
      await expectLater(service.loadReceiptPhoto(p), throwsA(isA<StateError>()));
      storage.downloadError = null;
      expect(await service.loadReceiptPhoto(p), _jpeg);
    });
  });

  group('screens', () {
    final repo = AppRepository.instance;
    late SubscriptionReceiptsService service;
    late _SlowStorage storage;

    setUp(() {
      loadTestSeed(now: _now);
      storage = _SlowStorage();
      service = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (_, __) {},
        imageStorage: storage,
      );
      SubscriptionReceiptsService.instance = service;
    });

    tearDown(() => SubscriptionReceiptsService.instance = null);

    Future<SubscriptionPayment> submitStored() async {
      repo.signInAsDemoUser(_admin);
      await service.savePricing((await service.loadPricing()).copyWith(storageReceipts: true));
      repo.signInAsDemoUser(_owner1);
      return service.submit(
          shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: 'CHK1AB2CDE', amount: 1400, receiptImageBase64: _b64);
    }

    testWidgets('admin pricing: the Storage switch is saved', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(AdminPricingScreen(service: service)));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('pricing-storage-receipts'));
      await tester.scrollUntilVisible(toggle, 300,
          scrollable: find.descendant(of: find.byType(AdminPricingScreen), matching: find.byType(Scrollable)).first);
      expect(find.text('Store receipt photos in Firebase Storage — needs Blaze'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('pricing-save'));
      await tester.scrollUntilVisible(save, 300,
          scrollable: find.descendant(of: find.byType(AdminPricingScreen), matching: find.byType(Scrollable)).first);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect((await service.loadPricing()).storageReceipts, isTrue);
    });

    testWidgets('admin detail: a Storage photo shows loading, then the image', (tester) async {
      final p = await submitStored();
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(AdminReceiptDetailScreen(payment: p, service: service)));
      await tester.pump();
      expect(find.byKey(const ValueKey('receipt-photo-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-receipt-image')), findsNothing);
      storage.gates.single.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-receipt-image')), findsOneWidget);
    });

    testWidgets('admin detail: a photo that cannot be loaded shows an error with retry', (tester) async {
      final p = await submitStored();
      storage.downloadError = StateError('storage/object-not-found');
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(AdminReceiptDetailScreen(payment: p, service: service)));
      await tester.pump();
      storage.gates.single.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-photo-error')), findsOneWidget);
      expect(find.text("Couldn't load the receipt photo."), findsOneWidget);

      storage.downloadError = null;
      await tester.tap(find.byKey(const ValueKey('receipt-photo-retry')));
      await tester.pump();
      storage.gates.last.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-receipt-image')), findsOneWidget);
    });

    testWidgets('owner history and admin list render inline and Storage photos', (tester) async {
      final stored = await submitStored();
      repo.signInAsDemoUser(_admin);
      await service.savePricing((await service.loadPricing()).copyWith(storageReceipts: false));
      repo.signInAsDemoUser(_owner1);
      final inline = await service.submit(
          shopId: 'shop_1', method: ReceiptMethod.telebirr, transactionId: 'CHK2AB2CDE', amount: 1400, receiptImageBase64: _b64);
      expect((stored.hasStoredImage, inline.hasInlineImage), (true, true));

      await tester.pumpWidget(_app(Scaffold(
        body: ListView(children: [
          ReceiptHistoryTile(payment: stored, service: service),
          ReceiptHistoryTile(payment: inline, service: service),
        ]),
      )));
      await tester.pump();
      // Inline shows at once; the Storage one loads.
      expect(find.byType(ReceiptPhoto), findsNWidgets(2));
      expect(find.byKey(const ValueKey('receipt-photo-loading')), findsOneWidget);
      for (final g in storage.gates) {
        g.complete();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-photo-loading')), findsNothing);
      expect(find.descendant(of: find.byType(ReceiptPhoto), matching: find.byType(Image)), findsNWidgets(2));

      // Admin list.
      repo.signInAsDemoUser(_admin);
      await tester.pumpWidget(_app(AdminReceiptsScreen(service: service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-receipt-telebirr_CHK1AB2CDE')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('admin-receipt-telebirr_CHK1AB2CDE')), matching: find.byType(Image)),
          findsOneWidget,
          reason: 'cached from the owner view');
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('admin-receipt-telebirr_CHK2AB2CDE')), matching: find.byType(Image)),
          findsOneWidget);
    });
  });
}
