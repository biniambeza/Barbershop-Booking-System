import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barber_model.dart';
import '../../models/user_model.dart';
import '../../services/app_repository.dart';
import '../../services/queue_service.dart';
import 'queue_l10n.dart';

/// The shop's walk-in queue for its owner and barbers: who is in the chair
/// (and with whom), who is waiting in arrival order with their estimated
/// wait, and the actions: add a walk-in, call next, start serving, finish,
/// mark as left.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key, required this.shopId, this.service});

  final String shopId;

  /// Defaults to [QueueService.instance].
  final QueueService? service;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  late final QueueService _queue = widget.service ?? QueueService.instance;
  late final Stream<List<QueueEntry>> _stream = _queue.watchActiveQueue(widget.shopId);

  /// Entries / barbers with an action in flight.
  final Set<String> _busy = {};

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(key));
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.queueActionFailed(l.queueErrorText(e)))));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  void _callNext(Barber barber) {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    _run('barber:${barber.id}', () async {
      final entry = await _queue.callNext(widget.shopId, barber.id);
      messenger.showSnackBar(SnackBar(
        content: Text(entry == null ? l.queueNobodyForBarber(barber.name) : l.queueNowServing(barber.name, entry.name)),
      ));
    });
  }

  Future<void> _start(QueueEntry entry, List<Barber> barbers, Map<String, QueueEntry> servingBy) async {
    final myBarberId = _myBarberId;
    String? barberId;
    if (myBarberId != null) {
      barberId = myBarberId;
    } else {
      barberId = await _chooseBarber(entry, barbers, servingBy);
    }
    if (barberId == null || !mounted) return;
    final chosen = barberId;
    await _run(entry.id, () => _queue.startServing(entry, chosen));
  }

  Future<String?> _chooseBarber(QueueEntry entry, List<Barber> barbers, Map<String, QueueEntry> servingBy) {
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.queueChooseBarber(entry.name)),
        children: [
          for (final b in barbers)
            SimpleDialogOption(
              onPressed: servingBy.containsKey(b.id) || !b.isAvailable ? null : () => Navigator.pop(context, b.id),
              child: Row(
                children: [
                  Icon(
                    b.id == entry.barberId ? Icons.star_rounded : Icons.content_cut,
                    size: 18,
                    color:
                        servingBy.containsKey(b.id) || !b.isAvailable ? AppTheme.textSecondary : AppTheme.primaryGold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.name,
                      style: TextStyle(
                        color: servingBy.containsKey(b.id) || !b.isAvailable ? AppTheme.textSecondary : null,
                      ),
                    ),
                  ),
                  if (servingBy.containsKey(b.id))
                    Text(l.queueBarberServing(servingBy[b.id]!.name),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))
                  else if (!b.isAvailable)
                    Text(l.queueBarberOff, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addWalkIn() async {
    final added = await showDialog<QueueEntry>(
      context: context,
      builder: (_) => AddWalkInDialog(shopId: widget.shopId, service: _queue),
    );
    if (added != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l10n.queueTitle}: ${added.name}')));
    }
  }

  String? get _myBarberId {
    final user = AppRepository.instance.currentUser;
    return user?.role == UserRole.barber ? user?.barberId : null;
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.queueTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('queueAddWalkIn'),
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        onPressed: _addWalkIn,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l.queueAddWalkIn),
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) => StreamBuilder<List<QueueEntry>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.queueActionFailed(l.queueErrorText(snapshot.error!)), textAlign: TextAlign.center),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
            }
            return _buildBody(context, snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<QueueEntry> entries) {
    final repo = AppRepository.instance;
    final l = context.l10n;
    final fmt = context.fmt;
    final barbers = repo.getBarbersForShop(widget.shopId);
    final barberNames = {for (final b in barbers) b.id: b.name};
    final serviceNames = {for (final s in repo.getServicesForShop(widget.shopId)) s.id: s.name};
    final servingBy = QueueService.servingByBarber(entries);
    final serving = queueArrivalOrder(entries.where((e) => e.status == QueueStatus.serving));
    final waiting = queueArrivalOrder(entries.where((e) => e.status == QueueStatus.waiting));
    final estimate = _queue.summarize(widget.shopId, entries);
    final myBarberId = _myBarberId;
    final me = myBarberId == null ? null : repo.getBarberById(myBarberId);

    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Summary line, like customers see it.
        Text(
          estimate.waitingCount == 0
              ? l.queueSummaryEmpty
              : l.queueSummaryWaiting(estimate.waitingCount, estimate.estimatedWaitMinutes),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        if (me != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('queueCallNextMe'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
              onPressed: servingBy.containsKey(me.id) || _busy.contains('barber:${me.id}') ? null : () => _callNext(me),
              icon: const Icon(Icons.campaign_rounded),
              label: Text(l.queueCallNext),
            ),
          ),
        ],

        header(l.queueBarbersHeader),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in barbers) _barberChip(context, b, servingBy[b.id], canCall: myBarberId == null),
          ],
        ),

        header(l.queueServingHeader(serving.length)),
        for (final e in serving)
          Card(
            color: AppTheme.darkCard,
            child: ListTile(
              key: Key('queueServing_${e.id}'),
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.content_cut, color: Colors.white, size: 18),
              ),
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  if (e.barberId != null) barberNames[e.barberId] ?? '',
                  if (e.serviceId != null && serviceNames[e.serviceId] != null) serviceNames[e.serviceId]!,
                  if (e.servingStartedAt != null) l.queueServingSince(fmt.addisTime(e.servingStartedAt!)),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              trailing: FilledButton(
                onPressed: _busy.contains(e.id) ? null : () => _run(e.id, () => _queue.finish(e)),
                child: Text(l.queueFinish),
              ),
            ),
          ),

        header(l.queueWaitingHeader(waiting.length)),
        if (waiting.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l.queueEmpty, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        for (final e in waiting)
          _waitingTile(
            context,
            e,
            estimate.positions[e.id],
            serviceName: e.serviceId == null ? null : serviceNames[e.serviceId],
            preferredBarber: e.barberId == null ? null : barberNames[e.barberId],
            canStart: !_busy.contains(e.id) && (me == null || !servingBy.containsKey(me.id)),
            onStart: () => _start(e, barbers, servingBy),
          ),
      ],
    );
  }

  Widget _barberChip(BuildContext context, Barber barber, QueueEntry? serving, {required bool canCall}) {
    final l = context.l10n;
    final String status;
    final Color color;
    if (serving != null) {
      status = l.queueBarberServing(serving.name);
      color = Colors.tealAccent;
    } else if (!barber.isAvailable) {
      status = l.queueBarberOff;
      color = AppTheme.textSecondary;
    } else {
      status = l.queueBarberFree;
      color = AppTheme.primaryGold;
    }
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(barber.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(status, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
    final free = serving == null && barber.isAvailable;
    if (canCall && free) {
      return Tooltip(
        message: l.queueCallNextFor(barber.name),
        child: ActionChip(
          key: Key('queueBarber_${barber.id}'),
          avatar: Icon(Icons.campaign_rounded, size: 18, color: color),
          label: label,
          onPressed: _busy.contains('barber:${barber.id}') ? null : () => _callNext(barber),
        ),
      );
    }
    return Chip(
      key: Key('queueBarber_${barber.id}'),
      avatar: Icon(serving != null ? Icons.content_cut : Icons.person_off_outlined, size: 18, color: color),
      label: label,
    );
  }

  Widget _waitingTile(
    BuildContext context,
    QueueEntry e,
    QueuePosition? position, {
    required String? serviceName,
    required String? preferredBarber,
    required bool canStart,
    required VoidCallback onStart,
  }) {
    final l = context.l10n;
    final fmt = context.fmt;
    final pos = position?.position;
    final details = [
      if (serviceName != null) serviceName,
      if (preferredBarber != null) l.queuePrefers(preferredBarber),
      if (e.phone != null) fmt.phone(e.phone!),
      l.queueJoinedAt(fmt.addisTime(e.createdAt)),
    ];
    return Card(
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          key: Key('queueWaiting_${e.id}'),
          children: [
            CircleAvatar(
              backgroundColor: pos == 1 ? AppTheme.primaryGold : AppTheme.accentSlate,
              foregroundColor: pos == 1 ? Colors.black : Colors.white,
              child: Text('${pos ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(e.name,
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (e.isRemote) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: l.queueRemoteBadge,
                          child: const Icon(Icons.phone_iphone, size: 14, color: AppTheme.primaryGold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(details.join(' · '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    pos == 1 || position == null ? l.queueNextUp : l.queueWaitAbout(position.waitMinutes),
                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('queueStart_${e.id}'),
              tooltip: l.queueStart,
              onPressed: canStart ? onStart : null,
              icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.tealAccent),
            ),
            IconButton(
              key: Key('queueLeft_${e.id}'),
              tooltip: l.queueMarkLeft,
              onPressed: _busy.contains(e.id) ? null : () => _run(e.id, () => _queue.markLeft(e)),
              icon: const Icon(Icons.directions_walk_rounded, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name, optional phone, service and preferred barber of a walk-in.
/// Pops the added [QueueEntry].
class AddWalkInDialog extends StatefulWidget {
  const AddWalkInDialog({super.key, required this.shopId, required this.service});

  final String shopId;
  final QueueService service;

  @override
  State<AddWalkInDialog> createState() => _AddWalkInDialogState();
}

class _AddWalkInDialogState extends State<AddWalkInDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _serviceId;
  String? _barberId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = await widget.service.addWalkIn(
        shopId: widget.shopId,
        name: _name.text,
        phone: _phone.text,
        serviceId: _serviceId,
        barberId: _barberId,
      );
      if (mounted) Navigator.pop(context, entry);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = l.queueErrorText(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final repo = AppRepository.instance;
    final services = repo.getServicesForShop(widget.shopId);
    final barbers = repo.getBarbersForShop(widget.shopId);
    return AlertDialog(
      title: Text(l.queueAddWalkIn),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('queueWalkInName'),
              controller: _name,
              maxLength: kQueueNameMaxLength,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.queueNameLabel),
            ),
            TextField(
              key: const Key('queueWalkInPhone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l.queuePhoneLabel, hintText: '09XXXXXXXX'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _serviceId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.queueServiceLabel),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.queueNoService)),
                for (final s in services)
                  DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text('${s.name} · ${l.minutesShort(s.durationMinutes)} · ${fmt.birr(s.price)}',
                        overflow: TextOverflow.ellipsis),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('queueWalkInSubmit'),
          onPressed: _saving ? null : _submit,
          child: Text(l.queueAddButton),
        ),
      ],
    );
  }
}
