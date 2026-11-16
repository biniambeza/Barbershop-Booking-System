import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/barbershop_model.dart';
import '../../models/user_model.dart';
import '../../services/app_repository.dart';
import '../auth/widgets/auth_form_fields.dart';
import '../legal/privacy_policy_screen.dart';
import '../shared/widgets/ui_kit.dart';

/// Opens [DeleteAccountScreen] (app bar menu > Delete account).
void openDeleteAccount(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()));
}

/// Settings > Delete account (account_deletion.dart): shows what deleting
/// does for this person, asks them to type DELETE and to sign in again
/// (password or Google), then runs [AppRepository.deleteMyAccount]. A shop
/// owner is asked to have the admin remove the shop first; the last admin
/// cannot delete their account.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  AccountDeletionStep? _step;
  String? _error;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  String _stepLabel(AccountDeletionStep step) {
    final l = context.l10n;
    switch (step) {
      case AccountDeletionStep.cancelBookings:
        return l.deleteStepCancelBookings;
      case AccountDeletionStep.anonymizeReviews:
        return l.deleteStepReviews;
      case AccountDeletionStep.anonymizeBookings:
        return l.deleteStepBookings;
      case AccountDeletionStep.leaveShop:
        return l.deleteStepLeaveShop;
      case AccountDeletionStep.deletePersonalData:
        return l.deleteStepPersonalData;
      case AccountDeletionStep.deleteProfile:
        return l.deleteStepProfile;
      case AccountDeletionStep.deleteLogin:
        return l.deleteStepLogin;
    }
  }

  String _messageFor(Object e) {
    final l = context.l10n;
    if (e is AccountDeletionException) {
      switch (e.error) {
        case AccountDeletionError.confirmationMismatch:
          return l.deleteAccountConfirmMismatch;
        case AccountDeletionError.reauthRequired:
          return l.deleteAccountErrReauth;
        case AccountDeletionError.reauthCancelled:
          return l.deleteAccountErrReauthCancelled;
        case AccountDeletionError.ownsShop:
          return l.deleteAccountOwnerTitle;
        case AccountDeletionError.lastAdmin:
          return l.deleteAccountLastAdminTitle;
        case AccountDeletionError.noteTooLong:
          return l.shopRemovalNoteTooLong(kShopRemovalNoteMaxLength);
        case AccountDeletionError.notSignedIn:
          return l.errorText(AppStateException(AppErrorCode.signInRequired));
        case AccountDeletionError.stepFailed:
          final step = e.step;
          return step == null ? l.deleteAccountErrFailed : l.deleteAccountErrStep(_stepLabel(step));
      }
    }
    if (e is EmailAuthException && e.code == EmailAuthErrorCode.wrongCredentials) {
      return l.changePasswordErrWrongCurrent;
    }
    return l.errorText(e);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final repo = AppRepository.instance;
    if (!isDeleteConfirmation(_confirm.text)) {
      setState(() => _error = l.deleteAccountConfirmMismatch);
      return;
    }
    final methods = repo.reauthMethods;
    final usePassword = methods.contains(ReauthMethod.password) && _password.text.isNotEmpty;
    if (methods.contains(ReauthMethod.password) && !methods.contains(ReauthMethod.google) && !usePassword) {
      setState(() => _passwordError = l.changePasswordErrCurrentRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _passwordError = null;
      _step = null;
    });
    final navigator = Navigator.of(context);
    try {
      if (usePassword) {
        await repo.reauthenticateWithPassword(_password.text);
      } else if (methods.contains(ReauthMethod.google)) {
        await repo.reauthenticateWithGoogle();
      }
      await repo.deleteMyAccount(
        confirmation: _confirm.text,
        onStep: (step) {
          if (mounted) setState(() => _step = step);
        },
      );
      // Signed out: back to the first route, where the sign-in screen is.
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = null;
        if (e is EmailAuthException && e.code == EmailAuthErrorCode.wrongCredentials) {
          _passwordError = _messageFor(e);
        } else {
          _error = _messageFor(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l.deleteAccountTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListenableBuilder(
              listenable: repo,
              builder: (context, _) {
                final user = repo.currentUser;
                if (user == null) return const SizedBox.shrink();
                // Only the login is left (Firebase asked for a new sign-in).
                final AccountDeletionPreview preview = repo.accountDeletionPending
                    ? AccountDeletionPreview(user: user)
                    : repo.previewAccountDeletion();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: switch (preview.blocker) {
                    AccountDeletionBlocker.ownsShop => [_OwnerBlocked(shop: preview.ownedShop!)],
                    AccountDeletionBlocker.lastAdmin => [_LastAdminBlocked()],
                    null => _deleteForm(preview),
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _deleteForm(AccountDeletionPreview preview) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final methods = repo.reauthMethods;
    final user = preview.user;
    final pending = repo.accountDeletionPending;
    final bullets = <String>[
      if (pending)
        l.deleteAccountPendingLogin
      else ...[
        l.deleteAccountCancelCount(preview.toCancel.length),
        if (preview.paidToCancel > 0) l.deleteAccountPaidRefund(preview.paidToCancel),
        if (preview.keptInsideCutoff.isNotEmpty) l.deleteAccountKeptInCutoff(preview.keptInsideCutoff.length),
        if (user.role == UserRole.barber) ...[
          if (preview.barberToCancel.isNotEmpty) l.deleteAccountBarberCancel(preview.barberToCancel.length),
          l.deleteAccountBarberLeaves(repo.getShopById(user.shopId ?? '')?.name ?? l.deleteAccountYourShop),
        ],
        l.deleteAccountReviews,
        l.deleteAccountBookingsHistory,
        l.deleteAccountPersonalData,
      ],
    ];
    return [
      HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.person_remove_outlined, size: 28),
            const SizedBox(height: 10),
            Text(l.deleteAccountHeroTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.onHero)),
            const SizedBox(height: 6),
            Text(l.deleteAccountHeroBody, style: TextStyle(fontSize: 13, color: AppTheme.onInkMuted, height: 1.4)),
            if ((user.email ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              HeroChip(icon: Icons.alternate_email_rounded, label: user.email!),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      AppCard(
        key: const ValueKey('delete-account-summary'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.deleteAccountWhatHappens, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final b in bullets) _Bullet(b),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('delete-account-privacy'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.success, padding: EdgeInsets.zero),
                onPressed: () => openPrivacyPolicy(context),
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: Text(l.privacyPolicyTitle),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.deleteAccountReauthTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('delete-account-confirm'),
              controller: _confirm,
              enabled: !_busy,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.deleteAccountConfirmLabel(kDeleteConfirmationWord),
                prefixIcon: const Icon(Icons.keyboard_rounded),
              ),
            ),
            if (methods.contains(ReauthMethod.password)) ...[
              const SizedBox(height: 12),
              PasswordField(
                key: const ValueKey('delete-account-password'),
                controller: _password,
                label: l.deleteAccountPasswordLabel,
                labelAbove: false,
                helperText: methods.contains(ReauthMethod.google) ? l.deleteAccountPasswordOrGoogle : null,
                errorText: _passwordError,
                textInputAction: TextInputAction.done,
              ),
            ] else if (methods.contains(ReauthMethod.google)) ...[
              const SizedBox(height: 10),
              Text(l.deleteAccountReauthGoogle, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 16),
            if (_busy && _step != null) ...[
              Row(
                key: const ValueKey('delete-account-progress'),
                children: [
                  SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.ink)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_stepLabel(_step!), style: const TextStyle(fontSize: 13))),
                ],
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              key: const ValueKey('delete-account-submit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: _busy || !isDeleteConfirmation(_confirm.text) ? null : _delete,
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: Text(l.deleteAccountSubmit),
            ),
            AuthErrorText(_error),
          ],
        ),
      ),
    ];
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 6, color: AppTheme.danger),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}

class _LastAdminBlocked extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      key: const ValueKey('delete-account-last-admin'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: Icons.admin_panel_settings_outlined, color: AppTheme.purple, size: 40),
          const SizedBox(height: 12),
          Text(l.deleteAccountLastAdminTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(l.deleteAccountLastAdminBody, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

/// A shop owner: the shop goes first. Sends, shows or withdraws the
/// "please remove my shop" request for the admin.
class _OwnerBlocked extends StatefulWidget {
  const _OwnerBlocked({required this.shop});

  final Barbershop shop;

  @override
  State<_OwnerBlocked> createState() => _OwnerBlockedState();
}

class _OwnerBlockedState extends State<_OwnerBlocked> {
  final _note = TextEditingController();
  late final Stream<ShopRemovalRequest?> _request = AppRepository.instance.watchMyShopRemovalRequest();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() => _error = e is AccountDeletionException && e.error == AccountDeletionError.noteTooLong
          ? l.shopRemovalNoteTooLong(kShopRemovalNoteMaxLength)
          : l.errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send({bool replace = false}) {
    final repo = AppRepository.instance;
    return _run(() async {
      if (replace) await repo.withdrawShopRemovalRequest();
      await repo.requestShopRemoval(note: _note.text);
      _note.clear();
    }, done: context.l10n.shopRemovalSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront_rounded, size: 28),
              const SizedBox(height: 10),
              Text(l.deleteAccountOwnerTitle,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.onHero)),
              const SizedBox(height: 6),
              Text(l.deleteAccountOwnerBody(widget.shop.name),
                  key: const ValueKey('delete-account-owner-blocked'),
                  style: TextStyle(fontSize: 13, color: AppTheme.onInkMuted, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<ShopRemovalRequest?>(
          stream: _request,
          builder: (context, snap) {
            final request = snap.data;
            final children = <Widget>[];
            if (request != null && request.isPending) {
              children.addAll([
                StatusChip(label: l.shopRemovalStatusPending, color: AppTheme.warning, icon: Icons.schedule_rounded),
                const SizedBox(height: 10),
                Text(l.shopRemovalPending(fmt.addisDateMedium(request.createdAt)),
                    key: const ValueKey('shop-removal-pending'), style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('shop-removal-withdraw'),
                  style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: _busy ? null : () => _run(AppRepository.instance.withdrawShopRemovalRequest),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(l.shopRemovalWithdraw),
                ),
              ]);
            } else {
              final dismissed = request != null && request.status == ShopRemovalStatus.dismissed;
              children.addAll([
                if (dismissed) ...[
                  Text(l.shopRemovalDismissed(fmt.addisDateMedium(request.handledAt ?? request.createdAt)),
                      style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.warning)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const ValueKey('shop-removal-note'),
                  controller: _note,
                  enabled: !_busy,
                  maxLines: 3,
                  maxLength: kShopRemovalNoteMaxLength,
                  decoration: InputDecoration(labelText: l.shopRemovalNoteLabel),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('shop-removal-request'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.ink,
                    foregroundColor: AppTheme.onInk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _busy ? null : () => _send(replace: request != null),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(l.shopRemovalRequestButton),
                ),
              ]);
            }
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...children, AuthErrorText(_error)],
              ),
            );
          },
        ),
      ],
    );
  }
}
