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
              const Divider(height: 1, color: Colors.white12),
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
      color: AppTheme.darkCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Icon(barber.isAvailable ? Icons.access_time_rounded : Icons.pause_circle_outline_rounded,
              size: 14, color: barber.isAvailable ? AppTheme.primaryGold : Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              barber.isAvailable ? text : l.notTakingNewBookings(text),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// The day's time off, with remove buttons and "Add time off" for the
  /// barber and the owner.
  Widget _buildTimeOffBar(Barbershop? shop, Barber barber, List<TimeOff> dayTimeOff, bool canManage) {
    final l = context.l10n;
    final fmt = context.fmt;
    if (!canManage && dayTimeOff.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppTheme.darkCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.beach_access_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.timeOffTitle,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
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
          if (dayTimeOff.isEmpty)
            Text(l.timeOffEmpty, style: const TextStyle(fontSize: 11, color: Colors.white38))
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
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      key: ValueKey('remove-time-off-${t.id}'),
                      tooltip: l.timeOffRemove,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
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
        backgroundColor: AppTheme.darkCard,
        title: Text(l.timeOffRemove),
        content: Text(l.timeOffRemoveConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(
            key: const ValueKey('confirm-remove-time-off'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.timeOffRemove, style: const TextStyle(color: Colors.redAccent)),
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

  Future<void> _showAddTimeOff(Barbershop shop, Barber barber) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddTimeOffDialog(shop: shop, barber: barber, date: _selectedDate),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.timeOffSaved)));
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
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
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
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDateSelector(Barbershop? shop, Barber barber) {
    final days = upcomingAddisDates(nowUtc: _nowUtc, count: 14);
    final schedule = shop == null ? null : WorkingSchedule.of(shop, barber);

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
          final isSelected = DateUtils.isSameDay(day, _selectedDate);
          final works = schedule != null && schedule.worksOn(day);

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
              child: Opacity(
                opacity: works || isSelected ? 1 : 0.4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.fmt.weekdayShort(day),
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
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return Colors.greenAccent;
      case BookingStatus.inProgress:
        return Colors.orangeAccent;
      case BookingStatus.cancelled:
        return Colors.redAccent;
      case BookingStatus.noShow:
        return Colors.deepOrangeAccent;
      case BookingStatus.pending:
      case BookingStatus.confirmed:
        return Colors.lightBlueAccent;
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
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(context.l10n.timeOffSlotLabel, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      );
    } else if (continuing) {
      content = Container(
        height: 28,
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(context.l10n.busy, style: const TextStyle(fontSize: 11, color: Colors.white38)),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          context.l10n.availableSlot,
          style: const TextStyle(fontSize: 12, color: Colors.white30, fontStyle: FontStyle.italic),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
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
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.customerName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.bookingStatus(booking.status),
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.serviceAndPrice(booking.serviceName, fmt.birr(booking.price)),
            style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 2),
          Text(
            l.rangeWithDuration(fmt.bookingRange(booking), booking.durationMinutes),
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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

/// Whole day (the barber's working hours that day) or a range of hours on
/// one Addis day, plus an optional note.
class _AddTimeOffDialog extends StatefulWidget {
  const _AddTimeOffDialog({required this.shop, required this.barber, required this.date});

  final Barbershop shop;
  final Barber barber;
  final DateTime date; // Addis calendar day

  @override
  State<_AddTimeOffDialog> createState() => _AddTimeOffDialogState();
}

class _AddTimeOffDialogState extends State<_AddTimeOffDialog> {
  bool _wholeDay = true;
  late int _from; // minute of the Addis day
  late int _to;
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

  @override
  void initState() {
    super.initState();
    final minutes = _minutes;
    _from = minutes.first;
    _to = minutes.length > 4 ? minutes[4] : minutes.last;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final range = _wholeDay
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
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          content: Text(l.errorText(e), key: const ValueKey('time-off-error')),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    String label(int m) => fmt.time(m ~/ 60 % 24, m % 60);
    final minutes = _minutes;
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Text(l.timeOffAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.timeOffDay}: ${fmt.dayLong(widget.date)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('time-off-whole-day'),
                  label: Text(l.timeOffWholeDay),
                  selected: _wholeDay,
                  onSelected: (_) => setState(() => _wholeDay = true),
                ),
                ChoiceChip(
                  key: const ValueKey('time-off-hours'),
                  label: Text(l.timeOffHours),
                  selected: !_wholeDay,
                  onSelected: (_) => setState(() => _wholeDay = false),
                ),
              ],
            ),
            if (!_wholeDay) ...[
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
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        ElevatedButton(
          key: const ValueKey('save-time-off'),
          onPressed: _saving ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
