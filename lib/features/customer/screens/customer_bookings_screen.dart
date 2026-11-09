import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';

class CustomerBookingsScreen extends StatelessWidget {
  const CustomerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final currentUserId = repo.currentUser?.uid ?? 'user_cust_1';
    final bookings = repo.getCustomerBookings(currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
      ),
      body: bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No bookings yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Explore top barbershops and book your first slot.', style: TextStyle(color: AppTheme.textSecondary)),
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
    Color statusColor;
    switch (booking.status) {
      case BookingStatus.confirmed:
        statusColor = Colors.green;
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
                  booking.status.name.toUpperCase(),
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('Barber: ${booking.barberName}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${DateFormat('EEEE, MMM d, y').format(booking.date)} at ${booking.timeSlot}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.accentSlate),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${booking.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
              ),
              if (booking.status != BookingStatus.cancelled && booking.status != BookingStatus.completed)
                OutlinedButton(
                  onPressed: () {
                    AppRepository.instance.updateBookingStatus(booking.id, BookingStatus.cancelled);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: const Text('Cancel Booking', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
