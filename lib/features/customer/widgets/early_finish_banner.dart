import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/app_notification.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/booking_model.dart';
import '../../../services/early_finish_service.dart';
import '../../../services/notification_service.dart';
import 'shop_location_block.dart' show shopDirectionsUri; // shop location (maps)

/// The newest 'barberFreeEarly' notice for [bookingId] that is younger than
/// [kEarlyFinishBannerWindow] at [nowUtc], or null.
AppNotification? activeEarlyFinishNotice(Iterable<AppNotification> notifications, String bookingId, DateTime nowUtc) {
  AppNotification? best;
  for (final n in notifications) {
    if (!showsEarlyFinishBanner(
      bookingId: bookingId,
      notificationBookingId: n.bookingId,
      notificationType: n.type,
      notificationCreatedAt: n.createdAt,
      nowUtc: nowUtc,
    )) {
      continue;
    }
    if (best == null || n.createdAt.isAfter(best.createdAt)) best = n;
  }
  return best;
}

/// Green banner on an upcoming booking card: "Your barber is free now -
/// come in early", shown for an hour after the barber finished the previous
/// appointment early, with call / directions shortcuts when the shop has a
/// phone number / address.
class EarlyFinishBanner extends StatelessWidget {
  const EarlyFinishBanner({
    super.key,
    required this.booking,
    required this.shop,
    required this.now,
    this.service,
  });

  final Booking booking;
  final Barbershop? shop;
  final DateTime Function() now;

  /// Defaults to [NotificationService.instance].
  final NotificationService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? NotificationService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        if (booking.status != BookingStatus.confirmed) return const SizedBox.shrink();
        final notice = activeEarlyFinishNotice(svc.notifications, booking.id, now());
        if (notice == null) return const SizedBox.shrink();
        return _buildBanner(context);
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    final l = context.l10n;
    final phone = shop?.phone.trim() ?? '';
    final place = shop == null
        ? ''
        : [shop!.address, shop!.subCity, shop!.city].where((p) => p.trim().isNotEmpty).join(', ');
    return Container(
      key: ValueKey('early-finish-banner-${booking.id}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.greenSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.directions_walk_rounded, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.earlyFinishBannerTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.earlyFinishBannerBody(booking.barberName, context.fmt.bookingTime(booking)),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty || place.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (phone.isNotEmpty)
                  _PillAction(
                    key: ValueKey('early-finish-call-${booking.id}'),
                    icon: Icons.call_rounded,
                    label: l.earlyFinishCallShop,
                    uri: Uri(scheme: 'tel', path: phone),
                  ),
                if (place.isNotEmpty)
                  _PillAction(
                    key: ValueKey('early-finish-directions-${booking.id}'),
                    icon: Icons.directions_rounded,
                    label: l.earlyFinishDirections,
                    // shop location (maps): straight to the pin when set.
                    uri: shop!.hasLocation
                        ? shopDirectionsUri(shop!)
                        : Uri.https('www.google.com', '/maps/search/', {
                            'api': '1',
                            'query': '${shop!.name}, $place',
                          }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({super.key, required this.icon, required this.label, required this.uri});

  final IconData icon;
  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Could not open $uri: $e');
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.success,
        backgroundColor: AppTheme.card,
        side: const BorderSide(color: AppTheme.hairline),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
