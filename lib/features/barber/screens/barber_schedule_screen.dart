import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barber_model.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';

class BarberScheduleScreen extends StatefulWidget {
  final Barber barber;

  const BarberScheduleScreen({super.key, required this.barber});

  @override
  State<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends State<BarberScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  final List<String> _allSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final allBookings = repo.getBookingsForBarber(widget.barber.id);
        final dayBookings = allBookings.where((b) {
          return b.date.year == _selectedDate.year &&
              b.date.month == _selectedDate.month &&
              b.date.day == _selectedDate.day;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.barber.name} • Schedule'),
          ),
          body: Column(
            children: [
              _buildDateSelector(),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _allSlots[index];
                    final bookingForSlot = dayBookings.where((b) => b.timeSlot.trim().toUpperCase() == slot.trim().toUpperCase()).firstOrNull;

                    return _buildTimelineSlot(slot, bookingForSlot);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i)));

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppTheme.darkCard,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = day),
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGold : Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGold : Colors.white12,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayName(day.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineSlot(String time, Booking? booking) {
    final isBooked = booking != null;
    Color slotColor = isBooked ? Colors.lightBlueAccent : Colors.grey;

    if (booking?.status == BookingStatus.completed) {
      slotColor = Colors.greenAccent;
    } else if (booking?.status == BookingStatus.inProgress) {
      slotColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              time,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBooked ? AppTheme.darkCard : Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isBooked ? slotColor.withValues(alpha: 0.5) : Colors.white12,
                ),
              ),
              child: isBooked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking.customerName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: slotColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                booking.status.displayName,
                                style: TextStyle(fontSize: 10, color: slotColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${booking.serviceName} • \$${booking.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold),
                        ),
                      ],
                    )
                  : const Text(
                      'Available Slot',
                      style: TextStyle(fontSize: 12, color: Colors.white30, fontStyle: FontStyle.italic),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}
