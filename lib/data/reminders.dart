import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../location/reminders.dart';
import 'alerts.dart';
import 'family_data.dart';
import 'locations.dart';
import '../model/family_place.dart';
import 'places.dart';

/// How far back a circle's events are read for reminders. The server keeps
/// events for the circle's history time (7 days by default), so an older
/// reminder that never went off is gone with them.
const reminderLookback = Duration(days: 30);

/// The circle's open place reminders (L-4), newest first, from its events.
final circleRemindersProvider = FutureProvider.autoDispose
    .family<List<OpenReminder>, String>((ref, spaceId) async {
      ref.watch(familyRevisionProvider);
      ref.watch(ztSpacesProvider);
      final backend = ref.watch(locationBackendProvider);
      final sub = backend
          .eventInserts([spaceId])
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
      return readOpenReminders(ref, spaceId);
    });

Future<List<OpenReminder>> readOpenReminders(Ref ref, String spaceId) async {
  final space = spaceOf(ref, spaceId);
  if (space == null) return const [];
  final rows = await ref
      .read(locationBackendProvider)
      .events(
        spaceId,
        since: DateTime.now().toUtc().subtract(reminderLookback),
        limit: 1000,
        newestFirst: true,
      );
  final events = await openCircleRows(space, spaceId, rows);
  return openReminders([
    for (final e in events) (userId: e.userId, event: e.event),
  ]);
}

class ReminderActions {
  ReminderActions(this.ref);
  final Ref ref;

  void _changed() => ref.read(familyRevisionProvider.notifier).bump();

  /// "Remind Dana to call when she gets to School". False when it couldn't
  /// be sent (offline, or this phone doesn't share with the circle).
  Future<bool> create(
    String spaceId, {
    required String to,
    required String placeId,
    required bool onLeave,
    String? note,
  }) async {
    final id = await ref
        .read(shareEngineProvider)
        .remind(
          spaceId,
          to: to,
          placeId: placeId,
          onLeave: onLeave,
          note: note,
        );
    if (id == null) return false;
    _changed();
    // A reminder for myself goes on this phone's list at once.
    if (to == ref.read(myUserIdProvider)) await syncMine(spaceId);
    return true;
  }

  Future<bool> cancel(String spaceId, OpenReminder reminder) async {
    final ok = await ref
        .read(shareEngineProvider)
        .cancelReminder(
          spaceId,
          reminder.id,
          // Taken back by its sender, or turned down by its member.
          to: reminder.to == ref.read(myUserIdProvider)
              ? reminder.from
              : reminder.to,
        );
    if (ok) {
      _changed();
      if (reminder.to == ref.read(myUserIdProvider)) await syncMine(spaceId);
    }
    return ok;
  }

  /// Puts the circle's reminders for this phone's member on the list the
  /// sharing service watches (with names, for the notification).
  Future<void> syncMine(String spaceId) async {
    final me = ref.read(myUserIdProvider);
    final space = spaceOf(ref, spaceId);
    if (me == null || space == null) return;
    final open = await readOpenReminders(ref, spaceId);
    final places = {
      for (final p in await readPlaces(space.store)) p.id: p.name,
    };
    final names = {for (final m in space.members) m.userId: m.name};
    await ref
        .read(shareEngineProvider)
        .updateReminders(
          spaceId,
          replace: [
            for (final r in open)
              if (r.to == me)
                ?PlaceReminder.fromEvent(
                  r.from,
                  r.event,
                  fromName: names[r.from] ?? '',
                  placeName: places[r.event.placeId],
                ),
          ],
        );
  }
}

final reminderActionsProvider = Provider<ReminderActions>(ReminderActions.new);
