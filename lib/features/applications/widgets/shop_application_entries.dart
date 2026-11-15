import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/ui_kit.dart';
import '../applications_l10n.dart';
import '../screens/admin_shop_applications_screen.dart';
import '../screens/shop_application_screen.dart';
import '../shop_applications_service.dart';

/// Customer home: "Register your barbershop" card (key
/// `open-shop-application`), with the application's status once there is
/// one. Watching the application also applies the owner invite as soon as
/// it is approved. Opens the form once after sign-up when the customer
/// ticked "I own a barbershop" on the profile setup screen.
class ShopApplicationEntryCard extends StatefulWidget {
  const ShopApplicationEntryCard({super.key, this.service});

  final ShopApplicationsService? service;

  @override
  State<ShopApplicationEntryCard> createState() => _ShopApplicationEntryCardState();
}

class _ShopApplicationEntryCardState extends State<ShopApplicationEntryCard> {
  late final Stream<ShopApplication?> _stream;

  ShopApplicationsService get _service => widget.service ?? ShopApplicationsService.instance;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchMine();
    if (_service.openFormAfterSignUp) {
      _service.openFormAfterSignUp = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open();
      });
    }
  }

  void _open() => unawaited(Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopApplicationScreen(service: widget.service)),
      ));

  @override
  Widget build(BuildContext context) {
    if (!_service.canApply) return const SizedBox.shrink();
    final l = context.l10n;
    return StreamBuilder<ShopApplication?>(
      stream: _stream,
      builder: (context, snap) {
        final app = snap.data;
        return AppCard(
          key: const ValueKey('open-shop-application'),
          onTap: _open,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const IconTile(icon: Icons.add_business_outlined, color: AppTheme.green, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app?.shopName ?? l.applRegisterShopTitle,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    if (app == null)
                      Text(
                        l.applRegisterShopSubtitle,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          label: l.applicationStatusLabel(app.status),
                          color: switch (app.status) {
                            ShopApplicationStatus.pending => AppTheme.orange,
                            ShopApplicationStatus.approved => AppTheme.green,
                            ShopApplicationStatus.rejected => AppTheme.red,
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                app == null ? l.applCtaApply : l.applCtaViewStatus,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.green),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
            ],
          ),
        );
      },
    );
  }
}

/// Admin dashboard: opens the shop applications (key
/// `open-shop-applications`), with the pending count as a badge.
class AdminShopApplicationsButton extends StatefulWidget {
  const AdminShopApplicationsButton({super.key, this.service});

  final ShopApplicationsService? service;

  @override
  State<AdminShopApplicationsButton> createState() => _AdminShopApplicationsButtonState();
}

class _AdminShopApplicationsButtonState extends State<AdminShopApplicationsButton> {
  late final Stream<List<ShopApplication>> _stream;

  ShopApplicationsService get _service => widget.service ?? ShopApplicationsService.instance;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchForAdmin();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StreamBuilder<List<ShopApplication>>(
      stream: _stream,
      builder: (context, snap) {
        final pending = (snap.data ?? const []).where((a) => a.isPending).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            key: const ValueKey('open-shop-applications'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminShopApplicationsScreen(service: widget.service)),
            ),
            child: Row(
              children: [
                const IconTile(icon: Icons.assignment_ind_outlined, color: AppTheme.blue, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.applAdminTitle,
                          style:
                              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(l.applAdminPendingCount(pending),
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (pending > 0)
                  Container(
                    key: const ValueKey('shop-applications-badge'),
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.orange, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      '$pending',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
