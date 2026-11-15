// End-to-end walkthrough (local mode, demo seed) of the three owner/barber
// upgrades working together:
//   shop applications -> barber acceptance -> commission + payouts.
//
// customer applies -> admin approves -> applicant becomes the owner;
// owner invites a barber and turns on acceptance -> customer books (pending)
// -> barber accepts; owner sets commission -> barber completes the booking
// -> owner records a payout -> barber sees a balance of 0.

import 'dart:convert';
import 'dart:io';

import 'package:barbershop_booking/features/applications/shop_applications_service.dart';
import 'package:barbershop_booking/features/payouts/payouts_manager.dart';
import 'package:barbershop_booking/models/booking_model.dart';
import 'package:barbershop_booking/models/user_model.dart';
import 'package:barbershop_booking/services/app_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Friday 20 Nov 2026, 10:00 in Addis Ababa.
final _now = DateTime.utc(2026, 11, 20, 7);

// Monday 23 Nov 2026, 10:00 Addis.
final _start = DateTime.utc(2026, 11, 23, 7);

const _applicantEmail = 'customer3@example.com';
const _barberEmail = 'walkthrough.barber@example.com';

void main() {
  setUpAll(() => HttpOverrides.global = TestHttpOverrides());
  tearDown(() {
    ShopApplicationsService.instance = null;
    PayoutsManager.instance = null;
  });

  test('apply -> approve -> owner; acceptance; commission and payout settle the balance', () async {
    // The clock moves forward during the walkthrough (booking is completed
    // after its start), so both the repository and the payouts manager read
    // this variable.
    var clock = _now;
    loadTestSeed(now: _now);
    final repo = AppRepository.instance;
    repo.debugClock = () => clock;

    final applications = ShopApplicationsService(
      repository: repo,
      local: LocalShopApplicationStore()
        ..loadSeedJson(jsonDecode(readSeedJson()) as Map<String, dynamic>, now: _now),
    );
    ShopApplicationsService.instance = applications;
    final payouts = PayoutsManager(local: LocalPayoutStore(), clock: () => clock);
    PayoutsManager.instance = payouts;

    // 1. A customer applies to list their shop.
    await signInWithGoogleAs(_applicantEmail);
    final applicant = repo.currentUser!;
    expect(applicant.role, UserRole.customer);
    final app = await applications.submit(
      ownerName: 'Rahel Desta',
      shopName: 'Gerji Sharp Cuts',
      address: 'Gerji, behind Unity University',
      subCity: 'Yeka',
      phone: '0911 22 33 44',
    );
    expect(app.isPending, isTrue);
    expect(app.uid, applicant.uid);

    // 2. The admin approves it: a new shop with an owner invite.
    await signInWithGoogleAs('admin@example.com');
    final pending = await applications.watchForAdmin().first;
    expect(pending.map((a) => a.uid), contains(applicant.uid));
    final shopId = await applications.approve(applicant.uid);
    expect(repo.getShopById(shopId)!.name, 'Gerji Sharp Cuts');
    expect(repo.getPendingOwnerInvite(shopId)!.email, _applicantEmail);

    // 3. The applicant is now the owner of that shop (same uid).
    await signInWithGoogleAs(_applicantEmail);
    expect(repo.currentUser!.uid, applicant.uid);
    expect(repo.currentUser!.role, UserRole.barbershopOwner);
    expect(repo.currentUser!.shopId, shopId);
    expect(repo.getShopById(shopId)!.ownerId, applicant.uid);

    // 4. The owner invites a barber and turns on booking acceptance.
    await repo.addBarber(shopId: shopId, name: 'Abel Girma', title: 'Barber', email: _barberEmail);
    final barber = repo.getBarbersForShop(shopId).singleWhere((b) => b.name == 'Abel Girma');
    final shop = repo.getShopById(shopId)!;
    await repo.updateShopPolicy(shopId,
        cancellationCutoffHours: shop.cancellationCutoffHours,
        maxReschedules: shop.maxReschedules,
        requireBarberAcceptance: true);
    expect(repo.getShopById(shopId)!.requireBarberAcceptance, isTrue);

    // 5. A customer books: the booking waits for the barber.
    await signInWithGoogleAs('liya@example.com'); // user_cust_1
    expect(repo.currentUser!.role, UserRole.customer);
    final customerUid = repo.currentUser!.uid;
    final service = repo.getServicesForShop(shopId).first;
    final booking = await repo.createBooking(
      shopId: shopId,
      shopName: shop.name,
      barberId: barber.id,
      barberName: barber.name,
      serviceId: service.id,
      serviceName: service.name,
      price: 300,
      date: DateTime(2026, 11, 23),
      timeSlot: '10:00 AM',
      startAt: _start,
      durationMinutes: service.durationMinutes,
    );
    expect(booking.status, BookingStatus.pending);
    expect(booking.customerId, customerUid);

    // 6. The invited barber signs in for the first time (profile setup takes
    // the role from the invite) and accepts the request.
    await signInWithGoogleAs(_barberEmail);
    expect(repo.authStatus, AuthStatus.needsProfile);
    await repo.completeProfile(name: 'Abel Girma', phone: '0912 34 56 78');
    expect(repo.currentUser!.role, UserRole.barber);
    expect(repo.currentUser!.barberId, barber.id);
    expect(repo.getBookingRequestsForBarber(barber.id).map((b) => b.id), [booking.id]);
    await repo.acceptBookingRequest(booking.id);
    expect(repo.getBookingById(booking.id)!.status, BookingStatus.confirmed);
    expect(repo.getBookingById(booking.id)!.acceptedAt, _now);
    expect(repo.getBookingRequestsForBarber(barber.id), isEmpty);

    // 7. The owner sets the barber's commission to 60%.
    await signInWithGoogleAs(_applicantEmail);
    await payouts.setCommission(barber.id, 60);
    expect(repo.getBarberById(barber.id)!.commissionPercent, 60);

    // 8. After the appointment the barber marks it completed.
    clock = _start.add(const Duration(hours: 1));
    await signInWithGoogleAs(_barberEmail);
    await repo.updateBookingStatus(booking.id, BookingStatus.completed);
    expect(repo.getBookingById(booking.id)!.status, BookingStatus.completed);

    final month = payouts.currentMonth();
    BarberPayoutSummary row(List<Payout> paid) => payouts
        .summarizeMonth(shopId, month, bookings: payouts.cachedMonthBookings(shopId, month), payouts: paid)
        .singleWhere((r) => r.barberId == barber.id);

    // 9. The owner sees 180 Birr owed (60% of 300) and pays it out.
    await signInWithGoogleAs(_applicantEmail);
    final before = row(await payouts.watchShopPayouts(shopId, month).first);
    expect(before.completedJobs, 1);
    expect(before.gross, 300);
    expect(before.share, 180);
    expect(before.balance, 180);
    final payout = await payouts.recordPayout(
      shopId: shopId,
      barberId: barber.id,
      amount: before.balance.toDouble(),
      method: PayoutMethod.telebirr,
    );
    expect(payout.createdBy, applicant.uid);

    // 10. The barber sees the payout and a balance of 0.
    await signInWithGoogleAs(_barberEmail);
    final mine = await payouts.watchBarberPayouts(repo.getBarberById(barber.id)!).first;
    expect(mine.map((p) => p.id), [payout.id]);
    final after = payouts
        .summarizeMonth(shopId, month,
            bookings: payouts.cachedMonthBookings(shopId, month, barberId: barber.id), payouts: mine)
        .singleWhere((r) => r.barberId == barber.id);
    expect(after.paid, 180);
    expect(after.balance, 0);
  });
}
