// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get homeTitle => 'Family';

  @override
  String get settings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get remove => 'Remove';

  @override
  String get emptyTitle => 'Start your family circle';

  @override
  String get emptyBody =>
      'A circle is the group of people who share with each other. Create one and invite your family, or join a circle you were invited to. Everything in it is end-to-end encrypted: only the people in the circle can read it.';

  @override
  String get createCircle => 'Create a circle';

  @override
  String get joinCircle => 'Join with an invite';

  @override
  String get newCircleTitle => 'New circle';

  @override
  String get circleName => 'Circle name';

  @override
  String get circleNameHint => 'For example: Family';

  @override
  String get circleNameRequired => 'Enter a name';

  @override
  String get yourNameTitle => 'Your name in the circle';

  @override
  String get renameCircle => 'Rename circle';

  @override
  String get unnamedCircle => 'Family circle';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get membersHeading => 'Members';

  @override
  String youSuffix(String name) {
    return '$name (you)';
  }

  @override
  String get owner => 'Owner';

  @override
  String get unnamedMember => 'No name';

  @override
  String get manageMembers => 'Members and invites';

  @override
  String get manageMembersHint =>
      'Invite, let people in, remove, or leave the circle';

  @override
  String get inviteSomeone => 'Invite someone';

  @override
  String get circleDescription =>
      'Only the people in this circle can read what is shared in it.';

  @override
  String get waitingTitle => 'Waiting to be let in';

  @override
  String get waitingBody =>
      'The circle\'s owner has to compare a code with you. Tap to see it.';

  @override
  String get stopWaiting => 'Stop waiting';

  @override
  String get couldNotCreate =>
      'Couldn\'t create the circle. Check your internet connection and try again.';

  @override
  String get couldNotSave =>
      'Couldn\'t save. Check your internet connection and try again.';

  @override
  String get couldNotLoad =>
      'Couldn\'t load your circles. Check your internet connection.';

  @override
  String get circleGone => 'You\'re no longer in this circle.';

  @override
  String get notifyChannelName => 'Location sharing';

  @override
  String get notifySharingTitle => 'Sharing your location';

  @override
  String get notifySharingBody =>
      'Your family circle can see where you are. Open ZT Family to pause.';

  @override
  String get notifyPausedTitle => 'Location sharing paused';

  @override
  String get notifyPausedBody =>
      'Your circle sees \"Paused\". Open ZT Family to resume.';

  @override
  String get notifyUnlockTitle => 'Open ZT Family to keep sharing';

  @override
  String get notifyUnlockBody =>
      'Someone joined or left your circle. Open the app once so your location reaches them again.';

  @override
  String get notSharing => 'Not sharing';

  @override
  String get pausedStatus => 'Paused';

  @override
  String pausedUntil(String time) {
    return 'Paused until $time';
  }

  @override
  String battery(int percent) {
    return 'Battery $percent%';
  }

  @override
  String batteryCharging(int percent) {
    return 'Charging $percent%';
  }

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get shareConsentTitle => 'Share your location';

  @override
  String get shareConsentBody =>
      'ZT Family collects your location to share it with the people in this circle, also when the app is closed or not in use. It is end-to-end encrypted: only the people in the circle can see it, not us and not the server.\n\nA notification shows while sharing is on. You can pause or stop at any time.';

  @override
  String get notNow => 'Not now';

  @override
  String get continueLabel => 'Continue';

  @override
  String get locationPermissionNeeded =>
      'ZT Family needs location access to share where you are.';

  @override
  String get circleKeyNotReady =>
      'This circle isn\'t ready on this phone yet. Try again in a moment.';

  @override
  String get pauseHour => 'For 1 hour';

  @override
  String get pauseTomorrow => 'Until tomorrow morning';

  @override
  String get pauseUntilResumed => 'Until I turn it back on';

  @override
  String get shareOffTitle => 'You\'re not sharing your location';

  @override
  String get shareOffBody =>
      'Turn on sharing so this circle can see where you are.';

  @override
  String get shareOnTitle => 'You\'re sharing your location';

  @override
  String get shareOnBody =>
      'Your circle sees where you are and your battery. It updates more often when you move.';

  @override
  String get sharePausedTitle => 'Sharing is paused';

  @override
  String get sharePausedOpenBody =>
      'Your circle sees \"Paused\" until you resume.';

  @override
  String sharePausedUntilBody(String time) {
    return 'Your circle sees \"Paused\" until $time.';
  }

  @override
  String get shareLiveTitle => 'Sharing live';

  @override
  String shareLiveBody(String time) {
    return 'Your circle sees you move every few seconds until $time.';
  }

  @override
  String get shareStale =>
      'Someone joined or left this circle. Sharing with it starts again now that the app is open.';

  @override
  String get needsAlwaysHint =>
      'For sharing to keep going after your phone restarts, allow location \"All the time\" for ZT Family.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get shareTurnOn => 'Share my location';

  @override
  String get shareTurnOff => 'Stop sharing';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get shareLiveHour => 'Share live for 1 hour';

  @override
  String get stopLive => 'Stop live';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get notifyAlertsTitle => 'Family alerts are on';

  @override
  String get notifyAlertsBody =>
      'You\'ll be told when someone arrives at or leaves a place.';

  @override
  String alertArrived(String name, String place) {
    return '$name arrived at $place';
  }

  @override
  String alertLeft(String name, String place) {
    return '$name left $place';
  }

  @override
  String alertArrivedSomewhere(String name) {
    return '$name arrived at a saved place';
  }

  @override
  String alertLeftSomewhere(String name) {
    return '$name left a saved place';
  }

  @override
  String alertAt(String time) {
    return 'At $time';
  }

  @override
  String get alertsChannelName => 'Family alerts';

  @override
  String get alertsQuietChannelName => 'Family alerts during quiet hours';

  @override
  String get placesHeading => 'Places';

  @override
  String get placesEmpty =>
      'Add Home, School or Work to know when someone arrives or leaves.';

  @override
  String placeHere(String names) {
    return 'Here now: $names';
  }

  @override
  String get addPlace => 'Add a place';

  @override
  String get editPlace => 'Edit place';

  @override
  String get placeName => 'Name';

  @override
  String get placeNameHint => 'Home, School, Work';

  @override
  String get placeNameRequired => 'Enter a name';

  @override
  String get placeWhere => 'Where';

  @override
  String get placeNoPositionYet => 'No position yet';

  @override
  String get placeUseHere => 'Use where I am now';

  @override
  String get placePaste => 'Or paste coordinates or a map link';

  @override
  String get placeBadPaste => 'No position found in that text';

  @override
  String get placeNoLocation =>
      'Couldn\'t get your position. Check that location is on.';

  @override
  String get placeNeedsPosition => 'Choose where the place is';

  @override
  String get placeSize => 'Size';

  @override
  String meters(int count) {
    return '$count m';
  }

  @override
  String get placeSizeHint =>
      'Bigger places notice arrivals sooner but less exactly. Arrivals are worked out on each phone; the server never sees your places.';

  @override
  String get tooManyPlaces => 'This circle has as many places as it can keep.';

  @override
  String get removePlace => 'Remove place';

  @override
  String removePlaceTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removePlaceBody =>
      'Nobody in the circle will get alerts for it any more.';

  @override
  String get recentHeading => 'Today';

  @override
  String get alertsTitle => 'Alerts on this phone';

  @override
  String get alertsBody =>
      'Get a notification when someone arrives at or leaves a place, also while ZT Family is locked. To read them, this phone keeps the circle\'s location key in its secure hardware.';

  @override
  String get alertsAbout => 'Alerts about';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietOff => 'Off';

  @override
  String quietOnSummary(String from, String to) {
    return '$from to $to, alerts without sound';
  }

  @override
  String quietRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get quietCustom => 'Choose times';

  @override
  String get quietFrom => 'Quiet from';

  @override
  String get quietTo => 'Quiet until';
}
