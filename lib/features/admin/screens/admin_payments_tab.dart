import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/admin_payments_summary.dart';
import '../../../services/app_repository.dart';
import '../../../services/payment_service.dart' show subscriptionDaysLeft;
import '../../payments/receipts/admin_pricing_screen.dart';
import '../../payments/receipts/admin_receipts_screen.dart';
import '../../payments/receipts/receipts_l10n.dart';
import '../../payments/receipts/subscription_receipts_service.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../refunds/refunds_dashboard_entries.dart' show AdminRefundsCard; // refunds
import 'admin_payment_review_screen.dart';
import 'admin_subscriptions_screen.dart';

/// Admin dashboard "Payments" tab: this month's subscription income, the
/// receipts waiting for a decision, the subscription types on sale (with a
/// link to edit them), shops whose subscription ends soon, and the latest
/// payments. Every control opens the existing screen that does the work.
class AdminPaymentsTab extends StatelessWidget {
  const AdminPaymentsTab({super.key, this.service, this.clock});

  /// Overrides the receipts service (tests).
  final SubscriptionReceiptsService? service;

  /// Overrides the clock (tests).
  final DateTime Function()? clock;

  /// How many decided receipts to load for the month figures.
  static const int decidedLimit = 200;

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final svc = service ?? SubscriptionReceiptsService.instance;
    final repo = AppRepository.instance;
    return StreamBuilder<List<SubscriptionPayment>>(
      stream: svc.watchForAdmin(decidedLimit: decidedLimit),
      builder: (context, paySnap) {
        return StreamBuilder<SubscriptionPricing>(
          stream: svc.watchPricing(),
          builder: (context, priceSnap) {
            return ListenableBuilder(
              listenable: repo,
              builder: (context, _) {
                final l = context.l10n;
                if (paySnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.receiptsErrorText(paySnap.error!), textAlign: TextAlign.center),
                    ),
                  );
                }
                final payments = paySnap.data ?? const <SubscriptionPayment>[];
                final now = (clock ?? () => DateTime.now().toUtc())();
                final summary = summarizeAdminPayments(payments: payments, shops: repo.getShops(), nowUtc: now);
                final pricing = priceSnap.data ?? SubscriptionPricing.defaults;
                return ListView(
                  key: const ValueKey('admin-payments-tab'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _incomeHero(context, summary, loading: !paySnap.hasData),
                    const SizedBox(height: 12),
                    _shopStatusRow(context, summary),
                    const SizedBox(height: 20),
                    SectionHeader(title: l.admPayManage),
                    const SizedBox(height: 10),
                    _actionCard(
                      context,
                      key: const ValueKey('admin-pay-open-receipts'),
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.success,
                      title: l.rcptAdminTitle,
                      subtitle: summary.pendingCount == 0
                          ? l.admPayNoPending
                          : l.admPayPendingCount(summary.pendingCount),
                      badge: summary.pendingCount,
                      onTap: () => _open(context, const AdminReceiptsScreen()),
                    ),
                    _actionCard(
                      context,
                      key: const ValueKey('admin-pay-open-pricing'),
                      icon: Icons.price_change_outlined,
                      color: AppTheme.blue,
                      title: l.admPayTypesTitle,
                      subtitle: l.admPayTypesSubtitle,
                      onTap: () => _open(context, const AdminPricingScreen()),
                    ),
                    _actionCard(
                      context,
                      key: const ValueKey('admin-pay-open-subscriptions'),
                      icon: Icons.workspace_premium_rounded,
                      color: AppTheme.purple,
                      title: l.subscriptionsAndPlansTooltip,
                      subtitle: l.admPaySubscriptionsSubtitle,
                      onTap: () => _open(context, const AdminSubscriptionsScreen()),
                    ),
                    _actionCard(
                      context,
                      key: const ValueKey('admin-pay-open-online'),
                      icon: Icons.credit_card_rounded,
                      color: AppTheme.orange,
                      title: l.admPayOnlineTitle,
                      subtitle: l.admPayOnlineSubtitle,
                      onTap: () => _open(context, const AdminPaymentReviewScreen()),
                    ),
                    // --- refunds: paid bookings that were cancelled, every shop ---
                    const AdminRefundsCard(),
                    const SizedBox(height: 12),
                    SectionHeader(
                      title: l.admPayTypesOnSale,
                      actionLabel: l.admPayEdit,
                      onAction: () => _open(context, const AdminPricingScreen()),
                    ),
                    const SizedBox(height: 10),
                    _tiersCard(context, pricing),
                    if (summary.expiringSoon.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SectionHeader(title: l.admPayExpiringTitle(summary.expiringSoon.length)),
                      const SizedBox(height: 10),
                      _expiringCard(context, summary, now),
                    ],
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: l.admPayRecentTitle,
                      actionLabel: payments.isEmpty ? null : l.admPaySeeAll,
                      onAction: payments.isEmpty ? null : () => _open(context, const AdminReceiptsScreen()),
                    ),
                    const SizedBox(height: 10),
                    if (!paySnap.hasData)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (payments.isEmpty)
                      AppCard(child: Text(l.admPayNoPayments, style: const TextStyle(color: AppTheme.textSecondary)))
                    else
                      ...payments.take(10).map((p) => _paymentRow(context, p)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _incomeHero(BuildContext context, AdminPaymentsSummary s, {required bool loading}) {
    final l = context.l10n;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.admPayIncomeLabel,
                    style: const TextStyle(color: AppTheme.onInkMuted, fontWeight: FontWeight.w600)),
              ),
              HeroChip(icon: Icons.calendar_month_rounded, label: l.admPayThisMonth),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              loading ? '—' : context.fmt.birr(s.monthIncome),
              key: const ValueKey('admin-pay-income'),
              style: const TextStyle(color: AppTheme.onInk, fontSize: 34, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: l.admPayVerifiedCount(s.monthVerifiedCount),
                color: AppTheme.success,
                background: AppTheme.greenSoft,
                icon: Icons.verified_rounded,
              ),
              StatusChip(
                label: l.admPayPendingCount(s.pendingCount),
                color: AppTheme.warning,
                background: AppTheme.orangeSoft,
                icon: Icons.hourglass_top_rounded,
              ),
              StatusChip(
                label: l.admPayRejectedCount(s.monthRejectedCount),
                color: AppTheme.danger,
                background: AppTheme.redSoft,
                icon: Icons.cancel_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shopStatusRow(BuildContext context, AdminPaymentsSummary s) {
    final l = context.l10n;
    Widget tile(String label, int value, Color color) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile(l.admPayShopsActive, s.activeShops, AppTheme.success),
        const SizedBox(width: 8),
        tile(l.admPayShopsTrial, s.trialShops, AppTheme.blue),
        const SizedBox(width: 8),
        tile(l.admPayShopsPastDue, s.pastDueShops, AppTheme.warning),
        const SizedBox(width: 8),
        tile(l.admPayShopsSuspended, s.suspendedShops, AppTheme.danger),
      ],
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return AppCard(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Row(
        children: [
          IconTile(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          if (badge > 0)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(20)),
              child: Text('$badge',
                  style: const TextStyle(color: AppTheme.onInk, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
        ],
      ),
    );
  }

  Widget _tiersCard(BuildContext context, SubscriptionPricing pricing) {
    final l = context.l10n;
    final receiversReady = pricing.telebirr.isConfigured || pricing.cbe.isConfigured;
    return AppCard(
      key: const ValueKey('admin-pay-tiers'),
      onTap: () => _open(context, const AdminPricingScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in pricing.tiers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 18, color: AppTheme.purple),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.rcptDays(t.days), style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(context.fmt.birr(t.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          if (!receiversReady) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.admPayReceiversMissing,
                      style: const TextStyle(color: AppTheme.warning, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _expiringCard(BuildContext context, AdminPaymentsSummary s, DateTime now) {
    final l = context.l10n;
    return AppCard(
      child: Column(
        children: [
          for (final shop in s.expiringSoon.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(shop.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  StatusChip(
                    label: l.admPayDaysLeft(subscriptionDaysLeft(shop.subscriptionEndsAt, now) ?? 0),
                    color: AppTheme.warning,
                    background: AppTheme.orangeSoft,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentRow(BuildContext context, SubscriptionPayment p) {
    final l = context.l10n;
    final shop = AppRepository.instance.getShopById(p.shopId);
    final color = receiptStatusColor(p.status);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _open(context, const AdminReceiptsScreen()),
      child: Row(
        children: [
          IconTile(icon: receiptMethodIcon(p.method), color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop?.name ?? p.shopId,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${l.receiptMethodLabel(p.method, short: true)} · ${p.transactionId} · '
                  '${context.fmt.addisDateMedium(p.decidedAt ?? p.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.fmt.birr(p.verifiedAmount ?? p.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  StatusChip(
                    label: l.receiptStatusLabel(p.status),
                    color: color,
                    icon: receiptStatusIcon(p.status),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
