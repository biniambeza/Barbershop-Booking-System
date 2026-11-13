// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

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
  String get invalidEmailShort => 'ትክክለኛ ኢሜይል ያስገቡ';

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
  String get noPlatformAppointments => 'እስካሁን በመድረኩ የተመዘገበ ቀጠሮ የለም';

  @override
  String scheduleAt(String when) {
    return 'ቀጠሮ፦ $when';
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
  String get reviewsRateAction => 'ደረጃ ይስጡ';

  @override
  String get reviewsYourRating => 'የሰጡት ደረጃ';

  @override
  String get reviewsRateTitle => 'ጉብኝትዎን ይገምግሙ';

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
  String get reviewsCommentHint => 'ምን ወደዱ? ምን ቢሻሻል ይሻላል?';

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
    return 'ባለ 6 አሃዝ ኮድ ወደ $email ልከናል';
  }

  @override
  String get codeLabel => 'ባለ 6 አሃዝ ኮድ';

  @override
  String get verifyAndCreate => 'አረጋግጥ እና መለያ ፍጠር';

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
  String get resetButton => 'የይለፍ ቃል ቀይር';

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
      'ይህ የኢሜይል አድራሻ አልተረጋገጠም። በGoogle ይግቡ ወይም ድጋፍ ሰጪን ያነጋግሩ።';

  @override
  String get emailErrSendFailed => 'ኢሜይሉን መላክ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get emailErrInvalidInput => 'ያስገቡትን መረጃ ያረጋግጡ እና እንደገና ይሞክሩ።';

  @override
  String emailErrInvalidCodeAttempts(int count) {
    return 'ኮዱ ትክክል አይደለም። የቀሩ ሙከራዎች፦ $count።';
  }

  @override
  String emailErrRateLimitedMinutes(int minutes) {
    return 'በጣም ብዙ ሙከራዎች። ከ$minutes ደቂቃ በኋላ እንደገና ይሞክሩ።';
  }
}
