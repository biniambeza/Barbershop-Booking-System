// Portfolio photos: compression (the receipt-photo pipeline with smaller
// limits) and Cloud Storage access (Blaze only).

import 'dart:async';
import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/portfolio_photo.dart';
import '../payments/receipts/receipt_image.dart' show compressReceiptImage;

/// Longest side of a stored portfolio photo (sharp on a phone screen).
const int kPortfolioMaxDimension = 1280;

/// Target size of a stored JPEG: ~150 KB (base64 under [kMaxPortfolioImageChars]).
const int kPortfolioMaxBytes = 150 * 1024;

/// Largest object storage.rules accepts for a portfolio photo.
const int kPortfolioStorageMaxBytes = 1024 * 1024;

const Duration kPortfolioUploadTimeout = Duration(seconds: 30);
const Duration kPortfolioDownloadTimeout = Duration(seconds: 30);

/// Any decodable image -> JPEG of at most [kPortfolioMaxBytes] as base64,
/// or null when it is not an image or cannot be made small enough. Pure
/// Dart (runs in an isolate via [compute]).
String? portfolioImageBase64(Uint8List bytes) {
  final jpeg = compressReceiptImage(bytes, maxDimension: kPortfolioMaxDimension, maxBytes: kPortfolioMaxBytes);
  if (jpeg == null) return null;
  final b64 = base64Encode(jpeg);
  return b64.length <= kMaxPortfolioImageChars ? b64 : null;
}

/// Thrown when the picked file is not an image we can shrink enough.
class PortfolioImageException implements Exception {
  const PortfolioImageException();
}

/// Takes or chooses a photo and compresses it off the UI thread. Returns
/// the base64 JPEG, or null when the person cancels.
class PortfolioImagePicker {
  PortfolioImagePicker({ImagePicker? picker}) : _picker = picker;

  ImagePicker? _picker;

  Future<String?> pick({required bool camera}) async {
    final file = await (_picker ??= ImagePicker()).pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: kPortfolioMaxDimension.toDouble(),
      maxHeight: kPortfolioMaxDimension.toDouble(),
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final b64 = await compute(portfolioImageBase64, bytes);
    if (b64 == null) throw const PortfolioImageException();
    return b64;
  }
}

/// Where portfolio photos live when Storage is on.
abstract class PortfolioImageStorage {
  /// Uploads [jpeg] to [path] (image/jpeg). Throws on failure.
  Future<void> upload(String path, Uint8List jpeg);

  /// The bytes at [path]. Throws when missing or unreadable.
  Future<Uint8List> download(String path);

  /// Removes [path]; a missing object is not an error.
  Future<void> delete(String path);
}

/// Firebase Storage (default bucket).
class FirebasePortfolioImageStorage implements PortfolioImageStorage {
  FirebasePortfolioImageStorage([FirebaseStorage? storage]) : _storage = storage;

  FirebaseStorage? _storage;

  FirebaseStorage get _fs => _storage ??= FirebaseStorage.instance
    ..setMaxUploadRetryTime(const Duration(seconds: 15))
    ..setMaxOperationRetryTime(const Duration(seconds: 15));

  @override
  Future<void> upload(String path, Uint8List jpeg) async {
    final task = _fs.ref(path).putData(
          jpeg,
          SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public, max-age=86400'),
        );
    try {
      await task.timeout(kPortfolioUploadTimeout);
    } on TimeoutException {
      await task.cancel().catchError((Object _) => false);
      rethrow;
    }
  }

  @override
  Future<Uint8List> download(String path) async {
    final data = await _fs.ref(path).getData(kPortfolioStorageMaxBytes).timeout(kPortfolioDownloadTimeout);
    if (data == null || data.isEmpty) throw StateError('Portfolio photo $path is empty');
    return data;
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _fs.ref(path).delete().timeout(kPortfolioUploadTimeout);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

/// In-memory storage for tests; uploads and downloads can be made to fail.
class MemoryPortfolioImageStorage implements PortfolioImageStorage {
  final Map<String, Uint8List> objects = {};
  Object? uploadError;
  Object? downloadError;
  int uploads = 0;
  int downloads = 0;

  @override
  Future<void> upload(String path, Uint8List jpeg) async {
    uploads++;
    final error = uploadError;
    if (error != null) throw error;
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

  @override
  Future<void> delete(String path) async => objects.remove(path);
}
