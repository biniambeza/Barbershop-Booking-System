import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/addis_time.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../models/booking_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/availability_service.dart';
import '../../../services/time_off_service.dart';
import '../../../services/vacation_service.dart';
import '../../shared/widgets/ui_kit.dart';

/// A barber's day: their effective working hours (own days/hours within the
/// shop's) on a 30-minute timeline in Addis Ababa time, with each booking
/// placed at its real start time and spanning its real duration, plus the
/// barber's time off. The barber (own schedule) and the shop owner (any of
/// their barbers) can add and remove time off for the selected day
/// ([AppRepository.addTimeOff]: the time-off doc and its slot locks in one
/// batch, so customers cannot book those times).
class BarberScheduleScreen extends StatefulWidget {
  final Barber barber;

  /// Overrides the clock (tests).
  final DateTime Function()? clock;

  const BarberScheduleScreen({super.key, required this.barber, this.clock});

  @override
  State<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends State<BarberScheduleScreen> {
  static const int _rowMinutes = 30;
  late DateTime _selectedDate; // Addis calendar day, DateTime(y, m, d)
  List<TimeOff> _timeOff = const [];
  StreamSubscription<List<TimeOff>>? _timeOffSub;

  DateTime get _nowUtc => (widget.clock?.call() ?? DateTime.now()).toUtc();

  @override
  void initState() {
    super.initState();
    _selectedDate = addisToday(_nowUtc);
    _timeOffSub = AppRepository.instance.watchTimeOff(widget.barber.shopId, widget.barber.id).listen((entries) {
      if (mounted) setState(() => _timeOff = entries);
    });
  }

  @override
  void dispose() {
    _timeOffSub?.cancel();
    super.dispose();
  }

  List<TimeOff> _timeOffOn(DateTime dayStart, DateTime dayEnd) =>
      _timeOff.where((t) => t.startAt.isBefore(dayEnd) && t.endAt.isAfter(dayStart)).toList();

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final barber = repo.getBarberById(widget.barber.id) ?? widget.barber;
        final shop = repo.getShopById(barber.shopId);
        final (dayStart, dayEnd) = addisDayBoundsUtc(_selectedDate);
        final dayBookings = repo
            .getBookingsForBarber(barber.id)
            .where((b) => b.startAt.isBefore(dayEnd) && b.endAt.isAfter(dayStart))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final dayTimeOff = _timeOffOn(dayStart, dayEnd);
        final canManage = repo.canManageTimeOffFor(barber);

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.barberScheduleTitle(barber.name)),
          ),
          body: Column(
            children: [
              _buildDateSelector(shop, barber),
              _buildHoursBanner(shop, barber),
              _buildTimeOffBar(shop, barber, dayTimeOff, canManage),
              Divider(height: 1, color: AppTheme.hairline),
              Expanded(child: _buildTimeline(shop, barber, dayBookings, dayTimeOff)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHoursBanner(Barbershop? shop, Barber barber) {
    final l = context.l10n;
    final fmt = context.fmt;
    String text;
    if (shop == null) {
      text = l.shopHoursUnavailable;
    } else {
      final s = WorkingSchedule.of(shop, barber);
      final days = (s.days.toList()..sort()).map(fmt.weekdayName).join(', ');
      text = s.isEmpty ? l.noWorkingHours : l.workingHoursLine(fmt.hoursRange(s.startHour, s.endHour), days);
    }
    return Container(
      width: double.infinity,
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(20, 2, 16, 10),
      child: Row(
        children: [
          Icon(barber.isAvailable ? Icons.access_time_rounded : Icons.pause_circle_outline_rounded,
              size: 14, color: barber.isAvailable ? AppTheme.success : AppTheme.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              barber.isAvailable ? text : l.notTakingNewBookings(text),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// The day's time off and every upcoming vacation (one row each, e.g.
  /// "Dec 12 - Dec 20 • Vacation"), with remove buttons and "Add time off"
  /// for the barber and the owner.
  Widget _buildTimeOffBar(Barbershop? shop, Barber barber, List<TimeOff> dayTimeOffAll, bool canManage) {
    final l = context.l10n;
    final fmt = context.fmt;
    final dayTimeOff = dayTimeOffAll.where((t) => !t.isVacationPart).toList();
    final vacations = groupTimeOff(_timeOff).where((i) => i.isVacation && i.isUpcoming(_nowUtc)).toList();
    if (!canManage && dayTimeOff.isEmpty && vacations.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 10),
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusPanel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.beach_access_rounded, size: 15, color: AppTheme.orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.timeOffTitle,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
              if (canManage && shop != null)
                TextButton.icon(
                  key: const ValueKey('add-time-off'),
                  onPressed: () => _showAddTimeOff(shop, barber),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l.timeOffAdd, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          for (final v in vacations)
            Row(
              key: ValueKey('vacation-${v.groupId}'),
              children: [
                Icon(Icons.flight_takeoff_rounded, size: 14, color: AppTheme.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      l.vacationRange(fmt.monthDay(v.fromDate), fmt.monthDay(v.toDate)),
                      v.reason ?? l.vacationLabel,
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
                if (canManage)
                  IconButton(
                    key: ValueKey('remove-vacation-${v.groupId}'),
                    tooltip: l.timeOffRemove,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                    onPressed: () => _removeVacation(v),
                  ),
              ],
            ),
          if (dayTimeOff.isEmpty && vacations.isEmpty)
            Text(l.timeOffEmpty, style: TextStyle(fontSize: 11, color: AppTheme.textTertiary))
          else
            for (final t in dayTimeOff)
              Row(
                key: ValueKey('time-off-${t.id}'),
                children: [
                  Expanded(
                    child: Text(
                      [
                        l.timeOffRange(fmt.dayShort(_selectedDate), fmt.addisTime(t.startAt), fmt.addisTime(t.endAt)),
                        if (t.reason != null) t.reason!,
                      ].join(' • '),
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      key: ValueKey('remove-time-off-${t.id}'),
                      tooltip: l.timeOffRemove,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                      onPressed: () => _removeTimeOff(t),
                    ),
                ],
              ),
        ],
      ),
    );
  }

  Future<void> _removeTimeOff(TimeOff entry) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.timeOffRemove),
        content: Text(l.timeOffRemoveConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(
            key: const ValueKey('confirm-remove-time-off'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.timeOffRemove, style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppRepository.instance.deleteTimeOff(entry);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.timeOffRemoved)));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.errorText(e))));
    }
  }

  /// Removes every part of a vacation after a confirmation.
  Future<void> _removeVacation(TimeOffItem item) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.timeOffRemove),
        content: Text(l.vacationRemoveConfirm(l.vacationRange(fmt.monthDay(item.fromDate), fmt.monthDay(item.toDate)))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(
            key: const ValueKey('confirm-remove-vacation'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.timeOffRemove, style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppRepository.instance.deleteTimeOffItem(item);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.timeOffRemoved)));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.errorText(e))));
    }
  }

  Future<void> _showAddTimeOff(Barbershop shop, Barber barber) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _AddTimeOffDialog(shop: shop, barber: barber, date: _selectedDate, nowUtc: _nowUtc),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildTimeline(Barbershop? shop, Barber barber, List<Booking> dayBookings, List<TimeOff> dayTimeOff) {
    final schedule = shop == null ? null : WorkingSchedule.of(shop, barber);
    final works = schedule != null && !schedule.isEmpty && schedule.worksOn(_selectedDate);
    final active = dayBookings.where(occupiesSlot).toList();
    final cancelled = dayBookings.where((b) => !occupiesSlot(b)).toList();

    if (!works && active.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(Icons.weekend_rounded, context.l10n.dayOff(context.fmt.weekdayLong(_selectedDate))),
          ...cancelled.map(_buildCancelledRow),
        ],
      );
    }

    // Rows cover the working hours, stretched to include any booking outside them.
    var startMin = (works ? schedule.startHour : 24) * 60;
    var endMin = (works ? schedule.endHour : 0) * 60;
    for (final b in active) {
      final s = toAddisWallClock(b.startAt);
      final e = toAddisWallClock(b.endAt);
      final sMin = DateUtils.isSameDay(s, _selectedDate) ? s.hour * 60 + s.minute : 0;
      final eMin = DateUtils.isSameDay(e, _selectedDate) ? e.hour * 60 + e.minute : 24 * 60;
      if (sMin < startMin) startMin = sMin - sMin % _rowMinutes;
      if (eMin > endMin) endMin = eMin;
    }

    final rows = <Widget>[];
    for (var m = startMin; m < endMin; m += _rowMinutes) {
      final rowStart = addisLocalToUtc(_selectedDate.year, _selectedDate.month, _selectedDate.day).add(Duration(minutes: m));
      final rowEnd = rowStart.add(const Duration(minutes: _rowMinutes));
      final starting = active.where((b) => !b.startAt.isBefore(rowStart) && b.startAt.isBefore(rowEnd)).toList();
      final continuing = active.where((b) => b.startAt.isBefore(rowStart) && b.endAt.isAfter(rowStart)).toList();
      final off = dayTimeOff.any((t) => t.startAt.isBefore(rowEnd) && t.endAt.isAfter(rowStart));
      rows.add(_buildTimelineRow(context.fmt.time(m ~/ 60 % 24, m % 60), starting, continuing.isNotEmpty, timeOff: off));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...rows,
        if (cancelled.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              context.l10n.statusCancelled,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          ...cancelled.map(_buildCancelledRow),
        ],
      ],
    );
  }

  Widget _infoCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusPanel),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDateSelector(Barbershop? shop, Barber barber) {
    final days = upcomingAddisDates(nowUtc: _nowUtc, count: 14);
    final schedule = shop == null ? null : WorkingSchedule.of(shop, barber);

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppTheme.background,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day, _selectedDate);
          final works = schedule != null && schedule.worksOn(day);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = day),
            child: Container(
              width: 58,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.ink : AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? AppTheme.ink : AppTheme.hairline,
                ),
              ),
              child: Opacity(
                opacity: works || isSelected ? 1 : 0.4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.fmt.weekdayShort(day),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.onInk.withValues(alpha: 0.75) : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppTheme.onInk : AppTheme.textPrimary,
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

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        // Teal: done, and different from the green "confirmed".
        return AppTheme.teal;
      case BookingStatus.inProgress:
        return AppTheme.blue;
      case BookingStatus.cancelled:
        return AppTheme.danger;
      case BookingStatus.noShow:
        return AppTheme.slate;
      case BookingStatus.pending:
        return AppTheme.warning;
      case BookingStatus.confirmed:
        return AppTheme.success;
    }
  }

  Widget _buildTimelineRow(String time, List<Booking> starting, bool continuing, {bool timeOff = false}) {
    Widget content;
    if (starting.isNotEmpty) {
      content = Column(children: starting.map(_buildBookingCard).toList());
    } else if (timeOff && !continuing) {
      content = Container(
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.orangeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(context.l10n.timeOffSlotLabel,
            style: TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w600)),
      );
    } else if (continuing) {
      content = Container(
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.blueSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(context.l10n.busy, style: TextStyle(fontSize: 11, color: AppTheme.blue, fontWeight: FontWeight.w600)),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Text(
          context.l10n.availableSlot,
          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
        ),
      );
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final color = _statusColor(booking.status);
    final l = context.l10n;
    final fmt = context.fmt;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusPanel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.customerName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(
                label: l.bookingStatus(booking.status),
                color: color,
                background: booking.status == BookingStatus.completed ? AppTheme.slateSoft : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.serviceAndPrice(booking.serviceName, fmt.birr(booking.price)),
            style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            l.rangeWithDuration(fmt.bookingRange(booking), booking.durationMinutes),
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledRow(Booking booking) {
    return Opacity(
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 70),
        child: _buildBookingCard(booking),
      ),
    );
  }
}

enum _TimeOffMode { wholeDay, hours, days }

/// Whole day (the barber's working hours that day), a range of hours on
/// one Addis day, or several days (a vacation, [AppRepository.addVacation]:
/// first and last date, optionally a later start on the first day and an
/// earlier end on the last), plus an optional note. Pops the message to
/// show once saved.
class _AddTimeOffDialog extends StatefulWidget {
  const _AddTimeOffDialog({required this.shop, required this.barber, required this.date, required this.nowUtc});

  final Barbershop shop;
  final Barber barber;
  final DateTime date; // Addis calendar day
  final DateTime nowUtc;

  @override
  State<_AddTimeOffDialog> createState() => _AddTimeOffDialogState();
}

/// What to do with the bookings inside a new vacation.
enum _ConflictChoice { cancel, keep }

class _AddTimeOffDialogState extends State<_AddTimeOffDialog> {
  _TimeOffMode _mode = _TimeOffMode.wholeDay;
  late int _from; // minute of the Addis day
  late int _to;
  late DateTime _vacationFrom; // Addis dates
  late DateTime _vacationTo;
  int? _firstDayFrom; // null = start of work
  int? _lastDayUntil; // null = end of work
  final _reason = TextEditingController();
  bool _saving = false;

  WorkingSchedule get _schedule => WorkingSchedule.of(widget.shop, widget.barber);

  /// Selectable minutes: the working hours that day, else the whole day.
  List<int> get _minutes {
    final s = _schedule;
    final works = !s.isEmpty && s.worksOn(widget.date);
    final start = works ? s.startHour * 60 : 0;
    final end = works ? s.endHour * 60 : 24 * 60;
    return [for (var m = start; m <= end; m += kSlotStepMinutes) m];
  }

  /// Partial first/last day choices: inside the usual working hours.
  List<int> get _workMinutes {
    final s = _schedule;
    final start = s.isEmpty ? 0 : s.startHour * 60;
    final end = s.isEmpty ? 24 * 60 : s.endHour * 60;
    return [for (var m = start + kSlotStepMinutes; m < end; m += kSlotStepMinutes) m];
  }

  @override
  void initState() {
    super.initState();
    final minutes = _minutes;
    _from = minutes.first;
    _to = minutes.length > 4 ? minutes[4] : minutes.last;
    _vacationFrom = DateTime(widget.date.year, widget.date.month, widget.date.day);
    _vacationTo = DateTime(widget.date.year, widget.date.month, widget.date.day + 2);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    final l = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.errorText(e), key: const ValueKey('time-off-error')),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))],
      ),
    );
  }

  Future<void> _save() async {
    if (_mode == _TimeOffMode.days) return _saveVacation();
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final range = _mode == _TimeOffMode.wholeDay
        ? wholeDayTimeOffRange(widget.shop, widget.barber, widget.date)
        : timeOffRangeOnDay(widget.date, _from, _to);
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.timeOffNotWorking(widget.barber.name))));
      return;
    }
    setState(() => _saving = true);
    try {
      await AppRepository.instance.addTimeOff(
        barberId: widget.barber.id,
        startUtc: range.$1,
        endUtc: range.$2,
        reason: _reason.text,
      );
      navigator.pop(l.timeOffSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e);
    }
  }

  Future<void> _saveVacation() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final repo = AppRepository.instance;
    try {
      validateVacation(
        fromDate: _vacationFrom,
        toDate: _vacationTo,
        firstDayFromMinute: _firstDayFrom,
        lastDayToMinute: _lastDayUntil,
        reason: _reason.text.trim(),
        nowUtc: repo.nowUtc(),
      );
    } catch (e) {
      _showError(e);
      return;
    }
    final conflicts = repo.vacationConflictsFor(
      barberId: widget.barber.id,
      fromDate: _vacationFrom,
      toDate: _vacationTo,
      firstDayFromMinute: _firstDayFrom,
      lastDayToMinute: _lastDayUntil,
    );
    var cancelIds = const <String>[];
    if (conflicts.isNotEmpty) {
      final choice = await showDialog<_ConflictChoice>(
        context: context,
        builder: (_) => _VacationConflictsDialog(bookings: conflicts),
      );
      if (choice == null || !mounted) return;
      if (choice == _ConflictChoice.cancel) cancelIds = [for (final b in conflicts) b.id];
    }
    setState(() => _saving = true);
    try {
      final result = await repo.addVacation(
        barberId: widget.barber.id,
        fromDate: _vacationFrom,
        toDate: _vacationTo,
        firstDayFromMinute: _firstDayFrom,
        lastDayToMinute: _lastDayUntil,
        reason: _reason.text,
        cancelBookingIds: cancelIds,
      );
      navigator.pop(result.cancelled.isEmpty ? l.vacationSaved : l.vacationSavedCancelled(result.cancelled.length));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e);
    }
  }

  Future<void> _pickDate({required bool first}) async {
    final today = addisToday(widget.nowUtc);
    final initial = first ? _vacationFrom : _vacationTo;
    final firstAllowed = first ? today : _vacationFrom;
    final lastAllowed = first
        ? DateTime(today.year + 1, today.month, today.day)
        : DateTime(_vacationFrom.year, _vacationFrom.month, _vacationFrom.day + kMaxVacationDays - 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstAllowed) ? firstAllowed : (initial.isAfter(lastAllowed) ? lastAllowed : initial),
      firstDate: firstAllowed,
      lastDate: lastAllowed,
    );
    if (picked == null || !mounted) return;
    setState(() {
      final day = DateTime(picked.year, picked.month, picked.day);
      if (first) {
        _vacationFrom = day;
        if (_vacationTo.isBefore(day)) _vacationTo = day;
        if (vacationLengthDays(_vacationFrom, _vacationTo) > kMaxVacationDays) {
          _vacationTo = DateTime(day.year, day.month, day.day + kMaxVacationDays - 1);
        }
      } else {
        _vacationTo = day;
      }
    });
  }

  Widget _modeChip(_TimeOffMode mode, String key, String label) {
    final selected = _mode == mode;
    return ChoiceChip(
      key: ValueKey(key),
      label: Text(label, style: TextStyle(color: selected ? AppTheme.onInk : AppTheme.textPrimary)),
      selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
    );
  }

  Widget _dateButton(String key, String label, DateTime date, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        key: ValueKey(key),
        onPressed: _saving ? null : onTap,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(context.fmt.dayShort(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  List<Widget> _vacationFields() {
    final l = context.l10n;
    final fmt = context.fmt;
    String label(int m) => fmt.time(m ~/ 60 % 24, m % 60);
    final work = _workMinutes;
    final days = vacationLengthDays(_vacationFrom, _vacationTo);
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          _dateButton('vacation-from', l.vacationFromDate, _vacationFrom, () => _pickDate(first: true)),
          const SizedBox(width: 8),
          _dateButton('vacation-to', l.vacationToDate, _vacationTo, () => _pickDate(first: false)),
        ],
      ),
      const SizedBox(height: 6),
      Text(l.vacationMaxDays(days, kMaxVacationDays),
          key: const ValueKey('vacation-days'),
          style: TextStyle(fontSize: 11.5, color: days > kMaxVacationDays ? AppTheme.danger : AppTheme.textSecondary)),
      const SizedBox(height: 8),
      DropdownButtonFormField<int?>(
        key: const ValueKey('vacation-first-from'),
        initialValue: _firstDayFrom,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.vacationFirstDayFrom),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(l.vacationStartOfWork)),
          for (final m in work) DropdownMenuItem<int?>(value: m, child: Text(label(m))),
        ],
        onChanged: (v) => setState(() => _firstDayFrom = v),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<int?>(
        key: const ValueKey('vacation-last-until'),
        initialValue: _lastDayUntil,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.vacationLastDayUntil),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(l.vacationEndOfWork)),
          for (final m in work) DropdownMenuItem<int?>(value: m, child: Text(label(m))),
        ],
        onChanged: (v) => setState(() => _lastDayUntil = v),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    String label(int m) => fmt.time(m ~/ 60 % 24, m % 60);
    final minutes = _minutes;
    return AlertDialog(
      title: Text(l.timeOffAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_mode != _TimeOffMode.days)
              Text('${l.timeOffDay}: ${fmt.dayLong(widget.date)}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _modeChip(_TimeOffMode.wholeDay, 'time-off-whole-day', l.timeOffWholeDay),
                _modeChip(_TimeOffMode.hours, 'time-off-hours', l.timeOffHours),
                _modeChip(_TimeOffMode.days, 'time-off-several-days', l.timeOffSeveralDays),
              ],
            ),
            if (_mode == _TimeOffMode.hours) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('time-off-from'),
                      initialValue: _from,
                      decoration: InputDecoration(labelText: l.timeOffFrom),
                      items: [
                        for (final m in minutes.take(minutes.length - 1)) DropdownMenuItem(value: m, child: Text(label(m))),
                      ],
                      onChanged: (v) => setState(() {
                        _from = v ?? _from;
                        if (_to <= _from) _to = minutes.firstWhere((m) => m > _from, orElse: () => minutes.last);
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('time-off-to-$_from'),
                      initialValue: _to,
                      decoration: InputDecoration(labelText: l.timeOffTo),
                      items: [
                        for (final m in minutes.where((m) => m > _from)) DropdownMenuItem(value: m, child: Text(label(m))),
                      ],
                      onChanged: (v) => setState(() => _to = v ?? _to),
                    ),
                  ),
                ],
              ),
            ],
            if (_mode == _TimeOffMode.days) ..._vacationFields(),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('time-off-reason'),
              controller: _reason,
              maxLength: kMaxTimeOffReasonLength,
              decoration: InputDecoration(labelText: l.timeOffReasonLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
        ElevatedButton(
          key: const ValueKey('save-time-off'),
          onPressed: _saving ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// The barber's upcoming bookings inside a new vacation: cancel them all
/// (each customer is notified; paid ones get a refund flag) or keep them.
class _VacationConflictsDialog extends StatelessWidget {
  const _VacationConflictsDialog({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return AlertDialog(
      title: Text(l.vacationConflictsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.vacationConflictsBody(bookings.length),
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              for (final b in bookings)
                Padding(
                  key: ValueKey('vacation-conflict-${b.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${b.customerName} • ${b.serviceName}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text('${fmt.dayShort(toAddisWallClock(b.startAt))}, ${fmt.bookingRange(b)}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (b.paymentStatus == PaymentStatus.paid)
                        Text(l.vacationPaidRefund,
                            key: ValueKey('vacation-conflict-paid-${b.id}'),
                            style: TextStyle(fontSize: 11.5, color: AppTheme.warning, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        TextButton(
          key: const ValueKey('vacation-keep-bookings'),
          onPressed: () => Navigator.of(context).pop(_ConflictChoice.keep),
          child: Text(l.vacationKeepBookings),
        ),
        ElevatedButton(
          key: const ValueKey('vacation-cancel-bookings'),
          onPressed: () => Navigator.of(context).pop(_ConflictChoice.cancel),
          child: Text(l.vacationCancelAndNotify),
        ),
      ],
    );
  }
}
