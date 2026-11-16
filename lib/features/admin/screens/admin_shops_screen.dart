import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../applications/widgets/shop_application_entries.dart'; // shop applications
import '../../reviews/widgets/review_widgets.dart' show ShopRatingBadge;
import '../../shared/widgets/ui_kit.dart';
import '../widgets/shop_suspension_widgets.dart';
import 'admin_shop_edit_screen.dart';

/// Admin dashboard "Shops" tab: platform counts, search (name / sub-city /
/// address), filters (all, active, suspended, verified, unverified) and one
/// card per shop with its status, owner and quick actions. Tapping a card
/// opens [AdminShopEditScreen].
class AdminShopsTab extends StatefulWidget {
  const AdminShopsTab({super.key});

  @override
  State<AdminShopsTab> createState() => _AdminShopsTabState();
}

class _AdminShopsTabState extends State<AdminShopsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  AdminShopFilter _filter = AdminShopFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openEdit(Barbershop shop) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminShopEditScreen(shopId: shop.id)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final l = context.l10n;
    final allShops = repo.getShops();
    final counts = AdminShopCounts.of(allShops);
    final barberCount = repo.getAllBarbersWithShops().length;
    final shops = filterAdminShops(allShops, query: _query, filter: _filter);

    return ListView(
      key: const ValueKey('admin-shops-tab'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.adminShopsHeroTitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.onInkMuted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  HeroChip(label: l.metricRegistered, icon: Icons.storefront),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${counts.total}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppTheme.onInk, letterSpacing: -0.8),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _metric('${counts.active}', l.adminShopsMetricBookable, Icons.event_available_rounded),
                  const SizedBox(width: 10),
                  _metric('${counts.suspended}', l.adminShopsMetricSuspended, Icons.block_rounded),
                  const SizedBox(width: 10),
                  _metric('$barberCount', l.metricActiveBarbers, Icons.content_cut),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // --- shop applications ---
        const AdminShopApplicationsButton(),

        // "Add shop" is the dashboard's Register Barbershop button
        // (AdminRegisterShopScreen, owner invited by email).
        TextField(
          key: const ValueKey('admin-shops-search'),
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _query = val),
          decoration: InputDecoration(
            hintText: l.searchShopsAdminHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in AdminShopFilter.values) ...[
                _filterChip(f, _filterLabel(l, f)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: l.registeredBarbershopsCount(shops.length), padding: EdgeInsets.zero),
        const SizedBox(height: 12),
        if (shops.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Icon(Icons.storefront, size: 44, color: AppTheme.textSecondary),
                const SizedBox(height: 8),
                Text(l.noRegisteredShops, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(l.noRegisteredShopsHint,
                    textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          )
        else
          for (final shop in shops) _shopCard(shop),
      ],
    );
  }

  String _filterLabel(AppLocalizations l, AdminShopFilter f) {
    switch (f) {
      case AdminShopFilter.all:
        return l.all;
      case AdminShopFilter.active:
        return l.adminShopsFilterActive;
      case AdminShopFilter.suspended:
        return l.adminShopsFilterSuspended;
      case AdminShopFilter.verified:
        return l.filterVerifiedPartners;
      case AdminShopFilter.unverified:
        return l.adminShopsFilterUnverified;
    }
  }

  Widget _metric(String value, String label, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
            child: Icon(icon, color: AppTheme.ink, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.onInk)),
                Text(label,
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.onInkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(AdminShopFilter value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      key: ValueKey('admin-shops-filter-${value.name}'),
      label: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppTheme.onInk : AppTheme.textPrimary)),
      selected: selected,
      selectedColor: AppTheme.ink,
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
    );
  }

  Widget _shopCard(Barbershop shop) {
    final repo = AppRepository.instance;
    final l = context.l10n;
    final barbers = repo.getBarbersForShop(shop.id);
    final services = repo.getServicesForShop(shop.id);
    final owner = repo.getShopOwnerInfo(shop.id);
    final ownerLabel = owner.hasAccount
        ? [owner.user!.name, owner.user!.email ?? formatEthiopianContactPhone(owner.user!.phone ?? shop.phone)]
            .where((s) => s.isNotEmpty)
            .join(' · ')
        : owner.isInvitePending
            ? l.ownerInvitePending(owner.invite!.name, owner.invite!.email)
            : l.notAssigned;

    return AppCard(
      key: ValueKey('admin-shop-${shop.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      onTap: () => _openEdit(shop),
      borderColor: shop.isBlocked ? AppTheme.danger.withValues(alpha: 0.35) : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
                  child: Image.network(
                    shop.imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      width: 72,
                      height: 72,
                      color: AppTheme.surface,
                      child: const Icon(Icons.storefront, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shop.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (shop.isVerified) const Icon(Icons.verified, color: AppTheme.green, size: 17),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.shopAddress(shop),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.ownerLabel(ownerLabel),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AdminShopStatusChip(shop: shop),
                          _badge(l.barbersCount(barbers.length), Icons.people_outline),
                          _badge(l.servicesCount(services.length), Icons.content_cut),
                          // Average of the rated barbers' averages, or "New".
                          ShopRatingBadge(shopId: shop.id),
                        ],
                      ),
                      if (shop.adminSuspended && (shop.adminSuspendedReason ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          shop.adminSuspendedReason!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.danger),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => repo.toggleShopVerification(shop.id),
                      icon: Icon(
                        shop.isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: shop.isVerified ? AppTheme.success : AppTheme.textSecondary,
                      ),
                      label: Text(
                        shop.isVerified ? l.verified : l.verifyShop,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: shop.isVerified ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (kDemoMode)
                  IconButton(
                    tooltip: l.manageShopPortal,
                    // Demo only: open that shop's owner app.
                    onPressed: () => repo.switchRole(UserRole.barbershopOwner, targetShopId: shop.id),
                    icon: const Icon(Icons.dashboard_customize, size: 18, color: AppTheme.ink),
                  ),
                IconButton(
                  key: ValueKey('admin-shop-suspend-${shop.id}'),
                  tooltip: shop.adminSuspended ? l.adminShopsReactivate : l.adminShopsSuspend,
                  onPressed: () => shop.adminSuspended
                      ? showReactivateShopDialog(context, shop)
                      : showSuspendShopDialog(context, shop),
                  icon: Icon(
                    shop.adminSuspended ? Icons.play_circle_outline_rounded : Icons.block_rounded,
                    size: 18,
                    color: shop.adminSuspended ? AppTheme.success : AppTheme.warning,
                  ),
                ),
                IconButton(
                  key: ValueKey('admin-shop-delete-${shop.id}'),
                  tooltip: l.deleteShop,
                  onPressed: () => showDeleteShopDialog(context, shop),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                ),
                TextButton(
                  onPressed: () => _openEdit(shop),
                  child: Text(l.adminShopsEdit, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
      ],
    );
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

/// Asks for a reason (1..300 characters) and suspends [shop]. Returns true
/// when the shop was suspended.
Future<bool> showSuspendShopDialog(BuildContext context, Barbershop shop) async {
  final done = await showDialog<bool>(
    context: context,
    builder: (_) => _SuspendShopDialog(shop: shop),
  );
  if (done == true && context.mounted) _toast(context, context.l10n.adminShopsSuspendedToast(shop.name));
  return done == true;
}

class _SuspendShopDialog extends StatefulWidget {
  const _SuspendShopDialog({required this.shop});
  final Barbershop shop;

  @override
  State<_SuspendShopDialog> createState() => _SuspendShopDialogState();
}

class _SuspendShopDialogState extends State<_SuspendShopDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppRepository.instance.suspendShop(widget.shop.id, _ctrl.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = adminShopErrorText(l, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.adminShopsSuspendTitle(widget.shop.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.adminShopsSuspendBody, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('admin-suspend-reason'),
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: kMaxShopSuspendReasonLength,
            decoration: InputDecoration(labelText: l.adminShopsReasonLabel, errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('admin-suspend-confirm'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
          onPressed: _busy ? null : _submit,
          child: Text(l.adminShopsSuspend),
        ),
      ],
    );
  }
}

/// Confirms and lifts the admin suspension of [shop].
Future<bool> showReactivateShopDialog(BuildContext context, Barbershop shop) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.adminShopsReactivateTitle(shop.name)),
      content: Text(l.adminShopsReactivateBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('admin-reactivate-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.adminShopsReactivate),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await AppRepository.instance.reactivateShop(shop.id);
    if (context.mounted) _toast(context, l.adminShopsReactivatedToast(shop.name));
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, adminShopErrorText(l, e));
    return false;
  }
}

/// Typed-name confirmation listing what goes, then deletes [shop] with the
/// full cascade (upcoming bookings cancelled, staff become customers, shop
/// data deleted; past bookings kept), showing each step. A failed step can
/// be retried from the dialog. Returns true when deleted.
Future<bool> showDeleteShopDialog(BuildContext context, Barbershop shop) async {
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteShopDialog(shop: shop),
  );
  if (done == true && context.mounted) _toast(context, context.l10n.shopRemoved(shop.name));
  return done == true;
}

String _deleteStepLabel(AppLocalizations l, ShopDeletionStep step) => switch (step) {
      ShopDeletionStep.prepare => l.adminShopsDeleteStepPrepare,
      ShopDeletionStep.bookings => l.adminShopsDeleteStepBookings,
      ShopDeletionStep.staff => l.adminShopsDeleteStepStaff,
      ShopDeletionStep.data => l.adminShopsDeleteStepData,
      ShopDeletionStep.shop => l.adminShopsDeleteStepShop,
    };

class _DeleteShopDialog extends StatefulWidget {
  const _DeleteShopDialog({required this.shop});
  final Barbershop shop;

  @override
  State<_DeleteShopDialog> createState() => _DeleteShopDialogState();
}

class _DeleteShopDialogState extends State<_DeleteShopDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  /// The step running now (while busy), or the one that failed.
  ShopDeletionStep? _step;
  bool _failed = false;
  ShopDeletionPreview? _preview;

  @override
  void initState() {
    super.initState();
    AppRepository.instance.previewShopDeletion(widget.shop.id).then((p) {
      if (mounted) setState(() => _preview = p);
    }).catchError((Object e) {
      debugPrint('Shop deletion preview failed: $e');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _failed = false;
    });
    try {
      await AppRepository.instance.deleteShopConfirmed(widget.shop.id, _ctrl.text, onStep: (step) {
        if (mounted) setState(() => _step = step);
      });
      if (mounted) Navigator.pop(context, true);
    } on ShopDeletionException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
          _step = e.step;
          _error = '${l.adminShopsDeleteFailed(_deleteStepLabel(l, e.step))}\n${l.errorText(e.cause)}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = adminShopErrorText(l, e);
        });
      }
    }
  }

  Widget _item(IconData icon, String text, {Color color = AppTheme.textSecondary}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final matches = deleteConfirmationMatches(_ctrl.text, widget.shop.name);
    final p = _preview;
    final step = _step;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.deleteShopTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.adminShopsDeleteBody(widget.shop.name), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Text(l.adminShopsDeleteWillHeading, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (p == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else ...[
              _item(Icons.event_busy_rounded,
                  p.upcomingBookings == null ? l.adminShopsDeleteListBookingsUnknown : l.adminShopsDeleteListBookings(p.upcomingBookings!),
                  color: AppTheme.danger),
              _item(Icons.person_off_outlined, l.adminShopsDeleteListStaff(p.staffAccounts), color: AppTheme.danger),
              _item(Icons.content_cut_rounded, l.adminShopsDeleteListBarbers(p.barbers)),
              _item(Icons.design_services_outlined, l.adminShopsDeleteListServices(p.services)),
              if (p.pendingInvites > 0) _item(Icons.mail_outline_rounded, l.adminShopsDeleteListInvites(p.pendingInvites)),
              _item(Icons.delete_sweep_outlined, l.adminShopsDeleteListOther),
              _item(Icons.history_rounded, l.adminShopsDeleteListKept, color: AppTheme.success),
            ],
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('admin-delete-name'),
              controller: _ctrl,
              autofocus: true,
              enabled: !_busy && !_failed,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: l.adminShopsDeleteTypeName,
                hintText: widget.shop.name,
              ),
            ),
            if (_busy && step != null) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                key: const ValueKey('admin-delete-progress'),
                value: (step.index + 1) / ShopDeletionStep.values.length,
                minHeight: 4,
              ),
              const SizedBox(height: 6),
              Text(
                l.adminShopsDeleteProgress(step.index + 1, ShopDeletionStep.values.length, _deleteStepLabel(l, step)),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                key: const ValueKey('admin-delete-error'),
                style: const TextStyle(fontSize: 12, color: AppTheme.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('admin-delete-confirm'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
          onPressed: _busy || !matches ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_failed ? l.adminShopsDeleteRetry : l.delete),
        ),
      ],
    );
  }
}
