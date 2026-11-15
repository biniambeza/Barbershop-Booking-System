import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barber_model.dart';
import '../../models/booking_model.dart';
import '../../services/app_repository.dart';
import '../shared/widgets/ui_kit.dart';
import 'payouts_l10n.dart';
import 'payouts_manager.dart';
import 'payouts_screen.dart';

/// Owner dashboard: opens [PayoutsScreen] (key `open-payouts`). Same
/// full-width row style as its neighbours. Includes its own bottom spacing.
class OwnerPayoutsButton extends StatelessWidget {
  const OwnerPayoutsButton({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('open-payouts'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PayoutsScreen(shopId: shopId)),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            backgroundColor: AppTheme.card,
            side: const BorderSide(color: AppTheme.hairline),
            minimumSize: const Size(0, 54),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.green),
          label: Row(
            children: [
              Expanded(
                child: Text(l.payoutsOpenButton, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barber dashboard: this month's share, what was paid, the balance owed,
/// and the latest payouts (key `barber-payouts-card`).
class BarberPayoutsCard extends StatefulWidget {
  const BarberPayoutsCard({super.key, required this.barber, this.manager});

  final Barber barber;

  /// Defaults to [PayoutsManager.instance].
  final PayoutsManager? manager;

  /// Payouts listed on the card; the rest via "See all payouts".
  static const int latestShown = 3;

  @override
  State<BarberPayoutsCard> createState() => _BarberPayoutsCardState();
}

class _BarberPayoutsCardState extends State<BarberPayoutsCard> {
  late final PayoutsManager _m = widget.manager ?? PayoutsManager.instance;
  late final PayoutMonth _month = _m.currentMonth();
  late Future<List<Booking>> _bookings;
  late Stream<List<Payout>> _payouts;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(BarberPayoutsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barber.id != widget.barber.id || oldWidget.barber.shopId != widget.barber.shopId) _subscribe();
  }

  void _subscribe() {
    _bookings = _m.loadMonthBookings(widget.barber.shopId, _month, barberId: widget.barber.id);
    _payouts = _m.watchBarberPayouts(widget.barber);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return StreamBuilder<List<Payout>>(
      stream: _payouts,
      builder: (context, payoutSnap) => FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, bookingSnap) => ListenableBuilder(
          listenable: AppRepository.instance,
          builder: (context, _) {
            final barber = AppRepository.instance.getBarberById(widget.barber.id) ?? widget.barber;
            final payouts = payoutSnap.data ?? const <Payout>[];
            final bookings = mergeBookings(
              bookingSnap.data ?? const <Booking>[],
              _m.cachedMonthBookings(barber.shopId, _month, barberId: barber.id),
            );
            final s = summarizeBarberMonth(barber: barber, bookings: bookings, payouts: payouts, month: _month);
            final latest = payouts.take(BarberPayoutsCard.latestShown).toList();
            return AppCard(
              key: const ValueKey('barber-payouts-card'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconTile(
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppTheme.green,
                          background: AppTheme.greenSoft,
                          size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.payoutsYourShare,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                            Text(l.payoutsThisMonth(payoutMonthLabel(fmt, _month)),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Text(
                        fmt.birr(s.share),
                        key: const ValueKey('barber-payouts-share'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.payoutsShareLine(s.commissionPercent, s.completedJobs, fmt.birr(s.gross)),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  PayoutFigureLine(
                    key: const ValueKey('barber-payouts-paid'),
                    label: l.payoutsPaidToYou,
                    value: fmt.birr(s.paid),
                  ),
                  PayoutFigureLine(
                    key: const ValueKey('barber-payouts-balance'),
                    label: l.payoutsBalanceOwed,
                    value: fmt.birr(s.balance),
                    strong: true,
                    color: s.balance > 0 ? AppTheme.success : AppTheme.textPrimary,
                  ),
                  const Divider(height: 22, color: AppTheme.hairline),
                  SectionHeader(
                    title: l.payoutsMyPayouts,
                    actionLabel: payouts.length > latest.length ? l.payoutsSeeAll : null,
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BarberPayoutsScreen(barber: barber, manager: _m)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (payoutSnap.hasError)
                    Text(l.payoutsLoadFailed, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5))
                  else if (latest.isEmpty)
                    Text(l.payoutsMyPayoutsEmpty,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5))
                  else
                    for (final p in latest) PayoutTile(payout: p),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Barber: all of their payouts, newest first (read-only).
class BarberPayoutsScreen extends StatefulWidget {
  const BarberPayoutsScreen({super.key, required this.barber, this.manager});

  final Barber barber;
  final PayoutsManager? manager;

  @override
  State<BarberPayoutsScreen> createState() => _BarberPayoutsScreenState();
}

class _BarberPayoutsScreenState extends State<BarberPayoutsScreen> {
  late final Stream<List<Payout>> _payouts =
      (widget.manager ?? PayoutsManager.instance).watchBarberPayouts(widget.barber);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.payoutsMyPayouts)),
      body: StreamBuilder<List<Payout>>(
        stream: _payouts,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(l.payoutsLoadFailed));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final payouts = snap.data!;
          if (payouts.isEmpty) {
            return Center(child: Text(l.payoutsMyPayoutsEmpty, style: const TextStyle(color: AppTheme.textSecondary)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [for (final p in payouts) PayoutTile(payout: p)],
          );
        },
      ),
    );
  }
}
