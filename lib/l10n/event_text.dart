import '../location/family_event.dart';
import 'l10n.dart';

/// "Dana arrived at Home", for the circle page and for notifications.
String eventLine(AppL10n l, String name, String? place, FamilyEventKind kind) =>
    switch (kind) {
      FamilyEventKind.arrive =>
        place == null
            ? l.alertArrivedSomewhere(name)
            : l.alertArrived(name, place),
      FamilyEventKind.leave =>
        place == null ? l.alertLeftSomewhere(name) : l.alertLeft(name, place),
    };
