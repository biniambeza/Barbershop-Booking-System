import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../../services/app_repository.dart';

/// Phone number + SMS code sign-in. The same flow covers new and returning
/// users; the role comes from the user's profile (or their invite), never
/// from anything chosen on this screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;

  static const _resendSeconds = 60;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _sendCode() async {
    if (normalizeEthiopianPhone(_phoneController.text) == null) {
      setState(() => _error = context.l10n.invalidEthiopianPhone);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AppRepository.instance.sendOtp(_phoneController.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _codeController.clear();
      _startResendTimer();
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.authError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AppRepository.instance.verifyOtp(_codeController.text);
      // On success the root gate switches screens.
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.authError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendIn = 0;
      _error = null;
      _codeController.clear();
    });
  }

  Future<void> _demoQuickLogin(String phone) async {
    _phoneController.text = phone;
    await _sendCode();
    if (!_codeSent) return;
    _codeController.text = kDemoOtpCode;
    await _verifyCode();
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final sessionError = repo.authError;
    final phone = repo.pendingPhone;

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
                    _codeSent
                        ? l.authSubtitleCode(formatEthiopianPhone(phone ?? _phoneController.text))
                        : l.authSubtitlePhone,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  if (!_codeSent) ..._buildPhoneStep() else ..._buildCodeStep(),
                  if (_error != null || sessionError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error ?? l.errorText(sessionError!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                  if (kDemoMode && !_codeSent) ..._buildDemoPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
        decoration: InputDecoration(
          labelText: context.l10n.mobileNumber,
          hintText: '09XX XXX XXX',
          prefixIcon: const Icon(Icons.phone_android),
        ),
        onSubmitted: (_) => _isLoading ? null : _sendCode(),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _isLoading ? null : _sendCode,
        child: _isLoading ? _spinner() : Text(context.l10n.sendCode),
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.smsNotice,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: '', hintText: '------'),
        onChanged: (value) {
          if (value.length == 6 && !_isLoading) _verifyCode();
        },
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _isLoading ? null : _verifyCode,
        child: _isLoading ? _spinner() : Text(context.l10n.verify),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isLoading ? null : _changeNumber,
            child: Text(context.l10n.changeNumber),
          ),
          TextButton(
            onPressed: _isLoading || _resendIn > 0 ? null : _sendCode,
            child: Text(_resendIn > 0 ? context.l10n.resendIn(_resendIn) : context.l10n.resendCode),
          ),
        ],
      ),
      if (kDemoMode)
        Text(
          context.l10n.demoCodeNotice(kDemoOtpCode),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.primaryGold),
        ),
    ];
  }

  List<Widget> _buildDemoPanel() {
    // Phone numbers of the demo accounts in AppRepository._initDemoData.
    final l = context.l10n;
    final personas = <(String, String, IconData, Color)>[
      (l.roleAdminShort, '+251911000001', Icons.admin_panel_settings, Colors.purpleAccent),
      (l.roleOwner, '+251911000101', Icons.storefront, AppTheme.primaryGold),
      (l.roleBarber, '+251911000201', Icons.content_cut, Colors.tealAccent),
      (l.roleCustomer, '+251911000301', Icons.person, Colors.lightBlueAccent),
    ];

    return [
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(child: Divider(color: Colors.white12)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
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
          Expanded(child: Divider(color: Colors.white12)),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final (label, phone, icon, color) in personas)
            SizedBox(
              width: 180,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : () => _demoQuickLogin(phone),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: color),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      formatEthiopianPhone(phone),
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
