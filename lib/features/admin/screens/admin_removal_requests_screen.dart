import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_shop_edit_screen.dart';

/// Admin: shop owners who want to delete their account ask for their shop
/// to be removed first (`shopRemovalRequests/{uid}`, account deletion).
/// The admin opens the shop, deletes it with the existing shop deletion,
/// then marks the request done (or dismisses it).
class AdminRemovalRequestsScreen extends StatefulWidget {
  const AdminRemovalRequestsScreen({super.key});

  @override
  State<AdminRemovalRequestsScreen> createState() => _AdminRemovalRequestsScreenState();
}

class _AdminRemovalRequestsScreenState extends State<AdminRemovalRequestsScreen> {
  late final Stream<List<ShopRemovalRequest>> _requests = AppRepository.instance.watchShopRemovalRequests();
  final Set<String> _busy = {};

  Future<void> _resolve(ShopRemovalRequest r, ShopRemovalStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy.add(r.uid));
    try {
      await AppRepository.instance.resolveShopRemovalRequest(r.uid, status);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(r.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminRemovalRequestsTitle)),
      body: SafeArea(
        child: StreamBuilder<List<ShopRemovalRequest>>(
          stream: _requests,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text(l.errorText(snap.error!), textAlign: TextAlign.center));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.ink));
            final requests = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                AppCard(
                  color: AppTheme.surface,
                  child: Text(l.adminRemovalHelp,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(l.adminRemovalEmpty,
                        key: const ValueKey('admin-removal-empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  ),
                for (final r in requests) ...[
                  _RequestCard(
                    request: r,
                    busy: _busy.contains(r.uid),
                    onResolve: (status) => _resolve(r, status),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.busy, required this.onResolve});

  final ShopRemovalRequest request;
  final bool busy;
  final void Function(ShopRemovalStatus status) onResolve;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final repo = AppRepository.instance;
    final shopExists = repo.getShopById(request.shopId) != null;
    final (statusLabel, statusColor) = switch (request.status) {
      ShopRemovalStatus.pending => (l.shopRemovalStatusPending, AppTheme.warning),
      ShopRemovalStatus.done => (l.shopRemovalStatusDone, AppTheme.success),
      ShopRemovalStatus.dismissed => (l.shopRemovalStatusDismissed, AppTheme.slate),
    };
    return AppCard(
      key: ValueKey('removal-request-${request.uid}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.storefront_rounded, color: AppTheme.ink, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.shopName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${request.name} · ${request.email}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              StatusChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.adminRemovalRequestedOn(fmt.addisDateMedium(request.createdAt)),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (request.note != null) ...[
            const SizedBox(height: 8),
            Text('"${request.note}"', style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (!shopExists) ...[
            const SizedBox(height: 8),
            Text(l.adminRemovalShopGone, style: const TextStyle(fontSize: 12, color: AppTheme.success)),
          ],
          if (request.isPending) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (shopExists)
                  OutlinedButton.icon(
                    key: ValueKey('removal-open-shop-${request.uid}'),
                    style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => AdminShopEditScreen(shopId: request.shopId),
                    )),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l.adminRemovalOpenShop),
                  ),
                FilledButton(
                  key: ValueKey('removal-done-${request.uid}'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.green, foregroundColor: Colors.white, shape: const StadiumBorder()),
                  onPressed: busy ? null : () => onResolve(ShopRemovalStatus.done),
                  child: Text(l.adminRemovalMarkDone),
                ),
                TextButton(
                  key: ValueKey('removal-dismiss-${request.uid}'),
                  onPressed: busy ? null : () => onResolve(ShopRemovalStatus.dismissed),
                  child: Text(l.adminRemovalDismiss),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
