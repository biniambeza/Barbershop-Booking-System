import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../models/shop_report.dart' show ShopClient;
import '../../../services/app_repository.dart';
import '../../../services/customer_blocks.dart';
import '../../../services/owner_insights_service.dart';
import '../../../services/report_fallback.dart' show kReportFallbackDays;
import '../../shared/widgets/ui_kit.dart';

/// Owner reports, No-shows tab: the shop's customers sorted by no-show
/// rate (bookings, completed, cancelled, no-shows), name search, a Blocked
/// filter, block / unblock, and the auto-block setting.
///
/// Shows only what the owner already sees on the shop's bookings: the
/// customer's name and phone as booked, and the booking statuses.
class CustomerNoShowTab extends StatefulWidget {
  const CustomerNoShowTab({
    super.key,
    required this.shopId,
    this.clientDocs = const [],
    this.service,
    this.blocks,
  });

  final String shopId;

  /// The report's function-maintained client docs (Blaze; empty on Spark).
  final List<ShopClient> clientDocs;

  final OwnerInsightsService? service;
  final CustomerBlockService? blocks;

  @override
  State<CustomerNoShowTab> createState() => _CustomerNoShowTabState();
}

class _CustomerNoShowTabState extends State<CustomerNoShowTab> {
  late final OwnerInsightsService _service = widget.service ?? OwnerInsightsService();
  late final CustomerBlockService _blocks = widget.blocks ?? CustomerBlockService.instance;
  late final Stream<List<CustomerBlock>> _blockStream = _blocks.watchBlocks(widget.shopId);
  late final Stream<CustomerBlockSettings> _settingsStream = _blocks.watchSettings(widget.shopId);
  final TextEditingController _search = TextEditingController();
  bool _blockedOnly = false;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(context.l10n.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CustomerBlock>>(
      stream: _blockStream,
      builder: (context, blockSnap) {
        final blocks = {for (final b in blockSnap.data ?? const <CustomerBlock>[]) b.customerId: b};
        return ListenableBuilder(
          listenable: AppRepository.instance,
          builder: (context, _) => _content(context, blocks),
        );
      },
    );
  }

  Widget _content(BuildContext context, Map<String, CustomerBlock> blocks) {
    final l = context.l10n;
    final rows = _service.customerRows(widget.shopId, clientDocs: widget.clientDocs);
    final known = {for (final r in rows) r.customerId};
    // Blocked customers with no booking in the loaded window still show.
    final all = [
      ...rows,
      for (final b in blocks.values)
        if (!known.contains(b.customerId))
          CustomerNoShowRow(customerId: b.customerId, name: b.customerName, phone: ''),
    ];
    var shown = searchCustomersByName(all, _search.text);
    if (_blockedOnly) shown = shown.where((r) => blocks.containsKey(r.customerId)).toList();
    final canManage = _blocks.canManage(widget.shopId);

    return ListView(
      key: const ValueKey('noshow-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (canManage) ...[
          _AutoBlockCard(
            stream: _settingsStream,
            busy: _busy,
            onChanged: (n) => _run(() => _blocks.setAutoBlock(widget.shopId, n)),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const ValueKey('noshow-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.noShowsSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppTheme.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: AppTheme.hairline)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: AppTheme.hairline)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _filterChip(const ValueKey('noshow-filter-all'), l.noShowsFilterAll, !_blockedOnly,
                () => setState(() => _blockedOnly = false)),
            _filterChip(const ValueKey('noshow-filter-blocked'), l.noShowsFilterBlocked(blocks.length), _blockedOnly,
                () => setState(() => _blockedOnly = true)),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(l.noShowsListTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary, letterSpacing: -0.2)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            [
              l.noShowsRateHelp,
              if (_service.usesFirestore && widget.clientDocs.isEmpty) l.noShowsWindowNote(kReportFallbackDays),
            ].join(' '),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        if (all.isEmpty)
          Text(l.noShowsNoCustomers,
              key: const ValueKey('noshow-empty'), style: const TextStyle(color: AppTheme.textSecondary))
        else if (shown.isEmpty)
          Text(l.noShowsNoMatch,
              key: const ValueKey('noshow-no-match'), style: const TextStyle(color: AppTheme.textSecondary))
        else
          for (final r in shown)
            _CustomerRowCard(
              row: r,
              block: blocks[r.customerId],
              canManage: canManage,
              busy: _busy,
              onBlock: () => _block(r),
              onUnblock: () => _unblock(r, blocks[r.customerId]),
            ),
      ],
    );
  }

  Widget _filterChip(Key key, String label, bool selected, VoidCallback onTap) => ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppTheme.ink,
        backgroundColor: AppTheme.card,
        side: BorderSide(color: selected ? AppTheme.ink : AppTheme.hairline),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            color: selected ? AppTheme.onInk : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
        onSelected: (_) => onTap(),
      );

  String _nameOf(BuildContext context, CustomerNoShowRow r) =>
      r.name.trim().isNotEmpty ? r.name.trim() : context.l10n.customerUnknownName;

  Future<void> _block(CustomerNoShowRow r) async {
    final l = context.l10n;
    final name = _nameOf(context, r);
    final upcoming = _blocks.upcomingBookingsOf(widget.shopId, r.customerId);
    final choice = await showDialog<_BlockChoice>(
      context: context,
      builder: (_) => _BlockDialog(name: name, upcoming: upcoming),
    );
    if (choice == null || !mounted) return;
    await _run(() async {
      await _blocks.blockCustomer(
          shopId: widget.shopId, customerId: r.customerId, customerName: r.name, reason: choice.reason);
      final cancelled = choice.cancelUpcoming ? await _blocks.cancelUpcomingBookings(widget.shopId, r.customerId) : 0;
      _snack(cancelled > 0 ? l.customerBlockedCancelledSnack(cancelled, name) : l.customerBlockedSnack(name));
    });
  }

  Future<void> _unblock(CustomerNoShowRow r, CustomerBlock? block) async {
    final l = context.l10n;
    final name = _nameOf(context, r);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.customerUnblockTitle(name)),
        content: Text(l.customerUnblockBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('unblock-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.customerUnblockAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await _blocks.unblockCustomer(widget.shopId, r.customerId);
      _snack(l.customerUnblockedSnack(name));
    });
  }
}

/// The auto-block switch and limit stepper.
class _AutoBlockCard extends StatelessWidget {
  const _AutoBlockCard({required this.stream, required this.busy, required this.onChanged});

  final Stream<CustomerBlockSettings> stream;
  final bool busy;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StreamBuilder<CustomerBlockSettings>(
      stream: stream,
      builder: (context, snap) {
        final settings = snap.data;
        return AppCard(
          key: const ValueKey('autoblock-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(icon: Icons.person_off_outlined, color: AppTheme.warning, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.noShowsAutoBlockTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          snap.hasError
                              ? l.noShowsSettingsUnavailable
                              : settings == null
                                  ? ''
                                  : settings.autoBlockOn
                                      ? l.noShowsAutoBlockOn(settings.autoBlockNoShows)
                                      : l.noShowsAutoBlockOff,
                          key: const ValueKey('autoblock-status'),
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const ValueKey('autoblock-switch'),
                    value: settings?.autoBlockOn ?? false,
                    activeTrackColor: AppTheme.green,
                    onChanged: settings == null || busy
                        ? null
                        : (on) => onChanged(on ? kDefaultAutoBlockNoShows : 0),
                  ),
                ],
              ),
              if (settings != null && settings.autoBlockOn) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(l.noShowsAutoBlockLimit,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    ),
                    IconButton(
                      key: const ValueKey('autoblock-dec'),
                      tooltip: l.noShowsDecrease,
                      onPressed: busy || settings.autoBlockNoShows <= 1
                          ? null
                          : () => onChanged(settings.autoBlockNoShows - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${settings.autoBlockNoShows}',
                        key: const ValueKey('autoblock-limit'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      key: const ValueKey('autoblock-inc'),
                      tooltip: l.noShowsIncrease,
                      onPressed: busy || settings.autoBlockNoShows >= kMaxAutoBlockNoShows
                          ? null
                          : () => onChanged(settings.autoBlockNoShows + 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CustomerRowCard extends StatelessWidget {
  const _CustomerRowCard({
    required this.row,
    required this.block,
    required this.canManage,
    required this.busy,
    required this.onBlock,
    required this.onUnblock,
  });

  final CustomerNoShowRow row;
  final CustomerBlock? block;
  final bool canManage;
  final bool busy;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  static Color rateColor(int? percent) {
    if (percent == null) return AppTheme.slate;
    if (percent >= 30) return AppTheme.danger;
    if (percent >= 10) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final name = row.name.trim().isNotEmpty ? row.name.trim() : l.customerUnknownName;
    final percent = row.noShowPercent;
    final b = block;
    return AppCard(
      key: ValueKey('noshow-row-${row.customerId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      borderColor: b != null ? AppTheme.danger.withValues(alpha: 0.35) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.surface,
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                if (row.phone.isNotEmpty)
                  Text(fmt.phone(row.phone), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 3),
                Text(
                  l.noShowsCustomerStats(row.bookings, row.completed, row.cancelled, row.noShows),
                  key: ValueKey('noshow-stats-${row.customerId}'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (b != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(
                        key: ValueKey('noshow-blocked-${row.customerId}'),
                        label: b.isAuto ? l.customerAutoBlockedChip : l.customerBlockedChip,
                        color: AppTheme.danger,
                        icon: Icons.block_rounded,
                      ),
                      Text(l.customerBlockedOn(fmt.addisDateMedium(b.blockedAt)),
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                    ],
                  ),
                  if (b.isAuto && b.noShowCount != null)
                    Text(l.customerAutoBlockedAfter(b.noShowCount!),
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  if (b.reason != null)
                    Text(l.customerBlockNote(b.reason!),
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                label: percent == null ? null : l.noShowsRateSemantics(percent),
                child: StatusChip(
                  key: ValueKey('noshow-rate-${row.customerId}'),
                  label: percent == null ? '—' : '$percent%',
                  color: rateColor(percent),
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 8),
                b == null
                    ? OutlinedButton(
                        key: ValueKey('noshow-block-${row.customerId}'),
                        onPressed: busy ? null : onBlock,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.hairline),
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(l.customerBlockAction),
                      )
                    : OutlinedButton(
                        key: ValueKey('noshow-unblock-${row.customerId}'),
                        onPressed: busy ? null : onUnblock,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.hairline),
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(l.customerUnblockAction),
                      ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockChoice {
  const _BlockChoice(this.reason, this.cancelUpcoming);
  final String? reason;
  final bool cancelUpcoming;
}

class _BlockDialog extends StatefulWidget {
  const _BlockDialog({required this.name, required this.upcoming});
  final String name;
  final List<Booking> upcoming;

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  final TextEditingController _reason = TextEditingController();
  bool _cancelUpcoming = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasPaid = widget.upcoming.any((b) => b.paymentStatus == PaymentStatus.paid);
    return AlertDialog(
      title: Text(l.customerBlockTitle(widget.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.customerBlockBody),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('block-reason-field'),
              controller: _reason,
              maxLength: kMaxBlockReasonLength,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(labelText: l.customerBlockReasonLabel, helperText: l.customerBlockReasonHelper),
            ),
            if (widget.upcoming.isNotEmpty) ...[
              const SizedBox(height: 6),
              CheckboxListTile(
                key: const ValueKey('block-cancel-upcoming'),
                value: _cancelUpcoming,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _cancelUpcoming = v ?? false),
                title: Text(l.customerBlockCancelUpcoming(widget.upcoming.length)),
                subtitle: Text(hasPaid ? l.customerBlockCancelPaidNote : l.customerBlockKeepNote),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('block-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: () => Navigator.pop(context, _BlockChoice(_reason.text, _cancelUpcoming)),
          child: Text(l.customerBlockAction),
        ),
      ],
    );
  }
}
