import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'auth_ui.dart';

/// 'am' or 'en': the language of emails the server sends.
String emailLanguageOf(BuildContext context) => context.l10n.localeName.startsWith('am') ? 'am' : 'en';

class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.textInputAction,
    this.labelAbove = true,
  });

  final TextEditingController controller;
  final bool enabled;
  final TextInputAction? textInputAction;

  /// Bold "Email" above the field with a hint inside (the sign-in look);
  /// false: the usual floating label.
  final bool labelAbove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction ?? TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: labelAbove ? null : l.emailLabel,
        hintText: labelAbove ? l.authEmailHint : null,
        prefixIcon: const Icon(Icons.mail_outline_rounded),
      ),
    );
    return labelAbove ? _Labelled(label: l.emailLabel, child: field) : field;
  }
}

/// [AuthFieldLabel] above [child].
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [AuthFieldLabel(label), child],
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
    this.labelAbove = true,
    this.hintText,
  });

  final TextEditingController controller;
  final String label;

  /// Bold [label] above the field (the sign-in look); false: floating label.
  final bool labelAbove;

  /// Hint inside the field when [labelAbove]; defaults to "Enter your
  /// password" for an existing password.
  final String? hintText;
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
    final above = widget.labelAbove;
    final field = TextField(
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction ?? TextInputAction.next,
      onSubmitted: widget.onSubmitted,
      autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
      decoration: InputDecoration(
        labelText: above ? null : widget.label,
        hintText: above ? widget.hintText ?? (widget.isNewPassword ? null : l.authPasswordHint) : null,
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorText: widget.errorText,
        errorMaxLines: 3,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? l.showPassword : l.hidePassword,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              key: ValueKey(_obscure),
            ),
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
    return above ? _Labelled(label: widget.label, child: field) : field;
  }
}

/// The emailed 6-digit code.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.onSubmitted, this.labelAbove = true});

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  /// Bold "Code" above the field (the sign-in look); false: floating label.
  final bool labelAbove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final field = TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: labelAbove ? null : l.codeLabel,
        hintText: labelAbove ? '••••••' : null,
        hintStyle: TextStyle(fontSize: 24, letterSpacing: 10, color: AppTheme.textTertiary),
        counterText: '',
      ),
    );
    return labelAbove ? _Labelled(label: l.codeLabel, child: field) : field;
  }
}

/// "Step 2 of 3", a title and an optional subtitle above a step of a
/// multi-step email form.
class AuthStepHeader extends StatelessWidget {
  const AuthStepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
    this.subtitleKey,
  });

  final int step;
  final int total;
  final String title;
  final String? subtitle;
  final Key? subtitleKey;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress: one segment per step, green up to this one.
          Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? AppTheme.primary : AppTheme.track,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.authStepOf(step, total),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.25),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              key: subtitleKey,
              style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Green confirmation line under a form.
class AuthInfoText extends StatelessWidget {
  const AuthInfoText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AuthBanner(color: AppTheme.success, icon: Icons.check_circle_outline_rounded, child: Text(text)),
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
      child: AuthBanner(
        color: AppTheme.danger,
        icon: Icons.error_outline_rounded,
        child: Text(text, key: const ValueKey('email-auth-error')),
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
        style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600),
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
    // While busy the button stays green with a spinner (not the grey of a
    // disabled button).
    final enabled = !busy && onPressed != null;
    final style = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: 0,
      textStyle: authFont(16, FontWeight.w800, letterSpacing: 0.2),
      disabledBackgroundColor: busy ? AppTheme.primary : null,
      disabledForegroundColor: busy ? AppTheme.onPrimary : null,
    );
    return AuthPressScale(
      enabled: enabled,
      child: DecoratedBox(
        // A soft green glow under the light-mode button.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled && !AppTheme.isDark
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: ElevatedButton(
          style: style,
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: busy
              ? SizedBox(
                  key: const ValueKey('busy'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.onPrimary),
                )
              : Text(label, key: const ValueKey('label'), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

/// "Resend code" with a countdown; rebuild it with a new [sentAt] after each
/// code is sent to restart the countdown. [label] / [waitingLabel] and
/// [buttonKey] reuse it for emailed links.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.sentAt,
    required this.cooldownSeconds,
    required this.onResend,
    this.label,
    this.waitingLabel,
    this.buttonKey = const ValueKey('resend-code'),
  });

  /// When the last code was sent; restarts the countdown when it changes.
  final DateTime sentAt;
  final int cooldownSeconds;

  /// Null while a request is running.
  final VoidCallback? onResend;

  /// Defaults to "Resend code" / "Resend code in N s".
  final String? label;
  final String Function(int seconds)? waitingLabel;
  final Key buttonKey;

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
    final waitingLabel = widget.waitingLabel ?? l.resendCodeIn;
    return TextButton(
      key: widget.buttonKey,
      onPressed: waiting ? null : widget.onResend,
      child: Text(waiting ? waitingLabel(_remaining) : widget.label ?? l.resendCode),
    );
  }
}

/// "Check your email" panel of the free-plan link fallback: an icon, a
/// title and what to do with the emailed link.
class AuthLinkSentPanel extends StatelessWidget {
  const AuthLinkSentPanel({super.key, required this.title, required this.body, this.bodyKey});

  final String title;
  final String body;
  final Key? bodyKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 36, color: AppTheme.success),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, key: bodyKey, textAlign: TextAlign.center, style: theme.bodyMedium),
        ],
      ),
    );
  }
}
