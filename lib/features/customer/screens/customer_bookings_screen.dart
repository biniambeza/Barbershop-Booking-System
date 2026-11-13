import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../models/service_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/booking_policy.dart';
import '../../../services/payment_service.dart';
import '../../payments/payment_flow.dart';
import '../../payments/widgets/payment_status_badge.dart';
import '../../reviews/widgets/booking_review_action.dart';
import 'booking_flow_screen.dart';

/// My Appointments: every booking of the signed-in customer, with pay,
/// reschedule and cancel actions. The shop's policy (cancellation cutoff
/// and reschedule limit, booking_policy.dart) is shown on each upcoming
/// booking and enforced before anything is written.
class CustomerBookingsScreen extends StatelessWidget {
  const CustomerBookingsScreen({super.key, this.clock});

  /// Overrides the clock (tests).
  final DateTime Function()? clock;

  DateTime _now() => (clock?.call() ?? AppRepository.instance.nowUtc()).toUtc();

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    // Rebuild on live changes (e.g. paymentStatus turning 'paid').
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => _buildScaffold(context, repo),
    );
  }

  Widget _buildScaffold(BuildContext context, AppRepository repo) {
    final currentUserId = repo.currentUser?.uid ?? 'user_cust_1';
    final bookings = repo.getCustomerBookings(currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.myAppointments),
      ),
      body: bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(context.l10n.noBookingsYet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(context.l10n.noBookingsHint, style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return _buildBookingCard(context, repo, booking);
              },
            ),
    );
  }

  static Color statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.inProgress:
        return Colors.orangeAccent;
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.completed:
        return AppTheme.primaryGold;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.noShow:
        return Colors.deepOrangeAccent;
    }
  }

  Widget _buildBookingCard(BuildContext context, AppRepository repo, Booking booking) {
    final l = context.l10n;
    final fmt = context.fmt;
    final color = statusColor(booking.status);
    final shop = repo.getShopById(booking.shopId);
    final now = _now();
    final upcoming = isChangeableStatus(booking.status) && booking.startAt.isAfter(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.shopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  l.bookingStatus(booking.status).toUpperCase(),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  booking.serviceName,
                  style: const TextStyle(fontSize: 14, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                ),
              ),
              if (booking.rescheduleCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  key: ValueKey('rescheduled-badge-${booking.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(l.rescheduledBadge, style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          PaymentStatusBadge(booking: booking),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(l.barberLabel(booking.barberName), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.dateAtTime(fmt.dayLong(fmt.bookingDay(booking)), fmt.bookingTime(booking)),
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (upcoming && shop != null) ...[
            const SizedBox(height: 8),
            Text(
              isBeforeCutoff(booking, shop, now)
                  ? '${l.reschedulePolicyNote(shop.cancellationCutoffHours)} ${l.rescheduleLeft(reschedulesLeft(booking, shop))}'
                  : l.rescheduleCallShop,
              key: ValueKey('policy-note-${booking.id}'),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
          const Divider(height: 24, color: AppTheme.accentSlate),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fmt.birr(booking.price),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (canPayBookingOnline(booking))
                      ElevatedButton(
                        key: ValueKey('pay-booking-${booking.id}'),
                        onPressed: () => payForBooking(context, booking),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                        child: Text(
                          booking.paymentStatus == PaymentStatus.pending ? l.finishPayment : l.payNow,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (booking.status == BookingStatus.completed)
                      BookingReviewAction(key: ValueKey('review-action-${booking.id}'), booking: booking),
                    if (upcoming) _RescheduleButton(booking: booking, now: _now),
                    if (booking.status != BookingStatus.cancelled &&
                        booking.status != BookingStatus.completed &&
                        booking.status != BookingStatus.noShow)
                      _CancelBookingButton(booking: booking, now: _now),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  final l = context.l10n;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l.errorText(error))));
}

/// Opens the booking flow's slot picker for the same barber and service.
/// The shop's cutoff and reschedule limit are checked first (with the
/// localized reason if it is too late or the limit is reached).
class _RescheduleButton extends StatelessWidget {
  const _RescheduleButton({required this.booking, required this.now});

  final Booking booking;
  final DateTime Function() now;

  Future<void> _open(BuildContext context) async {
    final repo = AppRepository.instance;
    final shop = repo.getShopById(booking.shopId);
    final barber = repo.getBarberById(booking.barberId);
    if (shop == null || barber == null) {
      _showError(context, AppStateException(AppErrorCode.bookingNotChangeable));
      return;
    }
    final blocker = rescheduleBlocker(booking, shop, now());
    if (blocker != null) {
      _showError(context, blocker);
      return;
    }
    // Same service and duration as booked, even if the shop changed it since.
    final service = repo.getServiceById(booking.serviceId) ??
        BarbershopService(
          id: booking.serviceId,
          shopId: booking.shopId,
          name: booking.serviceName,
          description: '',
          price: booking.price,
          durationMinutes: booking.durationMinutes,
        );
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => BookingFlowScreen(
        shop: shop,
        initialService: service,
        initialBarber: barber,
        rescheduling: booking,
        clock: now,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: ValueKey('reschedule-booking-${booking.id}'),
      onPressed: () => _open(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryGold,
        side: const BorderSide(color: AppTheme.primaryGold),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      child: Text(context.l10n.rescheduleAction, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Cancels the booking; inside the shop's cutoff it
/// shows the localized policy message instead. Disabled while the request
/// is in flight and shows a translated error if it fails.
class _CancelBookingButton extends StatefulWidget {
  const _CancelBookingButton({required this.booking, required this.now});

  final Booking booking;
  final DateTime Function() now;

  @override
  State<_CancelBookingButton> createState() => _CancelBookingButtonState();
}

class _CancelBookingButtonState extends State<_CancelBookingButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final booking = widget.booking;
    final shop = AppRepository.instance.getShopById(booking.shopId);
    final blocker = shop == null ? null : cancelBlocker(booking, shop, widget.now());
    if (blocker != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.errorText(blocker))));
      return;
    }
    setState(() => _busy = true);
    try {
      await AppRepository.instance.updateBookingStatus(booking.id, BookingStatus.cancelled);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.cancelBookingFailed(l.errorText(e)))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: ValueKey('cancel-booking-${widget.booking.id}'),
      onPressed: _busy ? null : _cancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      child: _busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(context.l10n.cancelBooking, style: const TextStyle(fontSize: 12)),
    );
  }
}
