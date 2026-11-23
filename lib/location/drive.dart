import 'dart:math' as math;

import 'schedule.dart';

/// One second of driving, from the phone's sensors (`ShareService.kt` takes
/// them only while the phone is driving and drive summaries or crash
/// detection are on).
class DriveSample {
  const DriveSample({
    required this.at,
    this.speedMps,
    this.lat,
    this.lng,
    this.accuracyM,
    this.peakG = 0,
    this.screenOn = false,
  });

  final DateTime at;

  /// From satellites, null when there was no fresh position this second.
  final double? speedMps;
  final double? lat;
  final double? lng;
  final double? accuracyM;

  /// The hardest jolt this second, in g, gravity taken out.
  final double peakG;

  /// The phone was unlocked with its screen on (someone used it).
  final bool screenOn;

  bool get hasLocation => lat != null && lng != null;

  static DriveSample? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['t'];
    if (t is! int) return null;
    double? d(String k) {
      final v = raw[k];
      return v is num && v.isFinite ? v.toDouble() : null;
    }

    final lat = d('la');
    final lng = d('lo');
    final valid =
        lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
    final speed = d('sp');
    return DriveSample(
      at: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
      speedMps: speed != null && speed >= 0 && speed < 100 ? speed : null,
      lat: valid ? lat : null,
      lng: valid ? lng : null,
      accuracyM: d('ac'),
      peakG: math.max(0, d('g') ?? 0),
      screenOn: raw['scr'] == true,
    );
  }
}

/// One finished drive, kept on this phone, and shared only with circles
/// the driver chose.
class DriveSummary {
  const DriveSummary({
    required this.id,
    required this.start,
    required this.end,
    required this.distanceM,
    required this.topSpeedMps,
    this.hardBrakes = 0,
    this.rapidStarts = 0,
    this.phoneUseSeconds = 0,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final double distanceM;
  final double topSpeedMps;

  /// Slowing down faster than [DriveTracker.hardMps2].
  final int hardBrakes;

  /// Speeding up faster than [DriveTracker.hardMps2].
  final int rapidStarts;

  /// Seconds the phone was unlocked and in use while moving.
  final int phoneUseSeconds;

  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;

  Duration get length => end.difference(start);

  double get averageSpeedMps {
    final s = length.inMilliseconds / 1000;
    return s <= 0 ? 0 : distanceM / s;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    's': start.toUtc().millisecondsSinceEpoch,
    'e': end.toUtc().millisecondsSinceEpoch,
    'dm': distanceM.round(),
    'ts': (topSpeedMps * 10).round() / 10,
    if (hardBrakes > 0) 'hb': hardBrakes,
    if (rapidStarts > 0) 'ra': rapidStarts,
    if (phoneUseSeconds > 0) 'pu': phoneUseSeconds,
    if (startLat != null) 'sla': startLat,
    if (startLng != null) 'slo': startLng,
    if (endLat != null) 'ela': endLat,
    if (endLng != null) 'elo': endLng,
  };

  static DriveSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final s = json['s'];
    final e = json['e'];
    if (id is! String || s is! int || e is! int) return null;
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    double? d(String k) => (json[k] as num?)?.toDouble();
    return DriveSummary(
      id: id,
      start: DateTime.fromMillisecondsSinceEpoch(s, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(e, isUtc: true),
      distanceM: d('dm') ?? 0,
      topSpeedMps: d('ts') ?? 0,
      hardBrakes: i('hb'),
      rapidStarts: i('ra'),
      phoneUseSeconds: i('pu'),
      startLat: d('sla'),
      startLng: d('slo'),
      endLat: d('ela'),
      endLng: d('elo'),
    );
  }
}

/// Turns driving samples into drive summaries, on the phone.
///
/// A drive starts at the first sample over [startMps] and ends once the
/// phone hasn't gone faster than [movingMps] for [endAfter]. Hard braking
/// and rapid starts are speed changes over [hardMps2] (about 0.3 g, the
/// usual telematics threshold), taken from satellite speed over 1 to 3
/// seconds, so a phone sliding off the seat doesn't count. Short trips
/// (under [minDistanceM] or [minLength]) are dropped.
class DriveTracker {
  DriveTracker({String Function()? newId}) : _newId = newId ?? _defaultId;

  static const startMps = AdaptiveSchedule.drivingMps;
  static const movingMps = 3.0;
  static const endAfter = Duration(minutes: 3);
  static const hardMps2 = 3.0;

  /// Speed changes from below this don't count (parking, queues).
  static const hardFromMps = 5.0;
  static const eventGap = Duration(seconds: 5);
  static const minDistanceM = 500.0;
  static const minLength = Duration(minutes: 2);

  /// Positions less exact than this don't add distance or top speed.
  static const maxAccuracyM = 50.0;

  final String Function() _newId;

  _Drive? _drive;
  final List<DriveSample> _speeds = [];

  bool get active => _drive != null;

  /// Starts the drive from where the phone began moving, when known
  /// (driving is only noticed after a few positions).
  void hint(Fix? movingSince) => _hint = movingSince;
  Fix? _hint;

  /// Adds samples (oldest first); returns any drive that finished.
  List<DriveSummary> add(Iterable<DriveSample> samples) {
    final done = <DriveSummary>[];
    for (final s in samples) {
      final d = _drive;
      if (d != null && s.at.difference(d.lastMovingAt) >= endAfter) {
        final summary = _finish();
        if (summary != null) done.add(summary);
      }
      _take(s);
    }
    return done;
  }

  /// Ends a drive that went quiet (the sensors stopped: the phone is no
  /// longer driving). Called on every position and wake-up.
  DriveSummary? tick(DateTime now) {
    final d = _drive;
    if (d == null || now.difference(d.lastMovingAt) < endAfter) return null;
    return _finish();
  }

  void _take(DriveSample s) {
    final speed = s.speedMps;
    var d = _drive;
    if (d == null) {
      if (speed == null || speed < startMps) return;
      final hint = _hint;
      final useHint =
          hint != null &&
          s.at.difference(hint.at) <= const Duration(minutes: 15) &&
          !hint.at.isAfter(s.at);
      d = _drive = _Drive(
        start: useHint ? hint.at : s.at,
        startLat: useHint ? hint.lat : s.lat,
        startLng: useHint ? hint.lng : s.lng,
        lastMovingAt: s.at,
      );
      if (useHint && s.hasLocation) {
        d.distanceM += haversine(hint.lat, hint.lng, s.lat!, s.lng!);
      }
      _speeds.clear();
    }
    final exact = s.accuracyM == null || s.accuracyM! <= maxAccuracyM;
    if (speed != null && speed >= movingMps) d.lastMovingAt = s.at;
    if (speed != null && exact && speed > d.topSpeedMps) {
      d.topSpeedMps = speed;
    }
    if (s.screenOn && speed != null && speed >= movingMps) d.phoneUse++;
    if (s.hasLocation && exact) {
      final last = d.last;
      if (last != null) {
        final meters = haversine(last.lat!, last.lng!, s.lat!, s.lng!);
        final secs = s.at.difference(last.at).inMilliseconds / 1000;
        // A jump faster than 250 km/h is a bad position, not travel.
        if (secs > 0 && meters / secs < 70) d.distanceM += meters;
      }
      d.last = s;
      d.endLat = s.lat;
      d.endLng = s.lng;
    }
    if (speed != null) _hardEvents(d, s);
    d.end = s.at;
  }

  void _hardEvents(_Drive d, DriveSample s) {
    _speeds.add(s);
    _speeds.removeWhere(
      (o) => s.at.difference(o.at) > const Duration(seconds: 3),
    );
    for (final o in _speeds) {
      final secs = s.at.difference(o.at).inMilliseconds / 1000;
      if (secs < 1) continue;
      final rate = (s.speedMps! - o.speedMps!) / secs;
      final from = math.max(s.speedMps!, o.speedMps!);
      if (from < hardFromMps || rate.abs() < hardMps2) continue;
      final braking = rate < 0;
      final last = braking ? d.lastBrake : d.lastStart;
      if (last != null && s.at.difference(last) < eventGap) break;
      if (braking) {
        d.hardBrakes++;
        d.lastBrake = s.at;
      } else {
        d.rapidStarts++;
        d.lastStart = s.at;
      }
      break;
    }
  }

  DriveSummary? _finish() {
    final d = _drive;
    _drive = null;
    _speeds.clear();
    _hint = null;
    if (d == null) return null;
    final end = d.lastMovingAt.isAfter(d.start) ? d.lastMovingAt : d.end;
    if (d.distanceM < minDistanceM || end.difference(d.start) < minLength) {
      return null;
    }
    return DriveSummary(
      id: _newId(),
      start: d.start,
      end: end,
      distanceM: d.distanceM,
      topSpeedMps: d.topSpeedMps,
      hardBrakes: d.hardBrakes,
      rapidStarts: d.rapidStarts,
      phoneUseSeconds: d.phoneUse,
      startLat: d.startLat,
      startLng: d.startLng,
      endLat: d.endLat,
      endLng: d.endLng,
    );
  }

  static String _defaultId() {
    final r = math.Random.secure();
    return [
      for (var i = 0; i < 12; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}

class _Drive {
  _Drive({
    required this.start,
    required this.startLat,
    required this.startLng,
    required this.lastMovingAt,
  }) : end = start;

  final DateTime start;
  final double? startLat;
  final double? startLng;
  DateTime end;
  DateTime lastMovingAt;
  double distanceM = 0;
  double topSpeedMps = 0;
  int hardBrakes = 0;
  int rapidStarts = 0;
  int phoneUse = 0;
  DateTime? lastBrake;
  DateTime? lastStart;
  DriveSample? last;
  double? endLat;
  double? endLng;
}

/// A crash the phone thinks happened: where and when the impact was.
class CrashSignal {
  const CrashSignal({required this.at, this.lat, this.lng});
  final DateTime at;
  final double? lat;
  final double? lng;
}

/// Looks for a car crash in driving samples: a hard impact while going
/// faster than [minSpeedMps], then the phone stays stopped for [stillFor]
/// within [window]. Moving on at speed after the jolt (a pothole, a phone
/// dropped in the footwell) cancels it.
///
/// This catches serious crashes only and can be wrong both ways, so the
/// phone counts down before alerting the circle, and the app says it is
/// not a replacement for calling emergency services.
class CrashDetector {
  static const impactG = 4.0;
  static const minSpeedMps = 7.0; // about 25 km/h
  static const stillMps = 2.0;
  static const movingOnMps = 5.0;
  static const stillFor = Duration(seconds: 10);
  static const window = Duration(seconds: 30);

  /// How far back the speed before an impact is looked for.
  static const before = Duration(seconds: 6);

  final List<DriveSample> _recent = [];
  DriveSample? _impact;
  DateTime? _stillSince;
  double? _lat;
  double? _lng;

  /// True while an impact is being checked.
  bool get watching => _impact != null;

  /// Adds samples (oldest first); returns a crash once confirmed.
  CrashSignal? add(Iterable<DriveSample> samples) {
    CrashSignal? found;
    for (final s in samples) {
      found ??= _take(s);
    }
    return found;
  }

  CrashSignal? _take(DriveSample s) {
    if (s.hasLocation) {
      _lat = s.lat;
      _lng = s.lng;
    }
    final impact = _impact;
    if (impact == null) {
      _recent.add(s);
      _recent.removeWhere((o) => s.at.difference(o.at) > before);
      if (s.peakG < impactG) return null;
      final fast = _recent.any(
        (o) => o.speedMps != null && o.speedMps! >= minSpeedMps,
      );
      if (!fast) return null;
      _impact = s;
      _stillSince = null;
      return null;
    }
    final since = s.at.difference(impact.at);
    final speed = s.speedMps;
    if (speed != null &&
        speed >= movingOnMps &&
        since > const Duration(seconds: 4)) {
      _reset(); // Drove on.
      return null;
    }
    if (speed == null || speed <= stillMps) {
      _stillSince ??= s.at;
      if (s.at.difference(_stillSince!) >=
          stillFor - const Duration(seconds: 1)) {
        final signal = CrashSignal(at: impact.at, lat: _lat, lng: _lng);
        _reset();
        return signal;
      }
    } else {
      _stillSince = null;
    }
    if (since > window) _reset();
    return null;
  }

  void _reset() {
    _impact = null;
    _stillSince = null;
    _recent.clear();
  }
}
