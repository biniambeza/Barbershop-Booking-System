import 'dart:io';
import 'dart:math';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/core/utils/password_utils.dart';
import 'package:barbershop_booking/features/auth/screens/force_password_change_screen.dart';
import 'package:barbershop_booking/features/auth/screens/profile_setup_screen.dart';
import 'package:barbershop_booking/features/barber/screens/barber_dashboard_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/main.dart' show RootGate;
import 'package:barbershop_booking/models/invite_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/email_auth_service.dart' show LocalEmailAuthService;
import 'package:barbershop_booking/services/staff_account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

final _en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _barberEmail = 'dawit.new@gmail.com';
const _tempPassword = 'Kx7m-Q2pab';

/// Records every account creation and what the store held right after the
/// (single) persist call.
class _RecordingStaffAccounts implements StaffAccountService {
  _RecordingStaffAccounts(this._inner, this._repo);

  final StaffAccountService _inner;
  final AppRepository _repo;
  int persistCalls = 0;
  UserInvite? inviteAfterPersist;
  bool barberAfterPersist = false;

  @override
  Future<String> createAccount({
    required String email,
    required String password,
    required Future<void> Function(String uid) persist,
  }) {
    return _inner.createAccount(
      email: email,
      password: password,
      persist: (uid) async {
        persistCalls++;
        await persist(uid);
        inviteAfterPersist = _repo.getPendingInvites().where((i) => i.email == email).firstOrNull;
        barberAfterPersist = inviteAfterPersist?.barberId != null && _repo.getBarberById(inviteAfterPersist!.barberId!) != null;
      },
    );
  }
}

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  final repo = AppRepository.instance;

  Future<BarberAccountCreated> ownerCreatesBarber({String email = _barberEmail, String? phone = '0912 345 678'}) {
    repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    return repo.addBarberWithAccount(
      shopId: 'shop_1',
      name: 'Dawit Haile',
      title: 'Fade Specialist',
      email: email,
      phone: phone,
      temporaryPassword: _tempPassword,
    );
  }

  group('pure logic', () {
    test('temporary passwords are readable, 10 characters and always valid', () {
      final rng = Random(7);
      for (var i = 0; i < 500; i++) {
        final p = generateTemporaryPassword(random: rng);
        expect(p.length, kTemporaryPasswordLength);
        expect(p, matches(RegExp(r'^[A-Za-z2-9]{4}-[A-Za-z2-9]{5}$')));
        expect(p, isNot(matches(RegExp('[01OIl]'))));
        expect(isValidPassword(p), isTrue, reason: p);
      }
      expect(generateTemporaryPassword(), isNot(generateTemporaryPassword()));
    });

    test('unverified sign-in: profile, or an invite carrying this uid', () {
      UserInvite invite({String? authUid}) => UserInvite(
            email: 'a@b.com',
            role: UserRole.barber,
            name: 'A',
            shopId: 'shop_1',
            barberId: 'barber_1',
            createdBy: 'owner_1',
            createdAt: _now,
            authUid: authUid,
          );
      expect(unverifiedSignInAllowed(uid: 'u1', profileExists: true), isTrue);
      expect(unverifiedSignInAllowed(uid: 'u1', profileExists: false, invite: invite(authUid: 'u1')), isTrue);
      expect(unverifiedSignInAllowed(uid: 'u1', profileExists: false, invite: invite(authUid: 'u2')), isFalse);
      expect(unverifiedSignInAllowed(uid: 'u1', profileExists: false, invite: invite()), isFalse);
      expect(unverifiedSignInAllowed(uid: 'u1', profileExists: false), isFalse);
      expect(unverifiedSignInAllowed(uid: '', profileExists: false, invite: invite(authUid: '')), isFalse);
    });

    test('invite and profile maps carry authUid / mustChangePassword', () {
      final invite = UserInvite(
        email: 'X@Gmail.com',
        role: UserRole.barber,
        name: 'X',
        shopId: 's',
        barberId: 'b',
        createdBy: 'o',
        createdAt: _now,
        authUid: 'uid-1',
        mustChangePassword: true,
      );
      final map = invite.toMap();
      expect(map['authUid'], 'uid-1');
      expect(map['mustChangePassword'], true);
      final back = UserInvite.fromMap(map, 'x@gmail.com');
      expect(back.authUid, 'uid-1');
      expect(back.mustChangePassword, isTrue);

      final plain = UserInvite(email: 'y@gmail.com', role: UserRole.barber, name: 'Y', createdBy: 'o', createdAt: _now);
      expect(plain.toMap().containsKey('authUid'), isFalse);
      expect(plain.toMap().containsKey('mustChangePassword'), isFalse);

      final user = AppUser(uid: 'u', name: 'U', role: UserRole.barber, createdAt: _now, mustChangePassword: true);
      expect(user.toMap()['mustChangePassword'], true);
      expect(AppUser.fromMap(user.toMap(), 'u').mustChangePassword, isTrue);
      expect(user.copyWith(mustChangePassword: false).toMap().containsKey('mustChangePassword'), isFalse);
    });

    test('local account creation rolls back when persisting fails', () async {
      final auth = LocalEmailAuthService();
      final service = LocalStaffAccountService(() => auth);
      await expectLater(
        service.createAccount(email: 'a@gmail.com', password: _tempPassword, persist: (_) async => throw StateError('x')),
        throwsStateError,
      );
      expect(service.uidFor('a@gmail.com'), isNull);
      // The email is free again.
      final uid = await service.createAccount(email: 'a@gmail.com', password: _tempPassword, persist: (_) async {});
      expect(service.uidFor('a@gmail.com'), uid);
    });
  });

  group('owner creates a barber account (repository)', () {
    setUp(() => loadTestSeed(now: _now));

    test('one write: barber profile + invite with authUid and mustChangePassword', () async {
      final recorder = _RecordingStaffAccounts(repo.staffAccountService, repo);
      repo.staffAccountService = recorder;
      final before = repo.getBarbersForShop('shop_1').length;

      final created = await ownerCreatesBarber(email: 'Dawit.New@Gmail.com');

      expect(created.email, _barberEmail);
      expect(created.temporaryPassword, _tempPassword);
      expect(recorder.persistCalls, 1);
      expect(recorder.barberAfterPersist, isTrue);
      final invite = recorder.inviteAfterPersist!;
      expect(invite.email, _barberEmail);
      expect(invite.role, UserRole.barber);
      expect(invite.shopId, 'shop_1');
      expect(invite.barberId, created.barberId);
      expect(invite.authUid, created.uid);
      expect(invite.mustChangePassword, isTrue);
      expect(invite.name, 'Dawit Haile');
      expect(invite.createdBy, 'owner_1');

      expect(repo.getBarbersForShop('shop_1').length, before + 1);
      final barber = repo.getBarberById(created.barberId)!;
      // private barber phone: kept off the public profile, in private/contact.
      expect(barber.phone, isNull, reason: 'the phone stays out of the public profile');
      expect(repo.getBarberPhone(created.barberId), '+251912345678');
      expect(barber.email, isNull, reason: 'the login email stays out of the public profile');
      expect(repo.getPendingBarberInvite(created.barberId)?.authUid, created.uid);
    });

    test('invalid input is rejected before any account is created', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      Future<void> add({String name = 'X', String email = 'x@gmail.com', String password = _tempPassword, String? phone}) =>
          repo.addBarberWithAccount(
              shopId: 'shop_1', name: name, title: 'T', email: email, temporaryPassword: password, phone: phone);

      await expectLater(add(name: ' '), throwsA(isA<AppFormatException>()));
      await expectLater(add(email: 'nope'), throwsA(isA<AppFormatException>()));
      await expectLater(add(phone: '12'), throwsA(isA<AppFormatException>()));
      await expectLater(
        add(password: 'short1'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.weakPassword)),
      );
      await expectLater(
        add(password: 'onlyletters'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.weakPassword)),
      );
      // Existing staff: never re-assigned.
      await expectLater(add(email: 'barber2.shop1@example.com'), throwsA(isA<AppFormatException>()));
      final local = repo.staffAccountService as LocalStaffAccountService;
      expect(local.temporaryPasswords, isEmpty);
    });

    test('email already in use: nothing is written; the invitation fallback works', () async {
      final before = repo.getBarbersForShop('shop_1').length;
      await expectLater(
        ownerCreatesBarber(email: 'liya@example.com'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.emailAlreadyRegistered)),
      );
      expect(repo.getBarbersForShop('shop_1').length, before);
      expect(repo.getPendingInvites().where((i) => i.email == 'liya@example.com'), isEmpty);

      // "Send them an invitation instead" = today's invite-by-email flow.
      await repo.addBarber(shopId: 'shop_1', name: 'Liya Getachew', title: 'Stylist', email: 'liya@example.com');
      final invite = repo.getPendingInvites().firstWhere((i) => i.email == 'liya@example.com');
      expect(invite.authUid, isNull);
      expect(invite.mustChangePassword, isFalse);

      // Liya logs in with her own password and becomes the shop's barber.
      await repo.signOut();
      await repo.loginWithEmail(email: 'liya@example.com', password: LocalEmailAuthService.demoPassword);
      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.mustChangePassword, isFalse);
    });
  });

  group('barber first login (repository)', () {
    setUp(() => loadTestSeed(now: _now));

    test('temp password → profile setup → forced change → dashboard', () async {
      final created = await ownerCreatesBarber();
      await repo.signOut();

      await repo.loginWithEmail(email: _barberEmail, password: _tempPassword);
      expect(repo.authStatus, AuthStatus.needsProfile);
      expect(repo.pendingInvite?.authUid, created.uid);
      expect(repo.pendingInvite?.name, 'Dawit Haile');
      expect(repo.pendingPhone, '+251912345678');

      await repo.completeProfile(name: 'Dawit Haile', phone: repo.pendingPhone!);
      final user = repo.currentUser!;
      expect(user.uid, created.uid);
      expect(user.role, UserRole.barber);
      expect(user.shopId, 'shop_1');
      expect(user.barberId, created.barberId);
      expect(user.mustChangePassword, isTrue);
      expect(repo.mustChangePassword, isTrue);
      expect(repo.getPendingBarberInvite(created.barberId), isNull, reason: 'the invite is consumed');

      await expectLater(
        repo.completeRequiredPasswordChange(temporaryPassword: 'wrong-1234', newPassword: 'MyOwnPass9'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.wrongCredentials)),
      );
      expect(repo.mustChangePassword, isTrue);

      await repo.completeRequiredPasswordChange(temporaryPassword: _tempPassword, newPassword: 'MyOwnPass9');
      expect(repo.mustChangePassword, isFalse);
      expect(repo.getAllUsers().firstWhere((u) => u.uid == created.uid).mustChangePassword, isFalse);

      // Next time: straight to the dashboard with the new password.
      await repo.signOut();
      await expectLater(
        repo.loginWithEmail(email: _barberEmail, password: _tempPassword),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.wrongCredentials)),
      );
      await repo.loginWithEmail(email: _barberEmail, password: 'MyOwnPass9');
      expect(repo.authStatus, AuthStatus.signedIn);
      expect(repo.currentUser?.role, UserRole.barber);
      expect(repo.mustChangePassword, isFalse);
      expect(repo.getBarberForCurrentUser()?.id, created.barberId);
    });

    test('an unverified address without an owner-created invite is still rejected', () async {
      // Free-plan registration (verification link not opened yet).
      await repo.registerWithLink(email: 'new.person@gmail.com', password: 'Passw0rd99');
      await expectLater(
        repo.loginWithEmail(email: 'new.person@gmail.com', password: 'Passw0rd99'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.emailNotVerified)),
      );
      expect(repo.currentUser, isNull);

      // An ordinary invitation (no authUid) does not unlock it either.
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.addBarber(shopId: 'shop_1', name: 'New Person', title: 'Barber', email: 'new.person@gmail.com');
      await repo.signOut();
      await expectLater(
        repo.loginWithEmail(email: 'new.person@gmail.com', password: 'Passw0rd99'),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.emailNotVerified)),
      );
      expect(repo.authStatus, AuthStatus.signedOut);
    });

    test('a removed barber whose account was never used cannot log in', () async {
      final created = await ownerCreatesBarber();
      await repo.deleteBarber(created.barberId);
      await repo.signOut();
      await expectLater(
        repo.loginWithEmail(email: _barberEmail, password: _tempPassword),
        throwsA(isA<EmailAuthException>().having((e) => e.code, 'code', EmailAuthErrorCode.emailNotVerified)),
      );
    });
  });

  group('screens', () {
    setUp(() => loadTestSeed(now: _now));

    testWidgets('owner adds a barber: login details sheet, then "waiting for first login"', (tester) async {
      _bigScreen(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.pumpWidget(_app(const ManageBarbersScreen(shopId: 'shop_1')));
      await tester.pumpAndSettle();

      // Seeded barbers with an account show as active.
      expect(find.byKey(const ValueKey('barber-account-active-barber_1')), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text(_en.staffAcctSheetTitle), findsOneWidget);

      // A generated temporary password is prefilled; regenerate changes it.
      String passwordField() =>
          tester.widget<TextField>(find.byKey(const ValueKey('add-barber-password'))).controller!.text;
      final first = passwordField();
      expect(isValidPassword(first), isTrue);
      await tester.tap(find.byKey(const ValueKey('add-barber-regenerate')));
      await tester.pump();
      final generated = passwordField();
      expect(isValidPassword(generated), isTrue);

      // Validation: name and email are required.
      await tester.tap(find.byKey(const ValueKey('add-barber-create')));
      await tester.pump();
      expect(find.text(_en.staffAcctNameRequired), findsOneWidget);
      expect(find.text(_en.staffAcctEmailRequired), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('add-barber-name')), 'Dawit Haile');
      await tester.enterText(find.byKey(const ValueKey('add-barber-email')), _barberEmail);
      await tester.enterText(find.byKey(const ValueKey('add-barber-phone')), '0912 345 678');
      await tester.tap(find.byKey(const ValueKey('add-barber-create')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('barber-login-details')), findsOneWidget);
      expect(find.text(_en.staffAcctCreatedBody('Dawit Haile')), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('barber-login-email'))).data, _barberEmail);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('barber-login-password'))).data, generated);

      await tester.tap(find.byKey(const ValueKey('barber-login-done')));
      await tester.pumpAndSettle();
      final barber = repo.getBarbersForShop('shop_1').firstWhere((b) => b.name == 'Dawit Haile');
      expect(find.byKey(ValueKey('barber-account-waiting-${barber.id}')), findsOneWidget);
      expect(find.text(_en.staffAcctLostPasswordHint), findsOneWidget);
      expect(repo.getPendingBarberInvite(barber.id)?.authUid, isNotNull);
    });

    testWidgets('email already registered: offers and sends an invitation instead', (tester) async {
      _bigScreen(tester);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await tester.pumpWidget(_app(const ManageBarbersScreen(shopId: 'shop_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('add-barber-name')), 'Liya Getachew');
      await tester.enterText(find.byKey(const ValueKey('add-barber-email')), 'liya@example.com');
      await tester.tap(find.byKey(const ValueKey('add-barber-create')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('add-barber-email-in-use')), findsOneWidget);
      expect(find.text(_en.staffAcctEmailInUseBody('liya@example.com')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-barber-send-invite')));
      await tester.pumpAndSettle();

      expect(find.text(_en.staffAcctInviteSaved('liya@example.com')), findsOneWidget);
      final barber = repo.getBarbersForShop('shop_1').firstWhere((b) => b.name == 'Liya Getachew');
      expect(find.byKey(ValueKey('barber-invite-waiting-${barber.id}')), findsOneWidget);
      expect(repo.getPendingBarberInvite(barber.id)?.authUid, isNull);
    });

    testWidgets('RootGate: temp-password login → profile (phone prefilled) → forced change → dashboard',
        (tester) async {
      _bigScreen(tester);
      await ownerCreatesBarber();
      await repo.signOut();
      await tester.pumpWidget(_app(const RootGate()));
      await tester.pumpAndSettle();

      await tester.runAsync(() => repo.loginWithEmail(email: _barberEmail, password: _tempPassword));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      final phone = tester.widget<TextField>(find.byKey(const ValueKey('profile-phone')));
      expect(phone.controller!.text, '+251912345678');
      expect(find.text('Dawit Haile'), findsOneWidget);

      await tester.tap(find.text(_en.continueLabel));
      await tester.pumpAndSettle();
      expect(find.byType(ForcePasswordChangeScreen), findsOneWidget);
      expect(find.byType(BarberDashboardScreen), findsNothing);

      // Same as the temporary one: refused.
      await tester.enterText(find.byKey(const ValueKey('force-password-temporary')), _tempPassword);
      await tester.enterText(find.byKey(const ValueKey('force-password-new')), _tempPassword);
      await tester.enterText(find.byKey(const ValueKey('force-password-confirm')), _tempPassword);
      await tester.tap(find.byKey(const ValueKey('force-password-save')));
      await tester.pumpAndSettle();
      expect(find.text(_en.staffAcctForceSameAsTemp), findsOneWidget);

      // Wrong temporary password.
      await tester.enterText(find.byKey(const ValueKey('force-password-temporary')), 'Wrong-pass9');
      await tester.enterText(find.byKey(const ValueKey('force-password-new')), 'MyOwnPass9');
      await tester.enterText(find.byKey(const ValueKey('force-password-confirm')), 'MyOwnPass9');
      await tester.tap(find.byKey(const ValueKey('force-password-save')));
      await tester.pumpAndSettle();
      expect(find.text(_en.staffAcctForceWrongTemp), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('force-password-temporary')), _tempPassword);
      await tester.tap(find.byKey(const ValueKey('force-password-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ForcePasswordChangeScreen), findsNothing);
      expect(find.byType(BarberDashboardScreen), findsOneWidget);
      expect(repo.mustChangePassword, isFalse);
    });

    test('the new strings are translated to Amharic', () {
      final am = lookupAppLocalizations(const Locale('am'));
      expect(am.staffAcctForceTitle, isNot(_en.staffAcctForceTitle));
      expect(am.staffAcctSheetTitle, isNot(_en.staffAcctSheetTitle));
    });
  });
}
