import 'package:flutter/material.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/persona_switcher.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_payment_review_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_register_shop_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _shopFilter = 'All'; // All, Verified, OpenNow

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmDeleteShop(Barbershop shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(context.l10n.deleteShopTitle),
        content: Text(context.l10n.deleteShopBody(shop.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppRepository.instance.deleteShop(shop.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.shopRemoved(shop.name))),
                );
              }
            },
            child: Text(context.l10n.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();
    final allUsers = repo.getAllUsers();
    final allBarbers = repo.getAllBarbersWithShops();
    final allBookings = <Booking>[];
    for (final s in allShops) {
      allBookings.addAll(repo.getShopBookings(s.id));
    }

    final totalRevenue = allBookings.fold<double>(
      0.0,
      (sum, b) => sum + (b.status != BookingStatus.cancelled ? b.price : 0),
    );

    final filteredShops = allShops.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchQuery = s.name.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.subCity.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q);
      if (!matchQuery) return false;

      if (_shopFilter == 'Verified') return s.isVerified;
      if (_shopFilter == 'OpenNow') return s.isOpenNow();
      return true;
    }).toList();

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
        actions: [
          if (kDemoMode)
            TextButton.icon(
              onPressed: () => showPersonaSwitcher(context, current: UserRole.admin),
              icon: const Icon(Icons.swap_horiz, size: 18, color: AppTheme.ink),
              label: Text(context.l10n.switchRole,
                  style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          IconButton(
            key: const ValueKey('open-admin-subscriptions'),
            tooltip: context.l10n.subscriptionsAndPlansTooltip,
            icon: const Icon(Icons.workspace_premium_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSubscriptionsScreen()),
            ),
          ),
          const PaymentsToReviewButton(),
          const LanguageToggle(),
          const NotificationBell(),
          IconButton(
            tooltip: context.l10n.signOut,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => repo.signOut(),
          ),
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
              icon: const Icon(Icons.people_outline),
              text: context.l10n.tabUsers(allUsers.length),
            ),
            Tab(
              icon: const Icon(Icons.calendar_month),
              text: context.l10n.tabBookings(allBookings.length),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Barbershops Directory
          _buildShopsTab(filteredShops, allShops.length, allBarbers.length, totalRevenue),

          // Tab 2: Users Directory
          _buildUsersTab(allUsers),

          // Tab 3: System Bookings
          _buildBookingsTab(allBookings),
        ],
      ),
    );
  }

  // --- TAB 1: Barbershops Directory ---
  Widget _buildShopsTab(List<Barbershop> filteredShops, int totalShops, int totalBarbers, double totalRevenue) {
    final repo = AppRepository.instance;
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform Metrics Grid
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.metricPlatformSales,
                        style: const TextStyle(fontSize: 13, color: AppTheme.onInkMuted, fontWeight: FontWeight.w500),
                      ),
                    ),
                    HeroChip(label: l.metricGrossVolume, icon: Icons.monetization_on_outlined),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.fmt.birr(totalRevenue),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onInk,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildMetricCard(
                      title: l.metricBarbershops,
                      value: '$totalShops',
                      subtitle: l.metricRegistered,
                      icon: Icons.storefront,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricCard(
                      title: l.metricActiveBarbers,
                      value: '$totalBarbers',
                      subtitle: l.metricAcrossNetwork,
                      icon: Icons.content_cut,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Search and Filter Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: l.searchShopsAdminHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildFilterChip('All', l.all),
              _buildFilterChip('Verified', l.filterVerifiedPartners),
              _buildFilterChip('OpenNow', l.filterOpenNow),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.registeredBarbershopsCount(filteredShops.length),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.adminActionsEnabled,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredShops.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                children: [
                  Icon(Icons.storefront, size: 48, color: AppTheme.textSecondary),
                  SizedBox(height: 8),
                  Text(l.noRegisteredShops, style: const TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(l.noRegisteredShopsHint, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            )
          else
            ...filteredShops.map((shop) {
              final barbers = repo.getBarbersForShop(shop.id);
              final services = repo.getServicesForShop(shop.id);
              final bookings = repo.getShopBookings(shop.id);
              final owner = repo
                  .getAllUsers()
                  .where((u) => u.shopId == shop.id && u.role == UserRole.barbershopOwner)
                  .firstOrNull;
              final ownerInvite = owner == null ? repo.getPendingOwnerInvite(shop.id) : null;
              final ownerLabel = owner != null
                  ? '${owner.name} (${formatEthiopianPhone(owner.phone ?? shop.phone)})'
                  : ownerInvite != null
                      ? l.ownerInvitePending(ownerInvite.name, ownerInvite.email)
                      : l.notAssigned;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: AppTheme.cardDecoration(),
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
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 80,
                                height: 80,
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (shop.isVerified) const Icon(Icons.verified, color: AppTheme.green, size: 17),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 12, color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        [
                                          shop.address,
                                          if (shop.subCity.isNotEmpty) l.placeName(shop.subCity),
                                          l.placeName(shop.city)
                                        ].join(', '),
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l.ownerLabel(ownerLabel),
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildBadge(l.barbersCount(barbers.length), Icons.people_outline),
                                    _buildBadge(l.servicesCount(services.length), Icons.content_cut),
                                    _buildBadge(l.bookingsCount(bookings.length), Icons.calendar_today_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.hairline),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              repo.toggleShopVerification(shop.id);
                            },
                            icon: Icon(
                              shop.isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 16,
                              color: shop.isVerified ? AppTheme.success : AppTheme.textSecondary,
                            ),
                            label: Text(
                              shop.isVerified ? l.verified : l.verifyShop,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: shop.isVerified ? AppTheme.success : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              if (kDemoMode)
                                TextButton.icon(
                                  onPressed: () {
                                    // Demo only: open that shop's owner app
                                    repo.switchRole(UserRole.barbershopOwner, targetShopId: shop.id);
                                  },
                                  icon: const Icon(Icons.dashboard_customize, size: 16, color: AppTheme.ink),
                                  label: Text(l.manageShopPortal,
                                      style: const TextStyle(color: AppTheme.ink, fontSize: 12)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                tooltip: l.deleteShop,
                                onPressed: () => _confirmDeleteShop(shop),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
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

  // --- TAB 3: System Platform Bookings ---
  Widget _buildBookingsTab(List<Booking> allBookings) {
    if (allBookings.isEmpty) {
      return Center(child: Text(context.l10n.noPlatformAppointments));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allBookings.length,
      itemBuilder: (context, index) {
        final b = allBookings[index];
        final l = context.l10n;
        final fmt = context.fmt;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(b.shopName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(label: l.bookingStatus(b.status).toUpperCase(), color: _statusColor(b.status)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l.serviceAndPrice(b.serviceName, fmt.birr(b.price)),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(l.clientLabel(b.customerName),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 14),
                  const Icon(Icons.content_cut, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(l.barberLabel(b.barberName),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.scheduleAt(l.dateAtTime(fmt.dayShort(fmt.bookingDay(b)), fmt.bookingTime(b))),
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppTheme.warning;
      case BookingStatus.confirmed:
        return AppTheme.success;
      case BookingStatus.inProgress:
        return AppTheme.blue;
      case BookingStatus.completed:
        return AppTheme.ink;
      case BookingStatus.cancelled:
        return AppTheme.danger;
      case BookingStatus.noShow:
        return AppTheme.slate;
    }
  }

  /// Small stat on the hero card: metallic icon circle + value and labels.
  Widget _buildMetricCard(
      {required String title, required String value, required String subtitle, required IconData icon}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
            child: Icon(icon, color: AppTheme.ink, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onInk)),
                Text(title,
                    style: const TextStyle(fontSize: 11, color: AppTheme.onInkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: const TextStyle(fontSize: 10, color: AppTheme.onInkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _shopFilter == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.onInk : AppTheme.textPrimary)),
      selected: isSelected,
      selectedColor: AppTheme.ink,
      onSelected: (val) {
        if (val) setState(() => _shopFilter = value);
      },
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
