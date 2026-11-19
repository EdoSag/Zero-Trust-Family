import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_places/zt_places.dart';

import '../model/circle.dart';
import '../model/family_place.dart';
import 'family_data.dart';
import 'locations.dart';

SharedSpace? spaceOf(Ref ref, String spaceId) {
  for (final e in ref.read(ztSpacesProvider).entries) {
    if (e.info.id == spaceId) return e.space;
  }
  return null;
}

final circlePlacesProvider = FutureProvider.autoDispose
    .family<List<ZtPlace>, String>((ref, spaceId) async {
      ref.watch(familyRevisionProvider);
      ref.watch(ztSpacesProvider);
      final space = spaceOf(ref, spaceId);
      if (space == null) return const [];
      return readPlaces(space.store);
    });

/// The phone's location service, for "Use my current location".
final placeLocatorProvider = Provider<ZtPlaceReminders>(
  (ref) => ZtPlaceRemindersAndroid(),
);

class PlaceActions {
  PlaceActions(this.ref);
  final Ref ref;

  Future<void> _after() async {
    ref.read(familyRevisionProvider.notifier).bump();
    // The background service watches the new list from now on.
    await ref.read(shareActionsProvider).refreshPackages();
  }

  /// Adds or changes [place] in [spaceId]. Returns false when the circle
  /// already has [FamilyPlace.maxPlaces] places.
  Future<bool> save(String spaceId, ZtPlace place) async {
    final name = Circle.cleanName(place.name);
    if (name == null) throw ArgumentError.value(place.name, 'name', 'empty');
    final space = spaceOf(ref, spaceId);
    if (space == null) throw StateError('Not in this circle');
    final existing = await readPlaces(space.store);
    final isNew = !existing.any((p) => p.id == place.id);
    if (isNew && existing.length >= FamilyPlace.maxPlaces) return false;
    await ref
        .read(ztSpacesProvider.notifier)
        .save(
          spaceId,
          FamilyPlace.itemId(place.id),
          FamilyPlace.toJson(place.copyWith(name: name)),
        );
    await _after();
    return true;
  }

  Future<void> remove(String spaceId, String placeId) async {
    await ref
        .read(ztSpacesProvider.notifier)
        .delete(spaceId, FamilyPlace.itemId(placeId));
    await _after();
  }

  static String newId() {
    final b = Kdf.randomBytes(9);
    return [for (final v in b) v.toRadixString(16).padLeft(2, '0')].join();
  }
}

final placeActionsProvider = Provider<PlaceActions>(PlaceActions.new);
