import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/portfolio_photo.dart';
import '../../models/user_model.dart';
import '../../services/app_repository.dart';
import 'portfolio_image.dart';

export '../../models/portfolio_photo.dart';
export 'portfolio_image.dart';

/// Why a portfolio change was refused.
enum PortfolioErrorCode { notAllowed, full, captionTooLong, invalidImage, slotTaken, notFound }

class PortfolioException implements Exception {
  PortfolioException(this.code);
  final PortfolioErrorCode code;

  @override
  String toString() => 'PortfolioException(${code.name})';
}

/// Where portfolio documents live: [FirestorePortfolioStore] in production,
/// [LocalPortfolioStore] in DEMO_MODE and tests.
abstract class PortfolioStore {
  /// The barber's photos (all of them; at most 12 documents).
  Future<List<PortfolioPhoto>> list(String shopId, String barberId);

  /// How many photos the barber has, without downloading them.
  Future<int> count(String shopId, String barberId);

  /// Creates [photo]; throws [PortfolioException] slotTaken when its slot
  /// is already used.
  Future<void> create(PortfolioPhoto photo);

  /// Sets or (null) removes the caption.
  Future<void> updateCaption(String shopId, String barberId, String photoId, String? caption);

  Future<void> delete(String shopId, String barberId, String photoId);

  /// The admin's Storage switch (platformConfig/subscriptionPricing
  /// .storageReceipts). False when it cannot be read.
  Future<bool> storageEnabled();
}

/// Firestore access (see portfolio_photo.dart for the document shape):
///
///  * list:   get of barbershops/{s}/barbers/{b}/portfolio (public read),
///            only when a gallery opens.
///  * count:  count() aggregate of the same collection (no image bytes).
///  * create: transaction: get portfolio/{pNN}, then set it if missing.
///  * caption: update {caption} or {caption: delete}.
///  * delete: delete portfolio/{pNN}.
///  * storage switch: get platformConfig/subscriptionPricing (owners and
///            admins may read it; for a barber the read is refused and the
///            photo is stored inline).
class FirestorePortfolioStore implements PortfolioStore {
  FirestorePortfolioStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String shopId, String barberId) =>
      _db.collection('barbershops').doc(shopId).collection('barbers').doc(barberId).collection(kPortfolioCollection);

  @override
  Future<List<PortfolioPhoto>> list(String shopId, String barberId) async {
    final qs = await _col(shopId, barberId).get();
    return [
      for (final d in qs.docs)
        if (isPortfolioPhotoId(d.id)) PortfolioPhoto.fromMap(d.data(), id: d.id, shopId: shopId, barberId: barberId),
    ]..sort(PortfolioPhoto.newestFirst);
  }

  @override
  Future<int> count(String shopId, String barberId) async {
    final snap = await _col(shopId, barberId).count().get();
    return snap.count ?? 0;
  }

  @override
  Future<void> create(PortfolioPhoto photo) async {
    final ref = _col(photo.shopId, photo.barberId).doc(photo.id);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) throw PortfolioException(PortfolioErrorCode.slotTaken);
      tx.set(ref, photo.toCreateMap());
    });
  }

  @override
  Future<void> updateCaption(String shopId, String barberId, String photoId, String? caption) async {
    try {
      await _col(shopId, barberId).doc(photoId).update({'caption': caption ?? FieldValue.delete()});
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') throw PortfolioException(PortfolioErrorCode.notFound);
      rethrow;
    }
  }

  @override
  Future<void> delete(String shopId, String barberId, String photoId) =>
      _col(shopId, barberId).doc(photoId).delete();

  @override
  Future<bool> storageEnabled() async {
    try {
      final snap = await _db.doc('platformConfig/subscriptionPricing').get();
      return snap.data()?['storageReceipts'] == true;
    } catch (_) {
      return false;
    }
  }
}

/// In-memory portfolio (DEMO_MODE builds and tests).
class LocalPortfolioStore implements PortfolioStore {
  final Map<String, Map<String, PortfolioPhoto>> _byBarber = {};

  /// What [storageEnabled] returns (tests).
  bool storageSwitch = false;

  /// Calls of [list] (tests check that listing shops loads nothing).
  int listCalls = 0;

  String _key(String shopId, String barberId) => '$shopId/$barberId';

  void clear() => _byBarber.clear();

  @override
  Future<List<PortfolioPhoto>> list(String shopId, String barberId) async {
    listCalls++;
    return (_byBarber[_key(shopId, barberId)]?.values.toList() ?? <PortfolioPhoto>[])..sort(PortfolioPhoto.newestFirst);
  }

  @override
  Future<int> count(String shopId, String barberId) async => _byBarber[_key(shopId, barberId)]?.length ?? 0;

  @override
  Future<void> create(PortfolioPhoto photo) async {
    final slots = _byBarber.putIfAbsent(_key(photo.shopId, photo.barberId), () => {});
    if (slots.containsKey(photo.id)) throw PortfolioException(PortfolioErrorCode.slotTaken);
    if (!isPortfolioPhotoId(photo.id)) throw PortfolioException(PortfolioErrorCode.full);
    slots[photo.id] = photo;
  }

  @override
  Future<void> updateCaption(String shopId, String barberId, String photoId, String? caption) async {
    final slots = _byBarber[_key(shopId, barberId)];
    final current = slots?[photoId];
    if (slots == null || current == null) throw PortfolioException(PortfolioErrorCode.notFound);
    slots[photoId] = current.copyWith(caption: caption, clearCaption: caption == null);
  }

  @override
  Future<void> delete(String shopId, String barberId, String photoId) async {
    _byBarber[_key(shopId, barberId)]?.remove(photoId);
  }

  @override
  Future<bool> storageEnabled() async => storageSwitch;
}

/// Barber portfolio photos.
///
///  * Customers (anyone): [load] a barber's photos when the gallery opens
///    (cached for the session), [count] for the shop page (no image bytes),
///    [loadBytes] for each photo.
///  * The barber and their shop's owner: [add] (compressed JPEG; inline in
///    Firestore, or Cloud Storage when the admin switch is on, falling back
///    to inline), [setCaption], [remove].
class PortfolioService extends ChangeNotifier {
  PortfolioService({AppRepository? repository, PortfolioStore? store, LocalPortfolioStore? local, PortfolioImageStorage? imageStorage})
      : _repo = repository ?? AppRepository.instance,
        _storeOverride = store,
        _imageStorageOverride = imageStorage {
    this.local = local ?? LocalPortfolioStore();
  }

  static PortfolioService? _instance;
  static PortfolioService get instance => _instance ??= PortfolioService();

  /// Tests: replaces the shared instance (null restores a fresh default).
  @visibleForTesting
  static set instance(PortfolioService? service) => _instance = service;

  final AppRepository _repo;
  final PortfolioStore? _storeOverride;
  final PortfolioImageStorage? _imageStorageOverride;
  PortfolioStore? _cloud;
  PortfolioImageStorage? _firebaseImages;

  late final LocalPortfolioStore local;

  PortfolioStore get store {
    if (_storeOverride != null) return _storeOverride;
    if (!_repo.isFirebaseAttached) return local;
    return _cloud ??= FirestorePortfolioStore(FirebaseFirestore.instance);
  }

  /// Firebase Storage once Firebase is attached; null in DEMO_MODE and
  /// tests without an override (photos stay inline).
  PortfolioImageStorage? get imageStorage {
    if (_imageStorageOverride != null) return _imageStorageOverride;
    if (!_repo.isFirebaseAttached) return null;
    return _firebaseImages ??= FirebasePortfolioImageStorage();
  }

  /// Why the last Storage upload fell back to inline (null: it did not).
  Object? lastUploadError;

  final Map<String, List<PortfolioPhoto>> _photos = {};
  final Map<String, Future<List<PortfolioPhoto>>> _loading = {};
  final Map<String, int> _counts = {};
  final Map<String, Future<int>> _counting = {};
  final Map<String, Future<Uint8List>> _bytes = {};

  String _key(String shopId, String barberId) => '$shopId/$barberId';

  /// Forgets everything loaded (tests, sign-out).
  void clearCache() {
    _photos.clear();
    _loading.clear();
    _counts.clear();
    _counting.clear();
    _bytes.clear();
    notifyListeners();
  }

  /// The barber's photos loaded so far (newest first), or null.
  List<PortfolioPhoto>? cached(String shopId, String barberId) => _photos[_key(shopId, barberId)];

  /// Loads the barber's photos (once per session unless [force]).
  Future<List<PortfolioPhoto>> load(String shopId, String barberId, {bool force = false}) {
    final key = _key(shopId, barberId);
    final have = _photos[key];
    if (have != null && !force) return Future.value(have);
    final running = _loading[key];
    if (running != null && !force) return running;
    final future = store.list(shopId, barberId).then((list) {
      _photos[key] = List.unmodifiable(list);
      _counts[key] = list.length;
      notifyListeners();
      return _photos[key]!;
    });
    _loading[key] = future;
    future.whenComplete(() {
      if (identical(_loading[key], future)) _loading.remove(key);
    }).ignore();
    return future;
  }

  /// How many photos the barber has (an aggregate query, no image bytes;
  /// cached).
  Future<int> count(String shopId, String barberId) {
    final key = _key(shopId, barberId);
    final loaded = _photos[key];
    if (loaded != null) return Future.value(loaded.length);
    final known = _counts[key];
    if (known != null) return Future.value(known);
    return _counting[key] ??= () async {
      try {
        final n = await store.count(shopId, barberId);
        if (_counts[key] != n) {
          _counts[key] = n;
          notifyListeners();
        }
        return n;
      } catch (e) {
        debugPrint('Could not count portfolio photos of $key: $e');
        return 0;
      } finally {
        _counting.remove(key);
      }
    }();
  }

  /// Cached count, or null when not known yet.
  int? knownCount(String shopId, String barberId) =>
      _photos[_key(shopId, barberId)]?.length ?? _counts[_key(shopId, barberId)];

  /// The signed-in barber of this profile, or the owner of its shop.
  bool canManage(String shopId, String barberId) {
    final user = _repo.currentUser;
    if (user == null) return false;
    if (user.role == UserRole.barbershopOwner) return user.shopId == shopId;
    if (user.role == UserRole.barber) return user.shopId == shopId && user.barberId == barberId;
    return false;
  }

  void _requireManage(String shopId, String barberId) {
    if (_repo.currentUser == null) throw AppStateException(AppErrorCode.signInRequired);
    if (!canManage(shopId, barberId)) throw PortfolioException(PortfolioErrorCode.notAllowed);
  }

  void _put(String shopId, String barberId, List<PortfolioPhoto> list) {
    final key = _key(shopId, barberId);
    _photos[key] = List.unmodifiable(list..sort(PortfolioPhoto.newestFirst));
    _counts[key] = list.length;
    notifyListeners();
  }

  /// Adds a photo ([base64Jpeg] from [PortfolioImagePicker]) with an
  /// optional style name. Throws [PortfolioException] when the barber
  /// already has 12 photos, the caption is too long, or the image is not
  /// valid.
  Future<PortfolioPhoto> add({
    required String shopId,
    required String barberId,
    required String base64Jpeg,
    String? caption,
  }) async {
    _requireManage(shopId, barberId);
    final text = normalizePortfolioCaption(caption);
    if (!isValidPortfolioCaption(text)) throw PortfolioException(PortfolioErrorCode.captionTooLong);
    final image = base64Jpeg.trim();
    if (image.isEmpty || image.length > kMaxPortfolioImageChars) throw PortfolioException(PortfolioErrorCode.invalidImage);
    var photo = PortfolioPhoto(id: '', shopId: shopId, barberId: barberId, createdAt: _repo.nowUtc(), caption: text, image: image);
    if (photo.inlineBytes == null) throw PortfolioException(PortfolioErrorCode.invalidImage);

    // Fresh list: the slot must be free on the server, not just here.
    final current = await load(shopId, barberId, force: true);
    final slot = nextFreePortfolioSlot(current.map((p) => p.id));
    if (slot == null) throw PortfolioException(PortfolioErrorCode.full);
    photo = PortfolioPhoto(
        id: slot, shopId: shopId, barberId: barberId, createdAt: photo.createdAt, caption: text, image: image);

    final storage = imageStorage;
    PortfolioPhoto toWrite = photo;
    if (storage != null && await store.storageEnabled()) {
      toWrite = await _upload(storage, photo);
    }
    try {
      await store.create(toWrite);
    } on FirebaseException catch (e) {
      // Rules without imagePath support (yet): store the photo inline.
      if (e.code == 'permission-denied' && toWrite.hasStoredImage) {
        debugPrint('Portfolio ${toWrite.id}: imagePath refused, storing the photo inline instead.');
        await store.create(photo);
        toWrite = photo;
      } else {
        rethrow;
      }
    }
    _put(shopId, barberId, [...current, toWrite]);
    return toWrite;
  }

  /// Blaze: uploads to portfolio/{shopId}/{barberId}/{photoId}.jpg and
  /// returns the photo with imagePath; on any failure, the inline photo.
  Future<PortfolioPhoto> _upload(PortfolioImageStorage storage, PortfolioPhoto photo) async {
    final jpeg = photo.inlineBytes;
    if (jpeg == null || jpeg.length > kPortfolioStorageMaxBytes) return photo;
    final path = portfolioStoragePath(photo.shopId, photo.barberId, photo.id);
    try {
      await storage.upload(path, jpeg).timeout(kPortfolioUploadTimeout + const Duration(seconds: 5));
      lastUploadError = null;
      final stored = photo.withStoredImage(path);
      _bytes[stored.cacheKey] = Future.value(jpeg);
      return stored;
    } catch (e) {
      lastUploadError = e;
      debugPrint('Portfolio upload to $path failed, storing it inline instead: $e');
      return photo;
    }
  }

  /// Sets (or with an empty [caption], removes) the style name.
  Future<void> setCaption(PortfolioPhoto photo, String? caption) async {
    _requireManage(photo.shopId, photo.barberId);
    final text = normalizePortfolioCaption(caption);
    if (!isValidPortfolioCaption(text)) throw PortfolioException(PortfolioErrorCode.captionTooLong);
    await store.updateCaption(photo.shopId, photo.barberId, photo.id, text);
    final list = [...?cached(photo.shopId, photo.barberId)];
    final i = list.indexWhere((p) => p.id == photo.id);
    if (i >= 0) {
      list[i] = list[i].copyWith(caption: text, clearCaption: text == null);
      _put(photo.shopId, photo.barberId, list);
    }
  }

  /// Deletes the photo (and its Storage object, best effort).
  Future<void> remove(PortfolioPhoto photo) async {
    _requireManage(photo.shopId, photo.barberId);
    await store.delete(photo.shopId, photo.barberId, photo.id);
    final path = photo.imagePath;
    final storage = imageStorage;
    if (photo.hasStoredImage && path != null && storage != null) {
      storage.delete(path).catchError((Object e) => debugPrint('Could not delete $path: $e'));
    }
    _bytes.remove(photo.cacheKey);
    _put(photo.shopId, photo.barberId, [...?cached(photo.shopId, photo.barberId)]..removeWhere((p) => p.id == photo.id));
  }

  /// The photo's JPEG: decoded inline base64, or downloaded from Storage
  /// (cached; a failed download is retried on the next call).
  Future<Uint8List> loadBytes(PortfolioPhoto photo) {
    final inline = photo.inlineBytes;
    if (inline != null) return Future.value(inline);
    final path = photo.imagePath;
    final storage = imageStorage;
    if (!photo.hasStoredImage || path == null || storage == null) {
      return Future.error(const PortfolioImageException());
    }
    final key = photo.cacheKey;
    final cached = _bytes[key];
    if (cached != null) return cached;
    if (_bytes.length >= 60) _bytes.remove(_bytes.keys.first);
    final future = storage.download(path);
    _bytes[key] = future;
    future.then((_) {}, onError: (Object e) {
      debugPrint('Could not load portfolio photo $path: $e');
      if (identical(_bytes[key], future)) _bytes.remove(key);
    });
    return future;
  }
}
