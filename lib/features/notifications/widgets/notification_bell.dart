import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/notification_service.dart';
import '../screens/notifications_screen.dart';

/// App-bar bell with the unread count; opens the inbox.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.service});

  /// Defaults to [NotificationService.instance].
  final NotificationService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? NotificationService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final unread = svc.unreadCount;
        return IconButton(
          tooltip: unread > 0 ? context.l10n.notificationsUnreadTooltip(unread) : context.l10n.notificationsTitle,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: AppTheme.primaryGold,
            textColor: Colors.black,
            child: Icon(unread > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_rounded),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationsScreen(service: svc)),
          ),
        );
      },
    );
  }
}
