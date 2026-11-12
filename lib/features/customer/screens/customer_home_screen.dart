import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import 'barbershop_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenBarbers;

  const CustomerHomeScreen({super.key, this.onOpenBarbers});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _searchQuery = '';
  String _selectedCity = 'All';
  String _selectedCategory = 'All';

  final List<String> _cities = ['All', 'New York', 'Brooklyn'];
  final List<String> _categories = [
    'All',
    'Fades & Tapers',
    'Beard Sculpt',
    'Hot Shave',
    'Kids & VIP'
  ];

  void _showRoleSwitcher(BuildContext context, AppRepository repo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.swap_horiz, color: AppTheme.primaryGold),
                    SizedBox(width: 8),
                    Text(
                      'SaaS Role Switcher',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch persona instantly to experience each role',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.purpleAccent,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white),
                  ),
                  title: const Text('Platform Superadmin', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Register shops, oversee platform metrics & users'),
                  onTap: () {
                    Navigator.pop(context);
                    repo.switchRole(UserRole.admin);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryGold,
                    child: Icon(Icons.storefront, color: Colors.black),
                  ),
                  title: const Text('Barbershop Owner', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Manage The Gentleman's Quarter shop, staff & menu"),
                  onTap: () {
                    Navigator.pop(context);
                    repo.switchRole(UserRole.barbershopOwner);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.tealAccent,
                    child: Icon(Icons.content_cut, color: Colors.black),
                  ),
                  title: const Text('Staff Barber Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Marcus Vance: Manage queue, update appointments & shifts'),
                  onTap: () {
                    Navigator.pop(context);
                    repo.switchRole(UserRole.barber);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.lightBlueAccent,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  title: const Text('Client / Customer (Active)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Browse shops, find barbers & book appointments'),
                  trailing: const Icon(Icons.check, color: AppTheme.primaryGold),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();

    final filteredShops = allShops.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.address.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCity = _selectedCity == 'All' || s.city.toLowerCase().contains(_selectedCity.toLowerCase());

      return matchesSearch && matchesCity;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CROWN & BLADE',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 18,
                  ),
            ),
            const Row(
              children: [
                Icon(Icons.location_on, size: 13, color: AppTheme.primaryGold),
                SizedBox(width: 4),
                Text(
                  'Greater New York Area',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showRoleSwitcher(context, repo),
            icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.lightBlueAccent),
            label: const Text(
              'Customer',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () => repo.signOut(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search Header & Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search barbershops by name or neighborhood...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                      filled: true,
                      fillColor: AppTheme.darkCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Promotional Feature Banner: Find Master Barbers
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGold.withValues(alpha: 0.25),
                          AppTheme.darkCard,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PREMIER TALENT',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Book Directly with Master Barbers',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Browse verified specialists, view portfolios & reserve seats.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.content_cut, size: 16),
                                label: const Text('Find Barbers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: widget.onOpenBarbers,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGold.withValues(alpha: 0.15),
                            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.content_cut, color: AppTheme.primaryGold, size: 32),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // City Filter Chips
                  Row(
                    children: [
                      const Text(
                        'City:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _cities.map((city) {
                              final isSelected = _selectedCity == city;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(city),
                                  selected: isSelected,
                                  selectedColor: AppTheme.primaryGold,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.black : AppTheme.textSecondary,
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedCity = city);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Service Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryGold.withValues(alpha: 0.25),
                            checkmarkColor: AppTheme.primaryGold,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryGold : AppTheme.textSecondary,
                            ),
                            onSelected: (val) {
                              setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Featured Barbershops (${filteredShops.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _selectedCity == 'All' ? 'All Locations' : _selectedCity,
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Shop Cards List
          if (filteredShops.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.storefront, size: 54, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No barbershops found matching "$_searchQuery"',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final shop = filteredShops[index];
                    return _buildShopCard(context, shop, repo);
                  },
                  childCount: filteredShops.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, Barbershop shop, AppRepository repo) {
    final services = repo.getServicesForShop(shop.id);
    final barbers = repo.getBarbersForShop(shop.id);
    final isFav = repo.isShopFavorite(shop.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BarbershopDetailScreen(shop: shop),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Cover Image
            Stack(
              children: [
                Image.network(
                  shop.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: AppTheme.darkSurface,
                    child: const Center(
                      child: Icon(Icons.storefront, size: 48, color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          '${shop.rating.toStringAsFixed(1)} (${shop.reviewCount})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      if (shop.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade800.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text('VERIFIED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_city, size: 12, color: AppTheme.primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          shop.city,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Shop Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : AppTheme.textSecondary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => repo.toggleFavoriteShop(shop.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shop.fullAddress,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${shop.openingHour}:00 AM - ${shop.closingHour - 12}:00 PM',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 14, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${barbers.length} Barbers',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.content_cut, size: 13, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${services.length} Services',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BarbershopDetailScreen(shop: shop),
                          ),
                        );
                      },
                      child: const Text('View Services & Book'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
