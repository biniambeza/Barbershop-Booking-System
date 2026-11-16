import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

// ---------------------------------------------------------------------------
// Fakes for FirebaseEmailAuthService (no network, no Firebase app).
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  _FakeUser(this.email, {this.failSend = false});

  @override
  final String email;

  bool verified = false;
  bool failSend;
  int verificationsSent = 0;

  @override
  bool get emailVerified => verified;

  @override
  String get uid => 'uid-$email';

  @override
  String? get displayName => null;

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? actionCodeSettings]) async {
    if (failSend) throw FirebaseAuthException(code: 'too-many-requests');
    verificationsSent++;
  }
}

class _FakeCredential extends Fake implements UserCredential {
  _FakeCredential(this.user);

  @override
  final User? user;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  final Map<String, (String, _FakeUser)> accounts = {};
  _FakeUser? _current;
  String? language;
  final List<String> resetEmails = [];
  int signOuts = 0;
  String? resetErrorCode;
  bool reachable = true;
  bool failVerificationSend = false;

  _FakeUser addAccount(String email, String password, {bool verified = true}) {
    final user = _FakeUser(email)..verified = verified;
    accounts[email] = (password, user);
    return user;
  }

  @override
  User? get currentUser => _current;

  @override
  Future<void> setLanguageCode(String? languageCode) async => language = languageCode;

  @override
  Future<void> sendPasswordResetEmail({required String email, ActionCodeSettings? actionCodeSettings}) async {
    final error = resetErrorCode;
    if (error != null) throw FirebaseAuthException(code: error);
    if (!accounts.containsKey(email)) throw FirebaseAuthException(code: 'user-not-found');
    resetEmails.add(email);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    if (accounts.containsKey(email)) throw FirebaseAuthException(code: 'email-already-in-use');
    if (password.length < 6) throw FirebaseAuthException(code: 'weak-password');
    final user = _FakeUser(email, failSend: failVerificationSend);
    accounts[email] = (password, user);
    _current = user;
    return _FakeCredential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    final account = accounts[email];
    if (account == null || account.$1 != password) throw FirebaseAuthException(code: 'invalid-credential');
    _current = account.$2;
    return _FakeCredential(account.$2);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    _current = null;
  }

  @override
  Future<ActionCodeInfo> checkActionCode(String code) async =>
      throw FirebaseAuthException(code: reachable ? 'invalid-action-code' : 'network-request-failed');
}

class _FakeCallable extends Fake implements HttpsCallable {
  _FakeCallable(this.functions, this.name);

  final _FakeFunctions functions;
  final String name;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    functions.calls.add(name);
    throw functions.error;
  }
}

/// Every callable fails with [error] (functions not deployed).
class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this.error);

  final Object error;
  final List<String> calls = [];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) => _FakeCallable(this, name);
}

/// Counts requestCode calls (the cached fallback skips them).
class _CountingLocalService extends LocalEmailAuthService {
  _CountingLocalService({super.isExistingAccount, super.functionsAvailable, super.functionsError, super.authReachable});

  int codeRequests = 0;

  @override
  Future<EmailCodeSent> requestCode({
    required String email,
    required EmailCodePurpose purpose,
    String language = 'en',
  }) {
    codeRequests++;
    return super.requestCode(email: email, purpose: purpose, language: language);
  }
}

void main() {
  final repo = AppRepository.instance;

  bool seeded(String email) => repo.getAllUsers().any((u) => u.email?.toLowerCase() == email);

  group('fallback detection', () {
    setUp(loadTestSeed);
    tearDown(() => repo.signOut());

    test('error mapping marks the "functions not deployed" class', () {
      EmailAuthException fn(String code, [Object? details]) =>
          emailAuthExceptionFrom(FirebaseFunctionsException(message: 'x', code: code, details: details));
      for (final c in ['not-found', 'unavailable', 'internal', 'unimplemented']) {
        expect(fn(c).functionsMissing, isTrue, reason: c);
        expect(fn(c).code, EmailAuthErrorCode.serviceUnavailable, reason: c);
      }
      // A server error with its own code is a real failure, not a missing function.
      expect(fn('internal', {'code': 'internal'}).functionsMissing, isFalse);
      expect(fn('internal', {'code': 'internal'}).code, EmailAuthErrorCode.serviceUnavailable);
      expect(fn('failed-precondition', {'code': 'email-send-failed'}).functionsMissing, isFalse);
      expect(fn('deadline-exceeded').functionsMissing, isFalse);
      expect(fn('permission-denied').functionsMissing, isFalse);
      expect(emailAuthExceptionFrom(FirebaseAuthException(code: 'email-already-in-use')).code,
          EmailAuthErrorCode.emailAlreadyRegistered);
    });

    for (final c in ['not-found', 'internal', 'unimplemented']) {
      test('$c switches register and reset to links right away', () async {
        final service = _CountingLocalService(
          isExistingAccount: seeded,
          functionsError: FirebaseFunctionsException(message: 'x', code: c),
          authReachable: false, // not even asked
        );
        repo.emailAuthService = service;
        expect(repo.registerUsesLink, isFalse);
        expect((await repo.registerStart(email: 'new@example.com')).usesLink, isTrue);
        expect(repo.registerUsesLink, isTrue);
        // Per flow: reset has not switched yet.
        expect(repo.resetUsesLink, isFalse);
        expect((await repo.resetStart(email: 'new@example.com')).usesLink, isTrue);
        expect(repo.resetUsesLink, isTrue);
        expect(service.codeRequests, 2);
      });
    }

    test('unavailable and network failures fall back only while Firebase Auth is reachable', () async {
      for (final error in <Object>[
        FirebaseFunctionsException(message: 'x', code: 'unavailable'),
        TimeoutException('callable'),
        FirebaseFunctionsException(message: 'x', code: 'deadline-exceeded'),
      ]) {
        // Offline: the error is shown and nothing is cached.
        final offline = LocalEmailAuthService(isExistingAccount: seeded, functionsError: error, authReachable: false);
        repo.emailAuthService = offline;
        await expectLater(
          repo.registerStart(email: 'new@example.com'),
          throwsA(isA<EmailAuthException>().having(
            (e) => e.code,
            'code',
            isIn([EmailAuthErrorCode.serviceUnavailable, EmailAuthErrorCode.network]),
          )),
          reason: '$error',
        );
        expect(repo.registerUsesLink, isFalse, reason: '$error');

        // Auth answers: the functions are what is missing.
        offline.authReachable = true;
        expect((await repo.registerStart(email: 'new@example.com')).usesLink, isTrue, reason: '$error');
        expect(repo.registerUsesLink, isTrue);
      }
    });

    test('other errors never switch to the fallback', () async {
      repo.emailAuthService = LocalEmailAuthService(
        isExistingAccount: seeded,
        functionsError: FirebaseFunctionsException(message: 'x', code: 'internal', details: {'code': 'internal'}),
      );
      await expectLater(repo.registerStart(email: 'new@example.com'), throwsEmailAuth(EmailAuthErrorCode.serviceUnavailable));
      expect(repo.registerUsesLink, isFalse);

      // Working functions: code-flow errors are shown as before.
      repo.emailAuthService = LocalEmailAuthService(isExistingAccount: seeded);
      await expectLater(repo.registerStart(email: 'not-an-email'), throwsEmailAuth(EmailAuthErrorCode.invalidEmail));
      final admin = repo.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
      await expectLater(repo.registerStart(email: admin.email!), throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered));
      await repo.registerStart(email: 'd@example.com');
      await expectLater(repo.registerStart(email: 'd@example.com'), throwsEmailAuth(EmailAuthErrorCode.tooSoon));
      expect(repo.registerUsesLink, isFalse);
      expect(repo.resetUsesLink, isFalse);
    });

    test('the decision is cached for the session and reset by a new session', () async {
      final service = _CountingLocalService(isExistingAccount: seeded, functionsAvailable: false);
      repo.emailAuthService = service;
      await repo.registerStart(email: 'a@example.com');
      await repo.registerStart(email: 'b@example.com');
      await repo.resetStart(email: 'a@example.com');
      await repo.resetStart(email: 'b@example.com');
      expect(service.codeRequests, 2, reason: 'later attempts go straight to the fallback');

      loadTestSeed(); // like an app restart
      expect(repo.registerUsesLink, isFalse);
      expect(repo.resetUsesLink, isFalse);
    });

    test('code flow unchanged when the functions work', () async {
      final service = _CountingLocalService(isExistingAccount: seeded);
      repo.emailAuthService = service;
      final start = await repo.registerStart(email: 'code@example.com');
      expect(start.usesLink, isFalse);
      expect(start.sent?.resendAfterSeconds, 60);
      final verified = await repo.registerVerifyCode(email: 'code@example.com', code: LocalEmailAuthService.demoCode);
      await repo.registerComplete(
        email: 'code@example.com',
        verificationToken: verified.verificationToken,
        password: 'secret123',
      );
      expect(repo.authStatus, AuthStatus.needsProfile);

      final reset = await repo.resetStart(email: 'code@example.com');
      expect(reset.usesLink, isFalse);
      expect(repo.registerUsesLink || repo.resetUsesLink, isFalse);
      expect(service.sentLinks, isEmpty);
    });

    test('Firebase service: undeployed callables give the link fallback', () async {
      final auth = _FakeAuth();
      final functions = _FakeFunctions(FirebaseFunctionsException(message: 'NOT_FOUND', code: 'not-found'));
      repo.emailAuthService = FirebaseEmailAuthService(auth, functions: functions);
      expect((await repo.registerStart(email: 'New@Example.com')).usesLink, isTrue);
      expect(functions.calls, ['requestEmailCode']);

      // Network-level failure: checks Firebase Auth first.
      final timeouts = _FakeFunctions(TimeoutException('x'));
      repo.emailAuthService = FirebaseEmailAuthService(auth, functions: timeouts);
      auth.reachable = false;
      await expectLater(repo.registerStart(email: 'new@example.com'), throwsEmailAuth(EmailAuthErrorCode.network));
      auth.reachable = true;
      expect((await repo.registerStart(email: 'new@example.com')).usesLink, isTrue);
    });
  });

  group('password reset fallback', () {
    late LocalEmailAuthService service;

    setUp(() {
      loadTestSeed();
      service = LocalEmailAuthService(isExistingAccount: seeded, functionsAvailable: false);
      repo.emailAuthService = service;
    });
    tearDown(() => repo.signOut());

    test('sends the reset link in the app language; unknown emails succeed too', () async {
      final barber = repo.getAllUsers().firstWhere((u) => u.role == UserRole.barber);
      final start = await repo.resetStart(email: barber.email!.toUpperCase(), language: 'am');
      expect(start.usesLink, isTrue);
      expect(service.sentLinks.single.kind, SentAuthLinkKind.passwordReset);
      expect(service.sentLinks.single.email, barber.email!.toLowerCase());
      expect(service.sentLinks.single.language, 'am');

      // No account enumeration: same answer, nothing sent.
      expect((await repo.resetStart(email: 'ghost@example.com')).usesLink, isTrue);
      expect(service.sentLinks, hasLength(1));

      await repo.resetSendLink(email: barber.email!);
      expect(service.sentLinks, hasLength(2));
      await expectLater(repo.resetStart(email: 'nope'), throwsEmailAuth(EmailAuthErrorCode.invalidEmail));
      expect(repo.authStatus, AuthStatus.signedOut);
    });

    test('Firebase service: user-not-found is success; other errors are mapped', () async {
      final auth = _FakeAuth()..addAccount('known@example.com', 'secret123');
      final firebase = FirebaseEmailAuthService(auth, functions: _FakeFunctions(FirebaseFunctionsException(message: 'x', code: 'not-found')));
      repo.emailAuthService = firebase;

      await repo.resetStart(email: 'Known@Example.com', language: 'am');
      expect(auth.resetEmails, ['known@example.com']);
      expect(auth.language, 'am');

      await repo.resetStart(email: 'ghost@example.com'); // user-not-found → success
      expect(auth.resetEmails, ['known@example.com']);
      expect(auth.language, 'en');

      for (final (code, expected) in [
        ('invalid-email', EmailAuthErrorCode.invalidEmail),
        ('too-many-requests', EmailAuthErrorCode.tooManyRequests),
        ('network-request-failed', EmailAuthErrorCode.network),
      ]) {
        auth.resetErrorCode = code;
        await expectLater(repo.resetSendLink(email: 'known@example.com'), throwsEmailAuth(expected), reason: code);
      }
    });
  });

  group('register fallback', () {
    late LocalEmailAuthService service;

    setUp(() {
      loadTestSeed();
      service = LocalEmailAuthService(isExistingAccount: seeded, functionsAvailable: false);
      repo.emailAuthService = service;
    });
    tearDown(() => repo.signOut());

    test('creates the account, sends the verification link and stays signed out', () async {
      expect((await repo.registerStart(email: 'Tsion@Example.com')).usesLink, isTrue);
      await expectLater(
        repo.registerWithLink(email: 'tsion@example.com', password: 'weakpass'),
        throwsEmailAuth(EmailAuthErrorCode.weakPassword),
      );
      final sent = await repo.registerWithLink(email: 'tsion@example.com', password: 'secret123', language: 'am');
      expect(sent, isTrue);
      expect(service.sentLinks.single.kind, SentAuthLinkKind.verification);
      expect(service.sentLinks.single.language, 'am');
      expect(repo.authStatus, AuthStatus.signedOut);

      // Not verified yet: log in explains it; resend works.
      await expectLater(
        repo.loginWithEmail(email: 'tsion@example.com', password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.emailNotVerified),
      );
      expect(repo.authStatus, AuthStatus.signedOut);
      await expectLater(
        repo.resendVerificationLink(email: 'tsion@example.com', password: 'wrong1234'),
        throwsEmailAuth(EmailAuthErrorCode.wrongCredentials),
      );
      expect(await repo.resendVerificationLink(email: 'tsion@example.com', password: 'secret123'), VerificationLinkResult.sent);
      expect(service.sentLinks, hasLength(2));
      expect(repo.authStatus, AuthStatus.signedOut);

      // The link is opened: log in continues to profile setup.
      service.markEmailVerified('tsion@example.com');
      expect(
        await repo.resendVerificationLink(email: 'tsion@example.com', password: 'secret123'),
        VerificationLinkResult.alreadyVerified,
      );
      await repo.loginWithEmail(email: 'tsion@example.com', password: 'secret123');
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingEmail, 'tsion@example.com');
    });

    test('an email that already has an account is refused', () async {
      final admin = repo.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
      await expectLater(
        repo.registerWithLink(email: admin.email!, password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );
      await repo.registerWithLink(email: 'twice@example.com', password: 'secret123');
      await expectLater(
        repo.registerWithLink(email: 'twice@example.com', password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );
    });

    test('Firebase service: create user, send verification, sign out', () async {
      final auth = _FakeAuth();
      repo.emailAuthService = FirebaseEmailAuthService(auth, functions: _FakeFunctions(FirebaseFunctionsException(message: 'x', code: 'not-found')));

      expect(await repo.registerWithLink(email: 'New@Example.com', password: 'secret123', language: 'am'), isTrue);
      final user = auth.accounts['new@example.com']!.$2;
      expect(user.verificationsSent, 1);
      expect(auth.currentUser, isNull);
      expect(auth.signOuts, 1);
      expect(auth.language, 'am');

      await expectLater(
        repo.registerWithLink(email: 'new@example.com', password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.emailAlreadyRegistered),
      );

      // Unverified log in: signed out again with "verify first".
      await expectLater(
        repo.loginWithEmail(email: 'new@example.com', password: 'secret123'),
        throwsEmailAuth(EmailAuthErrorCode.emailNotVerified),
      );
      expect(auth.currentUser, isNull);

      expect(await repo.resendVerificationLink(email: 'new@example.com', password: 'secret123'), VerificationLinkResult.sent);
      expect(user.verificationsSent, 2);
      expect(auth.currentUser, isNull);

      user.verified = true;
      expect(
        await repo.resendVerificationLink(email: 'new@example.com', password: 'secret123'),
        VerificationLinkResult.alreadyVerified,
      );
      expect(auth.currentUser, isNull);
      await expectLater(
        repo.resendVerificationLink(email: 'new@example.com', password: 'wrong123'),
        throwsEmailAuth(EmailAuthErrorCode.wrongCredentials),
      );

      // The link could not be sent: the account exists, still signed out.
      auth.failVerificationSend = true;
      expect(await repo.registerWithLink(email: 'second@example.com', password: 'secret123'), isFalse);
      expect(auth.accounts.containsKey('second@example.com'), isTrue);
      expect(auth.currentUser, isNull);
    });
  });

  test('new strings exist in English and Amharic', () {
    final en = AppLocalizationsEn();
    final am = AppLocalizationsAm();
    expect(en.authError(const EmailAuthException(EmailAuthErrorCode.emailNotVerified)), 'Please verify your email first.');
    expect(am.authError(const EmailAuthException(EmailAuthErrorCode.emailNotVerified)), isNot(en.emailErrNotVerified));
    expect(en.resetLinkSentBody('a@b.co'),
        'We sent a password reset link to a@b.co. Open it, choose a new password, then log in here.');
    expect(en.verifyLinkSentBody('a@b.co'), 'We sent a verification link to a@b.co. Open it, then come back and log in.');
    expect(am.resetLinkSentBody('a@b.co'), contains('a@b.co'));
    expect(am.verifyLinkSentBody('a@b.co'), contains('a@b.co'));
  });

  // -------------------------------------------------------------------------
  // Widgets
  // -------------------------------------------------------------------------

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<LocalEmailAuthService> pumpFallbackAuthScreen(WidgetTester tester) async {
    loadTestSeed();
    final previous = LocaleController.instance;
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'));
    addTearDown(() => LocaleController.instance = previous);
    final service = LocalEmailAuthService(isExistingAccount: seeded, functionsAvailable: false);
    repo.emailAuthService = service;
    await tester.pumpWidget(const BarbershopApp(showIntro: false));
    return service;
  }

  String fieldText(WidgetTester tester, String key) => tester
      .widget<TextField>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField)))
      .controller!
      .text;

  testWidgets('Auth screen (free plan): register with password, verification link, then log in', (tester) async {
    final service = await pumpFallbackAuthScreen(tester);
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    await tap('auth-tab-register');
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('register-email')), 'Tsion@Example.com');
    await tap('register-send-code');

    // Straight to the password: no code step.
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Create your password'), findsOneWidget);
    expect(find.byKey(const ValueKey('register-code')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('register-password')), 'secret123');
    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret124');
    await tap('register-create');
    expect(find.text('The passwords do not match.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret123');
    await tap('register-create');
    expect(
      find.text('We sent a verification link to tsion@example.com. Open it, then come back and log in.'),
      findsOneWidget,
    );
    expect(find.text('Resend link in 60 s'), findsOneWidget);
    expect(service.sentLinks.single.kind, SentAuthLinkKind.verification);
    expect(repo.authStatus, AuthStatus.signedOut);

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Resend link'), findsOneWidget);
    await tap('register-resend-link');
    expect(find.text('We sent a new link to tsion@example.com.'), findsOneWidget);
    expect(service.sentLinks, hasLength(2));

    // "I've verified — Log in" before opening the link.
    await tap('register-verified-login');
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(fieldText(tester, 'login-email'), 'tsion@example.com');
    await tester.enterText(find.byKey(const ValueKey('login-password')), 'secret123');
    await tap('login-submit');
    expect(find.text('Please verify your email first.'), findsOneWidget);
    expect(find.text('Resend verification link'), findsOneWidget);
    await tap('login-resend-verification');
    expect(find.text('We sent a new link to tsion@example.com.'), findsOneWidget);
    expect(find.text('Resend link in 60 s'), findsOneWidget);
    expect(service.sentLinks, hasLength(3));
    expect(repo.authStatus, AuthStatus.signedOut);

    // After opening the link.
    service.markEmailVerified('tsion@example.com');
    await tap('login-submit');
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);

    await repo.signOut();
    await tester.pumpAndSettle();
  });

  testWidgets('Auth screen (free plan): an existing email offers "Log in instead"', (tester) async {
    await pumpFallbackAuthScreen(tester);
    final admin = repo.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    await tap('auth-tab-register');
    await tester.enterText(find.byKey(const ValueKey('register-email')), admin.email!);
    await tap('register-send-code');
    await tester.enterText(find.byKey(const ValueKey('register-password')), 'secret123');
    await tester.enterText(find.byKey(const ValueKey('register-confirm')), 'secret123');
    await tap('register-create');
    expect(find.text('An account with this email already exists. Log in instead.'), findsOneWidget);
    await tap('register-login-instead');
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(fieldText(tester, 'login-email'), admin.email!.toLowerCase());
  });

  testWidgets('Auth screen (free plan): forgot password sends a reset link, resend, back to log in', (tester) async {
    final service = await pumpFallbackAuthScreen(tester);
    final barber = repo.getAllUsers().firstWhere((u) => u.role == UserRole.barber);
    Future<void> tap(String key) => tapKey(tester, ValueKey(key));

    await tap('forgot-password');
    await tester.enterText(find.byKey(const ValueKey('reset-email')), barber.email!);
    await tap('reset-send-code');

    final email = barber.email!.toLowerCase();
    expect(
      find.text('We sent a password reset link to $email. Open it, choose a new password, then log in here.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reset-password')), findsNothing);
    expect(find.text('Resend link in 60 s'), findsOneWidget);
    expect(service.sentLinks.single.kind, SentAuthLinkKind.passwordReset);
    expect(service.sentLinks.single.language, 'en');

    await tester.pump(const Duration(seconds: 61));
    await tap('reset-resend-link');
    expect(find.text('We sent a new link to $email.'), findsOneWidget);
    expect(service.sentLinks, hasLength(2));

    await tap('reset-link-back');
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(fieldText(tester, 'login-email'), email);

    // Cached: the next reset says "Send link" from the start.
    await tap('forgot-password');
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Send link'), findsOneWidget);
  });
}
