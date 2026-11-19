import 'dart:convert';
import 'dart:typed_data';

import 'location_box.dart';

/// How a sharing phone is moving, which sets how often it sends.
enum MotionMode { still, moving, driving, live }

/// One update from a sharing phone, as members see it after opening it.
class LocationUpdate {
  const LocationUpdate({
    required this.at,
    this.lat,
    this.lng,
    this.accuracyM,
    this.speedMps,
    this.heading,
    this.battery,
    this.charging = false,
    this.powerSave = false,
    this.mode = MotionMode.still,
    this.pausedUntil,
    this.pausedOpenEnded = false,
  });

  /// When the phone took the fix (or paused).
  final DateTime at;

  /// Null while paused: a paused member shows "Paused", never a location.
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final double? speedMps;
  final double? heading;

  /// 0 to 100, null when the phone didn't say.
  final int? battery;
  final bool charging;
  final bool powerSave;
  final MotionMode mode;

  /// Sharing is paused until then (or, with [pausedOpenEnded], until the
  /// member resumes).
  final DateTime? pausedUntil;
  final bool pausedOpenEnded;

  bool get paused => pausedOpenEnded || pausedUntil != null;
  bool get hasLocation => lat != null && lng != null;

  Map<String, Object?> toJson() => {
    'v': 1,
    't': at.toUtc().millisecondsSinceEpoch,
    if (lat != null) 'la': _round(lat!, 6),
    if (lng != null) 'lo': _round(lng!, 6),
    if (accuracyM != null) 'ac': _round(accuracyM!, 0),
    if (speedMps != null) 'sp': _round(speedMps!, 1),
    if (heading != null) 'hd': _round(heading!, 0),
    if (battery != null) 'b': battery,
    if (charging) 'ch': 1,
    if (powerSave) 'ps': 1,
    'm': mode.name,
    if (pausedUntil != null) 'pu': pausedUntil!.toUtc().millisecondsSinceEpoch,
    if (pausedOpenEnded) 'po': 1,
  };

  static LocationUpdate fromJson(Map<String, Object?> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    final t = json['t'];
    if (t is! int) throw const FormatException('No time');
    final pu = json['pu'];
    final b = json['b'];
    return LocationUpdate(
      at: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
      lat: d('la'),
      lng: d('lo'),
      accuracyM: d('ac'),
      speedMps: d('sp'),
      heading: d('hd'),
      battery: b is int && b >= 0 && b <= 100 ? b : null,
      charging: json['ch'] == 1,
      powerSave: json['ps'] == 1,
      mode: MotionMode.values.firstWhere(
        (m) => m.name == json['m'],
        orElse: () => MotionMode.still,
      ),
      pausedUntil: pu is int
          ? DateTime.fromMillisecondsSinceEpoch(pu, isUtc: true)
          : null,
      pausedOpenEnded: json['po'] == 1,
    );
  }

  /// JSON, padded to a fixed size before sealing.
  Uint8List encode() => PayloadPadding.pad(utf8.encode(jsonEncode(toJson())));

  static LocationUpdate decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(PayloadPadding.unpad(bytes)));
    if (json is! Map<String, Object?>) throw const FormatException('Not JSON');
    return fromJson(json);
  }

  static double _round(double v, int digits) {
    final f = [1, 10, 100, 1000, 10000, 100000, 1000000][digits];
    return (v * f).roundToDouble() / f;
  }
}
