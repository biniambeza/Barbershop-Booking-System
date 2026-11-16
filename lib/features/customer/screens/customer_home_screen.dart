import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/addis_locations.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../applications/widgets/shop_application_entries.dart'; // shop applications
import '../../notifications/widgets/notification_bell.dart';
import '../../reviews/widgets/rate_prompt_banner.dart';
import '../../reviews/widgets/review_widgets.dart';
import '../../shared/widgets/app_bar_menu.dart';
import '../../shared/widgets/ui_kit.dart';
import 'barbershop_detail_screen.dart';
import '../widgets/rebook_widgets.dart' show YourBarbersSection; // favourite barbers & rebook
// shop location (maps): landmark on the cards, "Near me" sort.
import '../../../services/device_location.dart';
import '../../../services/shop_maps.dart';
import '../widgets/shop_location_block.dart';

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

  // --- shop location (maps): "Near me" ---
  /// The customer's position while "Near me" is on (shops sorted by
  /// distance, nearest first; shops without a pin come last).
  (double, double)? _nearMe;
  bool _locating = false;

  Future<void> _toggleNearMe() async {
    if (_nearMe != null) {
      setState(() => _nearMe = null);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    setState(() => _locating = true);
    final result = await DeviceLocator.instance.currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.isOk) _nearMe = (result.latitude!, result.longitude!);
    });
    if (!result.isOk) {
      final text = result.status == DeviceLocationStatus.serviceDisabled ? l.locationServiceOff : l.nearMeNeedsLocation;
      messenger?.showSnackBar(SnackBar(
        content: Text(text),
        action: result.status == DeviceLocationStatus.deniedForever
            ? SnackBarAction(label: l.openSettingsAction, onPressed: () => DeviceLocator.instance.openSettings())
            : null,
      ));
    }
  }
  // --- end "Near me" ---

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
    // Sub-city dropdown: 'All', the Addis sub-cities in their usual order,
    // then any other sub-city a listed shop uses. Each shows its shop count.
    final shopsPerCity = <String, int>{};
    for (final s in allShops) {
      if (s.subCity.isNotEmpty) shopsPerCity[s.subCity] = (shopsPerCity[s.subCity] ?? 0) + 1;
    }
    final cities = [
      'All',
      ...{...kAddisSubCities, ...shopsPerCity.keys, if (_selectedCity != 'All') _selectedCity},
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
    // shop location (maps): nearest first while "Near me" is on.
    final nearMe = _nearMe;
    final shownShops = nearMe == null
        ? filteredShops
        : sortByDistance<Barbershop>(
            filteredShops, nearMe.$1, nearMe.$2, (s) => s.hasLocation ? (s.latitude!, s.longitude!) : null);

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
        // --- compact header: secondary actions live in AppBarMenu ---
        actions: const [
          NotificationBell(),
          AppBarMenu(role: UserRole.customer),
          SizedBox(width: 4),
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
                  // "How was your cut?": once, after a completed visit that has no review yet.
                  const RatePromptBanner(),
                  // Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: l.searchShopsHint,
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // favourite barbers & rebook: "Book again with <first name>".
                  const YourBarbersSection(),

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
                                  BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
                              child: Icon(Icons.content_cut, color: AppTheme.ink, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l.bookWithMasters,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onHero,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.bookWithMastersSubtitle,
                          style: TextStyle(fontSize: 13, color: AppTheme.onInkMuted, height: 1.35),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            // White pill on the green hero: fixed deep green
                            // text (AA on white in both modes).
                            backgroundColor: Colors.white,
                            foregroundColor: BrandColors.greenDeep,
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
                  // --- shop applications: "Register your barbershop" ---
                  const ShopApplicationEntryCard(),
                  const SizedBox(height: 18),
                  // Sub-city filter (dropdown)
                  Tooltip(
                    message: l.subCityFilterTooltip,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('subcity-filter'),
                      initialValue: _selectedCity,
                      isExpanded: true,
                      isDense: true,
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: AppTheme.card,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                      decoration: InputDecoration(
                        labelText: l.subCity,
                        isDense: true,
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: AppTheme.green),
                        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        contentPadding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      ),
                      selectedItemBuilder: (context) => [
                        for (final city in cities)
                          Text(
                            city == 'All' ? l.allSubCities : l.placeName(city),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                      items: [
                        for (final city in cities)
                          DropdownMenuItem<String>(
                            key: ValueKey('subcity-option-$city'),
                            value: city,
                            child: Text(
                              city == 'All'
                                  ? l.allSubCities
                                  : l.subCityOptionCount(l.placeName(city), shopsPerCity[city] ?? 0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (city) {
                        if (city != null) setState(() => _selectedCity = city);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Service Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // shop location (maps): sort by distance.
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            key: const ValueKey('near-me-chip'),
                            avatar: _locating
                                ? const SizedBox(
                                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(Icons.near_me_outlined,
                                    size: 15, color: _nearMe != null ? AppTheme.onInk : AppTheme.green),
                            label: Text(l.nearMe),
                            selected: _nearMe != null,
                            showCheckmark: false,
                            selectedColor: AppTheme.ink,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _nearMe != null ? AppTheme.onInk : AppTheme.textPrimary,
                            ),
                            onSelected: _locating ? null : (_) => _toggleNearMe(),
                          ),
                        ),
                        ..._categories.map((cat) {
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
                      }),
                      ],
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
                              TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCity == 'All' ? l.allLocations : l.placeName(_selectedCity),
                        style: TextStyle(fontSize: 12.5, color: AppTheme.success, fontWeight: FontWeight.w600),
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
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(color: AppTheme.greenSoft, shape: BoxShape.circle),
                        child: Icon(Icons.storefront, size: 40, color: AppTheme.success),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.noShopsMatching(_searchQuery),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                    final shop = shownShops[index];
                    return _buildShopCard(context, shop, repo,
                        distanceKm: nearMe != null && shop.hasLocation
                            ? distanceKm(nearMe.$1, nearMe.$2, shop.latitude!, shop.longitude!)
                            : null);
                  },
                  childCount: shownShops.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: FloatingPillNavBar.contentPadding)),
        ],
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, Barbershop shop, AppRepository repo, {double? distanceKm}) {
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
                    child: Center(
                      child: Icon(Icons.storefront, size: 48, color: AppTheme.ink),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 210),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // Average of the rated barbers' averages ("4.6 · 3 barbers rated") or "New".
                    child: ShopRatingBadge(shopId: shop.id),
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
                            color: AppTheme.primaryDeep,
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
                      // Dark glass on the photo in both modes.
                      color: const Color(0xD90A0A0A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_city, size: 12, color: Colors.white),
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
                              TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                  // shop location (maps): the landmark first, then the address.
                  if ((shop.landmark ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ShopLandmarkLine(key: ValueKey('shop-card-landmark-${shop.id}'), landmark: shop.landmark!.trim()),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          context.l10n.shopAddress(shop),
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          formatShopDistance(l, distanceKm),
                          key: ValueKey('shop-card-distance-${shop.id}'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success),
                        ),
                      ],
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
                          Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            fmt.hoursRange(shop.openingHour, shop.closingHour),
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                      // A Wrap, so long (Amharic) labels move to a new line
                      // instead of overflowing on narrow phones.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 14, color: AppTheme.success),
                              const SizedBox(width: 3),
                              Text(
                                l.barbersCount(barbers.length),
                                style: TextStyle(
                                    fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.content_cut, size: 13, color: AppTheme.blue),
                              const SizedBox(width: 3),
                              Text(
                                l.servicesCount(services.length),
                                style: TextStyle(
                                    fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ],
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
