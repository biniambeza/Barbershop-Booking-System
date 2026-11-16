import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/core/utils/password_utils.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/features/auth/screens/profile_setup_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations_am.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations_en.dart';
import 'package:barbershop_booking/l10n/labels.dart';
import 'package:barbershop_booking/l10n/locale_controller.dart';
import 'package:barbershop_booking/main.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/email_auth_service.dart';

import 'test_helpers.dart';

Matcher throwsEmailAuth(EmailAuthErrorCode code) =>
    throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', code));

void main() {
  final repo = AppRepository.instance;
  const code = LocalEmailAuthService.demoCode;

  group('password rules', () {
    test('8-128 characters with a letter (any script) and a digit', () {
      expect(isValidPassword('abcdefg1'), true);
      expect(isValidPassword('ሰላምሰላም12'), true);
      expect(isValidPassword('abc1'), false);
      expect(isValidPassword('abcdefgh'), false);
      expect(isValidPassword('12345678'), false);
      expect(isValidPassword('a1${'x' * 127}'), false);
    });

    test('codes are exactly six digits', () {
      expect(normalizeEmailCode(' 123 456 '), '123456');
      expect(normalizeEmailCode('12345'), isNull);
      expect(normalizeEmailCode('12345a'), isNull);
    });
  });

  group('email + password (local mode)', () {
    late DateTime now;

    setUp(() {
      loadTestSeed();
      now = DateTime(2026, 11, 13, 9);
      repo.emailAuthService = LocalEmailAuthService(
        isExistingAccount: (email) => repo.getAllUsers().any((u) => u.email?.toLowerCase() == email),
        clock: () => now,
      );
    });
    tearDown(() => repo.signOut());

    /// Steps 1 + 2: sends a code and verifies it; returns the token.
    Future<String> verifiedRegistration(String email) async {
      await repo.registerRequestCode(email: email);
      final verified = await repo.registerVerifyCode(email: email, code: code);
      return verified.verificationToken;
    }

    test('register in order: email, code, password; ends at profile setup, then logs in again', () async {
      final sent = await repo.registerRequestCode(email: ' New.User@Example.com ');
      expect(sent.resendAfterSeconds, 60);
      final verified = await repo.registerVerifyCode(email: 'new.user@example.com', code: code);
      expect(verified.verificationToken, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(verified.expiresInSeconds, 900);
      expect(repo.authStatus, AuthStatus.signedOut);

      await repo.registerComplete(
        email: 'new.user@example.com',
        verificationToken: verified.verificationToken,
        password: 'secret123',
      );
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingEmail, 'new.user@example.com');

      await repo.completeProfile(name: 'New User', phone: '0911223344');
      expect(repo.currentUser?.role, UserRole.customer);
      expect(repo.currentUser?.email, 'new.user@example.com');

      await repo.signOut();
      await repo.loginWithEmail(email: 'NEW.USER@example.com', password: 'secret123');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.email, 'new.user@example.com');
    });

    test('verification tokens are random and single-use', () async {
      final first = await verifiedRegistration('t1@example.com');
      final second = await verifiedRegistration('t2@example.com');
      expect(first, isNot(second));
      await expectLater(
        repo.registerComplete(email: 't1@example.com', verificationToken: second, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );
      await repo.registerComplete(email: 't1@example.com', verificationToken: first, password: 'secret123');
      await repo.signOut();
      await expectLater(
        repo.registerComplete(email: 't1@example.com', verificationToken: first, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );
    });

    test('a wrong code stops at step 2 with attempts left; the 5th wrong code expires it', () async {
      await repo.registerRequestCode(email: 'a@example.com');
      await expectLater(
        repo.registerVerifyCode(email: 'a@example.com', code: '000000'),
        throwsA(isA<EmailAuthException>()
            .having((e) => e.code, 'code', EmailAuthErrorCode.invalidCode)
            .having((e) => e.attemptsLeft, 'attemptsLeft', 4)),
      );
      // The right code still works after a wrong guess.
      final verified = await repo.registerVerifyCode(email: 'a@example.com', code: code);
      // Verifying again issues a new token; the previous one stops working.
      final again = await repo.registerVerifyCode(email: 'a@example.com', code: code);
      expect(again.verificationToken, isNot(verified.verificationToken));
      await expectLater(
        repo.registerComplete(email: 'a@example.com', verificationToken: verified.verificationToken, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );

      now = now.add(const Duration(seconds: 61));
      await repo.registerRequestCode(email: 'a@example.com');
      for (var left = 4; left >= 1; left--) {
        await expectLater(
          repo.registerVerifyCode(email: 'a@example.com', code: '000000'),
          throwsA(isA<EmailAuthException>().having((e) => e.attemptsLeft, 'attemptsLeft', left)),
        );
      }
      await expectLater(
        repo.registerVerifyCode(email: 'a@example.com', code: '000000'),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
      await expectLater(
        repo.registerVerifyCode(email: 'a@example.com', code: code),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
      expect(repo.authStatus, AuthStatus.signedOut);
    });

    test('a code that was never requested, or is too old, has expired', () async {
      await expectLater(
        repo.registerVerifyCode(email: 'b@example.com', code: code),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
      await repo.registerRequestCode(email: 'b@example.com');
      now = now.add(const Duration(minutes: 11));
      await expectLater(
        repo.registerVerifyCode(email: 'b@example.com', code: code),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
      await expectLater(
        repo.registerVerifyCode(email: 'b@example.com', code: '12'),
        throwsEmailAuth(EmailAuthErrorCode.invalidCode),
      );
    });

    test('a weak password stays on step 3: the token still works afterwards', () async {
      final token = await verifiedRegistration('c@example.com');
      for (final weak in ['short1', 'lettersonly', '1234567890']) {
        await expectLater(
          repo.registerComplete(email: 'c@example.com', verificationToken: token, password: weak),
          throwsEmailAuth(EmailAuthErrorCode.weakPassword),
          reason: weak,
        );
      }
      // The service checks the password too (as the server does).
      final service = LocalEmailAuthService(clock: () => now);
      await service.requestCode(email: 'x@example.com', purpose: EmailCodePurpose.register);
      final verified = await service.verifyCode(email: 'x@example.com', code: code, purpose: EmailCodePurpose.register);
      await expectLater(
        service.completeRegistration(email: 'x@example.com', verificationToken: verified.verificationToken, password: 'weak'),
        throwsEmailAuth(EmailAuthErrorCode.weakPassword),
      );

      await repo.registerComplete(email: 'c@example.com', verificationToken: token, password: 'secret123');
      expect(repo.authStatus, AuthStatus.needsProfile);
    });

    test('verification expires after 15 minutes: back to step 1 for a new code', () async {
      final token = await verifiedRegistration('v@example.com');
      now = now.add(const Duration(minutes: 15, seconds: 1));
      await expectLater(
        repo.registerComplete(email: 'v@example.com', verificationToken: token, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );
      expect(repo.authStatus, AuthStatus.signedOut);

      final fresh = await verifiedRegistration('v@example.com');
      now = now.add(const Duration(minutes: 14));
      await repo.registerComplete(email: 'v@example.com', verificationToken: fresh, password: 'secret123');
      expect(repo.authStatus, AuthStatus.needsProfile);
    });

    test('invalid email and resending too soon', () async {
      await expectLater(
        repo.registerRequestCode(email: 'not-an-email'),
        throwsEmailAuth(EmailAuthErrorCode.invalidEmail),
      );
      await repo.registerRequestCode(email: 'd@example.com');
      now = now.add(const Duration(seconds: 20));
      await expectLater(
        repo.registerRequestCode(email: 'd@example.com'),
        throwsA(isA<EmailAuthException>()
            .having((e) => e.code, 'code', EmailAuthErrorCode.tooSoon)
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 40)),
      );
      now = now.add(const Duration(seconds: 41));
      await repo.registerRequestCode(email: 'd@example.com');
    });

    test('an email that already has an account cannot register again', () async {
      final admin = repo.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
      await expectLater(
        repo.registerRequestCode(email: admin.email!),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );
      // The code step checks this before the code itself.
      await expectLater(
        repo.registerVerifyCode(email: admin.email!, code: '000000'),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );
      final token = await verifiedRegistration('e@example.com');
      await repo.registerComplete(email: 'e@example.com', verificationToken: token, password: 'secret123');
      await repo.signOut();
      await expectLater(
        repo.registerRequestCode(email: 'E@example.com'),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );
    });

    test('wrong password and unknown email give the same error', () async {
      final barber = repo.getAllUsers().firstWhere((u) => u.role == UserRole.barber);
      await expectLater(
        repo.loginWithEmail(email: barber.email!, password: 'wrong1234'),
        throwsEmailAuth(EmailAuthErrorCode.wrongCredentials),
      );
      await expectLater(
        repo.loginWithEmail(email: 'nobody@example.com', password: 'demo1234'),
        throwsEmailAuth(EmailAuthErrorCode.wrongCredentials),
      );
      expect(repo.authStatus, AuthStatus.signedOut);

      // Seeded demo accounts use the demo password.
      await repo.loginWithEmail(email: barber.email!, password: LocalEmailAuthService.demoPassword);
      expect(repo.currentUser?.uid, barber.uid);
    });

    test('forgot password in order: email, code, new password, then log in', () async {
      final token = await verifiedRegistration('f@example.com');
      await repo.registerComplete(email: 'f@example.com', verificationToken: token, password: 'oldpass12');
      await repo.completeProfile(name: 'F', phone: '0911000111');
      await repo.signOut();

      // Unknown emails also "succeed" (no account enumeration), even at the
      // code step; only the last step fails, like an expired verification.
      await repo.resetRequestCode(email: 'ghost@example.com');
      final ghost = await repo.resetVerifyCode(email: 'ghost@example.com', code: code);
      await expectLater(
        repo.resetComplete(email: 'ghost@example.com', verificationToken: ghost.verificationToken, newPassword: 'newpass12'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );

      await repo.resetRequestCode(email: 'f@example.com', language: 'am');
      await expectLater(
        repo.resetVerifyCode(email: 'f@example.com', code: '111111'),
        throwsA(isA<EmailAuthException>()
            .having((e) => e.code, 'code', EmailAuthErrorCode.invalidCode)
            .having((e) => e.attemptsLeft, 'attemptsLeft', 4)),
      );
      final verified = await repo.resetVerifyCode(email: 'f@example.com', code: code);

      // An unknown token is rejected.
      await expectLater(
        repo.resetComplete(email: 'f@example.com', verificationToken: 'nope', newPassword: 'newpass12'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );
      await expectLater(
        repo.resetComplete(email: 'f@example.com', verificationToken: verified.verificationToken, newPassword: 'weak'),
        throwsEmailAuth(EmailAuthErrorCode.weakPassword),
      );
      await repo.resetComplete(
        email: 'f@example.com',
        verificationToken: verified.verificationToken,
        newPassword: 'newpass12',
      );
      expect(repo.authStatus, AuthStatus.signedOut);

      await expectLater(
        repo.loginWithEmail(email: 'f@example.com', password: 'oldpass12'),
        throwsEmailAuth(EmailAuthErrorCode.wrongCredentials),
      );
      await repo.loginWithEmail(email: 'f@example.com', password: 'newpass12');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.email, 'f@example.com');
    });

    test('forgot password: an expired verification needs a new code', () async {
      final barber = repo.getAllUsers().firstWhere((u) => u.role == UserRole.barber);
      await repo.resetRequestCode(email: barber.email!);
      final verified = await repo.resetVerifyCode(email: barber.email!, code: code);
      now = now.add(const Duration(minutes: 16));
      await expectLater(
        repo.resetComplete(email: barber.email!, verificationToken: verified.verificationToken, newPassword: 'newpass12'),
        throwsEmailAuth(EmailAuthErrorCode.verificationExpired),
      );
      await repo.loginWithEmail(email: barber.email!, password: LocalEmailAuthService.demoPassword);
      expect(repo.currentUser?.uid, barber.uid);
    });

    test('an email invite applies to an email/password account', () async {
      await repo.addBarber(shopId: 'shop_1', name: 'Meron Ayele', title: 'Stylist', email: 'Meron.Ayele@Example.com');
      final token = await verifiedRegistration('meron.ayele@example.com');
      await repo.registerComplete(email: 'meron.ayele@example.com', verificationToken: token, password: 'secret123');
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingInvite?.role, UserRole.barber);

      await repo.completeProfile(name: 'Meron Ayele', phone: '0922334455');
      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.currentUser?.shopId, 'shop_1');
      expect(repo.getPendingInvites().any((i) => i.email == 'meron.ayele@example.com'), false);
    });
  });

  group('error mapping and text', () {
    final en = AppLocalizationsEn();
    final am = AppLocalizationsAm();

    EmailAuthException fn(String code, [Map<String, Object?>? details]) =>
        emailAuthExceptionFrom(FirebaseFunctionsException(message: 'x', code: 'invalid-argument', details: details));

    test('server codes from callable details', () {
      expect(fn('', {'code': 'invalid-code', 'attemptsLeft': 2}).attemptsLeft, 2);
      expect(fn('', {'code': 'too-soon', 'retryAfterSeconds': 30}).retryAfterSeconds, 30);
      expect(fn('', {'code': 'rate-limited', 'retryAfterSeconds': 600}).code, EmailAuthErrorCode.rateLimited);
      expect(fn('', {'code': 'email-send-failed'}).code, EmailAuthErrorCode.emailSendFailed);
      expect(fn('', {'code': 'invalid-input'}).code, EmailAuthErrorCode.invalidInput);
      expect(fn('', {'code': 'email-not-configured'}).code, EmailAuthErrorCode.emailNotConfigured);
      expect(fn('', {'code': 'verification-expired'}).code, EmailAuthErrorCode.verificationExpired);
      expect(fn('', {'code': 'invalid-input', 'field': 'password'}).code, EmailAuthErrorCode.weakPassword);
      expect(fn('', {'code': 'invalid-input', 'field': 'newPassword'}).code, EmailAuthErrorCode.weakPassword);
      expect(fn('', {'code': 'invalid-input', 'field': 'verificationToken'}).code, EmailAuthErrorCode.invalidInput);
      expect(fn('', {'code': 'email-already-registered'}).code, EmailAuthErrorCode.emailAlreadyRegistered);
      for (final c in ['internal', 'unavailable', 'not-found']) {
        expect(
          emailAuthExceptionFrom(FirebaseFunctionsException(message: 'x', code: c)).code,
          EmailAuthErrorCode.serviceUnavailable,
          reason: c,
        );
      }
    });

    test('Firebase Auth codes', () {
      EmailAuthErrorCode auth(String c) => emailAuthExceptionFrom(FirebaseAuthException(code: c)).code;
      for (final c in ['wrong-password', 'invalid-credential', 'user-not-found']) {
        expect(auth(c), EmailAuthErrorCode.wrongCredentials, reason: c);
      }
      expect(auth('too-many-requests'), EmailAuthErrorCode.tooManyRequests);
      expect(auth('user-disabled'), EmailAuthErrorCode.userDisabled);
      expect(auth('network-request-failed'), EmailAuthErrorCode.network);
      expect(auth('operation-not-allowed'), EmailAuthErrorCode.notEnabled);
    });

    test('localized in English and Amharic', () {
      expect(en.authError(const EmailAuthException(EmailAuthErrorCode.wrongCredentials)), 'Wrong email or password.');
      expect(en.authError(const EmailAuthException(EmailAuthErrorCode.notEnabled)), 'Email sign-in is not enabled yet.');
      expect(
        en.authError(const EmailAuthException(EmailAuthErrorCode.invalidCode, attemptsLeft: 3)),
        'That code is not correct. Attempts left: 3.',
      );
      expect(
        en.authError(const EmailAuthException(EmailAuthErrorCode.rateLimited, retryAfterSeconds: 90)),
        'Too many attempts. Try again in 2 min.',
      );
      expect(
        en.authError(const EmailAuthException(EmailAuthErrorCode.verificationExpired)),
        'This step took too long. Please request a new code.',
      );
      for (final c in EmailAuthErrorCode.values) {
        final e = EmailAuthException(c);
        expect(am.authError(e), isNotEmpty);
        if (c != EmailAuthErrorCode.unknown && c != EmailAuthErrorCode.invalidEmail) {
          expect(am.authError(e), isNot(en.authError(e)), reason: c.name);
        }
      }
    });
  });

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpAuthScreen(WidgetTester tester) async {
    loadTestSeed();
    final previous = LocaleController.instance;
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'));
    addTearDown(() => LocaleController.instance = previous);
    await tester.pumpWidget(const BarbershopApp(showIntro: false));
  }

  testWidgets('Auth screen: register shows email, then code, then password, then profile setup', (tester) async {
    await pumpAuthScreen(tester);
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-tab-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-tab-register')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('No SMS'), findsNothing);

    // Step 1: email only.
    await tap('auth-tab-register');
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.byKey(const ValueKey('register-send-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('register-password')), findsNothing);
    expect(find.byKey(const ValueKey('register-code')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('register-email')), 'Tsion@Example.com');
    await tap('register-send-code');

    // Step 2: the code; no password fields yet.
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Enter the 6-digit code we sent to tsion@example.com'), findsOneWidget);
    expect(find.text('Resend code in 60 s'), findsOneWidget);
    expect(find.byKey(const ValueKey('register-change-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('register-password')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('register-code')), '000000');
    await tap('register-verify');
    expect(find.text('That code is not correct. Attempts left: 4.'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('register-password')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('register-code')), code);
    await tap('register-verify');

    // Step 3: password + confirm.
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Create your password'), findsOneWidget);
    expect(find.text('At least 8 characters, with a letter and a number'), findsOneWidget);
    expect(find.byKey(const ValueKey('register-code')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('register-password')), 'weakpass');
    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'weakpass');
    await tap('register-create');
    expect(find.text('Use 8 to 128 characters with at least one letter and one number.'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('register-password')), 'secret123');
    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret124');
    await tap('register-create');
    expect(find.text('The passwords do not match.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret123');
    await tap('register-create');
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('tsion@example.com'), findsOneWidget);

    await AppRepository.instance.signOut();
    await tester.pumpAndSettle();
  });

  testWidgets('Auth screen: an existing email offers "Log in instead" with the email prefilled', (tester) async {
    await pumpAuthScreen(tester);
    final admin = AppRepository.instance.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    await tap('auth-tab-register');
    await tester.enterText(find.byKey(const ValueKey('register-email')), admin.email!);
    await tap('register-send-code');
    expect(find.text('An account with this email already exists. Log in instead.'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);

    await tap('register-login-instead');
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.text(admin.email!.toLowerCase()), findsOneWidget);
  });

  testWidgets('Auth screen: an expired verification returns to step 1 with the email kept', (tester) async {
    await pumpAuthScreen(tester);
    var now = DateTime.now();
    AppRepository.instance.emailAuthService = LocalEmailAuthService(
      isExistingAccount: (email) => AppRepository.instance.getAllUsers().any((u) => u.email?.toLowerCase() == email),
      clock: () => now,
    );
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    await tap('auth-tab-register');
    await tester.enterText(find.byKey(const ValueKey('register-email')), 'late@example.com');
    await tap('register-send-code');
    await tester.enterText(find.byKey(const ValueKey('register-code')), code);
    await tap('register-verify');
    expect(find.text('Step 3 of 3'), findsOneWidget);

    now = now.add(const Duration(minutes: 20));
    await tester.enterText(find.byKey(const ValueKey('register-password')), 'secret123');
    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret123');
    await tap('register-create');

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('This step took too long. Please request a new code.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.descendant(of: find.byKey(const ValueKey('register-email')), matching: find.byType(TextField))).controller?.text,
      'late@example.com',
    );
    expect(AppRepository.instance.authStatus, AuthStatus.signedOut);
  });

  testWidgets('Auth screen: forgot password in order, then back to log in with the email prefilled', (tester) async {
    await pumpAuthScreen(tester);
    final barber = AppRepository.instance.getAllUsers().firstWhere((u) => u.role == UserRole.barber);
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-password')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('reset-email')), barber.email!);
    await tap('reset-send-code');

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-password')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('reset-code')), code);
    await tap('reset-verify');

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Choose a new password'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('reset-password')), 'newpass12');
    await tester.enterText(find.byKey(const ValueKey('reset-confirm')), 'newpass12');
    await tap('reset-submit');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.text('Your password has been changed. Log in with your new password.'), findsOneWidget);
    expect(find.text(barber.email!), findsOneWidget);

    await AppRepository.instance.loginWithEmail(email: barber.email!, password: 'newpass12');
    expect(AppRepository.instance.currentUser?.uid, barber.uid);
    await AppRepository.instance.signOut();
    await tester.pumpAndSettle();
  });
}
