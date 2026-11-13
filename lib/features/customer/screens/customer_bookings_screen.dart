import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/payment_service.dart';
import '../../payments/payment_flow.dart';
import '../../payments/widgets/payment_status_badge.dart';

class CustomerBookingsScreen extends StatelessWidget {
  const CustomerBookingsScreen({super.key});

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
                return _buildBookingCard(context, booking);
              },
            ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Booking booking) {
    final l = context.l10n;
    final fmt = context.fmt;
    Color statusColor;
    switch (booking.status) {
      case BookingStatus.confirmed:
        statusColor = Colors.green;
        break;
      case BookingStatus.inProgress:
        statusColor = Colors.orangeAccent;
        break;
      case BookingStatus.pending:
        statusColor = Colors.orange;
        break;
      case BookingStatus.completed:
        statusColor = AppTheme.primaryGold;
        break;
      case BookingStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

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
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  l.bookingStatus(booking.status).toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.serviceName,
            style: const TextStyle(fontSize: 14, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
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
          const Divider(height: 24, color: AppTheme.accentSlate),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fmt.birr(booking.price),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
              ),
              Wrap(
                spacing: 8,
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
                  if (booking.status != BookingStatus.cancelled && booking.status != BookingStatus.completed)
                    OutlinedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await AppRepository.instance.updateBookingStatus(booking.id, BookingStatus.cancelled);
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text(l.cancelBookingFailed('$e'))));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      child: Text(l.cancelBooking, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
