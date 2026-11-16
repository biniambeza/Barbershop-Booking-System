import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../../services/reviews_service.dart';
import '../reviews_l10n.dart';

/// Read-only stars for a (possibly fractional) rating.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.reviewsRatedSemantics(rating.toStringAsFixed(1)),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                rating >= i
                    ? Icons.star_rounded
                    : rating >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                size: size,
                color: AppTheme.orange,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable 1..5 stars (keys `rate-star-1` .. `rate-star-5`).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 40});

  /// 0 = nothing chosen yet.
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            key: ValueKey('rate-star-$i'),
            tooltip: l.reviewsStarsLabel(i),
            iconSize: size,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(),
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? AppTheme.orange : AppTheme.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// "★ 4.8 (12)", or a "New" tag when nobody has rated yet.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.summary, this.fontSize = 11, this.showCount = true});

  final RatingSummary summary;
  final double fontSize;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (summary.count == 0) {
      return Text(
        l.reviewsNew,
        style: TextStyle(fontSize: fontSize, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
      );
    }
    return Semantics(
      label: l.reviewsSummaryText(summary),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: fontSize + 2, color: AppTheme.orange),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                showCount ? '${summary.rating.toStringAsFixed(1)} (${summary.count})' : summary.rating.toStringAsFixed(1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize, color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shop rating (average of its rated barbers' averages, from the
/// loaded barbers): "★ 4.6 · 3 barbers rated", or "New". Rebuilds when the
/// repository changes (e.g. a barber's counters after a new review).
class ShopRatingBadge extends StatelessWidget {
  const ShopRatingBadge({super.key, required this.shopId, this.fontSize = 12, this.color});

  final String shopId;
  final double fontSize;

  /// Defaults to AppTheme.textPrimary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final rating = repo.shopRatingOf(shopId);
        final text = context.l10n.shopRatingText(rating);
        return Row(
          key: ValueKey('shop-rating-$shopId'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!rating.isNew) ...[
              Icon(Icons.star_rounded, size: fontSize + 3, color: AppTheme.orange),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: rating.isNew ? AppTheme.textSecondary : (color ?? AppTheme.textPrimary),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Big average, stars, count, and one bar per star (5 down to 1).
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({super.key, required this.summary, this.distribution, this.caption});

  final RatingSummary summary;

  /// Extra line under the count (the shop card: "3 barbers rated").
  final String? caption;

  /// Null while loading (bars are hidden).
  final RatingDistribution? distribution;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dist = distribution;
    return Container(
      key: const ValueKey('rating-summary'),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.count == 0 ? '–' : summary.rating.toStringAsFixed(1),
                key: const ValueKey('rating-average'),
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.8),
              ),
              StarRatingDisplay(rating: summary.rating, size: 15),
              const SizedBox(height: 4),
              Text(
                l.reviewsCountLabel(summary.count),
                key: const ValueKey('rating-count'),
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              if (caption != null)
                Text(
                  caption!,
                  key: const ValueKey('rating-caption'),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$star', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ),
                        Icon(Icons.star_rounded, size: 11, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              key: ValueKey('rating-bar-$star'),
                              value: dist?.fraction(star) ?? 0,
                              minHeight: 6,
                              backgroundColor: AppTheme.track,
                              valueColor: AlwaysStoppedAnimation(AppTheme.green),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 22,
                          child: Text(
                            dist == null ? '' : '${dist.counts[star]}',
                            key: ValueKey('rating-bar-count-$star'),
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One review: name, stars, date, comment and the shop's reply. [onReply]
/// (owner) shows a Reply / Edit reply button.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.barberName, this.onReply, this.showAwaitingReply = false});

  final Review review;

  /// Shown under the name when given (shop-wide lists).
  final String? barberName;
  final VoidCallback? onReply;

  /// Owner view: marks reviews that have no reply yet.
  final bool showAwaitingReply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final name = review.isFormerCustomer // account deletion
        ? l.formerCustomer
        : (review.displayName.isEmpty ? l.reviewsCustomer : review.displayName);
    return Container(
      key: ValueKey('review-${review.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.surface,
                child: Text(
                  name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                    if (barberName != null && barberName!.isNotEmpty)
                      Text(
                        l.barberLabel(barberName!),
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StarRatingDisplay(rating: review.rating.toDouble(), size: 14),
                  const SizedBox(height: 2),
                  Text(
                    review.isEdited
                        ? '${fmt.addisDateMedium(review.createdAt)} · ${l.reviewsEdited}'
                        : fmt.addisDateMedium(review.createdAt),
                    key: ValueKey('review-date-${review.id}'),
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          if (review.hasComment) ...[
            const SizedBox(height: 10),
            Text(review.comment!, style: TextStyle(fontSize: 13.5, height: 1.4, color: AppTheme.textPrimary)),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: 10),
            Container(
              key: ValueKey('review-reply-${review.id}'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: AppTheme.ink, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.reviewsOwnerReply,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(review.reply!, style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ] else if (showAwaitingReply) ...[
            const SizedBox(height: 8),
            Text(
              l.reviewsAwaitingReply,
              style: TextStyle(fontSize: 11.5, color: AppTheme.warning),
            ),
          ],
          if (onReply != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('reply-review-${review.id}'),
                onPressed: onReply,
                icon: Icon(review.hasReply ? Icons.edit_outlined : Icons.reply_rounded, size: 16),
                label: Text(review.hasReply ? l.reviewsEditReply : l.reviewsReplyAction),
              ),
            ),
        ],
      ),
    );
  }
}
