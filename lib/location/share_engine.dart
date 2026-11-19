import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'family_event.dart';
import 'geofence.dart';
import 'location_backend.dart';
import 'location_box.dart';
import 'location_update.dart';
import 'schedule.dart';
import 'share_store.dart';

/// The phone's own state with each update: battery and power saving.
class DeviceStatus {
  const DeviceStatus({
    this.battery,
    this.charging = false,
    this.powerSave = false,
  });
  final int? battery;
  final bool charging;
  final bool powerSave;

  static DeviceStatus fromMap(Map<Object?, Object?> map) {
    final b = map['battery'];
    return DeviceStatus(
      battery: b is int && b >= 0 && b <= 100 ? b : null,
      charging: map['charging'] == true,
      powerSave: map['powerSave'] == true,
    );
  }
}

/// What the service shows and does next.
enum ShareHealth {
  /// Sending normally.
  sharing,

  /// Paused by the user: the circle sees "Paused".
  paused,

  /// A circle's key changed: open the app to keep sharing with it.
  needsUnlock,

  /// Couldn't reach the server this time; tries again on the next fix.
  offline,

  /// Not sharing with anyone any more (turned off, signed out, removed).
  stopped,
}

class ShareResult {
  const ShareResult(this.health, this.decision);
  final ShareHealth health;
  final ScheduleDecision decision;
  bool get stop => health == ShareHealth.stopped;
}

/// Seals and sends this phone's location to its circles. Runs in the app's
/// one Dart isolate, which the Android service keeps alive while sharing,
/// so it works with the app closed and locked: it needs only the share
/// store (public keys and the device key) and the signed-in session, never
/// the vault.
class ShareEngine {
  ShareEngine({
    required this.store,
    required this.backend,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ShareStore store;
  final LocationBackend backend;
  final DateTime Function() _clock;
  final AdaptiveSchedule schedule = AdaptiveSchedule();

  DeviceStatus _status = const DeviceStatus();
  Fix? _lastFix;
  Future<void> _queue = Future.value();

  /// One at a time: fixes, motion and the app's own requests queue up.
  Future<T> _serial<T>(Future<T> Function() task) {
    final done = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await task());
      } on Object catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  /// Saves what a send changed in the circles ([before] to [after]) onto
  /// the newest stored state, and returns it.
  Future<ShareState?> _merge(ShareState before, ShareState after) async {
    final latest = await store.load();
    if (latest == null || latest.userId != before.userId) return null;
    final changed = {for (final c in after.circles) c.spaceId: c};
    final dropped = {
      for (final c in before.circles)
        if (!changed.containsKey(c.spaceId)) c.spaceId,
    };
    final was = {for (final c in before.circles) c.spaceId: c};
    final merged = latest.copyWith(
      circles: [
        for (final c in latest.circles)
          if (dropped.contains(c.spaceId) && was[c.spaceId]?.epoch == c.epoch)
            ...const <CirclePackage>[]
          else if (changed.containsKey(c.spaceId) &&
              was[c.spaceId]?.epoch == c.epoch)
            changed[c.spaceId]!
          else
            c,
      ],
    );
    await store.save(merged);
    return merged;
  }

  /// Stops sharing with [spaceId] and takes this phone's last location off
  /// the server. Runs after any send in flight, so that send can't put the
  /// location back. Offline, the delete is kept and retried. Returns how
  /// many circles this phone still shares with.
  Future<int> stopCircle(String spaceId) => _serial(() async {
    final state = await store.load();
    if (state == null) return 0;
    var next = state.copyWith(
      circles: [
        for (final c in state.circles)
          if (c.spaceId != spaceId) c,
      ],
      pendingDeletes: {...state.pendingDeletes, spaceId}.toList(),
    );
    await store.save(next);
    next = await _flushDeletes(next);
    return next.circles.length;
  });

  /// Retries location deletes that failed offline.
  Future<void> retryDeletes() => _serial(() async {
    final state = await store.load();
    if (state != null && state.pendingDeletes.isNotEmpty) {
      await _flushDeletes(state);
    }
  });

  Future<ShareState> _flushDeletes(ShareState state) async {
    if (state.pendingDeletes.isEmpty) return state;
    if (backend.userId != state.userId) return state;
    final left = <String>[];
    for (final spaceId in state.pendingDeletes) {
      try {
        await backend.deleteLatest(spaceId: spaceId, deviceId: state.deviceId);
      } on NotInCircleException {
        // Gone from the circle: its rows went with it.
      } on Object {
        left.add(spaceId);
      }
    }
    if (left.length == state.pendingDeletes.length) return state;
    final latest = await store.load() ?? state;
    final next = latest.copyWith(
      pendingDeletes: [
        for (final d in latest.pendingDeletes)
          if (left.contains(d) || !state.pendingDeletes.contains(d)) d,
      ],
    );
    await store.save(next);
    return next;
  }

  Future<ShareResult> onFix(Fix fix, DeviceStatus status) => _serial(() async {
    _status = status;
    _lastFix = fix;
    final state = await store.load();
    final now = _clock();
    schedule.liveUntil = state?.liveUntil;
    final decision = schedule.onFix(fix);
    return _send(state, now, decision, newFix: fix);
  });

  Future<ShareResult> onMotion() => _serial(() async {
    final state = await store.load();
    final now = _clock();
    schedule.liveUntil = state?.liveUntil;
    final decision = schedule.onMotion(now);
    return ShareResult(_healthOf(state, now), decision);
  });

  /// Sends at once without a new position (paused, resumed, battery): the
  /// last position this phone had, or none.
  Future<ShareResult> sendNow() => _serial(() async {
    final state = await store.load();
    final now = _clock();
    schedule.liveUntil = state?.liveUntil;
    return _send(state, now, schedule.current(now));
  });

  /// The current decision, for the service when it starts.
  Future<ShareResult> current() => _serial(() async {
    final state = await store.load();
    final now = _clock();
    schedule.liveUntil = state?.liveUntil;
    return ShareResult(_healthOf(state, now), schedule.current(now));
  });

  ShareHealth _healthOf(ShareState? state, DateTime now) {
    if (state == null || !state.sharing) return ShareHealth.stopped;
    if (state.pausedAt(now)) return ShareHealth.paused;
    if (state.circles.every((c) => c.stale)) return ShareHealth.needsUnlock;
    return ShareHealth.sharing;
  }

  Future<ShareResult> _send(
    ShareState? state,
    DateTime now,
    ScheduleDecision decision, {
    Fix? newFix,
  }) async {
    if (state == null || !state.sharing) {
      return ShareResult(ShareHealth.stopped, decision);
    }
    final me = backend.userId;
    if (me == null || me != state.userId) {
      // Signed out, or another account on this phone: stop for good.
      await store.save(state.copyWith(circles: const []));
      return ShareResult(ShareHealth.stopped, decision);
    }
    // A pause that ran out ends by itself.
    var current = state;
    if (!current.pausedOpenEnded &&
        current.pausedUntil != null &&
        !now.isBefore(current.pausedUntil!)) {
      current = current.copyWith(pausedUntil: () => null);
      await store.save(current);
    }
    current = await _flushDeletes(current);
    final paused = current.pausedAt(now);
    final fix = _lastFix;
    final update = LocationUpdate(
      at: paused || fix == null ? now.toUtc() : fix.at,
      lat: paused ? null : fix?.lat,
      lng: paused ? null : fix?.lng,
      accuracyM: paused ? null : fix?.accuracyM,
      speedMps: paused ? null : fix?.speedMps,
      heading: paused ? null : fix?.heading,
      battery: _status.battery,
      charging: _status.charging,
      powerSave: _status.powerSave,
      mode: paused ? MotionMode.still : decision.mode,
      pausedUntil: paused ? current.pausedUntil : null,
      pausedOpenEnded: paused && current.pausedOpenEnded,
    );
    final plain = update.encode();
    final keys = await Signing.fromSeed(current.deviceSeed);

    var offline = false;
    final kept = <CirclePackage>[];
    for (final circle in current.circles) {
      if (circle.stale) {
        kept.add(circle);
        continue;
      }
      final context = LocationBox.context(
        table: 'family_latest',
        spaceId: circle.spaceId,
        userId: me,
        deviceId: current.deviceId,
        epoch: circle.epoch,
      );
      try {
        final payload = await LocationBox.seal(
          plain,
          boxPublic: circle.boxPublic,
          context: context,
        );
        final signature = await Signing.sign(
          LocationBox.signedBytes(context, payload),
          keys,
        );
        await backend.putLatest(
          LocationRow(
            spaceId: circle.spaceId,
            userId: me,
            deviceId: current.deviceId,
            epoch: circle.epoch,
            payload: payload,
            signature: signature,
          ),
        );
        // Arrive and leave, from this new position. Not while paused: a
        // paused phone tells nobody where it goes.
        kept.add(
          paused || newFix == null
              ? circle
              : await _crossings(circle, newFix, me, current, keys),
        );
      } on StaleKeyException {
        kept.add(circle.copyWith(stale: true));
      } on NotInCircleException {
        // Left or removed: this circle is dropped.
      } on SignedOutException {
        await store.save(current.copyWith(circles: const []));
        return ShareResult(ShareHealth.stopped, decision);
      } on Object {
        offline = true;
        kept.add(circle);
      }
    }
    var next = current.copyWith(circles: kept);
    if (!_samePackages(next.circles, current.circles)) {
      // The app may have changed the circles while this ran (started
      // sharing with another, paused): keep its changes, apply only ours.
      next = await _merge(current, next) ?? next;
    }
    final health = _healthOf(next, now);
    return ShareResult(
      health == ShareHealth.sharing && offline ? ShareHealth.offline : health,
      paused
          ? const ScheduleDecision(
              MotionMode.still,
              AdaptiveSchedule.stillEvery,
            )
          : decision,
    );
  }

  /// Sends an event for each place [fix] entered or left, and returns the
  /// circle with its new inside/outside state. A place whose event can't be
  /// sent (offline) keeps its old state, so the next position tries again.
  Future<CirclePackage> _crossings(
    CirclePackage circle,
    Fix fix,
    String me,
    ShareState state,
    Ed25519KeyMaterial keys,
  ) async {
    if (circle.places.isEmpty) return circle;
    final (next, crossings) = Geofence.check(circle.inside, circle.places, fix);
    final context = LocationBox.context(
      table: 'family_events',
      spaceId: circle.spaceId,
      userId: me,
      deviceId: state.deviceId,
      epoch: circle.epoch,
    );
    final inside = {...next};
    for (final c in crossings) {
      final event = FamilyEvent(
        id: _eventId(),
        kind: c.kind,
        at: fix.at,
        placeId: c.placeId,
        lat: fix.lat,
        lng: fix.lng,
        battery: _status.battery,
      );
      try {
        final payload = await LocationBox.seal(
          event.encode(),
          boxPublic: circle.boxPublic,
          context: context,
        );
        await backend.insertEvent(
          LocationRow(
            spaceId: circle.spaceId,
            userId: me,
            deviceId: state.deviceId,
            epoch: circle.epoch,
            payload: payload,
            signature: await Signing.sign(
              LocationBox.signedBytes(context, payload),
              keys,
            ),
          ),
        );
      } on Object {
        final was = circle.inside[c.placeId];
        if (was != null) inside[c.placeId] = was;
      }
    }
    return circle.copyWith(inside: inside);
  }

  static String _eventId() {
    final b = Kdf.randomBytes(12);
    return [for (final v in b) v.toRadixString(16).padLeft(2, '0')].join();
  }

  static bool _samePackages(List<CirclePackage> a, List<CirclePackage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].spaceId != b[i].spaceId ||
          a[i].epoch != b[i].epoch ||
          a[i].stale != b[i].stale ||
          !mapEquals(a[i].inside, b[i].inside)) {
        return false;
      }
    }
    return true;
  }
}
