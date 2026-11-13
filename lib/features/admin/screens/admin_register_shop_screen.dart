import 'package:flutter/material.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../../data/addis_locations.dart';

class AdminRegisterShopScreen extends StatefulWidget {
  const AdminRegisterShopScreen({super.key});

  @override
  State<AdminRegisterShopScreen> createState() => _AdminRegisterShopScreenState();
}

class _AdminRegisterShopScreenState extends State<AdminRegisterShopScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shop Details
  final _shopNameCtrl = TextEditingController();
  final _shopDescCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _imageCtrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
  );

  // Owner Details
  final _ownerNameCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();

  // Location Details
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: kDefaultCity);
  final _landmarkCtrl = TextEditingController();
  String _subCity = 'Bole';

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

  String _presetName(String name) {
    final l = context.l10n;
    switch (name) {
      case 'Classic Lounge':
        return l.presetClassicLounge;
      case 'Vintage Wood':
        return l.presetVintageWood;
      case 'Modern Gold':
        return l.presetModernGold;
      case 'Industrial Studio':
        return l.presetIndustrialStudio;
      default:
        return name;
    }
  }

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
    _landmarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final shopPhone = normalizeEthiopianContactPhone(_shopPhoneCtrl.text) ?? _shopPhoneCtrl.text.trim();

    try {
      await AppRepository.instance.registerBarbershopByAdmin(
        shopName: _shopNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        ownerPhone: _ownerPhoneCtrl.text.trim(),
        shopPhone: shopPhone,
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        subCity: _subCity,
        landmark: _landmarkCtrl.text.trim(),
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
              context.l10n.registeredShopSnack(_shopNameCtrl.text.trim(), formatEthiopianPhone(_ownerPhoneCtrl.text)),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.registrationError(context.l10n.authError(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.registerNewBarbershop),
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
                child: Row(
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
                            l.onboardingTitle,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          SizedBox(height: 2),
                          Text(
                            l.onboardingSubtitle,
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
              _buildSectionHeader(l.sectionShopProfile, Icons.storefront),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shopNameCtrl,
                decoration: InputDecoration(
                  labelText: l.shopBusinessName,
                  hintText: l.shopBusinessNameHint,
                  prefixIcon: const Icon(Icons.business),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopDescCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l.shopDescription,
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.shopTelephone,
                  hintText: l.shopPhoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (val) => normalizeEthiopianContactPhone(val ?? '') == null ? l.invalidContactPhone : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageCtrl,
                decoration: InputDecoration(
                  labelText: l.coverImageUrl,
                  prefixIcon: const Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 8),
              // Image Presets
              Wrap(
                spacing: 8,
                children: _imagePresets.map((preset) {
                  return ActionChip(
                    label: Text(_presetName(preset['name']!), style: const TextStyle(fontSize: 11)),
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
              _buildSectionHeader(l.sectionOwnerAccount, Icons.person_outline),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: InputDecoration(
                  labelText: l.ownerFullName,
                  hintText: l.ownerNameHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.ownerMobileLogin,
                  hintText: '09XX XXX XXX',
                  helperText: l.ownerMobileHelper,
                  prefixIcon: const Icon(Icons.phone_android),
                ),
                validator: (val) => normalizeEthiopianPhone(val ?? '') == null ? l.invalidEthiopianPhone : null,
              ),
              const SizedBox(height: 28),

              // Section 3: Location Details (No Map!)
              _buildSectionHeader(l.sectionLocation, Icons.location_on_outlined),
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
                      decoration: InputDecoration(
                        labelText: l.streetAddressRequired,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        hintText: l.streetAddressHint,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _subCity,
                      decoration: InputDecoration(
                        labelText: l.subCityRequired,
                        prefixIcon: const Icon(Icons.map_outlined),
                      ),
                      items: [
                        for (final sc in kAddisSubCities) DropdownMenuItem(value: sc, child: Text(l.placeName(sc))),
                      ],
                      onChanged: (val) => setState(() => _subCity = val ?? _subCity),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _landmarkCtrl,
                      decoration: InputDecoration(
                        labelText: l.landmark,
                        prefixIcon: const Icon(Icons.place_outlined),
                        hintText: l.landmarkHint,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: l.cityRequired,
                        prefixIcon: const Icon(Icons.location_city),
                        hintText: l.cityHint,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 4: Operating Hours & Status
              _buildSectionHeader(l.sectionHours, Icons.access_time),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _openingHour,
                      decoration: InputDecoration(labelText: l.openingTime),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(6, (i) => i + 6).map((h) {
                        return DropdownMenuItem(
                          value: h,
                          child: Text(fmt.hour(h)),
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
                      isExpanded: true,
                      initialValue: _closingHour,
                      decoration: InputDecoration(labelText: l.closingTime),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(8, (i) => i + 16).map((h) {
                        return DropdownMenuItem(
                          value: h,
                          child: Text(fmt.hour(h)),
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
                title: Text(l.markVerifiedPartner, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l.markVerifiedPartnerSubtitle),
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
                    _isSubmitting ? l.registeringBarbershop : l.registerIntoNetwork,
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
