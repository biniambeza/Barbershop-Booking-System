import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/password_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import 'auth_form_fields.dart';

/// Forgot password: email → "Send code", then the code and a new password.
/// Calls [onDone] with the email after the password was changed.
class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({super.key, this.initialEmail, required this.onDone, required this.onCancel});

  final String? initialEmail;
  final ValueChanged<String> onDone;
  final VoidCallback onCancel;

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _sentTo;
  DateTime _sentAt = DateTime.now();
  int _cooldown = 60;

  bool _busy = false;
  String? _error;
  String? _passwordError;
  String? _confirmError;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode({bool resend = false}) async {
    final language = emailLanguageOf(context);
    final l = context.l10n;
    final email = resend ? _sentTo! : _email.text;
    await _guard(() async {
      final sent = await AppRepository.instance.resetRequestCode(email: email, language: language);
      if (!mounted) return;
      setState(() {
        _sentTo = validEmailOrNull(email);
        _sentAt = DateTime.now();
        _cooldown = sent.resendAfterSeconds;
        if (resend) _info = l.codeResent;
      });
    });
  }

  Future<void> _reset() async {
    final l = context.l10n;
    if (normalizeEmailCode(_code.text) == null) {
      setState(() => _error = l.codeRequired);
      return;
    }
    setState(() {
      _passwordError = isValidPassword(_password.text) ? null : l.emailErrWeakPassword;
      _confirmError = _passwordError == null && _confirm.text != _password.text ? l.passwordsDontMatch : null;
    });
    if (_passwordError != null || _confirmError != null) return;
    final email = _sentTo!;
    var done = false;
    await _guard(() async {
      await AppRepository.instance.resetComplete(email: email, code: _code.text, newPassword: _password.text);
      done = true;
    });
    if (done && mounted) widget.onDone(email);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sentTo = _sentTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.resetTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (sentTo == null) ...[
          Text(l.resetIntro, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          EmailField(
            key: const ValueKey('reset-email'),
            controller: _email,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            key: const ValueKey('reset-send-code'),
            label: l.sendCode,
            busy: _busy,
            onPressed: _sendCode,
          ),
        ] else ...[
          Text(
            l.codeSentTo(sentTo),
            key: const ValueKey('reset-code-sent'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          CodeField(key: const ValueKey('reset-code'), controller: _code),
          const SizedBox(height: 12),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PasswordField(
                  key: const ValueKey('reset-password'),
                  controller: _password,
                  label: l.newPasswordLabel,
                  helperText: l.passwordHelper,
                  errorText: _passwordError,
                  isNewPassword: true,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  key: const ValueKey('reset-confirm'),
                  controller: _confirm,
                  label: l.confirmPasswordLabel,
                  errorText: _confirmError,
                  isNewPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _reset(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            key: const ValueKey('reset-submit'),
            label: l.resetButton,
            busy: _busy,
            onPressed: _reset,
          ),
        ],
        AuthErrorText(_error),
        if (_info != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_info!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.success, fontSize: 13)),
          ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              key: const ValueKey('reset-back'),
              onPressed: _busy ? null : widget.onCancel,
              child: Text(l.backToLogin),
            ),
            if (sentTo != null)
              ResendCodeButton(
                sentAt: _sentAt,
                cooldownSeconds: _cooldown,
                onResend: _busy ? null : () => _sendCode(resend: true),
              ),
          ],
        ),
        if (kDemoMode) const DemoEmailHint(),
      ],
    );
  }
}
