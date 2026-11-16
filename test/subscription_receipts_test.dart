import 'dart:convert';
import 'dart:typed_data';

import 'package:barbershop_booking/features/payments/receipts/receipt_image.dart';
import 'package:barbershop_booking/features/payments/receipts/subscription_receipts_service.dart';
import 'package:barbershop_booking/models/app_notification.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'test_helpers.dart';

// Sunday 15 Nov 2026, 12:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 15, 9, 0);

const _admin = 'admin@example.com';
const _owner1 = 'owner.shop1@example.com'; // shop_1, ends in 25 days, active
const _owner2 = 'owner.shop2@example.com'; // shop_2
const _owner5 = 'owner.shop5@example.com'; // shop_5, ended 2 days ago, past_due
const _owner6 = 'owner.shop6@example.com'; // shop_6, ended 10 days ago, suspended

Matcher _receiptError(ReceiptErrorCode code) =>
    throwsA(isA<ReceiptException>().having((e) => e.code, 'code', code));

void main() {
  group('duration from amount', () {
    const tiers = [
      PricingTier(days: 30, amount: 500),
      PricingTier(days: 90, amount: 1400),
      PricingTier(days: 180, amount: 2700),
      PricingTier(days: 365, amount: 5000),
    ];

    test('the longest tier whose amount is covered', () {
      expect(tierForAmount(tiers, 499.99), isNull);
      expect(tierForAmount(tiers, 500)?.days, 30);
      expect(tierForAmount(tiers, 1399)?.days, 30);
      expect(tierForAmount(tiers, 1400)?.days, 90);
      expect(tierForAmount(tiers, 2000)?.days, 90);
      expect(tierForAmount(tiers, 2700)?.days, 180);
      expect(tierForAmount(tiers, 5000)?.days, 365);
      expect(tierForAmount(tiers, 12000)?.days, 365);
    });

    test('order of the tiers does not matter', () {
      expect(tierForAmount(tiers.reversed.toList(), 2000)?.days, 90);
      expect(tierForAmount(const [], 2000), isNull);
    });

    test('defaults and minimum amount', () {
      const p = SubscriptionPricing.defaults;
      expect(p.minimumAmount, 500);
      expect(p.durationDaysFor(1400), 90);
      expect(p.durationDaysFor(100), isNull);
    });
  });

  group('transaction numbers', () {
    test('normalized: trimmed, uppercase, no spaces', () {
      expect(normalizeTransactionId('  chk1 ab2\tcde \n'), 'CHK1AB2CDE');
      expect(normalizeTransactionId('ft24 1234 5abc'), 'FT2412345ABC');
    });

    test('shape per method', () {
      expect(isValidTransactionId(ReceiptMethod.telebirr, 'CHK1AB2CDE'), isTrue);
      expect(isValidTransactionId(ReceiptMethod.telebirr, '1234567890'), isFalse, reason: 'needs a letter');
      expect(isValidTransactionId(ReceiptMethod.telebirr, 'CHK1'), isFalse);
      expect(isValidTransactionId(ReceiptMethod.telebirr, 'CHK1AB2CDE/X'), isFalse);
      expect(isValidTransactionId(ReceiptMethod.cbe, 'FT2412345ABC'), isTrue);
      expect(isValidTransactionId(ReceiptMethod.cbe, 'CHK1AB2CDE'), isFalse);
      expect(isValidTransactionId(ReceiptMethod.other, 'REF-2024-001'), isTrue);
      expect(isValidTransactionId(ReceiptMethod.other, 'A/B'), isFalse);
    });

    test('doc id makes one transaction usable once', () {
      expect(receiptDocId(ReceiptMethod.telebirr, 'CHK1AB2CDE'), 'telebirr_CHK1AB2CDE');
      expect(receiptDocId(ReceiptMethod.cbe, 'FT2412345ABC'), 'cbe_FT2412345ABC');
    });

    test('official receipt urls', () {
      expect(officialReceiptUrl(ReceiptMethod.telebirr, ' chk1ab2cde ').toString(),
          'https://transactioninfo.ethiotelecom.et/receipt/CHK1AB2CDE');
      expect(officialReceiptUrl(ReceiptMethod.cbe, 'FT2412345ABC').toString(),
          'https://apps.cbe.com.et:100/?id=FT2412345ABC');
      expect(officialReceiptUrl(ReceiptMethod.cbe, 'FT2412345ABC', payerAccountSuffix: '1000 1234 5678').toString(),
          'https://apps.cbe.com.et:100/?id=FT2412345ABC12345678');
      expect(officialReceiptUrl(ReceiptMethod.other, 'REF-1'), isNull);
      final custom = SubscriptionPricing.fromMap({
        'tiers': [
          {'days': 30, 'amount': 500}
        ],
        'receiptUrls': {'telebirr': 'https://example.com/r?tx={id}', 'cbe': 'http://insecure/{id}'},
      });
      expect(custom.receiptUrl(ReceiptMethod.telebirr, 'CHK1AB2CDE').toString(), 'https://example.com/r?tx=CHK1AB2CDE');
      expect(custom.cbeReceiptUrl, kCbeReceiptUrlTemplate, reason: 'only https templates are accepted');
    });

    test('payer account suffix and amounts', () {
      expect(normalizePayerAccountSuffix('1000 1234 5678'), '12345678');
      expect(normalizePayerAccountSuffix('12'), isNull);
      expect(normalizePayerAccountSuffix(null), isNull);
      expect(normalizeReceiptAmount('1,400'), 1400);
      expect(normalizeReceiptAmount(1400.456), 1400.46);
      expect(normalizeReceiptAmount(0), isNull);
      expect(normalizeReceiptAmount(-5), isNull);
      expect(normalizeReceiptAmount('abc'), isNull);
      expect(normalizeReceiptAmount(double.nan), isNull);
      expect(normalizeReceiptAmount(kMaxReceiptAmount + 1), isNull);
    });
  });

  group('extending the subscription', () {
    test('from the current end while it is in the future', () {
      final end = _now.add(const Duration(days: 10));
      expect(extendSubscriptionByDays(end, _now, 30), end.add(const Duration(days: 30)));
    });

    test('from now when it already ended or was never set', () {
      expect(extendSubscriptionByDays(_now.subtract(const Duration(days: 3)), _now, 90), _now.add(const Duration(days: 90)));
      expect(extendSubscriptionByDays(null, _now, 30), _now.add(const Duration(days: 30)));
    });
  });

  group('pricing config', () {
    test('round-trips with the contract keys', () {
      final p = SubscriptionPricing.defaults.copyWith(updatedAt: _now, updatedBy: 'user_admin_1');
      final map = p.toMap();
      expect(map.keys.toSet(), {'currency', 'tiers', 'receivers', 'receiptUrls', 'updatedAt', 'updatedBy'});
      expect((map['receivers'] as Map)['telebirr'], {'number': '+2519XXXXXXXX', 'name': 'Crown & Blade'});
      expect((map['receivers'] as Map)['cbe'], {'account': '1000XXXXXXXXX', 'name': 'Crown & Blade'});
      final back = SubscriptionPricing.fromMap(map);
      expect(back.tiers, p.tiers);
      expect(back.updatedAt, _now);
      expect(back.updatedBy, 'user_admin_1');
      expect(back.telebirr.isConfigured, isFalse, reason: 'placeholder');
    });

    test('tolerant reads: bad tiers dropped, missing doc gives defaults', () {
      final p = SubscriptionPricing.fromMap({
        'tiers': [
          {'days': 90, 'amount': 1400},
          {'days': 'x', 'amount': 1},
          {'days': 30, 'amount': -1},
          {'days': 30, 'amount': 500},
        ],
        'receivers': {
          'telebirr': {'number': '+251911223344', 'name': 'Crown'},
        },
      });
      expect(p.tiers, const [PricingTier(days: 30, amount: 500), PricingTier(days: 90, amount: 1400)]);
      expect(p.telebirr.account, '+251911223344');
      expect(p.telebirr.isConfigured, isTrue);
      expect(p.cbe.account, SubscriptionPricing.defaults.cbe.account);
      expect(SubscriptionPricing.fromMap(null).tiers, SubscriptionPricing.defaults.tiers);
      expect(SubscriptionPricing.fromMap({'tiers': []}).tiers, SubscriptionPricing.defaults.tiers);
    });

    test('validation', () {
      const d = SubscriptionPricing.defaults;
      expect(validatePricing(d), isNull);
      expect(validatePricing(d.copyWith(tiers: [])), PricingError.noTiers);
      expect(validatePricing(d.copyWith(tiers: [const PricingTier(days: 0, amount: 5)])), PricingError.invalidTier);
      expect(
          validatePricing(d.copyWith(tiers: const [PricingTier(days: 30, amount: 500), PricingTier(days: 30, amount: 900)])),
          PricingError.duplicateDays);
      expect(
          validatePricing(d.copyWith(tiers: const [PricingTier(days: 30, amount: 500), PricingTier(days: 90, amount: 500)])),
          PricingError.notIncreasing);
      expect(
          validatePricing(d.copyWith(tiers: [for (var i = 1; i <= kMaxPricingTiers + 1; i++) PricingTier(days: i, amount: i * 10.0)])),
          PricingError.tooManyTiers);
      expect(validatePricing(d.copyWith(telebirr: PaymentReceiver(account: '+251911223344', name: 'x' * 81))),
          PricingError.receiverName);
    });
  });

  group('SubscriptionPayment model', () {
    final p = SubscriptionPayment(
      id: 'telebirr_CHK1AB2CDE',
      shopId: 'shop_1',
      ownerId: 'owner_1',
      method: ReceiptMethod.telebirr,
      transactionId: 'CHK1AB2CDE',
      amount: 1400,
      receiptImage: 'AAAA',
      createdAt: _now,
    );

    test('owner create map has exactly the contract keys', () {
      expect(p.toCreateMap(), {
        'shopId': 'shop_1',
        'ownerId': 'owner_1',
        'method': 'telebirr',
        'transactionId': 'CHK1AB2CDE',
        'amount': 1400.0,
        'status': 'pending',
        'durationDays': 0,
        'createdAt': '2026-11-15T09:00:00.000Z',
        'receiptImage': 'AAAA',
      });
    });

    test('round-trips every field', () {
      final decided = p.copyWith(
        status: ReceiptStatus.needsReview,
        durationDays: 90,
        verifiedAmount: 1400,
        verifiedBy: 'auto',
        decisionReason: 'receiver_mismatch',
        decidedAt: _now.add(const Duration(minutes: 1)),
      );
      final back = SubscriptionPayment.fromMap(decided.toMap(), decided.id);
      expect(back.status, ReceiptStatus.needsReview);
      expect(back.status.isOpen, isTrue);
      expect(back.toMap(), decided.toMap());
      expect(back.isAutoVerified, isTrue);
      expect(ReceiptStatus.fromValue('needs_review'), ReceiptStatus.needsReview);
      expect(ReceiptStatus.fromValue('weird'), ReceiptStatus.pending);
    });

    test('admin order: open oldest first, then decided newest first', () {
      SubscriptionPayment at(String id, int hoursAgo, ReceiptStatus s, [int? decidedHoursAgo]) => SubscriptionPayment(
            id: id,
            shopId: 's',
            ownerId: 'o',
            method: ReceiptMethod.cbe,
            transactionId: id,
            amount: 500,
            status: s,
            createdAt: _now.subtract(Duration(hours: hoursAgo)),
            decidedAt: decidedHoursAgo == null ? null : _now.subtract(Duration(hours: decidedHoursAgo)),
          );
      final list = [
        at('d_old', 50, ReceiptStatus.verified, 40),
        at('open_new', 1, ReceiptStatus.pending),
        at('d_new', 30, ReceiptStatus.rejected, 2),
        at('open_old', 9, ReceiptStatus.needsReview),
      ]..sort(SubscriptionPayment.adminOrder);
      expect(list.map((p) => p.id), ['open_old', 'open_new', 'd_new', 'd_old']);
    });
  });

  group('seed', () {
    test('pricing and one pending + one verified payment', () {
      final json = jsonDecode(readSeedJson()) as Map<String, dynamic>;
      final pricing = subscriptionPricingFromSeedJson(json);
      expect(pricing.tiers, SubscriptionPricing.defaults.tiers);
      final payments = subscriptionPaymentsFromSeedJson(json, now: _now);
      expect(payments.map((p) => (p.id, p.status, p.ownerId)), [
        ('cbe_FT26300ABC12', ReceiptStatus.verified, 'owner_2'),
        ('telebirr_CHK7QX2M9P', ReceiptStatus.pending, 'owner_5'),
      ]);
      expect(payments.first.durationDays, 90);
      expect(payments.first.decidedAt, _now.subtract(const Duration(hours: 236)));
      expect(payments.last.createdAt, _now.subtract(const Duration(hours: 5)));
      expect(payments.last.decidedAt, isNull);
    });
  });

  group('receipt image compression', () {
    test('a large photo becomes a small JPEG within 1600px', () {
      final big = img.Image(width: 3000, height: 2000);
      for (var y = 0; y < big.height; y += 1) {
        for (var x = 0; x < big.width; x += 1) {
          big.setPixelRgb(x, y, (x * 7 + y * 3) % 256, (x * y) % 256, (x ^ y) % 256);
        }
      }
      final png = Uint8List.fromList(img.encodePng(big, level: 1));
      final jpeg = compressReceiptImage(png)!;
      expect(jpeg.length, lessThanOrEqualTo(kReceiptMaxBytes));
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, lessThanOrEqualTo(kReceiptMaxDimension));
      expect(decoded.height, lessThanOrEqualTo(kReceiptMaxDimension));
      final b64 = receiptImageBase64(png)!;
      expect(b64.length, lessThanOrEqualTo(kMaxReceiptImageChars));
    });

    test('not an image', () {
      expect(compressReceiptImage(Uint8List.fromList(utf8.encode('hello'))), isNull);
      expect(receiptImageBase64(Uint8List(0)), isNull);
    });
  });

  group('SubscriptionReceiptsService (local)', () {
    final repo = AppRepository.instance;
    late SubscriptionReceiptsService service;
    late List<(String, AppNotification)> inbox;

    setUp(() {
      loadTestSeed(now: _now);
      inbox = [];
      service = SubscriptionReceiptsService(
        repository: repo,
        local: LocalReceiptStore()..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
        localInbox: (uid, n) => inbox.add((uid, n)),
      );
    });

    Future<SubscriptionPayment> submitAs(String email, String shopId,
        {ReceiptMethod method = ReceiptMethod.telebirr, String tx = 'chk1 ab2cde', Object amount = 1400, String? image}) {
      repo.signInAsDemoUser(email);
      return service.submit(
          shopId: shopId, method: method, transactionId: tx, amount: amount, receiptImageBase64: image);
    }

    test('owner submits a pending receipt for their shop', () async {
      final p = await submitAs(_owner1, 'shop_1', image: 'QUJD', amount: '1,400');
      expect(p.id, 'telebirr_CHK1AB2CDE');
      expect((p.status, p.ownerId, p.shopId, p.amount, p.durationDays), (ReceiptStatus.pending, 'owner_1', 'shop_1', 1400.0, 0));
      expect(p.receiptImage, 'QUJD');
      expect(p.createdAt, _now);
      expect((await service.store.get(p.id))?.status, ReceiptStatus.pending);
    });

    test('CBE keeps the payer account suffix; other methods drop it', () async {
      repo.signInAsDemoUser(_owner1);
      final cbe = await service.submit(
          shopId: 'shop_1',
          method: ReceiptMethod.cbe,
          transactionId: 'FT2412345ABC',
          amount: 500,
          payerAccountSuffix: '1000-1234-5678');
      expect(cbe.payerAccountSuffix, '12345678');
      final tb = await service.submit(
          shopId: 'shop_1',
          method: ReceiptMethod.telebirr,
          transactionId: 'CHK9ZZ9ZZZ',
          amount: 500,
          payerAccountSuffix: '12345678');
      expect(tb.payerAccountSuffix, isNull);
    });

    test('a transaction number can be used only once, platform-wide', () async {
      await submitAs(_owner1, 'shop_1');
      expect(() => submitAs(_owner1, 'shop_1', tx: 'CHK1AB2CDE'), _receiptError(ReceiptErrorCode.duplicate));
      await expectLater(submitAs(_owner2, 'shop_2', tx: ' chk1ab2cde'), _receiptError(ReceiptErrorCode.duplicate));
      // The seeded verified CBE receipt cannot be reused either.
      await expectLater(
          submitAs(_owner1, 'shop_1', method: ReceiptMethod.cbe, tx: 'ft26300abc12'), _receiptError(ReceiptErrorCode.duplicate));
      // Same number under another method is a different transaction.
      final other = await submitAs(_owner2, 'shop_2', method: ReceiptMethod.other, tx: 'CHK1AB2CDE');
      expect(other.id, 'other_CHK1AB2CDE');
    });

    test('input checks', () async {
      await expectLater(submitAs(_owner1, 'shop_1', amount: 499), _receiptError(ReceiptErrorCode.amountTooLow));
      await expectLater(submitAs(_owner1, 'shop_1', amount: 'abc'), _receiptError(ReceiptErrorCode.invalidAmount));
      await expectLater(submitAs(_owner1, 'shop_1', tx: '12'), _receiptError(ReceiptErrorCode.invalidTransactionId));
      await expectLater(submitAs(_owner1, 'shop_1', method: ReceiptMethod.cbe, tx: 'CHK1AB2CDE'),
          _receiptError(ReceiptErrorCode.invalidTransactionId));
      await expectLater(submitAs(_owner1, 'shop_1', image: 'A' * (kMaxReceiptImageChars + 1)),
          _receiptError(ReceiptErrorCode.imageTooLarge));
      await expectLater(submitAs(_owner1, 'shop_2'), _receiptError(ReceiptErrorCode.ownerOnly));
      await expectLater(submitAs(_admin, 'shop_1'), _receiptError(ReceiptErrorCode.ownerOnly));
      expect(service.local.all.where((p) => p.ownerId == 'owner_1'), isEmpty);
    });

    test('owner history: only their own receipts, newest first', () async {
      repo.signInAsDemoUser(_owner5);
      final seeded = await service.watchMine('shop_5').first;
      expect(seeded.map((p) => p.id), ['telebirr_CHK7QX2M9P']);

      await submitAs(_owner1, 'shop_1', tx: 'CHKAAAA111');
      repo.debugClock = () => _now.add(const Duration(minutes: 5));
      await submitAs(_owner1, 'shop_1', tx: 'CHKBBBB222', amount: 500);
      final mine = await service.watchMine('shop_1').first;
      expect(mine.map((p) => p.transactionId), ['CHKBBBB222', 'CHKAAAA111']);

      // Live: an admin decision shows up in the owner's stream.
      final updates = <List<SubscriptionPayment>>[];
      final sub = service.watchMine('shop_1').listen(updates.add);
      await Future<void>.delayed(Duration.zero);
      repo.signInAsDemoUser(_admin);
      await service.reject('telebirr_CHKBBBB222', 'Wrong receiver');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(updates.last.first.status, ReceiptStatus.rejected);
    });

    test('admin approve extends from the current end when it is in the future', () async {
      final p = await submitAs(_owner1, 'shop_1', amount: 2000); // 90 days
      final before = repo.getShopById('shop_1')!;
      expect(before.subscriptionEndsAt, _now.add(const Duration(days: 25)));

      repo.signInAsDemoUser(_admin);
      final open = await service.watchForAdmin().first;
      expect(open.first.id, 'telebirr_CHK7QX2M9P', reason: 'oldest open first');
      expect(open.map((e) => e.id), contains(p.id));

      final result = await service.approve(p.id);
      expect(result.durationDays, 90);
      expect(result.newEndsAt, _now.add(const Duration(days: 115)));

      final shop = repo.getShopById('shop_1')!;
      expect(shop.subscriptionEndsAt, _now.add(const Duration(days: 115)));
      expect(shop.subscriptionStatus, SubscriptionStatus.active);
      expect(shop.subscriptionPlan, before.subscriptionPlan, reason: 'the plan stays');

      final stored = (await service.store.get(p.id))!;
      expect((stored.status, stored.durationDays, stored.verifiedAmount, stored.verifiedBy, stored.decidedAt),
          (ReceiptStatus.verified, 90, 2000.0, 'user_admin_1', _now));

      expect(inbox, hasLength(1));
      final (uid, n) = inbox.single;
      expect(uid, 'owner_1');
      expect(n.id, 'telebirr_CHK1AB2CDE_receipt');
      expect(n.type, NotificationTypes.receiptApproved);
      expect(n.title, isNotEmpty);

      // Decided receipts cannot be decided again.
      await expectLater(service.approve(p.id), _receiptError(ReceiptErrorCode.notOpen));
      await expectLater(service.reject(p.id, 'no'), _receiptError(ReceiptErrorCode.notOpen));
    });

    test('admin approve of a lapsed shop counts from now and reactivates it', () async {
      repo.signInAsDemoUser(_admin);
      final before = repo.getShopById('shop_5')!;
      expect(before.subscriptionStatus, SubscriptionStatus.pastDue);
      final result = await service.approve('telebirr_CHK7QX2M9P'); // seeded, 500 ETB
      expect(result.durationDays, 30);
      expect(result.newEndsAt, _now.add(const Duration(days: 30)));
      final shop = repo.getShopById('shop_5')!;
      expect(shop.subscriptionEndsAt, _now.add(const Duration(days: 30)));
      expect(shop.subscriptionStatus, SubscriptionStatus.active);
    });

    test('a subscription-suspended shop becomes active; an admin suspension stays', () async {
      final p = await submitAs(_owner6, 'shop_6', tx: 'CHK6SHOP66', amount: 500);
      repo.signInAsDemoUser(_admin);
      await repo.suspendShop('shop_6', 'Licence check');
      expect(repo.getShopById('shop_6')!.subscriptionStatus, SubscriptionStatus.suspended);
      await service.approve(p.id);
      final shop = repo.getShopById('shop_6')!;
      expect(shop.subscriptionStatus, SubscriptionStatus.active);
      expect(shop.adminSuspended, isTrue);
      expect(shop.isBlocked, isTrue);
    });

    test('admin may approve a different verified amount', () async {
      final p = await submitAs(_owner1, 'shop_1', amount: 5000);
      repo.signInAsDemoUser(_admin);
      await expectLater(service.approve(p.id, verifiedAmount: 300), _receiptError(ReceiptErrorCode.amountTooLow));
      final r = await service.approve(p.id, verifiedAmount: 1400);
      expect(r.durationDays, 90);
      expect((await service.store.get(p.id))!.verifiedAmount, 1400);
    });

    test('admin reject keeps the subscription and notifies with the reason', () async {
      final p = await submitAs(_owner1, 'shop_1');
      final before = repo.getShopById('shop_1')!;
      repo.signInAsDemoUser(_admin);
      await expectLater(service.reject(p.id, '   '), _receiptError(ReceiptErrorCode.reasonRequired));
      await expectLater(service.reject(p.id, 'x' * (kMaxReceiptReasonLength + 1)), _receiptError(ReceiptErrorCode.reasonRequired));
      await service.reject(p.id, ' Receipt shows another receiver ');
      final stored = (await service.store.get(p.id))!;
      expect((stored.status, stored.decisionReason, stored.verifiedBy, stored.durationDays),
          (ReceiptStatus.rejected, 'Receipt shows another receiver', 'user_admin_1', 0));
      expect(repo.getShopById('shop_1')!.subscriptionEndsAt, before.subscriptionEndsAt);
      expect(inbox.single.$1, 'owner_1');
      expect(inbox.single.$2.type, NotificationTypes.receiptRejected);
      expect(inbox.single.$2.body, contains('CHK1AB2CDE'));
    });

    test('only admins decide receipts or edit pricing', () async {
      final p = await submitAs(_owner1, 'shop_1');
      await expectLater(service.approve(p.id), _receiptError(ReceiptErrorCode.adminOnly));
      await expectLater(service.reject(p.id, 'x'), _receiptError(ReceiptErrorCode.adminOnly));
      await expectLater(service.savePricing(SubscriptionPricing.defaults), _receiptError(ReceiptErrorCode.adminOnly));
      expect(await service.watchForAdmin().first, isEmpty);
    });

    test('admin edits pricing; new tiers apply to later submissions', () async {
      repo.signInAsDemoUser(_admin);
      await expectLater(service.savePricing(SubscriptionPricing.defaults.copyWith(tiers: [])),
          _receiptError(ReceiptErrorCode.invalidPricing));
      final saved = await service.savePricing(SubscriptionPricing.defaults.copyWith(tiers: const [
        PricingTier(days: 90, amount: 1200),
        PricingTier(days: 30, amount: 450),
      ]));
      expect(saved.tiers.map((t) => t.days), [30, 90]);
      expect((saved.updatedBy, saved.updatedAt), ('user_admin_1', _now));
      expect((await service.loadPricing()).durationDaysFor(1300), 90);
      final p = await submitAs(_owner1, 'shop_1', amount: 450);
      repo.signInAsDemoUser(_admin);
      expect((await service.approve(p.id)).durationDays, 30);
    });
  });
}
