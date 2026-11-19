import 'dart:convert';
import 'dart:typed_data';

import 'location_box.dart';

/// What a [FamilyEvent] says.
enum FamilyEventKind {
  /// Arrived at one of the circle's places.
  arrive,

  /// Left one of the circle's places.
  leave;

  static FamilyEventKind? parse(Object? value) {
    for (final k in values) {
      if (k.name == value) return k;
    }
    return null;
  }
}

/// One event in `family_events`, before sealing: "arrived at Home".
///
/// The id is random and chosen by the sender, so a reader shows each event
/// once even if the server hands it back twice.
class FamilyEvent {
  const FamilyEvent({
    required this.id,
    required this.kind,
    required this.at,
    this.placeId,
    this.lat,
    this.lng,
    this.battery,
  });

  final String id;
  final FamilyEventKind kind;
  final DateTime at;
  final String? placeId;
  final double? lat;
  final double? lng;
  final int? battery;

  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'k': kind.name,
    't': at.toUtc().millisecondsSinceEpoch,
    if (placeId != null) 'p': placeId,
    if (lat != null) 'la': (lat! * 1e6).roundToDouble() / 1e6,
    if (lng != null) 'lo': (lng! * 1e6).roundToDouble() / 1e6,
    if (battery != null) 'b': battery,
  };

  /// Throws [FormatException] for anything this version can't show (a newer
  /// app's event kind is skipped, not shown wrong).
  static FamilyEvent fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final kind = FamilyEventKind.parse(json['k']);
    final t = json['t'];
    if (id is! String || id.isEmpty || kind == null || t is! int) {
      throw const FormatException('Not a family event');
    }
    final p = json['p'];
    final b = json['b'];
    return FamilyEvent(
      id: id,
      kind: kind,
      at: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
      placeId: p is String ? p : null,
      lat: (json['la'] as num?)?.toDouble(),
      lng: (json['lo'] as num?)?.toDouble(),
      battery: b is int && b >= 0 && b <= 100 ? b : null,
    );
  }

  /// JSON, padded like location updates so events look alike on the server.
  Uint8List encode() => PayloadPadding.pad(utf8.encode(jsonEncode(toJson())));

  static FamilyEvent decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(PayloadPadding.unpad(bytes)));
    if (json is! Map<String, Object?>) throw const FormatException('Not JSON');
    return fromJson(json);
  }
}
