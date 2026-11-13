import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/core/utils/email_utils.dart';
import 'package:barbershop_booking/core/utils/phone_utils.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/features/auth/screens/profile_setup_screen.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations_am.dart';
import 'package:barbershop_booking/l10n/gen/app_localizations_en.dart';
import 'package:barbershop_booking/l10n/labels.dart';
import 'package:barbershop_booking/l10n/locale_controller.dart';
import 'package:barbershop_booking/main.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/google_auth_service.dart';

import 'test_helpers.dart';

void main() {
  group('normalizeEthiopianPhone', () {
    test('accepts common Ethiopian mobile formats', () {
      for (final input in [
        '0911223344',
        '911223344',
        '+251911223344',
        '251911223344',
        '00251911223344',
        '+251 91 122 3344',
        '091-122-3344',
      ]) {
        expect(normalizeEthiopianPhone(input), '+251911223344', reason: input);
      }
      expect(normalizeEthiopianPhone('0711223344'), '+251711223344');
    });

    test('rejects invalid numbers', () {
      for (final input in ['', '0811223344', '091122334', '09112233445', '+1 212 555 0100', 'abc']) {
        expect(normalizeEthiopianPhone(input), isNull, reason: input);
      }
    });

    test('formats for display', () {
      expect(formatEthiopianPhone('+251911223344'), '+251 91 122 3344');
    });
  });

  group('validEmailOrNull', () {
    test('lowercases and trims valid addresses', () {
      expect(validEmailOrNull('  Abebe.K@Gmail.COM '), 'abebe.k@gmail.com');
      expect(validEmailOrNull('a+tag@shop.com.et'), 'a+tag@shop.com.et');
    });

    test('rejects invalid addresses', () {
      for (final input in [null, '', 'abc', 'a@b', '@gmail.com', 'a b@gmail.com', 'a@gmail.']) {
        expect(validEmailOrNull(input), isNull, reason: '$input');
      }
    });
  });

  group('Google sign-in (local mode)', () {
    final repo = AppRepository.instance;

    setUp(loadTestSeed);
    tearDown(() => repo.signOut());

    test('app starts signed out', () {
      expect(repo.authStatus, AuthStatus.signedOut);
      expect(repo.currentUser, isNull);
    });

    test('cancelling the Google account picker does nothing', () async {
      repo.googleAuthService = FakeGoogleAuthService(null);
      await repo.signInWithGoogle();
      expect(repo.authStatus, AuthStatus.signedOut);
      expect(repo.authError, isNull);
    });

    test('existing account keeps its stored role (email matched case-insensitively)', () async {
      final admin = repo.getAllUsers().firstWhere((u) => u.role == UserRole.admin);
      await signInWithGoogleAs(admin.email!.toUpperCase());
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.uid, admin.uid);
      expect(repo.currentUser?.role, UserRole.admin);
    });

    test('new Google account without an invite becomes a customer', () async {
      await signInWithGoogleAs('Hanna.Tesfaye@Gmail.com', displayName: 'Hanna Tesfaye');
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingEmail, 'hanna.tesfaye@gmail.com');
      expect(repo.pendingDisplayName, 'Hanna Tesfaye');
      expect(repo.pendingInvite, isNull);

      await repo.completeProfile(name: 'Hanna Tesfaye', phone: '0933 445 566');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.role, UserRole.customer);
      expect(repo.currentUser?.email, 'hanna.tesfaye@gmail.com');
      expect(repo.currentUser?.phone, '+251933445566');
      expect(repo.currentUser?.shopId, isNull);
      expect(repo.pendingEmail, isNull);

      // Signing in again finds the same account.
      await repo.signOut();
      await signInWithGoogleAs('hanna.tesfaye@gmail.com');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.phone, '+251933445566');
    });

    test('the profile needs a valid name and Ethiopian mobile number', () async {
      await signInWithGoogleAs('new.user@gmail.com');
      for (final phone in ['', '12345', '0811223344', '+1 212 555 0100']) {
        await expectLater(
          repo.completeProfile(name: 'New User', phone: phone),
          throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.invalidPhone)),
          reason: phone,
        );
      }
      await expectLater(
        repo.completeProfile(name: '  ', phone: '0911223344'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.invalidName)),
      );
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.currentUser, isNull);
    });

    test('completing a profile without signing in fails', () async {
      await expectLater(
        repo.completeProfile(name: 'Nobody', phone: '0911223344'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.signInRequired)),
      );
    });

    test('barber invited by email signs in with the barber role and the invite is consumed', () async {
      const shopId = 'shop_1';
      await repo.addBarber(
        shopId: shopId,
        name: 'Dawit Bekele',
        title: 'Fade Specialist',
        email: ' Dawit.Bekele@Gmail.com',
        phone: '0944556677',
      );
      final barber = repo.getBarbersForShop(shopId).firstWhere((b) => b.name == 'Dawit Bekele');
      final invite = repo.getPendingBarberInvite(barber.id);
      expect(invite?.email, 'dawit.bekele@gmail.com');
      expect(barber.email, isNull, reason: 'barber profiles are public; the email stays in the invite');
      expect(barber.phone, '+251944556677');

      await signInWithGoogleAs('DAWIT.BEKELE@gmail.com', displayName: 'Dawit B');
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingInvite?.role, UserRole.barber);
      await repo.completeProfile(name: 'Dawit Bekele', phone: '0944556677');

      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.currentUser?.email, 'dawit.bekele@gmail.com');
      expect(repo.currentUser?.shopId, shopId);
      expect(repo.currentUser?.barberId, barber.id);
      expect(repo.getBarberForCurrentUser()?.id, barber.id);
      expect(repo.getPendingBarberInvite(barber.id), isNull);
      expect(repo.getPendingInvites().any((i) => i.email == 'dawit.bekele@gmail.com'), false);
    });

    test('an existing customer invited as barber is upgraded on next sign-in', () async {
      await signInWithGoogleAs('selam.girma@gmail.com');
      await repo.completeProfile(name: 'Selam Girma', phone: '0955667788');
      expect(repo.currentUser?.role, UserRole.customer);
      await repo.signOut();

      await repo.addBarber(shopId: 'shop_2', name: 'Selam Girma', title: 'Stylist', email: 'selam.girma@gmail.com');
      await signInWithGoogleAs('selam.girma@gmail.com');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.currentUser?.shopId, 'shop_2');
      expect(repo.currentUser?.phone, '+251955667788');
      expect(repo.getPendingInvites().any((i) => i.email == 'selam.girma@gmail.com'), false);
    });

    test('staff and owner emails cannot be re-invited into another role', () async {
      final ownerEmail = repo.getAllUsers().firstWhere((u) => u.uid == 'owner_1').email!;
      expect(
        () => repo.addBarber(shopId: 'shop_2', name: 'Someone', title: 'Barber', email: ownerEmail),
        throwsFormatException,
      );
      expect(
        () => repo.addBarber(shopId: 'shop_2', name: 'Someone', title: 'Barber', email: 'not-an-email'),
        throwsFormatException,
      );
    });

    test('removing a barber cancels their pending invite', () async {
      await repo.addBarber(shopId: 'shop_3', name: 'Temp Barber', title: 'Barber', email: 'temp.barber@gmail.com');
      final barber = repo.getBarbersForShop('shop_3').firstWhere((b) => b.name == 'Temp Barber');
      await repo.deleteBarber(barber.id);
      expect(repo.getPendingBarberInvite(barber.id), isNull);

      await signInWithGoogleAs('temp.barber@gmail.com');
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingInvite, isNull);
    });

    test('the admin invites a shop owner by email (validated, lowercased)', () async {
      repo.switchRole(UserRole.admin);
      Future<String> register(String ownerEmail) => repo.registerBarbershopByAdmin(
            shopName: 'Piassa Cuts',
            ownerName: 'Kebede Alemu',
            ownerEmail: ownerEmail,
            shopPhone: '0111 234 567',
            address: 'Piassa',
            city: 'Addis Ababa',
            description: '',
            imageUrl: '',
            openingHour: 9,
            closingHour: 20,
            workingDays: const [1, 2, 3, 4, 5, 6],
            isVerified: true,
          );
      await expectLater(
        register('kebede-at-gmail'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.invalidOwnerEmail)),
      );
      final shopId = await register(' Kebede.Alemu@GMAIL.com ');
      expect(repo.getPendingOwnerInvite(shopId)?.email, 'kebede.alemu@gmail.com');
      expect(repo.getShopById(shopId)?.phone, '0111 234 567');
      await repo.signOut();

      await signInWithGoogleAs('kebede.alemu@gmail.com', displayName: 'Kebede');
      expect(repo.pendingInvite?.role, UserRole.barbershopOwner);
      await repo.completeProfile(name: 'Kebede Alemu', phone: '0912000111');
      expect(repo.currentUser?.role, UserRole.barbershopOwner);
      expect(repo.getShopById(shopId)?.ownerId, repo.currentUser?.uid);
      expect(repo.getPendingOwnerInvite(shopId), isNull);
    });

    test('users can change their own phone afterwards', () async {
      repo.switchRole(UserRole.customer);
      await repo.updateMyProfile(phone: '0700 112 233');
      expect(repo.currentUser?.phone, '+251700112233');
      expect(
        () => repo.updateMyProfile(phone: '12345'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', AppErrorCode.invalidPhone)),
      );
    });

    test('demo personas sign in by email', () async {
      final barber = repo.getAllUsers().firstWhere((u) => u.role == UserRole.barber);
      repo.signInAsDemoUser(barber.email!);
      expect(repo.currentUser?.uid, barber.uid);
    });
  });

  group('auth error text', () {
    final en = AppLocalizationsEn();
    final am = AppLocalizationsAm();
    FirebaseAuthException err(String code, [String? message]) => FirebaseAuthException(code: code, message: message);

    test('maps Firebase Auth codes in English and Amharic', () {
      expect(en.authError(err('operation-not-allowed')), 'Google sign-in is not enabled for this app yet.');
      expect(en.authError(err('configuration-not-found')), 'Google sign-in is not enabled for this app yet.');
      expect(en.authError(err('internal-error', 'CONFIGURATION_NOT_FOUND')), 'Google sign-in is not enabled for this app yet.');
      expect(en.authError(err('unauthorized-domain')), 'This web address is not authorised for sign-in.');
      expect(en.authError(err('network-request-failed')), en.authErrNetwork);
      expect(en.authError(err('popup-blocked')), en.authErrPopupBlocked);
      expect(en.authError(err('account-exists-with-different-credential')), en.authErrAccountExists);
      expect(en.authError(err('user-disabled')), en.authErrUserDisabled);
      expect(en.authError(err('weird-code', 'Error')), 'Sign-in failed (weird-code).');

      expect(am.authError(err('operation-not-allowed')), am.authErrNotEnabled);
      expect(am.authError(err('unauthorized-domain')), am.authErrUnauthorizedDomain);
      expect(am.authError(err('weird-code')), am.authErrWithCode('weird-code'));
      expect(am.authErrNotEnabled, isNot(en.authErrNotEnabled));
    });

    test('cancel codes are recognised', () {
      for (final code in ['popup-closed-by-user', 'web-context-cancelled', 'canceled', 'cancelled-popup-request']) {
        expect(FirebaseGoogleAuthService.isCancellation(err(code)), true, reason: code);
      }
      expect(FirebaseGoogleAuthService.isCancellation(err('popup-blocked')), false);
    });
  });

  testWidgets('Sign-in screen: Continue with Google, then profile setup with a phone number', (tester) async {
    loadTestSeed();
    // English UI regardless of the machine's language.
    final previous = LocaleController.instance;
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'));
    addTearDown(() => LocaleController.instance = previous);
    await tester.pumpWidget(const BarbershopApp());
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    // No phone field and no demo personas or demo hints in a non-demo build.
    expect(find.byKey(const ValueKey('profile-phone')), findsNothing);
    expect(find.text('DEMO ACCOUNTS'), findsNothing);
    expect(find.byKey(const ValueKey('demo-email-hint')), findsNothing);

    AppRepository.instance.googleAuthService =
        FakeGoogleAuthService(GoogleIdentity(email: 'Abel.Tesfaye@gmail.com', displayName: 'Abel Tesfaye'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('abel.tesfaye@gmail.com'), findsOneWidget);
    expect(find.text('Abel Tesfaye'), findsOneWidget); // Name prefilled from Google.

    // The mobile number is required.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid Ethiopian mobile number (09... or 07...)'), findsOneWidget);
    expect(AppRepository.instance.currentUser, isNull);

    await tester.enterText(find.byKey(const ValueKey('profile-phone')), '0911 223 344');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final user = AppRepository.instance.currentUser;
    expect(user?.role, UserRole.customer);
    expect(user?.email, 'abel.tesfaye@gmail.com');
    expect(user?.phone, '+251911223344');

    await AppRepository.instance.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });
}
