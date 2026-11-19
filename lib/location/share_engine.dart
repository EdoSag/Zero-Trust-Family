import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
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

  /// The last history point sent, to space them out.
  Fix? _lastPoint;

  /// A history point at most this often while still...
  static const pointEvery = Duration(minutes: 15);

  /// ...and while moving, after [pointMoveM] metres but not more often
  /// than [pointMinGap].
  static const pointMoveM = 150.0;
  static const pointMinGap = Duration(minutes: 2);

  bool _pointDue(Fix fix) {
    final last = _lastPoint;
    if (last == null) return true;
    final gap = fix.at.difference(last.at);
    if (gap >= pointEvery) return true;
    return gap >= pointMinGap &&
        haversine(last.lat, last.lng, fix.lat, fix.lng) >= pointMoveM;
  }

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
    final now = _clock();
    final state = await _load(now);
    schedule.liveUntil = state?.liveUntil;
    final decision = schedule.onFix(fix);
    return _send(state, now, decision, newFix: fix);
  });

  Future<ShareResult> onMotion() => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    schedule.liveUntil = state?.liveUntil;
    final decision = schedule.onMotion(now);
    return ShareResult(_healthOf(state, now), decision);
  });

  /// Sends at once without a new position (paused, resumed, battery): the
  /// last position this phone had, or none.
  Future<ShareResult> sendNow() => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    schedule.liveUntil = state?.liveUntil;
    return _send(state, now, schedule.current(now));
  });

  /// The current decision, for the service when it starts.
  Future<ShareResult> current() => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    schedule.liveUntil = state?.liveUntil;
    return ShareResult(_healthOf(state, now), schedule.current(now));
  });

  /// The share state, after sending the alert for a safety timer that ran
  /// out (and sharing live for an hour so the circle can find this phone).
  Future<ShareState?> _load(DateTime now) async {
    var state = await store.load();
    final timer = state?.timer;
    if (state == null || timer == null || now.isBefore(timer.until)) {
      return state;
    }
    final sent = await _event(
      state,
      timer.spaceId,
      FamilyEvent(
        id: _eventId(),
        kind: FamilyEventKind.overdue,
        at: now,
        until: timer.until,
        lat: _lastFix?.lat,
        lng: _lastFix?.lng,
        battery: _status.battery,
      ),
    );
    if (!sent && now.difference(timer.until) < const Duration(hours: 1)) {
      return state; // Offline: next wake-up tries again.
    }
    state = state.copyWith(
      timer: () => null,
      liveUntil: () => now.add(liveAfterAlarm),
      pausedUntil: () => null,
      pausedOpenEnded: false,
    );
    await store.save(state);
    return state;
  }

  /// How long a phone shares live after an SOS or a missed timer.
  static const liveAfterAlarm = Duration(hours: 1);

  /// Seals, signs and sends [event] to [spaceId]. False when this phone
  /// doesn't share with that circle (or its key changed) or it's offline.
  Future<bool> _event(
    ShareState state,
    String spaceId,
    FamilyEvent event,
  ) async {
    final me = backend.userId;
    if (me == null || me != state.userId) return false;
    CirclePackage? circle;
    for (final c in state.circles) {
      if (c.spaceId == spaceId && !c.stale) circle = c;
    }
    if (circle == null) return false;
    final context = LocationBox.context(
      table: 'family_events',
      spaceId: spaceId,
      userId: me,
      deviceId: state.deviceId,
      epoch: circle.epoch,
    );
    try {
      final payload = await LocationBox.seal(
        event.encode(),
        boxPublic: circle.boxPublic,
        context: context,
      );
      await backend.insertEvent(
        LocationRow(
          spaceId: spaceId,
          userId: me,
          deviceId: state.deviceId,
          epoch: circle.epoch,
          payload: payload,
          signature: await Signing.sign(
            LocationBox.signedBytes(context, payload),
            await Signing.fromSeed(state.deviceSeed),
          ),
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  FamilyEvent _now(
    FamilyEventKind kind,
    DateTime now, {
    String? note,
    String? to,
    DateTime? until,
  }) => FamilyEvent(
    id: _eventId(),
    kind: kind,
    at: now,
    lat: _lastFix?.lat,
    lng: _lastFix?.lng,
    battery: _status.battery,
    note: note,
    to: to,
    until: until,
  );

  /// "I'm here". Also ends this phone's safety timer in that circle.
  /// Works while locked (the "I'm OK" button on a notification).
  Future<bool> checkIn(String spaceId, {String? note}) => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    if (state == null) return false;
    final clean = note?.trim();
    final sent = await _event(
      state,
      spaceId,
      _now(
        FamilyEventKind.checkin,
        now,
        note: clean == null || clean.isEmpty
            ? null
            : clean.characters.take(FamilyEvent.maxNote).toString(),
      ),
    );
    if (sent && state.timer?.spaceId == spaceId) {
      await store.save(state.copyWith(timer: () => null));
    }
    return sent;
  });

  /// Asks [userId] to check in.
  Future<bool> askCheckIn(String spaceId, String userId) => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    if (state == null) return false;
    return _event(state, spaceId, _now(FamilyEventKind.ask, now, to: userId));
  });

  /// "If I don't check in by [until], alert my circle."
  Future<bool> startTimer(String spaceId, DateTime until) => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    if (state == null || !until.isAfter(now)) return false;
    final sent = await _event(
      state,
      spaceId,
      _now(FamilyEventKind.timer, now, until: until),
    );
    if (sent) {
      await store.save(
        state.copyWith(
          timer: () => SafetyRun(spaceId: spaceId, until: until),
        ),
      );
    }
    return sent;
  });

  /// "I'm OK": ends the timer in time.
  Future<bool> endTimer() => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    final timer = state?.timer;
    if (state == null || timer == null) return false;
    final sent = await _event(
      state,
      timer.spaceId,
      _now(FamilyEventKind.timerEnd, now),
    );
    if (sent) await store.save(state.copyWith(timer: () => null));
    return sent;
  });

  /// SOS: alerts the circle and shares live for an hour (a pause ends).
  Future<bool> startSos(String spaceId, {String? note}) => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    if (state == null) return false;
    final sent = await _event(
      state,
      spaceId,
      _now(FamilyEventKind.sos, now, note: note),
    );
    if (sent) {
      final until = now.add(liveAfterAlarm);
      await store.save(
        state.copyWith(
          sos: () => SafetyRun(spaceId: spaceId, until: until),
          liveUntil: () => until,
          pausedUntil: () => null,
          pausedOpenEnded: false,
        ),
      );
    }
    return sent;
  });

  /// "I'm safe": ends the SOS and its live sharing.
  Future<bool> endSos() => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    final sos = state?.sos;
    if (state == null || sos == null) return false;
    final sent = await _event(
      state,
      sos.spaceId,
      _now(FamilyEventKind.sosEnd, now),
    );
    // Offline, the SOS stays on (with its "I'm safe" button) until the
    // circle can be told. A circle this phone no longer shares with can't
    // be told at all, so then it just ends here.
    final reachable = state.circles.any(
      (c) => c.spaceId == sos.spaceId && !c.stale,
    );
    if (sent || !reachable) {
      await store.save(state.copyWith(sos: () => null, liveUntil: () => null));
    }
    return sent;
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
    var pointSent = false;
    final point = !paused && newFix != null && _pointDue(newFix);
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
        // A point for the circle's history.
        if (point &&
            await _event(
              current,
              circle.spaceId,
              FamilyEvent(
                id: _eventId(),
                kind: FamilyEventKind.point,
                at: newFix.at,
                lat: newFix.lat,
                lng: newFix.lng,
                accuracyM: newFix.accuracyM,
                battery: _status.battery,
              ),
            )) {
          pointSent = true;
        }
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
    if (pointSent) _lastPoint = newFix;
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
