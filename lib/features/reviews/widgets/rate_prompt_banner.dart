import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/reviews_service.dart';
import 'rate_booking_dialog.dart';

/// How far back a completed visit still gets the in-app rating prompt.
const Duration kRatePromptWindow = Duration(days: 14);

/// The completed visit of [customerId] to ask a rating for on the customer
/// home: the newest one (by start) within [window] before [nowUtc] that was
/// not prompted before ([alreadyPrompted]). Whether it already has a review
/// is checked by the banner. Null when there is none.
Booking? ratePromptCandidate(
  Iterable<Booking> bookings, {
  required String customerId,
  required Set<String> alreadyPrompted,
  required DateTime nowUtc,
  Duration window = kRatePromptWindow,
}) {
  final from = nowUtc.subtract(window);
  Booking? best;
  for (final b in bookings) {
    if (b.customerId != customerId || b.status != BookingStatus.completed) continue;
    if (alreadyPrompted.contains(b.id)) continue;
    if (b.startAt.isBefore(from) || b.startAt.isAfter(nowUtc)) continue;
    if (best == null || b.startAt.isAfter(best.startAt)) best = b;
  }
  return best;
}

/// Remembers which completed visits already got the rating prompt, so it
/// shows once (on the next app open after the visit was completed).
/// Kept in SharedPreferences; when they are unavailable (tests, a broken
/// platform channel) only in memory.
class RatePromptStore {
  RatePromptStore({this.usePreferences = true});

  static RatePromptStore instance = RatePromptStore();

  static const String prefsKey = 'ratePromptShownBookings';

  /// Most booking ids kept (oldest dropped).
  static const int maxKept = 50;

  final bool usePreferences;
  final List<String> _shown = [];
  Future<void>? _loading;

  /// The ids prompted so far (preferences are read once).
  Future<Set<String>> load() async {
    await (_loading ??= _readPreferences());
    return _shown.toSet();
  }

  Future<void> _readPreferences() async {
    if (!usePreferences) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(prefsKey) ?? const <String>[];
      // Stored ids are older than any marked while loading.
      _shown.insertAll(0, stored.where((id) => !_shown.contains(id)));
    } catch (_) {
      // No preferences: remember for this run only.
    }
  }

  /// Records that [bookingId] was prompted.
  Future<void> markShown(String bookingId) async {
    if (_shown.contains(bookingId)) return;
    _shown.add(bookingId);
    while (_shown.length > maxKept) {
      _shown.removeAt(0);
    }
    if (!usePreferences) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, List.of(_shown));
    } catch (_) {
      // Kept in memory only.
    }
  }

  bool wasShown(String bookingId) => _shown.contains(bookingId);
}

/// Customer home: a dismissable "How was your cut?" banner (key
/// `rate-prompt-{bookingId}`) for the newest completed visit that has no
/// review yet, with a "Rate your barber" button (key
/// `rate-prompt-action`) opening the rating dialog. Each visit is prompted
/// once: it is remembered as soon as the banner shows, so the next app
/// open does not show it again (My Appointments still offers rating).
class RatePromptBanner extends StatefulWidget {
  const RatePromptBanner({super.key, this.service, this.store, this.clock});

  final ReviewsService? service;
  final RatePromptStore? store;
  final DateTime Function()? clock;

  @override
  State<RatePromptBanner> createState() => _RatePromptBannerState();
}

class _RatePromptBannerState extends State<RatePromptBanner> {
  /// Prompted before this screen opened (null while loading).
  Set<String>? _promptedBefore;
  final Set<String> _dismissed = {};
  String? _streamBookingId;
  Stream<Review?>? _reviewStream;

  ReviewsService get _service => widget.service ?? ReviewsService.instance;
  RatePromptStore get _store => widget.store ?? RatePromptStore.instance;
  DateTime _now() => (widget.clock?.call() ?? AppRepository.instance.nowUtc()).toUtc();

  @override
  void initState() {
    super.initState();
    _store.load().then((ids) {
      if (mounted) setState(() => _promptedBefore = ids);
    });
  }

  Stream<Review?> _streamFor(Booking booking) {
    if (_streamBookingId != booking.id || _reviewStream == null) {
      _streamBookingId = booking.id;
      _reviewStream = _service.watchReviewForBooking(booking);
    }
    return _reviewStream!;
  }

  @override
  Widget build(BuildContext context) {
    final prompted = _promptedBefore;
    if (prompted == null) return const SizedBox.shrink();
    final repo = AppRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final user = repo.currentUser;
        if (user == null || user.role != UserRole.customer) return const SizedBox.shrink();
        final booking = ratePromptCandidate(
          repo.getCustomerBookings(user.uid),
          customerId: user.uid,
          alreadyPrompted: prompted,
          nowUtc: _now(),
        );
        if (booking == null || _dismissed.contains(booking.id)) return const SizedBox.shrink();
        if (_service.reviewBlocker(booking) != null) return const SizedBox.shrink();
        return StreamBuilder<Review?>(
          stream: _streamFor(booking),
          builder: (context, snapshot) {
            // Only once we know there is no review.
            if (snapshot.hasError || (!snapshot.hasData && snapshot.connectionState != ConnectionState.active)) {
              return const SizedBox.shrink();
            }
            if (snapshot.data != null) return const SizedBox.shrink();
            if (!_store.wasShown(booking.id)) unawaited(_store.markShown(booking.id));
            return _banner(context, booking);
          },
        );
      },
    );
  }

  Widget _banner(BuildContext context, Booking booking) {
    final l = context.l10n;
    return Container(
      key: ValueKey('rate-prompt-${booking.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppTheme.orangeSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.star_rounded, color: AppTheme.orange, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.ratePromptTitle,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  l.ratePromptBody(booking.barberName, booking.serviceName, booking.shopName),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      key: const ValueKey('rate-prompt-action'),
                      onPressed: () => showRateBookingDialog(context, booking, service: widget.service),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      icon: const Icon(Icons.star_rounded, size: 16),
                      label: Text(l.reviewsRateAction, style: const TextStyle(fontSize: 12.5)),
                    ),
                    TextButton(
                      key: const ValueKey('rate-prompt-later'),
                      onPressed: () => setState(() => _dismissed.add(booking.id)),
                      child: Text(l.ratePromptDismiss),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('rate-prompt-dismiss'),
            tooltip: l.ratePromptDismiss,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
            onPressed: () => setState(() => _dismissed.add(booking.id)),
          ),
        ],
      ),
    );
  }
}
