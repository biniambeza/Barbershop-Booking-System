import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import 'barber_schedule_screen.dart';

class BarberDashboardScreen extends StatefulWidget {
  const BarberDashboardScreen({super.key});

  @override
  State<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends State<BarberDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRoleSwitcher(BuildContext context, AppRepository repo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.swap_horiz, color: AppTheme.primaryGold),
                    SizedBox(width: 8),
                    Text(
                      'SaaS Role Switcher',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch persona instantly to test each role',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white),
                  ),
                  title: const Text('Platform Superadmin', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Register shops, oversee analytics, manage users'),
                  onTap: () {
                    Navigator.pop(context);
                    repo.switchRole(UserRole.admin);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryGold,
                    child: Icon(Icons.storefront, color: Colors.black),
                  ),
                  title: const Text('Barbershop Owner', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Manage The Gentleman's Quarter shop & staff"),
                  onTap: () {
                    Navigator.pop(context);
                    repo.switchRole(UserRole.barbershopOwner);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.tealAccent,
                    child: Icon(Icons.content_cut, color: Colors.black),
                  ),
                  title: const Text('Staff Barber (Active)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('View appointments, update cut queue, track earnings'),
                  trailing: const Icon(Icons.check, color: AppTheme.primaryGold),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.lightBlueAccent,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  title: const Text('Client / Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Browse shops, find barbers, book appointments'),
                  onTap: () {
                    Navigator.pop(context);
                    repo.switchRole(UserRole.customer);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final barber = repo.getBarberForCurrentUser();
        final shop = barber != null ? repo.getShopById(barber.shopId) : null;
        final bookings = barber != null ? repo.getBookingsForBarber(barber.id) : <Booking>[];

        final upcomingBookings = bookings.where((b) => b.status == BookingStatus.confirmed).toList();
        final inProgressBookings = bookings.where((b) => b.status == BookingStatus.inProgress).toList();
        final completedBookings = bookings.where((b) => b.status == BookingStatus.completed).toList();
        final totalEarnings = barber != null ? repo.getBarberTotalEarnings(barber.id) : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.content_cut, color: AppTheme.primaryGold, size: 20),
                SizedBox(width: 8),
                Text('Barber Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              if (kDemoMode)
                TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.tealAccent.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _showRoleSwitcher(context, repo),
                icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.tealAccent),
                label: const Text(
                  'Barber',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                ),
              ),
              IconButton(
                tooltip: 'Sign Out',
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () => repo.signOut(),
              ),
            ],
          ),
          body: barber == null
              ? const Center(child: Text('No Barber profile linked to this account.'))
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBarberProfileCard(barber, shop, repo),
                              const SizedBox(height: 16),
                              _buildMetricOverview(
                                todayAppointmentsCount: bookings.length,
                                inProgressCount: inProgressBookings.length,
                                completedCount: completedBookings.length,
                                totalEarnings: totalEarnings,
                              ),
                              const SizedBox(height: 16),
                              _buildScheduleQuickAction(context, barber),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabBarHeaderDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: AppTheme.primaryGold,
                            labelColor: AppTheme.primaryGold,
                            unselectedLabelColor: AppTheme.textSecondary,
                            tabs: [
                              Tab(text: 'Confirmed (${upcomingBookings.length})'),
                              Tab(text: 'In Progress (${inProgressBookings.length})'),
                              Tab(text: 'Completed (${completedBookings.length})'),
                              Tab(text: 'All (${bookings.length})'),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsList(upcomingBookings, repo, emptyMsg: 'No confirmed appointments scheduled.'),
                      _buildBookingsList(inProgressBookings, repo, emptyMsg: 'No appointments currently in progress.'),
                      _buildBookingsList(completedBookings, repo, emptyMsg: 'No completed appointments yet today.'),
                      _buildBookingsList(bookings, repo, emptyMsg: 'No booking history found.'),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBarberProfileCard(Barber barber, Barbershop? shop, AppRepository repo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                child: barber.avatarUrl == null ? const Icon(Icons.person, size: 30) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      barber.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      barber.title,
                      style: const TextStyle(fontSize: 13, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                    ),
                    if (shop != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shop.name,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppTheme.primaryGold, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      barber.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          // Availability Toggle Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: barber.isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    barber.isAvailable ? 'Status: On Duty (Accepting Clients)' : 'Status: On Break / Away',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: barber.isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              Switch(
                value: barber.isAvailable,
                activeThumbColor: Colors.greenAccent,
                activeTrackColor: Colors.green.withValues(alpha: 0.3),
                onChanged: (val) {
                  repo.updateBarberAvailability(barber.id, val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricOverview({
    required int todayAppointmentsCount,
    required int inProgressCount,
    required int completedCount,
    required double totalEarnings,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Appointments',
            value: '$todayAppointmentsCount',
            icon: Icons.calendar_today,
            color: Colors.lightBlueAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'In Chair',
            value: '$inProgressCount',
            icon: Icons.chair,
            color: Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Completed',
            value: '$completedCount',
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Earnings',
            value: '\$${totalEarnings.toStringAsFixed(0)}',
            icon: Icons.attach_money,
            color: AppTheme.primaryGold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleQuickAction(BuildContext context, Barber barber) {
    return Material(
      color: AppTheme.darkCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.schedule, color: AppTheme.primaryGold, size: 20),
        ),
        title: const Text(
          'View Weekly Schedule & Calendar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text('Inspect daily time slots, shifts, and bookings timeline', style: TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BarberScheduleScreen(barber: barber),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> list, AppRepository repo, {required String emptyMsg}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(
                emptyMsg,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final booking = list[index];
        return _buildBookingCard(context, booking, repo);
      },
    );
  }

  Widget _buildBookingCard(BuildContext context, Booking booking, AppRepository repo) {
    Color statusColor;
    String statusLabel;

    switch (booking.status) {
      case BookingStatus.confirmed:
        statusColor = Colors.lightBlueAccent;
        statusLabel = 'Confirmed';
        break;
      case BookingStatus.inProgress:
        statusColor = Colors.orangeAccent;
        statusLabel = 'In Chair';
        break;
      case BookingStatus.completed:
        statusColor = Colors.greenAccent;
        statusLabel = 'Completed';
        break;
      case BookingStatus.cancelled:
        statusColor = Colors.redAccent;
        statusLabel = 'Cancelled';
        break;
      case BookingStatus.pending:
        statusColor = Colors.amber;
        statusLabel = 'Pending';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: AppTheme.primaryGold),
                  const SizedBox(width: 6),
                  Text(
                    booking.customerName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.content_cut, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.serviceName,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '\$${booking.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${booking.timeSlot} • ${_formatDate(booking.date)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              if (booking.customerPhone.isNotEmpty) ...[
                const Icon(Icons.phone, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  booking.customerPhone,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 10),

          // Dynamic Action Buttons according to workflow
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (booking.status == BookingStatus.confirmed) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('No-Show', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    repo.updateBookingStatus(booking.id, BookingStatus.cancelled);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  icon: const Icon(Icons.chair, size: 16),
                  label: const Text('Start Service', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    repo.updateBookingStatus(booking.id, BookingStatus.inProgress);
                  },
                ),
              ] else if (booking.status == BookingStatus.inProgress) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  ),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Mark Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    repo.updateBookingStatus(booking.id, BookingStatus.completed);
                  },
                ),
              ] else if (booking.status == BookingStatus.completed) ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text('Service Completed', style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ] else ...[
                const Text('Appointment Cancelled', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.darkBackground,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) {
    return false;
  }
}
