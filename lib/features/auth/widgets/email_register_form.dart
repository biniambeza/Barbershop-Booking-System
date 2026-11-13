import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/password_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import 'auth_form_fields.dart';

/// Registration: email + password + confirm → "Send code", then the emailed
/// 6-digit code → "Verify and create account". The new account continues
/// to profile setup (name and phone).
class EmailRegisterForm extends StatefulWidget {
  const EmailRegisterForm({super.key});

  @override
  State<EmailRegisterForm> createState() => _EmailRegisterFormState();
}

class _EmailRegisterFormState extends State<EmailRegisterForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  /// Set once a code was sent: the normalized address it went to.
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
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
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

  bool _validatePasswords() {
    final l = context.l10n;
    setState(() {
      _passwordError = isValidPassword(_password.text) ? null : l.emailErrWeakPassword;
      _confirmError = _passwordError == null && _confirm.text != _password.text ? l.passwordsDontMatch : null;
    });
    return _passwordError == null && _confirmError == null;
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_validatePasswords()) return;
    final language = emailLanguageOf(context);
    final l = context.l10n;
    final email = resend ? _sentTo! : _email.text;
    await _guard(() async {
      final sent = await AppRepository.instance.registerRequestCode(
        email: email,
        password: _password.text,
        language: language,
      );
      if (!mounted) return;
      setState(() {
        _sentTo = validEmailOrNull(email);
        _sentAt = DateTime.now();
        _cooldown = sent.resendAfterSeconds;
        if (resend) _info = l.codeResent;
      });
    });
  }

  Future<void> _verify() async {
    final l = context.l10n;
    if (normalizeEmailCode(_code.text) == null) {
      setState(() => _error = l.codeRequired);
      return;
    }
    await _guard(() => AppRepository.instance.registerComplete(
          email: _sentTo!,
          code: _code.text,
          password: _password.text,
        ));
    // On success the root gate switches to profile setup.
  }

  void _changeEmail() {
    setState(() {
      _sentTo = null;
      _code.clear();
      _error = null;
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _sentTo == null ? _buildDetails(context) : _buildCodeStep(context, _sentTo!);
  }

  Widget _buildDetails(BuildContext context) {
    final l = context.l10n;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmailField(key: const ValueKey('register-email'), controller: _email),
          const SizedBox(height: 12),
          PasswordField(
            key: const ValueKey('register-password'),
            controller: _password,
            label: l.passwordLabel,
            helperText: l.passwordHelper,
            errorText: _passwordError,
            isNewPassword: true,
          ),
          const SizedBox(height: 12),
          PasswordField(
            key: const ValueKey('register-confirm'),
            controller: _confirm,
            label: l.confirmPasswordLabel,
            errorText: _confirmError,
            isNewPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            key: const ValueKey('register-send-code'),
            label: l.sendCode,
            busy: _busy,
            onPressed: _sendCode,
          ),
          AuthErrorText(_error),
          if (kDemoMode) const DemoEmailHint(),
        ],
      ),
    );
  }

  Widget _buildCodeStep(BuildContext context, String email) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.codeSentTo(email),
          key: const ValueKey('register-code-sent'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        CodeField(key: const ValueKey('register-code'), controller: _code, onSubmitted: (_) => _verify()),
        const SizedBox(height: 16),
        AuthSubmitButton(
          key: const ValueKey('register-verify'),
          label: l.verifyAndCreate,
          busy: _busy,
          onPressed: _verify,
        ),
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
              key: const ValueKey('register-change-email'),
              onPressed: _busy ? null : _changeEmail,
              child: Text(l.changeEmail),
            ),
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
