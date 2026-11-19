import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../location/alerts.dart';
import '../location/family_event.dart';
import '../location/location_box.dart';
import '../model/family_place.dart';
import 'family_data.dart';
import 'locations.dart';
import 'places.dart';

final alertStoreProvider = Provider<AlertStore>((ref) => SecureAlertStore());

final alertRevisionProvider = NotifierProvider<FamilyRevision, int>(
  FamilyRevision.new,
);

final alertStateProvider = FutureProvider<AlertState?>((ref) async {
  ref.watch(alertRevisionProvider);
  final state = await ref.read(alertStoreProvider).load();
  final me = ref.read(myUserIdProvider);
  return state != null && state.userId == me ? state : null;
});

/// One event as the circle page lists it.
class CircleEvent {
  const CircleEvent({required this.userId, required this.event});
  final String userId;
  final FamilyEvent event;
}

/// The circle's arrivals and departures from the last day, newest first.
/// Read with the circle's own key, so it works without alerts turned on.
final circleEventsProvider = FutureProvider.autoDispose
    .family<List<CircleEvent>, String>((ref, spaceId) async {
      ref.watch(familyRevisionProvider);
      ref.watch(ztSpacesProvider);
      final backend = ref.watch(locationBackendProvider);
      final sub = backend
          .eventInserts([spaceId])
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
      final space = spaceOf(ref, spaceId);
      if (space == null) return const [];
      final rows = await backend.events(
        spaceId,
        since: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        limit: 500,
        newestFirst: true,
      );
      final devices = DeviceItem.readAll(await space.store.all());
      final boxes = <int, SimpleKeyPair?>{};
      final out = <CircleEvent>[];
      final seen = <String>{};
      for (final row in rows) {
        final event = await openEvent(
          row,
          devicePublic: devices['${row.userId}/${row.deviceId}'],
          box: (epoch) async {
            if (boxes.containsKey(epoch)) return boxes[epoch];
            final key = space.codec.keyring[epoch];
            return boxes[epoch] = key == null
                ? null
                : await LocationBox.derive(
                    spaceKey: key,
                    spaceId: spaceId,
                    epoch: epoch,
                  );
          },
        );
        if (event == null || !seen.add(event.id)) continue;
        out.add(CircleEvent(userId: row.userId, event: event));
      }
      out.sort((a, b) => b.event.at.compareTo(a.event.at));
      return out;
    });

/// Alerts while locked (opt-in per circle), who to get alerts about, and
/// quiet hours. Run with the app unlocked; the service then works from what
/// they leave in the alert store.
class AlertActions {
  AlertActions(this.ref);
  final Ref ref;

  AlertStore get _store => ref.read(alertStoreProvider);
  ShareServiceControl get _service => ref.read(shareServiceProvider);

  void _changed() => ref.read(alertRevisionProvider.notifier).bump();

  Future<AlertState> _state() async {
    final me = ref.read(myUserIdProvider);
    if (me == null) throw StateError('Not signed in');
    final had = await _store.load();
    return had != null && had.userId == me ? had : AlertState(userId: me);
  }

  /// What the locked phone needs for [spaceId], from the open circle.
  /// Keeps the previous epoch's seed too, for events sent just before a
  /// key change. Null when the circle's key isn't on this phone yet.
  Future<AlertCircle?> _package(String spaceId, AlertCircle? had) async {
    final space = spaceOf(ref, spaceId);
    final epoch = space?.codec.keyring.writeEpoch;
    final key = epoch == null ? null : space!.codec.keyring[epoch];
    if (key == null) return null;
    final boxes = <int, Uint8List>{
      for (final e in (had?.boxes ?? const <int, Uint8List>{}).entries)
        if (e.key == epoch! - 1) e.key: e.value,
      epoch!: await LocationBox.boxSeed(
        spaceKey: key,
        spaceId: spaceId,
        epoch: epoch,
      ),
    };
    final items = await space!.store.all();
    return AlertCircle(
      spaceId: spaceId,
      boxes: boxes,
      devices: DeviceItem.readAll(items),
      names: {for (final m in space.members) m.userId: m.name},
      places: {for (final p in await readPlaces(space.store)) p.id: p.name},
      muted: had?.muted ?? const {},
      cursor: had?.cursor ?? DateTime.now().toUtc(),
      seen: had?.seen ?? const [],
    );
  }

  /// Turns alerts while locked on for [spaceId]. Asks for notification
  /// permission first; returns false when the circle's key isn't ready.
  Future<bool> enable(String spaceId) async {
    final state = await _state();
    final circle = await _package(spaceId, state.circles[spaceId]);
    if (circle == null) return false;
    await _store.save(
      state.copyWith(circles: {...state.circles, spaceId: circle}),
    );
    _changed();
    await _service.start();
    return true;
  }

  /// Turns them off and deletes the circle's keys from the Keystore.
  Future<void> disable(String spaceId) async {
    final state = await _store.load();
    if (state == null) return;
    final rest = {...state.circles}..remove(spaceId);
    if (rest.isEmpty && state.quiet == null) {
      await _store.clear();
    } else {
      await _store.save(state.copyWith(circles: rest));
    }
    _changed();
    // Stops the service unless this phone still shares its location.
    await _service.stop();
  }

  Future<void> setMuted(String spaceId, String userId, bool muted) async {
    final state = await _store.load();
    final circle = state?.circles[spaceId];
    if (state == null || circle == null) return;
    final next = {...circle.muted};
    muted ? next.add(userId) : next.remove(userId);
    await _store.save(
      state.copyWith(
        circles: {
          ...state.circles,
          spaceId: circle.copyWith(muted: next),
        },
      ),
    );
    _changed();
  }

  Future<void> setQuietHours(QuietHours? quiet) async {
    final state = await _state();
    await _store.save(state.copyWith(quiet: () => quiet));
    _changed();
  }

  /// After unlock and every sync: new keys, devices, names and places for
  /// circles with alerts on; drops circles this account left, and every
  /// alert when another account signed in on this phone.
  Future<void> refresh() async {
    final state = await _store.load();
    if (state == null) return;
    final me = ref.read(myUserIdProvider);
    if (me == null) return;
    if (me != state.userId) {
      await _store.clear();
      _changed();
      return;
    }
    if (!state.on) return;
    final ids = {for (final e in ref.read(ztSpacesProvider).entries) e.info.id};
    final next = <String, AlertCircle>{};
    for (final c in state.circles.values) {
      if (!ids.contains(c.spaceId)) continue;
      next[c.spaceId] = await _package(c.spaceId, c) ?? c;
    }
    // Cursors and seen ids may have moved in the service meanwhile.
    final latest = await _store.load() ?? state;
    await _store.save(
      latest.copyWith(
        circles: {
          for (final c in next.values)
            c.spaceId: c.copyWith(
              cursor: latest.circles[c.spaceId]?.cursor,
              seen: latest.circles[c.spaceId]?.seen,
              muted: latest.circles[c.spaceId]?.muted,
            ),
        },
      ),
    );
    _changed();
    if (next.length != state.circles.length) await _service.stop();
  }
}

final alertActionsProvider = Provider<AlertActions>(AlertActions.new);
