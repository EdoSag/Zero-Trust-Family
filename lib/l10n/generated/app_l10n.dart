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
  /// **'ZT Family collects your location to share it with the people in this circle, also when the app is closed or not in use. It is end-to-end encrypted: only the people in the circle can see it, not us and not the server.\n\nThe circle also sees where you have been, for as long as it keeps history (7 days unless its owner changes it). You can erase yours at any time.\n\nA notification shows while sharing is on. You can pause or stop at any time.'**
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

  /// No description provided for @notifyAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Family alerts are on'**
  String get notifyAlertsTitle;

  /// No description provided for @notifyAlertsBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be told when someone arrives at or leaves a place.'**
  String get notifyAlertsBody;

  /// No description provided for @alertArrived.
  ///
  /// In en, this message translates to:
  /// **'{name} arrived at {place}'**
  String alertArrived(String name, String place);

  /// No description provided for @alertLeft.
  ///
  /// In en, this message translates to:
  /// **'{name} left {place}'**
  String alertLeft(String name, String place);

  /// No description provided for @alertArrivedSomewhere.
  ///
  /// In en, this message translates to:
  /// **'{name} arrived at a saved place'**
  String alertArrivedSomewhere(String name);

  /// No description provided for @alertLeftSomewhere.
  ///
  /// In en, this message translates to:
  /// **'{name} left a saved place'**
  String alertLeftSomewhere(String name);

  /// No description provided for @alertAt.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String alertAt(String time);

  /// No description provided for @alertsChannelName.
  ///
  /// In en, this message translates to:
  /// **'Family alerts'**
  String get alertsChannelName;

  /// No description provided for @alertsQuietChannelName.
  ///
  /// In en, this message translates to:
  /// **'Family alerts during quiet hours'**
  String get alertsQuietChannelName;

  /// No description provided for @placesHeading.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesHeading;

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add Home, School or Work to know when someone arrives or leaves.'**
  String get placesEmpty;

  /// No description provided for @placeHere.
  ///
  /// In en, this message translates to:
  /// **'Here now: {names}'**
  String placeHere(String names);

  /// No description provided for @addPlace.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get addPlace;

  /// No description provided for @editPlace.
  ///
  /// In en, this message translates to:
  /// **'Edit place'**
  String get editPlace;

  /// No description provided for @placeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get placeName;

  /// No description provided for @placeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Home, School, Work'**
  String get placeNameHint;

  /// No description provided for @placeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get placeNameRequired;

  /// No description provided for @placeWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get placeWhere;

  /// No description provided for @placeNoPositionYet.
  ///
  /// In en, this message translates to:
  /// **'No position yet'**
  String get placeNoPositionYet;

  /// No description provided for @placeUseHere.
  ///
  /// In en, this message translates to:
  /// **'Use where I am now'**
  String get placeUseHere;

  /// No description provided for @placePaste.
  ///
  /// In en, this message translates to:
  /// **'Or paste coordinates or a map link'**
  String get placePaste;

  /// No description provided for @placeBadPaste.
  ///
  /// In en, this message translates to:
  /// **'No position found in that text'**
  String get placeBadPaste;

  /// No description provided for @placeNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your position. Check that location is on.'**
  String get placeNoLocation;

  /// No description provided for @placeNeedsPosition.
  ///
  /// In en, this message translates to:
  /// **'Choose where the place is'**
  String get placeNeedsPosition;

  /// No description provided for @placeSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get placeSize;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'{count} m'**
  String meters(int count);

  /// No description provided for @placeSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Bigger places notice arrivals sooner but less exactly. Arrivals are worked out on each phone; the server never sees your places.'**
  String get placeSizeHint;

  /// No description provided for @tooManyPlaces.
  ///
  /// In en, this message translates to:
  /// **'This circle has as many places as it can keep.'**
  String get tooManyPlaces;

  /// No description provided for @removePlace.
  ///
  /// In en, this message translates to:
  /// **'Remove place'**
  String get removePlace;

  /// No description provided for @removePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removePlaceTitle(String name);

  /// No description provided for @removePlaceBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody in the circle will get alerts for it any more.'**
  String get removePlaceBody;

  /// No description provided for @recentHeading.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get recentHeading;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts on this phone'**
  String get alertsTitle;

  /// No description provided for @alertsBody.
  ///
  /// In en, this message translates to:
  /// **'Get a notification when someone arrives at or leaves a place, also while ZT Family is locked. To read them, this phone keeps the circle\'s location key in its secure hardware.'**
  String get alertsBody;

  /// No description provided for @alertsAbout.
  ///
  /// In en, this message translates to:
  /// **'Alerts about'**
  String get alertsAbout;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @quietOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get quietOff;

  /// No description provided for @quietOnSummary.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}, alerts without sound'**
  String quietOnSummary(String from, String to);

  /// No description provided for @quietRange.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String quietRange(String from, String to);

  /// No description provided for @quietCustom.
  ///
  /// In en, this message translates to:
  /// **'Choose times'**
  String get quietCustom;

  /// No description provided for @quietFrom.
  ///
  /// In en, this message translates to:
  /// **'Quiet from'**
  String get quietFrom;

  /// No description provided for @quietTo.
  ///
  /// In en, this message translates to:
  /// **'Quiet until'**
  String get quietTo;

  /// No description provided for @eventCheckin.
  ///
  /// In en, this message translates to:
  /// **'{name} checked in'**
  String eventCheckin(String name);

  /// No description provided for @eventAsk.
  ///
  /// In en, this message translates to:
  /// **'{name} asks you to check in'**
  String eventAsk(String name);

  /// No description provided for @eventTimer.
  ///
  /// In en, this message translates to:
  /// **'{name} started a safety timer until {time}'**
  String eventTimer(String name, String time);

  /// No description provided for @eventTimerEnd.
  ///
  /// In en, this message translates to:
  /// **'{name} is OK'**
  String eventTimerEnd(String name);

  /// No description provided for @eventOverdue.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t check in by {time}'**
  String eventOverdue(String name, String time);

  /// No description provided for @eventSos.
  ///
  /// In en, this message translates to:
  /// **'{name} sent an SOS'**
  String eventSos(String name);

  /// No description provided for @eventSosEnd.
  ///
  /// In en, this message translates to:
  /// **'{name} is safe now'**
  String eventSosEnd(String name);

  /// No description provided for @sosChannelName.
  ///
  /// In en, this message translates to:
  /// **'SOS and missed check-ins'**
  String get sosChannelName;

  /// No description provided for @timerReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your safety timer ends at {time}'**
  String timerReminderTitle(String time);

  /// No description provided for @timerReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Tap I\'m OK, or your circle is alerted.'**
  String get timerReminderBody;

  /// No description provided for @imOk.
  ///
  /// In en, this message translates to:
  /// **'I\'m OK'**
  String get imOk;

  /// No description provided for @imSafe.
  ///
  /// In en, this message translates to:
  /// **'I\'m safe'**
  String get imSafe;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @couldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check your connection and try again.'**
  String get couldNotSend;

  /// No description provided for @safetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safetyTitle;

  /// No description provided for @safetyNeedsSharing.
  ///
  /// In en, this message translates to:
  /// **'Share your location with this circle to use check-ins, the safety timer and SOS.'**
  String get safetyNeedsSharing;

  /// No description provided for @safetyBody.
  ///
  /// In en, this message translates to:
  /// **'Check-ins and SOS go to everyone in this circle with your location.'**
  String get safetyBody;

  /// No description provided for @checkinButton.
  ///
  /// In en, this message translates to:
  /// **'I\'m here'**
  String get checkinButton;

  /// No description provided for @checkinTitle.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkinTitle;

  /// No description provided for @checkinNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get checkinNote;

  /// No description provided for @checkinNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Got to practice'**
  String get checkinNoteHint;

  /// No description provided for @checkinSent.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkinSent;

  /// No description provided for @askButton.
  ///
  /// In en, this message translates to:
  /// **'Ask someone to check in'**
  String get askButton;

  /// No description provided for @askWho.
  ///
  /// In en, this message translates to:
  /// **'Who should check in?'**
  String get askWho;

  /// No description provided for @askSent.
  ///
  /// In en, this message translates to:
  /// **'Asked {name} to check in'**
  String askSent(String name);

  /// No description provided for @timerButton.
  ///
  /// In en, this message translates to:
  /// **'Safety timer'**
  String get timerButton;

  /// No description provided for @timerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Alert my circle if I don\'t check in'**
  String get timerQuestion;

  /// No description provided for @timerPick.
  ///
  /// In en, this message translates to:
  /// **'By a time I choose'**
  String get timerPick;

  /// No description provided for @timerStarted.
  ///
  /// In en, this message translates to:
  /// **'Timer set until {time}'**
  String timerStarted(String time);

  /// No description provided for @timerActive.
  ///
  /// In en, this message translates to:
  /// **'Safety timer until {time}. If you don\'t tap I\'m OK by then, your circle is alerted and sees you live.'**
  String timerActive(String time);

  /// No description provided for @timerEnded.
  ///
  /// In en, this message translates to:
  /// **'Timer ended'**
  String get timerEnded;

  /// No description provided for @sosButton.
  ///
  /// In en, this message translates to:
  /// **'Hold for SOS'**
  String get sosButton;

  /// No description provided for @sosHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the button for 2 seconds to send an SOS'**
  String get sosHoldHint;

  /// No description provided for @sosSent.
  ///
  /// In en, this message translates to:
  /// **'SOS sent. Your circle sees you live for an hour.'**
  String get sosSent;

  /// No description provided for @sosActive.
  ///
  /// In en, this message translates to:
  /// **'SOS sent. Your circle sees where you are, live.'**
  String get sosActive;

  /// No description provided for @sosEnded.
  ///
  /// In en, this message translates to:
  /// **'Your circle knows you\'re safe'**
  String get sosEnded;

  /// No description provided for @timerInMinutes.
  ///
  /// In en, this message translates to:
  /// **'In {minutes} minutes'**
  String timerInMinutes(int minutes);

  /// No description provided for @timerInHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{In 1 hour} other{In {hours} hours}}'**
  String timerInHours(int hours);

  /// No description provided for @eventPoint.
  ///
  /// In en, this message translates to:
  /// **'{name} was here'**
  String eventPoint(String name);

  /// No description provided for @historyHeading.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyHeading;

  /// No description provided for @historyOf.
  ///
  /// In en, this message translates to:
  /// **'{name}: history'**
  String historyOf(String name);

  /// No description provided for @historyOpen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyOpen;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing for this day. History shows only while sharing is on.'**
  String get historyEmpty;

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyYesterday;

  /// No description provided for @historyAt.
  ///
  /// In en, this message translates to:
  /// **'At {place}'**
  String historyAt(String place);

  /// No description provided for @historyStayed.
  ///
  /// In en, this message translates to:
  /// **'Stayed in one spot'**
  String get historyStayed;

  /// No description provided for @historySince.
  ///
  /// In en, this message translates to:
  /// **'Since {time}'**
  String historySince(String time);

  /// No description provided for @historyRange.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}, {length}'**
  String historyRange(String from, String to, String length);

  /// No description provided for @historyMoved.
  ///
  /// In en, this message translates to:
  /// **'On the move: {distance}, {length}'**
  String historyMoved(String distance, String length);

  /// No description provided for @kilometers.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kilometers(String km);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHours(int hours, int minutes);

  /// No description provided for @historyDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep history for'**
  String get historyDaysTitle;

  /// No description provided for @historyDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String historyDays(int days);

  /// No description provided for @historyKeptBody.
  ///
  /// In en, this message translates to:
  /// **'Places people were, check-ins and alerts, end-to-end encrypted. The server deletes them after this many days.'**
  String get historyKeptBody;

  /// No description provided for @historyOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the circle\'s owner can change this.'**
  String get historyOwnerOnly;

  /// No description provided for @plusBadge.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get plusBadge;

  /// No description provided for @historyNeedsPlus.
  ///
  /// In en, this message translates to:
  /// **'Keeping history for more than 7 days is part of Plus. Safety (the map, check-ins, the safety timer and SOS) is always free.'**
  String get historyNeedsPlus;

  /// No description provided for @placesNeedPlus.
  ///
  /// In en, this message translates to:
  /// **'More than {count} places is part of Plus. Safety (the map, check-ins, the safety timer and SOS) is always free.'**
  String placesNeedPlus(int count);

  /// No description provided for @seePlans.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get seePlans;

  /// No description provided for @eraseMyHistory.
  ///
  /// In en, this message translates to:
  /// **'Erase my history in this circle'**
  String get eraseMyHistory;

  /// No description provided for @eraseMyHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes every position, check-in and alert you sent to this circle. Your current location stays shared while sharing is on.'**
  String get eraseMyHistoryBody;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @historyErased.
  ///
  /// In en, this message translates to:
  /// **'Your history in this circle was erased'**
  String get historyErased;

  /// No description provided for @historyCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the history. Check your internet connection.'**
  String get historyCouldNotLoad;

  /// No description provided for @eventCrash.
  ///
  /// In en, this message translates to:
  /// **'{name} may have been in a car crash'**
  String eventCrash(String name);

  /// No description provided for @eventDrive.
  ///
  /// In en, this message translates to:
  /// **'{name} drove {km} km (top speed {kmh} km/h)'**
  String eventDrive(String name, String km, String kmh);

  /// No description provided for @crashCountdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Were you in a crash?'**
  String get crashCountdownTitle;

  /// No description provided for @crashCountdownBody.
  ///
  /// In en, this message translates to:
  /// **'Your circles get an SOS with your location at {time}, unless you tap I\'m OK.'**
  String crashCountdownBody(String time);

  /// No description provided for @crashSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send SOS now'**
  String get crashSendNow;

  /// No description provided for @crashSosSentTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS sent to your circles'**
  String get crashSosSentTitle;

  /// No description provided for @crashSosSentBody.
  ///
  /// In en, this message translates to:
  /// **'They see your live location for an hour. Tap I\'m safe when you are.'**
  String get crashSosSentBody;

  /// No description provided for @drivingTitle.
  ///
  /// In en, this message translates to:
  /// **'Driving'**
  String get drivingTitle;

  /// No description provided for @drivingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drive summaries and crash detection'**
  String get drivingSubtitle;

  /// No description provided for @drivingNeedsSharing.
  ///
  /// In en, this message translates to:
  /// **'Turn on location sharing with this circle to use these.'**
  String get drivingNeedsSharing;

  /// No description provided for @drivesSwitch.
  ///
  /// In en, this message translates to:
  /// **'Drive summaries'**
  String get drivesSwitch;

  /// No description provided for @drivesSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'Keeps a summary of each drive on this phone: distance, speed, hard braking and phone use. Uses satellites every second while you drive.'**
  String get drivesSwitchBody;

  /// No description provided for @shareDrivesSwitch.
  ///
  /// In en, this message translates to:
  /// **'Share my drives with this circle'**
  String get shareDrivesSwitch;

  /// No description provided for @shareDrivesBody.
  ///
  /// In en, this message translates to:
  /// **'The circle sees each drive\'s summary in your history, end-to-end encrypted.'**
  String get shareDrivesBody;

  /// No description provided for @shareDrivesNeedsPlus.
  ///
  /// In en, this message translates to:
  /// **'Sharing drive summaries with a circle is part of Plus. Your own drive summaries and crash detection stay free.'**
  String get shareDrivesNeedsPlus;

  /// No description provided for @crashSwitch.
  ///
  /// In en, this message translates to:
  /// **'Crash detection'**
  String get crashSwitch;

  /// No description provided for @crashSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'If the phone feels a hard crash while driving and then stops, it rings for 60 seconds, then sends an SOS with your location to all your circles.'**
  String get crashSwitchBody;

  /// No description provided for @crashDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Crash detection can miss a crash or ring when there was none. It does not call emergency services: in an emergency, call your local emergency number.'**
  String get crashDisclaimer;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @myDrivesHeading.
  ///
  /// In en, this message translates to:
  /// **'My drives (on this phone)'**
  String get myDrivesHeading;

  /// No description provided for @noDrivesYet.
  ///
  /// In en, this message translates to:
  /// **'No drives yet. They show here after you drive with drive summaries on.'**
  String get noDrivesYet;

  /// No description provided for @driveSpeeds.
  ///
  /// In en, this message translates to:
  /// **'Top {top} km/h · average {average} km/h'**
  String driveSpeeds(String top, String average);

  /// No description provided for @hardBrakes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hard brake} other{{count} hard brakes}}'**
  String hardBrakes(int count);

  /// No description provided for @rapidStarts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rapid start} other{{count} rapid starts}}'**
  String rapidStarts(int count);

  /// No description provided for @phoneUseMinutes.
  ///
  /// In en, this message translates to:
  /// **'Phone used {minutes} min'**
  String phoneUseMinutes(int minutes);

  /// No description provided for @eraseMyDrives.
  ///
  /// In en, this message translates to:
  /// **'Erase my drives'**
  String get eraseMyDrives;

  /// No description provided for @eraseMyDrivesBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes the drives kept on this phone. Drives already shared stay in the circle\'s history until it deletes them.'**
  String get eraseMyDrivesBody;

  /// No description provided for @drivesErased.
  ///
  /// In en, this message translates to:
  /// **'Drives erased'**
  String get drivesErased;

  /// No description provided for @approximateStatus.
  ///
  /// In en, this message translates to:
  /// **'Approximate'**
  String get approximateStatus;

  /// No description provided for @approximateSwitch.
  ///
  /// In en, this message translates to:
  /// **'Approximate location'**
  String get approximateSwitch;

  /// No description provided for @approximateBody.
  ///
  /// In en, this message translates to:
  /// **'This circle sees only the area you\'re in (about 3 km across), not the exact spot. An SOS always sends your exact location.'**
  String get approximateBody;
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
