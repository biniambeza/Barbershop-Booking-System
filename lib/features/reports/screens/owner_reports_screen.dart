import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../../services/reports_service.dart';

/// Owner reports for one shop: an Overview tab (month picker, totals,
/// 6-month revenue trend, top services, barber performance) and a Clients
/// tab (frequent clients with no-show badges).
class OwnerReportsScreen extends StatefulWidget {
  const OwnerReportsScreen({super.key, required this.shopId, this.service, this.now});

  final String shopId;

  /// Defaults to a [ReportsService] over [AppRepository.instance].
  final ReportsService? service;

  /// Tests: a fixed "now".
  final DateTime? now;

  @override
  State<OwnerReportsScreen> createState() => _OwnerReportsScreenState();
}

class _OwnerReportsScreenState extends State<OwnerReportsScreen> {
  late final ReportsService _service = widget.service ?? ReportsService();
  Future<ShopReport>? _future;
  String? _selectedMonth;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    if (_service.usesFirestore) _future = _load();
  }

  Future<ShopReport> _load() => _service.loadShopReport(widget.shopId, now: _now);

  void _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.reportsTitle),
          actions: [
            if (_service.usesFirestore)
              IconButton(icon: const Icon(Icons.refresh), tooltip: l.reportsRetry, onPressed: _reload),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.primaryGold,
            labelColor: AppTheme.primaryGold,
            tabs: [
              Tab(key: const ValueKey('reports-tab-overview'), text: l.reportsOverviewTab),
              Tab(key: const ValueKey('reports-tab-clients'), text: l.reportsClientsTab),
            ],
          ),
        ),
        body: _service.usesFirestore
            ? FutureBuilder<ShopReport>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) return _error(context);
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  return _tabs(snap.data!);
                },
              )
            : ListenableBuilder(
                // Demo / tests: recomputed from the local bookings on every change.
                listenable: AppRepository.instance,
                builder: (context, _) => _tabs(_service.computeLocalReport(widget.shopId, now: _now)),
              ),
      ),
    );
  }

  Widget _error(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reportsLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _reload, child: Text(l.reportsRetry)),
          ],
        ),
      ),
    );
  }

  Widget _tabs(ShopReport report) {
    final month = _selectedMonth ?? report.months.first.month;
    return TabBarView(
      children: [
        _OverviewTab(
          report: report,
          month: month,
          showUpdatedNote: _service.usesFirestore,
          onMonthChanged: (m) => setState(() => _selectedMonth = m),
        ),
        _ClientsTab(clients: report.clients),
      ],
    );
  }
}

String _monthLabel(BuildContext context, String key, {bool short = false}) {
  final date = monthKeyToDate(key);
  if (date == null) return key;
  final language = context.fmt.language;
  return (short ? DateFormat.MMM(language) : DateFormat.yMMMM(language)).format(date);
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.report,
    required this.month,
    required this.showUpdatedNote,
    required this.onMonthChanged,
  });

  final ShopReport report;
  final String month;
  final bool showUpdatedNote;
  final ValueChanged<String> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final stats = report.month(month);
    final trend = report.trendEndingAt(month, ReportsService.trendMonths);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(l.reportsMonthLabel, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                key: const ValueKey('reports-month-picker'),
                value: month,
                isExpanded: true,
                items: [
                  for (final m in report.months)
                    DropdownMenuItem(value: m.month, child: Text(_monthLabel(context, m.month))),
                ],
                onChanged: (m) {
                  if (m != null) onMonthChanged(m);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricTile(
                key: const ValueKey('reports-total-bookings'),
                label: l.reportsBookings,
                value: '${stats.bookings}',
                icon: Icons.event_note),
            _MetricTile(
                key: const ValueKey('reports-total-completed'),
                label: l.reportsCompleted,
                value: '${stats.completed}',
                icon: Icons.check_circle_outline,
                color: Colors.greenAccent),
            _MetricTile(
                key: const ValueKey('reports-total-cancelled'),
                label: l.reportsCancelled,
                value: '${stats.cancelled}',
                icon: Icons.cancel_outlined,
                color: Colors.redAccent),
            _MetricTile(
                key: const ValueKey('reports-total-noshows'),
                label: l.reportsNoShows,
                value: '${stats.noShows}',
                icon: Icons.person_off_outlined,
                color: Colors.orangeAccent),
            _MetricTile(
                key: const ValueKey('reports-total-revenue'),
                label: l.reportsRevenue,
                value: fmt.birr(stats.revenueEtb),
                icon: Icons.payments_outlined,
                wide: true),
          ],
        ),
        if (stats.isEmpty) ...[
          const SizedBox(height: 12),
          Text(l.reportsNoBookingsMonth, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 20),
        _SectionTitle(l.reportsRevenueTrend),
        _RevenueBars(months: trend),
        const SizedBox(height: 20),
        _SectionTitle(l.reportsTopServices),
        if (stats.topServices.isEmpty)
          Text(l.reportsNoCompletedMonth, style: const TextStyle(color: AppTheme.textSecondary))
        else
          for (final s in stats.topServices)
            _RankRow(title: s.name, subtitle: l.reportsCompletedCount(s.count), amount: fmt.birr(s.revenueEtb)),
        const SizedBox(height: 20),
        _SectionTitle(l.reportsBarberPerformance),
        if (stats.barberPerformance.isEmpty)
          Text(l.reportsNoCompletedMonth, style: const TextStyle(color: AppTheme.textSecondary))
        else
          for (final b in stats.barberPerformance)
            _RankRow(title: b.name, subtitle: l.reportsCompletedCount(b.completed), amount: fmt.birr(b.revenueEtb)),
        if (showUpdatedNote) ...[
          const SizedBox(height: 20),
          Text(l.reportsUpdatedNote, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child:
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {super.key, required this.label, required this.value, required this.icon, this.color, this.wide = false});

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final half = (constraints.maxWidth - 10) / 2;
      return SizedBox(
        width: wide ? constraints.maxWidth : half,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color ?? AppTheme.primaryGold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Simple vertical bars (no chart dependency), oldest month on the left.
class _RevenueBars extends StatelessWidget {
  const _RevenueBars({required this.months});
  final List<ShopMonthStats> months;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final max = months.fold<double>(0, (m, s) => s.revenueEtb > m ? s.revenueEtb : m);
    const barArea = 110.0;
    return Container(
      key: const ValueKey('reports-revenue-trend'),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final s in months)
            Expanded(
              child: Semantics(
                label: '${_monthLabel(context, s.month)}: ${fmt.birr(s.revenueEtb)}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      child: Text(
                        s.revenueEtb > 0 ? NumberFormat.compact(locale: 'en').format(s.revenueEtb) : '0',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: max <= 0 ? 2 : 2 + (barArea - 2) * (s.revenueEtb / max),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: s.revenueEtb > 0 ? 0.85 : 0.25),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(_monthLabel(context, s.month, short: true),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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

class _RankRow extends StatelessWidget {
  const _RankRow({required this.title, required this.subtitle, required this.amount});
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.darkCard,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
        trailing: Text(amount, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab({required this.clients});
  final List<ShopClient> clients;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    if (clients.isEmpty) {
      return Center(child: Text(l.reportsNoClients, style: const TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clients.length,
      itemBuilder: (context, i) {
        final c = clients[i];
        final details = [
          l.reportsClientVisits(c.completedCount),
          if (c.cancelledCount > 0) l.reportsClientCancelled(c.cancelledCount),
          c.lastVisitAt != null ? l.reportsLastVisit(fmt.addisDateMedium(c.lastVisitAt!)) : l.reportsNoVisitYet,
        ].join(' · ');
        return Card(
          key: ValueKey('reports-client-${c.customerId}'),
          color: AppTheme.darkCard,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
              child: Text(
                c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(c.name.isNotEmpty ? c.name : fmt.phone(c.phone)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.phone.isNotEmpty && c.name.isNotEmpty)
                  Text(fmt.phone(c.phone), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(details, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            trailing: c.noShowCount > 0
                ? Container(
                    key: ValueKey('reports-noshow-badge-${c.customerId}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      l.reportsClientNoShows(c.noShowCount),
                      style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
