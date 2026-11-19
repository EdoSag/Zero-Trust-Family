import 'dart:math' as math;

import 'family_event.dart';
import 'schedule.dart';

/// One of a circle's places, as the background service keeps it: where and
/// how big, without its name (the name stays in the encrypted circle).
class WatchedPlace {
  const WatchedPlace({
    required this.id,
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  final String id;
  final double lat;
  final double lng;
  final double radiusM;

  Map<String, Object?> toJson() => {
    'id': id,
    'la': lat,
    'lo': lng,
    'r': radiusM,
  };

  static WatchedPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final lat = json['la'];
    final lng = json['lo'];
    final r = json['r'];
    if (id is! String || lat is! num || lng is! num || r is! num) return null;
    return WatchedPlace(
      id: id,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      radiusM: r.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WatchedPlace &&
      other.id == id &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusM == radiusM;

  @override
  int get hashCode => Object.hash(id, lat, lng, radiusM);
}

/// A crossing found by [Geofence.check].
typedef Crossing = ({String placeId, FamilyEventKind kind});

/// Arrive and leave, worked out on the phone from each position the sharing
/// service takes, so the server never learns a place or a crossing.
///
/// A place is entered within its radius and left only beyond the radius
/// plus a margin (the position's accuracy, at least 50 m), so a phone at
/// the edge doesn't flip between the two. A position too rough to tell
/// changes nothing. The first time a place is seen, its state is noted
/// without an alert: turning sharing on at home doesn't say "arrived".
abstract final class Geofence {
  static const minMargin = 50.0;

  /// Inside, outside, or null when this position can't tell.
  static bool? inside(WatchedPlace place, Fix fix) {
    final accuracy = fix.accuracyM ?? 0;
    if (accuracy > math.max(250, place.radiusM * 2)) return null;
    final d = haversine(place.lat, place.lng, fix.lat, fix.lng);
    if (d <= place.radiusM) return true;
    if (d >= place.radiusM + math.max(minMargin, accuracy)) return false;
    return null;
  }

  /// The new inside/outside state for [places] (keyed by place id) and the
  /// crossings since [known]. Places no longer in the list are forgotten.
  static (Map<String, bool>, List<Crossing>) check(
    Map<String, bool> known,
    List<WatchedPlace> places,
    Fix fix,
  ) {
    final next = <String, bool>{};
    final crossings = <Crossing>[];
    for (final place in places) {
      final was = known[place.id];
      final now = inside(place, fix);
      if (now == null) {
        if (was != null) next[place.id] = was;
        continue;
      }
      next[place.id] = now;
      if (was != null && was != now) {
        crossings.add((
          placeId: place.id,
          kind: now ? FamilyEventKind.arrive : FamilyEventKind.leave,
        ));
      }
    }
    return (next, crossings);
  }
}
