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

  /// No description provided for @notifyChannelName.
  ///
  /// In en, this message translates to:
  /// **'Location sharing'**
  String get notifyChannelName;

  /// No description provided for @notifySharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing your location'**
  String get notifySharingTitle;

  /// No description provided for @notifySharingBody.
  ///
  /// In en, this message translates to:
  /// **'Your family circle can see where you are. Open ZT Family to pause.'**
  String get notifySharingBody;

  /// No description provided for @notifyPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location sharing paused'**
  String get notifyPausedTitle;

  /// No description provided for @notifyPausedBody.
  ///
  /// In en, this message translates to:
  /// **'Your circle sees \"Paused\". Open ZT Family to resume.'**
  String get notifyPausedBody;

  /// No description provided for @notifyUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Open ZT Family to keep sharing'**
  String get notifyUnlockTitle;

  /// No description provided for @notifyUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Someone joined or left your circle. Open the app once so your location reaches them again.'**
  String get notifyUnlockBody;

  /// No description provided for @notSharing.
  ///
  /// In en, this message translates to:
  /// **'Not sharing'**
  String get notSharing;

  /// No description provided for @pausedStatus.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedStatus;

  /// No description provided for @pausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Paused until {time}'**
  String pausedUntil(String time);

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery {percent}%'**
  String battery(int percent);

  /// No description provided for @batteryCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging {percent}%'**
  String batteryCharging(int percent);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @shareConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your location'**
  String get shareConsentTitle;

  /// No description provided for @shareConsentBody.
  ///
  /// In en, this message translates to:
  /// **'ZT Family collects your location to share it with the people in this circle, also when the app is closed or not in use. It is end-to-end encrypted: only the people in the circle can see it, not us and not the server.\n\nA notification shows while sharing is on. You can pause or stop at any time.'**
  String get shareConsentBody;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @locationPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'ZT Family needs location access to share where you are.'**
  String get locationPermissionNeeded;

  /// No description provided for @circleKeyNotReady.
  ///
  /// In en, this message translates to:
  /// **'This circle isn\'t ready on this phone yet. Try again in a moment.'**
  String get circleKeyNotReady;

  /// No description provided for @pauseHour.
  ///
  /// In en, this message translates to:
  /// **'For 1 hour'**
  String get pauseHour;

  /// No description provided for @pauseTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Until tomorrow morning'**
  String get pauseTomorrow;

  /// No description provided for @pauseUntilResumed.
  ///
  /// In en, this message translates to:
  /// **'Until I turn it back on'**
  String get pauseUntilResumed;

  /// No description provided for @shareOffTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re not sharing your location'**
  String get shareOffTitle;

  /// No description provided for @shareOffBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on sharing so this circle can see where you are.'**
  String get shareOffBody;

  /// No description provided for @shareOnTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re sharing your location'**
  String get shareOnTitle;

  /// No description provided for @shareOnBody.
  ///
  /// In en, this message translates to:
  /// **'Your circle sees where you are and your battery. It updates more often when you move.'**
  String get shareOnBody;

  /// No description provided for @sharePausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing is paused'**
  String get sharePausedTitle;

  /// No description provided for @sharePausedOpenBody.
  ///
  /// In en, this message translates to:
  /// **'Your circle sees \"Paused\" until you resume.'**
  String get sharePausedOpenBody;

  /// No description provided for @sharePausedUntilBody.
  ///
  /// In en, this message translates to:
  /// **'Your circle sees \"Paused\" until {time}.'**
  String sharePausedUntilBody(String time);

  /// No description provided for @shareLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing live'**
  String get shareLiveTitle;

  /// No description provided for @shareLiveBody.
  ///
  /// In en, this message translates to:
  /// **'Your circle sees you move every few seconds until {time}.'**
  String shareLiveBody(String time);

  /// No description provided for @shareStale.
  ///
  /// In en, this message translates to:
  /// **'Someone joined or left this circle. Sharing with it starts again now that the app is open.'**
  String get shareStale;

  /// No description provided for @needsAlwaysHint.
  ///
  /// In en, this message translates to:
  /// **'For sharing to keep going after your phone restarts, allow location \"All the time\" for ZT Family.'**
  String get needsAlwaysHint;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @shareTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Share my location'**
  String get shareTurnOn;

  /// No description provided for @shareTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get shareTurnOff;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @shareLiveHour.
  ///
  /// In en, this message translates to:
  /// **'Share live for 1 hour'**
  String get shareLiveHour;

  /// No description provided for @stopLive.
  ///
  /// In en, this message translates to:
  /// **'Stop live'**
  String get stopLive;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;
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
