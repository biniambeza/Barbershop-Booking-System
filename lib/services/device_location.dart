// Shop location (maps): the device's current position (geolocator), behind
// a small interface so screens never call the plugin directly and tests can
// swap in a fake ([DeviceLocator.instance]).
//
// Works on Android, iOS and the web (geolocator_web uses the browser's
// Geolocation API). Permission strings: AndroidManifest.xml
// (ACCESS_COARSE/FINE_LOCATION) and ios/Runner/Info.plist
// (NSLocationWhenInUseUsageDescription).

import 'package:geolocator/geolocator.dart';

enum DeviceLocationStatus {
  ok,

  /// Location services (GPS) are switched off.
  serviceDisabled,

  /// The user said no this time; asking again is allowed.
  denied,

  /// The user said "don't ask again" (or iOS Settings): only the system
  /// settings can turn it back on.
  deniedForever,

  /// Anything else (timeout, unsupported platform, plugin error).
  error,
}

class DeviceLocationResult {
  final DeviceLocationStatus status;
  final double? latitude;
  final double? longitude;

  const DeviceLocationResult.ok(double this.latitude, double this.longitude) : status = DeviceLocationStatus.ok;

  const DeviceLocationResult.failed(this.status)
      : latitude = null,
        longitude = null;

  bool get isOk => status == DeviceLocationStatus.ok && latitude != null && longitude != null;
}

abstract class DeviceLocator {
  /// The locator the app uses; tests replace it with a fake.
  static DeviceLocator instance = GeolocatorDeviceLocator();

  /// Asks for permission when needed and returns the current position.
  /// Never throws.
  Future<DeviceLocationResult> currentPosition();

  /// Opens the app's system settings (after "don't ask again"); false when
  /// not possible (e.g. on the web).
  Future<bool> openSettings();
}

class GeolocatorDeviceLocator implements DeviceLocator {
  @override
  Future<DeviceLocationResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult.failed(DeviceLocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult.failed(DeviceLocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        return const DeviceLocationResult.failed(DeviceLocationStatus.denied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return DeviceLocationResult.ok(pos.latitude, pos.longitude);
    } on PermissionDeniedException {
      return const DeviceLocationResult.failed(DeviceLocationStatus.denied);
    } on LocationServiceDisabledException {
      return const DeviceLocationResult.failed(DeviceLocationStatus.serviceDisabled);
    } catch (_) {
      return const DeviceLocationResult.failed(DeviceLocationStatus.error);
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
