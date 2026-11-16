import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/password_utils.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import 'auth_form_fields.dart';

enum _RegisterStep { email, code, password, linkPassword, linkSent }

/// Registration in three steps: email → "Send code"; the emailed 6-digit
/// code → "Verify"; then (only after a correct code) password + confirm →
/// "Create account", which signs in and continues to profile setup (name
/// and phone).
///
/// Free-plan fallback (the code functions are not deployed): email →
/// password + confirm → "Create account" emails Firebase's verification
/// link and stays signed out; the panel offers "Resend link" and "I've
/// verified — Log in".
class EmailRegisterForm extends StatefulWidget {
  const EmailRegisterForm({super.key, this.onLogInInstead});

  /// "Log in instead" when the email already has an account; gets the email.
  final ValueChanged<String>? onLogInInstead;

  @override
  State<EmailRegisterForm> createState() => _EmailRegisterFormState();
}

class _EmailRegisterFormState extends State<EmailRegisterForm> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _RegisterStep _step = _RegisterStep.email;

  /// The normalized address the code went to (steps 2 and 3).
  String? _sentTo;
  DateTime _sentAt = DateTime.now();
  int _cooldown = 60;

  /// From a correct code (step 3).
  String? _token;
  DateTime? _tokenExpiresAt;

  bool _busy = false;
  String? _error;

  /// Fallback: whether the verification link went out with the account.
  bool _linkSent = true;

  /// The server said this email already has an account: offer to log in.
  bool _alreadyRegistered = false;
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
      _alreadyRegistered = false;
    });
    try {
      await action();
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (onError != null) {
        onError(e);
      } else {
        setState(() {
          _error = context.l10n.authError(e);
          _alreadyRegistered = e is EmailAuthException && e.code == EmailAuthErrorCode.emailAlreadyRegistered;
        });
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
      _step = _RegisterStep.email;
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
      _alreadyRegistered = false;
    });
  }

  /// "Log in instead" under an 'email already registered' error.
  Widget _logInInstead(String email) {
    final onLogIn = widget.onLogInInstead;
    if (!_alreadyRegistered || onLogIn == null) return const SizedBox.shrink();
    return Align(
      child: TextButton(
        key: const ValueKey('register-login-instead'),
        onPressed: _busy ? null : () => onLogIn(validEmailOrNull(email) ?? email.trim()),
        child: Text(context.l10n.logInInstead),
      ),
    );
  }

  Future<void> _sendCode({bool resend = false}) async {
    final language = emailLanguageOf(context);
    final l = context.l10n;
    final email = resend ? _sentTo! : _email.text;
    await _guard(() async {
      final EmailCodeSent sent;
      if (resend) {
        sent = await AppRepository.instance.registerRequestCode(email: email, language: language);
      } else {
        final start = await AppRepository.instance.registerStart(email: email, language: language);
        if (!mounted) return;
        if (start.usesLink) {
          // Free plan: no code; choose the password next.
          setState(() {
            _sentTo = validEmailOrNull(email);
            _password.clear();
            _confirm.clear();
            _passwordError = null;
            _confirmError = null;
            _step = _RegisterStep.linkPassword;
          });
          return;
        }
        sent = start.sent!;
      }
      if (!mounted) return;
      setState(() {
        _sentTo = validEmailOrNull(email);
        _sentAt = DateTime.now();
        _cooldown = sent.resendAfterSeconds;
        _step = _RegisterStep.code;
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
      final verified = await AppRepository.instance.registerVerifyCode(email: _sentTo!, code: _code.text);
      if (!mounted) return;
      setState(() {
        _token = verified.verificationToken;
        _tokenExpiresAt = DateTime.now().add(Duration(seconds: verified.expiresInSeconds));
        _password.clear();
        _confirm.clear();
        _passwordError = null;
        _confirmError = null;
        _step = _RegisterStep.password;
      });
    });
  }

  Future<void> _create() async {
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
    await _guard(
      () => AppRepository.instance.registerComplete(
        email: _sentTo!,
        verificationToken: _token!,
        password: _password.text,
      ),
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
    // On success the root gate switches to profile setup.
  }

  /// Fallback: validates the passwords, creates the account and emails the
  /// verification link.
  Future<void> _createWithLink() async {
    final l = context.l10n;
    final language = emailLanguageOf(context);
    setState(() {
      _error = null;
      _passwordError = isValidPassword(_password.text) ? null : l.emailErrWeakPassword;
      _confirmError = _passwordError == null && _confirm.text != _password.text ? l.passwordsDontMatch : null;
    });
    if (_passwordError != null || _confirmError != null) return;
    await _guard(
      () async {
        final sent = await AppRepository.instance.registerWithLink(
          email: _sentTo!,
          password: _password.text,
          language: language,
        );
        if (!mounted) return;
        setState(() {
          _linkSent = sent;
          _sentAt = DateTime.now();
          _cooldown = sent ? 60 : 0;
          _step = _RegisterStep.linkSent;
        });
      },
      onError: (e) {
        final code = e is EmailAuthException ? e.code : null;
        if (code == EmailAuthErrorCode.weakPassword) {
          setState(() => _passwordError = l.authError(e));
        } else {
          setState(() {
            _error = l.authError(e);
            _alreadyRegistered = code == EmailAuthErrorCode.emailAlreadyRegistered;
          });
        }
      },
    );
  }

  /// Fallback: signs in briefly to email a new verification link.
  Future<void> _resendLink() async {
    final l = context.l10n;
    final language = emailLanguageOf(context);
    final email = _sentTo!;
    await _guard(() async {
      final result = await AppRepository.instance.resendVerificationLink(
        email: email,
        password: _password.text,
        language: language,
      );
      if (!mounted) return;
      setState(() {
        _sentAt = DateTime.now();
        _cooldown = 60;
        if (result == VerificationLinkResult.alreadyVerified) {
          _info = l.emailAlreadyVerified;
        } else {
          _linkSent = true;
          _info = l.linkResent(email);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _RegisterStep.email:
        return _buildEmailStep(context);
      case _RegisterStep.code:
        return _buildCodeStep(context, _sentTo!);
      case _RegisterStep.password:
        return _buildPasswordStep(context, _sentTo!);
      case _RegisterStep.linkPassword:
        return _buildLinkPasswordStep(context, _sentTo!);
      case _RegisterStep.linkSent:
        return _buildLinkSentStep(context, _sentTo!);
    }
  }

  Widget _buildEmailStep(BuildContext context) {
    final l = context.l10n;
    final usesLink = AppRepository.instance.registerUsesLink;
    return Column(
      key: const ValueKey('register-step-email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthStepHeader(
          step: 1,
          total: usesLink ? 2 : 3,
          title: l.registerEmailTitle,
          subtitle: usesLink ? l.registerLinkIntro : l.registerEmailIntro,
        ),
        EmailField(
          key: const ValueKey('register-email'),
          controller: _email,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        AuthSubmitButton(
          key: const ValueKey('register-send-code'),
          label: usesLink ? l.authContinue : l.sendCode,
          busy: _busy,
          onPressed: _sendCode,
        ),
        AuthErrorText(_error),
        _logInInstead(_email.text),
        if (kDemoMode && !usesLink) const DemoEmailHint(),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context, String email) {
    final l = context.l10n;
    return Column(
      key: const ValueKey('register-step-code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthStepHeader(
          step: 2,
          total: 3,
          title: l.enterCodeTitle,
          subtitle: l.codeSentTo(email),
          subtitleKey: const ValueKey('register-code-sent'),
        ),
        CodeField(key: const ValueKey('register-code'), controller: _code, onSubmitted: (_) => _verify()),
        const SizedBox(height: 16),
        AuthSubmitButton(
          key: const ValueKey('register-verify'),
          label: l.verifyButton,
          busy: _busy,
          onPressed: _verify,
        ),
        AuthErrorText(_error),
        _logInInstead(email),
        AuthInfoText(_info),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              key: const ValueKey('register-change-email'),
              onPressed: _busy ? null : _restart,
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

  Widget _buildPasswordStep(BuildContext context, String email) {
    final l = context.l10n;
    return AutofillGroup(
      key: const ValueKey('register-step-password'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStepHeader(step: 3, total: 3, title: l.createPasswordTitle, subtitle: l.emailVerifiedNotice(email)),
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
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            key: const ValueKey('register-create'),
            label: l.createAccountButton,
            busy: _busy,
            onPressed: _create,
          ),
          AuthErrorText(_error),
          const SizedBox(height: 6),
          Align(
            child: TextButton(
              key: const ValueKey('register-change-email'),
              onPressed: _busy ? null : _restart,
              child: Text(l.changeEmail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPasswordStep(BuildContext context, String email) {
    final l = context.l10n;
    return AutofillGroup(
      key: const ValueKey('register-step-link-password'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStepHeader(
            step: 2,
            total: 2,
            title: l.createPasswordTitle,
            subtitle: l.registerLinkPasswordIntro(email),
          ),
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
            onSubmitted: (_) => _createWithLink(),
          ),
          const SizedBox(height: 16),
          AuthSubmitButton(
            key: const ValueKey('register-create'),
            label: l.createAccountButton,
            busy: _busy,
            onPressed: _createWithLink,
          ),
          AuthErrorText(_error),
          _logInInstead(email),
          const SizedBox(height: 6),
          Align(
            child: TextButton(
              key: const ValueKey('register-change-email'),
              onPressed: _busy ? null : _restart,
              child: Text(l.changeEmail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkSentStep(BuildContext context, String email) {
    final l = context.l10n;
    final onLogIn = widget.onLogInInstead;
    return Column(
      key: const ValueKey('register-step-link-sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthLinkSentPanel(
          title: l.verifyLinkSentTitle,
          body: l.verifyLinkSentBody(email),
          bodyKey: const ValueKey('register-link-sent'),
        ),
        if (!_linkSent) AuthErrorText(l.verifyLinkNotSent),
        if (onLogIn != null)
          AuthSubmitButton(
            key: const ValueKey('register-verified-login'),
            label: l.verifiedLogIn,
            busy: _busy,
            onPressed: () => onLogIn(email),
          ),
        AuthErrorText(_error),
        AuthInfoText(_info),
        const SizedBox(height: 6),
        Align(
          child: ResendCodeButton(
            sentAt: _sentAt,
            cooldownSeconds: _cooldown,
            label: l.resendLink,
            waitingLabel: l.resendLinkIn,
            buttonKey: const ValueKey('register-resend-link'),
            onResend: _busy ? null : _resendLink,
          ),
        ),
      ],
    );
  }
}
