import 'dart:async';
import 'dart:io';

import 'package:barbershop_booking/core/theme/app_theme.dart';
import 'package:barbershop_booking/features/admin/screens/admin_payment_review_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/features/shop_owner/screens/manage_barbers_screen.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/plan_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/payment_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

final _en = lookupAppLocalizations(const Locale('en'));
final _am = lookupAppLocalizations(const Locale('am'));

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

class _MemoryLanguageStore implements LanguageStore {
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String code) async {
    value = code;
    writes++;
  }
}

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() => Intl.defaultLocale = null);

  final repo = AppRepository.instance;

  group('typed service errors', () {
    setUp(() => loadTestSeed(now: _now));

    Future<AppException> appError(Future<Object?> Function() action) async {
      try {
        await action();
      } on AppException catch (e) {
        return e;
      }
      fail('expected an AppException');
    }

    test('repository errors carry codes (and stay Format/State errors)', () async {
      await signInWithGoogleAs('new.person@gmail.com');
      final phone = await appError(() => repo.completeProfile(name: 'New Person', phone: '12345'));
      expect(phone.code, AppErrorCode.invalidPhone);
      expect(phone, isA<FormatException>());
      await repo.signOut();

      final email = await appError(
        () => repo.addBarber(shopId: 'shop_2', name: 'Someone', title: 'Barber', email: 'not-an-email'),
      );
      expect(email.code, AppErrorCode.invalidEmail);

      // owner_1's email, typed in another case: still recognised.
      final ownerEmail = repo.getAllUsers().firstWhere((u) => u.uid == 'owner_1').email!;
      final staff = await appError(
        () => repo.addBarber(shopId: 'shop_2', name: 'Someone', title: 'Barber', email: ownerEmail.toUpperCase()),
      );
      expect(staff.code, AppErrorCode.emailAlreadyStaff);
      expect(staff.args, [UserRole.barbershopOwner]);

      final signedOut = await appError(() => repo.createBooking(
            shopId: 'shop_1',
            shopName: 'x',
            barberId: 'barber_1',
            barberName: 'x',
            serviceId: 'srv_1_1',
            serviceName: 'x',
            price: 450,
            date: DateTime(2026, 11, 25),
            timeSlot: '10:30 AM',
          ));
      expect(signedOut.code, AppErrorCode.signInToBook);
      expect(signedOut, isA<StateError>());
    });

    test('barber not taking bookings names the barber in both languages', () async {
      repo.switchRole(UserRole.customer);
      await repo.updateBarberAvailability('barber_1', false);
      final e = await appError(() => repo.createBooking(
            shopId: 'shop_1',
            shopName: 'x',
            barberId: 'barber_1',
            barberName: 'Yonas Tadesse',
            serviceId: 'srv_1_1',
            serviceName: 'x',
            price: 450,
            date: DateTime(2026, 11, 25),
            timeSlot: '10:30 AM',
          ));
      expect(e.code, AppErrorCode.barberNotTakingBookings);
      expect(_en.errorText(e), contains('Yonas Tadesse is not taking bookings'));
      expect(_am.errorText(e), contains('Yonas Tadesse በአሁኑ ጊዜ ቀጠሮ አይቀበሉም'));
    });

    test('services longer than the rules allow are rejected', () async {
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      final e = await appError(() => repo.addService(
            shopId: 'shop_1',
            name: 'Marathon',
            description: 'x',
            price: 100,
            durationMinutes: kMaxServiceDurationMinutes + 15,
          ));
      expect(e.code, AppErrorCode.serviceTooLong);
      expect(_en.errorText(e), 'A service can be at most $kMaxServiceDurationMinutes minutes long.');
    });

    test('every AppErrorCode has English and Amharic text', () {
      for (final code in AppErrorCode.values) {
        final args = <Object?>['x', 'y'];
        final en = _en.appError(code, args);
        final am = _am.appError(code, args);
        expect(en, isNotEmpty, reason: code.name);
        expect(am, isNotEmpty, reason: code.name);
        expect(am, isNot(en), reason: '${code.name} is not translated');
        expect(code.englishMessage(args), isNotEmpty);
      }
    });

    test('errorText covers slot conflicts, Firebase and unknown errors', () {
      expect(_am.errorText(const SlotTakenException()), _am.errSlotTaken);
      expect(_en.errorText(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), _en.errPermissionDenied);
      expect(_am.errorText(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), _am.errOffline);
      expect(_am.errorText(StateError('Could not book: aborted')), _am.errBookingFailed);
      expect(_am.errorText(Exception('boom')), _am.errGeneric);
    });

    test('validatePlan returns typed errors', () {
      const ok = SubscriptionPlan(id: 'basic', name: 'Basic', priceMonthlyEtb: 500, maxBarbers: 3);
      expect(validatePlan(ok), isNull);
      expect(validatePlan(ok.copyWith(maxBarbers: 0))!.code, AppErrorCode.planMaxBarbersInvalid);
      expect(validatePlan(ok.copyWith(priceMonthlyEtb: 0))!.code, AppErrorCode.planPriceRequired);
      expect(validatePlan(ok.copyWith(name: ' '))!.code, AppErrorCode.planNameRequired);
      final badId = validatePlan(const SubscriptionPlan(id: 'gold', name: 'Gold', priceMonthlyEtb: 9, maxBarbers: 1))!;
      expect(badId.code, AppErrorCode.planIdInvalid);
      expect(_am.errorText(badId), contains('trial'));
    });
  });

  group('payment errors in Amharic', () {
    test('known backend messages become reasons', () {
      final cancelled = PaymentException.of('failed-precondition', 'This booking was cancelled.');
      expect(cancelled.reason, PaymentErrorReason.bookingCancelled);
      expect(_am.paymentError(cancelled), _am.payErrBookingCancelled);
      expect(_en.paymentError(cancelled), 'This booking was cancelled.');

      final small = PaymentException.of(
        'failed-precondition',
        'This plan allows 3 barbers but the shop has 5. Choose a bigger plan or remove barbers.',
      );
      expect(small.reason, PaymentErrorReason.planTooSmall);
      expect(small.args, [3, 5]);
      expect(_am.paymentError(small), _am.payErrPlanTooSmall(3, 5));

      expect(PaymentException.of('aborted', 'Your payment is still being prepared. Please try again.').reason,
          PaymentErrorReason.stillPreparing);
      expect(PaymentException.of('failed-precondition', 'Payments are not configured (PAYMENT_RETURN_URL).').reason,
          PaymentErrorReason.notSetUp);
    });

    test('every callable code has an Amharic fallback', () {
      const codes = {
        'failed-precondition': 'payErrPrecondition',
        'invalid-argument': 'payErrInvalid',
        'aborted': 'payErrBookingChanged',
        'launch-failed': 'payErrLaunchFailed',
      };
      for (final code in codes.keys) {
        final text = _am.paymentError(PaymentException.of(code, 'Some new server message'));
        expect(text, isNot(contains('Some new server message')), reason: code);
        expect(RegExp(r'[ሀ-፿]').hasMatch(text), isTrue, reason: code);
      }
      expect(_am.paymentError(PaymentException.of('aborted')), _am.payErrBookingChanged);
      // English keeps an unknown backend message as written.
      expect(_en.paymentError(PaymentException.of('failed-precondition', 'Some new server message')),
          'Some new server message');
    });

    test('an invalid plan in savePlan is translated', () async {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.admin);
      final service = PaymentService(backend: LocalPaymentBackend(repository: repo, clock: () => _now), repository: repo);
      try {
        await service.savePlan(repo.getPlan('basic')!.copyWith(maxBarbers: 0));
        fail('expected an error');
      } on PaymentException catch (e) {
        expect(e.code, 'invalid-argument');
        expect(_am.paymentError(e), _am.errPlanMaxBarbers);
      }
    });
  });

  group('models', () {
    test('Barbershop.copyWith can clear the landmark', () {
      loadTestSeed(now: _now);
      final shop = repo.getShopById('shop_1')!.copyWith(landmark: 'Near Edna Mall');
      expect(shop.landmark, 'Near Edna Mall');
      expect(shop.copyWith(name: 'X').landmark, 'Near Edna Mall');
      expect(shop.copyWith(clearLandmark: true).landmark, isNull);
    });

    test('a cleared landmark is saved', () async {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
      await repo.updateShop(repo.getShopById('shop_1')!.copyWith(landmark: 'Near Edna Mall'));
      expect(repo.getShopById('shop_1')!.landmark, 'Near Edna Mall');
      await repo.updateShop(repo.getShopById('shop_1')!.copyWith(clearLandmark: true));
      expect(repo.getShopById('shop_1')!.landmark, isNull);
    });
  });

  group('barber working hours', () {
    setUp(() {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1');
    });

    test('owner sets and clears a barber schedule', () async {
      await repo.updateBarberSchedule('barber_1', workingDays: [3, 1, 1], startHour: 10, endHour: 16);
      var b = repo.getBarberById('barber_1')!;
      expect(b.workingDays, [1, 3]);
      expect(b.startHour, 10);
      expect(b.endHour, 16);

      await repo.updateBarberSchedule('barber_1', workingDays: null, startHour: null, endHour: null);
      b = repo.getBarberById('barber_1')!;
      expect(b.workingDays, isNull);
      expect(b.startHour, isNull);
      expect(b.endHour, isNull);
    });

    test('invalid schedules are rejected with codes', () async {
      Future<AppErrorCode?> codeOf(Future<void> f) async {
        try {
          await f;
        } on AppException catch (e) {
          return e.code;
        }
        return null;
      }

      expect(await codeOf(repo.updateBarberSchedule('barber_1', workingDays: [], startHour: 9, endHour: 17)),
          AppErrorCode.noWorkingDays);
      expect(await codeOf(repo.updateBarberSchedule('barber_1', workingDays: [1], startHour: 17, endHour: 9)),
          AppErrorCode.invalidWorkingHours);
      expect(await codeOf(repo.updateBarberSchedule('barber_1', workingDays: [1], startHour: 9, endHour: null)),
          AppErrorCode.invalidWorkingHours);
    });

    testWidgets('the owner edits hours from Manage barbers', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final shop = repo.getShopById('shop_1')!;
      await tester.pumpWidget(_app(const ManageBarbersScreen(shopId: 'shop_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit-hours-barber_1')));
      await tester.pumpAndSettle();
      expect(find.text(_en.barberHoursTitle('Yonas Tadesse')), findsOneWidget);

      // Follows the shop: switch to own hours, drop the first shop day, save.
      await tester.tap(find.byKey(const ValueKey('follow-shop-hours')));
      await tester.pumpAndSettle();
      final firstDay = (shop.workingDays.toList()..sort()).first;
      await tester.tap(find.byKey(ValueKey('day-$firstDay')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-hours')));
      await tester.pumpAndSettle();

      final b = repo.getBarberById('barber_1')!;
      expect(b.workingDays, isNot(contains(firstDay)));
      expect(b.workingDays!.length, shop.workingDays.toSet().length - 1);
      expect(b.startHour, shop.openingHour);
      expect(b.endHour, shop.closingHour);
      expect(find.text(_en.workingHoursSaved), findsOneWidget);

      // Back to the shop's hours.
      await tester.tap(find.byKey(const ValueKey('edit-hours-barber_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('follow-shop-hours')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-hours')));
      await tester.pumpAndSettle();
      expect(repo.getBarberById('barber_1')!.workingDays, isNull);
    });
  });

  group('booking status changes', () {
    setUp(() {
      loadTestSeed(now: _now);
      repo.switchRole(UserRole.customer); // user_cust_1
    });
    tearDown(() => repo.debugWriteGate = null);

    testWidgets('cancel is disabled while in flight and shows a translated error', (tester) async {
      var gate = Completer<void>();
      repo.debugWriteGate = () => gate.future;
      await tester.pumpWidget(_app(const CustomerBookingsScreen(), locale: const Locale('am')));
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('cancel-booking-book_1'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

      gate.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await tester.pump();
      await tester.pump();
      expect(find.text(_am.cancelBookingFailed(_am.errPermissionDenied)), findsOneWidget);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(repo.getBookingById('book_1')!.status, BookingStatus.confirmed);

      // Second try goes through.
      gate = Completer<void>()..complete();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.getBookingById('book_1')!.status, BookingStatus.cancelled);
    });
  });

  group('payment review (offline simulator)', () {
    late LocalPaymentBackend backend;
    late PaymentService service;
    var now = _now;

    setUp(() {
      now = _now;
      loadTestSeed(now: _now);
      backend = LocalPaymentBackend(repository: repo, clock: () => now);
      service = PaymentService(backend: backend, repository: repo);
      PaymentService.instance = service;
    });

    Future<String> paidThenCancelled() async {
      repo.switchRole(UserRole.customer);
      final checkout = await service.startBookingPayment('book_1');
      await repo.updateBookingStatus('book_1', BookingStatus.cancelled);
      await service.completeSimulatedPayment(checkout.paymentId);
      return checkout.paymentId;
    }

    test('a payment for a cancelled booking is flagged and can be refunded', () async {
      final id = await paidThenCancelled();
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.paid);

      repo.switchRole(UserRole.admin);
      final flagged = await service.watchPaymentsToReview().first;
      expect(flagged.map((p) => p.id), [id]);
      expect(paymentReviewReason(flagged.single, repo.getBookingById('book_1')), PaymentReviewReason.cancelledBooking);

      final result = await service.resolvePaymentReview(
        paymentId: id,
        resolution: PaymentReviewResolution.refundedInChapa,
        note: ' refunded ',
      );
      expect(result.status, PaymentRecordStatus.refunded);
      expect(result.bookingPaymentStatus, 'refunded');
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.refunded);
      final record = backend.payments.single;
      expect(record.needsReview, isFalse);
      expect(record.resolution, PaymentReviewResolution.refundedInChapa);
      expect(record.resolutionNote, 'refunded');
      expect(record.resolvedBy, repo.currentUser!.uid);
      expect(record.isRefunded, isTrue);
      expect(await service.watchPaymentsToReview().first, isEmpty);

      try {
        await service.resolvePaymentReview(paymentId: id, resolution: PaymentReviewResolution.noAction);
        fail('expected an error');
      } on PaymentException catch (e) {
        expect(e.reason, PaymentErrorReason.reviewNotNeeded);
      }
    });

    test('a second payment for a paid booking is flagged; refunding it keeps the booking paid', () async {
      repo.switchRole(UserRole.customer);
      final first = await service.startBookingPayment('book_1');
      now = _now.add(const Duration(minutes: 31)); // the first checkout is no longer reused
      final second = await service.startBookingPayment('book_1');
      expect(second.paymentId, isNot(first.paymentId));
      await service.completeSimulatedPayment(second.paymentId);
      await service.completeSimulatedPayment(first.paymentId);

      repo.switchRole(UserRole.admin);
      final flagged = await service.watchPaymentsToReview().first;
      expect(flagged.map((p) => p.id), [first.paymentId]);
      expect(paymentReviewReason(flagged.single, repo.getBookingById('book_1')), PaymentReviewReason.doublePayment);

      await service.resolvePaymentReview(paymentId: first.paymentId, resolution: PaymentReviewResolution.refundedInChapa);
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.paid);
    });

    test('only admins can list or resolve reviews', () async {
      final id = await paidThenCancelled();
      expect(service.watchPaymentsToReview().first, throwsA(isA<PaymentException>()));
      try {
        await service.resolvePaymentReview(paymentId: id, resolution: PaymentReviewResolution.noAction);
        fail('expected an error');
      } on PaymentException catch (e) {
        expect(e.code, 'permission-denied');
      }
    });

    testWidgets('admin resolves a payment from the review screen', (tester) async {
      await tester.runAsync(paidThenCancelled);
      repo.switchRole(UserRole.admin);
      await tester.pumpWidget(_app(AdminPaymentReviewScreen(payments: service)));
      await tester.pumpAndSettle();

      expect(find.text(_en.reviewReasonCancelledBooking), findsOneWidget);
      await tester.tap(find.text(_en.reviewReasonCancelledBooking));
      await tester.pumpAndSettle();
      expect(find.text(_en.paymentDetailsTitle), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('review-note')), 'Refunded via telebirr');
      await tester.tap(find.byKey(const ValueKey('review-refunded')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-refund')));
      await tester.pumpAndSettle();

      expect(find.text(_en.reviewClosedRefunded), findsOneWidget);
      expect(find.text(_en.noPaymentsToReview), findsOneWidget);
      expect(backend.payments.single.resolutionNote, 'Refunded via telebirr');
      expect(repo.getBookingById('book_1')!.paymentStatus, PaymentStatus.refunded);
    });
  });

  group('language on this device', () {
    setUp(() => loadTestSeed(now: _now));

    test('a choice made while signed out survives a restart', () async {
      final store = _MemoryLanguageStore();
      final first = LocaleController(repository: repo, deviceLocale: const Locale('en'), store: store)..start();
      await first.setLanguage('am');
      expect(store.value, 'am');
      first.dispose();

      // "Restart": a new controller reads the saved choice.
      final second = LocaleController(repository: repo, deviceLocale: const Locale('en'), store: store);
      await second.loadSaved();
      second.start();
      expect(second.languageCode, 'am');
      second.dispose();
    });

    test('the saved choice syncs to a profile without a language after sign-in', () async {
      final store = _MemoryLanguageStore()..value = 'am';
      final ctrl = LocaleController(repository: repo, deviceLocale: const Locale('en'), store: store);
      await ctrl.loadSaved();
      ctrl.start();
      expect(ctrl.languageCode, 'am');

      // A brand-new customer (no language on the profile yet).
      await signInWithGoogleAs('new.customer@gmail.com');
      await repo.completeProfile(name: 'New Customer', phone: '0911999888');
      await pumpEventQueue();
      expect(repo.currentUser!.language, 'am');
      ctrl.dispose();
    });

    test('a signed-in user language wins and is remembered on the device', () async {
      final store = _MemoryLanguageStore()..value = 'en';
      final ctrl = LocaleController(repository: repo, deviceLocale: const Locale('en'), store: store);
      await ctrl.loadSaved();
      ctrl.start();
      repo.switchRole(UserRole.barbershopOwner, targetShopId: 'shop_1'); // owner_1: 'am'
      await pumpEventQueue();
      expect(ctrl.languageCode, 'am');
      expect(store.value, 'am');
      ctrl.dispose();
    });

    test('a broken store falls back to the device language', () async {
      final ctrl = LocaleController(repository: repo, deviceLocale: const Locale('am'), store: _ThrowingStore());
      await ctrl.loadSaved();
      expect(ctrl.languageCode, 'am');
      await ctrl.setLanguage('en');
      expect(ctrl.languageCode, 'en');
      ctrl.dispose();
    });
  });

}

class _ThrowingStore implements LanguageStore {
  @override
  Future<String?> read() => Future.error(StateError('no prefs'));

  @override
  Future<void> write(String code) => Future.error(StateError('no prefs'));
}
