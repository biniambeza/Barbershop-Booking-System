import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/reviews_service.dart';
import '../reviews_l10n.dart';
import 'review_widgets.dart';

/// Asks the customer for 1-5 stars and an optional comment, then saves the
/// review. Returns the saved review, or null when dismissed.
Future<Review?> showRateBookingDialog(BuildContext context, Booking booking, {ReviewsService? service}) {
  return showDialog<Review>(
    context: context,
    builder: (_) => RateBookingDialog(booking: booking, service: service),
  );
}

class RateBookingDialog extends StatefulWidget {
  const RateBookingDialog({super.key, required this.booking, this.service});

  final Booking booking;
  final ReviewsService? service;

  @override
  State<RateBookingDialog> createState() => _RateBookingDialogState();
}

class _RateBookingDialogState extends State<RateBookingDialog> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  String? _error;

  ReviewsService get _service => widget.service ?? ReviewsService.instance;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_rating == 0) {
      setState(() => _error = l.reviewsPickRating);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final review = await _service.submitReview(widget.booking, rating: _rating, comment: _comment.text);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.reviewsThanks)));
      Navigator.of(context).pop(review);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ReviewException ? l.reviewsErrorText(e) : l.reviewsSubmitFailed(l.reviewsErrorText(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.reviewsRateTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(b.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              l.reviewsRateSubtitle(b.serviceName, b.barberName),
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            StarRatingInput(value: _rating, onChanged: _busy ? (_) {} : (v) => setState(() => _rating = v)),
            if (_rating > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.reviewsStarsLabel(_rating),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('review-comment'),
              controller: _comment,
              enabled: !_busy,
              maxLines: 4,
              minLines: 2,
              maxLength: kReviewCommentMaxLength,
              decoration: InputDecoration(labelText: l.reviewsCommentLabel, hintText: l.reviewsCommentHint),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('review-error'),
                style: const TextStyle(color: AppTheme.danger, fontSize: 12.5),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          key: const ValueKey('submit-review'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.reviewsSubmit),
        ),
      ],
    );
  }
}
