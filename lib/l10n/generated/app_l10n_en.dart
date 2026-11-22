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
      'ZT Family collects your location to share it with the people in this circle, also when the app is closed or not in use. It is end-to-end encrypted: only the people in the circle can see it, not us and not the server.\n\nThe circle also sees where you have been, for as long as it keeps history (7 days unless its owner changes it). You can erase yours at any time.\n\nA notification shows while sharing is on. You can pause or stop at any time.';

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

  @override
  String eventCheckin(String name) {
    return '$name checked in';
  }

  @override
  String eventAsk(String name) {
    return '$name asks you to check in';
  }

  @override
  String eventTimer(String name, String time) {
    return '$name started a safety timer until $time';
  }

  @override
  String eventTimerEnd(String name) {
    return '$name is OK';
  }

  @override
  String eventOverdue(String name, String time) {
    return '$name didn\'t check in by $time';
  }

  @override
  String eventSos(String name) {
    return '$name sent an SOS';
  }

  @override
  String eventSosEnd(String name) {
    return '$name is safe now';
  }

  @override
  String get sosChannelName => 'SOS and missed check-ins';

  @override
  String timerReminderTitle(String time) {
    return 'Your safety timer ends at $time';
  }

  @override
  String get timerReminderBody => 'Tap I\'m OK, or your circle is alerted.';

  @override
  String get imOk => 'I\'m OK';

  @override
  String get imSafe => 'I\'m safe';

  @override
  String get send => 'Send';

  @override
  String get couldNotSend =>
      'Couldn\'t send. Check your connection and try again.';

  @override
  String get safetyTitle => 'Safety';

  @override
  String get safetyNeedsSharing =>
      'Share your location with this circle to use check-ins, the safety timer and SOS.';

  @override
  String get safetyBody =>
      'Check-ins and SOS go to everyone in this circle with your location.';

  @override
  String get checkinButton => 'I\'m here';

  @override
  String get checkinTitle => 'Check in';

  @override
  String get checkinNote => 'Note (optional)';

  @override
  String get checkinNoteHint => 'Got to practice';

  @override
  String get checkinSent => 'Checked in';

  @override
  String get askButton => 'Ask someone to check in';

  @override
  String get askWho => 'Who should check in?';

  @override
  String askSent(String name) {
    return 'Asked $name to check in';
  }

  @override
  String get timerButton => 'Safety timer';

  @override
  String get timerQuestion => 'Alert my circle if I don\'t check in';

  @override
  String get timerPick => 'By a time I choose';

  @override
  String timerStarted(String time) {
    return 'Timer set until $time';
  }

  @override
  String timerActive(String time) {
    return 'Safety timer until $time. If you don\'t tap I\'m OK by then, your circle is alerted and sees you live.';
  }

  @override
  String get timerEnded => 'Timer ended';

  @override
  String get sosButton => 'Hold for SOS';

  @override
  String get sosHoldHint => 'Hold the button for 2 seconds to send an SOS';

  @override
  String get sosSent => 'SOS sent. Your circle sees you live for an hour.';

  @override
  String get sosActive => 'SOS sent. Your circle sees where you are, live.';

  @override
  String get sosEnded => 'Your circle knows you\'re safe';

  @override
  String timerInMinutes(int minutes) {
    return 'In $minutes minutes';
  }

  @override
  String timerInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'In $hours hours',
      one: 'In 1 hour',
    );
    return '$_temp0';
  }

  @override
  String eventPoint(String name) {
    return '$name was here';
  }

  @override
  String get historyHeading => 'History';

  @override
  String historyOf(String name) {
    return '$name: history';
  }

  @override
  String get historyOpen => 'History';

  @override
  String get historyEmpty =>
      'Nothing for this day. History shows only while sharing is on.';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String historyAt(String place) {
    return 'At $place';
  }

  @override
  String get historyStayed => 'Stayed in one spot';

  @override
  String historySince(String time) {
    return 'Since $time';
  }

  @override
  String historyRange(String from, String to, String length) {
    return '$from to $to, $length';
  }

  @override
  String historyMoved(String distance, String length) {
    return 'On the move: $distance, $length';
  }

  @override
  String kilometers(String km) {
    return '$km km';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get historyDaysTitle => 'Keep history for';

  @override
  String historyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get historyKeptBody =>
      'Places people were, check-ins and alerts, end-to-end encrypted. The server deletes them after this many days.';

  @override
  String get historyOwnerOnly => 'Only the circle\'s owner can change this.';

  @override
  String get plusBadge => 'Plus';

  @override
  String get historyNeedsPlus =>
      'Keeping history for more than 7 days is part of Plus. Safety (the map, check-ins, the safety timer and SOS) is always free.';

  @override
  String placesNeedPlus(int count) {
    return 'More than $count places is part of Plus. Safety (the map, check-ins, the safety timer and SOS) is always free.';
  }

  @override
  String get seePlans => 'See plans';

  @override
  String get eraseMyHistory => 'Erase my history in this circle';

  @override
  String get eraseMyHistoryBody =>
      'Deletes every position, check-in and alert you sent to this circle. Your current location stays shared while sharing is on.';

  @override
  String get erase => 'Erase';

  @override
  String get historyErased => 'Your history in this circle was erased';

  @override
  String get historyCouldNotLoad =>
      'Couldn\'t load the history. Check your internet connection.';

  @override
  String eventCrash(String name) {
    return '$name may have been in a car crash';
  }

  @override
  String eventDrive(String name, String km, String kmh) {
    return '$name drove $km km (top speed $kmh km/h)';
  }

  @override
  String get crashCountdownTitle => 'Were you in a crash?';

  @override
  String crashCountdownBody(String time) {
    return 'Your circles get an SOS with your location at $time, unless you tap I\'m OK.';
  }

  @override
  String get crashSendNow => 'Send SOS now';

  @override
  String get crashSosSentTitle => 'SOS sent to your circles';

  @override
  String get crashSosSentBody =>
      'They see your live location for an hour. Tap I\'m safe when you are.';

  @override
  String get drivingTitle => 'Driving';

  @override
  String get drivingSubtitle => 'Drive summaries and crash detection';

  @override
  String get drivingNeedsSharing =>
      'Turn on location sharing with this circle to use these.';

  @override
  String get drivesSwitch => 'Drive summaries';

  @override
  String get drivesSwitchBody =>
      'Keeps a summary of each drive on this phone: distance, speed, hard braking and phone use. Uses satellites every second while you drive.';

  @override
  String get shareDrivesSwitch => 'Share my drives with this circle';

  @override
  String get shareDrivesBody =>
      'The circle sees each drive\'s summary in your history, end-to-end encrypted.';

  @override
  String get shareDrivesNeedsPlus =>
      'Sharing drive summaries with a circle is part of Plus. Your own drive summaries and crash detection stay free.';

  @override
  String get crashSwitch => 'Crash detection';

  @override
  String get crashSwitchBody =>
      'If the phone feels a hard crash while driving and then stops, it rings for 60 seconds, then sends an SOS with your location to all your circles.';

  @override
  String get crashDisclaimer =>
      'Crash detection can miss a crash or ring when there was none. It does not call emergency services: in an emergency, call your local emergency number.';

  @override
  String get turnOn => 'Turn on';

  @override
  String get myDrivesHeading => 'My drives (on this phone)';

  @override
  String get noDrivesYet =>
      'No drives yet. They show here after you drive with drive summaries on.';

  @override
  String driveSpeeds(String top, String average) {
    return 'Top $top km/h · average $average km/h';
  }

  @override
  String hardBrakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hard brakes',
      one: '1 hard brake',
    );
    return '$_temp0';
  }

  @override
  String rapidStarts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rapid starts',
      one: '1 rapid start',
    );
    return '$_temp0';
  }

  @override
  String phoneUseMinutes(int minutes) {
    return 'Phone used $minutes min';
  }

  @override
  String get eraseMyDrives => 'Erase my drives';

  @override
  String get eraseMyDrivesBody =>
      'Deletes the drives kept on this phone. Drives already shared stay in the circle\'s history until it deletes them.';

  @override
  String get drivesErased => 'Drives erased';
}
