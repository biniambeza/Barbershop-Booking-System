/// Public pages Google Play (and the App Store) ask for: the privacy policy
/// and the "how to delete your account" page. Both are static files in
/// web/ (privacy.html, delete-account.html) that the Flutter web build
/// copies to build/web, so the GitHub Pages deploy publishes them next to
/// the app. Keep [kPrivacyContactEmail] in sync with those two files.
library;

/// The GitHub Pages site the deploy workflow publishes (see readme).
const String kPagesBaseUrl = 'https://biniambeza.github.io/Barbershop-Booking-System';

/// The privacy policy (English and Amharic on one page).
const String kPrivacyPolicyUrl = '$kPagesBaseUrl/privacy.html';

/// How to delete an account and its data (Play's "delete account URL").
const String kDeleteAccountUrl = '$kPagesBaseUrl/delete-account.html';

/// Where people send privacy questions and deletion requests.
/// PLACEHOLDER: replace with the real support address here and in
/// web/privacy.html and web/delete-account.html before publishing.
const String kPrivacyContactEmail = 'privacy@example.com';

/// "Last updated" date shown in the app and on the web page.
const String kPrivacyPolicyUpdated = '2026-11-16';
