import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../models/barber_model.dart';
import '../../../services/app_repository.dart';

class BookingFlowScreen extends StatefulWidget {
  final Barbershop shop;
  final BarbershopService initialService;
  final Barber initialBarber;

  const BookingFlowScreen({
    super.key,
    required this.shop,
    required this.initialService,
    required this.initialBarber,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  late BarbershopService _selectedService;
  late Barber _selectedBarber;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  bool _isSubmitting = false;

  final List<String> _timeSlots = [
    '09:00 AM',
    '09:45 AM',
    '10:30 AM',
    '11:15 AM',
    '12:00 PM',
    '01:30 PM',
    '02:15 PM',
    '03:00 PM',
    '03:45 PM',
    '04:30 PM',
    '05:15 PM',
    '06:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService;
    _selectedBarber = widget.initialBarber;
    _selectedTimeSlot = _timeSlots[2]; // Default 10:30 AM
  }

  Future<void> _confirmBooking() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an appointment time slot.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final booking = await AppRepository.instance.createBooking(
        shopId: widget.shop.id,
        shopName: widget.shop.name,
        barberId: _selectedBarber.id,
        barberName: _selectedBarber.name,
        serviceId: _selectedService.id,
        serviceName: _selectedService.name,
        price: _selectedService.price,
        date: _selectedDate,
        timeSlot: _selectedTimeSlot!,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 54, color: AppTheme.primaryGold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Your seat with ${booking.barberName} is reserved.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Shop', booking.shopName),
                    _buildReceiptRow('Service', booking.serviceName),
                    _buildReceiptRow('Date', DateFormat('EEE, MMM d').format(booking.date)),
                    _buildReceiptRow('Time', booking.timeSlot),
                    _buildReceiptRow('Total', '\$${booking.price.toStringAsFixed(0)}', isHighlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // dismiss dialog
                  Navigator.of(context).pop(); // return to detail or home
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppTheme.primaryGold : AppTheme.textPrimary,
              fontSize: isHighlight ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final allServices = repo.getServicesForShop(widget.shop.id);
    final allBarbers = repo.getBarbersForShop(widget.shop.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Appointment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Summary Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.shop.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 50, height: 50, color: AppTheme.darkSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${widget.shop.address}, ${widget.shop.city}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Step 1: Barber Selection
            Text('1. Choose Barber', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allBarbers.length,
                itemBuilder: (context, index) {
                  final barber = allBarbers[index];
                  final isSelected = _selectedBarber.id == barber.id;
                  return InkWell(
                    onTap: () => setState(() => _selectedBarber = barber),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGold.withValues(alpha: 0.15) : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryGold : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                            onBackgroundImageError: barber.avatarUrl != null ? (error, stackTrace) {} : null,
                            backgroundColor: AppTheme.primaryGold,
                            child: barber.avatarUrl == null ? Text(barber.name.substring(0, 1), style: const TextStyle(color: Colors.black)) : null,
                          ),
                          const SizedBox(height: 4),
                          Text(barber.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Step 2: Service Selection
            Text('2. Selected Service', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allServices.map((service) {
                  final isSelected = _selectedService.id == service.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${service.name} (\$${service.price.toStringAsFixed(0)})'),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryGold,
                      onSelected: (val) {
                        if (val) setState(() => _selectedService = service);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Step 3: Date Picker
            Text('3. Select Date', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = DateUtils.isSameDay(_selectedDate, date);
                  final dayName = DateFormat('EEE').format(date);
                  final dayNum = DateFormat('d').format(date);

                  return InkWell(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      width: 65,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryGold : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Step 4: Time Slot
            Text('4. Available Time Slots', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _timeSlots.map((slot) {
                final isSelected = _selectedTimeSlot == slot;
                return InkWell(
                  onTap: () => setState(() => _selectedTimeSlot = slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGold : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      slot,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.black : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Total Card & CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total to Pay at Salon:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      Text(
                        '\$${_selectedService.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _confirmBooking,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Text('Confirm Appointment'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
