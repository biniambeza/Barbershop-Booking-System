import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barbershop_model.dart';
import '../../models/booking_model.dart';
import '../../models/plan_model.dart';
import '../../services/app_repository.dart';
import '../../services/payment_service.dart';

/// Customer: pays [booking] online with Chapa (telebirr, CBE Birr, card).
///
/// Real builds open Chapa's checkout in the browser and then verify the
/// payment when the user comes back (app resume, the booking's live
/// paymentStatus, or the "I've paid" button). Demo/test builds show a fake
/// Chapa sheet instead. Returns the final verification, or null when the
/// user left before finishing (they can pay later from My Appointments).
Future<PaymentVerification?> payForBooking(
  BuildContext context,
  Booking booking, {
  PaymentService? service,
}) {
  final payments = service ?? PaymentService.instance;
  return _runCheckout(
    context,
    payments,
    title: booking.serviceName,
    subtitle: '${booking.shopName} • ${booking.barberName}',
    amount: booking.price,
    bookingId: booking.id,
    create: () => payments.startBookingPayment(booking.id),
  );
}

/// Owner: pays one month of [plan] for [shop] with Chapa.
Future<PaymentVerification?> payForSubscription(
  BuildContext context, {
  required Barbershop shop,
  required SubscriptionPlan plan,
  PaymentService? service,
}) {
  final payments = service ?? PaymentService.instance;
  return _runCheckout(
    context,
    payments,
    title: context.l10n.planOneMonth(context.l10n.planName(plan.id, plan)),
    subtitle: shop.name,
    amount: plan.priceMonthlyEtb,
    create: () => payments.startSubscriptionPayment(shopId: shop.id, planId: plan.id),
  );
}

Future<PaymentVerification?> _runCheckout(
  BuildContext context,
  PaymentService payments, {
  required String title,
  required String subtitle,
  required double amount,
  required Future<PaymentCheckout> Function() create,
  String? bookingId,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  PaymentCheckout checkout;
  try {
    checkout = await _withProgress(context, create(), l10n.preparingCheckout);
  } on PaymentException catch (e) {
    if (e.code == 'already-exists') {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.paymentError(e)), backgroundColor: Colors.green.shade700));
    } else if (context.mounted) {
      await showPaymentError(context, e);
    }
    return null;
  }
  if (!context.mounted) return null;

  PaymentVerification? result;
  try {
    if (checkout.isSimulated) {
      final pay = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SimulatedChapaCheckoutDialog(title: title, subtitle: subtitle, amount: amount),
      );
      if (pay == null || !context.mounted) return null;
      result = await payments.completeSimulatedPayment(checkout.paymentId, success: pay);
    } else {
      await payments.openCheckout(checkout);
      if (!context.mounted) return null;
      result = await showDialog<PaymentVerification>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentWaitingDialog(
          checkout: checkout,
          amount: amount,
          bookingId: bookingId,
          service: payments,
        ),
      );
    }
  } on PaymentException catch (e) {
    if (context.mounted) await showPaymentError(context, e);
    return null;
  }

  if (context.mounted) showPaymentResult(context, result, amount: amount);
  return result;
}

Future<T> _withProgress<T>(BuildContext context, Future<T> future, String label) async {
  final navigator = Navigator.of(context);
  var shown = true;
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppTheme.darkCard,
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryGold),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  ).whenComplete(() => shown = false));
  try {
    return await future;
  } finally {
    if (shown && navigator.mounted) navigator.pop();
  }
}

/// Error dialog for a failed payment call.
Future<void> showPaymentError(BuildContext context, PaymentException error) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.darkCard,
      icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
      title: Text(context.l10n.paymentProblem),
      content: Text(context.l10n.paymentError(error)),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.ok))],
    ),
  );
}

/// Snack bar summarising how a checkout ended.
void showPaymentResult(BuildContext context, PaymentVerification? result, {double? amount}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = context.l10n;
  final fmt = context.fmt;
  if (result == null || result.isPending) {
    messenger.showSnackBar(SnackBar(
      content: Text(l.paymentNotCompleted),
    ));
    return;
  }
  if (result.isSuccess) {
    final until = result.periodEndsAt;
    final extra = until == null ? '' : l.subscriptionActiveUntilSentence(fmt.addisDateMedium(until));
    messenger.showSnackBar(SnackBar(
      backgroundColor: Colors.green.shade700,
      content: Text(l.paymentReceivedAmount(fmt.birr(result.amount), extra)),
    ));
    return;
  }
  messenger.showSnackBar(SnackBar(
    backgroundColor: Colors.red.shade700,
    content: Text(l.paymentFailedRetry),
  ));
}

/// Demo stand-in for Chapa's hosted checkout page. Pops true (pay), false
/// (payment declined/cancelled) or null (closed, payment left pending).
class SimulatedChapaCheckoutDialog extends StatefulWidget {
  const SimulatedChapaCheckoutDialog({super.key, required this.title, required this.subtitle, required this.amount});

  final String title;
  final String subtitle;
  final double amount;

  @override
  State<SimulatedChapaCheckoutDialog> createState() => _SimulatedChapaCheckoutDialogState();
}

class _SimulatedChapaCheckoutDialogState extends State<SimulatedChapaCheckoutDialog> {
  static const _methods = ['telebirr', 'CBE Birr', 'Card'];
  String _method = _methods.first;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(l.chapaCheckoutDemo)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Text(
            context.fmt.birr(widget.amount),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in _methods)
                ChoiceChip(
                  label: Text(m == 'Card' ? l.cardMethod : m),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.chapaDemoNotice,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('demo-chapa-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancelPayment),
        ),
        ElevatedButton(
          key: const ValueKey('demo-chapa-pay'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.payAmount(context.fmt.birr(widget.amount))),
        ),
      ],
    );
  }
}

/// Shown while the user pays in the browser. Verifies the payment when the
/// app comes back to the foreground, when the booking's paymentStatus turns
/// 'paid', or on request. Pops the final [PaymentVerification], or null.
class PaymentWaitingDialog extends StatefulWidget {
  const PaymentWaitingDialog({
    super.key,
    required this.checkout,
    required this.amount,
    required this.service,
    this.bookingId,
  });

  final PaymentCheckout checkout;
  final double amount;
  final PaymentService service;
  final String? bookingId;

  @override
  State<PaymentWaitingDialog> createState() => _PaymentWaitingDialogState();
}

class _PaymentWaitingDialogState extends State<PaymentWaitingDialog> with WidgetsBindingObserver {
  final _repo = AppRepository.instance;
  bool _checking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.bookingId != null) _repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(quiet: true);
  }

  void _onRepoChanged() {
    final booking = _repo.getBookingById(widget.bookingId!);
    if (booking?.paymentStatus == PaymentStatus.paid) _check(quiet: true);
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      if (!quiet) _message = null;
    });
    try {
      final result = await widget.service.verify(widget.checkout.paymentId);
      if (!mounted) return;
      if (!result.isPending) {
        Navigator.of(context).pop(result);
        return;
      }
      setState(() => _message = context.l10n.chapaNotConfirmedYet);
    } on PaymentException catch (e) {
      if (mounted) setState(() => _message = context.l10n.paymentError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _reopen() async {
    try {
      await widget.service.openCheckout(widget.checkout);
    } on PaymentException catch (e) {
      if (mounted) setState(() => _message = context.l10n.paymentError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      icon: const Icon(Icons.open_in_browser_rounded, color: AppTheme.primaryGold, size: 40),
      title: Text(l.completeYourPayment),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.completePaymentBody(context.fmt.birr(widget.amount)),
            textAlign: TextAlign.center,
          ),
          if (_checking) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: AppTheme.primaryGold),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.payLater)),
        TextButton(onPressed: _checking ? null : _reopen, child: Text(l.openAgain)),
        ElevatedButton(
          onPressed: _checking ? null : () => _check(),
          child: Text(l.ivePaid),
        ),
      ],
    );
  }
}

/// Landing page for PAYMENT_RETURN_URL on the web (`?paymentId=...`):
/// verifies the payment and shows the outcome.
class PaymentReturnScreen extends StatefulWidget {
  const PaymentReturnScreen({super.key, required this.paymentId, this.service});

  final String paymentId;
  final PaymentService? service;

  @override
  State<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends State<PaymentReturnScreen> {
  PaymentVerification? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final r = await (widget.service ?? PaymentService.instance).verifyUntilSettled(widget.paymentId);
      if (mounted) setState(() => _result = r);
    } on PaymentException catch (e) {
      if (mounted) setState(() => _error = context.l10n.paymentError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final l = context.l10n;
    final fmt = context.fmt;
    Widget body;
    if (_error != null) {
      body = _status(Icons.error_outline_rounded, Colors.redAccent, l.couldNotCheckPayment, _error!);
    } else if (r == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryGold),
          const SizedBox(height: 16),
          Text(l.checkingPayment),
        ],
      );
    } else if (r.isSuccess) {
      final what = r.type == PaymentType.subscription
          ? (r.periodEndsAt == null ? l.subscriptionIsActive : l.subscriptionActiveUntil(fmt.addisDateMedium(r.periodEndsAt!)))
          : l.bookingIsPaid;
      body = _status(Icons.check_circle_rounded, Colors.greenAccent, l.paymentReceived, l.amountThen(fmt.birr(r.amount), what));
    } else if (r.isPending) {
      body = _status(Icons.hourglass_top_rounded, Colors.orangeAccent, l.stillProcessing, l.stillProcessingBody);
    } else {
      body = _status(Icons.cancel_rounded, Colors.redAccent, l.paymentFailed, l.noMoneyTaken);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.paymentTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              body,
              const SizedBox(height: 24),
              if ((r != null && r.isPending) || _error != null)
                OutlinedButton(onPressed: _verify, child: Text(l.checkAgain)),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l.done)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(IconData icon, Color color, String title, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 64),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }
}

/// Opens [PaymentReturnScreen] once the user is signed in when the app was
/// launched from Chapa's return URL (web: `PAYMENT_RETURN_URL?paymentId=`).
class PaymentReturnHandler {
  PaymentReturnHandler._();

  static bool _started = false;

  /// Call once from main() with `Uri.base` and the app's navigator key.
  static void start({required Uri uri, required GlobalKey<NavigatorState> navigatorKey, AppRepository? repository}) {
    if (_started) return;
    final paymentId = PaymentService.paymentIdFromReturnUri(uri);
    if (paymentId == null) return;
    _started = true;
    final repo = repository ?? AppRepository.instance;
    var opened = false;

    void tryOpen() {
      if (opened || repo.authStatus != AuthStatus.signedIn) return;
      final nav = navigatorKey.currentState;
      if (nav == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryOpen());
        return;
      }
      opened = true;
      repo.removeListener(tryOpen);
      nav.push(MaterialPageRoute<void>(builder: (_) => PaymentReturnScreen(paymentId: paymentId)));
    }

    repo.addListener(tryOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => tryOpen());
  }
}
