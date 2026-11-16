import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../shared/widgets/ui_kit.dart';
import '../portfolio_service.dart';
import '../screens/portfolio_gallery_screen.dart';
import '../screens/portfolio_manage_screen.dart';
import 'portfolio_photo_image.dart';

/// Called when a customer taps "Book this style with ..." for [barber].
typedef BookStyleCallback = void Function(Barber barber);

/// Shop page: "See their work" with one card per barber who has photos
/// ("Abel · 6 photos"). Only counts are fetched here (aggregate queries,
/// no image bytes); a card opens that barber's gallery. Shows nothing when
/// no barber has photos yet.
class ShopPortfolioSection extends StatefulWidget {
  const ShopPortfolioSection({super.key, required this.shopId, required this.barbers, this.onBookStyle, this.service});

  final String shopId;
  final List<Barber> barbers;

  /// Null: no "Book this style" button (e.g. a suspended shop).
  final BookStyleCallback? onBookStyle;
  final PortfolioService? service;

  @override
  State<ShopPortfolioSection> createState() => _ShopPortfolioSectionState();
}

class _ShopPortfolioSectionState extends State<ShopPortfolioSection> {
  PortfolioService get _service => widget.service ?? PortfolioService.instance;
  Map<String, int> _counts = const {};
  String _ids = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(ShopPortfolioSection old) {
    super.didUpdateWidget(old);
    _refresh();
  }

  void _refresh() {
    final ids = widget.barbers.map((b) => b.id).join(',');
    if (ids == _ids) return;
    _ids = ids;
    final barbers = widget.barbers;
    Future.wait(barbers.map((b) => _service.count(widget.shopId, b.id))).then((counts) {
      if (!mounted || ids != _ids) return;
      setState(() => _counts = {for (var i = 0; i < barbers.length; i++) barbers[i].id: counts[i]});
    });
  }

  Future<void> _open(Barber barber) async {
    final book = await openPortfolioGallery(context,
        shopId: widget.shopId, barber: barber, canBook: widget.onBookStyle != null && barber.isAvailable);
    if (book && mounted) widget.onBookStyle?.call(barber);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final l = context.l10n;
        final withPhotos = [
          for (final b in widget.barbers)
            if ((_service.knownCount(widget.shopId, b.id) ?? _counts[b.id] ?? 0) > 0) b,
        ];
        if (withPhotos.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const ValueKey('shop-portfolio-section'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            SectionHeader(title: l.portfolioShopSectionTitle),
            const SizedBox(height: 2),
            Text(l.portfolioShopSectionHint, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: withPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final barber = withPhotos[i];
                  final count = _service.knownCount(widget.shopId, barber.id) ?? _counts[barber.id] ?? 0;
                  return _BarberWorkChip(
                    key: ValueKey('shop-portfolio-${barber.id}'),
                    barber: barber,
                    label: l.portfolioPhotoCount(count),
                    onTap: () => _open(barber),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _BarberWorkChip extends StatelessWidget {
  const _BarberWorkChip({super.key, required this.barber, required this.label, required this.onTap});

  final Barber barber;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        side: BorderSide(color: AppTheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTile(icon: Icons.photo_library_outlined, color: AppTheme.green, size: 40),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(barber.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
                  ),
                  Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Booking flow: "See Abel's work · 6 photos" under the barber picker for
/// the chosen barber (nothing while they have no photos). The gallery's
/// "Book this style" calls [onBookStyle].
class BarberPortfolioLink extends StatefulWidget {
  const BarberPortfolioLink({super.key, required this.shopId, required this.barber, this.onBookStyle, this.service});

  final String shopId;
  final Barber barber;
  final BookStyleCallback? onBookStyle;
  final PortfolioService? service;

  @override
  State<BarberPortfolioLink> createState() => _BarberPortfolioLinkState();
}

class _BarberPortfolioLinkState extends State<BarberPortfolioLink> {
  PortfolioService get _service => widget.service ?? PortfolioService.instance;
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BarberPortfolioLink old) {
    super.didUpdateWidget(old);
    if (old.barber.id != widget.barber.id || old.shopId != widget.shopId) _load();
  }

  void _load() {
    final barberId = widget.barber.id;
    _count = _service.knownCount(widget.shopId, barberId);
    if (_count != null) return;
    _service.count(widget.shopId, barberId).then((n) {
      if (mounted && widget.barber.id == barberId) setState(() => _count = n);
    });
  }

  Future<void> _open() async {
    final barber = widget.barber;
    final book = await openPortfolioGallery(context,
        shopId: widget.shopId, barber: barber, canBook: widget.onBookStyle != null && barber.isAvailable);
    if (book && mounted) widget.onBookStyle?.call(barber);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final count = _service.knownCount(widget.shopId, widget.barber.id) ?? _count ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        final l = context.l10n;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            key: ValueKey('barber-portfolio-link-${widget.barber.id}'),
            onPressed: _open,
            icon: Icon(Icons.photo_library_outlined, size: 18, color: AppTheme.green),
            label: Text('${l.portfolioSeeWork(widget.barber.name)} · ${l.portfolioPhotoCount(count)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
          ),
        );
      },
    );
  }
}

/// Barber dashboard: "My portfolio" (their own photos), with the count
/// and the newest photo. Opens [PortfolioManageScreen].
class BarberPortfolioCard extends StatelessWidget {
  const BarberPortfolioCard({super.key, required this.barber, this.service});

  final Barber barber;
  final PortfolioService? service;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final svc = service ?? PortfolioService.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ListenableBuilder(
        listenable: svc,
        builder: (context, _) {
          final count = svc.knownCount(barber.shopId, barber.id);
          // One aggregate query (no image bytes); notifies when it lands.
          if (count == null) svc.count(barber.shopId, barber.id).ignore();
          final cover = svc.cached(barber.shopId, barber.id)?.firstOrNull;
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PortfolioManageScreen(shopId: barber.shopId, barber: barber, service: service)),
            ),
            child: Row(
              key: const ValueKey('open-my-portfolio'),
              children: [
                if (cover != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: PortfolioPhotoImage(photo: cover, service: service, cacheWidth: 132),
                    ),
                  )
                else
                  IconTile(icon: Icons.photo_library_outlined, color: AppTheme.green, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.portfolioDashboardTitle,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        count == null ? l.portfolioDashboardSubtitle : l.portfolioCountOfMax(count, kMaxPortfolioPhotos),
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Owner's Manage Barbers: "Portfolio" link under a barber.
class ManagePortfolioLink extends StatelessWidget {
  const ManagePortfolioLink({super.key, required this.barber, this.service});

  final Barber barber;
  final PortfolioService? service;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        key: ValueKey('manage-portfolio-${barber.id}'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PortfolioManageScreen(shopId: barber.shopId, barber: barber, service: service)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 14, color: AppTheme.green),
            const SizedBox(width: 4),
            Flexible(
              child: Text(l.portfolioManageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
