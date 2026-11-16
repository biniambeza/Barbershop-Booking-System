import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/payment_service.dart';
import '../../../services/subscription_state.dart'; // subscription expiry

/// Days before the end of a trial/paid period from which owners are warned.
const int kSubscriptionWarningDays = 5;

/// Owner dashboard warning: shown when the subscription is past due or
/// suspended, or when the trial / paid period ends within
/// [kSubscriptionWarningDays]. Renders nothing otherwise.
class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key, required this.shop, this.onManage, this.now});

  final Barbershop shop;
  /// Opens the subscription screen; the button is hidden when null.
  final VoidCallback? onManage;

  /// Overrides the clock (tests).
  final DateTime? now;

  /// The banner text for [shop], or null when no banner is needed.
  /// [l10n] defaults to English.
  static String? messageFor(Barbershop shop, DateTime nowUtc, {AppLocalizations? l10n}) {
    final l = l10n ?? lookupAppLocalizations(const Locale('en'));
    final days = subscriptionDaysLeft(shop.subscriptionEndsAt, nowUtc);
    // subscription expiry: the effective status (a lapsed trial reads as
    // past due, then suspended, even before the stored status catches up).
    final status = effectiveSubscriptionStatus(shop, nowUtc);
    switch (status) {
      case SubscriptionStatus.suspended:
        return l.bannerSuspended;
      case SubscriptionStatus.pastDue:
        final graceLeft = daysUntilSuspension(shop, nowUtc);
        if (isTrialEnded(shop, nowUtc)) {
          if (graceLeft == null) return l.subExpTrialEnded;
          if (graceLeft <= 0) return l.subExpTrialEndedToday;
          return l.subExpTrialEndedInDays(graceLeft);
        }
        if (graceLeft == null) return l.bannerOverdueSoon;
        if (graceLeft <= 0) return l.bannerOverdueToday;
        return l.bannerOverdueInDays(graceLeft);
      case SubscriptionStatus.trialing:
      case SubscriptionStatus.active:
        if (days == null || days > kSubscriptionWarningDays) return null;
        final trial = status == SubscriptionStatus.trialing;
        if (days <= 0) return trial ? l.bannerTrialEndsToday : l.bannerSubEndsToday;
        return trial ? l.bannerTrialEndsIn(days) : l.bannerSubEndsIn(days);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowUtc = (now ?? subscriptionClock()).toUtc();
    final message = messageFor(shop, nowUtc, l10n: context.l10n);
    if (message == null) return const SizedBox.shrink();
    final severe = effectiveSubscriptionStatus(shop, nowUtc) == SubscriptionStatus.suspended;
    final color = severe ? AppTheme.danger : AppTheme.warning;
    return Container(
      key: const ValueKey('subscription-banner'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softOf(color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(severe ? Icons.block_rounded : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          if (onManage != null) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('subscription-banner-action'),
              onPressed: onManage,
              child: Text(severe ? context.l10n.reactivate : context.l10n.payNow),
            ),
          ],
        ],
      ),
    );
  }
}
