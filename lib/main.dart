import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'models/user_model.dart';
import 'services/app_repository.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/customer/screens/customer_main_nav.dart';
import 'features/shop_owner/screens/owner_dashboard_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/barber/screens/barber_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard Firebase initialization:
  // On Flutter Web (and platforms without DefaultFirebaseOptions configured),
  // calling Firebase.initializeApp() without FirebaseOptions can hang indefinitely
  // or throw uncaught JS errors, preventing runApp() from executing and causing a blank screen.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Firebase initialization notice: $e (App running with full repository fallback)');
    }
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

        if (user.role == UserRole.admin) {
          return const AdminDashboardScreen();
        }

        if (user.role == UserRole.barbershopOwner) {
          return const OwnerDashboardScreen();
        }

        if (user.role == UserRole.barber) {
          return const BarberDashboardScreen();
        }

        return const CustomerMainNav();
      },
    );
  }
}
