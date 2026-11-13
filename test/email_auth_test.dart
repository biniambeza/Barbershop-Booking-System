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

    test('register happy path ends at profile setup, then logs in again', () async {
      final sent = await repo.registerRequestCode(email: ' New.User@Example.com ', password: 'secret123');
      expect(sent.resendAfterSeconds, 60);
      await repo.registerComplete(email: 'new.user@example.com', code: code, password: 'secret123');
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

    test('a wrong code reports attempts left; the 5th wrong code expires it', () async {
      await repo.registerRequestCode(email: 'a@example.com', password: 'secret123');
      await expectLater(
        repo.registerComplete(email: 'a@example.com', code: '000000', password: 'secret123'),
        throwsA(isA<EmailAuthException>()
            .having((e) => e.code, 'code', EmailAuthErrorCode.invalidCode)
            .having((e) => e.attemptsLeft, 'attemptsLeft', 4)),
      );
      for (var i = 0; i < 3; i++) {
        await expectLater(
          repo.registerComplete(email: 'a@example.com', code: '000000', password: 'secret123'),
          throwsEmailAuth(EmailAuthErrorCode.invalidCode),
        );
      }
      await expectLater(
        repo.registerComplete(email: 'a@example.com', code: '000000', password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
      expect(repo.authStatus, AuthStatus.signedOut);
    });

    test('a code that was never requested, or is too old, has expired', () async {
      await expectLater(
        repo.registerComplete(email: 'b@example.com', code: code, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
      await repo.registerRequestCode(email: 'b@example.com', password: 'secret123');
      now = now.add(const Duration(minutes: 11));
      await expectLater(
        repo.registerComplete(email: 'b@example.com', code: code, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );
    });

    test('weak passwords are rejected before sending or checking a code', () async {
      for (final weak in ['short1', 'lettersonly', '1234567890']) {
        await expectLater(
          repo.registerRequestCode(email: 'c@example.com', password: weak),
          throwsEmailAuth(EmailAuthErrorCode.weakPassword),
          reason: weak,
        );
      }
      await expectLater(
        repo.registerComplete(email: 'c@example.com', code: 'xx', password: 'weak'),
        throwsEmailAuth(EmailAuthErrorCode.weakPassword),
      );
    });

    test('invalid email and resending too soon', () async {
      await expectLater(
        repo.registerRequestCode(email: 'not-an-email', password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.invalidEmail),
      );
      await repo.registerRequestCode(email: 'd@example.com', password: 'secret123');
      now = now.add(const Duration(seconds: 20));
      await expectLater(
        repo.registerRequestCode(email: 'd@example.com', password: 'secret123'),
        throwsA(isA<EmailAuthException>()
            .having((e) => e.code, 'code', EmailAuthErrorCode.tooSoon)
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 40)),
      );
      now = now.add(const Duration(seconds: 41));
      await repo.registerRequestCode(email: 'd@example.com', password: 'secret123');
    });

    test('an email that already has an account cannot register again', () async {
      final admin = repo.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
      await expectLater(
        repo.registerRequestCode(email: admin.email!, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );
      await repo.registerRequestCode(email: 'e@example.com', password: 'secret123');
      await repo.registerComplete(email: 'e@example.com', code: code, password: 'secret123');
      await repo.signOut();
      await expectLater(
        repo.registerRequestCode(email: 'E@example.com', password: 'secret123'),
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

    test('forgot password: reset code, new password, then log in', () async {
      await repo.registerRequestCode(email: 'f@example.com', password: 'oldpass12');
      await repo.registerComplete(email: 'f@example.com', code: code, password: 'oldpass12');
      await repo.completeProfile(name: 'F', phone: '0911000111');
      await repo.signOut();

      // Unknown emails also "succeed" (no account enumeration).
      await repo.resetRequestCode(email: 'ghost@example.com');
      await expectLater(
        repo.resetComplete(email: 'ghost@example.com', code: code, newPassword: 'newpass12'),
        throwsEmailAuth(EmailAuthErrorCode.codeExpired),
      );

      await repo.resetRequestCode(email: 'f@example.com', language: 'am');
      await expectLater(
        repo.resetComplete(email: 'f@example.com', code: code, newPassword: 'weak'),
        throwsEmailAuth(EmailAuthErrorCode.weakPassword),
      );
      await expectLater(
        repo.resetComplete(email: 'f@example.com', code: '111111', newPassword: 'newpass12'),
        throwsEmailAuth(EmailAuthErrorCode.invalidCode),
      );
      await repo.resetComplete(email: 'f@example.com', code: code, newPassword: 'newpass12');
      expect(repo.authStatus, AuthStatus.signedOut);

      await expectLater(
        repo.loginWithEmail(email: 'f@example.com', password: 'oldpass12'),
        throwsEmailAuth(EmailAuthErrorCode.wrongCredentials),
      );
      await repo.loginWithEmail(email: 'f@example.com', password: 'newpass12');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.email, 'f@example.com');
    });

    test('an email invite applies to an email/password account', () async {
      await repo.addBarber(shopId: 'shop_1', name: 'Meron Ayele', title: 'Stylist', email: 'Meron.Ayele@Example.com');
      await repo.registerRequestCode(email: 'meron.ayele@example.com', password: 'secret123');
      await repo.registerComplete(email: 'meron.ayele@example.com', code: code, password: 'secret123');
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
      for (final c in EmailAuthErrorCode.values) {
        final e = EmailAuthException(c);
        expect(am.authError(e), isNotEmpty);
        if (c != EmailAuthErrorCode.unknown && c != EmailAuthErrorCode.invalidEmail) {
          expect(am.authError(e), isNot(en.authError(e)), reason: c.name);
        }
      }
    });
  });

  testWidgets('Auth screen: Log in / Register tabs, Google button, register to profile setup', (tester) async {
    loadTestSeed();
    final previous = LocaleController.instance;
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'));
    addTearDown(() => LocaleController.instance = previous);
    await tester.pumpWidget(const BarbershopApp());

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-tab-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-tab-register')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('No SMS'), findsNothing);

    Future<void> tap(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tap(const ValueKey('auth-tab-register'));
    expect(find.byKey(const ValueKey('register-send-code')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('register-email')), 'Tsion@Example.com');
    await tester.enterText(find.byKey(const ValueKey('register-password')), 'secret123');
    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret124');
    await tap(const ValueKey('register-send-code'));
    expect(find.text('The passwords do not match.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret123');
    await tap(const ValueKey('register-send-code'));
    expect(find.text('We sent a 6-digit code to tsion@example.com'), findsOneWidget);
    expect(find.text('Resend code in 60 s'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('register-code')), code);
    await tap(const ValueKey('register-verify'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('tsion@example.com'), findsOneWidget);

    await AppRepository.instance.signOut();
    await tester.pumpAndSettle();
  });
}
