import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Walk-in queue'**
  String get queueTitle;

  /// No description provided for @queueDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{waiting} waiting · {serving} in the chair'**
  String queueDashboardSubtitle(int waiting, int serving);

  /// No description provided for @queueSummaryWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting, about {minutes} min'**
  String queueSummaryWaiting(int count, int minutes);

  /// No description provided for @queueSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one waiting - walk right in'**
  String get queueSummaryEmpty;

  /// No description provided for @queueJoin.
  ///
  /// In en, this message translates to:
  /// **'Join queue'**
  String get queueJoin;

  /// No description provided for @queueLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave queue'**
  String get queueLeave;

  /// No description provided for @queueLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave the queue at {shop}?'**
  String queueLeaveConfirm(String shop);

  /// No description provided for @queueYourPosition.
  ///
  /// In en, this message translates to:
  /// **'You are number {position} in line, about {minutes} min'**
  String queueYourPosition(int position, int minutes);

  /// No description provided for @queueYouAreNext.
  ///
  /// In en, this message translates to:
  /// **'You\'re next! Please be at the shop.'**
  String get queueYouAreNext;

  /// No description provided for @queueYourTurn.
  ///
  /// In en, this message translates to:
  /// **'It\'s your turn - {barber} is ready for you'**
  String queueYourTurn(String barber);

  /// No description provided for @queueYourTurnAnyBarber.
  ///
  /// In en, this message translates to:
  /// **'It\'s your turn - please come in'**
  String get queueYourTurnAnyBarber;

  /// No description provided for @queueJoined.
  ///
  /// In en, this message translates to:
  /// **'You joined the queue.'**
  String get queueJoined;

  /// No description provided for @queueLeftMessage.
  ///
  /// In en, this message translates to:
  /// **'You left the queue.'**
  String get queueLeftMessage;

  /// No description provided for @queueSignInToJoin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join the queue.'**
  String get queueSignInToJoin;

  /// No description provided for @queueJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the queue at {shop}'**
  String queueJoinTitle(String shop);

  /// No description provided for @queueJoinBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll hold your place in line and tell you when you\'re next.'**
  String get queueJoinBody;

  /// No description provided for @queueWaitingHeader.
  ///
  /// In en, this message translates to:
  /// **'Waiting ({count})'**
  String queueWaitingHeader(int count);

  /// No description provided for @queueServingHeader.
  ///
  /// In en, this message translates to:
  /// **'In the chair ({count})'**
  String queueServingHeader(int count);

  /// No description provided for @queueBarbersHeader.
  ///
  /// In en, this message translates to:
  /// **'Barbers right now'**
  String get queueBarbersHeader;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting.'**
  String get queueEmpty;

  /// No description provided for @queueAddWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Add walk-in'**
  String get queueAddWalkIn;

  /// No description provided for @queueNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get queueNameLabel;

  /// No description provided for @queuePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get queuePhoneLabel;

  /// No description provided for @queueServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service (optional)'**
  String get queueServiceLabel;

  /// No description provided for @queuePreferredBarberLabel.
  ///
  /// In en, this message translates to:
  /// **'Preferred barber (optional)'**
  String get queuePreferredBarberLabel;

  /// No description provided for @queueAnyBarber.
  ///
  /// In en, this message translates to:
  /// **'Any barber'**
  String get queueAnyBarber;

  /// No description provided for @queueNoService.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get queueNoService;

  /// No description provided for @queueAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get queueAddButton;

  /// No description provided for @queueCallNext.
  ///
  /// In en, this message translates to:
  /// **'Call next'**
  String get queueCallNext;

  /// No description provided for @queueCallNextFor.
  ///
  /// In en, this message translates to:
  /// **'Call next for {barber}'**
  String queueCallNextFor(String barber);

  /// No description provided for @queueStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get queueStart;

  /// No description provided for @queueFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get queueFinish;

  /// No description provided for @queueMarkLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get queueMarkLeft;

  /// No description provided for @queueChooseBarber.
  ///
  /// In en, this message translates to:
  /// **'Who will serve {name}?'**
  String queueChooseBarber(String name);

  /// No description provided for @queueBarberServing.
  ///
  /// In en, this message translates to:
  /// **'Serving {name}'**
  String queueBarberServing(String name);

  /// No description provided for @queueBarberFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get queueBarberFree;

  /// No description provided for @queueBarberOff.
  ///
  /// In en, this message translates to:
  /// **'Not taking customers'**
  String get queueBarberOff;

  /// No description provided for @queueWaitAbout.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min'**
  String queueWaitAbout(int minutes);

  /// No description provided for @queueNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get queueNextUp;

  /// No description provided for @queuePrefers.
  ///
  /// In en, this message translates to:
  /// **'Prefers {barber}'**
  String queuePrefers(String barber);

  /// No description provided for @queueRemoteBadge.
  ///
  /// In en, this message translates to:
  /// **'Joined in app'**
  String get queueRemoteBadge;

  /// No description provided for @queueJoinedAt.
  ///
  /// In en, this message translates to:
  /// **'Joined {time}'**
  String queueJoinedAt(String time);

  /// No description provided for @queueServingSince.
  ///
  /// In en, this message translates to:
  /// **'Since {time}'**
  String queueServingSince(String time);

  /// No description provided for @queueNobodyForBarber.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting for {barber}.'**
  String queueNobodyForBarber(String barber);

  /// No description provided for @queueNowServing.
  ///
  /// In en, this message translates to:
  /// **'{barber} is now serving {name}.'**
  String queueNowServing(String barber, String name);

  /// No description provided for @queueActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the queue: {error}'**
  String queueActionFailed(String error);

  /// No description provided for @queueErrNotStaff.
  ///
  /// In en, this message translates to:
  /// **'Only this shop\'s owner and barbers can manage its queue.'**
  String get queueErrNotStaff;

  /// No description provided for @queueErrCustomersOnly.
  ///
  /// In en, this message translates to:
  /// **'Only customers can join the queue from the app.'**
  String get queueErrCustomersOnly;

  /// No description provided for @queueErrNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name (up to {max} characters).'**
  String queueErrNameRequired(int max);

  /// No description provided for @queueErrBarberBusy.
  ///
  /// In en, this message translates to:
  /// **'{name} is already serving someone. Finish that first.'**
  String queueErrBarberBusy(String name);

  /// No description provided for @queueErrNotWaiting.
  ///
  /// In en, this message translates to:
  /// **'This person is no longer waiting.'**
  String get queueErrNotWaiting;

  /// No description provided for @queueErrNotServing.
  ///
  /// In en, this message translates to:
  /// **'This person is not being served.'**
  String get queueErrNotServing;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Reports & clients'**
  String get reportsOpenButton;

  /// No description provided for @reportsOverviewTab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get reportsOverviewTab;

  /// No description provided for @reportsClientsTab.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get reportsClientsTab;

  /// No description provided for @reportsMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportsMonthLabel;

  /// No description provided for @reportsBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get reportsBookings;

  /// No description provided for @reportsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get reportsCompleted;

  /// No description provided for @reportsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get reportsCancelled;

  /// No description provided for @reportsNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get reportsNoShows;

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsRevenueTrend.
  ///
  /// In en, this message translates to:
  /// **'Revenue, last 6 months'**
  String get reportsRevenueTrend;

  /// No description provided for @reportsTopServices.
  ///
  /// In en, this message translates to:
  /// **'Top services'**
  String get reportsTopServices;

  /// No description provided for @reportsBarberPerformance.
  ///
  /// In en, this message translates to:
  /// **'Barber performance'**
  String get reportsBarberPerformance;

  /// No description provided for @reportsCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String reportsCompletedCount(int count);

  /// No description provided for @reportsNoBookingsMonth.
  ///
  /// In en, this message translates to:
  /// **'No bookings in this month.'**
  String get reportsNoBookingsMonth;

  /// No description provided for @reportsNoCompletedMonth.
  ///
  /// In en, this message translates to:
  /// **'No completed bookings in this month yet.'**
  String get reportsNoCompletedMonth;

  /// No description provided for @reportsNoClients.
  ///
  /// In en, this message translates to:
  /// **'No clients yet.'**
  String get reportsNoClients;

  /// No description provided for @reportsClientVisits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 visit} other{{count} visits}}'**
  String reportsClientVisits(int count);

  /// No description provided for @reportsClientNoShows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 no-show} other{{count} no-shows}}'**
  String reportsClientNoShows(int count);

  /// No description provided for @reportsClientCancelled.
  ///
  /// In en, this message translates to:
  /// **'{count} cancelled'**
  String reportsClientCancelled(int count);

  /// No description provided for @reportsLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit {date}'**
  String reportsLastVisit(String date);

  /// No description provided for @reportsNoVisitYet.
  ///
  /// In en, this message translates to:
  /// **'No completed visit yet'**
  String get reportsNoVisitYet;

  /// No description provided for @reportsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports. Check your connection and try again.'**
  String get reportsLoadFailed;

  /// No description provided for @reportsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get reportsRetry;

  /// No description provided for @reportsUpdatedNote.
  ///
  /// In en, this message translates to:
  /// **'Figures update a few seconds after each booking change.'**
  String get reportsUpdatedNote;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Crown & Blade - Barbershop Booking'**
  String get appTitle;

  /// No description provided for @brandUpper.
  ///
  /// In en, this message translates to:
  /// **'CROWN & BLADE'**
  String get brandUpper;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutLower.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutLower;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @cityAddisAbaba.
  ///
  /// In en, this message translates to:
  /// **'Addis Ababa'**
  String get cityAddisAbaba;

  /// No description provided for @languageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get languageTooltip;

  /// No description provided for @serviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get serviceUnavailable;

  /// No description provided for @serviceUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not connect to its server. Please try again later.'**
  String get serviceUnavailableBody;

  /// No description provided for @shopNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Your barbershop could not be loaded.'**
  String get shopNotLoaded;

  /// No description provided for @invalidEthiopianPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Ethiopian mobile number (09... or 07...)'**
  String get invalidEthiopianPhone;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(int count);

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count} reviews)'**
  String reviewsCount(String rating, int count);

  /// No description provided for @barbersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Barbers'**
  String barbersCount(int count);

  /// No description provided for @servicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Services'**
  String servicesCount(int count);

  /// No description provided for @bookingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Bookings'**
  String bookingsCount(int count);

  /// No description provided for @barberLabel.
  ///
  /// In en, this message translates to:
  /// **'Barber: {name}'**
  String barberLabel(String name);

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client: {name}'**
  String clientLabel(String name);

  /// No description provided for @dateAtTime.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String dateAtTime(String date, String time);

  /// No description provided for @serviceAndPrice.
  ///
  /// In en, this message translates to:
  /// **'{service} • {price}'**
  String serviceAndPrice(String service, String price);

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin'**
  String get roleAdmin;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Shop Owner'**
  String get roleOwner;

  /// No description provided for @roleBarber.
  ///
  /// In en, this message translates to:
  /// **'Barber'**
  String get roleBarber;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get statusNoShow;

  /// No description provided for @rescheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get rescheduleAction;

  /// No description provided for @rescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a new time'**
  String get rescheduleTitle;

  /// No description provided for @rescheduleCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current time: {when}'**
  String rescheduleCurrent(String when);

  /// No description provided for @rescheduleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move booking'**
  String get rescheduleConfirm;

  /// No description provided for @rescheduleDone.
  ///
  /// In en, this message translates to:
  /// **'Your booking was moved to {when}.'**
  String rescheduleDone(String when);

  /// No description provided for @rescheduleLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No more changes allowed} =1{1 change left} other{{count} changes left}}'**
  String rescheduleLeft(int count);

  /// No description provided for @rescheduledBadge.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get rescheduledBadge;

  /// No description provided for @reschedulePolicyNote.
  ///
  /// In en, this message translates to:
  /// **'Free changes and cancellation until {hours, plural, =0{the start time} =1{1 hour before} other{{hours} hours before}}.'**
  String reschedulePolicyNote(int hours);

  /// No description provided for @rescheduleCallShop.
  ///
  /// In en, this message translates to:
  /// **'Too late to change this booking in the app. Please call the shop.'**
  String get rescheduleCallShop;

  /// No description provided for @rescheduleErrNotChangeable.
  ///
  /// In en, this message translates to:
  /// **'This booking can no longer be changed.'**
  String get rescheduleErrNotChangeable;

  /// No description provided for @rescheduleErrCancelCutoff.
  ///
  /// In en, this message translates to:
  /// **'You can cancel up to {hours, plural, =1{1 hour} other{{hours} hours}} before your appointment. Please call the shop.'**
  String rescheduleErrCancelCutoff(int hours);

  /// No description provided for @rescheduleErrCutoff.
  ///
  /// In en, this message translates to:
  /// **'You can move a booking up to {hours, plural, =1{1 hour} other{{hours} hours}} before it starts. Please call the shop.'**
  String rescheduleErrCutoff(int hours);

  /// No description provided for @rescheduleErrLimit.
  ///
  /// In en, this message translates to:
  /// **'This booking has already been moved {max, plural, =0{- this shop does not allow changes} =1{once, the most this shop allows} other{{max} times, the most this shop allows}}.'**
  String rescheduleErrLimit(int max);

  /// No description provided for @rescheduleErrSameTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time different from your current one.'**
  String get rescheduleErrSameTime;

  /// No description provided for @noShowAction.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get noShowAction;

  /// No description provided for @noShowConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as no-show?'**
  String get noShowConfirmTitle;

  /// No description provided for @noShowConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} did not come to this appointment. The time stays blocked.'**
  String noShowConfirmBody(String name);

  /// No description provided for @noShowErrTooEarly.
  ///
  /// In en, this message translates to:
  /// **'You can mark a no-show only after the appointment start time.'**
  String get noShowErrTooEarly;

  /// No description provided for @policySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking policy'**
  String get policySectionTitle;

  /// No description provided for @policyCutoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation cutoff'**
  String get policyCutoffLabel;

  /// No description provided for @policyCutoffHelp.
  ///
  /// In en, this message translates to:
  /// **'Customers cannot cancel or move a booking within this many hours of the start. You and your barbers can still cancel.'**
  String get policyCutoffHelp;

  /// No description provided for @policyHoursValue.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =0{Until the start} =1{1 hour before} other{{hours} hours before}}'**
  String policyHoursValue(int hours);

  /// No description provided for @policyMaxReschedulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Changes allowed per booking'**
  String get policyMaxReschedulesLabel;

  /// No description provided for @policyMaxReschedulesValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No changes} =1{Once} other{{count} times}}'**
  String policyMaxReschedulesValue(int count);

  /// No description provided for @policySave.
  ///
  /// In en, this message translates to:
  /// **'Save policy'**
  String get policySave;

  /// No description provided for @policySaved.
  ///
  /// In en, this message translates to:
  /// **'Booking policy saved.'**
  String get policySaved;

  /// No description provided for @policyErrCutoff.
  ///
  /// In en, this message translates to:
  /// **'The cancellation cutoff must be between 0 and {max} hours.'**
  String policyErrCutoff(int max);

  /// No description provided for @policyErrMaxReschedules.
  ///
  /// In en, this message translates to:
  /// **'Changes allowed must be between 0 and {max}.'**
  String policyErrMaxReschedules(int max);

  /// No description provided for @timeOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Time off'**
  String get timeOffTitle;

  /// No description provided for @timeOffAdd.
  ///
  /// In en, this message translates to:
  /// **'Add time off'**
  String get timeOffAdd;

  /// No description provided for @timeOffWholeDay.
  ///
  /// In en, this message translates to:
  /// **'Whole day'**
  String get timeOffWholeDay;

  /// No description provided for @timeOffHours.
  ///
  /// In en, this message translates to:
  /// **'Some hours'**
  String get timeOffHours;

  /// No description provided for @timeOffDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get timeOffDay;

  /// No description provided for @timeOffFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get timeOffFrom;

  /// No description provided for @timeOffTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get timeOffTo;

  /// No description provided for @timeOffReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get timeOffReasonLabel;

  /// No description provided for @timeOffEmpty.
  ///
  /// In en, this message translates to:
  /// **'No time off planned.'**
  String get timeOffEmpty;

  /// No description provided for @timeOffSaved.
  ///
  /// In en, this message translates to:
  /// **'Time off added. Customers can no longer book these times.'**
  String get timeOffSaved;

  /// No description provided for @timeOffRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove time off'**
  String get timeOffRemove;

  /// No description provided for @timeOffRemoved.
  ///
  /// In en, this message translates to:
  /// **'Time off removed.'**
  String get timeOffRemoved;

  /// No description provided for @timeOffRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this time off? Customers can book these times again.'**
  String get timeOffRemoveConfirm;

  /// No description provided for @timeOffRange.
  ///
  /// In en, this message translates to:
  /// **'{day}, {from} - {to}'**
  String timeOffRange(String day, String from, String to);

  /// No description provided for @timeOffNotWorking.
  ///
  /// In en, this message translates to:
  /// **'{name} does not work on this day.'**
  String timeOffNotWorking(String name);

  /// No description provided for @timeOffSlotLabel.
  ///
  /// In en, this message translates to:
  /// **'Time off'**
  String get timeOffSlotLabel;

  /// No description provided for @timeOffErrRange.
  ///
  /// In en, this message translates to:
  /// **'Pick a range within one day, ending after it starts.'**
  String get timeOffErrRange;

  /// No description provided for @timeOffErrPast.
  ///
  /// In en, this message translates to:
  /// **'Time off must end in the future.'**
  String get timeOffErrPast;

  /// No description provided for @timeOffErrReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'The note can be at most {max} characters.'**
  String timeOffErrReasonTooLong(int max);

  /// No description provided for @timeOffErrConflict.
  ///
  /// In en, this message translates to:
  /// **'This time overlaps a booking or other time off. Move or cancel that booking first.'**
  String get timeOffErrConflict;

  /// No description provided for @timeOffErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You can only manage time off for your own schedule.'**
  String get timeOffErrNotAllowed;

  /// No description provided for @subTrialing.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get subTrialing;

  /// No description provided for @subActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subActive;

  /// No description provided for @subPastDue.
  ///
  /// In en, this message translates to:
  /// **'Payment overdue'**
  String get subPastDue;

  /// No description provided for @subSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get subSuspended;

  /// No description provided for @payUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get payUnpaid;

  /// No description provided for @payAtShop.
  ///
  /// In en, this message translates to:
  /// **'Pay at shop'**
  String get payAtShop;

  /// No description provided for @payPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get payPending;

  /// No description provided for @payPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get payPaid;

  /// No description provided for @payRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get payRefunded;

  /// No description provided for @recordProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get recordProcessing;

  /// No description provided for @recordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get recordFailed;

  /// No description provided for @planTrial.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get planTrial;

  /// No description provided for @planBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get planBasic;

  /// No description provided for @planPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get planPro;

  /// No description provided for @planUnlimitedBarbers.
  ///
  /// In en, this message translates to:
  /// **'Unlimited barbers'**
  String get planUnlimitedBarbers;

  /// No description provided for @planUpToBarbers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Up to 1 barber} other{Up to {count} barbers}}'**
  String planUpToBarbers(int count);

  /// No description provided for @payErrNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Online payments are not set up yet. Please pay at the shop.'**
  String get payErrNotSetUp;

  /// No description provided for @payErrSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to make a payment.'**
  String get payErrSignIn;

  /// No description provided for @payErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to make this payment.'**
  String get payErrNotAllowed;

  /// No description provided for @payErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'We could not find this item. It may have been removed.'**
  String get payErrNotFound;

  /// No description provided for @payErrAlreadyPaid.
  ///
  /// In en, this message translates to:
  /// **'This booking is already paid.'**
  String get payErrAlreadyPaid;

  /// No description provided for @payErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the payment service. Check your connection and try again.'**
  String get payErrNetwork;

  /// No description provided for @payErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'The payment could not be started. Please try again.'**
  String get payErrGeneric;

  /// No description provided for @switchRole.
  ///
  /// In en, this message translates to:
  /// **'Switch Role'**
  String get switchRole;

  /// No description provided for @personaTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch demo role'**
  String get personaTitle;

  /// No description provided for @personaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: switch persona instantly to try each role'**
  String get personaSubtitle;

  /// No description provided for @personaAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Administrator'**
  String get personaAdminTitle;

  /// No description provided for @personaAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register barbershops, manage users & platform config'**
  String get personaAdminSubtitle;

  /// No description provided for @personaOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Barbershop Owner App'**
  String get personaOwnerTitle;

  /// No description provided for @personaOwnerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage barbers, services & appointments ({shop})'**
  String personaOwnerSubtitle(String shop);

  /// No description provided for @personaBarberTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff Barber Workspace'**
  String get personaBarberTitle;

  /// No description provided for @personaBarberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: manage the appointment queue & earnings'**
  String personaBarberSubtitle(String name);

  /// No description provided for @personaCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer View'**
  String get personaCustomerTitle;

  /// No description provided for @personaCustomerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search barbershops, pick favorite barbers & book appointments'**
  String get personaCustomerSubtitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnreadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications ({count} unread)'**
  String notificationsUnreadTooltip(int count);

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @noNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmations, changes and reminders will appear here.'**
  String get noNotificationsHint;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String daysAgo(int count);

  /// No description provided for @authSubtitlePhone.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account with your phone number'**
  String get authSubtitlePhone;

  /// No description provided for @authSubtitleCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}'**
  String authSubtitleCode(String phone);

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @smsNotice.
  ///
  /// In en, this message translates to:
  /// **'We will send you a one-time code by SMS. Standard SMS rates may apply.'**
  String get smsNotice;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @demoCodeNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: the code is {code}'**
  String demoCodeNotice(String code);

  /// No description provided for @demoAccounts.
  ///
  /// In en, this message translates to:
  /// **'DEMO ACCOUNTS'**
  String get demoAccounts;

  /// No description provided for @roleAdminShort.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdminShort;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @profileCustomerMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your account to book barbers across Addis Ababa.'**
  String get profileCustomerMessage;

  /// No description provided for @profileOwnerInvite.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to manage {shop} as its owner.'**
  String profileOwnerInvite(String shop);

  /// No description provided for @profileBarberInvite.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to join {shop} as a barber.'**
  String profileBarberInvite(String shop);

  /// No description provided for @profileRoleInvite.
  ///
  /// In en, this message translates to:
  /// **'You have been invited as {role}.'**
  String profileRoleInvite(String role);

  /// No description provided for @aBarbershop.
  ///
  /// In en, this message translates to:
  /// **'a barbershop'**
  String get aBarbershop;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @useDifferentNumber.
  ///
  /// In en, this message translates to:
  /// **'Use a different number'**
  String get useDifferentNumber;

  /// No description provided for @authErrInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'That phone number is not valid.'**
  String get authErrInvalidPhone;

  /// No description provided for @authErrWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Check the SMS and try again.'**
  String get authErrWrongCode;

  /// No description provided for @authErrCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'The code expired. Request a new one.'**
  String get authErrCodeExpired;

  /// No description provided for @authErrTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get authErrTooMany;

  /// No description provided for @authErrQuota.
  ///
  /// In en, this message translates to:
  /// **'SMS limit reached. Please try again later.'**
  String get authErrQuota;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get authErrNetwork;

  /// No description provided for @authErrNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in is not enabled for this app yet.'**
  String get authErrNotEnabled;

  /// No description provided for @authErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrGeneric;

  /// No description provided for @adminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform System Administration'**
  String get adminSubtitle;

  /// No description provided for @deleteShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Barbershop?'**
  String get deleteShopTitle;

  /// No description provided for @deleteShopBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{shop}\" and all associated barbers, services and appointments?'**
  String deleteShopBody(String shop);

  /// No description provided for @shopRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {shop}'**
  String shopRemoved(String shop);

  /// No description provided for @subscriptionsAndPlansTooltip.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions & plans'**
  String get subscriptionsAndPlansTooltip;

  /// No description provided for @tabShops.
  ///
  /// In en, this message translates to:
  /// **'Shops ({count})'**
  String tabShops(int count);

  /// No description provided for @tabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users ({count})'**
  String tabUsers(int count);

  /// No description provided for @tabBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings ({count})'**
  String tabBookings(int count);

  /// No description provided for @registerBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Register Barbershop'**
  String get registerBarbershop;

  /// No description provided for @metricBarbershops.
  ///
  /// In en, this message translates to:
  /// **'Barbershops'**
  String get metricBarbershops;

  /// No description provided for @metricRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get metricRegistered;

  /// No description provided for @metricActiveBarbers.
  ///
  /// In en, this message translates to:
  /// **'Active Barbers'**
  String get metricActiveBarbers;

  /// No description provided for @metricAcrossNetwork.
  ///
  /// In en, this message translates to:
  /// **'Across network'**
  String get metricAcrossNetwork;

  /// No description provided for @metricPlatformSales.
  ///
  /// In en, this message translates to:
  /// **'Platform Sales'**
  String get metricPlatformSales;

  /// No description provided for @metricGrossVolume.
  ///
  /// In en, this message translates to:
  /// **'Gross volume'**
  String get metricGrossVolume;

  /// No description provided for @searchShopsAdminHint.
  ///
  /// In en, this message translates to:
  /// **'Search shops by name, address, or sub-city...'**
  String get searchShopsAdminHint;

  /// No description provided for @filterVerifiedPartners.
  ///
  /// In en, this message translates to:
  /// **'Verified Partners'**
  String get filterVerifiedPartners;

  /// No description provided for @filterOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get filterOpenNow;

  /// No description provided for @registeredBarbershopsCount.
  ///
  /// In en, this message translates to:
  /// **'Registered Barbershops ({count})'**
  String registeredBarbershopsCount(int count);

  /// No description provided for @adminActionsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Admin Actions Enabled'**
  String get adminActionsEnabled;

  /// No description provided for @noRegisteredShops.
  ///
  /// In en, this message translates to:
  /// **'No registered barbershops found'**
  String get noRegisteredShops;

  /// No description provided for @noRegisteredShopsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Register Barbershop\" to add a new shop to the platform.'**
  String get noRegisteredShopsHint;

  /// No description provided for @ownerInvitePending.
  ///
  /// In en, this message translates to:
  /// **'{name} ({phone}) - invite pending'**
  String ownerInvitePending(String name, String phone);

  /// No description provided for @notAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get notAssigned;

  /// No description provided for @ownerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner: {owner}'**
  String ownerLabel(String owner);

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @verifyShop.
  ///
  /// In en, this message translates to:
  /// **'Verify Shop'**
  String get verifyShop;

  /// No description provided for @manageShopPortal.
  ///
  /// In en, this message translates to:
  /// **'Manage Shop Portal'**
  String get manageShopPortal;

  /// No description provided for @deleteShop.
  ///
  /// In en, this message translates to:
  /// **'Delete Shop'**
  String get deleteShop;

  /// No description provided for @roleAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdministrator;

  /// No description provided for @roleStaffBarber.
  ///
  /// In en, this message translates to:
  /// **'Staff Barber'**
  String get roleStaffBarber;

  /// No description provided for @assignedShop.
  ///
  /// In en, this message translates to:
  /// **'Assigned Shop: {shop}'**
  String assignedShop(String shop);

  /// No description provided for @noPlatformAppointments.
  ///
  /// In en, this message translates to:
  /// **'No platform appointments recorded yet'**
  String get noPlatformAppointments;

  /// No description provided for @scheduleAt.
  ///
  /// In en, this message translates to:
  /// **'Schedule: {when}'**
  String scheduleAt(String when);

  /// No description provided for @registerNewBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Register New Barbershop'**
  String get registerNewBarbershop;

  /// No description provided for @registeredShopSnack.
  ///
  /// In en, this message translates to:
  /// **'Registered \"{shop}\". The owner can now sign in with {phone}.'**
  String registeredShopSnack(String shop, String phone);

  /// No description provided for @registrationError.
  ///
  /// In en, this message translates to:
  /// **'Registration error: {error}'**
  String registrationError(String error);

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'SaaS Barbershop Onboarding'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Registers shop profile, provisions tenant owner account & sets up staff suite.'**
  String get onboardingSubtitle;

  /// No description provided for @sectionShopProfile.
  ///
  /// In en, this message translates to:
  /// **'1. Shop Profile & Branding'**
  String get sectionShopProfile;

  /// No description provided for @shopBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Barbershop Business Name *'**
  String get shopBusinessName;

  /// No description provided for @shopBusinessNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bole Fade Studio'**
  String get shopBusinessNameHint;

  /// No description provided for @shopDescription.
  ///
  /// In en, this message translates to:
  /// **'Shop Description'**
  String get shopDescription;

  /// No description provided for @shopTelephone.
  ///
  /// In en, this message translates to:
  /// **'Shop Telephone *'**
  String get shopTelephone;

  /// No description provided for @coverImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Cover Image URL'**
  String get coverImageUrl;

  /// No description provided for @sectionOwnerAccount.
  ///
  /// In en, this message translates to:
  /// **'2. Barbershop Owner Account'**
  String get sectionOwnerAccount;

  /// No description provided for @ownerFullName.
  ///
  /// In en, this message translates to:
  /// **'Owner Full Name *'**
  String get ownerFullName;

  /// No description provided for @ownerMobileLogin.
  ///
  /// In en, this message translates to:
  /// **'Owner Mobile Number (Login) *'**
  String get ownerMobileLogin;

  /// No description provided for @ownerMobileHelper.
  ///
  /// In en, this message translates to:
  /// **'The owner signs in with this number to manage the shop.'**
  String get ownerMobileHelper;

  /// No description provided for @sectionLocation.
  ///
  /// In en, this message translates to:
  /// **'3. Physical Location'**
  String get sectionLocation;

  /// No description provided for @streetAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Street Address *'**
  String get streetAddressRequired;

  /// No description provided for @streetAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bole Road, Getu Building, 2nd floor'**
  String get streetAddressHint;

  /// No description provided for @subCityRequired.
  ///
  /// In en, this message translates to:
  /// **'Sub-city *'**
  String get subCityRequired;

  /// No description provided for @landmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get landmark;

  /// No description provided for @landmarkHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Near Edna Mall'**
  String get landmarkHint;

  /// No description provided for @cityRequired.
  ///
  /// In en, this message translates to:
  /// **'City *'**
  String get cityRequired;

  /// No description provided for @cityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Addis Ababa'**
  String get cityHint;

  /// No description provided for @sectionHours.
  ///
  /// In en, this message translates to:
  /// **'4. Business Hours & Verification'**
  String get sectionHours;

  /// No description provided for @openingTime.
  ///
  /// In en, this message translates to:
  /// **'Opening Time'**
  String get openingTime;

  /// No description provided for @closingTime.
  ///
  /// In en, this message translates to:
  /// **'Closing Time'**
  String get closingTime;

  /// No description provided for @markVerifiedPartner.
  ///
  /// In en, this message translates to:
  /// **'Mark as Verified Partner Shop'**
  String get markVerifiedPartner;

  /// No description provided for @markVerifiedPartnerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified badge displayed to all customers'**
  String get markVerifiedPartnerSubtitle;

  /// No description provided for @registeringBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Registering Barbershop...'**
  String get registeringBarbershop;

  /// No description provided for @registerIntoNetwork.
  ///
  /// In en, this message translates to:
  /// **'Register Barbershop into Network'**
  String get registerIntoNetwork;

  /// No description provided for @presetClassicLounge.
  ///
  /// In en, this message translates to:
  /// **'Classic Lounge'**
  String get presetClassicLounge;

  /// No description provided for @presetVintageWood.
  ///
  /// In en, this message translates to:
  /// **'Vintage Wood'**
  String get presetVintageWood;

  /// No description provided for @presetModernGold.
  ///
  /// In en, this message translates to:
  /// **'Modern Gold'**
  String get presetModernGold;

  /// No description provided for @presetIndustrialStudio.
  ///
  /// In en, this message translates to:
  /// **'Industrial Studio'**
  String get presetIndustrialStudio;

  /// No description provided for @subscriptionsAndPlans.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions & Plans'**
  String get subscriptionsAndPlans;

  /// No description provided for @tabPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans ({count})'**
  String tabPlans(int count);

  /// No description provided for @noBarbershopsYet.
  ///
  /// In en, this message translates to:
  /// **'No barbershops yet.'**
  String get noBarbershopsYet;

  /// No description provided for @statusCountChip.
  ///
  /// In en, this message translates to:
  /// **'{status}: {count}'**
  String statusCountChip(String status, int count);

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get noEndDate;

  /// No description provided for @endedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Ended {date} ({days}d ago)'**
  String endedDaysAgo(String date, int days);

  /// No description provided for @endsDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'Ends {date} ({days}d left)'**
  String endsDaysLeft(String date, int days);

  /// No description provided for @subscriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Subscription of {shop} updated.'**
  String subscriptionUpdated(String shop);

  /// No description provided for @createDefaultPlans.
  ///
  /// In en, this message translates to:
  /// **'Create default plans'**
  String get createDefaultPlans;

  /// No description provided for @addPlan.
  ///
  /// In en, this message translates to:
  /// **'Add plan'**
  String get addPlan;

  /// No description provided for @plansExplainer.
  ///
  /// In en, this message translates to:
  /// **'Owners can buy the Basic and Pro plans online. Deactivating a plan hides it from owners; current subscriptions keep running.'**
  String get plansExplainer;

  /// No description provided for @noPlansYet.
  ///
  /// In en, this message translates to:
  /// **'No plans yet.'**
  String get noPlansYet;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String perMonth(String price);

  /// No description provided for @planActivated.
  ///
  /// In en, this message translates to:
  /// **'{plan} activated.'**
  String planActivated(String plan);

  /// No description provided for @planDeactivated.
  ///
  /// In en, this message translates to:
  /// **'{plan} deactivated.'**
  String planDeactivated(String plan);

  /// No description provided for @defaultPlansExist.
  ///
  /// In en, this message translates to:
  /// **'The default plans already exist.'**
  String get defaultPlansExist;

  /// No description provided for @createdPlans.
  ///
  /// In en, this message translates to:
  /// **'Created plans: {plans}.'**
  String createdPlans(String plans);

  /// No description provided for @planSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan {plan} saved.'**
  String planSaved(String plan);

  /// No description provided for @manualSubscriptionHint.
  ///
  /// In en, this message translates to:
  /// **'For cash or bank payments and manual fixes.'**
  String get manualSubscriptionHint;

  /// No description provided for @planLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @addMonthsPrefix.
  ///
  /// In en, this message translates to:
  /// **'Add '**
  String get addMonthsPrefix;

  /// No description provided for @monthsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{ month} other{ months}}'**
  String monthsSuffix(int count);

  /// No description provided for @setADate.
  ///
  /// In en, this message translates to:
  /// **'Set a date...'**
  String get setADate;

  /// No description provided for @keepCurrentEndDate.
  ///
  /// In en, this message translates to:
  /// **'Keep current end date'**
  String get keepCurrentEndDate;

  /// No description provided for @pickEndDate.
  ///
  /// In en, this message translates to:
  /// **'Pick end date'**
  String get pickEndDate;

  /// No description provided for @enterValidPlanValues.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price and barber limit.'**
  String get enterValidPlanValues;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @editPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit {plan}'**
  String editPlan(String plan);

  /// No description provided for @planId.
  ///
  /// In en, this message translates to:
  /// **'Plan id'**
  String get planId;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @pricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'Price per month'**
  String get pricePerMonth;

  /// No description provided for @currencyEtb.
  ///
  /// In en, this message translates to:
  /// **'ETB'**
  String get currencyEtb;

  /// No description provided for @maxBarbers.
  ///
  /// In en, this message translates to:
  /// **'Max barbers'**
  String get maxBarbers;

  /// No description provided for @featuresOnePerLine.
  ///
  /// In en, this message translates to:
  /// **'Features (one per line)'**
  String get featuresOnePerLine;

  /// No description provided for @availableToOwners.
  ///
  /// In en, this message translates to:
  /// **'Available to owners'**
  String get availableToOwners;

  /// No description provided for @subscriptionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription: {shop}'**
  String subscriptionEditTitle(String shop);

  /// No description provided for @invalidContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Ethiopian phone number (09..., 07... or 011...)'**
  String get invalidContactPhone;

  /// No description provided for @shopPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'09XX XXX XXX or 011 XXX XXXX'**
  String get shopPhoneHint;

  /// No description provided for @ownerNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Abebe Kebede'**
  String get ownerNameHint;

  /// No description provided for @barberWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Barber Workspace'**
  String get barberWorkspace;

  /// No description provided for @noBarberProfile.
  ///
  /// In en, this message translates to:
  /// **'No Barber profile linked to this account.'**
  String get noBarberProfile;

  /// No description provided for @tabConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed ({count})'**
  String tabConfirmed(int count);

  /// No description provided for @tabInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress ({count})'**
  String tabInProgress(int count);

  /// No description provided for @tabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String tabCompleted(int count);

  /// No description provided for @tabAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String tabAll(int count);

  /// No description provided for @emptyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'No confirmed appointments scheduled.'**
  String get emptyConfirmed;

  /// No description provided for @emptyInProgress.
  ///
  /// In en, this message translates to:
  /// **'No appointments currently in progress.'**
  String get emptyInProgress;

  /// No description provided for @emptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed appointments yet today.'**
  String get emptyCompleted;

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No booking history found.'**
  String get emptyHistory;

  /// No description provided for @statusOnDuty.
  ///
  /// In en, this message translates to:
  /// **'Status: On Duty (Accepting Clients)'**
  String get statusOnDuty;

  /// No description provided for @statusOnBreak.
  ///
  /// In en, this message translates to:
  /// **'Status: On Break / Away'**
  String get statusOnBreak;

  /// No description provided for @metricAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get metricAppointments;

  /// No description provided for @metricInChair.
  ///
  /// In en, this message translates to:
  /// **'In Chair'**
  String get metricInChair;

  /// No description provided for @metricEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get metricEarnings;

  /// No description provided for @viewWeeklySchedule.
  ///
  /// In en, this message translates to:
  /// **'View Weekly Schedule & Calendar'**
  String get viewWeeklySchedule;

  /// No description provided for @viewWeeklyScheduleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect daily time slots, shifts, and bookings timeline'**
  String get viewWeeklyScheduleSubtitle;

  /// No description provided for @noShow.
  ///
  /// In en, this message translates to:
  /// **'No-Show'**
  String get noShow;

  /// No description provided for @startService.
  ///
  /// In en, this message translates to:
  /// **'Start Service'**
  String get startService;

  /// No description provided for @markCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get markCompleted;

  /// No description provided for @serviceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Service Completed'**
  String get serviceCompleted;

  /// No description provided for @appointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment Cancelled'**
  String get appointmentCancelled;

  /// No description provided for @statusUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the appointment: {error}'**
  String statusUpdateFailed(String error);

  /// No description provided for @barberScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} • Schedule'**
  String barberScheduleTitle(String name);

  /// No description provided for @shopHoursUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shop hours unavailable'**
  String get shopHoursUnavailable;

  /// No description provided for @noWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'No working hours set'**
  String get noWorkingHours;

  /// No description provided for @workingHoursLine.
  ///
  /// In en, this message translates to:
  /// **'Working hours: {range} • {days}'**
  String workingHoursLine(String range, String days);

  /// No description provided for @notTakingNewBookings.
  ///
  /// In en, this message translates to:
  /// **'{text} • Not taking new bookings'**
  String notTakingNewBookings(String text);

  /// No description provided for @dayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off - no working hours on {day}.'**
  String dayOff(String day);

  /// No description provided for @busy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get busy;

  /// No description provided for @availableSlot.
  ///
  /// In en, this message translates to:
  /// **'Available Slot'**
  String get availableSlot;

  /// No description provided for @rangeWithDuration.
  ///
  /// In en, this message translates to:
  /// **'{range} ({minutes} min)'**
  String rangeWithDuration(String range, int minutes);

  /// No description provided for @searchShopsHint.
  ///
  /// In en, this message translates to:
  /// **'Search barbershops by name or neighborhood...'**
  String get searchShopsHint;

  /// No description provided for @premierTalent.
  ///
  /// In en, this message translates to:
  /// **'PREMIER TALENT'**
  String get premierTalent;

  /// No description provided for @bookWithMasters.
  ///
  /// In en, this message translates to:
  /// **'Book Directly with Master Barbers'**
  String get bookWithMasters;

  /// No description provided for @bookWithMastersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse verified specialists, view portfolios & reserve seats.'**
  String get bookWithMastersSubtitle;

  /// No description provided for @findBarbers.
  ///
  /// In en, this message translates to:
  /// **'Find Barbers'**
  String get findBarbers;

  /// No description provided for @subCityFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub-city:'**
  String get subCityFilterLabel;

  /// No description provided for @catFades.
  ///
  /// In en, this message translates to:
  /// **'Fades & Tapers'**
  String get catFades;

  /// No description provided for @catBeard.
  ///
  /// In en, this message translates to:
  /// **'Beard Sculpt'**
  String get catBeard;

  /// No description provided for @catShave.
  ///
  /// In en, this message translates to:
  /// **'Hot Shave'**
  String get catShave;

  /// No description provided for @catKids.
  ///
  /// In en, this message translates to:
  /// **'Kids & VIP'**
  String get catKids;

  /// No description provided for @featuredBarbershops.
  ///
  /// In en, this message translates to:
  /// **'Featured Barbershops ({count})'**
  String featuredBarbershops(int count);

  /// No description provided for @allLocations.
  ///
  /// In en, this message translates to:
  /// **'All Locations'**
  String get allLocations;

  /// No description provided for @noShopsMatching.
  ///
  /// In en, this message translates to:
  /// **'No barbershops found matching \"{query}\"'**
  String noShopsMatching(String query);

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get verifiedBadge;

  /// No description provided for @viewServicesAndBook.
  ///
  /// In en, this message translates to:
  /// **'View Services & Book'**
  String get viewServicesAndBook;

  /// No description provided for @navBarbershops.
  ///
  /// In en, this message translates to:
  /// **'Barbershops'**
  String get navBarbershops;

  /// No description provided for @navAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get navAppointments;

  /// No description provided for @verifiedPartnerBadge.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED PARTNER'**
  String get verifiedPartnerBadge;

  /// No description provided for @locationAndHours.
  ///
  /// In en, this message translates to:
  /// **'Location & Hours'**
  String get locationAndHours;

  /// No description provided for @hoursWithDays.
  ///
  /// In en, this message translates to:
  /// **'{hours} ({days})'**
  String hoursWithDays(String hours, String days);

  /// No description provided for @ourMasterBarbers.
  ///
  /// In en, this message translates to:
  /// **'Our Master Barbers ({count})'**
  String ourMasterBarbers(int count);

  /// No description provided for @selectAService.
  ///
  /// In en, this message translates to:
  /// **'Select a Service ({count})'**
  String selectAService(int count);

  /// No description provided for @chooseAService.
  ///
  /// In en, this message translates to:
  /// **'Choose a service'**
  String get chooseAService;

  /// No description provided for @selectToSeePrice.
  ///
  /// In en, this message translates to:
  /// **'Select to see price'**
  String get selectToSeePrice;

  /// No description provided for @shopHasNoServicesOrBarbers.
  ///
  /// In en, this message translates to:
  /// **'This shop does not have active services or barbers.'**
  String get shopHasNoServicesOrBarbers;

  /// No description provided for @bookSlot.
  ///
  /// In en, this message translates to:
  /// **'Book Slot'**
  String get bookSlot;

  /// No description provided for @selectAvailableTime.
  ///
  /// In en, this message translates to:
  /// **'Please select an available time.'**
  String get selectAvailableTime;

  /// No description provided for @slotJustTaken.
  ///
  /// In en, this message translates to:
  /// **'Slot just taken'**
  String get slotJustTaken;

  /// No description provided for @slotJustTakenBody.
  ///
  /// In en, this message translates to:
  /// **'Someone else booked this time a moment ago.\n\nThe list of times has been refreshed.'**
  String get slotJustTakenBody;

  /// No description provided for @pickAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Pick another time'**
  String get pickAnotherTime;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed!'**
  String get bookingConfirmed;

  /// No description provided for @seatReserved.
  ///
  /// In en, this message translates to:
  /// **'Your seat with {barber} is reserved.'**
  String seatReserved(String barber);

  /// No description provided for @receiptShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get receiptShop;

  /// No description provided for @receiptService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get receiptService;

  /// No description provided for @receiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get receiptDate;

  /// No description provided for @receiptTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get receiptTime;

  /// No description provided for @receiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get receiptTotal;

  /// No description provided for @payAmountNow.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} now'**
  String payAmountNow(String amount);

  /// No description provided for @payAtShopInstead.
  ///
  /// In en, this message translates to:
  /// **'Pay at the shop instead'**
  String get payAtShopInstead;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @confirmAppointment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Appointment'**
  String get confirmAppointment;

  /// No description provided for @stepChooseBarber.
  ///
  /// In en, this message translates to:
  /// **'1. Choose Barber'**
  String get stepChooseBarber;

  /// No description provided for @stepSelectedService.
  ///
  /// In en, this message translates to:
  /// **'2. Selected Service'**
  String get stepSelectedService;

  /// No description provided for @stepSelectDate.
  ///
  /// In en, this message translates to:
  /// **'3. Select Date'**
  String get stepSelectDate;

  /// No description provided for @stepAvailableTimes.
  ///
  /// In en, this message translates to:
  /// **'4. Available Times'**
  String get stepAvailableTimes;

  /// No description provided for @durationAddisTime.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min • Addis Ababa time'**
  String durationAddisTime(int minutes);

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @serviceChip.
  ///
  /// In en, this message translates to:
  /// **'{service} ({price} • {minutes} min)'**
  String serviceChip(String service, String price, int minutes);

  /// No description provided for @shopNotTakingBookings.
  ///
  /// In en, this message translates to:
  /// **'This barbershop is not taking bookings right now.'**
  String get shopNotTakingBookings;

  /// No description provided for @barberNotTakingBookings.
  ///
  /// In en, this message translates to:
  /// **'{barber} is not taking bookings right now. Please choose another barber.'**
  String barberNotTakingBookings(String barber);

  /// No description provided for @barberDayOff.
  ///
  /// In en, this message translates to:
  /// **'{barber} does not work on this day. Please pick another date.'**
  String barberDayOff(String barber);

  /// No description provided for @noFreeTimes.
  ///
  /// In en, this message translates to:
  /// **'No free times left on this day. Please pick another date.'**
  String get noFreeTimes;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @totalPayAtSalon.
  ///
  /// In en, this message translates to:
  /// **'Total to Pay at Salon:'**
  String get totalPayAtSalon;

  /// No description provided for @totalPayOnline.
  ///
  /// In en, this message translates to:
  /// **'Total (pay online):'**
  String get totalPayOnline;

  /// No description provided for @selectATime.
  ///
  /// In en, this message translates to:
  /// **'Select a time'**
  String get selectATime;

  /// No description provided for @payAtShopCash.
  ///
  /// In en, this message translates to:
  /// **'Pay at shop (cash)'**
  String get payAtShopCash;

  /// No description provided for @payAfterAppointment.
  ///
  /// In en, this message translates to:
  /// **'Pay after your appointment'**
  String get payAfterAppointment;

  /// No description provided for @payNowWithChapa.
  ///
  /// In en, this message translates to:
  /// **'Pay now with Chapa'**
  String get payNowWithChapa;

  /// No description provided for @chapaMethods.
  ///
  /// In en, this message translates to:
  /// **'telebirr, CBE Birr or card'**
  String get chapaMethods;

  /// No description provided for @myAppointments.
  ///
  /// In en, this message translates to:
  /// **'My Appointments'**
  String get myAppointments;

  /// No description provided for @noBookingsYet.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get noBookingsYet;

  /// No description provided for @noBookingsHint.
  ///
  /// In en, this message translates to:
  /// **'Explore top barbershops and book your first slot.'**
  String get noBookingsHint;

  /// No description provided for @finishPayment.
  ///
  /// In en, this message translates to:
  /// **'Finish payment'**
  String get finishPayment;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get cancelBooking;

  /// No description provided for @cancelBookingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the booking: {error}'**
  String cancelBookingFailed(String error);

  /// No description provided for @specAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get specAll;

  /// No description provided for @specSkinFade.
  ///
  /// In en, this message translates to:
  /// **'Skin Fade'**
  String get specSkinFade;

  /// No description provided for @specBeardSculpting.
  ///
  /// In en, this message translates to:
  /// **'Beard Sculpting'**
  String get specBeardSculpting;

  /// No description provided for @specHotShave.
  ///
  /// In en, this message translates to:
  /// **'Hot Shave'**
  String get specHotShave;

  /// No description provided for @specScissorCut.
  ///
  /// In en, this message translates to:
  /// **'Scissor Cut'**
  String get specScissorCut;

  /// No description provided for @specExecutiveStyling.
  ///
  /// In en, this message translates to:
  /// **'Executive Styling'**
  String get specExecutiveStyling;

  /// No description provided for @findTopBarbers.
  ///
  /// In en, this message translates to:
  /// **'Find Top Barbers'**
  String get findTopBarbers;

  /// No description provided for @searchBarbersHint.
  ///
  /// In en, this message translates to:
  /// **'Search by barber name, specialty, or shop...'**
  String get searchBarbersHint;

  /// No description provided for @noBarbersMatching.
  ///
  /// In en, this message translates to:
  /// **'No barbers found matching \"{query}\"'**
  String noBarbersMatching(String query);

  /// No description provided for @bookWith.
  ///
  /// In en, this message translates to:
  /// **'Book with {name}'**
  String bookWith(String name);

  /// No description provided for @noServicesAtShop.
  ///
  /// In en, this message translates to:
  /// **'No services available at this shop yet.'**
  String get noServicesAtShop;

  /// No description provided for @partnerPortal.
  ///
  /// In en, this message translates to:
  /// **'Partner Business Portal'**
  String get partnerPortal;

  /// No description provided for @customizableApp.
  ///
  /// In en, this message translates to:
  /// **'Your Customizable Barbershop App'**
  String get customizableApp;

  /// No description provided for @customizableAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Branding, cover photo, opening hours & location'**
  String get customizableAppSubtitle;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @servicesButton.
  ///
  /// In en, this message translates to:
  /// **'Services ({count})'**
  String servicesButton(int count);

  /// No description provided for @manageBarbersButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Barbers ({count})'**
  String manageBarbersButton(int count);

  /// No description provided for @subscriptionAndBilling.
  ///
  /// In en, this message translates to:
  /// **'Subscription & billing'**
  String get subscriptionAndBilling;

  /// No description provided for @editInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Info'**
  String get editInfo;

  /// No description provided for @metricBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get metricBookings;

  /// No description provided for @activeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeCount(int count);

  /// No description provided for @metricEstRevenue.
  ///
  /// In en, this message translates to:
  /// **'Est. Revenue'**
  String get metricEstRevenue;

  /// No description provided for @metricGrossSales.
  ///
  /// In en, this message translates to:
  /// **'Gross sales'**
  String get metricGrossSales;

  /// No description provided for @appointmentsSchedule.
  ///
  /// In en, this message translates to:
  /// **'Appointments Schedule'**
  String get appointmentsSchedule;

  /// No description provided for @noAppointmentsFound.
  ///
  /// In en, this message translates to:
  /// **'No appointments found'**
  String get noAppointmentsFound;

  /// No description provided for @cancelSlot.
  ///
  /// In en, this message translates to:
  /// **'Cancel Slot'**
  String get cancelSlot;

  /// No description provided for @shopSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Customized shop settings saved successfully!'**
  String get shopSettingsSaved;

  /// No description provided for @customizeMyBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Customize My Barbershop'**
  String get customizeMyBarbershop;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @savingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Saving Updates...'**
  String get savingUpdates;

  /// No description provided for @publishCustomizations.
  ///
  /// In en, this message translates to:
  /// **'Publish Shop Customizations'**
  String get publishCustomizations;

  /// No description provided for @brandProfile.
  ///
  /// In en, this message translates to:
  /// **'Barbershop Brand Profile'**
  String get brandProfile;

  /// No description provided for @brandProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Changes made here instantly appear in the customer booking experience.'**
  String get brandProfileHint;

  /// No description provided for @sectionBranding.
  ///
  /// In en, this message translates to:
  /// **'Barbershop Branding & Info'**
  String get sectionBranding;

  /// No description provided for @barbershopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Barbershop Name *'**
  String get barbershopNameRequired;

  /// No description provided for @brandBio.
  ///
  /// In en, this message translates to:
  /// **'Brand Bio & Story'**
  String get brandBio;

  /// No description provided for @businessPhone.
  ///
  /// In en, this message translates to:
  /// **'Business Phone Number'**
  String get businessPhone;

  /// No description provided for @themePresets.
  ///
  /// In en, this message translates to:
  /// **'Quick Theme Aesthetic Presets:'**
  String get themePresets;

  /// No description provided for @coverPhotoUrl.
  ///
  /// In en, this message translates to:
  /// **'Cover Photo Image URL'**
  String get coverPhotoUrl;

  /// No description provided for @sectionAddress.
  ///
  /// In en, this message translates to:
  /// **'Physical Location & Address'**
  String get sectionAddress;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street Address'**
  String get streetAddress;

  /// No description provided for @subCity.
  ///
  /// In en, this message translates to:
  /// **'Sub-city'**
  String get subCity;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Business Schedule & Hours'**
  String get sectionSchedule;

  /// No description provided for @openingHour.
  ///
  /// In en, this message translates to:
  /// **'Opening Hour'**
  String get openingHour;

  /// No description provided for @closingHour.
  ///
  /// In en, this message translates to:
  /// **'Closing Hour'**
  String get closingHour;

  /// No description provided for @openWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'Open Working Days:'**
  String get openWorkingDays;

  /// No description provided for @presetRoyalGold.
  ///
  /// In en, this message translates to:
  /// **'Royal Gold & Noir'**
  String get presetRoyalGold;

  /// No description provided for @presetVintageGentleman.
  ///
  /// In en, this message translates to:
  /// **'Vintage Gentleman'**
  String get presetVintageGentleman;

  /// No description provided for @presetEmpireLuxury.
  ///
  /// In en, this message translates to:
  /// **'Empire Luxury'**
  String get presetEmpireLuxury;

  /// No description provided for @presetUrbanIndustrial.
  ///
  /// In en, this message translates to:
  /// **'Urban Industrial'**
  String get presetUrbanIndustrial;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String saveFailed(String error);

  /// No description provided for @defaultBarberTitle.
  ///
  /// In en, this message translates to:
  /// **'Stylist & Fade Specialist'**
  String get defaultBarberTitle;

  /// No description provided for @addBarberToShop.
  ///
  /// In en, this message translates to:
  /// **'Add Barber to Shop'**
  String get addBarberToShop;

  /// No description provided for @barberFullName.
  ///
  /// In en, this message translates to:
  /// **'Barber Full Name'**
  String get barberFullName;

  /// No description provided for @specialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization (e.g. Master Barber)'**
  String get specialization;

  /// No description provided for @mobileForLogin.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number (for login)'**
  String get mobileForLogin;

  /// No description provided for @barberPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional. The barber signs in with this number.'**
  String get barberPhoneHelper;

  /// No description provided for @selectAvatar.
  ///
  /// In en, this message translates to:
  /// **'Select Avatar Portrait:'**
  String get selectAvatar;

  /// No description provided for @invalidPhoneShort.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number (09... or 07...)'**
  String get invalidPhoneShort;

  /// No description provided for @addBarberFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add barber. Please try again.'**
  String get addBarberFailed;

  /// No description provided for @addBarber.
  ///
  /// In en, this message translates to:
  /// **'Add Barber'**
  String get addBarber;

  /// No description provided for @removeBarberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Barber?'**
  String get removeBarberTitle;

  /// No description provided for @removeBarberBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{name}\" from this barbershop?'**
  String removeBarberBody(String name);

  /// No description provided for @manageBarbersStaff.
  ///
  /// In en, this message translates to:
  /// **'Manage Barbers & Staff'**
  String get manageBarbersStaff;

  /// No description provided for @noBarbersYet.
  ///
  /// In en, this message translates to:
  /// **'No barbers added yet'**
  String get noBarbersYet;

  /// No description provided for @noBarbersHint.
  ///
  /// In en, this message translates to:
  /// **'Add barbers so clients can book appointments with them.'**
  String get noBarbersHint;

  /// No description provided for @loginInvitePending.
  ///
  /// In en, this message translates to:
  /// **'Login invite pending: {phone}'**
  String loginInvitePending(String phone);

  /// No description provided for @removeBarber.
  ///
  /// In en, this message translates to:
  /// **'Remove Barber'**
  String get removeBarber;

  /// No description provided for @addNewService.
  ///
  /// In en, this message translates to:
  /// **'Add New Service'**
  String get addNewService;

  /// No description provided for @serviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Service Name (e.g. Beard Trim)'**
  String get serviceNameHint;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @priceEtb.
  ///
  /// In en, this message translates to:
  /// **'Price (ETB)'**
  String get priceEtb;

  /// No description provided for @durationMins.
  ///
  /// In en, this message translates to:
  /// **'Duration (mins)'**
  String get durationMins;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add Service'**
  String get addService;

  /// No description provided for @manageServicesPricing.
  ///
  /// In en, this message translates to:
  /// **'Manage Services & Pricing'**
  String get manageServicesPricing;

  /// No description provided for @noServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services created yet'**
  String get noServicesYet;

  /// No description provided for @noServicesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add Service\" below to publish your salon pricing.'**
  String get noServicesHint;

  /// No description provided for @invalidServiceValues.
  ///
  /// In en, this message translates to:
  /// **'Enter a name, a price in ETB and a duration in minutes.'**
  String get invalidServiceValues;

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionTitle;

  /// No description provided for @plansTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plansTitle;

  /// No description provided for @plansIntro.
  ///
  /// In en, this message translates to:
  /// **'Pay monthly with telebirr, CBE Birr or card through Chapa. Paying early adds a month to your current end date.'**
  String get plansIntro;

  /// No description provided for @noPlansAvailable.
  ///
  /// In en, this message translates to:
  /// **'No plans are available right now. Please contact Crown & Blade support.'**
  String get noPlansAvailable;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment history'**
  String get paymentHistory;

  /// No description provided for @noEndDateSet.
  ///
  /// In en, this message translates to:
  /// **'No end date set'**
  String get noEndDateSet;

  /// No description provided for @endedAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ended {date} (1 day ago)} other{Ended {date} ({count} days ago)}}'**
  String endedAgo(int count, String date);

  /// No description provided for @trialEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Trial ends {date}'**
  String trialEndsOn(String date);

  /// No description provided for @renewsBy.
  ///
  /// In en, this message translates to:
  /// **'Renews by {date}'**
  String renewsBy(String date);

  /// No description provided for @endsToday.
  ///
  /// In en, this message translates to:
  /// **'{text} (today)'**
  String endsToday(String text);

  /// No description provided for @daysLeftSuffix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{text} (1 day left)} other{{text} ({count} days left)}}'**
  String daysLeftSuffix(int count, String text);

  /// No description provided for @barbersUsage.
  ///
  /// In en, this message translates to:
  /// **'Barbers: {count}'**
  String barbersUsage(int count);

  /// No description provided for @barbersUsageUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Barbers: {count} (unlimited)'**
  String barbersUsageUnlimited(int count);

  /// No description provided for @barbersUsageOf.
  ///
  /// In en, this message translates to:
  /// **'Barbers: {count} of {max}'**
  String barbersUsageOf(int count, int max);

  /// No description provided for @planTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Your shop has {count} barbers; this plan allows {max}.'**
  String planTooSmall(int count, int max);

  /// No description provided for @renewWithChapa.
  ///
  /// In en, this message translates to:
  /// **'Renew with Chapa'**
  String get renewWithChapa;

  /// No description provided for @payWithChapa.
  ///
  /// In en, this message translates to:
  /// **'Pay with Chapa'**
  String get payWithChapa;

  /// No description provided for @paymentHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment history is unavailable.'**
  String get paymentHistoryUnavailable;

  /// No description provided for @noSubscriptionPayments.
  ///
  /// In en, this message translates to:
  /// **'No subscription payments yet.'**
  String get noSubscriptionPayments;

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String untilDate(String date);

  /// No description provided for @planOneMonth.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan - 1 month'**
  String planOneMonth(String plan);

  /// No description provided for @preparingCheckout.
  ///
  /// In en, this message translates to:
  /// **'Preparing secure checkout...'**
  String get preparingCheckout;

  /// No description provided for @paymentProblem.
  ///
  /// In en, this message translates to:
  /// **'Payment problem'**
  String get paymentProblem;

  /// No description provided for @paymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment not completed yet. If you paid, it will show as paid shortly.'**
  String get paymentNotCompleted;

  /// No description provided for @subscriptionActiveUntilSentence.
  ///
  /// In en, this message translates to:
  /// **' Subscription active until {date}.'**
  String subscriptionActiveUntilSentence(String date);

  /// No description provided for @paymentReceivedAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment received: {amount}.{extra}'**
  String paymentReceivedAmount(String amount, String extra);

  /// No description provided for @paymentFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment failed or was cancelled. No money was taken. You can try again.'**
  String get paymentFailedRetry;

  /// No description provided for @chapaCheckoutDemo.
  ///
  /// In en, this message translates to:
  /// **'Chapa checkout (demo)'**
  String get chapaCheckoutDemo;

  /// No description provided for @chapaDemoNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: no money moves. Choose Pay to simulate a successful payment.'**
  String get chapaDemoNotice;

  /// No description provided for @cancelPayment.
  ///
  /// In en, this message translates to:
  /// **'Cancel payment'**
  String get cancelPayment;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @chapaNotConfirmedYet.
  ///
  /// In en, this message translates to:
  /// **'Chapa has not confirmed the payment yet. Finish it in the browser, then check again.'**
  String get chapaNotConfirmedYet;

  /// No description provided for @completeYourPayment.
  ///
  /// In en, this message translates to:
  /// **'Complete your payment'**
  String get completeYourPayment;

  /// No description provided for @completePaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} on the Chapa page that opened (telebirr, CBE Birr or card), then come back here.'**
  String completePaymentBody(String amount);

  /// No description provided for @payLater.
  ///
  /// In en, this message translates to:
  /// **'Pay later'**
  String get payLater;

  /// No description provided for @openAgain.
  ///
  /// In en, this message translates to:
  /// **'Open again'**
  String get openAgain;

  /// No description provided for @ivePaid.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid'**
  String get ivePaid;

  /// No description provided for @couldNotCheckPayment.
  ///
  /// In en, this message translates to:
  /// **'Could not check the payment'**
  String get couldNotCheckPayment;

  /// No description provided for @checkingPayment.
  ///
  /// In en, this message translates to:
  /// **'Checking your payment with Chapa...'**
  String get checkingPayment;

  /// No description provided for @subscriptionIsActive.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is active.'**
  String get subscriptionIsActive;

  /// No description provided for @subscriptionActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is active until {date}.'**
  String subscriptionActiveUntil(String date);

  /// No description provided for @bookingIsPaid.
  ///
  /// In en, this message translates to:
  /// **'Your booking is paid.'**
  String get bookingIsPaid;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paymentReceived;

  /// No description provided for @amountThen.
  ///
  /// In en, this message translates to:
  /// **'{amount}. {what}'**
  String amountThen(String amount, String what);

  /// No description provided for @stillProcessing.
  ///
  /// In en, this message translates to:
  /// **'Still processing'**
  String get stillProcessing;

  /// No description provided for @stillProcessingBody.
  ///
  /// In en, this message translates to:
  /// **'Chapa has not confirmed this payment yet. It will update automatically once it does.'**
  String get stillProcessingBody;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @noMoneyTaken.
  ///
  /// In en, this message translates to:
  /// **'No money was taken. You can try again.'**
  String get noMoneyTaken;

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @bannerSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your shop is suspended: customers cannot see or book it. Pay your subscription to reactivate it.'**
  String get bannerSuspended;

  /// No description provided for @bannerOverdueSoon.
  ///
  /// In en, this message translates to:
  /// **'Your subscription payment is overdue. The shop will be suspended soon unless you pay.'**
  String get bannerOverdueSoon;

  /// No description provided for @bannerOverdueToday.
  ///
  /// In en, this message translates to:
  /// **'Your subscription payment is overdue. The shop will be suspended today unless you pay.'**
  String get bannerOverdueToday;

  /// No description provided for @bannerOverdueInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your subscription payment is overdue. The shop will be suspended in 1 day unless you pay.} other{Your subscription payment is overdue. The shop will be suspended in {count} days unless you pay.}}'**
  String bannerOverdueInDays(int count);

  /// No description provided for @bannerTrialEndsToday.
  ///
  /// In en, this message translates to:
  /// **'Your free trial ends today. Pay now to keep taking bookings.'**
  String get bannerTrialEndsToday;

  /// No description provided for @bannerSubEndsToday.
  ///
  /// In en, this message translates to:
  /// **'Your subscription ends today. Pay now to keep taking bookings.'**
  String get bannerSubEndsToday;

  /// No description provided for @bannerTrialEndsIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your free trial ends in 1 day. Pay now to keep taking bookings.} other{Your free trial ends in {count} days. Pay now to keep taking bookings.}}'**
  String bannerTrialEndsIn(int count);

  /// No description provided for @bannerSubEndsIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your subscription ends in 1 day. Pay now to keep taking bookings.} other{Your subscription ends in {count} days. Pay now to keep taking bookings.}}'**
  String bannerSubEndsIn(int count);

  /// No description provided for @reactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get reactivate;

  /// No description provided for @cardMethod.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get cardMethod;

  /// No description provided for @errInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Ethiopian mobile number (09... or 07...).'**
  String get errInvalidPhone;

  /// No description provided for @errInvalidOwnerPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Ethiopian mobile number for the owner (09... or 07...).'**
  String get errInvalidOwnerPhone;

  /// No description provided for @errInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the SMS.'**
  String get errInvalidOtp;

  /// No description provided for @errWrongDemoCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. In demo mode the code is {code}.'**
  String errWrongDemoCode(String code);

  /// No description provided for @errRequestCodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Request a code first.'**
  String get errRequestCodeFirst;

  /// No description provided for @errInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name (up to 100 characters).'**
  String get errInvalidName;

  /// No description provided for @errVerifyPhoneFirst.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone number first.'**
  String get errVerifyPhoneFirst;

  /// No description provided for @errSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first.'**
  String get errSignInRequired;

  /// No description provided for @errPhoneAlreadyStaff.
  ///
  /// In en, this message translates to:
  /// **'This phone number already belongs to a {role} account.'**
  String errPhoneAlreadyStaff(String role);

  /// No description provided for @errSignInToBook.
  ///
  /// In en, this message translates to:
  /// **'Sign in to book an appointment.'**
  String get errSignInToBook;

  /// No description provided for @errInvalidTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'That time is not valid. Please pick another time.'**
  String get errInvalidTimeSlot;

  /// No description provided for @errServiceTooLong.
  ///
  /// In en, this message translates to:
  /// **'A service can be at most {minutes} minutes long.'**
  String errServiceTooLong(int minutes);

  /// No description provided for @errServerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the server can make this change.'**
  String get errServerOnly;

  /// No description provided for @errSlotTaken.
  ///
  /// In en, this message translates to:
  /// **'Sorry, that time was just taken. Please pick another slot.'**
  String get errSlotTaken;

  /// No description provided for @errBookingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not book this time. Check your connection and try again.'**
  String get errBookingFailed;

  /// No description provided for @errNoWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one working day.'**
  String get errNoWorkingDays;

  /// No description provided for @errInvalidWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'The end time must be after the start time.'**
  String get errInvalidWorkingHours;

  /// No description provided for @errPlanIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Plan id must be one of {ids}.'**
  String errPlanIdInvalid(String ids);

  /// No description provided for @errPlanNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Plan name is required.'**
  String get errPlanNameRequired;

  /// No description provided for @errPlanPriceNegative.
  ///
  /// In en, this message translates to:
  /// **'Price must be 0 or more.'**
  String get errPlanPriceNegative;

  /// No description provided for @errPlanPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'A paid plan needs a price above 0.'**
  String get errPlanPriceRequired;

  /// No description provided for @errPlanMaxBarbers.
  ///
  /// In en, this message translates to:
  /// **'Max barbers must be at least 1 (or -1 for unlimited).'**
  String get errPlanMaxBarbers;

  /// No description provided for @errPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do this.'**
  String get errPermissionDenied;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get errOffline;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @payErrBookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'This booking could not be found.'**
  String get payErrBookingNotFound;

  /// No description provided for @payErrBookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'This booking was cancelled.'**
  String get payErrBookingCancelled;

  /// No description provided for @payErrBookingRefunded.
  ///
  /// In en, this message translates to:
  /// **'This booking was refunded.'**
  String get payErrBookingRefunded;

  /// No description provided for @payErrCannotPayOnline.
  ///
  /// In en, this message translates to:
  /// **'This booking cannot be paid online.'**
  String get payErrCannotPayOnline;

  /// No description provided for @payErrNoValidPrice.
  ///
  /// In en, this message translates to:
  /// **'This has no valid price, so it cannot be paid online.'**
  String get payErrNoValidPrice;

  /// No description provided for @payErrNotYourBooking.
  ///
  /// In en, this message translates to:
  /// **'Only the customer who made this booking can pay for it.'**
  String get payErrNotYourBooking;

  /// No description provided for @payErrNotYourPayment.
  ///
  /// In en, this message translates to:
  /// **'This is not your payment.'**
  String get payErrNotYourPayment;

  /// No description provided for @payErrNotShopOwner.
  ///
  /// In en, this message translates to:
  /// **'Only the owner of this shop can pay its subscription.'**
  String get payErrNotShopOwner;

  /// No description provided for @payErrShopNotFound.
  ///
  /// In en, this message translates to:
  /// **'This barbershop could not be found.'**
  String get payErrShopNotFound;

  /// No description provided for @payErrPlanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This plan is not available.'**
  String get payErrPlanUnavailable;

  /// No description provided for @payErrUnknownPlan.
  ///
  /// In en, this message translates to:
  /// **'Unknown plan.'**
  String get payErrUnknownPlan;

  /// No description provided for @payErrPlanTooSmall.
  ///
  /// In en, this message translates to:
  /// **'This plan allows {max} barbers but the shop has {count}. Choose a bigger plan or remove barbers.'**
  String payErrPlanTooSmall(int max, int count);

  /// No description provided for @payErrBookingChanged.
  ///
  /// In en, this message translates to:
  /// **'Something changed while we prepared your payment. Please try again.'**
  String get payErrBookingChanged;

  /// No description provided for @payErrStillPreparing.
  ///
  /// In en, this message translates to:
  /// **'Your payment is still being prepared. Please try again in a moment.'**
  String get payErrStillPreparing;

  /// No description provided for @payErrLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Chapa checkout page. Please try again.'**
  String get payErrLaunchFailed;

  /// No description provided for @payErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some payment details are missing or invalid.'**
  String get payErrInvalid;

  /// No description provided for @payErrPrecondition.
  ///
  /// In en, this message translates to:
  /// **'This payment cannot be made right now.'**
  String get payErrPrecondition;

  /// No description provided for @payErrAdminsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only administrators can do this.'**
  String get payErrAdminsOnly;

  /// No description provided for @payErrPaymentNotFound.
  ///
  /// In en, this message translates to:
  /// **'This payment could not be found.'**
  String get payErrPaymentNotFound;

  /// No description provided for @payErrReviewNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'This payment is no longer waiting for review.'**
  String get payErrReviewNotNeeded;

  /// No description provided for @payErrReviewNotRefundable.
  ///
  /// In en, this message translates to:
  /// **'Only a successful payment can be marked as refunded.'**
  String get payErrReviewNotRefundable;

  /// No description provided for @viewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewAction;

  /// No description provided for @paymentsToReview.
  ///
  /// In en, this message translates to:
  /// **'Payments to review'**
  String get paymentsToReview;

  /// No description provided for @paymentsToReviewIntro.
  ///
  /// In en, this message translates to:
  /// **'These payments need a decision. Refund the customer in the Chapa dashboard first, then mark the payment here.'**
  String get paymentsToReviewIntro;

  /// No description provided for @noPaymentsToReview.
  ///
  /// In en, this message translates to:
  /// **'No payments need review'**
  String get noPaymentsToReview;

  /// No description provided for @noPaymentsToReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Payments for cancelled bookings, double payments and payments that could not be applied show up here.'**
  String get noPaymentsToReviewHint;

  /// No description provided for @paymentsToReviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load payments: {error}'**
  String paymentsToReviewLoadFailed(String error);

  /// No description provided for @reviewReasonCancelledBooking.
  ///
  /// In en, this message translates to:
  /// **'Paid for a cancelled booking'**
  String get reviewReasonCancelledBooking;

  /// No description provided for @reviewReasonDoublePayment.
  ///
  /// In en, this message translates to:
  /// **'Booking was paid twice'**
  String get reviewReasonDoublePayment;

  /// No description provided for @reviewReasonMissingBooking.
  ///
  /// In en, this message translates to:
  /// **'The booking no longer exists'**
  String get reviewReasonMissingBooking;

  /// No description provided for @reviewReasonRefundReported.
  ///
  /// In en, this message translates to:
  /// **'Chapa reported a refund that needs checking'**
  String get reviewReasonRefundReported;

  /// No description provided for @reviewReasonSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription payment could not be applied'**
  String get reviewReasonSubscription;

  /// No description provided for @reviewReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Needs a manual check'**
  String get reviewReasonOther;

  /// No description provided for @paymentTypeBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking payment'**
  String get paymentTypeBooking;

  /// No description provided for @paymentTypeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription payment'**
  String get paymentTypeSubscription;

  /// No description provided for @paymentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get paymentDetailsTitle;

  /// No description provided for @detailAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get detailAmount;

  /// No description provided for @detailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get detailStatus;

  /// No description provided for @detailCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get detailCreated;

  /// No description provided for @detailVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get detailVerified;

  /// No description provided for @detailShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get detailShop;

  /// No description provided for @detailBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get detailBooking;

  /// No description provided for @detailCustomer.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get detailCustomer;

  /// No description provided for @detailTxRef.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference'**
  String get detailTxRef;

  /// No description provided for @detailChapaReference.
  ///
  /// In en, this message translates to:
  /// **'Chapa reference'**
  String get detailChapaReference;

  /// No description provided for @detailMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get detailMethod;

  /// No description provided for @detailPaymentId.
  ///
  /// In en, this message translates to:
  /// **'Payment ID'**
  String get detailPaymentId;

  /// No description provided for @reviewNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get reviewNoteLabel;

  /// No description provided for @reviewNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Refunded on 13 Nov, Chapa ref ...'**
  String get reviewNoteHint;

  /// No description provided for @markRefundedInChapa.
  ///
  /// In en, this message translates to:
  /// **'I refunded it in Chapa'**
  String get markRefundedInChapa;

  /// No description provided for @markNoAction.
  ///
  /// In en, this message translates to:
  /// **'No action needed'**
  String get markNoAction;

  /// No description provided for @confirmRefundTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as refunded?'**
  String get confirmRefundTitle;

  /// No description provided for @confirmRefundBody.
  ///
  /// In en, this message translates to:
  /// **'Only continue if you already refunded {amount} in the Chapa dashboard. The payment and its booking will show as refunded.'**
  String confirmRefundBody(String amount);

  /// No description provided for @reviewClosedRefunded.
  ///
  /// In en, this message translates to:
  /// **'Marked as refunded.'**
  String get reviewClosedRefunded;

  /// No description provided for @reviewClosedNoAction.
  ///
  /// In en, this message translates to:
  /// **'Review closed.'**
  String get reviewClosedNoAction;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not close the review: {error}'**
  String reviewFailed(String error);

  /// No description provided for @editWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Working days and hours'**
  String get editWorkingHours;

  /// No description provided for @barberHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: working hours'**
  String barberHoursTitle(String name);

  /// No description provided for @followShopHours.
  ///
  /// In en, this message translates to:
  /// **'Same as the shop'**
  String get followShopHours;

  /// No description provided for @followShopHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Works on the shop\'s days, from opening to closing time.'**
  String get followShopHoursSubtitle;

  /// No description provided for @workingDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Working days'**
  String get workingDaysLabel;

  /// No description provided for @startsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get startsAt;

  /// No description provided for @endsAt.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get endsAt;

  /// No description provided for @workingHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Working hours saved.'**
  String get workingHoursSaved;

  /// No description provided for @shopHoursSummary.
  ///
  /// In en, this message translates to:
  /// **'Shop hours'**
  String get shopHoursSummary;

  /// No description provided for @errAccountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account. Check your connection and try again.'**
  String get errAccountLoadFailed;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// No description provided for @reviewsRateAction.
  ///
  /// In en, this message translates to:
  /// **'Rate visit'**
  String get reviewsRateAction;

  /// No description provided for @reviewsYourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get reviewsYourRating;

  /// No description provided for @reviewsRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your visit'**
  String get reviewsRateTitle;

  /// No description provided for @reviewsRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{service} with {barber}'**
  String reviewsRateSubtitle(String service, String barber);

  /// No description provided for @reviewsStarsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String reviewsStarsLabel(int count);

  /// No description provided for @reviewsPickRating.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate.'**
  String get reviewsPickRating;

  /// No description provided for @reviewsCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get reviewsCommentLabel;

  /// No description provided for @reviewsCommentHint.
  ///
  /// In en, this message translates to:
  /// **'What did you like? What could be better?'**
  String get reviewsCommentHint;

  /// No description provided for @reviewsSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send review'**
  String get reviewsSubmit;

  /// No description provided for @reviewsThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your review!'**
  String get reviewsThanks;

  /// No description provided for @reviewsSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your review: {error}'**
  String reviewsSubmitFailed(String error);

  /// No description provided for @reviewsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews yet} =1{1 review} other{{count} reviews}}'**
  String reviewsCountLabel(int count);

  /// No description provided for @reviewsNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get reviewsNew;

  /// No description provided for @reviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Customers can rate their visit after it is completed.'**
  String get reviewsEmpty;

  /// No description provided for @reviewsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all reviews ({count})'**
  String reviewsSeeAll(int count);

  /// No description provided for @reviewsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get reviewsLoadMore;

  /// No description provided for @reviewsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the reviews.'**
  String get reviewsLoadFailed;

  /// No description provided for @reviewsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get reviewsRetry;

  /// No description provided for @reviewsOwnerReply.
  ///
  /// In en, this message translates to:
  /// **'Reply from the shop'**
  String get reviewsOwnerReply;

  /// No description provided for @reviewsReplyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reviewsReplyAction;

  /// No description provided for @reviewsEditReply.
  ///
  /// In en, this message translates to:
  /// **'Edit reply'**
  String get reviewsEditReply;

  /// No description provided for @reviewsReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Your public reply'**
  String get reviewsReplyLabel;

  /// No description provided for @reviewsReplySave.
  ///
  /// In en, this message translates to:
  /// **'Save reply'**
  String get reviewsReplySave;

  /// No description provided for @reviewsReplySaved.
  ///
  /// In en, this message translates to:
  /// **'Reply saved.'**
  String get reviewsReplySaved;

  /// No description provided for @reviewsAwaitingReply.
  ///
  /// In en, this message translates to:
  /// **'No reply yet'**
  String get reviewsAwaitingReply;

  /// No description provided for @reviewsOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Reviews & replies'**
  String get reviewsOpenButton;

  /// No description provided for @reviewsMyReviews.
  ///
  /// In en, this message translates to:
  /// **'My reviews'**
  String get reviewsMyReviews;

  /// No description provided for @reviewsBarberTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews for {name}'**
  String reviewsBarberTitle(String name);

  /// No description provided for @reviewsSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'{rating} out of 5 · {count, plural, =1{1 review} other{{count} reviews}}'**
  String reviewsSummaryLine(String rating, int count);

  /// No description provided for @reviewsRatedSemantics.
  ///
  /// In en, this message translates to:
  /// **'Rated {rating} out of 5'**
  String reviewsRatedSemantics(String rating);

  /// No description provided for @reviewsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get reviewsCustomer;

  /// No description provided for @reviewsErrNotYourBooking.
  ///
  /// In en, this message translates to:
  /// **'You can only rate your own visits.'**
  String get reviewsErrNotYourBooking;

  /// No description provided for @reviewsErrNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'You can rate a visit once it is completed.'**
  String get reviewsErrNotCompleted;

  /// No description provided for @reviewsErrAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'You have already rated this visit.'**
  String get reviewsErrAlreadyReviewed;

  /// No description provided for @reviewsErrInvalidRating.
  ///
  /// In en, this message translates to:
  /// **'Choose from 1 to 5 stars.'**
  String get reviewsErrInvalidRating;

  /// No description provided for @reviewsErrCommentTooLong.
  ///
  /// In en, this message translates to:
  /// **'The comment can be at most {max} characters.'**
  String reviewsErrCommentTooLong(int max);

  /// No description provided for @reviewsErrReplyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Write a reply of up to {max} characters.'**
  String reviewsErrReplyInvalid(int max);

  /// No description provided for @reviewsErrOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the shop owner can reply to reviews.'**
  String get reviewsErrOwnerOnly;

  /// No description provided for @reviewsErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This review no longer exists.'**
  String get reviewsErrNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
