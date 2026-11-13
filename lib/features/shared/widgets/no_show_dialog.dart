import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';

/// Asks staff to confirm marking [booking] as a no-show. True when confirmed.
Future<bool> confirmNoShow(BuildContext context, Booking booking) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.darkCard,
      icon: const Icon(Icons.person_off_rounded, color: Colors.deepOrangeAccent, size: 36),
      title: Text(l.noShowConfirmTitle),
      content: Text(l.noShowConfirmBody(booking.customerName)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
        TextButton(
          key: const ValueKey('confirm-no-show'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.noShowAction, style: const TextStyle(color: Colors.deepOrangeAccent)),
        ),
      ],
    ),
  );
  return ok == true;
}
