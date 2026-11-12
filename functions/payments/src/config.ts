/**
 * Central configuration for the payments codebase. Default plans, trial and
 * grace periods live here so the app, admins and functions agree on them.
 */

export const REGION = 'europe-west1';
export const CHAPA_API_BASE = 'https://api.chapa.co/v1';
export const CURRENCY = 'ETB';

/** Prefix for Chapa tx_ref values: `${TX_REF_PREFIX}${paymentId}`. */
export const TX_REF_PREFIX = 'cb-';

/** Chapa limits customization.title to 16 characters. */
export const CHECKOUT_TITLE = 'Crown and Blade';

/** New shops get this many days of free trial. */
export const TRIAL_DAYS = 30;

/** Days after subscriptionEndsAt before a past_due shop is suspended. */
export const GRACE_DAYS = 7;

/** A pending checkout is reused (instead of a new one) for this long. */
export const PENDING_REUSE_MINUTES = 30;

/** Upper bound for one manual extension by an admin. */
export const MAX_MANUAL_MONTHS = 24;

export type PlanId = 'basic' | 'pro';
export type SubscriptionPlan = 'trial' | PlanId;
export type SubscriptionStatus = 'trialing' | 'active' | 'past_due' | 'suspended';

export const SUBSCRIPTION_PLANS: readonly SubscriptionPlan[] = ['trial', 'basic', 'pro'];
export const SUBSCRIPTION_STATUSES: readonly SubscriptionStatus[] = [
  'trialing',
  'active',
  'past_due',
  'suspended',
];

export interface PlanDoc {
  name: string;
  priceMonthlyEtb: number;
  /** -1 means unlimited. */
  maxBarbers: number;
  features: string[];
  active: boolean;
}

/** Written to plans/{planId} by the seedDefaultPlans callable. */
export const DEFAULT_PLANS: Record<PlanId, PlanDoc> = {
  basic: {
    name: 'Basic',
    priceMonthlyEtb: 500,
    maxBarbers: 3,
    features: ['Online booking', 'Up to 3 barbers', 'SMS reminders'],
    active: true,
  },
  pro: {
    name: 'Pro',
    priceMonthlyEtb: 1200,
    maxBarbers: -1,
    features: ['Online booking', 'Unlimited barbers', 'SMS reminders', 'Online payments (Chapa)', 'Priority listing'],
    active: true,
  },
};
