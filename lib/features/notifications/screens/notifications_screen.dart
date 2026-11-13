import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/app_notification.dart';
import '../../../services/notification_service.dart';

/// The signed-in user's notification inbox, newest first. Tapping an entry
/// marks it read.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.service});

  /// Defaults to [NotificationService.instance].
  final NotificationService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? NotificationService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final items = svc.notifications;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.notificationsTitle),
            actions: [
              if (svc.unreadCount > 0)
                TextButton(
                  onPressed: svc.markAllRead,
                  child: Text(context.l10n.markAllRead, style: const TextStyle(color: AppTheme.primaryGold)),
                ),
            ],
          ),
          body: items.isEmpty
              ? const _EmptyInbox()
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.accentSlate),
                  itemBuilder: (context, i) => _NotificationTile(
                    notification: items[i],
                    onTap: () => svc.markRead(items[i].id),
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(context.l10n.noNotifications, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              context.l10n.noNotificationsHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, color) = notificationIcon(n.type);
    return ListTile(
      onTap: onTap,
      tileColor: n.read ? null : AppTheme.primaryGold.withValues(alpha: 0.06),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        n.title,
        style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(n.body, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(relativeTime(n.createdAt, l10n: context.l10n), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
      trailing: n.read
          ? null
          : Container(
              key: const ValueKey('unread-dot'),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppTheme.primaryGold, shape: BoxShape.circle),
            ),
      isThreeLine: true,
    );
  }
}

(IconData, Color) notificationIcon(String type) {
  switch (type) {
    case NotificationTypes.created:
      return (Icons.event_note_rounded, Colors.lightBlueAccent);
    case NotificationTypes.confirmed:
      return (Icons.event_available_rounded, Colors.greenAccent);
    case NotificationTypes.cancelled:
    case NotificationTypes.slotTaken:
      return (Icons.event_busy_rounded, Colors.redAccent);
    case NotificationTypes.paymentReceived:
    case NotificationTypes.subscriptionPaid:
      return (Icons.payments_rounded, Colors.greenAccent);
    case NotificationTypes.paymentRefunded:
      return (Icons.currency_exchange_rounded, Colors.lightBlueAccent);
    case NotificationTypes.paymentFailed:
    case NotificationTypes.subscriptionFailed:
      return (Icons.money_off_rounded, Colors.redAccent);
    case NotificationTypes.started:
      return (Icons.content_cut_rounded, Colors.tealAccent);
    case NotificationTypes.completed:
      return (Icons.check_circle_outline_rounded, AppTheme.primaryGold);
    case NotificationTypes.reminder24h:
    case NotificationTypes.reminder2h:
      return (Icons.alarm_rounded, Colors.orangeAccent);
    case NotificationTypes.rescheduled:
      return (Icons.update_rounded, Colors.lightBlueAccent);
    case NotificationTypes.noShow:
      return (Icons.person_off_rounded, Colors.redAccent);
    case NotificationTypes.queueNext:
      return (Icons.groups_rounded, Colors.greenAccent);
    default:
      return (Icons.notifications_rounded, AppTheme.textSecondary);
  }
}

/// 'Just now', '5 min ago', '3 h ago', '2 d ago', or the date.
String relativeTime(DateTime createdAtUtc, {DateTime? now, AppLocalizations? l10n}) {
  final l = l10n ?? lookupAppLocalizations(const Locale('en'));
  final diff = (now ?? DateTime.now()).toUtc().difference(createdAtUtc.toUtc());
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.daysAgo(diff.inDays);
  // Older entries: the Addis Ababa calendar date.
  return AppFormats(l.localeName).addisDateMedium(createdAtUtc);
}
