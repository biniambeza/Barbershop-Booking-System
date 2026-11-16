// Shop location (maps): what customers see of a shop's location. Many
// people in Addis navigate by landmark, so the landmark comes first and
// big, then the address, a small map with the pin and a "Directions"
// button that opens Google Maps (or the default maps app).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/shop_maps.dart';
import '../../shared/widgets/shop_map.dart';

/// Opens a link; returns false when nothing could open it. Tests pass a fake.
typedef MapLinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Google Maps directions to the shop's pin, or a search for its landmark
/// and address when it has none.
Uri shopDirectionsUri(Barbershop shop) => directionsUri(
      latitude: shop.latitude,
      longitude: shop.longitude,
      address: shop.address,
      landmark: shop.landmark,
      subCity: shop.subCity,
      city: shop.city,
    );

/// Opens directions to [shop]: the Google Maps link first (the app when
/// installed, else the browser), then a `geo:` link for the default maps
/// app (not on the web). Shows a message when neither opens.
Future<void> openShopDirections(BuildContext context, Barbershop shop, {MapLinkLauncher? launcher}) async {
  final launch = launcher ?? _defaultLauncher;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.shopDirectionsFailed;
  Future<bool> tryOpen(Uri uri) async {
    try {
      return await launch(uri);
    } catch (_) {
      return false;
    }
  }

  if (await tryOpen(shopDirectionsUri(shop))) return;
  if (!kIsWeb &&
      await tryOpen(geoUri(
        latitude: shop.latitude,
        longitude: shop.longitude,
        address: shop.address,
        label: shop.name,
        landmark: shop.landmark,
        subCity: shop.subCity,
        city: shop.city,
      ))) {
    return;
  }
  messenger?.showSnackBar(SnackBar(content: Text(failed)));
}

/// "1.2 km away" / "350 m away".
String formatShopDistance(AppLocalizations l, double km) {
  if (km < 1) {
    final m = ((km * 1000) / 10).round() * 10;
    return l.distanceMetersAway(m < 10 ? 10 : m);
  }
  return l.distanceKmAway(km < 10 ? km.toStringAsFixed(1) : km.round().toString());
}

/// The landmark line of a shop card: a flag icon and the landmark in bold.
class ShopLandmarkLine extends StatelessWidget {
  const ShopLandmarkLine({super.key, required this.landmark, this.fontSize = 13.5});

  final String landmark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${context.l10n.shopLandmarkLabel}: $landmark',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(Icons.assistant_photo_outlined, size: fontSize + 2, color: AppTheme.success),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              landmark,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Landmark (big), address, map with the pin (when set) and the
/// "Directions" button, for the customer's shop page.
class ShopLocationBlock extends StatelessWidget {
  const ShopLocationBlock({super.key, required this.shop, this.launcher});

  final Barbershop shop;

  /// Opens the directions link (tests); defaults to url_launcher.
  final MapLinkLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final landmark = shop.landmark?.trim() ?? '';
    return Column(
      key: const ValueKey('shop-location-block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (landmark.isNotEmpty) ...[
          Row(
            key: const ValueKey('shop-landmark'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.greenSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                ),
                child: Icon(Icons.assistant_photo_outlined, color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.shopLandmarkLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      landmark,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.storefront, size: 15, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.shopAddress(shop),
                key: const ValueKey('shop-address'),
                style: TextStyle(fontSize: 13.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (shop.hasLocation) ...[
          const SizedBox(height: 12),
          ShopMapView(
            key: const ValueKey('shop-map'),
            latitude: shop.latitude!,
            longitude: shop.longitude!,
            height: 150,
            onTap: () => openShopDirections(context, shop, launcher: launcher),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const ValueKey('shop-directions'),
            onPressed: () => openShopDirections(context, shop, launcher: launcher),
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: Text(l.shopDirections),
          ),
        ),
      ],
    );
  }
}
