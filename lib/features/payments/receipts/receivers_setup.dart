import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/ui_kit.dart';
import 'admin_pricing_screen.dart';
import 'subscription_receipts_service.dart';

/// Receiver validation messages in the active language.
extension ReceiversL10n on AppLocalizations {
  String receiverIssueText(ReceiptMethod method, ReceiverIssue issue) {
    switch (issue) {
      case ReceiverIssue.placeholder:
        return rcvErrPlaceholder;
      case ReceiverIssue.invalidAccount:
        return method == ReceiptMethod.cbe ? rcvErrCbe : rcvErrPhone;
      case ReceiverIssue.nameTooShort:
        return rcvErrNameShort;
      case ReceiverIssue.nameTooLong:
        return rcvErrNameLong;
    }
  }
}

/// Listens to `platformConfig/subscriptionPricing` and tells [builder]
/// whether the admin still has to set up where owners pay. Says false
/// until the first value arrives, so nothing flashes while loading.
class ReceiversSetupStatus extends StatefulWidget {
  const ReceiversSetupStatus({super.key, required this.builder, this.service});

  final Widget Function(BuildContext context, bool needsSetup) builder;

  /// Defaults to [SubscriptionReceiptsService.instance].
  final SubscriptionReceiptsService? service;

  @override
  State<ReceiversSetupStatus> createState() => _ReceiversSetupStatusState();
}

class _ReceiversSetupStatusState extends State<ReceiversSetupStatus> {
  StreamSubscription<SubscriptionPricing>? _sub;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    final service = widget.service ?? SubscriptionReceiptsService.instance;
    _sub = service.watchPricing().listen(
      (p) {
        if (mounted && _needsSetup == p.hasReadyReceiver) setState(() => _needsSetup = !p.hasReadyReceiver);
      },
      // Not readable (offline, rules): stay quiet rather than nag.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _needsSetup);
}

/// Admin dashboard, above the tabs: "Set up where shop owners pay you"
/// until a telebirr number or CBE account is saved. It cannot be closed;
/// it goes away once a receiver is configured.
class ReceiversSetupBanner extends StatelessWidget {
  const ReceiversSetupBanner({super.key, this.service});

  final SubscriptionReceiptsService? service;

  @override
  Widget build(BuildContext context) {
    return ReceiversSetupStatus(
      service: service,
      builder: (context, needsSetup) => needsSetup
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: ReceiversSetupCard(
                onSetUp: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminPricingScreen(service: service)),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// The setup card itself.
class ReceiversSetupCard extends StatelessWidget {
  const ReceiversSetupCard({super.key, required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Compact so the tab content below keeps its room on phones; the
    // explanation is added on wide screens.
    return LayoutBuilder(
      builder: (context, constraints) => AppCard(
        key: const ValueKey('receivers-setup-card'),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        color: AppTheme.orangeSoft,
        borderColor: AppTheme.orange,
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppTheme.warning, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.rcvSetupTitle,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textPrimary)),
                  if (constraints.maxWidth >= 560) ...[
                    const SizedBox(height: 2),
                    Text(l.rcvSetupBody, style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              key: const ValueKey('receivers-setup-open'),
              onPressed: onSetUp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 38),
              ),
              child: Text(l.rcvSetupButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// A red dot on [child] (the dashboard's Payments tab icon) while the
/// receivers are not set up.
class ReceiversSetupDot extends StatelessWidget {
  const ReceiversSetupDot({super.key, required this.child, this.service});

  final Widget child;
  final SubscriptionReceiptsService? service;

  @override
  Widget build(BuildContext context) {
    return ReceiversSetupStatus(
      service: service,
      builder: (context, needsSetup) => needsSetup
          ? Semantics(
              label: context.l10n.rcvSetupDotLabel,
              child: Badge(
                key: const ValueKey('receivers-setup-dot'),
                smallSize: 9,
                backgroundColor: AppTheme.red,
                child: child,
              ),
            )
          : child,
    );
  }
}
