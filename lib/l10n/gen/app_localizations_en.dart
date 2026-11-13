// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get queueTitle => 'Walk-in queue';

  @override
  String queueDashboardSubtitle(int waiting, int serving) {
    return '$waiting waiting · $serving in the chair';
  }

  @override
  String queueSummaryWaiting(int count, int minutes) {
    return '$count waiting, about $minutes min';
  }

  @override
  String get queueSummaryEmpty => 'No one waiting - walk right in';

  @override
  String get queueJoin => 'Join queue';

  @override
  String get queueLeave => 'Leave queue';

  @override
  String queueLeaveConfirm(String shop) {
    return 'Leave the queue at $shop?';
  }

  @override
  String queueYourPosition(int position, int minutes) {
    return 'You are number $position in line, about $minutes min';
  }

  @override
  String get queueYouAreNext => 'You\'re next! Please be at the shop.';

  @override
  String queueYourTurn(String barber) {
    return 'It\'s your turn - $barber is ready for you';
  }

  @override
  String get queueYourTurnAnyBarber => 'It\'s your turn - please come in';

  @override
  String get queueJoined => 'You joined the queue.';

  @override
  String get queueLeftMessage => 'You left the queue.';

  @override
  String get queueSignInToJoin => 'Sign in to join the queue.';

  @override
  String queueJoinTitle(String shop) {
    return 'Join the queue at $shop';
  }

  @override
  String get queueJoinBody =>
      'We\'ll hold your place in line and tell you when you\'re next.';

  @override
  String queueWaitingHeader(int count) {
    return 'Waiting ($count)';
  }

  @override
  String queueServingHeader(int count) {
    return 'In the chair ($count)';
  }

  @override
  String get queueBarbersHeader => 'Barbers right now';

  @override
  String get queueEmpty => 'No one is waiting.';

  @override
  String get queueAddWalkIn => 'Add walk-in';

  @override
  String get queueNameLabel => 'Customer name';

  @override
  String get queuePhoneLabel => 'Phone (optional)';

  @override
  String get queueServiceLabel => 'Service (optional)';

  @override
  String get queuePreferredBarberLabel => 'Preferred barber (optional)';

  @override
  String get queueAnyBarber => 'Any barber';

  @override
  String get queueNoService => 'Not chosen';

  @override
  String get queueAddButton => 'Add to queue';

  @override
  String get queueCallNext => 'Call next';

  @override
  String queueCallNextFor(String barber) {
    return 'Call next for $barber';
  }

  @override
  String get queueStart => 'Start';

  @override
  String get queueFinish => 'Finish';

  @override
  String get queueMarkLeft => 'Left';

  @override
  String queueChooseBarber(String name) {
    return 'Who will serve $name?';
  }

  @override
  String queueBarberServing(String name) {
    return 'Serving $name';
  }

  @override
  String get queueBarberFree => 'Free';

  @override
  String get queueBarberOff => 'Not taking customers';

  @override
  String queueWaitAbout(int minutes) {
    return 'about $minutes min';
  }

  @override
  String get queueNextUp => 'Next';

  @override
  String queuePrefers(String barber) {
    return 'Prefers $barber';
  }

  @override
  String get queueRemoteBadge => 'Joined in app';

  @override
  String queueJoinedAt(String time) {
    return 'Joined $time';
  }

  @override
  String queueServingSince(String time) {
    return 'Since $time';
  }

  @override
  String queueNobodyForBarber(String barber) {
    return 'No one is waiting for $barber.';
  }

  @override
  String queueNowServing(String barber, String name) {
    return '$barber is now serving $name.';
  }

  @override
  String queueActionFailed(String error) {
    return 'Could not update the queue: $error';
  }

  @override
  String get queueErrNotStaff =>
      'Only this shop\'s owner and barbers can manage its queue.';

  @override
  String get queueErrCustomersOnly =>
      'Only customers can join the queue from the app.';

  @override
  String queueErrNameRequired(int max) {
    return 'Enter a name (up to $max characters).';
  }

  @override
  String queueErrBarberBusy(String name) {
    return '$name is already serving someone. Finish that first.';
  }

  @override
  String get queueErrNotWaiting => 'This person is no longer waiting.';

  @override
  String get queueErrNotServing => 'This person is not being served.';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsOpenButton => 'Reports & clients';

  @override
  String get reportsOverviewTab => 'Overview';

  @override
  String get reportsClientsTab => 'Clients';

  @override
  String get reportsMonthLabel => 'Month';

  @override
  String get reportsBookings => 'Bookings';

  @override
  String get reportsCompleted => 'Completed';

  @override
  String get reportsCancelled => 'Cancelled';

  @override
  String get reportsNoShows => 'No-shows';

  @override
  String get reportsRevenue => 'Revenue';

  @override
  String get reportsRevenueTrend => 'Revenue, last 6 months';

  @override
  String get reportsTopServices => 'Top services';

  @override
  String get reportsBarberPerformance => 'Barber performance';

  @override
  String reportsCompletedCount(int count) {
    return '$count completed';
  }

  @override
  String get reportsNoBookingsMonth => 'No bookings in this month.';

  @override
  String get reportsNoCompletedMonth =>
      'No completed bookings in this month yet.';

  @override
  String get reportsNoClients => 'No clients yet.';

  @override
  String reportsClientVisits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
    );
    return '$_temp0';
  }

  @override
  String reportsClientNoShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no-shows',
      one: '1 no-show',
    );
    return '$_temp0';
  }

  @override
  String reportsClientCancelled(int count) {
    return '$count cancelled';
  }

  @override
  String reportsLastVisit(String date) {
    return 'Last visit $date';
  }

  @override
  String get reportsNoVisitYet => 'No completed visit yet';

  @override
  String get reportsLoadFailed =>
      'Could not load reports. Check your connection and try again.';

  @override
  String get reportsRetry => 'Try again';

  @override
  String get reportsUpdatedNote =>
      'Figures update a few seconds after each booking change.';

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
  String get statusNoShow => 'No-show';

  @override
  String get rescheduleAction => 'Reschedule';

  @override
  String get rescheduleTitle => 'Pick a new time';

  @override
  String rescheduleCurrent(String when) {
    return 'Current time: $when';
  }

  @override
  String get rescheduleConfirm => 'Move booking';

  @override
  String rescheduleDone(String when) {
    return 'Your booking was moved to $when.';
  }

  @override
  String rescheduleLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes left',
      one: '1 change left',
      zero: 'No more changes allowed',
    );
    return '$_temp0';
  }

  @override
  String get rescheduledBadge => 'Rescheduled';

  @override
  String reschedulePolicyNote(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours before',
      one: '1 hour before',
      zero: 'the start time',
    );
    return 'Free changes and cancellation until $_temp0.';
  }

  @override
  String get rescheduleCallShop =>
      'Too late to change this booking in the app. Please call the shop.';

  @override
  String get rescheduleErrNotChangeable =>
      'This booking can no longer be changed.';

  @override
  String rescheduleErrCancelCutoff(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'You can cancel up to $_temp0 before your appointment. Please call the shop.';
  }

  @override
  String rescheduleErrCutoff(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'You can move a booking up to $_temp0 before it starts. Please call the shop.';
  }

  @override
  String rescheduleErrLimit(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max times, the most this shop allows',
      one: 'once, the most this shop allows',
      zero: '- this shop does not allow changes',
    );
    return 'This booking has already been moved $_temp0.';
  }

  @override
  String get rescheduleErrSameTime =>
      'Pick a time different from your current one.';

  @override
  String get noShowAction => 'No-show';

  @override
  String get noShowConfirmTitle => 'Mark as no-show?';

  @override
  String noShowConfirmBody(String name) {
    return '$name did not come to this appointment. The time stays blocked.';
  }

  @override
  String get noShowErrTooEarly =>
      'You can mark a no-show only after the appointment start time.';

  @override
  String get policySectionTitle => 'Booking policy';

  @override
  String get policyCutoffLabel => 'Cancellation cutoff';

  @override
  String get policyCutoffHelp =>
      'Customers cannot cancel or move a booking within this many hours of the start. You and your barbers can still cancel.';

  @override
  String policyHoursValue(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours before',
      one: '1 hour before',
      zero: 'Until the start',
    );
    return '$_temp0';
  }

  @override
  String get policyMaxReschedulesLabel => 'Changes allowed per booking';

  @override
  String policyMaxReschedulesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'Once',
      zero: 'No changes',
    );
    return '$_temp0';
  }

  @override
  String get policySave => 'Save policy';

  @override
  String get policySaved => 'Booking policy saved.';

  @override
  String policyErrCutoff(int max) {
    return 'The cancellation cutoff must be between 0 and $max hours.';
  }

  @override
  String policyErrMaxReschedules(int max) {
    return 'Changes allowed must be between 0 and $max.';
  }

  @override
  String get timeOffTitle => 'Time off';

  @override
  String get timeOffAdd => 'Add time off';

  @override
  String get timeOffWholeDay => 'Whole day';

  @override
  String get timeOffHours => 'Some hours';

  @override
  String get timeOffDay => 'Day';

  @override
  String get timeOffFrom => 'From';

  @override
  String get timeOffTo => 'To';

  @override
  String get timeOffReasonLabel => 'Note (optional)';

  @override
  String get timeOffEmpty => 'No time off planned.';

  @override
  String get timeOffSaved =>
      'Time off added. Customers can no longer book these times.';

  @override
  String get timeOffRemove => 'Remove time off';

  @override
  String get timeOffRemoved => 'Time off removed.';

  @override
  String get timeOffRemoveConfirm =>
      'Remove this time off? Customers can book these times again.';

  @override
  String timeOffRange(String day, String from, String to) {
    return '$day, $from - $to';
  }

  @override
  String timeOffNotWorking(String name) {
    return '$name does not work on this day.';
  }

  @override
  String get timeOffSlotLabel => 'Time off';

  @override
  String get timeOffErrRange =>
      'Pick a range within one day, ending after it starts.';

  @override
  String get timeOffErrPast => 'Time off must end in the future.';

  @override
  String timeOffErrReasonTooLong(int max) {
    return 'The note can be at most $max characters.';
  }

  @override
  String get timeOffErrConflict =>
      'This time overlaps a booking or other time off. Move or cancel that booking first.';

  @override
  String get timeOffErrNotAllowed =>
      'You can only manage time off for your own schedule.';

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
  String get mobileNumber => 'Mobile Number';

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
  String get authErrNetwork => 'No internet connection.';

  @override
  String get authErrNotEnabled =>
      'Google sign-in is not enabled for this app yet.';

  @override
  String get authErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get authSubtitle => 'Log in or create an account';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get googleSignInNotice =>
      'We only use your name and email address to manage your bookings.';

  @override
  String demoContinueAs(String name) {
    return 'Continue as $name';
  }

  @override
  String get demoGoogleNotice => 'Demo mode: no real Google account is used.';

  @override
  String get useDifferentAccount => 'Use a different account';

  @override
  String get profilePhoneHelper => 'For SMS booking reminders and payments.';

  @override
  String get authErrPopupBlocked =>
      'The sign-in window was blocked. Allow pop-ups for this site and try again.';

  @override
  String get authErrAccountExists =>
      'An account with this email already uses a different sign-in method.';

  @override
  String get authErrUnauthorizedDomain =>
      'This web address is not authorised for sign-in.';

  @override
  String get authErrUserDisabled =>
      'This account has been disabled. Please contact support.';

  @override
  String authErrWithCode(String code) {
    return 'Sign-in failed ($code).';
  }

  @override
  String get errInvalidEmail => 'Enter a valid email address.';

  @override
  String get errInvalidOwnerEmail =>
      'Enter a valid Gmail / email address for the owner.';

  @override
  String errEmailAlreadyStaff(String role) {
    return 'This email address already belongs to a $role account.';
  }

  @override
  String get errGoogleEmailMissing =>
      'Your Google account has no verified email address.';

  @override
  String get ownerEmailLogin => 'Owner Gmail Address (Login) *';

  @override
  String get ownerEmailHelper =>
      'The owner signs in with this email (Google or email and password) to manage the shop.';

  @override
  String get emailForLogin => 'Email address (for login)';

  @override
  String get barberEmailHelper =>
      'Optional. The barber signs in with this email (Google or email and password).';

  @override
  String get barberMobileOptional => 'Mobile Number (optional)';

  @override
  String get invalidEmailShort => 'Enter a valid email address';

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
  String ownerInvitePending(String name, String email) {
    return '$name ($email) - invite pending';
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
  String registeredShopSnack(String shop, String email) {
    return 'Registered \"$shop\". The owner can now sign in as $email.';
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
  String loginInvitePending(String email) {
    return 'Login invite pending: $email';
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

  @override
  String get errInvalidPhone =>
      'Enter a valid Ethiopian mobile number (09... or 07...).';

  @override
  String get errInvalidName => 'Enter your name (up to 100 characters).';

  @override
  String get errSignInRequired => 'Please sign in first.';

  @override
  String get errSignInToBook => 'Sign in to book an appointment.';

  @override
  String get errInvalidTimeSlot =>
      'That time is not valid. Please pick another time.';

  @override
  String errServiceTooLong(int minutes) {
    return 'A service can be at most $minutes minutes long.';
  }

  @override
  String get errServerOnly => 'Only the server can make this change.';

  @override
  String get errSlotTaken =>
      'Sorry, that time was just taken. Please pick another slot.';

  @override
  String get errBookingFailed =>
      'Could not book this time. Check your connection and try again.';

  @override
  String get errNoWorkingDays => 'Pick at least one working day.';

  @override
  String get errInvalidWorkingHours =>
      'The end time must be after the start time.';

  @override
  String errPlanIdInvalid(String ids) {
    return 'Plan id must be one of $ids.';
  }

  @override
  String get errPlanNameRequired => 'Plan name is required.';

  @override
  String get errPlanPriceNegative => 'Price must be 0 or more.';

  @override
  String get errPlanPriceRequired => 'A paid plan needs a price above 0.';

  @override
  String get errPlanMaxBarbers =>
      'Max barbers must be at least 1 (or -1 for unlimited).';

  @override
  String get errPermissionDenied => 'You do not have permission to do this.';

  @override
  String get errOffline =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get payErrBookingNotFound => 'This booking could not be found.';

  @override
  String get payErrBookingCancelled => 'This booking was cancelled.';

  @override
  String get payErrBookingRefunded => 'This booking was refunded.';

  @override
  String get payErrCannotPayOnline => 'This booking cannot be paid online.';

  @override
  String get payErrNoValidPrice =>
      'This has no valid price, so it cannot be paid online.';

  @override
  String get payErrNotYourBooking =>
      'Only the customer who made this booking can pay for it.';

  @override
  String get payErrNotYourPayment => 'This is not your payment.';

  @override
  String get payErrNotShopOwner =>
      'Only the owner of this shop can pay its subscription.';

  @override
  String get payErrShopNotFound => 'This barbershop could not be found.';

  @override
  String get payErrPlanUnavailable => 'This plan is not available.';

  @override
  String get payErrUnknownPlan => 'Unknown plan.';

  @override
  String payErrPlanTooSmall(int max, int count) {
    return 'This plan allows $max barbers but the shop has $count. Choose a bigger plan or remove barbers.';
  }

  @override
  String get payErrBookingChanged =>
      'Something changed while we prepared your payment. Please try again.';

  @override
  String get payErrStillPreparing =>
      'Your payment is still being prepared. Please try again in a moment.';

  @override
  String get payErrLaunchFailed =>
      'Could not open the Chapa checkout page. Please try again.';

  @override
  String get payErrInvalid => 'Some payment details are missing or invalid.';

  @override
  String get payErrPrecondition => 'This payment cannot be made right now.';

  @override
  String get payErrAdminsOnly => 'Only administrators can do this.';

  @override
  String get payErrPaymentNotFound => 'This payment could not be found.';

  @override
  String get payErrReviewNotNeeded =>
      'This payment is no longer waiting for review.';

  @override
  String get payErrReviewNotRefundable =>
      'Only a successful payment can be marked as refunded.';

  @override
  String get viewAction => 'View';

  @override
  String get paymentsToReview => 'Payments to review';

  @override
  String get paymentsToReviewIntro =>
      'These payments need a decision. Refund the customer in the Chapa dashboard first, then mark the payment here.';

  @override
  String get noPaymentsToReview => 'No payments need review';

  @override
  String get noPaymentsToReviewHint =>
      'Payments for cancelled bookings, double payments and payments that could not be applied show up here.';

  @override
  String paymentsToReviewLoadFailed(String error) {
    return 'Could not load payments: $error';
  }

  @override
  String get reviewReasonCancelledBooking => 'Paid for a cancelled booking';

  @override
  String get reviewReasonDoublePayment => 'Booking was paid twice';

  @override
  String get reviewReasonMissingBooking => 'The booking no longer exists';

  @override
  String get reviewReasonRefundReported =>
      'Chapa reported a refund that needs checking';

  @override
  String get reviewReasonSubscription =>
      'Subscription payment could not be applied';

  @override
  String get reviewReasonOther => 'Needs a manual check';

  @override
  String get paymentTypeBooking => 'Booking payment';

  @override
  String get paymentTypeSubscription => 'Subscription payment';

  @override
  String get paymentDetailsTitle => 'Payment details';

  @override
  String get detailAmount => 'Amount';

  @override
  String get detailStatus => 'Status';

  @override
  String get detailCreated => 'Created';

  @override
  String get detailVerified => 'Verified';

  @override
  String get detailShop => 'Shop';

  @override
  String get detailBooking => 'Booking';

  @override
  String get detailCustomer => 'Paid by';

  @override
  String get detailTxRef => 'Transaction reference';

  @override
  String get detailChapaReference => 'Chapa reference';

  @override
  String get detailMethod => 'Method';

  @override
  String get detailPaymentId => 'Payment ID';

  @override
  String get reviewNoteLabel => 'Note (optional)';

  @override
  String get reviewNoteHint => 'e.g. Refunded on 13 Nov, Chapa ref ...';

  @override
  String get markRefundedInChapa => 'I refunded it in Chapa';

  @override
  String get markNoAction => 'No action needed';

  @override
  String get confirmRefundTitle => 'Mark as refunded?';

  @override
  String confirmRefundBody(String amount) {
    return 'Only continue if you already refunded $amount in the Chapa dashboard. The payment and its booking will show as refunded.';
  }

  @override
  String get reviewClosedRefunded => 'Marked as refunded.';

  @override
  String get reviewClosedNoAction => 'Review closed.';

  @override
  String reviewFailed(String error) {
    return 'Could not close the review: $error';
  }

  @override
  String get editWorkingHours => 'Working days and hours';

  @override
  String barberHoursTitle(String name) {
    return '$name: working hours';
  }

  @override
  String get followShopHours => 'Same as the shop';

  @override
  String get followShopHoursSubtitle =>
      'Works on the shop\'s days, from opening to closing time.';

  @override
  String get workingDaysLabel => 'Working days';

  @override
  String get startsAt => 'Starts';

  @override
  String get endsAt => 'Ends';

  @override
  String get workingHoursSaved => 'Working hours saved.';

  @override
  String get shopHoursSummary => 'Shop hours';

  @override
  String get errAccountLoadFailed =>
      'Could not load your account. Check your connection and try again.';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get reviewsRateAction => 'Rate visit';

  @override
  String get reviewsYourRating => 'Your rating';

  @override
  String get reviewsRateTitle => 'Rate your visit';

  @override
  String reviewsRateSubtitle(String service, String barber) {
    return '$service with $barber';
  }

  @override
  String reviewsStarsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get reviewsPickRating => 'Tap a star to rate.';

  @override
  String get reviewsCommentLabel => 'Comment (optional)';

  @override
  String get reviewsCommentHint => 'What did you like? What could be better?';

  @override
  String get reviewsSubmit => 'Send review';

  @override
  String get reviewsThanks => 'Thank you for your review!';

  @override
  String reviewsSubmitFailed(String error) {
    return 'Could not send your review: $error';
  }

  @override
  String reviewsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews yet',
    );
    return '$_temp0';
  }

  @override
  String get reviewsNew => 'New';

  @override
  String get reviewsEmpty =>
      'No reviews yet. Customers can rate their visit after it is completed.';

  @override
  String reviewsSeeAll(int count) {
    return 'See all reviews ($count)';
  }

  @override
  String get reviewsLoadMore => 'Show more';

  @override
  String get reviewsLoadFailed => 'Could not load the reviews.';

  @override
  String get reviewsRetry => 'Try again';

  @override
  String get reviewsOwnerReply => 'Reply from the shop';

  @override
  String get reviewsReplyAction => 'Reply';

  @override
  String get reviewsEditReply => 'Edit reply';

  @override
  String get reviewsReplyLabel => 'Your public reply';

  @override
  String get reviewsReplySave => 'Save reply';

  @override
  String get reviewsReplySaved => 'Reply saved.';

  @override
  String get reviewsAwaitingReply => 'No reply yet';

  @override
  String get reviewsOpenButton => 'Reviews & replies';

  @override
  String get reviewsMyReviews => 'My reviews';

  @override
  String reviewsBarberTitle(String name) {
    return 'Reviews for $name';
  }

  @override
  String reviewsSummaryLine(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$rating out of 5 · $_temp0';
  }

  @override
  String reviewsRatedSemantics(String rating) {
    return 'Rated $rating out of 5';
  }

  @override
  String get reviewsCustomer => 'Customer';

  @override
  String get reviewsErrNotYourBooking => 'You can only rate your own visits.';

  @override
  String get reviewsErrNotCompleted =>
      'You can rate a visit once it is completed.';

  @override
  String get reviewsErrAlreadyReviewed => 'You have already rated this visit.';

  @override
  String get reviewsErrInvalidRating => 'Choose from 1 to 5 stars.';

  @override
  String reviewsErrCommentTooLong(int max) {
    return 'The comment can be at most $max characters.';
  }

  @override
  String reviewsErrReplyInvalid(int max) {
    return 'Write a reply of up to $max characters.';
  }

  @override
  String get reviewsErrOwnerOnly => 'Only the shop owner can reply to reviews.';

  @override
  String get reviewsErrNotFound => 'This review no longer exists.';

  @override
  String get authTabLogin => 'Log in';

  @override
  String get authTabRegister => 'Register';

  @override
  String get authOr => 'or';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get loginButton => 'Log in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get sendCode => 'Send code';

  @override
  String codeSentTo(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get codeLabel => '6-digit code';

  @override
  String get verifyAndCreate => 'Verify and create account';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get codeResent => 'We sent a new code.';

  @override
  String get changeEmail => 'Change email';

  @override
  String get passwordHelper =>
      'At least 8 characters, with a letter and a number';

  @override
  String get passwordsDontMatch => 'The passwords do not match.';

  @override
  String get enterPassword => 'Enter your password.';

  @override
  String get codeRequired => 'Enter the 6-digit code.';

  @override
  String get resetTitle => 'Reset your password';

  @override
  String get resetIntro =>
      'Enter your account email and we\'ll send you a 6-digit code.';

  @override
  String get resetButton => 'Reset password';

  @override
  String get resetDone =>
      'Your password has been changed. Log in with your new password.';

  @override
  String get backToLogin => 'Back to log in';

  @override
  String get demoEmailHint =>
      'Demo: the code is always 123456. Demo accounts log in with the password demo1234.';

  @override
  String get emailErrWeakPassword =>
      'Use 8 to 128 characters with at least one letter and one number.';

  @override
  String get emailErrInvalidCode =>
      'That code is not correct. Check the email and try again.';

  @override
  String get emailErrCodeExpired =>
      'That code has expired. Request a new code.';

  @override
  String get emailErrAlreadyRegistered =>
      'An account with this email already exists. Log in instead.';

  @override
  String get emailErrTooSoon =>
      'Please wait a moment before requesting another code.';

  @override
  String emailErrTooSoonSeconds(int seconds) {
    return 'Please wait $seconds s before requesting another code.';
  }

  @override
  String get emailErrRateLimited =>
      'Too many attempts. Please try again later.';

  @override
  String get emailErrNotConfigured =>
      'We can\'t send emails right now. Try Google sign-in instead.';

  @override
  String get emailErrWrongCredentials => 'Wrong email or password.';

  @override
  String get emailErrNotEnabled => 'Email sign-in is not enabled yet.';

  @override
  String get emailErrServiceUnavailable =>
      'This service isn\'t available yet. Try Google sign-in instead.';

  @override
  String get errEmailNotVerified =>
      'This email address is not verified. Sign in with Google or contact support.';

  @override
  String get emailErrSendFailed =>
      'Couldn\'t send the email. Please try again.';

  @override
  String get emailErrInvalidInput =>
      'Check the details you entered and try again.';

  @override
  String emailErrInvalidCodeAttempts(int count) {
    return 'That code is not correct. Attempts left: $count.';
  }

  @override
  String emailErrRateLimitedMinutes(int minutes) {
    return 'Too many attempts. Try again in $minutes min.';
  }
}
