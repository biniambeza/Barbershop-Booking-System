import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/password_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import 'auth_form_fields.dart';

enum _ResetStep { email, code, password }

/// Forgot password in three steps: email → "Send code"; the emailed code →
/// "Verify"; then (only after a correct code) new password + confirm →
/// "Save". Calls [onDone] with the email after the password was changed.
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

  _ResetStep _step = _ResetStep.email;

  /// The normalized address the code went to (steps 2 and 3).
  String? _sentTo;
  DateTime _sentAt = DateTime.now();
  int _cooldown = 60;

  /// From a correct code (step 3).
  String? _token;
  DateTime? _tokenExpiresAt;

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

  /// Runs [action] with a spinner; errors go to [onError] (default: the
  /// error line). Returns whether [action] succeeded.
  Future<bool> _guard(Future<void> Function() action, {void Function(Object error)? onError}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (onError != null) {
        onError(e);
      } else {
        setState(() => _error = context.l10n.authError(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to step 1 (email kept) with [message], e.g. after the
  /// verification token expired.
  void _restart({String? message}) {
    final sentTo = _sentTo;
    setState(() {
      if (sentTo != null) _email.text = sentTo;
      _step = _ResetStep.email;
      _sentTo = null;
      _token = null;
      _tokenExpiresAt = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
      _passwordError = null;
      _confirmError = null;
      _info = null;
      _error = message;
    });
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
        _step = _ResetStep.code;
        if (resend) {
          _info = l.codeResent;
        } else {
          _code.clear();
        }
      });
    });
  }

  Future<void> _verify() async {
    final l = context.l10n;
    if (normalizeEmailCode(_code.text) == null) {
      setState(() => _error = l.codeRequired);
      return;
    }
    await _guard(() async {
      final verified = await AppRepository.instance.resetVerifyCode(email: _sentTo!, code: _code.text);
      if (!mounted) return;
      setState(() {
        _token = verified.verificationToken;
        _tokenExpiresAt = DateTime.now().add(Duration(seconds: verified.expiresInSeconds));
        _password.clear();
        _confirm.clear();
        _passwordError = null;
        _confirmError = null;
        _step = _ResetStep.password;
      });
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _error = null;
      _passwordError = isValidPassword(_password.text) ? null : l.emailErrWeakPassword;
      _confirmError = _passwordError == null && _confirm.text != _password.text ? l.passwordsDontMatch : null;
    });
    if (_passwordError != null || _confirmError != null) return;
    final expiresAt = _tokenExpiresAt;
    if (_token == null || (expiresAt != null && DateTime.now().isAfter(expiresAt))) {
      _restart(message: l.emailErrVerificationExpired);
      return;
    }
    final email = _sentTo!;
    final done = await _guard(
      () => AppRepository.instance.resetComplete(email: email, verificationToken: _token!, newPassword: _password.text),
      onError: (e) {
        final code = e is EmailAuthException ? e.code : null;
        if (code == EmailAuthErrorCode.verificationExpired) {
          _restart(message: l.emailErrVerificationExpired);
        } else if (code == EmailAuthErrorCode.weakPassword) {
          setState(() => _passwordError = l.authError(e));
        } else {
          setState(() => _error = l.authError(e));
        }
      },
    );
    if (done && mounted) widget.onDone(email);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final Widget step;
    switch (_step) {
      case _ResetStep.email:
        step = _buildEmailStep(context);
      case _ResetStep.code:
        step = _buildCodeStep(context, _sentTo!);
      case _ResetStep.password:
        step = _buildPasswordStep(context, _sentTo!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        step,
        AuthErrorText(_error),
        AuthInfoText(_info),
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
            if (_step != _ResetStep.email)
              TextButton(
                key: const ValueKey('reset-change-email'),
                onPressed: _busy ? null : _restart,
                child: Text(l.changeEmail),
              ),
            if (_step == _ResetStep.code)
              ResendCodeButton(
                sentAt: _sentAt,
                cooldownSeconds: _cooldown,
                onResend: _busy ? null : () => _sendCode(resend: true),
              ),
          ],
        ),
        if (kDemoMode && _step != _ResetStep.password) const DemoEmailHint(),
      ],
    );
  }

  Widget _buildEmailStep(BuildContext context) {
    final l = context.l10n;
    return Column(
      key: const ValueKey('reset-step-email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthStepHeader(step: 1, total: 3, title: l.resetTitle, subtitle: l.resetIntro),
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
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context, String email) {
    final l = context.l10n;
    return Column(
      key: const ValueKey('reset-step-code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthStepHeader(
          step: 2,
          total: 3,
          title: l.enterCodeTitle,
          subtitle: l.codeSentTo(email),
          subtitleKey: const ValueKey('reset-code-sent'),
        ),
        CodeField(key: const ValueKey('reset-code'), controller: _code, onSubmitted: (_) => _verify()),
        const SizedBox(height: 16),
        AuthSubmitButton(
          key: const ValueKey('reset-verify'),
          label: l.verifyButton,
          busy: _busy,
          onPressed: _verify,
        ),
      ],
    );
  }

  Widget _buildPasswordStep(BuildContext context, String email) {
    final l = context.l10n;
    return AutofillGroup(
      key: const ValueKey('reset-step-password'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStepHeader(step: 3, total: 3, title: l.newPasswordTitle, subtitle: l.emailVerifiedNotice(email)),
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
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            key: const ValueKey('reset-submit'),
            label: l.savePasswordButton,
            busy: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
