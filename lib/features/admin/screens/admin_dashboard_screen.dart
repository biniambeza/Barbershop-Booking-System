import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
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

  void _showPersonaSwitcher(BuildContext context) {
    final repo = AppRepository.instance;
    final shops = repo.getShops();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.switch_account, color: AppTheme.primaryGold),
                  SizedBox(width: 8),
                  Text('Switch Role Persona', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryGold,
                  child: Icon(Icons.admin_panel_settings, color: Colors.black),
                ),
                title: const Text('Platform Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Register barbershops, manage users & platform config'),
                trailing: const Icon(Icons.check, color: AppTheme.primaryGold),
                onTap: () {
                  Navigator.pop(ctx);
                  repo.switchRole(UserRole.admin);
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.darkSurface,
                  child: Icon(Icons.storefront, color: AppTheme.primaryGold),
                ),
                title: const Text('Barbershop Owner App', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Manage team barbers, services & appointments (${shops.first.name})'),
                onTap: () {
                  Navigator.pop(ctx);
                  repo.switchRole(UserRole.barbershopOwner, targetShopId: shops.isNotEmpty ? shops.first.id : null);
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.tealAccent,
                  child: Icon(Icons.content_cut, color: Colors.black),
                ),
                title: const Text('Staff Barber Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Marcus Vance: Manage appointment queue & earnings'),
                onTap: () {
                  Navigator.pop(ctx);
                  repo.switchRole(UserRole.barber);
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.darkSurface,
                  child: Icon(Icons.person, color: Colors.lightBlueAccent),
                ),
                title: const Text('Customer View', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Search barbershops, pick favorite barbers & book appointments'),
                onTap: () {
                  Navigator.pop(ctx);
                  repo.switchRole(UserRole.customer);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteShop(Barbershop shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Delete Barbershop?'),
        content: Text('Are you sure you want to remove "${shop.name}" and all associated barbers, services and appointments?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppRepository.instance.deleteShop(shop.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${shop.name}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
          s.address.toLowerCase().contains(q);
      if (!matchQuery) return false;

      if (_shopFilter == 'Verified') return s.isVerified;
      if (_shopFilter == 'OpenNow') return s.isOpenNow();
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CROWN & BLADE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16),
            ),
            Row(
              children: [
                Icon(Icons.shield, size: 12, color: AppTheme.primaryGold),
                SizedBox(width: 4),
                Text(
                  'Platform System Administration',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showPersonaSwitcher(context),
            icon: const Icon(Icons.swap_horiz, size: 18, color: AppTheme.primaryGold),
            label: const Text('Switch Role', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => repo.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(
              icon: const Icon(Icons.storefront),
              text: 'Shops (${allShops.length})',
            ),
            Tab(
              icon: const Icon(Icons.people_outline),
              text: 'Users (${allUsers.length})',
            ),
            Tab(
              icon: const Icon(Icons.calendar_month),
              text: 'Bookings (${allBookings.length})',
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
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_business),
        label: const Text('Register Barbershop', style: TextStyle(fontWeight: FontWeight.bold)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform Metrics Grid
          Row(
            children: [
              _buildMetricCard(
                title: 'Barbershops',
                value: '$totalShops',
                subtitle: 'Registered',
                icon: Icons.storefront,
              ),
              const SizedBox(width: 10),
              _buildMetricCard(
                title: 'Active Barbers',
                value: '$totalBarbers',
                subtitle: 'Across network',
                icon: Icons.content_cut,
              ),
              const SizedBox(width: 10),
              _buildMetricCard(
                title: 'Platform Sales',
                value: '\$${totalRevenue.toStringAsFixed(0)}',
                subtitle: 'Gross volume',
                icon: Icons.monetization_on_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search and Filter Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search shops by name, address, or city...',
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
          Row(
            children: [
              _buildFilterChip('All', 'All'),
              const SizedBox(width: 8),
              _buildFilterChip('Verified', 'Verified Partners'),
              const SizedBox(width: 8),
              _buildFilterChip('OpenNow', 'Open Now'),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Barbershops (${filteredShops.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Admin Actions Enabled',
                style: TextStyle(color: AppTheme.primaryGold.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (filteredShops.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.storefront, size: 48, color: AppTheme.textSecondary),
                  SizedBox(height: 8),
                  Text('No registered barbershops found', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Tap "Register Barbershop" to add a new shop to the platform.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            )
          else
            ...filteredShops.map((shop) {
              final barbers = repo.getBarbersForShop(shop.id);
              final services = repo.getServicesForShop(shop.id);
              final bookings = repo.getShopBookings(shop.id);
              final owner = repo.getAllUsers().where((u) => u.shopId == shop.id).firstOrNull;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: shop.isVerified ? AppTheme.primaryGold.withValues(alpha: 0.4) : Colors.white12,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              shop.imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 80,
                                height: 80,
                                color: AppTheme.darkSurface,
                                child: const Icon(Icons.storefront, color: AppTheme.primaryGold),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (shop.isVerified)
                                      const Icon(Icons.verified, color: AppTheme.primaryGold, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 12, color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${shop.address}, ${shop.city}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Owner: ${owner?.name ?? "Assigned Partner"} (${owner?.email ?? shop.phone})',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildBadge('${barbers.length} Barbers', Icons.people_outline),
                                    _buildBadge('${services.length} Services', Icons.content_cut),
                                    _buildBadge('${bookings.length} Bookings', Icons.calendar_today_outlined),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
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
                              color: shop.isVerified ? AppTheme.primaryGold : AppTheme.textSecondary,
                            ),
                            label: Text(
                              shop.isVerified ? 'Verified' : 'Verify Shop',
                              style: TextStyle(
                                fontSize: 12,
                                color: shop.isVerified ? AppTheme.primaryGold : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  // Switch to that shop's customized owner app
                                  repo.switchRole(UserRole.barbershopOwner, targetShopId: shop.id);
                                },
                                icon: const Icon(Icons.dashboard_customize, size: 16, color: AppTheme.primaryGold),
                                label: const Text('Manage Shop Portal', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Delete Shop',
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
        final roleLabel = u.role == UserRole.admin
            ? 'Administrator'
            : (u.role == UserRole.barbershopOwner
                ? 'Shop Owner'
                : (u.role == UserRole.barber ? 'Staff Barber' : 'Customer'));
        final roleColor = u.role == UserRole.admin
            ? Colors.purpleAccent
            : (u.role == UserRole.barbershopOwner
                ? AppTheme.primaryGold
                : (u.role == UserRole.barber ? Colors.tealAccent : Colors.lightBlueAccent));

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: roleColor.withValues(alpha: 0.2),
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
                    Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(u.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    if (u.shopId != null) ...[
                      const SizedBox(height: 4),
                      Text('Assigned Shop: ${u.shopId}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: System Platform Bookings ---
  Widget _buildBookingsTab(List<Booking> allBookings) {
    if (allBookings.isEmpty) {
      return const Center(child: Text('No platform appointments recorded yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allBookings.length,
      itemBuilder: (context, index) {
        final b = allBookings[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(b.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryGold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: b.status == BookingStatus.confirmed
                          ? Colors.green.withValues(alpha: 0.2)
                          : (b.status == BookingStatus.completed ? Colors.blue.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      b.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: b.status == BookingStatus.confirmed
                            ? Colors.greenAccent
                            : (b.status == BookingStatus.completed ? Colors.lightBlueAccent : Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${b.serviceName} • \$${b.price.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Client: ${b.customerName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 14),
                  const Icon(Icons.content_cut, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Barber: ${b.barberName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Schedule: ${DateFormat('EEE, MMM d').format(b.date)} at ${b.timeSlot}',
                style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.primaryGold), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _shopFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppTheme.primaryGold,
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
