import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/admin_shops_logic.dart';

/// Text for an [AdminShopException] (other errors go through
/// `l10n.errorText`).
String adminShopErrorText(AppLocalizations l, Object error) {
  if (error is! AdminShopException) return l.errorText(error);
  switch (error.error) {
    case AdminShopError.reasonRequired:
      return l.adminShopsErrReasonRequired;
    case AdminShopError.reasonTooLong:
      return l.adminShopsErrReasonTooLong(kMaxShopSuspendReasonLength);
    case AdminShopError.nameRequired:
      return l.adminShopsErrNameRequired;
    case AdminShopError.nameTooLong:
      return l.adminShopsErrNameTooLong;
    case AdminShopError.addressRequired:
      return l.adminShopsErrAddressRequired;
    case AdminShopError.textTooLong:
      return l.adminShopsErrTextTooLong;
    case AdminShopError.invalidPlan:
      return l.adminShopsErrPlan;
    case AdminShopError.shopNotFound:
      return l.adminShopsErrNotFound;
    case AdminShopError.notAdmin:
      return l.adminShopsErrNotAdmin;
    case AdminShopError.nameMismatch:
      return l.adminShopsErrNameMismatch;
  }
}

/// Status chip of a shop in the admin list / edit screen.
class AdminShopStatusChip extends StatelessWidget {
  const AdminShopStatusChip({super.key, required this.shop});

  final Barbershop shop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, color, icon) = shop.adminSuspended
        ? (l.adminShopsStatusAdminSuspended, AppTheme.danger, Icons.block_rounded)
        : shop.isSuspended
            ? (l.adminShopsStatusUnpaid, AppTheme.warning, Icons.credit_card_off_rounded)
            : (l.adminShopsStatusActive, AppTheme.success, Icons.check_circle_rounded);
    // Like StatusChip, but the label shrinks (ellipsis) on narrow cards.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.softOf(color), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Owner dashboard: red banner while the platform admin has suspended the
/// shop, with the admin's reason. Renders nothing otherwise.
class AdminSuspensionBanner extends StatelessWidget {
  const AdminSuspensionBanner({super.key, required this.shop});

  final Barbershop shop;

  @override
  Widget build(BuildContext context) {
    if (!shop.adminSuspended) return const SizedBox.shrink();
    final l = context.l10n;
    final reason = shop.adminSuspendedReason?.trim() ?? '';
    return Container(
      key: const ValueKey('admin-suspension-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.redSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_rounded, color: AppTheme.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.adminShopsOwnerBannerTitle,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger),
                ),
                const SizedBox(height: 4),
                Text(l.adminShopsOwnerBannerBody, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.adminShopsOwnerBannerReason(reason),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ],
                const SizedBox(height: 6),
                Text(l.adminShopsOwnerBannerContact,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Customer shop page: "temporarily unavailable" notice for a blocked shop
/// ([Barbershop.isBlocked]). Renders nothing otherwise.
class ShopUnavailableNotice extends StatelessWidget {
  const ShopUnavailableNotice({super.key, required this.shop});

  final Barbershop shop;

  @override
  Widget build(BuildContext context) {
    if (!shop.isBlocked) return const SizedBox.shrink();
    final l = context.l10n;
    return Container(
      key: const ValueKey('shop-unavailable-notice'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.redSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_rounded, color: AppTheme.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.adminShopsUnavailableTitle,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.danger)),
                const SizedBox(height: 4),
                Text(l.adminShopsUnavailableBody, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
