import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';
import '../../../services/phone_auth_service.dart';

/// First sign-in: ask for the user's name and create their profile.
///
/// If the phone number has a pending invite (shop owner or barber), the
/// screen says which role they are joining as; otherwise they become a
/// customer.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AppRepository.instance.pendingInvite?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AppRepository.instance.completeProfile(name: _nameController.text);
    } catch (e) {
      if (mounted) setState(() => _error = describeAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;
    final invite = repo.pendingInvite;
    final phone = repo.pendingPhone;
    final shopName = invite?.shopId != null ? repo.getShopById(invite!.shopId!)?.name : null;

    final String roleMessage;
    if (invite == null) {
      roleMessage = 'Create your account to book barbers across Addis Ababa.';
    } else if (invite.role == UserRole.barbershopOwner) {
      roleMessage = 'You have been invited to manage ${shopName ?? 'a barbershop'} as its owner.';
    } else if (invite.role == UserRole.barber) {
      roleMessage = 'You have been invited to join ${shopName ?? 'a barbershop'} as a barber.';
    } else {
      roleMessage = 'You have been invited as ${invite.role.displayName}.';
    }

    return Scaffold(
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
                    'Welcome',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (phone != null)
                    Text(
                      formatEthiopianPhone(phone),
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
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      counterText: '',
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
                        : const Text('Continue'),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => repo.signOut(),
                    child: const Text('Use a different number'),
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
