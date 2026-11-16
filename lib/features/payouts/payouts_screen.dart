import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barber_model.dart';
import '../../models/booking_model.dart';
import '../../services/app_repository.dart';
import '../shared/widgets/ui_kit.dart';
import 'payouts_l10n.dart';
import 'payouts_manager.dart';

/// Owner: per-barber commission, share, payouts and balance for one month
/// (including what carried over from earlier months), with "Record payout"
/// and the month's payout history.
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key, required this.shopId, this.manager});

  final String shopId;

  /// Defaults to [PayoutsManager.instance].
  final PayoutsManager? manager;

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  late final PayoutsManager _m = widget.manager ?? PayoutsManager.instance;
  late PayoutMonth _month = _m.currentMonth();
  late Future<List<Booking>> _bookings;
  late Stream<List<Payout>> _payouts;
  late Future<Map<String, PayoutCarryOver>> _carry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bookings = _m.loadMonthBookings(widget.shopId, _month);
    _payouts = _m.watchShopPayouts(widget.shopId, _month);
    _carry = _m.loadShopCarryOver(widget.shopId, _month);
  }

  void _selectMonth(PayoutMonth month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      _load();
    });
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.payoutsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: l.reportsRetry, onPressed: _reload),
        ],
      ),
      body: StreamBuilder<List<Payout>>(
        stream: _payouts,
        builder: (context, payoutSnap) => FutureBuilder<List<Booking>>(
          future: _bookings,
          builder: (context, bookingSnap) {
            if (payoutSnap.hasError || bookingSnap.hasError) return _error(context);
            if (!payoutSnap.hasData || !bookingSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // carry-over: earlier unpaid balances (a failed load shows this month only)
            return FutureBuilder<Map<String, PayoutCarryOver>>(
              future: _carry,
              builder: (context, carrySnap) {
                if (carrySnap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListenableBuilder(
                  listenable: AppRepository.instance,
                  builder: (context, _) {
                    final bookings = mergeBookings(
                      bookingSnap.data!,
                      _m.cachedMonthBookings(widget.shopId, _month),
                    );
                    final payouts = payoutSnap.data!;
                    final rows = withCarryOver(
                      _m.summarizeMonth(widget.shopId, _month, bookings: bookings, payouts: payouts),
                      carrySnap.data ?? const {},
                      _month,
                    );
                    return _content(context, rows, payouts, carryFailed: carrySnap.hasError);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _error(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.payoutsLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _reload, child: Text(l.reportsRetry)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<BarberBalance> rows, List<Payout> payouts, {bool carryFailed = false}) {
    final l = context.l10n;
    final fmt = context.fmt;
    final totals = ShopBalanceTotals.of(rows);
    final names = {for (final r in rows) r.barberId: r.summary.barberName};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _MonthPicker(
          months: _m.recentMonths(),
          value: _month,
          onChanged: _selectMonth,
        ),
        const SizedBox(height: 14),
        HeroCard(
          key: const ValueKey('payouts-totals'),
          child: Row(
            children: [
              Expanded(child: _HeroFigure(label: l.payoutsTotalShare, value: fmt.birr(totals.share))),
              Expanded(child: _HeroFigure(label: l.payoutsTotalPaid, value: fmt.birr(totals.paid))),
              Expanded(
                child: _HeroFigure(
                  key: const ValueKey('payouts-total-owed'),
                  label: l.payoutsTotalOwed,
                  value: fmt.birr(totals.owed),
                  accent: totals.owed > 0,
                ),
              ),
            ],
          ),
        ),
        if (totals.carriedOver != 0) ...[
          const SizedBox(height: 8),
          Text(
            '${l.payoutsTotalCarried}: ${fmt.birr(totals.carriedOver)} · ${l.payoutsCarryHint}',
            key: const ValueKey('payouts-total-carried'),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
        if (carryFailed) ...[
          const SizedBox(height: 8),
          Text(
            l.payoutsCarryUnavailable,
            key: const ValueKey('payouts-carry-failed'),
            style: const TextStyle(color: AppTheme.warning, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        if (rows.isEmpty)
          AppCard(
            child: Text(l.payoutsNoBarbers, style: const TextStyle(color: AppTheme.textSecondary)),
          )
        else
          for (final r in rows) ...[
            _BarberRow(
              row: r,
              onRecord: () => _record(r),
              onCommission: () => _commission(r.barberId),
            ),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 8),
        SectionHeader(title: l.payoutsHistory),
        const SizedBox(height: 10),
        if (payouts.isEmpty)
          Text(l.payoutsNoHistory, style: const TextStyle(color: AppTheme.textSecondary))
        else
          for (final p in payouts)
            PayoutTile(
              payout: p,
              barberName: names[p.barberId] ?? AppRepository.instance.getBarberById(p.barberId)?.name,
              onDelete: _m.canDelete(p) ? () => _delete(p, names[p.barberId] ?? '') : null,
            ),
      ],
    );
  }

  Future<void> _record(BarberBalance row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard))),
      builder: (_) => RecordPayoutSheet(
        manager: _m,
        shopId: widget.shopId,
        month: _month,
        summary: row.summary,
        carriedOver: row.carriedOver,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.payoutsSaved)));
    }
  }

  Future<void> _commission(String barberId) async {
    final barber = AppRepository.instance.getBarberById(barberId);
    if (barber == null) return;
    final saved = await showCommissionDialog(context, barber, manager: _m);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.payoutsCommissionSaved)));
    }
  }

  Future<void> _delete(Payout payout, String barberName) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.payoutsDelete),
        content: Text(l.payoutsDeleteBody(fmt.birr(payout.amount), barberName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            key: const ValueKey('payout-delete-confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.payoutsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _m.deletePayout(payout);
      messenger.showSnackBar(SnackBar(content: Text(l.payoutsDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.payoutsErrorText(e))));
    }
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.months, required this.value, required this.onChanged});

  final List<PayoutMonth> months;
  final PayoutMonth value;
  final ValueChanged<PayoutMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final items = months.contains(value) ? months : [value, ...months];
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Row(
        children: [
          Text(l.payoutsMonthLabel,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<PayoutMonth>(
              key: const ValueKey('payouts-month-picker'),
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
              dropdownColor: AppTheme.card,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
              items: [
                for (final m in items) DropdownMenuItem(value: m, child: Text(payoutMonthLabel(fmt, m))),
              ],
              onChanged: (m) {
                if (m != null) onChanged(m);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({super.key, required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 12)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: accent ? AppTheme.green : AppTheme.onInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Label/value line inside a card.
class PayoutFigureLine extends StatelessWidget {
  const PayoutFigureLine({super.key, required this.label, required this.value, this.strong = false, this.color});

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: strong ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 13.5,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(
                  color: color ?? AppTheme.textPrimary,
                  fontSize: strong ? 15 : 13.5,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BarberRow extends StatelessWidget {
  const _BarberRow({required this.row, required this.onRecord, required this.onCommission});

  final BarberBalance row;
  final VoidCallback onRecord;
  final VoidCallback onCommission;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = row.summary;
    final owed = row.balance;
    final carry = row.carry;
    return AppCard(
      key: ValueKey('payout-row-${r.barberId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.content_cut_rounded, color: AppTheme.ink, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(r.barberName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: AppTheme.textPrimary)),
              ),
              InkWell(
                key: ValueKey('payout-commission-${r.barberId}'),
                borderRadius: BorderRadius.circular(999),
                onTap: onCommission,
                child: Tooltip(
                  message: l.payoutsSetCommission,
                  child: StatusChip(
                    label: l.payoutsCommissionLine(r.commissionPercent),
                    color: AppTheme.blue,
                    background: AppTheme.blueSoft,
                    icon: Icons.edit_outlined,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!carry.isZero)
            PayoutFigureLine(
              key: ValueKey('payout-carried-${r.barberId}'),
              label: l.payoutsCarriedOver(payoutMonthLabel(fmt, carry.from)),
              value: fmt.birr(carry.amount),
              color: carry.amount < 0 ? AppTheme.danger : null,
            ),
          PayoutFigureLine(label: l.payoutsCompletedJobs, value: '${r.completedJobs}'),
          PayoutFigureLine(label: l.payoutsGross, value: fmt.birr(r.gross)),
          PayoutFigureLine(label: l.payoutsBarberShare, value: fmt.birr(r.share)),
          PayoutFigureLine(label: l.payoutsAlreadyPaid, value: fmt.birr(r.paid)),
          const Divider(height: 18, color: AppTheme.hairline),
          PayoutFigureLine(
            key: ValueKey('payout-balance-${r.barberId}'),
            label: l.payoutsBalanceOwed,
            value: fmt.birr(owed),
            strong: true,
            color: owed > 0 ? AppTheme.success : (owed < 0 ? AppTheme.danger : AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: ValueKey('payout-record-${r.barberId}'),
              onPressed: onRecord,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text(l.payoutsRecord),
            ),
          ),
        ],
      ),
    );
  }
}

/// One payout in a history list. [onDelete] null hides the delete action.
class PayoutTile extends StatelessWidget {
  const PayoutTile({super.key, required this.payout, this.barberName, this.onDelete});

  final Payout payout;
  final String? barberName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final details = [
      l.payoutMethodLabel(payout.method),
      l.payoutsPeriod(payoutPeriodLabel(fmt, payout)),
      l.payoutsRecordedOn(fmt.addisDateMedium(payout.createdAt)),
      if (payout.note != null) payout.note!,
    ];
    return AppCard(
      key: ValueKey('payout-${payout.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(icon: Icons.payments_outlined, color: AppTheme.green, background: AppTheme.greenSoft, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barberName == null ? fmt.birr(payout.amount) : '${fmt.birr(payout.amount)} · $barberName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                for (final d in details)
                  Text(d, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              key: ValueKey('payout-delete-${payout.id}'),
              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
              tooltip: l.payoutsDelete,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Owner: records a payout to one barber for [month] (whole month period).
/// The amount is prefilled with the balance owed, including what carried
/// over from earlier months; paying part of it leaves the rest for the next
/// month. Pops `true` when saved.
class RecordPayoutSheet extends StatefulWidget {
  const RecordPayoutSheet({
    super.key,
    required this.manager,
    required this.shopId,
    required this.month,
    required this.summary,
    this.carriedOver = 0,
  });

  final PayoutsManager manager;
  final String shopId;
  final PayoutMonth month;
  final BarberPayoutSummary summary;

  /// Unpaid (or, negative, overpaid) amount carried in from earlier months.
  final double carriedOver;

  /// What is owed in total for [month].
  double get balance => carriedOver + summary.balance;

  @override
  State<RecordPayoutSheet> createState() => _RecordPayoutSheetState();
}

class _RecordPayoutSheetState extends State<RecordPayoutSheet> {
  late final TextEditingController _amount =
      TextEditingController(text: _amountText(widget.balance > 0 ? widget.balance : 0));
  final TextEditingController _note = TextEditingController();
  PayoutMethod _method = PayoutMethod.cash;
  String? _error;
  bool _saving = false;

  static String _amountText(double v) {
    if (v <= 0) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final amount = parsePayoutAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = l.payoutsErrorText(PayoutException(PayoutErrorCode.invalidAmount)));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.manager.recordPayout(
        shopId: widget.shopId,
        barberId: widget.summary.barberId,
        amount: amount,
        method: _method,
        month: widget.month,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.payoutsErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final period = '${fmt.dateMedium(widget.month.firstDay)} - ${fmt.dateMedium(widget.month.lastDay)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.payoutsRecordTitle(widget.summary.barberName),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(l.payoutsPeriod(period), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${l.payoutsBalanceOwed}: ${fmt.birr(widget.balance)}',
                key: const ValueKey('payout-sheet-balance'),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            if (widget.carriedOver != 0) ...[
              const SizedBox(height: 4),
              Text(
                '${l.payoutsCarriedOver(payoutMonthLabel(fmt, widget.month.previous()))}: '
                '${fmt.birr(widget.carriedOver)}. ${l.payoutsCarryHint}',
                key: const ValueKey('payout-sheet-carry'),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('payout-amount-field'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.payoutsAmount, prefixIcon: const Icon(Icons.payments_outlined)),
            ),
            const SizedBox(height: 14),
            Text(l.payoutsMethod, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in PayoutMethod.values)
                  ChoiceChip(
                    key: ValueKey('payout-method-${m.name}'),
                    label: Text(l.payoutMethodLabel(m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('payout-note-field'),
              controller: _note,
              maxLength: kMaxPayoutNoteLength,
              decoration: InputDecoration(labelText: l.payoutsNote),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, key: const ValueKey('payout-error'), style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('payout-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.payoutsSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner: edits [barber]'s commission. Returns `true` when saved.
Future<bool?> showCommissionDialog(BuildContext context, Barber barber, {PayoutsManager? manager}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => CommissionDialog(barber: barber, manager: manager ?? PayoutsManager.instance),
    );

class CommissionDialog extends StatefulWidget {
  const CommissionDialog({super.key, required this.barber, required this.manager});

  final Barber barber;
  final PayoutsManager manager;

  @override
  State<CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends State<CommissionDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: '${commissionOf(widget.barber)}');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final percent = int.tryParse(_ctrl.text.trim());
    if (percent == null || !isValidCommissionPercent(percent)) {
      setState(() => _error = l.payoutsErrInvalidCommission);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.manager.setCommission(widget.barber.id, percent);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.payoutsErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.payoutsCommissionTitle(widget.barber.name), style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('commission-field'),
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.payoutsCommissionPercent,
              helperText: l.payoutsCommissionHelp,
              helperMaxLines: 3,
              errorText: _error,
              errorMaxLines: 3,
              suffixText: '%',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('commission-save'),
          onPressed: _saving ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
