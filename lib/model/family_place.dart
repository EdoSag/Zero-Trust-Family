import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_places/zt_places.dart';

import '../location/geofence.dart';
import 'circle.dart';

/// A circle's place ("Home", "School"), kept as the encrypted space item
/// `family.place/<id>`. Any member can add, change or remove one.
abstract final class FamilyPlace {
  static const kind = 'family.place';
  static const prefix = 'family.place/';

  /// Most places a circle keeps (the plan's free limit comes with L4).
  static const maxPlaces = 30;

  static String itemId(String placeId) => '$prefix$placeId';

  static Map<String, Object?> toJson(ZtPlace place) => {
    'kind': kind,
    'name': place.name,
    'lat': place.latitude,
    'lng': place.longitude,
    'radius': place.radiusMeters,
  };

  /// The place in item [itemId], or null when it isn't one this version
  /// can show.
  static ZtPlace? fromItem(String itemId, Map<String, Object?>? json) {
    if (json == null || json['kind'] != kind) return null;
    if (!itemId.startsWith(prefix)) return null;
    final id = itemId.substring(prefix.length);
    final lat = json['lat'];
    final lng = json['lng'];
    final radius = json['radius'];
    if (id.isEmpty || lat is! num || lng is! num) return null;
    final position = ZtLatLng(lat.toDouble(), lng.toDouble());
    if (!position.isValid) return null;
    final r = radius is num ? radius.toDouble() : ZtPlace.defaultRadius;
    return ZtPlace(
      id: id,
      name: Circle.cleanName(json['name'] as String? ?? '') ?? '',
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: r.clamp(ZtPlace.minRadius, 2000).toDouble(),
    );
  }

  /// Where and how big, for the background service.
  static WatchedPlace watched(ZtPlace place) => WatchedPlace(
    id: place.id,
    lat: place.latitude,
    lng: place.longitude,
    radiusM: place.radiusMeters,
  );
}

/// A circle's places, by name.
Future<List<ZtPlace>> readPlaces(LocalItemStore store) async {
  final out = <ZtPlace>[];
  for (final item in await store.all()) {
    if (item.deleted) continue;
    final place = FamilyPlace.fromItem(item.itemId, item.json);
    if (place != null) out.add(place);
  }
  out.sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
  return out;
}
