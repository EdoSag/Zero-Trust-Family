import 'dart:async';

import 'package:zero_trust_core/zero_trust_core.dart';

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

  Future<ShareResult> onFix(Fix fix, DeviceStatus status) => _serial(() async {
    _status = status;
    _lastFix = fix;
    final state = await store.load();
    final now = _clock();
    schedule.liveUntil = state?.liveUntil;
    final decision = schedule.onFix(fix);
    return _send(state, now, decision);
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
    ScheduleDecision decision,
  ) async {
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
        kept.add(circle);
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
    final next = current.copyWith(circles: kept);
    if (!_samePackages(next.circles, current.circles)) await store.save(next);
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

  static bool _samePackages(List<CirclePackage> a, List<CirclePackage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].spaceId != b[i].spaceId ||
          a[i].epoch != b[i].epoch ||
          a[i].stale != b[i].stale) {
        return false;
      }
    }
    return true;
  }
}
