import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../common/screens/location_picker_screen.dart';
import '../../customer/screens/barbershop_detail_screen.dart';

class CustomizeShopScreen extends StatefulWidget {
  final Barbershop shop;

  const CustomizeShopScreen({super.key, required this.shop});

  @override
  State<CustomizeShopScreen> createState() => _CustomizeShopScreenState();
}

class _CustomizeShopScreenState extends State<CustomizeShopScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _imageCtrl;

  late double _latitude;
  late double _longitude;
  late int _openingHour;
  late int _closingHour;
  late List<int> _workingDays;
  bool _isSaving = false;

  final List<Map<String, String>> _themePresets = [
    {
      'title': 'Royal Gold & Noir',
      'url': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
    },
    {
      'title': 'Vintage Gentleman',
      'url': 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800',
    },
    {
      'title': 'Empire Luxury',
      'url': 'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=800',
    },
    {
      'title': 'Urban Industrial',
      'url': 'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800',
    },
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.shop;
    _nameCtrl = TextEditingController(text: s.name);
    _descCtrl = TextEditingController(text: s.description);
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
    _cityCtrl = TextEditingController(text: s.city);
    _imageCtrl = TextEditingController(text: s.imageUrl);

    _latitude = s.latitude;
    _longitude = s.longitude;
    _openingHour = s.openingHour;
    _closingHour = s.closingHour;
    _workingDays = List<int>.from(s.workingDays);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateMapLocation() async {
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = widget.shop.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      imageUrl: _imageCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      openingHour: _openingHour,
      closingHour: _closingHour,
      workingDays: _workingDays,
    );

    await AppRepository.instance.updateShop(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customized shop settings saved successfully!')),
      );
      Navigator.pop(context, updated);
    }
  }

  void _previewShopAsCustomer() {
    final previewShop = widget.shop.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      imageUrl: _imageCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      openingHour: _openingHour,
      closingHour: _closingHour,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BarbershopDetailScreen(shop: previewShop)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const daysMap = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Barbershop App'),
        actions: [
          TextButton.icon(
            onPressed: _previewShopAsCustomer,
            icon: const Icon(Icons.remove_red_eye, size: 16, color: AppTheme.primaryGold),
            label: const Text('Live Preview', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.dashboard_customize, color: AppTheme.primaryGold, size: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Customize your shop branding, cover imagery, map location, and business schedule in real time.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Branding
              _buildSectionTitle('Shop Branding & Profile', Icons.palette_outlined),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Barbershop Name', prefixIcon: Icon(Icons.store)),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'About / Description', prefixIcon: Icon(Icons.description_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Business Phone', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 20),

              // Aesthetic Presets
              const Text('Cover Photo Aesthetic Preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _themePresets.map((preset) {
                    final isSelected = _imageCtrl.text == preset['url'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(preset['title']!),
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
                decoration: const InputDecoration(labelText: 'Cover Photo Image URL', prefixIcon: Icon(Icons.image)),
              ),
              const SizedBox(height: 28),

              // Section 2: Interactive Location & Map
              _buildSectionTitle('Location & Pinned Map Coordinates', Icons.map_outlined),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_addressCtrl.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('Pin: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _updateMapLocation,
                          icon: const Icon(Icons.pin_drop, size: 14),
                          label: const Text('Update Map Pin'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Street Address', prefixIcon: Icon(Icons.location_on_outlined)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(labelText: 'City, State', prefixIcon: Icon(Icons.location_city)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 3: Operating Hours & Open Days
              _buildSectionTitle('Business Schedule & Hours', Icons.schedule),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _openingHour,
                      decoration: const InputDecoration(labelText: 'Opening Hour'),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(15, (i) => i + 6).map((h) {
                        final period = h >= 12 ? 'PM' : 'AM';
                        final displayHour = h > 12 ? h - 12 : h;
                        return DropdownMenuItem(value: h, child: Text('$displayHour:00 $period'));
                      }).toList(),
                      onChanged: (val) => setState(() => _openingHour = val ?? 9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _closingHour,
                      decoration: const InputDecoration(labelText: 'Closing Hour'),
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

              const Text('Open Working Days:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: daysMap.entries.map((entry) {
                  final dayIndex = entry.key;
                  final dayLabel = entry.value;
                  final isSelected = _workingDays.contains(dayIndex);
                  return FilterChip(
                    label: Text(dayLabel),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryGold,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _workingDays.add(dayIndex);
                          _workingDays.sort();
                        } else {
                          if (_workingDays.length > 1) {
                            _workingDays.remove(dayIndex);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check, size: 22),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save & Publish Customization',
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGold, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
      ],
    );
  }
}
