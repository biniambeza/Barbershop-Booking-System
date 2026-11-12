import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../models/barber_model.dart';
import '../../../services/app_repository.dart';
import 'booking_flow_screen.dart';

class BarbershopDetailScreen extends StatefulWidget {
  final Barbershop shop;

  const BarbershopDetailScreen({super.key, required this.shop});

  @override
  State<BarbershopDetailScreen> createState() => _BarbershopDetailScreenState();
}

class _BarbershopDetailScreenState extends State<BarbershopDetailScreen> {
  BarbershopService? _selectedService;
  Barber? _selectedBarber;

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final services = repo.getServicesForShop(widget.shop.id);
    final barbers = repo.getBarbersForShop(widget.shop.id);
    final isFav = repo.isShopFavorite(widget.shop.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Cover App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : Colors.white,
                ),
                onPressed: () => repo.toggleFavoriteShop(widget.shop.id),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.shop.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.shop.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.darkSurface),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification badge & Rating
                  Row(
                    children: [
                      if (widget.shop.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('VERIFIED PARTNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      const Icon(Icons.star, color: AppTheme.primaryGold, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.shop.rating.toStringAsFixed(1)} (${widget.shop.reviewCount} reviews)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    widget.shop.description,
                    style: const TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Location & Contact Card (No Map needed!)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: AppTheme.primaryGold, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Location & Hours',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.storefront, size: 15, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.shop.fullAddress,
                                style: const TextStyle(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 15, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.shop.openingHour}:00 AM - ${widget.shop.closingHour - 12}:00 PM (Mon - Sun)',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        if (widget.shop.phone.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 15, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                widget.shop.phone,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 32, color: AppTheme.accentSlate),

                  // Barbers Team Section
                  Text(
                    'Our Master Barbers (${barbers.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: barbers.length,
                      itemBuilder: (context, index) {
                        final barber = barbers[index];
                        final isSelected = _selectedBarber?.id == barber.id;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedBarber = isSelected ? null : barber;
                            });
                          },
                          child: Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryGold.withValues(alpha: 0.15) : AppTheme.darkCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryGold : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                                  onBackgroundImageError: barber.avatarUrl != null ? (error, stackTrace) {} : null,
                                  backgroundColor: AppTheme.primaryGold,
                                  child: barber.avatarUrl == null
                                      ? Text(barber.name.substring(0, 1), style: const TextStyle(color: Colors.black))
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  barber.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star, size: 12, color: AppTheme.primaryGold),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${barber.rating}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 32, color: AppTheme.accentSlate),

                  // Services Section
                  Text(
                    'Select a Service (${services.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Services List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = services[index];
                  final isSelected = _selectedService?.id == service.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryGold.withValues(alpha: 0.1) : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGold : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(
                        service.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(service.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryGold),
                              const SizedBox(width: 4),
                              Text('${service.durationMinutes} mins', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${service.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? AppTheme.primaryGold : AppTheme.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedService = service;
                        });
                      },
                    ),
                  );
                },
                childCount: services.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Bottom Bar
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedService != null ? _selectedService!.name : 'Choose a service',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _selectedService != null
                          ? '\$${_selectedService!.price.toStringAsFixed(0)} • ${_selectedService!.durationMinutes} mins'
                          : 'Select to see price',
                      style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final serviceToBook = _selectedService ?? (services.isNotEmpty ? services.first : null);
                  final barberToBook = _selectedBarber ?? (barbers.isNotEmpty ? barbers.first : null);

                  if (serviceToBook == null || barberToBook == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This shop does not have active services or barbers.')),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingFlowScreen(
                        shop: widget.shop,
                        initialService: serviceToBook,
                        initialBarber: barberToBook,
                      ),
                    ),
                  );
                },
                child: const Text('Book Slot'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
