// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get homeTitle => 'משפחה';

  @override
  String get settings => 'הגדרות';

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמירה';

  @override
  String get create => 'יצירה';

  @override
  String get remove => 'הסרה';

  @override
  String get emptyTitle => 'פותחים מעגל משפחתי';

  @override
  String get emptyBody =>
      'מעגל הוא קבוצת האנשים שמשתפים זה עם זה. אפשר ליצור מעגל ולהזמין את המשפחה, או להצטרף למעגל שהוזמנתם אליו. כל מה שבמעגל מוצפן מקצה לקצה: רק מי שבמעגל יכול לקרוא אותו.';

  @override
  String get createCircle => 'יצירת מעגל';

  @override
  String get joinCircle => 'הצטרפות עם הזמנה';

  @override
  String get newCircleTitle => 'מעגל חדש';

  @override
  String get circleName => 'שם המעגל';

  @override
  String get circleNameHint => 'לדוגמה: משפחה';

  @override
  String get circleNameRequired => 'צריך לכתוב שם';

  @override
  String get yourNameTitle => 'השם שלך במעגל';

  @override
  String get renameCircle => 'שינוי שם המעגל';

  @override
  String get unnamedCircle => 'מעגל משפחתי';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חברים',
      one: 'חבר אחד',
    );
    return '$_temp0';
  }

  @override
  String get membersHeading => 'חברי המעגל';

  @override
  String youSuffix(String name) {
    return '$name (את/ה)';
  }

  @override
  String get owner => 'בעלים';

  @override
  String get unnamedMember => 'ללא שם';

  @override
  String get manageMembers => 'חברים והזמנות';

  @override
  String get manageMembersHint => 'הזמנה, אישור מצטרפים, הסרה או עזיבת המעגל';

  @override
  String get inviteSomeone => 'הזמנת מישהו';

  @override
  String get circleDescription =>
      'רק מי שבמעגל הזה יכול לקרוא את מה שמשותף בו.';

  @override
  String get waitingTitle => 'ממתינים לאישור';

  @override
  String get waitingBody =>
      'הבעלים של המעגל צריכים להשוות איתך קוד. אפשר להקיש כדי לראות אותו.';

  @override
  String get stopWaiting => 'הפסקת ההמתנה';

  @override
  String get couldNotCreate =>
      'לא הצלחנו ליצור את המעגל. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get couldNotSave =>
      'השמירה נכשלה. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String get couldNotLoad =>
      'לא הצלחנו לטעון את המעגלים. כדאי לבדוק את החיבור לאינטרנט.';

  @override
  String get circleGone => 'כבר אינך במעגל הזה.';

  @override
  String get notifyChannelName => 'שיתוף מיקום';

  @override
  String get notifySharingTitle => 'המיקום שלך משותף';

  @override
  String get notifySharingBody =>
      'המעגל המשפחתי רואה איפה אתם. כדי להשהות, פתחו את ZT Family.';

  @override
  String get notifyPausedTitle => 'שיתוף המיקום מושהה';

  @override
  String get notifyPausedBody =>
      'המעגל רואה \"מושהה\". כדי לחדש, פתחו את ZT Family.';

  @override
  String get notifyUnlockTitle => 'כדי להמשיך לשתף, פתחו את ZT Family';

  @override
  String get notifyUnlockBody =>
      'מישהו הצטרף למעגל או עזב אותו. פתחו את האפליקציה פעם אחת כדי שהמיקום שלכם יגיע אליהם שוב.';

  @override
  String get notSharing => 'לא משתף';

  @override
  String get pausedStatus => 'מושהה';

  @override
  String pausedUntil(String time) {
    return 'מושהה עד $time';
  }

  @override
  String battery(int percent) {
    return 'סוללה $percent%';
  }

  @override
  String batteryCharging(int percent) {
    return 'בטעינה $percent%';
  }

  @override
  String get justNow => 'עכשיו';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count דקות',
      one: 'לפני דקה',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count שעות',
      one: 'לפני שעה',
    );
    return '$_temp0';
  }

  @override
  String get shareConsentTitle => 'שיתוף המיקום שלך';

  @override
  String get shareConsentBody =>
      'ZT Family אוספת את המיקום שלך כדי לשתף אותו עם האנשים במעגל הזה, גם כשהאפליקציה סגורה או לא בשימוש. הוא מוצפן מקצה לקצה: רק האנשים במעגל יכולים לראות אותו, לא אנחנו ולא השרת.\n\nכל עוד השיתוף פעיל מוצגת התראה. אפשר להשהות או להפסיק בכל רגע.';

  @override
  String get notNow => 'לא עכשיו';

  @override
  String get continueLabel => 'המשך';

  @override
  String get locationPermissionNeeded =>
      'ZT Family צריכה גישה למיקום כדי לשתף איפה אתם.';

  @override
  String get circleKeyNotReady =>
      'המעגל הזה עוד לא מוכן בטלפון הזה. נסו שוב בעוד רגע.';

  @override
  String get pauseHour => 'לשעה';

  @override
  String get pauseTomorrow => 'עד מחר בבוקר';

  @override
  String get pauseUntilResumed => 'עד שאפעיל שוב';

  @override
  String get shareOffTitle => 'המיקום שלך לא משותף';

  @override
  String get shareOffBody => 'הפעילו שיתוף כדי שהמעגל הזה יראה איפה אתם.';

  @override
  String get shareOnTitle => 'המיקום שלך משותף';

  @override
  String get shareOnBody =>
      'המעגל רואה איפה אתם ואת מצב הסוללה. העדכון תכוף יותר כשאתם בתנועה.';

  @override
  String get sharePausedTitle => 'השיתוף מושהה';

  @override
  String get sharePausedOpenBody => 'המעגל רואה \"מושהה\" עד שתחדשו.';

  @override
  String sharePausedUntilBody(String time) {
    return 'המעגל רואה \"מושהה\" עד $time.';
  }

  @override
  String get shareLiveTitle => 'שיתוף חי';

  @override
  String shareLiveBody(String time) {
    return 'המעגל רואה אתכם זזים כל כמה שניות, עד $time.';
  }

  @override
  String get shareStale =>
      'מישהו הצטרף למעגל או עזב אותו. השיתוף איתו מתחדש עכשיו, כשהאפליקציה פתוחה.';

  @override
  String get needsAlwaysHint =>
      'כדי שהשיתוף ימשיך גם אחרי הפעלה מחדש של הטלפון, אשרו ל־ZT Family גישה למיקום \"כל הזמן\".';

  @override
  String get openSettings => 'פתיחת ההגדרות';

  @override
  String get shareTurnOn => 'שיתוף המיקום שלי';

  @override
  String get shareTurnOff => 'הפסקת השיתוף';

  @override
  String get pause => 'השהיה';

  @override
  String get resume => 'חידוש';

  @override
  String get shareLiveHour => 'שיתוף חי לשעה';

  @override
  String get stopLive => 'הפסקת שיתוף חי';

  @override
  String get showOnMap => 'הצגה במפה';

  @override
  String get notifyAlertsTitle => 'התראות משפחה פעילות';

  @override
  String get notifyAlertsBody => 'תקבלו הודעה כשמישהו מגיע למקום או יוצא ממנו.';

  @override
  String alertArrived(String name, String place) {
    return '$name הגיע/ה ל$place';
  }

  @override
  String alertLeft(String name, String place) {
    return '$name יצא/ה מ$place';
  }

  @override
  String alertArrivedSomewhere(String name) {
    return '$name הגיע/ה למקום שמור';
  }

  @override
  String alertLeftSomewhere(String name) {
    return '$name יצא/ה ממקום שמור';
  }

  @override
  String alertAt(String time) {
    return 'בשעה $time';
  }

  @override
  String get alertsChannelName => 'התראות משפחה';

  @override
  String get alertsQuietChannelName => 'התראות משפחה בשעות שקטות';

  @override
  String get placesHeading => 'מקומות';

  @override
  String get placesEmpty =>
      'הוסיפו בית, בית ספר או עבודה כדי לדעת מתי מישהו מגיע או יוצא.';

  @override
  String placeHere(String names) {
    return 'כאן עכשיו: $names';
  }

  @override
  String get addPlace => 'הוספת מקום';

  @override
  String get editPlace => 'עריכת מקום';

  @override
  String get placeName => 'שם';

  @override
  String get placeNameHint => 'בית, בית ספר, עבודה';

  @override
  String get placeNameRequired => 'צריך להזין שם';

  @override
  String get placeWhere => 'איפה';

  @override
  String get placeNoPositionYet => 'עדיין לא נבחר מיקום';

  @override
  String get placeUseHere => 'להשתמש במיקום הנוכחי שלי';

  @override
  String get placePaste => 'או להדביק קואורדינטות או קישור למפה';

  @override
  String get placeBadPaste => 'לא נמצא מיקום בטקסט הזה';

  @override
  String get placeNoLocation => 'לא הצלחנו לקבל את המיקום. בדקו שהמיקום פועל.';

  @override
  String get placeNeedsPosition => 'צריך לבחור איפה המקום';

  @override
  String get placeSize => 'גודל';

  @override
  String meters(int count) {
    return '$count מ׳';
  }

  @override
  String get placeSizeHint =>
      'מקום גדול יותר מזהה הגעה מוקדם יותר אבל בפחות דיוק. ההגעות מחושבות בכל טלפון, והשרת אף פעם לא רואה את המקומות שלכם.';

  @override
  String get tooManyPlaces => 'במעגל הזה כבר יש את המספר המרבי של מקומות.';

  @override
  String get removePlace => 'הסרת מקום';

  @override
  String removePlaceTitle(String name) {
    return 'להסיר את $name?';
  }

  @override
  String get removePlaceBody => 'אף אחד במעגל לא יקבל עוד התראות עליו.';

  @override
  String get recentHeading => 'היום';

  @override
  String get alertsTitle => 'התראות בטלפון הזה';

  @override
  String get alertsBody =>
      'קבלו הודעה כשמישהו מגיע למקום או יוצא ממנו, גם כש-ZT Family נעולה. כדי לקרוא אותן, הטלפון שומר את מפתח המיקום של המעגל ברכיב האבטחה שלו.';

  @override
  String get alertsAbout => 'התראות על';

  @override
  String get quietHours => 'שעות שקטות';

  @override
  String get quietOff => 'כבוי';

  @override
  String quietOnSummary(String from, String to) {
    return '$from עד $to, התראות בלי צליל';
  }

  @override
  String quietRange(String from, String to) {
    return '$from עד $to';
  }

  @override
  String get quietCustom => 'בחירת שעות';

  @override
  String get quietFrom => 'שקט החל מ';

  @override
  String get quietTo => 'שקט עד';
}
