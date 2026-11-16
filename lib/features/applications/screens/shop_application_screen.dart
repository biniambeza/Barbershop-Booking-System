import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import '../applications_l10n.dart';
import '../shop_applications_service.dart';
import '../widgets/shop_application_form.dart';

/// "Register your barbershop": the signed-in customer's application. Shows
/// the form when there is none, or the status (pending: edit / withdraw;
/// rejected: reason + apply again; approved: the owner dashboard opens as
/// soon as the owner invite has been applied to this account).
class ShopApplicationScreen extends StatefulWidget {
  const ShopApplicationScreen({super.key, this.service});

  final ShopApplicationsService? service;

  @override
  State<ShopApplicationScreen> createState() => _ShopApplicationScreenState();
}

class _ShopApplicationScreenState extends State<ShopApplicationScreen> {
  late final Stream<ShopApplication?> _stream;
  bool _editing = false;
  bool _reapplying = false;
  bool _busy = false;

  ShopApplicationsService get _service => widget.service ?? ShopApplicationsService.instance;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchMine();
    AppRepository.instance.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    AppRepository.instance.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  /// Once the invite made this account an owner, RootGate shows the owner
  /// dashboard underneath: close this screen to reveal it.
  void _onRepositoryChanged() {
    final role = AppRepository.instance.currentUser?.role;
    if (!mounted || role == null || role == UserRole.customer) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openDashboard(ShopApplication app) async {
    setState(() => _busy = true);
    await _service.syncApprovedInvite(app);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _withdraw(ShopApplication app) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.applWithdrawTitle),
        content: Text(l.applWithdrawBody(app.shopName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            key: const ValueKey('appl-withdraw-confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.applWithdraw),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.withdraw();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.applWithdrawn)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.applicationsErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.applRegisterShopTitle)),
      body: StreamBuilder<ShopApplication?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(l.applLoadFailed, style: TextStyle(color: AppTheme.textSecondary)));
          }
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return Center(child: CircularProgressIndicator(color: AppTheme.ink));
          }
          final app = snap.data;
          final Widget content;
          if (app == null) {
            content = ShopApplicationForm(editing: false, service: widget.service, onDone: (_) {});
          } else if (_editing && app.isPending) {
            content = ShopApplicationForm(
              initial: app,
              editing: true,
              service: widget.service,
              onDone: (_) => setState(() => _editing = false),
              onCancel: () => setState(() => _editing = false),
            );
          } else if (_reapplying && app.isRejected) {
            content = ShopApplicationForm(
              initial: app,
              editing: false,
              service: widget.service,
              onDone: (_) => setState(() => _reapplying = false),
              onCancel: () => setState(() => _reapplying = false),
            );
          } else {
            content = _statusView(app);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content),
            ),
          );
        },
      ),
    );
  }

  Widget _statusView(ShopApplication app) {
    final l = context.l10n;
    final fmt = context.fmt;
    final (Color color, IconData icon) = switch (app.status) {
      ShopApplicationStatus.pending => (AppTheme.orange, Icons.hourglass_top_rounded),
      ShopApplicationStatus.approved => (AppTheme.green, Icons.verified_rounded),
      ShopApplicationStatus.rejected => (AppTheme.red, Icons.cancel_outlined),
    };
    final String message = switch (app.status) {
      ShopApplicationStatus.pending => l.applPendingBody(fmt.addisDateMedium(app.createdAt)),
      ShopApplicationStatus.approved => l.applApprovedBody(app.shopName),
      ShopApplicationStatus.rejected => l.applRejectedBody,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.shopName,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.onHero),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    key: ValueKey('appl-status-${app.status.name}'),
                    label: l.applicationStatusLabel(app.status),
                    color: color,
                    icon: icon,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message, style: TextStyle(fontSize: 13.5, color: AppTheme.onInkMuted, height: 1.35)),
              if (app.isRejected && app.rejectReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  l.applRejectReasonLine(app.rejectReason!),
                  style: TextStyle(fontSize: 13.5, color: AppTheme.onHero, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(l.applRejectedHint, style: TextStyle(fontSize: 12.5, color: AppTheme.onInkMuted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail(Icons.person_outline, app.ownerName),
              _detail(Icons.alternate_email, app.email),
              _detail(Icons.place_outlined, '${app.address}, ${l.placeName(app.subCity)}'),
              _detail(Icons.phone_outlined, context.fmt.phone(app.phone)),
              if (app.description != null) _detail(Icons.notes_outlined, app.description!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (app.isPending) ...[
          ElevatedButton.icon(
            key: const ValueKey('appl-edit'),
            onPressed: _busy ? null : () => setState(() => _editing = true),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l.applEdit),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('appl-withdraw'),
            onPressed: _busy ? null : () => _withdraw(app),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(l.applWithdraw),
          ),
        ],
        if (app.isRejected)
          ElevatedButton.icon(
            key: const ValueKey('appl-reapply'),
            onPressed: _busy ? null : () => setState(() => _reapplying = true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.applResubmit),
          ),
        if (app.isApproved)
          ElevatedButton.icon(
            key: const ValueKey('appl-open-dashboard'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: AppTheme.onPrimary),
            onPressed: _busy ? null : () => _openDashboard(app),
            icon: const Icon(Icons.dashboard_outlined, size: 18),
            label: Text(l.applOpenDashboard),
          ),
      ],
    );
  }

  Widget _detail(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          ],
        ),
      );
}
