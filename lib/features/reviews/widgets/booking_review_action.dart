import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/reviews_service.dart';
import '../reviews_l10n.dart';
import 'rate_booking_dialog.dart';
import 'review_widgets.dart';

/// My Appointments: on a completed booking of the signed-in customer, a
/// "Rate your barber" button (key `rate-booking-{id}`) until it is reviewed, then
/// the stars they gave (key `my-review-{id}`); tapping those opens Edit
/// review (`edit-review-{id}`) / Delete review (`delete-review-{id}`).
/// Shows nothing for other bookings.
class BookingReviewAction extends StatefulWidget {
  const BookingReviewAction({super.key, required this.booking, this.service});

  final Booking booking;
  final ReviewsService? service;

  @override
  State<BookingReviewAction> createState() => _BookingReviewActionState();
}

class _BookingReviewActionState extends State<BookingReviewAction> {
  Stream<Review?>? _stream;

  ReviewsService get _service => widget.service ?? ReviewsService.instance;

  bool get _eligible => _service.reviewBlocker(widget.booking) == null;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(BookingReviewAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.id != widget.booking.id || oldWidget.booking.status != widget.booking.status) _subscribe();
  }

  void _subscribe() => _stream = _eligible ? _service.watchReviewForBooking(widget.booking) : null;

  /// Edit or delete the customer's own [review].
  Future<void> _manage(Review review) async {
    final l = context.l10n;
    final booking = widget.booking;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.card,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: ValueKey('edit-review-${booking.id}'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.reviewsEditAction),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              key: ValueKey('delete-review-${booking.id}'),
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              title: Text(l.reviewsDeleteAction, style: const TextStyle(color: AppTheme.danger)),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await showRateBookingDialog(context, booking, service: widget.service, existing: review);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.reviewsDeleteConfirmTitle),
        content: Text(l.reviewsDeleteConfirmBody(booking.barberName)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l.cancel)),
          TextButton(
            key: const ValueKey('confirm-delete-review'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.delete, style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _service.deleteReview(review);
      messenger?.showSnackBar(SnackBar(content: Text(l.reviewsDeleted)));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(l.reviewsErrorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return const SizedBox.shrink();
    final l = context.l10n;
    final booking = widget.booking;
    return StreamBuilder<Review?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final review = snapshot.data;
        if (review != null) {
          return Tooltip(
            message: l.reviewsManageHint,
            child: Material(
              color: AppTheme.orangeSoft,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: ValueKey('my-review-${booking.id}'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => _manage(review),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.reviewsYourRating, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(width: 6),
                      StarRatingDisplay(rating: review.rating.toDouble(), size: 13),
                      if (review.isEdited) ...[
                        const SizedBox(width: 6),
                        Text(l.reviewsEdited,
                            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(width: 4),
                      const Icon(Icons.more_horiz_rounded, size: 13, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) return const SizedBox.shrink();
        return ElevatedButton.icon(
          key: ValueKey('rate-booking-${booking.id}'),
          onPressed: () => showRateBookingDialog(context, booking, service: widget.service),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
          icon: const Icon(Icons.star_rounded, size: 16),
          label: Text(l.reviewsRateAction, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }
}
