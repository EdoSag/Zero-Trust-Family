import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/circle.dart';

/// Bumped after every local write, so screens update at once even offline
/// (the sync status, which also refreshes them, changes only on sync).
final familyRevisionProvider = NotifierProvider<FamilyRevision, int>(
  FamilyRevision.new,
);

class FamilyRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// One family circle: its shared space, name and members.
class CircleData {
  const CircleData({
    required this.spaceId,
    required this.circle,
    required this.members,
    required this.isAdmin,
  });

  final String spaceId;

  /// Null until the circle's name has synced to this phone.
  final Circle? circle;

  /// Current members, owners first, then by name.
  final List<SpaceMember> members;
  final bool isAdmin;

  String? get name =>
      circle == null || circle!.name.isEmpty ? null : circle!.name;
}

/// A circle this account asked to join and is not let into yet (or that
/// this phone can't vouch for yet).
class PendingCircle {
  const PendingCircle(this.spaceId);
  final String spaceId;
}

class FamilyData {
  const FamilyData({
    this.circles = const [],
    this.pending = const [],
    this.ready = false,
    this.loading = true,
    this.error,
  });

  final List<CircleData> circles;
  final List<PendingCircle> pending;

  /// Circles can be created and joined (the vault is open).
  final bool ready;
  final bool loading;
  final Object? error;

  CircleData? circle(String spaceId) {
    for (final c in circles) {
      if (c.spaceId == spaceId) return c;
    }
    return null;
  }
}

/// Owners first, then by name (case ignored), then by id so the order
/// never jumps between two phones.
List<SpaceMember> sortMembers(Iterable<SpaceMember> members) {
  int rank(SpaceMember m) => m.role == SpaceRole.admin ? 0 : 1;
  return members.toList()..sort((a, b) {
    final byRole = rank(a).compareTo(rank(b));
    if (byRole != 0) return byRole;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.userId.compareTo(b.userId);
  });
}

/// Reads one open space into a [CircleData].
Future<CircleData> readCircle(SharedSpace space) async {
  Circle? circle;
  final item = await space.store.get(Circle.itemId);
  final json = item == null || item.deleted ? null : item.json;
  if (json != null && json['kind'] == Circle.kind) {
    try {
      circle = Circle.fromJson(json);
    } on Object {
      // Written by a newer version of the app: shown without a name.
    }
  }
  return CircleData(
    spaceId: space.id,
    circle: circle,
    members: sortMembers(space.members),
    isAdmin: space.isAdmin,
  );
}

/// The circles this account asked to join, kept in the app's own encrypted
/// store so the account's other phones show them as waiting too.
abstract final class PendingJoins {
  static const itemId = 'family.pending-joins';
  static const kind = 'family.pending_joins';

  static List<String> read(Map<String, Object?>? json) => [
    if (json != null && json['kind'] == kind)
      for (final id in (json['spaces'] as List? ?? const []))
        if (id is String) id,
  ];

  static Map<String, Object?> toJson(List<String> spaces) => {
    'kind': kind,
    'spaces': spaces,
  };
}

final pendingJoinIdsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(familyRevisionProvider);
  ref.watch(ztSyncControllerProvider);
  final store = await ref.watch(ztLocalStoreProvider.future);
  final item = await store.get(PendingJoins.itemId);
  return PendingJoins.read(item == null || item.deleted ? null : item.json);
});

final familyProvider = FutureProvider<FamilyData>((ref) async {
  ref.watch(familyRevisionProvider);
  final spaces = ref.watch(ztSpacesProvider);
  final circles = <CircleData>[];
  final pending = <PendingCircle>[];
  final listed = <String>{};
  for (final e in spaces.entries) {
    listed.add(e.info.id);
    final space = e.space;
    if (space == null) {
      // Let in, but this phone can't vouch for the member list yet.
      pending.add(PendingCircle(e.info.id));
      continue;
    }
    circles.add(await readCircle(space));
  }
  List<String> asked = const [];
  try {
    asked = await ref.watch(pendingJoinIdsProvider.future);
  } on Object {
    // The app's own store isn't open yet: shown on the next change.
  }
  for (final id in asked) {
    if (!listed.contains(id)) pending.add(PendingCircle(id));
  }
  circles.sort((a, b) {
    final byName = (a.name ?? '').toLowerCase().compareTo(
      (b.name ?? '').toLowerCase(),
    );
    return byName != 0 ? byName : a.spaceId.compareTo(b.spaceId);
  });
  return FamilyData(
    circles: circles,
    pending: pending,
    ready: spaces.ready,
    loading: spaces.loading,
    error: spaces.error,
  );
});

/// Every change Family makes, as one place to read the rules from.
class FamilyActions {
  FamilyActions(this.ref);
  final Ref ref;

  SpacesController get _spaces => ref.read(ztSpacesProvider.notifier);

  void _changed() => ref.read(familyRevisionProvider.notifier).bump();

  /// A new circle is a new shared space with this account as its owner.
  /// Returns its id.
  Future<String> createCircle({
    required String name,
    required String myName,
  }) async {
    final clean = Circle.cleanName(name);
    if (clean == null) throw ArgumentError.value(name, 'name', 'empty');
    final space = await _spaces.create(myName: myName);
    await _spaces.save(space.id, Circle.itemId, Circle(name: clean).toJson());
    _changed();
    return space.id;
  }

  /// Owners only (the server refuses anyone else).
  Future<void> renameCircle(String spaceId, String name) async {
    final clean = Circle.cleanName(name);
    if (clean == null) throw ArgumentError.value(name, 'name', 'empty');
    await _spaces.save(spaceId, Circle.itemId, Circle(name: clean).toJson());
    _changed();
  }

  Future<List<String>> _pending() async {
    final store = await ref.read(ztLocalStoreProvider.future);
    final item = await store.get(PendingJoins.itemId);
    return PendingJoins.read(item == null || item.deleted ? null : item.json);
  }

  Future<void> _savePending(List<String> ids) async {
    await ref
        .read(ztSyncControllerProvider.notifier)
        .save(PendingJoins.itemId, PendingJoins.toJson(ids));
    _changed();
  }

  /// Remembers a circle this account just asked to join, so the home
  /// screen shows it as waiting until an owner lets it in.
  Future<void> rememberJoin(String spaceId) async {
    final ids = await _pending();
    if (ids.contains(spaceId)) return;
    await _savePending([...ids, spaceId]);
  }

  /// Stops showing [spaceId] as waiting (the request was turned down, or
  /// the person changed their mind).
  Future<void> forgetJoin(String spaceId) async {
    final ids = await _pending();
    if (!ids.contains(spaceId)) return;
    await _savePending([
      for (final id in ids)
        if (id != spaceId) id,
    ]);
  }

  /// Drops waiting entries for circles this account is in by now.
  Future<void> tidyPending(Set<String> joined) async {
    final ids = await _pending();
    final keep = [
      for (final id in ids)
        if (!joined.contains(id)) id,
    ];
    if (keep.length != ids.length) await _savePending(keep);
  }
}

final familyActionsProvider = Provider<FamilyActions>(FamilyActions.new);

/// The signed-in account's id, to mark "you" in member lists.
final myUserIdProvider = Provider<String?>(
  (ref) => ref.watch(accountServiceProvider).currentUserId,
);
