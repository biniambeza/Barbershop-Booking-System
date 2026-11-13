import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../data/addis_locations.dart';
import '../../../l10n/l10n.dart';
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
  late TextEditingController _landmarkCtrl;
  late String _subCity;

  late int _openingHour;
  late int _closingHour;
  late List<int> _workingDays;
  bool _isSaving = false;

  /// Booking policy (saved with its own write, see AppRepository.updateShopPolicy).
  late int _cutoffHours;
  late int _maxReschedules;

  /// Cutoff choices (hours before the start); the current value is kept
  /// even if it is not one of them.
  static const List<int> _cutoffChoices = [0, 1, 2, 3, 4, 6, 12, 24, 48, 72];

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
    _landmarkCtrl = TextEditingController(text: s.landmark ?? '');
    _subCity = s.subCity;

    _openingHour = s.openingHour;
    _closingHour = s.closingHour;
    _workingDays = List<int>.from(s.workingDays);
    _cutoffHours = s.cancellationCutoffHours;
    _maxReschedules = s.maxReschedules;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _imageCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  String _presetTitle(String title) {
    final l = context.l10n;
    switch (title) {
      case 'Royal Gold & Noir':
        return l.presetRoyalGold;
      case 'Vintage Gentleman':
        return l.presetVintageGentleman;
      case 'Empire Luxury':
        return l.presetEmpireLuxury;
      case 'Urban Industrial':
        return l.presetUrbanIndustrial;
      default:
        return title;
    }
  }

  Barbershop _edited() {
    final phone = _phoneCtrl.text.trim();
    final landmark = _landmarkCtrl.text.trim();
    return widget.shop.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      phone: normalizeEthiopianContactPhone(phone) ?? phone,
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      subCity: _subCity,
      landmark: landmark.isEmpty ? null : landmark,
      clearLandmark: landmark.isEmpty,
      imageUrl: _imageCtrl.text.trim(),
      openingHour: _openingHour,
      closingHour: _closingHour,
      workingDays: _workingDays,
      cancellationCutoffHours: _cutoffHours,
      maxReschedules: _maxReschedules,
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final updated = _edited();
    try {
      await AppRepository.instance.updateShop(updated);
      if (_cutoffHours != widget.shop.cancellationCutoffHours || _maxReschedules != widget.shop.maxReschedules) {
        await AppRepository.instance.updateShopPolicy(
          widget.shop.id,
          cancellationCutoffHours: _cutoffHours,
          maxReschedules: _maxReschedules,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed(l.errorText(e)))));
      return;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l.shopSettingsSaved)),
      );
      Navigator.pop(context, updated);
    }
  }

  void _previewShopAsCustomer() {
    final previewShop = _edited();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarbershopDetailScreen(shop: previewShop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final subCities = [
      if (_subCity.isEmpty) '',
      ...kAddisSubCities,
      if (_subCity.isNotEmpty && !kAddisSubCities.contains(_subCity)) _subCity,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.customizeMyBarbershop),
        actions: [
          TextButton.icon(
            onPressed: _previewShopAsCustomer,
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppTheme.primaryGold),
            label: Text(l.preview, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
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
              label: Text(_isSaving ? l.savingUpdates : l.publishCustomizations, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                          Text(l.brandProfile,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(l.brandProfileHint, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Identity & Visuals
              _buildSectionTitle(l.sectionBranding, Icons.storefront),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: l.barbershopNameRequired, prefixIcon: const Icon(Icons.business)),
                validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: l.brandBio, prefixIcon: const Icon(Icons.notes)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.businessPhone,
                  hintText: l.shopPhoneHint,
                  prefixIcon: const Icon(Icons.phone),
                ),
                validator: (val) => val == null || val.trim().isEmpty || normalizeEthiopianContactPhone(val) != null
                    ? null
                    : l.invalidContactPhone,
              ),
              const SizedBox(height: 14),

              // Theme Presets
              Text(l.themePresets, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _themePresets.map((preset) {
                    final isSelected = _imageCtrl.text == preset['url'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(_presetTitle(preset['title']!)),
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
                decoration: InputDecoration(labelText: l.coverPhotoUrl, prefixIcon: const Icon(Icons.image)),
              ),
              const SizedBox(height: 28),

              // Section 2: Physical Location (No Map!)
              _buildSectionTitle(l.sectionAddress, Icons.location_on_outlined),
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
                      decoration: InputDecoration(labelText: l.streetAddress, prefixIcon: const Icon(Icons.location_on_outlined)),
                      validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _subCity,
                      decoration: InputDecoration(labelText: l.subCity, prefixIcon: const Icon(Icons.map_outlined)),
                      dropdownColor: AppTheme.darkCard,
                      items: [
                        for (final sc in subCities) DropdownMenuItem(value: sc, child: Text(sc.isEmpty ? '-' : l.placeName(sc))),
                      ],
                      onChanged: (val) => setState(() => _subCity = val ?? _subCity),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _landmarkCtrl,
                      decoration: InputDecoration(
                        labelText: l.landmark,
                        hintText: l.landmarkHint,
                        prefixIcon: const Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(labelText: l.city, prefixIcon: const Icon(Icons.location_city)),
                      validator: (val) => val == null || val.trim().isEmpty ? l.required : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section 3: Operating Hours & Open Days
              _buildSectionTitle(l.sectionSchedule, Icons.schedule),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _openingHour,
                      decoration: InputDecoration(labelText: l.openingHour),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(15, (i) => i + 6).map((h) {
                        return DropdownMenuItem(value: h, child: Text(fmt.hour(h)));
                      }).toList(),
                      onChanged: (val) => setState(() => _openingHour = val ?? 9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _closingHour,
                      decoration: InputDecoration(labelText: l.closingHour),
                      dropdownColor: AppTheme.darkCard,
                      items: List.generate(15, (i) => i + 10).map((h) {
                        return DropdownMenuItem(value: h, child: Text(fmt.hour(h)));
                      }).toList(),
                      onChanged: (val) => setState(() => _closingHour = val ?? 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l.openWorkingDays, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var d = 1; d <= 7; d++) _buildDayToggle(d, fmt.weekdayName(d)),
                ],
              ),
              const SizedBox(height: 28),

              // Section 4: Booking policy (cancellation cutoff, reschedules)
              _buildSectionTitle(l.policySectionTitle, Icons.policy_outlined),
              const SizedBox(height: 8),
              Text(l.policyCutoffHelp, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('policy-cutoff'),
                isExpanded: true,
                initialValue: _cutoffHours,
                decoration: InputDecoration(labelText: l.policyCutoffLabel, prefixIcon: const Icon(Icons.timer_outlined)),
                dropdownColor: AppTheme.darkCard,
                items: [
                  for (final h in {..._cutoffChoices, _cutoffHours}.toList()..sort())
                    DropdownMenuItem(value: h, child: Text(l.policyHoursValue(h))),
                ],
                onChanged: (val) => setState(() => _cutoffHours = val ?? _cutoffHours),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('policy-max-reschedules'),
                isExpanded: true,
                initialValue: _maxReschedules,
                decoration: InputDecoration(labelText: l.policyMaxReschedulesLabel, prefixIcon: const Icon(Icons.update)),
                dropdownColor: AppTheme.darkCard,
                items: [
                  for (var n = 0; n <= kMaxMaxReschedules; n++)
                    DropdownMenuItem(value: n, child: Text(l.policyMaxReschedulesValue(n))),
                ],
                onChanged: (val) => setState(() => _maxReschedules = val ?? _maxReschedules),
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
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
