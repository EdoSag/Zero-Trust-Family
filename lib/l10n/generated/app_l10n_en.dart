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
  String get locationSoonTitle => 'Location sharing comes next';

  @override
  String get locationSoonBody =>
      'This version sets up your circle. Sharing where you are, places and check-ins arrive in the next updates. Nobody\'s location is shared yet.';

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
}
