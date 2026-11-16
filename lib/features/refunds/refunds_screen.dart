import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/booking_model.dart';
import '../../services/app_repository.dart';
import '../../services/refunds.dart' show normalizeRefundReference;
import '../shared/widgets/ui_kit.dart';

/// "Refunds due": paid bookings that were cancelled and whose money still
/// has to go back to the customer. The shop owner sees their shop
/// ([shopId]); an admin with [shopId] null sees every shop. Each entry has
/// "Mark refunded" (method + optional reference).
class RefundsScreen extends StatelessWidget {
  const RefundsScreen({super.key, this.shopId, this.repository});

  /// The owner's shop, or null for the admin's platform-wide list.
  final String? shopId;

  /// Defaults to [AppRepository.instance] (tests).
  final AppRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AppRepository.instance;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.refundsDueTitle)),
      body: StreamBuilder<List<Booking>>(
        stream: repo.watchRefundsDue(shopId: shopId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.errorText(snap.error!), textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              key: const ValueKey('refunds-empty'),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 44, color: AppTheme.textTertiary),
                    const SizedBox(height: 12),
                    Text(l.refundsEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            key: const ValueKey('refunds-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: items.length,
            itemBuilder: (context, i) => _RefundTile(booking: items[i], repo: repo, showShop: shopId == null),
          );
        },
      ),
    );
  }
}

class _RefundTile extends StatelessWidget {
  const _RefundTile({required this.booking, required this.repo, required this.showShop});

  final Booking booking;
  final AppRepository repo;
  final bool showShop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final refund = booking.refund!;
    final customer = booking.customerName.trim().isEmpty ? booking.customerPhone : booking.customerName;
    return AppCard(
      key: ValueKey('refund-${booking.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: Icons.currency_exchange_rounded, color: AppTheme.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        booking.serviceName,
                        if (showShop && booking.shopName.isNotEmpty) booking.shopName,
                        '${fmt.addisDateMedium(booking.startAt)} ${fmt.bookingTime(booking)}',
                      ].join(' · '),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(fmt.birr(refund.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${l.refundReasonName(refund.reason)} · ${l.refundFlaggedOn(fmt.addisDateMedium(refund.flaggedAt))}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (booking.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(fmt.phone(booking.customerPhone), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: ValueKey('refund-mark-${booking.id}'),
              onPressed: () => showMarkRefundedDialog(context, booking, repository: repo),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(l.refundMarkButton),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the refund method and an optional reference, then marks the
/// refund of [booking] as sent. Returns true when it was saved.
Future<bool> showMarkRefundedDialog(BuildContext context, Booking booking, {AppRepository? repository}) async {
  final repo = repository ?? AppRepository.instance;
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _MarkRefundedDialog(booking: booking, repo: repo),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.refundMarkedSnack)));
  }
  return saved == true;
}

class _MarkRefundedDialog extends StatefulWidget {
  const _MarkRefundedDialog({required this.booking, required this.repo});

  final Booking booking;
  final AppRepository repo;

  @override
  State<_MarkRefundedDialog> createState() => _MarkRefundedDialogState();
}

class _MarkRefundedDialogState extends State<_MarkRefundedDialog> {
  RefundMethod _method = RefundMethod.telebirr;
  final _reference = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.markRefunded(
        widget.booking,
        method: _method,
        reference: normalizeRefundReference(_reference.text),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;
    final customer = b.customerName.trim().isEmpty ? b.customerPhone : b.customerName;
    return AlertDialog(
      title: Text(l.refundMarkTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.refundMarkBody(context.fmt.birr(b.refund?.amount ?? 0), customer)),
            const SizedBox(height: 16),
            DropdownButtonFormField<RefundMethod>(
              key: const ValueKey('refund-method'),
              initialValue: _method,
              decoration: InputDecoration(labelText: l.refundMethodLabel),
              items: [
                for (final m in RefundMethod.values)
                  DropdownMenuItem(value: m, child: Text(l.refundMethodName(m.name))),
              ],
              onChanged: _saving ? null : (m) => setState(() => _method = m ?? _method),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('refund-reference'),
              controller: _reference,
              enabled: !_saving,
              maxLength: kMaxRefundReferenceLength,
              decoration: InputDecoration(labelText: l.refundReferenceLabel, hintText: l.refundReferenceHint),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 12.5)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          key: const ValueKey('refund-confirm'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.refundMarkButton),
        ),
      ],
    );
  }
}
