import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
import 'l10n/l10n.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'services/app_repository.dart';
import 'services/app_check_setup.dart';
import 'services/crash_reporting.dart';
import 'services/notification_service.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/payments/payment_flow.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/customer/screens/customer_main_nav.dart';
import 'features/shop_owner/screens/owner_dashboard_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/barber/screens/barber_dashboard_screen.dart';
import 'features/auth/screens/force_password_change_screen.dart'; // barber accounts
import 'features/splash/animated_splash.dart'; // start-up intro

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
      // App Check (tokens only, not enforced) before the first Firebase
      // request, then Crashlytics (release builds only). Neither throws.
      await setupAppCheck();
      await setupCrashReporting();
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
  // Light / dark / system mode picked on this device (default: system).
  await ThemeController.instance.loadSaved();

  runApp(BarbershopApp(firebaseError: firebaseError));
}

class BarbershopApp extends StatelessWidget {
  const BarbershopApp({super.key, this.firebaseError, this.showIntro = true});

  /// Set when Firebase could not be initialized in a production build.
  final String? firebaseError;

  /// Plays the animated start-up intro over the app (cold start). Tests that
  /// drive the app pass false.
  final bool showIntro;

  /// The app can be shown once the saved session has been restored.
  bool _appReady() =>
      firebaseError != null || AppRepository.instance.authStatus != AuthStatus.initializing;

  @override
  Widget build(BuildContext context) {
    final localeController = LocaleController.instance;
    final themeController = ThemeController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([localeController, themeController]),
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        navigatorKey: NotificationService.navigatorKey,
        scaffoldMessengerKey: NotificationService.messengerKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.mode,
        locale: localeController.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // The intro sits above the navigator: it plays once per app start
        // while the app builds underneath, and never on sign-in / sign-out.
        // ThemeRebuilder repaints AppTheme.xxx colours when light / dark
        // changes.
        builder: (context, child) => ThemeRebuilder(child: AnimatedSplash(
          enabled: showIntro,
          isReady: _appReady,
          readiness: AppRepository.instance,
          child: child ?? const SizedBox.shrink(),
        )),
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
            // The finished intro picture (white, or near-black in dark
            // mode): no blank flash while the session is restored.
            return const StartupHoldScreen();
          case AuthStatus.signedOut:
            return const AuthScreen();
          case AuthStatus.needsProfile:
            return const ProfileSetupScreen();
          case AuthStatus.signedIn:
            break;
        }

        final user = repo.currentUser;
        if (user == null) return const AuthScreen();
        // Barber accounts: the owner's temporary password is replaced first.
        if (repo.mustChangePassword) return const ForcePasswordChangeScreen();

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
                Icon(Icons.cloud_off, size: 48, color: AppTheme.ink),
                const SizedBox(height: 16),
                Text(
                  context.l10n.serviceUnavailable,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.serviceUnavailableBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
