import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rebook_service.dart';

/// Where a customer's favourite barbers are kept: on this device, per
/// account (like the shop favourites, nothing goes to Firestore, so it
/// works on the free plan and needs no security rules).
abstract class FavoriteBarbersStore {
  /// The saved favourites of [uid], or an empty list.
  Future<List<FavoriteBarber>> load(String uid);

  Future<void> save(String uid, List<FavoriteBarber> favorites);
}

/// [FavoriteBarbersStore] backed by shared_preferences, one key per
/// account. Failures (no plugin, broken storage) are logged and ignored:
/// the favourites then last until the app is closed.
class PrefsFavoriteBarbersStore implements FavoriteBarbersStore {
  static String keyFor(String uid) => 'favoriteBarbers.$uid';

  @override
  Future<List<FavoriteBarber>> load(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return FavoriteBarber.decodeList(prefs.getString(keyFor(uid)));
    } catch (e) {
      debugPrint('Could not read favourite barbers: $e');
      return const [];
    }
  }

  @override
  Future<void> save(String uid, List<FavoriteBarber> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(uid), FavoriteBarber.encodeList(favorites));
    } catch (e) {
      debugPrint('Could not save favourite barbers: $e');
    }
  }
}

/// In-memory [FavoriteBarbersStore] (tests).
class MemoryFavoriteBarbersStore implements FavoriteBarbersStore {
  final Map<String, String> saved = {};

  @override
  Future<List<FavoriteBarber>> load(String uid) async => FavoriteBarber.decodeList(saved[uid]);

  @override
  Future<void> save(String uid, List<FavoriteBarber> favorites) async {
    saved[uid] = FavoriteBarber.encodeList(favorites);
  }
}
