import 'package:flutter/material.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../shared/widgets/app_bar_menu.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_payment_review_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_register_shop_screen.dart';
import 'admin_shops_screen.dart'; // admin shop management
import 'admin_payments_tab.dart'; // payments dashboard
import '../../payments/receipts/admin_pricing_screen.dart'; // subscription receipts
import '../../payments/receipts/admin_receipts_screen.dart'; // subscription receipts
import '../../payments/receipts/receivers_setup.dart'; // receivers setup (banner + red dot)

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Shops + Payments + Users (the bookings tab was removed).
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();
    final allUsers = repo.getAllUsers();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.brandUpper,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 16, color: AppTheme.textPrimary),
            ),
            Row(
              children: [
                const Icon(Icons.shield, size: 12, color: AppTheme.green),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context.l10n.adminSubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        // --- compact header: secondary actions live in AppBarMenu ---
        actions: [
          const ReceiptsToReviewButton(), // subscription receipts (hidden when none)
          const PaymentsToReviewButton(),
          const NotificationBell(),
          AppBarMenu(
            role: UserRole.admin,
            entries: [
              AppBarMenuEntry(
                key: const ValueKey('open-admin-subscriptions'),
                icon: Icons.workspace_premium_rounded,
                color: AppTheme.purple,
                label: context.l10n.subscriptionsAndPlansTooltip,
                onSelected: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSubscriptionsScreen()),
                ),
              ),
              // --- subscription receipts ---
              AppBarMenuEntry(
                key: const ValueKey('open-admin-receipts'),
                icon: Icons.receipt_long_rounded,
                color: AppTheme.success,
                label: context.l10n.rcptAdminTitle,
                onSelected: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReceiptsScreen()),
                ),
              ),
              AppBarMenuEntry(
                key: const ValueKey('open-admin-pricing'),
                icon: Icons.price_change_outlined,
                color: AppTheme.blue,
                label: context.l10n.rcptPricingTitle,
                onSelected: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPricingScreen()),
                ),
              ),
              // --- end subscription receipts ---
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.ink,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(
              icon: const Icon(Icons.storefront),
              text: context.l10n.tabShops(allShops.length),
            ),
            Tab(
              key: const ValueKey('admin-tab-payments'),
              // receivers setup: red dot until owners have somewhere to pay
              icon: const ReceiversSetupDot(child: Icon(Icons.payments_outlined)),
              text: context.l10n.admPayTab,
            ),
            Tab(
              icon: const Icon(Icons.people_outline),
              text: context.l10n.tabUsers(allUsers.length),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminRegisterShopScreen()),
          );
        },
        backgroundColor: AppTheme.ink,
        foregroundColor: AppTheme.onInk,
        icon: const Icon(Icons.add_business),
        label: Text(context.l10n.registerBarbershop, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      // --- receivers setup: "Set up where shop owners pay you" above every tab ---
      body: Column(children: [
        const ReceiversSetupBanner(),
        Expanded(child: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Barbershops (search, filter, edit, suspend, delete)
          const AdminShopsTab(),

          // Tab 2: Payments (income, receipts, subscription types, plans)
          const AdminPaymentsTab(),

          // Tab 3: Users Directory
          _buildUsersTab(allUsers),
        ],
      )),
      ]), // --- end receivers setup ---
    );
  }

  // --- TAB 2: Users Directory ---
  Widget _buildUsersTab(List<AppUser> allUsers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allUsers.length,
      itemBuilder: (context, index) {
        final u = allUsers[index];
        final l = context.l10n;
        final roleLabel = u.role == UserRole.admin
            ? l.roleAdministrator
            : (u.role == UserRole.barbershopOwner
                ? l.roleOwner
                : (u.role == UserRole.barber ? l.roleStaffBarber : l.roleCustomer));
        final roleColor = u.role == UserRole.admin
            ? AppTheme.purple
            : (u.role == UserRole.barbershopOwner
                ? AppTheme.ink
                : (u.role == UserRole.barber ? AppTheme.teal : AppTheme.blue));

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(radius: 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.softOf(roleColor),
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                  style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      u.phone != null ? formatEthiopianPhone(u.phone!) : (u.email ?? ''),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    if (u.shopId != null) ...[
                      const SizedBox(height: 4),
                      Text(l.assignedShop(AppRepository.instance.getShopById(u.shopId!)?.name ?? u.shopId!),
                          style:
                              const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              StatusChip(label: roleLabel, color: roleColor),
            ],
          ),
        );
      },
    );
  }
}
