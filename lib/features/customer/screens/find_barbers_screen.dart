import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import 'booking_flow_screen.dart';
import 'barbershop_detail_screen.dart';

class FindBarbersScreen extends StatefulWidget {
  const FindBarbersScreen({super.key});

  @override
  State<FindBarbersScreen> createState() => _FindBarbersScreenState();
}

class _FindBarbersScreenState extends State<FindBarbersScreen> {
  String _searchQuery = '';
  String _selectedSpecialty = 'All';

  final List<String> _specialtyFilters = [
    'All',
    'Skin Fade',
    'Beard Sculpting',
    'Hot Shave',
    'Scissor Cut',
    'Executive Styling',
  ];

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final allBarbersWithShops = repo.getAllBarbersWithShops();

        final filtered = allBarbersWithShops.where((item) {
          final barber = item.barber;
          final shop = item.shop;

          final matchesSearch = _searchQuery.isEmpty ||
              barber.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              barber.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              shop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              shop.city.toLowerCase().contains(_searchQuery.toLowerCase());

          final matchesSpecialty = _selectedSpecialty == 'All' ||
              barber.specialties.any((s) => s.toLowerCase().contains(_selectedSpecialty.toLowerCase())) ||
              barber.title.toLowerCase().contains(_selectedSpecialty.toLowerCase());

          return matchesSearch && matchesSpecialty;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Find Top Barbers', style: TextStyle(fontWeight: FontWeight.bold)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(116),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search by barber name, specialty, or shop...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                        filled: true,
                        fillColor: AppTheme.darkCard,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Specialty Chips
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _specialtyFilters.length,
                      itemBuilder: (context, index) {
                        final specialty = _specialtyFilters[index];
                        final isSelected = specialty == _selectedSpecialty;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(specialty),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryGold,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : AppTheme.textSecondary,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedSpecialty = specialty);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          body: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, size: 56, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No barbers found matching "$_searchQuery"',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildBarberCard(context, item.barber, item.shop, repo);
                  },
                ),
        );
      },
    );
  }

  Widget _buildBarberCard(BuildContext context, Barber barber, Barbershop shop, AppRepository repo) {
    final isFav = repo.isBarberFavorite(barber.id);
    final services = repo.getServicesForShop(shop.id);
    final defaultService = services.isNotEmpty ? services.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                  child: barber.avatarUrl == null ? const Icon(Icons.person, size: 30) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              barber.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.redAccent : AppTheme.textSecondary,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => repo.toggleFavoriteBarber(barber.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        barber.title,
                        style: const TextStyle(fontSize: 13, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppTheme.primaryGold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${barber.rating.toStringAsFixed(1)} (${barber.reviewCount} reviews)',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Shop Affiliation Pill
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarbershopDetailScreen(shop: shop),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, size: 16, color: AppTheme.primaryGold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            shop.fullAddress,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Specialties
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: barber.specialties.map((spec) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    spec,
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // One-tap Book Appointment with this Barber
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  'Book with ${barber.name.split(' ').first}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  if (defaultService == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No services available at this shop yet.')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingFlowScreen(
                        shop: shop,
                        initialBarber: barber,
                        initialService: defaultService,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
