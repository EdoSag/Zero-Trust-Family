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
  String get locationSoonTitle => 'שיתוף מיקום מגיע בהמשך';

  @override
  String get locationSoonBody =>
      'הגרסה הזאת מקימה את המעגל. שיתוף המיקום, מקומות וצ׳ק־אין יגיעו בעדכונים הבאים. בינתיים המיקום של אף אחד לא משותף.';

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
}
