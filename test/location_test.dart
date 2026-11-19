import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/location/alerts.dart';
import 'package:zerotrust_family/location/family_event.dart';
import 'package:zerotrust_family/location/geofence.dart';
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

  group('places', () {
    const home = WatchedPlace(id: 'home', lat: 32.0, lng: 34.8, radiusM: 150);
    final t = DateTime.utc(2026, 11, 19, 8);
    Fix at(double lat, {double accuracy = 10}) =>
        Fix(lat: lat, lng: 34.8, at: t, accuracyM: accuracy);

    test('inside, outside, and the edge in between', () {
      expect(Geofence.inside(home, at(32.0)), isTrue);
      // About 167 m north: past the radius but within the margin.
      expect(Geofence.inside(home, at(32.0015)), isNull);
      expect(Geofence.inside(home, at(32.003)), isFalse);
      // Too rough to tell.
      expect(Geofence.inside(home, at(32.0, accuracy: 900)), isNull);
    });

    test('the first sighting says nothing; crossings after it do', () {
      var (known, crossings) = Geofence.check({}, [home], at(32.0));
      expect(known, {'home': true});
      expect(crossings, isEmpty);
      (known, crossings) = Geofence.check(known, [home], at(32.0015));
      expect(known, {'home': true});
      expect(crossings, isEmpty);
      (known, crossings) = Geofence.check(known, [home], at(32.01));
      expect(known, {'home': false});
      expect(crossings.single.kind, FamilyEventKind.leave);
      (known, crossings) = Geofence.check(known, [home], at(32.0));
      expect(crossings.single.kind, FamilyEventKind.arrive);
      // A removed place is forgotten.
      (known, crossings) = Geofence.check(known, const [], at(32.0));
      expect(known, isEmpty);
    });

    test('quiet hours wrap past midnight', () {
      const q = QuietHours.standard;
      expect(q.at(DateTime(2026, 1, 1, 23)), isTrue);
      expect(q.at(DateTime(2026, 1, 1, 6, 59)), isTrue);
      expect(q.at(DateTime(2026, 1, 1, 7)), isFalse);
      expect(
        const QuietHours(13 * 60, 15 * 60).at(DateTime(2026, 1, 1, 14)),
        isTrue,
      );
    });
  });

  group('arrive and leave alerts', () {
    late InMemoryLocationServer server;
    late InMemoryShareStore mumStore;
    late ShareEngine mum$;
    late InMemoryAlertStore dadStore;
    late AlertEngine dad$;
    late DateTime now;
    const home = WatchedPlace(id: 'home', lat: 32.0, lng: 34.8, radiusM: 150);

    setUp(() async {
      now = DateTime.utc(2026, 11, 19, 9);
      server = InMemoryLocationServer()
        ..members[circle] = {mum, dad}
        ..epochs[circle] = 1
        ..now = () => now;
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
            places: const [home],
          ),
        ],
      );
      mumStore = InMemoryShareStore(state);
      mum$ = ShareEngine(
        store: mumStore,
        backend: InMemoryLocationBackend(userId: mum, server: server),
        clock: () => now,
      );
      final devicePub = (await Signing.fromSeed(
        state.deviceSeed,
      )).publicKeyBytes;
      dadStore = InMemoryAlertStore(
        AlertState(
          userId: dad,
          circles: {
            circle: AlertCircle(
              spaceId: circle,
              boxes: {
                1: await LocationBox.boxSeed(
                  spaceKey: spaceKey(1),
                  spaceId: circle,
                  epoch: 1,
                ),
              },
              devices: {'$mum/${state.deviceId}': devicePub},
              names: {mum: 'Mum'},
              places: {'home': 'Home'},
              cursor: now.subtract(const Duration(minutes: 1)),
            ),
          },
        ),
      );
      dad$ = AlertEngine(
        store: dadStore,
        backend: InMemoryLocationBackend(userId: dad, server: server),
        clock: () => now,
      );
    });

    Future<void> mumAt(double lat) async {
      now = now.add(const Duration(minutes: 2));
      await mum$.onFix(fix(now, lat: lat), const DeviceStatus(battery: 50));
    }

    test('leaving home reaches dad\'s locked phone, once', () async {
      await mumAt(32.0); // First sighting: no event.
      expect(server.events, isEmpty);
      await mumAt(32.01);
      expect(server.events, hasLength(1));
      final hits = await dad$.check();
      expect(hits.single.name, 'Mum');
      expect(hits.single.placeName, 'Home');
      expect(hits.single.event.kind, FamilyEventKind.leave);
      expect(hits.single.event.battery, 50);
      // Asked again: already shown.
      expect(await dad$.check(), isEmpty);
      await mumAt(32.0);
      expect((await dad$.check()).single.event.kind, FamilyEventKind.arrive);
    });

    test('nothing while paused', () async {
      await mumAt(32.0);
      mumStore.state = mumStore.state!.copyWith(pausedOpenEnded: true);
      await mumAt(32.01);
      expect(server.events, isEmpty);
    });

    test('muted people, own events and old events stay silent', () async {
      await mumAt(32.0);
      await mumAt(32.01);
      final c = dadStore.state!.circles[circle]!;
      dadStore.state = dadStore.state!.copyWith(
        circles: {
          circle: c.copyWith(muted: {mum}),
        },
      );
      expect(await dad$.check(), isEmpty);

      // Mum's own phone, with alerts on, doesn't alert her about herself.
      final mine = AlertEngine(
        store: InMemoryAlertStore(
          AlertState(userId: mum, circles: {circle: c}),
        ),
        backend: InMemoryLocationBackend(userId: mum, server: server),
        clock: () => now,
      );
      expect(await mine.check(), isEmpty);

      // A phone that was off for a day doesn't ring for old events.
      final late = AlertEngine(
        store: InMemoryAlertStore(
          AlertState(userId: dad, circles: {circle: c}),
        ),
        backend: InMemoryLocationBackend(userId: dad, server: server),
        clock: () => now.add(const Duration(days: 1)),
      );
      expect(await late.check(), isEmpty);
    });

    test('an event from an unknown device is not shown', () async {
      await mumAt(32.0);
      await mumAt(32.01);
      final c = dadStore.state!.circles[circle]!;
      final other = await Signing.generate();
      dadStore.state = dadStore.state!.copyWith(
        circles: {
          circle: c.copyWith(
            devices: {c.devices.keys.single: other.publicKeyBytes},
          ),
        },
      );
      expect(await dad$.check(), isEmpty);
    });

    test('quiet hours mark alerts silent', () async {
      dadStore.state = dadStore.state!.copyWith(
        quiet: () => const QuietHours(0, 1439),
      );
      await mumAt(32.0);
      await mumAt(32.01);
      expect((await dad$.check()).single.quiet, isTrue);
    });

    test('another account on the phone drops the alerts', () async {
      final other = AlertEngine(
        store: dadStore,
        backend: InMemoryLocationBackend(userId: teen, server: server),
        clock: () => now,
      );
      expect(await other.check(), isEmpty);
      expect(dadStore.state, isNull);
    });

    test('a check-in reaches dad, note and all, and ends the timer', () async {
      await mumAt(32.0);
      expect(
        await mum$.startTimer(circle, now.add(const Duration(minutes: 30))),
        isTrue,
      );
      expect((await dad$.check()).single.event.kind, FamilyEventKind.timer);
      expect(dadStore.state!.circles[circle]!.timers.keys, [mum]);

      expect(await mum$.checkIn(circle, note: '  Home safe  '), isTrue);
      expect(mumStore.state!.timer, isNull);
      final hit = (await dad$.check()).single;
      expect(hit.event.kind, FamilyEventKind.checkin);
      expect(hit.event.note, 'Home safe');
      expect(hit.event.lat, 32.0);
      expect(dadStore.state!.circles[circle]!.timers, isEmpty);
    });

    test('a long note is cut to 140 characters', () async {
      await mum$.checkIn(circle, note: 'x' * 400);
      expect((await dad$.check()).single.event.note, hasLength(140));
    });

    test('an ask rings only the person it is for, even muted', () async {
      final c = dadStore.state!.circles[circle]!;
      dadStore.state = dadStore.state!.copyWith(
        circles: {
          circle: c.copyWith(muted: {mum}),
        },
      );
      await mum$.askCheckIn(circle, teen);
      expect(await dad$.check(), isEmpty);
      await mum$.askCheckIn(circle, dad);
      final hit = (await dad$.check()).single;
      expect(hit.asksMe, isTrue);
      expect(hit.urgent, isFalse);
    });

    test(
      'a missed timer: mum\'s phone sends overdue and shares live',
      () async {
        await mumAt(32.0);
        mumStore.state = mumStore.state!.copyWith(pausedOpenEnded: true);
        final until = now.add(const Duration(minutes: 30));
        await mum$.startTimer(circle, until);
        await dad$.check();

        now = until.add(const Duration(minutes: 1));
        await mum$.onMotion();
        final s = mumStore.state!;
        expect(s.timer, isNull);
        expect(s.pausedOpenEnded, isFalse);
        expect(s.liveUntil, now.add(ShareEngine.liveAfterAlarm));
        final hit = (await dad$.check()).single;
        expect(hit.event.kind, FamilyEventKind.overdue);
        expect(hit.urgent, isTrue);
      },
    );

    test(
      'a timer that runs out with mum\'s phone off still alerts, once',
      () async {
        final until = now.add(const Duration(minutes: 30));
        await mum$.startTimer(circle, until);
        await dad$.check();
        now = until.add(const Duration(minutes: 1));
        // Mum's phone is off: dad's phone sees the time pass by itself.
        final hit = (await dad$.check()).single;
        expect(hit.event.kind, FamilyEventKind.overdue);
        expect(hit.event.id, startsWith('late-'));
        expect(await dad$.check(), isEmpty);
        // Her phone comes back and sends overdue: not a second alert.
        await mum$.onMotion();
        expect(server.events, hasLength(2));
        expect(await dad$.check(), isEmpty);
      },
    );

    test('ending the timer in time alerts no one later', () async {
      final until = now.add(const Duration(minutes: 30));
      await mum$.startTimer(circle, until);
      await dad$.check();
      expect(await mum$.endTimer(), isTrue);
      expect((await dad$.check()).single.event.kind, FamilyEventKind.timerEnd);
      now = until.add(const Duration(minutes: 5));
      expect(await dad$.check(), isEmpty);
    });

    test('SOS: loud past muting and quiet hours, shares live', () async {
      final c = dadStore.state!.circles[circle]!;
      dadStore.state = dadStore.state!.copyWith(
        quiet: () => const QuietHours(0, 1439),
        circles: {
          circle: c.copyWith(muted: {mum}),
        },
      );
      mumStore.state = mumStore.state!.copyWith(pausedOpenEnded: true);
      expect(await mum$.startSos(circle), isTrue);
      expect(mumStore.state!.sos?.spaceId, circle);
      expect(mumStore.state!.pausedOpenEnded, isFalse);
      expect(mumStore.state!.liveUntil, now.add(ShareEngine.liveAfterAlarm));
      final hit = (await dad$.check()).single;
      expect(hit.event.kind, FamilyEventKind.sos);
      expect(hit.urgent, isTrue);

      expect(await mum$.endSos(), isTrue);
      expect(mumStore.state!.sos, isNull);
      expect(mumStore.state!.liveUntil, isNull);
      // Whoever got the SOS also hears that it ended, without sound.
      final safe = (await dad$.check()).single;
      expect(safe.event.kind, FamilyEventKind.sosEnd);
      expect(safe.urgent, isFalse);
      expect(safe.quiet, isTrue);
    });

    test('safety needs the circle: an unknown circle sends nothing', () async {
      expect(await mum$.checkIn('other'), isFalse);
      expect(await mum$.startSos('other'), isFalse);
      expect(mumStore.state!.sos, isNull);
      expect(
        await mum$.startTimer(circle, now.subtract(const Duration(minutes: 1))),
        isFalse,
      );
      expect(server.events, isEmpty);
    });

    test('the newest events come first when asked (the Today list)', () async {
      await mumAt(32.0);
      for (var i = 0; i < 6; i++) {
        await mumAt(i.isEven ? 32.01 : 32.0);
      }
      final reader = InMemoryLocationBackend(userId: dad, server: server);
      final since = DateTime.utc(2026, 11, 19);
      final oldest = await reader.events(circle, since: since, limit: 2);
      final newest = await reader.events(
        circle,
        since: since,
        limit: 2,
        newestFirst: true,
      );
      expect(newest.first.sentAt, server.events.last.sentAt);
      expect(oldest.first.sentAt, server.events.first.sentAt);
    });

    test('settings survive a round trip through JSON', () {
      final s = dadStore.state!.copyWith(quiet: () => QuietHours.standard);
      final back = AlertState.fromJson(s.toJson());
      final c = back.circles[circle]!;
      expect(back.quiet, QuietHours.standard);
      expect(c.boxes[1], dadStore.state!.circles[circle]!.boxes[1]);
      expect(c.places, {'home': 'Home'});
      final pkg = CirclePackage.fromJson(
        mumStore.state!.circles.single
            .copyWith(inside: {'home': true})
            .toJson(),
      );
      expect(pkg.places.single, home);
      expect(pkg.inside, {'home': true});
    });
  });
}
