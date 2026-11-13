// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Crown & Blade - Barbershop Booking';

  @override
  String get brandUpper => 'CROWN & BLADE';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Done';

  @override
  String get required => 'Required';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutLower => 'Sign out';

  @override
  String get all => 'All';

  @override
  String get today => 'Today';

  @override
  String get closed => 'Closed';

  @override
  String get cityAddisAbaba => 'Addis Ababa';

  @override
  String get languageTooltip => 'Change language';

  @override
  String get serviceUnavailable => 'Service unavailable';

  @override
  String get serviceUnavailableBody =>
      'The app could not connect to its server. Please try again later.';

  @override
  String get shopNotLoaded => 'Your barbershop could not be loaded.';

  @override
  String get invalidEthiopianPhone =>
      'Enter a valid Ethiopian mobile number (09... or 07...)';

  @override
  String minutesShort(int count) {
    return '$count min';
  }

  @override
  String reviewsCount(String rating, int count) {
    return '$rating ($count reviews)';
  }

  @override
  String barbersCount(int count) {
    return '$count Barbers';
  }

  @override
  String servicesCount(int count) {
    return '$count Services';
  }

  @override
  String bookingsCount(int count) {
    return '$count Bookings';
  }

  @override
  String barberLabel(String name) {
    return 'Barber: $name';
  }

  @override
  String clientLabel(String name) {
    return 'Client: $name';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String serviceAndPrice(String service, String price) {
    return '$service • $price';
  }

  @override
  String get roleAdmin => 'Platform Admin';

  @override
  String get roleOwner => 'Shop Owner';

  @override
  String get roleBarber => 'Barber';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get subTrialing => 'Free trial';

  @override
  String get subActive => 'Active';

  @override
  String get subPastDue => 'Payment overdue';

  @override
  String get subSuspended => 'Suspended';

  @override
  String get payUnpaid => 'Unpaid';

  @override
  String get payAtShop => 'Pay at shop';

  @override
  String get payPending => 'Payment pending';

  @override
  String get payPaid => 'Paid';

  @override
  String get payRefunded => 'Refunded';

  @override
  String get recordProcessing => 'Processing';

  @override
  String get recordFailed => 'Failed';

  @override
  String get planTrial => 'Free trial';

  @override
  String get planBasic => 'Basic';

  @override
  String get planPro => 'Pro';

  @override
  String get planUnlimitedBarbers => 'Unlimited barbers';

  @override
  String planUpToBarbers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to $count barbers',
      one: 'Up to 1 barber',
    );
    return '$_temp0';
  }

  @override
  String get payErrNotSetUp =>
      'Online payments are not set up yet. Please pay at the shop.';

  @override
  String get payErrSignIn => 'Please sign in again to make a payment.';

  @override
  String get payErrNotAllowed => 'You are not allowed to make this payment.';

  @override
  String get payErrNotFound =>
      'We could not find this item. It may have been removed.';

  @override
  String get payErrAlreadyPaid => 'This booking is already paid.';

  @override
  String get payErrNetwork =>
      'Could not reach the payment service. Check your connection and try again.';

  @override
  String get payErrGeneric =>
      'The payment could not be started. Please try again.';

  @override
  String get switchRole => 'Switch Role';

  @override
  String get personaTitle => 'Switch demo role';

  @override
  String get personaSubtitle =>
      'Demo mode: switch persona instantly to try each role';

  @override
  String get personaAdminTitle => 'Platform Administrator';

  @override
  String get personaAdminSubtitle =>
      'Register barbershops, manage users & platform config';

  @override
  String get personaOwnerTitle => 'Barbershop Owner App';

  @override
  String personaOwnerSubtitle(String shop) {
    return 'Manage barbers, services & appointments ($shop)';
  }

  @override
  String get personaBarberTitle => 'Staff Barber Workspace';

  @override
  String personaBarberSubtitle(String name) {
    return '$name: manage the appointment queue & earnings';
  }

  @override
  String get personaCustomerTitle => 'Customer View';

  @override
  String get personaCustomerSubtitle =>
      'Search barbershops, pick favorite barbers & book appointments';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsUnreadTooltip(int count) {
    return 'Notifications ($count unread)';
  }

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get noNotificationsHint =>
      'Booking confirmations, changes and reminders will appear here.';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String daysAgo(int count) {
    return '$count d ago';
  }

  @override
  String get authSubtitlePhone =>
      'Sign in or create an account with your phone number';

  @override
  String authSubtitleCode(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get sendCode => 'Send Code';

  @override
  String get smsNotice =>
      'We will send you a one-time code by SMS. Standard SMS rates may apply.';

  @override
  String get verify => 'Verify';

  @override
  String get changeNumber => 'Change number';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String demoCodeNotice(String code) {
    return 'Demo mode: the code is $code';
  }

  @override
  String get demoAccounts => 'DEMO ACCOUNTS';

  @override
  String get roleAdminShort => 'Admin';

  @override
  String get welcome => 'Welcome';

  @override
  String get profileCustomerMessage =>
      'Create your account to book barbers across Addis Ababa.';

  @override
  String profileOwnerInvite(String shop) {
    return 'You have been invited to manage $shop as its owner.';
  }

  @override
  String profileBarberInvite(String shop) {
    return 'You have been invited to join $shop as a barber.';
  }

  @override
  String profileRoleInvite(String role) {
    return 'You have been invited as $role.';
  }

  @override
  String get aBarbershop => 'a barbershop';

  @override
  String get fullName => 'Full Name';

  @override
  String get continueLabel => 'Continue';

  @override
  String get useDifferentNumber => 'Use a different number';

  @override
  String get authErrInvalidPhone => 'That phone number is not valid.';

  @override
  String get authErrWrongCode => 'Wrong code. Check the SMS and try again.';

  @override
  String get authErrCodeExpired => 'The code expired. Request a new one.';

  @override
  String get authErrTooMany =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get authErrQuota => 'SMS limit reached. Please try again later.';

  @override
  String get authErrNetwork => 'No internet connection.';

  @override
  String get authErrNotEnabled =>
      'Phone sign-in is not enabled for this app yet.';

  @override
  String get authErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get adminSubtitle => 'Platform System Administration';

  @override
  String get deleteShopTitle => 'Delete Barbershop?';

  @override
  String deleteShopBody(String shop) {
    return 'Are you sure you want to remove \"$shop\" and all associated barbers, services and appointments?';
  }

  @override
  String shopRemoved(String shop) {
    return 'Removed $shop';
  }

  @override
  String get subscriptionsAndPlansTooltip => 'Subscriptions & plans';

  @override
  String tabShops(int count) {
    return 'Shops ($count)';
  }

  @override
  String tabUsers(int count) {
    return 'Users ($count)';
  }

  @override
  String tabBookings(int count) {
    return 'Bookings ($count)';
  }

  @override
  String get registerBarbershop => 'Register Barbershop';

  @override
  String get metricBarbershops => 'Barbershops';

  @override
  String get metricRegistered => 'Registered';

  @override
  String get metricActiveBarbers => 'Active Barbers';

  @override
  String get metricAcrossNetwork => 'Across network';

  @override
  String get metricPlatformSales => 'Platform Sales';

  @override
  String get metricGrossVolume => 'Gross volume';

  @override
  String get searchShopsAdminHint =>
      'Search shops by name, address, or sub-city...';

  @override
  String get filterVerifiedPartners => 'Verified Partners';

  @override
  String get filterOpenNow => 'Open Now';

  @override
  String registeredBarbershopsCount(int count) {
    return 'Registered Barbershops ($count)';
  }

  @override
  String get adminActionsEnabled => 'Admin Actions Enabled';

  @override
  String get noRegisteredShops => 'No registered barbershops found';

  @override
  String get noRegisteredShopsHint =>
      'Tap \"Register Barbershop\" to add a new shop to the platform.';

  @override
  String ownerInvitePending(String name, String phone) {
    return '$name ($phone) - invite pending';
  }

  @override
  String get notAssigned => 'Not assigned';

  @override
  String ownerLabel(String owner) {
    return 'Owner: $owner';
  }

  @override
  String get verified => 'Verified';

  @override
  String get verifyShop => 'Verify Shop';

  @override
  String get manageShopPortal => 'Manage Shop Portal';

  @override
  String get deleteShop => 'Delete Shop';

  @override
  String get roleAdministrator => 'Administrator';

  @override
  String get roleStaffBarber => 'Staff Barber';

  @override
  String assignedShop(String shop) {
    return 'Assigned Shop: $shop';
  }

  @override
  String get noPlatformAppointments => 'No platform appointments recorded yet';

  @override
  String scheduleAt(String when) {
    return 'Schedule: $when';
  }

  @override
  String get registerNewBarbershop => 'Register New Barbershop';

  @override
  String registeredShopSnack(String shop, String phone) {
    return 'Registered \"$shop\". The owner can now sign in with $phone.';
  }

  @override
  String registrationError(String error) {
    return 'Registration error: $error';
  }

  @override
  String get onboardingTitle => 'SaaS Barbershop Onboarding';

  @override
  String get onboardingSubtitle =>
      'Registers shop profile, provisions tenant owner account & sets up staff suite.';

  @override
  String get sectionShopProfile => '1. Shop Profile & Branding';

  @override
  String get shopBusinessName => 'Barbershop Business Name *';

  @override
  String get shopBusinessNameHint => 'e.g. Bole Fade Studio';

  @override
  String get shopDescription => 'Shop Description';

  @override
  String get shopTelephone => 'Shop Telephone *';

  @override
  String get coverImageUrl => 'Cover Image URL';

  @override
  String get sectionOwnerAccount => '2. Barbershop Owner Account';

  @override
  String get ownerFullName => 'Owner Full Name *';

  @override
  String get ownerMobileLogin => 'Owner Mobile Number (Login) *';

  @override
  String get ownerMobileHelper =>
      'The owner signs in with this number to manage the shop.';

  @override
  String get sectionLocation => '3. Physical Location';

  @override
  String get streetAddressRequired => 'Street Address *';

  @override
  String get streetAddressHint => 'e.g. Bole Road, Getu Building, 2nd floor';

  @override
  String get subCityRequired => 'Sub-city *';

  @override
  String get landmark => 'Landmark';

  @override
  String get landmarkHint => 'e.g. Near Edna Mall';

  @override
  String get cityRequired => 'City *';

  @override
  String get cityHint => 'e.g. Addis Ababa';

  @override
  String get sectionHours => '4. Business Hours & Verification';

  @override
  String get openingTime => 'Opening Time';

  @override
  String get closingTime => 'Closing Time';

  @override
  String get markVerifiedPartner => 'Mark as Verified Partner Shop';

  @override
  String get markVerifiedPartnerSubtitle =>
      'Verified badge displayed to all customers';

  @override
  String get registeringBarbershop => 'Registering Barbershop...';

  @override
  String get registerIntoNetwork => 'Register Barbershop into Network';

  @override
  String get presetClassicLounge => 'Classic Lounge';

  @override
  String get presetVintageWood => 'Vintage Wood';

  @override
  String get presetModernGold => 'Modern Gold';

  @override
  String get presetIndustrialStudio => 'Industrial Studio';

  @override
  String get subscriptionsAndPlans => 'Subscriptions & Plans';

  @override
  String tabPlans(int count) {
    return 'Plans ($count)';
  }

  @override
  String get noBarbershopsYet => 'No barbershops yet.';

  @override
  String statusCountChip(String status, int count) {
    return '$status: $count';
  }

  @override
  String get noEndDate => 'No end date';

  @override
  String endedDaysAgo(String date, int days) {
    return 'Ended $date (${days}d ago)';
  }

  @override
  String endsDaysLeft(String date, int days) {
    return 'Ends $date (${days}d left)';
  }

  @override
  String subscriptionUpdated(String shop) {
    return 'Subscription of $shop updated.';
  }

  @override
  String get createDefaultPlans => 'Create default plans';

  @override
  String get addPlan => 'Add plan';

  @override
  String get plansExplainer =>
      'Owners can buy the Basic and Pro plans online. Deactivating a plan hides it from owners; current subscriptions keep running.';

  @override
  String get noPlansYet => 'No plans yet.';

  @override
  String perMonth(String price) {
    return '$price / month';
  }

  @override
  String planActivated(String plan) {
    return '$plan activated.';
  }

  @override
  String planDeactivated(String plan) {
    return '$plan deactivated.';
  }

  @override
  String get defaultPlansExist => 'The default plans already exist.';

  @override
  String createdPlans(String plans) {
    return 'Created plans: $plans.';
  }

  @override
  String planSaved(String plan) {
    return 'Plan $plan saved.';
  }

  @override
  String get manualSubscriptionHint =>
      'For cash or bank payments and manual fixes.';

  @override
  String get planLabel => 'Plan';

  @override
  String get statusLabel => 'Status';

  @override
  String get endDate => 'End date';

  @override
  String get addMonthsPrefix => 'Add ';

  @override
  String monthsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' months',
      one: ' month',
    );
    return '$_temp0';
  }

  @override
  String get setADate => 'Set a date...';

  @override
  String get keepCurrentEndDate => 'Keep current end date';

  @override
  String get pickEndDate => 'Pick end date';

  @override
  String get enterValidPlanValues => 'Enter a valid price and barber limit.';

  @override
  String get newPlan => 'New plan';

  @override
  String editPlan(String plan) {
    return 'Edit $plan';
  }

  @override
  String get planId => 'Plan id';

  @override
  String get nameLabel => 'Name';

  @override
  String get pricePerMonth => 'Price per month';

  @override
  String get currencyEtb => 'ETB';

  @override
  String get maxBarbers => 'Max barbers';

  @override
  String get featuresOnePerLine => 'Features (one per line)';

  @override
  String get availableToOwners => 'Available to owners';

  @override
  String subscriptionEditTitle(String shop) {
    return 'Subscription: $shop';
  }

  @override
  String get invalidContactPhone =>
      'Enter a valid Ethiopian phone number (09..., 07... or 011...)';

  @override
  String get shopPhoneHint => '09XX XXX XXX or 011 XXX XXXX';

  @override
  String get ownerNameHint => 'e.g. Abebe Kebede';

  @override
  String get barberWorkspace => 'Barber Workspace';

  @override
  String get noBarberProfile => 'No Barber profile linked to this account.';

  @override
  String tabConfirmed(int count) {
    return 'Confirmed ($count)';
  }

  @override
  String tabInProgress(int count) {
    return 'In Progress ($count)';
  }

  @override
  String tabCompleted(int count) {
    return 'Completed ($count)';
  }

  @override
  String tabAll(int count) {
    return 'All ($count)';
  }

  @override
  String get emptyConfirmed => 'No confirmed appointments scheduled.';

  @override
  String get emptyInProgress => 'No appointments currently in progress.';

  @override
  String get emptyCompleted => 'No completed appointments yet today.';

  @override
  String get emptyHistory => 'No booking history found.';

  @override
  String get statusOnDuty => 'Status: On Duty (Accepting Clients)';

  @override
  String get statusOnBreak => 'Status: On Break / Away';

  @override
  String get metricAppointments => 'Appointments';

  @override
  String get metricInChair => 'In Chair';

  @override
  String get metricEarnings => 'Earnings';

  @override
  String get viewWeeklySchedule => 'View Weekly Schedule & Calendar';

  @override
  String get viewWeeklyScheduleSubtitle =>
      'Inspect daily time slots, shifts, and bookings timeline';

  @override
  String get noShow => 'No-Show';

  @override
  String get startService => 'Start Service';

  @override
  String get markCompleted => 'Mark Completed';

  @override
  String get serviceCompleted => 'Service Completed';

  @override
  String get appointmentCancelled => 'Appointment Cancelled';

  @override
  String statusUpdateFailed(String error) {
    return 'Could not update the appointment: $error';
  }

  @override
  String barberScheduleTitle(String name) {
    return '$name • Schedule';
  }

  @override
  String get shopHoursUnavailable => 'Shop hours unavailable';

  @override
  String get noWorkingHours => 'No working hours set';

  @override
  String workingHoursLine(String range, String days) {
    return 'Working hours: $range • $days';
  }

  @override
  String notTakingNewBookings(String text) {
    return '$text • Not taking new bookings';
  }

  @override
  String dayOff(String day) {
    return 'Day off - no working hours on $day.';
  }

  @override
  String get busy => 'Busy';

  @override
  String get availableSlot => 'Available Slot';

  @override
  String rangeWithDuration(String range, int minutes) {
    return '$range ($minutes min)';
  }

  @override
  String get searchShopsHint => 'Search barbershops by name or neighborhood...';

  @override
  String get premierTalent => 'PREMIER TALENT';

  @override
  String get bookWithMasters => 'Book Directly with Master Barbers';

  @override
  String get bookWithMastersSubtitle =>
      'Browse verified specialists, view portfolios & reserve seats.';

  @override
  String get findBarbers => 'Find Barbers';

  @override
  String get subCityFilterLabel => 'Sub-city:';

  @override
  String get catFades => 'Fades & Tapers';

  @override
  String get catBeard => 'Beard Sculpt';

  @override
  String get catShave => 'Hot Shave';

  @override
  String get catKids => 'Kids & VIP';

  @override
  String featuredBarbershops(int count) {
    return 'Featured Barbershops ($count)';
  }

  @override
  String get allLocations => 'All Locations';

  @override
  String noShopsMatching(String query) {
    return 'No barbershops found matching \"$query\"';
  }

  @override
  String get verifiedBadge => 'VERIFIED';

  @override
  String get viewServicesAndBook => 'View Services & Book';

  @override
  String get navBarbershops => 'Barbershops';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get verifiedPartnerBadge => 'VERIFIED PARTNER';

  @override
  String get locationAndHours => 'Location & Hours';

  @override
  String hoursWithDays(String hours, String days) {
    return '$hours ($days)';
  }

  @override
  String ourMasterBarbers(int count) {
    return 'Our Master Barbers ($count)';
  }

  @override
  String selectAService(int count) {
    return 'Select a Service ($count)';
  }

  @override
  String get chooseAService => 'Choose a service';

  @override
  String get selectToSeePrice => 'Select to see price';

  @override
  String get shopHasNoServicesOrBarbers =>
      'This shop does not have active services or barbers.';

  @override
  String get bookSlot => 'Book Slot';

  @override
  String get selectAvailableTime => 'Please select an available time.';

  @override
  String get slotJustTaken => 'Slot just taken';

  @override
  String get slotJustTakenBody =>
      'Someone else booked this time a moment ago.\n\nThe list of times has been refreshed.';

  @override
  String get pickAnotherTime => 'Pick another time';

  @override
  String get bookingConfirmed => 'Booking Confirmed!';

  @override
  String seatReserved(String barber) {
    return 'Your seat with $barber is reserved.';
  }

  @override
  String get receiptShop => 'Shop';

  @override
  String get receiptService => 'Service';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptTime => 'Time';

  @override
  String get receiptTotal => 'Total';

  @override
  String payAmountNow(String amount) {
    return 'Pay $amount now';
  }

  @override
  String get payAtShopInstead => 'Pay at the shop instead';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get confirmAppointment => 'Confirm Appointment';

  @override
  String get stepChooseBarber => '1. Choose Barber';

  @override
  String get stepSelectedService => '2. Selected Service';

  @override
  String get stepSelectDate => '3. Select Date';

  @override
  String get stepAvailableTimes => '4. Available Times';

  @override
  String durationAddisTime(int minutes) {
    return '$minutes min • Addis Ababa time';
  }

  @override
  String get unavailable => 'Unavailable';

  @override
  String serviceChip(String service, String price, int minutes) {
    return '$service ($price • $minutes min)';
  }

  @override
  String get shopNotTakingBookings =>
      'This barbershop is not taking bookings right now.';

  @override
  String barberNotTakingBookings(String barber) {
    return '$barber is not taking bookings right now. Please choose another barber.';
  }

  @override
  String barberDayOff(String barber) {
    return '$barber does not work on this day. Please pick another date.';
  }

  @override
  String get noFreeTimes =>
      'No free times left on this day. Please pick another date.';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get totalPayAtSalon => 'Total to Pay at Salon:';

  @override
  String get totalPayOnline => 'Total (pay online):';

  @override
  String get selectATime => 'Select a time';

  @override
  String get payAtShopCash => 'Pay at shop (cash)';

  @override
  String get payAfterAppointment => 'Pay after your appointment';

  @override
  String get payNowWithChapa => 'Pay now with Chapa';

  @override
  String get chapaMethods => 'telebirr, CBE Birr or card';

  @override
  String get myAppointments => 'My Appointments';

  @override
  String get noBookingsYet => 'No bookings yet';

  @override
  String get noBookingsHint =>
      'Explore top barbershops and book your first slot.';

  @override
  String get finishPayment => 'Finish payment';

  @override
  String get payNow => 'Pay now';

  @override
  String get cancelBooking => 'Cancel Booking';

  @override
  String cancelBookingFailed(String error) {
    return 'Could not cancel the booking: $error';
  }

  @override
  String get specAll => 'All';

  @override
  String get specSkinFade => 'Skin Fade';

  @override
  String get specBeardSculpting => 'Beard Sculpting';

  @override
  String get specHotShave => 'Hot Shave';

  @override
  String get specScissorCut => 'Scissor Cut';

  @override
  String get specExecutiveStyling => 'Executive Styling';

  @override
  String get findTopBarbers => 'Find Top Barbers';

  @override
  String get searchBarbersHint =>
      'Search by barber name, specialty, or shop...';

  @override
  String noBarbersMatching(String query) {
    return 'No barbers found matching \"$query\"';
  }

  @override
  String bookWith(String name) {
    return 'Book with $name';
  }

  @override
  String get noServicesAtShop => 'No services available at this shop yet.';

  @override
  String get partnerPortal => 'Partner Business Portal';

  @override
  String get customizableApp => 'Your Customizable Barbershop App';

  @override
  String get customizableAppSubtitle =>
      'Branding, cover photo, opening hours & location';

  @override
  String get customize => 'Customize';

  @override
  String servicesButton(int count) {
    return 'Services ($count)';
  }

  @override
  String manageBarbersButton(int count) {
    return 'Manage Barbers ($count)';
  }

  @override
  String get subscriptionAndBilling => 'Subscription & billing';

  @override
  String get editInfo => 'Edit Info';

  @override
  String get metricBookings => 'Bookings';

  @override
  String activeCount(int count) {
    return '$count active';
  }

  @override
  String get metricEstRevenue => 'Est. Revenue';

  @override
  String get metricGrossSales => 'Gross sales';

  @override
  String get appointmentsSchedule => 'Appointments Schedule';

  @override
  String get noAppointmentsFound => 'No appointments found';

  @override
  String get cancelSlot => 'Cancel Slot';

  @override
  String get shopSettingsSaved =>
      'Customized shop settings saved successfully!';

  @override
  String get customizeMyBarbershop => 'Customize My Barbershop';

  @override
  String get preview => 'Preview';

  @override
  String get savingUpdates => 'Saving Updates...';

  @override
  String get publishCustomizations => 'Publish Shop Customizations';

  @override
  String get brandProfile => 'Barbershop Brand Profile';

  @override
  String get brandProfileHint =>
      'Changes made here instantly appear in the customer booking experience.';

  @override
  String get sectionBranding => 'Barbershop Branding & Info';

  @override
  String get barbershopNameRequired => 'Barbershop Name *';

  @override
  String get brandBio => 'Brand Bio & Story';

  @override
  String get businessPhone => 'Business Phone Number';

  @override
  String get themePresets => 'Quick Theme Aesthetic Presets:';

  @override
  String get coverPhotoUrl => 'Cover Photo Image URL';

  @override
  String get sectionAddress => 'Physical Location & Address';

  @override
  String get streetAddress => 'Street Address';

  @override
  String get subCity => 'Sub-city';

  @override
  String get city => 'City';

  @override
  String get sectionSchedule => 'Business Schedule & Hours';

  @override
  String get openingHour => 'Opening Hour';

  @override
  String get closingHour => 'Closing Hour';

  @override
  String get openWorkingDays => 'Open Working Days:';

  @override
  String get presetRoyalGold => 'Royal Gold & Noir';

  @override
  String get presetVintageGentleman => 'Vintage Gentleman';

  @override
  String get presetEmpireLuxury => 'Empire Luxury';

  @override
  String get presetUrbanIndustrial => 'Urban Industrial';

  @override
  String saveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get defaultBarberTitle => 'Stylist & Fade Specialist';

  @override
  String get addBarberToShop => 'Add Barber to Shop';

  @override
  String get barberFullName => 'Barber Full Name';

  @override
  String get specialization => 'Specialization (e.g. Master Barber)';

  @override
  String get mobileForLogin => 'Mobile Number (for login)';

  @override
  String get barberPhoneHelper =>
      'Optional. The barber signs in with this number.';

  @override
  String get selectAvatar => 'Select Avatar Portrait:';

  @override
  String get invalidPhoneShort => 'Enter a valid number (09... or 07...)';

  @override
  String get addBarberFailed => 'Could not add barber. Please try again.';

  @override
  String get addBarber => 'Add Barber';

  @override
  String get removeBarberTitle => 'Remove Barber?';

  @override
  String removeBarberBody(String name) {
    return 'Are you sure you want to remove \"$name\" from this barbershop?';
  }

  @override
  String get manageBarbersStaff => 'Manage Barbers & Staff';

  @override
  String get noBarbersYet => 'No barbers added yet';

  @override
  String get noBarbersHint =>
      'Add barbers so clients can book appointments with them.';

  @override
  String loginInvitePending(String phone) {
    return 'Login invite pending: $phone';
  }

  @override
  String get removeBarber => 'Remove Barber';

  @override
  String get addNewService => 'Add New Service';

  @override
  String get serviceNameHint => 'Service Name (e.g. Beard Trim)';

  @override
  String get description => 'Description';

  @override
  String get priceEtb => 'Price (ETB)';

  @override
  String get durationMins => 'Duration (mins)';

  @override
  String get addService => 'Add Service';

  @override
  String get manageServicesPricing => 'Manage Services & Pricing';

  @override
  String get noServicesYet => 'No services created yet';

  @override
  String get noServicesHint =>
      'Tap \"Add Service\" below to publish your salon pricing.';

  @override
  String get invalidServiceValues =>
      'Enter a name, a price in ETB and a duration in minutes.';

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String get plansTitle => 'Plans';

  @override
  String get plansIntro =>
      'Pay monthly with telebirr, CBE Birr or card through Chapa. Paying early adds a month to your current end date.';

  @override
  String get noPlansAvailable =>
      'No plans are available right now. Please contact Crown & Blade support.';

  @override
  String get paymentHistory => 'Payment history';

  @override
  String get noEndDateSet => 'No end date set';

  @override
  String endedAgo(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ended $date ($count days ago)',
      one: 'Ended $date (1 day ago)',
    );
    return '$_temp0';
  }

  @override
  String trialEndsOn(String date) {
    return 'Trial ends $date';
  }

  @override
  String renewsBy(String date) {
    return 'Renews by $date';
  }

  @override
  String endsToday(String text) {
    return '$text (today)';
  }

  @override
  String daysLeftSuffix(int count, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$text ($count days left)',
      one: '$text (1 day left)',
    );
    return '$_temp0';
  }

  @override
  String barbersUsage(int count) {
    return 'Barbers: $count';
  }

  @override
  String barbersUsageUnlimited(int count) {
    return 'Barbers: $count (unlimited)';
  }

  @override
  String barbersUsageOf(int count, int max) {
    return 'Barbers: $count of $max';
  }

  @override
  String planTooSmall(int count, int max) {
    return 'Your shop has $count barbers; this plan allows $max.';
  }

  @override
  String get renewWithChapa => 'Renew with Chapa';

  @override
  String get payWithChapa => 'Pay with Chapa';

  @override
  String get paymentHistoryUnavailable => 'Payment history is unavailable.';

  @override
  String get noSubscriptionPayments => 'No subscription payments yet.';

  @override
  String untilDate(String date) {
    return 'until $date';
  }

  @override
  String planOneMonth(String plan) {
    return '$plan plan - 1 month';
  }

  @override
  String get preparingCheckout => 'Preparing secure checkout...';

  @override
  String get paymentProblem => 'Payment problem';

  @override
  String get paymentNotCompleted =>
      'Payment not completed yet. If you paid, it will show as paid shortly.';

  @override
  String subscriptionActiveUntilSentence(String date) {
    return ' Subscription active until $date.';
  }

  @override
  String paymentReceivedAmount(String amount, String extra) {
    return 'Payment received: $amount.$extra';
  }

  @override
  String get paymentFailedRetry =>
      'Payment failed or was cancelled. No money was taken. You can try again.';

  @override
  String get chapaCheckoutDemo => 'Chapa checkout (demo)';

  @override
  String get chapaDemoNotice =>
      'Demo mode: no money moves. Choose Pay to simulate a successful payment.';

  @override
  String get cancelPayment => 'Cancel payment';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get chapaNotConfirmedYet =>
      'Chapa has not confirmed the payment yet. Finish it in the browser, then check again.';

  @override
  String get completeYourPayment => 'Complete your payment';

  @override
  String completePaymentBody(String amount) {
    return 'Pay $amount on the Chapa page that opened (telebirr, CBE Birr or card), then come back here.';
  }

  @override
  String get payLater => 'Pay later';

  @override
  String get openAgain => 'Open again';

  @override
  String get ivePaid => 'I\'ve paid';

  @override
  String get couldNotCheckPayment => 'Could not check the payment';

  @override
  String get checkingPayment => 'Checking your payment with Chapa...';

  @override
  String get subscriptionIsActive => 'Your subscription is active.';

  @override
  String subscriptionActiveUntil(String date) {
    return 'Your subscription is active until $date.';
  }

  @override
  String get bookingIsPaid => 'Your booking is paid.';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String amountThen(String amount, String what) {
    return '$amount. $what';
  }

  @override
  String get stillProcessing => 'Still processing';

  @override
  String get stillProcessingBody =>
      'Chapa has not confirmed this payment yet. It will update automatically once it does.';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get noMoneyTaken => 'No money was taken. You can try again.';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get checkAgain => 'Check again';

  @override
  String get bannerSuspended =>
      'Your shop is suspended: customers cannot see or book it. Pay your subscription to reactivate it.';

  @override
  String get bannerOverdueSoon =>
      'Your subscription payment is overdue. The shop will be suspended soon unless you pay.';

  @override
  String get bannerOverdueToday =>
      'Your subscription payment is overdue. The shop will be suspended today unless you pay.';

  @override
  String bannerOverdueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your subscription payment is overdue. The shop will be suspended in $count days unless you pay.',
      one:
          'Your subscription payment is overdue. The shop will be suspended in 1 day unless you pay.',
    );
    return '$_temp0';
  }

  @override
  String get bannerTrialEndsToday =>
      'Your free trial ends today. Pay now to keep taking bookings.';

  @override
  String get bannerSubEndsToday =>
      'Your subscription ends today. Pay now to keep taking bookings.';

  @override
  String bannerTrialEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your free trial ends in $count days. Pay now to keep taking bookings.',
      one: 'Your free trial ends in 1 day. Pay now to keep taking bookings.',
    );
    return '$_temp0';
  }

  @override
  String bannerSubEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your subscription ends in $count days. Pay now to keep taking bookings.',
      one: 'Your subscription ends in 1 day. Pay now to keep taking bookings.',
    );
    return '$_temp0';
  }

  @override
  String get reactivate => 'Reactivate';

  @override
  String get cardMethod => 'Card';
}
