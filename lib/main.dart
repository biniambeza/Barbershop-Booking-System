import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/app_repository.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/customer/screens/customer_main_nav.dart';
import 'features/shop_owner/screens/owner_dashboard_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/barber/screens/barber_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseError;
  if (!kDemoMode) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      AppRepository.instance.attachFirebase();
    } catch (e) {
      // Never fall back to the offline demo in a production build: that
      // would bring back the unauthenticated demo logins.
      debugPrint('Firebase initialization failed: $e');
      firebaseError = e.toString();
    }
  }

  runApp(BarbershopApp(firebaseError: firebaseError));
}

class BarbershopApp extends StatelessWidget {
  const BarbershopApp({super.key, this.firebaseError});

  /// Set when Firebase could not be initialized in a production build.
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crown & Blade - Barbershop Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: firebaseError != null ? _FirebaseSetupRequired(error: firebaseError!) : const RootGate(),
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
        switch (repo.authStatus) {
          case AuthStatus.initializing:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
            );
          case AuthStatus.signedOut:
            return const AuthScreen();
          case AuthStatus.needsProfile:
            return const ProfileSetupScreen();
          case AuthStatus.signedIn:
            break;
        }

        final user = repo.currentUser;
        if (user == null) return const AuthScreen();

        switch (user.role) {
          case UserRole.admin:
            return const AdminDashboardScreen();
          case UserRole.barbershopOwner:
            return const OwnerDashboardScreen();
          case UserRole.barber:
            return const BarberDashboardScreen();
          case UserRole.customer:
            return const CustomerMainNav();
        }
      },
    );
  }
}

class _FirebaseSetupRequired extends StatelessWidget {
  const _FirebaseSetupRequired({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: AppTheme.primaryGold),
                const SizedBox(height: 16),
                const Text(
                  'Service unavailable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app could not connect to its server. Please try again later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
