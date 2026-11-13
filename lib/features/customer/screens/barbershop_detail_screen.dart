import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../reviews/reviews_l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../models/barber_model.dart';
import '../../../services/app_repository.dart';
import 'booking_flow_screen.dart';
import '../../queue/queue_status_card.dart';
import '../../reviews/widgets/shop_reviews_section.dart';

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
    final l = context.l10n;
    final fmt = context.fmt;
    final shopDays = (widget.shop.workingDays.toList()..sort()).map(fmt.weekdayName).join(', ');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Cover App Bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            // Image header: dark bar (collapsed) with white text/icons.
            backgroundColor: AppTheme.ink,
            foregroundColor: AppTheme.onInk,
            iconTheme: const IconThemeData(color: AppTheme.onInk),
            actionsIconTheme: const IconThemeData(color: AppTheme.onInk),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
            clipBehavior: Clip.antiAlias,
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? AppTheme.danger : Colors.white,
                ),
                onPressed: () => repo.toggleFavoriteShop(widget.shop.id),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.shop.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onInk,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.shop.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surface),
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
                            color: AppTheme.greenSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified, size: 12, color: AppTheme.success),
                              const SizedBox(width: 4),
                              Text(l.verifiedPartnerBadge,
                                  style: const TextStyle(
                                      fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.success)),
                            ],
                          ),
                        ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, color: AppTheme.orange, size: 20),
                      const SizedBox(width: 4),
                      Flexible(
                        flex: 3,
                        child: Text(
                          l.reviewsRatingShort(widget.shop.rating, widget.shop.reviewCount),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
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
                    decoration: AppTheme.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const IconTile(icon: Icons.location_on_outlined, color: AppTheme.green, size: 38),
                            const SizedBox(width: 10),
                            Text(
                              l.locationAndHours,
                              style: const TextStyle(
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
                                l.shopAddress(widget.shop),
                                style: const TextStyle(
                                    fontSize: 13.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (widget.shop.landmark != null && widget.shop.landmark!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 15, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.shop.landmark!,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 15, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.hoursWithDays(
                                    fmt.hoursRange(widget.shop.openingHour, widget.shop.closingHour), shopDays),
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
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
                                formatEthiopianContactPhone(widget.shop.phone),
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  QueueStatusCard(shop: widget.shop),
                  const Divider(height: 32, color: AppTheme.hairline),

                  // Barbers Team Section
                  Text(
                    l.ourMasterBarbers(barbers.length),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 116,
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
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(AppTheme.radiusPanel + 2),
                              border: Border.all(
                                color: isSelected ? AppTheme.ink : AppTheme.hairline,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                                  onBackgroundImageError: barber.avatarUrl != null ? (error, stackTrace) {} : null,
                                  backgroundColor: AppTheme.surface,
                                  child: barber.avatarUrl == null
                                      ? Text(barber.name.substring(0, 1),
                                          style:
                                              const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700))
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  barber.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                BarberRatingInline(barber: barber),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 32, color: AppTheme.hairline),

                  // Services Section
                  Text(
                    l.selectAService(services.length),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
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
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard - 2),
                      border: Border.all(
                        color: isSelected ? AppTheme.ink : AppTheme.hairline,
                        width: isSelected ? 1.6 : 1,
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                        title: Text(
                          service.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(service.description,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppTheme.blue),
                                const SizedBox(width: 4),
                                Text(l.minutesShort(service.durationMinutes),
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fmt.birr(service.price),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? AppTheme.green : AppTheme.textTertiary,
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
                    ),
                  );
                },
                childCount: services.length,
              ),
            ),
          ),

          // Ratings & reviews
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: ShopReviewsSection(shop: widget.shop)),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Bottom Bar
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.hairline)),
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -6)),
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
                      _selectedService != null ? _selectedService!.name : l.chooseAService,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _selectedService != null
                          ? '${fmt.birr(_selectedService!.price)} • ${l.minutesShort(_selectedService!.durationMinutes)}'
                          : l.selectToSeePrice,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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
                      SnackBar(content: Text(l.shopHasNoServicesOrBarbers)),
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
                child: Text(l.bookSlot),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
