import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/reviews_service.dart';
import '../screens/reviews_screen.dart';
import 'review_widgets.dart';

/// Shop detail page: rating summary with star distribution and the latest
/// reviews, plus "See all reviews" (key `reviews-see-all`) opening the
/// paginated [ReviewsScreen]. Average and count are the shop's live
/// `rating` / `reviewCount`.
class ShopReviewsSection extends StatefulWidget {
  const ShopReviewsSection({super.key, required this.shop, this.service, this.latestCount = 3});

  final Barbershop shop;
  final ReviewsService? service;

  /// Reviews shown inline.
  final int latestCount;

  @override
  State<ShopReviewsSection> createState() => _ShopReviewsSectionState();
}

class _ShopReviewsSectionState extends State<ShopReviewsSection> {
  late Future<(RatingDistribution, ReviewPage)> _load;

  ReviewsService get _service => widget.service ?? ReviewsService.instance;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<(RatingDistribution, ReviewPage)> _fetch() async {
    final results = await Future.wait<Object>([
      _service.loadDistribution(widget.shop.id),
      _service.loadPage(widget.shop.id, limit: widget.latestCount),
    ]);
    return (results[0] as RatingDistribution, results[1] as ReviewPage);
  }

  Future<void> _openAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewsScreen(shopId: widget.shop.id, service: widget.service)),
    );
    if (mounted) setState(() => _load = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    return Column(
      key: const ValueKey('shop-reviews-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32, color: AppTheme.hairline),
        Text(
          l.reviewsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<(RatingDistribution, ReviewPage)>(
          future: _load,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return ListenableBuilder(
              listenable: repo,
              builder: (context, _) {
                final summary = _service.shopSummary(widget.shop.id);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RatingSummaryCard(summary: summary, distribution: data?.$1),
                    const SizedBox(height: 12),
                    if (snapshot.hasError)
                      Text(l.reviewsLoadFailed, style: const TextStyle(color: AppTheme.textSecondary))
                    else if (data == null)
                      const Center(
                        child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
                      )
                    else if (data.$2.reviews.isEmpty)
                      Text(
                        l.reviewsEmpty,
                        key: const ValueKey('reviews-empty'),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      )
                    else ...[
                      for (final review in data.$2.reviews)
                        ReviewTile(review: review, barberName: repo.getBarberById(review.barberId)?.name),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('reviews-see-all'),
                          onPressed: _openAll,
                          icon: const Icon(Icons.reviews_outlined, size: 18),
                          label: Text(l.reviewsSeeAll(summary.count)),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Barber card rating on the shop page: "★ 4.8 (12)" or "New".
class BarberRatingInline extends StatelessWidget {
  const BarberRatingInline({super.key, required this.barber});

  final Barber barber;

  @override
  Widget build(BuildContext context) => RatingBadge(
        key: ValueKey('barber-rating-${barber.id}'),
        summary: RatingSummary(rating: barber.rating, count: barber.reviewCount),
      );
}
