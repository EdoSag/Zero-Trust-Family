import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../location/location_backend.dart';
import '../location/location_box.dart';
import '../location/location_update.dart';
import '../location/share_engine.dart';
import '../location/share_store.dart';
import '../model/family_place.dart';
import 'family_data.dart';

/// A sharing device, published by its member as a space item that only
/// that member can write: `family.me/<user id>/device/<device id>`.
abstract final class DeviceItem {
  static const kind = 'family.device';
  static const _prefix = 'family.me/';

  static String itemId(String userId, String deviceId) =>
      '$_prefix$userId/device/$deviceId';

  static Map<String, Object?> toJson(Uint8List publicKey) => {
    'kind': kind,
    'pub': ZtBase64.encode(publicKey),
  };

  /// `userId/deviceId` → public key, for every device in [items].
  static Map<String, Uint8List> readAll(Iterable<LocalItem> items) {
    final out = <String, Uint8List>{};
    for (final item in items) {
      if (item.deleted || !item.itemId.startsWith(_prefix)) continue;
      final rest = item.itemId.substring(_prefix.length).split('/');
      if (rest.length != 3 || rest[1] != 'device') continue;
      final json = item.json;
      if (json == null || json['kind'] != kind) continue;
      final pub = json['pub'];
      if (pub is! String) continue;
      try {
        final key = ZtBase64.decode(pub);
        if (key.length == 32) out['${rest[0]}/${rest[2]}'] = key;
      } on FormatException {
        // Written by a newer version: that device isn't shown.
      }
    }
    return out;
  }
}

/// A member's newest location (or pause), opened and checked.
class MemberLocation {
  const MemberLocation({
    required this.userId,
    required this.deviceId,
    required this.update,
    this.sentAt,
  });

  final String userId;
  final String deviceId;
  final LocationUpdate update;
  final DateTime? sentAt;
}

/// Opens a circle's `family_latest` rows: only rows signed by a device its
/// member published, sealed for this circle and bound to that row. Anything
/// else (forged by the server, moved between rows, old key) is skipped.
/// Newest update per member.
Future<Map<String, MemberLocation>> openCircleLocations({
  required String spaceId,
  required List<LocationRow> rows,
  required Map<String, Uint8List> devices,
  required Uint8List? Function(int epoch) spaceKey,
}) async {
  final boxes = <int, SimpleKeyPair?>{};
  final out = <String, MemberLocation>{};
  for (final row in rows) {
    if (row.spaceId != spaceId) continue;
    final pub = devices['${row.userId}/${row.deviceId}'];
    if (pub == null) continue;
    final context = LocationBox.context(
      table: 'family_latest',
      spaceId: spaceId,
      userId: row.userId,
      deviceId: row.deviceId,
      epoch: row.epoch,
    );
    try {
      final ok = await Signing.verify(
        LocationBox.signedBytes(context, row.payload),
        signature: row.signature,
        publicKey: pub,
      );
      if (!ok) continue;
      final box = boxes.containsKey(row.epoch)
          ? boxes[row.epoch]
          : boxes[row.epoch] = await _box(
              spaceKey(row.epoch),
              spaceId,
              row.epoch,
            );
      if (box == null) continue;
      final update = LocationUpdate.decode(
        await LocationBox.open(row.payload, box: box, context: context),
      );
      final had = out[row.userId];
      if (had == null || update.at.isAfter(had.update.at)) {
        out[row.userId] = MemberLocation(
          userId: row.userId,
          deviceId: row.deviceId,
          update: update,
          sentAt: row.sentAt,
        );
      }
    } on Object {
      continue;
    }
  }
  return out;
}

Future<SimpleKeyPair?> _box(Uint8List? key, String spaceId, int epoch) async =>
    key == null
    ? null
    : LocationBox.derive(spaceKey: key, spaceId: spaceId, epoch: epoch);

final locationBackendProvider = Provider<LocationBackend>(
  (ref) => SupabaseLocationBackend(),
);

final shareStoreProvider = Provider<ShareStore>((ref) => SecureShareStore());

/// Starts and stops the Android service; replaced in tests.
abstract class ShareServiceControl {
  Future<void> start();
  Future<void> stop();

  /// Ask the running service to send now and refresh its notification.
  Future<void> poke();

  /// Can the service run (location "all the time" and notifications)?
  Future<SharePermissions> permissions();
  Future<SharePermissions> requestPermissions();

  /// For alerts alone (no location needed).
  Future<bool> requestNotifications();
}

class SharePermissions {
  const SharePermissions({
    required this.location,
    required this.background,
    required this.notifications,
  });
  final bool location;
  final bool background;
  final bool notifications;
  bool get all => location && background;
}

final shareServiceProvider = Provider<ShareServiceControl>(
  (ref) => throw UnimplementedError('set in main()'),
);

final shareEngineProvider = Provider<ShareEngine>(
  (ref) => throw UnimplementedError('set in main()'),
);

final shareRevisionProvider = NotifierProvider<FamilyRevision, int>(
  FamilyRevision.new,
);

final shareStateProvider = FutureProvider<ShareState?>((ref) async {
  ref.watch(shareRevisionProvider);
  return ref.read(shareStoreProvider).load();
});

SharedSpace? _space(Ref ref, String spaceId) {
  for (final e in ref.read(ztSpacesProvider).entries) {
    if (e.info.id == spaceId) return e.space;
  }
  return null;
}

/// Where everyone in a circle is, refreshed live while a screen shows it.
final circleLocationsProvider = FutureProvider.autoDispose
    .family<Map<String, MemberLocation>, String>((ref, spaceId) async {
      ref.watch(familyRevisionProvider);
      ref.watch(ztSpacesProvider);
      final backend = ref.watch(locationBackendProvider);
      final sub = backend.changes(spaceId).listen((_) => ref.invalidateSelf());
      final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
      ref.onDispose(() {
        sub.cancel();
        timer.cancel();
      });
      final space = _space(ref, spaceId);
      if (space == null) return const {};
      final rows = await backend.latest(spaceId);
      final devices = DeviceItem.readAll(await space.store.all());
      return openCircleLocations(
        spaceId: spaceId,
        rows: rows,
        devices: devices,
        spaceKey: (epoch) => space.codec.keyring[epoch],
      );
    });

/// Turning sharing on and off, pausing and sharing live. All of these run
/// with the app open and unlocked; the service then works from what they
/// leave in the share store.
class ShareActions {
  ShareActions(this.ref);
  final Ref ref;

  ShareStore get _store => ref.read(shareStoreProvider);
  ShareServiceControl get _service => ref.read(shareServiceProvider);
  ShareEngine get _engine => ref.read(shareEngineProvider);

  void _changed() => ref.read(shareRevisionProvider.notifier).bump();

  Future<CirclePackage?> _package(String spaceId) async {
    final space = _space(ref, spaceId);
    final epoch = space?.codec.keyring.writeEpoch;
    final key = epoch == null ? null : space!.codec.keyring[epoch];
    if (key == null) return null;
    final box = await LocationBox.derive(
      spaceKey: key,
      spaceId: spaceId,
      epoch: epoch!,
    );
    return CirclePackage(
      spaceId: spaceId,
      epoch: epoch,
      boxPublic: await LocationBox.publicKeyOf(box),
      places: [
        for (final p in await readPlaces(space!.store)) FamilyPlace.watched(p),
      ],
    );
  }

  Future<ShareState> _state() async {
    final me = ref.read(myUserIdProvider);
    if (me == null) throw StateError('Not signed in');
    final had = await _store.load();
    return had != null && had.userId == me ? had : ShareState.fresh(me);
  }

  /// Publishes this phone's device key in the circle (once) and adds the
  /// circle to what the service shares with. Throws [StateError] when the
  /// circle's key isn't ready on this phone yet.
  Future<void> startSharing(String spaceId) async {
    final package = await _package(spaceId);
    if (package == null) throw StateError('Circle key not ready');
    var state = await _state();
    final keys = await Signing.fromSeed(state.deviceSeed);
    final id = DeviceItem.itemId(state.userId, state.deviceId);
    final space = _space(ref, spaceId)!;
    final existing = await space.store.get(id);
    final published = existing?.json?['pub'];
    if (existing == null ||
        existing.deleted ||
        published != ZtBase64.encode(keys.publicKeyBytes)) {
      await ref
          .read(ztSpacesProvider.notifier)
          .save(spaceId, id, DeviceItem.toJson(keys.publicKeyBytes));
    }
    state = state.copyWith(
      circles: [
        for (final c in state.circles)
          if (c.spaceId != spaceId) c,
        package,
      ],
    );
    await _store.save(state);
    _changed();
    await _service.start();
    await _service.poke();
  }

  /// Stops sharing with [spaceId] and takes this phone's last location off
  /// the server, so the circle doesn't see an old position.
  Future<void> stopSharing(String spaceId) async {
    final state = await _store.load();
    if (state == null) return;
    final rest = [
      for (final c in state.circles)
        if (c.spaceId != spaceId) c,
    ];
    await _store.save(state.copyWith(circles: rest));
    _changed();
    try {
      await ref
          .read(locationBackendProvider)
          .deleteLatest(spaceId: spaceId, deviceId: state.deviceId);
    } on Object {
      // Offline: the circle sees the last update until it's back.
    }
    if (rest.isEmpty) {
      await _service.stop();
    } else {
      await _service.poke();
    }
  }

  /// Pauses every circle for [duration], or until resumed when null.
  Future<void> pause(Duration? duration) async {
    final state = await _store.load();
    if (state == null) return;
    final until = duration == null ? null : DateTime.now().add(duration);
    await _store.save(
      state.copyWith(
        pausedUntil: () => until,
        pausedOpenEnded: duration == null,
        liveUntil: () => null,
      ),
    );
    _changed();
    await _engine.sendNow();
    await _service.poke();
  }

  Future<void> resume() async {
    final state = await _store.load();
    if (state == null) return;
    await _store.save(
      state.copyWith(pausedUntil: () => null, pausedOpenEnded: false),
    );
    _changed();
    await _service.poke();
  }

  /// Sends every few seconds for [duration] (one hour by default).
  Future<void> shareLive([Duration duration = const Duration(hours: 1)]) async {
    final state = await _store.load();
    if (state == null) return;
    await _store.save(
      state.copyWith(
        liveUntil: () => DateTime.now().add(duration),
        pausedUntil: () => null,
        pausedOpenEnded: false,
      ),
    );
    _changed();
    await _service.poke();
  }

  Future<void> stopLive() async {
    final state = await _store.load();
    if (state == null) return;
    await _store.save(state.copyWith(liveUntil: () => null));
    _changed();
    await _service.poke();
  }

  Future<bool> _safety(Future<bool> Function(ShareEngine e) run) async {
    final sent = await run(_engine);
    _changed();
    // New live sharing (SOS) or a timer to wake up for.
    await _service.poke();
    return sent;
  }

  /// The safety actions. Each returns false when it couldn't be sent
  /// (offline, or this phone doesn't share with the circle).
  Future<bool> checkIn(String spaceId, {String? note}) =>
      _safety((e) => e.checkIn(spaceId, note: note));

  Future<bool> askCheckIn(String spaceId, String userId) =>
      _safety((e) => e.askCheckIn(spaceId, userId));

  Future<bool> startTimer(String spaceId, DateTime until) =>
      _safety((e) => e.startTimer(spaceId, until));

  Future<bool> endTimer() => _safety((e) => e.endTimer());

  Future<bool> startSos(String spaceId) => _safety((e) => e.startSos(spaceId));

  Future<bool> endSos() => _safety((e) => e.endSos());

  /// After unlock and every sync: follows key changes (someone left or was
  /// removed), drops circles this account isn't in, and stops sharing when
  /// another account signed in on this phone.
  Future<void> refreshPackages() async {
    final state = await _store.load();
    if (state == null || !state.sharing) return;
    final me = ref.read(myUserIdProvider);
    if (me == null) return;
    if (me != state.userId) {
      await _store.save(state.copyWith(circles: const []));
      _changed();
      await _service.stop();
      return;
    }
    final ids = {for (final e in ref.read(ztSpacesProvider).entries) e.info.id};
    final next = <CirclePackage>[];
    for (final c in state.circles) {
      if (!ids.contains(c.spaceId)) continue; // Left or removed.
      final fresh = await _package(c.spaceId);
      next.add(
        fresh == null
            ? c
            // Keeps where this phone is for places that are still there.
            : fresh.copyWith(
                inside: {
                  for (final p in fresh.places)
                    if (c.inside[p.id] != null) p.id: c.inside[p.id]!,
                },
              ),
      );
    }
    final changed =
        next.length != state.circles.length ||
        [
          for (var i = 0; i < next.length; i++)
            next[i].epoch != state.circles[i].epoch ||
                next[i].stale != state.circles[i].stale ||
                !listEquals(next[i].places, state.circles[i].places),
        ].any((x) => x);
    if (!changed) return;
    await _store.save(state.copyWith(circles: next));
    _changed();
    if (next.isEmpty) {
      await _service.stop();
    } else {
      await _service.poke();
    }
  }
}

final shareActionsProvider = Provider<ShareActions>(ShareActions.new);
