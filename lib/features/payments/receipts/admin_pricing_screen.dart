import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/ui_kit.dart';
import 'receipts_l10n.dart';
import 'receivers_setup.dart';
import 'subscription_receipts_service.dart';

/// Admin: edits `platformConfig/subscriptionPricing` - the subscription
/// lengths and prices owners can pay for, and the telebirr / CBE accounts
/// they pay to.
class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key, this.service});

  final SubscriptionReceiptsService? service;

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _TierRow {
  _TierRow(PricingTier? t)
      : days = TextEditingController(text: t == null ? '' : '${t.days}'),
        amount = TextEditingController(
            text: t == null ? '' : (t.amount == t.amount.roundToDouble() ? t.amount.toStringAsFixed(0) : '${t.amount}'));

  final TextEditingController days;
  final TextEditingController amount;

  PricingTier? toTier() {
    final d = int.tryParse(days.text.trim());
    final a = normalizeReceiptAmount(amount.text);
    return d == null || a == null ? null : PricingTier(days: d, amount: a);
  }

  void dispose() {
    days.dispose();
    amount.dispose();
  }
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  late final SubscriptionReceiptsService _service = widget.service ?? SubscriptionReceiptsService.instance;
  SubscriptionPricing? _loaded;
  Object? _loadError;
  final List<_TierRow> _rows = [];
  final _telebirrNumber = TextEditingController();
  final _telebirrName = TextEditingController();
  final _cbeAccount = TextEditingController();
  final _cbeName = TextEditingController();
  bool _saving = false;

  /// Receipt photos in Firebase Storage (Blaze only); off = inline.
  bool _storageReceipts = false;

  /// Receiver problems found by the last save (shown under the fields).
  ReceiverCheck _telebirrCheck = const ReceiverCheck();
  ReceiverCheck _cbeCheck = const ReceiverCheck();

  @override
  void initState() {
    super.initState();
    _service.loadPricing().then(_fill, onError: (Object e) {
      if (mounted) setState(() => _loadError = e);
    });
  }

  void _fill(SubscriptionPricing p) {
    if (!mounted) return;
    setState(() {
      _loaded = p;
      for (final r in _rows) {
        r.dispose();
      }
      _rows
        ..clear()
        ..addAll(p.tiers.map(_TierRow.new));
      // The 'XXXX' sample is shown as an empty field: never saved back.
      _telebirrNumber.text = isPlaceholderReceiverAccount(p.telebirr.account) ? '' : p.telebirr.account;
      _telebirrName.text = p.telebirr.name;
      _cbeAccount.text = isPlaceholderReceiverAccount(p.cbe.account) ? '' : p.cbe.account;
      _cbeName.text = p.cbe.name;
      _storageReceipts = p.storageReceipts;
      _telebirrCheck = const ReceiverCheck();
      _cbeCheck = const ReceiverCheck();
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _telebirrNumber.dispose();
    _telebirrName.dispose();
    _cbeAccount.dispose();
    _cbeName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final tiers = _rows.map((r) => r.toTier()).toList();
    if (tiers.any((t) => t == null)) {
      messenger.showSnackBar(SnackBar(content: Text(l.rcptErrPricing)));
      return;
    }
    final telebirr = checkReceiver(ReceiptMethod.telebirr, account: _telebirrNumber.text, name: _telebirrName.text);
    final cbe = checkReceiver(ReceiptMethod.cbe, account: _cbeAccount.text, name: _cbeName.text);
    setState(() {
      _telebirrCheck = telebirr;
      _cbeCheck = cbe;
    });
    if (!telebirr.ok || !cbe.ok) {
      messenger.showSnackBar(SnackBar(content: Text(l.rcvErrFix)));
      return;
    }
    final pricing = _loaded!.copyWith(
      tiers: tiers.cast<PricingTier>(),
      telebirr: telebirr.receiver,
      cbe: cbe.receiver,
      storageReceipts: _storageReceipts,
    );
    setState(() => _saving = true);
    try {
      final saved = await _service.savePricing(pricing);
      _fill(saved);
      messenger.showSnackBar(SnackBar(content: Text(l.rcptPricingSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.receiptsErrorText(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _issue(ReceiptMethod method, ReceiverIssue? issue) =>
      issue == null ? null : context.l10n.receiverIssueText(method, issue);

  void _clearCheck(ReceiptMethod method) {
    final current = method == ReceiptMethod.cbe ? _cbeCheck : _telebirrCheck;
    if (current.ok) return;
    setState(() {
      if (method == ReceiptMethod.cbe) {
        _cbeCheck = const ReceiverCheck();
      } else {
        _telebirrCheck = const ReceiverCheck();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.rcptPricingTitle)),
      body: _loadError != null
          ? Center(child: Text(l.receiptsErrorText(_loadError!)))
          : _loaded == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(l.rcptPricingIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < _rows.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: ValueKey('pricing-days-$i'),
                                      controller: _rows[i].days,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: InputDecoration(labelText: l.rcptPricingDays),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      key: ValueKey('pricing-amount-$i'),
                                      controller: _rows[i].amount,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(labelText: l.rcptPricingAmount),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l.rcptPricingRemoveTier,
                                    onPressed: _rows.length <= 1
                                        ? null
                                        : () => setState(() => _rows.removeAt(i).dispose()),
                                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger),
                                  ),
                                ],
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _rows.length >= kMaxPricingTiers
                                  ? null
                                  : () => setState(() => _rows.add(_TierRow(null))),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l.rcptPricingAddTier),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(title: l.rcptPricingTelebirr),
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        children: [
                          TextField(
                            key: const ValueKey('pricing-telebirr-number'),
                            controller: _telebirrNumber,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => _clearCheck(ReceiptMethod.telebirr),
                            decoration: InputDecoration(
                              labelText: l.rcptReceiverNumber,
                              hintText: '0911 223344',
                              helperText: l.rcvTelebirrOptional,
                              helperMaxLines: 2,
                              errorText: _issue(ReceiptMethod.telebirr, _telebirrCheck.account),
                              errorMaxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const ValueKey('pricing-telebirr-name'),
                            controller: _telebirrName,
                            maxLength: kMaxReceiverNameLength,
                            onChanged: (_) => _clearCheck(ReceiptMethod.telebirr),
                            decoration: InputDecoration(
                              labelText: l.rcptPricingName,
                              errorText: _issue(ReceiptMethod.telebirr, _telebirrCheck.name),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(title: l.rcptPricingCbe),
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        children: [
                          TextField(
                            key: const ValueKey('pricing-cbe-account'),
                            controller: _cbeAccount,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _clearCheck(ReceiptMethod.cbe),
                            decoration: InputDecoration(
                              labelText: l.rcptReceiverAccount,
                              hintText: '1000123456789',
                              helperText: l.rcvCbeOptional,
                              helperMaxLines: 2,
                              errorText: _issue(ReceiptMethod.cbe, _cbeCheck.account),
                              errorMaxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const ValueKey('pricing-cbe-name'),
                            controller: _cbeName,
                            maxLength: kMaxReceiverNameLength,
                            onChanged: (_) => _clearCheck(ReceiptMethod.cbe),
                            decoration: InputDecoration(
                              labelText: l.rcptPricingName,
                              errorText: _issue(ReceiptMethod.cbe, _cbeCheck.name),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(title: l.rcptStorageTitle),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          key: const ValueKey('pricing-storage-receipts'),
                          value: _storageReceipts,
                          onChanged: _saving ? null : (v) => setState(() => _storageReceipts = v),
                          title: Text(l.rcptStorageToggle,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(l.rcptStorageHelp,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      key: const ValueKey('pricing-save'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onInk))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(l.rcptPricingSave),
                    ),
                  ],
                ),
    );
  }
}
