import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/family_hub.dart';
import 'family_data.dart';
import 'places.dart';

/// L-2: the family hub of a circle, from the items ZT Calendar, ZT Tasks,
/// ZT Meds and other apps keep in it (S-10). Read-only here.
final circleHubProvider = FutureProvider.autoDispose.family<FamilyHub, String>((
  ref,
  spaceId,
) async {
  ref.watch(familyRevisionProvider);
  ref.watch(ztSpacesProvider);
  final space = spaceOf(ref, spaceId);
  if (space == null) return const FamilyHub();
  return FamilyHub.of(await space.store.all(), DateTime.now());
});
