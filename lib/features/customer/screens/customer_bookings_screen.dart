import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../models/service_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/booking_policy.dart';
import '../../../services/booking_acceptance.dart' as acceptance;
import '../../../services/payment_service.dart';
import '../../payments/payment_flow.dart';
import '../../payments/widgets/payment_status_badge.dart';
import '../../reviews/widgets/booking_review_action.dart';
import 'booking_flow_screen.dart';
import '../widgets/early_finish_banner.dart'; // early finish
import '../widgets/rebook_widgets.dart'; // favourite barbers & rebook

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
                  // Green-tinted circle: the white + green / black + green look.
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: AppTheme.greenSoft, shape: BoxShape.circle),
                    child: Icon(Icons.calendar_month_outlined, size: 44, color: AppTheme.success),
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.noBookingsYet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(context.l10n.noBookingsHint, style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, AppBottomNavBar.contentPadding),
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
        return AppTheme.success;
      case BookingStatus.inProgress:
        return AppTheme.blue;
      case BookingStatus.pending:
        return AppTheme.warning;
      case BookingStatus.completed:
        // Teal: done, and different from the green "confirmed".
        return AppTheme.teal;
      case BookingStatus.cancelled:
        return AppTheme.danger;
      case BookingStatus.noShow:
        return AppTheme.slate;
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
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.shopName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(
                key: ValueKey('booking-status-${booking.id}'),
                // barber acceptance: a pending booking waits for the barber
                label: (acceptance.isUnansweredExpiredRequest(booking, now) // free plan
                        ? l.freePlanRequestNoAnswer
                        : acceptance.isAwaitingAcceptance(booking)
                            ? l.acceptWaitingForBarber
                            : l.bookingStatus(booking.status))
                    .toUpperCase(),
                color: color,
                icon: acceptance.isAwaitingAcceptance(booking) ? Icons.hourglass_top_rounded : null,
              ),
            ],
          ),
          // --- barber acceptance: why a request ended ---
          // free plan: still pending but expired (nobody closed it yet)
          if (acceptance.isUnansweredExpiredRequest(booking, now)) ...[
            const SizedBox(height: 6),
            Text(l.acceptExpiredNote,
                key: ValueKey('request-expired-${booking.id}'),
                style: TextStyle(fontSize: 12, color: AppTheme.danger)),
          ] else if (acceptance.isAwaitingAcceptance(booking)) ...[
            const SizedBox(height: 6),
            Text(l.acceptWaitingFor(booking.barberName),
                style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600)),
          ] else if (acceptance.wasDeclined(booking) || acceptance.wasNotAccepted(booking)) ...[
            const SizedBox(height: 6),
            Text(
              acceptance.wasDeclined(booking) ? l.acceptDeclinedNote : l.acceptExpiredNote,
              key: ValueKey('request-ended-${booking.id}'),
              style: TextStyle(fontSize: 12, color: AppTheme.danger),
            ),
            if (booking.declineReason != null && acceptance.wasDeclined(booking))
              Text(l.acceptDeclineReasonNote(booking.declineReason!),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  booking.serviceName,
                  style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              if (booking.rescheduleCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  key: ValueKey('rescheduled-badge-${booking.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.blueSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(l.rescheduledBadge, style: TextStyle(fontSize: 10, color: AppTheme.blue)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          PaymentStatusBadge(booking: booking),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(l.barberLabel(booking.barberName),
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ),
              // favourite barbers & rebook: favourite the barber of a past visit.
              if (booking.status == BookingStatus.completed)
                FavoriteBarberButton.ids(
                  barberId: booking.barberId,
                  shopId: booking.shopId,
                  barberName: booking.barberName,
                  size: 18,
                ),
            ],
          ),
          // --- private barber phone: only on a confirmed booking ---
          if (booking.visibleBarberPhone != null) _BarberPhoneRow(booking: booking),
          // --- end private barber phone ---
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.dateAtTime(fmt.dayLong(fmt.bookingDay(booking)), fmt.bookingTime(booking)),
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          // --- early finish: the barber is free now, come in early ---
          if (upcoming) EarlyFinishBanner(booking: booking, shop: shop, now: _now),
          // --- end early finish ---
          if (upcoming && shop != null) ...[
            const SizedBox(height: 8),
            Text(
              isBeforeCutoff(booking, shop, now)
                  ? '${l.reschedulePolicyNote(shop.cancellationCutoffHours)} ${l.rescheduleLeft(reschedulesLeft(booking, shop))}'
                  : l.rescheduleCallShop,
              key: ValueKey('policy-note-${booking.id}'),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
          Divider(height: 24, color: AppTheme.hairline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fmt.birr(booking.price),
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
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
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        ),
                        child: Text(
                          booking.paymentStatus == PaymentStatus.pending ? l.finishPayment : l.payNow,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (booking.status == BookingStatus.completed)
                      BookingReviewAction(key: ValueKey('review-action-${booking.id}'), booking: booking),
                    // favourite barbers & rebook
                    if (booking.status == BookingStatus.completed) BookAgainButton(booking: booking, clock: clock),
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

// --- private barber phone ---
/// The barber's phone on a confirmed (or in-progress) booking, with a call
/// button. Barber profiles are public, so the number is not on them: the
/// staff app copies it into the booking once it is confirmed
/// ([Booking.visibleBarberPhone]).
class _BarberPhoneRow extends StatelessWidget {
  const _BarberPhoneRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phone = booking.visibleBarberPhone!;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.barberPhoneOnBooking(context.fmt.phone(phone)),
              key: ValueKey('barber-phone-${booking.id}'),
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          TextButton.icon(
            key: ValueKey('call-barber-${booking.id}'),
            onPressed: () async {
              final uri = Uri(scheme: 'tel', path: phone);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Could not open $uri: $e');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.success,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.call_rounded, size: 16),
            label: Text(l.callBarberAction(booking.barberName), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
// --- end private barber phone ---

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
        foregroundColor: AppTheme.success,
        side: BorderSide(color: AppTheme.hairline),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        foregroundColor: AppTheme.danger,
        side: BorderSide(color: AppTheme.hairline),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      child: _busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(context.l10n.cancelBooking, style: const TextStyle(fontSize: 12)),
    );
  }
}
