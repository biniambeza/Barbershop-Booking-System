import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_users_tab.dart' show adminRoleColor, adminRoleLabel, adminUserErrorText;

/// Admin: one user's details (full email and phone), their role (customer,
/// owner of a shop, barber of a shop, admin) and their account status
/// (disable / enable). Every change asks for confirmation. The admin cannot
/// change their own role or disable themselves; the last admin stays.
class AdminUserEditScreen extends StatefulWidget {
  const AdminUserEditScreen({super.key, required this.uid});

  final String uid;

  @override
  State<AdminUserEditScreen> createState() => _AdminUserEditScreenState();
}

class _AdminUserEditScreenState extends State<AdminUserEditScreen> {
  late UserRole _role;
  String? _shopId;

  /// Barber role: the profile to link; null creates a new one.
  String? _barberId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _resetFrom(AppRepository.instance.getUserById(widget.uid));
  }

  void _resetFrom(AppUser? user) {
    _role = user?.role ?? UserRole.customer;
    _shopId = user?.shopId;
    _barberId = user?.barberId;
  }

  bool _changed(AppUser user) {
    if (_role != user.role) return true;
    if (_role == UserRole.barbershopOwner) return _shopId != user.shopId;
    if (_role == UserRole.barber) return _shopId != user.shopId || _barberId != user.barberId;
    return false;
  }

  RoleTarget get _target {
    switch (_role) {
      case UserRole.customer:
        return const RoleTarget.customer();
      case UserRole.admin:
        return const RoleTarget.admin();
      case UserRole.barbershopOwner:
        return RoleTarget(UserRole.barbershopOwner, shopId: _shopId);
      case UserRole.barber:
        return RoleTarget(UserRole.barber, shopId: _shopId, barberId: _barberId);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppTheme.danger : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final l = context.l10n;
        final user = repo.getUserById(widget.uid);
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.admUsrEditTitle)),
            body: Center(child: Text(l.admUsrErrNotFound)),
          );
        }
        final isMe = repo.currentUser?.uid == user.uid;
        return Scaffold(
          appBar: AppBar(title: Text(l.admUsrEditTitle)),
          body: ListView(
            key: const ValueKey('admin-user-edit'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _profileCard(context, user),
              if (isMe) ...[
                const SizedBox(height: 12),
                AppCard(
                  key: const ValueKey('admin-user-self-note'),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.admUsrSelfNote, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                SectionHeader(title: l.admUsrRoleSection, padding: EdgeInsets.zero),
                const SizedBox(height: 8),
                _roleCard(context, user),
                const SizedBox(height: 18),
                SectionHeader(title: l.admUsrAccountSection, padding: EdgeInsets.zero),
                const SizedBox(height: 8),
                _accountCard(context, user),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _profileCard(BuildContext context, AppUser user) {
    final l = context.l10n;
    final color = adminRoleColor(user.role);
    Widget row(IconData icon, String label, String value, String key) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 10),
              Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Expanded(
                child: SelectableText(value,
                    key: ValueKey(key), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.softOf(color),
                child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(user.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
              StatusChip(label: adminRoleLabel(l, user.role), color: color),
            ],
          ),
          if (user.email != null && user.email!.isNotEmpty)
            row(Icons.alternate_email, l.admUsrEmailLabel, user.email!, 'admin-user-email'),
          if (user.phone != null && user.phone!.isNotEmpty)
            row(Icons.phone_outlined, l.admUsrPhoneLabel, formatEthiopianPhone(user.phone!), 'admin-user-phone'),
          if (user.shopId != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(l.assignedShop(AppRepository.instance.getShopById(user.shopId!)?.name ?? user.shopId!),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.admUsrJoined(context.fmt.dateMedium(user.createdAt)),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(BuildContext context, AppUser user) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final shops = [...repo.getShops()]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final needsShop = _role == UserRole.barbershopOwner || _role == UserRole.barber;
    final shopId = shops.any((s) => s.id == _shopId) ? _shopId : null;
    final linkable =
        _role == UserRole.barber && shopId != null ? repo.linkableBarbersFor(shopId, user) : const <Barber>[];
    final barberId = linkable.any((b) => b.id == _barberId) ? _barberId : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Own Material so the tiles' ink shows on the card.
          Material(
            type: MaterialType.transparency,
            child: RadioGroup<UserRole>(
              groupValue: _role,
              onChanged: (v) {
                if (v == null || _busy) return;
                setState(() {
                  _role = v;
                  if (v == user.role) {
                    _shopId = user.shopId;
                    _barberId = user.barberId;
                  } else if (v == UserRole.barber && _shopId != user.shopId) {
                    _barberId = null;
                  }
                });
              },
              child: Column(
                children: [
                  for (final r in const [UserRole.customer, UserRole.barbershopOwner, UserRole.barber, UserRole.admin])
                    RadioListTile<UserRole>(
                      key: ValueKey('admin-user-role-${r.name}'),
                      value: r,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(adminRoleLabel(l, r)),
                    ),
                ],
              ),
            ),
          ),
          if (needsShop) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: KeyedSubtree(
                key: ValueKey('shop-$_role'),
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('admin-user-shop'),
                  initialValue: shopId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.admUsrShopLabel, hintText: l.admUsrPickShop),
                  items: [
                    for (final s in shops)
                      DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _shopId = v;
                            _barberId = v == user.shopId && user.role == UserRole.barber ? user.barberId : null;
                          }),
                ),
              ),
            ),
          ],
          if (_role == UserRole.barber && shopId != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: KeyedSubtree(
                key: ValueKey('barber-$shopId'),
                child: DropdownButtonFormField<String?>(
                  key: const ValueKey('admin-user-barber'),
                  initialValue: barberId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.admUsrBarberProfileLabel),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(l.admUsrNewBarberProfile)),
                    for (final b in linkable)
                      DropdownMenuItem<String?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _barberId = v),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              key: const ValueKey('admin-user-save-role'),
              onPressed: _busy || !_changed(user) || (needsShop && shopId == null) ? null : () => _saveRole(user),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(l.admUsrSaveRole),
            ),
          ),
        ],
      ),
    );
  }

  String _describeTarget(AppLocalizations l, AppUser after) {
    final role = adminRoleLabel(l, after.role);
    final shopId = after.shopId;
    if (shopId == null) return role;
    return l.admUsrRoleAtShop(role, AppRepository.instance.getShopById(shopId)?.name ?? shopId);
  }

  Future<void> _saveRole(AppUser user) async {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final RoleChangePlan plan;
    try {
      plan = repo.previewRoleChange(user.uid, _target);
    } catch (e) {
      _snack(adminUserErrorText(l, e), error: true);
      return;
    }
    String shopName(String id) => repo.getShopById(id)?.name ?? id;
    final effects = <String>[
      if (plan.newBarber != null) l.admUsrEffectNewBarber(shopName(plan.newBarber!.shopId)),
      if (plan.unlinkedBarber != null) l.admUsrEffectUnlinkBarber(plan.unlinkedBarber!.name),
      if (plan.releaseShopId != null) l.admUsrEffectReleaseShop(shopName(plan.releaseShopId!)),
      for (final o in plan.previousOwners) l.admUsrEffectPreviousOwner(o.name, shopName(plan.after.shopId ?? '')),
      if (plan.deleteInviteEmails.isNotEmpty) l.admUsrEffectInvites(plan.deleteInviteEmails.length),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.admUsrConfirmRoleTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.admUsrConfirmRoleBody(user.name, _describeTarget(l, plan.after))),
            for (final e in effects) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.subdirectory_arrow_right, size: 16, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            key: const ValueKey('admin-user-role-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.admUsrSaveRole),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await repo.adminChangeUserRole(user.uid, _target);
      if (!mounted) return;
      setState(() => _resetFrom(repo.getUserById(user.uid)));
      _snack(l.admUsrRoleChanged);
    } catch (e) {
      if (mounted) _snack(adminUserErrorText(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _accountCard(BuildContext context, AppUser user) {
    final l = context.l10n;
    final at = user.disabledAt;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(user.disabled ? Icons.block_rounded : Icons.verified_user_outlined,
                  color: user.disabled ? AppTheme.danger : AppTheme.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.disabled
                          ? (at == null ? l.admUsrDisabledChip : l.admUsrDisabledOn(context.fmt.dateMedium(at)))
                          : l.admUsrActive,
                      key: const ValueKey('admin-user-status'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (user.disabled && user.disabledReason != null)
                      Text(l.admUsrDisabledReason(user.disabledReason!),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (user.disabled)
            ElevatedButton.icon(
              key: const ValueKey('admin-user-enable'),
              onPressed: _busy ? null : () => _enable(user),
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(l.admUsrEnable),
            )
          else
            OutlinedButton.icon(
              key: const ValueKey('admin-user-disable'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: _busy ? null : () => _disable(user),
              icon: const Icon(Icons.block_rounded),
              label: Text(l.admUsrDisable),
            ),
        ],
      ),
    );
  }

  Future<void> _disable(AppUser user) async {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final result = await showDialog<({String? reason, bool cancel})>(
      context: context,
      builder: (_) => _DisableUserDialog(user: user, upcoming: repo.countUpcomingBookingsOf(user.uid)),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final cancelled = await repo.adminDisableUser(user.uid, reason: result.reason, cancelUpcoming: result.cancel);
      if (mounted) _snack(l.admUsrDisabledSnack(cancelled));
    } catch (e) {
      if (mounted) _snack(adminUserErrorText(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enable(AppUser user) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.admUsrEnableTitle(user.name)),
        content: Text(l.admUsrEnableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            key: const ValueKey('admin-user-enable-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.admUsrEnable),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppRepository.instance.adminEnableUser(user.uid);
      if (mounted) _snack(l.admUsrEnabledSnack);
    } catch (e) {
      if (mounted) _snack(adminUserErrorText(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Asks for the (optional) reason and whether to cancel the upcoming
/// bookings. Pops `(reason, cancel)` or null.
class _DisableUserDialog extends StatefulWidget {
  const _DisableUserDialog({required this.user, required this.upcoming});

  final AppUser user;
  final Future<int?> upcoming;

  @override
  State<_DisableUserDialog> createState() => _DisableUserDialogState();
}

class _DisableUserDialogState extends State<_DisableUserDialog> {
  final _ctrl = TextEditingController();
  bool _cancel = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final l = context.l10n;
    try {
      final reason = normalizeDisableReason(_ctrl.text);
      Navigator.pop(context, (reason: reason, cancel: _cancel));
    } catch (e) {
      setState(() => _error = adminUserErrorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.admUsrDisableTitle(widget.user.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.admUsrDisableBody, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('admin-user-disable-reason'),
              controller: _ctrl,
              minLines: 1,
              maxLines: 3,
              maxLength: kDisableReasonMaxLength,
              decoration: InputDecoration(labelText: l.admUsrReasonLabel, errorText: _error),
            ),
            FutureBuilder<int?>(
              future: widget.upcoming,
              builder: (context, snap) {
                final count = snap.data;
                final subtitle = snap.connectionState != ConnectionState.done
                    ? null
                    : (count == null ? l.admUsrUpcomingUnknown : l.admUsrUpcomingCount(count));
                return CheckboxListTile(
                  key: const ValueKey('admin-user-cancel-bookings'),
                  value: _cancel,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l.admUsrCancelBookings, style: const TextStyle(fontSize: 14)),
                  subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
                  onChanged: (v) => setState(() => _cancel = v ?? false),
                );
              },
            ),
            if (!_cancel)
              Text(l.admUsrBookingsStay, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('admin-user-disable-confirm'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
          onPressed: _submit,
          child: Text(l.admUsrDisable),
        ),
      ],
    );
  }
}
