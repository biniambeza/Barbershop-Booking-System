import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../widgets/auth_form_fields.dart';

/// Opens [ChangePasswordScreen] for accounts with a password, or the
/// [SetPasswordScreen] guidance for Google-only accounts.
void openPasswordSettings(BuildContext context) {
  final repo = AppRepository.instance;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => repo.canChangePassword ? const ChangePasswordScreen() : const SetPasswordScreen(),
  ));
}

/// Signed-in user with an email/password account: current password, new
/// password and confirmation (8–128 characters with a letter and a digit).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _currentError;
  String? _passwordError;
  String? _confirmError;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _messageFor(Object e) {
    final l = context.l10n;
    if (e is EmailAuthException && e.code == EmailAuthErrorCode.wrongCredentials) {
      return l.changePasswordErrWrongCurrent;
    }
    return l.errorText(e);
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _currentError = _current.text.isEmpty ? l.changePasswordErrCurrentRequired : null;
      _passwordError = isValidPassword(_password.text) ? null : l.emailErrWeakPassword;
      _confirmError = _confirm.text == _password.text ? null : l.passwordsDontMatch;
      _error = null;
    });
    if (_currentError != null || _passwordError != null || _confirmError != null) return;
    setState(() => _busy = true);
    try {
      await AppRepository.instance.changePassword(currentPassword: _current.text, newPassword: _password.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.changePasswordDone)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is EmailAuthException && e.code == EmailAuthErrorCode.wrongCredentials) {
          _currentError = _messageFor(e);
        } else {
          _error = _messageFor(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.changePasswordTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.changePasswordIntro, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    PasswordField(
                      key: const ValueKey('change-password-current'),
                      controller: _current,
                      label: l.currentPasswordLabel,
                      errorText: _currentError,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      key: const ValueKey('change-password-new'),
                      controller: _password,
                      label: l.newPasswordLabel,
                      helperText: l.passwordHelper,
                      errorText: _passwordError,
                      isNewPassword: true,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      key: const ValueKey('change-password-confirm'),
                      controller: _confirm,
                      label: l.confirmPasswordLabel,
                      errorText: _confirmError,
                      isNewPassword: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    const SizedBox(height: 18),
                    AuthSubmitButton(
                      key: const ValueKey('change-password-save'),
                      label: l.changePasswordSave,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    AuthErrorText(_error),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google-only accounts: explains how to create a password ("Forgot
/// password?" on the login screen with their Gmail) and offers to sign out
/// and open that form.
class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({super.key});

  Future<void> _signOutToSetPassword(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(l.setPasswordConfirmTitle),
        content: Text(l.setPasswordConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(
            key: const ValueKey('set-password-confirm-sign-out'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.signOut),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await AppRepository.instance.signOutToSetPassword();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final email = AppRepository.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l.setPasswordTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.key_rounded, size: 36, color: AppTheme.ink),
                    const SizedBox(height: 12),
                    Text(
                      l.setPasswordBody(email),
                      key: const ValueKey('set-password-guidance'),
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      key: const ValueKey('set-password-sign-out'),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(l.setPasswordSignOutAction),
                      onPressed: () => _signOutToSetPassword(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
