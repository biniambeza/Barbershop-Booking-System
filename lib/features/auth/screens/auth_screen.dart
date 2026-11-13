import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/ui_kit.dart';
import '../../../services/app_repository.dart';
import '../widgets/email_login_form.dart';
import '../widgets/email_register_form.dart';
import '../widgets/forgot_password_form.dart';

enum _AuthMode { login, register, forgot }

/// Sign-in: email + password ("Log in" / "Register" tabs, with emailed
/// 6-digit codes for registration and password reset) or Google. New
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageToggle(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.heroShadow,
                      ),
                      child: const Icon(Icons.content_cut_rounded, size: 28, color: AppTheme.onInk),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.brandUpper,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.authSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  if (_mode != _AuthMode.forgot) ...[
                    SegmentedButton<_AuthMode>(
                      key: const ValueKey('auth-tabs'),
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: _AuthMode.login,
                          label: Text(l.authTabLogin, key: const ValueKey('auth-tab-login')),
                        ),
                        ButtonSegment(
                          value: _AuthMode.register,
                          label: Text(l.authTabRegister, key: const ValueKey('auth-tab-register')),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => _setMode(s.first),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildEmailForm(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppTheme.hairline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l.authOr, style: const TextStyle(color: AppTheme.textSecondary)),
                      ),
                      const Expanded(child: Divider(color: AppTheme.hairline)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const ValueKey('google-sign-in'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.hairline),
                    ),
                    onPressed: _isLoading ? null : () => _run(repo.signInWithGoogle),
                    icon: _isLoading ? _spinner() : const _GoogleMark(),
                    label: Text(l.continueWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kDemoMode ? l.demoGoogleNotice : l.googleSignInNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: kDemoMode ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: kDemoMode ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      l.authError(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ],
                  if (kDemoMode) ..._buildDemoPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
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
        return const EmailRegisterForm(key: ValueKey('register-form'));
      case _AuthMode.forgot:
        return ForgotPasswordForm(
          key: const ValueKey('forgot-form'),
          initialEmail: _carryEmail,
          onCancel: () => _setMode(_AuthMode.login),
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
      (l.roleOwner, first(UserRole.barbershopOwner), Icons.storefront, AppTheme.ink),
      (l.roleBarber, first(UserRole.barber), Icons.content_cut, AppTheme.teal),
      (l.roleCustomer, first(UserRole.customer), Icons.person, AppTheme.blue),
    ];

    return [
      const SizedBox(height: 28),
      Row(
        children: [
          const Expanded(child: Divider(color: AppTheme.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              l.demoAccounts,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppTheme.hairline)),
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
                    side: const BorderSide(color: AppTheme.hairline),
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ];
  }

  Widget _spinner() {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.ink),
    );
  }
}

/// A simple "G" mark (no bundled brand asset needed).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF4285F4)),
      ),
    );
  }
}
