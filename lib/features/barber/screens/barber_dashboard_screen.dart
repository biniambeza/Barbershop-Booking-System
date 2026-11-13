import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../data/addis_time.dart';
import '../../../l10n/l10n.dart';
import '../../reviews/reviews_l10n.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/persona_switcher.dart';
import '../../payments/widgets/payment_status_badge.dart';
import 'barber_schedule_screen.dart';
import '../../queue/queue_dashboard_card.dart';
import '../../reviews/widgets/reviews_dashboard_entries.dart';
import '../../../services/booking_policy.dart';
import '../../shared/widgets/no_show_dialog.dart';
import '../../shared/widgets/ui_kit.dart';

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

  /// Bookings with a status change in flight (their buttons are disabled).
  final Set<String> _busy = {};

  /// Runs a booking status change and reports a failure (e.g. a rules rejection).
  Future<void> _setStatus(AppRepository repo, String bookingId, BookingStatus status) async {
    if (_busy.contains(bookingId)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(bookingId));
    try {
      await repo.updateBookingStatus(bookingId, status);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.statusUpdateFailed(l.errorText(e)))));
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
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

        final l = context.l10n;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Row(
              children: [
                const IconTile(icon: Icons.content_cut, size: 36),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(l.barberWorkspace,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            actions: [
              if (kDemoMode)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.tealSoft,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => showPersonaSwitcher(context, current: UserRole.barber),
                  icon: const Icon(Icons.swap_horiz, size: 16, color: AppTheme.teal),
                  label: Text(
                    l.roleBarber,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.teal),
                  ),
                ),
              const LanguageToggle(),
              const NotificationBell(),
              IconButton(
                tooltip: l.signOut,
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () => repo.signOut(),
              ),
            ],
          ),
          body: barber == null
              ? Center(child: Text(l.noBarberProfile))
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
                              QueueDashboardCard(shopId: barber.shopId),
                              BarberReviewsCard(barber: barber),
                            ],
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabBarHeaderDelegate(
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            indicatorSize: TabBarIndicatorSize.label,
                            indicatorColor: AppTheme.ink,
                            labelColor: AppTheme.textPrimary,
                            unselectedLabelColor: AppTheme.textSecondary,
                            labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                            unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                            tabs: [
                              Tab(text: l.tabConfirmed(upcomingBookings.length)),
                              Tab(text: l.tabInProgress(inProgressBookings.length)),
                              Tab(text: l.tabCompleted(completedBookings.length)),
                              Tab(text: l.tabAll(bookings.length)),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsList(upcomingBookings, repo, emptyMsg: l.emptyConfirmed),
                      _buildBookingsList(inProgressBookings, repo, emptyMsg: l.emptyInProgress),
                      _buildBookingsList(completedBookings, repo, emptyMsg: l.emptyCompleted),
                      _buildBookingsList(bookings, repo, emptyMsg: l.emptyHistory),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBarberProfileCard(Barber barber, Barbershop? shop, AppRepository repo) {
    return HeroCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.charcoal,
                  foregroundColor: AppTheme.onInk,
                  backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                  child: barber.avatarUrl == null ? const Icon(Icons.person, size: 28) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      barber.name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.onInk, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      barber.title,
                      style: const TextStyle(fontSize: 13, color: AppTheme.onInkMuted, fontWeight: FontWeight.w500),
                    ),
                    if (shop != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 14, color: AppTheme.onInkMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shop.name,
                              style: const TextStyle(fontSize: 12, color: AppTheme.onInkMuted),
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
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.reviewsRatingValue(barber.rating, barber.reviewCount),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.onInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Availability Toggle Row
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: barber.isAvailable ? AppTheme.green : AppTheme.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          barber.isAvailable ? context.l10n.statusOnDuty : context.l10n.statusOnBreak,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: barber.isAvailable ? const Color(0xFF6EE08F) : const Color(0xFFFFB066),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: barber.isAvailable,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.green,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  onChanged: (val) {
                    repo.updateBarberAvailability(barber.id, val);
                  },
                ),
              ],
            ),
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
    final l = context.l10n;
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildMetricTile(
            title: l.metricAppointments,
            value: '$todayAppointmentsCount',
            icon: Icons.calendar_today_outlined,
            color: AppTheme.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: l.metricInChair,
            value: '$inProgressCount',
            icon: Icons.chair_outlined,
            color: AppTheme.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: l.statusCompleted,
            value: '$completedCount',
            icon: Icons.check_circle_outline,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: l.metricEarnings,
            value: context.fmt.birr(totalEarnings),
            icon: Icons.payments_outlined,
            color: AppTheme.success,
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: AppTheme.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, size: 34),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleQuickAction(BuildContext context, Barber barber) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: const IconTile(icon: Icons.schedule, color: AppTheme.blue, size: 44),
        title: Text(
          context.l10n.viewWeeklySchedule,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
        ),
        subtitle: Text(context.l10n.viewWeeklyScheduleSubtitle,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
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
    final l = context.l10n;
    final fmt = context.fmt;

    switch (booking.status) {
      case BookingStatus.confirmed:
        statusColor = AppTheme.success;
        statusLabel = l.statusConfirmed;
        break;
      case BookingStatus.inProgress:
        statusColor = AppTheme.blue;
        statusLabel = l.metricInChair;
        break;
      case BookingStatus.completed:
        statusColor = AppTheme.ink;
        statusLabel = l.statusCompleted;
        break;
      case BookingStatus.cancelled:
        statusColor = AppTheme.danger;
        statusLabel = l.statusCancelled;
        break;
      case BookingStatus.noShow:
        statusColor = AppTheme.slate;
        statusLabel = l.statusNoShow;
        break;
      case BookingStatus.pending:
        statusColor = AppTheme.warning;
        statusLabel = l.statusPending;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surface),
                      child: const Icon(Icons.person_outline, size: 18, color: AppTheme.ink),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        booking.customerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: statusLabel,
                color: statusColor,
                background: booking.status == BookingStatus.completed ? AppTheme.slateSoft : null,
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
                fmt.birr(booking.price),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          PaymentStatusBadge(booking: booking),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${fmt.bookingTime(booking)} • ${_formatDate(fmt, booking)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              if (booking.customerPhone.isNotEmpty) ...[
                const Icon(Icons.phone, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  formatEthiopianPhone(booking.customerPhone),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.hairline),
          const SizedBox(height: 10),

          // Dynamic Action Buttons according to workflow
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (booking.status == BookingStatus.confirmed) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.hairline),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: Icon(canMarkNoShow(booking, repo.nowUtc()) ? Icons.person_off_rounded : Icons.close, size: 15),
                  label: Text(canMarkNoShow(booking, repo.nowUtc()) ? l.noShowAction : l.cancelBooking,
                      style: const TextStyle(fontSize: 11)),
                  key: ValueKey('barber-no-show-${booking.id}'),
                  onPressed: _busy.contains(booking.id)
                      ? null
                      : () async {
                          if (!canMarkNoShow(booking, repo.nowUtc())) {
                            await _setStatus(repo, booking.id, BookingStatus.cancelled);
                          } else if (await confirmNoShow(context, booking) && mounted) {
                            await _setStatus(repo, booking.id, BookingStatus.noShow);
                          }
                        },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.chair, size: 16),
                  label: Text(l.startService, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _busy.contains(booking.id) ? null : () => _setStatus(repo, booking.id, BookingStatus.inProgress),
                ),
              ] else if (booking.status == BookingStatus.inProgress) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: AppTheme.onInk,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: Text(l.markCompleted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _busy.contains(booking.id) ? null : () => _setStatus(repo, booking.id, BookingStatus.completed),
                ),
              ] else if (booking.status == BookingStatus.completed) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                    SizedBox(width: 4),
                    Text(l.serviceCompleted,
                        style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold)),
                  ],
                ),
              ] else if (booking.status == BookingStatus.noShow) ...[
                Text(l.statusNoShow, style: const TextStyle(fontSize: 11, color: AppTheme.slate)),
              ] else ...[
                Text(l.appointmentCancelled, style: const TextStyle(fontSize: 11, color: AppTheme.danger)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 'Today' or the Addis calendar date of the booking.
  String _formatDate(AppFormats fmt, Booking booking) {
    final day = fmt.bookingDay(booking);
    final today = addisNow();
    if (day.year == today.year && day.month == today.month && day.day == today.day) {
      return context.l10n.today;
    }
    return fmt.dateMedium(day);
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
      color: AppTheme.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeaderDelegate oldDelegate) {
    return false;
  }
}
