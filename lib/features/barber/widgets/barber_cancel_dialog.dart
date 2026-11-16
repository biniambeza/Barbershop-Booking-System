import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/booking_policy.dart' show kMaxCancelReasonNoteLength;

/// Asks the barber to confirm cancelling [booking], with an optional
/// reason (<= 200 characters). Returns the trimmed reason ('' for none)
/// when confirmed, or null when the barber keeps the booking.
Future<String?> showBarberCancelDialog(BuildContext context, Booking booking) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BarberCancelDialog(booking: booking),
  );
}

class _BarberCancelDialog extends StatefulWidget {
  const _BarberCancelDialog({required this.booking});

  final Booking booking;

  @override
  State<_BarberCancelDialog> createState() => _BarberCancelDialogState();
}

class _BarberCancelDialogState extends State<_BarberCancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final b = widget.booking;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      icon: Icon(Icons.event_busy_rounded, color: AppTheme.danger, size: 36),
      title: Text(l.barberCancelTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.barberCancelBody(
                b.customerName, b.serviceName, '${fmt.dateMedium(fmt.bookingDay(b))}, ${fmt.bookingTime(b)}')),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('barber-cancel-reason'),
              controller: _reason,
              maxLength: kMaxCancelReasonNoteLength,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.barberCancelReasonLabel,
                hintText: l.barberCancelReasonHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('barber-cancel-keep'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.barberCancelKeep, style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('barber-cancel-confirm'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: Text(l.barberCancelConfirm),
        ),
      ],
    );
  }
}
