import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import 'auth_form_fields.dart';

/// Email + password log in, with a "Forgot password?" link.
class EmailLoginForm extends StatefulWidget {
  const EmailLoginForm({super.key, this.initialEmail, this.notice, required this.onForgotPassword});

  final String? initialEmail;

  /// Shown above the form (e.g. "Your password has been changed").
  final String? notice;

  /// Opens the reset flow with the email typed so far.
  final ValueChanged<String> onForgotPassword;

  @override
  State<EmailLoginForm> createState() => _EmailLoginFormState();
}

class _EmailLoginFormState extends State<EmailLoginForm> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_password.text.isEmpty) {
      setState(() => _error = l.enterPassword);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppRepository.instance.loginWithEmail(email: _email.text, password: _password.text);
      // On success the root gate switches screens.
    } catch (e) {
      if (mounted) setState(() => _error = l.authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.notice!,
                key: const ValueKey('login-notice'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.success, fontSize: 13),
              ),
            ),
          EmailField(key: const ValueKey('login-email'), controller: _email),
          const SizedBox(height: 12),
          PasswordField(
            key: const ValueKey('login-password'),
            controller: _password,
            label: l.passwordLabel,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('forgot-password'),
              onPressed: _busy ? null : () => widget.onForgotPassword(_email.text.trim()),
              child: Text(l.forgotPassword),
            ),
          ),
          AuthSubmitButton(
            key: const ValueKey('login-submit'),
            label: l.loginButton,
            busy: _busy,
            onPressed: _submit,
          ),
          AuthErrorText(_error),
          if (kDemoMode) const DemoEmailHint(),
        ],
      ),
    );
  }
}
