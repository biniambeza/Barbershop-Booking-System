// Shop location (maps): OpenStreetMap maps (flutter_map, no API key) for a
// shop's pin. [ShopMapView] is the small read-only map on the customer's
// shop page; [ShopLocationPicker] lets the owner or admin set the pin by
// tapping the map or with the device's current location.
//
// OSM tile usage policy: every TileLayer sends the app id as User-Agent
// (kMapUserAgentPackage) and every map shows the attribution.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/device_location.dart';
import '../../../services/shop_maps.dart';

/// Map tiles on or off. Widget tests turn them off so no tile is fetched
/// from the network; the map, pin and attribution still render.
class ShopMapTiles {
  static bool enabled = true;

  /// One HTTP client for every map's tiles (keep-alive connections are
  /// reused between maps). Never closed: a TileLayer only closes clients it
  /// created itself.
  static final http.Client _client = RetryClient(http.Client());
}

List<Widget> _baseLayers() => [
      if (ShopMapTiles.enabled)
        TileLayer(
          urlTemplate: kOsmTileUrl,
          userAgentPackageName: kMapUserAgentPackage,
          tileProvider: NetworkTileProvider(httpClient: ShopMapTiles._client, silenceExceptions: true),
          maxZoom: 19,
        ),
    ];

/// "© OpenStreetMap contributors" in the bottom-right corner, linking to
/// the OSM copyright page. One line that shortens with an ellipsis instead
/// of overflowing on very narrow maps.
Widget _attribution() => Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: () async {
          try {
            await launchUrl(Uri.parse(kOsmCopyrightUrl), mode: LaunchMode.externalApplication);
          } catch (_) {}
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
          ),
          child: const Text(
            '© OpenStreetMap contributors',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );

Marker _pinMarker(LatLng point) => Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const Icon(Icons.location_on, size: 44, color: AppTheme.danger, shadows: [
        Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
      ]),
    );

/// Read-only map centred on a shop's pin. [onTap] (e.g. directions) runs
/// when the map is tapped.
class ShopMapView extends StatelessWidget {
  const ShopMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 160,
    this.zoom = 16,
    this.onTap,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double zoom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Semantics(
      label: context.l10n.shopMapSemantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        child: Container(
          height: height,
          color: AppTheme.surface,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: zoom,
              // Static preview: no panning while the page scrolls.
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              onTap: onTap == null ? null : (_, __) => onTap!(),
            ),
            children: [
              ..._baseLayers(),
              MarkerLayer(markers: [_pinMarker(point)]),
              _attribution(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pin editor of the shop forms: a map (tap to place or move the pin),
/// "Use my current location" and "Remove pin". Reports every change with
/// [onChanged] (both null when the pin is removed).
class ShopLocationPicker extends StatefulWidget {
  const ShopLocationPicker({
    super.key,
    this.latitude,
    this.longitude,
    required this.onChanged,
    this.height = 220,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double? latitude, double? longitude) onChanged;
  final double height;

  @override
  State<ShopLocationPicker> createState() => _ShopLocationPickerState();
}

class _ShopLocationPickerState extends State<ShopLocationPicker> {
  final MapController _map = MapController();
  LatLng? _pin;
  bool _locating = false;
  DeviceLocationStatus? _problem;

  @override
  void initState() {
    super.initState();
    if (isValidShopCoordinate(widget.latitude, widget.longitude)) {
      _pin = LatLng(widget.latitude!, widget.longitude!);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _setPin(LatLng? p, {bool move = false}) {
    final rounded = p == null ? null : LatLng(roundCoordinate(p.latitude), roundCoordinate(p.longitude));
    setState(() {
      _pin = rounded;
      _problem = null;
    });
    widget.onChanged(rounded?.latitude, rounded?.longitude);
    if (move && rounded != null) {
      try {
        _map.move(rounded, 17);
      } catch (_) {
        // The map is not laid out yet; it starts on the pin next build.
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _problem = null;
    });
    final result = await DeviceLocator.instance.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.isOk) {
      _setPin(LatLng(result.latitude!, result.longitude!), move: true);
    } else {
      setState(() => _problem = result.status);
    }
  }

  String _problemText(BuildContext context, DeviceLocationStatus s) {
    final l = context.l10n;
    switch (s) {
      case DeviceLocationStatus.serviceDisabled:
        return l.locationServiceOff;
      case DeviceLocationStatus.denied:
        return l.locationPermissionDenied;
      case DeviceLocationStatus.deniedForever:
        return l.locationPermissionBlocked;
      case DeviceLocationStatus.ok:
      case DeviceLocationStatus.error:
        return l.locationUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pin = _pin;
    final center = pin ?? const LatLng(kAddisCenterLat, kAddisCenterLng);
    return Column(
      key: const ValueKey('shop-location-picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.push_pin_outlined, size: 18, color: AppTheme.green),
            const SizedBox(width: 6),
            Text(l.shopMapPinTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(l.shopMapPinHelp, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.hairline),
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
            ),
            child: FlutterMap(
              key: const ValueKey('shop-location-picker-map'),
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: pin == null ? 13 : 17,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, point) => _setPin(point),
                onLongPress: (_, point) => _setPin(point),
              ),
              children: [
                ..._baseLayers(),
                if (pin != null) MarkerLayer(markers: [_pinMarker(pin)]),
                _attribution(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (pin == null)
          Text(l.noMapPinYet, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))
        else ...[
          Text(
            l.mapPinCoordinates(pin.latitude.toStringAsFixed(5), pin.longitude.toStringAsFixed(5)),
            key: const ValueKey('shop-location-coordinates'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (!isInEthiopia(pin.latitude, pin.longitude))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.mapPinOutsideEthiopia,
                  style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600)),
            ),
        ],
        if (_problem != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _problemText(context, _problem!),
                  key: const ValueKey('shop-location-problem'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                ),
              ),
              if (_problem == DeviceLocationStatus.deniedForever)
                TextButton(
                  onPressed: () => DeviceLocator.instance.openSettings(),
                  child: Text(l.openSettingsAction),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('shop-location-use-current'),
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_locating ? l.findingYourLocation : l.useMyCurrentLocation),
            ),
            if (pin != null)
              TextButton.icon(
                key: const ValueKey('shop-location-remove'),
                onPressed: () => _setPin(null),
                icon: const Icon(Icons.location_off_outlined, size: 18),
                label: Text(l.removeMapPin),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              ),
          ],
        ),
      ],
    );
  }
}
