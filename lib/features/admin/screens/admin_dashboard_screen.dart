import 'package:flutter/material.dart';
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
import 'admin_users_tab.dart'; // admin users
import '../../payments/receipts/admin_pricing_screen.dart'; // subscription receipts
import '../../payments/receipts/admin_receipts_screen.dart'; // subscription receipts
import 'admin_removal_requests_screen.dart'; // account deletion
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
              style: TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 16, color: AppTheme.textPrimary),
            ),
            Row(
              children: [
                Icon(Icons.shield, size: 12, color: AppTheme.green),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context.l10n.adminSubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
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
              // --- account deletion ---
              AppBarMenuEntry(
                key: const ValueKey('open-admin-removal-requests'),
                icon: Icons.store_mall_directory_outlined,
                color: AppTheme.warning,
                label: context.l10n.adminRemovalRequestsTitle,
                onSelected: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminRemovalRequestsScreen()),
                ),
              ),
              // --- end account deletion ---
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Shops / Payments / Users live in a bottom navigation bar.
      bottomNavigationBar: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => AppBottomNavBar(
          selectedIndex: _tabController.index,
          onSelected: _tabController.animateTo,
          items: [
            BottomNavItem(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront,
              label: context.l10n.tabShops(allShops.length),
            ),
            BottomNavItem(
              key: const ValueKey('admin-tab-payments'),
              icon: Icons.payments_outlined,
              selectedIcon: Icons.payments,
              label: context.l10n.admPayTab,
              // receivers setup: red dot until owners have somewhere to pay
              wrapIcon: (icon) => ReceiversSetupDot(child: icon),
            ),
            BottomNavItem(
              icon: Icons.people_outline,
              selectedIcon: Icons.people,
              label: context.l10n.tabUsers(allUsers.length),
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

          // Tab 3: Users (admin_users_tab.dart)
          const AdminUsersTab(), // admin users: search, filters, edit user
        ],
      )),
      ]), // --- end receivers setup ---
    );
  }
}
