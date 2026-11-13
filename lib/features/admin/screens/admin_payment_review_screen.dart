import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/payment_service.dart';

/// Why a payment was flagged needsReview, as far as the app can tell.
enum PaymentReviewReason { cancelledBooking, doublePayment, refundReported, subscription, other }

/// Mirrors where functions/payments sets needsReview (store.ts applyOutcome
/// and the refund webhook). [booking] may be null when it is not loaded.
PaymentReviewReason paymentReviewReason(PaymentRecord payment, Booking? booking) {
  if (payment.type == PaymentType.subscription) return PaymentReviewReason.subscription;
  if (booking == null) return PaymentReviewReason.other;
  if (booking.paymentStatus == PaymentStatus.paid && booking.paymentId != null && booking.paymentId != payment.id) {
    return PaymentReviewReason.doublePayment;
  }
  if (booking.status == BookingStatus.cancelled) return PaymentReviewReason.cancelledBooking;
  if (payment.status == PaymentRecordStatus.success) return PaymentReviewReason.refundReported;
  return PaymentReviewReason.other;
}

extension on AppLocalizations {
  String reviewReason(PaymentReviewReason reason) {
    switch (reason) {
      case PaymentReviewReason.cancelledBooking:
        return reviewReasonCancelledBooking;
      case PaymentReviewReason.doublePayment:
        return reviewReasonDoublePayment;
      case PaymentReviewReason.refundReported:
        return reviewReasonRefundReported;
      case PaymentReviewReason.subscription:
        return reviewReasonSubscription;
      case PaymentReviewReason.other:
        return reviewReasonOther;
    }
  }
}

/// Admin: payments flagged needsReview (paid for a cancelled booking, paid
/// twice, unconfirmed refund, subscription not applied), with their details
/// and the two ways to close them (resolvePaymentReview).
class AdminPaymentReviewScreen extends StatefulWidget {
  const AdminPaymentReviewScreen({super.key, this.payments});

  /// Defaults to [PaymentService.instance].
  final PaymentService? payments;

  @override
  State<AdminPaymentReviewScreen> createState() => _AdminPaymentReviewScreenState();
}

class _AdminPaymentReviewScreenState extends State<AdminPaymentReviewScreen> {
  late final PaymentService _payments = widget.payments ?? PaymentService.instance;
  late final Stream<List<PaymentRecord>> _stream = _payments.watchPaymentsToReview();

  Future<void> _open(PaymentRecord payment) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final resolution = await showModalBottomSheet<PaymentReviewResolution>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkCard,
      builder: (_) => PaymentReviewSheet(payment: payment, payments: _payments),
    );
    if (resolution == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(resolution == PaymentReviewResolution.refundedInChapa ? l.reviewClosedRefunded : l.reviewClosedNoAction),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.paymentsToReview)),
      body: StreamBuilder<List<PaymentRecord>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Message(
              icon: Icons.error_outline,
              title: l.paymentsToReviewLoadFailed(l.errorText(snap.error!)),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return _Message(icon: Icons.verified_outlined, title: l.noPaymentsToReview, body: l.noPaymentsToReviewHint);
          }
          return ListenableBuilder(
            listenable: AppRepository.instance,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.paymentsToReviewIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                for (final p in items) _ReviewCard(payment: p, onTap: () => _open(p)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.payment, required this.onTap});

  final PaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final repo = AppRepository.instance;
    final booking = payment.bookingId == null ? null : repo.getBookingById(payment.bookingId!);
    final shop = repo.getShopById(payment.shopId);
    final reason = paymentReviewReason(payment, booking);
    return Card(
      key: ValueKey('review-${payment.id}'),
      color: AppTheme.darkCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.report_gmailerrorred_rounded, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.reviewReason(reason), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text(
                    fmt.birr(payment.amount),
                    style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  payment.type == PaymentType.subscription ? l.paymentTypeSubscription : l.paymentTypeBooking,
                  if (shop != null) shop.name,
                  fmt.addisDateMedium(payment.createdAt),
                ].join(' • '),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              if (booking != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${booking.customerName} • ${booking.serviceName} • ${l.bookingStatus(booking.status)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Details of one flagged payment and the actions that close its review.
/// Pops the chosen [PaymentReviewResolution] once the server accepted it.
class PaymentReviewSheet extends StatefulWidget {
  const PaymentReviewSheet({super.key, required this.payment, required this.payments});

  final PaymentRecord payment;
  final PaymentService payments;

  @override
  State<PaymentReviewSheet> createState() => _PaymentReviewSheetState();
}

class _PaymentReviewSheetState extends State<PaymentReviewSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  PaymentRecord get _p => widget.payment;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _resolve(PaymentReviewResolution resolution) async {
    final l = context.l10n;
    if (resolution == PaymentReviewResolution.refundedInChapa) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: Text(l.confirmRefundTitle),
          content: Text(l.confirmRefundBody(context.fmt.birr(_p.amount))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            ElevatedButton(
              key: const ValueKey('confirm-refund'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.markRefundedInChapa),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.payments.resolvePaymentReview(paymentId: _p.id, resolution: resolution, note: _note.text);
      if (mounted) Navigator.of(context).pop(resolution);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.reviewFailed(l.errorText(e));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final repo = AppRepository.instance;
    final booking = _p.bookingId == null ? null : repo.getBookingById(_p.bookingId!);
    final shop = repo.getShopById(_p.shopId);
    final payer = repo.getAllUsers().where((u) => u.uid == _p.userId).firstOrNull;
    String when(DateTime t) => '${fmt.addisDateMedium(t)} ${fmt.addisTime(t)}';

    final rows = <(String, String)>[
      (l.detailAmount, fmt.birr(_p.amount)),
      (l.detailStatus, l.paymentRecordStatus(_p.status)),
      (l.detailCreated, when(_p.createdAt)),
      if (_p.verifiedAt != null) (l.detailVerified, when(_p.verifiedAt!)),
      if (shop != null) (l.detailShop, shop.name),
      if (booking != null)
        (l.detailBooking, '${booking.serviceName} • ${fmt.addisDateMedium(booking.startAt)} • ${l.bookingStatus(booking.status)}'),
      if (payer != null || booking != null)
        (l.detailCustomer, payer != null ? '${payer.name} ${fmt.phone(payer.phone ?? '')}'.trim() : booking!.customerName),
      if (_p.chapaMethod != null) (l.detailMethod, _p.chapaMethod!),
      (l.detailTxRef, _p.txRef),
      if (_p.chapaReference != null) (l.detailChapaReference, _p.chapaReference!),
      (l.detailPaymentId, _p.id),
    ];
    final canRefund = _p.status == PaymentRecordStatus.success || _p.status == PaymentRecordStatus.refunded;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.paymentDetailsTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l.reviewReason(paymentReviewReason(_p, booking)),
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ),
                      Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('review-note'),
                controller: _note,
                enabled: !_busy,
                maxLength: kMaxReviewNoteLength,
                maxLines: 2,
                decoration: InputDecoration(labelText: l.reviewNoteLabel, hintText: l.reviewNoteHint),
              ),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    key: const ValueKey('review-no-action'),
                    onPressed: _busy ? null : () => _resolve(PaymentReviewResolution.noAction),
                    child: Text(l.markNoAction),
                  ),
                  if (canRefund)
                    ElevatedButton.icon(
                      key: const ValueKey('review-refunded'),
                      onPressed: _busy ? null : () => _resolve(PaymentReviewResolution.refundedInChapa),
                      icon: _busy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.undo_rounded, size: 18),
                      label: Text(l.markRefundedInChapa),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App-bar button on the admin dashboard; shows how many payments wait.
class PaymentsToReviewButton extends StatefulWidget {
  const PaymentsToReviewButton({super.key, this.payments});

  final PaymentService? payments;

  @override
  State<PaymentsToReviewButton> createState() => _PaymentsToReviewButtonState();
}

class _PaymentsToReviewButtonState extends State<PaymentsToReviewButton> {
  StreamSubscription<List<PaymentRecord>>? _sub;
  int _count = 0;

  PaymentService get _payments => widget.payments ?? PaymentService.instance;

  @override
  void initState() {
    super.initState();
    _sub = _payments.watchPaymentsToReview().listen(
      (items) {
        if (mounted) setState(() => _count = items.length);
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('open-payments-to-review'),
      tooltip: context.l10n.paymentsToReview,
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text('$_count'),
        child: const Icon(Icons.fact_check_outlined, color: AppTheme.primaryGold),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminPaymentReviewScreen(payments: widget.payments)),
      ),
    );
  }
}
