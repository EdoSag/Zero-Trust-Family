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
}
