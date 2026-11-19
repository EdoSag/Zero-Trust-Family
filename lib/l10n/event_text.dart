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
    FamilyEventKind.sos => l.eventSos(name),
    FamilyEventKind.sosEnd => l.eventSosEnd(name),
  };
}
