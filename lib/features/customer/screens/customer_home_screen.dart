import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/persona_switcher.dart';
import '../../shared/widgets/ui_kit.dart';
import 'barbershop_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenBarbers;

  const CustomerHomeScreen({super.key, this.onOpenBarbers});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _searchQuery = '';
  String _selectedCity = 'All';
  String _selectedCategory = 'all';

  /// Sub-city filter chips ('All' + the sub-cities of the listed shops).
  List<String> _cities = const ['All'];
  static const List<String> _categories = ['all', 'fades', 'beard', 'shave', 'kids'];

  String _categoryLabel(String id) {
    final l = context.l10n;
    switch (id) {
      case 'fades':
        return l.catFades;
      case 'beard':
        return l.catBeard;
      case 'shave':
        return l.catShave;
      case 'kids':
        return l.catKids;
      default:
        return l.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allShops = repo.getShops();
    _cities = [
      'All',
      ...{
        for (final s in allShops)
          if (s.subCity.isNotEmpty) s.subCity
      }
    ];

    final filteredShops = allShops.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.subCity.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.landmark ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.address.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCity = _selectedCity == 'All' || s.subCity == _selectedCity;

      return matchesSearch && matchesCity;
    }).toList();

    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.brandUpper,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 17,
                  ),
            ),
            Row(
              children: [
                Icon(Icons.location_on, size: 13, color: AppTheme.green),
                SizedBox(width: 4),
                Text(
                  l.cityAddisAbaba,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (kDemoMode)
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.blueSoft,
                shape: const StadiumBorder(),
              ),
              onPressed: () => showPersonaSwitcher(context, current: UserRole.customer),
              icon: const Icon(Icons.swap_horiz, size: 16, color: AppTheme.blue),
              label: Text(
                l.roleCustomer,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.blue),
              ),
            ),
          const LanguageToggle(),
          const NotificationBell(),
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () => repo.signOut(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search Header & Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: l.searchShopsHint,
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Promotional Feature Banner: Find Master Barbers
                  HeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(child: HeroChip(label: l.premierTalent, icon: Icons.workspace_premium_outlined)),
                            const SizedBox(width: 12),
                            const Spacer(),
                            Container(
                              width: 44,
                              height: 44,
                              decoration:
                                  const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
                              child: const Icon(Icons.content_cut, color: AppTheme.ink, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l.bookWithMasters,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onInk,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.bookWithMastersSubtitle,
                          style: const TextStyle(fontSize: 13, color: AppTheme.onInkMuted, height: 1.35),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.ink,
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                          icon: const Icon(Icons.content_cut, size: 16),
                          label:
                              Text(l.findBarbers, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          onPressed: widget.onOpenBarbers,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // City Filter Chips
                  Row(
                    children: [
                      Text(
                        l.subCityFilterLabel,
                        style:
                            const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _cities.map((city) {
                              final isSelected = _selectedCity == city;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(city == 'All' ? l.all : l.placeName(city)),
                                  selected: isSelected,
                                  selectedColor: AppTheme.ink,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppTheme.onInk : AppTheme.textPrimary,
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedCity = city);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Service Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(_categoryLabel(cat)),
                            selected: isSelected,
                            selectedColor: AppTheme.ink,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.onInk : AppTheme.textPrimary,
                            ),
                            onSelected: (val) {
                              setState(() => _selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l.featuredBarbershops(filteredShops.length),
                          style:
                              const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCity == 'All' ? l.allLocations : l.placeName(_selectedCity),
                        style:
                            const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Shop Cards List
          if (filteredShops.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.storefront, size: 54, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        l.noShopsMatching(_searchQuery),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final shop = filteredShops[index];
                    return _buildShopCard(context, shop, repo);
                  },
                  childCount: filteredShops.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: FloatingPillNavBar.contentPadding)),
        ],
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, Barbershop shop, AppRepository repo) {
    final services = repo.getServicesForShop(shop.id);
    final barbers = repo.getBarbersForShop(shop.id);
    final isFav = repo.isShopFavorite(shop.id);
    final l = context.l10n;
    final fmt = context.fmt;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BarbershopDetailScreen(shop: shop),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Cover Image
            Stack(
              children: [
                Image.network(
                  shop.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: AppTheme.surface,
                    child: const Center(
                      child: Icon(Icons.storefront, size: 48, color: AppTheme.ink),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: AppTheme.orange),
                        const SizedBox(width: 4),
                        Text(
                          shop.reviewCount == 0
                              ? context.l10n.reviewsNew
                              : '${shop.rating.toStringAsFixed(1)} (${shop.reviewCount})',
                          style:
                              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      if (shop.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(l.verifiedBadge,
                                  style:
                                      const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.ink.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_city, size: 12, color: AppTheme.onInk),
                        const SizedBox(width: 4),
                        Text(
                          l.shopArea(shop),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Shop Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style:
                              const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppTheme.danger : AppTheme.textSecondary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => repo.toggleFavoriteShop(shop.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          context.l10n.shopAddress(shop),
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            fmt.hoursRange(shop.openingHour, shop.closingHour),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 14, color: AppTheme.success),
                          const SizedBox(width: 3),
                          Text(
                            l.barbersCount(barbers.length),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.content_cut, size: 13, color: AppTheme.blue),
                          const SizedBox(width: 3),
                          Text(
                            l.servicesCount(services.length),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BarbershopDetailScreen(shop: shop),
                          ),
                        );
                      },
                      child: Text(l.viewServicesAndBook),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
