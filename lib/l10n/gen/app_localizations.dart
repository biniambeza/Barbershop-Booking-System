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

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String privacyPolicyUpdated(String date);

  /// No description provided for @privacyOpenWeb.
  ///
  /// In en, this message translates to:
  /// **'Open on the web'**
  String get privacyOpenWeb;

  /// No description provided for @privacyDeletePageLink.
  ///
  /// In en, this message translates to:
  /// **'How to delete your account'**
  String get privacyDeletePageLink;

  /// No description provided for @privacyLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get privacyLinkFailed;

  /// No description provided for @privacyConsentPrefix.
  ///
  /// In en, this message translates to:
  /// **'By signing up or signing in you agree to our'**
  String get privacyConsentPrefix;

  /// No description provided for @deleteAccountMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountMenu;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account'**
  String get deleteAccountHeroTitle;

  /// No description provided for @deleteAccountHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile and login are removed for good. This cannot be undone.'**
  String get deleteAccountHeroBody;

  /// No description provided for @deleteAccountWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'What happens'**
  String get deleteAccountWhatHappens;

  /// No description provided for @deleteAccountCancelCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{You have no upcoming bookings to cancel.} =1{Your 1 upcoming booking will be cancelled.} other{Your {count} upcoming bookings will be cancelled.}}'**
  String deleteAccountCancelCount(int count);

  /// No description provided for @deleteAccountPaidRefund.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 paid booking will be flagged for a refund. The shop keeps your phone number on it until the money is sent back.} other{{count} paid bookings will be flagged for a refund. The shop keeps your phone number on them until the money is sent back.}}'**
  String deleteAccountPaidRefund(int count);

  /// No description provided for @deleteAccountKeptInCutoff.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking starts too soon to cancel in the app. It stays with the shop without your name; call the shop if you will not come.} other{{count} bookings start too soon to cancel in the app. They stay with the shop without your name; call the shop if you will not come.}}'**
  String deleteAccountKeptInCutoff(int count);

  /// No description provided for @deleteAccountBarberCancel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 customer booking with you will be cancelled and the customer told.} other{{count} customer bookings with you will be cancelled and the customers told.}}'**
  String deleteAccountBarberCancel(int count);

  /// No description provided for @deleteAccountBarberLeaves.
  ///
  /// In en, this message translates to:
  /// **'You are removed from {shop}.'**
  String deleteAccountBarberLeaves(String shop);

  /// No description provided for @deleteAccountYourShop.
  ///
  /// In en, this message translates to:
  /// **'your shop'**
  String get deleteAccountYourShop;

  /// No description provided for @deleteAccountReviews.
  ///
  /// In en, this message translates to:
  /// **'Your reviews keep their stars but show \"Former customer\" and lose the comment.'**
  String get deleteAccountReviews;

  /// No description provided for @deleteAccountBookingsHistory.
  ///
  /// In en, this message translates to:
  /// **'Past bookings stay in the shop\'s history without your name and phone number.'**
  String get deleteAccountBookingsHistory;

  /// No description provided for @deleteAccountPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Your profile, inbox, invitations, favourites and login are deleted.'**
  String get deleteAccountPersonalData;

  /// No description provided for @deleteAccountPendingLogin.
  ///
  /// In en, this message translates to:
  /// **'Your data is already deleted. Confirm it\'s you once more to delete your login.'**
  String get deleteAccountPendingLogin;

  /// No description provided for @deleteAccountReauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get deleteAccountReauthTitle;

  /// No description provided for @deleteAccountConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String deleteAccountConfirmLabel(String word);

  /// No description provided for @deleteAccountConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE exactly to confirm.'**
  String get deleteAccountConfirmMismatch;

  /// No description provided for @deleteAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get deleteAccountPasswordLabel;

  /// No description provided for @deleteAccountPasswordOrGoogle.
  ///
  /// In en, this message translates to:
  /// **'Or leave it empty to confirm with Google.'**
  String get deleteAccountPasswordOrGoogle;

  /// No description provided for @deleteAccountReauthGoogle.
  ///
  /// In en, this message translates to:
  /// **'You will be asked to sign in with Google again.'**
  String get deleteAccountReauthGoogle;

  /// No description provided for @deleteAccountSubmit.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountSubmit;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get deleteAccountDone;

  /// No description provided for @deleteAccountErrReauth.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign in again to finish deleting your account, then tap Delete again.'**
  String get deleteAccountErrReauth;

  /// No description provided for @deleteAccountErrReauthCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was cancelled. Nothing was deleted.'**
  String get deleteAccountErrReauthCancelled;

  /// No description provided for @deleteAccountErrStep.
  ///
  /// In en, this message translates to:
  /// **'Deleting stopped at: {step} Tap Delete again to continue where it stopped.'**
  String deleteAccountErrStep(String step);

  /// No description provided for @deleteAccountErrFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be deleted. Try again.'**
  String get deleteAccountErrFailed;

  /// No description provided for @deleteStepCancelBookings.
  ///
  /// In en, this message translates to:
  /// **'Cancelling your bookings…'**
  String get deleteStepCancelBookings;

  /// No description provided for @deleteStepReviews.
  ///
  /// In en, this message translates to:
  /// **'Updating your reviews…'**
  String get deleteStepReviews;

  /// No description provided for @deleteStepBookings.
  ///
  /// In en, this message translates to:
  /// **'Removing your name from bookings…'**
  String get deleteStepBookings;

  /// No description provided for @deleteStepLeaveShop.
  ///
  /// In en, this message translates to:
  /// **'Removing you from the shop…'**
  String get deleteStepLeaveShop;

  /// No description provided for @deleteStepPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Deleting your inbox and invitations…'**
  String get deleteStepPersonalData;

  /// No description provided for @deleteStepProfile.
  ///
  /// In en, this message translates to:
  /// **'Deleting your profile…'**
  String get deleteStepProfile;

  /// No description provided for @deleteStepLogin.
  ///
  /// In en, this message translates to:
  /// **'Deleting your login…'**
  String get deleteStepLogin;

  /// No description provided for @deleteAccountOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove your shop first'**
  String get deleteAccountOwnerTitle;

  /// No description provided for @deleteAccountOwnerBody.
  ///
  /// In en, this message translates to:
  /// **'You own {shop}. An account that owns a shop cannot be deleted. Ask the admin to remove the shop: its upcoming bookings are cancelled and the customers told. You then become a customer and can delete your account here.'**
  String deleteAccountOwnerBody(String shop);

  /// No description provided for @deleteAccountLastAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'You are the only admin'**
  String get deleteAccountLastAdminTitle;

  /// No description provided for @deleteAccountLastAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Make another person an admin first (Users tab), then you can delete your account.'**
  String get deleteAccountLastAdminBody;

  /// No description provided for @shopRemovalNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the admin (optional)'**
  String get shopRemovalNoteLabel;

  /// No description provided for @shopRemovalRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Ask the admin to remove my shop'**
  String get shopRemovalRequestButton;

  /// No description provided for @shopRemovalSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent to the admin.'**
  String get shopRemovalSent;

  /// No description provided for @shopRemovalPending.
  ///
  /// In en, this message translates to:
  /// **'You asked on {date}. The admin will remove the shop and may contact you.'**
  String shopRemovalPending(String date);

  /// No description provided for @shopRemovalWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw request'**
  String get shopRemovalWithdraw;

  /// No description provided for @shopRemovalDismissed.
  ///
  /// In en, this message translates to:
  /// **'The admin dismissed your request on {date}. You can send it again.'**
  String shopRemovalDismissed(String date);

  /// No description provided for @shopRemovalNoteTooLong.
  ///
  /// In en, this message translates to:
  /// **'The note can be at most {max} characters.'**
  String shopRemovalNoteTooLong(int max);

  /// No description provided for @shopRemovalStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get shopRemovalStatusPending;

  /// No description provided for @shopRemovalStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get shopRemovalStatusDone;

  /// No description provided for @shopRemovalStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get shopRemovalStatusDismissed;

  /// No description provided for @formerCustomer.
  ///
  /// In en, this message translates to:
  /// **'Former customer'**
  String get formerCustomer;

  /// No description provided for @adminRemovalRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop removal requests'**
  String get adminRemovalRequestsTitle;

  /// No description provided for @adminRemovalHelp.
  ///
  /// In en, this message translates to:
  /// **'Owners who want to delete their account ask here first. Open the shop and delete it (Delete shop), then mark the request done. The owner becomes a customer and can delete the account in the app.'**
  String get adminRemovalHelp;

  /// No description provided for @adminRemovalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No requests.'**
  String get adminRemovalEmpty;

  /// No description provided for @adminRemovalRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Asked on {date}'**
  String adminRemovalRequestedOn(String date);

  /// No description provided for @adminRemovalShopGone.
  ///
  /// In en, this message translates to:
  /// **'The shop is already removed.'**
  String get adminRemovalShopGone;

  /// No description provided for @adminRemovalOpenShop.
  ///
  /// In en, this message translates to:
  /// **'Open shop'**
  String get adminRemovalOpenShop;

  /// No description provided for @adminRemovalMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get adminRemovalMarkDone;

  /// No description provided for @adminRemovalDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get adminRemovalDismiss;

  /// No description provided for @portfolioTitle.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolioTitle;

  /// No description provided for @portfolioOfBarber.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s work'**
  String portfolioOfBarber(String name);

  /// No description provided for @portfolioPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String portfolioPhotoCount(int count);

  /// No description provided for @portfolioShopSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'See their work'**
  String get portfolioShopSectionTitle;

  /// No description provided for @portfolioShopSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Haircuts by this shop\'s barbers'**
  String get portfolioShopSectionHint;

  /// No description provided for @portfolioSeeWork.
  ///
  /// In en, this message translates to:
  /// **'See {name}\'s work'**
  String portfolioSeeWork(String name);

  /// No description provided for @portfolioEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get portfolioEmpty;

  /// No description provided for @portfolioBookStyle.
  ///
  /// In en, this message translates to:
  /// **'Book this style with {name}'**
  String portfolioBookStyle(String name);

  /// No description provided for @portfolioViewerCounter.
  ///
  /// In en, this message translates to:
  /// **'{index} / {total}'**
  String portfolioViewerCounter(int index, int total);

  /// No description provided for @portfolioPhotoSemantics.
  ///
  /// In en, this message translates to:
  /// **'Portfolio photo {index}'**
  String portfolioPhotoSemantics(int index);

  /// No description provided for @portfolioManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Portfolio photos'**
  String get portfolioManageTitle;

  /// No description provided for @portfolioManageIntro.
  ///
  /// In en, this message translates to:
  /// **'Photos of your best haircuts help customers choose you. Up to {max} photos.'**
  String portfolioManageIntro(int max);

  /// No description provided for @portfolioPublicNotice.
  ///
  /// In en, this message translates to:
  /// **'Portfolio photos are public. Only post photos your customers agreed to share, with no names or phone numbers.'**
  String get portfolioPublicNotice;

  /// No description provided for @portfolioCountOfMax.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} photos'**
  String portfolioCountOfMax(int count, int max);

  /// No description provided for @portfolioAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get portfolioAddPhoto;

  /// No description provided for @portfolioTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get portfolioTakePhoto;

  /// No description provided for @portfolioChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get portfolioChooseFromGallery;

  /// No description provided for @portfolioCaptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Style name (optional)'**
  String get portfolioCaptionLabel;

  /// No description provided for @portfolioCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Low fade'**
  String get portfolioCaptionHint;

  /// No description provided for @portfolioEditCaption.
  ///
  /// In en, this message translates to:
  /// **'Edit style name'**
  String get portfolioEditCaption;

  /// No description provided for @portfolioDeletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get portfolioDeletePhoto;

  /// No description provided for @portfolioDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get portfolioDeleteConfirmTitle;

  /// No description provided for @portfolioDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Customers will no longer see it.'**
  String get portfolioDeleteConfirmBody;

  /// No description provided for @portfolioAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added.'**
  String get portfolioAdded;

  /// No description provided for @portfolioDeleted.
  ///
  /// In en, this message translates to:
  /// **'Photo deleted.'**
  String get portfolioDeleted;

  /// No description provided for @portfolioCaptionSaved.
  ///
  /// In en, this message translates to:
  /// **'Style name saved.'**
  String get portfolioCaptionSaved;

  /// No description provided for @portfolioSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving photo...'**
  String get portfolioSaving;

  /// No description provided for @portfolioFull.
  ///
  /// In en, this message translates to:
  /// **'You have {max} photos. Delete one to add another.'**
  String portfolioFull(int max);

  /// No description provided for @portfolioErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only this barber and the shop owner can change this portfolio.'**
  String get portfolioErrNotAllowed;

  /// No description provided for @portfolioErrCaptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the style name to {max} characters or fewer.'**
  String portfolioErrCaptionTooLong(int max);

  /// No description provided for @portfolioErrImage.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be used. Try another one.'**
  String get portfolioErrImage;

  /// No description provided for @portfolioErrSlotTaken.
  ///
  /// In en, this message translates to:
  /// **'Another photo was just added. Please try again.'**
  String get portfolioErrSlotTaken;

  /// No description provided for @portfolioErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This photo was already deleted.'**
  String get portfolioErrNotFound;

  /// No description provided for @portfolioLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the photos.'**
  String get portfolioLoadFailed;

  /// No description provided for @portfolioRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get portfolioRetry;

  /// No description provided for @portfolioDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'My portfolio'**
  String get portfolioDashboardTitle;

  /// No description provided for @portfolioDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show customers your best haircuts'**
  String get portfolioDashboardSubtitle;

  /// No description provided for @rcptPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay by transfer'**
  String get rcptPayTitle;

  /// No description provided for @rcptEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with telebirr or CBE'**
  String get rcptEntryTitle;

  /// No description provided for @rcptEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Send the subscription fee, then upload the receipt. Your subscription is extended once it is verified.'**
  String get rcptEntryBody;

  /// No description provided for @rcptIntro.
  ///
  /// In en, this message translates to:
  /// **'1. Pick a period and send the amount. 2. Enter the transaction number and attach the receipt. 3. Once the receipt is verified, the days are added to your subscription.'**
  String get rcptIntro;

  /// No description provided for @rcptCurrentSub.
  ///
  /// In en, this message translates to:
  /// **'Current subscription'**
  String get rcptCurrentSub;

  /// No description provided for @rcptPaidUntil.
  ///
  /// In en, this message translates to:
  /// **'Paid until {date}'**
  String rcptPaidUntil(String date);

  /// No description provided for @rcptNoEnd.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get rcptNoEnd;

  /// No description provided for @rcptPricesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prices'**
  String get rcptPricesTitle;

  /// No description provided for @rcptDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String rcptDays(int count);

  /// No description provided for @rcptTierUse.
  ///
  /// In en, this message translates to:
  /// **'Tap to use this amount'**
  String get rcptTierUse;

  /// No description provided for @rcptWhereToPay.
  ///
  /// In en, this message translates to:
  /// **'Where to pay'**
  String get rcptWhereToPay;

  /// No description provided for @rcptMethodTelebirr.
  ///
  /// In en, this message translates to:
  /// **'telebirr'**
  String get rcptMethodTelebirr;

  /// No description provided for @rcptMethodCbe.
  ///
  /// In en, this message translates to:
  /// **'Commercial Bank of Ethiopia (CBE)'**
  String get rcptMethodCbe;

  /// No description provided for @rcptMethodCbeShort.
  ///
  /// In en, this message translates to:
  /// **'CBE'**
  String get rcptMethodCbeShort;

  /// No description provided for @rcptMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other bank'**
  String get rcptMethodOther;

  /// No description provided for @rcptReceiverNumber.
  ///
  /// In en, this message translates to:
  /// **'telebirr number'**
  String get rcptReceiverNumber;

  /// No description provided for @rcptReceiverAccount.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get rcptReceiverAccount;

  /// No description provided for @rcptReceiverName.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String rcptReceiverName(String name);

  /// No description provided for @rcptNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet. Please contact support.'**
  String get rcptNotConfigured;

  /// No description provided for @rcvSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up where shop owners pay you'**
  String get rcvSetupTitle;

  /// No description provided for @rcvSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Owners can\'t pay their subscription until you add your telebirr number or CBE account.'**
  String get rcvSetupBody;

  /// No description provided for @rcvSetupButton.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get rcvSetupButton;

  /// No description provided for @rcvSetupDotLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment setup needed'**
  String get rcvSetupDotLabel;

  /// No description provided for @rcvErrPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter an Ethiopian mobile number, e.g. 0911 223344.'**
  String get rcvErrPhone;

  /// No description provided for @rcvErrCbe.
  ///
  /// In en, this message translates to:
  /// **'Enter the 13-digit CBE account number that starts with 1000.'**
  String get rcvErrCbe;

  /// No description provided for @rcvErrPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Replace the XXXX sample with your real number.'**
  String get rcvErrPlaceholder;

  /// No description provided for @rcvErrNameShort.
  ///
  /// In en, this message translates to:
  /// **'Enter the account holder\'s name (at least 2 characters).'**
  String get rcvErrNameShort;

  /// No description provided for @rcvErrNameLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most 80 characters.'**
  String get rcvErrNameLong;

  /// No description provided for @rcvErrFix.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields.'**
  String get rcvErrFix;

  /// No description provided for @rcvTelebirrOptional.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if you don\'t take telebirr. Owners won\'t see it.'**
  String get rcvTelebirrOptional;

  /// No description provided for @rcvCbeOptional.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if you don\'t take CBE transfers. Owners won\'t see it.'**
  String get rcvCbeOptional;

  /// No description provided for @rcvPaymentsNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Payments aren\'t open yet — please check back soon.'**
  String get rcvPaymentsNotOpen;

  /// No description provided for @rcptCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get rcptCopy;

  /// No description provided for @rcptCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get rcptCopied;

  /// No description provided for @rcptSubmitTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your receipt'**
  String get rcptSubmitTitle;

  /// No description provided for @rcptMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get rcptMethodLabel;

  /// No description provided for @rcptTxLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction number'**
  String get rcptTxLabel;

  /// No description provided for @rcptTxHintTelebirr.
  ///
  /// In en, this message translates to:
  /// **'e.g. CHK1AB2CDE (in the telebirr SMS)'**
  String get rcptTxHintTelebirr;

  /// No description provided for @rcptTxHintCbe.
  ///
  /// In en, this message translates to:
  /// **'e.g. FT2412345ABC (on the CBE receipt)'**
  String get rcptTxHintCbe;

  /// No description provided for @rcptTxHintOther.
  ///
  /// In en, this message translates to:
  /// **'The reference on your receipt'**
  String get rcptTxHintOther;

  /// No description provided for @rcptSuffixLabel.
  ///
  /// In en, this message translates to:
  /// **'Last 8 digits of your account (optional)'**
  String get rcptSuffixLabel;

  /// No description provided for @rcptSuffixHelper.
  ///
  /// In en, this message translates to:
  /// **'Helps us open your CBE receipt.'**
  String get rcptSuffixHelper;

  /// No description provided for @rcptAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount paid (ETB)'**
  String get rcptAmountLabel;

  /// No description provided for @rcptAmountGrants.
  ///
  /// In en, this message translates to:
  /// **'Adds {days} to your subscription'**
  String rcptAmountGrants(String days);

  /// No description provided for @rcptAmountBelowMin.
  ///
  /// In en, this message translates to:
  /// **'The minimum payment is {amount}'**
  String rcptAmountBelowMin(String amount);

  /// No description provided for @rcptPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo or screenshot'**
  String get rcptPhotoLabel;

  /// No description provided for @rcptPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended: it makes verification faster.'**
  String get rcptPhotoHint;

  /// No description provided for @rcptTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get rcptTakePhoto;

  /// No description provided for @rcptChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get rcptChooseImage;

  /// No description provided for @rcptRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get rcptRemovePhoto;

  /// No description provided for @rcptPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'That image can\'t be used. Try another photo or screenshot.'**
  String get rcptPhotoFailed;

  /// No description provided for @rcptSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit receipt'**
  String get rcptSubmit;

  /// No description provided for @rcptSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Receipt submitted. We\'ll notify you when it\'s verified.'**
  String get rcptSubmitted;

  /// No description provided for @rcptHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your receipts'**
  String get rcptHistoryTitle;

  /// No description provided for @rcptNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No receipts submitted yet.'**
  String get rcptNoHistory;

  /// No description provided for @rcptStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting verification'**
  String get rcptStatusPending;

  /// No description provided for @rcptStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get rcptStatusVerified;

  /// No description provided for @rcptStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rcptStatusRejected;

  /// No description provided for @rcptStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Being checked'**
  String get rcptStatusNeedsReview;

  /// No description provided for @rcptGranted.
  ///
  /// In en, this message translates to:
  /// **'{days} added'**
  String rcptGranted(String days);

  /// No description provided for @rcptVerifiedAuto.
  ///
  /// In en, this message translates to:
  /// **'Verified automatically'**
  String get rcptVerifiedAuto;

  /// No description provided for @rcptReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get rcptReasonTitle;

  /// No description provided for @rcptReasonLine.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String rcptReasonLine(String reason);

  /// No description provided for @rcptReasonAmountTooLow.
  ///
  /// In en, this message translates to:
  /// **'The amount is below the cheapest subscription.'**
  String get rcptReasonAmountTooLow;

  /// No description provided for @rcptReasonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This transaction has already been used.'**
  String get rcptReasonDuplicate;

  /// No description provided for @rcptReasonNotFound.
  ///
  /// In en, this message translates to:
  /// **'The official receipt could not be found.'**
  String get rcptReasonNotFound;

  /// No description provided for @rcptReasonNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'The transaction is not completed.'**
  String get rcptReasonNotCompleted;

  /// No description provided for @rcptReasonReceiverMismatch.
  ///
  /// In en, this message translates to:
  /// **'The money was not sent to the platform\'s account.'**
  String get rcptReasonReceiverMismatch;

  /// No description provided for @rcptReasonAmountMismatch.
  ///
  /// In en, this message translates to:
  /// **'The receipt shows a lower amount.'**
  String get rcptReasonAmountMismatch;

  /// No description provided for @rcptReasonTooOld.
  ///
  /// In en, this message translates to:
  /// **'The receipt is more than 30 days old.'**
  String get rcptReasonTooOld;

  /// No description provided for @rcptReasonFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'The receipt couldn\'t be checked automatically. An admin will review it.'**
  String get rcptReasonFetchFailed;

  /// No description provided for @rcptReasonUnsupported.
  ///
  /// In en, this message translates to:
  /// **'An admin checks payments made this way.'**
  String get rcptReasonUnsupported;

  /// No description provided for @rcptErrOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the shop owner can do this.'**
  String get rcptErrOwnerOnly;

  /// No description provided for @rcptErrAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the platform admin can do this.'**
  String get rcptErrAdminOnly;

  /// No description provided for @rcptErrShopNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shop not found.'**
  String get rcptErrShopNotFound;

  /// No description provided for @rcptErrTxId.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid transaction number.'**
  String get rcptErrTxId;

  /// No description provided for @rcptErrAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount you paid.'**
  String get rcptErrAmount;

  /// No description provided for @rcptErrDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This transaction number has already been submitted.'**
  String get rcptErrDuplicate;

  /// No description provided for @rcptErrImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is too large.'**
  String get rcptErrImageTooLarge;

  /// No description provided for @rcptErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Receipt not found.'**
  String get rcptErrNotFound;

  /// No description provided for @rcptErrNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This receipt has already been decided.'**
  String get rcptErrNotOpen;

  /// No description provided for @rcptErrReason.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason (up to 300 characters).'**
  String get rcptErrReason;

  /// No description provided for @rcptErrPricing.
  ///
  /// In en, this message translates to:
  /// **'Check the prices: every period needs whole days and an amount, and a longer period must cost more.'**
  String get rcptErrPricing;

  /// No description provided for @rcptAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription receipts'**
  String get rcptAdminTitle;

  /// No description provided for @rcptAdminIntro.
  ///
  /// In en, this message translates to:
  /// **'Open the official receipt and check the amount, receiver and date, then approve or reject.'**
  String get rcptAdminIntro;

  /// No description provided for @rcptAdminOpenSection.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get rcptAdminOpenSection;

  /// No description provided for @rcptAdminDecidedSection.
  ///
  /// In en, this message translates to:
  /// **'Recently decided'**
  String get rcptAdminDecidedSection;

  /// No description provided for @rcptAdminEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review.'**
  String get rcptAdminEmpty;

  /// No description provided for @rcptAdminLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load receipts: {error}'**
  String rcptAdminLoadFailed(String error);

  /// No description provided for @rcptAdminWouldGrant.
  ///
  /// In en, this message translates to:
  /// **'Grants {days}'**
  String rcptAdminWouldGrant(String days);

  /// No description provided for @rcptAdminTooLow.
  ///
  /// In en, this message translates to:
  /// **'Below the cheapest period'**
  String get rcptAdminTooLow;

  /// No description provided for @rcptAdminSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent {date}'**
  String rcptAdminSubmitted(String date);

  /// No description provided for @rcptAdminSubmittedLabel.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get rcptAdminSubmittedLabel;

  /// No description provided for @rcptAdminNoImage.
  ///
  /// In en, this message translates to:
  /// **'No photo attached.'**
  String get rcptAdminNoImage;

  /// No description provided for @rcptAdminOpenOfficial.
  ///
  /// In en, this message translates to:
  /// **'Open official receipt'**
  String get rcptAdminOpenOfficial;

  /// No description provided for @rcptAdminNoOfficial.
  ///
  /// In en, this message translates to:
  /// **'This method has no official receipt page. Check the photo and your bank statement.'**
  String get rcptAdminNoOfficial;

  /// No description provided for @rcptAdminVerifiedAmount.
  ///
  /// In en, this message translates to:
  /// **'Verified amount (ETB)'**
  String get rcptAdminVerifiedAmount;

  /// No description provided for @rcptAdminNewEnd.
  ///
  /// In en, this message translates to:
  /// **'New end date: {date}'**
  String rcptAdminNewEnd(String date);

  /// No description provided for @rcptApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get rcptApprove;

  /// No description provided for @rcptReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rcptReject;

  /// No description provided for @rcptRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject receipt'**
  String get rcptRejectTitle;

  /// No description provided for @rcptRejectReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (the owner will see this)'**
  String get rcptRejectReasonLabel;

  /// No description provided for @rcptApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved: {days} added, until {date}.'**
  String rcptApproved(String days, String date);

  /// No description provided for @rcptRejectedDone.
  ///
  /// In en, this message translates to:
  /// **'Receipt rejected.'**
  String get rcptRejectedDone;

  /// No description provided for @rcptPricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription prices'**
  String get rcptPricingTitle;

  /// No description provided for @rcptPricingIntro.
  ///
  /// In en, this message translates to:
  /// **'Owners see these prices. A payment buys the longest period it covers.'**
  String get rcptPricingIntro;

  /// No description provided for @rcptPricingDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get rcptPricingDays;

  /// No description provided for @rcptPricingAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (ETB)'**
  String get rcptPricingAmount;

  /// No description provided for @rcptPricingAddTier.
  ///
  /// In en, this message translates to:
  /// **'Add a period'**
  String get rcptPricingAddTier;

  /// No description provided for @rcptPricingRemoveTier.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get rcptPricingRemoveTier;

  /// No description provided for @rcptPricingTelebirr.
  ///
  /// In en, this message translates to:
  /// **'telebirr receiver'**
  String get rcptPricingTelebirr;

  /// No description provided for @rcptPricingCbe.
  ///
  /// In en, this message translates to:
  /// **'CBE receiver'**
  String get rcptPricingCbe;

  /// No description provided for @rcptPricingName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get rcptPricingName;

  /// No description provided for @rcptPricingSave.
  ///
  /// In en, this message translates to:
  /// **'Save prices'**
  String get rcptPricingSave;

  /// No description provided for @rcptPricingSaved.
  ///
  /// In en, this message translates to:
  /// **'Prices saved.'**
  String get rcptPricingSaved;

  /// No description provided for @rcptStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt photos'**
  String get rcptStorageTitle;

  /// No description provided for @rcptStorageToggle.
  ///
  /// In en, this message translates to:
  /// **'Store receipt photos in Firebase Storage — needs Blaze'**
  String get rcptStorageToggle;

  /// No description provided for @rcptStorageHelp.
  ///
  /// In en, this message translates to:
  /// **'Off: photos are saved inside the receipt record (works on the free plan). On: they go to Firebase Storage; if an upload fails, the photo is saved inside the record instead.'**
  String get rcptStorageHelp;

  /// No description provided for @rcptPhotoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the receipt photo.'**
  String get rcptPhotoLoadFailed;

  /// No description provided for @rcptPhotoRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get rcptPhotoRetry;

  /// No description provided for @rcptNotifApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription payment approved'**
  String get rcptNotifApprovedTitle;

  /// No description provided for @rcptNotifApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day was} other{{days} days were}} added. Your subscription runs until {date}.'**
  String rcptNotifApprovedBody(int days, String date);

  /// No description provided for @rcptNotifRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription payment rejected'**
  String get rcptNotifRejectedTitle;

  /// No description provided for @rcptNotifRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Transaction {transactionId}: {reason}'**
  String rcptNotifRejectedBody(String transactionId, String reason);

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

  /// Owner reports computed in the app (no stats from the server).
  ///
  /// In en, this message translates to:
  /// **'Based on the last {days} days of bookings.'**
  String freePlanReportsFromBookings(int days);

  /// Status chip of a booking request the barber did not answer in time.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get freePlanRequestNoAnswer;

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

  /// No description provided for @barberLabel.
  ///
  /// In en, this message translates to:
  /// **'Barber: {name}'**
  String barberLabel(String name);

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

  /// No description provided for @timeOffSeveralDays.
  ///
  /// In en, this message translates to:
  /// **'Several days'**
  String get timeOffSeveralDays;

  /// No description provided for @vacationFromDate.
  ///
  /// In en, this message translates to:
  /// **'First day'**
  String get vacationFromDate;

  /// No description provided for @vacationToDate.
  ///
  /// In en, this message translates to:
  /// **'Last day'**
  String get vacationToDate;

  /// No description provided for @vacationFirstDayFrom.
  ///
  /// In en, this message translates to:
  /// **'First day starts at'**
  String get vacationFirstDayFrom;

  /// No description provided for @vacationLastDayUntil.
  ///
  /// In en, this message translates to:
  /// **'Last day ends at'**
  String get vacationLastDayUntil;

  /// No description provided for @vacationStartOfWork.
  ///
  /// In en, this message translates to:
  /// **'Start of work'**
  String get vacationStartOfWork;

  /// No description provided for @vacationEndOfWork.
  ///
  /// In en, this message translates to:
  /// **'End of work'**
  String get vacationEndOfWork;

  /// No description provided for @vacationMaxDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days selected (at most {max}).'**
  String vacationMaxDays(int days, int max);

  /// No description provided for @vacationLabel.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get vacationLabel;

  /// No description provided for @vacationRange.
  ///
  /// In en, this message translates to:
  /// **'{from} - {to}'**
  String vacationRange(String from, String to);

  /// No description provided for @vacationConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings during this time off'**
  String get vacationConflictsTitle;

  /// No description provided for @vacationConflictsBody.
  ///
  /// In en, this message translates to:
  /// **'{count} upcoming bookings fall inside this time off. Cancel them and notify each customer, or keep them (their times stay booked).'**
  String vacationConflictsBody(int count);

  /// No description provided for @vacationPaidRefund.
  ///
  /// In en, this message translates to:
  /// **'Paid: a refund will be flagged'**
  String get vacationPaidRefund;

  /// No description provided for @vacationCancelAndNotify.
  ///
  /// In en, this message translates to:
  /// **'Cancel & notify customers'**
  String get vacationCancelAndNotify;

  /// No description provided for @vacationKeepBookings.
  ///
  /// In en, this message translates to:
  /// **'Keep bookings'**
  String get vacationKeepBookings;

  /// No description provided for @vacationSaved.
  ///
  /// In en, this message translates to:
  /// **'Vacation saved. Customers can no longer book these days.'**
  String get vacationSaved;

  /// No description provided for @vacationSavedCancelled.
  ///
  /// In en, this message translates to:
  /// **'Vacation saved. {count} bookings cancelled and their customers notified.'**
  String vacationSavedCancelled(int count);

  /// No description provided for @vacationRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the whole vacation {range}? Customers can book these days again.'**
  String vacationRemoveConfirm(String range);

  /// No description provided for @vacationErrTooLong.
  ///
  /// In en, this message translates to:
  /// **'A vacation can be at most {max} days long.'**
  String vacationErrTooLong(int max);

  /// No description provided for @vacationErrNothingToBlock.
  ///
  /// In en, this message translates to:
  /// **'There are no working hours left to block on these days.'**
  String get vacationErrNothingToBlock;

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

  /// No description provided for @earlyFinishBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Your barber is free now — come in early'**
  String get earlyFinishBannerTitle;

  /// No description provided for @earlyFinishBannerBody.
  ///
  /// In en, this message translates to:
  /// **'{barber} finished early. You can come in before your {time} appointment.'**
  String earlyFinishBannerBody(String barber, String time);

  /// No description provided for @earlyFinishCallShop.
  ///
  /// In en, this message translates to:
  /// **'Call shop'**
  String get earlyFinishCallShop;

  /// No description provided for @earlyFinishDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get earlyFinishDirections;

  /// No description provided for @earlyFinishNotified.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 customer was told they can come early} other{{count} customers were told they can come early}}'**
  String earlyFinishNotified(int count);

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

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

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

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get authErrNetwork;

  /// No description provided for @authErrNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not enabled for this app yet.'**
  String get authErrNotEnabled;

  /// No description provided for @authErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrGeneric;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in or create an account'**
  String get authSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @googleSignInNotice.
  ///
  /// In en, this message translates to:
  /// **'We only use your name and email address to manage your bookings.'**
  String get googleSignInNotice;

  /// No description provided for @demoContinueAs.
  ///
  /// In en, this message translates to:
  /// **'Continue as {name}'**
  String demoContinueAs(String name);

  /// No description provided for @demoGoogleNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: no real Google account is used.'**
  String get demoGoogleNotice;

  /// No description provided for @useDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get useDifferentAccount;

  /// No description provided for @profilePhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'For SMS booking reminders and payments.'**
  String get profilePhoneHelper;

  /// No description provided for @authErrPopupBlocked.
  ///
  /// In en, this message translates to:
  /// **'The sign-in window was blocked. Allow pop-ups for this site and try again.'**
  String get authErrPopupBlocked;

  /// No description provided for @authErrAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already uses a different sign-in method.'**
  String get authErrAccountExists;

  /// No description provided for @authErrUnauthorizedDomain.
  ///
  /// In en, this message translates to:
  /// **'This web address is not authorised for sign-in.'**
  String get authErrUnauthorizedDomain;

  /// No description provided for @authErrUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Please contact support.'**
  String get authErrUserDisabled;

  /// No description provided for @authErrWithCode.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed ({code}).'**
  String authErrWithCode(String code);

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errInvalidEmail;

  /// No description provided for @errInvalidOwnerEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Gmail / email address for the owner.'**
  String get errInvalidOwnerEmail;

  /// No description provided for @errEmailAlreadyStaff.
  ///
  /// In en, this message translates to:
  /// **'This email address already belongs to a {role} account.'**
  String errEmailAlreadyStaff(String role);

  /// No description provided for @errGoogleEmailMissing.
  ///
  /// In en, this message translates to:
  /// **'Your Google account has no verified email address.'**
  String get errGoogleEmailMissing;

  /// No description provided for @ownerEmailLogin.
  ///
  /// In en, this message translates to:
  /// **'Owner Gmail Address (Login) *'**
  String get ownerEmailLogin;

  /// No description provided for @ownerEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'The owner signs in with this email (Google or email and password) to manage the shop.'**
  String get ownerEmailHelper;

  /// No description provided for @emailForLogin.
  ///
  /// In en, this message translates to:
  /// **'Email address (for login)'**
  String get emailForLogin;

  /// No description provided for @barberEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional. The barber signs in with this email (Google or email and password).'**
  String get barberEmailHelper;

  /// No description provided for @barberMobileOptional.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number (optional)'**
  String get barberMobileOptional;

  /// No description provided for @barberPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Private. Customers see it only after their booking is confirmed.'**
  String get barberPhoneHelper;

  /// No description provided for @barberPhoneNone.
  ///
  /// In en, this message translates to:
  /// **'No mobile number'**
  String get barberPhoneNone;

  /// No description provided for @barberPhoneEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit mobile number'**
  String get barberPhoneEdit;

  /// No description provided for @barberPhoneSaved.
  ///
  /// In en, this message translates to:
  /// **'Mobile number saved'**
  String get barberPhoneSaved;

  /// No description provided for @callBarberAction.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String callBarberAction(String name);

  /// No description provided for @barberPhoneOnBooking.
  ///
  /// In en, this message translates to:
  /// **'Barber\'s phone: {phone}'**
  String barberPhoneOnBooking(String phone);

  /// No description provided for @invalidEmailShort.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmailShort;

  /// No description provided for @adminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform System Administration'**
  String get adminSubtitle;

  /// No description provided for @adminShopsHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Barbershops on the platform'**
  String get adminShopsHeroTitle;

  /// No description provided for @adminShopsMetricBookable.
  ///
  /// In en, this message translates to:
  /// **'Bookable'**
  String get adminShopsMetricBookable;

  /// No description provided for @adminShopsMetricSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get adminShopsMetricSuspended;

  /// No description provided for @adminShopsFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminShopsFilterActive;

  /// No description provided for @adminShopsFilterSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get adminShopsFilterSuspended;

  /// No description provided for @adminShopsFilterUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get adminShopsFilterUnverified;

  /// No description provided for @adminShopsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminShopsEdit;

  /// No description provided for @adminShopsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit barbershop'**
  String get adminShopsEditTitle;

  /// No description provided for @adminShopsSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Shop profile'**
  String get adminShopsSectionProfile;

  /// No description provided for @adminShopsSectionPlatform.
  ///
  /// In en, this message translates to:
  /// **'Verification & subscription'**
  String get adminShopsSectionPlatform;

  /// No description provided for @adminShopsSectionOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get adminShopsSectionOwner;

  /// No description provided for @adminShopsSectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get adminShopsSectionStatus;

  /// No description provided for @adminShopsFieldName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get adminShopsFieldName;

  /// No description provided for @adminShopsFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get adminShopsFieldAddress;

  /// No description provided for @adminShopsFieldSubCity.
  ///
  /// In en, this message translates to:
  /// **'Sub-city'**
  String get adminShopsFieldSubCity;

  /// No description provided for @adminShopsFieldLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get adminShopsFieldLandmark;

  /// No description provided for @adminShopsFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Shop phone'**
  String get adminShopsFieldPhone;

  /// No description provided for @adminShopsFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminShopsFieldDescription;

  /// No description provided for @adminShopsHoursReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Opening hours: {days} {hours} · set by the shop owner'**
  String adminShopsHoursReadOnly(String days, String hours);

  /// No description provided for @adminShopsFieldVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified partner'**
  String get adminShopsFieldVerified;

  /// No description provided for @adminShopsFieldVerifiedHint.
  ///
  /// In en, this message translates to:
  /// **'Shows the verified badge to customers'**
  String get adminShopsFieldVerifiedHint;

  /// No description provided for @adminShopsFieldPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get adminShopsFieldPlan;

  /// No description provided for @adminShopsFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Subscription status'**
  String get adminShopsFieldStatus;

  /// No description provided for @adminShopsFieldEndsAt.
  ///
  /// In en, this message translates to:
  /// **'Subscription ends'**
  String get adminShopsFieldEndsAt;

  /// No description provided for @adminShopsNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get adminShopsNoEndDate;

  /// No description provided for @adminShopsClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get adminShopsClearDate;

  /// No description provided for @adminShopsOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'Admin override: changes here are saved directly to the shop.'**
  String get adminShopsOverrideHint;

  /// No description provided for @adminShopsSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get adminShopsSave;

  /// No description provided for @adminShopsSaved.
  ///
  /// In en, this message translates to:
  /// **'Shop saved'**
  String get adminShopsSaved;

  /// No description provided for @adminShopsOwnerSignedUp.
  ///
  /// In en, this message translates to:
  /// **'Signed up · {email}'**
  String adminShopsOwnerSignedUp(String email);

  /// No description provided for @adminShopsOwnerInvitePending.
  ///
  /// In en, this message translates to:
  /// **'Invite pending: {email} gets owner access when they sign in'**
  String adminShopsOwnerInvitePending(String email);

  /// No description provided for @adminShopsOwnerNone.
  ///
  /// In en, this message translates to:
  /// **'No owner assigned'**
  String get adminShopsOwnerNone;

  /// No description provided for @adminShopsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminShopsStatusActive;

  /// No description provided for @adminShopsStatusAdminSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended by admin'**
  String get adminShopsStatusAdminSuspended;

  /// No description provided for @adminShopsStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Subscription suspended'**
  String get adminShopsStatusUnpaid;

  /// No description provided for @adminShopsSuspendedSince.
  ///
  /// In en, this message translates to:
  /// **'Suspended on {date}: {reason}'**
  String adminShopsSuspendedSince(String date, String reason);

  /// No description provided for @adminShopsSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend shop'**
  String get adminShopsSuspend;

  /// No description provided for @adminShopsReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate shop'**
  String get adminShopsReactivate;

  /// No description provided for @adminShopsSuspendTitle.
  ///
  /// In en, this message translates to:
  /// **'Suspend {shop}?'**
  String adminShopsSuspendTitle(String shop);

  /// No description provided for @adminShopsSuspendBody.
  ///
  /// In en, this message translates to:
  /// **'Customers will not see this shop or be able to book it. Existing bookings stay. The owner sees your reason.'**
  String get adminShopsSuspendBody;

  /// No description provided for @adminShopsReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (shown to the owner)'**
  String get adminShopsReasonLabel;

  /// No description provided for @adminShopsSuspendedToast.
  ///
  /// In en, this message translates to:
  /// **'{shop} suspended'**
  String adminShopsSuspendedToast(String shop);

  /// No description provided for @adminShopsReactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate {shop}?'**
  String adminShopsReactivateTitle(String shop);

  /// No description provided for @adminShopsReactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Customers will be able to find and book this shop again.'**
  String get adminShopsReactivateBody;

  /// No description provided for @adminShopsReactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'{shop} reactivated'**
  String adminShopsReactivatedToast(String shop);

  /// No description provided for @adminShopsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {shop}. Type the shop name to confirm.'**
  String adminShopsDeleteBody(String shop);

  /// No description provided for @adminShopsDeleteTypeName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get adminShopsDeleteTypeName;

  /// No description provided for @adminShopsDeleteWillHeading.
  ///
  /// In en, this message translates to:
  /// **'What happens'**
  String get adminShopsDeleteWillHeading;

  /// No description provided for @adminShopsDeleteListBarbers.
  ///
  /// In en, this message translates to:
  /// **'{count} barber profiles are deleted, with their time off and booked slots'**
  String adminShopsDeleteListBarbers(int count);

  /// No description provided for @adminShopsDeleteListServices.
  ///
  /// In en, this message translates to:
  /// **'{count} services are deleted'**
  String adminShopsDeleteListServices(int count);

  /// No description provided for @adminShopsDeleteListStaff.
  ///
  /// In en, this message translates to:
  /// **'{count} staff accounts (owner and barbers) become customer accounts'**
  String adminShopsDeleteListStaff(int count);

  /// No description provided for @adminShopsDeleteListInvites.
  ///
  /// In en, this message translates to:
  /// **'{count} pending invites are revoked'**
  String adminShopsDeleteListInvites(int count);

  /// No description provided for @adminShopsDeleteListBookings.
  ///
  /// In en, this message translates to:
  /// **'{count} upcoming bookings are cancelled and their customers notified'**
  String adminShopsDeleteListBookings(int count);

  /// No description provided for @adminShopsDeleteListBookingsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bookings are cancelled and their customers notified'**
  String get adminShopsDeleteListBookingsUnknown;

  /// No description provided for @adminShopsDeleteListOther.
  ///
  /// In en, this message translates to:
  /// **'The walk-in queue, reviews, payouts and statistics are deleted'**
  String get adminShopsDeleteListOther;

  /// No description provided for @adminShopsDeleteListKept.
  ///
  /// In en, this message translates to:
  /// **'Past bookings are kept for history. Staff can still sign in, as customers.'**
  String get adminShopsDeleteListKept;

  /// No description provided for @adminShopsDeleteStepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Suspending the shop'**
  String get adminShopsDeleteStepPrepare;

  /// No description provided for @adminShopsDeleteStepBookings.
  ///
  /// In en, this message translates to:
  /// **'Cancelling upcoming bookings'**
  String get adminShopsDeleteStepBookings;

  /// No description provided for @adminShopsDeleteStepStaff.
  ///
  /// In en, this message translates to:
  /// **'Moving staff to customer accounts'**
  String get adminShopsDeleteStepStaff;

  /// No description provided for @adminShopsDeleteStepData.
  ///
  /// In en, this message translates to:
  /// **'Deleting barbers, services and shop data'**
  String get adminShopsDeleteStepData;

  /// No description provided for @adminShopsDeleteStepShop.
  ///
  /// In en, this message translates to:
  /// **'Deleting the shop'**
  String get adminShopsDeleteStepShop;

  /// No description provided for @adminShopsDeleteProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}: {label}…'**
  String adminShopsDeleteProgress(int step, int total, String label);

  /// No description provided for @adminShopsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish \"{step}\". What was done stays done; tap Retry to continue.'**
  String adminShopsDeleteFailed(String step);

  /// No description provided for @adminShopsDeleteRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminShopsDeleteRetry;

  /// No description provided for @shopRemovedNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your barbershop was removed'**
  String get shopRemovedNoticeTitle;

  /// No description provided for @shopRemovedNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'You can keep using Crown & Blade as a customer.'**
  String get shopRemovedNoticeBody;

  /// No description provided for @adminShopsErrReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason.'**
  String get adminShopsErrReasonRequired;

  /// No description provided for @adminShopsErrReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the reason under {max} characters.'**
  String adminShopsErrReasonTooLong(int max);

  /// No description provided for @adminShopsErrNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the shop name.'**
  String get adminShopsErrNameRequired;

  /// No description provided for @adminShopsErrNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'The shop name is too long.'**
  String get adminShopsErrNameTooLong;

  /// No description provided for @adminShopsErrAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the address.'**
  String get adminShopsErrAddressRequired;

  /// No description provided for @adminShopsErrTextTooLong.
  ///
  /// In en, this message translates to:
  /// **'Some of the text is too long.'**
  String get adminShopsErrTextTooLong;

  /// No description provided for @adminShopsErrPlan.
  ///
  /// In en, this message translates to:
  /// **'Unknown plan.'**
  String get adminShopsErrPlan;

  /// No description provided for @adminShopsErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This shop no longer exists.'**
  String get adminShopsErrNotFound;

  /// No description provided for @adminShopsErrNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'Only the platform admin can do this.'**
  String get adminShopsErrNotAdmin;

  /// No description provided for @adminShopsErrNameMismatch.
  ///
  /// In en, this message translates to:
  /// **'The name does not match.'**
  String get adminShopsErrNameMismatch;

  /// No description provided for @adminShopsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Temporarily unavailable'**
  String get adminShopsUnavailableTitle;

  /// No description provided for @adminShopsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This barbershop is not taking bookings right now. Your existing appointments are not affected.'**
  String get adminShopsUnavailableBody;

  /// No description provided for @adminShopsOwnerBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Your shop is suspended by the platform'**
  String get adminShopsOwnerBannerTitle;

  /// No description provided for @adminShopsOwnerBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Customers cannot find or book your shop until it is reactivated. Existing bookings stay.'**
  String get adminShopsOwnerBannerBody;

  /// No description provided for @adminShopsOwnerBannerReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String adminShopsOwnerBannerReason(String reason);

  /// No description provided for @adminShopsOwnerBannerContact.
  ///
  /// In en, this message translates to:
  /// **'Contact the platform admin to reactivate it.'**
  String get adminShopsOwnerBannerContact;

  /// No description provided for @deleteShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Barbershop?'**
  String get deleteShopTitle;

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

  /// No description provided for @registeredBarbershopsCount.
  ///
  /// In en, this message translates to:
  /// **'Registered Barbershops ({count})'**
  String registeredBarbershopsCount(int count);

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
  /// **'{name} ({email}) - invite pending'**
  String ownerInvitePending(String name, String email);

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

  /// No description provided for @registerNewBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Register New Barbershop'**
  String get registerNewBarbershop;

  /// No description provided for @registeredShopSnack.
  ///
  /// In en, this message translates to:
  /// **'Registered \"{shop}\". The owner can now sign in as {email}.'**
  String registeredShopSnack(String shop, String email);

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

  /// No description provided for @adminRegisterHoursOwnerNote.
  ///
  /// In en, this message translates to:
  /// **'The shop owner sets the opening hours after signing in.'**
  String get adminRegisterHoursOwnerNote;

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

  /// No description provided for @allSubCities.
  ///
  /// In en, this message translates to:
  /// **'All sub-cities'**
  String get allSubCities;

  /// No description provided for @subCityFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter barbershops by sub-city'**
  String get subCityFilterTooltip;

  /// No description provided for @subCityOptionCount.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count})'**
  String subCityOptionCount(String name, int count);

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

  /// No description provided for @reportsBusyHoursTab.
  ///
  /// In en, this message translates to:
  /// **'Busy hours'**
  String get reportsBusyHoursTab;

  /// No description provided for @reportsNoShowsTab.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get reportsNoShowsTab;

  /// No description provided for @busyRangeLast30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get busyRangeLast30;

  /// No description provided for @busyRangeLast90.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get busyRangeLast90;

  /// No description provided for @busyRangeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get busyRangeMonth;

  /// No description provided for @busyHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings by day and hour'**
  String get busyHoursTitle;

  /// No description provided for @busyHoursNote.
  ///
  /// In en, this message translates to:
  /// **'Addis Ababa time. Each booking counts in the hour it starts. Cancelled bookings are left out.'**
  String get busyHoursNote;

  /// No description provided for @busyBusiestDay.
  ///
  /// In en, this message translates to:
  /// **'Busiest day'**
  String get busyBusiestDay;

  /// No description provided for @busyBusiestTime.
  ///
  /// In en, this message translates to:
  /// **'Busiest time'**
  String get busyBusiestTime;

  /// No description provided for @busyQuietestHour.
  ///
  /// In en, this message translates to:
  /// **'Quietest hour'**
  String get busyQuietestHour;

  /// No description provided for @busyTotalBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get busyTotalBookings;

  /// No description provided for @busyNoBookings.
  ///
  /// In en, this message translates to:
  /// **'No bookings in this period.'**
  String get busyNoBookings;

  /// No description provided for @busyLegendFewer.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get busyLegendFewer;

  /// No description provided for @busyLegendMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get busyLegendMore;

  /// No description provided for @busyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this month\'s bookings.'**
  String get busyLoadFailed;

  /// No description provided for @busyCellSemantics.
  ///
  /// In en, this message translates to:
  /// **'{day} {hour}: {count} bookings'**
  String busyCellSemantics(String day, String hour, int count);

  /// No description provided for @noShowsAutoBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-block repeat no-shows'**
  String get noShowsAutoBlockTitle;

  /// No description provided for @noShowsAutoBlockOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A customer is blocked after 1 no-show at your shop.} other{A customer is blocked after {count} no-shows at your shop.}}'**
  String noShowsAutoBlockOn(int count);

  /// No description provided for @noShowsAutoBlockOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Turn it on to block a customer automatically after repeated no-shows.'**
  String get noShowsAutoBlockOff;

  /// No description provided for @noShowsAutoBlockLimit.
  ///
  /// In en, this message translates to:
  /// **'No-shows before blocking'**
  String get noShowsAutoBlockLimit;

  /// No description provided for @noShowsDecrease.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get noShowsDecrease;

  /// No description provided for @noShowsIncrease.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get noShowsIncrease;

  /// No description provided for @noShowsSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The auto-block setting could not be loaded.'**
  String get noShowsSettingsUnavailable;

  /// No description provided for @noShowsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customers by name'**
  String get noShowsSearchHint;

  /// No description provided for @noShowsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get noShowsFilterAll;

  /// No description provided for @noShowsFilterBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked ({count})'**
  String noShowsFilterBlocked(int count);

  /// No description provided for @noShowsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers by no-show rate'**
  String get noShowsListTitle;

  /// No description provided for @noShowsRateHelp.
  ///
  /// In en, this message translates to:
  /// **'No-show rate: missed appointments out of completed and missed ones.'**
  String get noShowsRateHelp;

  /// No description provided for @noShowsNoCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customers yet.'**
  String get noShowsNoCustomers;

  /// No description provided for @noShowsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No customers match your search.'**
  String get noShowsNoMatch;

  /// No description provided for @noShowsWindowNote.
  ///
  /// In en, this message translates to:
  /// **'Counts cover the last {days} days of bookings.'**
  String noShowsWindowNote(int days);

  /// No description provided for @noShowsCustomerStats.
  ///
  /// In en, this message translates to:
  /// **'Bookings {bookings} · Completed {completed} · Cancelled {cancelled} · No-shows {noShows}'**
  String noShowsCustomerStats(
      int bookings, int completed, int cancelled, int noShows);

  /// No description provided for @noShowsRateSemantics.
  ///
  /// In en, this message translates to:
  /// **'No-show rate {percent}%'**
  String noShowsRateSemantics(int percent);

  /// No description provided for @customerBlockedChip.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get customerBlockedChip;

  /// No description provided for @customerAutoBlockedChip.
  ///
  /// In en, this message translates to:
  /// **'Auto-blocked'**
  String get customerAutoBlockedChip;

  /// No description provided for @customerBlockAction.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get customerBlockAction;

  /// No description provided for @customerUnblockAction.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get customerUnblockAction;

  /// No description provided for @customerBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String customerBlockTitle(String name);

  /// No description provided for @customerBlockBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to book or join the queue at your shop. They will see: \"This shop can\'t take your booking right now. Please contact the shop.\"'**
  String get customerBlockBody;

  /// No description provided for @customerBlockReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get customerBlockReasonLabel;

  /// No description provided for @customerBlockReasonHelper.
  ///
  /// In en, this message translates to:
  /// **'For your records. The app doesn\'t show it to the customer.'**
  String get customerBlockReasonHelper;

  /// No description provided for @customerBlockCancelUpcoming.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Also cancel their upcoming booking} other{Also cancel their {count} upcoming bookings}}'**
  String customerBlockCancelUpcoming(int count);

  /// No description provided for @customerBlockCancelPaidNote.
  ///
  /// In en, this message translates to:
  /// **'Paid bookings are marked for a refund.'**
  String get customerBlockCancelPaidNote;

  /// No description provided for @customerBlockKeepNote.
  ///
  /// In en, this message translates to:
  /// **'Their upcoming bookings stay unless you cancel them here.'**
  String get customerBlockKeepNote;

  /// No description provided for @customerBlockedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked.'**
  String customerBlockedSnack(String name);

  /// No description provided for @customerBlockedCancelledSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name} is blocked. 1 booking cancelled.} other{{name} is blocked. {count} bookings cancelled.}}'**
  String customerBlockedCancelledSnack(int count, String name);

  /// No description provided for @customerUnblockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}?'**
  String customerUnblockTitle(String name);

  /// No description provided for @customerUnblockBody.
  ///
  /// In en, this message translates to:
  /// **'They can book and join the queue at your shop again.'**
  String get customerUnblockBody;

  /// No description provided for @customerUnblockedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} is unblocked.'**
  String customerUnblockedSnack(String name);

  /// No description provided for @customerBlockedOn.
  ///
  /// In en, this message translates to:
  /// **'Blocked on {date}'**
  String customerBlockedOn(String date);

  /// No description provided for @customerBlockNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {reason}'**
  String customerBlockNote(String reason);

  /// No description provided for @customerAutoBlockedAfter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Blocked automatically after 1 no-show} other{Blocked automatically after {count} no-shows}}'**
  String customerAutoBlockedAfter(int count);

  /// No description provided for @customerUnknownName.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerUnknownName;

  /// No description provided for @errCustomerBlockedAtShop.
  ///
  /// In en, this message translates to:
  /// **'This shop can\'t take your booking right now. Please contact the shop.'**
  String get errCustomerBlockedAtShop;

  /// No description provided for @errCustomerBlockNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only the shop owner can block or unblock customers.'**
  String get errCustomerBlockNotAllowed;

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

  /// No description provided for @yourBarbersTitle.
  ///
  /// In en, this message translates to:
  /// **'Your barbers'**
  String get yourBarbersTitle;

  /// No description provided for @yourBarbersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites and recent visits'**
  String get yourBarbersSubtitle;

  /// No description provided for @bookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book again'**
  String get bookAgain;

  /// No description provided for @bookAgainWith.
  ///
  /// In en, this message translates to:
  /// **'Book again with {name}'**
  String bookAgainWith(String name);

  /// No description provided for @rebookLastService.
  ///
  /// In en, this message translates to:
  /// **'Last time: {service}'**
  String rebookLastService(String service);

  /// No description provided for @rebookFavoriteTag.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get rebookFavoriteTag;

  /// No description provided for @favoriteBarberAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {name} to favorites'**
  String favoriteBarberAdd(String name);

  /// No description provided for @favoriteBarberRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from favorites'**
  String favoriteBarberRemove(String name);

  /// No description provided for @rebookSuggestedSlot.
  ///
  /// In en, this message translates to:
  /// **'Next free time with {name}: {when}. Tap another time to change it.'**
  String rebookSuggestedSlot(String name, String when);

  /// No description provided for @rebookNoFreeTime.
  ///
  /// In en, this message translates to:
  /// **'{name} has no free time in the next {days} days. Try another barber at this shop.'**
  String rebookNoFreeTime(String name, int days);

  /// No description provided for @rebookFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t book again right now'**
  String get rebookFallbackTitle;

  /// No description provided for @rebookShopGone.
  ///
  /// In en, this message translates to:
  /// **'{shop} is no longer listed in the app. Find another barber in Find Barbers.'**
  String rebookShopGone(String shop);

  /// No description provided for @rebookShopBlocked.
  ///
  /// In en, this message translates to:
  /// **'{shop} isn\'t taking bookings right now. Please try again later.'**
  String rebookShopBlocked(String shop);

  /// No description provided for @rebookBarberGone.
  ///
  /// In en, this message translates to:
  /// **'{barber} no longer works at {shop}. Another barber there can look after you.'**
  String rebookBarberGone(String barber, String shop);

  /// No description provided for @rebookBarberUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{barber} isn\'t taking bookings right now. Another barber at {shop} can look after you.'**
  String rebookBarberUnavailable(String barber, String shop);

  /// No description provided for @rebookServiceGone.
  ///
  /// In en, this message translates to:
  /// **'{shop} no longer offers {service}. Pick another service with {barber}.'**
  String rebookServiceGone(String shop, String service, String barber);

  /// No description provided for @rebookNoServices.
  ///
  /// In en, this message translates to:
  /// **'{shop} has no services listed right now. Please try again later.'**
  String rebookNoServices(String shop);

  /// No description provided for @rebookSeeShop.
  ///
  /// In en, this message translates to:
  /// **'See the shop'**
  String get rebookSeeShop;

  /// No description provided for @rebookPickService.
  ///
  /// In en, this message translates to:
  /// **'Pick a service'**
  String get rebookPickService;

  /// No description provided for @rebookRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get rebookRemoveFavorite;

  /// No description provided for @rebookSignInNeeded.
  ///
  /// In en, this message translates to:
  /// **'Sign in as a customer to book again.'**
  String get rebookSignInNeeded;

  /// No description provided for @rebookClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get rebookClose;

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
  /// **'Login invite pending: {email}'**
  String loginInvitePending(String email);

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

  /// No description provided for @subExpTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'Your trial ended — pay to keep taking bookings. Your shop will be suspended soon unless you pay.'**
  String get subExpTrialEnded;

  /// No description provided for @subExpTrialEndedToday.
  ///
  /// In en, this message translates to:
  /// **'Your trial ended — pay to keep taking bookings. Your shop will be suspended today unless you pay.'**
  String get subExpTrialEndedToday;

  /// No description provided for @subExpTrialEndedInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your trial ended — pay to keep taking bookings. 1 day left before your shop is suspended.} other{Your trial ended — pay to keep taking bookings. {count} days left before your shop is suspended.}}'**
  String subExpTrialEndedInDays(int count);

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

  /// No description provided for @errInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name (up to 100 characters).'**
  String get errInvalidName;

  /// No description provided for @errSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first.'**
  String get errSignInRequired;

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
  /// **'Rate your barber'**
  String get reviewsRateAction;

  /// No description provided for @reviewsYourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get reviewsYourRating;

  /// No description provided for @reviewsRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your barber'**
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
  /// **'Tell us about your experience'**
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

  /// No description provided for @reviewsEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit review'**
  String get reviewsEditAction;

  /// No description provided for @reviewsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete review'**
  String get reviewsDeleteAction;

  /// No description provided for @reviewsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your review'**
  String get reviewsEditTitle;

  /// No description provided for @reviewsSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get reviewsSaveEdit;

  /// No description provided for @reviewsEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Your review was updated.'**
  String get reviewsEditSaved;

  /// No description provided for @reviewsEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get reviewsEdited;

  /// No description provided for @reviewsManageHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit or delete your review'**
  String get reviewsManageHint;

  /// No description provided for @reviewsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your review?'**
  String get reviewsDeleteConfirmTitle;

  /// No description provided for @reviewsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your stars and comment will be removed from {barber}\'s rating. You can rate this visit again later.'**
  String reviewsDeleteConfirmBody(String barber);

  /// No description provided for @reviewsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your review was deleted.'**
  String get reviewsDeleted;

  /// No description provided for @authTabLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authTabLogin;

  /// No description provided for @authTabRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authTabRegister;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}'**
  String codeSentTo(String email);

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String resendCodeIn(int seconds);

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'We sent a new code.'**
  String get codeResent;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with a letter and a number'**
  String get passwordHelper;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get passwordsDontMatch;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get enterPassword;

  /// No description provided for @codeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code.'**
  String get codeRequired;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetTitle;

  /// No description provided for @resetIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send you a 6-digit code.'**
  String get resetIntro;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. Log in with your new password.'**
  String get resetDone;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get backToLogin;

  /// No description provided for @demoEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Demo: the code is always 123456. Demo accounts log in with the password demo1234.'**
  String get demoEmailHint;

  /// No description provided for @emailErrWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use 8 to 128 characters with at least one letter and one number.'**
  String get emailErrWeakPassword;

  /// No description provided for @emailErrInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not correct. Check the email and try again.'**
  String get emailErrInvalidCode;

  /// No description provided for @emailErrCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Request a new code.'**
  String get emailErrCodeExpired;

  /// No description provided for @emailErrAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Log in instead.'**
  String get emailErrAlreadyRegistered;

  /// No description provided for @emailErrTooSoon.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before requesting another code.'**
  String get emailErrTooSoon;

  /// No description provided for @emailErrTooSoonSeconds.
  ///
  /// In en, this message translates to:
  /// **'Please wait {seconds} s before requesting another code.'**
  String emailErrTooSoonSeconds(int seconds);

  /// No description provided for @emailErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get emailErrRateLimited;

  /// No description provided for @emailErrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'We can\'t send emails right now. Try Google sign-in instead.'**
  String get emailErrNotConfigured;

  /// No description provided for @emailErrWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get emailErrWrongCredentials;

  /// No description provided for @emailErrNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is not enabled yet.'**
  String get emailErrNotEnabled;

  /// No description provided for @emailErrServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This service isn\'t available yet. Try Google sign-in instead.'**
  String get emailErrServiceUnavailable;

  /// No description provided for @errEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first. Open the link we emailed you, then log in.'**
  String get errEmailNotVerified;

  /// No description provided for @emailErrSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the email. Please try again.'**
  String get emailErrSendFailed;

  /// No description provided for @emailErrInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Check the details you entered and try again.'**
  String get emailErrInvalidInput;

  /// No description provided for @emailErrInvalidCodeAttempts.
  ///
  /// In en, this message translates to:
  /// **'That code is not correct. Attempts left: {count}.'**
  String emailErrInvalidCodeAttempts(int count);

  /// No description provided for @registerEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get registerEmailTitle;

  /// No description provided for @registerEmailIntro.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a 6-digit code to confirm it\'s yours.'**
  String get registerEmailIntro;

  /// No description provided for @enterCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get enterCodeTitle;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @createPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your password'**
  String get createPasswordTitle;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get newPasswordTitle;

  /// No description provided for @savePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savePasswordButton;

  /// No description provided for @emailVerifiedNotice.
  ///
  /// In en, this message translates to:
  /// **'{email} is verified.'**
  String emailVerifiedNotice(String email);

  /// No description provided for @authStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String authStepOf(int step, int total);

  /// No description provided for @emailErrVerificationExpired.
  ///
  /// In en, this message translates to:
  /// **'This step took too long. Please request a new code.'**
  String get emailErrVerificationExpired;

  /// No description provided for @logInInstead.
  ///
  /// In en, this message translates to:
  /// **'Log in instead'**
  String get logInInstead;

  /// No description provided for @acceptRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'New requests'**
  String get acceptRequestsTitle;

  /// No description provided for @acceptRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String acceptRequestsCount(int count);

  /// No description provided for @acceptRequestsHelp.
  ///
  /// In en, this message translates to:
  /// **'Accept or decline each booking. Requests not answered 1 hour before the start are cancelled automatically.'**
  String get acceptRequestsHelp;

  /// No description provided for @acceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptAction;

  /// No description provided for @acceptDeclineAction.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get acceptDeclineAction;

  /// No description provided for @acceptDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this booking?'**
  String get acceptDeclineTitle;

  /// No description provided for @acceptDeclineBody.
  ///
  /// In en, this message translates to:
  /// **'{customer} will be told you can\'t take it and asked to pick another time.'**
  String acceptDeclineBody(String customer);

  /// No description provided for @acceptDeclineReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get acceptDeclineReasonLabel;

  /// No description provided for @acceptDeclineConfirm.
  ///
  /// In en, this message translates to:
  /// **'Decline booking'**
  String get acceptDeclineConfirm;

  /// No description provided for @acceptDeclineCancel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get acceptDeclineCancel;

  /// No description provided for @acceptAccepted.
  ///
  /// In en, this message translates to:
  /// **'Booking accepted. {customer} has been told.'**
  String acceptAccepted(String customer);

  /// No description provided for @acceptDeclined.
  ///
  /// In en, this message translates to:
  /// **'Booking declined.'**
  String get acceptDeclined;

  /// No description provided for @acceptFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t answer the request: {error}'**
  String acceptFailed(String error);

  /// No description provided for @acceptWaitingForBarber.
  ///
  /// In en, this message translates to:
  /// **'Waiting for barber'**
  String get acceptWaitingForBarber;

  /// No description provided for @acceptWaitingFor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {barber} to accept'**
  String acceptWaitingFor(String barber);

  /// No description provided for @acceptRequestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request sent!'**
  String get acceptRequestSentTitle;

  /// No description provided for @acceptRequestSentBody.
  ///
  /// In en, this message translates to:
  /// **'{barber} will confirm your booking soon. We\'ll let you know when they accept.'**
  String acceptRequestSentBody(String barber);

  /// No description provided for @acceptPayAfterAcceptance.
  ///
  /// In en, this message translates to:
  /// **'You can pay online once the barber accepts.'**
  String get acceptPayAfterAcceptance;

  /// No description provided for @acceptDeclinedNote.
  ///
  /// In en, this message translates to:
  /// **'The barber couldn\'t take this booking. Please pick another time.'**
  String get acceptDeclinedNote;

  /// No description provided for @acceptExpiredNote.
  ///
  /// In en, this message translates to:
  /// **'The barber didn\'t answer in time. Please pick another time.'**
  String get acceptExpiredNote;

  /// No description provided for @acceptDeclineReasonNote.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String acceptDeclineReasonNote(String reason);

  /// No description provided for @acceptPolicyToggle.
  ///
  /// In en, this message translates to:
  /// **'Barbers accept each booking'**
  String get acceptPolicyToggle;

  /// No description provided for @acceptPolicyToggleHelp.
  ///
  /// In en, this message translates to:
  /// **'New bookings wait until the barber accepts them. Requests not answered 1 hour before the start are cancelled automatically.'**
  String get acceptPolicyToggleHelp;

  /// No description provided for @acceptErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only the booked barber or the shop owner can answer this request.'**
  String get acceptErrNotAllowed;

  /// No description provided for @acceptErrReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'The reason can be at most {max} characters.'**
  String acceptErrReasonTooLong(int max);

  /// No description provided for @payoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Barber payouts'**
  String get payoutsTitle;

  /// No description provided for @payoutsOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Payouts & commission'**
  String get payoutsOpenButton;

  /// No description provided for @payoutsMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get payoutsMonthLabel;

  /// No description provided for @payoutsCompletedJobs.
  ///
  /// In en, this message translates to:
  /// **'Completed jobs'**
  String get payoutsCompletedJobs;

  /// No description provided for @payoutsGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get payoutsGross;

  /// No description provided for @payoutsCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get payoutsCommission;

  /// No description provided for @payoutsCommissionLine.
  ///
  /// In en, this message translates to:
  /// **'Commission: {percent}%'**
  String payoutsCommissionLine(int percent);

  /// No description provided for @payoutsBarberShare.
  ///
  /// In en, this message translates to:
  /// **'Barber share'**
  String get payoutsBarberShare;

  /// No description provided for @payoutsAlreadyPaid.
  ///
  /// In en, this message translates to:
  /// **'Already paid'**
  String get payoutsAlreadyPaid;

  /// No description provided for @payoutsBalanceOwed.
  ///
  /// In en, this message translates to:
  /// **'Balance owed'**
  String get payoutsBalanceOwed;

  /// No description provided for @payoutsTotalShare.
  ///
  /// In en, this message translates to:
  /// **'Barbers\' share'**
  String get payoutsTotalShare;

  /// No description provided for @payoutsTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid out'**
  String get payoutsTotalPaid;

  /// No description provided for @payoutsTotalOwed.
  ///
  /// In en, this message translates to:
  /// **'Still owed'**
  String get payoutsTotalOwed;

  /// No description provided for @payoutsRecord.
  ///
  /// In en, this message translates to:
  /// **'Record payout'**
  String get payoutsRecord;

  /// No description provided for @payoutsRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay {name}'**
  String payoutsRecordTitle(String name);

  /// No description provided for @payoutsHistory.
  ///
  /// In en, this message translates to:
  /// **'Payout history'**
  String get payoutsHistory;

  /// No description provided for @payoutsNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No payouts recorded for this month.'**
  String get payoutsNoHistory;

  /// No description provided for @payoutsNoBarbers.
  ///
  /// In en, this message translates to:
  /// **'Add barbers to track their commission and payouts.'**
  String get payoutsNoBarbers;

  /// No description provided for @payoutsAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (Birr)'**
  String get payoutsAmount;

  /// No description provided for @payoutsMethod.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get payoutsMethod;

  /// No description provided for @payoutsMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payoutsMethodCash;

  /// No description provided for @payoutsMethodTelebirr.
  ///
  /// In en, this message translates to:
  /// **'telebirr'**
  String get payoutsMethodTelebirr;

  /// No description provided for @payoutsMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get payoutsMethodBank;

  /// No description provided for @payoutsMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get payoutsMethodOther;

  /// No description provided for @payoutsNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get payoutsNote;

  /// No description provided for @payoutsPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period: {range}'**
  String payoutsPeriod(String range);

  /// No description provided for @payoutsSave.
  ///
  /// In en, this message translates to:
  /// **'Save payout'**
  String get payoutsSave;

  /// No description provided for @payoutsSaved.
  ///
  /// In en, this message translates to:
  /// **'Payout recorded.'**
  String get payoutsSaved;

  /// No description provided for @payoutsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete payout'**
  String get payoutsDelete;

  /// No description provided for @payoutsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete the {amount} payout to {name}? Payouts can be deleted only within 24 hours of recording them.'**
  String payoutsDeleteBody(String amount, String name);

  /// No description provided for @payoutsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Payout deleted.'**
  String get payoutsDeleted;

  /// No description provided for @payoutsYourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get payoutsYourShare;

  /// No description provided for @payoutsPaidToYou.
  ///
  /// In en, this message translates to:
  /// **'Paid to you'**
  String get payoutsPaidToYou;

  /// No description provided for @payoutsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month: {month}'**
  String payoutsThisMonth(String month);

  /// No description provided for @payoutsShareLine.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of {jobs} completed jobs ({gross})'**
  String payoutsShareLine(int percent, int jobs, String gross);

  /// No description provided for @payoutsMyPayouts.
  ///
  /// In en, this message translates to:
  /// **'My payouts'**
  String get payoutsMyPayouts;

  /// No description provided for @payoutsMyPayoutsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet.'**
  String get payoutsMyPayoutsEmpty;

  /// No description provided for @payoutsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all payouts'**
  String get payoutsSeeAll;

  /// No description provided for @payoutsSetCommission.
  ///
  /// In en, this message translates to:
  /// **'Set commission'**
  String get payoutsSetCommission;

  /// No description provided for @payoutsCommissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Commission for {name}'**
  String payoutsCommissionTitle(String name);

  /// No description provided for @payoutsCommissionHelp.
  ///
  /// In en, this message translates to:
  /// **'The barber\'s share of each completed booking\'s price.'**
  String get payoutsCommissionHelp;

  /// No description provided for @payoutsCommissionPercent.
  ///
  /// In en, this message translates to:
  /// **'Commission (%)'**
  String get payoutsCommissionPercent;

  /// No description provided for @payoutsCommissionSaved.
  ///
  /// In en, this message translates to:
  /// **'Commission saved.'**
  String get payoutsCommissionSaved;

  /// No description provided for @payoutsRecordedOn.
  ///
  /// In en, this message translates to:
  /// **'Recorded {date}'**
  String payoutsRecordedOn(String date);

  /// No description provided for @payoutsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load payouts. Please try again.'**
  String get payoutsLoadFailed;

  /// No description provided for @payoutsErrOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the shop owner can manage payouts and commission.'**
  String get payoutsErrOwnerOnly;

  /// No description provided for @payoutsErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This payout or barber no longer exists.'**
  String get payoutsErrNotFound;

  /// No description provided for @payoutsErrUnknownBarber.
  ///
  /// In en, this message translates to:
  /// **'This barber is not part of your shop.'**
  String get payoutsErrUnknownBarber;

  /// No description provided for @payoutsErrInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above 0 and up to {max} Birr.'**
  String payoutsErrInvalidAmount(String max);

  /// No description provided for @payoutsErrInvalidPeriod.
  ///
  /// In en, this message translates to:
  /// **'The period must start on or before its end.'**
  String get payoutsErrInvalidPeriod;

  /// No description provided for @payoutsErrNoteTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the note to {max} characters or fewer.'**
  String payoutsErrNoteTooLong(int max);

  /// No description provided for @payoutsErrInvalidCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission must be a whole number from 0 to 100.'**
  String get payoutsErrInvalidCommission;

  /// No description provided for @payoutsErrDeleteWindow.
  ///
  /// In en, this message translates to:
  /// **'Payouts can be deleted only within 24 hours of recording them.'**
  String get payoutsErrDeleteWindow;

  /// No description provided for @payoutsCarriedOver.
  ///
  /// In en, this message translates to:
  /// **'Carried over from {month}'**
  String payoutsCarriedOver(String month);

  /// No description provided for @payoutsCarryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Earlier unpaid balances couldn\'t be loaded. Showing this month only.'**
  String get payoutsCarryUnavailable;

  /// No description provided for @payoutsCarryHint.
  ///
  /// In en, this message translates to:
  /// **'Includes unpaid balances from earlier months. Paying part of it leaves the rest for next month.'**
  String get payoutsCarryHint;

  /// No description provided for @payoutsTotalCarried.
  ///
  /// In en, this message translates to:
  /// **'Carried over'**
  String get payoutsTotalCarried;

  /// No description provided for @earningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your earnings'**
  String get earningsTitle;

  /// No description provided for @earningsShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Totals for any period'**
  String get earningsShopTitle;

  /// No description provided for @earningsTab.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get earningsTab;

  /// No description provided for @earningsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get earningsThisMonth;

  /// No description provided for @earningsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get earningsLastMonth;

  /// No description provided for @earningsPickMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick a month'**
  String get earningsPickMonth;

  /// No description provided for @earningsThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get earningsThisYear;

  /// No description provided for @earningsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get earningsAllTime;

  /// No description provided for @earningsAllTimeNote.
  ///
  /// In en, this message translates to:
  /// **'All completed bookings'**
  String get earningsAllTimeNote;

  /// No description provided for @earningsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed jobs'**
  String get earningsCompleted;

  /// No description provided for @earningsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get earningsRevenue;

  /// No description provided for @earningsYourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share ({percent}%)'**
  String earningsYourShare(int percent);

  /// No description provided for @earningsBarbersShare.
  ///
  /// In en, this message translates to:
  /// **'Barbers\' share'**
  String get earningsBarbersShare;

  /// No description provided for @earningsShopKeeps.
  ///
  /// In en, this message translates to:
  /// **'Shop\'s part'**
  String get earningsShopKeeps;

  /// No description provided for @earningsByBarber.
  ///
  /// In en, this message translates to:
  /// **'By barber'**
  String get earningsByBarber;

  /// No description provided for @earningsBarberJobs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 completed job} other{{count} completed jobs}}'**
  String earningsBarberJobs(int count);

  /// No description provided for @earningsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the totals. Please try again.'**
  String get earningsLoadFailed;

  /// No description provided for @earningsShareNote.
  ///
  /// In en, this message translates to:
  /// **'Shares use the current commission. Only completed bookings count.'**
  String get earningsShareNote;

  /// No description provided for @applRegisterShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Register your barbershop'**
  String get applRegisterShopTitle;

  /// No description provided for @applRegisterShopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Own a barbershop? Apply to list it on Crown & Blade. We review every application.'**
  String get applRegisterShopSubtitle;

  /// No description provided for @applCtaApply.
  ///
  /// In en, this message translates to:
  /// **'Apply now'**
  String get applCtaApply;

  /// No description provided for @applCtaViewStatus.
  ///
  /// In en, this message translates to:
  /// **'View application'**
  String get applCtaViewStatus;

  /// No description provided for @applFormIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your shop. When the admin approves it, this account becomes the shop\'s owner account.'**
  String get applFormIntro;

  /// No description provided for @applOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get applOwnerName;

  /// No description provided for @applShopName.
  ///
  /// In en, this message translates to:
  /// **'Barbershop name'**
  String get applShopName;

  /// No description provided for @applAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get applAddress;

  /// No description provided for @applSubCity.
  ///
  /// In en, this message translates to:
  /// **'Sub-city'**
  String get applSubCity;

  /// No description provided for @applPhone.
  ///
  /// In en, this message translates to:
  /// **'Shop contact phone'**
  String get applPhone;

  /// No description provided for @applPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'09XX XXX XXX or 011 XXX XXXX'**
  String get applPhoneHint;

  /// No description provided for @applDescription.
  ///
  /// In en, this message translates to:
  /// **'About the shop (optional)'**
  String get applDescription;

  /// No description provided for @applSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get applSubmit;

  /// No description provided for @applSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get applSaveChanges;

  /// No description provided for @applResubmit.
  ///
  /// In en, this message translates to:
  /// **'Apply again'**
  String get applResubmit;

  /// No description provided for @applSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted. We\'ll let you know once it\'s reviewed.'**
  String get applSubmitted;

  /// No description provided for @applUpdated.
  ///
  /// In en, this message translates to:
  /// **'Application updated.'**
  String get applUpdated;

  /// No description provided for @applEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit application'**
  String get applEdit;

  /// No description provided for @applWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw application'**
  String get applWithdraw;

  /// No description provided for @applWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw application?'**
  String get applWithdrawTitle;

  /// No description provided for @applWithdrawBody.
  ///
  /// In en, this message translates to:
  /// **'Your application for {shop} will be deleted. You can apply again later.'**
  String applWithdrawBody(String shop);

  /// No description provided for @applWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Application withdrawn.'**
  String get applWithdrawn;

  /// No description provided for @applStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get applStatusPending;

  /// No description provided for @applStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get applStatusApproved;

  /// No description provided for @applStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get applStatusRejected;

  /// No description provided for @applPendingBody.
  ///
  /// In en, this message translates to:
  /// **'We received your application on {date}. The admin will review it soon.'**
  String applPendingBody(String date);

  /// No description provided for @applApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'{shop} is approved! Your account is now the shop\'s owner account.'**
  String applApprovedBody(String shop);

  /// No description provided for @applOpenDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open owner dashboard'**
  String get applOpenDashboard;

  /// No description provided for @applRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your application was not approved.'**
  String get applRejectedBody;

  /// No description provided for @applRejectReasonLine.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String applRejectReasonLine(String reason);

  /// No description provided for @applRejectedHint.
  ///
  /// In en, this message translates to:
  /// **'You can update the details and apply again.'**
  String get applRejectedHint;

  /// No description provided for @applSignUpOwnShop.
  ///
  /// In en, this message translates to:
  /// **'I own a barbershop and want to list it'**
  String get applSignUpOwnShop;

  /// No description provided for @applSignUpOwnShopHint.
  ///
  /// In en, this message translates to:
  /// **'After you continue, you can send your shop\'s details for approval.'**
  String get applSignUpOwnShopHint;

  /// No description provided for @applAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop applications'**
  String get applAdminTitle;

  /// No description provided for @applAdminPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pending applications} =1{1 pending application} other{{count} pending applications}}'**
  String applAdminPendingCount(int count);

  /// No description provided for @applAdminPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get applAdminPending;

  /// No description provided for @applAdminRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently decided'**
  String get applAdminRecent;

  /// No description provided for @applAdminEmpty.
  ///
  /// In en, this message translates to:
  /// **'No shop applications yet.'**
  String get applAdminEmpty;

  /// No description provided for @applAdminSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted {date}'**
  String applAdminSubmittedOn(String date);

  /// No description provided for @applAdminReviewedOn.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {date}'**
  String applAdminReviewedOn(String date);

  /// No description provided for @applAdminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get applAdminApprove;

  /// No description provided for @applAdminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get applAdminReject;

  /// No description provided for @applAdminApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve {shop}?'**
  String applAdminApproveTitle(String shop);

  /// No description provided for @applAdminApproveBody.
  ///
  /// In en, this message translates to:
  /// **'This registers the shop on a free trial with two starter services and invites {email} as its owner.'**
  String applAdminApproveBody(String email);

  /// No description provided for @applAdminApproved.
  ///
  /// In en, this message translates to:
  /// **'{shop} approved and registered.'**
  String applAdminApproved(String shop);

  /// No description provided for @applAdminRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject {shop}?'**
  String applAdminRejectTitle(String shop);

  /// No description provided for @applAdminRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (the applicant sees this)'**
  String get applAdminRejectReason;

  /// No description provided for @applAdminRejected.
  ///
  /// In en, this message translates to:
  /// **'Application rejected.'**
  String get applAdminRejected;

  /// No description provided for @applLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load applications. Please try again.'**
  String get applLoadFailed;

  /// No description provided for @applErrOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name (up to 100 characters).'**
  String get applErrOwnerName;

  /// No description provided for @applErrShopName.
  ///
  /// In en, this message translates to:
  /// **'The shop name must be 2 to 80 characters.'**
  String get applErrShopName;

  /// No description provided for @applErrAddress.
  ///
  /// In en, this message translates to:
  /// **'The address must be 2 to 160 characters.'**
  String get applErrAddress;

  /// No description provided for @applErrSubCity.
  ///
  /// In en, this message translates to:
  /// **'Choose a sub-city.'**
  String get applErrSubCity;

  /// No description provided for @applErrPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Ethiopian phone number (09..., 07... or 011...).'**
  String get applErrPhone;

  /// No description provided for @applErrDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the description to {max} characters or fewer.'**
  String applErrDescriptionTooLong(int max);

  /// No description provided for @applErrRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Write a reason of up to {max} characters.'**
  String applErrRejectReason(int max);

  /// No description provided for @applErrCustomersOnly.
  ///
  /// In en, this message translates to:
  /// **'Only customer accounts can apply to register a barbershop.'**
  String get applErrCustomersOnly;

  /// No description provided for @applErrEmailMissing.
  ///
  /// In en, this message translates to:
  /// **'Your account has no email address, which the owner invite needs.'**
  String get applErrEmailMissing;

  /// No description provided for @applErrAlreadyPending.
  ///
  /// In en, this message translates to:
  /// **'You already have an application under review. Edit it instead.'**
  String get applErrAlreadyPending;

  /// No description provided for @applErrAlreadyApproved.
  ///
  /// In en, this message translates to:
  /// **'Your application has already been approved.'**
  String get applErrAlreadyApproved;

  /// No description provided for @applErrNotPending.
  ///
  /// In en, this message translates to:
  /// **'This application has already been reviewed.'**
  String get applErrNotPending;

  /// No description provided for @applErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This application no longer exists.'**
  String get applErrNotFound;

  /// No description provided for @applErrAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the platform admin can review applications.'**
  String get applErrAdminOnly;

  /// No description provided for @emailErrRateLimitedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {minutes} min.'**
  String emailErrRateLimitedMinutes(int minutes);

  /// No description provided for @barberCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get barberCancelAction;

  /// No description provided for @barberCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get barberCancelTitle;

  /// No description provided for @barberCancelBody.
  ///
  /// In en, this message translates to:
  /// **'{customer} will be told that you cancelled their {service} on {when}. This can\'t be undone.'**
  String barberCancelBody(String customer, String service, String when);

  /// No description provided for @barberCancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get barberCancelReasonLabel;

  /// No description provided for @barberCancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. I\'m unwell today'**
  String get barberCancelReasonHint;

  /// No description provided for @barberCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get barberCancelConfirm;

  /// No description provided for @barberCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep booking'**
  String get barberCancelKeep;

  /// No description provided for @barberCancelDone.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled. The customer has been notified.'**
  String get barberCancelDone;

  /// No description provided for @barberCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel the booking: {error}'**
  String barberCancelFailed(String error);

  /// No description provided for @barberCancelErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You can only cancel your own bookings.'**
  String get barberCancelErrNotAllowed;

  /// No description provided for @barberCancelErrAfterStart.
  ///
  /// In en, this message translates to:
  /// **'This appointment has already started. Mark it as a no-show or finish it instead.'**
  String get barberCancelErrAfterStart;

  /// No description provided for @changePasswordMenu.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordMenu;

  /// No description provided for @setPasswordMenu.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPasswordMenu;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password, then choose a new one.'**
  String get changePasswordIntro;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @changePasswordSave.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get changePasswordSave;

  /// No description provided for @changePasswordDone.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed.'**
  String get changePasswordDone;

  /// No description provided for @changePasswordErrWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'Your current password is not correct.'**
  String get changePasswordErrWrongCurrent;

  /// No description provided for @changePasswordErrCurrentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password.'**
  String get changePasswordErrCurrentRequired;

  /// No description provided for @changePasswordErrRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign out and sign in again, then change your password.'**
  String get changePasswordErrRecentLogin;

  /// No description provided for @changePasswordErrNoPassword.
  ///
  /// In en, this message translates to:
  /// **'This account signs in with Google and has no password yet.'**
  String get changePasswordErrNoPassword;

  /// No description provided for @setPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get setPasswordTitle;

  /// No description provided for @setPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'You sign in with Google, so this account has no password yet. To create one, sign out, tap \"Forgot password?\" on the login screen and enter {email}. We\'ll email you a code, then you choose your password.'**
  String setPasswordBody(String email);

  /// No description provided for @setPasswordSignOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out and set a password'**
  String get setPasswordSignOutAction;

  /// No description provided for @setPasswordConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out now?'**
  String get setPasswordConfirmTitle;

  /// No description provided for @setPasswordConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll go to the login screen with \"Forgot password?\" open for your Gmail.'**
  String get setPasswordConfirmBody;

  /// No description provided for @barberInviteHelper.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email them an invitation. They open Crown & Blade, tap Register and use this Gmail to create their password.'**
  String get barberInviteHelper;

  /// No description provided for @barberInviteWaiting.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent — waiting for sign-up'**
  String get barberInviteWaiting;

  /// No description provided for @staffAcctSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a barber'**
  String get staffAcctSheetTitle;

  /// No description provided for @staffAcctSheetIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a login for your barber. They log in with this email and the temporary password, then choose their own password.'**
  String get staffAcctSheetIntro;

  /// No description provided for @staffAcctEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Login email'**
  String get staffAcctEmailLabel;

  /// No description provided for @staffAcctNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the barber\'s name'**
  String get staffAcctNameRequired;

  /// No description provided for @staffAcctEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the email the barber will log in with'**
  String get staffAcctEmailRequired;

  /// No description provided for @staffAcctTempPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get staffAcctTempPasswordLabel;

  /// No description provided for @staffAcctTempPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'8 to 128 characters with a letter and a number. The barber changes it at first login.'**
  String get staffAcctTempPasswordHelper;

  /// No description provided for @staffAcctRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate a new password'**
  String get staffAcctRegenerate;

  /// No description provided for @staffAcctCopyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get staffAcctCopyPassword;

  /// No description provided for @staffAcctCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get staffAcctCopied;

  /// No description provided for @staffAcctCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get staffAcctCreate;

  /// No description provided for @staffAcctInviteSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Already has a Crown & Blade account?'**
  String get staffAcctInviteSectionTitle;

  /// No description provided for @staffAcctInviteInstead.
  ///
  /// In en, this message translates to:
  /// **'Invite by email instead'**
  String get staffAcctInviteInstead;

  /// No description provided for @staffAcctEmailInUseTitle.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account'**
  String get staffAcctEmailInUseTitle;

  /// No description provided for @staffAcctEmailInUseBody.
  ///
  /// In en, this message translates to:
  /// **'{email} is already registered, so we can\'t create a new login for it. Send an invitation instead: they log in with their own password or Google and join your shop as a barber.'**
  String staffAcctEmailInUseBody(String email);

  /// No description provided for @staffAcctSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invitation instead'**
  String get staffAcctSendInvite;

  /// No description provided for @staffAcctInviteSaved.
  ///
  /// In en, this message translates to:
  /// **'Invitation saved. {email} becomes a barber at your shop at their next login.'**
  String staffAcctInviteSaved(String email);

  /// No description provided for @staffAcctCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Barber account created'**
  String get staffAcctCreatedTitle;

  /// No description provided for @staffAcctCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'Give these details to {name}. They log in with this email and password, then choose their own password.'**
  String staffAcctCreatedBody(String name);

  /// No description provided for @staffAcctEmailField.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get staffAcctEmailField;

  /// No description provided for @staffAcctShownOnce.
  ///
  /// In en, this message translates to:
  /// **'The temporary password is shown only now. Copy it or write it down before closing.'**
  String get staffAcctShownOnce;

  /// No description provided for @staffAcctCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy login details'**
  String get staffAcctCopyDetails;

  /// No description provided for @staffAcctDetailsHeading.
  ///
  /// In en, this message translates to:
  /// **'Crown & Blade barber login'**
  String get staffAcctDetailsHeading;

  /// No description provided for @staffAcctDetailsFooter.
  ///
  /// In en, this message translates to:
  /// **'After logging in, choose your own password.'**
  String get staffAcctDetailsFooter;

  /// No description provided for @staffAcctWaitingFirstLogin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first login'**
  String get staffAcctWaitingFirstLogin;

  /// No description provided for @staffAcctActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get staffAcctActive;

  /// No description provided for @staffAcctLostPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Lost the temporary password? They can tap \"Forgot password?\" on the login screen to reset it by email.'**
  String get staffAcctLostPasswordHint;

  /// No description provided for @staffAcctForceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your new password'**
  String get staffAcctForceTitle;

  /// No description provided for @staffAcctForceIntro.
  ///
  /// In en, this message translates to:
  /// **'You logged in with a temporary password from your barbershop. Choose your own password to continue.'**
  String get staffAcctForceIntro;

  /// No description provided for @staffAcctForceTempLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get staffAcctForceTempLabel;

  /// No description provided for @staffAcctForceTempRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the temporary password you received'**
  String get staffAcctForceTempRequired;

  /// No description provided for @staffAcctForceWrongTemp.
  ///
  /// In en, this message translates to:
  /// **'The temporary password is not correct.'**
  String get staffAcctForceWrongTemp;

  /// No description provided for @staffAcctForceSameAsTemp.
  ///
  /// In en, this message translates to:
  /// **'Choose a password different from the temporary one.'**
  String get staffAcctForceSameAsTemp;

  /// No description provided for @staffAcctForceSave.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get staffAcctForceSave;

  /// No description provided for @staffAcctForceDone.
  ///
  /// In en, this message translates to:
  /// **'Password saved. Welcome!'**
  String get staffAcctForceDone;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @registerLinkIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. Next you\'ll create a password, and we\'ll email you a link to verify the address.'**
  String get registerLinkIntro;

  /// No description provided for @registerLinkPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'You\'ll log in with {email}. After you create your account, we\'ll email you a verification link.'**
  String registerLinkPasswordIntro(String email);

  /// No description provided for @verifyLinkSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyLinkSentTitle;

  /// No description provided for @verifyLinkSentBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it, then come back and log in.'**
  String verifyLinkSentBody(String email);

  /// No description provided for @verifyLinkNotSent.
  ///
  /// In en, this message translates to:
  /// **'Your account was created, but we couldn\'t send the verification link. Tap \"Resend link\" to try again.'**
  String get verifyLinkNotSent;

  /// No description provided for @verifiedLogIn.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified — Log in'**
  String get verifiedLogIn;

  /// No description provided for @resendLink.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get resendLink;

  /// No description provided for @resendLinkIn.
  ///
  /// In en, this message translates to:
  /// **'Resend link in {seconds} s'**
  String resendLinkIn(int seconds);

  /// No description provided for @linkResent.
  ///
  /// In en, this message translates to:
  /// **'We sent a new link to {email}.'**
  String linkResent(String email);

  /// No description provided for @resetLinkIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send you a link to choose a new password.'**
  String get resetLinkIntro;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @resetLinkSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get resetLinkSentTitle;

  /// No description provided for @resetLinkSentBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset link to {email}. Open it, choose a new password, then log in here.'**
  String resetLinkSentBody(String email);

  /// No description provided for @emailErrNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get emailErrNotVerified;

  /// No description provided for @resendVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Resend verification link'**
  String get resendVerificationLink;

  /// No description provided for @emailAlreadyVerified.
  ///
  /// In en, this message translates to:
  /// **'Your email is already verified. Log in again.'**
  String get emailAlreadyVerified;

  /// No description provided for @ratingShopSummary.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count, plural, =1{1 barber rated} other{{count} barbers rated}}'**
  String ratingShopSummary(String rating, int count);

  /// No description provided for @ratingBarbersRated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 barber rated} other{{count} barbers rated}}'**
  String ratingBarbersRated(int count);

  /// No description provided for @ratingSeeBarberReviews.
  ///
  /// In en, this message translates to:
  /// **'See {name}\'s reviews'**
  String ratingSeeBarberReviews(String name);

  /// No description provided for @reviewsByBarber.
  ///
  /// In en, this message translates to:
  /// **'Reviews by barber'**
  String get reviewsByBarber;

  /// No description provided for @ratePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your cut?'**
  String get ratePromptTitle;

  /// No description provided for @ratePromptBody.
  ///
  /// In en, this message translates to:
  /// **'Rate {barber} for your {service} at {shop}.'**
  String ratePromptBody(String barber, String service, String shop);

  /// No description provided for @ratePromptDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get ratePromptDismiss;

  /// No description provided for @admPayTab.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get admPayTab;

  /// No description provided for @admPayIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription income'**
  String get admPayIncomeLabel;

  /// No description provided for @admPayThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get admPayThisMonth;

  /// No description provided for @admPayVerifiedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} verified'**
  String admPayVerifiedCount(int count);

  /// No description provided for @admPayPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String admPayPendingCount(int count);

  /// No description provided for @admPayRejectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rejected'**
  String admPayRejectedCount(int count);

  /// No description provided for @admPayShopsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get admPayShopsActive;

  /// No description provided for @admPayShopsTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get admPayShopsTrial;

  /// No description provided for @admPayShopsPastDue.
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get admPayShopsPastDue;

  /// No description provided for @admPayShopsSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get admPayShopsSuspended;

  /// No description provided for @admPayManage.
  ///
  /// In en, this message translates to:
  /// **'Manage payments'**
  String get admPayManage;

  /// No description provided for @admPayNoPending.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for review'**
  String get admPayNoPending;

  /// No description provided for @admPayTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription types & prices'**
  String get admPayTypesTitle;

  /// No description provided for @admPayTypesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, remove or change lengths and prices, and where owners pay'**
  String get admPayTypesSubtitle;

  /// No description provided for @admPaySubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each shop\'s plan, status and end date'**
  String get admPaySubscriptionsSubtitle;

  /// No description provided for @admPayOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Online payments'**
  String get admPayOnlineTitle;

  /// No description provided for @admPayOnlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Card and Chapa payments that need a decision'**
  String get admPayOnlineSubtitle;

  /// No description provided for @admPayTypesOnSale.
  ///
  /// In en, this message translates to:
  /// **'Subscription types on sale'**
  String get admPayTypesOnSale;

  /// No description provided for @admPayEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get admPayEdit;

  /// No description provided for @refundsDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds due'**
  String get refundsDueTitle;

  /// No description provided for @refundsDueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 refund waiting} other{{count} refunds waiting}}'**
  String refundsDueCount(int count);

  /// No description provided for @refundsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No refunds due. When a paid booking is cancelled, the money owed to the customer shows up here.'**
  String get refundsEmpty;

  /// No description provided for @refundBadgeDue.
  ///
  /// In en, this message translates to:
  /// **'Refund due · {amount}'**
  String refundBadgeDue(String amount);

  /// No description provided for @refundBadgeRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refundBadgeRefunded;

  /// No description provided for @refundMarkButton.
  ///
  /// In en, this message translates to:
  /// **'Mark refunded'**
  String get refundMarkButton;

  /// No description provided for @refundMarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark the refund as sent'**
  String get refundMarkTitle;

  /// No description provided for @refundMarkBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm that you sent {amount} back to {customer}.'**
  String refundMarkBody(String amount, String customer);

  /// No description provided for @refundMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'How was it refunded?'**
  String get refundMethodLabel;

  /// No description provided for @refundMethodName.
  ///
  /// In en, this message translates to:
  /// **'{method, select, telebirr{telebirr} cbe{CBE Birr} bank{Bank transfer} cash{Cash} chapa{Chapa} other{Other}}'**
  String refundMethodName(String method);

  /// No description provided for @refundReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference (optional)'**
  String get refundReferenceLabel;

  /// No description provided for @refundReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID or a short note'**
  String get refundReferenceHint;

  /// No description provided for @refundMarkedSnack.
  ///
  /// In en, this message translates to:
  /// **'Marked as refunded. The customer was notified.'**
  String get refundMarkedSnack;

  /// No description provided for @refundReasonName.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, customer_cancelled{Customer cancelled} customer_late_cancel{Customer cancelled late (partial refund)} barber_cancelled{Barber cancelled} shop_cancelled{Shop cancelled} admin_cancelled{Cancelled by the platform} request_declined{Request declined} request_expired{Request expired} shop_deleted{Shop removed} other{Cancelled}}'**
  String refundReasonName(String reason);

  /// No description provided for @refundFlaggedOn.
  ///
  /// In en, this message translates to:
  /// **'Cancelled {date}'**
  String refundFlaggedOn(String date);

  /// No description provided for @admPayReceiversMissing.
  ///
  /// In en, this message translates to:
  /// **'Add your telebirr number or CBE account so owners know where to pay.'**
  String get admPayReceiversMissing;

  /// No description provided for @admPayExpiringTitle.
  ///
  /// In en, this message translates to:
  /// **'Ending within 7 days ({count})'**
  String admPayExpiringTitle(int count);

  /// No description provided for @admPayDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Ends today} =1{1 day left} other{{count} days left}}'**
  String admPayDaysLeft(int count);

  /// No description provided for @admPayRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest payments'**
  String get admPayRecentTitle;

  /// No description provided for @admPaySeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get admPaySeeAll;

  /// No description provided for @admPayNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet.'**
  String get admPayNoPayments;

  /// No description provided for @errAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your account has been disabled. Contact support.'**
  String get errAccountDisabled;

  /// No description provided for @admUsrSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, email or phone'**
  String get admUsrSearchHint;

  /// No description provided for @admUsrFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String admUsrFilterAll(int count);

  /// No description provided for @admUsrFilterCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers ({count})'**
  String admUsrFilterCustomers(int count);

  /// No description provided for @admUsrFilterOwners.
  ///
  /// In en, this message translates to:
  /// **'Owners ({count})'**
  String admUsrFilterOwners(int count);

  /// No description provided for @admUsrFilterBarbers.
  ///
  /// In en, this message translates to:
  /// **'Barbers ({count})'**
  String admUsrFilterBarbers(int count);

  /// No description provided for @admUsrFilterAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins ({count})'**
  String admUsrFilterAdmins(int count);

  /// No description provided for @admUsrFilterDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled ({count})'**
  String admUsrFilterDisabled(int count);

  /// No description provided for @admUsrEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users match your search.'**
  String get admUsrEmpty;

  /// No description provided for @admUsrDisabledChip.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get admUsrDisabledChip;

  /// No description provided for @admUsrYouChip.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get admUsrYouChip;

  /// No description provided for @admUsrEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get admUsrEditTitle;

  /// No description provided for @admUsrEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get admUsrEmailLabel;

  /// No description provided for @admUsrPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get admUsrPhoneLabel;

  /// No description provided for @admUsrJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String admUsrJoined(String date);

  /// No description provided for @admUsrRoleSection.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get admUsrRoleSection;

  /// No description provided for @admUsrShopLabel.
  ///
  /// In en, this message translates to:
  /// **'Barbershop'**
  String get admUsrShopLabel;

  /// No description provided for @admUsrPickShop.
  ///
  /// In en, this message translates to:
  /// **'Choose a barbershop'**
  String get admUsrPickShop;

  /// No description provided for @admUsrBarberProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Barber profile'**
  String get admUsrBarberProfileLabel;

  /// No description provided for @admUsrNewBarberProfile.
  ///
  /// In en, this message translates to:
  /// **'Create a new barber profile'**
  String get admUsrNewBarberProfile;

  /// No description provided for @admUsrSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get admUsrSaveRole;

  /// No description provided for @admUsrSelfNote.
  ///
  /// In en, this message translates to:
  /// **'This is your own account. You cannot change your own role or disable yourself.'**
  String get admUsrSelfNote;

  /// No description provided for @admUsrRoleAtShop.
  ///
  /// In en, this message translates to:
  /// **'{role} at {shop}'**
  String admUsrRoleAtShop(String role, String shop);

  /// No description provided for @admUsrConfirmRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Change role?'**
  String get admUsrConfirmRoleTitle;

  /// No description provided for @admUsrConfirmRoleBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will become: {role}.'**
  String admUsrConfirmRoleBody(String name, String role);

  /// No description provided for @admUsrEffectNewBarber.
  ///
  /// In en, this message translates to:
  /// **'A new barber profile is created in {shop}.'**
  String admUsrEffectNewBarber(String shop);

  /// No description provided for @admUsrEffectUnlinkBarber.
  ///
  /// In en, this message translates to:
  /// **'Their barber profile \"{barber}\" stays in the shop for its history but stops taking bookings.'**
  String admUsrEffectUnlinkBarber(String barber);

  /// No description provided for @admUsrEffectReleaseShop.
  ///
  /// In en, this message translates to:
  /// **'{shop} will have no owner until you assign one.'**
  String admUsrEffectReleaseShop(String shop);

  /// No description provided for @admUsrEffectPreviousOwner.
  ///
  /// In en, this message translates to:
  /// **'{name} owns {shop} now and becomes a customer.'**
  String admUsrEffectPreviousOwner(String name, String shop);

  /// No description provided for @admUsrEffectInvites.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending invite is cancelled.} other{{count} pending invites are cancelled.}}'**
  String admUsrEffectInvites(int count);

  /// No description provided for @admUsrRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'Role changed.'**
  String get admUsrRoleChanged;

  /// No description provided for @admUsrAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get admUsrAccountSection;

  /// No description provided for @admUsrActive.
  ///
  /// In en, this message translates to:
  /// **'Active. This person can sign in.'**
  String get admUsrActive;

  /// No description provided for @admUsrDisabledOn.
  ///
  /// In en, this message translates to:
  /// **'Disabled on {date}'**
  String admUsrDisabledOn(String date);

  /// No description provided for @admUsrDisabledReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String admUsrDisabledReason(String reason);

  /// No description provided for @admUsrDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable account'**
  String get admUsrDisable;

  /// No description provided for @admUsrEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable account'**
  String get admUsrEnable;

  /// No description provided for @admUsrDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable {name}?'**
  String admUsrDisableTitle(String name);

  /// No description provided for @admUsrDisableBody.
  ///
  /// In en, this message translates to:
  /// **'They are signed out right away and cannot sign in until you enable the account again.'**
  String get admUsrDisableBody;

  /// No description provided for @admUsrReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get admUsrReasonLabel;

  /// No description provided for @admUsrCancelBookings.
  ///
  /// In en, this message translates to:
  /// **'Also cancel their upcoming bookings'**
  String get admUsrCancelBookings;

  /// No description provided for @admUsrUpcomingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No upcoming bookings} =1{1 upcoming booking} other{{count} upcoming bookings}}'**
  String admUsrUpcomingCount(int count);

  /// No description provided for @admUsrUpcomingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bookings could not be counted.'**
  String get admUsrUpcomingUnknown;

  /// No description provided for @admUsrBookingsStay.
  ///
  /// In en, this message translates to:
  /// **'Their upcoming bookings stay unless you tick the box.'**
  String get admUsrBookingsStay;

  /// No description provided for @admUsrDisabledSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Account disabled.} =1{Account disabled. 1 booking cancelled.} other{Account disabled. {count} bookings cancelled.}}'**
  String admUsrDisabledSnack(int count);

  /// No description provided for @admUsrEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable {name}?'**
  String admUsrEnableTitle(String name);

  /// No description provided for @admUsrEnableBody.
  ///
  /// In en, this message translates to:
  /// **'They can sign in again.'**
  String get admUsrEnableBody;

  /// No description provided for @admUsrEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Account enabled.'**
  String get admUsrEnabledSnack;

  /// No description provided for @admUsrErrNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'Only admins can manage users.'**
  String get admUsrErrNotAdmin;

  /// No description provided for @admUsrErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'This user no longer exists.'**
  String get admUsrErrNotFound;

  /// No description provided for @admUsrErrSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot change your own role or disable your own account.'**
  String get admUsrErrSelf;

  /// No description provided for @admUsrErrLastAdmin.
  ///
  /// In en, this message translates to:
  /// **'The platform needs at least one active admin.'**
  String get admUsrErrLastAdmin;

  /// No description provided for @admUsrErrShopRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a barbershop.'**
  String get admUsrErrShopRequired;

  /// No description provided for @admUsrErrShopNotFound.
  ///
  /// In en, this message translates to:
  /// **'That barbershop or barber profile no longer exists.'**
  String get admUsrErrShopNotFound;

  /// No description provided for @admUsrErrBarberTaken.
  ///
  /// In en, this message translates to:
  /// **'That barber profile already belongs to another account.'**
  String get admUsrErrBarberTaken;

  /// No description provided for @admUsrErrNoChange.
  ///
  /// In en, this message translates to:
  /// **'Nothing to change.'**
  String get admUsrErrNoChange;

  /// No description provided for @admUsrErrReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'The reason can be at most {max} characters.'**
  String admUsrErrReasonTooLong(int max);

  /// No description provided for @nearbyLandmark.
  ///
  /// In en, this message translates to:
  /// **'Nearby landmark'**
  String get nearbyLandmark;

  /// No description provided for @nearbyLandmarkHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Near Edna Mall'**
  String get nearbyLandmarkHint;

  /// No description provided for @nearbyLandmarkHelper.
  ///
  /// In en, this message translates to:
  /// **'Most customers find shops by landmark. It is shown big on your shop page.'**
  String get nearbyLandmarkHelper;

  /// No description provided for @shopMapPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Map pin'**
  String get shopMapPinTitle;

  /// No description provided for @shopMapPinHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to place the shop\'s pin, or use your current location while you are at the shop.'**
  String get shopMapPinHelp;

  /// No description provided for @useMyCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useMyCurrentLocation;

  /// No description provided for @findingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location...'**
  String get findingYourLocation;

  /// No description provided for @removeMapPin.
  ///
  /// In en, this message translates to:
  /// **'Remove pin'**
  String get removeMapPin;

  /// No description provided for @noMapPinYet.
  ///
  /// In en, this message translates to:
  /// **'No pin yet. Directions will search for the address and landmark instead.'**
  String get noMapPinYet;

  /// No description provided for @mapPinCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Pin: {latitude}, {longitude}'**
  String mapPinCoordinates(String latitude, String longitude);

  /// No description provided for @mapPinOutsideEthiopia.
  ///
  /// In en, this message translates to:
  /// **'This pin is outside Ethiopia. Check it before saving.'**
  String get mapPinOutsideEthiopia;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off. Turn it on in your phone settings and try again.'**
  String get locationServiceOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not given. You can still tap the map to place the pin.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for Crown & Blade. Allow it in Settings.'**
  String get locationPermissionBlocked;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location. Try again, or tap the map.'**
  String get locationUnavailable;

  /// No description provided for @openSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get openSettingsAction;

  /// No description provided for @shopDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get shopDirections;

  /// No description provided for @shopDirectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open a maps app.'**
  String get shopDirectionsFailed;

  /// No description provided for @shopLandmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get shopLandmarkLabel;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearMe;

  /// No description provided for @nearMeNeedsLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow location to sort shops by distance.'**
  String get nearMeNeedsLocation;

  /// No description provided for @distanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceKmAway(String km);

  /// No description provided for @distanceMetersAway.
  ///
  /// In en, this message translates to:
  /// **'{meters} m away'**
  String distanceMetersAway(int meters);

  /// No description provided for @shopMapSemantics.
  ///
  /// In en, this message translates to:
  /// **'Map showing the shop\'s location'**
  String get shopMapSemantics;
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
