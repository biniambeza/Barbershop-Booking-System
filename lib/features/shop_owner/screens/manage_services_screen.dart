import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
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
    final priceCtrl = TextEditingController(text: '300');
    final durationCtrl = TextEditingController(text: '30');
    final l = context.l10n;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.addNewService, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l.serviceNameHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: l.description),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l.priceEtb, suffixText: l.currencyEtb),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l.durationMins),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
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
              final price = double.tryParse(priceCtrl.text.trim().replaceAll(',', ''));
              final duration = int.tryParse(durationCtrl.text.trim());
              if (nameCtrl.text.trim().isEmpty || price == null || price < 0 || duration == null || duration <= 0) {
                setDialogState(() => error = l.invalidServiceValues);
                return;
              }
              try {
                await AppRepository.instance.addService(
                  shopId: widget.shopId,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  price: price,
                  durationMinutes: duration,
                );
              } catch (e) {
                setDialogState(() => error = l.saveFailed('$e'));
                return;
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) setState(() {});
            },
            child: Text(l.addService),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppRepository.instance.getServicesForShop(widget.shopId);
    final l = context.l10n;
    final fmt = context.fmt;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.manageServicesPricing),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceDialog,
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(l.addService, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: services.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.content_cut, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text(l.noServicesYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(l.noServicesHint, style: const TextStyle(color: AppTheme.textSecondary)),
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
                              l.minutesShort(service.durationMinutes),
                              style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmt.birr(service.price),
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
