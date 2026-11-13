import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/booking_model.dart';

/// Small pill showing a booking's payment state: Paid, Payment pending,
/// Refunded, Unpaid (online) or Pay at shop (cash).
class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.booking});

  final Booking booking;

  static Color colorFor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppTheme.success;
      case PaymentStatus.pending:
        return AppTheme.warning;
      case PaymentStatus.refunded:
        return AppTheme.blue;
      case PaymentStatus.unpaid:
        return AppTheme.textSecondary;
    }
  }

  static IconData iconFor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Icons.verified_rounded;
      case PaymentStatus.pending:
        return Icons.hourglass_top_rounded;
      case PaymentStatus.refunded:
        return Icons.undo_rounded;
      case PaymentStatus.unpaid:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking.paymentStatus;
    final color = colorFor(status);
    return Container(
      key: ValueKey('payment-badge-${booking.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.softOf(color),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(status), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            context.l10n.paymentStatus(status, method: booking.paymentMethod),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Pill for a shop's subscription status.
class SubscriptionStatusChip extends StatelessWidget {
  const SubscriptionStatusChip({super.key, required this.status});

  final SubscriptionStatus status;

  static Color colorFor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.trialing:
        return AppTheme.blue;
      case SubscriptionStatus.active:
        return AppTheme.success;
      case SubscriptionStatus.pastDue:
        return AppTheme.warning;
      case SubscriptionStatus.suspended:
        return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.softOf(color),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.transparent),
      ),
      child: Text(
        context.l10n.subscriptionStatus(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
