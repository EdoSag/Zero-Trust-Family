import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get homeTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

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

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start your family circle'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'A circle is the group of people who share with each other. Create one and invite your family, or join a circle you were invited to. Everything in it is end-to-end encrypted: only the people in the circle can read it.'**
  String get emptyBody;

  /// No description provided for @createCircle.
  ///
  /// In en, this message translates to:
  /// **'Create a circle'**
  String get createCircle;

  /// No description provided for @joinCircle.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite'**
  String get joinCircle;

  /// No description provided for @newCircleTitle.
  ///
  /// In en, this message translates to:
  /// **'New circle'**
  String get newCircleTitle;

  /// No description provided for @circleName.
  ///
  /// In en, this message translates to:
  /// **'Circle name'**
  String get circleName;

  /// No description provided for @circleNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Family'**
  String get circleNameHint;

  /// No description provided for @circleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get circleNameRequired;

  /// No description provided for @yourNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name in the circle'**
  String get yourNameTitle;

  /// No description provided for @renameCircle.
  ///
  /// In en, this message translates to:
  /// **'Rename circle'**
  String get renameCircle;

  /// No description provided for @unnamedCircle.
  ///
  /// In en, this message translates to:
  /// **'Family circle'**
  String get unnamedCircle;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// No description provided for @membersHeading.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersHeading;

  /// No description provided for @youSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String youSuffix(String name);

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @unnamedMember.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get unnamedMember;

  /// No description provided for @manageMembers.
  ///
  /// In en, this message translates to:
  /// **'Members and invites'**
  String get manageMembers;

  /// No description provided for @manageMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Invite, let people in, remove, or leave the circle'**
  String get manageMembersHint;

  /// No description provided for @inviteSomeone.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteSomeone;

  /// No description provided for @circleDescription.
  ///
  /// In en, this message translates to:
  /// **'Only the people in this circle can read what is shared in it.'**
  String get circleDescription;

  /// No description provided for @waitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be let in'**
  String get waitingTitle;

  /// No description provided for @waitingBody.
  ///
  /// In en, this message translates to:
  /// **'The circle\'s owner has to compare a code with you. Tap to see it.'**
  String get waitingBody;

  /// No description provided for @stopWaiting.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get stopWaiting;

  /// No description provided for @locationSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Location sharing comes next'**
  String get locationSoonTitle;

  /// No description provided for @locationSoonBody.
  ///
  /// In en, this message translates to:
  /// **'This version sets up your circle. Sharing where you are, places and check-ins arrive in the next updates. Nobody\'s location is shared yet.'**
  String get locationSoonBody;

  /// No description provided for @couldNotCreate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the circle. Check your internet connection and try again.'**
  String get couldNotCreate;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your internet connection and try again.'**
  String get couldNotSave;

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your circles. Check your internet connection.'**
  String get couldNotLoad;

  /// No description provided for @circleGone.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer in this circle.'**
  String get circleGone;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
