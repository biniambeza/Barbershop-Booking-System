import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../common/screens/location_picker_screen.dart';

class AdminRegisterShopScreen extends StatefulWidget {
  const AdminRegisterShopScreen({super.key});

  @override
  State<AdminRegisterShopScreen> createState() => _AdminRegisterShopScreenState();
}

class _AdminRegisterShopScreenState extends State<AdminRegisterShopScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shop Details
  final _shopNameCtrl = TextEditingController(text: 'Grand Central Barber Club');
  final _shopDescCtrl = TextEditingController(
    text: 'Bespoke precision haircuts, beard sculpting, and luxury hot towel treatments.',
  );
  final _shopPhoneCtrl = TextEditingController(text: '+1 212-555-7800');
  final _imageCtrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
  );

  // Owner Details
  final _ownerNameCtrl = TextEditingController(text: 'Victor Cole');
  final _ownerEmailCtrl = TextEditingController(text: 'victor@grandbarber.com');
  final _ownerPhoneCtrl = TextEditingController(text: '+1 212-555-7801');

  // Location Details
  final _addressCtrl = TextEditingController(text: '89 E 42nd St');
  final _cityCtrl = TextEditingController(text: 'New York, NY');
  double _latitude = 40.7516;
  double _longitude = -73.9765;

  // Operating Hours
  int _openingHour = 9;
  int _closingHour = 20;
  bool _isVerified = true;
  bool _isSubmitting = false;

  final List<Map<String, String>> _imagePresets = [
    {
      'name': 'Classic Lounge',
      'url': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
    },
    {
      'name': 'Vintage Wood',
      'url': 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
    },
    {
      'name': 'Modern Gold',
      'url': 'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=800',
    },
    {
      'name': 'Industrial Studio',
      'url': 'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800',
    },
  ];

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopDescCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _imageCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _addressCtrl.text,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _addressCtrl.text = result.address;
        if (result.address.contains(',')) {
          final parts = result.address.split(',');
          if (parts.length > 1) {
            _cityCtrl.text = parts.sublist(1).join(',').trim();
          }
        }
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = AppRepository.instance;
      final newShopId = await repo.registerBarbershopByAdmin(
        shopName: _shopNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        ownerEmail: _ownerEmailCtrl.text.trim(),
        ownerPhone: _ownerPhoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        description: _shopDescCtrl.text.trim(),
        imageUrl: _imageCtrl.text.trim(),
        openingHour: _openingHour,
        closingHour: _closingHour,
        workingDays: const [1, 2, 3, 4, 5, 6, 7],
        isVerified: _isVerified,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primaryGold, size: 28),
              SizedBox(width: 10),
              Text('Barbershop Registered!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_shopNameCtrl.text.trim()} is now successfully registered in Crown & Blade.',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Owner: ${_ownerNameCtrl.text.trim()} (${_ownerEmailCtrl.text.trim()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Location: ${_addressCtrl.text.trim()}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    const Text('Status: Active with customizable portal & default services', style: TextStyle(fontSize: 12, color: AppTheme.primaryGold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close register screen back to Admin
              },
              child: const Text('Back to Admin Dashboard', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                repo.switchRole(UserRole.barbershopOwner, targetShopId: newShopId);
              },
              icon: const Icon(Icons.storefront, size: 16),
              label: const Text('Open Shop Portal'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering barbershop: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Barbershop'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppTheme.primaryGold, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform Administrator Onboarding',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryGold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Registering a shop automatically provisions the business owner account and their customizable portal.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Barbershop Info
              _buildSectionHeader('1. Barbershop Business Info', Icons.storefront),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shopNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barbershop Name',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Tagline & Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Contact Phone',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 18),

              // Cover Image Presets
              const Text('Cover Photo Aesthetic Preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _imagePresets.map((preset) {
                    final isSelected = _imageCtrl.text == preset['url'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(preset['name']!),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryGold,
                        onSelected: (val) {
                          if (val) setState(() => _imageCtrl.text = preset['url']!);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _imageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cover Photo Image URL',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 28),

              // Section 2: Barbershop Owner Account
              _buildSectionHeader('2. Barbershop Owner Credentials', Icons.person_add_alt_1),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerEmailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Email (Login ID)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Mobile Phone',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 28),

              // Section 3: Interactive Location & Map Pin
              _buildSectionHeader('3. Location & Map Pin', Icons.map_outlined),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: AppTheme.primaryGold, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _addressCtrl.text,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Coordinates: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickLocationOnMap,
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('Pick on Map'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City & State',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 4: Operating Hours & Status
              _buildSectionHeader('4. Business Hours & Verification', Icons.access_time),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _openingHour,
                      decoration: const InputDecoration(labelText: 'Opening Time'),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(15, (i) => i + 6).map((h) {
                        final period = h >= 12 ? 'PM' : 'AM';
                        final displayHour = h > 12 ? h - 12 : h;
                        return DropdownMenuItem(value: h, child: Text('$displayHour:00 $period'));
                      }).toList(),
                      onChanged: (val) => setState(() => _openingHour = val ?? 9),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _closingHour,
                      decoration: const InputDecoration(labelText: 'Closing Time'),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(15, (i) => i + 10).map((h) {
                        final period = h >= 12 ? 'PM' : 'AM';
                        final displayHour = h > 12 ? h - 12 : h;
                        return DropdownMenuItem(value: h, child: Text('$displayHour:00 $period'));
                      }).toList(),
                      onChanged: (val) => setState(() => _closingHour = val ?? 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _isVerified,
                onChanged: (val) => setState(() => _isVerified = val),
                title: const Text('Verified Partner Barbershop', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Displays the verified badge on map pins and customer cards'),
                activeThumbColor: AppTheme.primaryGold,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitRegistration,
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.how_to_reg, size: 22),
                  label: Text(
                    _isSubmitting ? 'Registering...' : 'Register Barbershop into Platform',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGold, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
        ),
      ],
    );
  }
}
