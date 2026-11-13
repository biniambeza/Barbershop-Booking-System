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
import '../../shared/widgets/ui_kit.dart';
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
    final totalRevenue =
        bookings.fold<double>(0.0, (sum, b) => sum + (b.status != BookingStatus.cancelled ? b.price : 0));
    final confirmedCount = bookings.where((b) => b.status == BookingStatus.confirmed).length;

    final filteredBookings = bookings.where((b) {
      if (_selectedFilter == 'Confirmed') return b.status == BookingStatus.confirmed;
      if (_selectedFilter == 'Completed') return b.status == BookingStatus.completed;
      if (_selectedFilter == 'Cancelled') return b.status == BookingStatus.cancelled;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shop.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l.partnerPortal,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (kDemoMode)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: AppTheme.textPrimary),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription warning (past due / suspended / ending soon)
            SubscriptionBanner(shop: shop, onManage: () => _openSubscription(shop.id)),

            // Summary (hero card)
            HeroCard(
              key: const ValueKey('owner-summary'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.metricEstRevenue,
                          style: const TextStyle(fontSize: 13, color: AppTheme.onInkMuted, fontWeight: FontWeight.w500),
                        ),
                      ),
                      HeroChip(label: l.metricGrossSales, icon: Icons.payments_outlined),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fmt.birr(totalRevenue),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onInk,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.metallicGradient),
                        child: const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.ink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.metricBookings,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.onInkMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${bookings.length}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.onInk),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.greenSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up_rounded, size: 13, color: AppTheme.success),
                            const SizedBox(width: 4),
                            Text(
                              l.activeCount(confirmedCount),
                              style:
                                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Walk-in queue
            QueueDashboardCard(shopId: shop.id),

            // Customize Barbershop Banner
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconTile(icon: Icons.dashboard_customize_outlined, color: AppTheme.blue),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.customizableApp,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.customizableAppSubtitle,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CustomizeShopScreen(shop: shop)),
                        ).then((_) => setState(() {}));
                      },
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(l.customize),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Navigation shortcuts
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _shortcutTile(
                      icon: Icons.content_cut,
                      color: AppTheme.ink,
                      label: l.servicesButton(services.length),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ManageServicesScreen(shopId: shop.id)),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _shortcutTile(
                      icon: Icons.people_outline,
                      color: AppTheme.green,
                      label: l.manageBarbersButton(barbers.length),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ManageBarbersScreen(shopId: shop.id)),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ),
                ],
              ),
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
                style: _rowButtonStyle,
                icon: const Icon(Icons.insights_rounded, size: 18, color: AppTheme.orange),
                label: _rowLabel(l.reportsOpenButton),
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
                style: _rowButtonStyle,
                icon: const Icon(Icons.workspace_premium_rounded, size: 18, color: AppTheme.purple),
                label: _rowLabel(l.subscriptionAndBilling),
              ),
            ),
            const SizedBox(height: 14),

            // Shop Map Location Card
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const IconTile(icon: Icons.location_on_outlined, color: AppTheme.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 36),
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
                    label: Text(l.editInfo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Booking Management Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l.appointmentsSchedule,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: AppTheme.card,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary, fontSize: 13.5),
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
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 48, color: AppTheme.textTertiary),
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

  static final ButtonStyle _rowButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppTheme.textPrimary,
    backgroundColor: AppTheme.card,
    side: const BorderSide(color: AppTheme.hairline),
    minimumSize: const Size(0, 54),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  );

  /// Label + trailing chevron for a full-width list-row button.
  Widget _rowLabel(String text) => Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
        ],
      );

  Widget _shortcutTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: color, size: 42),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ],
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
        statusColor = AppTheme.success;
        break;
      case BookingStatus.inProgress:
        statusColor = AppTheme.blue;
        break;
      case BookingStatus.pending:
        statusColor = AppTheme.warning;
        break;
      case BookingStatus.completed:
        statusColor = AppTheme.ink;
        break;
      case BookingStatus.cancelled:
        statusColor = AppTheme.danger;
        break;
      case BookingStatus.noShow:
        statusColor = AppTheme.slate;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: l.bookingStatus(booking.status).toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.serviceAndPrice(booking.serviceName, fmt.birr(booking.price)),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
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
              Text(l.dateAtTime(fmt.monthDay(fmt.bookingDay(booking)), fmt.bookingTime(booking)),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 20, color: AppTheme.hairline),

          // Action Buttons (Mark as Complete / Cancel)
          if (booking.status == BookingStatus.confirmed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy.contains(booking.id) ? null : () => _setStatus(booking, BookingStatus.completed),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    child: Text(l.markCompleted, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy.contains(booking.id) ? null : () => _setStatus(booking, BookingStatus.cancelled),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.hairline),
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
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        foregroundColor: AppTheme.slate,
                        side: const BorderSide(color: AppTheme.hairline),
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
