import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import 'barbershop_detail_screen.dart';
import 'nearby_map_screen.dart';
import 'booking_flow_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenMap;

  const CustomerHomeScreen({super.key, this.onOpenMap});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isMapView = false;
  bool _browseBarbersMode = false;

  static const LatLng _userLocation = LatLng(40.7484, -73.9857);

  final List<String> _categories = [
    'All',
    'Fades & Tapers',
    'Beard Sculpt',
    'Hot Shave',
    'Kids & VIP'
  ];

  void _openFullMap() {
    if (widget.onOpenMap != null) {
      widget.onOpenMap!();
    } else {
      setState(() => _isMapView = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();
    final allBarbersWithShops = repo.getAllBarbersWithShops();

    final filteredShops = allShops.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.address.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    final filteredBarbers = allBarbersWithShops.where((item) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = item.barber.name.toLowerCase().contains(q) ||
            item.barber.title.toLowerCase().contains(q) ||
            item.shop.name.toLowerCase().contains(q) ||
            item.shop.city.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle List / Map View Button
          IconButton(
            icon: Icon(
              _isMapView ? Icons.view_list : Icons.map,
              color: AppTheme.primaryGold,
            ),
            tooltip: _isMapView ? 'Show List' : 'Show Map',
            onPressed: () {
              setState(() => _isMapView = !_isMapView);
            },
          ),
          // Persona Switcher
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryGold),
            tooltip: 'Switch Persona',
            color: AppTheme.darkCard,
            onSelected: (val) {
              if (val == 'admin') {
                repo.switchRole(UserRole.admin);
              } else if (val == 'owner') {
                repo.switchRole(UserRole.barbershopOwner);
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppTheme.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Text('👑 Admin Portal', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'owner',
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: AppTheme.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Text('💈 Barbershop Owner', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => repo.signOut(),
          ),
        ],
      ),
      body: _isMapView
          ? const NearbyMapScreen(showBackButton: false)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar
                        TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search barbershops, cities, stylists...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // View Switcher Bar
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isMapView = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_isMapView ? AppTheme.primaryGold : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.view_list,
                                          size: 16,
                                          color: !_isMapView ? Colors.black : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'List View',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: !_isMapView ? Colors.black : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isMapView = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isMapView ? AppTheme.primaryGold : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.map,
                                          size: 16,
                                          color: _isMapView ? Colors.black : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Map View',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _isMapView ? Colors.black : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Live Interactive Map Widget Embedded directly on Home Page
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.location_on, color: AppTheme.primaryGold, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'Nearby Barbershops Map',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: _openFullMap,
                                      icon: const Icon(Icons.fullscreen, size: 16),
                                      label: const Text('Full Screen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                child: SizedBox(
                                  height: 220,
                                  width: double.infinity,
                                  child: FlutterMap(
                                    options: const MapOptions(
                                      initialCenter: _userLocation,
                                      initialZoom: 13.0,
                                      minZoom: 5.0,
                                      maxZoom: 18.0,
                                      interactionOptions: InteractionOptions(
                                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                                      ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.barbershop.barbershop_booking',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          // User location pin
                                          const Marker(
                                            point: _userLocation,
                                            width: 36,
                                            height: 36,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryGold,
                                                shape: BoxShape.circle,
                                                boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 4)],
                                              ),
                                              child: Center(
                                                child: Icon(Icons.person, color: Colors.black, size: 20),
                                              ),
                                            ),
                                          ),
                                          // Barbershop markers
                                          ...filteredShops.map((shop) {
                                            return Marker(
                                              point: shop.coordinates,
                                              width: 85,
                                              height: 38,
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => BarbershopDetailScreen(shop: shop),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.darkCard,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: AppTheme.primaryGold, width: 1.5),
                                                    boxShadow: const [
                                                      BoxShadow(color: Colors.black54, blurRadius: 4),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.content_cut, size: 11, color: AppTheme.primaryGold),
                                                      const SizedBox(width: 3),
                                                      Flexible(
                                                        child: Text(
                                                          shop.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
                        // Browse Mode Selector (Barbershops vs Favorite Barbers)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _browseBarbersMode = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: !_browseBarbersMode ? AppTheme.primaryGold : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.storefront,
                                          size: 16,
                                          color: !_browseBarbersMode ? Colors.black : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Barbershops (${filteredShops.length})',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: !_browseBarbersMode ? Colors.black : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _browseBarbersMode = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _browseBarbersMode ? AppTheme.primaryGold : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.content_cut,
                                          size: 16,
                                          color: _browseBarbersMode ? Colors.black : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Favorite Barbers (${filteredBarbers.length})',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _browseBarbersMode ? Colors.black : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              !_browseBarbersMode
                                  ? 'Featured Barbershops (${filteredShops.length})'
                                  : 'Top Barbers & Stylists (${filteredBarbers.length})',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _isMapView = true),
                              icon: const Icon(Icons.map, size: 16, color: AppTheme.primaryGold),
                              label: const Text('View on Map', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Content List: Barbershops or Barbers
                if (!_browseBarbersMode) ...[
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
                ] else ...[
                  if (filteredBarbers.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No barbers found matching your search.', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredBarbers[index];
                            return _buildBarberCard(context, item);
                          },
                          childCount: filteredBarbers.length,
                        ),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }

  Widget _buildBarberCard(BuildContext context, BarberWithShop item) {
    final barber = item.barber;
    final shop = item.shop;
    final distanceStr = shop.formattedDistanceFrom(_userLocation);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
            onBackgroundImageError: barber.avatarUrl != null ? (err, stack) {} : null,
            backgroundColor: AppTheme.primaryGold,
            child: barber.avatarUrl == null
                ? Text(barber.name.substring(0, 1), style: const TextStyle(fontSize: 20, color: Colors.black))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        barber.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.primaryGold),
                        const SizedBox(width: 3),
                        Text(
                          '${barber.rating}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  barber.title,
                  style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${shop.name} • $distanceStr',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final services = AppRepository.instance.getServicesForShop(shop.id);
                      final service = services.isNotEmpty
                          ? services.first
                          : BarbershopService(
                              id: 'srv_gen',
                              shopId: shop.id,
                              name: 'Signature Haircut',
                              description: 'Standard precision cut',
                              price: 40.0,
                            );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingFlowScreen(
                            shop: shop,
                            initialBarber: barber,
                            initialService: service,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month, size: 14),
                    label: Text('Book with ${barber.name.split(" ").first}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, Barbershop shop) {
    final services = AppRepository.instance.getServicesForShop(shop.id);
    final barbers = AppRepository.instance.getBarbersForShop(shop.id);
    final distanceStr = shop.formattedDistanceFrom(_userLocation);

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
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation, size: 11, color: AppTheme.primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          distanceStr,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map, color: AppTheme.primaryGold, size: 20),
                        tooltip: 'View on Map',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NearbyMapScreen(
                                initialSelectedShopId: shop.id,
                                showBackButton: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 14, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${barbers.length}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.content_cut, size: 13, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${services.length}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
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
