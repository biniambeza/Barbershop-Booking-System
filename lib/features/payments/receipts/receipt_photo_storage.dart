// Receipt photos in Firebase Storage (Blaze plan only).
//
// Free plan (Spark): there is no Storage bucket, so photos stay inline in the
// receipt document (`receiptImage`, base64). When the admin turns on
// `storageReceipts` in platformConfig/subscriptionPricing, the owner's app
// uploads the compressed JPEG to `receipts/{shopId}/{paymentId}.jpg` and
// saves only `imagePath` on the receipt. Any upload failure (no bucket,
// permission, network, timeout) falls back to inline automatically.
//
// storage.rules: the shop's owner may create (not overwrite or delete) an
// image under receipts/{shopId}/ of less than 2 MB and read it back; admins
// read all receipts.

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Largest receipt object storage.rules accepts (and the app reads).
const int kReceiptStorageMaxBytes = 2 * 1024 * 1024;

/// How long an upload may take before the app stores the photo inline.
const Duration kReceiptUploadTimeout = Duration(seconds: 30);

/// How long a photo download may take before the viewer shows an error.
const Duration kReceiptDownloadTimeout = Duration(seconds: 30);

/// Storage object of a receipt photo: `receipts/{shopId}/{paymentId}.jpg`.
String receiptStoragePath(String shopId, String paymentId) => 'receipts/$shopId/$paymentId.jpg';

/// Where receipt photos are uploaded to and read from.
abstract class ReceiptImageStorage {
  /// Uploads [jpeg] to [path] (content type image/jpeg). Throws on failure.
  Future<void> upload(String path, Uint8List jpeg);

  /// The bytes at [path]. Throws when missing or unreadable.
  Future<Uint8List> download(String path);
}

/// Firebase Storage (default bucket of the Firebase app).
class FirebaseReceiptImageStorage implements ReceiptImageStorage {
  FirebaseReceiptImageStorage([FirebaseStorage? storage]) : _storage = storage;

  FirebaseStorage? _storage;

  FirebaseStorage get _fs {
    final existing = _storage;
    if (existing != null) return existing;
    // Fail fast (and fall back to inline) instead of retrying for minutes.
    final fs = FirebaseStorage.instance
      ..setMaxUploadRetryTime(const Duration(seconds: 15))
      ..setMaxOperationRetryTime(const Duration(seconds: 15));
    return _storage = fs;
  }

  @override
  Future<void> upload(String path, Uint8List jpeg) async {
    final task = _fs.ref(path).putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    try {
      await task.timeout(kReceiptUploadTimeout);
    } on TimeoutException {
      await task.cancel().catchError((Object _) => false);
      rethrow;
    }
  }

  @override
  Future<Uint8List> download(String path) async {
    final data = await _fs.ref(path).getData(kReceiptStorageMaxBytes).timeout(kReceiptDownloadTimeout);
    if (data == null || data.isEmpty) throw StateError('Receipt photo $path is empty');
    return data;
  }
}

/// In-memory storage for tests (and demos): uploads can be made to fail.
class MemoryReceiptImageStorage implements ReceiptImageStorage {
  final Map<String, Uint8List> objects = {};

  /// When set, [upload] throws it (e.g. a missing bucket).
  Object? uploadError;

  /// When set, [download] throws it.
  Object? downloadError;

  int uploads = 0;
  int downloads = 0;

  @override
  Future<void> upload(String path, Uint8List jpeg) async {
    uploads++;
    final error = uploadError;
    if (error != null) throw error;
    // storage.rules: create only, never overwrite.
    if (objects.containsKey(path)) throw StateError('storage/unauthorized: $path exists');
    objects[path] = Uint8List.fromList(jpeg);
  }

  @override
  Future<Uint8List> download(String path) async {
    downloads++;
    final error = downloadError;
    if (error != null) throw error;
    final data = objects[path];
    if (data == null) throw StateError('storage/object-not-found: $path');
    return data;
  }
}
