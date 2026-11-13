import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/addis_time.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/plan_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/payment_service.dart';
import '../../payments/payment_flow.dart';
import '../../payments/widgets/payment_status_badge.dart';

/// Platform admin: every shop's subscription (with manual changes for cash
/// or bank payments via setShopSubscription) and the plan catalogue in
/// `plans`.
class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key, this.service, this.clock});

  final PaymentService? service;

  /// Overrides the clock (tests).
  final DateTime Function()? clock;

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  final _repo = AppRepository.instance;
  late final PaymentService _payments = widget.service ?? PaymentService.instance;

  DateTime get _now => (widget.clock?.call() ?? DateTime.now()).toUtc();

  String _date(DateTime utc) => context.fmt.addisDateMedium(utc);

  static int _severity(SubscriptionStatus s) {
    switch (s) {
      case SubscriptionStatus.suspended:
        return 0;
      case SubscriptionStatus.pastDue:
        return 1;
      case SubscriptionStatus.trialing:
        return 2;
      case SubscriptionStatus.active:
        return 3;
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on PaymentException catch (e) {
      if (mounted) await showPaymentError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final shops = _repo.getShops().toList()
            ..sort((a, b) {
              final c = _severity(a.subscriptionStatus).compareTo(_severity(b.subscriptionStatus));
              if (c != 0) return c;
              final ae = a.subscriptionEndsAt, be = b.subscriptionEndsAt;
              if (ae == null || be == null) return ae == null ? 1 : -1;
              return ae.compareTo(be);
            });
          final plans = _repo.getPlans().toList()
            ..sort((a, b) => a.priceMonthlyEtb.compareTo(b.priceMonthlyEtb));

          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.subscriptionsAndPlans),
              bottom: TabBar(
                indicatorColor: AppTheme.primaryGold,
                labelColor: AppTheme.primaryGold,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: [
                  Tab(text: context.l10n.tabShops(shops.length)),
                  Tab(text: context.l10n.tabPlans(plans.length)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildShops(shops),
                _buildPlans(plans),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Shops ---

  Widget _buildShops(List<Barbershop> shops) {
    if (shops.isEmpty) return Center(child: Text(context.l10n.noBarbershopsYet));
    final counts = <SubscriptionStatus, int>{};
    for (final s in shops) {
      counts[s.subscriptionStatus] = (counts[s.subscriptionStatus] ?? 0) + 1;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in SubscriptionStatus.values)
              Chip(
                label: Text(context.l10n.statusCountChip(context.l10n.subscriptionStatus(status), counts[status] ?? 0)),
                side: BorderSide(color: SubscriptionStatusChip.colorFor(status).withValues(alpha: 0.5)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final shop in shops) _buildShopTile(shop),
      ],
    );
  }

  Widget _buildShopTile(Barbershop shop) {
    final days = subscriptionDaysLeft(shop.subscriptionEndsAt, _now);
    final ends = shop.subscriptionEndsAt;
    final l = context.l10n;
    final endText = ends == null
        ? l.noEndDate
        : days! < 0
            ? l.endedDaysAgo(_date(ends), -days)
            : l.endsDaysLeft(_date(ends), days);
    return Card(
      key: ValueKey('admin-sub-${shop.id}'),
      color: AppTheme.darkCard,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${l.planName(shop.subscriptionPlan, _repo.getPlan(shop.subscriptionPlan))} • $endText'
          '${shop.subCity.isEmpty ? '' : '\n${l.placeName(shop.subCity)}'}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: shop.subCity.isNotEmpty,
        trailing: SubscriptionStatusChip(status: shop.subscriptionStatus),
        onTap: () => _editShop(shop),
      ),
    );
  }

  Future<void> _editShop(Barbershop shop) async {
    final change = await showDialog<_SubscriptionChange>(
      context: context,
      builder: (_) => _SubscriptionDialog(shop: shop, plans: _repo.getPlans()),
    );
    if (change == null || !mounted) return;
    await _run(
      () => _payments.setShopSubscription(
        shopId: shop.id,
        plan: change.plan,
        status: change.status,
        endsAt: change.endsAt,
        months: change.months,
      ),
      context.l10n.subscriptionUpdated(shop.name),
    );
  }

  // --- Plans ---

  Widget _buildPlans(List<SubscriptionPlan> plans) {
    final missing = SubscriptionPlan.knownIds.where((id) => !plans.any((p) => p.id == id)).toList();
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('seed-plans'),
                onPressed: _seedPlans,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(l.createDefaultPlans),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                key: const ValueKey('add-plan'),
                onPressed: missing.isEmpty ? null : () => _editPlan(null, missing),
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.addPlan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l.plansExplainer,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty) Text(l.noPlansYet),
        for (final plan in plans)
          Card(
            key: ValueKey('admin-plan-${plan.id}'),
            color: AppTheme.darkCard,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text('${plan.name} (${plan.id})'),
              subtitle: Text(
                '${l.perMonth(context.fmt.birr(plan.priceMonthlyEtb))} • ${l.barberLimit(plan)}'
                '${plan.features.isEmpty ? '' : '\n${plan.features.join(' • ')}'}',
                style: const TextStyle(fontSize: 12),
              ),
              isThreeLine: plan.features.isNotEmpty,
              onTap: () => _editPlan(plan, const []),
              trailing: Switch(
                value: plan.active,
                onChanged: (v) => _run(
                  () => _payments.setPlanActive(plan, v),
                  v ? l.planActivated(plan.name) : l.planDeactivated(plan.name),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _seedPlans() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final written = await _payments.seedDefaultPlans();
      messenger.showSnackBar(SnackBar(
        content: Text(written.isEmpty ? l.defaultPlansExist : l.createdPlans(written.join(', '))),
      ));
    } on PaymentException catch (e) {
      if (mounted) await showPaymentError(context, e);
    }
  }

  Future<void> _editPlan(SubscriptionPlan? plan, List<String> newIds) async {
    final result = await showDialog<SubscriptionPlan>(
      context: context,
      builder: (_) => _PlanDialog(plan: plan, newIds: newIds),
    );
    if (result == null || !mounted) return;
    await _run(() => _payments.savePlan(result), context.l10n.planSaved(result.name));
  }
}

class _SubscriptionChange {
  final String? plan;
  final SubscriptionStatus? status;
  final DateTime? endsAt;
  final int? months;

  const _SubscriptionChange({this.plan, this.status, this.endsAt, this.months});
}

enum _EndMode { keep, extend, date }

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({required this.shop, required this.plans});

  final Barbershop shop;
  final List<SubscriptionPlan> plans;

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  late String _plan = widget.shop.subscriptionPlan;
  late SubscriptionStatus _status = widget.shop.subscriptionStatus;
  _EndMode _mode = _EndMode.extend;
  int _months = 1;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final planIds = {...SubscriptionPlan.knownIds, widget.shop.subscriptionPlan}.toList();
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Text(widget.shop.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.manualSubscriptionHint, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: InputDecoration(labelText: l.planLabel),
              items: [
                for (final id in planIds)
                  DropdownMenuItem(
                    value: id,
                    child: Text(l.planName(id, widget.plans.where((p) => p.id == id).firstOrNull)),
                  ),
              ],
              onChanged: (v) => setState(() => _plan = v ?? _plan),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SubscriptionStatus>(
              initialValue: _status,
              decoration: InputDecoration(labelText: l.statusLabel),
              items: [
                for (final s in SubscriptionStatus.values) DropdownMenuItem(value: s, child: Text(l.subscriptionStatus(s))),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 12),
            Text(l.endDate, style: const TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<_EndMode>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v ?? _mode),
              child: Column(
                children: [
                  RadioListTile<_EndMode>(
                    value: _EndMode.extend,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Text(l.addMonthsPrefix),
                        DropdownButton<int>(
                          value: _months,
                          items: [
                            for (var m = 1; m <= kMaxManualMonths; m++) DropdownMenuItem(value: m, child: Text('$m')),
                          ],
                          onChanged: (v) => setState(() {
                            _months = v ?? 1;
                            _mode = _EndMode.extend;
                          }),
                        ),
                        Text(l.monthsSuffix(_months)),
                      ],
                    ),
                  ),
                  RadioListTile<_EndMode>(
                    value: _EndMode.date,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_endDate == null ? l.setADate : context.fmt.dateMedium(_endDate!)),
                  ),
                  RadioListTile<_EndMode>(
                    value: _EndMode.keep,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.keepCurrentEndDate),
                  ),
                ],
              ),
            ),
            if (_mode == _EndMode.date || _endDate == null)
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event, size: 16),
                label: Text(l.pickEndDate),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        ElevatedButton(
          key: const ValueKey('save-subscription'),
          onPressed: _mode == _EndMode.date && _endDate == null ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = widget.shop.subscriptionEndsAt != null ? toAddisWallClock(widget.shop.subscriptionEndsAt!) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(2000)) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _mode = _EndMode.date;
      });
    }
  }

  void _save() {
    final shop = widget.shop;
    final status = _status == shop.subscriptionStatus && _mode == _EndMode.extend ? null : _status;
    DateTime? endsAt;
    if (_mode == _EndMode.date && _endDate != null) {
      // End of the chosen Addis day.
      endsAt = addisLocalToUtc(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59);
    }
    Navigator.of(context).pop(_SubscriptionChange(
      plan: _plan == shop.subscriptionPlan ? null : _plan,
      // Extending sets 'active' on the server unless a status is given.
      status: status,
      endsAt: endsAt,
      months: _mode == _EndMode.extend ? _months : null,
    ));
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({required this.plan, required this.newIds});

  /// Null to create a plan with one of [newIds].
  final SubscriptionPlan? plan;
  final List<String> newIds;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late String _id = widget.plan?.id ?? widget.newIds.first;
  late final _name = TextEditingController(text: widget.plan?.name ?? planDisplayName(_id));
  late final _price = TextEditingController(text: widget.plan == null ? '' : widget.plan!.priceMonthlyEtb.toStringAsFixed(0));
  late bool _unlimited = widget.plan?.isUnlimited ?? false;
  late final _maxBarbers = TextEditingController(
    text: widget.plan == null || widget.plan!.isUnlimited ? '3' : '${widget.plan!.maxBarbers}',
  );
  late final _features = TextEditingController(text: widget.plan?.features.join('\n') ?? '');
  late bool _active = widget.plan?.active ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _maxBarbers.dispose();
    _features.dispose();
    super.dispose();
  }

  void _save() {
    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    final max = _unlimited ? -1 : int.tryParse(_maxBarbers.text.trim());
    if (price == null || max == null) {
      setState(() => _error = context.l10n.enterValidPlanValues);
      return;
    }
    final plan = SubscriptionPlan(
      id: _id,
      name: _name.text.trim(),
      priceMonthlyEtb: price,
      maxBarbers: max,
      features: _features.text.split('\n').map((f) => f.trim()).where((f) => f.isNotEmpty).toList(),
      active: _active,
    );
    final error = validatePlan(plan);
    if (error != null) {
      setState(() => _error = context.l10n.errorText(error));
      return;
    }
    Navigator.of(context).pop(plan);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Text(widget.plan == null ? l.newPlan : l.editPlan(widget.plan!.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.plan == null)
              DropdownButtonFormField<String>(
                initialValue: _id,
                decoration: InputDecoration(labelText: l.planId),
                items: [for (final id in widget.newIds) DropdownMenuItem(value: id, child: Text(id))],
                onChanged: (v) => setState(() => _id = v ?? _id),
              ),
            TextField(
              key: const ValueKey('plan-name'),
              controller: _name,
              decoration: InputDecoration(labelText: l.nameLabel),
            ),
            TextField(
              key: const ValueKey('plan-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.pricePerMonth, suffixText: l.currencyEtb),
            ),
            CheckboxListTile(
              value: _unlimited,
              contentPadding: EdgeInsets.zero,
              title: Text(l.planUnlimitedBarbers),
              onChanged: (v) => setState(() => _unlimited = v ?? false),
            ),
            if (!_unlimited)
              TextField(
                key: const ValueKey('plan-max-barbers'),
                controller: _maxBarbers,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.maxBarbers),
              ),
            TextField(
              controller: _features,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(labelText: l.featuresOnePerLine),
            ),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(l.availableToOwners),
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        ElevatedButton(key: const ValueKey('save-plan'), onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
