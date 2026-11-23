import 'dart:convert';
import 'dart:typed_data';

import 'drive.dart';
import 'location_box.dart';

/// What a [FamilyEvent] says.
enum FamilyEventKind {
  /// Arrived at one of the circle's places.
  arrive,

  /// Left one of the circle's places.
  leave,

  /// "I'm here", with an optional note.
  checkin,

  /// Asks one member ([FamilyEvent.to]) to check in.
  ask,

  /// A safety timer: "if I don't check in by [FamilyEvent.until], alert my
  /// circle". Every reader also watches the time itself, so the alert comes
  /// even if the sender's phone is off.
  timer,

  /// The timer was ended in time ("I'm OK").
  timerEnd,

  /// The timer ran out without a check-in (sent by the phone itself).
  overdue,

  /// SOS: the sender needs help now. Ignores quiet hours and muting.
  sos,

  /// The SOS was ended ("I'm safe").
  sosEnd,

  /// A history point: where the sender was (for the circle's timeline).
  /// Never alerts.
  point,

  /// A finished drive (distance, top speed, hard braking), shared only
  /// with circles the driver chose. Never alerts.
  drive,

  /// A place reminder for one member ([FamilyEvent.to]): "call me when you
  /// get to School". Their own phone shows it when they arrive at (or
  /// leave, with [FamilyEvent.onLeave]) the place.
  remind,

  /// The reminder [FamilyEvent.ref] went off on its member's phone; [to]
  /// is who set it.
  remindDone,

  /// The reminder [FamilyEvent.ref] was taken back by who set it.
  remindCancel;

  /// Kinds that only fill the history and never ring anyone.
  bool get quiet => this == point || this == drive;

  /// Kinds meant for one member ([FamilyEvent.to]) only.
  bool get addressed =>
      this == ask ||
      this == remind ||
      this == remindDone ||
      this == remindCancel;

  static FamilyEventKind? parse(Object? value) {
    for (final k in values) {
      if (k.name == value) return k;
    }
    return null;
  }
}

/// One event in `family_events`, before sealing: "arrived at Home", a
/// check-in, a safety timer, an SOS.
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
    this.note,
    this.to,
    this.until,
    this.accuracyM,
    this.drive,
    this.crash = false,
    this.approximate = false,
    this.ref,
    this.onLeave = false,
  });

  /// Longest note kept.
  static const maxNote = 140;

  final String id;
  final FamilyEventKind kind;
  final DateTime at;
  final String? placeId;
  final double? lat;
  final double? lng;
  final int? battery;

  /// A short text with a check-in or SOS.
  final String? note;

  /// Who an [FamilyEventKind.ask] is for.
  final String? to;

  /// A timer's deadline.
  final DateTime? until;

  /// How exact [lat] and [lng] are, in metres.
  final double? accuracyM;

  /// A [FamilyEventKind.drive]'s numbers.
  final DriveSummary? drive;

  /// An SOS the phone sent by itself after it detected a car crash and
  /// nobody answered its countdown. Older apps still see a plain SOS.
  final bool crash;

  /// Sent by a member who shares only roughly where they are (L-5).
  final bool approximate;

  /// The reminder a [FamilyEventKind.remindDone] or
  /// [FamilyEventKind.remindCancel] is about.
  final String? ref;

  /// A [FamilyEventKind.remind] that goes off on leaving, not arriving.
  final bool onLeave;

  bool get hasLocation => lat != null && lng != null;

  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'k': kind.name,
    't': at.toUtc().millisecondsSinceEpoch,
    if (placeId != null) 'p': placeId,
    if (lat != null) 'la': (lat! * 1e6).roundToDouble() / 1e6,
    if (lng != null) 'lo': (lng! * 1e6).roundToDouble() / 1e6,
    if (battery != null) 'b': battery,
    if (note != null && note!.isNotEmpty) 'n': note,
    if (to != null) 'to': to,
    if (until != null) 'u': until!.toUtc().millisecondsSinceEpoch,
    if (accuracyM != null) 'ac': accuracyM!.round(),
    if (drive != null) 'dr': drive!.toJson(),
    if (crash) 'cr': 1,
    if (approximate) 'ax': 1,
    if (ref != null) 'rf': ref,
    if (onLeave) 'ol': 1,
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
    final n = json['n'];
    final to = json['to'];
    final u = json['u'];
    return FamilyEvent(
      id: id,
      kind: kind,
      at: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
      placeId: p is String ? p : null,
      lat: (json['la'] as num?)?.toDouble(),
      lng: (json['lo'] as num?)?.toDouble(),
      battery: b is int && b >= 0 && b <= 100 ? b : null,
      note: n is String
          ? (n.length > maxNote ? n.substring(0, maxNote) : n)
          : null,
      to: to is String ? to : null,
      until: u is int
          ? DateTime.fromMillisecondsSinceEpoch(u, isUtc: true)
          : null,
      accuracyM: (json['ac'] as num?)?.toDouble(),
      drive: DriveSummary.fromJson(json['dr']),
      crash: json['cr'] == 1,
      approximate: json['ax'] == 1,
      ref: json['rf'] is String ? json['rf'] as String : null,
      onLeave: json['ol'] == 1,
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
