import 'package:intl/intl.dart';

import '../location/family_event.dart';
import 'l10n.dart';

/// "Dana arrived at Home", "Dana sent an SOS": one line for an event, for
/// the circle page and for notifications.
String eventLine(AppL10n l, String name, String? place, FamilyEvent event) {
  String hm(DateTime? t) =>
      t == null ? '' : DateFormat.Hm(l.localeName).format(t.toLocal());
  return switch (event.kind) {
    FamilyEventKind.arrive =>
      place == null
          ? l.alertArrivedSomewhere(name)
          : l.alertArrived(name, place),
    FamilyEventKind.leave =>
      place == null ? l.alertLeftSomewhere(name) : l.alertLeft(name, place),
    FamilyEventKind.checkin => l.eventCheckin(name),
    FamilyEventKind.ask => l.eventAsk(name),
    FamilyEventKind.timer => l.eventTimer(name, hm(event.until)),
    FamilyEventKind.timerEnd => l.eventTimerEnd(name),
    FamilyEventKind.overdue => l.eventOverdue(name, hm(event.until)),
    FamilyEventKind.sos => event.crash ? l.eventCrash(name) : l.eventSos(name),
    FamilyEventKind.sosEnd => l.eventSosEnd(name),
    FamilyEventKind.point => l.eventPoint(name),
    FamilyEventKind.remind => l.eventRemind(name),
    FamilyEventKind.remindDone =>
      place == null
          ? l.eventRemindDoneSomewhere(name)
          : l.eventRemindDone(name, place),
    FamilyEventKind.remindCancel => l.eventRemindCancel(name),
    FamilyEventKind.drive => l.eventDrive(
      name,
      km(l, event.drive?.distanceM ?? 0),
      kmh(l, event.drive?.topSpeedMps ?? 0),
    ),
  };
}

/// "12.4" (kilometres, one decimal under 100).
String km(AppL10n l, double meters) {
  final k = meters / 1000;
  return NumberFormat(k < 100 ? '0.0' : '0', l.localeName).format(k);
}

/// "94" (km/h, whole).
String kmh(AppL10n l, double mps) =>
    NumberFormat('0', l.localeName).format(mps * 3.6);
