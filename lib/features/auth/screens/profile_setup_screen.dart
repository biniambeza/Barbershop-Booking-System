import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../l10n/l10n.dart';
import '../../shared/widgets/language_toggle.dart';
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
                  const Icon(Icons.verified_user_outlined, size: 54, color: AppTheme.primaryGold),
                  const SizedBox(height: 12),
                  Text(
                    l.welcome,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (email != null)
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: invite != null ? AppTheme.primaryGold.withValues(alpha: 0.5) : Colors.white12,
                      ),
                    ),
                    child: Text(roleMessage, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: l.fullName,
                      prefixIcon: const Icon(Icons.person_outline),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('profile-phone'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                    decoration: InputDecoration(
                      labelText: '${l.mobileNumber} *',
                      hintText: '09XX XXX XXX',
                      helperText: l.profilePhoneHelper,
                      errorText: _phoneError,
                      prefixIcon: const Icon(Icons.phone_android),
                    ),
                    onSubmitted: (_) => _isLoading ? null : _submit(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(l.continueLabel),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => repo.signOut(),
                    child: Text(l.useDifferentAccount),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
