import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:zero_trust_core/zero_trust_core.dart';

import 'approximate.dart';
import 'drive.dart';
import 'drive_store.dart';
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
    DriveStore? drives,
    DateTime Function()? clock,
  }) : drives = drives ?? InMemoryDriveStore(),
       _clock = clock ?? DateTime.now;

  final ShareStore store;
  final LocationBackend backend;

  /// This phone's own drive summaries.
  final DriveStore drives;
  final DateTime Function() _clock;
  final AdaptiveSchedule schedule = AdaptiveSchedule();
  final DriveTracker tracker = DriveTracker();
  final CrashDetector crashes = CrashDetector();

  /// How long a detected crash counts down before the circle is alerted.
  static const crashCountdown = Duration(seconds: 60);

  /// Where this phone started moving (a drive starts there).
  Fix? _movingSince;

  /// Drives that failed to reach a circle may wait in the drive store.
  bool _drivesUnsent = true;

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
    final wasStill = schedule.mode == MotionMode.still;
    final decision = schedule.onFix(fix);
    if (schedule.mode == MotionMode.still) {
      _movingSince = null;
    } else if (wasStill || _movingSince == null) {
      _movingSince = fix;
    }
    if (schedule.mode == MotionMode.driving) tracker.hint(_movingSince);
    await _tickDrives(state, now);
    return _send(state, now, decision, newFix: fix);
  });

  /// Driving samples (one a second) from the phone's sensors: drive
  /// summaries and crash detection. The service sends them only while
  /// [wantsDriveSensors] says so.
  Future<ShareResult> onDrive(List<DriveSample> samples) => _serial(() async {
    final now = _clock();
    var state = await _load(now);
    schedule.liveUntil = state?.liveUntil;
    final decision = schedule.current(now);
    if (state == null || !state.sharing || state.pausedAt(now)) {
      return ShareResult(_healthOf(state, now), decision);
    }
    if (state.drives) {
      tracker.hint(_movingSince);
      for (final drive in tracker.add(samples)) {
        await _keepDrive(state, drive, now);
      }
    }
    if (state.crashDetection && state.crash == null && state.sos == null) {
      final crash = crashes.add(samples);
      if (crash != null) {
        state = state.copyWith(
          crash: () => CrashRun(
            at: crash.at,
            deadline: now.add(crashCountdown),
            lat: crash.lat,
            lng: crash.lng,
          ),
        );
        await store.save(state);
      }
    }
    return ShareResult(_healthOf(state, now), decision);
  });

  /// Whether the service should run the driving sensors (satellites every
  /// second and the accelerometer): only while driving, sharing and not
  /// paused, with drive summaries or crash detection on.
  bool wantsDriveSensors(ShareState? state, DateTime now) =>
      state != null &&
      state.sharing &&
      !state.pausedAt(now) &&
      (state.drives || state.crashDetection) &&
      (schedule.mode == MotionMode.driving ||
          tracker.active ||
          crashes.watching);

  /// Ends a drive that went quiet, and retries drives a circle missed.
  Future<void> _tickDrives(ShareState? state, DateTime now) async {
    if (state == null) return;
    final done = tracker.tick(now);
    if (done != null && state.drives) await _keepDrive(state, done, now);
    if (_drivesUnsent) await _flushDrives(state);
  }

  /// Keeps [drive] on this phone and sends it to the circles that get
  /// this driver's drives.
  Future<void> _keepDrive(
    ShareState state,
    DriveSummary drive,
    DateTime now,
  ) async {
    final unsent = <String>[];
    for (final c in state.circles) {
      if (!c.shareDrives || c.stale) continue;
      if (!await _event(state, c.spaceId, _driveEvent(drive))) {
        unsent.add(c.spaceId);
      }
    }
    if (unsent.isNotEmpty) _drivesUnsent = true;
    await drives.add(state.userId, StoredDrive(drive, unsent: unsent), now);
  }

  static FamilyEvent _driveEvent(DriveSummary drive) => FamilyEvent(
    id: drive.id,
    kind: FamilyEventKind.drive,
    at: drive.end,
    lat: drive.endLat,
    lng: drive.endLng,
    drive: drive,
  );

  /// Drives that couldn't reach a circle (offline) for up to a day.
  Future<void> _flushDrives(ShareState state) async {
    final now = _clock();
    final all = await drives.load(state.userId, now);
    var changed = false;
    var left = false;
    final next = <StoredDrive>[];
    for (final d in all) {
      if (d.unsent.isEmpty) {
        next.add(d);
        continue;
      }
      if (now.difference(d.drive.end) > const Duration(days: 1)) {
        next.add(d.copyWith(unsent: const []));
        changed = true;
        continue;
      }
      final still = <String>[];
      for (final spaceId in d.unsent) {
        final shares = state.circles.any(
          (c) => c.spaceId == spaceId && c.shareDrives,
        );
        if (!shares) continue; // Turned off since: never sent.
        if (!await _event(state, spaceId, _driveEvent(d.drive))) {
          still.add(spaceId);
        }
      }
      if (still.length != d.unsent.length) changed = true;
      if (still.isNotEmpty) left = true;
      next.add(d.copyWith(unsent: still));
    }
    if (changed) await drives.save(state.userId, next);
    _drivesUnsent = left;
  }

  /// "I'm OK" on the crash countdown: nobody is alerted.
  Future<bool> cancelCrash() => _serial(() async {
    final state = await store.load();
    if (state?.crash == null) return false;
    await store.save(state!.copyWith(crash: () => null));
    return true;
  });

  /// "Send SOS now" on the crash countdown.
  Future<bool> crashSosNow() => _serial(() async {
    final now = _clock();
    final state = await store.load();
    final crash = state?.crash;
    if (state == null || crash == null) return false;
    await store.save(
      state.copyWith(
        crash: () => CrashRun(
          at: crash.at,
          deadline: now,
          lat: crash.lat,
          lng: crash.lng,
        ),
      ),
    );
    final after = await _load(now);
    return after?.sos != null && after?.crash == null;
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
    await _tickDrives(state, now);
    return _send(state, now, schedule.current(now));
  });

  /// The current decision, for the service when it starts.
  Future<ShareResult> current() => _serial(() async {
    final now = _clock();
    final state = await _load(now);
    schedule.liveUntil = state?.liveUntil;
    await _tickDrives(state, now);
    return ShareResult(_healthOf(state, now), schedule.current(now));
  });

  /// The share state, after sending the alert for a safety timer that ran
  /// out or a crash countdown nobody answered (and sharing live for an hour
  /// so the circle can find this phone).
  Future<ShareState?> _load(DateTime now) async {
    final state = await _loadTimer(now);
    final crash = state?.crash;
    if (state == null || crash == null || now.isBefore(crash.deadline)) {
      return state;
    }
    return _crashSos(state, crash, now);
  }

  /// Nobody answered the crash countdown: SOS to every circle, with where
  /// the crash was, and live sharing for an hour.
  Future<ShareState> _crashSos(
    ShareState state,
    CrashRun crash,
    DateTime now,
  ) async {
    // A retry (offline before) sends only to circles not reached yet.
    final sent = [...crash.sent];
    var missing = false;
    for (final c in state.circles) {
      if (c.stale || sent.contains(c.spaceId)) continue;
      final ok = await _event(
        state,
        c.spaceId,
        FamilyEvent(
          id: _eventId(),
          kind: FamilyEventKind.sos,
          at: now,
          lat: crash.lat ?? _lastFix?.lat,
          lng: crash.lng ?? _lastFix?.lng,
          battery: _status.battery,
          crash: true,
        ),
      );
      if (ok) {
        sent.add(c.spaceId);
      } else {
        missing = true;
      }
    }
    final retrying = now.difference(crash.deadline) < const Duration(hours: 1);
    if (sent.isEmpty) {
      if (retrying) return state; // Offline: the next wake-up tries again.
      final dropped = state.copyWith(crash: () => null);
      await store.save(dropped);
      return dropped;
    }
    final first = crash.sent.isEmpty;
    final until = first ? now.add(liveAfterAlarm) : state.sos?.until ?? now;
    final next = state.copyWith(
      // Circles it didn't reach yet are retried for an hour.
      crash: () => missing && retrying ? crash.copyWith(sent: sent) : null,
      sos: () =>
          SafetyRun(spaceId: sent.first, until: until, also: sent.sublist(1)),
      liveUntil: first ? () => until : null,
      pausedUntil: first ? () => null : null,
      pausedOpenEnded: first ? false : null,
    );
    await store.save(next);
    return next;
  }

  /// The share state, after the missed safety timer's alert.
  Future<ShareState?> _loadTimer(DateTime now) async {
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
    final sealed = _rough(circle, state) ? Approximate.event(event) : event;
    final context = LocationBox.context(
      table: 'family_events',
      spaceId: spaceId,
      userId: me,
      deviceId: state.deviceId,
      epoch: circle.epoch,
    );
    try {
      final payload = await LocationBox.seal(
        sealed.encode(),
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
    var sent = false;
    final failed = <String>[];
    for (final spaceId in sos.spaces) {
      if (await _event(state, spaceId, _now(FamilyEventKind.sosEnd, now))) {
        sent = true;
      } else {
        failed.add(spaceId);
      }
    }
    // Offline, the SOS stays on (with its "I'm safe" button) until the
    // circle can be told. A circle this phone no longer shares with can't
    // be told at all, so then it just ends here.
    final reachable = [
      for (final c in state.circles)
        if (failed.contains(c.spaceId) && !c.stale) c.spaceId,
    ];
    if (sent || reachable.isEmpty) {
      // Told some: the rest are told with the next updates.
      await store.save(
        state.copyWith(
          sos: () => null,
          liveUntil: () => null,
          sosEndPending: {...state.sosEndPending, ...reachable}.toList(),
        ),
      );
    }
    return sent;
  });

  /// "I'm safe" for circles that missed it (offline).
  Future<ShareState> _flushSosEnds(ShareState state, DateTime now) async {
    if (state.sosEndPending.isEmpty) return state;
    final left = <String>[];
    for (final spaceId in state.sosEndPending) {
      final shares = state.circles.any((c) => c.spaceId == spaceId && !c.stale);
      if (!shares) continue;
      if (!await _event(state, spaceId, _now(FamilyEventKind.sosEnd, now))) {
        left.add(spaceId);
      }
    }
    if (left.length == state.sosEndPending.length) return state;
    final latest = await store.load() ?? state;
    final next = latest.copyWith(sosEndPending: left);
    await store.save(next);
    return next;
  }

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
    current = await _flushSosEnds(current, now);
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
    final exact = update.encode();
    Uint8List? rough;
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
      // Approximate circles get the cell, not the spot; during an SOS
      // everyone gets the exact position.
      final plain = _rough(circle, current)
          ? rough ??= Approximate.update(update).encode()
          : exact;
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
      final exact = FamilyEvent(
        id: _eventId(),
        kind: c.kind,
        at: fix.at,
        placeId: c.placeId,
        lat: fix.lat,
        lng: fix.lng,
        battery: _status.battery,
      );
      final event = _rough(circle, state) ? Approximate.event(exact) : exact;
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

  /// Whether [circle] gets only approximate positions now: it asked for
  /// them, and this phone isn't in an SOS.
  static bool _rough(CirclePackage circle, ShareState state) =>
      circle.approximate && state.sos == null;

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
