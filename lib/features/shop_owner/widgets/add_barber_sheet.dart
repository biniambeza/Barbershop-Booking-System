import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/password_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/staff_account_service.dart';
import '../../shared/widgets/ui_kit.dart';

/// Owner: "Add a barber". Creates the barber profile and their login (email
/// + a temporary password), then shows the login details to hand over. If
/// the email already has an account, offers today's invitation instead.
Future<void> showAddBarberSheet(
  BuildContext context, {
  required String shopId,
  required List<String> avatarPresets,
}) async {
  final outcome = await showModalBottomSheet<_AddBarberOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard))),
    builder: (_) => AddBarberSheet(shopId: shopId, avatarPresets: avatarPresets),
  );
  if (outcome == null || !context.mounted) return;
  final created = outcome.created;
  if (created != null) {
    await showBarberLoginDetails(context, name: outcome.name, account: created);
  } else {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(context.l10n.staffAcctInviteSaved(outcome.email))));
  }
}

class _AddBarberOutcome {
  const _AddBarberOutcome.created(BarberAccountCreated this.created, this.name) : email = '';
  const _AddBarberOutcome.invited(this.email, this.name) : created = null;

  final BarberAccountCreated? created;
  final String email;
  final String name;
}

/// The form of [showAddBarberSheet]. Pops an [_AddBarberOutcome].
class AddBarberSheet extends StatefulWidget {
  const AddBarberSheet({super.key, required this.shopId, required this.avatarPresets});

  final String shopId;
  final List<String> avatarPresets;

  @override
  State<AddBarberSheet> createState() => _AddBarberSheetState();
}

class _AddBarberSheetState extends State<AddBarberSheet> {
  final _name = TextEditingController();
  TextEditingController? _title;
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController(text: generateTemporaryPassword());
  late String _avatar = widget.avatarPresets.isEmpty ? '' : widget.avatarPresets.first;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;
  bool _copied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _title ??= TextEditingController(text: context.l10n.defaultBarberTitle);
  }

  @override
  void dispose() {
    _name.dispose();
    _title?.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Checks the fields; [withPassword] also checks the temporary password.
  bool _validate({required bool withPassword}) {
    final l = context.l10n;
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l.staffAcctNameRequired : null;
      _emailError = email.isEmpty
          ? l.staffAcctEmailRequired
          : (validEmailOrNull(email) == null ? l.invalidEmailShort : null);
      _phoneError = phone.isNotEmpty && normalizeEthiopianPhone(phone) == null ? l.invalidPhoneShort : null;
      _passwordError = withPassword && !isValidPassword(_password.text) ? l.emailErrWeakPassword : null;
      _formError = null;
    });
    return _nameError == null && _emailError == null && _phoneError == null && _passwordError == null;
  }

  void _regenerate() {
    setState(() {
      _password.text = generateTemporaryPassword();
      _passwordError = null;
      _copied = false;
    });
  }

  Future<void> _copyPassword() async {
    await copyToClipboard(_password.text);
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _create() async {
    if (_busy || !_validate(withPassword: true)) return;
    final l = context.l10n;
    setState(() => _busy = true);
    final name = _name.text.trim();
    try {
      final created = await AppRepository.instance.addBarberWithAccount(
        shopId: widget.shopId,
        name: name,
        title: _title!.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        temporaryPassword: _password.text,
        avatarUrl: _avatar.isEmpty ? null : _avatar,
      );
      if (mounted) Navigator.of(context).pop(_AddBarberOutcome.created(created, name));
    } on EmailAuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.code == EmailAuthErrorCode.emailAlreadyRegistered) {
        await _offerInvitation();
      } else if (e.code == EmailAuthErrorCode.weakPassword) {
        setState(() => _passwordError = l.emailErrWeakPassword);
      } else {
        setState(() => _formError = l.errorText(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = e is AppException ? l.errorText(e) : l.addBarberFailed;
      });
    }
  }

  /// The email has an account already: invite it instead (today's flow).
  Future<void> _offerInvitation() async {
    final l = context.l10n;
    final email = normalizeEmail(_email.text.trim());
    final invite = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('add-barber-email-in-use'),
        backgroundColor: AppTheme.card,
        title: Text(l.staffAcctEmailInUseTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(l.staffAcctEmailInUseBody(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            key: const ValueKey('add-barber-send-invite'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.staffAcctSendInvite),
          ),
        ],
      ),
    );
    if (invite == true && mounted) await _invite();
  }

  Future<void> _invite() async {
    if (_busy || !_validate(withPassword: false)) return;
    final l = context.l10n;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final email = normalizeEmail(_email.text.trim());
    try {
      await AppRepository.instance.addBarber(
        shopId: widget.shopId,
        name: name,
        title: _title!.text.trim(),
        email: email,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        avatarUrl: _avatar.isEmpty ? null : _avatar,
      );
      if (mounted) Navigator.of(context).pop(_AddBarberOutcome.invited(email, name));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = e is AppException ? l.errorText(e) : l.addBarberFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const IconTile(icon: Icons.person_add_alt_1_rounded, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.staffAcctSheetTitle,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.staffAcctSheetIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('add-barber-name'),
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l.barberFullName,
                errorText: _nameError,
                counterText: '',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('add-barber-title'),
              controller: _title,
              enabled: !_busy,
              decoration: InputDecoration(labelText: l.specialization, prefixIcon: const Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('add-barber-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.staffAcctEmailLabel,
                hintText: 'barber@gmail.com',
                errorText: _emailError,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('add-barber-phone'),
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              decoration: InputDecoration(
                labelText: l.barberMobileOptional,
                hintText: '09XX XXX XXX',
                errorText: _phoneError,
                prefixIcon: const Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('add-barber-password'),
              controller: _password,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) {
                if (_copied) setState(() => _copied = false);
              },
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1),
              decoration: InputDecoration(
                labelText: l.staffAcctTempPasswordLabel,
                helperText: l.staffAcctTempPasswordHelper,
                helperMaxLines: 3,
                errorText: _passwordError,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey('add-barber-regenerate'),
                      tooltip: l.staffAcctRegenerate,
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _busy ? null : _regenerate,
                    ),
                    IconButton(
                      key: const ValueKey('add-barber-copy-password'),
                      tooltip: _copied ? l.staffAcctCopied : l.staffAcctCopyPassword,
                      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copied ? AppTheme.success : null),
                      onPressed: _copyPassword,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.avatarPresets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.selectAvatar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final url in widget.avatarPresets)
                      GestureDetector(
                        onTap: _busy ? null : () => setState(() => _avatar = url),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _avatar == url ? AppTheme.ink : Colors.transparent, width: 2.5),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.surface,
                            backgroundImage: NetworkImage(url),
                            onBackgroundImageError: (_, __) {},
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_formError != null) ...[
              const SizedBox(height: 12),
              Text(_formError!,
                  key: const ValueKey('add-barber-error'),
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(l.cancel, style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('add-barber-create'),
                    onPressed: _busy ? null : _create,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onInk),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(l.staffAcctCreate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              color: AppTheme.surface,
              radius: AppTheme.radiusPanel,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.staffAcctInviteSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(l.barberInviteHelper, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('add-barber-invite-instead'),
                      onPressed: _busy ? null : _invite,
                      icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                      label: Text(l.staffAcctInviteInstead),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies [text]; a missing clipboard (tests, some web contexts) is ignored.
Future<void> copyToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {}
}

/// The final step: the email and temporary password to hand to the barber
/// (shown only now — the password is not stored anywhere readable).
Future<void> showBarberLoginDetails(
  BuildContext context, {
  required String name,
  required BarberAccountCreated account,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard))),
    builder: (_) => BarberLoginDetailsSheet(name: name, account: account),
  );
}

class BarberLoginDetailsSheet extends StatefulWidget {
  const BarberLoginDetailsSheet({super.key, required this.name, required this.account});

  final String name;
  final BarberAccountCreated account;

  @override
  State<BarberLoginDetailsSheet> createState() => _BarberLoginDetailsSheetState();
}

class _BarberLoginDetailsSheetState extends State<BarberLoginDetailsSheet> {
  bool _copiedPassword = false;
  bool _copiedDetails = false;

  Future<void> _copyPassword() async {
    await copyToClipboard(widget.account.temporaryPassword);
    if (mounted) setState(() => _copiedPassword = true);
  }

  Future<void> _copyDetails() async {
    final l = context.l10n;
    await copyToClipboard(staffLoginDetailsText(
      heading: l.staffAcctDetailsHeading,
      emailLabel: l.staffAcctEmailField,
      email: widget.account.email,
      passwordLabel: l.staffAcctTempPasswordLabel,
      password: widget.account.temporaryPassword,
      footer: l.staffAcctDetailsFooter,
    ));
    if (mounted) setState(() => _copiedDetails = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = widget.account;
    return SingleChildScrollView(
      key: const ValueKey('barber-login-details'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.verified_user_rounded, color: AppTheme.success, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.staffAcctCreatedTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l.staffAcctCreatedBody(widget.name), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          HeroCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.staffAcctEmailField, style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 12)),
                const SizedBox(height: 2),
                SelectableText(
                  account.email,
                  key: const ValueKey('barber-login-email'),
                  style: const TextStyle(color: AppTheme.onInk, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Text(l.staffAcctTempPasswordLabel, style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        account.temporaryPassword,
                        key: const ValueKey('barber-login-password'),
                        style: const TextStyle(
                          color: AppTheme.onInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _copiedPassword ? l.staffAcctCopied : l.staffAcctCopyPassword,
                      icon: Icon(_copiedPassword ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copiedPassword ? AppTheme.green : AppTheme.onInk),
                      onPressed: _copyPassword,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.staffAcctShownOnce,
                    style: const TextStyle(color: AppTheme.warning, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('barber-login-copy-details'),
            onPressed: _copyDetails,
            icon: Icon(_copiedDetails ? Icons.check_rounded : Icons.copy_all_rounded, size: 18),
            label: Text(_copiedDetails ? l.staffAcctCopied : l.staffAcctCopyDetails),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            key: const ValueKey('barber-login-done'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.done),
          ),
        ],
      ),
    );
  }
}

/// Manage barbers: whether the barber's login is set up.
///  * owner-created account not used yet → "Waiting for first login" (with
///    the lost-password hint);
///  * plain email invitation pending → "Invitation sent — waiting for
///    sign-up";
///  * a signed-up account linked to the profile → "Active".
class BarberAccountStatus extends StatelessWidget {
  const BarberAccountStatus({super.key, required this.barber});

  final Barber barber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final invite = repo.getPendingBarberInvite(barber.id);
    if (invite != null) {
      final ownerCreated = invite.authUid != null;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              key: ValueKey(ownerCreated ? 'barber-account-waiting-${barber.id}' : 'barber-invite-waiting-${barber.id}'),
              children: [
                Icon(ownerCreated ? Icons.hourglass_top_rounded : Icons.mark_email_unread_outlined,
                    size: 14, color: AppTheme.warning),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ownerCreated ? l.staffAcctWaitingFirstLogin : l.barberInviteWaiting,
                    style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              invite.email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
            ),
            if (ownerCreated) ...[
              const SizedBox(height: 2),
              Text(
                l.staffAcctLostPasswordHint,
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              ),
            ],
          ],
        ),
      );
    }
    final hasAccount =
        repo.getAllUsers().any((u) => u.role == UserRole.barber && u.barberId == barber.id);
    if (!hasAccount) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: StatusChip(
        key: ValueKey('barber-account-active-${barber.id}'),
        label: l.staffAcctActive,
        color: AppTheme.success,
        background: AppTheme.greenSoft,
        icon: Icons.verified_user_rounded,
      ),
    );
  }
}
