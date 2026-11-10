import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import 'barbershop_detail_screen.dart';
import 'booking_flow_screen.dart';

enum MapFilterRadius { all, twoKm, fiveKm, highlyRated, openNow }
enum MapTileStyle { standard, darkLuxury }

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
  MapTileStyle _tileStyle = MapTileStyle.standard;

  // Toggle between viewing Barbershops vs individual Nearby Barbers
  bool _showBarbersMode = false;

  Barbershop? _selectedShop;
  BarberWithShop? _selectedBarberWithShop;

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

  List<BarberWithShop> _getFilteredBarbers(List<BarberWithShop> allBarbersWithShops) {
    return allBarbersWithShops.where((item) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = item.barber.name.toLowerCase().contains(q) ||
            item.barber.title.toLowerCase().contains(q) ||
            item.shop.name.toLowerCase().contains(q) ||
            item.shop.address.toLowerCase().contains(q);
        if (!match) return false;
      }

      final distanceKm = item.shop.distanceInKmFrom(_userLocation);
      switch (_activeFilter) {
        case MapFilterRadius.all:
          return true;
        case MapFilterRadius.twoKm:
          return distanceKm <= 2.5;
        case MapFilterRadius.fiveKm:
          return distanceKm <= 5.0;
        case MapFilterRadius.highlyRated:
          return item.barber.rating >= 4.9;
        case MapFilterRadius.openNow:
          return item.shop.isOpenNow();
      }
    }).toList()
      ..sort((a, b) => a.shop.distanceInKmFrom(_userLocation).compareTo(b.shop.distanceInKmFrom(_userLocation)));
  }

  void _selectShop(Barbershop shop) {
    setState(() {
      _selectedShop = shop;
      _selectedBarberWithShop = null;
    });
    _mapController.move(shop.coordinates, 14.5);
  }

  void _selectBarber(BarberWithShop item) {
    setState(() {
      _selectedBarberWithShop = item;
      _selectedShop = null;
    });
    _mapController.move(item.shop.coordinates, 14.5);
  }

  void _recenterToUser() {
    _mapController.move(_userLocation, 14.0);
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();
    final filteredShops = _getFilteredShops(allShops);
    final allBarbersWithShops = repo.getAllBarbersWithShops();
    final filteredBarbers = _getFilteredBarbers(allBarbersWithShops);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedBarberWithShop != null
                  ? _selectedBarberWithShop!.shop.coordinates
                  : (_selectedShop != null ? _selectedShop!.coordinates : _userLocation),
              initialZoom: 13.5,
              minZoom: 4.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                if (_selectedShop != null || _selectedBarberWithShop != null) {
                  setState(() {
                    _selectedShop = null;
                    _selectedBarberWithShop = null;
                  });
                }
              },
            ),
            children: [
              // Tile Layer
              if (_tileStyle == MapTileStyle.darkLuxury)
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
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
                  // User Location Pin
                  Marker(
                    point: _userLocation,
                    width: 44,
                    height: 44,
                    child: _buildUserMarker(),
                  ),

                  // Mode A: Barbershop Pins
                  if (!_showBarbersMode)
                    ...filteredShops.map((shop) {
                      final isSelected = _selectedShop?.id == shop.id;
                      return Marker(
                        point: shop.coordinates,
                        width: isSelected ? 120 : 95,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _selectShop(shop),
                          child: _buildShopPin(shop, isSelected),
                        ),
                      );
                    })
                  // Mode B: Nearby Barber Pins
                  else
                    ...filteredBarbers.map((item) {
                      final isSelected = _selectedBarberWithShop?.barber.id == item.barber.id;
                      return Marker(
                        point: item.shop.coordinates,
                        width: isSelected ? 130 : 105,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _selectBarber(item),
                          child: _buildBarberPin(item, isSelected),
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
                  _buildModeAndFilterBar(filteredShops.length, filteredBarbers.length),
                ],
              ),
            ),
          ),

          // 3. Floating Action Buttons (Recenter & Map Style)
          Positioned(
            right: 14,
            top: MediaQuery.of(context).padding.top + 130,
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

          // 4. Bottom Selected Card (Shop or Barber)
          if (!_showBarbersMode && _selectedShop != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _buildSelectedShopCard(_selectedShop!),
            )
          else if (_showBarbersMode && _selectedBarberWithShop != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _buildSelectedBarberCard(_selectedBarberWithShop!),
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
                hintText: _showBarbersMode ? 'Search nearby barbers by name or skill...' : 'Search nearby barbershops...',
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

  Widget _buildModeAndFilterBar(int shopCount, int barberCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Target Mode Switcher: Shops vs Barbers
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.darkCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _showBarbersMode = false;
                    _selectedBarberWithShop = null;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: !_showBarbersMode ? AppTheme.primaryGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront,
                          size: 15,
                          color: !_showBarbersMode ? Colors.black : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Shops ($shopCount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_showBarbersMode ? Colors.black : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _showBarbersMode = true;
                    _selectedShop = null;
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _showBarbersMode ? AppTheme.primaryGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          size: 15,
                          color: _showBarbersMode ? Colors.black : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Nearby Barbers ($barberCount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _showBarbersMode ? Colors.black : AppTheme.textSecondary,
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
        const SizedBox(height: 6),

        // Radius & Star Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip(MapFilterRadius.all, 'All', Icons.near_me),
              _buildChip(MapFilterRadius.twoKm, '< 2.5 km', Icons.directions_walk),
              _buildChip(MapFilterRadius.fiveKm, '< 5 km', Icons.directions_car),
              _buildChip(MapFilterRadius.highlyRated, 'Top Rated', Icons.star),
              _buildChip(MapFilterRadius.openNow, 'Open Now', Icons.schedule),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(MapFilterRadius filter, String label, IconData icon) {
    final isSelected = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
      width: 40,
      height: 40,
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
        icon: Icon(icon, color: AppTheme.primaryGold, size: 18),
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

  Widget _buildShopPin(Barbershop shop, bool isSelected) {
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

  Widget _buildBarberPin(BarberWithShop item, bool isSelected) {
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
            Icons.person,
            size: isSelected ? 13 : 11,
            color: isSelected ? Colors.black : AppTheme.primaryGold,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              item.barber.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.star,
            size: 11,
            color: isSelected ? Colors.black87 : AppTheme.primaryGold,
          ),
          const SizedBox(width: 1),
          Text(
            '${item.barber.rating}',
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Barbers Roster at this Shop
          if (barbers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.people, size: 13, color: AppTheme.primaryGold),
                  const SizedBox(width: 4),
                  Text(
                    'Barbers at this shop (${barbers.length}):',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: barbers.length,
                itemBuilder: (context, index) {
                  final barber = barbers[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                          onBackgroundImageError: barber.avatarUrl != null ? (error, stackTrace) {} : null,
                          backgroundColor: AppTheme.primaryGold,
                          child: barber.avatarUrl == null
                              ? Text(barber.name.substring(0, 1), style: const TextStyle(fontSize: 10, color: Colors.black))
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(barber.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 10, color: AppTheme.primaryGold),
                                const SizedBox(width: 2),
                                Text('${barber.rating}', style: const TextStyle(fontSize: 10, color: AppTheme.primaryGold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

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
                icon: Text('Book with Shop (${services.length} Services)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                label: const Icon(Icons.arrow_forward, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBarberCard(BarberWithShop item) {
    final distanceStr = item.shop.formattedDistanceFrom(_userLocation);
    final services = AppRepository.instance.getServicesForShop(item.shop.id);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barber Avatar
                CircleAvatar(
                  radius: 34,
                  backgroundImage: item.barber.avatarUrl != null ? NetworkImage(item.barber.avatarUrl!) : null,
                  onBackgroundImageError: item.barber.avatarUrl != null ? (error, stackTrace) {} : null,
                  backgroundColor: AppTheme.primaryGold,
                  child: item.barber.avatarUrl == null
                      ? Text(item.barber.name.substring(0, 1), style: const TextStyle(fontSize: 20, color: Colors.black))
                      : null,
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
                              item.barber.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _selectedBarberWithShop = null),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.barber.title,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            '${item.barber.rating} (${item.barber.reviewCount} cuts)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.navigation, size: 11, color: AppTheme.primaryGold),
                          const SizedBox(width: 3),
                          Text(
                            distanceStr,
                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${item.shop.name} • ${item.shop.address}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Button: Direct booking with this barber
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
                  // Direct booking flow with this barber pre-selected
                  if (services.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingFlowScreen(
                          shop: item.shop,
                          initialService: services.first,
                          initialBarber: item.barber,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BarbershopDetailScreen(shop: item.shop),
                      ),
                    );
                  }
                },
                icon: Text('Book Appointment with ${item.barber.name.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                label: const Icon(Icons.arrow_forward, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
