import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/app_repository.dart';

class ManageServicesScreen extends StatefulWidget {
  final String shopId;

  const ManageServicesScreen({super.key, required this.shopId});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  void _showAddServiceDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '35');
    final durationCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Service', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Service Name (e.g. Beard Trim)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (\$)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (mins)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              AppRepository.instance.addService(
                shopId: widget.shopId,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 30.0,
                durationMinutes: int.tryParse(durationCtrl.text) ?? 30,
              );
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Add Service'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppRepository.instance.getServicesForShop(widget.shopId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services & Pricing'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceDialog,
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Service', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: services.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.content_cut, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  const Text('No services created yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Tap "Add Service" below to publish your salon pricing.', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.content_cut, color: AppTheme.primaryGold, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service.description,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${service.durationMinutes} mins',
                              style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${service.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryGold),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
