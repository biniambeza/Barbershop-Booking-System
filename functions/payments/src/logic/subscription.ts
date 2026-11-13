/** Subscription status transitions (pure; used by the scheduled job and admin callable). */
import {
  GRACE_DAYS,
  MAX_MANUAL_MONTHS,
  SUBSCRIPTION_PLANS,
  SUBSCRIPTION_STATUSES,
  SubscriptionPlan,
  SubscriptionStatus,
  TRIAL_DAYS,
} from '../config';
import { addDays, extendSubscriptionEnd, initialTrialEnd, parseIso } from './period';

export interface ShopSubscriptionFields {
  subscriptionPlan?: unknown;
  subscriptionStatus?: unknown;
  subscriptionEndsAt?: unknown;
  createdAt?: unknown;
}

export interface SubscriptionPatch {
  subscriptionPlan?: SubscriptionPlan;
  subscriptionStatus?: SubscriptionStatus;
  subscriptionEndsAt?: string;
}

export function isPlan(v: unknown): v is SubscriptionPlan {
  return typeof v === 'string' && (SUBSCRIPTION_PLANS as readonly string[]).includes(v);
}

export function isStatus(v: unknown): v is SubscriptionStatus {
  return typeof v === 'string' && (SUBSCRIPTION_STATUSES as readonly string[]).includes(v);
}

/** Status a shop should have at `now`, given its end date. Suspended is sticky. */
export function statusForEnd(current: SubscriptionStatus, endsAt: Date, now: Date): SubscriptionStatus {
  if (current === 'suspended') return 'suspended';
  if (now.getTime() < endsAt.getTime()) {
    return current === 'past_due' ? 'active' : current;
  }
  if (now.getTime() >= addDays(endsAt, GRACE_DAYS).getTime()) return 'suspended';
  return 'past_due';
}

/**
 * What the daily job should write for one shop, or null for no change.
 * - no subscription fields: start a trial (TRIAL_DAYS)
 * - trialing/active at or past the end: past_due
 * - GRACE_DAYS or more past the end: suspended
 * - past_due whose end was moved into the future: active
 * - suspended: never changed here (only a payment or an admin lifts it)
 * Shops with a status but an unreadable end date are left alone (null).
 */
export function computeScheduledUpdate(shop: ShopSubscriptionFields, now: Date): SubscriptionPatch | null {
  const hasStatus = shop.subscriptionStatus !== undefined && shop.subscriptionStatus !== null;
  const endsAt = parseIso(shop.subscriptionEndsAt);

  if (!hasStatus && !endsAt) {
    return {
      subscriptionPlan: 'trial',
      subscriptionStatus: 'trialing',
      subscriptionEndsAt: initialTrialEnd(shop.createdAt, now, TRIAL_DAYS).toISOString(),
    };
  }
  if (!isStatus(shop.subscriptionStatus) || !endsAt) return null;

  const next = statusForEnd(shop.subscriptionStatus, endsAt, now);
  const patch: SubscriptionPatch = {};
  if (next !== shop.subscriptionStatus) patch.subscriptionStatus = next;
  if (!isPlan(shop.subscriptionPlan)) patch.subscriptionPlan = 'trial';
  return Object.keys(patch).length ? patch : null;
}

/** Patch written when a subscription payment is verified as paid. */
export function paidSubscriptionPatch(
  plan: SubscriptionPlan,
  currentEnd: unknown,
  now: Date,
  months = 1,
): Required<SubscriptionPatch> {
  return {
    subscriptionPlan: plan,
    subscriptionStatus: 'active',
    subscriptionEndsAt: extendSubscriptionEnd(currentEnd, now, months).toISOString(),
  };
}

export interface ManualChangeInput {
  plan?: unknown;
  status?: unknown;
  endsAt?: unknown;
  months?: unknown;
}

/** Validates an admin change; returns the patch or an error message. */
export function buildManualChange(
  input: ManualChangeInput,
  current: ShopSubscriptionFields,
  now: Date,
): { patch: SubscriptionPatch } | { error: string } {
  const patch: SubscriptionPatch = {};
  if (input.plan !== undefined && input.plan !== null) {
    if (!isPlan(input.plan)) return { error: `plan must be one of ${SUBSCRIPTION_PLANS.join(', ')}` };
    patch.subscriptionPlan = input.plan;
  }
  if (input.status !== undefined && input.status !== null) {
    if (!isStatus(input.status)) return { error: `status must be one of ${SUBSCRIPTION_STATUSES.join(', ')}` };
    patch.subscriptionStatus = input.status;
  }
  const hasEnds = input.endsAt !== undefined && input.endsAt !== null;
  const hasMonths = input.months !== undefined && input.months !== null;
  if (hasEnds && hasMonths) return { error: 'Pass endsAt or months, not both' };
  if (hasEnds) {
    const d = parseIso(input.endsAt);
    if (!d) return { error: 'endsAt must be an ISO-8601 date' };
    patch.subscriptionEndsAt = d.toISOString();
  }
  if (hasMonths) {
    const m = input.months;
    if (typeof m !== 'number' || !Number.isInteger(m) || m < 1 || m > MAX_MANUAL_MONTHS) {
      return { error: `months must be an integer from 1 to ${MAX_MANUAL_MONTHS}` };
    }
    patch.subscriptionEndsAt = extendSubscriptionEnd(current.subscriptionEndsAt, now, m).toISOString();
    if (patch.subscriptionStatus === undefined) patch.subscriptionStatus = 'active';
  }
  if (Object.keys(patch).length === 0) return { error: 'Nothing to change' };
  return { patch };
}
