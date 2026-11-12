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
  final _nameController = TextEditingController(text: 'Alex Johnson');
  final _emailController = TextEditingController(text: 'alex@example.com');
  final _passwordController = TextEditingController(text: 'password123');

  // Shop Owner fields
  final _shopNameController = TextEditingController(text: 'Crown & Razor Lounge');
  final _shopAddressController = TextEditingController(text: '350 5th Ave');
  final _shopCityController = TextEditingController(text: 'New York, NY');

  // Barber fields
  final _barberTitleController = TextEditingController(text: 'Master Barber / Fade Specialist');
  String? _selectedAssignedShopId;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopCityController.dispose();
    _barberTitleController.dispose();
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
          shopCity: _selectedRole == UserRole.barbershopOwner ? _shopCityController.text.trim() : null,
          assignedShopId: _selectedRole == UserRole.barber ? _selectedAssignedShopId : null,
          barberTitle: _selectedRole == UserRole.barber ? _barberTitleController.text.trim() : null,
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
    final repo = AppRepository.instance;
    final allShops = repo.getShops();

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
                    size: 58,
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
                        ? 'Multi-Tenant Barbershop SaaS Platform'
                        : 'Sign in to access your role workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

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
                            onTap: () => setState(() {
                              _isSignUp = false;
                              _emailController.text = 'alex@example.com';
                            }),
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
                            onTap: () => setState(() {
                              _isSignUp = true;
                              _nameController.text = 'Jordan Lee';
                              _emailController.text = 'jordan@example.com';
                            }),
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
                      'I want to join as:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            selected: _selectedRole == UserRole.customer,
                            selectedColor: AppTheme.primaryGold,
                            onSelected: (val) {
                              if (val) setState(() => _selectedRole = UserRole.customer);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('Barber', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            selected: _selectedRole == UserRole.barber,
                            selectedColor: AppTheme.primaryGold,
                            onSelected: (val) {
                              if (val) setState(() => _selectedRole = UserRole.barber);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('Shop Owner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

                  // Additional fields for Staff Barber
                  if (_isSignUp && _selectedRole == UserRole.barber) ...[
                    TextFormField(
                      controller: _barberTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Professional Title',
                        prefixIcon: Icon(Icons.badge_outlined),
                        hintText: 'e.g. Master Fade Specialist',
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter your barber title' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAssignedShopId ?? (allShops.isNotEmpty ? allShops.first.id : null),
                      decoration: const InputDecoration(
                        labelText: 'Assigned Barbershop',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      items: allShops.map((shop) {
                        return DropdownMenuItem(
                          value: shop.id,
                          child: Text('${shop.name} (${shop.city})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAssignedShopId = val),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                        labelText: 'Street Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter shop address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _shopCityController,
                      decoration: const InputDecoration(
                        labelText: 'City & State',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter city & state' : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 8),
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
                                    : (_selectedRole == UserRole.barber
                                        ? 'Register as Barber'
                                        : 'Create Customer Account'))
                                : 'Sign In',
                          ),
                  ),

                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'ONE-TAP ROLE DEMO ACCESS',
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

                  // 4 Roles Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildPersonaButton(
                          roleName: 'Admin',
                          subtitle: 'SaaS Platform',
                          icon: Icons.admin_panel_settings,
                          color: Colors.purpleAccent,
                          onTap: () => repo.switchRole(UserRole.admin),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPersonaButton(
                          roleName: 'Shop Owner',
                          subtitle: "Gentleman's Quarter",
                          icon: Icons.storefront,
                          color: AppTheme.primaryGold,
                          onTap: () => repo.switchRole(UserRole.barbershopOwner),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPersonaButton(
                          roleName: 'Barber',
                          subtitle: 'Marcus Vance',
                          icon: Icons.content_cut,
                          color: Colors.tealAccent,
                          onTap: () => repo.switchRole(UserRole.barber),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPersonaButton(
                          roleName: 'Customer',
                          subtitle: 'Alex Johnson',
                          icon: Icons.person,
                          color: Colors.lightBlueAccent,
                          onTap: () => repo.switchRole(UserRole.customer),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonaButton({
    required String roleName,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            roleName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
