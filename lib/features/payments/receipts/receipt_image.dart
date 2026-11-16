import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../models/subscription_payment.dart';

/// Longest side of a stored receipt photo.
const int kReceiptMaxDimension = 1600;

/// Largest stored JPEG (its base64 stays under [kMaxReceiptImageChars]).
const int kReceiptMaxBytes = 250 * 1024;

/// Smallest side we shrink to before giving up.
const int _kMinDimension = 480;

/// Re-encodes any image the `image` package can decode (JPEG, PNG, WebP,
/// GIF, BMP...) as a JPEG of at most [maxBytes], longest side at most
/// [maxDimension]: first lower JPEG quality (85..45), then smaller sizes.
/// Pure Dart (runs in an isolate via [compute]). Returns null when the
/// bytes are not an image or cannot be made small enough.
Uint8List? compressReceiptImage(Uint8List bytes,
    {int maxDimension = kReceiptMaxDimension, int maxBytes = kReceiptMaxBytes}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) return null;
  // Phone photos carry their rotation in EXIF.
  var image = img.bakeOrientation(decoded);
  int longest(img.Image i) => math.max(i.width, i.height);
  img.Image resizeTo(img.Image i, int side) => i.width >= i.height
      ? img.copyResize(i, width: side, interpolation: img.Interpolation.average)
      : img.copyResize(i, height: side, interpolation: img.Interpolation.average);

  if (longest(image) > maxDimension) image = resizeTo(image, maxDimension);
  while (true) {
    for (final quality in const [85, 75, 65, 55, 45]) {
      final jpeg = img.encodeJpg(image, quality: quality);
      if (jpeg.length <= maxBytes) return jpeg;
    }
    final side = (longest(image) * 0.75).round();
    if (side < _kMinDimension) return null;
    image = resizeTo(image, side);
  }
}

/// [compressReceiptImage] then base64 (what `receiptImage` stores).
String? receiptImageBase64(Uint8List bytes) {
  final jpeg = compressReceiptImage(bytes);
  if (jpeg == null) return null;
  final b64 = base64Encode(jpeg);
  return b64.length <= kMaxReceiptImageChars ? b64 : null;
}

/// Decodes a stored receipt photo (null when it is not valid base64).
Uint8List? decodeReceiptImage(String? base64) {
  if (base64 == null || base64.isEmpty) return null;
  try {
    return base64Decode(base64);
  } catch (_) {
    return null;
  }
}

/// A picked and compressed receipt photo.
class PickedReceiptImage {
  const PickedReceiptImage(this.jpeg, this.base64);
  final Uint8List jpeg;
  final String base64;
}

/// Thrown when the picked file is not an image we can shrink enough.
class ReceiptImageException implements Exception {
  const ReceiptImageException();
}

/// Lets the owner take or choose a receipt photo, then compresses it off
/// the UI thread. Returns null when they cancel.
class ReceiptImagePicker {
  ReceiptImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedReceiptImage?> pick({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      // The platform shrinks big photos first (cheap); the pure-Dart pass
      // below guarantees the final size.
      maxWidth: kReceiptMaxDimension.toDouble(),
      maxHeight: kReceiptMaxDimension.toDouble(),
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final b64 = await compute(receiptImageBase64, bytes);
    if (b64 == null) throw const ReceiptImageException();
    return PickedReceiptImage(base64Decode(b64), b64);
  }
}
