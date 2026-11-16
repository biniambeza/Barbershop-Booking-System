// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String privacyPolicyUpdated(String date) {
    return 'Last updated $date';
  }

  @override
  String get privacyOpenWeb => 'Open on the web';

  @override
  String get privacyDeletePageLink => 'How to delete your account';

  @override
  String get privacyLinkFailed => 'Could not open the link.';

  @override
  String get privacyConsentPrefix =>
      'By signing up or signing in you agree to our';

  @override
  String get deleteAccountMenu => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountHeroTitle => 'Delete your account';

  @override
  String get deleteAccountHeroBody =>
      'Your profile and login are removed for good. This cannot be undone.';

  @override
  String get deleteAccountWhatHappens => 'What happens';

  @override
  String deleteAccountCancelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count upcoming bookings will be cancelled.',
      one: 'Your 1 upcoming booking will be cancelled.',
      zero: 'You have no upcoming bookings to cancel.',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountPaidRefund(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count paid bookings will be flagged for a refund. The shop keeps your phone number on them until the money is sent back.',
      one:
          '1 paid booking will be flagged for a refund. The shop keeps your phone number on it until the money is sent back.',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountKeptInCutoff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count bookings start too soon to cancel in the app. They stay with the shop without your name; call the shop if you will not come.',
      one:
          '1 booking starts too soon to cancel in the app. It stays with the shop without your name; call the shop if you will not come.',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountBarberCancel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count customer bookings with you will be cancelled and the customers told.',
      one:
          '1 customer booking with you will be cancelled and the customer told.',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountBarberLeaves(String shop) {
    return 'You are removed from $shop.';
  }

  @override
  String get deleteAccountYourShop => 'your shop';

  @override
  String get deleteAccountReviews =>
      'Your reviews keep their stars but show \"Former customer\" and lose the comment.';

  @override
  String get deleteAccountBookingsHistory =>
      'Past bookings stay in the shop\'s history without your name and phone number.';

  @override
  String get deleteAccountPersonalData =>
      'Your profile, inbox, invitations, favourites and login are deleted.';

  @override
  String get deleteAccountPendingLogin =>
      'Your data is already deleted. Confirm it\'s you once more to delete your login.';

  @override
  String get deleteAccountReauthTitle => 'Confirm it\'s you';

  @override
  String deleteAccountConfirmLabel(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get deleteAccountConfirmMismatch => 'Type DELETE exactly to confirm.';

  @override
  String get deleteAccountPasswordLabel => 'Your password';

  @override
  String get deleteAccountPasswordOrGoogle =>
      'Or leave it empty to confirm with Google.';

  @override
  String get deleteAccountReauthGoogle =>
      'You will be asked to sign in with Google again.';

  @override
  String get deleteAccountSubmit => 'Delete my account';

  @override
  String get deleteAccountDone => 'Your account was deleted.';

  @override
  String get deleteAccountErrReauth =>
      'For your security, sign in again to finish deleting your account, then tap Delete again.';

  @override
  String get deleteAccountErrReauthCancelled =>
      'Google sign-in was cancelled. Nothing was deleted.';

  @override
  String deleteAccountErrStep(String step) {
    return 'Deleting stopped at: $step Tap Delete again to continue where it stopped.';
  }

  @override
  String get deleteAccountErrFailed =>
      'Your account could not be deleted. Try again.';

  @override
  String get deleteStepCancelBookings => 'Cancelling your bookings…';

  @override
  String get deleteStepReviews => 'Updating your reviews…';

  @override
  String get deleteStepBookings => 'Removing your name from bookings…';

  @override
  String get deleteStepLeaveShop => 'Removing you from the shop…';

  @override
  String get deleteStepPersonalData => 'Deleting your inbox and invitations…';

  @override
  String get deleteStepProfile => 'Deleting your profile…';

  @override
  String get deleteStepLogin => 'Deleting your login…';

  @override
  String get deleteAccountOwnerTitle => 'Remove your shop first';

  @override
  String deleteAccountOwnerBody(String shop) {
    return 'You own $shop. An account that owns a shop cannot be deleted. Ask the admin to remove the shop: its upcoming bookings are cancelled and the customers told. You then become a customer and can delete your account here.';
  }

  @override
  String get deleteAccountLastAdminTitle => 'You are the only admin';

  @override
  String get deleteAccountLastAdminBody =>
      'Make another person an admin first (Users tab), then you can delete your account.';

  @override
  String get shopRemovalNoteLabel => 'Note for the admin (optional)';

  @override
  String get shopRemovalRequestButton => 'Ask the admin to remove my shop';

  @override
  String get shopRemovalSent => 'Request sent to the admin.';

  @override
  String shopRemovalPending(String date) {
    return 'You asked on $date. The admin will remove the shop and may contact you.';
  }

  @override
  String get shopRemovalWithdraw => 'Withdraw request';

  @override
  String shopRemovalDismissed(String date) {
    return 'The admin dismissed your request on $date. You can send it again.';
  }

  @override
  String shopRemovalNoteTooLong(int max) {
    return 'The note can be at most $max characters.';
  }

  @override
  String get shopRemovalStatusPending => 'Waiting';

  @override
  String get shopRemovalStatusDone => 'Done';

  @override
  String get shopRemovalStatusDismissed => 'Dismissed';

  @override
  String get formerCustomer => 'Former customer';

  @override
  String get adminRemovalRequestsTitle => 'Shop removal requests';

  @override
  String get adminRemovalHelp =>
      'Owners who want to delete their account ask here first. Open the shop and delete it (Delete shop), then mark the request done. The owner becomes a customer and can delete the account in the app.';

  @override
  String get adminRemovalEmpty => 'No requests.';

  @override
  String adminRemovalRequestedOn(String date) {
    return 'Asked on $date';
  }

  @override
  String get adminRemovalShopGone => 'The shop is already removed.';

  @override
  String get adminRemovalOpenShop => 'Open shop';

  @override
  String get adminRemovalMarkDone => 'Mark done';

  @override
  String get adminRemovalDismiss => 'Dismiss';

  @override
  String get portfolioTitle => 'Portfolio';

  @override
  String portfolioOfBarber(String name) {
    return '$name\'s work';
  }

  @override
  String portfolioPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get portfolioShopSectionTitle => 'See their work';

  @override
  String get portfolioShopSectionHint => 'Haircuts by this shop\'s barbers';

  @override
  String portfolioSeeWork(String name) {
    return 'See $name\'s work';
  }

  @override
  String get portfolioEmpty => 'No photos yet.';

  @override
  String portfolioBookStyle(String name) {
    return 'Book this style with $name';
  }

  @override
  String portfolioViewerCounter(int index, int total) {
    return '$index / $total';
  }

  @override
  String portfolioPhotoSemantics(int index) {
    return 'Portfolio photo $index';
  }

  @override
  String get portfolioManageTitle => 'Portfolio photos';

  @override
  String portfolioManageIntro(int max) {
    return 'Photos of your best haircuts help customers choose you. Up to $max photos.';
  }

  @override
  String get portfolioPublicNotice =>
      'Portfolio photos are public. Only post photos your customers agreed to share, with no names or phone numbers.';

  @override
  String portfolioCountOfMax(int count, int max) {
    return '$count of $max photos';
  }

  @override
  String get portfolioAddPhoto => 'Add photo';

  @override
  String get portfolioTakePhoto => 'Take a photo';

  @override
  String get portfolioChooseFromGallery => 'Choose from gallery';

  @override
  String get portfolioCaptionLabel => 'Style name (optional)';

  @override
  String get portfolioCaptionHint => 'e.g. Low fade';

  @override
  String get portfolioEditCaption => 'Edit style name';

  @override
  String get portfolioDeletePhoto => 'Delete photo';

  @override
  String get portfolioDeleteConfirmTitle => 'Delete this photo?';

  @override
  String get portfolioDeleteConfirmBody => 'Customers will no longer see it.';

  @override
  String get portfolioAdded => 'Photo added.';

  @override
  String get portfolioDeleted => 'Photo deleted.';

  @override
  String get portfolioCaptionSaved => 'Style name saved.';

  @override
  String get portfolioSaving => 'Saving photo...';

  @override
  String portfolioFull(int max) {
    return 'You have $max photos. Delete one to add another.';
  }

  @override
  String get portfolioErrNotAllowed =>
      'Only this barber and the shop owner can change this portfolio.';

  @override
  String portfolioErrCaptionTooLong(int max) {
    return 'Keep the style name to $max characters or fewer.';
  }

  @override
  String get portfolioErrImage =>
      'This photo could not be used. Try another one.';

  @override
  String get portfolioErrSlotTaken =>
      'Another photo was just added. Please try again.';

  @override
  String get portfolioErrNotFound => 'This photo was already deleted.';

  @override
  String get portfolioLoadFailed => 'Could not load the photos.';

  @override
  String get portfolioRetry => 'Try again';

  @override
  String get portfolioDashboardTitle => 'My portfolio';

  @override
  String get portfolioDashboardSubtitle => 'Show customers your best haircuts';

  @override
  String get rcptPayTitle => 'Pay by transfer';

  @override
  String get rcptEntryTitle => 'Pay with telebirr or CBE';

  @override
  String get rcptEntryBody =>
      'Send the subscription fee, then upload the receipt. Your subscription is extended once it is verified.';

  @override
  String get rcptIntro =>
      '1. Pick a period and send the amount. 2. Enter the transaction number and attach the receipt. 3. Once the receipt is verified, the days are added to your subscription.';

  @override
  String get rcptCurrentSub => 'Current subscription';

  @override
  String rcptPaidUntil(String date) {
    return 'Paid until $date';
  }

  @override
  String get rcptNoEnd => 'No end date';

  @override
  String get rcptPricesTitle => 'Prices';

  @override
  String rcptDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get rcptTierUse => 'Tap to use this amount';

  @override
  String get rcptWhereToPay => 'Where to pay';

  @override
  String get rcptMethodTelebirr => 'telebirr';

  @override
  String get rcptMethodCbe => 'Commercial Bank of Ethiopia (CBE)';

  @override
  String get rcptMethodCbeShort => 'CBE';

  @override
  String get rcptMethodOther => 'Other bank';

  @override
  String get rcptReceiverNumber => 'telebirr number';

  @override
  String get rcptReceiverAccount => 'Account number';

  @override
  String rcptReceiverName(String name) {
    return 'Name: $name';
  }

  @override
  String get rcptNotConfigured => 'Not set up yet. Please contact support.';

  @override
  String get rcvSetupTitle => 'Set up where shop owners pay you';

  @override
  String get rcvSetupBody =>
      'Owners can\'t pay their subscription until you add your telebirr number or CBE account.';

  @override
  String get rcvSetupButton => 'Set up';

  @override
  String get rcvSetupDotLabel => 'Payment setup needed';

  @override
  String get rcvErrPhone =>
      'Enter an Ethiopian mobile number, e.g. 0911 223344.';

  @override
  String get rcvErrCbe =>
      'Enter the 13-digit CBE account number that starts with 1000.';

  @override
  String get rcvErrPlaceholder =>
      'Replace the XXXX sample with your real number.';

  @override
  String get rcvErrNameShort =>
      'Enter the account holder\'s name (at least 2 characters).';

  @override
  String get rcvErrNameLong => 'Use at most 80 characters.';

  @override
  String get rcvErrFix => 'Fix the highlighted fields.';

  @override
  String get rcvTelebirrOptional =>
      'Leave empty if you don\'t take telebirr. Owners won\'t see it.';

  @override
  String get rcvCbeOptional =>
      'Leave empty if you don\'t take CBE transfers. Owners won\'t see it.';

  @override
  String get rcvPaymentsNotOpen =>
      'Payments aren\'t open yet — please check back soon.';

  @override
  String get rcptCopy => 'Copy';

  @override
  String get rcptCopied => 'Copied';

  @override
  String get rcptSubmitTitle => 'Submit your receipt';

  @override
  String get rcptMethodLabel => 'Paid with';

  @override
  String get rcptTxLabel => 'Transaction number';

  @override
  String get rcptTxHintTelebirr => 'e.g. CHK1AB2CDE (in the telebirr SMS)';

  @override
  String get rcptTxHintCbe => 'e.g. FT2412345ABC (on the CBE receipt)';

  @override
  String get rcptTxHintOther => 'The reference on your receipt';

  @override
  String get rcptSuffixLabel => 'Last 8 digits of your account (optional)';

  @override
  String get rcptSuffixHelper => 'Helps us open your CBE receipt.';

  @override
  String get rcptAmountLabel => 'Amount paid (ETB)';

  @override
  String rcptAmountGrants(String days) {
    return 'Adds $days to your subscription';
  }

  @override
  String rcptAmountBelowMin(String amount) {
    return 'The minimum payment is $amount';
  }

  @override
  String get rcptPhotoLabel => 'Receipt photo or screenshot';

  @override
  String get rcptPhotoHint => 'Recommended: it makes verification faster.';

  @override
  String get rcptTakePhoto => 'Camera';

  @override
  String get rcptChooseImage => 'Gallery';

  @override
  String get rcptRemovePhoto => 'Remove photo';

  @override
  String get rcptPhotoFailed =>
      'That image can\'t be used. Try another photo or screenshot.';

  @override
  String get rcptSubmit => 'Submit receipt';

  @override
  String get rcptSubmitted =>
      'Receipt submitted. We\'ll notify you when it\'s verified.';

  @override
  String get rcptHistoryTitle => 'Your receipts';

  @override
  String get rcptNoHistory => 'No receipts submitted yet.';

  @override
  String get rcptStatusPending => 'Awaiting verification';

  @override
  String get rcptStatusVerified => 'Verified';

  @override
  String get rcptStatusRejected => 'Rejected';

  @override
  String get rcptStatusNeedsReview => 'Being checked';

  @override
  String rcptGranted(String days) {
    return '$days added';
  }

  @override
  String get rcptVerifiedAuto => 'Verified automatically';

  @override
  String get rcptReasonTitle => 'Reason';

  @override
  String rcptReasonLine(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get rcptReasonAmountTooLow =>
      'The amount is below the cheapest subscription.';

  @override
  String get rcptReasonDuplicate => 'This transaction has already been used.';

  @override
  String get rcptReasonNotFound => 'The official receipt could not be found.';

  @override
  String get rcptReasonNotCompleted => 'The transaction is not completed.';

  @override
  String get rcptReasonReceiverMismatch =>
      'The money was not sent to the platform\'s account.';

  @override
  String get rcptReasonAmountMismatch => 'The receipt shows a lower amount.';

  @override
  String get rcptReasonTooOld => 'The receipt is more than 30 days old.';

  @override
  String get rcptReasonFetchFailed =>
      'The receipt couldn\'t be checked automatically. An admin will review it.';

  @override
  String get rcptReasonUnsupported => 'An admin checks payments made this way.';

  @override
  String get rcptErrOwnerOnly => 'Only the shop owner can do this.';

  @override
  String get rcptErrAdminOnly => 'Only the platform admin can do this.';

  @override
  String get rcptErrShopNotFound => 'Shop not found.';

  @override
  String get rcptErrTxId => 'Enter a valid transaction number.';

  @override
  String get rcptErrAmount => 'Enter the amount you paid.';

  @override
  String get rcptErrDuplicate =>
      'This transaction number has already been submitted.';

  @override
  String get rcptErrImageTooLarge => 'The photo is too large.';

  @override
  String get rcptErrNotFound => 'Receipt not found.';

  @override
  String get rcptErrNotOpen => 'This receipt has already been decided.';

  @override
  String get rcptErrReason => 'Enter a reason (up to 300 characters).';

  @override
  String get rcptErrPricing =>
      'Check the prices: every period needs whole days and an amount, and a longer period must cost more.';

  @override
  String get rcptAdminTitle => 'Subscription receipts';

  @override
  String get rcptAdminIntro =>
      'Open the official receipt and check the amount, receiver and date, then approve or reject.';

  @override
  String get rcptAdminOpenSection => 'To review';

  @override
  String get rcptAdminDecidedSection => 'Recently decided';

  @override
  String get rcptAdminEmpty => 'Nothing to review.';

  @override
  String rcptAdminLoadFailed(String error) {
    return 'Couldn\'t load receipts: $error';
  }

  @override
  String rcptAdminWouldGrant(String days) {
    return 'Grants $days';
  }

  @override
  String get rcptAdminTooLow => 'Below the cheapest period';

  @override
  String rcptAdminSubmitted(String date) {
    return 'Sent $date';
  }

  @override
  String get rcptAdminSubmittedLabel => 'Submitted';

  @override
  String get rcptAdminNoImage => 'No photo attached.';

  @override
  String get rcptAdminOpenOfficial => 'Open official receipt';

  @override
  String get rcptAdminNoOfficial =>
      'This method has no official receipt page. Check the photo and your bank statement.';

  @override
  String get rcptAdminVerifiedAmount => 'Verified amount (ETB)';

  @override
  String rcptAdminNewEnd(String date) {
    return 'New end date: $date';
  }

  @override
  String get rcptApprove => 'Approve';

  @override
  String get rcptReject => 'Reject';

  @override
  String get rcptRejectTitle => 'Reject receipt';

  @override
  String get rcptRejectReasonLabel => 'Reason (the owner will see this)';

  @override
  String rcptApproved(String days, String date) {
    return 'Approved: $days added, until $date.';
  }

  @override
  String get rcptRejectedDone => 'Receipt rejected.';

  @override
  String get rcptPricingTitle => 'Subscription prices';

  @override
  String get rcptPricingIntro =>
      'Owners see these prices. A payment buys the longest period it covers.';

  @override
  String get rcptPricingDays => 'Days';

  @override
  String get rcptPricingAmount => 'Amount (ETB)';

  @override
  String get rcptPricingAddTier => 'Add a period';

  @override
  String get rcptPricingRemoveTier => 'Remove';

  @override
  String get rcptPricingTelebirr => 'telebirr receiver';

  @override
  String get rcptPricingCbe => 'CBE receiver';

  @override
  String get rcptPricingName => 'Account name';

  @override
  String get rcptPricingSave => 'Save prices';

  @override
  String get rcptPricingSaved => 'Prices saved.';

  @override
  String get rcptStorageTitle => 'Receipt photos';

  @override
  String get rcptStorageToggle =>
      'Store receipt photos in Firebase Storage — needs Blaze';

  @override
  String get rcptStorageHelp =>
      'Off: photos are saved inside the receipt record (works on the free plan). On: they go to Firebase Storage; if an upload fails, the photo is saved inside the record instead.';

  @override
  String get rcptPhotoLoadFailed => 'Couldn\'t load the receipt photo.';

  @override
  String get rcptPhotoRetry => 'Try again';

  @override
  String get rcptNotifApprovedTitle => 'Subscription payment approved';

  @override
  String rcptNotifApprovedBody(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days were',
      one: '1 day was',
    );
    return '$_temp0 added. Your subscription runs until $date.';
  }

  @override
  String get rcptNotifRejectedTitle => 'Subscription payment rejected';

  @override
  String rcptNotifRejectedBody(String transactionId, String reason) {
    return 'Transaction $transactionId: $reason';
  }

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
  String freePlanReportsFromBookings(int days) {
    return 'Based on the last $days days of bookings.';
  }

  @override
  String get freePlanRequestNoAnswer => 'No answer';

  @override
  String get appTitle => 'Crown & Blade - Barbershop Booking';

  @override
  String get brandUpper => 'CROWN & BLADE';

  @override
  String get brandName => 'Crown & Blade';

  @override
  String get introTagline => 'Book your barber in Addis Ababa';

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
  String barberLabel(String name) {
    return 'Barber: $name';
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
  String get timeOffSeveralDays => 'Several days';

  @override
  String get vacationFromDate => 'First day';

  @override
  String get vacationToDate => 'Last day';

  @override
  String get vacationFirstDayFrom => 'First day starts at';

  @override
  String get vacationLastDayUntil => 'Last day ends at';

  @override
  String get vacationStartOfWork => 'Start of work';

  @override
  String get vacationEndOfWork => 'End of work';

  @override
  String vacationMaxDays(int days, int max) {
    return '$days days selected (at most $max).';
  }

  @override
  String get vacationLabel => 'Vacation';

  @override
  String vacationRange(String from, String to) {
    return '$from - $to';
  }

  @override
  String get vacationConflictsTitle => 'Bookings during this time off';

  @override
  String vacationConflictsBody(int count) {
    return '$count upcoming bookings fall inside this time off. Cancel them and notify each customer, or keep them (their times stay booked).';
  }

  @override
  String get vacationPaidRefund => 'Paid: a refund will be flagged';

  @override
  String get vacationCancelAndNotify => 'Cancel & notify customers';

  @override
  String get vacationKeepBookings => 'Keep bookings';

  @override
  String get vacationSaved =>
      'Vacation saved. Customers can no longer book these days.';

  @override
  String vacationSavedCancelled(int count) {
    return 'Vacation saved. $count bookings cancelled and their customers notified.';
  }

  @override
  String vacationRemoveConfirm(String range) {
    return 'Remove the whole vacation $range? Customers can book these days again.';
  }

  @override
  String vacationErrTooLong(int max) {
    return 'A vacation can be at most $max days long.';
  }

  @override
  String get vacationErrNothingToBlock =>
      'There are no working hours left to block on these days.';

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
  String get earlyFinishBannerTitle =>
      'Your barber is free now — come in early';

  @override
  String earlyFinishBannerBody(String barber, String time) {
    return '$barber finished early. You can come in before your $time appointment.';
  }

  @override
  String get earlyFinishCallShop => 'Call shop';

  @override
  String get earlyFinishDirections => 'Directions';

  @override
  String earlyFinishNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers were told they can come early',
      one: '1 customer was told they can come early',
    );
    return '$_temp0';
  }

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
  String get barberPhoneHelper =>
      'Private. Customers see it only after their booking is confirmed.';

  @override
  String get barberPhoneNone => 'No mobile number';

  @override
  String get barberPhoneEdit => 'Edit mobile number';

  @override
  String get barberPhoneSaved => 'Mobile number saved';

  @override
  String callBarberAction(String name) {
    return 'Call $name';
  }

  @override
  String barberPhoneOnBooking(String phone) {
    return 'Barber\'s phone: $phone';
  }

  @override
  String get invalidEmailShort => 'Enter a valid email address';

  @override
  String get adminSubtitle => 'Platform System Administration';

  @override
  String get adminShopsHeroTitle => 'Barbershops on the platform';

  @override
  String get adminShopsMetricBookable => 'Bookable';

  @override
  String get adminShopsMetricSuspended => 'Suspended';

  @override
  String get adminShopsFilterActive => 'Active';

  @override
  String get adminShopsFilterSuspended => 'Suspended';

  @override
  String get adminShopsFilterUnverified => 'Unverified';

  @override
  String get adminShopsEdit => 'Edit';

  @override
  String get adminShopsEditTitle => 'Edit barbershop';

  @override
  String get adminShopsSectionProfile => 'Shop profile';

  @override
  String get adminShopsSectionPlatform => 'Verification & subscription';

  @override
  String get adminShopsSectionOwner => 'Owner';

  @override
  String get adminShopsSectionStatus => 'Availability';

  @override
  String get adminShopsFieldName => 'Shop name';

  @override
  String get adminShopsFieldAddress => 'Address';

  @override
  String get adminShopsFieldSubCity => 'Sub-city';

  @override
  String get adminShopsFieldLandmark => 'Landmark (optional)';

  @override
  String get adminShopsFieldPhone => 'Shop phone';

  @override
  String get adminShopsFieldDescription => 'Description';

  @override
  String adminShopsHoursReadOnly(String days, String hours) {
    return 'Opening hours: $days $hours · set by the shop owner';
  }

  @override
  String get adminShopsFieldVerified => 'Verified partner';

  @override
  String get adminShopsFieldVerifiedHint =>
      'Shows the verified badge to customers';

  @override
  String get adminShopsFieldPlan => 'Plan';

  @override
  String get adminShopsFieldStatus => 'Subscription status';

  @override
  String get adminShopsFieldEndsAt => 'Subscription ends';

  @override
  String get adminShopsNoEndDate => 'No end date';

  @override
  String get adminShopsClearDate => 'Clear date';

  @override
  String get adminShopsOverrideHint =>
      'Admin override: changes here are saved directly to the shop.';

  @override
  String get adminShopsSave => 'Save changes';

  @override
  String get adminShopsSaved => 'Shop saved';

  @override
  String adminShopsOwnerSignedUp(String email) {
    return 'Signed up · $email';
  }

  @override
  String adminShopsOwnerInvitePending(String email) {
    return 'Invite pending: $email gets owner access when they sign in';
  }

  @override
  String get adminShopsOwnerNone => 'No owner assigned';

  @override
  String get adminShopsStatusActive => 'Active';

  @override
  String get adminShopsStatusAdminSuspended => 'Suspended by admin';

  @override
  String get adminShopsStatusUnpaid => 'Subscription suspended';

  @override
  String adminShopsSuspendedSince(String date, String reason) {
    return 'Suspended on $date: $reason';
  }

  @override
  String get adminShopsSuspend => 'Suspend shop';

  @override
  String get adminShopsReactivate => 'Reactivate shop';

  @override
  String adminShopsSuspendTitle(String shop) {
    return 'Suspend $shop?';
  }

  @override
  String get adminShopsSuspendBody =>
      'Customers will not see this shop or be able to book it. Existing bookings stay. The owner sees your reason.';

  @override
  String get adminShopsReasonLabel => 'Reason (shown to the owner)';

  @override
  String adminShopsSuspendedToast(String shop) {
    return '$shop suspended';
  }

  @override
  String adminShopsReactivateTitle(String shop) {
    return 'Reactivate $shop?';
  }

  @override
  String get adminShopsReactivateBody =>
      'Customers will be able to find and book this shop again.';

  @override
  String adminShopsReactivatedToast(String shop) {
    return '$shop reactivated';
  }

  @override
  String adminShopsDeleteBody(String shop) {
    return 'This permanently deletes $shop. Type the shop name to confirm.';
  }

  @override
  String get adminShopsDeleteTypeName => 'Shop name';

  @override
  String get adminShopsDeleteWillHeading => 'What happens';

  @override
  String adminShopsDeleteListBarbers(int count) {
    return '$count barber profiles are deleted, with their time off and booked slots';
  }

  @override
  String adminShopsDeleteListServices(int count) {
    return '$count services are deleted';
  }

  @override
  String adminShopsDeleteListStaff(int count) {
    return '$count staff accounts (owner and barbers) become customer accounts';
  }

  @override
  String adminShopsDeleteListInvites(int count) {
    return '$count pending invites are revoked';
  }

  @override
  String adminShopsDeleteListBookings(int count) {
    return '$count upcoming bookings are cancelled and their customers notified';
  }

  @override
  String get adminShopsDeleteListBookingsUnknown =>
      'Upcoming bookings are cancelled and their customers notified';

  @override
  String get adminShopsDeleteListOther =>
      'The walk-in queue, reviews, payouts and statistics are deleted';

  @override
  String get adminShopsDeleteListKept =>
      'Past bookings are kept for history. Staff can still sign in, as customers.';

  @override
  String get adminShopsDeleteStepPrepare => 'Suspending the shop';

  @override
  String get adminShopsDeleteStepBookings => 'Cancelling upcoming bookings';

  @override
  String get adminShopsDeleteStepStaff => 'Moving staff to customer accounts';

  @override
  String get adminShopsDeleteStepData =>
      'Deleting barbers, services and shop data';

  @override
  String get adminShopsDeleteStepShop => 'Deleting the shop';

  @override
  String adminShopsDeleteProgress(int step, int total, String label) {
    return 'Step $step of $total: $label…';
  }

  @override
  String adminShopsDeleteFailed(String step) {
    return 'Could not finish \"$step\". What was done stays done; tap Retry to continue.';
  }

  @override
  String get adminShopsDeleteRetry => 'Retry';

  @override
  String get shopRemovedNoticeTitle => 'Your barbershop was removed';

  @override
  String get shopRemovedNoticeBody =>
      'You can keep using Crown & Blade as a customer.';

  @override
  String get adminShopsErrReasonRequired => 'Enter a reason.';

  @override
  String adminShopsErrReasonTooLong(int max) {
    return 'Keep the reason under $max characters.';
  }

  @override
  String get adminShopsErrNameRequired => 'Enter the shop name.';

  @override
  String get adminShopsErrNameTooLong => 'The shop name is too long.';

  @override
  String get adminShopsErrAddressRequired => 'Enter the address.';

  @override
  String get adminShopsErrTextTooLong => 'Some of the text is too long.';

  @override
  String get adminShopsErrPlan => 'Unknown plan.';

  @override
  String get adminShopsErrNotFound => 'This shop no longer exists.';

  @override
  String get adminShopsErrNotAdmin => 'Only the platform admin can do this.';

  @override
  String get adminShopsErrNameMismatch => 'The name does not match.';

  @override
  String get adminShopsUnavailableTitle => 'Temporarily unavailable';

  @override
  String get adminShopsUnavailableBody =>
      'This barbershop is not taking bookings right now. Your existing appointments are not affected.';

  @override
  String get adminShopsOwnerBannerTitle =>
      'Your shop is suspended by the platform';

  @override
  String get adminShopsOwnerBannerBody =>
      'Customers cannot find or book your shop until it is reactivated. Existing bookings stay.';

  @override
  String adminShopsOwnerBannerReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get adminShopsOwnerBannerContact =>
      'Contact the platform admin to reactivate it.';

  @override
  String get deleteShopTitle => 'Delete Barbershop?';

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
  String get searchShopsAdminHint =>
      'Search shops by name, address, or sub-city...';

  @override
  String get filterVerifiedPartners => 'Verified Partners';

  @override
  String registeredBarbershopsCount(int count) {
    return 'Registered Barbershops ($count)';
  }

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
  String get adminRegisterHoursOwnerNote =>
      'The shop owner sets the opening hours after signing in.';

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
  String get allSubCities => 'All sub-cities';

  @override
  String get subCityFilterTooltip => 'Filter barbershops by sub-city';

  @override
  String subCityOptionCount(String name, int count) {
    return '$name ($count)';
  }

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
  String get reportsBusyHoursTab => 'Busy hours';

  @override
  String get reportsNoShowsTab => 'No-shows';

  @override
  String get busyRangeLast30 => 'Last 30 days';

  @override
  String get busyRangeLast90 => 'Last 90 days';

  @override
  String get busyRangeMonth => 'Month';

  @override
  String get busyHoursTitle => 'Bookings by day and hour';

  @override
  String get busyHoursNote =>
      'Addis Ababa time. Each booking counts in the hour it starts. Cancelled bookings are left out.';

  @override
  String get busyBusiestDay => 'Busiest day';

  @override
  String get busyBusiestTime => 'Busiest time';

  @override
  String get busyQuietestHour => 'Quietest hour';

  @override
  String get busyTotalBookings => 'Bookings';

  @override
  String get busyNoBookings => 'No bookings in this period.';

  @override
  String get busyLegendFewer => 'Fewer';

  @override
  String get busyLegendMore => 'More';

  @override
  String get busyLoadFailed => 'Could not load this month\'s bookings.';

  @override
  String busyCellSemantics(String day, String hour, int count) {
    return '$day $hour: $count bookings';
  }

  @override
  String get noShowsAutoBlockTitle => 'Auto-block repeat no-shows';

  @override
  String noShowsAutoBlockOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A customer is blocked after $count no-shows at your shop.',
      one: 'A customer is blocked after 1 no-show at your shop.',
    );
    return '$_temp0';
  }

  @override
  String get noShowsAutoBlockOff =>
      'Off. Turn it on to block a customer automatically after repeated no-shows.';

  @override
  String get noShowsAutoBlockLimit => 'No-shows before blocking';

  @override
  String get noShowsDecrease => 'Fewer';

  @override
  String get noShowsIncrease => 'More';

  @override
  String get noShowsSettingsUnavailable =>
      'The auto-block setting could not be loaded.';

  @override
  String get noShowsSearchHint => 'Search customers by name';

  @override
  String get noShowsFilterAll => 'All';

  @override
  String noShowsFilterBlocked(int count) {
    return 'Blocked ($count)';
  }

  @override
  String get noShowsListTitle => 'Customers by no-show rate';

  @override
  String get noShowsRateHelp =>
      'No-show rate: missed appointments out of completed and missed ones.';

  @override
  String get noShowsNoCustomers => 'No customers yet.';

  @override
  String get noShowsNoMatch => 'No customers match your search.';

  @override
  String noShowsWindowNote(int days) {
    return 'Counts cover the last $days days of bookings.';
  }

  @override
  String noShowsCustomerStats(
      int bookings, int completed, int cancelled, int noShows) {
    return 'Bookings $bookings · Completed $completed · Cancelled $cancelled · No-shows $noShows';
  }

  @override
  String noShowsRateSemantics(int percent) {
    return 'No-show rate $percent%';
  }

  @override
  String get customerBlockedChip => 'Blocked';

  @override
  String get customerAutoBlockedChip => 'Auto-blocked';

  @override
  String get customerBlockAction => 'Block';

  @override
  String get customerUnblockAction => 'Unblock';

  @override
  String customerBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get customerBlockBody =>
      'They won\'t be able to book or join the queue at your shop. They will see: \"This shop can\'t take your booking right now. Please contact the shop.\"';

  @override
  String get customerBlockReasonLabel => 'Note (optional)';

  @override
  String get customerBlockReasonHelper =>
      'For your records. The app doesn\'t show it to the customer.';

  @override
  String customerBlockCancelUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Also cancel their $count upcoming bookings',
      one: 'Also cancel their upcoming booking',
    );
    return '$_temp0';
  }

  @override
  String get customerBlockCancelPaidNote =>
      'Paid bookings are marked for a refund.';

  @override
  String get customerBlockKeepNote =>
      'Their upcoming bookings stay unless you cancel them here.';

  @override
  String customerBlockedSnack(String name) {
    return '$name is blocked.';
  }

  @override
  String customerBlockedCancelledSnack(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name is blocked. $count bookings cancelled.',
      one: '$name is blocked. 1 booking cancelled.',
    );
    return '$_temp0';
  }

  @override
  String customerUnblockTitle(String name) {
    return 'Unblock $name?';
  }

  @override
  String get customerUnblockBody =>
      'They can book and join the queue at your shop again.';

  @override
  String customerUnblockedSnack(String name) {
    return '$name is unblocked.';
  }

  @override
  String customerBlockedOn(String date) {
    return 'Blocked on $date';
  }

  @override
  String customerBlockNote(String reason) {
    return 'Note: $reason';
  }

  @override
  String customerAutoBlockedAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blocked automatically after $count no-shows',
      one: 'Blocked automatically after 1 no-show',
    );
    return '$_temp0';
  }

  @override
  String get customerUnknownName => 'Customer';

  @override
  String get errCustomerBlockedAtShop =>
      'This shop can\'t take your booking right now. Please contact the shop.';

  @override
  String get errCustomerBlockNotAllowed =>
      'Only the shop owner can block or unblock customers.';

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
  String get yourBarbersTitle => 'Your barbers';

  @override
  String get yourBarbersSubtitle => 'Favorites and recent visits';

  @override
  String get bookAgain => 'Book again';

  @override
  String bookAgainWith(String name) {
    return 'Book again with $name';
  }

  @override
  String rebookLastService(String service) {
    return 'Last time: $service';
  }

  @override
  String get rebookFavoriteTag => 'Favorite';

  @override
  String favoriteBarberAdd(String name) {
    return 'Add $name to favorites';
  }

  @override
  String favoriteBarberRemove(String name) {
    return 'Remove $name from favorites';
  }

  @override
  String rebookSuggestedSlot(String name, String when) {
    return 'Next free time with $name: $when. Tap another time to change it.';
  }

  @override
  String rebookNoFreeTime(String name, int days) {
    return '$name has no free time in the next $days days. Try another barber at this shop.';
  }

  @override
  String get rebookFallbackTitle => 'Can\'t book again right now';

  @override
  String rebookShopGone(String shop) {
    return '$shop is no longer listed in the app. Find another barber in Find Barbers.';
  }

  @override
  String rebookShopBlocked(String shop) {
    return '$shop isn\'t taking bookings right now. Please try again later.';
  }

  @override
  String rebookBarberGone(String barber, String shop) {
    return '$barber no longer works at $shop. Another barber there can look after you.';
  }

  @override
  String rebookBarberUnavailable(String barber, String shop) {
    return '$barber isn\'t taking bookings right now. Another barber at $shop can look after you.';
  }

  @override
  String rebookServiceGone(String shop, String service, String barber) {
    return '$shop no longer offers $service. Pick another service with $barber.';
  }

  @override
  String rebookNoServices(String shop) {
    return '$shop has no services listed right now. Please try again later.';
  }

  @override
  String get rebookSeeShop => 'See the shop';

  @override
  String get rebookPickService => 'Pick a service';

  @override
  String get rebookRemoveFavorite => 'Remove from favorites';

  @override
  String get rebookSignInNeeded => 'Sign in as a customer to book again.';

  @override
  String get rebookClose => 'Close';

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
  String get subExpTrialEnded =>
      'Your trial ended — pay to keep taking bookings. Your shop will be suspended soon unless you pay.';

  @override
  String get subExpTrialEndedToday =>
      'Your trial ended — pay to keep taking bookings. Your shop will be suspended today unless you pay.';

  @override
  String subExpTrialEndedInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your trial ended — pay to keep taking bookings. $count days left before your shop is suspended.',
      one:
          'Your trial ended — pay to keep taking bookings. 1 day left before your shop is suspended.',
    );
    return '$_temp0';
  }

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
  String get reviewsRateAction => 'Rate your barber';

  @override
  String get reviewsYourRating => 'Your rating';

  @override
  String get reviewsRateTitle => 'Rate your barber';

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
  String get reviewsCommentHint => 'Tell us about your experience';

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
  String get reviewsEditAction => 'Edit review';

  @override
  String get reviewsDeleteAction => 'Delete review';

  @override
  String get reviewsEditTitle => 'Edit your review';

  @override
  String get reviewsSaveEdit => 'Save changes';

  @override
  String get reviewsEditSaved => 'Your review was updated.';

  @override
  String get reviewsEdited => 'edited';

  @override
  String get reviewsManageHint => 'Tap to edit or delete your review';

  @override
  String get reviewsDeleteConfirmTitle => 'Delete your review?';

  @override
  String reviewsDeleteConfirmBody(String barber) {
    return 'Your stars and comment will be removed from $barber\'s rating. You can rate this visit again later.';
  }

  @override
  String get reviewsDeleted => 'Your review was deleted.';

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
    return 'Enter the 6-digit code we sent to $email';
  }

  @override
  String get codeLabel => '6-digit code';

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
      'Please verify your email first. Open the link we emailed you, then log in.';

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
  String get registerEmailTitle => 'Enter your email';

  @override
  String get registerEmailIntro =>
      'We\'ll send you a 6-digit code to confirm it\'s yours.';

  @override
  String get enterCodeTitle => 'Check your email';

  @override
  String get verifyButton => 'Verify';

  @override
  String get createPasswordTitle => 'Create your password';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get newPasswordTitle => 'Choose a new password';

  @override
  String get savePasswordButton => 'Save';

  @override
  String emailVerifiedNotice(String email) {
    return '$email is verified.';
  }

  @override
  String authStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get emailErrVerificationExpired =>
      'This step took too long. Please request a new code.';

  @override
  String get logInInstead => 'Log in instead';

  @override
  String get acceptRequestsTitle => 'New requests';

  @override
  String acceptRequestsCount(int count) {
    return '$count waiting';
  }

  @override
  String get acceptRequestsHelp =>
      'Accept or decline each booking. Requests not answered 1 hour before the start are cancelled automatically.';

  @override
  String get acceptAction => 'Accept';

  @override
  String get acceptDeclineAction => 'Decline';

  @override
  String get acceptDeclineTitle => 'Decline this booking?';

  @override
  String acceptDeclineBody(String customer) {
    return '$customer will be told you can\'t take it and asked to pick another time.';
  }

  @override
  String get acceptDeclineReasonLabel => 'Reason (optional)';

  @override
  String get acceptDeclineConfirm => 'Decline booking';

  @override
  String get acceptDeclineCancel => 'Back';

  @override
  String acceptAccepted(String customer) {
    return 'Booking accepted. $customer has been told.';
  }

  @override
  String get acceptDeclined => 'Booking declined.';

  @override
  String acceptFailed(String error) {
    return 'Couldn\'t answer the request: $error';
  }

  @override
  String get acceptWaitingForBarber => 'Waiting for barber';

  @override
  String acceptWaitingFor(String barber) {
    return 'Waiting for $barber to accept';
  }

  @override
  String get acceptRequestSentTitle => 'Request sent!';

  @override
  String acceptRequestSentBody(String barber) {
    return '$barber will confirm your booking soon. We\'ll let you know when they accept.';
  }

  @override
  String get acceptPayAfterAcceptance =>
      'You can pay online once the barber accepts.';

  @override
  String get acceptDeclinedNote =>
      'The barber couldn\'t take this booking. Please pick another time.';

  @override
  String get acceptExpiredNote =>
      'The barber didn\'t answer in time. Please pick another time.';

  @override
  String acceptDeclineReasonNote(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get acceptPolicyToggle => 'Barbers accept each booking';

  @override
  String get acceptPolicyToggleHelp =>
      'New bookings wait until the barber accepts them. Requests not answered 1 hour before the start are cancelled automatically.';

  @override
  String get acceptErrNotAllowed =>
      'Only the booked barber or the shop owner can answer this request.';

  @override
  String acceptErrReasonTooLong(int max) {
    return 'The reason can be at most $max characters.';
  }

  @override
  String get payoutsTitle => 'Barber payouts';

  @override
  String get payoutsOpenButton => 'Payouts & commission';

  @override
  String get payoutsMonthLabel => 'Month';

  @override
  String get payoutsCompletedJobs => 'Completed jobs';

  @override
  String get payoutsGross => 'Gross';

  @override
  String get payoutsCommission => 'Commission';

  @override
  String payoutsCommissionLine(int percent) {
    return 'Commission: $percent%';
  }

  @override
  String get payoutsBarberShare => 'Barber share';

  @override
  String get payoutsAlreadyPaid => 'Already paid';

  @override
  String get payoutsBalanceOwed => 'Balance owed';

  @override
  String get payoutsTotalShare => 'Barbers\' share';

  @override
  String get payoutsTotalPaid => 'Paid out';

  @override
  String get payoutsTotalOwed => 'Still owed';

  @override
  String get payoutsRecord => 'Record payout';

  @override
  String payoutsRecordTitle(String name) {
    return 'Pay $name';
  }

  @override
  String get payoutsHistory => 'Payout history';

  @override
  String get payoutsNoHistory => 'No payouts recorded for this month.';

  @override
  String get payoutsNoBarbers =>
      'Add barbers to track their commission and payouts.';

  @override
  String get payoutsAmount => 'Amount (Birr)';

  @override
  String get payoutsMethod => 'Paid by';

  @override
  String get payoutsMethodCash => 'Cash';

  @override
  String get payoutsMethodTelebirr => 'telebirr';

  @override
  String get payoutsMethodBank => 'Bank transfer';

  @override
  String get payoutsMethodOther => 'Other';

  @override
  String get payoutsNote => 'Note (optional)';

  @override
  String payoutsPeriod(String range) {
    return 'Period: $range';
  }

  @override
  String get payoutsSave => 'Save payout';

  @override
  String get payoutsSaved => 'Payout recorded.';

  @override
  String get payoutsDelete => 'Delete payout';

  @override
  String payoutsDeleteBody(String amount, String name) {
    return 'Delete the $amount payout to $name? Payouts can be deleted only within 24 hours of recording them.';
  }

  @override
  String get payoutsDeleted => 'Payout deleted.';

  @override
  String get payoutsYourShare => 'Your share';

  @override
  String get payoutsPaidToYou => 'Paid to you';

  @override
  String payoutsThisMonth(String month) {
    return 'This month: $month';
  }

  @override
  String payoutsShareLine(int percent, int jobs, String gross) {
    return '$percent% of $jobs completed jobs ($gross)';
  }

  @override
  String get payoutsMyPayouts => 'My payouts';

  @override
  String get payoutsMyPayoutsEmpty => 'No payouts yet.';

  @override
  String get payoutsSeeAll => 'See all payouts';

  @override
  String get payoutsSetCommission => 'Set commission';

  @override
  String payoutsCommissionTitle(String name) {
    return 'Commission for $name';
  }

  @override
  String get payoutsCommissionHelp =>
      'The barber\'s share of each completed booking\'s price.';

  @override
  String get payoutsCommissionPercent => 'Commission (%)';

  @override
  String get payoutsCommissionSaved => 'Commission saved.';

  @override
  String payoutsRecordedOn(String date) {
    return 'Recorded $date';
  }

  @override
  String get payoutsLoadFailed => 'Couldn\'t load payouts. Please try again.';

  @override
  String get payoutsErrOwnerOnly =>
      'Only the shop owner can manage payouts and commission.';

  @override
  String get payoutsErrNotFound => 'This payout or barber no longer exists.';

  @override
  String get payoutsErrUnknownBarber => 'This barber is not part of your shop.';

  @override
  String payoutsErrInvalidAmount(String max) {
    return 'Enter an amount above 0 and up to $max Birr.';
  }

  @override
  String get payoutsErrInvalidPeriod =>
      'The period must start on or before its end.';

  @override
  String payoutsErrNoteTooLong(int max) {
    return 'Keep the note to $max characters or fewer.';
  }

  @override
  String get payoutsErrInvalidCommission =>
      'Commission must be a whole number from 0 to 100.';

  @override
  String get payoutsErrDeleteWindow =>
      'Payouts can be deleted only within 24 hours of recording them.';

  @override
  String payoutsCarriedOver(String month) {
    return 'Carried over from $month';
  }

  @override
  String get payoutsCarryUnavailable =>
      'Earlier unpaid balances couldn\'t be loaded. Showing this month only.';

  @override
  String get payoutsCarryHint =>
      'Includes unpaid balances from earlier months. Paying part of it leaves the rest for next month.';

  @override
  String get payoutsTotalCarried => 'Carried over';

  @override
  String get earningsTitle => 'Your earnings';

  @override
  String get earningsShopTitle => 'Totals for any period';

  @override
  String get earningsTab => 'Totals';

  @override
  String get earningsThisMonth => 'This month';

  @override
  String get earningsLastMonth => 'Last month';

  @override
  String get earningsPickMonth => 'Pick a month';

  @override
  String get earningsThisYear => 'This year';

  @override
  String get earningsAllTime => 'All time';

  @override
  String get earningsAllTimeNote => 'All completed bookings';

  @override
  String get earningsCompleted => 'Completed jobs';

  @override
  String get earningsRevenue => 'Revenue';

  @override
  String earningsYourShare(int percent) {
    return 'Your share ($percent%)';
  }

  @override
  String get earningsBarbersShare => 'Barbers\' share';

  @override
  String get earningsShopKeeps => 'Shop\'s part';

  @override
  String get earningsByBarber => 'By barber';

  @override
  String earningsBarberJobs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed jobs',
      one: '1 completed job',
    );
    return '$_temp0';
  }

  @override
  String get earningsLoadFailed =>
      'Couldn\'t load the totals. Please try again.';

  @override
  String get earningsShareNote =>
      'Shares use the current commission. Only completed bookings count.';

  @override
  String get applRegisterShopTitle => 'Register your barbershop';

  @override
  String get applRegisterShopSubtitle =>
      'Own a barbershop? Apply to list it on Crown & Blade. We review every application.';

  @override
  String get applCtaApply => 'Apply now';

  @override
  String get applCtaViewStatus => 'View application';

  @override
  String get applFormIntro =>
      'Tell us about your shop. When the admin approves it, this account becomes the shop\'s owner account.';

  @override
  String get applOwnerName => 'Your full name';

  @override
  String get applShopName => 'Barbershop name';

  @override
  String get applAddress => 'Street address';

  @override
  String get applSubCity => 'Sub-city';

  @override
  String get applPhone => 'Shop contact phone';

  @override
  String get applPhoneHint => '09XX XXX XXX or 011 XXX XXXX';

  @override
  String get applDescription => 'About the shop (optional)';

  @override
  String get applSubmit => 'Submit application';

  @override
  String get applSaveChanges => 'Save changes';

  @override
  String get applResubmit => 'Apply again';

  @override
  String get applSubmitted =>
      'Application submitted. We\'ll let you know once it\'s reviewed.';

  @override
  String get applUpdated => 'Application updated.';

  @override
  String get applEdit => 'Edit application';

  @override
  String get applWithdraw => 'Withdraw application';

  @override
  String get applWithdrawTitle => 'Withdraw application?';

  @override
  String applWithdrawBody(String shop) {
    return 'Your application for $shop will be deleted. You can apply again later.';
  }

  @override
  String get applWithdrawn => 'Application withdrawn.';

  @override
  String get applStatusPending => 'Under review';

  @override
  String get applStatusApproved => 'Approved';

  @override
  String get applStatusRejected => 'Not approved';

  @override
  String applPendingBody(String date) {
    return 'We received your application on $date. The admin will review it soon.';
  }

  @override
  String applApprovedBody(String shop) {
    return '$shop is approved! Your account is now the shop\'s owner account.';
  }

  @override
  String get applOpenDashboard => 'Open owner dashboard';

  @override
  String get applRejectedBody => 'Your application was not approved.';

  @override
  String applRejectReasonLine(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get applRejectedHint => 'You can update the details and apply again.';

  @override
  String get applSignUpOwnShop => 'I own a barbershop and want to list it';

  @override
  String get applSignUpOwnShopHint =>
      'After you continue, you can send your shop\'s details for approval.';

  @override
  String get applAdminTitle => 'Shop applications';

  @override
  String applAdminPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending applications',
      one: '1 pending application',
      zero: 'No pending applications',
    );
    return '$_temp0';
  }

  @override
  String get applAdminPending => 'Pending';

  @override
  String get applAdminRecent => 'Recently decided';

  @override
  String get applAdminEmpty => 'No shop applications yet.';

  @override
  String applAdminSubmittedOn(String date) {
    return 'Submitted $date';
  }

  @override
  String applAdminReviewedOn(String date) {
    return 'Reviewed $date';
  }

  @override
  String get applAdminApprove => 'Approve';

  @override
  String get applAdminReject => 'Reject';

  @override
  String applAdminApproveTitle(String shop) {
    return 'Approve $shop?';
  }

  @override
  String applAdminApproveBody(String email) {
    return 'This registers the shop on a free trial with two starter services and invites $email as its owner.';
  }

  @override
  String applAdminApproved(String shop) {
    return '$shop approved and registered.';
  }

  @override
  String applAdminRejectTitle(String shop) {
    return 'Reject $shop?';
  }

  @override
  String get applAdminRejectReason => 'Reason (the applicant sees this)';

  @override
  String get applAdminRejected => 'Application rejected.';

  @override
  String get applLoadFailed => 'Couldn\'t load applications. Please try again.';

  @override
  String get applErrOwnerName => 'Enter your name (up to 100 characters).';

  @override
  String get applErrShopName => 'The shop name must be 2 to 80 characters.';

  @override
  String get applErrAddress => 'The address must be 2 to 160 characters.';

  @override
  String get applErrSubCity => 'Choose a sub-city.';

  @override
  String get applErrPhone =>
      'Enter a valid Ethiopian phone number (09..., 07... or 011...).';

  @override
  String applErrDescriptionTooLong(int max) {
    return 'Keep the description to $max characters or fewer.';
  }

  @override
  String applErrRejectReason(int max) {
    return 'Write a reason of up to $max characters.';
  }

  @override
  String get applErrCustomersOnly =>
      'Only customer accounts can apply to register a barbershop.';

  @override
  String get applErrEmailMissing =>
      'Your account has no email address, which the owner invite needs.';

  @override
  String get applErrAlreadyPending =>
      'You already have an application under review. Edit it instead.';

  @override
  String get applErrAlreadyApproved =>
      'Your application has already been approved.';

  @override
  String get applErrNotPending => 'This application has already been reviewed.';

  @override
  String get applErrNotFound => 'This application no longer exists.';

  @override
  String get applErrAdminOnly =>
      'Only the platform admin can review applications.';

  @override
  String emailErrRateLimitedMinutes(int minutes) {
    return 'Too many attempts. Try again in $minutes min.';
  }

  @override
  String get barberCancelAction => 'Cancel';

  @override
  String get barberCancelTitle => 'Cancel this booking?';

  @override
  String barberCancelBody(String customer, String service, String when) {
    return '$customer will be told that you cancelled their $service on $when. This can\'t be undone.';
  }

  @override
  String get barberCancelReasonLabel => 'Reason (optional)';

  @override
  String get barberCancelReasonHint => 'e.g. I\'m unwell today';

  @override
  String get barberCancelConfirm => 'Cancel booking';

  @override
  String get barberCancelKeep => 'Keep booking';

  @override
  String get barberCancelDone =>
      'Booking cancelled. The customer has been notified.';

  @override
  String barberCancelFailed(String error) {
    return 'Couldn\'t cancel the booking: $error';
  }

  @override
  String get barberCancelErrNotAllowed =>
      'You can only cancel your own bookings.';

  @override
  String get barberCancelErrAfterStart =>
      'This appointment has already started. Mark it as a no-show or finish it instead.';

  @override
  String get changePasswordMenu => 'Change password';

  @override
  String get setPasswordMenu => 'Set a password';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordIntro =>
      'Enter your current password, then choose a new one.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get changePasswordSave => 'Update password';

  @override
  String get changePasswordDone => 'Your password has been changed.';

  @override
  String get changePasswordErrWrongCurrent =>
      'Your current password is not correct.';

  @override
  String get changePasswordErrCurrentRequired => 'Enter your current password.';

  @override
  String get changePasswordErrRecentLogin =>
      'For your security, sign out and sign in again, then change your password.';

  @override
  String get changePasswordErrNoPassword =>
      'This account signs in with Google and has no password yet.';

  @override
  String get setPasswordTitle => 'Set a password';

  @override
  String setPasswordBody(String email) {
    return 'You sign in with Google, so this account has no password yet. To create one, sign out, tap \"Forgot password?\" on the login screen and enter $email. We\'ll email you a code, then you choose your password.';
  }

  @override
  String get setPasswordSignOutAction => 'Sign out and set a password';

  @override
  String get setPasswordConfirmTitle => 'Sign out now?';

  @override
  String get setPasswordConfirmBody =>
      'You\'ll go to the login screen with \"Forgot password?\" open for your Gmail.';

  @override
  String get barberInviteHelper =>
      'We\'ll email them an invitation. They open Crown & Blade, tap Register and use this Gmail to create their password.';

  @override
  String get barberInviteWaiting => 'Invitation sent — waiting for sign-up';

  @override
  String get staffAcctSheetTitle => 'Add a barber';

  @override
  String get staffAcctSheetIntro =>
      'Create a login for your barber. They log in with this email and the temporary password, then choose their own password.';

  @override
  String get staffAcctEmailLabel => 'Login email';

  @override
  String get staffAcctNameRequired => 'Enter the barber\'s name';

  @override
  String get staffAcctEmailRequired =>
      'Enter the email the barber will log in with';

  @override
  String get staffAcctTempPasswordLabel => 'Temporary password';

  @override
  String get staffAcctTempPasswordHelper =>
      '8 to 128 characters with a letter and a number. The barber changes it at first login.';

  @override
  String get staffAcctRegenerate => 'Generate a new password';

  @override
  String get staffAcctCopyPassword => 'Copy password';

  @override
  String get staffAcctCopied => 'Copied';

  @override
  String get staffAcctCreate => 'Create account';

  @override
  String get staffAcctInviteSectionTitle =>
      'Already has a Crown & Blade account?';

  @override
  String get staffAcctInviteInstead => 'Invite by email instead';

  @override
  String get staffAcctEmailInUseTitle => 'This email already has an account';

  @override
  String staffAcctEmailInUseBody(String email) {
    return '$email is already registered, so we can\'t create a new login for it. Send an invitation instead: they log in with their own password or Google and join your shop as a barber.';
  }

  @override
  String get staffAcctSendInvite => 'Send invitation instead';

  @override
  String staffAcctInviteSaved(String email) {
    return 'Invitation saved. $email becomes a barber at your shop at their next login.';
  }

  @override
  String get staffAcctCreatedTitle => 'Barber account created';

  @override
  String staffAcctCreatedBody(String name) {
    return 'Give these details to $name. They log in with this email and password, then choose their own password.';
  }

  @override
  String get staffAcctEmailField => 'Email';

  @override
  String get staffAcctShownOnce =>
      'The temporary password is shown only now. Copy it or write it down before closing.';

  @override
  String get staffAcctCopyDetails => 'Copy login details';

  @override
  String get staffAcctDetailsHeading => 'Crown & Blade barber login';

  @override
  String get staffAcctDetailsFooter =>
      'After logging in, choose your own password.';

  @override
  String get staffAcctWaitingFirstLogin => 'Waiting for first login';

  @override
  String get staffAcctActive => 'Active';

  @override
  String get staffAcctLostPasswordHint =>
      'Lost the temporary password? They can tap \"Forgot password?\" on the login screen to reset it by email.';

  @override
  String get staffAcctForceTitle => 'Choose your new password';

  @override
  String get staffAcctForceIntro =>
      'You logged in with a temporary password from your barbershop. Choose your own password to continue.';

  @override
  String get staffAcctForceTempLabel => 'Temporary password';

  @override
  String get staffAcctForceTempRequired =>
      'Enter the temporary password you received';

  @override
  String get staffAcctForceWrongTemp =>
      'The temporary password is not correct.';

  @override
  String get staffAcctForceSameAsTemp =>
      'Choose a password different from the temporary one.';

  @override
  String get staffAcctForceSave => 'Save and continue';

  @override
  String get staffAcctForceDone => 'Password saved. Welcome!';

  @override
  String get authContinue => 'Continue';

  @override
  String get registerLinkIntro =>
      'Enter your email. Next you\'ll create a password, and we\'ll email you a link to verify the address.';

  @override
  String registerLinkPasswordIntro(String email) {
    return 'You\'ll log in with $email. After you create your account, we\'ll email you a verification link.';
  }

  @override
  String get verifyLinkSentTitle => 'Verify your email';

  @override
  String verifyLinkSentBody(String email) {
    return 'We sent a verification link to $email. Open it, then come back and log in.';
  }

  @override
  String get verifyLinkNotSent =>
      'Your account was created, but we couldn\'t send the verification link. Tap \"Resend link\" to try again.';

  @override
  String get verifiedLogIn => 'I\'ve verified — Log in';

  @override
  String get resendLink => 'Resend link';

  @override
  String resendLinkIn(int seconds) {
    return 'Resend link in $seconds s';
  }

  @override
  String linkResent(String email) {
    return 'We sent a new link to $email.';
  }

  @override
  String get resetLinkIntro =>
      'Enter your account email and we\'ll send you a link to choose a new password.';

  @override
  String get sendLink => 'Send link';

  @override
  String get resetLinkSentTitle => 'Check your email';

  @override
  String resetLinkSentBody(String email) {
    return 'We sent a password reset link to $email. Open it, choose a new password, then log in here.';
  }

  @override
  String get emailErrNotVerified => 'Please verify your email first.';

  @override
  String get resendVerificationLink => 'Resend verification link';

  @override
  String get emailAlreadyVerified =>
      'Your email is already verified. Log in again.';

  @override
  String ratingShopSummary(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count barbers rated',
      one: '1 barber rated',
    );
    return '$rating · $_temp0';
  }

  @override
  String ratingBarbersRated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count barbers rated',
      one: '1 barber rated',
    );
    return '$_temp0';
  }

  @override
  String ratingSeeBarberReviews(String name) {
    return 'See $name\'s reviews';
  }

  @override
  String get reviewsByBarber => 'Reviews by barber';

  @override
  String get ratePromptTitle => 'How was your cut?';

  @override
  String ratePromptBody(String barber, String service, String shop) {
    return 'Rate $barber for your $service at $shop.';
  }

  @override
  String get ratePromptDismiss => 'Not now';

  @override
  String get admPayTab => 'Payments';

  @override
  String get admPayIncomeLabel => 'Subscription income';

  @override
  String get admPayThisMonth => 'This month';

  @override
  String admPayVerifiedCount(int count) {
    return '$count verified';
  }

  @override
  String admPayPendingCount(int count) {
    return '$count waiting';
  }

  @override
  String admPayRejectedCount(int count) {
    return '$count rejected';
  }

  @override
  String get admPayShopsActive => 'Active';

  @override
  String get admPayShopsTrial => 'Trial';

  @override
  String get admPayShopsPastDue => 'Past due';

  @override
  String get admPayShopsSuspended => 'Suspended';

  @override
  String get admPayManage => 'Manage payments';

  @override
  String get admPayNoPending => 'Nothing waiting for review';

  @override
  String get admPayTypesTitle => 'Subscription types & prices';

  @override
  String get admPayTypesSubtitle =>
      'Add, remove or change lengths and prices, and where owners pay';

  @override
  String get admPaySubscriptionsSubtitle =>
      'Each shop\'s plan, status and end date';

  @override
  String get admPayOnlineTitle => 'Online payments';

  @override
  String get admPayOnlineSubtitle =>
      'Card and Chapa payments that need a decision';

  @override
  String get admPayTypesOnSale => 'Subscription types on sale';

  @override
  String get admPayEdit => 'Edit';

  @override
  String get refundsDueTitle => 'Refunds due';

  @override
  String refundsDueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count refunds waiting',
      one: '1 refund waiting',
    );
    return '$_temp0';
  }

  @override
  String get refundsEmpty =>
      'No refunds due. When a paid booking is cancelled, the money owed to the customer shows up here.';

  @override
  String refundBadgeDue(String amount) {
    return 'Refund due · $amount';
  }

  @override
  String get refundBadgeRefunded => 'Refunded';

  @override
  String get refundMarkButton => 'Mark refunded';

  @override
  String get refundMarkTitle => 'Mark the refund as sent';

  @override
  String refundMarkBody(String amount, String customer) {
    return 'Confirm that you sent $amount back to $customer.';
  }

  @override
  String get refundMethodLabel => 'How was it refunded?';

  @override
  String refundMethodName(String method) {
    String _temp0 = intl.Intl.selectLogic(
      method,
      {
        'telebirr': 'telebirr',
        'cbe': 'CBE Birr',
        'bank': 'Bank transfer',
        'cash': 'Cash',
        'chapa': 'Chapa',
        'other': 'Other',
      },
    );
    return '$_temp0';
  }

  @override
  String get refundReferenceLabel => 'Reference (optional)';

  @override
  String get refundReferenceHint => 'Transaction ID or a short note';

  @override
  String get refundMarkedSnack =>
      'Marked as refunded. The customer was notified.';

  @override
  String refundReasonName(String reason) {
    String _temp0 = intl.Intl.selectLogic(
      reason,
      {
        'customer_cancelled': 'Customer cancelled',
        'customer_late_cancel': 'Customer cancelled late (partial refund)',
        'barber_cancelled': 'Barber cancelled',
        'shop_cancelled': 'Shop cancelled',
        'admin_cancelled': 'Cancelled by the platform',
        'request_declined': 'Request declined',
        'request_expired': 'Request expired',
        'shop_deleted': 'Shop removed',
        'other': 'Cancelled',
      },
    );
    return '$_temp0';
  }

  @override
  String refundFlaggedOn(String date) {
    return 'Cancelled $date';
  }

  @override
  String get admPayReceiversMissing =>
      'Add your telebirr number or CBE account so owners know where to pay.';

  @override
  String admPayExpiringTitle(int count) {
    return 'Ending within 7 days ($count)';
  }

  @override
  String admPayDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Ends today',
    );
    return '$_temp0';
  }

  @override
  String get admPayRecentTitle => 'Latest payments';

  @override
  String get admPaySeeAll => 'See all';

  @override
  String get admPayNoPayments => 'No payments yet.';

  @override
  String get errAccountDisabled =>
      'Your account has been disabled. Contact support.';

  @override
  String get admUsrSearchHint => 'Search by name, email or phone';

  @override
  String admUsrFilterAll(int count) {
    return 'All ($count)';
  }

  @override
  String admUsrFilterCustomers(int count) {
    return 'Customers ($count)';
  }

  @override
  String admUsrFilterOwners(int count) {
    return 'Owners ($count)';
  }

  @override
  String admUsrFilterBarbers(int count) {
    return 'Barbers ($count)';
  }

  @override
  String admUsrFilterAdmins(int count) {
    return 'Admins ($count)';
  }

  @override
  String admUsrFilterDisabled(int count) {
    return 'Disabled ($count)';
  }

  @override
  String get admUsrEmpty => 'No users match your search.';

  @override
  String get admUsrDisabledChip => 'Disabled';

  @override
  String get admUsrYouChip => 'You';

  @override
  String get admUsrEditTitle => 'Edit user';

  @override
  String get admUsrEmailLabel => 'Email';

  @override
  String get admUsrPhoneLabel => 'Phone';

  @override
  String admUsrJoined(String date) {
    return 'Joined $date';
  }

  @override
  String get admUsrRoleSection => 'Role';

  @override
  String get admUsrShopLabel => 'Barbershop';

  @override
  String get admUsrPickShop => 'Choose a barbershop';

  @override
  String get admUsrBarberProfileLabel => 'Barber profile';

  @override
  String get admUsrNewBarberProfile => 'Create a new barber profile';

  @override
  String get admUsrSaveRole => 'Change role';

  @override
  String get admUsrSelfNote =>
      'This is your own account. You cannot change your own role or disable yourself.';

  @override
  String admUsrRoleAtShop(String role, String shop) {
    return '$role at $shop';
  }

  @override
  String get admUsrConfirmRoleTitle => 'Change role?';

  @override
  String admUsrConfirmRoleBody(String name, String role) {
    return '$name will become: $role.';
  }

  @override
  String admUsrEffectNewBarber(String shop) {
    return 'A new barber profile is created in $shop.';
  }

  @override
  String admUsrEffectUnlinkBarber(String barber) {
    return 'Their barber profile \"$barber\" stays in the shop for its history but stops taking bookings.';
  }

  @override
  String admUsrEffectReleaseShop(String shop) {
    return '$shop will have no owner until you assign one.';
  }

  @override
  String admUsrEffectPreviousOwner(String name, String shop) {
    return '$name owns $shop now and becomes a customer.';
  }

  @override
  String admUsrEffectInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending invites are cancelled.',
      one: '1 pending invite is cancelled.',
    );
    return '$_temp0';
  }

  @override
  String get admUsrRoleChanged => 'Role changed.';

  @override
  String get admUsrAccountSection => 'Account';

  @override
  String get admUsrActive => 'Active. This person can sign in.';

  @override
  String admUsrDisabledOn(String date) {
    return 'Disabled on $date';
  }

  @override
  String admUsrDisabledReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get admUsrDisable => 'Disable account';

  @override
  String get admUsrEnable => 'Enable account';

  @override
  String admUsrDisableTitle(String name) {
    return 'Disable $name?';
  }

  @override
  String get admUsrDisableBody =>
      'They are signed out right away and cannot sign in until you enable the account again.';

  @override
  String get admUsrReasonLabel => 'Reason (optional)';

  @override
  String get admUsrCancelBookings => 'Also cancel their upcoming bookings';

  @override
  String admUsrUpcomingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upcoming bookings',
      one: '1 upcoming booking',
      zero: 'No upcoming bookings',
    );
    return '$_temp0';
  }

  @override
  String get admUsrUpcomingUnknown => 'Upcoming bookings could not be counted.';

  @override
  String get admUsrBookingsStay =>
      'Their upcoming bookings stay unless you tick the box.';

  @override
  String admUsrDisabledSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Account disabled. $count bookings cancelled.',
      one: 'Account disabled. 1 booking cancelled.',
      zero: 'Account disabled.',
    );
    return '$_temp0';
  }

  @override
  String admUsrEnableTitle(String name) {
    return 'Enable $name?';
  }

  @override
  String get admUsrEnableBody => 'They can sign in again.';

  @override
  String get admUsrEnabledSnack => 'Account enabled.';

  @override
  String get admUsrErrNotAdmin => 'Only admins can manage users.';

  @override
  String get admUsrErrNotFound => 'This user no longer exists.';

  @override
  String get admUsrErrSelf =>
      'You cannot change your own role or disable your own account.';

  @override
  String get admUsrErrLastAdmin =>
      'The platform needs at least one active admin.';

  @override
  String get admUsrErrShopRequired => 'Choose a barbershop.';

  @override
  String get admUsrErrShopNotFound =>
      'That barbershop or barber profile no longer exists.';

  @override
  String get admUsrErrBarberTaken =>
      'That barber profile already belongs to another account.';

  @override
  String get admUsrErrNoChange => 'Nothing to change.';

  @override
  String admUsrErrReasonTooLong(int max) {
    return 'The reason can be at most $max characters.';
  }

  @override
  String get nearbyLandmark => 'Nearby landmark';

  @override
  String get nearbyLandmarkHint => 'e.g. Near Edna Mall';

  @override
  String get nearbyLandmarkHelper =>
      'Most customers find shops by landmark. It is shown big on your shop page.';

  @override
  String get shopMapPinTitle => 'Map pin';

  @override
  String get shopMapPinHelp =>
      'Tap the map to place the shop\'s pin, or use your current location while you are at the shop.';

  @override
  String get useMyCurrentLocation => 'Use my current location';

  @override
  String get findingYourLocation => 'Finding your location...';

  @override
  String get removeMapPin => 'Remove pin';

  @override
  String get noMapPinYet =>
      'No pin yet. Directions will search for the address and landmark instead.';

  @override
  String mapPinCoordinates(String latitude, String longitude) {
    return 'Pin: $latitude, $longitude';
  }

  @override
  String get mapPinOutsideEthiopia =>
      'This pin is outside Ethiopia. Check it before saving.';

  @override
  String get locationServiceOff =>
      'Location is turned off. Turn it on in your phone settings and try again.';

  @override
  String get locationPermissionDenied =>
      'Location permission was not given. You can still tap the map to place the pin.';

  @override
  String get locationPermissionBlocked =>
      'Location is blocked for Crown & Blade. Allow it in Settings.';

  @override
  String get locationUnavailable =>
      'Could not get your location. Try again, or tap the map.';

  @override
  String get openSettingsAction => 'Settings';

  @override
  String get shopDirections => 'Directions';

  @override
  String get shopDirectionsFailed => 'Could not open a maps app.';

  @override
  String get shopLandmarkLabel => 'Landmark';

  @override
  String get nearMe => 'Near me';

  @override
  String get nearMeNeedsLocation => 'Allow location to sort shops by distance.';

  @override
  String distanceKmAway(String km) {
    return '$km km away';
  }

  @override
  String distanceMetersAway(int meters) {
    return '$meters m away';
  }

  @override
  String get shopMapSemantics => 'Map showing the shop\'s location';
}
