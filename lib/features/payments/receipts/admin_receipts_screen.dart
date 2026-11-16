import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_pricing_screen.dart';
import 'receipt_photo.dart';
import 'receipts_l10n.dart';
import 'subscription_receipts_service.dart';

/// Admin: subscription receipts to verify (free plan path - with the
/// payments Cloud Function most are verified automatically and only the
/// 'needs_review' ones land here), plus recent decisions.
class AdminReceiptsScreen extends StatefulWidget {
  const AdminReceiptsScreen({super.key, this.service});

  final SubscriptionReceiptsService? service;

  @override
  State<AdminReceiptsScreen> createState() => _AdminReceiptsScreenState();
}

class _AdminReceiptsScreenState extends State<AdminReceiptsScreen> {
  late final SubscriptionReceiptsService _service = widget.service ?? SubscriptionReceiptsService.instance;
  late final Stream<List<SubscriptionPayment>> _stream = _service.watchForAdmin();
  late final Stream<SubscriptionPricing> _pricing = _service.watchPricing();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rcptAdminTitle),
        actions: [
          IconButton(
            key: const ValueKey('open-receipt-pricing'),
            tooltip: l.rcptPricingTitle,
            icon: const Icon(Icons.price_change_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminPricingScreen(service: _service)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<SubscriptionPricing>(
        stream: _pricing,
        builder: (context, pricingSnap) {
          final pricing = pricingSnap.data ?? SubscriptionPricing.defaults;
          return StreamBuilder<List<SubscriptionPayment>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.rcptAdminLoadFailed(l.receiptsErrorText(snap.error!)), textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final items = snap.data!;
              final open = items.where((p) => p.status.isOpen).toList();
              final decided = items.where((p) => !p.status.isOpen).toList();
              return ListenableBuilder(
                listenable: AppRepository.instance,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(l.rcptAdminIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    SectionHeader(title: '${l.rcptAdminOpenSection} (${open.length})'),
                    const SizedBox(height: 8),
                    if (open.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(l.rcptAdminEmpty, style: const TextStyle(color: AppTheme.textSecondary)),
                      ),
                    for (final p in open) _AdminReceiptCard(payment: p, pricing: pricing, service: _service, onTap: () => _open(p)),
                    if (decided.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SectionHeader(title: l.rcptAdminDecidedSection),
                      const SizedBox(height: 8),
                      for (final p in decided)
                        _AdminReceiptCard(payment: p, pricing: pricing, service: _service, onTap: () => _open(p)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _open(SubscriptionPayment payment) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminReceiptDetailScreen(payment: payment, service: _service)),
    );
  }
}

class _AdminReceiptCard extends StatelessWidget {
  const _AdminReceiptCard({required this.payment, required this.pricing, required this.service, required this.onTap});

  final SubscriptionPayment payment;
  final SubscriptionPricing pricing;
  final SubscriptionReceiptsService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = payment;
    final shop = AppRepository.instance.getShopById(p.shopId);
    final days = p.status == ReceiptStatus.verified ? p.durationDays : pricing.durationDaysFor(p.amount);
    final color = receiptStatusColor(p.status);
    return AppCard(
      key: ValueKey('admin-receipt-${p.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ReceiptPhoto(
                payment: p,
                service: service,
                width: 56,
                height: 56,
                compact: true,
                placeholder: IconTile(icon: receiptMethodIcon(p.method), size: 56),
              ),
            )
          else
            IconTile(icon: receiptMethodIcon(p.method), size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(shop?.name ?? p.shopId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: StatusChip(
                            label: l.receiptStatusLabel(p.status), color: color, icon: receiptStatusIcon(p.status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${l.receiptMethodLabel(p.method, short: true)} • ${p.transactionId}',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  [
                    context.fmt.birr(p.amount),
                    days == null ? l.rcptAdminTooLow : l.rcptAdminWouldGrant(l.rcptDays(days)),
                    l.rcptAdminSubmitted(context.fmt.addisDateMedium(p.createdAt)),
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (p.decisionReason != null)
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

/// Admin: one receipt - photo, details, link to the official receipt, and
/// Approve (with the verified amount) / Reject (with a reason).
class AdminReceiptDetailScreen extends StatefulWidget {
  const AdminReceiptDetailScreen({super.key, required this.payment, this.service, this.launcher});

  final SubscriptionPayment payment;
  final SubscriptionReceiptsService? service;

  /// Opens the official receipt URL (tests override it).
  final Future<bool> Function(Uri uri)? launcher;

  @override
  State<AdminReceiptDetailScreen> createState() => _AdminReceiptDetailScreenState();
}

class _AdminReceiptDetailScreenState extends State<AdminReceiptDetailScreen> {
  late final SubscriptionReceiptsService _service = widget.service ?? SubscriptionReceiptsService.instance;
  late final Stream<SubscriptionPricing> _pricing = _service.watchPricing();
  late final TextEditingController _amount = TextEditingController(text: _plain(widget.payment.amount));
  bool _busy = false;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openOfficial(Uri uri) async {
    final ok = await (widget.launcher?.call(uri) ?? launchUrl(uri, mode: LaunchMode.externalApplication))
        .catchError((Object _) => false);
    if (!ok && mounted) _snack(uri.toString());
  }

  Future<void> _approve() async {
    final l = context.l10n;
    final fmt = context.fmt;
    setState(() => _busy = true);
    try {
      final result =
          await _service.approve(widget.payment.id, verifiedAmount: normalizeReceiptAmount(_amount.text) ?? -1);
      if (!mounted) return;
      _snack(l.rcptApproved(l.rcptDays(result.durationDays), fmt.addisDateMedium(result.newEndsAt)));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(l.receiptsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final l = context.l10n;
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectDialog());
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.reject(widget.payment.id, reason);
      if (!mounted) return;
      _snack(l.rcptRejectedDone);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(l.receiptsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = widget.payment;
    final shop = AppRepository.instance.getShopById(p.shopId);
    return Scaffold(
      appBar: AppBar(title: Text(p.transactionId)),
      body: StreamBuilder<SubscriptionPricing>(
        stream: _pricing,
        builder: (context, snap) {
          final pricing = snap.data ?? SubscriptionPricing.defaults;
          final official = pricing.receiptUrl(p.method, p.transactionId, payerAccountSuffix: p.payerAccountSuffix);
          final amount = normalizeReceiptAmount(_amount.text);
          final days = amount == null ? null : pricing.durationDaysFor(amount);
          final newEnd = days == null
              ? null
              : extendSubscriptionByDays(shop?.subscriptionEndsAt, AppRepository.instance.nowUtc(), days);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (p.hasImage)
                AppCard(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    child: InteractiveViewer(
                      maxScale: 5,
                      // Inline (free plan) or Firebase Storage (Blaze).
                      child: ReceiptPhoto(
                        payment: p,
                        service: _service,
                        fit: BoxFit.contain,
                        imageKey: const ValueKey('admin-receipt-image'),
                      ),
                    ),
                  ),
                )
              else
                AppCard(child: Text(l.rcptAdminNoImage, style: const TextStyle(color: AppTheme.textSecondary))),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(shop?.name ?? p.shopId,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        StatusChip(
                          label: l.receiptStatusLabel(p.status),
                          color: receiptStatusColor(p.status),
                          icon: receiptStatusIcon(p.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _row(l.rcptMethodLabel, l.receiptMethodLabel(p.method)),
                    _row(l.rcptTxLabel, p.transactionId),
                    if (p.payerAccountSuffix != null) _row(l.rcptSuffixLabel, p.payerAccountSuffix!),
                    _row(l.rcptAmountLabel, context.fmt.birr(p.amount)),
                    _row(l.rcptAdminSubmittedLabel, context.fmt.addisDateMedium(p.createdAt)),
                    if (shop?.subscriptionEndsAt != null)
                      _row(l.rcptCurrentSub, l.rcptPaidUntil(context.fmt.addisDateMedium(shop!.subscriptionEndsAt!))),
                    if (p.decisionReason != null) _row(l.rcptReasonTitle, l.receiptReasonText(p.decisionReason!)),
                    const SizedBox(height: 10),
                    if (official != null)
                      OutlinedButton.icon(
                        key: const ValueKey('open-official-receipt'),
                        onPressed: () => _openOfficial(official),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(l.rcptAdminOpenOfficial),
                      )
                    else
                      Text(l.rcptAdminNoOfficial, style: const TextStyle(fontSize: 12.5, color: AppTheme.warning)),
                  ],
                ),
              ),
              if (p.status.isOpen) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('admin-receipt-amount'),
                        controller: _amount,
                        enabled: !_busy,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: l.rcptAdminVerifiedAmount,
                          helperText: days == null ? null : l.rcptAdminWouldGrant(l.rcptDays(days)),
                          errorText: amount != null && days == null ? l.rcptAdminTooLow : null,
                        ),
                      ),
                      if (newEnd != null) ...[
                        const SizedBox(height: 8),
                        Text(l.rcptAdminNewEnd(context.fmt.addisDateMedium(newEnd)),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.success)),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('admin-receipt-reject'),
                              onPressed: _busy ? null : _reject,
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: Text(l.rcptReject),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const ValueKey('admin-receipt-approve'),
                              onPressed: _busy || days == null ? null : _approve,
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: Text(l.rcptApprove),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            ),
            Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = _controller.text.trim();
    return AlertDialog(
      title: Text(l.rcptRejectTitle),
      content: TextField(
        key: const ValueKey('admin-receipt-reject-reason'),
        controller: _controller,
        autofocus: true,
        maxLength: kMaxReceiptReasonLength,
        maxLines: 3,
        minLines: 1,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: l.rcptRejectReasonLabel),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(
          key: const ValueKey('admin-receipt-reject-confirm'),
          onPressed: text.isEmpty ? null : () => Navigator.pop(context, text),
          child: Text(l.rcptReject, style: const TextStyle(color: AppTheme.danger)),
        ),
      ],
    );
  }
}

/// Admin app bar: a badge with the number of receipts waiting; hidden
/// while there are none.
class ReceiptsToReviewButton extends StatefulWidget {
  const ReceiptsToReviewButton({super.key, this.service});

  final SubscriptionReceiptsService? service;

  @override
  State<ReceiptsToReviewButton> createState() => _ReceiptsToReviewButtonState();
}

class _ReceiptsToReviewButtonState extends State<ReceiptsToReviewButton> {
  StreamSubscription<List<SubscriptionPayment>>? _sub;
  int _count = 0;

  SubscriptionReceiptsService get _service => widget.service ?? SubscriptionReceiptsService.instance;

  @override
  void initState() {
    super.initState();
    _sub = _service.watchForAdmin(decidedLimit: 1).listen(
      (items) {
        final open = items.where((p) => p.status.isOpen).length;
        if (mounted && open != _count) setState(() => _count = open);
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('open-receipts-to-review'),
      tooltip: context.l10n.rcptAdminTitle,
      icon: Badge(
        label: Text('$_count'),
        child: const Icon(Icons.receipt_long_outlined, color: AppTheme.textPrimary),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminReceiptsScreen(service: widget.service)),
      ),
    );
  }
}
