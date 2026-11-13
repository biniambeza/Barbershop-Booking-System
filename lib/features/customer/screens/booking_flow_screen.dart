import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/addis_time.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/service_model.dart';
import '../../../models/barber_model.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/availability_service.dart';
import '../../payments/payment_flow.dart';

/// Pick barber, service, day and a real free time, then book.
///
/// Slots come from [availableSlotStarts]: the barber's working days/hours
/// (within the shop's), the service duration, "now" in Addis Ababa plus a
/// lead time, and the barber's live busy times
/// ([AppRepository.watchBarberBusyTimes]: visible bookings + slot locks).
/// The server transaction is the final word: if someone else took the slot
/// first, [SlotTakenException] is shown and the slots refresh.
///
/// With [rescheduling] set, the same slot picker moves that booking: the
/// barber and service are fixed, the booking's own blocks count as free,
/// its current time is not offered, and confirming calls
/// [AppRepository.rescheduleBooking] (the screen pops with `true`).
class BookingFlowScreen extends StatefulWidget {
  final Barbershop shop;
  final BarbershopService initialService;
  final Barber initialBarber;

  /// Overrides the clock (tests).
  final DateTime Function()? clock;

  /// The customer's booking being moved, or null for a new booking.
  final Booking? rescheduling;

  const BookingFlowScreen({
    super.key,
    required this.shop,
    required this.initialService,
    required this.initialBarber,
    this.clock,
    this.rescheduling,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  final _repo = AppRepository.instance;

  late String _serviceId;
  late String _barberId;
  late DateTime _date; // Addis calendar day, DateTime(y, m, d)
  DateTime? _selectedStart; // UTC
  bool _isSubmitting = false;

  /// Cash at the shop (default) or Chapa right after booking. The booking
  /// is always created as 'cash'; the payments function switches it to
  /// 'chapa' when the checkout starts.
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  List<BusyInterval> _busy = const [];
  bool _busyLoaded = false;
  StreamSubscription<List<BusyInterval>>? _busySub;
  Timer? _clockTimer;
  late DateTime _now;

  DateTime _readClock() => (widget.clock?.call() ?? DateTime.now()).toUtc();

  @override
  void initState() {
    super.initState();
    _now = _readClock();
    _serviceId = widget.initialService.id;
    _barberId = widget.initialBarber.id;
    final moving = widget.rescheduling;
    final currentDay = moving == null ? null : toAddisWallClock(moving.startAt);
    final currentDate = currentDay == null ? null : DateTime(currentDay.year, currentDay.month, currentDay.day);
    _date = currentDate != null &&
            isBookableDate(shop: _currentShop, barber: _currentBarber, addisDate: currentDate, nowUtc: _now)
        ? currentDate
        : _firstBookableDate(_currentShop, _currentBarber) ?? addisToday(_now);
    _subscribeBusy();
    // Past slots disappear as time goes by.
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = _readClock());
    });
  }

  @override
  void dispose() {
    _busySub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  // Live copies from the repository (fall back to what we were given).
  Barbershop get _currentShop => _repo.getShopById(widget.shop.id) ?? widget.shop;
  Barber get _currentBarber => _repo.getBarberById(_barberId) ?? widget.initialBarber;
  BarbershopService get _currentService => _repo.getServiceById(_serviceId) ?? widget.initialService;

  DateTime? _firstBookableDate(Barbershop shop, Barber barber) {
    for (final d in upcomingAddisDates(nowUtc: _now)) {
      if (isBookableDate(shop: shop, barber: barber, addisDate: d, nowUtc: _now)) return d;
    }
    return null;
  }

  void _subscribeBusy() {
    _busySub?.cancel();
    _busyLoaded = false;
    _busySub = _repo
        .watchBarberBusyTimes(widget.shop.id, _barberId, _date, excludeBookingId: widget.rescheduling?.id)
        .listen((busy) {
      if (!mounted) return;
      setState(() {
        _busy = busy;
        _busyLoaded = true;
      });
    });
  }

  void _selectBarber(Barber barber) {
    if (barber.id == _barberId) return;
    setState(() {
      _barberId = barber.id;
      _selectedStart = null;
      final shop = _currentShop;
      if (!isBookableDate(shop: shop, barber: barber, addisDate: _date, nowUtc: _now)) {
        _date = _firstBookableDate(shop, barber) ?? _date;
      }
    });
    _subscribeBusy();
  }

  void _selectDate(DateTime date) {
    if (DateUtils.isSameDay(date, _date)) return;
    setState(() {
      _date = date;
      _selectedStart = null;
    });
    _subscribeBusy();
  }

  bool get _isRescheduling => widget.rescheduling != null;

  /// Free starts; when rescheduling, for the booking's own duration and
  /// without its current start.
  List<DateTime> _slots(Barbershop shop, Barber barber, BarbershopService service) {
    final moving = widget.rescheduling;
    final slots = availableSlotStarts(
      shop: shop,
      barber: barber,
      durationMinutes: moving?.durationMinutes ?? service.durationMinutes,
      addisDate: _date,
      busy: _busy,
      nowUtc: _now,
    );
    return moving == null ? slots : slots.where((s) => s != moving.startAt).toList();
  }

  /// The stored display slot (always English 12-hour form, e.g. '02:30 PM').
  static String _slotLabel(DateTime startUtc) {
    final t = toAddisWallClock(startUtc);
    return formatTimeSlot(t.hour, t.minute);
  }

  /// The slot time shown to the user, in the active language.
  String _slotDisplay(DateTime startUtc) => context.fmt.addisTime(startUtc);

  String _etb(double amount) => context.fmt.birr(amount);

  Future<void> _confirmBooking() async {
    final shop = _currentShop;
    final barber = _currentBarber;
    final service = _currentService;
    _now = _readClock();
    final start = _selectedStart;
    if (start == null || !_slots(shop, barber, service).contains(start)) {
      setState(() => _selectedStart = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectAvailableTime)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final moving = widget.rescheduling;
    if (moving != null) {
      await _submitReschedule(moving, start);
      return;
    }

    try {
      final booking = await _repo.createBooking(
        shopId: shop.id,
        shopName: shop.name,
        barberId: barber.id,
        barberName: barber.name,
        serviceId: service.id,
        serviceName: service.name,
        price: service.price,
        date: DateTime(_date.year, _date.month, _date.day),
        timeSlot: _slotLabel(start),
        startAt: start,
        durationMinutes: service.durationMinutes,
      );

      if (!mounted) return;
      _showConfirmation(booking.shopName, booking.barberName, booking.serviceName, booking.startAt, booking.price,
          booking: booking);
    } on SlotTakenException {
      if (!mounted) return;
      await _showSlotTaken();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// The slot went to someone else: refresh the busy times and say so.
  Future<void> _showSlotTaken() async {
    setState(() => _selectedStart = null);
    _subscribeBusy(); // refresh the busy times
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        icon: const Icon(Icons.event_busy_rounded, color: AppTheme.primaryGold, size: 40),
        title: Text(context.l10n.slotJustTaken),
        content: Text(context.l10n.slotJustTakenBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.pickAnotherTime)),
        ],
      ),
    );
  }

  Future<void> _submitReschedule(Booking moving, DateTime start) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l = context.l10n;
    final fmt = context.fmt;
    try {
      final moved = await _repo.rescheduleBooking(moving.id, start);
      final local = toAddisWallClock(moved.startAt);
      final when = l.dateAtTime(fmt.dayShort(DateTime(local.year, local.month, local.day)), fmt.addisTime(moved.startAt));
      messenger.showSnackBar(SnackBar(content: Text(l.rescheduleDone(when))));
      if (mounted) navigator.pop(true);
    } on SlotTakenException {
      if (mounted) await _showSlotTaken();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorText(e))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showConfirmation(String shopName, String barberName, String serviceName, DateTime startUtc, double price,
      {Booking? booking}) {
    final payOnline = booking != null && _paymentMethod == PaymentMethod.chapa;
    final local = toAddisWallClock(startUtc);
    final l = context.l10n;
    final fmt = context.fmt;
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
            Text(
              l.bookingConfirmed,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l.seatReserved(barberName),
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
                  _buildReceiptRow(l.receiptShop, shopName),
                  _buildReceiptRow(l.receiptService, serviceName),
                  _buildReceiptRow(l.receiptDate, fmt.dayShort(DateTime(local.year, local.month, local.day))),
                  _buildReceiptRow(l.receiptTime, _slotDisplay(startUtc)),
                  _buildReceiptRow(l.receiptTotal, _etb(price), isHighlight: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (payOnline) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('pay-now-chapa'),
                  onPressed: () async {
                    Navigator.of(ctx).pop(); // dismiss dialog
                    await payForBooking(context, booking);
                    if (mounted) Navigator.of(context).pop(); // return to detail or home
                  },
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: Text(l.payAmountNow(_etb(price))),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: Text(l.payAtShopInstead),
              ),
            ] else
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // dismiss dialog
                  Navigator.of(context).pop(); // return to detail or home
                },
                child: Text(l.backToHome),
              ),
          ],
        ),
      ),
    );
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
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final shop = _currentShop;
        final barber = _currentBarber;
        final service = _currentService;
        final allServices = _repo.getServicesForShop(shop.id);
        final allBarbers = _repo.getBarbersForShop(shop.id);
        final slots = _slots(shop, barber, service);
        final selected = slots.contains(_selectedStart) ? _selectedStart : null;
        final l = context.l10n;

        final moving = widget.rescheduling;

        return Scaffold(
          appBar: AppBar(title: Text(moving == null ? l.confirmAppointment : l.rescheduleTitle)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShopSummary(shop),
                const SizedBox(height: 24),
                if (moving != null) ...[
                  _buildRescheduleSummary(moving),
                  const SizedBox(height: 24),
                ] else ...[
                  _sectionTitle(context, l.stepChooseBarber),
                  const SizedBox(height: 12),
                  _buildBarberPicker(allBarbers.isEmpty ? [barber] : allBarbers),
                  const SizedBox(height: 24),
                  _sectionTitle(context, l.stepSelectedService),
                  const SizedBox(height: 12),
                  _buildServicePicker(allServices.isEmpty ? [service] : allServices),
                  const SizedBox(height: 24),
                ],
                _sectionTitle(context, l.stepSelectDate),
                const SizedBox(height: 12),
                _buildDatePicker(shop, barber),
                const SizedBox(height: 24),
                _sectionTitle(context, l.stepAvailableTimes),
                const SizedBox(height: 4),
                Text(
                  l.durationAddisTime(moving?.durationMinutes ?? service.durationMinutes),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildSlots(shop, barber, slots, selected),
                const SizedBox(height: 32),
                _buildTotal(service, selected),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Reschedule mode: the fixed barber and service and the current time.
  Widget _buildRescheduleSummary(Booking moving) {
    final l = context.l10n;
    final fmt = context.fmt;
    final local = toAddisWallClock(moving.startAt);
    final when = l.dateAtTime(fmt.dayShort(DateTime(local.year, local.month, local.day)), fmt.addisTime(moving.startAt));
    return Container(
      key: const ValueKey('reschedule-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.serviceAndPrice(moving.serviceName, fmt.birr(moving.price)),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
          const SizedBox(height: 4),
          Text(l.barberLabel(moving.barberName), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(l.rescheduleCurrent(when), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold));

  Widget _buildShopSummary(Barbershop shop) {
    return Container(
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
              shop.imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: AppTheme.darkSurface),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(context.l10n.shopAddress(shop), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberPicker(List<Barber> barbers) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: barbers.length,
        itemBuilder: (context, index) {
          final barber = barbers[index];
          final isSelected = _barberId == barber.id;
          return Opacity(
            opacity: barber.isAvailable ? 1 : 0.45,
            child: InkWell(
              onTap: barber.isAvailable ? () => _selectBarber(barber) : null,
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
                      child: barber.avatarUrl == null
                          ? Text(barber.name.isEmpty ? '?' : barber.name.substring(0, 1), style: const TextStyle(color: Colors.black))
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(barber.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (!barber.isAvailable)
                      Text(context.l10n.unavailable, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicePicker(List<BarbershopService> services) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: services.map((service) {
          final isSelected = _serviceId == service.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(context.l10n.serviceChip(service.name, _etb(service.price), service.durationMinutes)),
              selected: isSelected,
              selectedColor: AppTheme.primaryGold,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _serviceId = service.id;
                    _selectedStart = null;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePicker(Barbershop shop, Barber barber) {
    final dates = upcomingAddisDates(nowUtc: _now);
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final enabled = isBookableDate(shop: shop, barber: barber, addisDate: date, nowUtc: _now);
          final isSelected = DateUtils.isSameDay(_date, date);
          final fmt = context.fmt;
          final dayName = fmt.weekdayShort(date);
          final dayNum = '${date.day}';
          final fg = isSelected
              ? Colors.black
              : enabled
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary.withValues(alpha: 0.4);

          return Tooltip(
            message: enabled ? fmt.weekdayMonthDay(date) : context.l10n.closed,
            child: InkWell(
              key: ValueKey('booking-date-$index'),
              onTap: enabled ? () => _selectDate(date) : null,
              child: Container(
                width: 65,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryGold : AppTheme.darkCard.withValues(alpha: enabled ? 1 : 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryGold : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      index == 0 ? context.l10n.today : dayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.black : AppTheme.textSecondary.withValues(alpha: enabled ? 1 : 0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayNum,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        decoration: enabled ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlots(Barbershop shop, Barber barber, List<DateTime> slots, DateTime? selected) {
    final l = context.l10n;
    String? emptyMessage;
    if (shop.isSuspended) {
      emptyMessage = l.shopNotTakingBookings;
    } else if (!barber.isAvailable) {
      emptyMessage = l.barberNotTakingBookings(barber.name);
    } else if (!isBookableDate(shop: shop, barber: barber, addisDate: _date, nowUtc: _now)) {
      emptyMessage = l.barberDayOff(barber.name);
    } else if (!_busyLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (slots.isEmpty) {
      emptyMessage = l.noFreeTimes;
    }
    if (emptyMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.event_busy_rounded, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(emptyMessage, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          ],
        ),
      );
    }

    final groups = <String, List<DateTime>>{l.morning: [], l.afternoon: [], l.evening: []};
    for (final s in slots) {
      final h = toAddisWallClock(s).hour;
      groups[h < 12 ? l.morning : h < 17 ? l.afternoon : l.evening]!.add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(entry.key, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: entry.value.map((slot) {
                final isSelected = selected == slot;
                final label = _slotLabel(slot);
                return InkWell(
                  key: ValueKey('slot-$label'),
                  onTap: () => setState(() => _selectedStart = slot),
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
                      _slotDisplay(slot),
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
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildTotal(BarbershopService service, DateTime? selected) {
    final l = context.l10n;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _paymentMethod == PaymentMethod.cash ? l.totalPayAtSalon : l.totalPayOnline,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _etb(service.price),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
              ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.dateAtTime(context.fmt.dayShort(_date), _slotDisplay(selected)),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
          if (!_isRescheduling) ...[
            const SizedBox(height: 12),
            _buildPaymentChoice(),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('confirm-booking'),
              onPressed: _isSubmitting || selected == null ? null : _confirmBooking,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Text(selected == null
                      ? l.selectATime
                      : _isRescheduling
                          ? l.rescheduleConfirm
                          : l.confirmAppointment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChoice() {
    final l = context.l10n;
    Widget option(PaymentMethod method, IconData icon, String title, String subtitle) {
      final selected = _paymentMethod == method;
      return InkWell(
        key: ValueKey('pay-method-${method.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: _isSubmitting ? null : () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryGold.withValues(alpha: 0.12) : AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.primaryGold : Colors.white12),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18, color: selected ? AppTheme.primaryGold : AppTheme.textSecondary),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        option(PaymentMethod.cash, Icons.payments_outlined, l.payAtShopCash, l.payAfterAppointment),
        const SizedBox(height: 8),
        option(PaymentMethod.chapa, Icons.phone_android_rounded, l.payNowWithChapa, l.chapaMethods),
      ],
    );
  }
}
