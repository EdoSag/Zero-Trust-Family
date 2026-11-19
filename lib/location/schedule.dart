import 'dart:math' as math;

import 'location_update.dart';

/// A position from the phone's location provider.
class Fix {
  const Fix({
    required this.lat,
    required this.lng,
    required this.at,
    this.accuracyM,
    this.speedMps,
    this.heading,
  });

  final double lat;
  final double lng;
  final DateTime at;
  final double? accuracyM;
  final double? speedMps;
  final double? heading;

  static Fix? fromMap(Map<Object?, Object?> map) {
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final at = map['at'];
    if (lat == null || lng == null || at is! int) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return Fix(
      lat: lat,
      lng: lng,
      at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      accuracyM: (map['accuracy'] as num?)?.toDouble(),
      speedMps: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
    );
  }
}

/// How often the phone asks for a position.
class ScheduleDecision {
  const ScheduleDecision(this.mode, this.interval);
  final MotionMode mode;
  final Duration interval;

  @override
  bool operator ==(Object other) =>
      other is ScheduleDecision &&
      other.mode == mode &&
      other.interval == interval;

  @override
  int get hashCode => Object.hash(mode, interval);
}

/// The battery schedule (plan section 5), without Google Play services:
///
/// | Mode    | When                                         | Every  |
/// |---------|----------------------------------------------|--------|
/// | still   | no real movement for 5 minutes                | 15 min |
/// | moving  | the phone felt motion, or moved over 100 m    | 90 s   |
/// | driving | over 25 km/h on two of the last three fixes   | 45 s   |
/// | live    | "Share live" is on (time limited)             | 10 s   |
///
/// Pure logic, so it is tested without a phone; the Android service only
/// delivers positions and motion, and asks this what to do next.
class AdaptiveSchedule {
  static const stillEvery = Duration(minutes: 15);
  static const movingEvery = Duration(seconds: 90);
  static const drivingEvery = Duration(seconds: 45);
  static const liveEvery = Duration(seconds: 10);

  /// Moving further than this from where the phone settled counts as moving.
  static const moveMeters = 100.0;
  static const walkingMps = 1.0;
  static const drivingMps = 7.0; // about 25 km/h

  /// Back to still after this long without movement.
  static const settleAfter = Duration(minutes: 5);

  MotionMode _mode = MotionMode.still;
  DateTime? liveUntil;
  Fix? _anchor;
  DateTime? _lastMoveAt;
  final List<Fix> _recent = [];

  MotionMode get mode => _mode;

  ScheduleDecision current(DateTime now) {
    if (liveUntil != null && now.isBefore(liveUntil!)) {
      return const ScheduleDecision(MotionMode.live, liveEvery);
    }
    return switch (_mode) {
      MotionMode.driving => const ScheduleDecision(
        MotionMode.driving,
        drivingEvery,
      ),
      MotionMode.moving ||
      MotionMode.live => const ScheduleDecision(MotionMode.moving, movingEvery),
      MotionMode.still => const ScheduleDecision(MotionMode.still, stillEvery),
    };
  }

  /// The phone's significant-motion sensor fired.
  ScheduleDecision onMotion(DateTime now) {
    if (_mode == MotionMode.still) _mode = MotionMode.moving;
    _lastMoveAt = now;
    return current(now);
  }

  ScheduleDecision onFix(Fix fix) {
    final now = fix.at;
    _recent.add(fix);
    if (_recent.length > 3) _recent.removeAt(0);

    final fast = _recent
        .where((f) => (f.speedMps ?? _speedBefore(f) ?? 0) >= drivingMps)
        .length;
    final speed = fix.speedMps ?? _speedBefore(fix) ?? 0;
    final anchor = _anchor;
    final far = anchor != null && distanceMeters(anchor, fix) > moveMeters;

    // Fast now, and on two of the last three: a red light or one bad
    // speed reading doesn't switch modes.
    if (fast >= 2 && speed >= drivingMps) {
      _mode = MotionMode.driving;
      _lastMoveAt = now;
      _anchor = fix;
    } else if (speed >= walkingMps || far) {
      if (_mode != MotionMode.driving) _mode = MotionMode.moving;
      _lastMoveAt = now;
      _anchor = fix;
    } else if (_mode != MotionMode.still &&
        (_lastMoveAt == null || now.difference(_lastMoveAt!) >= settleAfter)) {
      _mode = MotionMode.still;
      _anchor = fix;
    } else if (_mode == MotionMode.driving &&
        _lastMoveAt != null &&
        now.difference(_lastMoveAt!) >= const Duration(minutes: 2)) {
      // Stopped at the destination: walking pace until it settles.
      _mode = MotionMode.moving;
    }
    _anchor ??= fix;
    return current(now);
  }

  /// Speed from the previous fix, for providers that don't report one.
  double? _speedBefore(Fix fix) {
    final i = _recent.indexOf(fix);
    if (i <= 0) return null;
    final prev = _recent[i - 1];
    final seconds = fix.at.difference(prev.at).inMilliseconds / 1000;
    if (seconds < 5) return null;
    return distanceMeters(prev, fix) / seconds;
  }

  static double distanceMeters(Fix a, Fix b) =>
      haversine(a.lat, a.lng, b.lat, b.lng);
}

/// Great-circle distance in meters.
double haversine(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}
