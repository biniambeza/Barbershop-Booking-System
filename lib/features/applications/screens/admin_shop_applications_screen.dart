import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/ui_kit.dart';
import '../applications_l10n.dart';
import '../shop_applications_service.dart';

/// Admin: pending shop applications (oldest first) with Approve / Reject,
/// then the recently decided ones.
class AdminShopApplicationsScreen extends StatefulWidget {
  const AdminShopApplicationsScreen({super.key, this.service});

  final ShopApplicationsService? service;

  @override
  State<AdminShopApplicationsScreen> createState() => _AdminShopApplicationsScreenState();
}

class _AdminShopApplicationsScreenState extends State<AdminShopApplicationsScreen> {
  late final Stream<List<ShopApplication>> _stream;
  final Set<String> _busy = {};

  ShopApplicationsService get _service => widget.service ?? ShopApplicationsService.instance;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchForAdmin();
  }

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _approve(ShopApplication app) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.applAdminApproveTitle(app.shopName)),
        content: Text(l.applAdminApproveBody(app.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            key: const ValueKey('appl-approve-confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: AppTheme.onPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.applAdminApprove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy.add(app.uid));
    try {
      await _service.approve(app.uid);
      _toast(l.applAdminApproved(app.shopName));
    } catch (e) {
      _toast(l.applicationsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy.remove(app.uid));
    }
  }

  Future<void> _reject(ShopApplication app) async {
    final l = context.l10n;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectDialog(shopName: app.shopName),
    );
    if (reason == null) return;
    setState(() => _busy.add(app.uid));
    try {
      await _service.reject(app.uid, reason);
      _toast(l.applAdminRejected);
    } catch (e) {
      _toast(l.applicationsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy.remove(app.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.applAdminTitle)),
      body: StreamBuilder<List<ShopApplication>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(l.applLoadFailed, style: TextStyle(color: AppTheme.textSecondary)));
          }
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: AppTheme.ink));
          final all = snap.data!;
          final pending = all.where((a) => a.isPending).toList();
          final decided = all.where((a) => !a.isPending).toList();
          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTile(icon: Icons.assignment_outlined, color: AppTheme.textSecondary, size: 54),
                    const SizedBox(height: 12),
                    Text(l.applAdminEmpty, style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SectionHeader(title: '${l.applAdminPending} (${pending.length})'),
              const SizedBox(height: 10),
              if (pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l.applAdminPendingCount(0), style: TextStyle(color: AppTheme.textSecondary)),
                ),
              for (final a in pending) _card(a),
              if (decided.isNotEmpty) ...[
                const SizedBox(height: 10),
                SectionHeader(title: l.applAdminRecent),
                const SizedBox(height: 10),
                for (final a in decided) _card(a),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _card(ShopApplication a) {
    final l = context.l10n;
    final fmt = context.fmt;
    final busy = _busy.contains(a.uid);
    final color = switch (a.status) {
      ShopApplicationStatus.pending => AppTheme.orange,
      ShopApplicationStatus.approved => AppTheme.green,
      ShopApplicationStatus.rejected => AppTheme.red,
    };
    return AppCard(
      key: ValueKey('appl-card-${a.uid}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: Icons.storefront_outlined, color: AppTheme.ink, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.shopName,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      a.isPending || a.reviewedAt == null
                          ? l.applAdminSubmittedOn(fmt.addisDateMedium(a.createdAt))
                          : l.applAdminReviewedOn(fmt.addisDateMedium(a.reviewedAt!)),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusChip(label: l.applicationStatusLabel(a.status), color: color),
            ],
          ),
          const SizedBox(height: 12),
          _line(Icons.person_outline, a.ownerName),
          _line(Icons.alternate_email, a.email),
          _line(Icons.phone_outlined, fmt.phone(a.phone)),
          _line(Icons.place_outlined, '${a.address}, ${l.placeName(a.subCity)}'),
          if (a.description != null) _line(Icons.notes_outlined, a.description!),
          if (a.isRejected && a.rejectReason != null) _line(Icons.info_outline, l.applRejectReasonLine(a.rejectReason!)),
          if (a.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('appl-reject-${a.uid}'),
                    onPressed: busy ? null : () => _reject(a),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                    child: Text(l.applAdminReject),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    key: ValueKey('appl-approve-${a.uid}'),
                    onPressed: busy ? null : () => _approve(a),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: AppTheme.onPrimary),
                    child: busy
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimary),
                          )
                        : Text(l.applAdminApprove),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
          ],
        ),
      );
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.shopName});

  final String shopName;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.pop(context, validateRejectReason(_controller.text));
    } catch (e) {
      setState(() => _error = context.l10n.applicationsErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.applAdminRejectTitle(widget.shopName)),
      content: TextField(
        key: const ValueKey('appl-reject-reason'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: kApplicationRejectReasonMax,
        decoration: InputDecoration(labelText: l.applAdminRejectReason, errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('appl-reject-confirm'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
          onPressed: _submit,
          child: Text(l.applAdminReject),
        ),
      ],
    );
  }
}
