import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barbershop_model.dart';
import '../../models/user_model.dart';
import '../../services/app_repository.dart';
import '../../services/queue_service.dart';
import '../shared/widgets/ui_kit.dart';
import 'queue_l10n.dart';

/// Walk-in queue on a shop's detail page: "N waiting, about X min" from the
/// public summary, and for a signed-in customer "Join queue", their place in
/// line and "Leave queue".
class QueueStatusCard extends StatefulWidget {
  const QueueStatusCard({super.key, required this.shop, this.service});

  final Barbershop shop;

  /// Defaults to [QueueService.instance].
  final QueueService? service;

  @override
  State<QueueStatusCard> createState() => _QueueStatusCardState();
}

class _QueueStatusCardState extends State<QueueStatusCard> {
  late final QueueService _queue = widget.service ?? QueueService.instance;
  late Stream<QueueSummary> _summary;
  late Stream<QueueEntry?> _mine;
  String? _uid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _uid = AppRepository.instance.currentUser?.uid;
    _summary = _queue.watchSummary(widget.shop.id);
    _mine = _queue.watchMyEntry(widget.shop.id);
  }

  @override
  void didUpdateWidget(QueueStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shop.id != widget.shop.id || AppRepository.instance.currentUser?.uid != _uid) _subscribe();
  }

  Future<void> _run(Future<void> Function() action, String doneText) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.queueErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final l = context.l10n;
    final choice = await showDialog<_JoinChoice>(
      context: context,
      builder: (_) => _JoinQueueDialog(shop: widget.shop),
    );
    if (choice == null || !mounted) return;
    await _run(
      () => _queue.joinQueue(shopId: widget.shop.id, serviceId: choice.serviceId, barberId: choice.barberId),
      l.queueJoined,
    );
  }

  Future<void> _leave(QueueEntry entry) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.queueLeaveConfirm(widget.shop.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const Key('queueLeaveConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.queueLeave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => _queue.leaveQueue(entry), l.queueLeftMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = AppRepository.instance.currentUser;
    final isCustomer = user?.role == UserRole.customer;
    return StreamBuilder<QueueSummary>(
      stream: _summary,
      builder: (context, summarySnap) {
        final summary = summarySnap.data ?? QueueSummary.empty;
        return StreamBuilder<QueueEntry?>(
          stream: _mine,
          builder: (context, mineSnap) {
            final mine = mineSnap.data;
            return Container(
              key: const Key('queueStatusCard'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(borderColor: mine != null ? AppTheme.green : null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconTile(icon: Icons.groups_outlined, color: AppTheme.green, size: 40),
                      const SizedBox(width: 12),
                      Text(l.queueTitle,
                          style:
                              const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary.waitingCount == 0
                        ? l.queueSummaryEmpty
                        : l.queueSummaryWaiting(summary.waitingCount, summary.estimatedWaitMinutes),
                    key: const Key('queueSummaryText'),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (mine != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _myStatus(context, mine, summary),
                      key: const Key('queueMyStatus'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success),
                    ),
                    if (mine.status == QueueStatus.waiting) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('queueLeaveButton'),
                        onPressed: _busy ? null : () => _leave(mine),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(l.queueLeave),
                      ),
                    ],
                  ] else if (isCustomer) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const Key('queueJoinButton'),
                      onPressed: _busy || widget.shop.isSuspended ? null : _join,
                      icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                      label: Text(l.queueJoin),
                    ),
                  ] else if (user == null) ...[
                    const SizedBox(height: 6),
                    Text(l.queueSignInToJoin, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _myStatus(BuildContext context, QueueEntry mine, QueueSummary summary) {
    final l = context.l10n;
    if (mine.status == QueueStatus.serving) {
      final barber = mine.barberId == null ? null : AppRepository.instance.getBarberById(mine.barberId!);
      return barber == null ? l.queueYourTurnAnyBarber : l.queueYourTurn(barber.name);
    }
    final position = summary.positions[mine.id];
    if (position == null) return l.queueJoined; // summary not updated yet
    if (position.position == 1) return l.queueYouAreNext;
    return l.queueYourPosition(position.position, position.waitMinutes);
  }
}

class _JoinChoice {
  const _JoinChoice(this.serviceId, this.barberId);
  final String? serviceId;
  final String? barberId;
}

/// Optional service and preferred barber for a remote join.
class _JoinQueueDialog extends StatefulWidget {
  const _JoinQueueDialog({required this.shop});

  final Barbershop shop;

  @override
  State<_JoinQueueDialog> createState() => _JoinQueueDialogState();
}

class _JoinQueueDialogState extends State<_JoinQueueDialog> {
  String? _serviceId;
  String? _barberId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final repo = AppRepository.instance;
    final services = repo.getServicesForShop(widget.shop.id);
    final barbers = repo.getBarbersForShop(widget.shop.id).where((b) => b.isAvailable).toList();
    return AlertDialog(
      title: Text(l.queueJoinTitle(widget.shop.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.queueJoinBody, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _serviceId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.queueServiceLabel),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.queueNoService)),
                for (final s in services)
                  DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text('${s.name} · ${fmt.birr(s.price)}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _serviceId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _barberId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.queuePreferredBarberLabel),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.queueAnyBarber)),
                for (final b in barbers) DropdownMenuItem<String?>(value: b.id, child: Text(b.name)),
              ],
              onChanged: (v) => setState(() => _barberId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('queueJoinSubmit'),
          onPressed: () => Navigator.pop(context, _JoinChoice(_serviceId, _barberId)),
          child: Text(l.queueJoin),
        ),
      ],
    );
  }
}
