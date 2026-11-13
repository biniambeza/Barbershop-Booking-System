import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/booking_policy.dart' show canMarkNoShow;
import '../../shared/widgets/no_show_dialog.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/persona_switcher.dart';
import 'manage_services_screen.dart';
import 'manage_barbers_screen.dart';
import 'customize_shop_screen.dart';
import 'owner_subscription_screen.dart';
import '../../payments/widgets/payment_status_badge.dart';
import '../../payments/widgets/subscription_banner.dart';
import '../../queue/queue_dashboard_card.dart';
import '../../reports/screens/owner_reports_screen.dart';
import '../../reviews/widgets/reviews_dashboard_entries.dart';

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
    final shop = repo.getShopById(shopId);
    final l = context.l10n;
    final fmt = context.fmt;
    if (shop == null) {
      // Not loaded yet, or the shop was removed by the platform admin.
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.shopNotLoaded),
              const SizedBox(height: 12),
              TextButton(onPressed: repo.signOut, child: Text(l.signOutLower)),
            ],
          ),
        ),
      );
    }
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
            Text(
              l.partnerPortal,
              style: const TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (kDemoMode)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryGold),
              tooltip: l.switchRole,
              onPressed: () => showPersonaSwitcher(context, current: UserRole.barbershopOwner),
            ),
          const LanguageToggle(),
          const NotificationBell(),
          IconButton(
            tooltip: l.signOut,
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
            // Subscription warning (past due / suspended / ending soon)
            SubscriptionBanner(shop: shop, onManage: () => _openSubscription(shop.id)),

            // Walk-in queue
            QueueDashboardCard(shopId: shop.id),

            // Customize Barbershop Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold.withValues(alpha: 0.2),
                    AppTheme.darkCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.dashboard_customize, color: AppTheme.primaryGold, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.customizableApp,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.customizableAppSubtitle,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CustomizeShopScreen(shop: shop)),
                      ).then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text(l.customize),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

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
                    label: Text(l.servicesButton(services.length), style: const TextStyle(fontSize: 13)),
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
                    label: Text(l.manageBarbersButton(barbers.length), style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Reports (functions/insights stats; computed locally in demo mode)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('open-reports'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OwnerReportsScreen(shopId: shop.id)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: Text(l.reportsOpenButton, style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 14),

            // Reviews and owner replies
            OwnerReviewsButton(shopId: shop.id),

            // Platform subscription
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('open-subscription'),
                onPressed: () => _openSubscription(shop.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: Text(l.subscriptionAndBilling, style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 14),

            // Shop Map Location Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
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
                          shop.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.shopAddress(shop),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomizeShopScreen(shop: shop),
                        ),
                      );
                      setState(() {});
                    },
                    icon: const Icon(Icons.edit, size: 14),
                    label: Text(l.editInfo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildMetricCard(
                  title: l.metricBookings,
                  value: '${bookings.length}',
                  subtitle: l.activeCount(confirmedCount),
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  title: l.metricEstRevenue,
                  value: fmt.birr(totalRevenue),
                  subtitle: l.metricGrossSales,
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Booking Management Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.appointmentsSchedule,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: AppTheme.darkCard,
                  underline: const SizedBox(),
                  style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  items: [
                    DropdownMenuItem(value: 'All', child: Text(l.all)),
                    DropdownMenuItem(value: 'Confirmed', child: Text(l.statusConfirmed)),
                    DropdownMenuItem(value: 'Completed', child: Text(l.statusCompleted)),
                    DropdownMenuItem(value: 'Cancelled', child: Text(l.statusCancelled)),
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
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 8),
                    Text(l.noAppointmentsFound, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _openSubscription(String shopId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OwnerSubscriptionScreen(shopId: shopId)),
    ).then((_) {
      if (mounted) setState(() {});
    });
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

  /// Bookings with a status change in flight (their buttons are disabled).
  final Set<String> _busy = {};

  /// Runs a status change and reports a failure (e.g. a rules rejection).
  Future<void> _setStatus(Booking booking, BookingStatus status) async {
    if (_busy.contains(booking.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(booking.id));
    try {
      await AppRepository.instance.updateBookingStatus(booking.id, status);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.statusUpdateFailed(l.errorText(e)))));
    } finally {
      if (mounted) setState(() => _busy.remove(booking.id));
    }
  }

  Widget _buildAppointmentAdminCard(BuildContext context, Booking booking) {
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
      case BookingStatus.noShow:
        statusColor = Colors.deepOrangeAccent;
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
                  l.bookingStatus(booking.status).toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.serviceAndPrice(booking.serviceName, fmt.birr(booking.price)),
            style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          PaymentStatusBadge(booking: booking),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.content_cut, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.barberLabel(booking.barberName),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(l.dateAtTime(fmt.monthDay(fmt.bookingDay(booking)), fmt.bookingTime(booking)), style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 20, color: AppTheme.accentSlate),

          // Action Buttons (Mark as Complete / Cancel)
          if (booking.status == BookingStatus.confirmed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy.contains(booking.id) ? null : () => _setStatus(booking, BookingStatus.completed),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l.markCompleted, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy.contains(booking.id) ? null : () => _setStatus(booking, BookingStatus.cancelled),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: Text(l.cancelSlot, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                // No-show: only once the appointment time has come.
                if (canMarkNoShow(booking, AppRepository.instance.nowUtc())) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('owner-no-show-${booking.id}'),
                      onPressed: _busy.contains(booking.id)
                          ? null
                          : () async {
                              if (await confirmNoShow(context, booking) && mounted) {
                                await _setStatus(booking, BookingStatus.noShow);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor: Colors.deepOrangeAccent,
                        side: const BorderSide(color: Colors.deepOrangeAccent),
                      ),
                      child: Text(l.noShowAction, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
