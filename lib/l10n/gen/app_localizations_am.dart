// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'Crown & Blade - የፀጉር ቤት ቀጠሮ';

  @override
  String get brandUpper => 'CROWN & BLADE';

  @override
  String get cancel => 'ይቅር';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get delete => 'ሰርዝ';

  @override
  String get remove => 'አስወግድ';

  @override
  String get ok => 'እሺ';

  @override
  String get done => 'ጨርስ';

  @override
  String get required => 'ያስፈልጋል';

  @override
  String get signOut => 'ውጣ';

  @override
  String get signOutLower => 'ውጣ';

  @override
  String get all => 'ሁሉም';

  @override
  String get today => 'ዛሬ';

  @override
  String get closed => 'ዝግ ነው';

  @override
  String get cityAddisAbaba => 'አዲስ አበባ';

  @override
  String get languageTooltip => 'ቋንቋ ቀይር';

  @override
  String get serviceUnavailable => 'አገልግሎቱ አይገኝም';

  @override
  String get serviceUnavailableBody =>
      'መተግበሪያው ከአገልጋዩ ጋር መገናኘት አልቻለም። እባክዎ ቆየት ብለው እንደገና ይሞክሩ።';

  @override
  String get shopNotLoaded => 'የፀጉር ቤትዎን መጫን አልተቻለም።';

  @override
  String get invalidEthiopianPhone =>
      'ትክክለኛ የኢትዮጵያ ሞባይል ቁጥር ያስገቡ (09... ወይም 07...)';

  @override
  String minutesShort(int count) {
    return '$count ደቂቃ';
  }

  @override
  String reviewsCount(String rating, int count) {
    return '$rating ($count ግምገማዎች)';
  }

  @override
  String barbersCount(int count) {
    return '$count ፀጉር አስተካካዮች';
  }

  @override
  String servicesCount(int count) {
    return '$count አገልግሎቶች';
  }

  @override
  String bookingsCount(int count) {
    return '$count ቀጠሮዎች';
  }

  @override
  String barberLabel(String name) {
    return 'ፀጉር አስተካካይ፦ $name';
  }

  @override
  String clientLabel(String name) {
    return 'ደንበኛ፦ $name';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date $time ላይ';
  }

  @override
  String serviceAndPrice(String service, String price) {
    return '$service • $price';
  }

  @override
  String get roleAdmin => 'የመድረክ አስተዳዳሪ';

  @override
  String get roleOwner => 'የፀጉር ቤት ባለቤት';

  @override
  String get roleBarber => 'ፀጉር አስተካካይ';

  @override
  String get roleCustomer => 'ደንበኛ';

  @override
  String get statusPending => 'በመጠባበቅ ላይ';

  @override
  String get statusConfirmed => 'ተረጋግጧል';

  @override
  String get statusInProgress => 'በሂደት ላይ';

  @override
  String get statusCompleted => 'ተጠናቋል';

  @override
  String get statusCancelled => 'ተሰርዟል';

  @override
  String get subTrialing => 'ነፃ ሙከራ';

  @override
  String get subActive => 'ንቁ';

  @override
  String get subPastDue => 'ክፍያ ዘግይቷል';

  @override
  String get subSuspended => 'ታግዷል';

  @override
  String get payUnpaid => 'ያልተከፈለ';

  @override
  String get payAtShop => 'ፀጉር ቤቱ ላይ ይከፈላል';

  @override
  String get payPending => 'ክፍያ በሂደት ላይ';

  @override
  String get payPaid => 'ተከፍሏል';

  @override
  String get payRefunded => 'ተመላሽ ተደርጓል';

  @override
  String get recordProcessing => 'በሂደት ላይ';

  @override
  String get recordFailed => 'አልተሳካም';

  @override
  String get planTrial => 'ነፃ ሙከራ';

  @override
  String get planBasic => 'መሰረታዊ';

  @override
  String get planPro => 'ፕሮ';

  @override
  String get planUnlimitedBarbers => 'ያልተገደበ የፀጉር አስተካካዮች ብዛት';

  @override
  String planUpToBarbers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'እስከ $count ፀጉር አስተካካዮች',
      one: 'እስከ 1 ፀጉር አስተካካይ',
    );
    return '$_temp0';
  }

  @override
  String get payErrNotSetUp => 'የኦንላይን ክፍያ ገና አልተዘጋጀም። እባክዎ ፀጉር ቤቱ ላይ ይክፈሉ።';

  @override
  String get payErrSignIn => 'ክፍያ ለመፈጸም እባክዎ እንደገና ይግቡ።';

  @override
  String get payErrNotAllowed => 'ይህን ክፍያ ለመፈጸም አልተፈቀደልዎትም።';

  @override
  String get payErrNotFound => 'ይህ ንጥል አልተገኘም። ተሰርዞ ሊሆን ይችላል።';

  @override
  String get payErrAlreadyPaid => 'ይህ ቀጠሮ አስቀድሞ ተከፍሏል።';

  @override
  String get payErrNetwork =>
      'ከክፍያ አገልግሎቱ ጋር መገናኘት አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get payErrGeneric => 'ክፍያውን መጀመር አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get switchRole => 'ሚና ቀይር';

  @override
  String get personaTitle => 'የሙከራ ሚና ቀይር';

  @override
  String get personaSubtitle => 'የሙከራ ሁነታ፦ እያንዳንዱን ሚና ለመሞከር ወዲያውኑ ይቀይሩ';

  @override
  String get personaAdminTitle => 'የመድረክ አስተዳዳሪ';

  @override
  String get personaAdminSubtitle =>
      'ፀጉር ቤቶችን ይመዝግቡ፣ ተጠቃሚዎችንና የመድረኩን ቅንብሮች ያስተዳድሩ';

  @override
  String get personaOwnerTitle => 'የፀጉር ቤት ባለቤት መተግበሪያ';

  @override
  String personaOwnerSubtitle(String shop) {
    return 'ፀጉር አስተካካዮችን፣ አገልግሎቶችንና ቀጠሮዎችን ያስተዳድሩ ($shop)';
  }

  @override
  String get personaBarberTitle => 'የፀጉር አስተካካይ የስራ ቦታ';

  @override
  String personaBarberSubtitle(String name) {
    return '$name፦ የቀጠሮ ወረፋና ገቢን ያስተዳድሩ';
  }

  @override
  String get personaCustomerTitle => 'የደንበኛ እይታ';

  @override
  String get personaCustomerSubtitle =>
      'ፀጉር ቤቶችን ይፈልጉ፣ ተወዳጅ ፀጉር አስተካካይ ይምረጡና ቀጠሮ ይያዙ';

  @override
  String get notificationsTitle => 'ማሳወቂያዎች';

  @override
  String notificationsUnreadTooltip(int count) {
    return 'ማሳወቂያዎች ($count ያልተነበቡ)';
  }

  @override
  String get markAllRead => 'ሁሉንም እንደተነበበ ምልክት አድርግ';

  @override
  String get noNotifications => 'እስካሁን ምንም ማሳወቂያ የለም';

  @override
  String get noNotificationsHint => 'የቀጠሮ ማረጋገጫዎች፣ ለውጦችና ማስታወሻዎች እዚህ ይታያሉ።';

  @override
  String get justNow => 'አሁን';

  @override
  String minutesAgo(int count) {
    return 'ከ$count ደቂቃ በፊት';
  }

  @override
  String hoursAgo(int count) {
    return 'ከ$count ሰዓት በፊት';
  }

  @override
  String daysAgo(int count) {
    return 'ከ$count ቀን በፊት';
  }

  @override
  String get authSubtitlePhone => 'በስልክ ቁጥርዎ ይግቡ ወይም አዲስ መለያ ይፍጠሩ';

  @override
  String authSubtitleCode(String phone) {
    return 'ወደ $phone የተላከውን ባለ 6 አሃዝ ኮድ ያስገቡ';
  }

  @override
  String get mobileNumber => 'የሞባይል ቁጥር';

  @override
  String get sendCode => 'ኮድ ላክ';

  @override
  String get smsNotice =>
      'የአንድ ጊዜ ኮድ በኤስኤምኤስ እንልክልዎታለን። መደበኛ የኤስኤምኤስ ክፍያ ሊኖር ይችላል።';

  @override
  String get verify => 'አረጋግጥ';

  @override
  String get changeNumber => 'ቁጥር ቀይር';

  @override
  String resendIn(int seconds) {
    return 'በ$seconds ሰከንድ ውስጥ እንደገና ላክ';
  }

  @override
  String get resendCode => 'ኮዱን እንደገና ላክ';

  @override
  String demoCodeNotice(String code) {
    return 'የሙከራ ሁነታ፦ ኮዱ $code ነው';
  }

  @override
  String get demoAccounts => 'የሙከራ መለያዎች';

  @override
  String get roleAdminShort => 'አስተዳዳሪ';

  @override
  String get welcome => 'እንኳን ደህና መጡ';

  @override
  String get profileCustomerMessage => 'በመላው አዲስ አበባ የፀጉር ቀጠሮ ለመያዝ መለያዎን ይፍጠሩ።';

  @override
  String profileOwnerInvite(String shop) {
    return '$shopን በባለቤትነት እንዲያስተዳድሩ ተጋብዘዋል።';
  }

  @override
  String profileBarberInvite(String shop) {
    return '$shopን በፀጉር አስተካካይነት እንዲቀላቀሉ ተጋብዘዋል።';
  }

  @override
  String profileRoleInvite(String role) {
    return 'እንደ $role ተጋብዘዋል።';
  }

  @override
  String get aBarbershop => 'አንድ ፀጉር ቤት';

  @override
  String get fullName => 'ሙሉ ስም';

  @override
  String get continueLabel => 'ቀጥል';

  @override
  String get useDifferentNumber => 'ሌላ ቁጥር ተጠቀም';

  @override
  String get authErrInvalidPhone => 'ይህ ስልክ ቁጥር ትክክል አይደለም።';

  @override
  String get authErrWrongCode => 'የተሳሳተ ኮድ። ኤስኤምኤሱን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get authErrCodeExpired => 'ኮዱ ጊዜው አልፎበታል። አዲስ ኮድ ይጠይቁ።';

  @override
  String get authErrTooMany => 'በጣም ብዙ ሙከራዎች። እባክዎ ጥቂት ደቂቃዎች ጠብቀው እንደገና ይሞክሩ።';

  @override
  String get authErrQuota => 'የኤስኤምኤስ ገደብ ተደርሷል። እባክዎ ቆየት ብለው ይሞክሩ።';

  @override
  String get authErrNetwork => 'የኢንተርኔት ግንኙነት የለም።';

  @override
  String get authErrNotEnabled => 'በስልክ መግባት ለዚህ መተግበሪያ ገና አልነቃም።';

  @override
  String get authErrGeneric => 'የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get adminSubtitle => 'የመድረክ ሲስተም አስተዳደር';

  @override
  String get deleteShopTitle => 'ፀጉር ቤቱ ይሰረዝ?';

  @override
  String deleteShopBody(String shop) {
    return '\"$shop\"ን ከነፀጉር አስተካካዮቹ፣ አገልግሎቶቹና ቀጠሮዎቹ ማስወገድ እንደሚፈልጉ እርግጠኛ ነዎት?';
  }

  @override
  String shopRemoved(String shop) {
    return '$shop ተወግዷል';
  }

  @override
  String get subscriptionsAndPlansTooltip => 'የደንበኝነት ክፍያዎችና ዕቅዶች';

  @override
  String tabShops(int count) {
    return 'ፀጉር ቤቶች ($count)';
  }

  @override
  String tabUsers(int count) {
    return 'ተጠቃሚዎች ($count)';
  }

  @override
  String tabBookings(int count) {
    return 'ቀጠሮዎች ($count)';
  }

  @override
  String get registerBarbershop => 'ፀጉር ቤት መዝግብ';

  @override
  String get metricBarbershops => 'ፀጉር ቤቶች';

  @override
  String get metricRegistered => 'የተመዘገቡ';

  @override
  String get metricActiveBarbers => 'ንቁ ፀጉር አስተካካዮች';

  @override
  String get metricAcrossNetwork => 'በመላው አውታረ መረብ';

  @override
  String get metricPlatformSales => 'የመድረኩ ሽያጭ';

  @override
  String get metricGrossVolume => 'ጠቅላላ መጠን';

  @override
  String get searchShopsAdminHint => 'ፀጉር ቤቶችን በስም፣ በአድራሻ ወይም በክፍለ ከተማ ይፈልጉ...';

  @override
  String get filterVerifiedPartners => 'የተረጋገጡ አጋሮች';

  @override
  String get filterOpenNow => 'አሁን ክፍት';

  @override
  String registeredBarbershopsCount(int count) {
    return 'የተመዘገቡ ፀጉር ቤቶች ($count)';
  }

  @override
  String get adminActionsEnabled => 'የአስተዳዳሪ እርምጃዎች ነቅተዋል';

  @override
  String get noRegisteredShops => 'ምንም የተመዘገበ ፀጉር ቤት አልተገኘም';

  @override
  String get noRegisteredShopsHint =>
      'አዲስ ፀጉር ቤት ወደ መድረኩ ለመጨመር \"ፀጉር ቤት መዝግብ\"ን ይንኩ።';

  @override
  String ownerInvitePending(String name, String phone) {
    return '$name ($phone) - ግብዣ በመጠባበቅ ላይ';
  }

  @override
  String get notAssigned => 'አልተመደበም';

  @override
  String ownerLabel(String owner) {
    return 'ባለቤት፦ $owner';
  }

  @override
  String get verified => 'የተረጋገጠ';

  @override
  String get verifyShop => 'ፀጉር ቤቱን አረጋግጥ';

  @override
  String get manageShopPortal => 'የፀጉር ቤቱን ፖርታል አስተዳድር';

  @override
  String get deleteShop => 'ፀጉር ቤቱን ሰርዝ';

  @override
  String get roleAdministrator => 'አስተዳዳሪ';

  @override
  String get roleStaffBarber => 'ተቀጣሪ ፀጉር አስተካካይ';

  @override
  String assignedShop(String shop) {
    return 'የተመደበበት ፀጉር ቤት፦ $shop';
  }

  @override
  String get noPlatformAppointments => 'እስካሁን በመድረኩ የተመዘገበ ቀጠሮ የለም';

  @override
  String scheduleAt(String when) {
    return 'ቀጠሮ፦ $when';
  }

  @override
  String get registerNewBarbershop => 'አዲስ ፀጉር ቤት መዝግብ';

  @override
  String registeredShopSnack(String shop, String phone) {
    return '\"$shop\" ተመዝግቧል። ባለቤቱ አሁን በ$phone መግባት ይችላሉ።';
  }

  @override
  String registrationError(String error) {
    return 'የምዝገባ ስህተት፦ $error';
  }

  @override
  String get onboardingTitle => 'የፀጉር ቤት ምዝገባ';

  @override
  String get onboardingSubtitle =>
      'የፀጉር ቤቱን መገለጫ ይመዘግባል፣ ለባለቤቱ መለያ ያዘጋጃል፣ የሰራተኞች ቦታም ያደራጃል።';

  @override
  String get sectionShopProfile => '1. የፀጉር ቤቱ መገለጫና ምልክት';

  @override
  String get shopBusinessName => 'የፀጉር ቤቱ የንግድ ስም *';

  @override
  String get shopBusinessNameHint => 'ለምሳሌ ቦሌ ፌድ ስቱዲዮ';

  @override
  String get shopDescription => 'የፀጉር ቤቱ መግለጫ';

  @override
  String get shopTelephone => 'የፀጉር ቤቱ ስልክ *';

  @override
  String get coverImageUrl => 'የሽፋን ምስል ማስፈንጠሪያ (URL)';

  @override
  String get sectionOwnerAccount => '2. የፀጉር ቤቱ ባለቤት መለያ';

  @override
  String get ownerFullName => 'የባለቤቱ ሙሉ ስም *';

  @override
  String get ownerMobileLogin => 'የባለቤቱ ሞባይል ቁጥር (ለመግቢያ) *';

  @override
  String get ownerMobileHelper => 'ባለቤቱ ፀጉር ቤቱን ለማስተዳደር በዚህ ቁጥር ይገባሉ።';

  @override
  String get sectionLocation => '3. አካላዊ አድራሻ';

  @override
  String get streetAddressRequired => 'የመንገድ አድራሻ *';

  @override
  String get streetAddressHint => 'ለምሳሌ ቦሌ መንገድ፣ ጌቱ ህንፃ፣ 2ኛ ፎቅ';

  @override
  String get subCityRequired => 'ክፍለ ከተማ *';

  @override
  String get landmark => 'መለያ ቦታ';

  @override
  String get landmarkHint => 'ለምሳሌ ኤድና ሞል አጠገብ';

  @override
  String get cityRequired => 'ከተማ *';

  @override
  String get cityHint => 'ለምሳሌ አዲስ አበባ';

  @override
  String get sectionHours => '4. የስራ ሰዓትና ማረጋገጫ';

  @override
  String get openingTime => 'የመክፈቻ ሰዓት';

  @override
  String get closingTime => 'የመዝጊያ ሰዓት';

  @override
  String get markVerifiedPartner => 'እንደ የተረጋገጠ አጋር ፀጉር ቤት ምልክት አድርግ';

  @override
  String get markVerifiedPartnerSubtitle => 'የማረጋገጫ ምልክቱ ለሁሉም ደንበኞች ይታያል';

  @override
  String get registeringBarbershop => 'ፀጉር ቤቱ በመመዝገብ ላይ...';

  @override
  String get registerIntoNetwork => 'ፀጉር ቤቱን ወደ አውታረ መረቡ መዝግብ';

  @override
  String get presetClassicLounge => 'ክላሲክ ላውንጅ';

  @override
  String get presetVintageWood => 'ቪንቴጅ እንጨት';

  @override
  String get presetModernGold => 'ዘመናዊ ወርቅ';

  @override
  String get presetIndustrialStudio => 'ኢንዱስትሪያል ስቱዲዮ';

  @override
  String get subscriptionsAndPlans => 'የደንበኝነት ክፍያዎችና ዕቅዶች';

  @override
  String tabPlans(int count) {
    return 'ዕቅዶች ($count)';
  }

  @override
  String get noBarbershopsYet => 'እስካሁን ምንም ፀጉር ቤት የለም።';

  @override
  String statusCountChip(String status, int count) {
    return '$status፦ $count';
  }

  @override
  String get noEndDate => 'የማብቂያ ቀን የለም';

  @override
  String endedDaysAgo(String date, int days) {
    return '$date አብቅቷል (ከ$days ቀን በፊት)';
  }

  @override
  String endsDaysLeft(String date, int days) {
    return '$date ያበቃል ($days ቀን ቀርቷል)';
  }

  @override
  String subscriptionUpdated(String shop) {
    return 'የ$shop የደንበኝነት ክፍያ ተዘምኗል።';
  }

  @override
  String get createDefaultPlans => 'መደበኛ ዕቅዶችን ፍጠር';

  @override
  String get addPlan => 'ዕቅድ ጨምር';

  @override
  String get plansExplainer =>
      'ባለቤቶች መሰረታዊና ፕሮ ዕቅዶችን በኦንላይን መግዛት ይችላሉ። ዕቅድን ማቦዘን ከባለቤቶች ይደብቀዋል፤ ነባር ምዝገባዎች ግን ይቀጥላሉ።';

  @override
  String get noPlansYet => 'እስካሁን ምንም ዕቅድ የለም።';

  @override
  String perMonth(String price) {
    return '$price / በወር';
  }

  @override
  String planActivated(String plan) {
    return '$plan ነቅቷል።';
  }

  @override
  String planDeactivated(String plan) {
    return '$plan ቦዝኗል።';
  }

  @override
  String get defaultPlansExist => 'መደበኛ ዕቅዶቹ አስቀድመው አሉ።';

  @override
  String createdPlans(String plans) {
    return 'የተፈጠሩ ዕቅዶች፦ $plans።';
  }

  @override
  String planSaved(String plan) {
    return 'ዕቅድ $plan ተቀምጧል።';
  }

  @override
  String get manualSubscriptionHint => 'ለጥሬ ገንዘብ ወይም ለባንክ ክፍያዎችና ለእጅ ማስተካከያዎች።';

  @override
  String get planLabel => 'ዕቅድ';

  @override
  String get statusLabel => 'ሁኔታ';

  @override
  String get endDate => 'የማብቂያ ቀን';

  @override
  String get addMonthsPrefix => 'ጨምር፦ ';

  @override
  String monthsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' ወር',
    );
    return '$_temp0';
  }

  @override
  String get setADate => 'ቀን ይምረጡ...';

  @override
  String get keepCurrentEndDate => 'የአሁኑን የማብቂያ ቀን አቆይ';

  @override
  String get pickEndDate => 'የማብቂያ ቀን ምረጥ';

  @override
  String get enterValidPlanValues => 'ትክክለኛ ዋጋና የፀጉር አስተካካዮች ገደብ ያስገቡ።';

  @override
  String get newPlan => 'አዲስ ዕቅድ';

  @override
  String editPlan(String plan) {
    return '$planን አስተካክል';
  }

  @override
  String get planId => 'የዕቅድ መለያ';

  @override
  String get nameLabel => 'ስም';

  @override
  String get pricePerMonth => 'ወርሃዊ ዋጋ';

  @override
  String get currencyEtb => 'ብር';

  @override
  String get maxBarbers => 'ከፍተኛ የፀጉር አስተካካዮች ብዛት';

  @override
  String get featuresOnePerLine => 'ባህሪያት (በአንድ መስመር አንድ)';

  @override
  String get availableToOwners => 'ለባለቤቶች ይገኛል';

  @override
  String subscriptionEditTitle(String shop) {
    return 'የደንበኝነት ክፍያ፦ $shop';
  }

  @override
  String get invalidContactPhone =>
      'ትክክለኛ የኢትዮጵያ ስልክ ቁጥር ያስገቡ (09...፣ 07... ወይም 011...)';

  @override
  String get shopPhoneHint => '09XX XXX XXX ወይም 011 XXX XXXX';

  @override
  String get ownerNameHint => 'ለምሳሌ አበበ ከበደ';

  @override
  String get barberWorkspace => 'የፀጉር አስተካካይ የስራ ቦታ';

  @override
  String get noBarberProfile => 'ከዚህ መለያ ጋር የተገናኘ የፀጉር አስተካካይ መገለጫ የለም።';

  @override
  String tabConfirmed(int count) {
    return 'የተረጋገጡ ($count)';
  }

  @override
  String tabInProgress(int count) {
    return 'በሂደት ላይ ($count)';
  }

  @override
  String tabCompleted(int count) {
    return 'የተጠናቀቁ ($count)';
  }

  @override
  String tabAll(int count) {
    return 'ሁሉም ($count)';
  }

  @override
  String get emptyConfirmed => 'የተያዘ የተረጋገጠ ቀጠሮ የለም።';

  @override
  String get emptyInProgress => 'በአሁኑ ጊዜ በሂደት ላይ ያለ ቀጠሮ የለም።';

  @override
  String get emptyCompleted => 'ዛሬ እስካሁን የተጠናቀቀ ቀጠሮ የለም።';

  @override
  String get emptyHistory => 'የቀጠሮ ታሪክ አልተገኘም።';

  @override
  String get statusOnDuty => 'ሁኔታ፦ በስራ ላይ (ደንበኞችን ይቀበላል)';

  @override
  String get statusOnBreak => 'ሁኔታ፦ እረፍት ላይ / የለም';

  @override
  String get metricAppointments => 'ቀጠሮዎች';

  @override
  String get metricInChair => 'ወንበር ላይ';

  @override
  String get metricEarnings => 'ገቢ';

  @override
  String get viewWeeklySchedule => 'የሳምንቱን የስራ ሰሌዳ ይመልከቱ';

  @override
  String get viewWeeklyScheduleSubtitle => 'የዕለቱን ሰዓቶች፣ ፈረቃዎችና የቀጠሮ ሰሌዳ ይመልከቱ';

  @override
  String get noShow => 'አልመጣም';

  @override
  String get startService => 'አገልግሎት ጀምር';

  @override
  String get markCompleted => 'እንደተጠናቀቀ ምልክት አድርግ';

  @override
  String get serviceCompleted => 'አገልግሎቱ ተጠናቋል';

  @override
  String get appointmentCancelled => 'ቀጠሮው ተሰርዟል';

  @override
  String statusUpdateFailed(String error) {
    return 'ቀጠሮውን ማዘመን አልተቻለም፦ $error';
  }

  @override
  String barberScheduleTitle(String name) {
    return '$name • የስራ ሰሌዳ';
  }

  @override
  String get shopHoursUnavailable => 'የፀጉር ቤቱ የስራ ሰዓት አይገኝም';

  @override
  String get noWorkingHours => 'የስራ ሰዓት አልተወሰነም';

  @override
  String workingHoursLine(String range, String days) {
    return 'የስራ ሰዓት፦ $range • $days';
  }

  @override
  String notTakingNewBookings(String text) {
    return '$text • አዲስ ቀጠሮ አይቀበልም';
  }

  @override
  String dayOff(String day) {
    return 'የእረፍት ቀን - $day የስራ ሰዓት የለም።';
  }

  @override
  String get busy => 'ተይዟል';

  @override
  String get availableSlot => 'ክፍት ሰዓት';

  @override
  String rangeWithDuration(String range, int minutes) {
    return '$range ($minutes ደቂቃ)';
  }

  @override
  String get searchShopsHint => 'ፀጉር ቤቶችን በስም ወይም በሰፈር ይፈልጉ...';

  @override
  String get premierTalent => 'ምርጥ ባለሙያዎች';

  @override
  String get bookWithMasters => 'ከዋና ፀጉር አስተካካዮች ጋር በቀጥታ ቀጠሮ ይያዙ';

  @override
  String get bookWithMastersSubtitle =>
      'የተረጋገጡ ባለሙያዎችን ይመልከቱ፣ ስራዎቻቸውን ይዩና ቦታ ያስይዙ።';

  @override
  String get findBarbers => 'ፀጉር አስተካካይ ፈልግ';

  @override
  String get subCityFilterLabel => 'ክፍለ ከተማ፦';

  @override
  String get catFades => 'ፌድና ቴፐር';

  @override
  String get catBeard => 'የጢም ቅርጽ';

  @override
  String get catShave => 'በሙቅ ፎጣ መላጨት';

  @override
  String get catKids => 'ልጆችና ቪአይፒ';

  @override
  String featuredBarbershops(int count) {
    return 'ተለይተው የቀረቡ ፀጉር ቤቶች ($count)';
  }

  @override
  String get allLocations => 'ሁሉም አካባቢዎች';

  @override
  String noShopsMatching(String query) {
    return 'ከ\"$query\" ጋር የሚዛመድ ፀጉር ቤት አልተገኘም';
  }

  @override
  String get verifiedBadge => 'የተረጋገጠ';

  @override
  String get viewServicesAndBook => 'አገልግሎቶችን ይመልከቱና ቀጠሮ ይያዙ';

  @override
  String get navBarbershops => 'ፀጉር ቤቶች';

  @override
  String get navAppointments => 'ቀጠሮዎች';

  @override
  String get verifiedPartnerBadge => 'የተረጋገጠ አጋር';

  @override
  String get locationAndHours => 'አድራሻና የስራ ሰዓት';

  @override
  String hoursWithDays(String hours, String days) {
    return '$hours ($days)';
  }

  @override
  String ourMasterBarbers(int count) {
    return 'ዋና ፀጉር አስተካካዮቻችን ($count)';
  }

  @override
  String selectAService(int count) {
    return 'አገልግሎት ይምረጡ ($count)';
  }

  @override
  String get chooseAService => 'አገልግሎት ይምረጡ';

  @override
  String get selectToSeePrice => 'ዋጋውን ለማየት ይምረጡ';

  @override
  String get shopHasNoServicesOrBarbers =>
      'ይህ ፀጉር ቤት ንቁ አገልግሎቶች ወይም ፀጉር አስተካካዮች የሉትም።';

  @override
  String get bookSlot => 'ቀጠሮ ያዝ';

  @override
  String get selectAvailableTime => 'እባክዎ ክፍት ሰዓት ይምረጡ።';

  @override
  String get slotJustTaken => 'ሰዓቱ አሁን ተይዟል';

  @override
  String get slotJustTakenBody => 'ይህን ሰዓት ሌላ ሰው ቅድም ያዘው።\n\nየሰዓቶቹ ዝርዝር ታድሷል።';

  @override
  String get pickAnotherTime => 'ሌላ ሰዓት ምረጥ';

  @override
  String get bookingConfirmed => 'ቀጠሮዎ ተረጋግጧል!';

  @override
  String seatReserved(String barber) {
    return 'ከ$barber ጋር ያለዎት ቦታ ተይዟል።';
  }

  @override
  String get receiptShop => 'ፀጉር ቤት';

  @override
  String get receiptService => 'አገልግሎት';

  @override
  String get receiptDate => 'ቀን';

  @override
  String get receiptTime => 'ሰዓት';

  @override
  String get receiptTotal => 'ጠቅላላ';

  @override
  String payAmountNow(String amount) {
    return '$amount አሁን ይክፈሉ';
  }

  @override
  String get payAtShopInstead => 'በምትኩ ፀጉር ቤቱ ላይ እከፍላለሁ';

  @override
  String get backToHome => 'ወደ መነሻ ተመለስ';

  @override
  String get confirmAppointment => 'ቀጠሮውን አረጋግጥ';

  @override
  String get stepChooseBarber => '1. ፀጉር አስተካካይ ይምረጡ';

  @override
  String get stepSelectedService => '2. የተመረጠው አገልግሎት';

  @override
  String get stepSelectDate => '3. ቀን ይምረጡ';

  @override
  String get stepAvailableTimes => '4. ክፍት ሰዓቶች';

  @override
  String durationAddisTime(int minutes) {
    return '$minutes ደቂቃ • በአዲስ አበባ ሰዓት';
  }

  @override
  String get unavailable => 'አይገኝም';

  @override
  String serviceChip(String service, String price, int minutes) {
    return '$service ($price • $minutes ደቂቃ)';
  }

  @override
  String get shopNotTakingBookings => 'ይህ ፀጉር ቤት በአሁኑ ጊዜ ቀጠሮ አይቀበልም።';

  @override
  String barberNotTakingBookings(String barber) {
    return '$barber በአሁኑ ጊዜ ቀጠሮ አይቀበሉም። እባክዎ ሌላ ፀጉር አስተካካይ ይምረጡ።';
  }

  @override
  String barberDayOff(String barber) {
    return '$barber በዚህ ቀን አይሰሩም። እባክዎ ሌላ ቀን ይምረጡ።';
  }

  @override
  String get noFreeTimes => 'በዚህ ቀን ክፍት ሰዓት የለም። እባክዎ ሌላ ቀን ይምረጡ።';

  @override
  String get morning => 'ጠዋት';

  @override
  String get afternoon => 'ከሰዓት';

  @override
  String get evening => 'ምሽት';

  @override
  String get totalPayAtSalon => 'ፀጉር ቤቱ ላይ የሚከፈል ጠቅላላ፦';

  @override
  String get totalPayOnline => 'ጠቅላላ (በኦንላይን ክፍያ)፦';

  @override
  String get selectATime => 'ሰዓት ይምረጡ';

  @override
  String get payAtShopCash => 'ፀጉር ቤቱ ላይ ይክፈሉ (በጥሬ ገንዘብ)';

  @override
  String get payAfterAppointment => 'ከቀጠሮዎ በኋላ ይክፈሉ';

  @override
  String get payNowWithChapa => 'አሁን በቻፓ ይክፈሉ';

  @override
  String get chapaMethods => 'ቴሌብር፣ ሲቢኢ ብር ወይም ካርድ';

  @override
  String get myAppointments => 'የእኔ ቀጠሮዎች';

  @override
  String get noBookingsYet => 'እስካሁን ምንም ቀጠሮ የለም';

  @override
  String get noBookingsHint => 'ምርጥ ፀጉር ቤቶችን ያስሱና የመጀመሪያ ቀጠሮዎን ይያዙ።';

  @override
  String get finishPayment => 'ክፍያውን ጨርስ';

  @override
  String get payNow => 'አሁን ክፈል';

  @override
  String get cancelBooking => 'ቀጠሮውን ሰርዝ';

  @override
  String cancelBookingFailed(String error) {
    return 'ቀጠሮውን መሰረዝ አልተቻለም፦ $error';
  }

  @override
  String get specAll => 'ሁሉም';

  @override
  String get specSkinFade => 'ስኪን ፌድ';

  @override
  String get specBeardSculpting => 'የጢም ቅርጽ';

  @override
  String get specHotShave => 'በሙቅ ፎጣ መላጨት';

  @override
  String get specScissorCut => 'በመቀስ ቁርጥ';

  @override
  String get specExecutiveStyling => 'ዘመናዊ ስታይል';

  @override
  String get findTopBarbers => 'ምርጥ ፀጉር አስተካካዮችን ያግኙ';

  @override
  String get searchBarbersHint => 'በፀጉር አስተካካይ ስም፣ በሙያ ወይም በፀጉር ቤት ይፈልጉ...';

  @override
  String noBarbersMatching(String query) {
    return 'ከ\"$query\" ጋር የሚዛመድ ፀጉር አስተካካይ አልተገኘም';
  }

  @override
  String bookWith(String name) {
    return 'ከ$name ጋር ቀጠሮ ያዙ';
  }

  @override
  String get noServicesAtShop => 'በዚህ ፀጉር ቤት እስካሁን አገልግሎት የለም።';

  @override
  String get partnerPortal => 'የአጋር ንግድ ፖርታል';

  @override
  String get customizableApp => 'ሊያበጁት የሚችሉት የፀጉር ቤትዎ መተግበሪያ';

  @override
  String get customizableAppSubtitle => 'ምልክት፣ የሽፋን ፎቶ፣ የስራ ሰዓትና አድራሻ';

  @override
  String get customize => 'አብጅ';

  @override
  String servicesButton(int count) {
    return 'አገልግሎቶች ($count)';
  }

  @override
  String manageBarbersButton(int count) {
    return 'ፀጉር አስተካካዮችን አስተዳድር ($count)';
  }

  @override
  String get subscriptionAndBilling => 'የደንበኝነት ክፍያና ሂሳብ';

  @override
  String get editInfo => 'መረጃ አስተካክል';

  @override
  String get metricBookings => 'ቀጠሮዎች';

  @override
  String activeCount(int count) {
    return '$count ንቁ';
  }

  @override
  String get metricEstRevenue => 'የሚገመት ገቢ';

  @override
  String get metricGrossSales => 'ጠቅላላ ሽያጭ';

  @override
  String get appointmentsSchedule => 'የቀጠሮዎች ሰሌዳ';

  @override
  String get noAppointmentsFound => 'ምንም ቀጠሮ አልተገኘም';

  @override
  String get cancelSlot => 'ቀጠሮውን ሰርዝ';

  @override
  String get shopSettingsSaved => 'የፀጉር ቤቱ ቅንብሮች በተሳካ ሁኔታ ተቀምጠዋል!';

  @override
  String get customizeMyBarbershop => 'የፀጉር ቤቴን አብጅ';

  @override
  String get preview => 'ቅድመ እይታ';

  @override
  String get savingUpdates => 'ለውጦች በመቀመጥ ላይ...';

  @override
  String get publishCustomizations => 'የፀጉር ቤቱን ለውጦች አትም';

  @override
  String get brandProfile => 'የፀጉር ቤቱ የምልክት መገለጫ';

  @override
  String get brandProfileHint => 'እዚህ የሚያደርጓቸው ለውጦች ወዲያውኑ ለደንበኞች ይታያሉ።';

  @override
  String get sectionBranding => 'የፀጉር ቤቱ ምልክትና መረጃ';

  @override
  String get barbershopNameRequired => 'የፀጉር ቤቱ ስም *';

  @override
  String get brandBio => 'ስለ ፀጉር ቤቱ';

  @override
  String get businessPhone => 'የንግድ ስልክ ቁጥር';

  @override
  String get themePresets => 'ፈጣን የገጽታ ምርጫዎች፦';

  @override
  String get coverPhotoUrl => 'የሽፋን ፎቶ ማስፈንጠሪያ (URL)';

  @override
  String get sectionAddress => 'አካላዊ አድራሻ';

  @override
  String get streetAddress => 'የመንገድ አድራሻ';

  @override
  String get subCity => 'ክፍለ ከተማ';

  @override
  String get city => 'ከተማ';

  @override
  String get sectionSchedule => 'የስራ ቀናትና ሰዓት';

  @override
  String get openingHour => 'የመክፈቻ ሰዓት';

  @override
  String get closingHour => 'የመዝጊያ ሰዓት';

  @override
  String get openWorkingDays => 'የስራ ቀናት፦';

  @override
  String get presetRoyalGold => 'ንጉሳዊ ወርቅና ጥቁር';

  @override
  String get presetVintageGentleman => 'ቪንቴጅ ጨዋ';

  @override
  String get presetEmpireLuxury => 'ኢምፓየር ቅንጦት';

  @override
  String get presetUrbanIndustrial => 'የከተማ ኢንዱስትሪያል';

  @override
  String saveFailed(String error) {
    return 'ማስቀመጥ አልተቻለም፦ $error';
  }

  @override
  String get defaultBarberTitle => 'የፀጉር ስታይልና ፌድ ባለሙያ';

  @override
  String get addBarberToShop => 'ፀጉር አስተካካይ ወደ ፀጉር ቤቱ ጨምር';

  @override
  String get barberFullName => 'የፀጉር አስተካካዩ ሙሉ ስም';

  @override
  String get specialization => 'ሙያ (ለምሳሌ ዋና ፀጉር አስተካካይ)';

  @override
  String get mobileForLogin => 'የሞባይል ቁጥር (ለመግቢያ)';

  @override
  String get barberPhoneHelper => 'አማራጭ። ፀጉር አስተካካዩ በዚህ ቁጥር ይገባሉ።';

  @override
  String get selectAvatar => 'የመገለጫ ፎቶ ይምረጡ፦';

  @override
  String get invalidPhoneShort => 'ትክክለኛ ቁጥር ያስገቡ (09... ወይም 07...)';

  @override
  String get addBarberFailed => 'ፀጉር አስተካካዩን መጨመር አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get addBarber => 'ፀጉር አስተካካይ ጨምር';

  @override
  String get removeBarberTitle => 'ፀጉር አስተካካዩ ይወገድ?';

  @override
  String removeBarberBody(String name) {
    return '\"$name\"ን ከዚህ ፀጉር ቤት ማስወገድ እንደሚፈልጉ እርግጠኛ ነዎት?';
  }

  @override
  String get manageBarbersStaff => 'ፀጉር አስተካካዮችንና ሰራተኞችን አስተዳድር';

  @override
  String get noBarbersYet => 'እስካሁን ምንም ፀጉር አስተካካይ አልተጨመረም';

  @override
  String get noBarbersHint => 'ደንበኞች ቀጠሮ እንዲይዙ ፀጉር አስተካካዮችን ይጨምሩ።';

  @override
  String loginInvitePending(String phone) {
    return 'የመግቢያ ግብዣ በመጠባበቅ ላይ፦ $phone';
  }

  @override
  String get removeBarber => 'ፀጉር አስተካካዩን አስወግድ';

  @override
  String get addNewService => 'አዲስ አገልግሎት ጨምር';

  @override
  String get serviceNameHint => 'የአገልግሎት ስም (ለምሳሌ የጢም ማስተካከያ)';

  @override
  String get description => 'መግለጫ';

  @override
  String get priceEtb => 'ዋጋ (ብር)';

  @override
  String get durationMins => 'የሚወስደው ጊዜ (ደቂቃ)';

  @override
  String get addService => 'አገልግሎት ጨምር';

  @override
  String get manageServicesPricing => 'አገልግሎቶችንና ዋጋዎችን አስተዳድር';

  @override
  String get noServicesYet => 'እስካሁን ምንም አገልግሎት አልተፈጠረም';

  @override
  String get noServicesHint => 'የዋጋ ዝርዝርዎን ለማተም ከታች \"አገልግሎት ጨምር\"ን ይንኩ።';

  @override
  String get invalidServiceValues => 'ስም፣ ዋጋ በብርና የሚወስደውን ጊዜ በደቂቃ ያስገቡ።';

  @override
  String get subscriptionTitle => 'የደንበኝነት ክፍያ';

  @override
  String get plansTitle => 'ዕቅዶች';

  @override
  String get plansIntro =>
      'በየወሩ በቴሌብር፣ በሲቢኢ ብር ወይም በካርድ በቻፓ በኩል ይክፈሉ። ቀድመው ከከፈሉ አንድ ወር አሁን ባለው የማብቂያ ቀን ላይ ይጨመራል።';

  @override
  String get noPlansAvailable =>
      'በአሁኑ ጊዜ ምንም ዕቅድ የለም። እባክዎ የCrown & Blade ድጋፍን ያነጋግሩ።';

  @override
  String get paymentHistory => 'የክፍያ ታሪክ';

  @override
  String get noEndDateSet => 'የማብቂያ ቀን አልተወሰነም';

  @override
  String endedAgo(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$date አብቅቷል (ከ$count ቀን በፊት)',
    );
    return '$_temp0';
  }

  @override
  String trialEndsOn(String date) {
    return 'ሙከራው $date ያበቃል';
  }

  @override
  String renewsBy(String date) {
    return 'እስከ $date መታደስ አለበት';
  }

  @override
  String endsToday(String text) {
    return '$text (ዛሬ)';
  }

  @override
  String daysLeftSuffix(int count, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$text ($count ቀን ቀርቷል)',
    );
    return '$_temp0';
  }

  @override
  String barbersUsage(int count) {
    return 'ፀጉር አስተካካዮች፦ $count';
  }

  @override
  String barbersUsageUnlimited(int count) {
    return 'ፀጉር አስተካካዮች፦ $count (ያልተገደበ)';
  }

  @override
  String barbersUsageOf(int count, int max) {
    return 'ፀጉር አስተካካዮች፦ $count ከ$max';
  }

  @override
  String planTooSmall(int count, int max) {
    return 'ፀጉር ቤትዎ $count ፀጉር አስተካካዮች አሉት፤ ይህ ዕቅድ የሚፈቅደው $max ብቻ ነው።';
  }

  @override
  String get renewWithChapa => 'በቻፓ አድስ';

  @override
  String get payWithChapa => 'በቻፓ ክፈል';

  @override
  String get paymentHistoryUnavailable => 'የክፍያ ታሪክ አይገኝም።';

  @override
  String get noSubscriptionPayments => 'እስካሁን ምንም የደንበኝነት ክፍያ የለም።';

  @override
  String untilDate(String date) {
    return 'እስከ $date';
  }

  @override
  String planOneMonth(String plan) {
    return '$plan ዕቅድ - 1 ወር';
  }

  @override
  String get preparingCheckout => 'ደህንነቱ የተጠበቀ ክፍያ በመዘጋጀት ላይ...';

  @override
  String get paymentProblem => 'የክፍያ ችግር';

  @override
  String get paymentNotCompleted => 'ክፍያው ገና አልተጠናቀቀም። ከከፈሉ በቅርቡ እንደተከፈለ ይታያል።';

  @override
  String subscriptionActiveUntilSentence(String date) {
    return ' የደንበኝነት ክፍያው እስከ $date ይሰራል።';
  }

  @override
  String paymentReceivedAmount(String amount, String extra) {
    return 'ክፍያ ደርሷል፦ $amount።$extra';
  }

  @override
  String get paymentFailedRetry =>
      'ክፍያው አልተሳካም ወይም ተሰርዟል። ምንም ገንዘብ አልተወሰደም። እንደገና መሞከር ይችላሉ።';

  @override
  String get chapaCheckoutDemo => 'የቻፓ ክፍያ (ሙከራ)';

  @override
  String get chapaDemoNotice =>
      'የሙከራ ሁነታ፦ ምንም ገንዘብ አይንቀሳቀስም። የተሳካ ክፍያን ለመሞከር \"ክፈል\"ን ይምረጡ።';

  @override
  String get cancelPayment => 'ክፍያውን ሰርዝ';

  @override
  String payAmount(String amount) {
    return '$amount ክፈል';
  }

  @override
  String get chapaNotConfirmedYet =>
      'ቻፓ ክፍያውን ገና አላረጋገጠም። በብራውዘሩ ውስጥ ጨርሰው እንደገና ያረጋግጡ።';

  @override
  String get completeYourPayment => 'ክፍያዎን ያጠናቅቁ';

  @override
  String completePaymentBody(String amount) {
    return 'በተከፈተው የቻፓ ገጽ ላይ $amount ይክፈሉ (ቴሌብር፣ ሲቢኢ ብር ወይም ካርድ)፣ ከዚያ ወደዚህ ይመለሱ።';
  }

  @override
  String get payLater => 'በኋላ እከፍላለሁ';

  @override
  String get openAgain => 'እንደገና ክፈት';

  @override
  String get ivePaid => 'ከፍያለሁ';

  @override
  String get couldNotCheckPayment => 'ክፍያውን ማረጋገጥ አልተቻለም';

  @override
  String get checkingPayment => 'ክፍያዎን ከቻፓ ጋር በማረጋገጥ ላይ...';

  @override
  String get subscriptionIsActive => 'የደንበኝነት ክፍያዎ ንቁ ነው።';

  @override
  String subscriptionActiveUntil(String date) {
    return 'የደንበኝነት ክፍያዎ እስከ $date ንቁ ነው።';
  }

  @override
  String get bookingIsPaid => 'ቀጠሮዎ ተከፍሏል።';

  @override
  String get paymentReceived => 'ክፍያ ደርሷል';

  @override
  String amountThen(String amount, String what) {
    return '$amount። $what';
  }

  @override
  String get stillProcessing => 'አሁንም በሂደት ላይ';

  @override
  String get stillProcessingBody => 'ቻፓ ይህን ክፍያ ገና አላረጋገጠም። ሲያረጋግጥ በራሱ ይዘምናል።';

  @override
  String get paymentFailed => 'ክፍያው አልተሳካም';

  @override
  String get noMoneyTaken => 'ምንም ገንዘብ አልተወሰደም። እንደገና መሞከር ይችላሉ።';

  @override
  String get paymentTitle => 'ክፍያ';

  @override
  String get checkAgain => 'እንደገና አረጋግጥ';

  @override
  String get bannerSuspended =>
      'ፀጉር ቤትዎ ታግዷል፦ ደንበኞች ሊያዩት ወይም ቀጠሮ ሊይዙበት አይችሉም። እንደገና ለማንቃት የደንበኝነት ክፍያዎን ይክፈሉ።';

  @override
  String get bannerOverdueSoon =>
      'የደንበኝነት ክፍያዎ ዘግይቷል። ካልከፈሉ ፀጉር ቤቱ በቅርቡ ይታገዳል።';

  @override
  String get bannerOverdueToday => 'የደንበኝነት ክፍያዎ ዘግይቷል። ካልከፈሉ ፀጉር ቤቱ ዛሬ ይታገዳል።';

  @override
  String bannerOverdueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'የደንበኝነት ክፍያዎ ዘግይቷል። ካልከፈሉ ፀጉር ቤቱ በ$count ቀን ውስጥ ይታገዳል።',
    );
    return '$_temp0';
  }

  @override
  String get bannerTrialEndsToday =>
      'ነፃ ሙከራዎ ዛሬ ያበቃል። ቀጠሮ መቀበልዎን ለመቀጠል አሁን ይክፈሉ።';

  @override
  String get bannerSubEndsToday =>
      'የደንበኝነት ክፍያዎ ዛሬ ያበቃል። ቀጠሮ መቀበልዎን ለመቀጠል አሁን ይክፈሉ።';

  @override
  String bannerTrialEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ነፃ ሙከራዎ በ$count ቀን ውስጥ ያበቃል። ቀጠሮ መቀበልዎን ለመቀጠል አሁን ይክፈሉ።',
    );
    return '$_temp0';
  }

  @override
  String bannerSubEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'የደንበኝነት ክፍያዎ በ$count ቀን ውስጥ ያበቃል። ቀጠሮ መቀበልዎን ለመቀጠል አሁን ይክፈሉ።',
    );
    return '$_temp0';
  }

  @override
  String get reactivate => 'እንደገና አንቃ';

  @override
  String get cardMethod => 'ካርድ';
}
