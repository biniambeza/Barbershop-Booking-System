import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';

/// DEMO_MODE only: bottom sheet that switches between the demo personas.
/// Names come from the loaded demo dataset.
void showPersonaSwitcher(BuildContext context, {required UserRole current}) {
  final repo = AppRepository.instance;
  final shops = repo.getShops();
  final ownerShop = repo.getShopById('shop_1') ?? (shops.isEmpty ? null : shops.first);
  final barber = repo.getBarberById('barber_1') ?? repo.getAllBarbers().firstOrNull;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.darkCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final l = ctx.l10n;
      Widget tile({
        required UserRole role,
        required IconData icon,
        required Color color,
        required String title,
        required String subtitle,
        required VoidCallback onSelect,
      }) {
        final active = role == current;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: active ? const Icon(Icons.check, color: AppTheme.primaryGold) : null,
          onTap: () {
            Navigator.pop(ctx);
            if (!active) onSelect();
          },
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz, color: AppTheme.primaryGold),
                  const SizedBox(width: 8),
                  Text(l.personaTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.personaSubtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              tile(
                role: UserRole.admin,
                icon: Icons.admin_panel_settings,
                color: Colors.purpleAccent,
                title: l.personaAdminTitle,
                subtitle: l.personaAdminSubtitle,
                onSelect: () => repo.switchRole(UserRole.admin),
              ),
              tile(
                role: UserRole.barbershopOwner,
                icon: Icons.storefront,
                color: AppTheme.primaryGold,
                title: l.personaOwnerTitle,
                subtitle: l.personaOwnerSubtitle(ownerShop?.name ?? '-'),
                onSelect: () => repo.switchRole(UserRole.barbershopOwner, targetShopId: ownerShop?.id),
              ),
              tile(
                role: UserRole.barber,
                icon: Icons.content_cut,
                color: Colors.tealAccent,
                title: l.personaBarberTitle,
                subtitle: l.personaBarberSubtitle(barber?.name ?? '-'),
                onSelect: () => repo.switchRole(UserRole.barber, targetBarberId: barber?.id),
              ),
              tile(
                role: UserRole.customer,
                icon: Icons.person,
                color: Colors.lightBlueAccent,
                title: l.personaCustomerTitle,
                subtitle: l.personaCustomerSubtitle,
                onSelect: () => repo.switchRole(UserRole.customer),
              ),
            ],
          ),
        ),
      );
    },
  );
}
