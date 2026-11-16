import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/rebook_service.dart';
import '../../shared/widgets/ui_kit.dart';
import '../screens/barbershop_detail_screen.dart';
import '../screens/booking_flow_screen.dart';

/// Favourite barbers and one-tap rebooking ("Book again with Dawit"):
/// the heart button, the "Your barbers" row on the customer home, the
/// "Book again" button on completed bookings, and the friendly fallback
/// when the barber, shop or service is no longer bookable. Logic lives in
/// lib/services/rebook_service.dart; favourites are kept on the device.

bool _isCustomer(AppRepository repo) => repo.currentUser?.role == UserRole.customer;

/// Heart that adds or removes a favourite barber. Shown to signed-in
/// customers only (nothing for anyone else). Rebuilds on its own, so it
/// also works on screens that do not listen to the repository.
class FavoriteBarberButton extends StatelessWidget {
  FavoriteBarberButton({super.key, required Barber barber, this.size = 20, this.onDark = false})
      : barberId = barber.id,
        shopId = barber.shopId,
        barberName = barber.name;

  const FavoriteBarberButton.ids({
    super.key,
    required this.barberId,
    required this.shopId,
    required this.barberName,
    this.size = 20,
    this.onDark = false,
  });

  final String barberId;
  final String shopId;
  final String barberName;
  final double size;

  /// White outline on a dark background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!_isCustomer(repo)) return const SizedBox.shrink();
        final fav = repo.isBarberFavorite(barberId);
        final l = context.l10n;
        final name = barberName.isEmpty ? '' : firstNameOf(barberName);
        return IconButton(
          key: ValueKey('fav-barber-$barberId'),
          tooltip: fav ? l.favoriteBarberRemove(name) : l.favoriteBarberAdd(name),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: size + 14, height: size + 14),
          iconSize: size,
          icon: Icon(
            fav ? Icons.favorite : Icons.favorite_border,
            color: fav ? AppTheme.danger : (onDark ? Colors.white : AppTheme.textSecondary),
          ),
          onPressed: () => repo.toggleFavoriteBarber(barberId, shopId: shopId, barberName: barberName),
        );
      },
    );
  }
}

/// "Book again": opens the booking flow prefilled with the shop, barber
/// and service of [candidate], landing on the date and time with the next
/// free slot suggested. When that is not possible (shop gone or suspended,
/// barber left or unavailable, service gone) it shows a friendly fallback
/// instead. Signed-in customers only.
Future<void> startRebook(BuildContext context, RebookCandidate candidate, {DateTime Function()? clock}) async {
  final repo = AppRepository.instance;
  final l = context.l10n;
  if (!_isCustomer(repo)) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.rebookSignInNeeded)));
    return;
  }
  final check = repo.checkRebook(candidate);
  if (check.ok) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookingFlowScreen(
        shop: check.shop!,
        initialService: check.service!,
        initialBarber: check.barber!,
        suggestNextSlot: true,
        clock: clock,
      ),
    ));
    return;
  }
  await _showRebookFallback(context, candidate, check, clock: clock);
}

Future<void> _showRebookFallback(BuildContext context, RebookCandidate c, RebookCheck check,
    {DateTime Function()? clock}) {
  final repo = AppRepository.instance;
  final l = context.l10n;
  final shopName = check.shop?.name ?? c.shopName;
  final barberName = check.barber?.name ?? c.barberName;
  final shop = check.shop;
  final String message;
  switch (check.problem!) {
    case RebookProblem.shopGone:
      message = l.rebookShopGone(shopName);
    case RebookProblem.shopBlocked:
      message = l.rebookShopBlocked(shopName);
    case RebookProblem.barberGone:
      message = l.rebookBarberGone(barberName, shopName);
    case RebookProblem.barberUnavailable:
      message = l.rebookBarberUnavailable(barberName, shopName);
    case RebookProblem.serviceGone:
      message = l.rebookServiceGone(shopName, c.serviceName ?? '', firstNameOf(barberName));
    case RebookProblem.noServices:
      message = l.rebookNoServices(shopName);
  }
  final canSeeShop = shop != null &&
      (check.problem == RebookProblem.barberGone || check.problem == RebookProblem.barberUnavailable);
  final canPickService = check.problem == RebookProblem.serviceGone &&
      shop != null &&
      check.barber != null &&
      check.service != null;
  final canUnfavorite = repo.isBarberFavorite(c.barberId) &&
      (check.problem == RebookProblem.shopGone || check.problem == RebookProblem.barberGone);

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('rebook-fallback'),
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: IconTile(icon: Icons.event_busy_rounded, color: AppTheme.warning),
      title: Text(l.rebookFallbackTitle, textAlign: TextAlign.center),
      content: Text(
        message,
        key: ValueKey('rebook-fallback-${check.problem!.name}'),
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        if (canPickService)
          ElevatedButton(
            key: const ValueKey('rebook-pick-service'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BookingFlowScreen(
                  shop: shop,
                  initialService: check.service!,
                  initialBarber: check.barber!,
                  clock: clock,
                ),
              ));
            },
            child: Text(l.rebookPickService),
          ),
        if (canSeeShop)
          ElevatedButton(
            key: const ValueKey('rebook-see-shop'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BarbershopDetailScreen(shop: shop)));
            },
            child: Text(l.rebookSeeShop),
          ),
        if (canUnfavorite)
          TextButton(
            key: const ValueKey('rebook-unfavorite'),
            onPressed: () {
              repo.toggleFavoriteBarber(c.barberId);
              Navigator.of(ctx).pop();
            },
            child: Text(l.rebookRemoveFavorite),
          ),
        TextButton(
          key: const ValueKey('rebook-close'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.rebookClose),
        ),
      ],
    ),
  );
}

/// "Book again" on a completed booking card.
class BookAgainButton extends StatelessWidget {
  const BookAgainButton({super.key, required this.booking, this.clock});

  final Booking booking;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      key: ValueKey('book-again-${booking.id}'),
      onPressed: () => startRebook(context, AppRepository.instance.rebookCandidateFor(booking), clock: clock),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      icon: const Icon(Icons.replay_rounded, size: 16),
      label: Text(context.l10n.bookAgain, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// "Your barbers" on the customer home: favourite barbers and the barbers
/// of recent completed bookings, each with "Book again with Dawit" (first name).
/// Nothing is shown when the list is empty or nobody is signed in as a
/// customer.
class YourBarbersSection extends StatelessWidget {
  const YourBarbersSection({super.key, this.clock});

  /// Overrides the clock of the booking flow it opens (tests).
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!_isCustomer(repo)) return const SizedBox.shrink();
        final entries = repo.getYourBarbers();
        if (entries.isEmpty) return const SizedBox.shrink();
        final l = context.l10n;
        return Padding(
          key: const ValueKey('your-barbers'),
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l.yourBarbersTitle),
              const SizedBox(height: 2),
              Text(l.yourBarbersSubtitle, style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _YourBarberCard(candidate: entries[i], clock: clock),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YourBarberCard extends StatelessWidget {
  const _YourBarberCard({required this.candidate, this.clock});

  final RebookCandidate candidate;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = candidate;
    final live = AppRepository.instance.getBarberById(c.barberId);
    final avatar = live != null && live.shopId == c.shopId ? live.avatarUrl : null;
    final initial = c.barberName.trim().isEmpty ? '?' : c.barberName.trim().substring(0, 1).toUpperCase();
    return Container(
      key: ValueKey('your-barber-${c.barberId}'),
      width: 248,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusPanel + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.surface,
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                onBackgroundImageError: avatar != null ? (error, stackTrace) {} : null,
                child: avatar == null
                    ? Text(initial, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.barberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text(c.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              FavoriteBarberButton.ids(barberId: c.barberId, shopId: c.shopId, barberName: c.barberName),
            ],
          ),
          const SizedBox(height: 10),
          if (c.serviceName != null && c.serviceName!.isNotEmpty)
            Text(l.rebookLastService(c.serviceName!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
          else if (c.isFavorite)
            StatusChip(label: l.rebookFavoriteTag, color: AppTheme.danger, icon: Icons.favorite),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: ValueKey('book-again-with-${c.barberId}'),
                onPressed: () => startRebook(context, c, clock: clock),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  l.bookAgainWith(c.firstName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
