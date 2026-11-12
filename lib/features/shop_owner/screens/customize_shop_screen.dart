import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
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
      openingHour: _openingHour,
      closingHour: _closingHour,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarbershopDetailScreen(shop: previewShop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize My Barbershop'),
        actions: [
          TextButton.icon(
            onPressed: _previewShopAsCustomer,
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppTheme.primaryGold),
            label: const Text('Preview', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving Updates...' : 'Publish Shop Customizations', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.primaryGold,
                      radius: 20,
                      child: Icon(Icons.brush, color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Barbershop Brand Profile',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('Changes made here instantly appear in the customer booking experience.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Identity & Visuals
              _buildSectionTitle('Barbershop Branding & Info', Icons.storefront),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Barbershop Name *', prefixIcon: Icon(Icons.business)),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Brand Bio & Story', prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Business Phone Number', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 14),

              // Theme Presets
              const Text('Quick Theme Aesthetic Presets:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
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

              // Section 2: Physical Location (No Map!)
              _buildSectionTitle('Physical Location & Address', Icons.location_on_outlined),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Street Address', prefixIcon: Icon(Icons.location_on_outlined)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(labelText: 'City & State', prefixIcon: Icon(Icons.location_city)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
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
              const Text('Open Working Days:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayToggle(1, 'Mon'),
                  _buildDayToggle(2, 'Tue'),
                  _buildDayToggle(3, 'Wed'),
                  _buildDayToggle(4, 'Thu'),
                  _buildDayToggle(5, 'Fri'),
                  _buildDayToggle(6, 'Sat'),
                  _buildDayToggle(7, 'Sun'),
                ],
              ),
              const SizedBox(height: 60),
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
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDayToggle(int dayNumber, String label) {
    final isSelected = _workingDays.contains(dayNumber);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_workingDays.length > 1) _workingDays.remove(dayNumber);
          } else {
            _workingDays.add(dayNumber);
            _workingDays.sort();
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primaryGold : Colors.white12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
