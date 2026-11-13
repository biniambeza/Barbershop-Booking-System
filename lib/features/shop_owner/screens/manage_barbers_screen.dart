import 'package:flutter/material.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../reviews/reviews_l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/availability_service.dart' show WorkingSchedule;

class ManageBarbersScreen extends StatefulWidget {
  final String shopId;

  const ManageBarbersScreen({super.key, required this.shopId});

  @override
  State<ManageBarbersScreen> createState() => _ManageBarbersScreenState();
}

class _ManageBarbersScreenState extends State<ManageBarbersScreen> {
  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
  ];

  void _showAddBarberDialog() {
    final l = context.l10n;
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: l.defaultBarberTitle);
    final phoneCtrl = TextEditingController();
    String? phoneError;
    String selectedAvatar = _avatarPresets[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l.addBarberToShop, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l.barberFullName, prefixIcon: const Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: l.specialization, prefixIcon: const Icon(Icons.badge)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l.mobileForLogin,
                    hintText: '09XX XXX XXX',
                    helperText: l.barberPhoneHelper,
                    errorText: phoneError,
                    prefixIcon: const Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l.selectAvatar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _avatarPresets.map((avatarUrl) {
                      final isSelected = selectedAvatar == avatarUrl;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedAvatar = avatarUrl),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryGold : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(avatarUrl),
                            onBackgroundImageError: (err, stack) {},
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final phone = phoneCtrl.text.trim();
                if (phone.isNotEmpty && normalizeEthiopianPhone(phone) == null) {
                  setDialogState(() => phoneError = l.invalidPhoneShort);
                  return;
                }
                try {
                  await AppRepository.instance.addBarber(
                    shopId: widget.shopId,
                    name: nameCtrl.text.trim(),
                    title: titleCtrl.text.trim(),
                    phone: phone.isEmpty ? null : phone,
                    avatarUrl: selectedAvatar,
                  );
                } catch (e) {
                  setDialogState(() => phoneError = e is AppException ? l.errorText(e) : l.addBarberFailed);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) setState(() {});
              },
              child: Text(l.addBarber),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBarber(String barberId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Text(context.l10n.removeBarberTitle),
        content: Text(context.l10n.removeBarberBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final l = context.l10n;
              try {
                await AppRepository.instance.deleteBarber(barberId);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(l.saveFailed(l.errorText(e)))));
              }
              if (mounted) setState(() {});
            },
            child: Text(context.l10n.remove, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _editSchedule(Barber barber, Barbershop shop) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BarberScheduleDialog(barber: barber, shop: shop),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.workingHoursSaved)));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final barbers = AppRepository.instance.getBarbersForShop(widget.shopId);
    final shop = AppRepository.instance.getShopById(widget.shopId);
    final fmt = context.fmt;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.manageBarbersStaff),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBarberDialog,
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
        label: Text(context.l10n.addBarber, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: barbers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text(context.l10n.noBarbersYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(context.l10n.noBarbersHint, style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: barbers.length,
              itemBuilder: (context, index) {
                final barber = barbers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                        onBackgroundImageError: barber.avatarUrl != null ? (error, stackTrace) {} : null,
                        backgroundColor: AppTheme.primaryGold,
                        child: barber.avatarUrl == null
                            ? Text(barber.name.substring(0, 1), style: const TextStyle(color: Colors.black, fontSize: 18))
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              barber.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              barber.title,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            if (AppRepository.instance.getPendingBarberInvite(barber.id) != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.loginInvitePending(formatEthiopianPhone(barber.phone ?? '')),
                                style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12),
                              ),
                            ],
                            if (shop != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _scheduleSummary(context, fmt, shop, barber),
                                key: ValueKey('barber-hours-${barber.id}'),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: AppTheme.primaryGold),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    context.l10n.reviewsRatingShort(barber.rating, barber.reviewCount),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (shop != null)
                        IconButton(
                          key: ValueKey('edit-hours-${barber.id}'),
                          icon: const Icon(Icons.schedule, size: 20, color: AppTheme.primaryGold),
                          tooltip: context.l10n.editWorkingHours,
                          onPressed: () => _editSchedule(barber, shop),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: context.l10n.removeBarber,
                        onPressed: () => _confirmDeleteBarber(barber.id, barber.name),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

String _scheduleSummary(BuildContext context, AppFormats fmt, Barbershop shop, Barber barber) {
  final l = context.l10n;
  final s = WorkingSchedule.of(shop, barber);
  if (s.isEmpty) return l.noWorkingHours;
  final days = (s.days.toList()..sort()).map(fmt.weekdayName).join(', ');
  return l.workingHoursLine(fmt.hoursRange(s.startHour, s.endHour), days);
}

/// Lets the owner set a barber's own working days and hours (within the
/// shop's days and hours), or make them follow the shop again. Pops `true`
/// once saved.
class BarberScheduleDialog extends StatefulWidget {
  const BarberScheduleDialog({super.key, required this.barber, required this.shop});

  final Barber barber;
  final Barbershop shop;

  @override
  State<BarberScheduleDialog> createState() => _BarberScheduleDialogState();
}

class _BarberScheduleDialogState extends State<BarberScheduleDialog> {
  late bool _followShop;
  late Set<int> _days;
  late int _start;
  late int _end;
  bool _saving = false;
  String? _error;

  Barbershop get _shop => widget.shop;

  @override
  void initState() {
    super.initState();
    final b = widget.barber;
    _followShop = b.workingDays == null && b.startHour == null && b.endHour == null;
    final effective = WorkingSchedule.of(_shop, b);
    _days = b.workingDays == null ? _shop.workingDays.toSet() : effective.days;
    _start = effective.startHour.clamp(_shop.openingHour, _shop.closingHour - 1);
    _end = effective.endHour.clamp(_start + 1, _shop.closingHour);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final l = context.l10n;
    try {
      await AppRepository.instance.updateBarberSchedule(
        widget.barber.id,
        workingDays: _followShop ? null : (_days.toList()..sort()),
        startHour: _followShop ? null : _start,
        endHour: _followShop ? null : _end,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is AppException ? l.errorText(e) : l.saveFailed(l.errorText(e));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final shopDays = _shop.workingDays.toList()..sort();
    final hours = [for (var h = _shop.openingHour; h <= _shop.closingHour; h++) h];
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l.barberHoursTitle(widget.barber.name), style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('follow-shop-hours'),
              contentPadding: EdgeInsets.zero,
              value: _followShop,
              activeThumbColor: AppTheme.primaryGold,
              title: Text(l.followShopHours),
              subtitle: Text(
                '${l.followShopHoursSubtitle}\n${l.shopHoursSummary}: ${fmt.hoursRange(_shop.openingHour, _shop.closingHour)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              onChanged: _saving ? null : (v) => setState(() => _followShop = v),
            ),
            if (!_followShop) ...[
              const SizedBox(height: 8),
              Text(l.workingDaysLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in shopDays)
                    FilterChip(
                      key: ValueKey('day-$d'),
                      label: Text(fmt.weekdayName(d)),
                      selected: _days.contains(d),
                      selectedColor: AppTheme.primaryGold.withValues(alpha: 0.3),
                      onSelected: _saving
                          ? null
                          : (on) => setState(() {
                                if (on) {
                                  _days.add(d);
                                } else {
                                  _days.remove(d);
                                }
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('start-hour'),
                      isExpanded: true,
                      initialValue: _start,
                      decoration: InputDecoration(labelText: l.startsAt),
                      items: [
                        for (final h in hours.where((h) => h < _shop.closingHour))
                          DropdownMenuItem(value: h, child: Text(fmt.hour(h))),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _start = v ?? _start),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('end-hour'),
                      isExpanded: true,
                      initialValue: _end,
                      decoration: InputDecoration(labelText: l.endsAt),
                      items: [
                        for (final h in hours.where((h) => h > _shop.openingHour))
                          DropdownMenuItem(value: h, child: Text(fmt.hour(h))),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _end = v ?? _end),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('save-hours'),
          onPressed: _saving ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
