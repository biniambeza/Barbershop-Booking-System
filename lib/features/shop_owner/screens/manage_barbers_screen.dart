import 'package:flutter/material.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';

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
                } on FormatException catch (e) {
                  setDialogState(() => phoneError = e.message);
                  return;
                } catch (e) {
                  setDialogState(() => phoneError = l.addBarberFailed);
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
                messenger.showSnackBar(SnackBar(content: Text(l.saveFailed('$e'))));
              }
              if (mounted) setState(() {});
            },
            child: Text(context.l10n.remove, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barbers = AppRepository.instance.getBarbersForShop(widget.shopId);

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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: AppTheme.primaryGold),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.reviewsCount(barber.rating.toStringAsFixed(1), barber.reviewCount),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
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
