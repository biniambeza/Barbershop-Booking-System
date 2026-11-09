import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'models/user_model.dart';
import 'services/app_repository.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/customer/screens/customer_main_nav.dart';
import 'features/shop_owner/screens/owner_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e (App running with full repository fallback)');
  }
  runApp(const BarbershopApp());
}

class BarbershopApp extends StatelessWidget {
  const BarbershopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crown & Blade - Barbershop Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RootGate(),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final user = repo.currentUser;
        if (user == null) {
          return const AuthScreen();
        }

        if (user.role == UserRole.barbershopOwner) {
          return const OwnerDashboardScreen();
        }

        return const CustomerMainNav();
      },
    );
  }
}
