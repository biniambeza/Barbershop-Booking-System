import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/app_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  UserRole _selectedRole = UserRole.customer;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'John Doe');
  final _emailController = TextEditingController(text: 'barber@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _shopNameController = TextEditingController(text: 'Crown & Razor Lounge');
  final _shopAddressController = TextEditingController(text: '5th Ave & 42nd St');

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await AppRepository.instance.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          role: _selectedRole,
          shopName: _selectedRole == UserRole.barbershopOwner ? _shopNameController.text.trim() : null,
          shopAddress: _selectedRole == UserRole.barbershopOwner ? _shopAddressController.text.trim() : null,
        );
      } else {
        await AppRepository.instance.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.content_cut_rounded,
                    size: 64,
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CROWN & BLADE',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUp
                        ? 'Join the premier barbershop network'
                        : 'Sign in to access your appointments & shop',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),

                  // Mode Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isSignUp = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isSignUp ? AppTheme.primaryGold : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Sign In',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isSignUp ? Colors.black : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isSignUp = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isSignUp ? AppTheme.primaryGold : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isSignUp ? Colors.black : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Role Selection (on sign up)
                  if (_isSignUp) ...[
                    Text(
                      'I want to register as:',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            selected: _selectedRole == UserRole.customer,
                            selectedColor: AppTheme.primaryGold,
                            onSelected: (val) {
                              if (val) setState(() => _selectedRole = UserRole.customer);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('Shop Owner', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            selected: _selectedRole == UserRole.barbershopOwner,
                            selectedColor: AppTheme.primaryGold,
                            onSelected: (val) {
                              if (val) setState(() => _selectedRole = UserRole.barbershopOwner);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter name' : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Password must be 6+ chars' : null,
                  ),
                  const SizedBox(height: 12),

                  // Additional fields for Barbershop Owner
                  if (_isSignUp && _selectedRole == UserRole.barbershopOwner) ...[
                    TextFormField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Barbershop Name',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter barbershop name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _shopAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Street Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter shop address' : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            _isSignUp
                                ? (_selectedRole == UserRole.barbershopOwner
                                    ? 'Register My Barbershop'
                                    : 'Create Customer Account')
                                : 'Sign In',
                          ),
                  ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      // Quick demo login bypass
                      AppRepository.instance.switchRole(UserRole.customer);
                    },
                    child: const Text('Or explore demo as Guest Client', style: TextStyle(color: AppTheme.primaryGold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
