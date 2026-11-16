import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/brand/crown_blade_logo.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/theme_mode_toggle.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../../services/app_repository.dart';
import '../widgets/email_login_form.dart';
import '../widgets/email_register_form.dart';
import '../widgets/auth_ui.dart';
import '../widgets/forgot_password_form.dart';
import '../../legal/privacy_policy_screen.dart' show PrivacyConsentNote; // privacy policy

enum _AuthMode { login, register, forgot }

/// Sign-in: email + password ("Log in" / "Register" tabs, with emailed
/// 6-digit codes for registration and password reset, or Firebase's emailed
/// links when the code functions are not deployed) or Google. New
/// accounts continue to profile setup; the role comes from the user's
/// profile (or their email invite), never from anything chosen here.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  Object? _error;

  _AuthMode _mode = _AuthMode.login;

  /// Prefills the login / reset email when switching between them.
  String? _carryEmail;

  /// "Password changed" notice shown on the login form after a reset.
  bool _passwordWasReset = false;

  /// Bumped to rebuild the login form with a new prefilled email.
  int _loginFormVersion = 0;

  /// account deletion: "Your account was deleted." after deleting it.
  late final bool _accountDeleted = AppRepository.instance.takeAccountDeletedNotice();

  @override
  void initState() {
    super.initState();
    // A Google-only user who signed out to create a password lands on
    // "Forgot password" with their Gmail.
    final setPasswordEmail = AppRepository.instance.takeSetPasswordEmail();
    if (setPasswordEmail != null) {
      _mode = _AuthMode.forgot;
      _carryEmail = setPasswordEmail;
    }
  }

  void _setMode(_AuthMode mode) => setState(() {
        _mode = mode;
        _error = null;
        if (mode != _AuthMode.login) _passwordWasReset = false;
      });

  Future<void> _run(Future<void> Function() signIn) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await signIn();
      // On success the root gate switches screens.
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final error = _error ?? repo.authError;
    final l = context.l10n;
    final dark = AppTheme.isDark;
    final theme = Theme.of(context);
    final pageColor = dark ? AppTheme.background : AppTheme.card;

    // Staggered entrance, once, when the screen first appears.
    var order = 0;
    Widget enter(Widget child) => AuthFadeSlideIn(
          delay: Duration(milliseconds: 60 * order++),
          duration: const Duration(milliseconds: 440),
          child: child,
        );

    final heading = switch (_mode) {
      _AuthMode.login => l.authWelcomeBack,
      _AuthMode.register => l.authCreateAccountTitle,
      _AuthMode.forgot => null,
    };

    final top = <Widget>[
      enter(const _BrandHeader()),
      const SizedBox(height: 22),
      if (_accountDeleted) ...[
        // account deletion
        enter(AuthBanner(
          key: const ValueKey('account-deleted-notice'),
          color: AppTheme.success,
          icon: Icons.check_circle_outline_rounded,
          child: Text(l.deleteAccountDone),
        )),
        const SizedBox(height: 18),
      ],
      if (heading != null) ...[
        enter(AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: Column(
            key: ValueKey(_mode),
            children: [
              Text(
                heading,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        )),
        const SizedBox(height: 18),
      ],
      if (_mode != _AuthMode.forgot) ...[
        enter(AuthModeSwitch(
          key: const ValueKey('auth-tabs'),
          labels: [l.authTabLogin, l.authTabRegister],
          labelKeys: const [ValueKey('auth-tab-login'), ValueKey('auth-tab-register')],
          selected: _mode == _AuthMode.login ? 0 : 1,
          onChanged: (i) => _setMode(i == 0 ? _AuthMode.login : _AuthMode.register),
        )),
        const SizedBox(height: 22),
      ],
      enter(
        // A new key per mode plays the entrance again: the forms switch
        // with a short fade and slide.
        AuthFadeSlideIn(
          key: ValueKey('form-$_mode'),
          duration: const Duration(milliseconds: 340),
          offset: 10,
          child: _buildEmailForm(),
        ),
      ),
      const SizedBox(height: 22),
      enter(AuthOrDivider(label: l.authOr)),
      const SizedBox(height: 22),
      enter(_GoogleButton(
        busy: _isLoading,
        label: l.continueWithGoogle,
        onPressed: _isLoading ? null : () => _run(repo.signInWithGoogle),
      )),
      const SizedBox(height: 10),
      enter(Text(
        kDemoMode ? l.demoGoogleNotice : l.googleSignInNotice,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: kDemoMode ? AppTheme.textPrimary : AppTheme.textTertiary,
          fontWeight: kDemoMode ? FontWeight.w500 : FontWeight.w400,
        ),
      )),
      if (error != null) ...[
        const SizedBox(height: 14),
        AuthBanner(
          color: AppTheme.danger,
          icon: Icons.error_outline_rounded,
          child: Text(l.authError(error)),
        ),
      ],
      if (kDemoMode) ..._buildDemoPanel(),
    ];

    final bottom = <Widget>[
      const SizedBox(height: 24),
      if (_mode != _AuthMode.forgot) enter(_buildFooterSwitch()),
      const SizedBox(height: 4),
      enter(const PrivacyConsentNote()), // privacy policy
    ];

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: pageColor,
        elevation: 0,
        actions: const [ThemeModeToggle(), LanguageToggle(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: Theme(
          data: theme.copyWith(inputDecorationTheme: authInputTheme(theme.inputDecorationTheme)),
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Center(
                child: ConstrainedBox(
                  // At least the screen's height, so the footer sits at the
                  // bottom on tall phones; scrolls on small ones.
                  constraints: BoxConstraints(maxWidth: 440, minHeight: math.max(0, viewport.maxHeight - 16)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top),
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Don't have an account? Sign up" / "Already have an account? Log in".
  Widget _buildFooterSwitch() {
    final l = context.l10n;
    final login = _mode == _AuthMode.login;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          login ? l.authNoAccount : l.authHaveAccount,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        TextButton(
          key: const ValueKey('auth-footer-switch'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 40),
            textStyle: authFont(14, FontWeight.w800),
          ),
          onPressed: () => _setMode(login ? _AuthMode.register : _AuthMode.login),
          child: Text(login ? l.authSignUp : l.authTabLogin),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    switch (_mode) {
      case _AuthMode.login:
        return EmailLoginForm(
          key: ValueKey('login-form-$_loginFormVersion'),
          initialEmail: _carryEmail,
          notice: _passwordWasReset ? context.l10n.resetDone : null,
          onForgotPassword: (email) {
            _carryEmail = email;
            _setMode(_AuthMode.forgot);
          },
        );
      case _AuthMode.register:
        return EmailRegisterForm(
          key: const ValueKey('register-form'),
          onLogInInstead: (email) => setState(() {
            _carryEmail = email;
            _passwordWasReset = false;
            _loginFormVersion++;
            _mode = _AuthMode.login;
            _error = null;
          }),
        );
      case _AuthMode.forgot:
        return ForgotPasswordForm(
          key: const ValueKey('forgot-form'),
          initialEmail: _carryEmail,
          onCancel: () => _setMode(_AuthMode.login),
          onBackToLogin: (email) => setState(() {
            _carryEmail = email;
            _passwordWasReset = false;
            _loginFormVersion++;
            _mode = _AuthMode.login;
            _error = null;
          }),
          onDone: (email) => setState(() {
            _carryEmail = email;
            _passwordWasReset = true;
            _loginFormVersion++;
            _mode = _AuthMode.login;
          }),
        );
    }
  }

  List<Widget> _buildDemoPanel() {
    final l = context.l10n;
    final users = AppRepository.instance.getAllUsers();
    AppUser? first(UserRole role) => users.where((u) => u.role == role && u.email != null).firstOrNull;
    final personas = <(String, AppUser?, IconData, Color)>[
      (l.roleAdminShort, first(UserRole.admin), Icons.admin_panel_settings, AppTheme.purple),
      (l.roleOwner, first(UserRole.barbershopOwner), Icons.storefront, AppTheme.green),
      (l.roleBarber, first(UserRole.barber), Icons.content_cut, AppTheme.teal),
      (l.roleCustomer, first(UserRole.customer), Icons.person, AppTheme.blue),
    ];

    return [
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(child: Divider(color: AppTheme.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              l.demoAccounts,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppTheme.hairline)),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final (label, user, icon, color) in personas)
            if (user != null)
              SizedBox(
                width: 180,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    backgroundColor: AppTheme.card,
                    side: BorderSide(color: AppTheme.hairline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPanel + 2)),
                  ),
                  onPressed:
                      _isLoading ? null : () => _run(() async => AppRepository.instance.signInAsDemoUser(user.email!)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTile(icon: icon, color: color, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        l.demoContinueAs(label),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ];
  }

}

/// "CROWN & BLADE" with the logo: the top of the sign-in screen.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
                AppTheme.primary.withValues(alpha: 0),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: const CrownBladeLogo.adaptive(size: 66),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            context.l10n.brandUpper,
            textAlign: TextAlign.center,
            style: authFont(21, FontWeight.w800, letterSpacing: 3.4, color: AppTheme.textPrimary, height: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        // A short green "blade" under the wordmark.
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDeep]),
          ),
        ),
      ],
    );
  }
}

/// Full-width white "Continue with Google" pill with the multicolour G (a
/// hairline in light mode; plain white on the dark page).
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.label, required this.onPressed});

  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  static const _text = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return AuthPressScale(
      enabled: onPressed != null,
      child: OutlinedButton.icon(
        key: const ValueKey('google-sign-in'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: Colors.white,
          foregroundColor: _text,
          disabledBackgroundColor: Colors.white.withValues(alpha: dark ? 0.85 : 1),
          disabledForegroundColor: _text.withValues(alpha: 0.6),
          overlayColor: AppTheme.primaryDeep,
          side: BorderSide(color: dark ? Colors.white : AppTheme.outline, width: 1.3),
          shape: const StadiumBorder(),
          textStyle: authFont(16, FontWeight.w700),
        ),
        onPressed: onPressed,
        icon: busy
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppTheme.primaryDeep),
              )
            : const GoogleGLogo(size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
