import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbershop_booking/core/utils/phone_utils.dart';
import 'package:barbershop_booking/features/auth/screens/auth_screen.dart';
import 'package:barbershop_booking/l10n/locale_controller.dart';
import 'package:barbershop_booking/main.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(loadTestSeed);

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

  group('Phone OTP sign-in (local mode)', () {
    final repo = AppRepository.instance;

    tearDown(() => repo.signOut());

    test('app starts signed out', () {
      expect(repo.authStatus, AuthStatus.signedOut);
      expect(repo.currentUser, isNull);
    });

    test('invalid phone number is rejected before sending a code', () async {
      expect(() => repo.sendOtp('12345'), throwsFormatException);
    });

    test('wrong code is rejected', () async {
      await repo.sendOtp('0911000001');
      expect(() => repo.verifyOtp('000000'), throwsFormatException);
      expect(repo.currentUser, isNull);
    });

    test('existing account keeps its stored role', () async {
      await repo.sendOtp('0911000001');
      await repo.verifyOtp('123456');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.role, UserRole.admin);
    });

    test('new number without an invite becomes a customer', () async {
      await repo.sendOtp('0933445566');
      await repo.verifyOtp('123456');
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingInvite, isNull);

      await repo.completeProfile(name: 'Hanna Tesfaye');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.role, UserRole.customer);
      expect(repo.currentUser?.phone, '+251933445566');
      expect(repo.currentUser?.shopId, isNull);
    });

    test('barber invited by the owner signs in with the barber role', () async {
      const shopId = 'shop_1';
      await repo.addBarber(shopId: shopId, name: 'Dawit Bekele', title: 'Fade Specialist', phone: '0944556677');
      final barber = repo.getBarbersForShop(shopId).firstWhere((b) => b.name == 'Dawit Bekele');
      expect(repo.getPendingBarberInvite(barber.id), isNotNull);

      await repo.sendOtp('+251944556677');
      await repo.verifyOtp('123456');
      expect(repo.pendingInvite?.role, UserRole.barber);
      await repo.completeProfile(name: 'Dawit Bekele');

      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.currentUser?.shopId, shopId);
      expect(repo.currentUser?.barberId, barber.id);
      expect(repo.getBarberForCurrentUser()?.id, barber.id);
      expect(repo.getPendingBarberInvite(barber.id), isNull);
    });

    test('an existing customer invited as barber is upgraded on next sign-in', () async {
      await repo.sendOtp('0955667788');
      await repo.verifyOtp('123456');
      await repo.completeProfile(name: 'Selam Girma');
      expect(repo.currentUser?.role, UserRole.customer);
      await repo.signOut();

      await repo.addBarber(shopId: 'shop_2', name: 'Selam Girma', title: 'Stylist', phone: '0955667788');
      await repo.sendOtp('0955667788');
      await repo.verifyOtp('123456');
      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.currentUser?.shopId, 'shop_2');
    });

    test('staff and owner numbers cannot be re-invited into another role', () async {
      // +251911000101 is the demo owner of shop_1.
      expect(
        () => repo.addBarber(shopId: 'shop_2', name: 'Someone', title: 'Barber', phone: '0911000101'),
        throwsFormatException,
      );
    });

    test('removing a barber cancels their pending invite', () async {
      await repo.addBarber(shopId: 'shop_3', name: 'Temp Barber', title: 'Barber', phone: '0966778899');
      final barber = repo.getBarbersForShop('shop_3').firstWhere((b) => b.name == 'Temp Barber');
      await repo.deleteBarber(barber.id);
      expect(repo.getPendingBarberInvite(barber.id), isNull);

      await repo.sendOtp('0966778899');
      await repo.verifyOtp('123456');
      expect(repo.pendingInvite, isNull);
    });
  });

  testWidgets('Sign-in screen asks for a phone number, then the code', (tester) async {
    // English UI regardless of the machine's language.
    final previous = LocaleController.instance;
    LocaleController.instance = LocaleController(deviceLocale: const Locale('en'));
    addTearDown(() => LocaleController.instance = previous);
    await tester.pumpWidget(const BarbershopApp());
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
    // No email/password fields and no demo personas in a non-demo build.
    expect(find.text('Password'), findsNothing);
    expect(find.text('DEMO ACCOUNTS'), findsNothing);

    await tester.enterText(find.byType(TextField), '0911000301');
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();
    expect(find.text('Verify'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(AppRepository.instance.currentUser?.role, UserRole.customer);

    await AppRepository.instance.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    // Stop the resend countdown timer.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
