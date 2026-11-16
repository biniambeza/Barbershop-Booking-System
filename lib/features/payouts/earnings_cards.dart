import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barber_model.dart';
import '../../services/app_repository.dart';
import '../shared/widgets/ui_kit.dart';
import 'payouts_l10n.dart';
import 'payouts_manager.dart';
import 'payouts_screen.dart' show PayoutFigureLine;

/// Earnings and totals for any period (this month, last month, a chosen
/// month, this year, all time). The figures come from Firestore aggregate
/// queries (PayoutsManager.loadEarnings), so they are not limited to the
/// ~90 days of bookings the app keeps in memory.

/// Months offered by "Pick a month".
const int kEarningsMonthsShown = 24;

/// The ranges offered, in order.
const List<EarningsRange> kEarningsRanges = [
  EarningsRange.thisMonth,
  EarningsRange.lastMonth,
  EarningsRange.month,
  EarningsRange.thisYear,
  EarningsRange.allTime,
];

extension EarningsL10n on AppLocalizations {
  String earningsRangeLabel(EarningsRange range) {
    switch (range) {
      case EarningsRange.thisMonth:
        return earningsThisMonth;
      case EarningsRange.lastMonth:
        return earningsLastMonth;
      case EarningsRange.month:
        return earningsPickMonth;
      case EarningsRange.thisYear:
        return earningsThisYear;
      case EarningsRange.allTime:
        return earningsAllTime;
    }
  }
}

/// `November 2026`, `2026` or "All completed bookings".
String earningsPeriodLabel(BuildContext context, EarningsPeriod period) {
  if (period.month != null) return payoutMonthLabel(context.fmt, period.month!);
  if (period.year != null) return '${period.year}';
  if (period.isAllTime) return context.l10n.earningsAllTimeNote;
  final first = period.firstDay, last = period.lastDay;
  return first == null || last == null ? '' : '${context.fmt.dateMedium(first)} - ${context.fmt.dateMedium(last)}';
}

/// Shared state of the earnings widgets: the chosen period and its
/// figures. Reloads when the period changes, on [reload], and (without
/// Firebase, where the figures come from the in-memory bookings) whenever
/// the repository changes.
mixin _EarningsLoader<W extends StatefulWidget, T> on State<W> {
  PayoutsManager get manager;

  EarningsRange range = EarningsRange.thisMonth;
  late PayoutMonth pickedMonth = manager.currentMonth();
  late Future<T> future;

  EarningsPeriod get period => EarningsPeriod.of(range, manager.nowUtc(), month: pickedMonth);

  Future<T> fetch(EarningsPeriod period);

  void reload() {
    final next = fetch(period);
    setState(() {
      future = next;
    });
  }

  void _onRepoChanged() {
    if (mounted) reload();
  }

  @override
  void initState() {
    super.initState();
    future = fetch(period);
    if (!manager.usesFirestore) AppRepository.instance.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    AppRepository.instance.removeListener(_onRepoChanged);
    super.dispose();
  }

  void selectRange(EarningsRange r) {
    if (r == range) return;
    range = r;
    reload();
  }

  void selectMonth(PayoutMonth m) {
    if (m == pickedMonth) return;
    pickedMonth = m;
    reload();
  }

  Widget picker(BuildContext context) => EarningsPeriodPicker(
        range: range,
        month: pickedMonth,
        months: PayoutMonth.recent(manager.nowUtc(), kEarningsMonthsShown),
        onRange: selectRange,
        onMonth: selectMonth,
      );
}

/// Range chips, plus a month dropdown when "Pick a month" is selected.
class EarningsPeriodPicker extends StatelessWidget {
  const EarningsPeriodPicker({
    super.key,
    required this.range,
    required this.month,
    required this.months,
    required this.onRange,
    required this.onMonth,
  });

  final EarningsRange range;
  final PayoutMonth month;
  final List<PayoutMonth> months;
  final ValueChanged<EarningsRange> onRange;
  final ValueChanged<PayoutMonth> onMonth;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final items = months.contains(month) ? months : [month, ...months];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in kEarningsRanges)
              ChoiceChip(
                key: ValueKey('earnings-range-${r.name}'),
                label: Text(l.earningsRangeLabel(r)),
                selected: r == range,
                onSelected: (_) => onRange(r),
              ),
          ],
        ),
        if (range == EarningsRange.month) ...[
          const SizedBox(height: 8),
          DropdownButton<PayoutMonth>(
            key: const ValueKey('earnings-month-picker'),
            value: month,
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
            dropdownColor: AppTheme.card,
            items: [
              for (final m in items) DropdownMenuItem(value: m, child: Text(payoutMonthLabel(fmt, m))),
            ],
            onChanged: (m) {
              if (m != null) onMonth(m);
            },
          ),
        ],
      ],
    );
  }
}

Widget _loadFailed(BuildContext context, VoidCallback onRetry) {
  final l = context.l10n;
  return Row(
    key: const ValueKey('earnings-error'),
    children: [
      Expanded(
        child: Text(l.earningsLoadFailed, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
      ),
      TextButton(onPressed: onRetry, child: Text(l.reportsRetry)),
    ],
  );
}

const Widget _loading = Padding(
  padding: EdgeInsets.symmetric(vertical: 16),
  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
);

/// Barber dashboard: the barber's completed jobs, revenue and share for
/// any period (key `barber-earnings-card`).
class BarberEarningsCard extends StatefulWidget {
  const BarberEarningsCard({super.key, required this.barber, this.manager});

  final Barber barber;

  /// Defaults to [PayoutsManager.instance].
  final PayoutsManager? manager;

  @override
  State<BarberEarningsCard> createState() => _BarberEarningsCardState();
}

class _BarberEarningsCardState extends State<BarberEarningsCard>
    with _EarningsLoader<BarberEarningsCard, EarningsTotals> {
  @override
  late final PayoutsManager manager = widget.manager ?? PayoutsManager.instance;

  @override
  Future<EarningsTotals> fetch(EarningsPeriod period) =>
      manager.loadEarnings(widget.barber.shopId, period, barberId: widget.barber.id);

  @override
  void didUpdateWidget(BarberEarningsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barber.id != widget.barber.id || oldWidget.barber.shopId != widget.barber.shopId) {
      future = fetch(period);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final barber = AppRepository.instance.getBarberById(widget.barber.id) ?? widget.barber;
    final percent = commissionOf(barber);
    return AppCard(
      key: const ValueKey('barber-earnings-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.insights_outlined, color: AppTheme.blue, background: AppTheme.blueSoft, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.earningsTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    Text(earningsPeriodLabel(context, period),
                        key: const ValueKey('earnings-period-label'),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          picker(context),
          const SizedBox(height: 10),
          FutureBuilder<EarningsTotals>(
            future: future,
            builder: (context, snap) {
              if (snap.hasError) return _loadFailed(context, reload);
              if (snap.connectionState != ConnectionState.done || !snap.hasData) return _loading;
              final t = snap.data!;
              return Column(
                children: [
                  PayoutFigureLine(
                      key: const ValueKey('earnings-completed'), label: l.earningsCompleted, value: '${t.completed}'),
                  PayoutFigureLine(
                      key: const ValueKey('earnings-revenue'), label: l.earningsRevenue, value: fmt.birr(t.revenue)),
                  PayoutFigureLine(
                    key: const ValueKey('earnings-share'),
                    label: l.earningsYourShare(percent),
                    value: fmt.birr(t.shareAt(percent)),
                    strong: true,
                    color: AppTheme.success,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(l.earningsShareNote, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Owner: the shop's totals for any period (revenue, completed jobs,
/// barbers' share, the shop's part) and each barber's line. Used as the
/// "Totals" tab of the owner reports.
class ShopEarningsView extends StatefulWidget {
  const ShopEarningsView({super.key, required this.shopId, this.manager});

  final String shopId;

  /// Defaults to [PayoutsManager.instance].
  final PayoutsManager? manager;

  @override
  State<ShopEarningsView> createState() => _ShopEarningsViewState();
}

class _ShopEarningsViewState extends State<ShopEarningsView> with _EarningsLoader<ShopEarningsView, ShopEarnings> {
  @override
  late final PayoutsManager manager = widget.manager ?? PayoutsManager.instance;

  @override
  Future<ShopEarnings> fetch(EarningsPeriod period) => manager.loadShopEarnings(widget.shopId, period);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return RefreshIndicator(
      onRefresh: () async {
        reload();
        try {
          await future;
        } catch (_) {}
      },
      child: ListView(
        key: const ValueKey('shop-earnings'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(l.earningsShopTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          picker(context),
          const SizedBox(height: 12),
          FutureBuilder<ShopEarnings>(
            future: future,
            builder: (context, snap) {
              if (snap.hasError) return _loadFailed(context, reload);
              if (snap.connectionState != ConnectionState.done || !snap.hasData) return _loading;
              final e = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroCard(
                    key: const ValueKey('shop-earnings-hero'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(earningsPeriodLabel(context, period),
                            key: const ValueKey('earnings-period-label'),
                            style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Text(l.earningsRevenue, style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 13)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            fmt.birr(e.shop.revenue),
                            key: const ValueKey('shop-earnings-revenue'),
                            style: const TextStyle(
                                color: AppTheme.onInk, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.earningsBarberJobs(e.shop.completed),
                          key: const ValueKey('shop-earnings-completed'),
                          style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      children: [
                        PayoutFigureLine(
                          key: const ValueKey('shop-earnings-barbers-share'),
                          label: l.earningsBarbersShare,
                          value: fmt.birr(e.barbersShare),
                        ),
                        PayoutFigureLine(
                          key: const ValueKey('shop-earnings-shop-keeps'),
                          label: l.earningsShopKeeps,
                          value: fmt.birr(e.shopKeeps),
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(title: l.earningsByBarber),
                  const SizedBox(height: 10),
                  if (e.barbers.isEmpty)
                    Text(l.payoutsNoBarbers, style: const TextStyle(color: AppTheme.textSecondary))
                  else
                    for (final b in e.barbers)
                      AppCard(
                        key: ValueKey('shop-earnings-barber-${b.barberId}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const IconTile(icon: Icons.person_outline, color: AppTheme.green, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.barberName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                                  Text(
                                    '${l.earningsBarberJobs(b.totals.completed)} · '
                                    '${l.payoutsCommissionLine(b.commissionPercent)}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fmt.birr(b.totals.revenue),
                                    key: ValueKey('shop-earnings-barber-revenue-${b.barberId}'),
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                Text(fmt.birr(b.share),
                                    key: ValueKey('shop-earnings-barber-share-${b.barberId}'),
                                    style: const TextStyle(color: AppTheme.success, fontSize: 12.5)),
                              ],
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 6),
                  Text(l.earningsShareNote, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11.5)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
