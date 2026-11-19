import 'family_event.dart';
import 'geofence.dart';
import 'schedule.dart';

/// One line of a member's history.
sealed class TimelineEntry {
  const TimelineEntry();

  /// When it started (a stop's arrival, a move's departure, an event).
  DateTime get at;
}

/// Stayed in one spot for a while.
class Stop extends TimelineEntry {
  const Stop({
    required this.start,
    required this.end,
    required this.lat,
    required this.lng,
    this.placeId,
    this.ongoing = false,
  });

  final DateTime start;
  final DateTime end;
  final double lat;
  final double lng;

  /// The circle place it was at, if any.
  final String? placeId;

  /// The latest stop: still there as far as anyone knows.
  final bool ongoing;

  Duration get length => end.difference(start);

  @override
  DateTime get at => start;
}

/// Went from one stop to the next.
class Move extends TimelineEntry {
  const Move({required this.start, required this.end, required this.meters});

  final DateTime start;
  final DateTime end;
  final double meters;

  Duration get length => end.difference(start);

  @override
  DateTime get at => start;
}

/// A check-in, an SOS, an arrival: shown as it was sent.
class Moment extends TimelineEntry {
  const Moment(this.event);
  final FamilyEvent event;

  @override
  DateTime get at => event.at;
}

/// Turns one member's events into stops, moves and moments, newest first.
///
/// Positions within [stopRadiusM] of where a group started, over at least
/// [minStop], make a stop; anything shorter is on the way. Positions come
/// from history points and from any event that carries one.
List<TimelineEntry> buildTimeline(
  List<FamilyEvent> events, {
  List<WatchedPlace> places = const [],
  double stopRadiusM = 150,
  Duration minStop = const Duration(minutes: 10),
}) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  final fixes = [
    for (final e in sorted)
      if (e.hasLocation) e,
  ];
  final moments = [
    for (final e in sorted)
      if (e.kind != FamilyEventKind.point) Moment(e),
  ];

  // Consecutive positions near the first of each group.
  final groups = <List<FamilyEvent>>[];
  for (final f in fixes) {
    final g = groups.lastOrNull;
    if (g != null &&
        haversine(g.first.lat!, g.first.lng!, f.lat!, f.lng!) <= stopRadiusM) {
      g.add(f);
    } else {
      groups.add([f]);
    }
  }

  final out = <TimelineEntry>[];
  Stop? lastStop;
  FamilyEvent? lastStopFix;
  for (var i = 0; i < groups.length; i++) {
    final g = groups[i];
    final isLast = i == groups.length - 1;
    final span = g.last.at.difference(g.first.at);
    if (span < minStop && !isLast) continue;
    final lat = g.map((e) => e.lat!).reduce((a, b) => a + b) / g.length;
    final lng = g.map((e) => e.lng!).reduce((a, b) => a + b) / g.length;
    String? placeId;
    var best = double.infinity;
    for (final p in places) {
      final d = haversine(p.lat, p.lng, lat, lng);
      if (d <= p.radiusM && d < best) {
        best = d;
        placeId = p.id;
      }
    }
    final stop = Stop(
      start: g.first.at,
      end: g.last.at,
      lat: lat,
      lng: lng,
      placeId: placeId,
      ongoing: isLast,
    );
    if (lastStop != null && lastStopFix != null) {
      // The way between: every position after the last stop, up to here.
      var meters = 0.0;
      var prev = lastStopFix;
      for (final f in fixes) {
        if (!f.at.isAfter(lastStopFix.at) || f.at.isAfter(g.first.at)) {
          continue;
        }
        meters += haversine(prev.lat!, prev.lng!, f.lat!, f.lng!);
        prev = f;
      }
      if (meters > 0) {
        out.add(Move(start: lastStop.end, end: g.first.at, meters: meters));
      }
    }
    out.add(stop);
    lastStop = stop;
    lastStopFix = g.last;
  }
  out.addAll(moments);
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}
