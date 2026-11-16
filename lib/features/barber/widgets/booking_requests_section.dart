import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/booking_acceptance.dart';
import '../../shared/widgets/ui_kit.dart';

/// "New requests": pending bookings waiting for the barber's answer, each
/// with Accept and Decline (optional reason). Used on the barber dashboard
/// (their own requests) and by the owner (every barber of the shop, with
/// [showBarber]). Renders nothing when [requests] is empty.
class BookingRequestsSection extends StatefulWidget {
  const BookingRequestsSection({super.key, required this.requests, this.showBarber = false});

  final List<Booking> requests;

  /// Shows which barber each request is for (owner view).
  final bool showBarber;

  @override
  State<BookingRequestsSection> createState() => _BookingRequestsSectionState();
}

class _BookingRequestsSectionState extends State<BookingRequestsSection> {
  /// Requests with an answer in flight (their buttons are disabled).
  final Set<String> _busy = {};

  Future<void> _run(String bookingId, Future<void> Function() action, String success) async {
    if (_busy.contains(bookingId)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(bookingId));
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.acceptFailed(l.errorText(e)))));
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  Future<void> _accept(Booking booking) {
    final l = context.l10n;
    return _run(booking.id, () => AppRepository.instance.acceptBookingRequest(booking.id),
        l.acceptAccepted(booking.customerName));
  }

  Future<void> _decline(Booking booking) async {
    final l = context.l10n;
    final reason = await showDeclineRequestDialog(context, booking);
    if (reason == null || !mounted) return;
    await _run(
      booking.id,
      () => AppRepository.instance.declineBookingRequest(booking.id, reason: reason.isEmpty ? null : reason),
      l.acceptDeclined,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requests.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      key: const ValueKey('booking-requests-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(title: l.acceptRequestsTitle, padding: EdgeInsets.zero),
            ),
            StatusChip(label: l.acceptRequestsCount(widget.requests.length), color: AppTheme.warning),
          ],
        ),
        const SizedBox(height: 4),
        Text(l.acceptRequestsHelp, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        for (final b in widget.requests) _buildRequestCard(b),
      ],
    );
  }

  Widget _buildRequestCard(Booking booking) {
    final l = context.l10n;
    final fmt = context.fmt;
    final busy = _busy.contains(booking.id);
    return AppCard(
      key: ValueKey('booking-request-${booking.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: AppTheme.warning.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: Icons.mark_email_unread_outlined, color: AppTheme.warning, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(
                      widget.showBarber ? '${booking.serviceName} • ${booking.barberName}' : booking.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(fmt.birr(booking.price),
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${fmt.bookingTime(booking)} • ${fmt.dateMedium(fmt.bookingDay(booking))}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('decline-request-${booking.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(color: AppTheme.hairline),
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: busy ? null : () => _decline(booking),
                  child: Text(l.acceptDeclineAction),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: ValueKey('accept-request-${booking.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: AppTheme.onInk,
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: busy ? null : () => _accept(booking),
                  child: Text(l.acceptAction, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks to confirm a decline. Returns the (possibly empty) reason, or null
/// when the user backs out.
Future<String?> showDeclineRequestDialog(BuildContext context, Booking booking) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DeclineDialog(booking: booking),
  );
}

class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog({required this.booking});

  final Booking booking;

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.acceptDeclineTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.acceptDeclineBody(widget.booking.customerName)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('decline-reason-field'),
            controller: _controller,
            maxLength: kMaxDeclineReasonLength,
            maxLines: 2,
            decoration: InputDecoration(labelText: l.acceptDeclineReasonLabel),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.acceptDeclineCancel)),
        TextButton(
          key: const ValueKey('decline-request-confirm'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l.acceptDeclineConfirm),
        ),
      ],
    );
  }
}
