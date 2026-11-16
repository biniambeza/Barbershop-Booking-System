import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/subscription_state.dart'; // subscription expiry
import '../../shared/widgets/ui_kit.dart';
import '../widgets/payment_status_badge.dart';
import 'receipt_image.dart';
import 'receipts_l10n.dart';
import 'subscription_receipts_service.dart';

/// Owner: pay the platform subscription by telebirr / CBE transfer. Shows
/// the prices and where to pay, takes the transaction number, amount and a
/// receipt photo, and lists the owner's receipts with their status.
class ReceiptPaymentScreen extends StatefulWidget {
  const ReceiptPaymentScreen({super.key, required this.shopId, this.service, this.imagePicker});

  final String shopId;

  /// Defaults to [SubscriptionReceiptsService.instance].
  final SubscriptionReceiptsService? service;

  /// Defaults to the device camera / gallery.
  final ReceiptImagePicker? imagePicker;

  @override
  State<ReceiptPaymentScreen> createState() => _ReceiptPaymentScreenState();
}

class _ReceiptPaymentScreenState extends State<ReceiptPaymentScreen> {
  final _repo = AppRepository.instance;
  late final SubscriptionReceiptsService _service = widget.service ?? SubscriptionReceiptsService.instance;
  late final Stream<SubscriptionPricing> _pricing = _service.watchPricing();
  late final Stream<List<SubscriptionPayment>> _history = _service.watchMine(widget.shopId);

  final _txController = TextEditingController();
  final _amountController = TextEditingController();
  final _suffixController = TextEditingController();
  ReceiptMethod _method = ReceiptMethod.telebirr;

  /// Methods owners can pay with right now (receivers setup); empty while
  /// the admin has not set up a telebirr number or CBE account.
  List<ReceiptMethod> _payable = const [];

  /// [_method], or the first payable method when [_method] is not offered.
  ReceiptMethod get _activeMethod =>
      _payable.isEmpty || _payable.contains(_method) ? _method : _payable.first;

  PickedReceiptImage? _image;
  bool _picking = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _txController.dispose();
    _amountController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickImage({required bool camera}) async {
    setState(() => _picking = true);
    try {
      final picked = await (widget.imagePicker ?? ReceiptImagePicker()).pick(camera: camera);
      if (picked != null && mounted) setState(() => _image = picked);
    } catch (e) {
      if (mounted) _snack(context.l10n.receiptsErrorText(e is ReceiptImageException ? e : const ReceiptImageException()));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_payable.isEmpty) return; // receivers setup: payments not open yet
    final method = _activeMethod;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await _service.submit(
        shopId: widget.shopId,
        method: method,
        transactionId: _txController.text,
        amount: _amountController.text,
        receiptImageBase64: _image?.base64,
        payerAccountSuffix: method == ReceiptMethod.cbe ? _suffixController.text : null,
      );
      if (!mounted) return;
      _txController.clear();
      _amountController.clear();
      _suffixController.clear();
      setState(() => _image = null);
      _snack(l.rcptSubmitted);
    } catch (e) {
      if (mounted) _snack(l.receiptsErrorText(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack(context.l10n.rcptCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.rcptPayTitle)),
      body: StreamBuilder<SubscriptionPricing>(
        stream: _pricing,
        builder: (context, snap) {
          // receivers setup: wait for the real config so "not open" never flashes
          if (!snap.hasData && !snap.hasError) return const Center(child: CircularProgressIndicator());
          final pricing = snap.data ?? SubscriptionPricing.defaults;
          _payable = pricing.payableMethods;
          return ListenableBuilder(
            listenable: _repo,
            builder: (context, _) {
              final shop = _repo.getShopById(widget.shopId);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (shop != null) _currentCard(shop),
                  const SizedBox(height: 12),
                  Text(l.rcptIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  SectionHeader(title: l.rcptPricesTitle),
                  const SizedBox(height: 8),
                  _tiersCard(pricing),
                  const SizedBox(height: 20),
                  SectionHeader(title: l.rcptWhereToPay),
                  const SizedBox(height: 8),
                  if (_payable.isEmpty) const PaymentsNotOpenNotice() else _receiversCard(pricing),
                  const SizedBox(height: 20),
                  SectionHeader(title: l.rcptSubmitTitle),
                  const SizedBox(height: 8),
                  _form(pricing),
                  const SizedBox(height: 24),
                  SectionHeader(title: l.rcptHistoryTitle),
                  const SizedBox(height: 8),
                  _historyList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _currentCard(Barbershop shop) {
    final l = context.l10n;
    final ends = shop.subscriptionEndsAt;
    return HeroCard(
      key: const ValueKey('receipt-current-subscription'),
      child: Row(
        children: [
          const IconTile(icon: Icons.workspace_premium_rounded, color: AppTheme.onInk, background: AppTheme.charcoal),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.rcptCurrentSub, style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  ends == null ? l.rcptNoEnd : l.rcptPaidUntil(context.fmt.addisDateMedium(ends)),
                  style: const TextStyle(color: AppTheme.onInk, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // subscription expiry: the effective status (subscription_state.dart).
          SubscriptionStatusChip(status: shop.effectiveStatusAt(_repo.nowUtc())),
        ],
      ),
    );
  }

  Widget _tiersCard(SubscriptionPricing pricing) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // Own Material so the tiles' ink shows above the card's colour.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final t in pricing.tiers)
              ListTile(
                key: ValueKey('receipt-tier-${t.days}'),
                leading: const Icon(Icons.event_repeat_rounded, color: AppTheme.purple),
                title: Text(l.rcptDays(t.days), style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(context.fmt.birr(t.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                subtitle: Text(l.rcptTierUse, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                onTap: () => _amountController.text = _plainAmount(t.amount),
              ),
          ],
        ),
      ),
    );
  }

  static String _plainAmount(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _receiversCard(SubscriptionPricing pricing) {
    final l = context.l10n;
    Widget row(ReceiptMethod method, String label, PaymentReceiver r) => ListTile(
          leading: IconTile(icon: receiptMethodIcon(method), size: 40),
          title: Text(l.receiptMethodLabel(method), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: r.isConfigured
              ? Text('$label: ${r.account}\n${l.rcptReceiverName(r.name)}', style: const TextStyle(fontSize: 12.5))
              : Text(l.rcptNotConfigured, style: const TextStyle(fontSize: 12.5, color: AppTheme.warning)),
          isThreeLine: r.isConfigured,
          trailing: r.isConfigured
              ? IconButton(
                  key: ValueKey('copy-receiver-${method.name}'),
                  tooltip: l.rcptCopy,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () => _copy(r.account),
                )
              : null,
        );
    // receivers setup: a method whose receiver is not set up is hidden
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            if (pricing.telebirrReady) row(ReceiptMethod.telebirr, l.rcptReceiverNumber, pricing.telebirr),
            if (pricing.telebirrReady && pricing.cbeReady) const Divider(height: 1, color: AppTheme.hairline),
            if (pricing.cbeReady) row(ReceiptMethod.cbe, l.rcptReceiverAccount, pricing.cbe),
          ],
        ),
      ),
    );
  }

  Widget _form(SubscriptionPricing pricing) {
    final l = context.l10n;
    final amount = normalizeReceiptAmount(_amountController.text);
    final days = amount == null ? null : pricing.durationDaysFor(amount);
    String? amountHelper;
    String? amountError;
    if (amount != null) {
      if (days == null) {
        amountError = l.rcptAmountBelowMin(context.fmt.birr(pricing.minimumAmount));
      } else {
        amountHelper = l.rcptAmountGrants(l.rcptDays(days));
      }
    }
    final open = _payable.isNotEmpty; // receivers setup
    final busy = _submitting || _picking || !open;
    final method = _activeMethod;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.rcptMethodLabel, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          SegmentedButton<ReceiptMethod>(
            key: const ValueKey('receipt-method'),
            showSelectedIcon: false,
            segments: [
              for (final m in open ? _payable : ReceiptMethod.values)
                ButtonSegment(value: m, label: Text(l.receiptMethodLabel(m, short: true)), icon: Icon(receiptMethodIcon(m), size: 16)),
            ],
            selected: {method},
            onSelectionChanged: busy ? null : (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('receipt-tx'),
            controller: _txController,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')), LengthLimitingTextInputFormatter(40)],
            decoration: InputDecoration(
              labelText: l.rcptTxLabel,
              hintText: switch (method) {
                ReceiptMethod.telebirr => l.rcptTxHintTelebirr,
                ReceiptMethod.cbe => l.rcptTxHintCbe,
                ReceiptMethod.other => l.rcptTxHintOther,
              },
            ),
          ),
          if (method == ReceiptMethod.cbe) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('receipt-suffix'),
              controller: _suffixController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
              decoration: InputDecoration(labelText: l.rcptSuffixLabel, helperText: l.rcptSuffixHelper),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('receipt-amount'),
            controller: _amountController,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(12)],
            decoration: InputDecoration(labelText: l.rcptAmountLabel, helperText: amountHelper, errorText: amountError),
          ),
          const SizedBox(height: 16),
          Text(l.rcptPhotoLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(l.rcptPhotoHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          if (_image != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                  child: Image.memory(_image!.jpeg, height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    key: const ValueKey('receipt-remove-photo'),
                    tooltip: l.rcptRemovePhoto,
                    style: IconButton.styleFrom(backgroundColor: AppTheme.ink),
                    onPressed: busy ? null : () => setState(() => _image = null),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.onInk, size: 18),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('receipt-camera'),
                    onPressed: busy ? null : () => _pickImage(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(l.rcptTakePhoto),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('receipt-gallery'),
                    onPressed: busy ? null : () => _pickImage(camera: false),
                    icon: _picking
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l.rcptChooseImage),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            key: const ValueKey('receipt-submit'),
            onPressed: busy ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onInk))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(l.rcptSubmit),
          ),
        ],
      ),
    );
  }

  Widget _historyList() {
    final l = context.l10n;
    return StreamBuilder<List<SubscriptionPayment>>(
      stream: _history,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(l.receiptsErrorText(snap.error!), style: const TextStyle(color: AppTheme.danger));
        }
        final items = snap.data ?? const <SubscriptionPayment>[];
        if (items.isEmpty) {
          return Text(l.rcptNoHistory, style: const TextStyle(color: AppTheme.textSecondary));
        }
        return Column(children: [for (final p in items) ReceiptHistoryTile(payment: p)]);
      },
    );
  }
}

/// One receipt in the owner's history.
class ReceiptHistoryTile extends StatelessWidget {
  const ReceiptHistoryTile({super.key, required this.payment});

  final SubscriptionPayment payment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = payment;
    final color = receiptStatusColor(p.status);
    final details = <String>[
      context.fmt.addisDateMedium(p.createdAt),
      if (p.status == ReceiptStatus.verified && p.durationDays > 0) l.rcptGranted(l.rcptDays(p.durationDays)),
      if (p.status == ReceiptStatus.verified && p.isAutoVerified) l.rcptVerifiedAuto,
    ];
    return AppCard(
      key: ValueKey('receipt-${p.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(base64Decode(p.receiptImage!), width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => IconTile(icon: receiptMethodIcon(p.method), size: 48)),
            )
          else
            IconTile(icon: receiptMethodIcon(p.method), size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${l.receiptMethodLabel(p.method, short: true)} • ${context.fmt.birr(p.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ),
                    StatusChip(label: l.receiptStatusLabel(p.status), color: color, icon: receiptStatusIcon(p.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p.transactionId,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(details.join(' • '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (p.decisionReason != null && p.status != ReceiptStatus.verified)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.rcptReasonLine(l.receiptReasonText(p.decisionReason!)),
                        style: TextStyle(fontSize: 12, color: color)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Payments aren't open yet": no telebirr number or CBE account is set up.
class PaymentsNotOpenNotice extends StatelessWidget {
  const PaymentsNotOpenNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('receipt-payments-not-open'),
      color: AppTheme.orangeSoft,
      borderColor: AppTheme.orange,
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.l10n.rcvPaymentsNotOpen,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Owner subscription screen: the entry to [ReceiptPaymentScreen].
class ReceiptPaymentEntryCard extends StatefulWidget {
  const ReceiptPaymentEntryCard({super.key, required this.shopId, this.service});

  final String shopId;
  final SubscriptionReceiptsService? service;

  @override
  State<ReceiptPaymentEntryCard> createState() => _ReceiptPaymentEntryCardState();
}

class _ReceiptPaymentEntryCardState extends State<ReceiptPaymentEntryCard> {
  // receivers setup: says "not open yet" while no receiver is set up
  late final Stream<SubscriptionPricing> _pricing =
      (widget.service ?? SubscriptionReceiptsService.instance).watchPricing();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SubscriptionPricing>(
      stream: _pricing,
      builder: (context, snap) => _card(context, open: !snap.hasData || snap.data!.hasReadyReceiver),
    );
  }

  Widget _card(BuildContext context, {required bool open}) {
    final shopId = widget.shopId;
    final service = widget.service;
    final l = context.l10n;
    return AppCard(
      key: const ValueKey('open-receipt-payment'),
      margin: const EdgeInsets.only(top: 12),
      borderColor: open ? AppTheme.green : AppTheme.hairline,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReceiptPaymentScreen(shopId: shopId, service: service)),
      ),
      child: Row(
        children: [
          open
              ? const IconTile(icon: Icons.receipt_long_rounded, color: AppTheme.success, background: AppTheme.greenSoft)
              : const IconTile(icon: Icons.schedule_rounded, color: AppTheme.warning, background: AppTheme.orangeSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.rcptEntryTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(open ? l.rcptEntryBody : l.rcvPaymentsNotOpen,
                    key: const ValueKey('receipt-entry-body'),
                    style: TextStyle(fontSize: 12.5, color: open ? AppTheme.textSecondary : AppTheme.warning)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

/// Decodes a stored receipt photo (null when it is not valid base64).
Uint8List? decodeReceiptImage(String? base64) {
  if (base64 == null || base64.isEmpty) return null;
  try {
    return base64Decode(base64);
  } catch (_) {
    return null;
  }
}
