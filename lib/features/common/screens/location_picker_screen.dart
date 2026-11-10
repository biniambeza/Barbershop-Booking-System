import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/theme/app_theme.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude = 40.7484,
    this.initialLongitude = -73.9857,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  late TextEditingController _addressController;

  final List<Map<String, dynamic>> _quickLocations = [
    {
      'name': 'Midtown',
      'lat': 40.7527,
      'lng': -73.9772,
      'address': '422 Lexington Ave, New York, NY',
    },
    {
      'name': 'Empire State',
      'lat': 40.7484,
      'lng': -73.9857,
      'address': '350 5th Ave, New York, NY',
    },
    {
      'name': 'Greenwich Village',
      'lat': 40.7295,
      'lng': -73.9935,
      'address': '784 Broadway St, New York, NY',
    },
    {
      'name': 'Brooklyn DUMBO',
      'lat': 40.7033,
      'lng': -73.9890,
      'address': '55 Water Street, Brooklyn, NY',
    },
    {
      'name': 'Upper West Side',
      'lat': 40.7812,
      'lng': -73.9818,
      'address': '2150 Broadway, New York, NY',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
    _addressController = TextEditingController(
      text: widget.initialAddress ?? '350 5th Ave, New York, NY',
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _moveTo(double lat, double lng, String address) {
    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _addressController.text = address;
    });
    _mapController.move(_selectedLocation, 15.0);
  }

  void _confirm() {
    final address = _addressController.text.trim();
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        address: address.isNotEmpty ? address : 'Selected Location',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pick Shop Location',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primaryGold),
            tooltip: 'Confirm Location',
            onPressed: _confirm,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 14.5,
              minZoom: 4.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.barbershop.barbershop_booking',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: AppTheme.primaryGold,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Instructions & Quick Jump Chips
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app, size: 16, color: AppTheme.primaryGold),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap anywhere on the map to set your barbershop pin',
                            style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickLocations.map((loc) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(Icons.near_me, size: 13, color: AppTheme.primaryGold),
                            label: Text(loc['name'] as String),
                            backgroundColor: AppTheme.darkCard.withValues(alpha: 0.95),
                            labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            side: const BorderSide(color: Colors.white24),
                            onPressed: () {
                              _moveTo(
                                loc['lat'] as double,
                                loc['lng'] as double,
                                loc['address'] as String,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Recenter / Locate Button
          Positioned(
            right: 14,
            bottom: 210,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: AppTheme.primaryGold, size: 20),
                tooltip: 'Recenter Pin',
                onPressed: () => _mapController.move(_selectedLocation, 15.0),
              ),
            ),
          ),

          // 4. Bottom Confirmation Panel
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primaryGold, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: AppTheme.primaryGold, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Selected Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      prefixIcon: Icon(Icons.edit_location_alt_outlined, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text(
                        'Set Shop Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
}
