import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../reviews/reviews_l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/barbershop_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/rating_service.dart';
import '../../../services/availability_service.dart' show WorkingSchedule;
import '../../shared/widgets/ui_kit.dart';
import '../widgets/add_barber_sheet.dart'; // barber accounts
import '../../payouts/payouts_screen.dart' show showCommissionDialog; // barber commission
import '../../../services/payout_service.dart' show commissionOf; // barber commission
import '../../portfolio/widgets/portfolio_entries.dart' show ManagePortfolioLink; // barber portfolio

class ManageBarbersScreen extends StatefulWidget {
  final String shopId;

  const ManageBarbersScreen({super.key, required this.shopId});

  @override
  State<ManageBarbersScreen> createState() => _ManageBarbersScreenState();
}

class _ManageBarbersScreenState extends State<ManageBarbersScreen> {
  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
  ];

  // --- barber accounts: add a barber with a login + temporary password ---
  Future<void> _showAddBarberDialog() async {
    await showAddBarberSheet(context, shopId: widget.shopId, avatarPresets: _avatarPresets);
    if (mounted) setState(() {});
  }
  // --- end barber accounts ---

  void _confirmDeleteBarber(String barberId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(context.l10n.removeBarberTitle),
        content: Text(context.l10n.removeBarberBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white),
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

  // --- barber commission ---
  Future<void> _editCommission(Barber barber) async {
    final saved = await showCommissionDialog(context, barber);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.payoutsCommissionSaved)));
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
        backgroundColor: AppTheme.ink,
        foregroundColor: AppTheme.onInk,
        icon: const Icon(Icons.person_add),
        label: Text(context.l10n.addBarber, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: barbers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const IconTile(icon: Icons.people_outline, color: AppTheme.textSecondary, size: 64),
                  const SizedBox(height: 12),
                  Text(context.l10n.noBarbersYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(context.l10n.noBarbersHint, style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: barbers.length,
              itemBuilder: (context, index) {
                final barber = barbers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: barber.avatarUrl != null ? NetworkImage(barber.avatarUrl!) : null,
                        onBackgroundImageError: barber.avatarUrl != null ? (error, stackTrace) {} : null,
                        backgroundColor: AppTheme.surface,
                        child: barber.avatarUrl == null
                            ? Text(barber.name.substring(0, 1),
                                style: const TextStyle(color: AppTheme.onInk, fontSize: 18))
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              barber.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              barber.title,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            // Barber accounts: waiting for first login / invitation / active.
                            BarberAccountStatus(barber: barber),
                            BarberPhoneLine(barber: barber), // private barber phone
                            if (shop != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _scheduleSummary(context, fmt, shop, barber),
                                key: ValueKey('barber-hours-${barber.id}'),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                            // --- barber commission ---
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.payoutsCommissionLine(commissionOf(barber)),
                              key: ValueKey('barber-commission-${barber.id}'),
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            // --- end barber commission ---
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 15, color: AppTheme.orange),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    context.l10n.barberRatingText(barberRatingSummary(barber)),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            ManagePortfolioLink(barber: barber), // barber portfolio
                          ],
                        ),
                      ),
                      if (shop != null)
                        IconButton(
                          key: ValueKey('edit-hours-${barber.id}'),
                          icon: const Icon(Icons.schedule, size: 20, color: AppTheme.ink),
                          tooltip: context.l10n.editWorkingHours,
                          onPressed: () => _editSchedule(barber, shop),
                        ),
                      // --- barber commission ---
                      IconButton(
                        key: ValueKey('edit-commission-${barber.id}'),
                        icon: const Icon(Icons.percent_rounded, size: 20, color: AppTheme.ink),
                        tooltip: context.l10n.payoutsSetCommission,
                        onPressed: () => _editCommission(barber),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
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

// --- private barber phone ---
/// The barber's private phone (AppRepository.getBarberPhone: staff and
/// admins only) with an edit button. Live: the contact doc arrives after
/// the barber list.
class BarberPhoneLine extends StatelessWidget {
  const BarberPhoneLine({super.key, required this.barber});

  final Barber barber;

  Future<void> _edit(BuildContext context, String? current) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BarberPhoneDialog(barberId: barber.id, initial: current),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.barberPhoneSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final l = context.l10n;
        final phone = repo.getBarberPhone(barber.id);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: InkWell(
            key: ValueKey('barber-phone-edit-${barber.id}'),
            onTap: () => _edit(context, phone),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    phone == null ? l.barberPhoneNone : context.fmt.phone(phone),
                    key: ValueKey('barber-phone-${barber.id}'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined, size: 13, semanticLabel: l.barberPhoneEdit, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sets or clears a barber's private phone (AppRepository.updateBarberPhone).
/// Pops `true` once saved.
class BarberPhoneDialog extends StatefulWidget {
  const BarberPhoneDialog({super.key, required this.barberId, this.initial});

  final String barberId;
  final String? initial;

  @override
  State<BarberPhoneDialog> createState() => _BarberPhoneDialogState();
}

class _BarberPhoneDialogState extends State<BarberPhoneDialog> {
  late final TextEditingController _phone = TextEditingController(text: widget.initial ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppRepository.instance.updateBarberPhone(widget.barberId, _phone.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AppFormatException && e.code == AppErrorCode.invalidPhone ? l.invalidPhoneShort : l.errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(l.barberPhoneEdit),
      content: TextField(
        key: const ValueKey('barber-phone-field'),
        controller: _phone,
        enabled: !_busy,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: l.barberMobileOptional,
          hintText: '09XX XXX XXX',
          helperText: l.barberPhoneHelper,
          helperMaxLines: 3,
          errorText: _error,
          prefixIcon: const Icon(Icons.phone_android),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          key: const ValueKey('barber-phone-save'),
          onPressed: _busy ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
// --- end private barber phone ---

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
      backgroundColor: AppTheme.card,
      title: Text(l.barberHoursTitle(widget.barber.name), style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('follow-shop-hours'),
              contentPadding: EdgeInsets.zero,
              value: _followShop,
              activeThumbColor: Colors.white,
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
                      label: Text(
                        fmt.weekdayName(d),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _days.contains(d) ? AppTheme.onInk : AppTheme.textPrimary,
                        ),
                      ),
                      selected: _days.contains(d),
                      selectedColor: AppTheme.ink,
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
              Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
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
