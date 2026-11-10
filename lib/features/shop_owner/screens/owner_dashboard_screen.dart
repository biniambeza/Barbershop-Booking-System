import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../common/screens/location_picker_screen.dart';
import 'manage_services_screen.dart';
import 'manage_barbers_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final user = repo.currentUser;
    final shopId = user?.shopId ?? 'shop_1';
    final shop = repo.getShopById(shopId) ?? repo.getShops().first;
    final bookings = repo.getShopBookings(shop.id);
    final barbers = repo.getBarbersForShop(shop.id);
    final services = repo.getServicesForShop(shop.id);

    // Calculate metrics
    final totalRevenue = bookings.fold<double>(0.0, (sum, b) => sum + (b.status != BookingStatus.cancelled ? b.price : 0));
    final confirmedCount = bookings.where((b) => b.status == BookingStatus.confirmed).length;

    final filteredBookings = bookings.where((b) {
      if (_selectedFilter == 'Confirmed') return b.status == BookingStatus.confirmed;
      if (_selectedFilter == 'Completed') return b.status == BookingStatus.completed;
      if (_selectedFilter == 'Cancelled') return b.status == BookingStatus.cancelled;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shop.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Partner Business Portal',
              style: TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Switch to Customer View
          TextButton.icon(
            onPressed: () {
              repo.switchRole(UserRole.customer);
            },
            icon: const Icon(Icons.person, size: 18, color: AppTheme.primaryGold),
            label: const Text('Client View', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => repo.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Navigation shortcuts
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ManageServicesScreen(shopId: shop.id)),
                      ).then((_) => setState(() {}));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkCard,
                      foregroundColor: AppTheme.primaryGold,
                      side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                    ),
                    icon: const Icon(Icons.content_cut, size: 18),
                    label: Text('Services (${services.length})', style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ManageBarbersScreen(shopId: shop.id)),
                      ).then((_) => setState(() {}));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkCard,
                      foregroundColor: AppTheme.primaryGold,
                      side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                    ),
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: Text('Barbers (${barbers.length})', style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Shop Map Location Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.address,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pinned at: ${shop.latitude.toStringAsFixed(4)}, ${shop.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryGold),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () async {
                      final result = await Navigator.push<LocationPickerResult>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationPickerScreen(
                            initialLatitude: shop.latitude,
                            initialLongitude: shop.longitude,
                            initialAddress: shop.address,
                          ),
                        ),
                      );
                      if (result != null) {
                        await AppRepository.instance.updateShopLocation(
                          shopId: shop.id,
                          address: result.address,
                          latitude: result.latitude,
                          longitude: result.longitude,
                        );
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.pin_drop, size: 14),
                    label: const Text('Update Map Pin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildMetricCard(
                  title: 'Bookings',
                  value: '${bookings.length}',
                  subtitle: '$confirmedCount active',
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  title: 'Est. Revenue',
                  value: '\$${totalRevenue.toStringAsFixed(0)}',
                  subtitle: 'Gross sales',
                  icon: Icons.attach_money_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Booking Management Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Appointments Schedule',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: AppTheme.darkCard,
                  underline: const SizedBox(),
                  style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredBookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.event_available, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 8),
                    Text('No appointments found', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBookings.length,
                itemBuilder: (context, index) {
                  final booking = filteredBookings[index];
                  return _buildAppointmentAdminCard(context, booking);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
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
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Icon(icon, size: 20, color: AppTheme.primaryGold),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.primaryGold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentAdminCard(BuildContext context, Booking booking) {
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
      margin: const EdgeInsets.only(bottom: 14),
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
              Text(
                booking.customerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.status.name.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.serviceName} • \$${booking.price.toStringAsFixed(0)}',
            style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.content_cut, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('Barber: ${booking.barberName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const Spacer(),
              const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${DateFormat('MMM d').format(booking.date)} at ${booking.timeSlot}', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 20, color: AppTheme.accentSlate),

          // Action Buttons (Mark as Complete / Cancel)
          if (booking.status == BookingStatus.confirmed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      AppRepository.instance.updateBookingStatus(booking.id, BookingStatus.completed);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark Completed', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      AppRepository.instance.updateBookingStatus(booking.id, BookingStatus.cancelled);
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text('Cancel Slot', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
