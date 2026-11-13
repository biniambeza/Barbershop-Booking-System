import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
import 'l10n/l10n.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/app_repository.dart';
import 'services/notification_service.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/payments/payment_flow.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/customer/screens/customer_main_nav.dart';
import 'features/shop_owner/screens/owner_dashboard_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/barber/screens/barber_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Date symbols for every locale (Amharic month/day names).
  ensureDateFormattingData();

  String? firebaseError;
  if (kDemoMode) {
    // Offline demo: the bundled Addis Ababa dataset (assets/seed/addis_seed.json).
    await AppRepository.instance.loadDemoData();
  } else {
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

  if (firebaseError == null) {
    // Inbox, unread badge, banners and (with Firebase) FCM registration.
    NotificationService.inboxRouteBuilder = (_) => const NotificationsScreen();
    NotificationService.instance.start();
    // Web: Chapa returns to PAYMENT_RETURN_URL?paymentId=... - verify it.
    PaymentReturnHandler.start(uri: Uri.base, navigatorKey: NotificationService.navigatorKey);
  }

  // App language: the choice saved on this device (or the device language),
  // then the signed-in user's users/{uid}.language.
  await LocaleController.instance.loadSaved();
  LocaleController.instance.start();

  runApp(BarbershopApp(firebaseError: firebaseError));
}

class BarbershopApp extends StatelessWidget {
  const BarbershopApp({super.key, this.firebaseError});

  /// Set when Firebase could not be initialized in a production build.
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    final localeController = LocaleController.instance;
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        navigatorKey: NotificationService.navigatorKey,
        scaffoldMessengerKey: NotificationService.messengerKey,
        theme: AppTheme.darkTheme,
        locale: localeController.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: firebaseError != null ? _FirebaseSetupRequired(error: firebaseError!) : const RootGate(),
      ),
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
                Text(
                  context.l10n.serviceUnavailable,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.serviceUnavailableBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
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
