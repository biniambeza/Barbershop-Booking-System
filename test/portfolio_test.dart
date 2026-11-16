// Barber portfolio photos: the model, compression, the service rules (who
// may change a portfolio, the 12-photo cap, captions), Storage on/off with
// the inline fallback, and the Firestore store's document shape.
import 'dart:convert';
import 'dart:typed_data';

import 'package:barbershop_booking/features/portfolio/portfolio_service.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'test_helpers.dart';

final _now = DateTime.utc(2026, 11, 15, 9, 0);
const _owner1 = 'owner.shop1@example.com'; // shop_1
const _owner2 = 'owner.shop2@example.com'; // shop_2
const _barber1 = 'barber1.shop1@example.com'; // shop_1 / barber_1
const _barber2 = 'barber2.shop1@example.com'; // shop_1 / barber_2
const _customer = 'liya@example.com';

final Uint8List _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
final String _b64 = base64Encode(_jpeg);

void main() {
  group('model', () {
    test('slots p01..p12, first free slot, Storage path', () {
      expect(portfolioSlotId(1), 'p01');
      expect(portfolioSlotId(12), 'p12');
      expect(['p01', 'p09', 'p10', 'p12'].every(isPortfolioPhotoId), isTrue);
      expect(['p00', 'p13', 'p1', 'x01', 'p01a', ''].any(isPortfolioPhotoId), isFalse);
      expect(nextFreePortfolioSlot(const []), 'p01');
      expect(nextFreePortfolioSlot(const ['p01', 'p02', 'p04']), 'p03');
      expect(nextFreePortfolioSlot([for (var i = 1; i <= 12; i++) portfolioSlotId(i)]), isNull);
      expect(portfolioStoragePath('shop_1', 'barber_1', 'p03'), 'portfolio/shop_1/barber_1/p03.jpg');
    });

    test('captions are trimmed, optional and at most 40 characters', () {
      expect(normalizePortfolioCaption('  Low   fade '), 'Low fade');
      expect(normalizePortfolioCaption('   '), isNull);
      expect(normalizePortfolioCaption(null), isNull);
      expect(isValidPortfolioCaption(null), isTrue);
      expect(isValidPortfolioCaption('a' * 40), isTrue);
      expect(isValidPortfolioCaption('a' * 41), isFalse);
    });

    test('create map: inline image or imagePath, no personal data', () {
      final p = PortfolioPhoto(id: 'p01', shopId: 'shop_1', barberId: 'barber_1', createdAt: _now, caption: 'Low fade', image: _b64);
      expect(p.toCreateMap(), {'caption': 'Low fade', 'image': _b64, 'createdAt': '2026-11-15T09:00:00.000Z'});
      expect((p.hasInlineImage, p.hasStoredImage), (true, false));
      expect(p.inlineBytes, _jpeg);

      final stored = p.withStoredImage('portfolio/shop_1/barber_1/p01.jpg');
      expect(stored.toCreateMap(), {
        'caption': 'Low fade',
        'imagePath': 'portfolio/shop_1/barber_1/p01.jpg',
        'createdAt': '2026-11-15T09:00:00.000Z',
      });
      expect((stored.hasInlineImage, stored.hasStoredImage, stored.inlineBytes), (false, true, null));

      final back = PortfolioPhoto.fromMap(stored.toCreateMap(), id: 'p01', shopId: 'shop_1', barberId: 'barber_1');
      expect((back.caption, back.imagePath, back.image, back.createdAt), ('Low fade', stored.imagePath, null, _now));
      final noCaption = PortfolioPhoto.fromMap({'image': _b64, 'createdAt': Timestamp.fromDate(_now)},
          id: 'p02', shopId: 'shop_1', barberId: 'barber_1');
      expect((noCaption.caption, noCaption.createdAt), (null, _now));
      expect(p.copyWith(clearCaption: true).toCreateMap().containsKey('caption'), isFalse);
    });

    test('compression: big photos become a JPEG of at most ~150 KB and 1280 px', () {
      final big = img.Image(width: 2400, height: 1600);
      for (final px in big) {
        px
          ..r = (px.x * 7 + px.y * 3) % 256
          ..g = (px.x * px.y) % 256
          ..b = (px.y * 11) % 256;
      }
      final b64 = portfolioImageBase64(Uint8List.fromList(img.encodePng(big)));
      expect(b64, isNotNull);
      expect(b64!.length, lessThanOrEqualTo(kMaxPortfolioImageChars));
      final jpeg = base64Decode(b64);
      expect(jpeg.length, lessThanOrEqualTo(kPortfolioMaxBytes));
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, lessThanOrEqualTo(kPortfolioMaxDimension));
      expect(decoded.height, lessThanOrEqualTo(kPortfolioMaxDimension));
      expect(portfolioImageBase64(Uint8List.fromList(utf8.encode('not an image'))), isNull);
    });
  });

  group('service', () {
    final repo = AppRepository.instance;
    late LocalPortfolioStore store;
    late MemoryPortfolioImageStorage storage;
    late PortfolioService service;

    setUp(() {
      loadTestSeed(now: _now);
      store = LocalPortfolioStore();
      storage = MemoryPortfolioImageStorage();
      service = PortfolioService(repository: repo, local: store, imageStorage: storage);
    });

    Future<PortfolioPhoto> add({String barberId = 'barber_1', String? caption, String? image}) =>
        service.add(shopId: 'shop_1', barberId: barberId, base64Jpeg: image ?? _b64, caption: caption);

    test('the barber adds photos to their own portfolio, newest first, in free slots', () async {
      repo.signInAsDemoUser(_barber1);
      expect(service.canManage('shop_1', 'barber_1'), isTrue);
      final a = await add(caption: '  Low   fade ');
      final b = await add();
      expect((a.id, a.caption, a.image), ('p01', 'Low fade', _b64));
      expect((b.id, b.caption), ('p02', null));
      expect(await service.count('shop_1', 'barber_1'), 2);
      expect((await store.list('shop_1', 'barber_1')).map((p) => p.id), ['p01', 'p02']..sort());
      expect(service.cached('shop_1', 'barber_1')!.map((p) => p.id).toSet(), {'p01', 'p02'});
      // Free plan: inline, nothing uploaded.
      expect(storage.uploads, 0);
      expect(await service.loadBytes(a), _jpeg);
    });

    test('the shop owner manages any of their barbers; nobody else does', () async {
      repo.signInAsDemoUser(_owner1);
      expect(service.canManage('shop_1', 'barber_2'), isTrue);
      final p = await add(barberId: 'barber_2', caption: 'Taper');
      expect(p.barberId, 'barber_2');

      repo.signInAsDemoUser(_barber2);
      expect(service.canManage('shop_1', 'barber_1'), isFalse);
      await expectLater(add(), throwsA(isA<PortfolioException>().having((e) => e.code, 'code', PortfolioErrorCode.notAllowed)));

      repo.signInAsDemoUser(_owner2);
      expect(service.canManage('shop_1', 'barber_2'), isFalse);
      await expectLater(service.remove(p), throwsA(isA<PortfolioException>()));

      repo.signInAsDemoUser(_customer);
      expect(service.canManage('shop_1', 'barber_1'), isFalse);
      await expectLater(service.setCaption(p, 'x'), throwsA(isA<PortfolioException>()));

      await repo.signOut();
      expect(service.canManage('shop_1', 'barber_1'), isFalse);
      // Anyone can still see it.
      expect((await service.load('shop_1', 'barber_2')).single.caption, 'Taper');
    });

    test('at most 12 photos; a deleted slot is reused', () async {
      repo.signInAsDemoUser(_barber1);
      for (var i = 0; i < kMaxPortfolioPhotos; i++) {
        await add();
      }
      await expectLater(add(), throwsA(isA<PortfolioException>().having((e) => e.code, 'code', PortfolioErrorCode.full)));
      final third = (await service.load('shop_1', 'barber_1')).firstWhere((p) => p.id == 'p03');
      await service.remove(third);
      expect(await service.count('shop_1', 'barber_1'), 11);
      expect((await add()).id, 'p03');
    });

    test('captions: edit, remove, too long; bad images are refused', () async {
      repo.signInAsDemoUser(_barber1);
      final p = await add(caption: 'Low fade');
      await service.setCaption(p, '  Mid   taper ');
      expect((await store.list('shop_1', 'barber_1')).single.caption, 'Mid taper');
      await service.setCaption(p, '');
      expect((await store.list('shop_1', 'barber_1')).single.caption, isNull);
      expect(service.cached('shop_1', 'barber_1')!.single.caption, isNull);
      await expectLater(service.setCaption(p, 'a' * 41),
          throwsA(isA<PortfolioException>().having((e) => e.code, 'code', PortfolioErrorCode.captionTooLong)));
      await expectLater(add(caption: 'a' * 41), throwsA(isA<PortfolioException>()));
      await expectLater(add(image: 'x' * (kMaxPortfolioImageChars + 1)),
          throwsA(isA<PortfolioException>().having((e) => e.code, 'code', PortfolioErrorCode.invalidImage)));
      await expectLater(add(image: '%%%not base64%%%'), throwsA(isA<PortfolioException>()));
    });

    test('Storage switch on: uploaded to portfolio/{shop}/{barber}/{id}.jpg, only imagePath stored', () async {
      store.storageSwitch = true;
      repo.signInAsDemoUser(_barber1);
      final p = await add(caption: 'Low fade');
      const path = 'portfolio/shop_1/barber_1/p01.jpg';
      expect((p.image, p.imagePath), (null, path));
      expect(storage.objects[path], _jpeg);
      expect((await store.list('shop_1', 'barber_1')).single.toCreateMap().containsKey('image'), isFalse);
      // Read back from Storage (fresh service: no cached bytes).
      final reader = PortfolioService(repository: repo, local: store, imageStorage: storage);
      final listed = (await reader.load('shop_1', 'barber_1')).single;
      expect(await reader.loadBytes(listed), _jpeg);
      expect(storage.downloads, 1);
      await reader.loadBytes(listed);
      expect(storage.downloads, 1, reason: 'cached');
      // Deleting removes the object too.
      await service.remove(p);
      await Future<void>.delayed(Duration.zero);
      expect(storage.objects.containsKey(path), isFalse);
    });

    test('Storage switch on but the upload fails (free plan): stored inline', () async {
      store.storageSwitch = true;
      storage.uploadError = StateError('no bucket');
      repo.signInAsDemoUser(_barber1);
      final p = await add();
      expect((p.image, p.imagePath), (_b64, null));
      expect(service.lastUploadError, isNotNull);
      expect((await store.list('shop_1', 'barber_1')).single.image, _b64);
    });

    test('no Storage (demo, tests): switch ignored', () async {
      store.storageSwitch = true;
      final noStorage = PortfolioService(repository: repo, local: store);
      repo.signInAsDemoUser(_barber1);
      final p = await noStorage.add(shopId: 'shop_1', barberId: 'barber_1', base64Jpeg: _b64);
      expect(p.hasInlineImage, isTrue);
    });

    test('counting does not download photos; galleries load once per session', () async {
      repo.signInAsDemoUser(_barber1);
      await add();
      final viewer = PortfolioService(repository: repo, local: store);
      store.listCalls = 0;
      expect(await viewer.count('shop_1', 'barber_1'), 1);
      expect(await viewer.count('shop_1', 'barber_2'), 0);
      expect(store.listCalls, 0);
      await viewer.load('shop_1', 'barber_1');
      await viewer.load('shop_1', 'barber_1');
      expect(store.listCalls, 1);
    });
  });

  group('Firestore store', () {
    late FakeFirebaseFirestore db;
    late FirestorePortfolioStore store;
    final photo = PortfolioPhoto(id: 'p01', shopId: 'shop_1', barberId: 'barber_1', createdAt: _now, caption: 'Low fade', image: _b64);

    setUp(() {
      db = FakeFirebaseFirestore();
      store = FirestorePortfolioStore(db);
    });

    DocumentReference<Map<String, dynamic>> doc(String id) =>
        db.doc('barbershops/shop_1/barbers/barber_1/portfolio/$id');

    test('create writes one document per photo at its slot; a taken slot is refused', () async {
      await store.create(photo);
      expect((await doc('p01').get()).data(),
          {'caption': 'Low fade', 'image': _b64, 'createdAt': '2026-11-15T09:00:00.000Z'});
      await expectLater(store.create(photo),
          throwsA(isA<PortfolioException>().having((e) => e.code, 'code', PortfolioErrorCode.slotTaken)));
    });

    test('list, count, caption update and delete', () async {
      await store.create(photo);
      await store.create(PortfolioPhoto(
          id: 'p02', shopId: 'shop_1', barberId: 'barber_1', createdAt: _now.add(const Duration(hours: 1)), image: _b64));
      // Stray documents with other ids are ignored.
      await doc('other').set({'image': _b64, 'createdAt': _now.toIso8601String()});
      expect((await store.list('shop_1', 'barber_1')).map((p) => p.id), ['p02', 'p01']);
      expect(await store.count('shop_1', 'barber_1'), 3);
      expect(await store.count('shop_1', 'barber_2'), 0);

      await store.updateCaption('shop_1', 'barber_1', 'p01', 'Taper');
      expect((await doc('p01').get()).data()!['caption'], 'Taper');
      await store.updateCaption('shop_1', 'barber_1', 'p01', null);
      expect((await doc('p01').get()).data()!.containsKey('caption'), isFalse);

      await store.delete('shop_1', 'barber_1', 'p01');
      expect((await doc('p01').get()).exists, isFalse);
    });

    test('the Storage switch is read from platformConfig/subscriptionPricing', () async {
      expect(await store.storageEnabled(), isFalse);
      await db.doc('platformConfig/subscriptionPricing').set({'storageReceipts': true});
      expect(await store.storageEnabled(), isTrue);
    });
  });
}
