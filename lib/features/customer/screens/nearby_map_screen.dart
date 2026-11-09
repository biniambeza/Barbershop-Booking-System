import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import 'barbershop_detail_screen.dart';

enum MapFilterRadius { all, twoKm, fiveKm, highlyRated, openNow }
enum MapTileStyle { darkLuxury, standard }

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

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final MapController _mapController = MapController();

  // User reference location: Midtown Manhattan NYC
  final LatLng _userLocation = const LatLng(40.7484, -73.9857);

  String _searchQuery = '';
  MapFilterRadius _activeFilter = MapFilterRadius.all;
  MapTileStyle _tileStyle = MapTileStyle.darkLuxury;

  Barbershop? _selectedShop;

  @override
  void initState() {
    super.initState();
    final allShops = AppRepository.instance.getShops();
    if (widget.initialSelectedShopId != null) {
      _selectedShop = allShops.firstWhere(
        (s) => s.id == widget.initialSelectedShopId,
        orElse: () => allShops.first,
      );
    } else if (allShops.isNotEmpty) {
      _selectedShop = allShops.first;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Barbershop> _getFilteredShops(List<Barbershop> allShops) {
    return allShops.where((shop) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = shop.name.toLowerCase().contains(q) ||
            shop.address.toLowerCase().contains(q) ||
            shop.city.toLowerCase().contains(q);
        if (!match) return false;
      }

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

  void _selectShop(Barbershop shop) {
    setState(() {
      _selectedShop = shop;
    });
    _mapController.move(shop.coordinates, 14.5);
  }

  void _recenterToUser() {
    _mapController.move(_userLocation, 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final allShops = AppRepository.instance.getShops();
    final filteredShops = _getFilteredShops(allShops);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedShop != null ? _selectedShop!.coordinates : _userLocation,
              initialZoom: 13.5,
              minZoom: 4.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                // Tapping on empty map dismisses the selected card for clean view
                if (_selectedShop != null) {
                  setState(() => _selectedShop = null);
                }
              },
            ),
            children: [
              // Tile Layer
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

              // Markers
              MarkerLayer(
                markers: [
                  // User Location Marker with Person Pin Icon
                  Marker(
                    point: _userLocation,
                    width: 44,
                    height: 44,
                    child: _buildUserMarker(),
                  ),

                  // Barbershop Markers
                  ...filteredShops.map((shop) {
                    final isSelected = _selectedShop?.id == shop.id;
                    return Marker(
                      point: shop.coordinates,
                      width: isSelected ? 115 : 95,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _selectShop(shop),
                        child: _buildPinMarker(shop, isSelected),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Top Header & Search + Filters
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(context),
                  const SizedBox(height: 8),
                  _buildFilterBar(),
                ],
              ),
            ),
          ),

          // 3. Floating Action Buttons (Recenter & Map Style)
          Positioned(
            right: 14,
            top: MediaQuery.of(context).padding.top + 115,
            child: Column(
              children: [
                _buildFloatingButton(
                  icon: Icons.my_location,
                  tooltip: 'Recenter',
                  onPressed: _recenterToUser,
                ),
                const SizedBox(height: 8),
                _buildFloatingButton(
                  icon: _tileStyle == MapTileStyle.darkLuxury ? Icons.layers : Icons.layers_outlined,
                  tooltip: 'Map Style',
                  onPressed: () {
                    setState(() {
                      _tileStyle = _tileStyle == MapTileStyle.darkLuxury
                          ? MapTileStyle.standard
                          : MapTileStyle.darkLuxury;
                    });
                  },
                ),
              ],
            ),
          ),

          // 4. Bottom Selected Barbershop Card
          if (_selectedShop != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _buildSelectedShopCard(_selectedShop!),
            ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 3),
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
              child: Icon(Icons.location_on, color: AppTheme.primaryGold, size: 22),
            ),
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search nearby barbershops...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(MapFilterRadius.all, 'All', Icons.storefront),
          _buildChip(MapFilterRadius.twoKm, '< 2.5 km', Icons.directions_walk),
          _buildChip(MapFilterRadius.fiveKm, '< 5 km', Icons.directions_car),
          _buildChip(MapFilterRadius.highlyRated, 'Top Rated', Icons.star),
          _buildChip(MapFilterRadius.openNow, 'Open Now', Icons.schedule),
        ],
      ),
    );
  }

  Widget _buildChip(MapFilterRadius filter, String label, IconData icon) {
    final isSelected = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 14,
          color: isSelected ? Colors.black : AppTheme.primaryGold,
        ),
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryGold,
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.primaryGold, size: 20),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildUserMarker() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryGold,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 6),
        ],
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.black, size: 22),
      ),
    );
  }

  Widget _buildPinMarker(Barbershop shop, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.white : AppTheme.primaryGold,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? AppTheme.primaryGold.withValues(alpha: 0.5) : Colors.black54,
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.content_cut,
            size: isSelected ? 13 : 11,
            color: isSelected ? Colors.black : AppTheme.primaryGold,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              shop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star,
            size: 11,
            color: isSelected ? Colors.black87 : AppTheme.primaryGold,
          ),
          const SizedBox(width: 1),
          Text(
            '${shop.rating}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black87 : AppTheme.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedShopCard(Barbershop shop) {
    final distanceStr = shop.formattedDistanceFrom(_userLocation);
    final barbers = AppRepository.instance.getBarbersForShop(shop.id);
    final services = AppRepository.instance.getServicesForShop(shop.id);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    shop.imageUrl,
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 78,
                      height: 78,
                      color: AppTheme.darkSurface,
                      child: const Icon(Icons.storefront, color: AppTheme.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
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
                          InkWell(
                            onTap: () => setState(() => _selectedShop = null),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${shop.rating} (${shop.reviewCount})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.navigation, size: 11, color: AppTheme.primaryGold),
                          const SizedBox(width: 2),
                          Text(
                            distanceStr,
                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: shop.isOpenNow() ? Colors.greenAccent : Colors.redAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            shop.isOpenNow() ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: shop.isOpenNow() ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${shop.address}, ${shop.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 13, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${barbers.length} Barbers',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryGold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.content_cut, size: 11, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${services.length} Services',
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryGold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
            ),
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
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
                icon: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                label: const Icon(Icons.arrow_forward, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
