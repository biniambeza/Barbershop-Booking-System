import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/booking_model.dart';
import '../../services/app_repository.dart';
import '../shared/widgets/ui_kit.dart';
import 'refunds_screen.dart';

/// Red count pill shown next to "Refunds due" while some are waiting.
class RefundsCountBadge extends StatelessWidget {
  const RefundsCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('refunds-badge'),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.red, borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: const TextStyle(color: AppTheme.onInk, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

/// Owner dashboard: opens [RefundsScreen] for the shop (key
/// `open-refunds`) with the number waiting. Shown only while a refund is
/// due. On first build it also flags cancelled paid bookings an older app
/// left unflagged ([AppRepository.flagMissingRefunds]). Includes its own
/// bottom spacing.
class OwnerRefundsButton extends StatefulWidget {
  const OwnerRefundsButton({super.key, required this.shopId, this.repository});

  final String shopId;

  /// Defaults to [AppRepository.instance] (tests).
  final AppRepository? repository;

  @override
  State<OwnerRefundsButton> createState() => _OwnerRefundsButtonState();
}

class _OwnerRefundsButtonState extends State<OwnerRefundsButton> {
  late final AppRepository _repo = widget.repository ?? AppRepository.instance;
  late final Stream<List<Booking>> _due = _repo.watchRefundsDue(shopId: widget.shopId);

  @override
  void initState() {
    super.initState();
    _repo.flagMissingRefunds(shopId: widget.shopId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _due,
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        final l = context.l10n;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('open-refunds'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RefundsScreen(shopId: widget.shopId, repository: _repo)),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                backgroundColor: AppTheme.card,
                side: const BorderSide(color: AppTheme.hairline),
                minimumSize: const Size(0, 54),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              icon: const Icon(Icons.currency_exchange_rounded, size: 18, color: AppTheme.warning),
              label: Row(
                children: [
                  Expanded(
                    child: Text(l.refundsDueTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  RefundsCountBadge(count: count),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Admin payments tab: "Refunds due" across every shop, with the number
/// waiting (key `admin-pay-open-refunds`). Shown only while any is due.
class AdminRefundsCard extends StatefulWidget {
  const AdminRefundsCard({super.key, this.repository});

  /// Defaults to [AppRepository.instance] (tests).
  final AppRepository? repository;

  @override
  State<AdminRefundsCard> createState() => _AdminRefundsCardState();
}

class _AdminRefundsCardState extends State<AdminRefundsCard> {
  late final AppRepository repo = widget.repository ?? AppRepository.instance;
  late final Stream<List<Booking>> _due = repo.watchRefundsDue();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _due,
      builder: (context, snap) {
        final l = context.l10n;
        final count = snap.data?.length ?? 0;
        // Shown only while a refund is waiting (like the owner's button).
        if (count == 0) return const SizedBox.shrink();
        return AppCard(
          key: const ValueKey('admin-pay-open-refunds'),
          margin: const EdgeInsets.only(bottom: 10),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RefundsScreen(repository: repo)),
          ),
          child: Row(
            children: [
              const IconTile(icon: Icons.currency_exchange_rounded, color: AppTheme.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.refundsDueTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      l.refundsDueCount(count),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              RefundsCountBadge(count: count),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
            ],
          ),
        );
      },
    );
  }
}
