import 'package:flutter/material.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../services/phone_auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/app_repository.dart';

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
  final _ownerPhoneCtrl = TextEditingController();

  // Location Details
  final _addressCtrl = TextEditingController(text: '89 E 42nd St');
  final _cityCtrl = TextEditingController(text: 'New York, NY');

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
    _ownerPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await AppRepository.instance.registerBarbershopByAdmin(
        shopName: _shopNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        ownerPhone: _ownerPhoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        description: _shopDescCtrl.text.trim(),
        imageUrl: _imageCtrl.text.trim(),
        openingHour: _openingHour,
        closingHour: _closingHour,
        workingDays: const [1, 2, 3, 4, 5, 6, 7],
        isVerified: _isVerified,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              'Registered "${_shopNameCtrl.text}". The owner can now sign in with ${formatEthiopianPhone(_ownerPhoneCtrl.text)}.',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: ${describeAuthError(e)}')),
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SaaS Registration Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGold.withValues(alpha: 0.2),
                      AppTheme.darkCard,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryGold,
                      radius: 20,
                      child: Icon(Icons.admin_panel_settings, color: Colors.black, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SaaS Barbershop Onboarding',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Registers shop profile, provisions tenant owner account & sets up staff suite.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Shop Information
              _buildSectionHeader('1. Shop Profile & Branding', Icons.storefront),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shopNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barbershop Business Name *',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Shop Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Telephone *',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cover Image URL',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 8),
              // Image Presets
              Wrap(
                spacing: 8,
                children: _imagePresets.map((preset) {
                  return ActionChip(
                    label: Text(preset['name']!, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _imageCtrl.text = preset['url']!;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Section 2: Owner Account
              _buildSectionHeader('2. Barbershop Owner Account', Icons.person_outline),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Owner Mobile Number (Login) *',
                  hintText: '09XX XXX XXX',
                  helperText: 'The owner signs in with this number to manage the shop.',
                  prefixIcon: Icon(Icons.phone_android),
                ),
                validator: (val) => normalizeEthiopianPhone(val ?? '') == null
                    ? 'Enter a valid Ethiopian mobile number (09... or 07...)'
                    : null,
              ),
              const SizedBox(height: 28),

              // Section 3: Location Details (No Map!)
              _buildSectionHeader('3. Physical Location', Icons.location_on_outlined),
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
                      decoration: const InputDecoration(
                        labelText: 'Street Address *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        hintText: 'e.g. 123 Main St, Suite 4',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City, State & ZIP *',
                        prefixIcon: Icon(Icons.location_city),
                        hintText: 'e.g. New York, NY 10001',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
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
                      items: List.generate(6, (i) => i + 6).map((h) {
                        return DropdownMenuItem(
                          value: h,
                          child: Text('$h:00 AM'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _openingHour = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _closingHour,
                      decoration: const InputDecoration(labelText: 'Closing Time'),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(8, (i) => i + 16).map((h) {
                        return DropdownMenuItem(
                          value: h,
                          child: Text('${h - 12}:00 PM'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _closingHour = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as Verified Partner Shop', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Verified badge displayed to all customers'),
                value: _isVerified,
                activeThumbColor: AppTheme.primaryGold,
                onChanged: (val) => setState(() => _isVerified = val),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSubmitting ? 'Registering Barbershop...' : 'Register Barbershop into Network',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 40),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
