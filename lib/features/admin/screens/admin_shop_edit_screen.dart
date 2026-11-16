import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../data/addis_locations.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import '../widgets/shop_suspension_widgets.dart';
import 'admin_shops_screen.dart';

/// Admin: edit one shop (profile, verified flag, plan / status /
/// subscription end date override), see its owner, suspend / reactivate it
/// and delete it. Saves with [AppRepository.adminUpdateShop] (one write).
/// The opening hours (openingHour, closingHour, workingDays) are shown
/// read-only: only the shop owner sets them, in the Customize shop screen.
class AdminShopEditScreen extends StatefulWidget {
  const AdminShopEditScreen({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminShopEditScreen> createState() => _AdminShopEditScreenState();
}

class _AdminShopEditScreenState extends State<AdminShopEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  String _subCity = '';
  bool _verified = false;
  String _plan = 'trial';
  SubscriptionStatus _status = SubscriptionStatus.trialing;
  DateTime? _endsAt;
  bool _loaded = false;
  bool _saving = false;

  AppRepository get _repo => AppRepository.instance;

  @override
  void initState() {
    super.initState();
    final shop = _repo.getShopById(widget.shopId);
    if (shop != null) _load(shop);
  }

  void _load(Barbershop shop) {
    _name.text = shop.name;
    _address.text = shop.address;
    _landmark.text = shop.landmark ?? '';
    _phone.text = shop.phone;
    _description.text = shop.description;
    _subCity = shop.subCity;
    _verified = shop.isVerified;
    _plan = shop.subscriptionPlan;
    _status = shop.subscriptionStatus;
    _endsAt = shop.subscriptionEndsAt;
    _loaded = true;
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _landmark, _phone, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Barbershop shop) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final phone = _phone.text.trim();
    final edited = shop.copyWith(
      name: _name.text,
      address: _address.text,
      landmark: _landmark.text,
      clearLandmark: _landmark.text.trim().isEmpty,
      phone: phone.isEmpty ? '' : (normalizeEthiopianContactPhone(phone) ?? phone),
      description: _description.text,
      subCity: _subCity,
      // No opening hours: the admin never writes them (owner only).
      isVerified: _verified,
      subscriptionPlan: _plan,
      subscriptionStatus: _status,
      subscriptionEndsAt: _endsAt,
      clearSubscriptionEndsAt: _endsAt == null,
    );
    setState(() => _saving = true);
    try {
      await _repo.adminUpdateShop(edited);
      messenger.showSnackBar(SnackBar(content: Text(l.adminShopsSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(adminShopErrorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endsAt != null ? toLocalDate(_endsAt!) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    // End of the picked Addis day (23:59 Addis = 20:59 UTC).
    setState(() => _endsAt = DateTime.utc(picked.year, picked.month, picked.day, 20, 59));
  }

  /// The Addis calendar day of an instant, as a local date for the picker.
  static DateTime toLocalDate(DateTime utc) {
    final addis = utc.toUtc().add(const Duration(hours: 3));
    return DateTime(addis.year, addis.month, addis.day);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final l = context.l10n;
        final shop = _repo.getShopById(widget.shopId);
        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.adminShopsEditTitle)),
            body: Center(child: Text(l.adminShopsErrNotFound)),
          );
        }
        if (!_loaded) _load(shop);
        return Scaffold(
          appBar: AppBar(
            title: Text(l.adminShopsEditTitle),
            actions: [
              TextButton(
                key: const ValueKey('admin-shop-save'),
                onPressed: _saving ? null : () => _save(shop),
                child: Text(l.adminShopsSave, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _statusCard(shop),
                const SizedBox(height: 16),
                _ownerCard(shop),
                const SizedBox(height: 16),
                _profileCard(shop),
                const SizedBox(height: 16),
                _platformCard(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : () => _save(shop),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l.adminShopsSave),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('admin-shop-edit-delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (await showDeleteShopDialog(context, shop)) navigator.maybePop();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.deleteShop),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({required String title, required IconData icon, required List<Widget> children, Color? color}) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: color ?? AppTheme.ink, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _statusCard(Barbershop shop) {
    final l = context.l10n;
    final fmt = context.fmt;
    final reason = shop.adminSuspendedReason ?? '';
    return _card(
      title: l.adminShopsSectionStatus,
      icon: shop.isBlocked ? Icons.block_rounded : Icons.storefront,
      color: shop.isBlocked ? AppTheme.danger : AppTheme.green,
      children: [
        Text(shop.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        AdminShopStatusChip(shop: shop),
        if (shop.adminSuspended) ...[
          const SizedBox(height: 10),
          Text(
            l.adminShopsSuspendedSince(
                shop.adminSuspendedAt != null ? fmt.addisDateMedium(shop.adminSuspendedAt!) : '-', reason),
            key: const ValueKey('admin-shop-suspended-since'),
            style: const TextStyle(fontSize: 13, color: AppTheme.danger),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: shop.adminSuspended
              ? ElevatedButton.icon(
                  key: const ValueKey('admin-shop-edit-reactivate'),
                  onPressed: () => showReactivateShopDialog(context, shop),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: Text(l.adminShopsReactivate),
                )
              : OutlinedButton.icon(
                  key: const ValueKey('admin-shop-edit-suspend'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning),
                  onPressed: () => showSuspendShopDialog(context, shop),
                  icon: const Icon(Icons.block_rounded),
                  label: Text(l.adminShopsSuspend),
                ),
        ),
      ],
    );
  }

  Widget _ownerCard(Barbershop shop) {
    final l = context.l10n;
    final owner = _repo.getShopOwnerInfo(shop.id);
    final String title;
    final String subtitle;
    final Color color;
    if (owner.hasAccount) {
      title = owner.user!.name;
      subtitle = l.adminShopsOwnerSignedUp(owner.user!.email ?? formatEthiopianPhone(owner.user!.phone ?? ''));
      color = AppTheme.success;
    } else if (owner.isInvitePending) {
      title = owner.invite!.name;
      subtitle = l.adminShopsOwnerInvitePending(owner.invite!.email);
      color = AppTheme.warning;
    } else {
      title = l.adminShopsOwnerNone;
      subtitle = '';
      color = AppTheme.textSecondary;
    }
    return _card(
      title: l.adminShopsSectionOwner,
      icon: Icons.person_outline,
      children: [
        Row(
          children: [
            Icon(owner.hasAccount ? Icons.verified_user_outlined : Icons.mail_outline, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        key: const ValueKey('admin-shop-owner-status'),
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _profileCard(Barbershop shop) {
    final l = context.l10n;
    final fmt = context.fmt;
    final subCities = [
      if (_subCity.isEmpty) '',
      ...kAddisSubCities,
      if (_subCity.isNotEmpty && !kAddisSubCities.contains(_subCity)) _subCity,
    ];
    return _card(
      title: l.adminShopsSectionProfile,
      icon: Icons.storefront,
      children: [
        TextFormField(
          key: const ValueKey('admin-shop-name'),
          controller: _name,
          maxLength: kMaxShopNameLength,
          decoration: InputDecoration(labelText: l.adminShopsFieldName, counterText: ''),
          validator: (v) => (v ?? '').trim().isEmpty ? l.adminShopsErrNameRequired : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _address,
          maxLength: kMaxShopAddressLength,
          decoration: InputDecoration(labelText: l.adminShopsFieldAddress, counterText: ''),
          validator: (v) => (v ?? '').trim().isEmpty ? l.adminShopsErrAddressRequired : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _subCity,
          decoration: InputDecoration(labelText: l.adminShopsFieldSubCity),
          dropdownColor: AppTheme.card,
          items: [
            for (final sc in subCities) DropdownMenuItem(value: sc, child: Text(sc.isEmpty ? '-' : l.placeName(sc))),
          ],
          onChanged: (v) => setState(() => _subCity = v ?? _subCity),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _landmark,
          maxLength: kMaxShopAddressLength,
          decoration: InputDecoration(labelText: l.adminShopsFieldLandmark, counterText: ''),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: l.adminShopsFieldPhone),
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return null;
            return normalizeEthiopianContactPhone(value) == null ? l.invalidContactPhone : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _description,
          minLines: 2,
          maxLines: 5,
          maxLength: kMaxShopDescriptionLength,
          decoration: InputDecoration(labelText: l.adminShopsFieldDescription),
        ),
        const SizedBox(height: 4),
        // Opening hours are owner-only: shown here read-only.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.adminShopsHoursReadOnly(
                  weekdaysSummary(shop.workingDays, fmt.weekdayName),
                  fmt.hoursRange(shop.openingHour, shop.closingHour),
                ),
                key: const ValueKey('admin-shop-hours-readonly'),
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _platformCard() {
    final l = context.l10n;
    final fmt = context.fmt;
    final plans = _repo.getPlans();
    final planIds = {...plans.map((p) => p.id), _plan, 'trial'}.toList();
    return _card(
      title: l.adminShopsSectionPlatform,
      icon: Icons.workspace_premium_rounded,
      color: AppTheme.purple,
      children: [
        Text(l.adminShopsOverrideHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const ValueKey('admin-shop-verified'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.adminShopsFieldVerified, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(l.adminShopsFieldVerifiedHint),
            value: _verified,
            onChanged: (v) => setState(() => _verified = v),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _plan,
          decoration: InputDecoration(labelText: l.adminShopsFieldPlan),
          dropdownColor: AppTheme.card,
          items: [
            for (final id in planIds)
              DropdownMenuItem(value: id, child: Text(l.planName(id, plans.where((p) => p.id == id).firstOrNull))),
          ],
          onChanged: (v) => setState(() => _plan = v ?? _plan),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<SubscriptionStatus>(
          isExpanded: true,
          initialValue: _status,
          decoration: InputDecoration(labelText: l.adminShopsFieldStatus),
          dropdownColor: AppTheme.card,
          items: [
            for (final s in SubscriptionStatus.values) DropdownMenuItem(value: s, child: Text(l.subscriptionStatus(s))),
          ],
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickEndDate,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l.adminShopsFieldEndsAt),
                  child: Text(
                    _endsAt == null ? l.adminShopsNoEndDate : fmt.addisDateMedium(_endsAt!),
                    key: const ValueKey('admin-shop-ends-at'),
                  ),
                ),
              ),
            ),
            if (_endsAt != null)
              IconButton(
                tooltip: l.adminShopsClearDate,
                onPressed: () => setState(() => _endsAt = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ],
    );
  }
}
