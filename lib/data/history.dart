import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/family_place.dart';
import '../location/location_backend.dart';
import '../location/timeline.dart';
import 'alerts.dart';
import 'family_data.dart';
import 'locations.dart';
import 'places.dart';

/// Places a circle can have without Plus.
const freePlaces = 5;

/// Whether this account has Plus (or more) for ZT Family: more places and
/// up to 30 days of history. Safety is never behind it.
final familyPlusProvider = Provider<bool>((ref) {
  final plan = ref.watch(ztPlanProvider).value;
  return plan?.has('family') ?? false;
});

/// Bumped when history settings change, so screens reload.
final historyRevisionProvider = NotifierProvider<FamilyRevision, int>(
  FamilyRevision.new,
);

/// How many days a circle keeps history.
final historyDaysProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  spaceId,
) async {
  ref.watch(historyRevisionProvider);
  return ref.watch(locationBackendProvider).historyDays(spaceId);
});

/// Which member and which day (local midnight).
typedef HistoryKey = ({String spaceId, String userId, DateTime day});

/// One member's day: stops, moves, check-ins and alerts, newest first.
final memberHistoryProvider = FutureProvider.autoDispose
    .family<List<TimelineEntry>, HistoryKey>((ref, key) async {
      ref.watch(historyRevisionProvider);
      ref.watch(ztSpacesProvider);
      final space = spaceOf(ref, key.spaceId);
      if (space == null) return const [];
      final rows = await ref
          .watch(locationBackendProvider)
          .memberEvents(
            key.spaceId,
            key.userId,
            from: key.day,
            to: DateTime(key.day.year, key.day.month, key.day.day + 1),
          );
      final events = [
        for (final e in await openCircleRows(space, key.spaceId, rows))
          // Only what this member sent (the server filters too).
          if (e.userId == key.userId) e.event,
      ];
      final places = await ref.watch(circlePlacesProvider(key.spaceId).future);
      return buildTimeline(
        events,
        places: [for (final p in places) FamilyPlace.watched(p)],
      );
    });

class HistoryActions {
  HistoryActions(this.ref);
  final Ref ref;

  LocationBackend get _backend => ref.read(locationBackendProvider);
  void _changed() => ref.read(historyRevisionProvider.notifier).bump();

  /// Throws [NeedsPlusException] for over 7 days without Plus.
  Future<void> setDays(String spaceId, int days) async {
    await _backend.setHistoryDays(spaceId, days);
    _changed();
  }

  Future<void> eraseMine(String spaceId) async {
    await _backend.eraseMyEvents(spaceId);
    _changed();
    ref.read(familyRevisionProvider.notifier).bump();
  }
}

final historyActionsProvider = Provider<HistoryActions>(HistoryActions.new);
