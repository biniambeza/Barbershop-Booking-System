import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/app_repository.dart';

class ManageBarbersScreen extends StatefulWidget {
  final String shopId;

  const ManageBarbersScreen({super.key, required this.shopId});

  @override
  State<ManageBarbersScreen> createState() => _ManageBarbersScreenState();
}

class _ManageBarbersScreenState extends State<ManageBarbersScreen> {
  void _showAddBarberDialog() {
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'Stylist & Fade Specialist');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Barber / Stylist', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Barber Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title / Specialization'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              AppRepository.instance.addBarber(
                shopId: widget.shopId,
                name: nameCtrl.text.trim(),
                title: titleCtrl.text.trim(),
              );
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Add Barber'),
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
        title: const Text('Manage Barbers & Staff'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBarberDialog,
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Barber', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: barbers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  const Text('No barbers added yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Add barbers so clients can book appointments with them.', style: TextStyle(color: AppTheme.textSecondary)),
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
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: AppTheme.primaryGold),
                                const SizedBox(width: 4),
                                Text(
                                  '${barber.rating} (${barber.reviewCount} reviews)',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
