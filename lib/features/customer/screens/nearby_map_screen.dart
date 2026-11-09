import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import 'barbershop_detail_screen.dart';

class NearbyMapScreen extends StatefulWidget {
  final String? initialSelectedShopId;
  final bool showBackButton;

  const NearbyMapScreen({
    super.key,
    this.initialSelectedShopId,
    this.showBackButton = false,
  });

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

enum MapFilterRadius { all, twoKm, fiveKm, highlyRated, openNow }
enum MapTileStyle { darkLuxury, standard }

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final MapController _mapController = MapController();
  late PageController _pageController;

  // Default User Location: Central Midtown Manhattan NYC
  final LatLng _userLocation = const LatLng(40.7484, -73.9857);

  String _searchQuery = '';
  MapFilterRadius _activeFilter = MapFilterRadius.all;
  MapTileStyle _tileStyle = MapTileStyle.darkLuxury;

  String? _selectedShopId;
  bool _isCarouselCollapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.initialSelectedShopId;
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<Barbershop> _getFilteredShops(List<Barbershop> allShops) {
    return allShops.where((shop) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = shop.name.toLowerCase().contains(q) ||
            shop.address.toLowerCase().contains(q) ||
            shop.city.toLowerCase().contains(q);
        if (!match) return false;
      }

      // Radius & attribute filter
      final distanceKm = shop.distanceInKmFrom(_userLocation);
      switch (_activeFilter) {
        case MapFilterRadius.all:
          return true;
        case MapFilterRadius.twoKm:
          return distanceKm <= 2.5;
        case MapFilterRadius.fiveKm:
          return distanceKm <= 5.0;
        case MapFilterRadius.highlyRated:
          return shop.rating >= 4.9;
        case MapFilterRadius.openNow:
          return shop.isOpenNow();
      }
    }).toList()
      ..sort((a, b) => a.distanceInKmFrom(_userLocation).compareTo(b.distanceInKmFrom(_userLocation)));
  }

  void _onShopMarkerTapped(Barbershop shop, List<Barbershop> filteredShops) {
    setState(() {
      _selectedShopId = shop.id;
      _isCarouselCollapsed = false;
    });

    _animateMapTo(shop.coordinates, 14.5);

    final idx = filteredShops.indexWhere((s) => s.id == shop.id);
    if (idx != -1 && _pageController.hasClients) {
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onCarouselPageChanged(int index, List<Barbershop> filteredShops) {
    if (index >= 0 && index < filteredShops.length) {
      final shop = filteredShops[index];
      setState(() {
        _selectedShopId = shop.id;
      });
      _animateMapTo(shop.coordinates, 14.5);
    }
  }

  void _animateMapTo(LatLng target, double zoom) {
    _mapController.move(target, zoom);
  }

  void _recenterToUser() {
    _animateMapTo(_userLocation, 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final allShops = AppRepository.instance.getShops();
    final filteredShops = _getFilteredShops(allShops);

    // If active selected shop is not in filtered list or null, default to first if available
    if (_selectedShopId == null && filteredShops.isNotEmpty) {
      _selectedShopId = filteredShops.first.id;
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. FlutterMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialSelectedShopId != null
                  ? (allShops.firstWhere(
                      (s) => s.id == widget.initialSelectedShopId,
                      orElse: () => allShops.first,
                    ).coordinates)
                  : _userLocation,
              initialZoom: 13.5,
              minZoom: 4.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                // Tapping empty map area dismisses/minimizes details if desired
              },
            ),
            children: [
              // Tile Layer (CartoDB Dark Luxury or Standard OSM)
              if (_tileStyle == MapTileStyle.darkLuxury)
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.barbershop.barbershop_booking',
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.barbershop.barbershop_booking',
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User Location Marker
                  Marker(
                    point: _userLocation,
                    width: 60,
                    height: 60,
                    child: _buildUserLocationMarker(),
                  ),

                  // Barbershop Markers
                  ...filteredShops.map((shop) {
                    final isSelected = shop.id == _selectedShopId;
                    return Marker(
                      point: shop.coordinates,
                      width: isSelected ? 120 : 85,
                      height: isSelected ? 70 : 55,
                      child: GestureDetector(
                        onTap: () => _onShopMarkerTapped(shop, filteredShops),
                        child: _buildShopMarker(shop, isSelected),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Top Header & Search / Filters
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopSearchBar(context),
                  const SizedBox(height: 8),
                  _buildFilterChips(filteredShops.length),
                ],
              ),
            ),
          ),

          // 3. Floating Map Controls (Zoom in/out, Style, Recenter)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 130,
            child: Column(
              children: [
                _buildFloatingButton(
                  icon: Icons.my_location,
                  tooltip: 'Recenter to My Location',
                  onPressed: _recenterToUser,
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  icon: _tileStyle == MapTileStyle.darkLuxury ? Icons.lightbulb_outline : Icons.dark_mode_outlined,
                  tooltip: 'Toggle Map Style',
                  onPressed: () {
                    setState(() {
                      _tileStyle = _tileStyle == MapTileStyle.darkLuxury
                          ? MapTileStyle.standard
                          : MapTileStyle.darkLuxury;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildFloatingButton(
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, currentZoom + 1);
                  },
                ),
                const SizedBox(height: 6),
                _buildFloatingButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, currentZoom - 1);
                  },
                ),
              ],
            ),
          ),

          // 4. Bottom Horizontal Carousel of Nearby Barbershops
          if (filteredShops.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: AnimatedCrossFade(
                firstChild: _buildCarousel(filteredShops),
                secondChild: _buildCollapsedPill(filteredShops),
                crossFadeState: _isCarouselCollapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            )
          else
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.primaryGold),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No barbershops found for this filter radius.',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _activeFilter = MapFilterRadius.all),
                      child: const Text('Reset', style: TextStyle(color: AppTheme.primaryGold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildTopSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
              onPressed: () => Navigator.pop(context),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.explore, color: AppTheme.primaryGold),
            ),
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search nearby barbershops & streets...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: Colors.white12,
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.primaryGold, size: 20),
            tooltip: 'Filter Radius',
            onPressed: () => _showFilterModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int count) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 13, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  '$count Nearby',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          _buildChip(MapFilterRadius.all, 'All'),
          _buildChip(MapFilterRadius.twoKm, '< 2.5 km'),
          _buildChip(MapFilterRadius.fiveKm, '< 5 km'),
          _buildChip(MapFilterRadius.highlyRated, '★ 4.9+'),
          _buildChip(MapFilterRadius.openNow, 'Open Now'),
        ],
      ),
    );
  }

  Widget _buildChip(MapFilterRadius filter, String label) {
    final isSelected = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryGold.withValues(alpha: 0.9),
        backgroundColor: AppTheme.darkCard.withValues(alpha: 0.9),
        labelStyle: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.black : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryGold : Colors.white24,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onSelected: (_) => setState(() => _activeFilter = filter),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.primaryGold, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing outer ripple
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryGold.withValues(alpha: 0.2),
          ),
        ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryGold.withValues(alpha: 0.4),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryGold,
          ),
        ),
      ],
    );
  }

  Widget _buildShopMarker(Barbershop shop, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 8 : 6,
            vertical: isSelected ? 5 : 3,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : AppTheme.primaryGold,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppTheme.primaryGold.withValues(alpha: 0.6) : Colors.black45,
                blurRadius: isSelected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.content_cut,
                size: isSelected ? 14 : 11,
                color: isSelected ? Colors.black : AppTheme.primaryGold,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSelected ? 11 : 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '★${shop.rating}',
                style: TextStyle(
                  fontSize: isSelected ? 10 : 8.5,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.black87 : AppTheme.primaryGold,
                ),
              ),
            ],
          ),
        ),
        // Arrow Pointer
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(
            color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard,
          ),
        ),
      ],
    );
  }

  Widget _buildCarousel(List<Barbershop> filteredShops) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Collapse Handle Bar
        GestureDetector(
          onTap: () => setState(() => _isCarouselCollapsed = true),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.darkCard.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.primaryGold),
                SizedBox(width: 4),
                Text(
                  'Minimize Card',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _pageController,
            itemCount: filteredShops.length,
            onPageChanged: (idx) => _onCarouselPageChanged(idx, filteredShops),
            itemBuilder: (context, index) {
              final shop = filteredShops[index];
              return _buildCarouselShopCard(shop);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedPill(List<Barbershop> filteredShops) {
    final currentShop = filteredShops.firstWhere(
      (s) => s.id == _selectedShopId,
      orElse: () => filteredShops.first,
    );

    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isCarouselCollapsed = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.darkCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.primaryGold),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, color: AppTheme.primaryGold, size: 16),
              const SizedBox(width: 8),
              Text(
                currentShop.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${currentShop.formattedDistanceFrom(_userLocation)})',
                style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_up, color: AppTheme.primaryGold, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselShopCard(Barbershop shop) {
    final distanceStr = shop.formattedDistanceFrom(_userLocation);
    final barbers = AppRepository.instance.getBarbersForShop(shop.id);
    final services = AppRepository.instance.getServicesForShop(shop.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shop.id == _selectedShopId ? AppTheme.primaryGold : Colors.white.withValues(alpha: 0.1),
          width: shop.id == _selectedShopId ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Left Thumbnail
          Stack(
            children: [
              Image.network(
                shop.imageUrl,
                width: 125,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 125,
                  color: AppTheme.darkSurface,
                  child: const Icon(Icons.storefront, color: AppTheme.primaryGold, size: 36),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me, size: 10, color: AppTheme.primaryGold),
                      const SizedBox(width: 3),
                      Text(
                        distanceStr,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Right Information
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shop.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (shop.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, size: 14, color: AppTheme.primaryGold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${shop.rating} (${shop.reviewCount})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            shop.isOpenNow() ? '• Open Now' : '• Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: shop.isOpenNow() ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${shop.address}, ${shop.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${barbers.length} Barbers • ${services.length} Services',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryGold),
                      ),
                    ],
                  ),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BarbershopDetailScreen(shop: shop),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Book Appointment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Barbershops on Map',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: AppTheme.primaryGold),
                title: const Text('All Nearby Barbershops'),
                trailing: _activeFilter == MapFilterRadius.all ? const Icon(Icons.check, color: AppTheme.primaryGold) : null,
                onTap: () {
                  setState(() => _activeFilter = MapFilterRadius.all);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_walk, color: AppTheme.primaryGold),
                title: const Text('Within 2.5 km (Walking distance)'),
                trailing: _activeFilter == MapFilterRadius.twoKm ? const Icon(Icons.check, color: AppTheme.primaryGold) : null,
                onTap: () {
                  setState(() => _activeFilter = MapFilterRadius.twoKm);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_car, color: AppTheme.primaryGold),
                title: const Text('Within 5.0 km (Short drive)'),
                trailing: _activeFilter == MapFilterRadius.fiveKm ? const Icon(Icons.check, color: AppTheme.primaryGold) : null,
                onTap: () {
                  setState(() => _activeFilter = MapFilterRadius.fiveKm);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: AppTheme.primaryGold),
                title: const Text('Top Rated Only (4.9+ Stars)'),
                trailing: _activeFilter == MapFilterRadius.highlyRated ? const Icon(Icons.check, color: AppTheme.primaryGold) : null,
                onTap: () {
                  setState(() => _activeFilter = MapFilterRadius.highlyRated);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: AppTheme.primaryGold),
                title: const Text('Open Right Now'),
                trailing: _activeFilter == MapFilterRadius.openNow ? const Icon(Icons.check, color: AppTheme.primaryGold) : null,
                onTap: () {
                  setState(() => _activeFilter = MapFilterRadius.openNow);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
