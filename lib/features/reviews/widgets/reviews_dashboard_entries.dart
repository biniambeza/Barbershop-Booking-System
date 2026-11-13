import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/reviews_service.dart';
import '../reviews_l10n.dart';
import '../screens/reviews_screen.dart';
import '../../shared/widgets/ui_kit.dart';

/// Owner dashboard: opens the shop's reviews, where the owner replies
/// (key `open-reviews`). Includes its own bottom spacing.
class OwnerReviewsButton extends StatelessWidget {
  const OwnerReviewsButton({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: ListenableBuilder(
          listenable: AppRepository.instance,
          builder: (context, _) {
            final summary = ReviewsService.instance.shopSummary(shopId);
            return OutlinedButton.icon(
              key: const ValueKey('open-reviews'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReviewsScreen(shopId: shopId)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.reviews_outlined, size: 18),
              label: Text(
                summary.count == 0
                    ? l.reviewsOpenButton
                    : '${l.reviewsOpenButton} · ${summary.rating.toStringAsFixed(1)} ★',
                style: const TextStyle(fontSize: 13),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Barber dashboard: their own rating, opening their reviews read-only
/// (key `open-my-reviews`).
class BarberReviewsCard extends StatelessWidget {
  const BarberReviewsCard({super.key, required this.barber});

  final Barber barber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: AppRepository.instance,
      builder: (context, _) {
        final summary = ReviewsService.instance.barberSummary(barber.id);
        return Card(
          key: const ValueKey('open-my-reviews'),
          color: AppTheme.card,
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: const IconTile(icon: Icons.star_outline_rounded, color: AppTheme.orange, size: 44),
            title: Text(l.reviewsMyReviews,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
            subtitle: Text(
              l.reviewsSummaryText(summary),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewsScreen(shopId: barber.shopId, barberId: barber.id, title: l.reviewsMyReviews),
              ),
            ),
          ),
        );
      },
    );
  }
}
