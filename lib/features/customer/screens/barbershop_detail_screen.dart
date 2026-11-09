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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Cover App Bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.shop.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.shop.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: AppTheme.darkSurface),
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

          // Shop Info Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.shop.rating} (${widget.shop.reviewCount} reviews)',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: AppTheme.primaryGold),
                            const SizedBox(width: 4),
                            Text(
                              'Open Today: ${widget.shop.openingHour}:00 AM - ${widget.shop.closingHour - 12}:00 PM',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.shop.description,
                    style: const TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppTheme.primaryGold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.shop.address}, ${widget.shop.city}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        ),
                      ),
                    ],
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
                                Text(
                                  '★ ${barber.rating}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.primaryGold),
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
