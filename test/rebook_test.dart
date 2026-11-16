import 'dart:io';

import 'package:barbershop_booking/data/addis_time.dart';
import 'package:barbershop_booking/features/customer/screens/barbershop_detail_screen.dart';
import 'package:barbershop_booking/features/customer/screens/booking_flow_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_bookings_screen.dart';
import 'package:barbershop_booking/features/customer/screens/customer_home_screen.dart';
import 'package:barbershop_booking/features/customer/widgets/rebook_widgets.dart';
import 'package:barbershop_booking/l10n/l10n.dart';
import 'package:barbershop_booking/models/barber_model.dart';
import 'package:barbershop_booking/models/barbershop_model.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/service_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:barbershop_booking/services/availability_service.dart';
import 'package:barbershop_booking/services/favorite_barbers_store.dart';
import 'package:barbershop_booking/services/rebook_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7, 0);

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

Booking _booking(String id, String barberId, String shopId, String serviceId, DateTime start,
        {BookingStatus status = BookingStatus.completed}) =>
    Booking(
      id: id,
      shopId: shopId,
      shopName: 'Shop $shopId',
      barberId: barberId,
      barberName: 'Barber $barberId',
      customerId: 'c1',
      customerName: 'C',
      customerPhone: '',
      serviceId: serviceId,
      serviceName: 'Service $serviceId',
      price: 100,
      date: start,
      timeSlot: '10:00 AM',
      status: status,
      createdAt: start,
      startAt: start,
    );

Barbershop _shop(String id, {bool suspended = false}) => Barbershop(
      id: id,
      ownerId: 'o',
      name: 'Shop $id',
      description: '',
      address: '',
      city: 'Addis Ababa',
      subCity: 'Bole',
      phone: '',
      imageUrl: '',
      adminSuspended: suspended,
    );

/// Records pushed routes.
class _PushRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  setUp(() => loadTestSeed(now: _now));

  final repo = AppRepository.instance;

  group('rebook logic', () {
    test('first names', () {
      expect(firstNameOf('Dawit Mekonnen'), 'Dawit');
      expect(firstNameOf('  Abel  '), 'Abel');
      expect(firstNameOf(''), '');
    });

    test('favourites first, then recent completed barbers, one entry per barber', () {
      final now = DateTime.utc(2026, 11, 20);
      final list = buildYourBarbers(
        favorites: const [
          FavoriteBarber(barberId: 'fav_new', shopId: 's9', barberName: 'Never Visited'),
          FavoriteBarber(barberId: 'b2', shopId: 's1', barberName: 'Old Name'),
        ],
        bookings: [
          _booking('k1', 'b1', 's1', 'v1', now.subtract(const Duration(days: 2))),
          _booking('k2', 'b2', 's1', 'v2', now.subtract(const Duration(days: 5))),
          _booking('k3', 'b2', 's1', 'v3', now.subtract(const Duration(days: 40))),
          _booking('k4', 'b3', 's2', 'v4', now.subtract(const Duration(days: 1)), status: BookingStatus.cancelled),
          _booking('k5', 'b4', 's2', 'v5', now.subtract(const Duration(days: 400))),
          _booking('k6', 'b5', 's2', 'v6', now.add(const Duration(days: 1)), status: BookingStatus.confirmed),
        ],
        barberById: (id) => id == 'b2'
            ? Barber(id: 'b2', shopId: 's1', name: 'Dawit Mekonnen', title: 'Barber')
            : null,
        shopById: (id) => id == 's1' ? _shop('s1') : null,
        nowUtc: now,
      );
      expect(list.map((c) => c.barberId), ['b2', 'fav_new', 'b1']);
      final b2 = list[0];
      expect(b2.isFavorite, isTrue);
      expect(b2.barberName, 'Dawit Mekonnen'); // the live profile wins
      expect(b2.firstName, 'Dawit');
      expect(b2.serviceId, 'v2'); // the last completed visit
      expect(list[1].serviceId, isNull);
      expect(list[1].barberName, 'Never Visited');
      expect(list[2].isFavorite, isFalse);
      expect(list[2].serviceId, 'v1');
    });

    test('the row is capped', () {
      final now = DateTime.utc(2026, 11, 20);
      final list = buildYourBarbers(
        favorites: const [],
        bookings: [
          for (var i = 0; i < 20; i++) _booking('k$i', 'b$i', 's1', 'v', now.subtract(Duration(days: i + 1))),
        ],
        barberById: (_) => null,
        shopById: (_) => null,
        nowUtc: now,
      );
      expect(list, hasLength(kYourBarbersLimit));
      expect(list.first.barberId, 'b0');
    });

    test('checkRebook names each problem', () {
      final services = {
        's1': [BarbershopService(id: 'v1', shopId: 's1', name: 'Fade', description: '', price: 1)],
        'empty': <BarbershopService>[],
      };
      final barbers = {
        'b1': Barber(id: 'b1', shopId: 's1', name: 'A', title: ''),
        'off': Barber(id: 'off', shopId: 's1', name: 'B', title: '', isAvailable: false),
        'moved': Barber(id: 'moved', shopId: 's2', name: 'C', title: ''),
        'e1': Barber(id: 'e1', shopId: 'empty', name: 'D', title: ''),
      };
      final shops = {'s1': _shop('s1'), 's2': _shop('s2'), 'blocked': _shop('blocked', suspended: true), 'empty': _shop('empty')};
      RebookProblem? problem(String barberId, String shopId, {String? serviceId = 'v1'}) => checkRebook(
            RebookCandidate(
                barberId: barberId, shopId: shopId, barberName: 'X', shopName: 'Y', serviceId: serviceId),
            shopById: (id) => shops[id],
            barberById: (id) => barbers[id],
            servicesForShop: (id) => services[id] ?? const [],
          ).problem;

      expect(problem('b1', 's1'), isNull);
      expect(problem('b1', 'gone'), RebookProblem.shopGone);
      expect(problem('b1', 'blocked'), RebookProblem.shopBlocked);
      expect(problem('nobody', 's1'), RebookProblem.barberGone);
      expect(problem('moved', 's1'), RebookProblem.barberGone); // now at another shop
      expect(problem('off', 's1'), RebookProblem.barberUnavailable);
      expect(problem('b1', 's1', serviceId: 'v_old'), RebookProblem.serviceGone);
      expect(problem('e1', 'empty'), RebookProblem.noServices);

      // A favourite never booked gets the shop's first service.
      final fresh = checkRebook(
        const RebookCandidate(barberId: 'b1', shopId: 's1', barberName: 'A', shopName: 'Y'),
        shopById: (id) => shops[id],
        barberById: (id) => barbers[id],
        servicesForShop: (id) => services[id] ?? const [],
      );
      expect(fresh.ok, isTrue);
      expect(fresh.service!.id, 'v1');
    });

    test('saved favourites survive bad data', () {
      const f = FavoriteBarber(barberId: 'b1', shopId: 's1', barberName: 'Dawit');
      final round = FavoriteBarber.decodeList(FavoriteBarber.encodeList([f]));
      expect(round.single.barberId, 'b1');
      expect(round.single.shopId, 's1');
      expect(round.single.barberName, 'Dawit');
      expect(FavoriteBarber.decodeList('not json'), isEmpty);
      expect(FavoriteBarber.decodeList('[1, {"b": ""}, {"b": "x"}]').single.barberId, 'x');
    });
  });

  group('repository', () {
    test('only signed-in customers have favourite barbers', () {
      expect(repo.toggleFavoriteBarber('barber_2'), isFalse);
      expect(repo.isBarberFavorite('barber_2'), isFalse);
      expect(repo.getYourBarbers(), isEmpty);

      repo.switchRole(UserRole.barbershopOwner);
      expect(repo.toggleFavoriteBarber('barber_2'), isFalse);
      expect(repo.getYourBarbers(), isEmpty);

      repo.switchRole(UserRole.customer);
      expect(repo.toggleFavoriteBarber('barber_2'), isTrue);
      expect(repo.isBarberFavorite('barber_2'), isTrue);
      expect(repo.getFavoriteBarbers().last.shopId, 'shop_1');
      expect(repo.toggleFavoriteBarber('barber_2'), isFalse);
      expect(repo.isBarberFavorite('barber_2'), isFalse);
    });

    test('favourites are saved per account and read back', () async {
      final store = MemoryFavoriteBarbersStore();
      repo.favoriteBarbersStore = store;
      addTearDown(() => repo.favoriteBarbersStore = null);

      repo.switchRole(UserRole.customer);
      final uid = repo.currentUser!.uid;
      await repo.loadFavoriteBarbers();
      expect(repo.getFavoriteBarbers(), isEmpty); // with a store, the seed's are not used
      repo.toggleFavoriteBarber('barber_2_1');
      await Future<void>.delayed(Duration.zero);
      expect(store.saved[uid], contains('barber_2_1'));

      // A fresh start (app restart): the saved list comes back.
      repo.favoriteBarbersStore = store;
      expect(repo.isBarberFavorite('barber_2_1'), isFalse); // still loading
      await repo.loadFavoriteBarbers();
      expect(repo.isBarberFavorite('barber_2_1'), isTrue);
      final fav = repo.getFavoriteBarbers().single;
      expect(fav.shopId, 'shop_2');
      expect(fav.barberName, 'Tewodros Alemu');

      // Another account on the same device has its own list.
      repo.switchRole(UserRole.admin);
      expect(repo.isBarberFavorite('barber_2_1'), isFalse);
    });

    test('Your barbers for the demo customer', () {
      repo.switchRole(UserRole.customer); // Liya (user_cust_1)
      final list = repo.getYourBarbers();
      // The seed's favourite first, with the service of the last visit.
      expect(list.first.barberId, 'barber_1');
      expect(list.first.isFavorite, isTrue);
      expect(list.first.serviceId, 'srv_1_1');
      expect(list.first.firstName, 'Yonas');
      // Then the most recent completed visit (7 days ago).
      expect(list[1].barberId, 'barber_2_1');
      expect(list[1].serviceId, 'srv_2_1');
      expect(list.where((c) => c.barberId == 'barber_1'), hasLength(1));
    });

    test('checkRebook uses live data', () async {
      repo.switchRole(UserRole.customer);
      final booking = repo.getBookingById('book_5')!;
      expect(repo.checkRebook(repo.rebookCandidateFor(booking)).ok, isTrue);

      await repo.deleteService('srv_2_1');
      final serviceGone = repo.checkRebook(repo.rebookCandidateFor(booking));
      expect(serviceGone.problem, RebookProblem.serviceGone);
      expect(serviceGone.service, isNotNull); // offered instead

      await repo.deleteBarber('barber_2_1');
      expect(repo.checkRebook(repo.rebookCandidateFor(booking)).problem, RebookProblem.barberGone);

      repo.switchRole(UserRole.admin);
      await repo.suspendShop('shop_2', 'Inspection');
      repo.switchRole(UserRole.customer);
      expect(repo.checkRebook(repo.rebookCandidateFor(booking)).problem, RebookProblem.shopBlocked);
    });
  });

  group('screens', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    /// The first free slot of [barberId] from the availability service,
    /// searching day by day like the booking flow.
    Future<DateTime?> firstFreeSlot(WidgetTester tester, String barberId, int minutes, DateTime now) async {
      final barber = repo.getBarberById(barberId)!;
      final shop = repo.getShopById(barber.shopId)!;
      return tester.runAsync<DateTime?>(() async {
        for (final d in upcomingAddisDates(nowUtc: now)) {
          if (!isBookableDate(shop: shop, barber: barber, addisDate: d, nowUtc: now)) continue;
          final busy = await repo.watchBarberBusyTimes(shop.id, barberId, d).first;
          final slots = availableSlotStarts(
              shop: shop, barber: barber, durationMinutes: minutes, addisDate: d, busy: busy, nowUtc: now);
          if (slots.isNotEmpty) return slots.first;
        }
        return null;
      });
    }

    ChoiceChip selectedServiceChip(WidgetTester tester) =>
        tester.widget<ChoiceChip>(find.byWidgetPredicate((w) => w is ChoiceChip && w.selected));

    testWidgets('home shows Your barbers with Book again with the first name', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(const CustomerHomeScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('your-barbers')), findsOneWidget);
      expect(find.text('Your barbers'), findsOneWidget);
      expect(find.text('Book again with Yonas'), findsOneWidget);
      expect(find.byKey(const ValueKey('your-barber-barber_2_1')), findsOneWidget);
      expect(find.text('Book again with Tewodros'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('signed out or staff: no row and no hearts', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          const YourBarbersSection(),
          FavoriteBarberButton(barber: repo.getBarberById('barber_1')!),
        ]),
      )));
      expect(find.byKey(const ValueKey('your-barbers')), findsNothing);
      expect(find.byKey(const ValueKey('fav-barber-barber_1')), findsNothing);

      repo.switchRole(UserRole.barber);
      await tester.pump();
      expect(find.byKey(const ValueKey('your-barbers')), findsNothing);
      expect(find.byKey(const ValueKey('fav-barber-barber_1')), findsNothing);
    });

    testWidgets('Amharic labels', (tester) async {
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(const Scaffold(body: YourBarbersSection()), locale: const Locale('am')));
      expect(find.text('የእርስዎ ፀጉር አስተካካዮች'), findsOneWidget);
      expect(find.text('ከYonas ጋር እንደገና ቀጠሮ ያዝ'), findsOneWidget);
    });

    testWidgets('Book again prefills shop, barber and last service with the next free slot', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      final uid = repo.currentUser!.uid;
      final expected = await firstFreeSlot(tester, 'barber_1', 45, _now);
      expect(expected, isNotNull);

      await tester.pumpWidget(_app(Scaffold(body: YourBarbersSection(clock: () => _now))));
      await tester.tap(find.byKey(const ValueKey('book-again-with-barber_1')));
      await tester.pumpAndSettle();

      final flow = tester.widget<BookingFlowScreen>(find.byType(BookingFlowScreen));
      expect(flow.shop.id, 'shop_1');
      expect(flow.initialBarber.id, 'barber_1');
      expect(flow.initialService.id, 'srv_1_1');
      expect(flow.suggestNextSlot, isTrue);
      expect(find.byKey(const ValueKey('rebook-suggestion')), findsOneWidget);
      expect(find.textContaining('Next free time with Yonas'), findsOneWidget);
      expect((selectedServiceChip(tester).label as Text).data, contains('Signature Skin Fade'));

      // The suggested time is already selected: one tap books it.
      final before = repo.getCustomerBookings(uid).length;
      await tester.tap(find.byKey(const ValueKey('confirm-booking')));
      await tester.pumpAndSettle();
      expect(find.text('Booking Confirmed!'), findsOneWidget);
      final mine = repo.getCustomerBookings(uid);
      expect(mine, hasLength(before + 1));
      final created = mine.firstWhere((b) => b.startAt == expected);
      expect(created.barberId, 'barber_1');
      expect(created.serviceId, 'srv_1_1');
      expect(created.shopId, 'shop_1');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no time left today: the suggestion moves to the next free day', (tester) async {
      bigScreen(tester);
      // Friday 19:50 in Addis Ababa: nothing bookable is left today.
      final late = DateTime.utc(2026, 11, 20, 16, 50);
      repo.debugClock = () => late;
      repo.switchRole(UserRole.customer);
      final expected = await firstFreeSlot(tester, 'barber_1', 45, late);
      expect(expected, isNotNull);
      expect(toAddisWallClock(expected!).day, isNot(20));

      await tester.pumpWidget(_app(Scaffold(body: YourBarbersSection(clock: () => late))));
      await tester.tap(find.byKey(const ValueKey('book-again-with-barber_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rebook-suggestion')), findsOneWidget);
      final local = toAddisWallClock(expected);
      expect(find.byKey(ValueKey('slot-${formatTimeSlot(local.hour, local.minute)}')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-booking')));
      await tester.pumpAndSettle();
      expect(repo.getCustomerBookings(repo.currentUser!.uid).where((b) => b.startAt == expected), hasLength(1));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('completed booking: heart and Book again', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(CustomerBookingsScreen(clock: () => _now)));
      await tester.pump();

      // Only completed bookings get "Book again".
      expect(find.byKey(const ValueKey('book-again-book_5')), findsOneWidget);
      expect(find.byKey(const ValueKey('book-again-book_1')), findsNothing);

      expect(repo.isBarberFavorite('barber_2_1'), isFalse);
      await tester.tap(find.byKey(const ValueKey('fav-barber-barber_2_1')).first);
      await tester.pump();
      expect(repo.isBarberFavorite('barber_2_1'), isTrue);
      expect(repo.getYourBarbers().where((c) => c.barberId == 'barber_2_1').single.isFavorite, isTrue);

      await tester.tap(find.byKey(const ValueKey('book-again-book_5')));
      await tester.pumpAndSettle();
      final flow = tester.widget<BookingFlowScreen>(find.byType(BookingFlowScreen));
      expect(flow.initialBarber.id, 'barber_2_1');
      expect(flow.initialService.id, 'srv_2_1');
      expect(find.byKey(const ValueKey('rebook-suggestion')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('service gone: friendly fallback, then pick another service', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      await repo.deleteService('srv_2_1');
      await tester.pumpWidget(_app(CustomerBookingsScreen(clock: () => _now)));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('book-again-book_5')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rebook-fallback')), findsOneWidget);
      expect(find.byKey(const ValueKey('rebook-fallback-serviceGone')), findsOneWidget);
      expect(find.textContaining('no longer offers'), findsOneWidget);
      expect(find.byType(BookingFlowScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('rebook-pick-service')));
      await tester.pumpAndSettle();
      final flow = tester.widget<BookingFlowScreen>(find.byType(BookingFlowScreen));
      expect(flow.initialBarber.id, 'barber_2_1');
      expect(flow.initialService.shopId, 'shop_2');
      expect(flow.suggestNextSlot, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('barber left the shop: fallback offers the shop page', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.customer);
      repo.toggleFavoriteBarber('barber_2_1');
      await repo.deleteBarber('barber_2_1');
      final observer = _PushRecorder();
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: CustomerBookingsScreen(clock: () => _now),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('book-again-book_5')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rebook-fallback-barberGone')), findsOneWidget);
      expect(find.textContaining('no longer works at'), findsOneWidget);

      // "Remove from favorites" is offered for a favourite who left.
      expect(find.byKey(const ValueKey('rebook-unfavorite')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rebook-unfavorite')));
      await tester.pumpAndSettle();
      expect(repo.isBarberFavorite('barber_2_1'), isFalse);
      expect(find.byKey(const ValueKey('rebook-fallback')), findsNothing);

      // "See the shop" opens the shop page (checked on the pushed route:
      // the page's map cannot be torn down by the test HTTP fake).
      await tester.tap(find.byKey(const ValueKey('book-again-book_5')));
      await tester.pumpAndSettle();
      final element = tester.element(find.byKey(const ValueKey('rebook-see-shop')));
      observer.pushed.clear();
      await tester.tap(find.byKey(const ValueKey('rebook-see-shop')));
      final page = (observer.pushed.single as MaterialPageRoute).builder(element);
      expect(page, isA<BarbershopDetailScreen>());
      expect((page as BarbershopDetailScreen).shop.id, 'shop_2');
      expect(find.byType(BookingFlowScreen), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('suspended shop: fallback, no booking flow', (tester) async {
      bigScreen(tester);
      repo.switchRole(UserRole.admin);
      await repo.suspendShop('shop_1', 'Inspection');
      repo.switchRole(UserRole.customer);
      await tester.pumpWidget(_app(Scaffold(body: YourBarbersSection(clock: () => _now))));

      await tester.tap(find.byKey(const ValueKey('book-again-with-barber_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rebook-fallback-shopBlocked')), findsOneWidget);
      expect(find.byKey(const ValueKey('rebook-see-shop')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('rebook-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rebook-fallback')), findsNothing);
      expect(find.byType(BookingFlowScreen), findsNothing);
    });
  });
}
