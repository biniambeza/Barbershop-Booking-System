import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/reviews_service.dart';
import 'rate_booking_dialog.dart';
import 'review_widgets.dart';

/// My Appointments: on a completed booking of the signed-in customer, a
/// "Rate visit" button (key `rate-booking-{id}`) until it is reviewed, then
/// the stars they gave (key `my-review-{id}`). Shows nothing for other
/// bookings.
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
          return Container(
            key: ValueKey('my-review-${booking.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.orangeSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.reviewsYourRating, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(width: 6),
                StarRatingDisplay(rating: review.rating.toDouble(), size: 13),
              ],
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
