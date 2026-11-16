import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_user_edit_screen.dart';

/// Admin dashboard, Users tab: search (name, email, phone), filter chips by
/// role (plus "Disabled"), and a tap opens [AdminUserEditScreen]. Phones
/// and emails are partly masked here; the edit screen shows them in full.
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  AdminUserFilter _filter = AdminUserFilter.all;

  @override
  void initState() {
    super.initState();
    AppRepository.instance.addListener(_onRepoChanged);
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppRepository.instance.removeListener(_onRepoChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final l = context.l10n;
    final all = repo.getAllUsers();
    final counts = countUsersByFilter(all);
    final users = filterAdminUsers(all, query: _query, filter: _filter);
    final me = repo.currentUser?.uid;

    return ListView(
      key: const ValueKey('admin-users-tab'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          key: const ValueKey('admin-users-search'),
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _query = val),
          decoration: InputDecoration(
            hintText: l.admUsrSearchHint,
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
              for (final f in AdminUserFilter.values) ...[
                _filterChip(f, _filterLabel(l, f, counts[f] ?? 0)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (users.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(Icons.person_search_outlined, size: 44, color: AppTheme.textSecondary),
                const SizedBox(height: 8),
                Text(l.admUsrEmpty, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        else
          for (final u in users) _userCard(context, u, isMe: u.uid == me),
      ],
    );
  }

  String _filterLabel(AppLocalizations l, AdminUserFilter f, int count) {
    switch (f) {
      case AdminUserFilter.all:
        return l.admUsrFilterAll(count);
      case AdminUserFilter.customer:
        return l.admUsrFilterCustomers(count);
      case AdminUserFilter.barbershopOwner:
        return l.admUsrFilterOwners(count);
      case AdminUserFilter.barber:
        return l.admUsrFilterBarbers(count);
      case AdminUserFilter.admin:
        return l.admUsrFilterAdmins(count);
      case AdminUserFilter.disabled:
        return l.admUsrFilterDisabled(count);
    }
  }

  Widget _filterChip(AdminUserFilter value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      key: ValueKey('admin-users-filter-${value.name}'),
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

  Widget _userCard(BuildContext context, AppUser u, {required bool isMe}) {
    final l = context.l10n;
    final color = adminRoleColor(u.role);
    final contact = [
      if (u.phone != null && u.phone!.isNotEmpty) maskPhone(u.phone!),
      if (u.email != null && u.email!.isNotEmpty) maskEmail(u.email!),
    ].join(' · ');
    final shopName = u.shopId == null ? null : (AppRepository.instance.getShopById(u.shopId!)?.name ?? u.shopId!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('admin-user-${u.uid}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminUserEditScreen(uid: u.uid)),
          ),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(radius: 18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softOf(u.disabled ? AppTheme.slate : color),
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                    style: TextStyle(color: u.disabled ? AppTheme.slate : color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: u.disabled ? AppTheme.textSecondary : AppTheme.textPrimary)),
                      if (contact.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                      ],
                      if (shopName != null) ...[
                        const SizedBox(height: 4),
                        Text(l.assignedShop(shopName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(label: adminRoleLabel(l, u.role), color: color),
                    if (u.disabled) ...[
                      const SizedBox(height: 4),
                      StatusChip(
                        key: ValueKey('admin-user-disabled-${u.uid}'),
                        label: l.admUsrDisabledChip,
                        color: AppTheme.danger,
                        icon: Icons.block_rounded,
                      ),
                    ] else if (isMe) ...[
                      const SizedBox(height: 4),
                      StatusChip(label: l.admUsrYouChip, color: AppTheme.slate),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The role's label on the admin screens.
String adminRoleLabel(AppLocalizations l, UserRole role) {
  switch (role) {
    case UserRole.admin:
      return l.roleAdministrator;
    case UserRole.barbershopOwner:
      return l.roleOwner;
    case UserRole.barber:
      return l.roleStaffBarber;
    case UserRole.customer:
      return l.roleCustomer;
  }
}

/// The role's accent colour on the admin screens.
Color adminRoleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppTheme.purple;
    case UserRole.barbershopOwner:
      return AppTheme.success;
    case UserRole.barber:
      return AppTheme.teal;
    case UserRole.customer:
      return AppTheme.blue;
  }
}

/// Text for an [AdminUserException] (or any other error) on the admin
/// user screens.
String adminUserErrorText(AppLocalizations l, Object error) {
  if (error is AdminUserException) {
    switch (error.code) {
      case AdminUserError.notAdmin:
        return l.admUsrErrNotAdmin;
      case AdminUserError.userNotFound:
        return l.admUsrErrNotFound;
      case AdminUserError.cannotChangeSelf:
        return l.admUsrErrSelf;
      case AdminUserError.lastAdmin:
        return l.admUsrErrLastAdmin;
      case AdminUserError.shopRequired:
        return l.admUsrErrShopRequired;
      case AdminUserError.shopNotFound:
        return l.admUsrErrShopNotFound;
      case AdminUserError.barberProfileTaken:
        return l.admUsrErrBarberTaken;
      case AdminUserError.noChange:
        return l.admUsrErrNoChange;
      case AdminUserError.reasonTooLong:
        return l.admUsrErrReasonTooLong(kDisableReasonMaxLength);
    }
  }
  return l.errorText(error);
}
