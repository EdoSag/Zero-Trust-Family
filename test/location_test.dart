import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/location/location_backend.dart';
import 'package:zerotrust_family/location/location_box.dart';
import 'package:zerotrust_family/location/location_update.dart';
import 'package:zerotrust_family/location/schedule.dart';
import 'package:zerotrust_family/location/share_engine.dart';
import 'package:zerotrust_family/location/share_store.dart';

import 'support/phone.dart';

const circle = 'circle-1';
Uint8List spaceKey(int epoch) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (epoch * 31 + i) & 0xff));

String ctx({String user = mum, String device = 'dev', int epoch = 1}) =>
    LocationBox.context(
      table: 'family_latest',
      spaceId: circle,
      userId: user,
      deviceId: device,
      epoch: epoch,
    );

Fix fix(DateTime at, {double lat = 32.0, double lng = 34.8, double? speed}) =>
    Fix(lat: lat, lng: lng, at: at, accuracyM: 10, speedMps: speed);

void main() {
  group('location box', () {
    test(
      'a sealed update opens only with the circle box and context',
      () async {
        final box = await LocationBox.derive(
          spaceKey: spaceKey(1),
          spaceId: circle,
          epoch: 1,
        );
        final pub = await LocationBox.publicKeyOf(box);
        final payload = await LocationBox.seal(
          [1, 2, 3],
          boxPublic: pub,
          context: ctx(),
        );
        expect(payload.first, LocationBox.version);
        expect(await LocationBox.open(payload, box: box, context: ctx()), [
          1,
          2,
          3,
        ]);

        // Moved to another member's row: refused.
        await expectLater(
          LocationBox.open(
            payload,
            box: box,
            context: ctx(user: dad),
          ),
          throwsA(anything),
        );
        // The next key epoch (someone left) can't open it.
        final next = await LocationBox.derive(
          spaceKey: spaceKey(2),
          spaceId: circle,
          epoch: 2,
        );
        await expectLater(
          LocationBox.open(payload, box: next, context: ctx()),
          throwsA(anything),
        );
        // One flipped bit: refused.
        final tampered = Uint8List.fromList(payload)..[40] ^= 1;
        await expectLater(
          LocationBox.open(tampered, box: box, context: ctx()),
          throwsA(anything),
        );
      },
    );

    test('every member derives the same box', () async {
      final a = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: circle,
        epoch: 1,
      );
      final b = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: circle,
        epoch: 1,
      );
      expect(
        await LocationBox.publicKeyOf(a),
        await LocationBox.publicKeyOf(b),
      );
    });

    test('padding hides the size of an update', () {
      final still = LocationUpdate(
        at: DateTime.utc(2026, 11, 19, 12),
        lat: 32,
        lng: 34.8,
        mode: MotionMode.still,
      ).encode();
      final moving = LocationUpdate(
        at: DateTime.utc(2026, 11, 19, 12),
        lat: 32.123456,
        lng: 34.812345,
        accuracyM: 5,
        speedMps: 13.4,
        heading: 271,
        battery: 64,
        charging: true,
        mode: MotionMode.driving,
      ).encode();
      expect(still.length, moving.length);
      expect(still.length % PayloadPadding.bucket, 0);
      final back = LocationUpdate.decode(moving);
      expect(back.speedMps, 13.4);
      expect(back.battery, 64);
      expect(back.mode, MotionMode.driving);
    });
  });

  group('schedule', () {
    final t0 = DateTime.utc(2026, 11, 19, 8);

    test('a still phone asks every 15 minutes', () {
      final s = AdaptiveSchedule();
      expect(s.onFix(fix(t0)).interval, AdaptiveSchedule.stillEvery);
      expect(
        s.onFix(fix(t0.add(const Duration(minutes: 15)))).mode,
        MotionMode.still,
      );
    });

    test('motion speeds up, driving faster, and it settles back', () {
      final s = AdaptiveSchedule()..onFix(fix(t0));
      expect(s.onMotion(t0).interval, AdaptiveSchedule.movingEvery);
      var t = t0.add(const Duration(seconds: 45));
      s.onFix(fix(t, speed: 15));
      t = t.add(const Duration(seconds: 45));
      final driving = s.onFix(fix(t, lat: 32.01, speed: 15));
      expect(driving.mode, MotionMode.driving);
      expect(driving.interval, AdaptiveSchedule.drivingEvery);

      // Parked: walking pace, then still once nothing moves for 5 minutes.
      t = t.add(const Duration(minutes: 3));
      expect(s.onFix(fix(t, lat: 32.01)).mode, MotionMode.moving);
      t = t.add(const Duration(minutes: 6));
      expect(s.onFix(fix(t, lat: 32.01)).mode, MotionMode.still);
    });

    test('moving over 100 m counts as moving without a speed', () {
      final s = AdaptiveSchedule()..onFix(fix(t0));
      final d = s.onFix(fix(t0.add(const Duration(minutes: 15)), lat: 32.002));
      expect(d.mode, MotionMode.moving);
    });

    test('share live wins until it runs out', () {
      final s = AdaptiveSchedule()
        ..liveUntil = t0.add(const Duration(hours: 1));
      expect(s.current(t0).interval, AdaptiveSchedule.liveEvery);
      expect(
        s.current(t0.add(const Duration(hours: 2))).mode,
        MotionMode.still,
      );
    });
  });

  group('sharing engine', () {
    late InMemoryLocationServer server;
    late InMemoryShareStore store;
    late ShareEngine engine;
    late DateTime now;
    late Uint8List devicePub;

    setUp(() async {
      now = DateTime.utc(2026, 11, 19, 9);
      server = InMemoryLocationServer()
        ..members[circle] = {mum, dad}
        ..epochs[circle] = 1;
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: circle,
        epoch: 1,
      );
      final state = ShareState.fresh(mum).copyWith(
        circles: [
          CirclePackage(
            spaceId: circle,
            epoch: 1,
            boxPublic: await LocationBox.publicKeyOf(box),
          ),
        ],
      );
      devicePub = (await Signing.fromSeed(state.deviceSeed)).publicKeyBytes;
      store = InMemoryShareStore(state);
      engine = ShareEngine(
        store: store,
        backend: InMemoryLocationBackend(userId: mum, server: server),
        clock: () => now,
      );
    });

    Future<Map<String, MemberLocation>> dadSees({
      Map<String, Uint8List>? devices,
    }) async => openCircleLocations(
      spaceId: circle,
      rows: await InMemoryLocationBackend(
        userId: dad,
        server: server,
      ).latest(circle),
      devices: devices ?? {'$mum/${store.state!.deviceId}': devicePub},
      spaceKey: spaceKey,
    );

    test('a fix reaches the circle, sealed and signed', () async {
      final result = await engine.onFix(
        fix(now, speed: 0),
        const DeviceStatus(battery: 80),
      );
      expect(result.health, ShareHealth.sharing);
      expect(result.stop, isFalse);

      final seen = (await dadSees())[mum]!;
      expect(seen.update.lat, 32.0);
      expect(seen.update.lng, 34.8);
      expect(seen.update.battery, 80);
      // The server only ever had ciphertext.
      final row = server.rows.values.single;
      expect(row.payload.length, greaterThan(256));
    });

    test('a row from an unknown device is ignored', () async {
      await engine.onFix(fix(now), const DeviceStatus());
      final other = await Signing.generate();
      final seen = await dadSees(
        devices: {'$mum/${store.state!.deviceId}': other.publicKeyBytes},
      );
      expect(seen, isEmpty);
    });

    test('paused sends no position, only that it is paused', () async {
      final until = now.add(const Duration(hours: 1));
      store.state = store.state!.copyWith(pausedUntil: () => until);
      final result = await engine.onFix(fix(now), const DeviceStatus());
      expect(result.health, ShareHealth.paused);
      expect(result.decision.interval, AdaptiveSchedule.stillEvery);
      final seen = (await dadSees())[mum]!.update;
      expect(seen.lat, isNull);
      expect(seen.lng, isNull);
      expect(seen.pausedUntil, until);

      // An hour later the pause ends by itself.
      now = until.add(const Duration(minutes: 1));
      final after = await engine.onFix(fix(now), const DeviceStatus());
      expect(after.health, ShareHealth.sharing);
      expect((await dadSees())[mum]!.update.lat, 32.0);
      expect(store.state!.pausedUntil, isNull);
    });

    test('a changed circle key waits for the app to be unlocked', () async {
      server.epochs[circle] = 2;
      final result = await engine.onFix(fix(now), const DeviceStatus());
      expect(result.health, ShareHealth.needsUnlock);
      expect(store.state!.circles.single.stale, isTrue);
      expect(server.rows, isEmpty);
    });

    test('leaving the circle drops it and stops the service', () async {
      server.members[circle] = {dad};
      final result = await engine.onFix(fix(now), const DeviceStatus());
      expect(result.stop, isTrue);
      expect(store.state!.circles, isEmpty);
    });

    test('stopping waits for a send in flight, which can\'t undo it', () async {
      await engine.onFix(fix(now), const DeviceStatus());
      expect(await dadSees(), isNotEmpty);
      // A fix arrives and, before its send finishes, sharing is stopped.
      final sending = engine.onFix(
        fix(now.add(const Duration(minutes: 1))),
        const DeviceStatus(),
      );
      final left = await engine.stopCircle(circle);
      await sending;
      expect(left, 0);
      expect(store.state!.circles, isEmpty);
      expect(await dadSees(), isEmpty);
      // Later fixes go nowhere.
      final after = await engine.onFix(
        fix(now.add(const Duration(minutes: 2))),
        const DeviceStatus(),
      );
      expect(after.stop, isTrue);
      expect(await dadSees(), isEmpty);
    });

    test('stopped offline: the delete is kept and retried', () async {
      await engine.onFix(fix(now), const DeviceStatus());
      server.offline = true;
      expect(await engine.stopCircle(circle), 0);
      expect(store.state!.pendingDeletes, [circle]);
      expect(await dadSees(), isNotEmpty);
      // Survives a restart of the app.
      final back = ShareState.fromJson(store.state!.toJson());
      expect(back.pendingDeletes, [circle]);

      server.offline = false;
      await engine.retryDeletes();
      expect(store.state!.pendingDeletes, isEmpty);
      expect(await dadSees(), isEmpty);
    });

    test('another account on the phone stops sharing', () async {
      engine = ShareEngine(
        store: store,
        backend: InMemoryLocationBackend(userId: dad, server: server),
        clock: () => now,
      );
      final result = await engine.onFix(fix(now), const DeviceStatus());
      expect(result.stop, isTrue);
      expect(server.rows, isEmpty);
    });

    test('a device item lists the device for readers', () {
      final id = DeviceItem.itemId(mum, 'abc');
      expect(id, 'family.me/$mum/device/abc');
      final items = [
        LocalItem(
          itemId: id,
          updatedAt: now,
          json: DeviceItem.toJson(devicePub),
        ),
      ];
      expect(DeviceItem.readAll(items)['$mum/abc'], devicePub);
    });
  });
}
