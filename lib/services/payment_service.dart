import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/barbershop_model.dart';
import '../models/booking_model.dart';
import '../models/payment_model.dart';
import '../models/plan_model.dart';
import '../models/user_model.dart';
import 'app_repository.dart';

export '../models/payment_model.dart';

/// Region of the payments Cloud Functions codebase (functions/payments).
const String kPaymentsRegion = 'europe-west1';

/// A pending checkout is reused instead of creating a new one for this long
/// (same as PENDING_REUSE_MINUTES in functions/payments/src/config.ts).
const Duration kPendingCheckoutReuse = Duration(minutes: 30);

/// Days after subscriptionEndsAt before a past_due shop is suspended
/// (GRACE_DAYS in functions/payments/src/config.ts).
const int kSubscriptionGraceDays = 7;

/// Longest manual extension an admin can give at once (MAX_MANUAL_MONTHS).
const int kMaxManualMonths = 24;

/// Defaults written by seedDefaultPlans (DEFAULT_PLANS in config.ts).
const List<SubscriptionPlan> kDefaultPaidPlans = [
  SubscriptionPlan(
    id: 'basic',
    name: 'Basic',
    priceMonthlyEtb: 500,
    maxBarbers: 3,
    features: ['Online booking', 'Up to 3 barbers', 'SMS reminders'],
  ),
  SubscriptionPlan(
    id: 'pro',
    name: 'Pro',
    priceMonthlyEtb: 1200,
    maxBarbers: -1,
    features: ['Online booking', 'Unlimited barbers', 'SMS reminders', 'Online payments (Chapa)', 'Priority listing'],
  ),
];

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// A payment call failed. [code] is the callable error code ('not-found',
/// 'already-exists', 'unavailable', ...) or 'launch-failed' / 'unknown';
/// [message] is ready to show to the user.
class PaymentException implements Exception {
  final String code;
  final String message;

  const PaymentException(this.code, this.message);

  /// Builds an exception with the user-facing text for [code].
  factory PaymentException.of(String code, [String? serverMessage]) =>
      PaymentException(code, paymentErrorMessage(code, serverMessage));

  @override
  String toString() => message;
}

/// User-friendly text for a payments callable error. The backend's own
/// messages for permission / precondition / not-found errors are already
/// written for users, so they are used when present.
String paymentErrorMessage(String code, [String? serverMessage]) {
  final server = serverMessage?.trim();
  final hasServer = server != null && server.isNotEmpty && !server.toUpperCase().contains('INTERNAL');
  if (hasServer && server.contains('PAYMENT_RETURN_URL')) {
    return 'Online payments are not set up yet. Please pay at the shop.';
  }
  switch (code) {
    case 'unauthenticated':
      return 'Please sign in again to make a payment.';
    case 'permission-denied':
      return hasServer ? server : 'You are not allowed to make this payment.';
    case 'not-found':
      return hasServer ? server : 'We could not find this item. It may have been removed.';
    case 'already-exists':
      return 'This booking is already paid.';
    case 'failed-precondition':
      return hasServer ? server : 'This payment cannot be made right now.';
    case 'invalid-argument':
      return hasServer ? server : 'Some payment details are missing or invalid.';
    case 'aborted':
      return 'Something changed while we prepared your payment. Please try again.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'The payment service (Chapa) is not reachable right now. Please try again in a few minutes.';
    case 'launch-failed':
      return 'Could not open the Chapa checkout page. Please try again.';
    default:
      return 'The payment could not be completed. Please try again.';
  }
}

/// Normalises any error from a payment call into a [PaymentException].
PaymentException paymentExceptionFrom(Object error) {
  if (error is PaymentException) return error;
  if (error is FirebaseFunctionsException) {
    final code = error.code.toLowerCase().replaceAll('_', '-');
    return PaymentException.of(code, error.message);
  }
  if (error is TimeoutException) return PaymentException.of('deadline-exceeded');
  if (error is FirebaseException) {
    return PaymentException.of(error.code.toLowerCase().replaceAll('_', '-'), error.message);
  }
  return PaymentException.of('unknown');
}

// ---------------------------------------------------------------------------
// Pure helpers (shared by the UI and the offline simulator; mirror
// functions/payments/src/logic)
// ---------------------------------------------------------------------------

/// Adds calendar months in UTC, clamping the day (Jan 31 + 1 month = Feb 28/29).
DateTime addMonthsUtc(DateTime date, int months) {
  final d = date.toUtc();
  final m = d.month - 1 + months;
  final year = d.year + (m ~/ 12) - (m < 0 && m % 12 != 0 ? 1 : 0);
  final month = ((m % 12) + 12) % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime.utc(year, month, day, d.hour, d.minute, d.second, d.millisecond);
}

/// New period end after paying [months]: extends from the current end while
/// it is still in the future (paying early never loses days), otherwise
/// from now.
DateTime extendSubscriptionEnd(DateTime? currentEnd, DateTime nowUtc, [int months = 1]) {
  final now = nowUtc.toUtc();
  final base = currentEnd != null && currentEnd.toUtc().isAfter(now) ? currentEnd.toUtc() : now;
  return addMonthsUtc(base, months);
}

/// Whole days until [endsAt] (rounded up; 0 on the last day, negative once
/// it has passed). Null when there is no end date.
int? subscriptionDaysLeft(DateTime? endsAt, DateTime nowUtc) {
  if (endsAt == null) return null;
  final diff = endsAt.toUtc().difference(nowUtc.toUtc());
  if (diff.isNegative) return -((-diff.inMinutes) / (60 * 24)).ceil();
  return (diff.inMinutes / (60 * 24)).ceil();
}

/// Mirrors checkBookingPayable in functions/payments/src/logic/eligibility.ts.
PaymentException? checkBookingPayable(Booking? booking, String uid) {
  if (booking == null) return PaymentException.of('not-found', 'Booking not found.');
  if (booking.customerId != uid) {
    return PaymentException.of('permission-denied', 'Only the customer who made this booking can pay for it.');
  }
  if (booking.status == BookingStatus.cancelled) {
    return PaymentException.of('failed-precondition', 'This booking was cancelled.');
  }
  if (booking.paymentStatus == PaymentStatus.paid) return PaymentException.of('already-exists');
  if (booking.paymentStatus == PaymentStatus.refunded) {
    return PaymentException.of('failed-precondition', 'This booking was refunded.');
  }
  if (!(booking.price > 0)) return PaymentException.of('failed-precondition', 'This booking has no valid price.');
  return null;
}

/// Whether the customer may start an online payment for [booking] (used to
/// show the "Pay now" button).
bool canPayBookingOnline(Booking booking) =>
    booking.status != BookingStatus.cancelled &&
    booking.status != BookingStatus.completed &&
    booking.price > 0 &&
    (booking.paymentStatus == PaymentStatus.unpaid || booking.paymentStatus == PaymentStatus.pending);

/// Mirrors checkPlanFitsShop in eligibility.ts.
PaymentException? checkPlanFitsShop(SubscriptionPlan plan, int barberCount) {
  if (plan.allowsBarbers(barberCount)) return null;
  return PaymentException.of(
    'failed-precondition',
    'This plan allows ${plan.maxBarbers} barbers but the shop has $barberCount. Choose a bigger plan or remove barbers.',
  );
}

String planDisplayName(String planId, [SubscriptionPlan? plan]) {
  if (plan != null) return plan.name;
  switch (planId) {
    case 'trial':
      return 'Free trial';
    case 'basic':
      return 'Basic';
    case 'pro':
      return 'Pro';
    default:
      return planId;
  }
}

// ---------------------------------------------------------------------------
// Backends
// ---------------------------------------------------------------------------

/// What the app can ask of the payments system.
abstract class PaymentBackend {
  /// True for the offline simulator (no Chapa page to open).
  bool get isSimulated;

  Future<PaymentCheckout> createBookingPayment(String bookingId);
  Future<PaymentCheckout> createSubscriptionPayment({required String shopId, required String planId});
  Future<PaymentVerification> verifyPayment(String paymentId);

  /// Admin only. Pass [endsAt] or [months], not both.
  Future<ShopSubscriptionUpdate> setShopSubscription({
    required String shopId,
    String? plan,
    SubscriptionStatus? status,
    DateTime? endsAt,
    int? months,
  });

  /// Admin only. Returns the ids written.
  Future<List<String>> seedDefaultPlans({bool overwrite = false});

  /// Payments of one shop (owner / admin), newest first.
  Stream<List<PaymentRecord>> watchShopPayments(String shopId);

  /// The signed-in user's own payments, newest first.
  Stream<List<PaymentRecord>> watchUserPayments(String uid);
}

List<PaymentRecord> _newestFirst(Iterable<PaymentRecord> payments) =>
    payments.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// Production: the callables of functions/payments and read-only queries on
/// `payments`.
class CloudPaymentBackend implements PaymentBackend {
  CloudPaymentBackend({FirebaseFunctions? functions, FirebaseFirestore? firestore})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: kPaymentsRegion),
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  /// Max docs per payments query (no orderBy, so no composite index).
  static const int historyLimit = 50;

  @override
  bool get isSimulated => false;

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final callable = _functions.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 60)));
    final result = await callable.call<dynamic>(data);
    final raw = result.data;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  @override
  Future<PaymentCheckout> createBookingPayment(String bookingId) async =>
      PaymentCheckout.fromMap(await _call('createBookingPayment', {'bookingId': bookingId}));

  @override
  Future<PaymentCheckout> createSubscriptionPayment({required String shopId, required String planId}) async =>
      PaymentCheckout.fromMap(await _call('createSubscriptionPayment', {'shopId': shopId, 'planId': planId}));

  @override
  Future<PaymentVerification> verifyPayment(String paymentId) async =>
      PaymentVerification.fromMap(await _call('verifyPayment', {'paymentId': paymentId}));

  @override
  Future<ShopSubscriptionUpdate> setShopSubscription({
    required String shopId,
    String? plan,
    SubscriptionStatus? status,
    DateTime? endsAt,
    int? months,
  }) async {
    final data = await _call('setShopSubscription', {
      'shopId': shopId,
      if (plan != null) 'plan': plan,
      if (status != null) 'status': status.value,
      if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
      if (months != null) 'months': months,
    });
    return ShopSubscriptionUpdate.fromMap(data);
  }

  @override
  Future<List<String>> seedDefaultPlans({bool overwrite = false}) async {
    final data = await _call('seedDefaultPlans', {'overwrite': overwrite});
    return (data['written'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
  }

  Stream<List<PaymentRecord>> _watch(Query<Map<String, dynamic>> query) => query
      .limit(historyLimit)
      .snapshots()
      .map((snap) => _newestFirst(snap.docs.map((d) => PaymentRecord.fromMap(d.data(), d.id))));

  @override
  Stream<List<PaymentRecord>> watchShopPayments(String shopId) =>
      _watch(_db.collection('payments').where('shopId', isEqualTo: shopId));

  @override
  Stream<List<PaymentRecord>> watchUserPayments(String uid) =>
      _watch(_db.collection('payments').where('userId', isEqualTo: uid));
}

/// Offline simulator for DEMO_MODE builds and tests. It follows the same
/// rules as the Cloud Functions (who may pay, plan limits, period maths) and
/// writes results into the local repository, so every flow is clickable
/// without a network or Chapa account. A checkout stays 'pending' until
/// [completeSimulatedPayment] is called (the UI's fake Chapa sheet).
class LocalPaymentBackend implements PaymentBackend {
  LocalPaymentBackend({AppRepository? repository, DateTime Function()? clock})
      : _repo = repository ?? AppRepository.instance,
        _clock = clock ?? DateTime.now;

  final AppRepository _repo;
  final DateTime Function() _clock;
  final Map<String, PaymentRecord> _payments = {};

  /// bookingId -> its current (latest) payment id, like bookings.paymentId.
  final Map<String, String> _bookingPaymentIds = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _seq = 0;

  DateTime get _now => _clock().toUtc();

  @override
  bool get isSimulated => true;

  /// All simulated payments, newest first.
  List<PaymentRecord> get payments => _newestFirst(_payments.values);

  AppUser _requireUser() {
    final user = _repo.currentUser;
    if (user == null) throw PaymentException.of('unauthenticated');
    return user;
  }

  void _requireAdmin() {
    if (_requireUser().role != UserRole.admin) throw PaymentException.of('permission-denied', 'Admins only.');
  }

  PaymentRecord _newPayment({
    required PaymentType type,
    String? bookingId,
    required String shopId,
    required String userId,
    String? plan,
    required double amount,
  }) {
    _seq++;
    final id = 'demo_pay_${_now.millisecondsSinceEpoch}_$_seq';
    final record = PaymentRecord(
      id: id,
      type: type,
      bookingId: bookingId,
      shopId: shopId,
      userId: userId,
      plan: plan,
      amount: (amount * 100).roundToDouble() / 100,
      txRef: 'cb-$id',
      status: PaymentRecordStatus.pending,
      checkoutUrl: '$kSimulatedCheckoutScheme$id',
      createdAt: _now,
    );
    _payments[id] = record;
    _changes.add(null);
    return record;
  }

  PaymentCheckout _checkoutOf(PaymentRecord p) =>
      PaymentCheckout(checkoutUrl: p.checkoutUrl, paymentId: p.id, txRef: p.txRef);

  @override
  Future<PaymentCheckout> createBookingPayment(String bookingId) async {
    final user = _requireUser();
    final booking = _repo.getBookingById(bookingId);
    final denial = checkBookingPayable(booking, user.uid);
    if (denial != null) throw denial;

    // Reuse a recent pending checkout (as the backend does).
    final currentId = _bookingPaymentIds[bookingId];
    final current = currentId == null ? null : _payments[currentId];
    if (current != null &&
        current.status == PaymentRecordStatus.pending &&
        _now.difference(current.createdAt) < kPendingCheckoutReuse) {
      return _checkoutOf(current);
    }

    final record = _newPayment(
      type: PaymentType.booking,
      bookingId: bookingId,
      shopId: booking!.shopId,
      userId: user.uid,
      amount: booking.price,
    );
    _bookingPaymentIds[bookingId] = record.id;
    _repo.applySimulatedBookingPayment(bookingId, PaymentStatus.pending);
    return _checkoutOf(record);
  }

  @override
  Future<PaymentCheckout> createSubscriptionPayment({required String shopId, required String planId}) async {
    final user = _requireUser();
    if (!SubscriptionPlan.purchasableIds.contains(planId)) throw PaymentException.of('invalid-argument', 'Unknown plan.');
    final shop = _repo.getShopById(shopId);
    final ownsShop = user.role == UserRole.barbershopOwner &&
        user.shopId == shopId &&
        (shop == null || shop.ownerId.isEmpty || shop.ownerId == user.uid);
    if (!ownsShop) {
      throw PaymentException.of('permission-denied', 'Only the owner of this shop can pay its subscription.');
    }
    if (shop == null) throw PaymentException.of('not-found', 'Shop not found.');
    final plan = _repo.getPlan(planId);
    if (plan == null || !plan.active) throw PaymentException.of('not-found', 'This plan is not available.');
    if (!(plan.priceMonthlyEtb > 0)) throw PaymentException.of('failed-precondition', 'This plan has no valid price.');
    final fit = checkPlanFitsShop(plan, _repo.getBarbersForShop(shopId).length);
    if (fit != null) throw fit;

    final record = _newPayment(
      type: PaymentType.subscription,
      shopId: shopId,
      userId: user.uid,
      plan: planId,
      amount: plan.priceMonthlyEtb,
    );
    return _checkoutOf(record);
  }

  /// The fake Chapa page's result. Success marks the booking paid or extends
  /// the shop's subscription by one month; failure (or cancelling) marks the
  /// payment failed and frees the booking for another attempt.
  Future<PaymentVerification> completeSimulatedPayment(String paymentId, {bool success = true}) async {
    final record = _payments[paymentId];
    if (record == null) throw PaymentException.of('not-found', 'Payment not found.');
    if (record.status == PaymentRecordStatus.success) return PaymentVerification.fromRecord(record);

    var updated = record.copyWith(
      status: success ? PaymentRecordStatus.success : PaymentRecordStatus.failed,
      verifiedAt: _now,
      failureReason: success ? null : 'chapa_status_failed',
    );

    if (record.type == PaymentType.booking && record.bookingId != null) {
      final isCurrent = _bookingPaymentIds[record.bookingId] == record.id;
      if (success) {
        _repo.applySimulatedBookingPayment(record.bookingId!, PaymentStatus.paid);
      } else if (isCurrent) {
        _repo.applySimulatedBookingPayment(record.bookingId!, PaymentStatus.unpaid);
      }
    } else if (record.type == PaymentType.subscription && success) {
      final shop = _repo.getShopById(record.shopId);
      if (shop != null) {
        final end = extendSubscriptionEnd(shop.subscriptionEndsAt, _now);
        await _repo.updateShopSubscription(
          shop.id,
          plan: record.plan ?? shop.subscriptionPlan,
          status: SubscriptionStatus.active,
          endsAt: end,
        );
        updated = updated.copyWith(periodEndsAt: end);
      }
    }

    _payments[paymentId] = updated;
    _changes.add(null);
    return PaymentVerification.fromRecord(updated);
  }

  @override
  Future<PaymentVerification> verifyPayment(String paymentId) async {
    final user = _requireUser();
    final record = _payments[paymentId];
    if (record == null) throw PaymentException.of('not-found', 'Payment not found.');
    final isOwner = user.role == UserRole.barbershopOwner && user.shopId == record.shopId;
    if (record.userId != user.uid && user.role != UserRole.admin && !isOwner) {
      throw PaymentException.of('permission-denied', 'Not your payment.');
    }
    return PaymentVerification.fromRecord(record);
  }

  @override
  Future<ShopSubscriptionUpdate> setShopSubscription({
    required String shopId,
    String? plan,
    SubscriptionStatus? status,
    DateTime? endsAt,
    int? months,
  }) async {
    _requireAdmin();
    final shop = _repo.getShopById(shopId);
    if (shop == null) throw PaymentException.of('not-found', 'Shop not found.');
    if (endsAt != null && months != null) {
      throw PaymentException.of('invalid-argument', 'Pass either an end date or a number of months, not both.');
    }
    if (months != null && (months < 1 || months > kMaxManualMonths)) {
      throw PaymentException.of('invalid-argument', 'months must be between 1 and $kMaxManualMonths.');
    }
    if (plan != null && !SubscriptionPlan.knownIds.contains(plan)) {
      throw PaymentException.of('invalid-argument', 'Unknown plan.');
    }
    if (plan == null && status == null && endsAt == null && months == null) {
      throw PaymentException.of('invalid-argument', 'Nothing to change.');
    }
    final newEnd = months != null ? extendSubscriptionEnd(shop.subscriptionEndsAt, _now, months) : (endsAt ?? shop.subscriptionEndsAt);
    final newStatus = status ?? (months != null ? SubscriptionStatus.active : shop.subscriptionStatus);
    final newPlan = plan ?? shop.subscriptionPlan;
    await _repo.updateShopSubscription(shopId, plan: newPlan, status: newStatus, endsAt: newEnd);
    return ShopSubscriptionUpdate(shopId: shopId, plan: newPlan, status: newStatus.value, endsAt: newEnd);
  }

  @override
  Future<List<String>> seedDefaultPlans({bool overwrite = false}) async {
    _requireAdmin();
    final written = <String>[];
    for (final plan in kDefaultPaidPlans) {
      if (!overwrite && _repo.getPlan(plan.id) != null) continue;
      await _repo.savePlan(plan);
      written.add(plan.id);
    }
    return written;
  }

  Stream<List<PaymentRecord>> _watch(bool Function(PaymentRecord) test) async* {
    yield _newestFirst(_payments.values.where(test));
    await for (final _ in _changes.stream) {
      yield _newestFirst(_payments.values.where(test));
    }
  }

  @override
  Stream<List<PaymentRecord>> watchShopPayments(String shopId) => _watch((p) => p.shopId == shopId);

  @override
  Stream<List<PaymentRecord>> watchUserPayments(String uid) => _watch((p) => p.userId == uid);
}

// ---------------------------------------------------------------------------
// Service used by the UI
// ---------------------------------------------------------------------------

/// Entry point for every payment action in the app. Picks the Cloud
/// Functions backend when Firebase is attached and the offline simulator
/// otherwise (DEMO_MODE, tests). Every error comes out as a
/// [PaymentException] with a user-facing message.
class PaymentService {
  PaymentService({
    PaymentBackend? backend,
    AppRepository? repository,
    Future<bool> Function(Uri url)? launcher,
  })  : _backend = backend,
        _repo = repository ?? AppRepository.instance,
        _launcher = launcher;

  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService();

  /// Replaces the shared instance (tests).
  static set instance(PaymentService service) => _instance = service;

  PaymentBackend? _backend;
  final AppRepository _repo;
  final Future<bool> Function(Uri url)? _launcher;

  PaymentBackend get backend =>
      _backend ??= _repo.isFirebaseAttached ? CloudPaymentBackend() : LocalPaymentBackend(repository: _repo);

  bool get isSimulated => backend.isSimulated;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw paymentExceptionFrom(e);
    }
  }

  /// Customer: starts (or resumes) a Chapa checkout for their booking.
  Future<PaymentCheckout> startBookingPayment(String bookingId) =>
      _guard(() => backend.createBookingPayment(bookingId));

  /// Owner: starts a one-month Chapa checkout for [planId] ('basic' | 'pro').
  Future<PaymentCheckout> startSubscriptionPayment({required String shopId, required String planId}) =>
      _guard(() => backend.createSubscriptionPayment(shopId: shopId, planId: planId));

  /// Asks the server to re-check a payment with Chapa.
  Future<PaymentVerification> verify(String paymentId) => _guard(() => backend.verifyPayment(paymentId));

  /// Verifies up to [attempts] times while the result is still pending.
  Future<PaymentVerification> verifyUntilSettled(
    String paymentId, {
    int attempts = 4,
    Duration delay = const Duration(seconds: 3),
  }) async {
    var result = await verify(paymentId);
    for (var i = 1; i < attempts && result.isPending; i++) {
      await Future<void>.delayed(delay);
      result = await verify(paymentId);
    }
    return result;
  }

  /// Opens a real Chapa checkout in the external browser.
  Future<void> openCheckout(PaymentCheckout checkout) async {
    if (checkout.isSimulated) throw StateError('Simulated checkouts have no page to open.');
    final uri = Uri.tryParse(checkout.checkoutUrl);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      throw PaymentException.of('launch-failed');
    }
    bool opened;
    try {
      opened = await (_launcher?.call(uri) ?? launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (!opened) throw PaymentException.of('launch-failed');
  }

  /// Demo/test only: the result of the fake Chapa page.
  Future<PaymentVerification> completeSimulatedPayment(String paymentId, {bool success = true}) {
    final b = backend;
    if (b is! LocalPaymentBackend) throw StateError('Only simulated payments can be completed locally.');
    return _guard(() => b.completeSimulatedPayment(paymentId, success: success));
  }

  /// Admin: manual plan/status/end date change (cash or bank payments).
  Future<ShopSubscriptionUpdate> setShopSubscription({
    required String shopId,
    String? plan,
    SubscriptionStatus? status,
    DateTime? endsAt,
    int? months,
  }) =>
      _guard(() => backend.setShopSubscription(shopId: shopId, plan: plan, status: status, endsAt: endsAt, months: months));

  /// Admin: writes the default Basic and Pro plans.
  Future<List<String>> seedDefaultPlans({bool overwrite = false}) =>
      _guard(() => backend.seedDefaultPlans(overwrite: overwrite));

  /// Admin: creates or edits a plan in `plans/{id}`.
  Future<void> savePlan(SubscriptionPlan plan) {
    final error = validatePlan(plan);
    if (error != null) return Future.error(PaymentException('invalid-argument', error));
    return _guard(() => _repo.savePlan(plan));
  }

  /// Admin: hides a plan from owners (existing subscriptions keep running).
  Future<void> setPlanActive(SubscriptionPlan plan, bool active) => savePlan(plan.copyWith(active: active));

  Stream<List<PaymentRecord>> watchShopPayments(String shopId) => backend.watchShopPayments(shopId);
  Stream<List<PaymentRecord>> watchUserPayments(String uid) => backend.watchUserPayments(uid);

  /// The paymentId Chapa sends back on PAYMENT_RETURN_URL
  /// (`?paymentId=<id>&txRef=cb-<id>`), or null.
  static String? paymentIdFromReturnUri(Uri uri) {
    final id = uri.queryParameters['paymentId'];
    if (id != null && id.isNotEmpty && !id.contains('/')) return id;
    final txRef = uri.queryParameters['txRef'] ?? uri.queryParameters['trx_ref'] ?? uri.queryParameters['tx_ref'];
    if (txRef != null && txRef.startsWith('cb-') && txRef.length > 3 && !txRef.contains('/')) return txRef.substring(3);
    return null;
  }
}

/// Null when [plan] can be saved, otherwise why not.
String? validatePlan(SubscriptionPlan plan) {
  if (!SubscriptionPlan.knownIds.contains(plan.id)) return 'Plan id must be one of ${SubscriptionPlan.knownIds.join(', ')}.';
  if (plan.name.trim().isEmpty) return 'Plan name is required.';
  if (plan.priceMonthlyEtb.isNaN || plan.priceMonthlyEtb < 0) return 'Price must be 0 or more.';
  if (plan.id != 'trial' && plan.active && plan.priceMonthlyEtb <= 0) return 'A paid plan needs a price above 0.';
  if (plan.maxBarbers == 0 || plan.maxBarbers < -1) return 'Max barbers must be at least 1 (or -1 for unlimited).';
  return null;
}
