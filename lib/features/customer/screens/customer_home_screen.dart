import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import 'barbershop_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Fades & Tapers',
    'Beard Sculpt',
    'Hot Shave',
    'Kids & VIP'
  ];

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();

    final filteredShops = allShops.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.address.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
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
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppTheme.primaryGold),
                const SizedBox(width: 4),
                Text(
                  'New York, NY',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Switch to Owner Dashboard preview button
          TextButton.icon(
            onPressed: () {
              repo.switchRole(UserRole.barbershopOwner);
            },
            icon: const Icon(Icons.storefront, size: 18, color: AppTheme.primaryGold),
            label: const Text('Owner View', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => repo.signOut(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search & Promotional Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search barbershops, cities, stylists...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Promo Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGold.withValues(alpha: 0.9),
                          const Color(0xFF996515),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGold.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PREMIUM GROOMING',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Book Top Barbers\nIn Your City Instantly',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Zero waiting lines. Choose your master barber & exact time slot.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Categories chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryGold,
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Featured Barbershops (${filteredShops.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Barbershops List
          if (filteredShops.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No barbershops found matching your search.', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final shop = filteredShops[index];
                    return _buildShopCard(context, shop);
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

  Widget _buildShopCard(BuildContext context, Barbershop shop) {
    final services = AppRepository.instance.getServicesForShop(shop.id);
    final barbers = AppRepository.instance.getBarbersForShop(shop.id);

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
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 170,
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
                          '${shop.rating} (${shop.reviewCount})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                if (shop.isVerified)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
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
                  ),
              ],
            ),

            // Shop Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: AppTheme.primaryGold),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${shop.address}, ${shop.city}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${shop.openingHour}:00 AM - ${shop.closingHour - 12}:00 PM',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '${barbers.length} Barbers • ${services.length} Services',
                        style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
