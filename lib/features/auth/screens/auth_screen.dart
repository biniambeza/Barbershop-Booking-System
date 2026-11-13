import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/user_model.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../../services/app_repository.dart';

/// Google sign-in. The same flow covers new and returning users; the role
/// comes from the user's profile (or their email invite), never from
/// anything chosen on this screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  Object? _error;

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
                  const Icon(Icons.content_cut_rounded, size: 58, color: AppTheme.primaryGold),
                  const SizedBox(height: 12),
                  Text(
                    l.brandUpper,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.authSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    key: const ValueKey('google-sign-in'),
                    onPressed: _isLoading ? null : () => _run(repo.signInWithGoogle),
                    icon: _isLoading ? _spinner() : const _GoogleMark(),
                    label: Text(l.continueWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kDemoMode ? l.demoGoogleNotice : l.googleSignInNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: kDemoMode ? AppTheme.primaryGold : AppTheme.textSecondary),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      l.authError(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
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

  List<Widget> _buildDemoPanel() {
    final l = context.l10n;
    final users = AppRepository.instance.getAllUsers();
    AppUser? first(UserRole role) => users.where((u) => u.role == role && u.email != null).firstOrNull;
    final personas = <(String, AppUser?, IconData, Color)>[
      (l.roleAdminShort, first(UserRole.admin), Icons.admin_panel_settings, Colors.purpleAccent),
      (l.roleOwner, first(UserRole.barbershopOwner), Icons.storefront, AppTheme.primaryGold),
      (l.roleBarber, first(UserRole.barber), Icons.content_cut, Colors.tealAccent),
      (l.roleCustomer, first(UserRole.customer), Icons.person, Colors.lightBlueAccent),
    ];

    return [
      const SizedBox(height: 28),
      Row(
        children: [
          const Expanded(child: Divider(color: Colors.white12)),
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
          const Expanded(child: Divider(color: Colors.white12)),
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () => _run(() async => AppRepository.instance.signInAsDemoUser(user.email!)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 22, color: color),
                      const SizedBox(height: 4),
                      Text(
                        l.demoContinueAs(label),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
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
