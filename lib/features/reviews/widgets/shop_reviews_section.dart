import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/reviews_service.dart';
import '../reviews_l10n.dart';
import '../screens/reviews_screen.dart';
import 'review_widgets.dart';

/// Opens [barber]'s reviews (the shop's reviews filtered by barberId).
Future<void> openBarberReviews(BuildContext context, Barber barber, {ReviewsService? service}) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewsScreen(
          shopId: barber.shopId,
          barberId: barber.id,
          title: context.l10n.reviewsBarberTitle(barber.name),
          service: service,
        ),
      ),
    );

/// Shop detail page: rating summary with star distribution and the latest
/// reviews, plus "See all reviews" (key `reviews-see-all`) opening the
/// paginated [ReviewsScreen], and one chip per rated barber opening that
/// barber's reviews (keys `barber-reviews-{barberId}`). The average is the
/// shop rating (average of its rated barbers' averages, see
/// lib/services/rating_service.dart) over the barbers' review counts.
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
                final rating = _service.shopRating(widget.shop.id);
                final summary = rating.summary;
                final ratedBarbers = repo
                    .getBarbersForShop(widget.shop.id)
                    .where((b) => b.reviewCount > 0)
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RatingSummaryCard(
                      summary: summary,
                      distribution: data?.$1,
                      caption: rating.isNew ? null : l.ratingBarbersRated(rating.ratedBarbers),
                    ),
                    const SizedBox(height: 12),
                    if (ratedBarbers.isNotEmpty) ...[
                      Text(
                        l.reviewsByBarber,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final b in ratedBarbers)
                            ActionChip(
                              key: ValueKey('barber-reviews-${b.id}'),
                              avatar: const Icon(Icons.star_rounded, size: 16, color: AppTheme.orange),
                              label: Text('${b.name} · ${l.barberRatingText(_service.barberSummary(b.id))}'),
                              tooltip: l.ratingSeeBarberReviews(b.name),
                              onPressed: () => openBarberReviews(context, b, service: widget.service),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
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

/// A barber's own rating on barber cards: "★ 4.8 (12)" or "New"
/// (ratingSum / reviewCount). With [openReviews] a tap opens the barber's
/// reviews (when there are any).
class BarberRatingInline extends StatelessWidget {
  const BarberRatingInline({super.key, required this.barber, this.openReviews = false, this.fontSize = 11});

  final Barber barber;
  final bool openReviews;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final summary = barberRatingSummary(barber);
    final badge = RatingBadge(key: ValueKey('barber-rating-${barber.id}'), summary: summary, fontSize: fontSize);
    if (!openReviews || summary.count == 0) return badge;
    return Tooltip(
      message: context.l10n.ratingSeeBarberReviews(barber.name),
      child: InkWell(
        key: ValueKey('open-barber-reviews-${barber.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => openBarberReviews(context, barber),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: badge),
      ),
    );
  }
}
