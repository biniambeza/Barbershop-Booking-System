import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../services/queue_service.dart';
import '../shared/widgets/ui_kit.dart';
import 'queue_screen.dart';

/// Owner / barber dashboard entry to the walk-in queue: live counts of
/// waiting and served people; opens [QueueScreen].
class QueueDashboardCard extends StatefulWidget {
  const QueueDashboardCard({super.key, required this.shopId});

  final String shopId;

  @override
  State<QueueDashboardCard> createState() => _QueueDashboardCardState();
}

class _QueueDashboardCardState extends State<QueueDashboardCard> {
  late Stream<List<QueueEntry>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = QueueService.instance.watchActiveQueue(widget.shopId);
  }

  @override
  void didUpdateWidget(QueueDashboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _stream = QueueService.instance.watchActiveQueue(widget.shopId);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StreamBuilder<List<QueueEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <QueueEntry>[];
        final waiting = entries.where((e) => e.status == QueueStatus.waiting).length;
        final serving = entries.where((e) => e.status == QueueStatus.serving).length;
        return Card(
          key: const Key('queueDashboardCard'),
          color: AppTheme.card,
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: const IconTile(icon: Icons.groups_outlined, color: AppTheme.green, size: 44),
            title: Text(l.queueTitle,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
            subtitle: Text(
              l.queueDashboardSubtitle(waiting, serving),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QueueScreen(shopId: widget.shopId)),
            ),
          ),
        );
      },
    );
  }
}
