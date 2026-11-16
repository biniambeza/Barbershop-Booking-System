/// Trial / subscription expiry computed on the client.
///
/// On the Blaze plan the payments Cloud Functions' daily job
/// (`dailySubscriptionCheck`, see `statusForEnd` / `computeScheduledUpdate`
/// in functions/payments/src/logic/subscription.ts) moves shops along
/// trialing/active -> past_due (at the end of the period) -> suspended
/// ([kSubscriptionGracePeriod] after it). On the free Spark plan nothing
/// runs, so the app derives the *effective* status from the stored status,
/// `subscriptionEndsAt` and the clock, and the owner / admin app persists
/// the downgrade ([subscriptionTransitionPatch]) so other clients and the
/// Firestore rules see it. The writes are idempotent and use the same
/// values as the function, which takes over unchanged on Blaze.
library;

import '../models/barbershop_model.dart';

/// Time after `subscriptionEndsAt` before a lapsed shop is suspended
/// (GRACE_DAYS in functions/payments/src/config.ts; same as
/// `kSubscriptionGraceDays` in payment_service.dart).
const Duration kSubscriptionGracePeriod = Duration(days: 7);

/// Shop field written with a client-side transition: when it happened (ISO
/// 8601 UTC, client clock).
const String kSubscriptionStatusChangedAtField = 'subscriptionStatusChangedAt';

/// The clock [Barbershop.isSuspended] / [Barbershop.isBlocked] read (UTC).
/// The app repository points it at its own clock so tests that fix the
/// repository's time see the same verdict.
DateTime Function() subscriptionClock = _systemClock;

DateTime _systemClock() => DateTime.now().toUtc();

/// The status a shop has at [nowUtc] given its stored [stored] status and
/// period end [endsAt] (same rules as `statusForEnd` in the function):
///  * suspended stays suspended (only a payment or the admin lifts it);
///  * no end date: the stored status;
///  * before the end: the stored status (past_due with an end moved into
///    the future reads as active);
///  * from the end: past_due;
///  * from [kSubscriptionGracePeriod] after the end: suspended.
SubscriptionStatus effectiveStatusFor(SubscriptionStatus stored, DateTime? endsAt, DateTime nowUtc) {
  if (stored == SubscriptionStatus.suspended) return SubscriptionStatus.suspended;
  if (endsAt == null) return stored;
  final now = nowUtc.toUtc();
  final end = endsAt.toUtc();
  if (now.isBefore(end)) return stored == SubscriptionStatus.pastDue ? SubscriptionStatus.active : stored;
  if (!now.isBefore(end.add(kSubscriptionGracePeriod))) return SubscriptionStatus.suspended;
  return SubscriptionStatus.pastDue;
}

/// [effectiveStatusFor] of [shop].
SubscriptionStatus effectiveSubscriptionStatus(Barbershop shop, DateTime nowUtc) =>
    effectiveStatusFor(shop.subscriptionStatus, shop.subscriptionEndsAt, nowUtc);

/// When a lapsed shop is suspended: [kSubscriptionGracePeriod] after its
/// period end. Null without an end date.
DateTime? suspensionDateOf(Barbershop shop) => shop.subscriptionEndsAt?.toUtc().add(kSubscriptionGracePeriod);

/// Whole days (rounded up; 0 on the last day) until the shop is suspended
/// for not paying. Null when it has no end date or is already suspended.
int? daysUntilSuspension(Barbershop shop, DateTime nowUtc) {
  final at = suspensionDateOf(shop);
  if (at == null || effectiveSubscriptionStatus(shop, nowUtc) == SubscriptionStatus.suspended) return null;
  final minutes = at.difference(nowUtc.toUtc()).inMinutes;
  if (minutes <= 0) return 0;
  return (minutes / (60 * 24)).ceil();
}

/// A lapsed free trial: past due, and the shop was on the trial (stored
/// status trialing or plan 'trial').
bool isTrialEnded(Barbershop shop, DateTime nowUtc) =>
    effectiveSubscriptionStatus(shop, nowUtc) == SubscriptionStatus.pastDue &&
    (shop.subscriptionStatus == SubscriptionStatus.trialing || shop.subscriptionPlan == 'trial');

int _rank(SubscriptionStatus s) {
  switch (s) {
    case SubscriptionStatus.trialing:
    case SubscriptionStatus.active:
      return 0;
    case SubscriptionStatus.pastDue:
      return 1;
    case SubscriptionStatus.suspended:
      return 2;
  }
}

/// The only transitions the client persists: trialing/active -> past_due,
/// trialing/active/past_due -> suspended. Never an upgrade.
bool isSubscriptionDowngrade(SubscriptionStatus from, SubscriptionStatus to) => _rank(to) > _rank(from);

/// The update the owner / admin app writes to `barbershops/{id}` when the
/// stored status lags behind the effective one, or null when nothing is to
/// be written: exactly `{subscriptionStatus: 'past_due' | 'suspended',
/// subscriptionStatusChangedAt: nowUtc as ISO 8601}`, only for a downgrade.
Map<String, dynamic>? subscriptionTransitionPatch(Barbershop shop, DateTime nowUtc) {
  final next = effectiveSubscriptionStatus(shop, nowUtc);
  if (!isSubscriptionDowngrade(shop.subscriptionStatus, next)) return null;
  return {
    'subscriptionStatus': next.value,
    kSubscriptionStatusChangedAtField: nowUtc.toUtc().toIso8601String(),
  };
}

extension BarbershopSubscriptionState on Barbershop {
  /// [effectiveSubscriptionStatus] at [nowUtc].
  SubscriptionStatus effectiveStatusAt(DateTime nowUtc) => effectiveSubscriptionStatus(this, nowUtc);

  /// Hidden from customers and closed to new bookings at [nowUtc]: admin
  /// suspended, or suspended for not paying (stored or effective).
  bool isBlockedAt(DateTime nowUtc) =>
      adminSuspended || effectiveSubscriptionStatus(this, nowUtc) == SubscriptionStatus.suspended;
}
