import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/plan_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/payment_service.dart';
import '../../payments/payment_flow.dart';
import '../../payments/widgets/payment_status_badge.dart';
import '../../payments/widgets/subscription_banner.dart';

/// Owner: current plan and status, the plans on offer (from `plans`), and
/// paying a month with Chapa via createSubscriptionPayment.
class OwnerSubscriptionScreen extends StatefulWidget {
  const OwnerSubscriptionScreen({super.key, required this.shopId, this.service, this.clock});

  final String shopId;
  final PaymentService? service;

  /// Overrides the clock (tests).
  final DateTime Function()? clock;

  @override
  State<OwnerSubscriptionScreen> createState() => _OwnerSubscriptionScreenState();
}

class _OwnerSubscriptionScreenState extends State<OwnerSubscriptionScreen> {
  final _repo = AppRepository.instance;
  late final PaymentService _payments = widget.service ?? PaymentService.instance;
  late final Stream<List<PaymentRecord>> _history = _payments.watchShopPayments(widget.shopId);
  String? _busyPlanId;

  DateTime get _now => (widget.clock?.call() ?? DateTime.now()).toUtc();

  String _date(DateTime utc) => context.fmt.addisDateMedium(utc);

  Future<void> _pay(Barbershop shop, SubscriptionPlan plan) async {
    setState(() => _busyPlanId = plan.id);
    try {
      await payForSubscription(context, shop: shop, plan: plan, service: _payments);
    } finally {
      if (mounted) setState(() => _busyPlanId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final shop = _repo.getShopById(widget.shopId);
        final l = context.l10n;
        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.subscriptionTitle)),
            body: Center(child: Text(l.shopNotLoaded)),
          );
        }
        final barberCount = _repo.getBarbersForShop(shop.id).length;
        final plans = _repo.getPlans().where((p) => p.isPurchasable).toList()
          ..sort((a, b) => a.priceMonthlyEtb.compareTo(b.priceMonthlyEtb));

        return Scaffold(
          appBar: AppBar(title: Text(l.subscriptionTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SubscriptionBanner(shop: shop, now: _now),
              _buildCurrent(shop, barberCount),
              const SizedBox(height: 24),
              Text(l.plansTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                l.plansIntro,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (plans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l.noPlansAvailable),
                ),
              for (final plan in plans) _buildPlan(shop, plan, barberCount),
              const SizedBox(height: 24),
              Text(l.paymentHistory, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildHistory(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrent(Barbershop shop, int barberCount) {
    final plan = _repo.getPlan(shop.subscriptionPlan);
    final days = subscriptionDaysLeft(shop.subscriptionEndsAt, _now);
    final ends = shop.subscriptionEndsAt;
    final l = context.l10n;
    String endText;
    if (ends == null) {
      endText = l.noEndDateSet;
    } else if (days != null && days < 0) {
      endText = l.endedAgo(-days, _date(ends));
    } else {
      final base = shop.subscriptionStatus == SubscriptionStatus.trialing ? l.trialEndsOn(_date(ends)) : l.renewsBy(_date(ends));
      endText = days == null || days == 0 ? l.endsToday(base) : l.daysLeftSuffix(days, base);
    }

    return Container(
      key: const ValueKey('current-subscription'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.planName(shop.subscriptionPlan, plan),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SubscriptionStatusChip(status: shop.subscriptionStatus),
            ],
          ),
          const SizedBox(height: 10),
          Text(endText, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            plan == null
                ? l.barbersUsage(barberCount)
                : plan.isUnlimited
                    ? l.barbersUsageUnlimited(barberCount)
                    : l.barbersUsageOf(barberCount, plan.maxBarbers),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPlan(Barbershop shop, SubscriptionPlan plan, int barberCount) {
    final fits = plan.allowsBarbers(barberCount);
    final isCurrent = shop.subscriptionPlan == plan.id && shop.subscriptionStatus != SubscriptionStatus.trialing;
    final busy = _busyPlanId == plan.id;
    final l = context.l10n;
    return Container(
      key: ValueKey('plan-${plan.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? AppTheme.primaryGold : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.planName(plan.id, plan), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Text(
                l.perMonth(context.fmt.birr(plan.priceMonthlyEtb)),
                style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.barberLimit(plan), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, size: 14, color: AppTheme.primaryGold),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (!fits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.planTooSmall(barberCount, plan.maxBarbers),
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: ValueKey('pay-plan-${plan.id}'),
              onPressed: !fits || _busyPlanId != null ? null : () => _pay(shop, plan),
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.lock_outline_rounded, size: 16),
              label: Text(isCurrent ? l.renewWithChapa : l.payWithChapa),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return StreamBuilder<List<PaymentRecord>>(
      stream: _history,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(context.l10n.paymentHistoryUnavailable, style: const TextStyle(color: AppTheme.textSecondary));
        }
        final items = (snap.data ?? const <PaymentRecord>[]).where((p) => p.type == PaymentType.subscription).toList();
        if (items.isEmpty) {
          return Text(context.l10n.noSubscriptionPayments, style: const TextStyle(color: AppTheme.textSecondary));
        }
        return Column(
          children: [
            for (final p in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: switch (p.status) {
                  PaymentRecordStatus.success => const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  PaymentRecordStatus.failed => const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                  PaymentRecordStatus.refunded => const Icon(Icons.undo_rounded, color: Colors.lightBlueAccent),
                  PaymentRecordStatus.pending => const Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent),
                },
                title: Text('${context.l10n.planName(p.plan ?? '', _repo.getPlan(p.plan ?? ''))} • ${context.fmt.birr(p.amount)}'),
                subtitle: Text(
                  '${_date(p.createdAt)} • ${context.l10n.paymentRecordStatus(p.status)}'
                  '${p.periodEndsAt != null ? ' • ${context.l10n.untilDate(_date(p.periodEndsAt!))}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
