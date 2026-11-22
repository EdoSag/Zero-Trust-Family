import 'family_event.dart';

/// A place reminder waiting on this phone (its member's): what to show and
/// when. Kept in the share store, so the service can show it while locked.
class PlaceReminder {
  const PlaceReminder({
    required this.id,
    required this.from,
    required this.placeId,
    this.onLeave = false,
    this.note,
    this.fromName = '',
    this.placeName,
  });

  final String id;

  /// Who set it (they're told when it goes off).
  final String from;
  final String placeId;
  final bool onLeave;
  final String? note;

  /// Names when it arrived, for the notification while locked.
  final String fromName;
  final String? placeName;

  Map<String, Object?> toJson() => {
    'id': id,
    'from': from,
    'place': placeId,
    if (onLeave) 'leave': true,
    if (note != null) 'note': note,
    if (fromName.isNotEmpty) 'fromName': fromName,
    if (placeName != null) 'placeName': placeName,
  };

  static PlaceReminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final from = json['from'];
    final place = json['place'];
    if (id is! String || from is! String || place is! String) return null;
    return PlaceReminder(
      id: id,
      from: from,
      placeId: place,
      onLeave: json['leave'] == true,
      note: json['note'] as String?,
      fromName: json['fromName'] as String? ?? '',
      placeName: json['placeName'] as String?,
    );
  }

  /// The reminder in a `remind` event sent by [from].
  static PlaceReminder? fromEvent(
    String from,
    FamilyEvent event, {
    String fromName = '',
    String? placeName,
  }) {
    if (event.kind != FamilyEventKind.remind || event.placeId == null) {
      return null;
    }
    return PlaceReminder(
      id: event.id,
      from: from,
      placeId: event.placeId!,
      onLeave: event.onLeave,
      note: event.note,
      fromName: fromName,
      placeName: placeName,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceReminder &&
      other.id == id &&
      other.from == from &&
      other.placeId == placeId &&
      other.onLeave == onLeave &&
      other.note == note &&
      other.fromName == fromName &&
      other.placeName == placeName;

  @override
  int get hashCode => Object.hash(id, from, placeId, onLeave, note);
}

/// A reminder that hasn't gone off or been taken back: who set it, and for
/// whom.
class OpenReminder {
  const OpenReminder({required this.from, required this.event});
  final String from;
  final FamilyEvent event;
  String get to => event.to!;
  String get id => event.id;
}

/// The circle's open reminders, from its events (any order): each `remind`
/// minus the ones a `remindDone` (by its member) or `remindCancel` (by who
/// set it, or by its member turning it down) closed. Newest first.
List<OpenReminder> openReminders(
  Iterable<({String userId, FamilyEvent event})> events,
) {
  final reminds = <String, OpenReminder>{};
  final closed = <String, Set<String>>{}; // ref -> users who closed it
  for (final e in events) {
    switch (e.event.kind) {
      case FamilyEventKind.remind
          when e.event.to != null && e.event.placeId != null:
        reminds[e.event.id] = OpenReminder(from: e.userId, event: e.event);
      case FamilyEventKind.remindDone || FamilyEventKind.remindCancel
          when e.event.ref != null:
        (closed[e.event.ref!] ??= {}).add('${e.event.kind.name}:${e.userId}');
      default:
    }
  }
  final out = [
    for (final r in reminds.values)
      // Only its member can say it went off, and only its sender or its
      // member can take it back: nobody else can close it.
      if (!(closed[r.id]?.contains('remindDone:${r.to}') ?? false) &&
          !(closed[r.id]?.contains('remindCancel:${r.from}') ?? false) &&
          !(closed[r.id]?.contains('remindCancel:${r.to}') ?? false))
        r,
  ];
  out.sort((a, b) => b.event.at.compareTo(a.event.at));
  return out;
}
