import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../applications/shop_applications_service.dart'; // shop applications
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/theme_mode_toggle.dart';
import '../widgets/auth_form_fields.dart';
import '../widgets/auth_ui.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';

/// First sign-in: ask for the user's name and mobile number and create
/// their profile.
///
/// The name is prefilled from the invite or the Google account. The mobile
/// number is required (SMS reminders, payments, bookings) but not verified.
/// If the Google email has a pending invite (shop owner or barber), the
/// screen says which role they are joining as; otherwise they become a
/// customer.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final repo = AppRepository.instance;
    final inviteName = repo.pendingInvite?.name.trim() ?? '';
    _nameController = TextEditingController(
      text: inviteName.isNotEmpty ? inviteName : (repo.pendingDisplayName ?? ''),
    );
    // Barber accounts: the phone the owner saved on the barber profile.
    final pendingPhone = repo.pendingPhone;
    if (pendingPhone != null && pendingPhone.isNotEmpty) _phoneController.text = pendingPhone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (normalizeEthiopianPhone(_phoneController.text) == null) {
      setState(() => _phoneError = context.l10n.invalidEthiopianPhone);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _phoneError = null;
    });
    try {
      await AppRepository.instance.completeProfile(name: _nameController.text, phone: _phoneController.text);
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.authError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final invite = repo.pendingInvite;
    final email = repo.pendingEmail;
    final shopName = invite?.shopId != null ? repo.getShopById(invite!.shopId!)?.name : null;

    final l = context.l10n;
    final String roleMessage;
    if (invite == null) {
      roleMessage = l.profileCustomerMessage;
    } else if (invite.role == UserRole.barbershopOwner) {
      roleMessage = l.profileOwnerInvite(shopName ?? l.aBarbershop);
    } else if (invite.role == UserRole.barber) {
      roleMessage = l.profileBarberInvite(shopName ?? l.aBarbershop);
    } else {
      roleMessage = l.profileRoleInvite(l.roleName(invite.role));
    }

    final theme = Theme.of(context);
    final dark = AppTheme.isDark;
    final pageColor = dark ? AppTheme.background : AppTheme.card;
    var order = 0;
    Widget enter(Widget child) => AuthFadeSlideIn(delay: Duration(milliseconds: 60 * order++), child: child);

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    enter(Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.greenSoft,
                          border: Border.all(color: AppTheme.green.withValues(alpha: dark ? 0.45 : 0.25), width: 1.5),
                        ),
                        child: Icon(Icons.verified_user_outlined, size: 36, color: AppTheme.success),
                      ),
                    )),
                    const SizedBox(height: 16),
                    enter(Text(
                      l.welcome,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    )),
                    if (email != null) ...[
                      const SizedBox(height: 6),
                      enter(Text(
                        email,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      )),
                    ],
                    const SizedBox(height: 18),
                    enter(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: invite != null ? AppTheme.greenSoft : AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: invite != null ? AppTheme.green.withValues(alpha: 0.5) : AppTheme.hairline,
                        ),
                      ),
                      child: Text(
                        roleMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.4,
                          color: invite != null ? AppTheme.success : AppTheme.textPrimary,
                          fontWeight: invite != null ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    )),
                    const SizedBox(height: 22),
                    enter(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthFieldLabel(l.fullName),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 100,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            counterText: '',
                          ),
                        ),
                      ],
                    )),
                    const SizedBox(height: 14),
                    enter(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthFieldLabel('${l.mobileNumber} *'),
                        TextField(
                          key: const ValueKey('profile-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                          decoration: InputDecoration(
                            hintText: '09XX XXX XXX',
                            helperText: l.profilePhoneHelper,
                            helperMaxLines: 2,
                            errorText: _phoneError,
                            errorMaxLines: 2,
                            prefixIcon: const Icon(Icons.phone_android_rounded),
                          ),
                          onSubmitted: (_) => _isLoading ? null : _submit(),
                        ),
                      ],
                    )),
                    // --- shop applications: "I own a barbershop" ---
                    if (invite == null) ...[
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        key: const ValueKey('profile-own-shop'),
                        value: ShopApplicationsService.instance.openFormAfterSignUp,
                        onChanged: _isLoading
                            ? null
                            : (v) => setState(() => ShopApplicationsService.instance.openFormAfterSignUp = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.green,
                        title: Text(l.applSignUpOwnShop, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(l.applSignUpOwnShopHint, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    // --- end shop applications ---
                    const SizedBox(height: 16),
                    enter(AuthSubmitButton(label: l.continueLabel, busy: _isLoading, onPressed: _submit)),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _isLoading ? null : () => repo.signOut(),
                      child: Text(l.useDifferentAccount),
                    ),
                    if (_error != null) AuthErrorText(_error),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
