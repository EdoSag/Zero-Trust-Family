import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

import '../data/locations.dart';
import '../location/approximate.dart';
import 'common.dart';

/// Where the map comes from: a Protomaps PMTiles file on the project's own
/// storage (`FAMILY_MAP_URL` in `.env`), so no map company sees which part
/// of the world a family looks at. Null until it's set: the circle then
/// shows the member list without a map.
String? familyMapUrl() {
  try {
    if (!dotenv.isInitialized) return null;
    final url = dotenv.env['FAMILY_MAP_URL']?.trim();
    return url == null || url.isEmpty ? null : url;
  } on Object {
    return null;
  }
}

/// The circle's map: everyone who shares, at their last position.
class FamilyMap extends StatefulWidget {
  const FamilyMap({
    super.key,
    required this.url,
    required this.locations,
    required this.names,
    required this.controller,
  });

  final String url;
  final Map<String, MemberLocation> locations;
  final Map<String, String> names;
  final MapController controller;

  @override
  State<FamilyMap> createState() => _FamilyMapState();
}

class _FamilyMapState extends State<FamilyMap> {
  late Future<PmTilesVectorTileProvider> _tiles =
      PmTilesVectorTileProvider.fromSource(widget.url);

  @override
  void didUpdateWidget(FamilyMap old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _tiles = PmTilesVectorTileProvider.fromSource(widget.url);
    }
  }

  List<LatLng> get _points => [
    for (final m in widget.locations.values)
      if (m.update.hasLocation) LatLng(m.update.lat!, m.update.lng!),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final points = _points;
    return FutureBuilder<PmTilesVectorTileProvider>(
      future: _tiles,
      builder: (context, snapshot) {
        final tiles = snapshot.data;
        return FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 16,
                  )
                : null,
            initialCenter: points.isEmpty
                ? const LatLng(31.77, 35.21)
                : points.first,
            initialZoom: points.isEmpty ? 7 : 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            if (tiles != null)
              VectorTileLayer(
                theme: dark
                    ? ProtomapsThemes.darkV3()
                    : ProtomapsThemes.lightV3(),
                tileProviders: TileProviders({'protomaps': tiles}),
              ),
            // Members who share only roughly where they are: their area.
            CircleLayer(
              circles: [
                for (final m in widget.locations.values)
                  if (m.update.hasLocation && m.update.approximate)
                    CircleMarker(
                      point: LatLng(m.update.lat!, m.update.lng!),
                      radius: m.update.accuracyM ?? Approximate.radiusM,
                      useRadiusInMeter: true,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderColor: Theme.of(context).colorScheme.primary,
                      borderStrokeWidth: 1,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final e in widget.locations.entries)
                  if (e.value.update.hasLocation)
                    Marker(
                      key: Key('marker-${e.key}'),
                      point: LatLng(e.value.update.lat!, e.value.update.lng!),
                      width: 44,
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black26),
                          ],
                        ),
                        child: MemberAvatar(name: widget.names[e.key] ?? ''),
                      ),
                    ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('© OpenStreetMap, Protomaps'),
            ),
          ],
        );
      },
    );
  }
}
