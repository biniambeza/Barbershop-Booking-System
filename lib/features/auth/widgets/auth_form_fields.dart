import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';

/// 'am' or 'en': the language of emails the server sends.
String emailLanguageOf(BuildContext context) => context.l10n.localeName.startsWith('am') ? 'am' : 'en';

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller, this.enabled = true, this.textInputAction});

  final TextEditingController controller;
  final bool enabled;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction ?? TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: context.l10n.emailLabel,
        prefixIcon: const Icon(Icons.email_outlined),
      ),
    );
  }
}

/// Password input with a show / hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.helperText,
    this.errorText,
    this.isNewPassword = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool isNewPassword;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction ?? TextInputAction.next,
      onSubmitted: widget.onSubmitted,
      autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorText: widget.errorText,
        errorMaxLines: 3,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscure ? l.showPassword : l.hidePassword,
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// The emailed 6-digit code.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
      decoration: InputDecoration(labelText: context.l10n.codeLabel, counterText: ''),
    );
  }
}

/// Red error line under a form.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        key: const ValueKey('email-auth-error'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.danger, fontSize: 13),
      ),
    );
  }
}

/// Gold "Demo: code is 123456" hint (demo builds only).
class DemoEmailHint extends StatelessWidget {
  const DemoEmailHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        context.l10n.demoEmailHint,
        key: const ValueKey('demo-email-hint'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppTheme.ink),
      ),
    );
  }
}

/// Primary action button that shows a spinner while [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({super.key, required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onInk),
            )
          : Text(label),
    );
  }
}

/// "Resend code" with a countdown; rebuild it with a new [sentAt] after each
/// code is sent to restart the countdown.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({super.key, required this.sentAt, required this.cooldownSeconds, required this.onResend});

  /// When the last code was sent; restarts the countdown when it changes.
  final DateTime sentAt;
  final int cooldownSeconds;

  /// Null while a request is running.
  final VoidCallback? onResend;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ResendCodeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentAt != widget.sentAt || oldWidget.cooldownSeconds != widget.cooldownSeconds) _start();
  }

  void _start() {
    _timer?.cancel();
    _remaining = widget.cooldownSeconds;
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final waiting = _remaining > 0;
    return TextButton(
      key: const ValueKey('resend-code'),
      onPressed: waiting ? null : widget.onResend,
      child: Text(waiting ? l.resendCodeIn(_remaining) : l.resendCode),
    );
  }
}
