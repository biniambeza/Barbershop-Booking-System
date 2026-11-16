// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get privacyPolicyTitle => 'የግላዊነት መመሪያ';

  @override
  String privacyPolicyUpdated(String date) {
    return 'መጨረሻ የተዘመነው $date';
  }

  @override
  String get privacyOpenWeb => 'በድረ-ገጽ ክፈት';

  @override
  String get privacyDeletePageLink => 'መለያዎን እንዴት እንደሚሰርዙ';

  @override
  String get privacyLinkFailed => 'ሊንኩን መክፈት አልተቻለም።';

  @override
  String get privacyConsentPrefix => 'በመመዝገብ ወይም በመግባት በዚህ ይስማማሉ፦';

  @override
  String get deleteAccountMenu => 'መለያ ሰርዝ';

  @override
  String get deleteAccountTitle => 'መለያ ሰርዝ';

  @override
  String get deleteAccountHeroTitle => 'መለያዎን ይሰርዙ';

  @override
  String get deleteAccountHeroBody =>
      'መገለጫዎና መግቢያዎ ለዘለቄታው ይሰረዛሉ። ይህን መመለስ አይቻልም።';

  @override
  String get deleteAccountWhatHappens => 'የሚሆነው';

  @override
  String deleteAccountCancelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count መጪ ቀጠሮዎችዎ ይሰረዛሉ።',
      one: '1 መጪ ቀጠሮዎ ይሰረዛል።',
      zero: 'የሚሰረዝ መጪ ቀጠሮ የለዎትም።',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountPaidRefund(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'የተከፈለባቸው $count ቀጠሮዎች ለተመላሽ ገንዘብ ይመዘገባሉ። ገንዘቡ እስኪመለስልዎ ድረስ ፀጉር ቤቱ ስልክ ቁጥርዎን በእነሱ ላይ ያቆያል።',
      one:
          'የተከፈለበት 1 ቀጠሮ ለተመላሽ ገንዘብ ይመዘገባል። ገንዘቡ እስኪመለስልዎ ድረስ ፀጉር ቤቱ ስልክ ቁጥርዎን በዚያ ቀጠሮ ላይ ያቆያል።',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountKeptInCutoff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ቀጠሮዎች በቅርቡ ስለሚጀምሩ በመተግበሪያው መሰረዝ አይቻልም። ያለ ስምዎ ከፀጉር ቤቱ ጋር ይቆያሉ፤ የማይመጡ ከሆነ ለፀጉር ቤቱ ይደውሉ።',
      one:
          '1 ቀጠሮ በቅርቡ ስለሚጀምር በመተግበሪያው መሰረዝ አይቻልም። ያለ ስምዎ ከፀጉር ቤቱ ጋር ይቆያል፤ የማይመጡ ከሆነ ለፀጉር ቤቱ ይደውሉ።',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountBarberCancel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ከእርስዎ ጋር ያሉ $count የደንበኛ ቀጠሮዎች ይሰረዛሉ፤ ደንበኞቹ ይነገራቸዋል።',
      one: 'ከእርስዎ ጋር ያለ 1 የደንበኛ ቀጠሮ ይሰረዛል፤ ደንበኛው ይነገረዋል።',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountBarberLeaves(String shop) {
    return 'ከ$shop ይወገዳሉ።';
  }

  @override
  String get deleteAccountYourShop => 'ፀጉር ቤትዎ';

  @override
  String get deleteAccountReviews =>
      'ግምገማዎችዎ ኮከባቸውን ይዘው ይቆያሉ፤ ነገር ግን \"የቀድሞ ደንበኛ\" ተብለው ይታያሉ፣ አስተያየታቸውም ይሰረዛል።';

  @override
  String get deleteAccountBookingsHistory =>
      'ያለፉ ቀጠሮዎች ያለ ስምዎና ስልክ ቁጥርዎ በፀጉር ቤቱ መዝገብ ይቀራሉ።';

  @override
  String get deleteAccountPersonalData =>
      'መገለጫዎ፣ የመልዕክት ሳጥንዎ፣ ግብዣዎችዎ፣ ተወዳጆችዎና መግቢያዎ ይሰረዛሉ።';

  @override
  String get deleteAccountPendingLogin =>
      'መረጃዎ ቀድሞውኑ ተሰርዟል። መግቢያዎን ለመሰረዝ እርስዎ መሆንዎን አንድ ጊዜ ያረጋግጡ።';

  @override
  String get deleteAccountReauthTitle => 'እርስዎ መሆንዎን ያረጋግጡ';

  @override
  String deleteAccountConfirmLabel(String word) {
    return 'ለማረጋገጥ $word ብለው ይጻፉ';
  }

  @override
  String get deleteAccountConfirmMismatch => 'ለማረጋገጥ DELETE ብለው በትክክል ይጻፉ።';

  @override
  String get deleteAccountPasswordLabel => 'የይለፍ ቃልዎ';

  @override
  String get deleteAccountPasswordOrGoogle => 'ወይም በGoogle ለማረጋገጥ ባዶ ይተዉት።';

  @override
  String get deleteAccountReauthGoogle => 'እንደገና በGoogle እንዲገቡ ይጠየቃሉ።';

  @override
  String get deleteAccountSubmit => 'መለያዬን ሰርዝ';

  @override
  String get deleteAccountDone => 'መለያዎ ተሰርዟል።';

  @override
  String get deleteAccountErrReauth =>
      'ለደህንነትዎ፣ መለያዎን መሰረዝ ለመጨረስ እንደገና ይግቡ፤ ከዚያ ሰርዝን እንደገና ይጫኑ።';

  @override
  String get deleteAccountErrReauthCancelled =>
      'በGoogle መግባት ተሰርዟል። ምንም አልተሰረዘም።';

  @override
  String deleteAccountErrStep(String step) {
    return 'መሰረዙ እዚህ ቆሟል፦ $step ካቆመበት ለመቀጠል ሰርዝን እንደገና ይጫኑ።';
  }

  @override
  String get deleteAccountErrFailed => 'መለያዎን መሰረዝ አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get deleteStepCancelBookings => 'ቀጠሮዎችዎን በመሰረዝ ላይ…';

  @override
  String get deleteStepReviews => 'ግምገማዎችዎን በማዘመን ላይ…';

  @override
  String get deleteStepBookings => 'ስምዎን ከቀጠሮዎች በማስወገድ ላይ…';

  @override
  String get deleteStepLeaveShop => 'ከፀጉር ቤቱ በማስወገድ ላይ…';

  @override
  String get deleteStepPersonalData => 'የመልዕክት ሳጥንዎንና ግብዣዎችዎን በመሰረዝ ላይ…';

  @override
  String get deleteStepProfile => 'መገለጫዎን በመሰረዝ ላይ…';

  @override
  String get deleteStepLogin => 'መግቢያዎን በመሰረዝ ላይ…';

  @override
  String get deleteAccountOwnerTitle => 'መጀመሪያ ፀጉር ቤትዎን ያስወግዱ';

  @override
  String deleteAccountOwnerBody(String shop) {
    return 'የ$shop ባለቤት ነዎት። ፀጉር ቤት ያለው መለያ መሰረዝ አይቻልም። ፀጉር ቤቱን እንዲያስወግድ አስተዳዳሪውን ይጠይቁ፤ መጪ ቀጠሮዎቹ ይሰረዛሉ፣ ደንበኞቹም ይነገራቸዋል። ከዚያ ደንበኛ ይሆናሉ፣ መለያዎንም እዚህ መሰረዝ ይችላሉ።';
  }

  @override
  String get deleteAccountLastAdminTitle => 'ብቸኛው አስተዳዳሪ እርስዎ ነዎት';

  @override
  String get deleteAccountLastAdminBody =>
      'መጀመሪያ ሌላ ሰው አስተዳዳሪ ያድርጉ (የተጠቃሚዎች ትር)፤ ከዚያ መለያዎን መሰረዝ ይችላሉ።';

  @override
  String get shopRemovalNoteLabel => 'ለአስተዳዳሪው ማስታወሻ (አማራጭ)';

  @override
  String get shopRemovalRequestButton => 'ፀጉር ቤቴን እንዲያስወግድ አስተዳዳሪውን ጠይቅ';

  @override
  String get shopRemovalSent => 'ጥያቄው ለአስተዳዳሪው ተልኳል።';

  @override
  String shopRemovalPending(String date) {
    return 'በ$date ጠይቀዋል። አስተዳዳሪው ፀጉር ቤቱን ያስወግዳል፤ ሊያገኝዎትም ይችላል።';
  }

  @override
  String get shopRemovalWithdraw => 'ጥያቄውን መልስ';

  @override
  String shopRemovalDismissed(String date) {
    return 'አስተዳዳሪው በ$date ጥያቄዎን አልተቀበለውም። እንደገና መላክ ይችላሉ።';
  }

  @override
  String shopRemovalNoteTooLong(int max) {
    return 'ማስታወሻው ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String get shopRemovalStatusPending => 'በመጠባበቅ ላይ';

  @override
  String get shopRemovalStatusDone => 'ተጠናቋል';

  @override
  String get shopRemovalStatusDismissed => 'ውድቅ ተደርጓል';

  @override
  String get formerCustomer => 'የቀድሞ ደንበኛ';

  @override
  String get adminRemovalRequestsTitle => 'ፀጉር ቤት የማስወገድ ጥያቄዎች';

  @override
  String get adminRemovalHelp =>
      'መለያቸውን መሰረዝ የሚፈልጉ ባለቤቶች መጀመሪያ እዚህ ይጠይቃሉ። ፀጉር ቤቱን ከፍተው ይሰርዙት (ፀጉር ቤት ሰርዝ)፤ ከዚያ ጥያቄውን ተጠናቋል ብለው ምልክት ያድርጉ። ባለቤቱ ደንበኛ ይሆናል፣ መለያውንም በመተግበሪያው መሰረዝ ይችላል።';

  @override
  String get adminRemovalEmpty => 'ምንም ጥያቄ የለም።';

  @override
  String adminRemovalRequestedOn(String date) {
    return 'በ$date የተጠየቀ';
  }

  @override
  String get adminRemovalShopGone => 'ፀጉር ቤቱ ቀድሞውኑ ተወግዷል።';

  @override
  String get adminRemovalOpenShop => 'ፀጉር ቤቱን ክፈት';

  @override
  String get adminRemovalMarkDone => 'ተጠናቋል በል';

  @override
  String get adminRemovalDismiss => 'ውድቅ አድርግ';

  @override
  String get portfolioTitle => 'የሥራ ማሳያ';

  @override
  String portfolioOfBarber(String name) {
    return 'የ$name ሥራዎች';
  }

  @override
  String portfolioPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ፎቶዎች',
      one: '1 ፎቶ',
    );
    return '$_temp0';
  }

  @override
  String get portfolioShopSectionTitle => 'ሥራዎቻቸውን ይመልከቱ';

  @override
  String get portfolioShopSectionHint => 'የዚህ ቤት ፀጉር አስተካካዮች የሠሯቸው ቁርጦች';

  @override
  String portfolioSeeWork(String name) {
    return 'የ$name ሥራዎችን ይመልከቱ';
  }

  @override
  String get portfolioEmpty => 'እስካሁን ምንም ፎቶ የለም።';

  @override
  String portfolioBookStyle(String name) {
    return 'ይህን ቁርጥ ከ$name ጋር ይያዙ';
  }

  @override
  String portfolioViewerCounter(int index, int total) {
    return '$index / $total';
  }

  @override
  String portfolioPhotoSemantics(int index) {
    return 'የሥራ ማሳያ ፎቶ $index';
  }

  @override
  String get portfolioManageTitle => 'የሥራ ማሳያ ፎቶዎች';

  @override
  String portfolioManageIntro(int max) {
    return 'የምርጥ ቁርጦችዎ ፎቶዎች ደንበኞች እርስዎን እንዲመርጡ ይረዳሉ። እስከ $max ፎቶዎች።';
  }

  @override
  String get portfolioPublicNotice =>
      'የሥራ ማሳያ ፎቶዎች ለሁሉም ይታያሉ። ደንበኞችዎ እንዲጋሩ የፈቀዱትን ፎቶዎች ብቻ ያስቀምጡ፤ ስም ወይም ስልክ ቁጥር አያካትቱ።';

  @override
  String portfolioCountOfMax(int count, int max) {
    return '$count ከ$max ፎቶዎች';
  }

  @override
  String get portfolioAddPhoto => 'ፎቶ ያክሉ';

  @override
  String get portfolioTakePhoto => 'ፎቶ ያንሱ';

  @override
  String get portfolioChooseFromGallery => 'ከጋለሪ ይምረጡ';

  @override
  String get portfolioCaptionLabel => 'የቁርጥ ስም (አማራጭ)';

  @override
  String get portfolioCaptionHint => 'ለምሳሌ፦ ሎው ፌድ';

  @override
  String get portfolioEditCaption => 'የቁርጥ ስም ያስተካክሉ';

  @override
  String get portfolioDeletePhoto => 'ፎቶውን ይሰርዙ';

  @override
  String get portfolioDeleteConfirmTitle => 'ይህን ፎቶ ይሰርዙ?';

  @override
  String get portfolioDeleteConfirmBody => 'ደንበኞች ከእንግዲህ አያዩትም።';

  @override
  String get portfolioAdded => 'ፎቶው ታክሏል።';

  @override
  String get portfolioDeleted => 'ፎቶው ተሰርዟል።';

  @override
  String get portfolioCaptionSaved => 'የቁርጥ ስሙ ተቀምጧል።';

  @override
  String get portfolioSaving => 'ፎቶው እየተቀመጠ ነው...';

  @override
  String portfolioFull(int max) {
    return '$max ፎቶዎች አሉዎት። ሌላ ለማከል አንዱን ይሰርዙ።';
  }

  @override
  String get portfolioErrNotAllowed =>
      'ይህን የሥራ ማሳያ መቀየር የሚችሉት ፀጉር አስተካካዩ እና የቤቱ ባለቤት ብቻ ናቸው።';

  @override
  String portfolioErrCaptionTooLong(int max) {
    return 'የቁርጥ ስሙ ከ$max ፊደላት መብለጥ የለበትም።';
  }

  @override
  String get portfolioErrImage => 'ይህን ፎቶ መጠቀም አልተቻለም። ሌላ ይሞክሩ።';

  @override
  String get portfolioErrSlotTaken => 'ሌላ ፎቶ አሁን ታክሏል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get portfolioErrNotFound => 'ይህ ፎቶ አስቀድሞ ተሰርዟል።';

  @override
  String get portfolioLoadFailed => 'ፎቶዎቹን መጫን አልተቻለም።';

  @override
  String get portfolioRetry => 'እንደገና ይሞክሩ';

  @override
  String get portfolioDashboardTitle => 'የሥራ ማሳያዬ';

  @override
  String get portfolioDashboardSubtitle => 'ምርጥ ቁርጦችዎን ለደንበኞች ያሳዩ';

  @override
  String get rcptPayTitle => 'በዝውውር ይክፈሉ';

  @override
  String get rcptEntryTitle => 'በቴሌብር ወይም በንግድ ባንክ ይክፈሉ';

  @override
  String get rcptEntryBody =>
      'የደንበኝነት ክፍያውን ይላኩ፣ ከዚያ ደረሰኙን ያስገቡ። ደረሰኙ ሲረጋገጥ ደንበኝነትዎ ይራዘማል።';

  @override
  String get rcptIntro =>
      '1. የጊዜ ርዝመት መርጠው ገንዘቡን ይላኩ። 2. የግብይት ቁጥሩን ያስገቡና ደረሰኙን ያያይዙ። 3. ደረሰኙ ሲረጋገጥ ቀናቱ በደንበኝነትዎ ላይ ይጨመራሉ።';

  @override
  String get rcptCurrentSub => 'የአሁኑ ደንበኝነት';

  @override
  String rcptPaidUntil(String date) {
    return 'እስከ $date ተከፍሏል';
  }

  @override
  String get rcptNoEnd => 'የማብቂያ ቀን የለም';

  @override
  String get rcptPricesTitle => 'ዋጋዎች';

  @override
  String rcptDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቀናት',
      one: '1 ቀን',
    );
    return '$_temp0';
  }

  @override
  String get rcptTierUse => 'ይህን መጠን ለመጠቀም ይንኩ';

  @override
  String get rcptWhereToPay => 'የት እንደሚከፍሉ';

  @override
  String get rcptMethodTelebirr => 'ቴሌብር';

  @override
  String get rcptMethodCbe => 'የኢትዮጵያ ንግድ ባንክ (CBE)';

  @override
  String get rcptMethodCbeShort => 'ንግድ ባንክ';

  @override
  String get rcptMethodOther => 'ሌላ ባንክ';

  @override
  String get rcptReceiverNumber => 'የቴሌብር ቁጥር';

  @override
  String get rcptReceiverAccount => 'የሂሳብ ቁጥር';

  @override
  String rcptReceiverName(String name) {
    return 'ስም፦ $name';
  }

  @override
  String get rcptNotConfigured => 'ገና አልተዘጋጀም። እባክዎ ድጋፍ ሰጪን ያግኙ።';

  @override
  String get rcvSetupTitle => 'የሱቅ ባለቤቶች የሚከፍሉዎትን ቦታ ያዘጋጁ';

  @override
  String get rcvSetupBody =>
      'የቴሌብር ቁጥርዎን ወይም የንግድ ባንክ ሂሳብዎን እስኪያስገቡ ድረስ ባለቤቶች የደንበኝነት ክፍያቸውን መክፈል አይችሉም።';

  @override
  String get rcvSetupButton => 'ያዘጋጁ';

  @override
  String get rcvSetupDotLabel => 'የክፍያ ዝግጅት ያስፈልጋል';

  @override
  String get rcvErrPhone => 'የኢትዮጵያ ሞባይል ቁጥር ያስገቡ፣ ለምሳሌ 0911 223344።';

  @override
  String get rcvErrCbe => 'በ1000 የሚጀምር ባለ 13 አሃዝ የንግድ ባንክ ሂሳብ ቁጥር ያስገቡ።';

  @override
  String get rcvErrPlaceholder => 'XXXX የሚለውን ምሳሌ በእውነተኛ ቁጥርዎ ይተኩ።';

  @override
  String get rcvErrNameShort => 'የሂሳቡን ባለቤት ስም ያስገቡ (ቢያንስ 2 ፊደላት)።';

  @override
  String get rcvErrNameLong => 'ከ80 ፊደላት አይበልጥ።';

  @override
  String get rcvErrFix => 'ምልክት የተደረገባቸውን መስኮች ያስተካክሉ።';

  @override
  String get rcvTelebirrOptional => 'ቴሌብር የማይቀበሉ ከሆነ ባዶ ይተዉት። ባለቤቶች አያዩትም።';

  @override
  String get rcvCbeOptional => 'በንግድ ባንክ ዝውውር የማይቀበሉ ከሆነ ባዶ ይተዉት። ባለቤቶች አያዩትም።';

  @override
  String get rcvPaymentsNotOpen => 'ክፍያዎች ገና አልተከፈቱም — እባክዎ ቆይተው ይመለሱ።';

  @override
  String get rcptCopy => 'ቅዳ';

  @override
  String get rcptCopied => 'ተቀድቷል';

  @override
  String get rcptSubmitTitle => 'ደረሰኝዎን ያስገቡ';

  @override
  String get rcptMethodLabel => 'የተከፈለበት';

  @override
  String get rcptTxLabel => 'የግብይት ቁጥር';

  @override
  String get rcptTxHintTelebirr => 'ለምሳሌ CHK1AB2CDE (በቴሌብር መልዕክቱ ውስጥ)';

  @override
  String get rcptTxHintCbe => 'ለምሳሌ FT2412345ABC (በንግድ ባንክ ደረሰኙ ላይ)';

  @override
  String get rcptTxHintOther => 'በደረሰኝዎ ላይ ያለው የማጣቀሻ ቁጥር';

  @override
  String get rcptSuffixLabel => 'የሂሳብዎ የመጨረሻ 8 አሃዞች (አማራጭ)';

  @override
  String get rcptSuffixHelper => 'የንግድ ባንክ ደረሰኝዎን ለመክፈት ይረዳናል።';

  @override
  String get rcptAmountLabel => 'የተከፈለው መጠን (ብር)';

  @override
  String rcptAmountGrants(String days) {
    return 'በደንበኝነትዎ ላይ $days ይጨምራል';
  }

  @override
  String rcptAmountBelowMin(String amount) {
    return 'ዝቅተኛው ክፍያ $amount ነው';
  }

  @override
  String get rcptPhotoLabel => 'የደረሰኝ ፎቶ ወይም ስክሪንሾት';

  @override
  String get rcptPhotoHint => 'ይመከራል፦ ማረጋገጫውን ያፋጥናል።';

  @override
  String get rcptTakePhoto => 'ካሜራ';

  @override
  String get rcptChooseImage => 'ጋለሪ';

  @override
  String get rcptRemovePhoto => 'ፎቶውን አስወግድ';

  @override
  String get rcptPhotoFailed => 'ይህን ምስል መጠቀም አልተቻለም። ሌላ ፎቶ ወይም ስክሪንሾት ይሞክሩ።';

  @override
  String get rcptSubmit => 'ደረሰኝ አስገባ';

  @override
  String get rcptSubmitted => 'ደረሰኙ ገብቷል። ሲረጋገጥ እናሳውቅዎታለን።';

  @override
  String get rcptHistoryTitle => 'ደረሰኞችዎ';

  @override
  String get rcptNoHistory => 'እስካሁን የገባ ደረሰኝ የለም።';

  @override
  String get rcptStatusPending => 'ማረጋገጫ በመጠበቅ ላይ';

  @override
  String get rcptStatusVerified => 'ተረጋግጧል';

  @override
  String get rcptStatusRejected => 'ውድቅ ተደርጓል';

  @override
  String get rcptStatusNeedsReview => 'በመፈተሽ ላይ';

  @override
  String rcptGranted(String days) {
    return '$days ተጨምሯል';
  }

  @override
  String get rcptVerifiedAuto => 'በራስ-ሰር ተረጋግጧል';

  @override
  String get rcptReasonTitle => 'ምክንያት';

  @override
  String rcptReasonLine(String reason) {
    return 'ምክንያት፦ $reason';
  }

  @override
  String get rcptReasonAmountTooLow => 'መጠኑ ከዝቅተኛው የደንበኝነት ዋጋ ያነሰ ነው።';

  @override
  String get rcptReasonDuplicate => 'ይህ ግብይት ቀደም ሲል ጥቅም ላይ ውሏል።';

  @override
  String get rcptReasonNotFound => 'ኦፊሴላዊው ደረሰኝ አልተገኘም።';

  @override
  String get rcptReasonNotCompleted => 'ግብይቱ አልተጠናቀቀም።';

  @override
  String get rcptReasonReceiverMismatch => 'ገንዘቡ ወደ መድረኩ ሂሳብ አልተላከም።';

  @override
  String get rcptReasonAmountMismatch => 'ደረሰኙ ያነሰ መጠን ያሳያል።';

  @override
  String get rcptReasonTooOld => 'ደረሰኙ ከ30 ቀናት በላይ ቆይቷል።';

  @override
  String get rcptReasonFetchFailed =>
      'ደረሰኙን በራስ-ሰር ማረጋገጥ አልተቻለም። አስተዳዳሪ ይመረምረዋል።';

  @override
  String get rcptReasonUnsupported => 'በዚህ መንገድ የተደረጉ ክፍያዎችን አስተዳዳሪ ያረጋግጣል።';

  @override
  String get rcptErrOwnerOnly => 'ይህን ማድረግ የሚችለው የሱቁ ባለቤት ብቻ ነው።';

  @override
  String get rcptErrAdminOnly => 'ይህን ማድረግ የሚችለው የመድረኩ አስተዳዳሪ ብቻ ነው።';

  @override
  String get rcptErrShopNotFound => 'ሱቁ አልተገኘም።';

  @override
  String get rcptErrTxId => 'ትክክለኛ የግብይት ቁጥር ያስገቡ።';

  @override
  String get rcptErrAmount => 'የከፈሉትን መጠን ያስገቡ።';

  @override
  String get rcptErrDuplicate => 'ይህ የግብይት ቁጥር ቀደም ሲል ገብቷል።';

  @override
  String get rcptErrImageTooLarge => 'ፎቶው በጣም ትልቅ ነው።';

  @override
  String get rcptErrNotFound => 'ደረሰኙ አልተገኘም።';

  @override
  String get rcptErrNotOpen => 'በዚህ ደረሰኝ ላይ ቀደም ሲል ውሳኔ ተሰጥቷል።';

  @override
  String get rcptErrReason => 'ምክንያት ያስገቡ (እስከ 300 ፊደላት)።';

  @override
  String get rcptErrPricing =>
      'ዋጋዎቹን ያረጋግጡ፦ እያንዳንዱ የጊዜ ርዝመት ሙሉ ቀናትና መጠን ያስፈልገዋል፣ ረዘም ያለው ደግሞ የበለጠ ዋጋ ሊኖረው ይገባል።';

  @override
  String get rcptAdminTitle => 'የደንበኝነት ደረሰኞች';

  @override
  String get rcptAdminIntro =>
      'ኦፊሴላዊውን ደረሰኝ ከፍተው መጠኑን፣ ተቀባዩንና ቀኑን ያረጋግጡ፣ ከዚያ ያጽድቁ ወይም ውድቅ ያድርጉ።';

  @override
  String get rcptAdminOpenSection => 'የሚመረመሩ';

  @override
  String get rcptAdminDecidedSection => 'በቅርቡ ውሳኔ የተሰጠባቸው';

  @override
  String get rcptAdminEmpty => 'የሚመረመር የለም።';

  @override
  String rcptAdminLoadFailed(String error) {
    return 'ደረሰኞችን መጫን አልተቻለም፦ $error';
  }

  @override
  String rcptAdminWouldGrant(String days) {
    return '$days ይሰጣል';
  }

  @override
  String get rcptAdminTooLow => 'ከዝቅተኛው የጊዜ ርዝመት ዋጋ ያነሰ';

  @override
  String rcptAdminSubmitted(String date) {
    return '$date ተልኳል';
  }

  @override
  String get rcptAdminSubmittedLabel => 'የገባበት';

  @override
  String get rcptAdminNoImage => 'ፎቶ አልተያያዘም።';

  @override
  String get rcptAdminOpenOfficial => 'ኦፊሴላዊውን ደረሰኝ ክፈት';

  @override
  String get rcptAdminNoOfficial =>
      'ይህ የክፍያ መንገድ ኦፊሴላዊ የደረሰኝ ገጽ የለውም። ፎቶውንና የባንክ መግለጫዎን ያረጋግጡ።';

  @override
  String get rcptAdminVerifiedAmount => 'የተረጋገጠ መጠን (ብር)';

  @override
  String rcptAdminNewEnd(String date) {
    return 'አዲስ የማብቂያ ቀን፦ $date';
  }

  @override
  String get rcptApprove => 'አጽድቅ';

  @override
  String get rcptReject => 'ውድቅ አድርግ';

  @override
  String get rcptRejectTitle => 'ደረሰኙን ውድቅ አድርግ';

  @override
  String get rcptRejectReasonLabel => 'ምክንያት (ባለቤቱ ያየዋል)';

  @override
  String rcptApproved(String days, String date) {
    return 'ጸድቋል፦ $days ተጨምሯል፣ እስከ $date።';
  }

  @override
  String get rcptRejectedDone => 'ደረሰኙ ውድቅ ተደርጓል።';

  @override
  String get rcptPricingTitle => 'የደንበኝነት ዋጋዎች';

  @override
  String get rcptPricingIntro =>
      'ባለቤቶች እነዚህን ዋጋዎች ያያሉ። ክፍያው የሚሸፍነውን ረጅሙን የጊዜ ርዝመት ይገዛል።';

  @override
  String get rcptPricingDays => 'ቀናት';

  @override
  String get rcptPricingAmount => 'መጠን (ብር)';

  @override
  String get rcptPricingAddTier => 'የጊዜ ርዝመት ጨምር';

  @override
  String get rcptPricingRemoveTier => 'አስወግድ';

  @override
  String get rcptPricingTelebirr => 'የቴሌብር ተቀባይ';

  @override
  String get rcptPricingCbe => 'የንግድ ባንክ ተቀባይ';

  @override
  String get rcptPricingName => 'የሂሳቡ ስም';

  @override
  String get rcptPricingSave => 'ዋጋዎቹን አስቀምጥ';

  @override
  String get rcptPricingSaved => 'ዋጋዎቹ ተቀምጠዋል።';

  @override
  String get rcptStorageTitle => 'የደረሰኝ ፎቶዎች';

  @override
  String get rcptStorageToggle =>
      'የደረሰኝ ፎቶዎችን በFirebase Storage አስቀምጥ — Blaze ዕቅድ ያስፈልጋል';

  @override
  String get rcptStorageHelp =>
      'ሲጠፋ፦ ፎቶዎች በደረሰኙ መዝገብ ውስጥ ይቀመጣሉ (በነጻው ዕቅድ ይሰራል)። ሲበራ፦ ወደ Firebase Storage ይሄዳሉ፤ መስቀሉ ካልተሳካ ፎቶው በመዝገቡ ውስጥ ይቀመጣል።';

  @override
  String get rcptPhotoLoadFailed => 'የደረሰኙን ፎቶ መጫን አልተቻለም።';

  @override
  String get rcptPhotoRetry => 'እንደገና ይሞክሩ';

  @override
  String get rcptNotifApprovedTitle => 'የደንበኝነት ክፍያ ጸድቋል';

  @override
  String rcptNotifApprovedBody(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ቀናት ተጨምረዋል',
      one: '1 ቀን ተጨምሯል',
    );
    return '$_temp0። ደንበኝነትዎ እስከ $date ይቆያል።';
  }

  @override
  String get rcptNotifRejectedTitle => 'የደንበኝነት ክፍያ ውድቅ ተደርጓል';

  @override
  String rcptNotifRejectedBody(String transactionId, String reason) {
    return 'ግብይት $transactionId፦ $reason';
  }

  @override
  String get queueTitle => 'ወረፋ';

  @override
  String queueDashboardSubtitle(int waiting, int serving) {
    return '$waiting በመጠበቅ ላይ · $serving በአገልግሎት ላይ';
  }

  @override
  String queueSummaryWaiting(int count, int minutes) {
    return '$count ሰው በመጠበቅ ላይ፣ በግምት $minutes ደቂቃ';
  }

  @override
  String get queueSummaryEmpty => 'ማንም አይጠብቅም - በቀጥታ ይግቡ';

  @override
  String get queueJoin => 'ወረፋ ይያዙ';

  @override
  String get queueLeave => 'ወረፋውን ይልቀቁ';

  @override
  String queueLeaveConfirm(String shop) {
    return 'ከ$shop ወረፋ መውጣት ይፈልጋሉ?';
  }

  @override
  String queueYourPosition(int position, int minutes) {
    return 'በወረፋው $positionኛ ነዎት፣ በግምት $minutes ደቂቃ';
  }

  @override
  String get queueYouAreNext => 'ቀጣዩ እርስዎ ነዎት! እባክዎ ፀጉር ቤቱ ይገኙ።';

  @override
  String queueYourTurn(String barber) {
    return 'ተራዎ ደርሷል - $barber እየጠበቀዎት ነው';
  }

  @override
  String get queueYourTurnAnyBarber => 'ተራዎ ደርሷል - እባክዎ ይግቡ';

  @override
  String get queueJoined => 'ወረፋ ይዘዋል።';

  @override
  String get queueLeftMessage => 'ወረፋውን ለቀዋል።';

  @override
  String get queueSignInToJoin => 'ወረፋ ለመያዝ ይግቡ።';

  @override
  String queueJoinTitle(String shop) {
    return 'የ$shop ወረፋ ይያዙ';
  }

  @override
  String get queueJoinBody => 'ቦታዎን እንይዝልዎታለን፤ ቀጣዩ ሲሆኑ እናሳውቅዎታለን።';

  @override
  String queueWaitingHeader(int count) {
    return 'በመጠበቅ ላይ ($count)';
  }

  @override
  String queueServingHeader(int count) {
    return 'በአገልግሎት ላይ ($count)';
  }

  @override
  String get queueBarbersHeader => 'ፀጉር አስተካካዮች አሁን';

  @override
  String get queueEmpty => 'ማንም እየጠበቀ አይደለም።';

  @override
  String get queueAddWalkIn => 'ቀጥታ የመጣ ደንበኛ ያስገቡ';

  @override
  String get queueNameLabel => 'የደንበኛ ስም';

  @override
  String get queuePhoneLabel => 'ስልክ (አማራጭ)';

  @override
  String get queueServiceLabel => 'አገልግሎት (አማራጭ)';

  @override
  String get queuePreferredBarberLabel => 'የሚመረጥ ፀጉር አስተካካይ (አማራጭ)';

  @override
  String get queueAnyBarber => 'ማንኛውም ፀጉር አስተካካይ';

  @override
  String get queueNoService => 'አልተመረጠም';

  @override
  String get queueAddButton => 'ወደ ወረፋ አስገባ';

  @override
  String get queueCallNext => 'ቀጣዩን ጥራ';

  @override
  String queueCallNextFor(String barber) {
    return 'ለ$barber ቀጣዩን ጥራ';
  }

  @override
  String get queueStart => 'ጀምር';

  @override
  String get queueFinish => 'ጨርስ';

  @override
  String get queueMarkLeft => 'ሄዷል';

  @override
  String queueChooseBarber(String name) {
    return '$nameን ማን ያስተናግዳል?';
  }

  @override
  String queueBarberServing(String name) {
    return '$nameን እያስተናገደ';
  }

  @override
  String get queueBarberFree => 'ነፃ';

  @override
  String get queueBarberOff => 'ደንበኛ እየተቀበለ አይደለም';

  @override
  String queueWaitAbout(int minutes) {
    return 'በግምት $minutes ደቂቃ';
  }

  @override
  String get queueNextUp => 'ቀጣይ';

  @override
  String queuePrefers(String barber) {
    return '$barberን ይመርጣል';
  }

  @override
  String get queueRemoteBadge => 'በመተግበሪያ የገባ';

  @override
  String queueJoinedAt(String time) {
    return 'የገባበት $time';
  }

  @override
  String queueServingSince(String time) {
    return 'ከ$time ጀምሮ';
  }

  @override
  String queueNobodyForBarber(String barber) {
    return '$barberን የሚጠብቅ የለም።';
  }

  @override
  String queueNowServing(String barber, String name) {
    return '$barber አሁን $nameን እያስተናገደ ነው።';
  }

  @override
  String queueActionFailed(String error) {
    return 'ወረፋውን ማዘመን አልተቻለም፦ $error';
  }

  @override
  String get queueErrNotStaff =>
      'ወረፋውን ማስተዳደር የሚችሉት የፀጉር ቤቱ ባለቤት እና ፀጉር አስተካካዮች ብቻ ናቸው።';

  @override
  String get queueErrCustomersOnly => 'ከመተግበሪያው ወረፋ መያዝ የሚችሉት ደንበኞች ብቻ ናቸው።';

  @override
  String queueErrNameRequired(int max) {
    return 'ስም ያስገቡ (እስከ $max ፊደላት)።';
  }

  @override
  String queueErrBarberBusy(String name) {
    return '$name ሌላ ደንበኛ እያስተናገደ ነው። መጀመሪያ ያንን ይጨርሱ።';
  }

  @override
  String get queueErrNotWaiting => 'ይህ ሰው ከአሁን በኋላ እየጠበቀ አይደለም።';

  @override
  String get queueErrNotServing => 'ይህ ሰው በአገልግሎት ላይ አይደለም።';

  @override
  String get reportsTitle => 'ሪፖርቶች';

  @override
  String get reportsOpenButton => 'ሪፖርቶችና ደንበኞች';

  @override
  String get reportsOverviewTab => 'አጠቃላይ እይታ';

  @override
  String get reportsClientsTab => 'ደንበኞች';

  @override
  String get reportsMonthLabel => 'ወር';

  @override
  String get reportsBookings => 'ቀጠሮዎች';

  @override
  String get reportsCompleted => 'የተጠናቀቁ';

  @override
  String get reportsCancelled => 'የተሰረዙ';

  @override
  String get reportsNoShows => 'ያልመጡ';

  @override
  String get reportsRevenue => 'ገቢ';

  @override
  String get reportsRevenueTrend => 'ገቢ፣ ያለፉት 6 ወራት';

  @override
  String get reportsTopServices => 'ብዙ የተሰሩ አገልግሎቶች';

  @override
  String get reportsBarberPerformance => 'የፀጉር አስተካካዮች አፈጻጸም';

  @override
  String reportsCompletedCount(int count) {
    return '$count ተጠናቀዋል';
  }

  @override
  String get reportsNoBookingsMonth => 'በዚህ ወር ምንም ቀጠሮ የለም።';

  @override
  String get reportsNoCompletedMonth => 'በዚህ ወር እስካሁን የተጠናቀቀ ቀጠሮ የለም።';

  @override
  String get reportsNoClients => 'እስካሁን ደንበኛ የለም።';

  @override
  String reportsClientVisits(int count) {
    return '$count ጉብኝት';
  }

  @override
  String reportsClientNoShows(int count) {
    return '$count ጊዜ አልመጡም';
  }

  @override
  String reportsClientCancelled(int count) {
    return '$count ተሰርዘዋል';
  }

  @override
  String reportsLastVisit(String date) {
    return 'የመጨረሻ ጉብኝት $date';
  }

  @override
  String get reportsNoVisitYet => 'እስካሁን የተጠናቀቀ ጉብኝት የለም';

  @override
  String get reportsLoadFailed =>
      'ሪፖርቶችን መጫን አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get reportsRetry => 'እንደገና ይሞክሩ';

  @override
  String get reportsUpdatedNote =>
      'አሃዞቹ እያንዳንዱ የቀጠሮ ለውጥ ከተደረገ ከጥቂት ሰከንዶች በኋላ ይዘመናሉ።';

  @override
  String freePlanReportsFromBookings(int days) {
    return 'ባለፉት $days ቀናት ቀጠሮዎች ላይ የተመሰረተ።';
  }

  @override
  String get freePlanRequestNoAnswer => 'ምላሽ አልተሰጠም';

  @override
  String get appTitle => 'Crown & Blade - የፀጉር ቤት ቀጠሮ';

  @override
  String get brandUpper => 'CROWN & BLADE';

  @override
  String get brandName => 'Crown & Blade';

  @override
  String get introTagline => 'በአዲስ አበባ የፀጉር አስተካካይዎን ቀጠሮ ይያዙ';

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
  String barberLabel(String name) {
    return 'ፀጉር አስተካካይ፦ $name';
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
  String get statusNoShow => 'አልመጡም';

  @override
  String get rescheduleAction => 'ቀጠሮ ቀይር';

  @override
  String get rescheduleTitle => 'አዲስ ሰዓት ይምረጡ';

  @override
  String rescheduleCurrent(String when) {
    return 'አሁን ያለው ሰዓት፦ $when';
  }

  @override
  String get rescheduleConfirm => 'ቀጠሮውን አዛውር';

  @override
  String rescheduleDone(String when) {
    return 'ቀጠሮዎ ወደ $when ተዛውሯል።';
  }

  @override
  String rescheduleLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ጊዜ መቀየር ይቻላል',
      zero: 'ከዚህ በኋላ መቀየር አይቻልም',
    );
    return '$_temp0';
  }

  @override
  String get rescheduledBadge => 'ተዛውሯል';

  @override
  String reschedulePolicyNote(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'ቀጠሮው ከመጀመሩ $hours ሰዓት በፊት ድረስ',
      zero: 'ቀጠሮው እስኪጀምር ድረስ',
    );
    return '$_temp0 በነፃ መቀየር ወይም መሰረዝ ይችላሉ።';
  }

  @override
  String get rescheduleCallShop =>
      'ይህን ቀጠሮ በመተግበሪያው ለመቀየር ጊዜው አልፏል። እባክዎ ፀጉር ቤቱን ይደውሉ።';

  @override
  String get rescheduleErrNotChangeable => 'ይህ ቀጠሮ ከአሁን በኋላ ሊቀየር አይችልም።';

  @override
  String rescheduleErrCancelCutoff(int hours) {
    return 'ቀጠሮዎን መሰረዝ የሚችሉት ከመጀመሩ $hours ሰዓት በፊት ብቻ ነው። እባክዎ ፀጉር ቤቱን ይደውሉ።';
  }

  @override
  String rescheduleErrCutoff(int hours) {
    return 'ቀጠሮን ማዛወር የሚቻለው ከመጀመሩ $hours ሰዓት በፊት ብቻ ነው። እባክዎ ፀጉር ቤቱን ይደውሉ።';
  }

  @override
  String rescheduleErrLimit(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'ይህ ቀጠሮ ፀጉር ቤቱ የሚፈቅደውን ከፍተኛ $max ጊዜ ተዛውሯል።',
      zero: 'ይህ ፀጉር ቤት ቀጠሮ መቀየር አይፈቅድም።',
    );
    return '$_temp0';
  }

  @override
  String get rescheduleErrSameTime => 'አሁን ካለዎት ሰዓት የተለየ ሰዓት ይምረጡ።';

  @override
  String get noShowAction => 'አልመጡም';

  @override
  String get noShowConfirmTitle => 'እንዳልመጡ ይመዝገብ?';

  @override
  String noShowConfirmBody(String name) {
    return '$name ወደዚህ ቀጠሮ አልመጡም። ሰዓቱ እንደተያዘ ይቆያል።';
  }

  @override
  String get noShowErrTooEarly =>
      'እንዳልመጡ መመዝገብ የሚቻለው የቀጠሮው ሰዓት ከደረሰ በኋላ ብቻ ነው።';

  @override
  String get policySectionTitle => 'የቀጠሮ ደንብ';

  @override
  String get policyCutoffLabel => 'የመሰረዣ ገደብ';

  @override
  String get policyCutoffHelp =>
      'ደንበኞች ቀጠሮው ሊጀምር ይህን ያህል ሰዓት ሲቀረው መሰረዝም ሆነ ማዛወር አይችሉም። እርስዎና ፀጉር አስተካካዮችዎ ግን አሁንም መሰረዝ ይችላሉ።';

  @override
  String policyHoursValue(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ሰዓት በፊት',
      zero: 'እስከ መጀመሪያው',
    );
    return '$_temp0';
  }

  @override
  String get policyMaxReschedulesLabel => 'ለአንድ ቀጠሮ የሚፈቀድ የመቀየር ብዛት';

  @override
  String policyMaxReschedulesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ጊዜ',
      one: 'አንድ ጊዜ',
      zero: 'መቀየር አይቻልም',
    );
    return '$_temp0';
  }

  @override
  String get policySave => 'ደንቡን አስቀምጥ';

  @override
  String get policySaved => 'የቀጠሮ ደንቡ ተቀምጧል።';

  @override
  String policyErrCutoff(int max) {
    return 'የመሰረዣ ገደቡ ከ0 እስከ $max ሰዓት መሆን አለበት።';
  }

  @override
  String policyErrMaxReschedules(int max) {
    return 'የሚፈቀደው የመቀየር ብዛት ከ0 እስከ $max መሆን አለበት።';
  }

  @override
  String get timeOffTitle => 'እረፍት';

  @override
  String get timeOffAdd => 'እረፍት ጨምር';

  @override
  String get timeOffWholeDay => 'ሙሉ ቀን';

  @override
  String get timeOffHours => 'የተወሰኑ ሰዓታት';

  @override
  String get timeOffDay => 'ቀን';

  @override
  String get timeOffFrom => 'ከ';

  @override
  String get timeOffTo => 'እስከ';

  @override
  String get timeOffReasonLabel => 'ማስታወሻ (አማራጭ)';

  @override
  String get timeOffEmpty => 'የታቀደ እረፍት የለም።';

  @override
  String get timeOffSaved => 'እረፍቱ ተጨምሯል። ደንበኞች እነዚህን ሰዓቶች መያዝ አይችሉም።';

  @override
  String get timeOffRemove => 'እረፍቱን አስወግድ';

  @override
  String get timeOffRemoved => 'እረፍቱ ተወግዷል።';

  @override
  String get timeOffRemoveConfirm =>
      'ይህ እረፍት ይወገድ? ደንበኞች እነዚህን ሰዓቶች እንደገና መያዝ ይችላሉ።';

  @override
  String timeOffRange(String day, String from, String to) {
    return '$day፣ $from - $to';
  }

  @override
  String timeOffNotWorking(String name) {
    return '$name በዚህ ቀን አይሰሩም።';
  }

  @override
  String get timeOffSlotLabel => 'እረፍት';

  @override
  String get timeOffErrRange =>
      'በአንድ ቀን ውስጥ ያለ፣ ማብቂያው ከመጀመሪያው በኋላ የሆነ ጊዜ ይምረጡ።';

  @override
  String get timeOffErrPast => 'የእረፍት ጊዜው ወደፊት የሚያበቃ መሆን አለበት።';

  @override
  String timeOffErrReasonTooLong(int max) {
    return 'ማስታወሻው ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String get timeOffErrConflict =>
      'ይህ ጊዜ ከቀጠሮ ወይም ከሌላ እረፍት ጋር ይጋጫል። መጀመሪያ ያንን ቀጠሮ ያዛውሩ ወይም ይሰርዙ።';

  @override
  String get timeOffErrNotAllowed => 'እረፍት ማስተዳደር የሚችሉት ለራስዎ መርሐ ግብር ብቻ ነው።';

  @override
  String get timeOffSeveralDays => 'ብዙ ቀናት';

  @override
  String get vacationFromDate => 'የመጀመሪያ ቀን';

  @override
  String get vacationToDate => 'የመጨረሻ ቀን';

  @override
  String get vacationFirstDayFrom => 'የመጀመሪያው ቀን የሚጀምረው';

  @override
  String get vacationLastDayUntil => 'የመጨረሻው ቀን የሚያበቃው';

  @override
  String get vacationStartOfWork => 'የሥራ መጀመሪያ';

  @override
  String get vacationEndOfWork => 'የሥራ መጨረሻ';

  @override
  String vacationMaxDays(int days, int max) {
    return '$days ቀናት ተመርጠዋል (ቢበዛ $max)።';
  }

  @override
  String get vacationLabel => 'የእረፍት ጊዜ';

  @override
  String vacationRange(String from, String to) {
    return '$from - $to';
  }

  @override
  String get vacationConflictsTitle => 'በዚህ እረፍት ውስጥ ያሉ ቀጠሮዎች';

  @override
  String vacationConflictsBody(int count) {
    return '$count መጪ ቀጠሮዎች በዚህ እረፍት ውስጥ ይወድቃሉ። ሰርዘው ለእያንዳንዱ ደንበኛ ያሳውቁ፣ ወይም ያቆዩዋቸው (ሰዓቶቻቸው እንደተያዙ ይቆያሉ)።';
  }

  @override
  String get vacationPaidRefund => 'ተከፍሏል፦ ተመላሽ ክፍያ ይመዘገባል';

  @override
  String get vacationCancelAndNotify => 'ሰርዝና ደንበኞችን አሳውቅ';

  @override
  String get vacationKeepBookings => 'ቀጠሮዎቹን አቆይ';

  @override
  String get vacationSaved => 'የእረፍት ጊዜው ተቀምጧል። ደንበኞች እነዚህን ቀናት መያዝ አይችሉም።';

  @override
  String vacationSavedCancelled(int count) {
    return 'የእረፍት ጊዜው ተቀምጧል። $count ቀጠሮዎች ተሰርዘው ደንበኞቻቸው ተነግሯቸዋል።';
  }

  @override
  String vacationRemoveConfirm(String range) {
    return 'ሙሉው የእረፍት ጊዜ $range ይወገድ? ደንበኞች እነዚህን ቀናት እንደገና መያዝ ይችላሉ።';
  }

  @override
  String vacationErrTooLong(int max) {
    return 'የእረፍት ጊዜ ቢበዛ $max ቀናት ሊሆን ይችላል።';
  }

  @override
  String get vacationErrNothingToBlock => 'በእነዚህ ቀናት የሚዘጋ የሥራ ሰዓት የለም።';

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
  String get earlyFinishBannerTitle => 'ፀጉር አስተካካይዎ አሁን ነፃ ናቸው — ቀድመው ይምጡ';

  @override
  String earlyFinishBannerBody(String barber, String time) {
    return '$barber ቀድመው ጨርሰዋል። ከ$time ቀጠሮዎ በፊት መምጣት ይችላሉ።';
  }

  @override
  String get earlyFinishCallShop => 'ወደ ፀጉር ቤቱ ይደውሉ';

  @override
  String get earlyFinishDirections => 'አቅጣጫ';

  @override
  String earlyFinishNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ለ$count ደንበኞች ቀድመው መምጣት እንደሚችሉ ተነግሯል',
      one: 'ለ1 ደንበኛ ቀድመው መምጣት እንደሚችሉ ተነግሯል',
    );
    return '$_temp0';
  }

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
  String get mobileNumber => 'የሞባይል ቁጥር';

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
  String get authErrNetwork => 'የኢንተርኔት ግንኙነት የለም።';

  @override
  String get authErrNotEnabled => 'በGoogle መግባት ለዚህ መተግበሪያ ገና አልነቃም።';

  @override
  String get authErrGeneric => 'የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authSubtitle => 'ይግቡ ወይም አዲስ መለያ ይፍጠሩ';

  @override
  String get continueWithGoogle => 'በGoogle ይቀጥሉ';

  @override
  String get googleSignInNotice =>
      'ስምዎን እና የኢሜይል አድራሻዎን ቀጠሮዎችዎን ለማስተዳደር ብቻ እንጠቀማለን።';

  @override
  String demoContinueAs(String name) {
    return 'እንደ $name ይቀጥሉ';
  }

  @override
  String get demoGoogleNotice => 'የሙከራ ሁነታ፦ እውነተኛ የGoogle መለያ ጥቅም ላይ አይውልም።';

  @override
  String get useDifferentAccount => 'ሌላ መለያ ተጠቀም';

  @override
  String get profilePhoneHelper => 'ለኤስኤምኤስ የቀጠሮ ማስታወሻዎች እና ለክፍያ።';

  @override
  String get authErrPopupBlocked =>
      'የመግቢያ መስኮቱ ታግዷል። ለዚህ ድረ-ገጽ ብቅ-ባይ መስኮቶችን ይፍቀዱ እና እንደገና ይሞክሩ።';

  @override
  String get authErrAccountExists => 'በዚህ ኢሜይል የተፈጠረ መለያ ሌላ የመግቢያ ዘዴ ይጠቀማል።';

  @override
  String get authErrUnauthorizedDomain => 'ይህ የድር አድራሻ ለመግቢያ አልተፈቀደም።';

  @override
  String get authErrUserDisabled => 'ይህ መለያ ታግዷል። እባክዎ ድጋፍ ሰጪን ያነጋግሩ።';

  @override
  String authErrWithCode(String code) {
    return 'መግባት አልተሳካም ($code)።';
  }

  @override
  String get errInvalidEmail => 'ትክክለኛ የኢሜይል አድራሻ ያስገቡ።';

  @override
  String get errInvalidOwnerEmail => 'ለባለቤቱ ትክክለኛ የGmail / ኢሜይል አድራሻ ያስገቡ።';

  @override
  String errEmailAlreadyStaff(String role) {
    return 'ይህ የኢሜይል አድራሻ ቀድሞውኑ የ$role መለያ ነው።';
  }

  @override
  String get errGoogleEmailMissing => 'የGoogle መለያዎ የተረጋገጠ የኢሜይል አድራሻ የለውም።';

  @override
  String get ownerEmailLogin => 'የባለቤቱ Gmail አድራሻ (ለመግቢያ) *';

  @override
  String get ownerEmailHelper =>
      'ባለቤቱ ፀጉር ቤቱን ለማስተዳደር በዚህ ኢሜይል (በGoogle ወይም በኢሜይል እና የይለፍ ቃል) ይገባሉ።';

  @override
  String get emailForLogin => 'የኢሜይል አድራሻ (ለመግቢያ)';

  @override
  String get barberEmailHelper =>
      'አማራጭ። ፀጉር አስተካካዩ በዚህ ኢሜይል (በGoogle ወይም በኢሜይል እና የይለፍ ቃል) ይገባሉ።';

  @override
  String get barberMobileOptional => 'የሞባይል ቁጥር (አማራጭ)';

  @override
  String get barberPhoneHelper =>
      'የግል ነው። ደንበኞች የሚያዩት ቀጠሮአቸው ከተረጋገጠ በኋላ ብቻ ነው።';

  @override
  String get barberPhoneNone => 'የሞባይል ቁጥር የለም';

  @override
  String get barberPhoneEdit => 'የሞባይል ቁጥር ያስተካክሉ';

  @override
  String get barberPhoneSaved => 'የሞባይል ቁጥሩ ተቀምጧል';

  @override
  String callBarberAction(String name) {
    return 'ለ$name ይደውሉ';
  }

  @override
  String barberPhoneOnBooking(String phone) {
    return 'የፀጉር አስተካካዩ ስልክ፦ $phone';
  }

  @override
  String get invalidEmailShort => 'ትክክለኛ ኢሜይል ያስገቡ';

  @override
  String get adminSubtitle => 'የመድረክ ሲስተም አስተዳደር';

  @override
  String get adminShopsHeroTitle => 'በመድረኩ ላይ ያሉ ፀጉር ቤቶች';

  @override
  String get adminShopsMetricBookable => 'ቀጠሮ የሚቀበሉ';

  @override
  String get adminShopsMetricSuspended => 'የታገዱ';

  @override
  String get adminShopsFilterActive => 'ንቁ';

  @override
  String get adminShopsFilterSuspended => 'የታገዱ';

  @override
  String get adminShopsFilterUnverified => 'ያልተረጋገጡ';

  @override
  String get adminShopsEdit => 'አስተካክል';

  @override
  String get adminShopsEditTitle => 'ፀጉር ቤቱን አስተካክል';

  @override
  String get adminShopsSectionProfile => 'የፀጉር ቤቱ መረጃ';

  @override
  String get adminShopsSectionPlatform => 'ማረጋገጫ እና የደንበኝነት ምዝገባ';

  @override
  String get adminShopsSectionOwner => 'ባለቤት';

  @override
  String get adminShopsSectionStatus => 'ተገኝነት';

  @override
  String get adminShopsFieldName => 'የፀጉር ቤቱ ስም';

  @override
  String get adminShopsFieldAddress => 'አድራሻ';

  @override
  String get adminShopsFieldSubCity => 'ክፍለ ከተማ';

  @override
  String get adminShopsFieldLandmark => 'የሚታወቅ ቦታ (አማራጭ)';

  @override
  String get adminShopsFieldPhone => 'የፀጉር ቤቱ ስልክ';

  @override
  String get adminShopsFieldDescription => 'መግለጫ';

  @override
  String adminShopsHoursReadOnly(String days, String hours) {
    return 'የሥራ ሰዓት፦ $days $hours · በፀጉር ቤቱ ባለቤት የሚወሰን';
  }

  @override
  String get adminShopsFieldVerified => 'የተረጋገጠ አጋር';

  @override
  String get adminShopsFieldVerifiedHint => 'ለደንበኞች የማረጋገጫ ምልክቱን ያሳያል';

  @override
  String get adminShopsFieldPlan => 'ዕቅድ';

  @override
  String get adminShopsFieldStatus => 'የደንበኝነት ሁኔታ';

  @override
  String get adminShopsFieldEndsAt => 'የደንበኝነት ማብቂያ';

  @override
  String get adminShopsNoEndDate => 'የማብቂያ ቀን የለም';

  @override
  String get adminShopsClearDate => 'ቀኑን አጥፋ';

  @override
  String get adminShopsOverrideHint =>
      'የአስተዳዳሪ ማስተካከያ፦ እዚህ የሚደረጉ ለውጦች በቀጥታ በፀጉር ቤቱ ላይ ይቀመጣሉ።';

  @override
  String get adminShopsSave => 'ለውጦቹን አስቀምጥ';

  @override
  String get adminShopsSaved => 'ፀጉር ቤቱ ተቀምጧል';

  @override
  String adminShopsOwnerSignedUp(String email) {
    return 'ተመዝግቧል · $email';
  }

  @override
  String adminShopsOwnerInvitePending(String email) {
    return 'ግብዣ በመጠባበቅ ላይ፦ $email ሲገባ የባለቤት ፈቃድ ያገኛል';
  }

  @override
  String get adminShopsOwnerNone => 'ባለቤት አልተመደበም';

  @override
  String get adminShopsStatusActive => 'ንቁ';

  @override
  String get adminShopsStatusAdminSuspended => 'በአስተዳዳሪ ታግዷል';

  @override
  String get adminShopsStatusUnpaid => 'የደንበኝነት ምዝገባው ታግዷል';

  @override
  String adminShopsSuspendedSince(String date, String reason) {
    return '$date ታግዷል፦ $reason';
  }

  @override
  String get adminShopsSuspend => 'ፀጉር ቤቱን አግድ';

  @override
  String get adminShopsReactivate => 'ፀጉር ቤቱን እንደገና አንቃ';

  @override
  String adminShopsSuspendTitle(String shop) {
    return '$shop ይታገድ?';
  }

  @override
  String get adminShopsSuspendBody =>
      'ደንበኞች ይህን ፀጉር ቤት አያዩትም፤ ቀጠሮም መያዝ አይችሉም። ያሉት ቀጠሮዎች ይቆያሉ። ባለቤቱ ምክንያትዎን ያያል።';

  @override
  String get adminShopsReasonLabel => 'ምክንያት (ለባለቤቱ ይታያል)';

  @override
  String adminShopsSuspendedToast(String shop) {
    return '$shop ታግዷል';
  }

  @override
  String adminShopsReactivateTitle(String shop) {
    return '$shop እንደገና ይንቃ?';
  }

  @override
  String get adminShopsReactivateBody =>
      'ደንበኞች ይህን ፀጉር ቤት እንደገና ማግኘትና ቀጠሮ መያዝ ይችላሉ።';

  @override
  String adminShopsReactivatedToast(String shop) {
    return '$shop እንደገና ነቅቷል';
  }

  @override
  String adminShopsDeleteBody(String shop) {
    return 'ይህ $shopን በቋሚነት ይሰርዛል። ለማረጋገጥ የፀጉር ቤቱን ስም ይጻፉ።';
  }

  @override
  String get adminShopsDeleteTypeName => 'የፀጉር ቤቱ ስም';

  @override
  String get adminShopsDeleteWillHeading => 'ምን ይከሰታል';

  @override
  String adminShopsDeleteListBarbers(int count) {
    return '$count የፀጉር አስተካካይ መገለጫዎች ከእረፍት ጊዜያቸውና ከተያዙ ሰዓቶቻቸው ጋር ይሰረዛሉ';
  }

  @override
  String adminShopsDeleteListServices(int count) {
    return '$count አገልግሎቶች ይሰረዛሉ';
  }

  @override
  String adminShopsDeleteListStaff(int count) {
    return '$count የሰራተኛ መለያዎች (ባለቤትና ፀጉር አስተካካዮች) የደንበኛ መለያ ይሆናሉ';
  }

  @override
  String adminShopsDeleteListInvites(int count) {
    return 'በመጠባበቅ ላይ ያሉ $count ግብዣዎች ይሰረዛሉ';
  }

  @override
  String adminShopsDeleteListBookings(int count) {
    return '$count መጪ ቀጠሮዎች ይሰረዛሉ፤ ደንበኞቻቸውም ይነገራቸዋል';
  }

  @override
  String get adminShopsDeleteListBookingsUnknown =>
      'መጪ ቀጠሮዎች ይሰረዛሉ፤ ደንበኞቻቸውም ይነገራቸዋል';

  @override
  String get adminShopsDeleteListOther =>
      'የወረፋ ዝርዝሩ፣ ግምገማዎች፣ የሰራተኛ ክፍያዎችና ስታቲስቲክስ ይሰረዛሉ';

  @override
  String get adminShopsDeleteListKept =>
      'ያለፉ ቀጠሮዎች ለታሪክ ይቀመጣሉ። ሰራተኞቹ አሁንም እንደ ደንበኛ መግባት ይችላሉ።';

  @override
  String get adminShopsDeleteStepPrepare => 'ፀጉር ቤቱን በማገድ ላይ';

  @override
  String get adminShopsDeleteStepBookings => 'መጪ ቀጠሮዎችን በመሰረዝ ላይ';

  @override
  String get adminShopsDeleteStepStaff => 'ሰራተኞችን ወደ ደንበኛ መለያ በመቀየር ላይ';

  @override
  String get adminShopsDeleteStepData =>
      'ፀጉር አስተካካዮችን፣ አገልግሎቶችንና የፀጉር ቤቱን መረጃ በመሰረዝ ላይ';

  @override
  String get adminShopsDeleteStepShop => 'ፀጉር ቤቱን በመሰረዝ ላይ';

  @override
  String adminShopsDeleteProgress(int step, int total, String label) {
    return 'ደረጃ $step ከ$total፦ $label…';
  }

  @override
  String adminShopsDeleteFailed(String step) {
    return '«$step» መጨረስ አልተቻለም። የተሰራው ይቀመጣል፤ ለመቀጠል «እንደገና ሞክር»ን ይጫኑ።';
  }

  @override
  String get adminShopsDeleteRetry => 'እንደገና ሞክር';

  @override
  String get shopRemovedNoticeTitle => 'ፀጉር ቤትዎ ተወግዷል';

  @override
  String get shopRemovedNoticeBody => 'Crown & Bladeን እንደ ደንበኛ መጠቀም መቀጠል ይችላሉ።';

  @override
  String get adminShopsErrReasonRequired => 'ምክንያት ያስገቡ።';

  @override
  String adminShopsErrReasonTooLong(int max) {
    return 'ምክንያቱ ከ$max ቁምፊዎች ያልበለጠ ይሁን።';
  }

  @override
  String get adminShopsErrNameRequired => 'የፀጉር ቤቱን ስም ያስገቡ።';

  @override
  String get adminShopsErrNameTooLong => 'የፀጉር ቤቱ ስም በጣም ረጅም ነው።';

  @override
  String get adminShopsErrAddressRequired => 'አድራሻውን ያስገቡ።';

  @override
  String get adminShopsErrTextTooLong => 'ከጽሑፉ የተወሰነው በጣም ረጅም ነው።';

  @override
  String get adminShopsErrPlan => 'ያልታወቀ ዕቅድ።';

  @override
  String get adminShopsErrNotFound => 'ይህ ፀጉር ቤት ከእንግዲህ የለም።';

  @override
  String get adminShopsErrNotAdmin => 'ይህን ማድረግ የሚችለው የመድረኩ አስተዳዳሪ ብቻ ነው።';

  @override
  String get adminShopsErrNameMismatch => 'ስሙ አይዛመድም።';

  @override
  String get adminShopsUnavailableTitle => 'ለጊዜው አይገኝም';

  @override
  String get adminShopsUnavailableBody =>
      'ይህ ፀጉር ቤት አሁን ቀጠሮ እየተቀበለ አይደለም። ያሉዎት ቀጠሮዎች አይነኩም።';

  @override
  String get adminShopsOwnerBannerTitle => 'ፀጉር ቤትዎ በመድረኩ ታግዷል';

  @override
  String get adminShopsOwnerBannerBody =>
      'እንደገና እስኪነቃ ድረስ ደንበኞች ፀጉር ቤትዎን ማግኘትም ሆነ ቀጠሮ መያዝ አይችሉም። ያሉት ቀጠሮዎች ይቆያሉ።';

  @override
  String adminShopsOwnerBannerReason(String reason) {
    return 'ምክንያት፦ $reason';
  }

  @override
  String get adminShopsOwnerBannerContact => 'እንደገና ለማንቃት የመድረኩን አስተዳዳሪ ያነጋግሩ።';

  @override
  String get deleteShopTitle => 'ፀጉር ቤቱ ይሰረዝ?';

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
  String get searchShopsAdminHint => 'ፀጉር ቤቶችን በስም፣ በአድራሻ ወይም በክፍለ ከተማ ይፈልጉ...';

  @override
  String get filterVerifiedPartners => 'የተረጋገጡ አጋሮች';

  @override
  String registeredBarbershopsCount(int count) {
    return 'የተመዘገቡ ፀጉር ቤቶች ($count)';
  }

  @override
  String get noRegisteredShops => 'ምንም የተመዘገበ ፀጉር ቤት አልተገኘም';

  @override
  String get noRegisteredShopsHint =>
      'አዲስ ፀጉር ቤት ወደ መድረኩ ለመጨመር \"ፀጉር ቤት መዝግብ\"ን ይንኩ።';

  @override
  String ownerInvitePending(String name, String email) {
    return '$name ($email) - ግብዣ በመጠባበቅ ላይ';
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
  String get registerNewBarbershop => 'አዲስ ፀጉር ቤት መዝግብ';

  @override
  String registeredShopSnack(String shop, String email) {
    return '\"$shop\" ተመዝግቧል። ባለቤቱ አሁን በ$email መግባት ይችላሉ።';
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
  String get adminRegisterHoursOwnerNote =>
      'የሥራ ሰዓቱን የፀጉር ቤቱ ባለቤት ከገባ በኋላ ያስቀምጣል።';

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
  String get allSubCities => 'ሁሉም ክፍለ ከተማዎች';

  @override
  String get subCityFilterTooltip => 'ፀጉር ቤቶችን በክፍለ ከተማ ያጣሩ';

  @override
  String subCityOptionCount(String name, int count) {
    return '$name ($count)';
  }

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
  String get reportsBusyHoursTab => 'የተጨናነቁ ሰዓታት';

  @override
  String get reportsNoShowsTab => 'ያልመጡ';

  @override
  String get busyRangeLast30 => 'ያለፉት 30 ቀናት';

  @override
  String get busyRangeLast90 => 'ያለፉት 90 ቀናት';

  @override
  String get busyRangeMonth => 'ወር';

  @override
  String get busyHoursTitle => 'ቀጠሮዎች በቀን እና በሰዓት';

  @override
  String get busyHoursNote =>
      'የአዲስ አበባ ሰዓት። እያንዳንዱ ቀጠሮ በሚጀምርበት ሰዓት ይቆጠራል። የተሰረዙ ቀጠሮዎች አይቆጠሩም።';

  @override
  String get busyBusiestDay => 'በጣም የተጨናነቀ ቀን';

  @override
  String get busyBusiestTime => 'በጣም የተጨናነቀ ሰዓት';

  @override
  String get busyQuietestHour => 'በጣም ጸጥ ያለ ሰዓት';

  @override
  String get busyTotalBookings => 'ቀጠሮዎች';

  @override
  String get busyNoBookings => 'በዚህ ጊዜ ውስጥ ቀጠሮ የለም።';

  @override
  String get busyLegendFewer => 'ጥቂት';

  @override
  String get busyLegendMore => 'ብዙ';

  @override
  String get busyLoadFailed => 'የዚህን ወር ቀጠሮዎች መጫን አልተቻለም።';

  @override
  String busyCellSemantics(String day, String hour, int count) {
    return '$day $hour: $count ቀጠሮዎች';
  }

  @override
  String get noShowsAutoBlockTitle => 'በተደጋጋሚ የማይመጡትን በራስ-ሰር አግድ';

  @override
  String noShowsAutoBlockOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'አንድ ደንበኛ በፀጉር ቤትዎ $count ጊዜ ሳይመጣ ሲቀር ይታገዳል።',
    );
    return '$_temp0';
  }

  @override
  String get noShowsAutoBlockOff =>
      'ጠፍቷል። ደንበኛን በተደጋጋሚ ሳይመጣ ሲቀር በራስ-ሰር ለማገድ ያብሩት።';

  @override
  String get noShowsAutoBlockLimit => 'ከመታገድ በፊት ያልመጡበት ብዛት';

  @override
  String get noShowsDecrease => 'ቀንስ';

  @override
  String get noShowsIncrease => 'ጨምር';

  @override
  String get noShowsSettingsUnavailable => 'የራስ-ሰር እገዳ ቅንብሩን መጫን አልተቻለም።';

  @override
  String get noShowsSearchHint => 'ደንበኞችን በስም ይፈልጉ';

  @override
  String get noShowsFilterAll => 'ሁሉም';

  @override
  String noShowsFilterBlocked(int count) {
    return 'የታገዱ ($count)';
  }

  @override
  String get noShowsListTitle => 'ደንበኞች ባለመምጣት መጠን';

  @override
  String get noShowsRateHelp => 'ያለመምጣት መጠን፦ ከተጠናቀቁ እና ካመለጡ ቀጠሮዎች ውስጥ ያመለጡት።';

  @override
  String get noShowsNoCustomers => 'እስካሁን ደንበኛ የለም።';

  @override
  String get noShowsNoMatch => 'ከፍለጋዎ ጋር የሚዛመድ ደንበኛ የለም።';

  @override
  String noShowsWindowNote(int days) {
    return 'ቁጥሮቹ ያለፉትን $days ቀናት ቀጠሮዎች ይሸፍናሉ።';
  }

  @override
  String noShowsCustomerStats(
      int bookings, int completed, int cancelled, int noShows) {
    return 'ቀጠሮዎች $bookings · የተጠናቀቁ $completed · የተሰረዙ $cancelled · ያልመጡ $noShows';
  }

  @override
  String noShowsRateSemantics(int percent) {
    return 'ያለመምጣት መጠን $percent%';
  }

  @override
  String get customerBlockedChip => 'ታግዷል';

  @override
  String get customerAutoBlockedChip => 'በራስ-ሰር ታግዷል';

  @override
  String get customerBlockAction => 'አግድ';

  @override
  String get customerUnblockAction => 'እገዳ አንሳ';

  @override
  String customerBlockTitle(String name) {
    return '$name ይታገዱ?';
  }

  @override
  String get customerBlockBody =>
      'በፀጉር ቤትዎ ቀጠሮ መያዝም ሆነ ወረፋ መግባት አይችሉም። የሚያዩት መልዕክት፦ \"ይህ ፀጉር ቤት አሁን ቀጠሮዎን መቀበል አይችልም። እባክዎ ፀጉር ቤቱን ያነጋግሩ።\"';

  @override
  String get customerBlockReasonLabel => 'ማስታወሻ (አማራጭ)';

  @override
  String get customerBlockReasonHelper => 'ለእርስዎ መዝገብ። መተግበሪያው ለደንበኛው አያሳየውም።';

  @override
  String customerBlockCancelUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'የሚመጡትን $count ቀጠሮዎቻቸውንም ሰርዝ',
    );
    return '$_temp0';
  }

  @override
  String get customerBlockCancelPaidNote =>
      'የተከፈለባቸው ቀጠሮዎች ለተመላሽ ገንዘብ ምልክት ይደረግባቸዋል።';

  @override
  String get customerBlockKeepNote => 'እዚህ ካልሰረዟቸው በስተቀር የሚመጡት ቀጠሮዎቻቸው ይቆያሉ።';

  @override
  String customerBlockedSnack(String name) {
    return '$name ታግደዋል።';
  }

  @override
  String customerBlockedCancelledSnack(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name ታግደዋል። $count ቀጠሮዎች ተሰርዘዋል።',
    );
    return '$_temp0';
  }

  @override
  String customerUnblockTitle(String name) {
    return 'የ$name እገዳ ይነሳ?';
  }

  @override
  String get customerUnblockBody => 'በፀጉር ቤትዎ እንደገና ቀጠሮ መያዝ እና ወረፋ መግባት ይችላሉ።';

  @override
  String customerUnblockedSnack(String name) {
    return 'የ$name እገዳ ተነስቷል።';
  }

  @override
  String customerBlockedOn(String date) {
    return '$date ታግዷል';
  }

  @override
  String customerBlockNote(String reason) {
    return 'ማስታወሻ፦ $reason';
  }

  @override
  String customerAutoBlockedAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ከ$count ያለመምጣት በኋላ በራስ-ሰር ታግዷል',
    );
    return '$_temp0';
  }

  @override
  String get customerUnknownName => 'ደንበኛ';

  @override
  String get errCustomerBlockedAtShop =>
      'ይህ ፀጉር ቤት አሁን ቀጠሮዎን መቀበል አይችልም። እባክዎ ፀጉር ቤቱን ያነጋግሩ።';

  @override
  String get errCustomerBlockNotAllowed =>
      'ደንበኞችን ማገድ ወይም እገዳ ማንሳት የሚችለው የፀጉር ቤቱ ባለቤት ብቻ ነው።';

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
  String get yourBarbersTitle => 'የእርስዎ ፀጉር አስተካካዮች';

  @override
  String get yourBarbersSubtitle => 'ተወዳጆች እና የቅርብ ጊዜ ጉብኝቶች';

  @override
  String get bookAgain => 'እንደገና ቀጠሮ ያዝ';

  @override
  String bookAgainWith(String name) {
    return 'ከ$name ጋር እንደገና ቀጠሮ ያዝ';
  }

  @override
  String rebookLastService(String service) {
    return 'ባለፈው ጊዜ፦ $service';
  }

  @override
  String get rebookFavoriteTag => 'ተወዳጅ';

  @override
  String favoriteBarberAdd(String name) {
    return 'ወደ ተወዳጆች ያክሉ፦ $name';
  }

  @override
  String favoriteBarberRemove(String name) {
    return 'ከተወዳጆች ያስወግዱ፦ $name';
  }

  @override
  String rebookSuggestedSlot(String name, String when) {
    return 'ከ$name ጋር ቀጣዩ ክፍት ሰዓት፦ $when። ለመቀየር ሌላ ሰዓት ይንኩ።';
  }

  @override
  String rebookNoFreeTime(String name, int days) {
    return '$name በሚቀጥሉት $days ቀናት ክፍት ሰዓት የላቸውም። በዚህ ፀጉር ቤት ሌላ ፀጉር አስተካካይ ይሞክሩ።';
  }

  @override
  String get rebookFallbackTitle => 'አሁን እንደገና ቀጠሮ መያዝ አይቻልም';

  @override
  String rebookShopGone(String shop) {
    return '$shop ከእንግዲህ በመተግበሪያው ላይ የለም። በ«ፀጉር አስተካካይ ፈልግ» ሌላ ፀጉር አስተካካይ ያግኙ።';
  }

  @override
  String rebookShopBlocked(String shop) {
    return '$shop በአሁኑ ጊዜ ቀጠሮ አይቀበልም። እባክዎ ቆይተው ይሞክሩ።';
  }

  @override
  String rebookBarberGone(String barber, String shop) {
    return '$barber ከእንግዲህ በ$shop አይሰሩም። እዚያ ሌላ ፀጉር አስተካካይ ሊያገለግልዎ ይችላል።';
  }

  @override
  String rebookBarberUnavailable(String barber, String shop) {
    return '$barber በአሁኑ ጊዜ ቀጠሮ አይቀበሉም። በ$shop ሌላ ፀጉር አስተካካይ ሊያገለግልዎ ይችላል።';
  }

  @override
  String rebookServiceGone(String shop, String service, String barber) {
    return '$shop ከእንግዲህ $service አይሰጥም። ከ$barber ጋር ሌላ አገልግሎት ይምረጡ።';
  }

  @override
  String rebookNoServices(String shop) {
    return '$shop በአሁኑ ጊዜ የተመዘገበ አገልግሎት የለውም። እባክዎ ቆይተው ይሞክሩ።';
  }

  @override
  String get rebookSeeShop => 'ፀጉር ቤቱን ይመልከቱ';

  @override
  String get rebookPickService => 'አገልግሎት ይምረጡ';

  @override
  String get rebookRemoveFavorite => 'ከተወዳጆች ያስወግዱ';

  @override
  String get rebookSignInNeeded => 'እንደገና ቀጠሮ ለመያዝ እንደ ደንበኛ ይግቡ።';

  @override
  String get rebookClose => 'ዝጋ';

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
  String loginInvitePending(String email) {
    return 'የመግቢያ ግብዣ በመጠባበቅ ላይ፦ $email';
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
  String get subExpTrialEnded =>
      'የሙከራ ጊዜዎ አብቅቷል — ቀጠሮ መቀበልዎን ለመቀጠል ይክፈሉ። ካልከፈሉ ፀጉር ቤትዎ በቅርቡ ይታገዳል።';

  @override
  String get subExpTrialEndedToday =>
      'የሙከራ ጊዜዎ አብቅቷል — ቀጠሮ መቀበልዎን ለመቀጠል ይክፈሉ። ካልከፈሉ ፀጉር ቤትዎ ዛሬ ይታገዳል።';

  @override
  String subExpTrialEndedInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'የሙከራ ጊዜዎ አብቅቷል — ቀጠሮ መቀበልዎን ለመቀጠል ይክፈሉ። ፀጉር ቤትዎ እስኪታገድ $count ቀን ቀርቷል።',
    );
    return '$_temp0';
  }

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

  @override
  String get errInvalidPhone => 'ትክክለኛ የኢትዮጵያ ሞባይል ቁጥር ያስገቡ (09... ወይም 07...)።';

  @override
  String get errInvalidName => 'ስምዎን ያስገቡ (እስከ 100 ፊደላት)።';

  @override
  String get errSignInRequired => 'እባክዎ መጀመሪያ ይግቡ።';

  @override
  String get errSignInToBook => 'ቀጠሮ ለመያዝ ይግቡ።';

  @override
  String get errInvalidTimeSlot => 'ያ ሰዓት ትክክል አይደለም። እባክዎ ሌላ ሰዓት ይምረጡ።';

  @override
  String errServiceTooLong(int minutes) {
    return 'አንድ አገልግሎት ቢበዛ $minutes ደቂቃ ሊሆን ይችላል።';
  }

  @override
  String get errServerOnly => 'ይህን ለውጥ ማድረግ የሚችለው አገልጋዩ ብቻ ነው።';

  @override
  String get errSlotTaken => 'ይቅርታ፣ ያ ሰዓት አሁን ተይዟል። እባክዎ ሌላ ሰዓት ይምረጡ።';

  @override
  String get errBookingFailed =>
      'ይህን ሰዓት መያዝ አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get errNoWorkingDays => 'ቢያንስ አንድ የሥራ ቀን ይምረጡ።';

  @override
  String get errInvalidWorkingHours => 'የማብቂያ ሰዓቱ ከመጀመሪያ ሰዓቱ በኋላ መሆን አለበት።';

  @override
  String errPlanIdInvalid(String ids) {
    return 'የዕቅድ መለያ ከእነዚህ አንዱ መሆን አለበት፦ $ids።';
  }

  @override
  String get errPlanNameRequired => 'የዕቅድ ስም ያስፈልጋል።';

  @override
  String get errPlanPriceNegative => 'ዋጋ 0 ወይም ከዚያ በላይ መሆን አለበት።';

  @override
  String get errPlanPriceRequired => 'የሚከፈልበት ዕቅድ ከ0 በላይ ዋጋ ያስፈልገዋል።';

  @override
  String get errPlanMaxBarbers =>
      'ከፍተኛው የፀጉር አስተካካዮች ቁጥር ቢያንስ 1 (ወይም ላልተገደበ -1) መሆን አለበት።';

  @override
  String get errPermissionDenied => 'ይህን ለማድረግ ፈቃድ የለዎትም።';

  @override
  String get errOffline => 'ከአገልጋዩ ጋር መገናኘት አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get errGeneric => 'የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get payErrBookingNotFound => 'ይህ ቀጠሮ አልተገኘም።';

  @override
  String get payErrBookingCancelled => 'ይህ ቀጠሮ ተሰርዟል።';

  @override
  String get payErrBookingRefunded => 'የዚህ ቀጠሮ ክፍያ ተመላሽ ተደርጓል።';

  @override
  String get payErrCannotPayOnline => 'ይህ ቀጠሮ በመስመር ላይ ሊከፈል አይችልም።';

  @override
  String get payErrNoValidPrice => 'ይህ ትክክለኛ ዋጋ ስለሌለው በመስመር ላይ ሊከፈል አይችልም።';

  @override
  String get payErrNotYourBooking => 'ይህን ቀጠሮ መክፈል የሚችለው የያዘው ደንበኛ ብቻ ነው።';

  @override
  String get payErrNotYourPayment => 'ይህ የእርስዎ ክፍያ አይደለም።';

  @override
  String get payErrNotShopOwner => 'የዚህን ፀጉር ቤት ደንበኝነት መክፈል የሚችለው ባለቤቱ ብቻ ነው።';

  @override
  String get payErrShopNotFound => 'ይህ ፀጉር ቤት አልተገኘም።';

  @override
  String get payErrPlanUnavailable => 'ይህ ዕቅድ አይገኝም።';

  @override
  String get payErrUnknownPlan => 'ያልታወቀ ዕቅድ።';

  @override
  String payErrPlanTooSmall(int max, int count) {
    return 'ይህ ዕቅድ $max ፀጉር አስተካካዮችን ብቻ ይፈቅዳል፤ ፀጉር ቤቱ ግን $count አለው። ትልቅ ዕቅድ ይምረጡ ወይም ፀጉር አስተካካዮችን ያስወግዱ።';
  }

  @override
  String get payErrBookingChanged =>
      'ክፍያዎን እያዘጋጀን ሳለ ለውጥ ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get payErrStillPreparing =>
      'ክፍያዎ ገና በመዘጋጀት ላይ ነው። እባክዎ ትንሽ ቆይተው እንደገና ይሞክሩ።';

  @override
  String get payErrLaunchFailed => 'የቻፓ የክፍያ ገጽን መክፈት አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get payErrInvalid => 'አንዳንድ የክፍያ መረጃዎች የሉም ወይም ትክክል አይደሉም።';

  @override
  String get payErrPrecondition => 'ይህ ክፍያ አሁን ሊፈጸም አይችልም።';

  @override
  String get payErrAdminsOnly => 'ይህን ማድረግ የሚችሉት አስተዳዳሪዎች ብቻ ናቸው።';

  @override
  String get payErrPaymentNotFound => 'ይህ ክፍያ አልተገኘም።';

  @override
  String get payErrReviewNotNeeded => 'ይህ ክፍያ ከአሁን በኋላ ግምገማ አይጠብቅም።';

  @override
  String get payErrReviewNotRefundable =>
      'ተመላሽ ተብሎ ምልክት ሊደረግበት የሚችለው የተሳካ ክፍያ ብቻ ነው።';

  @override
  String get viewAction => 'ይመልከቱ';

  @override
  String get paymentsToReview => 'የሚገመገሙ ክፍያዎች';

  @override
  String get paymentsToReviewIntro =>
      'እነዚህ ክፍያዎች ውሳኔ ይፈልጋሉ። መጀመሪያ በቻፓ ዳሽቦርድ ገንዘቡን ለደንበኛው ይመልሱ፣ ከዚያ እዚህ ምልክት ያድርጉ።';

  @override
  String get noPaymentsToReview => 'ግምገማ የሚያስፈልገው ክፍያ የለም';

  @override
  String get noPaymentsToReviewHint =>
      'ለተሰረዙ ቀጠሮዎች የተከፈሉ፣ ሁለት ጊዜ የተከፈሉ እና ሊተገበሩ ያልቻሉ ክፍያዎች እዚህ ይታያሉ።';

  @override
  String paymentsToReviewLoadFailed(String error) {
    return 'ክፍያዎችን መጫን አልተቻለም፦ $error';
  }

  @override
  String get reviewReasonCancelledBooking => 'ለተሰረዘ ቀጠሮ ተከፍሏል';

  @override
  String get reviewReasonDoublePayment => 'ቀጠሮው ሁለት ጊዜ ተከፍሏል';

  @override
  String get reviewReasonMissingBooking => 'ቀጠሮው ከአሁን በኋላ የለም';

  @override
  String get reviewReasonRefundReported => 'ቻፓ ያሳወቀው ተመላሽ ክፍያ መረጋገጥ አለበት';

  @override
  String get reviewReasonSubscription => 'የደንበኝነት ክፍያው ሊተገበር አልቻለም';

  @override
  String get reviewReasonOther => 'በእጅ መረጋገጥ አለበት';

  @override
  String get paymentTypeBooking => 'የቀጠሮ ክፍያ';

  @override
  String get paymentTypeSubscription => 'የደንበኝነት ክፍያ';

  @override
  String get paymentDetailsTitle => 'የክፍያ ዝርዝሮች';

  @override
  String get detailAmount => 'መጠን';

  @override
  String get detailStatus => 'ሁኔታ';

  @override
  String get detailCreated => 'የተፈጠረበት';

  @override
  String get detailVerified => 'የተረጋገጠበት';

  @override
  String get detailShop => 'ፀጉር ቤት';

  @override
  String get detailBooking => 'ቀጠሮ';

  @override
  String get detailCustomer => 'የከፈለው';

  @override
  String get detailTxRef => 'የግብይት መለያ';

  @override
  String get detailChapaReference => 'የቻፓ መለያ';

  @override
  String get detailMethod => 'የክፍያ ዘዴ';

  @override
  String get detailPaymentId => 'የክፍያ መለያ';

  @override
  String get reviewNoteLabel => 'ማስታወሻ (አማራጭ)';

  @override
  String get reviewNoteHint => 'ለምሳሌ፦ ኅዳር 4 ተመልሷል፣ የቻፓ መለያ ...';

  @override
  String get markRefundedInChapa => 'በቻፓ ተመላሽ አድርጌያለሁ';

  @override
  String get markNoAction => 'ምንም እርምጃ አያስፈልግም';

  @override
  String get confirmRefundTitle => 'ተመላሽ ተደርጓል ብለው ምልክት ያድርጉ?';

  @override
  String confirmRefundBody(String amount) {
    return '$amount በቻፓ ዳሽቦርድ አስቀድመው ከመለሱ ብቻ ይቀጥሉ። ክፍያውና ቀጠሮው ተመላሽ እንደተደረጉ ይታያሉ።';
  }

  @override
  String get reviewClosedRefunded => 'ተመላሽ ተደርጓል ተብሎ ምልክት ተደርጓል።';

  @override
  String get reviewClosedNoAction => 'ግምገማው ተዘግቷል።';

  @override
  String reviewFailed(String error) {
    return 'ግምገማውን መዝጋት አልተቻለም፦ $error';
  }

  @override
  String get editWorkingHours => 'የሥራ ቀናትና ሰዓታት';

  @override
  String barberHoursTitle(String name) {
    return '$name፦ የሥራ ሰዓታት';
  }

  @override
  String get followShopHours => 'ከፀጉር ቤቱ ጋር አንድ ዓይነት';

  @override
  String get followShopHoursSubtitle =>
      'በፀጉር ቤቱ የሥራ ቀናት ከመክፈቻ እስከ መዝጊያ ሰዓት ይሠራል።';

  @override
  String get workingDaysLabel => 'የሥራ ቀናት';

  @override
  String get startsAt => 'ይጀምራል';

  @override
  String get endsAt => 'ያበቃል';

  @override
  String get workingHoursSaved => 'የሥራ ሰዓታት ተቀምጠዋል።';

  @override
  String get shopHoursSummary => 'የፀጉር ቤቱ ሰዓታት';

  @override
  String get errAccountLoadFailed =>
      'መለያዎን መጫን አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get reviewsTitle => 'ግምገማዎች';

  @override
  String get reviewsRateAction => 'ፀጉር አስተካካይዎን ይገምግሙ';

  @override
  String get reviewsYourRating => 'የሰጡት ደረጃ';

  @override
  String get reviewsRateTitle => 'ፀጉር አስተካካይዎን ይገምግሙ';

  @override
  String reviewsRateSubtitle(String service, String barber) {
    return '$service በ$barber';
  }

  @override
  String reviewsStarsLabel(int count) {
    return '$count ኮከብ';
  }

  @override
  String get reviewsPickRating => 'ደረጃ ለመስጠት ኮከብ ይንኩ።';

  @override
  String get reviewsCommentLabel => 'አስተያየት (ካሉዎት)';

  @override
  String get reviewsCommentHint => 'ስለ ልምድዎ ይንገሩን';

  @override
  String get reviewsSubmit => 'ግምገማውን ላክ';

  @override
  String get reviewsThanks => 'ስለ ግምገማዎ እናመሰግናለን!';

  @override
  String reviewsSubmitFailed(String error) {
    return 'ግምገማዎን መላክ አልተቻለም፦ $error';
  }

  @override
  String reviewsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ግምገማዎች',
      zero: 'እስካሁን ግምገማ የለም',
    );
    return '$_temp0';
  }

  @override
  String get reviewsNew => 'አዲስ';

  @override
  String get reviewsEmpty =>
      'እስካሁን ግምገማ የለም። ደንበኞች ጉብኝታቸው ከተጠናቀቀ በኋላ ደረጃ መስጠት ይችላሉ።';

  @override
  String reviewsSeeAll(int count) {
    return 'ሁሉንም ግምገማዎች ይመልከቱ ($count)';
  }

  @override
  String get reviewsLoadMore => 'ተጨማሪ አሳይ';

  @override
  String get reviewsLoadFailed => 'ግምገማዎቹን መጫን አልተቻለም።';

  @override
  String get reviewsRetry => 'እንደገና ይሞክሩ';

  @override
  String get reviewsOwnerReply => 'ከፀጉር ቤቱ የተሰጠ ምላሽ';

  @override
  String get reviewsReplyAction => 'ምላሽ ይስጡ';

  @override
  String get reviewsEditReply => 'ምላሹን ያስተካክሉ';

  @override
  String get reviewsReplyLabel => 'ለሁሉም የሚታይ ምላሽዎ';

  @override
  String get reviewsReplySave => 'ምላሹን አስቀምጥ';

  @override
  String get reviewsReplySaved => 'ምላሹ ተቀምጧል።';

  @override
  String get reviewsAwaitingReply => 'እስካሁን ምላሽ አልተሰጠም';

  @override
  String get reviewsOpenButton => 'ግምገማዎችና ምላሾች';

  @override
  String get reviewsMyReviews => 'የእኔ ግምገማዎች';

  @override
  String reviewsBarberTitle(String name) {
    return 'የ$name ግምገማዎች';
  }

  @override
  String reviewsSummaryLine(String rating, int count) {
    return 'ከ5 $rating · $count ግምገማዎች';
  }

  @override
  String reviewsRatedSemantics(String rating) {
    return 'ከ5 $rating ደረጃ';
  }

  @override
  String get reviewsCustomer => 'ደንበኛ';

  @override
  String get reviewsErrNotYourBooking => 'ደረጃ መስጠት የሚችሉት ለራስዎ ጉብኝቶች ብቻ ነው።';

  @override
  String get reviewsErrNotCompleted => 'ጉብኝቱ ከተጠናቀቀ በኋላ ደረጃ መስጠት ይችላሉ።';

  @override
  String get reviewsErrAlreadyReviewed => 'ለዚህ ጉብኝት አስቀድመው ደረጃ ሰጥተዋል።';

  @override
  String get reviewsErrInvalidRating => 'ከ1 እስከ 5 ኮከብ ይምረጡ።';

  @override
  String reviewsErrCommentTooLong(int max) {
    return 'አስተያየቱ ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String reviewsErrReplyInvalid(int max) {
    return 'እስከ $max ፊደላት የሚደርስ ምላሽ ይጻፉ።';
  }

  @override
  String get reviewsErrOwnerOnly =>
      'ለግምገማዎች ምላሽ መስጠት የሚችለው የፀጉር ቤቱ ባለቤት ብቻ ነው።';

  @override
  String get reviewsErrNotFound => 'ይህ ግምገማ ከእንግዲህ የለም።';

  @override
  String get reviewsEditAction => 'ግምገማውን ያስተካክሉ';

  @override
  String get reviewsDeleteAction => 'ግምገማውን ይሰርዙ';

  @override
  String get reviewsEditTitle => 'ግምገማዎን ያስተካክሉ';

  @override
  String get reviewsSaveEdit => 'ለውጦቹን አስቀምጥ';

  @override
  String get reviewsEditSaved => 'ግምገማዎ ተዘምኗል።';

  @override
  String get reviewsEdited => 'ተስተካክሏል';

  @override
  String get reviewsManageHint => 'ግምገማዎን ለማስተካከል ወይም ለመሰረዝ ይንኩ';

  @override
  String get reviewsDeleteConfirmTitle => 'ግምገማዎን ይሰርዙ?';

  @override
  String reviewsDeleteConfirmBody(String barber) {
    return 'ኮከቦችዎና አስተያየትዎ ከ$barber ደረጃ ይወገዳሉ። ይህን ጉብኝት በኋላ እንደገና መገምገም ይችላሉ።';
  }

  @override
  String get reviewsDeleted => 'ግምገማዎ ተሰርዟል።';

  @override
  String get authTabLogin => 'ግባ';

  @override
  String get authTabRegister => 'ተመዝገብ';

  @override
  String get authOr => 'ወይም';

  @override
  String get emailLabel => 'ኢሜይል';

  @override
  String get passwordLabel => 'የይለፍ ቃል';

  @override
  String get confirmPasswordLabel => 'የይለፍ ቃሉን ያረጋግጡ';

  @override
  String get newPasswordLabel => 'አዲስ የይለፍ ቃል';

  @override
  String get showPassword => 'የይለፍ ቃሉን አሳይ';

  @override
  String get hidePassword => 'የይለፍ ቃሉን ደብቅ';

  @override
  String get loginButton => 'ግባ';

  @override
  String get forgotPassword => 'የይለፍ ቃልዎን ረሱት?';

  @override
  String get sendCode => 'ኮድ ላክ';

  @override
  String codeSentTo(String email) {
    return 'ወደ $email የላክነውን ባለ 6 አሃዝ ኮድ ያስገቡ';
  }

  @override
  String get codeLabel => 'ባለ 6 አሃዝ ኮድ';

  @override
  String get resendCode => 'ኮዱን እንደገና ላክ';

  @override
  String resendCodeIn(int seconds) {
    return 'በ$seconds ሰከንድ ውስጥ ኮዱን እንደገና መላክ ይችላሉ';
  }

  @override
  String get codeResent => 'አዲስ ኮድ ልከናል።';

  @override
  String get changeEmail => 'ኢሜይል ቀይር';

  @override
  String get passwordHelper => 'ቢያንስ 8 ቁምፊዎች፣ ፊደል እና ቁጥር ያካተተ';

  @override
  String get passwordsDontMatch => 'የይለፍ ቃሎቹ አይመሳሰሉም።';

  @override
  String get enterPassword => 'የይለፍ ቃልዎን ያስገቡ።';

  @override
  String get codeRequired => 'ባለ 6 አሃዝ ኮዱን ያስገቡ።';

  @override
  String get resetTitle => 'የይለፍ ቃልዎን ዳግም ያስጀምሩ';

  @override
  String get resetIntro => 'የመለያዎን ኢሜይል ያስገቡ፤ ባለ 6 አሃዝ ኮድ እንልክልዎታለን።';

  @override
  String get resetDone => 'የይለፍ ቃልዎ ተቀይሯል። በአዲሱ የይለፍ ቃል ይግቡ።';

  @override
  String get backToLogin => 'ወደ መግቢያ ተመለስ';

  @override
  String get demoEmailHint =>
      'ሙከራ፦ ኮዱ ሁልጊዜ 123456 ነው። የሙከራ መለያዎች በይለፍ ቃል demo1234 ይገባሉ።';

  @override
  String get emailErrWeakPassword =>
      'ከ8 እስከ 128 ቁምፊዎች ያሉት፣ ቢያንስ አንድ ፊደል እና አንድ ቁጥር ያለው የይለፍ ቃል ይጠቀሙ።';

  @override
  String get emailErrInvalidCode => 'ኮዱ ትክክል አይደለም። ኢሜይሉን ይመልከቱ እና እንደገና ይሞክሩ።';

  @override
  String get emailErrCodeExpired => 'ኮዱ ጊዜው አልፎበታል። አዲስ ኮድ ይጠይቁ።';

  @override
  String get emailErrAlreadyRegistered => 'በዚህ ኢሜይል የተፈጠረ መለያ አለ። እባክዎ ይግቡ።';

  @override
  String get emailErrTooSoon => 'ሌላ ኮድ ከመጠየቅዎ በፊት ትንሽ ይጠብቁ።';

  @override
  String emailErrTooSoonSeconds(int seconds) {
    return 'ሌላ ኮድ ከመጠየቅዎ በፊት $seconds ሰከንድ ይጠብቁ።';
  }

  @override
  String get emailErrRateLimited => 'በጣም ብዙ ሙከራዎች። እባክዎ ቆይተው እንደገና ይሞክሩ።';

  @override
  String get emailErrNotConfigured =>
      'አሁን ኢሜይል መላክ አልቻልንም። በGoogle ለመግባት ይሞክሩ።';

  @override
  String get emailErrWrongCredentials => 'የተሳሳተ ኢሜይል ወይም የይለፍ ቃል።';

  @override
  String get emailErrNotEnabled => 'በኢሜይል መግባት ገና አልነቃም።';

  @override
  String get emailErrServiceUnavailable =>
      'ይህ አገልግሎት ገና አልተዘጋጀም። በGoogle ለመግባት ይሞክሩ።';

  @override
  String get errEmailNotVerified =>
      'እባክዎ መጀመሪያ ኢሜይልዎን ያረጋግጡ። በኢሜይል የላክነውን ሊንክ ይክፈቱ፣ ከዚያ ይግቡ።';

  @override
  String get emailErrSendFailed => 'ኢሜይሉን መላክ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get emailErrInvalidInput => 'ያስገቡትን መረጃ ያረጋግጡ እና እንደገና ይሞክሩ።';

  @override
  String emailErrInvalidCodeAttempts(int count) {
    return 'ኮዱ ትክክል አይደለም። የቀሩ ሙከራዎች፦ $count።';
  }

  @override
  String get registerEmailTitle => 'ኢሜይልዎን ያስገቡ';

  @override
  String get registerEmailIntro => 'የእርስዎ መሆኑን ለማረጋገጥ ባለ 6 አሃዝ ኮድ እንልክልዎታለን።';

  @override
  String get enterCodeTitle => 'ኢሜይልዎን ይመልከቱ';

  @override
  String get verifyButton => 'አረጋግጥ';

  @override
  String get createPasswordTitle => 'የይለፍ ቃልዎን ይፍጠሩ';

  @override
  String get createAccountButton => 'መለያ ፍጠር';

  @override
  String get newPasswordTitle => 'አዲስ የይለፍ ቃል ይምረጡ';

  @override
  String get savePasswordButton => 'አስቀምጥ';

  @override
  String emailVerifiedNotice(String email) {
    return '$email ተረጋግጧል።';
  }

  @override
  String authStepOf(int step, int total) {
    return 'ደረጃ $step ከ$total';
  }

  @override
  String get emailErrVerificationExpired =>
      'ይህ ደረጃ ብዙ ጊዜ ወሰደ። እባክዎ አዲስ ኮድ ይጠይቁ።';

  @override
  String get logInInstead => 'በምትኩ ይግቡ';

  @override
  String get acceptRequestsTitle => 'አዲስ ጥያቄዎች';

  @override
  String acceptRequestsCount(int count) {
    return '$count በመጠባበቅ ላይ';
  }

  @override
  String get acceptRequestsHelp =>
      'እያንዳንዱን ቀጠሮ ይቀበሉ ወይም ውድቅ ያድርጉ። ከመጀመሪያው 1 ሰዓት በፊት ምላሽ ያላገኙ ጥያቄዎች በራስ-ሰር ይሰረዛሉ።';

  @override
  String get acceptAction => 'ተቀበል';

  @override
  String get acceptDeclineAction => 'ውድቅ አድርግ';

  @override
  String get acceptDeclineTitle => 'ይህን ቀጠሮ ውድቅ ያደርጋሉ?';

  @override
  String acceptDeclineBody(String customer) {
    return 'ለ$customer ቀጠሮውን መውሰድ እንደማይችሉ ይነገራቸዋል፤ ሌላ ሰዓት እንዲመርጡም ይጠየቃሉ።';
  }

  @override
  String get acceptDeclineReasonLabel => 'ምክንያት (አማራጭ)';

  @override
  String get acceptDeclineConfirm => 'ቀጠሮውን ውድቅ አድርግ';

  @override
  String get acceptDeclineCancel => 'ተመለስ';

  @override
  String acceptAccepted(String customer) {
    return 'ቀጠሮው ተቀባይነት አግኝቷል። ለ$customer ተነግሯቸዋል።';
  }

  @override
  String get acceptDeclined => 'ቀጠሮው ውድቅ ተደርጓል።';

  @override
  String acceptFailed(String error) {
    return 'ለጥያቄው ምላሽ መስጠት አልተቻለም፦ $error';
  }

  @override
  String get acceptWaitingForBarber => 'ፀጉር አስተካካዩን በመጠበቅ ላይ';

  @override
  String acceptWaitingFor(String barber) {
    return '$barber እስኪቀበሉ በመጠበቅ ላይ';
  }

  @override
  String get acceptRequestSentTitle => 'ጥያቄዎ ተልኳል!';

  @override
  String acceptRequestSentBody(String barber) {
    return '$barber ቀጠሮዎን በቅርቡ ያረጋግጣሉ። ሲቀበሉ እናሳውቅዎታለን።';
  }

  @override
  String get acceptPayAfterAcceptance =>
      'ፀጉር አስተካካዩ ከተቀበለ በኋላ በኦንላይን መክፈል ይችላሉ።';

  @override
  String get acceptDeclinedNote =>
      'ፀጉር አስተካካዩ ይህን ቀጠሮ መውሰድ አልቻሉም። እባክዎ ሌላ ሰዓት ይምረጡ።';

  @override
  String get acceptExpiredNote =>
      'ፀጉር አስተካካዩ በጊዜው ምላሽ አልሰጡም። እባክዎ ሌላ ሰዓት ይምረጡ።';

  @override
  String acceptDeclineReasonNote(String reason) {
    return 'ምክንያት፦ $reason';
  }

  @override
  String get acceptPolicyToggle => 'ፀጉር አስተካካዮች እያንዳንዱን ቀጠሮ ይቀበላሉ';

  @override
  String get acceptPolicyToggleHelp =>
      'አዲስ ቀጠሮዎች ፀጉር አስተካካዩ እስኪቀበላቸው ድረስ ይጠብቃሉ። ከመጀመሪያው 1 ሰዓት በፊት ምላሽ ያላገኙ ጥያቄዎች በራስ-ሰር ይሰረዛሉ።';

  @override
  String get acceptErrNotAllowed =>
      'ይህን ጥያቄ መመለስ የሚችሉት የተያዘው ፀጉር አስተካካይ ወይም የፀጉር ቤቱ ባለቤት ብቻ ናቸው።';

  @override
  String acceptErrReasonTooLong(int max) {
    return 'ምክንያቱ ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String get payoutsTitle => 'የባርበሮች ክፍያ';

  @override
  String get payoutsOpenButton => 'ክፍያዎችና ኮሚሽን';

  @override
  String get payoutsMonthLabel => 'ወር';

  @override
  String get payoutsCompletedJobs => 'የተጠናቀቁ ሥራዎች';

  @override
  String get payoutsGross => 'ጠቅላላ ገቢ';

  @override
  String get payoutsCommission => 'ኮሚሽን';

  @override
  String payoutsCommissionLine(int percent) {
    return 'ኮሚሽን፦ $percent%';
  }

  @override
  String get payoutsBarberShare => 'የባርበሩ ድርሻ';

  @override
  String get payoutsAlreadyPaid => 'የተከፈለ';

  @override
  String get payoutsBalanceOwed => 'ቀሪ ዕዳ';

  @override
  String get payoutsTotalShare => 'የባርበሮች ድርሻ';

  @override
  String get payoutsTotalPaid => 'የተከፈለ';

  @override
  String get payoutsTotalOwed => 'ገና ያልተከፈለ';

  @override
  String get payoutsRecord => 'ክፍያ መዝግብ';

  @override
  String payoutsRecordTitle(String name) {
    return 'ለ$name ክፈል';
  }

  @override
  String get payoutsHistory => 'የክፍያ ታሪክ';

  @override
  String get payoutsNoHistory => 'ለዚህ ወር የተመዘገበ ክፍያ የለም።';

  @override
  String get payoutsNoBarbers => 'ኮሚሽናቸውንና ክፍያቸውን ለመከታተል ባርበሮችን ያክሉ።';

  @override
  String get payoutsAmount => 'መጠን (ብር)';

  @override
  String get payoutsMethod => 'የተከፈለበት መንገድ';

  @override
  String get payoutsMethodCash => 'ጥሬ ገንዘብ';

  @override
  String get payoutsMethodTelebirr => 'ቴሌብር';

  @override
  String get payoutsMethodBank => 'የባንክ ዝውውር';

  @override
  String get payoutsMethodOther => 'ሌላ';

  @override
  String get payoutsNote => 'ማስታወሻ (አማራጭ)';

  @override
  String payoutsPeriod(String range) {
    return 'ጊዜ፦ $range';
  }

  @override
  String get payoutsSave => 'ክፍያውን አስቀምጥ';

  @override
  String get payoutsSaved => 'ክፍያው ተመዝግቧል።';

  @override
  String get payoutsDelete => 'ክፍያውን ሰርዝ';

  @override
  String payoutsDeleteBody(String amount, String name) {
    return 'ለ$name የተከፈለውን $amount ይሰርዙ? ክፍያን መሰረዝ የሚቻለው ከተመዘገበ በ24 ሰዓት ውስጥ ብቻ ነው።';
  }

  @override
  String get payoutsDeleted => 'ክፍያው ተሰርዟል።';

  @override
  String get payoutsYourShare => 'የእርስዎ ድርሻ';

  @override
  String get payoutsPaidToYou => 'የተከፈለዎት';

  @override
  String payoutsThisMonth(String month) {
    return 'በዚህ ወር፦ $month';
  }

  @override
  String payoutsShareLine(int percent, int jobs, String gross) {
    return 'ከ$jobs የተጠናቀቁ ሥራዎች ($gross) $percent%';
  }

  @override
  String get payoutsMyPayouts => 'የእኔ ክፍያዎች';

  @override
  String get payoutsMyPayoutsEmpty => 'እስካሁን ምንም ክፍያ የለም።';

  @override
  String get payoutsSeeAll => 'ሁሉንም ክፍያዎች ይመልከቱ';

  @override
  String get payoutsSetCommission => 'ኮሚሽን ያስተካክሉ';

  @override
  String payoutsCommissionTitle(String name) {
    return 'የ$name ኮሚሽን';
  }

  @override
  String get payoutsCommissionHelp => 'ባርበሩ ከእያንዳንዱ የተጠናቀቀ ቀጠሮ ዋጋ የሚያገኘው ድርሻ።';

  @override
  String get payoutsCommissionPercent => 'ኮሚሽን (%)';

  @override
  String get payoutsCommissionSaved => 'ኮሚሽኑ ተቀምጧል።';

  @override
  String payoutsRecordedOn(String date) {
    return 'የተመዘገበው $date';
  }

  @override
  String get payoutsLoadFailed => 'ክፍያዎችን መጫን አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get payoutsErrOwnerOnly =>
      'ክፍያዎችንና ኮሚሽንን ማስተዳደር የሚችለው የሱቁ ባለቤት ብቻ ነው።';

  @override
  String get payoutsErrNotFound => 'ይህ ክፍያ ወይም ባርበር ከአሁን በኋላ የለም።';

  @override
  String get payoutsErrUnknownBarber => 'ይህ ባርበር የሱቅዎ አባል አይደለም።';

  @override
  String payoutsErrInvalidAmount(String max) {
    return 'ከ0 በላይ እና እስከ $max ብር የሆነ መጠን ያስገቡ።';
  }

  @override
  String get payoutsErrInvalidPeriod => 'ጊዜው ከመጨረሻው በፊት ወይም በዚያው ቀን መጀመር አለበት።';

  @override
  String payoutsErrNoteTooLong(int max) {
    return 'ማስታወሻው ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String get payoutsErrInvalidCommission =>
      'ኮሚሽኑ ከ0 እስከ 100 ያለ ሙሉ ቁጥር መሆን አለበት።';

  @override
  String get payoutsErrDeleteWindow =>
      'ክፍያን መሰረዝ የሚቻለው ከተመዘገበ በ24 ሰዓት ውስጥ ብቻ ነው።';

  @override
  String payoutsCarriedOver(String month) {
    return 'ከ$month የተላለፈ';
  }

  @override
  String get payoutsCarryUnavailable =>
      'የቀደሙ ወራት ያልተከፈሉ ቀሪዎችን መጫን አልተቻለም። የዚህ ወር ብቻ ይታያል።';

  @override
  String get payoutsCarryHint =>
      'ከቀደሙ ወራት ያልተከፈሉ ቀሪዎችን ያካትታል። ከፊሉን ከከፈሉ ቀሪው ወደሚቀጥለው ወር ይተላለፋል።';

  @override
  String get payoutsTotalCarried => 'የተላለፈ';

  @override
  String get earningsTitle => 'የእርስዎ ገቢ';

  @override
  String get earningsShopTitle => 'የማንኛውም ጊዜ ድምር';

  @override
  String get earningsTab => 'ድምሮች';

  @override
  String get earningsThisMonth => 'ይህ ወር';

  @override
  String get earningsLastMonth => 'ያለፈው ወር';

  @override
  String get earningsPickMonth => 'ወር ይምረጡ';

  @override
  String get earningsThisYear => 'ይህ ዓመት';

  @override
  String get earningsAllTime => 'ሁሉም ጊዜ';

  @override
  String get earningsAllTimeNote => 'ሁሉም የተጠናቀቁ ቀጠሮዎች';

  @override
  String get earningsCompleted => 'የተጠናቀቁ ሥራዎች';

  @override
  String get earningsRevenue => 'ገቢ';

  @override
  String earningsYourShare(int percent) {
    return 'የእርስዎ ድርሻ ($percent%)';
  }

  @override
  String get earningsBarbersShare => 'የባርበሮች ድርሻ';

  @override
  String get earningsShopKeeps => 'የፀጉር ቤቱ ድርሻ';

  @override
  String get earningsByBarber => 'በባርበር';

  @override
  String earningsBarberJobs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count የተጠናቀቁ ሥራዎች',
      one: '1 የተጠናቀቀ ሥራ',
    );
    return '$_temp0';
  }

  @override
  String get earningsLoadFailed => 'ድምሮቹን መጫን አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get earningsShareNote =>
      'ድርሻዎች አሁን ባለው ኮሚሽን ይሰላሉ። የተጠናቀቁ ቀጠሮዎች ብቻ ይቆጠራሉ።';

  @override
  String get applRegisterShopTitle => 'የፀጉር ቤትዎን ያስመዝግቡ';

  @override
  String get applRegisterShopSubtitle =>
      'የፀጉር ቤት ባለቤት ነዎት? በክራውን ኤንድ ብሌድ ላይ ለመመዝገብ ያመልክቱ። እያንዳንዱን ማመልከቻ እንገመግማለን።';

  @override
  String get applCtaApply => 'አሁን ያመልክቱ';

  @override
  String get applCtaViewStatus => 'ማመልከቻውን ይመልከቱ';

  @override
  String get applFormIntro =>
      'ስለ ሱቅዎ ይንገሩን። አስተዳዳሪው ሲያጸድቀው ይህ መለያ የሱቁ ባለቤት መለያ ይሆናል።';

  @override
  String get applOwnerName => 'ሙሉ ስምዎ';

  @override
  String get applShopName => 'የፀጉር ቤቱ ስም';

  @override
  String get applAddress => 'የመንገድ አድራሻ';

  @override
  String get applSubCity => 'ክፍለ ከተማ';

  @override
  String get applPhone => 'የሱቁ መገናኛ ስልክ';

  @override
  String get applPhoneHint => '09XX XXX XXX ወይም 011 XXX XXXX';

  @override
  String get applDescription => 'ስለ ሱቁ (አማራጭ)';

  @override
  String get applSubmit => 'ማመልከቻውን ይላኩ';

  @override
  String get applSaveChanges => 'ለውጦቹን ያስቀምጡ';

  @override
  String get applResubmit => 'እንደገና ያመልክቱ';

  @override
  String get applSubmitted => 'ማመልከቻው ተልኳል። ሲገመገም እናሳውቅዎታለን።';

  @override
  String get applUpdated => 'ማመልከቻው ተዘምኗል።';

  @override
  String get applEdit => 'ማመልከቻውን ያስተካክሉ';

  @override
  String get applWithdraw => 'ማመልከቻውን ይሰርዙ';

  @override
  String get applWithdrawTitle => 'ማመልከቻውን ይሰርዙ?';

  @override
  String applWithdrawBody(String shop) {
    return 'ለ$shop ያቀረቡት ማመልከቻ ይሰረዛል። በኋላ እንደገና ማመልከት ይችላሉ።';
  }

  @override
  String get applWithdrawn => 'ማመልከቻው ተሰርዟል።';

  @override
  String get applStatusPending => 'በግምገማ ላይ';

  @override
  String get applStatusApproved => 'ጸድቋል';

  @override
  String get applStatusRejected => 'አልጸደቀም';

  @override
  String applPendingBody(String date) {
    return 'ማመልከቻዎን በ$date ተቀብለናል። አስተዳዳሪው በቅርቡ ይገመግመዋል።';
  }

  @override
  String applApprovedBody(String shop) {
    return '$shop ጸድቋል! መለያዎ አሁን የሱቁ ባለቤት መለያ ነው።';
  }

  @override
  String get applOpenDashboard => 'የባለቤት ዳሽቦርድን ይክፈቱ';

  @override
  String get applRejectedBody => 'ማመልከቻዎ አልጸደቀም።';

  @override
  String applRejectReasonLine(String reason) {
    return 'ምክንያት፦ $reason';
  }

  @override
  String get applRejectedHint => 'ዝርዝሩን አስተካክለው እንደገና ማመልከት ይችላሉ።';

  @override
  String get applSignUpOwnShop => 'የፀጉር ቤት አለኝ፤ ማስመዝገብ እፈልጋለሁ';

  @override
  String get applSignUpOwnShopHint => 'ከቀጠሉ በኋላ የሱቅዎን ዝርዝር ለማጽደቅ መላክ ይችላሉ።';

  @override
  String get applAdminTitle => 'የሱቅ ማመልከቻዎች';

  @override
  String applAdminPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count በመጠባበቅ ላይ ያሉ ማመልከቻዎች',
      one: '1 በመጠባበቅ ላይ ያለ ማመልከቻ',
      zero: 'በመጠባበቅ ላይ ያለ ማመልከቻ የለም',
    );
    return '$_temp0';
  }

  @override
  String get applAdminPending => 'በመጠባበቅ ላይ';

  @override
  String get applAdminRecent => 'በቅርቡ የተወሰኑ';

  @override
  String get applAdminEmpty => 'እስካሁን የሱቅ ማመልከቻ የለም።';

  @override
  String applAdminSubmittedOn(String date) {
    return 'የቀረበው $date';
  }

  @override
  String applAdminReviewedOn(String date) {
    return 'የተገመገመው $date';
  }

  @override
  String get applAdminApprove => 'አጽድቅ';

  @override
  String get applAdminReject => 'ውድቅ አድርግ';

  @override
  String applAdminApproveTitle(String shop) {
    return '$shop ይጽደቅ?';
  }

  @override
  String applAdminApproveBody(String email) {
    return 'ይህ ሱቁን በነጻ የሙከራ ጊዜ ከሁለት መነሻ አገልግሎቶች ጋር ይመዘግባል፤ $emailን እንደ ባለቤት ይጋብዛል።';
  }

  @override
  String applAdminApproved(String shop) {
    return '$shop ጸድቆ ተመዝግቧል።';
  }

  @override
  String applAdminRejectTitle(String shop) {
    return '$shop ውድቅ ይደረግ?';
  }

  @override
  String get applAdminRejectReason => 'ምክንያት (አመልካቹ ያየዋል)';

  @override
  String get applAdminRejected => 'ማመልከቻው ውድቅ ተደርጓል።';

  @override
  String get applLoadFailed => 'ማመልከቻዎችን መጫን አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get applErrOwnerName => 'ስምዎን ያስገቡ (እስከ 100 ፊደላት)።';

  @override
  String get applErrShopName => 'የሱቁ ስም ከ2 እስከ 80 ፊደላት መሆን አለበት።';

  @override
  String get applErrAddress => 'አድራሻው ከ2 እስከ 160 ፊደላት መሆን አለበት።';

  @override
  String get applErrSubCity => 'ክፍለ ከተማ ይምረጡ።';

  @override
  String get applErrPhone =>
      'ትክክለኛ የኢትዮጵያ ስልክ ቁጥር ያስገቡ (09...፣ 07... ወይም 011...)።';

  @override
  String applErrDescriptionTooLong(int max) {
    return 'መግለጫው ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String applErrRejectReason(int max) {
    return 'እስከ $max ፊደላት የሚሆን ምክንያት ይጻፉ።';
  }

  @override
  String get applErrCustomersOnly =>
      'የፀጉር ቤት ለማስመዝገብ ማመልከት የሚችሉት የደንበኛ መለያዎች ብቻ ናቸው።';

  @override
  String get applErrEmailMissing =>
      'መለያዎ የኢሜይል አድራሻ የለውም፤ የባለቤት ግብዣው ኢሜይል ያስፈልገዋል።';

  @override
  String get applErrAlreadyPending => 'በግምገማ ላይ ያለ ማመልከቻ አለዎት። እሱን ያስተካክሉ።';

  @override
  String get applErrAlreadyApproved => 'ማመልከቻዎ አስቀድሞ ጸድቋል።';

  @override
  String get applErrNotPending => 'ይህ ማመልከቻ አስቀድሞ ተገምግሟል።';

  @override
  String get applErrNotFound => 'ይህ ማመልከቻ ከአሁን በኋላ የለም።';

  @override
  String get applErrAdminOnly => 'ማመልከቻዎችን መገምገም የሚችለው የመድረኩ አስተዳዳሪ ብቻ ነው።';

  @override
  String emailErrRateLimitedMinutes(int minutes) {
    return 'በጣም ብዙ ሙከራዎች። ከ$minutes ደቂቃ በኋላ እንደገና ይሞክሩ።';
  }

  @override
  String get barberCancelAction => 'ሰርዝ';

  @override
  String get barberCancelTitle => 'ይህን ቀጠሮ ይሰርዛሉ?';

  @override
  String barberCancelBody(String customer, String service, String when) {
    return '$customer $when ያለውን የ$service ቀጠሮአቸውን እንደሰረዙ ይነገራቸዋል። ይህ ሊቀለበስ አይችልም።';
  }

  @override
  String get barberCancelReasonLabel => 'ምክንያት (አማራጭ)';

  @override
  String get barberCancelReasonHint => 'ለምሳሌ፦ ዛሬ አሞኛል';

  @override
  String get barberCancelConfirm => 'ቀጠሮውን ሰርዝ';

  @override
  String get barberCancelKeep => 'ቀጠሮውን አቆይ';

  @override
  String get barberCancelDone => 'ቀጠሮው ተሰርዟል። ለደንበኛው ተነግሯል።';

  @override
  String barberCancelFailed(String error) {
    return 'ቀጠሮውን መሰረዝ አልተቻለም፦ $error';
  }

  @override
  String get barberCancelErrNotAllowed => 'መሰረዝ የሚችሉት የራስዎን ቀጠሮዎች ብቻ ነው።';

  @override
  String get barberCancelErrAfterStart =>
      'ይህ ቀጠሮ ቀድሞ ጀምሯል። በምትኩ \"አልመጡም\" ብለው ምልክት ያድርጉ ወይም ያጠናቅቁት።';

  @override
  String get changePasswordMenu => 'የይለፍ ቃል ቀይር';

  @override
  String get setPasswordMenu => 'የይለፍ ቃል አዘጋጅ';

  @override
  String get changePasswordTitle => 'የይለፍ ቃል ቀይር';

  @override
  String get changePasswordIntro => 'የአሁኑን የይለፍ ቃልዎን ያስገቡ፣ ከዚያ አዲስ ይምረጡ።';

  @override
  String get currentPasswordLabel => 'የአሁኑ የይለፍ ቃል';

  @override
  String get changePasswordSave => 'የይለፍ ቃሉን አዘምን';

  @override
  String get changePasswordDone => 'የይለፍ ቃልዎ ተቀይሯል።';

  @override
  String get changePasswordErrWrongCurrent => 'የአሁኑ የይለፍ ቃልዎ ትክክል አይደለም።';

  @override
  String get changePasswordErrCurrentRequired => 'የአሁኑን የይለፍ ቃልዎን ያስገቡ።';

  @override
  String get changePasswordErrRecentLogin =>
      'ለደህንነትዎ ሲባል ወጥተው እንደገና ይግቡ፣ ከዚያ የይለፍ ቃልዎን ይቀይሩ።';

  @override
  String get changePasswordErrNoPassword =>
      'ይህ መለያ በGoogle ይገባል፤ እስካሁን የይለፍ ቃል የለውም።';

  @override
  String get setPasswordTitle => 'የይለፍ ቃል አዘጋጅ';

  @override
  String setPasswordBody(String email) {
    return 'በGoogle ስለሚገቡ ይህ መለያ እስካሁን የይለፍ ቃል የለውም። የይለፍ ቃል ለመፍጠር ይውጡ፣ በመግቢያ ገጹ ላይ \"የይለፍ ቃልዎን ረሱት?\" የሚለውን ይንኩ እና $email ያስገቡ። ኮድ በኢሜይል እንልክልዎታለን፤ ከዚያ የይለፍ ቃልዎን ይመርጣሉ።';
  }

  @override
  String get setPasswordSignOutAction => 'ውጣ እና የይለፍ ቃል አዘጋጅ';

  @override
  String get setPasswordConfirmTitle => 'አሁን ይውጣሉ?';

  @override
  String get setPasswordConfirmBody =>
      'ለGmailዎ \"የይለፍ ቃልዎን ረሱት?\" ተከፍቶ ወደ መግቢያ ገጹ ይወሰዳሉ።';

  @override
  String get barberInviteHelper =>
      'የግብዣ ኢሜይል እንልክላቸዋለን። Crown & Bladeን ከፍተው \"ተመዝገብ\" የሚለውን ይንኩ እና የይለፍ ቃላቸውን ለመፍጠር ይህን Gmail ይጠቀሙ።';

  @override
  String get barberInviteWaiting => 'ግብዣ ተልኳል — ምዝገባቸውን በመጠባበቅ ላይ';

  @override
  String get staffAcctSheetTitle => 'ፀጉር አስተካካይ ጨምር';

  @override
  String get staffAcctSheetIntro =>
      'ለፀጉር አስተካካይዎ የመግቢያ መለያ ይፍጠሩ። በዚህ ኢሜይል እና በጊዜያዊው የይለፍ ቃል ይገባሉ፣ ከዚያም የራሳቸውን የይለፍ ቃል ይመርጣሉ።';

  @override
  String get staffAcctEmailLabel => 'የመግቢያ ኢሜይል';

  @override
  String get staffAcctNameRequired => 'የፀጉር አስተካካዩን ስም ያስገቡ';

  @override
  String get staffAcctEmailRequired => 'ፀጉር አስተካካዩ የሚገባበትን ኢሜይል ያስገቡ';

  @override
  String get staffAcctTempPasswordLabel => 'ጊዜያዊ የይለፍ ቃል';

  @override
  String get staffAcctTempPasswordHelper =>
      'ከ8 እስከ 128 ቁምፊዎች፣ ፊደል እና ቁጥር ያካተተ። ፀጉር አስተካካዩ ለመጀመሪያ ጊዜ ሲገባ ይቀይረዋል።';

  @override
  String get staffAcctRegenerate => 'አዲስ የይለፍ ቃል ፍጠር';

  @override
  String get staffAcctCopyPassword => 'የይለፍ ቃሉን ቅዳ';

  @override
  String get staffAcctCopied => 'ተቀድቷል';

  @override
  String get staffAcctCreate => 'መለያ ፍጠር';

  @override
  String get staffAcctInviteSectionTitle => 'የCrown & Blade መለያ አላቸው?';

  @override
  String get staffAcctInviteInstead => 'በምትኩ በኢሜይል ጋብዝ';

  @override
  String get staffAcctEmailInUseTitle => 'ይህ ኢሜይል መለያ አለው';

  @override
  String staffAcctEmailInUseBody(String email) {
    return '$email አስቀድሞ ተመዝግቧል፣ ስለዚህ አዲስ መግቢያ ልንፈጥርለት አንችልም። በምትኩ ግብዣ ይላኩ፦ በራሳቸው የይለፍ ቃል ወይም በGoogle ገብተው የፀጉር ቤትዎ ፀጉር አስተካካይ ይሆናሉ።';
  }

  @override
  String get staffAcctSendInvite => 'በምትኩ ግብዣ ላክ';

  @override
  String staffAcctInviteSaved(String email) {
    return 'ግብዣው ተቀምጧል። $email በሚቀጥለው ሲገቡ የፀጉር ቤትዎ ፀጉር አስተካካይ ይሆናሉ።';
  }

  @override
  String get staffAcctCreatedTitle => 'የፀጉር አስተካካይ መለያ ተፈጥሯል';

  @override
  String staffAcctCreatedBody(String name) {
    return 'እነዚህን መረጃዎች ለ$name ይስጡ። በዚህ ኢሜይል እና የይለፍ ቃል ገብተው የራሳቸውን የይለፍ ቃል ይመርጣሉ።';
  }

  @override
  String get staffAcctEmailField => 'ኢሜይል';

  @override
  String get staffAcctShownOnce =>
      'ጊዜያዊ የይለፍ ቃሉ የሚታየው አሁን ብቻ ነው። ከመዝጋትዎ በፊት ይቅዱት ወይም ይጻፉት።';

  @override
  String get staffAcctCopyDetails => 'የመግቢያ መረጃውን ቅዳ';

  @override
  String get staffAcctDetailsHeading => 'የCrown & Blade ፀጉር አስተካካይ መግቢያ';

  @override
  String get staffAcctDetailsFooter => 'ከገቡ በኋላ የራስዎን የይለፍ ቃል ይምረጡ።';

  @override
  String get staffAcctWaitingFirstLogin => 'የመጀመሪያ መግቢያቸውን በመጠባበቅ ላይ';

  @override
  String get staffAcctActive => 'ንቁ';

  @override
  String get staffAcctLostPasswordHint =>
      'ጊዜያዊ የይለፍ ቃሉ ጠፍቷቸዋል? በመግቢያ ገጹ ላይ \"የይለፍ ቃልዎን ረሱት?\" የሚለውን ነክተው በኢሜይል ዳግም ማስጀመር ይችላሉ።';

  @override
  String get staffAcctForceTitle => 'አዲሱን የይለፍ ቃልዎን ይምረጡ';

  @override
  String get staffAcctForceIntro =>
      'ከፀጉር ቤትዎ በተሰጠ ጊዜያዊ የይለፍ ቃል ገብተዋል። ለመቀጠል የራስዎን የይለፍ ቃል ይምረጡ።';

  @override
  String get staffAcctForceTempLabel => 'ጊዜያዊ የይለፍ ቃል';

  @override
  String get staffAcctForceTempRequired => 'የተሰጠዎትን ጊዜያዊ የይለፍ ቃል ያስገቡ';

  @override
  String get staffAcctForceWrongTemp => 'ጊዜያዊ የይለፍ ቃሉ ትክክል አይደለም።';

  @override
  String get staffAcctForceSameAsTemp => 'ከጊዜያዊው የተለየ የይለፍ ቃል ይምረጡ።';

  @override
  String get staffAcctForceSave => 'አስቀምጥና ቀጥል';

  @override
  String get staffAcctForceDone => 'የይለፍ ቃሉ ተቀምጧል። እንኳን ደህና መጡ!';

  @override
  String get authContinue => 'ቀጥል';

  @override
  String get registerLinkIntro =>
      'ኢሜይልዎን ያስገቡ። ቀጥሎ የይለፍ ቃል ይፈጥራሉ፤ አድራሻውን ለማረጋገጥ የሚያስችል ሊንክ በኢሜይል እንልክልዎታለን።';

  @override
  String registerLinkPasswordIntro(String email) {
    return 'በ$email ይገባሉ። መለያዎን ከፈጠሩ በኋላ የማረጋገጫ ሊንክ በኢሜይል እንልክልዎታለን።';
  }

  @override
  String get verifyLinkSentTitle => 'ኢሜይልዎን ያረጋግጡ';

  @override
  String verifyLinkSentBody(String email) {
    return 'ወደ $email የማረጋገጫ ሊንክ ልከናል። ሊንኩን ይክፈቱ፣ ከዚያ ተመልሰው ይግቡ።';
  }

  @override
  String get verifyLinkNotSent =>
      'መለያዎ ተፈጥሯል፣ ነገር ግን የማረጋገጫ ሊንኩን መላክ አልቻልንም። እንደገና ለመሞከር \"ሊንኩን እንደገና ላክ\" የሚለውን ይንኩ።';

  @override
  String get verifiedLogIn => 'አረጋግጫለሁ — ግባ';

  @override
  String get resendLink => 'ሊንኩን እንደገና ላክ';

  @override
  String resendLinkIn(int seconds) {
    return 'በ$seconds ሰከንድ ውስጥ ሊንኩን እንደገና መላክ ይችላሉ';
  }

  @override
  String linkResent(String email) {
    return 'ወደ $email አዲስ ሊንክ ልከናል።';
  }

  @override
  String get resetLinkIntro =>
      'የመለያዎን ኢሜይል ያስገቡ፤ አዲስ የይለፍ ቃል ለመምረጥ የሚያስችል ሊንክ እንልክልዎታለን።';

  @override
  String get sendLink => 'ሊንክ ላክ';

  @override
  String get resetLinkSentTitle => 'ኢሜይልዎን ይመልከቱ';

  @override
  String resetLinkSentBody(String email) {
    return 'ወደ $email የይለፍ ቃል ዳግም ማስጀመሪያ ሊንክ ልከናል። ሊንኩን ይክፈቱ፣ አዲስ የይለፍ ቃል ይምረጡ፣ ከዚያ እዚህ ይግቡ።';
  }

  @override
  String get emailErrNotVerified => 'እባክዎ መጀመሪያ ኢሜይልዎን ያረጋግጡ።';

  @override
  String get resendVerificationLink => 'የማረጋገጫ ሊንኩን እንደገና ላክ';

  @override
  String get emailAlreadyVerified => 'ኢሜይልዎ አስቀድሞ ተረጋግጧል። እንደገና ይግቡ።';

  @override
  String ratingShopSummary(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ፀጉር አስተካካዮች ተገምግመዋል',
      one: '1 ፀጉር አስተካካይ ተገምግሟል',
    );
    return '$rating · $_temp0';
  }

  @override
  String ratingBarbersRated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ፀጉር አስተካካዮች ተገምግመዋል',
      one: '1 ፀጉር አስተካካይ ተገምግሟል',
    );
    return '$_temp0';
  }

  @override
  String ratingSeeBarberReviews(String name) {
    return 'የ$name ግምገማዎችን ይመልከቱ';
  }

  @override
  String get reviewsByBarber => 'ግምገማዎች በፀጉር አስተካካይ';

  @override
  String get ratePromptTitle => 'አቆራረጡ እንዴት ነበር?';

  @override
  String ratePromptBody(String barber, String service, String shop) {
    return 'በ$shop ለተደረገልዎ $service $barberን ይገምግሙ።';
  }

  @override
  String get ratePromptDismiss => 'አሁን አይደለም';

  @override
  String get admPayTab => 'ክፍያዎች';

  @override
  String get admPayIncomeLabel => 'የደንበኝነት ገቢ';

  @override
  String get admPayThisMonth => 'በዚህ ወር';

  @override
  String admPayVerifiedCount(int count) {
    return '$count የተረጋገጡ';
  }

  @override
  String admPayPendingCount(int count) {
    return '$count በመጠባበቅ ላይ';
  }

  @override
  String admPayRejectedCount(int count) {
    return '$count ውድቅ የተደረጉ';
  }

  @override
  String get admPayShopsActive => 'ንቁ';

  @override
  String get admPayShopsTrial => 'ሙከራ';

  @override
  String get admPayShopsPastDue => 'ጊዜው ያለፈ';

  @override
  String get admPayShopsSuspended => 'የታገዱ';

  @override
  String get admPayManage => 'ክፍያዎችን ያስተዳድሩ';

  @override
  String get admPayNoPending => 'ለግምገማ የሚጠብቅ የለም';

  @override
  String get admPayTypesTitle => 'የደንበኝነት ዓይነቶች እና ዋጋዎች';

  @override
  String get admPayTypesSubtitle =>
      'የጊዜ ርዝመቶችን እና ዋጋዎችን ይጨምሩ፣ ያስወግዱ ወይም ይቀይሩ፤ ባለቤቶች የሚከፍሉበትንም ያስቀምጡ';

  @override
  String get admPaySubscriptionsSubtitle =>
      'የእያንዳንዱ ፀጉር ቤት ዕቅድ፣ ሁኔታ እና ማብቂያ ቀን';

  @override
  String get admPayOnlineTitle => 'የኦንላይን ክፍያዎች';

  @override
  String get admPayOnlineSubtitle => 'ውሳኔ የሚያስፈልጋቸው የካርድ እና የቻፓ ክፍያዎች';

  @override
  String get admPayTypesOnSale => 'በሽያጭ ላይ ያሉ የደንበኝነት ዓይነቶች';

  @override
  String get admPayEdit => 'አስተካክል';

  @override
  String get refundsDueTitle => 'ተመላሽ የሚደረጉ ክፍያዎች';

  @override
  String refundsDueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ተመላሾች ይጠብቃሉ',
      one: '1 ተመላሽ ይጠብቃል',
    );
    return '$_temp0';
  }

  @override
  String get refundsEmpty =>
      'ተመላሽ የሚደረግ ክፍያ የለም። የተከፈለበት ቀጠሮ ሲሰረዝ ለደንበኛው የሚመለሰው ገንዘብ እዚህ ይታያል።';

  @override
  String refundBadgeDue(String amount) {
    return 'ተመላሽ ይጠበቃል · $amount';
  }

  @override
  String get refundBadgeRefunded => 'ተመልሷል';

  @override
  String get refundMarkButton => 'ተመልሷል በል';

  @override
  String get refundMarkTitle => 'ተመላሹ መላኩን አረጋግጥ';

  @override
  String refundMarkBody(String amount, String customer) {
    return '$amount ለ$customer መመለሱን ያረጋግጡ።';
  }

  @override
  String get refundMethodLabel => 'በምን ተመለሰ?';

  @override
  String refundMethodName(String method) {
    String _temp0 = intl.Intl.selectLogic(
      method,
      {
        'telebirr': 'ቴሌብር',
        'cbe': 'ሲቢኢ ብር',
        'bank': 'የባንክ ዝውውር',
        'cash': 'ጥሬ ገንዘብ',
        'chapa': 'ቻፓ',
        'other': 'ሌላ',
      },
    );
    return '$_temp0';
  }

  @override
  String get refundReferenceLabel => 'ማጣቀሻ (አማራጭ)';

  @override
  String get refundReferenceHint => 'የግብይት መለያ ወይም አጭር ማስታወሻ';

  @override
  String get refundMarkedSnack => 'ተመልሷል ተብሎ ተመዝግቧል። ደንበኛው ተነግሯቸዋል።';

  @override
  String refundReasonName(String reason) {
    String _temp0 = intl.Intl.selectLogic(
      reason,
      {
        'customer_cancelled': 'ደንበኛው ሰርዘዋል',
        'customer_late_cancel': 'ደንበኛው ዘግይተው ሰርዘዋል (ከፊል ተመላሽ)',
        'barber_cancelled': 'ፀጉር አስተካካዩ ሰርዘዋል',
        'shop_cancelled': 'ፀጉር ቤቱ ሰርዟል',
        'admin_cancelled': 'በመድረኩ ተሰርዟል',
        'request_declined': 'ጥያቄው ውድቅ ሆኗል',
        'request_expired': 'ጥያቄው ጊዜው አልፏል',
        'shop_deleted': 'ፀጉር ቤቱ ተወግዷል',
        'other': 'ተሰርዟል',
      },
    );
    return '$_temp0';
  }

  @override
  String refundFlaggedOn(String date) {
    return 'የተሰረዘው $date';
  }

  @override
  String get admPayReceiversMissing =>
      'ባለቤቶች የት እንደሚከፍሉ እንዲያውቁ የቴሌብር ቁጥርዎን ወይም የንግድ ባንክ ሂሳብዎን ያስገቡ።';

  @override
  String admPayExpiringTitle(int count) {
    return 'በ7 ቀናት ውስጥ የሚያበቁ ($count)';
  }

  @override
  String admPayDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቀናት ቀርተዋል',
      one: '1 ቀን ቀርቷል',
      zero: 'ዛሬ ያበቃል',
    );
    return '$_temp0';
  }

  @override
  String get admPayRecentTitle => 'የቅርብ ጊዜ ክፍያዎች';

  @override
  String get admPaySeeAll => 'ሁሉንም ይመልከቱ';

  @override
  String get admPayNoPayments => 'እስካሁን ምንም ክፍያ የለም።';

  @override
  String get errAccountDisabled => 'መለያዎ ታግዷል። ድጋፍ ሰጪን ያነጋግሩ።';

  @override
  String get admUsrSearchHint => 'በስም፣ በኢሜይል ወይም በስልክ ይፈልጉ';

  @override
  String admUsrFilterAll(int count) {
    return 'ሁሉም ($count)';
  }

  @override
  String admUsrFilterCustomers(int count) {
    return 'ደንበኞች ($count)';
  }

  @override
  String admUsrFilterOwners(int count) {
    return 'ባለቤቶች ($count)';
  }

  @override
  String admUsrFilterBarbers(int count) {
    return 'ፀጉር አስተካካዮች ($count)';
  }

  @override
  String admUsrFilterAdmins(int count) {
    return 'አስተዳዳሪዎች ($count)';
  }

  @override
  String admUsrFilterDisabled(int count) {
    return 'የታገዱ ($count)';
  }

  @override
  String get admUsrEmpty => 'ከፍለጋዎ ጋር የሚዛመድ ተጠቃሚ የለም።';

  @override
  String get admUsrDisabledChip => 'ታግዷል';

  @override
  String get admUsrYouChip => 'እርስዎ';

  @override
  String get admUsrEditTitle => 'ተጠቃሚን ያስተካክሉ';

  @override
  String get admUsrEmailLabel => 'ኢሜይል';

  @override
  String get admUsrPhoneLabel => 'ስልክ';

  @override
  String admUsrJoined(String date) {
    return 'የተቀላቀሉት $date';
  }

  @override
  String get admUsrRoleSection => 'ሚና';

  @override
  String get admUsrShopLabel => 'ፀጉር ቤት';

  @override
  String get admUsrPickShop => 'ፀጉር ቤት ይምረጡ';

  @override
  String get admUsrBarberProfileLabel => 'የፀጉር አስተካካይ መገለጫ';

  @override
  String get admUsrNewBarberProfile => 'አዲስ የፀጉር አስተካካይ መገለጫ ይፍጠሩ';

  @override
  String get admUsrSaveRole => 'ሚናውን ይቀይሩ';

  @override
  String get admUsrSelfNote =>
      'ይህ የራስዎ መለያ ነው። የራስዎን ሚና መቀየር ወይም ራስዎን ማገድ አይችሉም።';

  @override
  String admUsrRoleAtShop(String role, String shop) {
    return '$role በ$shop';
  }

  @override
  String get admUsrConfirmRoleTitle => 'ሚናው ይቀየር?';

  @override
  String admUsrConfirmRoleBody(String name, String role) {
    return '$name የሚሆኑት፦ $role።';
  }

  @override
  String admUsrEffectNewBarber(String shop) {
    return 'በ$shop አዲስ የፀጉር አስተካካይ መገለጫ ይፈጠራል።';
  }

  @override
  String admUsrEffectUnlinkBarber(String barber) {
    return 'የፀጉር አስተካካይ መገለጫቸው \"$barber\" ለታሪክ በፀጉር ቤቱ ይቆያል፤ ነገር ግን ቀጠሮ መቀበል ያቆማል።';
  }

  @override
  String admUsrEffectReleaseShop(String shop) {
    return 'ሌላ ባለቤት እስኪመድቡ ድረስ $shop ባለቤት አይኖረውም።';
  }

  @override
  String admUsrEffectPreviousOwner(String name, String shop) {
    return '$name አሁን የ$shop ባለቤት ናቸው፤ ደንበኛ ይሆናሉ።';
  }

  @override
  String admUsrEffectInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count በመጠባበቅ ላይ ያሉ ግብዣዎች ይሰረዛሉ።',
      one: '1 በመጠባበቅ ላይ ያለ ግብዣ ይሰረዛል።',
    );
    return '$_temp0';
  }

  @override
  String get admUsrRoleChanged => 'ሚናው ተቀይሯል።';

  @override
  String get admUsrAccountSection => 'መለያ';

  @override
  String get admUsrActive => 'ንቁ። ይህ ሰው መግባት ይችላል።';

  @override
  String admUsrDisabledOn(String date) {
    return 'የታገደው $date';
  }

  @override
  String admUsrDisabledReason(String reason) {
    return 'ምክንያት፦ $reason';
  }

  @override
  String get admUsrDisable => 'መለያውን ያግዱ';

  @override
  String get admUsrEnable => 'መለያውን ይክፈቱ';

  @override
  String admUsrDisableTitle(String name) {
    return '$name ይታገዱ?';
  }

  @override
  String get admUsrDisableBody =>
      'ወዲያውኑ ይወጣሉ፤ መለያውን እንደገና እስኪከፍቱ ድረስ መግባት አይችሉም።';

  @override
  String get admUsrReasonLabel => 'ምክንያት (አማራጭ)';

  @override
  String get admUsrCancelBookings => 'መጪ ቀጠሮዎቻቸውንም ይሰርዙ';

  @override
  String admUsrUpcomingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count መጪ ቀጠሮዎች',
      one: '1 መጪ ቀጠሮ',
      zero: 'መጪ ቀጠሮ የለም',
    );
    return '$_temp0';
  }

  @override
  String get admUsrUpcomingUnknown => 'መጪ ቀጠሮዎችን መቁጠር አልተቻለም።';

  @override
  String get admUsrBookingsStay => 'ሳጥኑን ካልመረጡ መጪ ቀጠሮዎቻቸው ይቆያሉ።';

  @override
  String admUsrDisabledSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'መለያው ታግዷል። $count ቀጠሮዎች ተሰርዘዋል።',
      one: 'መለያው ታግዷል። 1 ቀጠሮ ተሰርዟል።',
      zero: 'መለያው ታግዷል።',
    );
    return '$_temp0';
  }

  @override
  String admUsrEnableTitle(String name) {
    return '$name ይከፈትላቸው?';
  }

  @override
  String get admUsrEnableBody => 'እንደገና መግባት ይችላሉ።';

  @override
  String get admUsrEnabledSnack => 'መለያው ተከፍቷል።';

  @override
  String get admUsrErrNotAdmin => 'ተጠቃሚዎችን ማስተዳደር የሚችሉት አስተዳዳሪዎች ብቻ ናቸው።';

  @override
  String get admUsrErrNotFound => 'ይህ ተጠቃሚ ከእንግዲህ የለም።';

  @override
  String get admUsrErrSelf => 'የራስዎን ሚና መቀየር ወይም የራስዎን መለያ ማገድ አይችሉም።';

  @override
  String get admUsrErrLastAdmin => 'መድረኩ ቢያንስ አንድ ንቁ አስተዳዳሪ ያስፈልገዋል።';

  @override
  String get admUsrErrShopRequired => 'ፀጉር ቤት ይምረጡ።';

  @override
  String get admUsrErrShopNotFound =>
      'ያ ፀጉር ቤት ወይም የፀጉር አስተካካይ መገለጫ ከእንግዲህ የለም።';

  @override
  String get admUsrErrBarberTaken => 'ያ የፀጉር አስተካካይ መገለጫ የሌላ መለያ ነው።';

  @override
  String get admUsrErrNoChange => 'የሚቀየር ነገር የለም።';

  @override
  String admUsrErrReasonTooLong(int max) {
    return 'ምክንያቱ ቢበዛ $max ፊደላት ሊሆን ይችላል።';
  }

  @override
  String get nearbyLandmark => 'በአቅራቢያ ያለ መለያ ቦታ';

  @override
  String get nearbyLandmarkHint => 'ለምሳሌ ኤድና ሞል አጠገብ';

  @override
  String get nearbyLandmarkHelper =>
      'ብዙ ደንበኞች ፀጉር ቤትን የሚያገኙት በመለያ ቦታ ነው። በፀጉር ቤትዎ ገጽ ላይ በትልቁ ይታያል።';

  @override
  String get shopMapPinTitle => 'የካርታ ምልክት';

  @override
  String get shopMapPinHelp =>
      'የፀጉር ቤቱን ምልክት ለማስቀመጥ ካርታውን ይንኩ፣ ወይም ፀጉር ቤቱ ውስጥ ሆነው አሁን ያሉበትን ቦታ ይጠቀሙ።';

  @override
  String get useMyCurrentLocation => 'አሁን ያለሁበትን ቦታ ተጠቀም';

  @override
  String get findingYourLocation => 'ቦታዎን በመፈለግ ላይ...';

  @override
  String get removeMapPin => 'ምልክቱን አስወግድ';

  @override
  String get noMapPinYet => 'እስካሁን ምልክት የለም። አቅጣጫ ሲጠየቅ አድራሻውና መለያ ቦታው ይፈለጋሉ።';

  @override
  String mapPinCoordinates(String latitude, String longitude) {
    return 'ምልክት፦ $latitude፣ $longitude';
  }

  @override
  String get mapPinOutsideEthiopia =>
      'ይህ ምልክት ከኢትዮጵያ ውጭ ነው። ከማስቀመጥዎ በፊት ያረጋግጡ።';

  @override
  String get locationServiceOff =>
      'የአካባቢ አገልግሎት ጠፍቷል። በስልክዎ ቅንብሮች ውስጥ አብርተው እንደገና ይሞክሩ።';

  @override
  String get locationPermissionDenied =>
      'የአካባቢ ፈቃድ አልተሰጠም። አሁንም ምልክቱን ለማስቀመጥ ካርታውን መንካት ይችላሉ።';

  @override
  String get locationPermissionBlocked =>
      'ለCrown & Blade የአካባቢ ፈቃድ ታግዷል። በቅንብሮች ውስጥ ይፍቀዱ።';

  @override
  String get locationUnavailable =>
      'ቦታዎን ማግኘት አልተቻለም። እንደገና ይሞክሩ ወይም ካርታውን ይንኩ።';

  @override
  String get openSettingsAction => 'ቅንብሮች';

  @override
  String get shopDirections => 'አቅጣጫ';

  @override
  String get shopDirectionsFailed => 'የካርታ መተግበሪያ መክፈት አልተቻለም።';

  @override
  String get shopLandmarkLabel => 'መለያ ቦታ';

  @override
  String get nearMe => 'በአቅራቢያዬ';

  @override
  String get nearMeNeedsLocation => 'ፀጉር ቤቶችን በርቀት ለመደርደር የአካባቢ ፈቃድ ይስጡ።';

  @override
  String distanceKmAway(String km) {
    return '$km ኪ.ሜ ይርቃል';
  }

  @override
  String distanceMetersAway(int meters) {
    return '$meters ሜ ይርቃል';
  }

  @override
  String get shopMapSemantics => 'የፀጉር ቤቱን ቦታ የሚያሳይ ካርታ';
}
