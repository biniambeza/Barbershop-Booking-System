// Shop location (maps): pure helpers for shop map pins, directions links
// and "near me" distances. No Flutter or plugin imports, so the model,
// the screens and the tests share them.

import 'dart:math' as math;

/// Centre of Addis Ababa (Meskel Square), where the pin picker starts when a
/// shop has no pin yet.
const double kAddisCenterLat = 9.0108;
const double kAddisCenterLng = 38.7613;

/// Rough bounding box of Ethiopia. A pin outside it is allowed (the rules
/// only check the world range) but the picker warns about it.
const double kEthiopiaMinLat = 3.0;
const double kEthiopiaMaxLat = 15.0;
const double kEthiopiaMinLng = 33.0;
const double kEthiopiaMaxLng = 48.0;

/// OpenStreetMap standard tiles (no API key). The tile usage policy asks
/// for a real User-Agent ([kMapUserAgentPackage]) and visible attribution.
const String kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kMapUserAgentPackage = 'et.crownblade.app';
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// True when both values are finite and inside the world range
/// (latitude -90..90, longitude -180..180). Firestore rules check the same.
bool isValidShopCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (!latitude.isFinite || !longitude.isFinite) return false;
  return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
}

/// True when the pin lies roughly inside Ethiopia.
bool isInEthiopia(double latitude, double longitude) =>
    latitude >= kEthiopiaMinLat &&
    latitude <= kEthiopiaMaxLat &&
    longitude >= kEthiopiaMinLng &&
    longitude <= kEthiopiaMaxLng;

/// Coordinates rounded to 6 decimals (about 10 cm) for links and storage.
double roundCoordinate(double value) => (value * 1e6).roundToDouble() / 1e6;

String _coord(double v) {
  final s = roundCoordinate(v).toStringAsFixed(6);
  // Trim trailing zeros but keep at least one decimal: 9.010800 -> 9.0108.
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '.0');
}

/// The text searched for when a shop has no pin: landmark first (that is
/// how people in Addis find places), then address, sub-city and city.
String shopSearchQuery({
  required String address,
  String? landmark,
  String subCity = '',
  String city = '',
}) {
  final parts = <String>[];
  for (final p in [landmark ?? '', address, subCity, city]) {
    final t = p.trim();
    if (t.isNotEmpty && !parts.any((x) => x.toLowerCase() == t.toLowerCase())) parts.add(t);
  }
  return parts.join(', ');
}

/// Google Maps directions link (opens the Google Maps app when installed,
/// else the browser). With a pin: directions to the exact point. Without:
/// a search for [shopSearchQuery].
/// See https://developers.google.com/maps/documentation/urls/get-started.
Uri directionsUri({
  double? latitude,
  double? longitude,
  required String address,
  String? landmark,
  String subCity = '',
  String city = '',
}) {
  if (isValidShopCoordinate(latitude, longitude)) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${_coord(latitude!)},${_coord(longitude!)}',
    });
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': shopSearchQuery(address: address, landmark: landmark, subCity: subCity, city: city),
  });
}

/// A `geo:` link for the device's default maps app (Android), used when the
/// Google Maps link cannot be opened. With a pin it drops a labelled marker;
/// without one it searches for [shopSearchQuery].
Uri geoUri({
  double? latitude,
  double? longitude,
  required String address,
  String? label,
  String? landmark,
  String subCity = '',
  String city = '',
}) {
  if (isValidShopCoordinate(latitude, longitude)) {
    final point = '${_coord(latitude!)},${_coord(longitude!)}';
    final name = (label ?? '').trim();
    final q = name.isEmpty ? point : '$point($name)';
    return Uri.parse('geo:$point?q=${Uri.encodeQueryComponent(q)}');
  }
  final q = shopSearchQuery(address: address, landmark: landmark, subCity: subCity, city: city);
  return Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(q)}');
}

/// Great-circle distance in kilometres (haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Sorts items by distance from (lat, lng), nearest first. Items without a
/// pin ([locate] returns null) keep their order after the located ones.
List<T> sortByDistance<T>(
  Iterable<T> items,
  double latitude,
  double longitude,
  (double, double)? Function(T item) locate,
) {
  final located = <(T, double)>[];
  final rest = <T>[];
  for (final item in items) {
    final p = locate(item);
    if (p == null || !isValidShopCoordinate(p.$1, p.$2)) {
      rest.add(item);
    } else {
      located.add((item, distanceKm(latitude, longitude, p.$1, p.$2)));
    }
  }
  // List.sort is not stable: tie-break on the original position.
  final indexed = [for (var i = 0; i < located.length; i++) (i, located[i])];
  indexed.sort((a, b) {
    final c = a.$2.$2.compareTo(b.$2.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2.$1, ...rest];
}
