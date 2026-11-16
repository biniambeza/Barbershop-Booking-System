import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/shop_report.dart' show recentMonthKeys, monthKeyToDate;
import '../../../services/app_repository.dart';
import '../../../services/owner_insights_service.dart';
import '../../shared/widgets/ui_kit.dart';

/// Owner reports, Busy hours tab: a weekday x hour heatmap of the shop's
/// bookings (Addis time) for the last 30 / 90 days or a chosen month, with
/// busiest day, busiest time and quietest hour callouts.
class BusyHoursTab extends StatefulWidget {
  const BusyHoursTab({super.key, required this.shopId, this.service, this.now});

  final String shopId;

  /// Defaults to an [OwnerInsightsService] over [AppRepository.instance].
  final OwnerInsightsService? service;

  /// Tests: a fixed "now".
  final DateTime? now;

  @override
  State<BusyHoursTab> createState() => _BusyHoursTabState();
}

class _BusyHoursTabState extends State<BusyHoursTab> {
  late final OwnerInsightsService _service = widget.service ?? OwnerInsightsService();
  BusyHoursRange _range = BusyHoursRange.last30Days;
  late String _month = recentMonthKeys(_now, 1).first;
  BusyHoursPeriod? _queried;
  Future<BusyHoursHeatmap>? _future;

  DateTime get _now => (widget.now ?? AppRepository.instance.nowUtc()).toUtc();

  BusyHoursPeriod get _period => BusyHoursPeriod.of(_range, _now, month: _month);

  Future<BusyHoursHeatmap> _futureFor(BusyHoursPeriod period) {
    if (_queried != period || _future == null) {
      _queried = period;
      _future = _service.busyHours(widget.shopId, period, now: _now);
    }
    return _future!;
  }

  void _retry() => setState(() => _future = null);

  @override
  Widget build(BuildContext context) {
    final period = _period;
    final controls = _controls(context);
    if (_service.needsQuery(period, _now)) {
      return FutureBuilder<BusyHoursHeatmap>(
        future: _futureFor(period),
        builder: (context, snap) {
          if (snap.hasError) return _list([controls, const SizedBox(height: 24), _failed(context)]);
          if (!snap.hasData) {
            return _list([controls, const SizedBox(height: 40), const Center(child: CircularProgressIndicator())]);
          }
          return _content(context, controls, snap.data!);
        },
      );
    }
    return ListenableBuilder(
      listenable: AppRepository.instance,
      builder: (context, _) => _content(context, controls, _service.cachedBusyHours(widget.shopId, period)),
    );
  }

  Widget _list(List<Widget> children) => ListView(
        key: const ValueKey('busy-hours-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      );

  Widget _failed(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Text(l.busyLoadFailed, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextButton(onPressed: _retry, child: Text(l.reportsRetry)),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final l = context.l10n;
    Widget chip(BusyHoursRange range, String label) {
      final selected = _range == range;
      return ChoiceChip(
        key: ValueKey('busy-range-${range.name}'),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppTheme.ink,
        backgroundColor: AppTheme.card,
        side: BorderSide(color: selected ? AppTheme.ink : AppTheme.hairline),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          color: selected ? AppTheme.onInk : AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        onSelected: (_) => setState(() => _range = range),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(BusyHoursRange.last30Days, l.busyRangeLast30),
            chip(BusyHoursRange.last90Days, l.busyRangeLast90),
            chip(BusyHoursRange.month, l.busyRangeMonth),
          ],
        ),
        if (_range == BusyHoursRange.month) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: DropdownButton<String>(
              key: const ValueKey('busy-month-picker'),
              value: _month,
              isExpanded: true,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
              dropdownColor: AppTheme.card,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
              items: [
                for (final m in recentMonthKeys(_now, 12))
                  DropdownMenuItem(value: m, child: Text(_monthLabel(context, m))),
              ],
              onChanged: (m) {
                if (m != null) setState(() => _month = m);
              },
            ),
          ),
        ],
      ],
    );
  }

  static String _monthLabel(BuildContext context, String key) {
    final date = monthKeyToDate(key);
    return date == null ? key : DateFormat.yMMMM(context.fmt.language).format(date);
  }

  Widget _content(BuildContext context, Widget controls, BusyHoursHeatmap map) {
    final l = context.l10n;
    final fmt = context.fmt;
    final shop = AppRepository.instance.getShopById(widget.shopId);
    final open = shop?.openingHour ?? 9, close = shop?.closingHour ?? 20;
    final day = map.busiestWeekday;
    final slot = map.busiestSlot;
    final quiet = map.quietestHour(openingHour: open, closingHour: close);
    return _list([
      controls,
      const SizedBox(height: 14),
      HeroCard(
        key: const ValueKey('busy-summary'),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.busyTotalBookings, style: TextStyle(fontSize: 12, color: AppTheme.onHeroMuted)),
            const SizedBox(height: 2),
            Text('${map.total}',
                key: const ValueKey('busy-total'),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _Callout(
                        key: const ValueKey('busy-busiest-day'),
                        label: l.busyBusiestDay,
                        value: day == null ? '—' : fmt.weekdayName(day))),
                Expanded(
                    child: _Callout(
                        key: const ValueKey('busy-busiest-time'),
                        label: l.busyBusiestTime,
                        value: slot == null ? '—' : '${fmt.weekdayName(slot.$1)} ${fmt.hour(slot.$2)}')),
                Expanded(
                    child: _Callout(
                        key: const ValueKey('busy-quietest-hour'),
                        label: l.busyQuietestHour,
                        value: quiet == null ? '—' : fmt.hour(quiet))),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(l.busyHoursTitle,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary, letterSpacing: -0.2)),
      ),
      if (map.isEmpty)
        AppCard(
          child: Text(l.busyNoBookings,
              key: const ValueKey('busy-empty'), style: TextStyle(color: AppTheme.textSecondary)),
        )
      else
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: BusyHoursGrid(map: map, openingHour: open, closingHour: close),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l.busyHoursNote, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    ]);
  }
}

class _Callout extends StatelessWidget {
  const _Callout({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppTheme.onHeroMuted)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.onHero)),
          ],
        ),
      );
}

/// The heatmap: one row per weekday (Monday first), one column per hour of
/// [BusyHoursHeatmap.visibleHours]. Scrolls sideways when the hours do not
/// fit.
class BusyHoursGrid extends StatelessWidget {
  const BusyHoursGrid({super.key, required this.map, required this.openingHour, required this.closingHour});

  final BusyHoursHeatmap map;
  final int openingHour;
  final int closingHour;

  static const double _labelWidth = 40;
  static const double _minCell = 24;
  static const double _cellHeight = 26;

  // Three-stop green ramps: pale mint -> fresh green -> deep green on white;
  // deep forest -> brand green -> bright mint on black. Both low ends stay
  // clearly apart from the empty-cell track, so one booking never looks
  // like none, and the busiest cell is the most prominent in either mode.
  static const List<Color> _rampLight = [Color(0xFFBBF7D0), Color(0xFF4ADE80), Color(0xFF15803D)];
  static const List<Color> _rampDark = [Color(0xFF14532D), Color(0xFF16A34A), Color(0xFF4ADE80)];

  /// Colour of the ramp at [t] (0 = fewest, 1 = most bookings).
  static Color rampColor(double t) {
    final stops = AppTheme.isDark ? _rampDark : _rampLight;
    final x = t.clamp(0.0, 1.0) * (stops.length - 1);
    final i = x.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], x - i)!;
  }

  static Color cellColor(int count, int max) {
    if (count <= 0 || max <= 0) return AppTheme.track;
    return rampColor(count / max);
  }

  /// Readable count on a cell of colour [cell]: deep green on the light end
  /// of the ramp, white on the dark end.
  static Color countColor(Color cell) =>
      cell.computeLuminance() > 0.3 ? const Color(0xFF052E16) : const Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final (from, to) = map.visibleHours(openingHour: openingHour, closingHour: closingHour);
    final hours = [for (var h = from; h < to; h++) h];
    final max = map.maxCell;
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth - _labelWidth;
      final cell = (available / hours.length).clamp(_minCell, 44.0);
      final width = _labelWidth + cell * hours.length;
      final showEvery = cell < 30 ? 2 : 1;
      final grid = SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: _labelWidth),
                for (final h in hours)
                  SizedBox(
                    width: cell,
                    child: Text(
                      (h - from) % showEvery == 0 ? h.toString().padLeft(2, '0') : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var d = 1; d <= 7; d++)
              Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(fmt.weekdayName(d),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                            fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  for (final h in hours)
                    Semantics(
                      label: l.busyCellSemantics(fmt.weekdayName(d), fmt.hour(h), map.at(d, h)),
                      child: Container(
                        key: ValueKey('busy-cell-$d-$h'),
                        width: cell - 3,
                        height: _cellHeight - 3,
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: cellColor(map.at(d, h), max),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: map.at(d, h) > 0 && cell >= 28
                            ? Text('${map.at(d, h)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: countColor(cellColor(map.at(d, h), max))))
                            : null,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: _labelWidth),
                Text(l.busyLegendFewer, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(width: 6),
                for (final t in const [0.0, 0.1, 0.4, 0.7, 1.0])
                  Container(
                    width: 16,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: t == 0 ? AppTheme.track : rampColor(t),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(l.busyLegendMore, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      );
      if (width <= constraints.maxWidth + 0.5) return grid;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid);
    });
  }
}
