/// The privacy policy bundled in the app (English and Amharic), shown when
/// the web page (web/privacy.html, kPrivacyPolicyUrl) cannot be opened.
/// Keep the two in sync: test/privacy_and_account_deletion_widget_test.dart
/// checks that every section title below is on the web page too.
library;

import '../../core/config/legal_links.dart';

class PolicySection {
  const PolicySection(this.title, this.body);

  final String title;

  /// Paragraphs separated by blank lines; lines starting with "• " are
  /// bullet points.
  final String body;
}

/// The policy in [languageCode] ('am' = Amharic, anything else English).
List<PolicySection> privacyPolicySections(String languageCode) =>
    languageCode == 'am' ? kPrivacyPolicyAm : kPrivacyPolicyEn;

const List<PolicySection> kPrivacyPolicyEn = [
  PolicySection(
    'Who we are',
    'Crown & Blade is an app for booking barbershops in Addis Ababa. Customers book and pay for haircuts; '
        'shop owners and barbers manage their shop, bookings and walk-in queue. This policy explains what '
        'information the app collects, why, who can see it, how long it is kept and how to delete it.\n\n'
        'Questions: $kPrivacyContactEmail',
  ),
  PolicySection(
    'What we collect',
    '• Account: your name, email address, contact phone number, app language and role (customer, barber, '
        'shop owner or admin). If you sign in with Google we receive your Google email and name.\n'
        '• Bookings: the shop, barber, service, date and time, price, status, and reasons you or the shop give '
        'when a booking is cancelled or declined.\n'
        '• Reviews: the stars and the comment you write. Only your first name is shown with a review.\n'
        '• Payments: payment status and payment references (for example a Chapa reference, or the telebirr or '
        'CBE transaction number a shop owner enters for a subscription). We never see your card or wallet PIN.\n'
        '• Receipt photos: shop owners who pay a subscription by transfer may upload a photo of the receipt.\n'
        '• Location: only when a shop owner places the shop pin on the map (the shop location is public), or '
        'when you tap "Near me" to sort shops by distance. Your own location is used on your phone to work out '
        'distances and is not saved on our servers.\n'
        '• Walk-in queue: the name and phone number used to join a shop\'s queue.\n'
        '• Portfolio photos: barbers and shop owners may upload photos of haircuts the barber has done (up to 12 '
        'per barber, with an optional style name). These photos are public in the app and on the barber\'s '
        'profile.\n'
        '• Device: a notification token so we can send booking reminders, crash reports (Firebase Crashlytics: '
        'device model, system and app version and what went wrong, no names or messages), and App Check '
        'signals (Play Integrity, App Attest or reCAPTCHA) that tell us the request comes from the real app.\n'
        '• Favourites are kept on your device only.',
  ),
  PolicySection(
    'How we use it',
    '• To make, change and cancel bookings and show them to the shop and barber you booked.\n'
        '• To send reminders and updates in the app, by push notification and by SMS.\n'
        '• To take payments, flag and record refunds, and check shop subscription receipts.\n'
        '• To keep the service safe (stop abuse and fake requests) and to fix crashes.\n'
        'We do not sell your information and we do not show ads.',
  ),
  PolicySection(
    'Who can see it',
    '• The shop and barber you book see your name, phone number and booking.\n'
        '• Shop profiles, barber profiles and reviews (with the reviewer\'s first name) are public in the app.\n'
        '• Portfolio photos of haircuts are public. A barber must ask the customer before taking or uploading a '
        'photo in which the customer can be recognised, and removes it when the customer asks (the barber or '
        'the shop owner can delete any photo in the app, or email $kPrivacyContactEmail and we remove it).\n'
        '• A shop\'s address, nearby landmark and map pin are public so customers can find it.\n'
        '• A barber\'s private phone is shown only to their own customers with a confirmed booking.\n'
        '• Crown & Blade administrators can see accounts and shops to run the service; they do not see '
        'customers\' bookings lists.',
  ),
  PolicySection(
    'Services we use',
    'Google Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Functions, Cloud Messaging, '
        'Crashlytics and App Check) stores and processes the data on Google Cloud servers, which may be outside '
        'Ethiopia. Online payments go through Chapa, SMS messages through AfroMessage, and sign-up codes are '
        'sent by email. Google sign-in is provided by Google. These providers process data only to provide '
        'their service to us.',
  ),
  PolicySection(
    'How long we keep it',
    '• Your account information is kept while your account exists.\n'
        '• Bookings are the shop\'s business records. When you delete your account they stay without your name '
        'and phone ("Former customer"). If a refund is still owed to you, the phone number stays on that booking '
        'until the shop has paid it back.\n'
        '• Reviews: the stars stay as "Former customer"; your comment is deleted.\n'
        '• Payment, refund and subscription records are kept as long as needed for accounting and the law.\n'
        '• Crash reports are deleted by Crashlytics after 90 days.',
  ),
  PolicySection(
    'Deleting your account',
    'In the app: open the menu (⋮) and tap "Delete account". You type DELETE and sign in again; the app '
        'cancels your upcoming bookings (paid ones are flagged for a refund), anonymises your reviews and '
        'bookings, deletes your profile, inbox and invitations, and then your login.\n\n'
        '• A barber is also removed from their shop, with their portfolio photos.\n'
        '• A shop owner first asks us to remove the shop (the app sends the request), then deletes the account.\n\n'
        'Without the app: see $kDeleteAccountUrl or email $kPrivacyContactEmail from the address you sign in '
        'with. We reply within 30 days.',
  ),
  PolicySection(
    'Your choices',
    '• Change your name, phone number and language in the app at any time.\n'
        '• Location is optional: you can refuse the permission and still use the app.\n'
        '• You can turn notifications off in your phone settings.',
  ),
  PolicySection(
    'Children',
    'Crown & Blade is not meant for children under 13, and we do not knowingly collect their information.',
  ),
  PolicySection(
    'Security',
    'Data is sent over encrypted connections. Access is limited by security rules: each person reads only '
        'what their role allows. No system is perfectly secure; tell us at once if you notice a problem.',
  ),
  PolicySection(
    'Changes and contact',
    'We will update this page when the app changes what it collects, and show the date below.\n\n'
        'Email: $kPrivacyContactEmail\nLast updated: $kPrivacyPolicyUpdated',
  ),
];

const List<PolicySection> kPrivacyPolicyAm = [
  PolicySection(
    'እኛ ማን ነን',
    'Crown & Blade በአዲስ አበባ የፀጉር ቤት ቀጠሮ ለመያዝ የሚያገለግል መተግበሪያ ነው። ደንበኞች ቀጠሮ ይይዛሉ፣ ይከፍላሉ፤ '
        'የፀጉር ቤት ባለቤቶችና ፀጉር አስተካካዮች ፀጉር ቤታቸውን፣ ቀጠሮዎችንና ወረፋውን ያስተዳድራሉ። ይህ መመሪያ መተግበሪያው '
        'ምን መረጃ እንደሚሰበስብ፣ ለምን፣ ማን እንደሚያየው፣ ለምን ያህል ጊዜ እንደሚቀመጥና እንዴት እንደሚሰረዝ ያብራራል።\n\n'
        'ጥያቄ ካለዎት፦ $kPrivacyContactEmail',
  ),
  PolicySection(
    'የምንሰበስበው መረጃ',
    '• መለያ፦ ስምዎ፣ ኢሜይልዎ፣ የመገናኛ ስልክ ቁጥርዎ፣ የመተግበሪያ ቋንቋ እና ሚናዎ (ደንበኛ፣ ፀጉር አስተካካይ፣ '
        'የፀጉር ቤት ባለቤት ወይም አስተዳዳሪ)። በGoogle ከገቡ የGoogle ኢሜይልዎንና ስምዎን እንቀበላለን።\n'
        '• ቀጠሮዎች፦ ፀጉር ቤቱ፣ ፀጉር አስተካካዩ፣ አገልግሎቱ፣ ቀንና ሰዓቱ፣ ዋጋው፣ ሁኔታው እና ቀጠሮ ሲሰረዝ ወይም ውድቅ ሲደረግ '
        'የሚሰጡ ምክንያቶች።\n'
        '• ግምገማዎች፦ የሚሰጡት ኮከብና አስተያየት። ከግምገማው ጋር የሚታየው የመጀመሪያ ስምዎ ብቻ ነው።\n'
        '• ክፍያዎች፦ የክፍያ ሁኔታና የክፍያ ማጣቀሻዎች (ለምሳሌ የChapa ማጣቀሻ ወይም የፀጉር ቤት ባለቤት ለደንበኝነት '
        'የሚያስገባው የቴሌብር ወይም የCBE የግብይት ቁጥር)። የካርድዎን ወይም የኪስ ቦርሳዎን ሚስጥር ቁጥር አናይም።\n'
        '• የደረሰኝ ፎቶዎች፦ ደንበኝነትን በዝውውር የሚከፍሉ የፀጉር ቤት ባለቤቶች የደረሰኙን ፎቶ ሊጭኑ ይችላሉ።\n'
        '• አካባቢ፦ የፀጉር ቤት ባለቤት የፀጉር ቤቱን ቦታ በካርታ ላይ ሲያስቀምጥ (የፀጉር ቤቱ ቦታ ለሁሉም ይታያል) ወይም '
        'ፀጉር ቤቶችን በርቀት ለመደርደር "በአቅራቢያዬ"ን ሲጫኑ ብቻ። የእርስዎ አካባቢ ርቀትን ለማስላት በስልክዎ ላይ ብቻ '
        'ይጠቅማል፤ በአገልጋዮቻችን ላይ አይቀመጥም።\n'
        '• የወረፋ ዝርዝር፦ ወረፋ ለመቀላቀል የሚጠቀሙበት ስምና ስልክ ቁጥር።\n'
        '• የሥራ ፎቶዎች፦ ፀጉር አስተካካዮችና የፀጉር ቤት ባለቤቶች ፀጉር አስተካካዩ የሠራቸውን የፀጉር ቁርጦች ፎቶዎች ሊጭኑ ይችላሉ '
        '(ለእያንዳንዱ ፀጉር አስተካካይ እስከ 12፣ ከአማራጭ የስታይል ስም ጋር)። እነዚህ ፎቶዎች በመተግበሪያውና በፀጉር አስተካካዩ '
        'መገለጫ ላይ ለሁሉም ይታያሉ።\n'
        '• መሣሪያ፦ የቀጠሮ ማስታወሻ ለመላክ የማሳወቂያ መለያ፣ የብልሽት ሪፖርቶች (Firebase Crashlytics፦ የስልኩ ዓይነት፣ '
        'የሲስተምና የመተግበሪያ ስሪት እና የተፈጠረው ስህተት፤ ስም ወይም መልዕክት አያካትትም) እና ጥያቄው ከእውነተኛው '
        'መተግበሪያ መምጣቱን የሚያረጋግጡ የApp Check ምልክቶች (Play Integrity፣ App Attest ወይም reCAPTCHA)።\n'
        '• ተወዳጆች በስልክዎ ላይ ብቻ ይቀመጣሉ።',
  ),
  PolicySection(
    'መረጃውን እንዴት እንጠቀምበታለን',
    '• ቀጠሮ ለመያዝ፣ ለመቀየርና ለመሰረዝ እንዲሁም ቀጠሮውን ለያዙት ፀጉር ቤትና ፀጉር አስተካካይ ለማሳየት።\n'
        '• ማስታወሻዎችንና ዝማኔዎችን በመተግበሪያው፣ በማሳወቂያና በኤስኤምኤስ ለመላክ።\n'
        '• ክፍያ ለመቀበል፣ ተመላሽ ገንዘብን ለመመዝገብና የደንበኝነት ደረሰኞችን ለማረጋገጥ።\n'
        '• አገልግሎቱን ከአላግባብ አጠቃቀም ለመጠበቅና ብልሽቶችን ለማስተካከል።\n'
        'መረጃዎን አንሸጥም፤ ማስታወቂያም አናሳይም።',
  ),
  PolicySection(
    'መረጃውን ማን ያያል',
    '• ቀጠሮ የያዙበት ፀጉር ቤትና ፀጉር አስተካካይ ስምዎን፣ ስልክ ቁጥርዎንና ቀጠሮዎን ያያሉ።\n'
        '• የፀጉር ቤቶችና የፀጉር አስተካካዮች መገለጫዎች እንዲሁም ግምገማዎች (ከገምጋሚው የመጀመሪያ ስም ጋር) በመተግበሪያው '
        'ለሁሉም ይታያሉ።\n'
        '• የፀጉር ቁርጥ የሥራ ፎቶዎች ለሁሉም ይታያሉ። ፀጉር አስተካካዩ ደንበኛው የሚታወቅበትን ፎቶ ከማንሳቱ ወይም ከመጫኑ በፊት '
        'ደንበኛውን መጠየቅ አለበት፤ ደንበኛው ሲጠይቅም ያነሳዋል (ፀጉር አስተካካዩ ወይም የፀጉር ቤቱ ባለቤት ማንኛውንም ፎቶ በመተግበሪያው '
        'መሰረዝ ይችላሉ፤ ወይም ወደ $kPrivacyContactEmail ይጻፉ፣ እኛ እናነሳዋለን)።\n'
        '• ደንበኞች እንዲያገኙት የፀጉር ቤቱ አድራሻ፣ አቅራቢያ ያለው ምልክት እና በካርታ ላይ ያለው ቦታ ለሁሉም ይታያሉ።\n'
        '• የፀጉር አስተካካይ የግል ስልክ የሚታየው የተረጋገጠ ቀጠሮ ላላቸው ደንበኞቻቸው ብቻ ነው።\n'
        '• የCrown & Blade አስተዳዳሪዎች አገልግሎቱን ለማስኬድ መለያዎችንና ፀጉር ቤቶችን ያያሉ፤ የደንበኞችን የቀጠሮ ዝርዝር '
        'አያዩም።',
  ),
  PolicySection(
    'የምንጠቀምባቸው አገልግሎቶች',
    'Google Firebase (Authentication፣ Cloud Firestore፣ Cloud Storage፣ Cloud Functions፣ Cloud Messaging፣ '
        'Crashlytics እና App Check) መረጃውን ከኢትዮጵያ ውጭ ሊሆኑ በሚችሉ የGoogle Cloud አገልጋዮች ላይ ያስቀምጣል፣ '
        'ያስኬዳል። የመስመር ላይ ክፍያ በChapa፣ ኤስኤምኤስ በAfroMessage ይላካል፤ የምዝገባ ኮዶች በኢሜይል ይላካሉ። '
        'በGoogle መግባትን Google ያቀርባል። እነዚህ አቅራቢዎች መረጃውን የሚያስኬዱት አገልግሎታቸውን ለእኛ ለመስጠት ብቻ ነው።',
  ),
  PolicySection(
    'መረጃውን ለምን ያህል ጊዜ እናስቀምጣለን',
    '• የመለያዎ መረጃ መለያዎ እስካለ ድረስ ይቀመጣል።\n'
        '• ቀጠሮዎች የፀጉር ቤቱ የሥራ መዝገቦች ናቸው። መለያዎን ሲሰርዙ ያለ ስምዎና ስልክዎ ("የቀድሞ ደንበኛ") ይቀራሉ። '
        'ገና ያልተመለሰልዎ ገንዘብ ካለ ፀጉር ቤቱ እስኪመልስልዎ ድረስ ስልክ ቁጥርዎ በዚያ ቀጠሮ ላይ ይቆያል።\n'
        '• ግምገማዎች፦ ኮከቦቹ "የቀድሞ ደንበኛ" በሚል ይቀራሉ፤ አስተያየትዎ ይሰረዛል።\n'
        '• የክፍያ፣ የተመላሽ ገንዘብና የደንበኝነት መዝገቦች ለሂሳብና ለሕግ በሚያስፈልገው ጊዜ ይቀመጣሉ።\n'
        '• የብልሽት ሪፖርቶችን Crashlytics ከ90 ቀን በኋላ ይሰርዛቸዋል።',
  ),
  PolicySection(
    'መለያዎን መሰረዝ',
    'በመተግበሪያው፦ ምናሌውን (⋮) ከፍተው "መለያ ሰርዝ"ን ይጫኑ። DELETE ብለው ይጽፋሉ፣ እንደገና ይገባሉ፤ መተግበሪያው '
        'መጪ ቀጠሮዎችዎን ይሰርዛል (የተከፈለባቸው ለተመላሽ ገንዘብ ይመዘገባሉ)፣ ግምገማዎችዎንና ቀጠሮዎችዎን ስም-አልባ ያደርጋል፣ '
        'መገለጫዎን፣ የመልዕክት ሳጥንዎንና ግብዣዎችዎን ይሰርዛል፤ በመጨረሻም መግቢያዎን ይሰርዛል።\n\n'
        '• ፀጉር አስተካካይ ከሥራ ፎቶዎቹ ጋር ከፀጉር ቤቱም ይወገዳል።\n'
        '• የፀጉር ቤት ባለቤት መጀመሪያ ፀጉር ቤቱን እንድናስወግድ ይጠይቃል (መተግበሪያው ጥያቄውን ይልካል)፤ ከዚያ መለያውን ይሰርዛል።\n\n'
        'ያለ መተግበሪያው፦ $kDeleteAccountUrl ይመልከቱ ወይም በሚገቡበት ኢሜይል ወደ $kPrivacyContactEmail ይጻፉ። '
        'በ30 ቀን ውስጥ እንመልሳለን።',
  ),
  PolicySection(
    'የእርስዎ ምርጫዎች',
    '• ስምዎን፣ ስልክ ቁጥርዎንና ቋንቋዎን በማንኛውም ጊዜ በመተግበሪያው መቀየር ይችላሉ።\n'
        '• አካባቢ አማራጭ ነው፦ ፈቃዱን ከልክለው መተግበሪያውን መጠቀም ይችላሉ።\n'
        '• ማሳወቂያዎችን በስልክዎ ቅንብሮች ማጥፋት ይችላሉ።',
  ),
  PolicySection(
    'ልጆች',
    'Crown & Blade ከ13 ዓመት በታች ለሆኑ ልጆች የታሰበ አይደለም፤ የእነሱን መረጃ አውቀን አንሰበስብም።',
  ),
  PolicySection(
    'ደህንነት',
    'መረጃ የሚላከው በተመሰጠሩ ግንኙነቶች ነው። እያንዳንዱ ሰው ሚናው የሚፈቅድለትን ብቻ እንዲያነብ የደህንነት ደንቦች '
        'ይገድባሉ። ፍጹም ደህንነቱ የተጠበቀ ሥርዓት የለም፤ ችግር ካዩ ወዲያውኑ ያሳውቁን።',
  ),
  PolicySection(
    'ለውጦችና መገኛ',
    'መተግበሪያው የሚሰበስበውን ሲቀይር ይህን ገጽ እናዘምናለን፤ ቀኑን ከታች እናሳያለን።\n\n'
        'ኢሜይል፦ $kPrivacyContactEmail\nመጨረሻ የተዘመነው፦ $kPrivacyPolicyUpdated',
  ),
];
