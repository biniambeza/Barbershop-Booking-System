// Admin payments dashboard: pure figures from subscription receipts and
// shops (no Flutter, no Firebase), so they can be unit tested.

import '../data/addis_time.dart';
import '../models/barbershop_model.dart';
import '../models/subscription_payment.dart';
import 'subscription_state.dart'; // subscription expiry

/// Shops whose subscription ends within this many days count as expiring.
const int kExpiringSoonDays = 7;

class AdminPaymentsSummary {
  const AdminPaymentsSummary({
    required this.pendingCount,
    required this.monthIncome,
    required this.monthVerifiedCount,
    required this.monthRejectedCount,
    required this.activeShops,
    required this.trialShops,
    required this.pastDueShops,
    required this.suspendedShops,
    required this.expiringSoon,
  });

  /// Receipts waiting for a decision (pending or needs review).
  final int pendingCount;

  /// ETB from receipts verified in the current Addis calendar month.
  final double monthIncome;
  final int monthVerifiedCount;
  final int monthRejectedCount;

  final int activeShops;
  final int trialShops;
  final int pastDueShops;

  /// Subscription-suspended shops (not admin suspensions).
  final int suspendedShops;

  /// Active or trial shops whose subscription ends within
  /// [kExpiringSoonDays], soonest first.
  final List<Barbershop> expiringSoon;
}

/// True when [instantUtc] falls in the same Addis calendar month as [nowUtc].
bool isInAddisMonth(DateTime instantUtc, DateTime nowUtc) {
  final a = toAddisWallClock(instantUtc);
  final n = addisNow(nowUtc);
  return a.year == n.year && a.month == n.month;
}

AdminPaymentsSummary summarizeAdminPayments({
  required List<SubscriptionPayment> payments,
  required List<Barbershop> shops,
  required DateTime nowUtc,
}) {
  var pending = 0, verified = 0, rejected = 0;
  var income = 0.0;
  for (final p in payments) {
    if (p.status.isOpen) {
      pending++;
      continue;
    }
    final decided = p.decidedAt;
    if (decided == null || !isInAddisMonth(decided, nowUtc)) continue;
    if (p.status == ReceiptStatus.verified) {
      verified++;
      income += p.verifiedAmount ?? p.amount;
    } else if (p.status == ReceiptStatus.rejected) {
      rejected++;
    }
  }

  var active = 0, trial = 0, pastDue = 0, suspended = 0;
  final expiring = <Barbershop>[];
  final horizon = nowUtc.toUtc().add(const Duration(days: kExpiringSoonDays));
  for (final s in shops) {
    // subscription expiry: count the effective status (subscription_state.dart).
    final status = effectiveSubscriptionStatus(s, nowUtc);
    switch (status) {
      case SubscriptionStatus.active:
        active++;
      case SubscriptionStatus.trialing:
        trial++;
      case SubscriptionStatus.pastDue:
        pastDue++;
      case SubscriptionStatus.suspended:
        suspended++;
    }
    final ends = s.subscriptionEndsAt;
    // Running: neither stored nor effectively past due / suspended.
    final running = (status == SubscriptionStatus.active || status == SubscriptionStatus.trialing) &&
        (s.subscriptionStatus == SubscriptionStatus.active || s.subscriptionStatus == SubscriptionStatus.trialing);
    if (running && ends != null && ends.isAfter(nowUtc.toUtc()) && !ends.isAfter(horizon)) {
      expiring.add(s);
    }
  }
  expiring.sort((a, b) => a.subscriptionEndsAt!.compareTo(b.subscriptionEndsAt!));

  return AdminPaymentsSummary(
    pendingCount: pending,
    monthIncome: income,
    monthVerifiedCount: verified,
    monthRejectedCount: rejected,
    activeShops: active,
    trialShops: trial,
    pastDueShops: pastDue,
    suspendedShops: suspended,
    expiringSoon: expiring,
  );
}
