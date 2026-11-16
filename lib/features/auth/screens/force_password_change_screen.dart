import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/ui_kit.dart';
import '../widgets/auth_form_fields.dart';

/// First login of a barber account the shop owner created: the temporary
/// password must be replaced before any dashboard opens. RootGate shows
/// this while [AppRepository.mustChangePassword] is true; saving clears it
/// and the barber dashboard takes over.
class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() => _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _temporary = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _temporaryError;
  String? _passwordError;
  String? _confirmError;
  String? _error;

  @override
  void dispose() {
    _temporary.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _temporaryError = _temporary.text.isEmpty ? l.staffAcctForceTempRequired : null;
      _passwordError = !isValidPassword(_password.text)
          ? l.emailErrWeakPassword
          : (_password.text == _temporary.text ? l.staffAcctForceSameAsTemp : null);
      _confirmError = _confirm.text == _password.text ? null : l.passwordsDontMatch;
      _error = null;
    });
    if (_temporaryError != null || _passwordError != null || _confirmError != null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await AppRepository.instance.completeRequiredPasswordChange(
        temporaryPassword: _temporary.text,
        newPassword: _password.text,
      );
      // RootGate now shows the dashboard.
      messenger?.showSnackBar(SnackBar(content: Text(l.staffAcctForceDone)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is EmailAuthException && e.code == EmailAuthErrorCode.wrongCredentials) {
          _temporaryError = l.staffAcctForceWrongTemp;
        } else if (e is EmailAuthException && e.code == EmailAuthErrorCode.weakPassword) {
          _passwordError = l.emailErrWeakPassword;
        } else {
          _error = l.errorText(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final email = repo.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l.staffAcctForceTitle),
        actions: const [LanguageToggle(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: IconTile(icon: Icons.lock_reset_rounded, size: 52)),
                    const SizedBox(height: 14),
                    Text(
                      l.staffAcctForceIntro,
                      key: const ValueKey('force-password-intro'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ],
                    const SizedBox(height: 18),
                    PasswordField(
                      key: const ValueKey('force-password-temporary'),
                      controller: _temporary,
                      label: l.staffAcctForceTempLabel,
                      errorText: _temporaryError,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      key: const ValueKey('force-password-new'),
                      controller: _password,
                      label: l.newPasswordLabel,
                      helperText: l.passwordHelper,
                      errorText: _passwordError,
                      isNewPassword: true,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      key: const ValueKey('force-password-confirm'),
                      controller: _confirm,
                      label: l.confirmPasswordLabel,
                      errorText: _confirmError,
                      isNewPassword: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),
                    AuthSubmitButton(
                      key: const ValueKey('force-password-save'),
                      label: l.staffAcctForceSave,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    AuthErrorText(_error),
                    const SizedBox(height: 6),
                    TextButton(
                      key: const ValueKey('force-password-sign-out'),
                      onPressed: _busy ? null : () => repo.signOut(),
                      child: Text(l.signOut, style: const TextStyle(color: AppTheme.textSecondary)),
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
