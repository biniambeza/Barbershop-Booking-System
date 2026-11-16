// Barber portfolio photos (haircut gallery).
//
// Firestore: barbershops/{shopId}/barbers/{barberId}/portfolio/{photoId}
// (public read: it is marketing). One photo per document, no personal data:
//
//   caption    string, 1..40 characters (optional style name, "Low fade")
//   image      string, base64 JPEG, at most [kMaxPortfolioImageChars]
//              (free Spark plan; about 150 KB of JPEG)
//   imagePath  string, exactly portfolio/{shopId}/{barberId}/{photoId}.jpg
//              (Blaze, Cloud Storage); exactly one of image / imagePath
//   createdAt  string, ISO-8601 UTC
//
// The document id is a slot, p01..p12, so a barber can never have more than
// [kMaxPortfolioPhotos] photos (firestore.rules only accepts those ids).

import 'dart:convert';
import 'dart:typed_data';

/// Most photos one barber can show.
const int kMaxPortfolioPhotos = 12;

/// Longest style name.
const int kMaxPortfolioCaptionLength = 40;

/// Longest inline base64 image (a ~150 KB JPEG is ~205,000 characters), so
/// each document stays far below Firestore's 1 MiB limit.
const int kMaxPortfolioImageChars = 210000;

/// Subcollection name under barbershops/{shopId}/barbers/{barberId}.
const String kPortfolioCollection = 'portfolio';

/// Slot id [index] (1..[kMaxPortfolioPhotos]): p01..p12.
String portfolioSlotId(int index) => 'p${index.toString().padLeft(2, '0')}';

/// The ids firestore.rules accepts: p01..p12.
final RegExp kPortfolioPhotoIdPattern = RegExp(r'^p(0[1-9]|1[0-2])$');

bool isPortfolioPhotoId(String id) => kPortfolioPhotoIdPattern.hasMatch(id);

/// The first slot not in [takenIds] (lowest number), or null when all
/// [kMaxPortfolioPhotos] are used.
String? nextFreePortfolioSlot(Iterable<String> takenIds) {
  final taken = takenIds.toSet();
  for (var i = 1; i <= kMaxPortfolioPhotos; i++) {
    final id = portfolioSlotId(i);
    if (!taken.contains(id)) return id;
  }
  return null;
}

/// Cloud Storage object of a photo (Blaze only).
String portfolioStoragePath(String shopId, String barberId, String photoId) =>
    'portfolio/$shopId/$barberId/$photoId.jpg';

/// Trims a style name and collapses inner whitespace; null when empty.
String? normalizePortfolioCaption(String? raw) {
  if (raw == null) return null;
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text.isEmpty ? null : text;
}

/// A normalized caption is valid when absent or 1..[kMaxPortfolioCaptionLength].
bool isValidPortfolioCaption(String? caption) => caption == null || caption.length <= kMaxPortfolioCaptionLength;

/// One haircut photo of a barber.
class PortfolioPhoto {
  PortfolioPhoto({
    required this.id,
    required this.shopId,
    required this.barberId,
    required this.createdAt,
    this.caption,
    this.image,
    this.imagePath,
  });

  /// Slot id, p01..p12.
  final String id;
  final String shopId;
  final String barberId;

  /// Optional style name ("Low fade").
  final String? caption;

  /// Inline base64 JPEG (free plan).
  final String? image;

  /// Cloud Storage object (Blaze).
  final String? imagePath;
  final DateTime createdAt;

  bool get hasInlineImage => image != null && image!.isNotEmpty;
  bool get hasStoredImage => !hasInlineImage && imagePath != null && imagePath!.isNotEmpty;

  /// Identifies this exact image (a slot can be reused after a delete).
  String get cacheKey => '$shopId/$barberId/$id@${createdAt.microsecondsSinceEpoch}';

  Uint8List? _decoded;
  bool _decodeTried = false;

  /// The inline JPEG bytes (decoded once), or null.
  Uint8List? get inlineBytes {
    if (!_decodeTried) {
      _decodeTried = true;
      if (hasInlineImage) {
        try {
          _decoded = base64Decode(image!);
        } catch (_) {
          _decoded = null;
        }
      }
    }
    return _decoded;
  }

  /// What the app writes on create (see the file comment).
  Map<String, dynamic> toCreateMap() => {
        if (caption != null) 'caption': caption,
        if (hasInlineImage) 'image': image else if (imagePath != null) 'imagePath': imagePath,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory PortfolioPhoto.fromMap(Map<String, dynamic> map, {required String id, required String shopId, required String barberId}) {
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    DateTime created;
    final raw = map['createdAt'];
    if (raw is String) {
      created = DateTime.tryParse(raw)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    } else {
      try {
        // A Firestore Timestamp (written by a script or the console).
        created = (raw as dynamic).toDate().toUtc() as DateTime;
      } catch (_) {
        created = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }
    return PortfolioPhoto(
      id: id,
      shopId: shopId,
      barberId: barberId,
      caption: str(map['caption']),
      image: str(map['image']),
      imagePath: str(map['imagePath']),
      createdAt: created,
    );
  }

  PortfolioPhoto copyWith({String? caption, bool clearCaption = false, String? image, String? imagePath, bool clearImage = false}) =>
      PortfolioPhoto(
        id: id,
        shopId: shopId,
        barberId: barberId,
        createdAt: createdAt,
        caption: clearCaption ? null : (caption ?? this.caption),
        image: clearImage ? null : (image ?? this.image),
        imagePath: imagePath ?? this.imagePath,
      );

  /// The same photo stored in Cloud Storage at [path] (no inline bytes).
  PortfolioPhoto withStoredImage(String path) => copyWith(imagePath: path, clearImage: true);

  /// Newest first; ties by id.
  static int newestFirst(PortfolioPhoto a, PortfolioPhoto b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }
}
