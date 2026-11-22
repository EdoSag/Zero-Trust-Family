import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/l10n/event_text.dart';
import 'package:zerotrust_family/l10n/l10n.dart';
import 'package:zerotrust_family/location/alerts.dart';
import 'package:zerotrust_family/location/drive.dart';
import 'package:zerotrust_family/location/drive_store.dart';
import 'package:zerotrust_family/location/family_event.dart';
import 'package:zerotrust_family/location/location_backend.dart';
import 'package:zerotrust_family/location/location_box.dart';
import 'package:zerotrust_family/location/schedule.dart';
import 'package:zerotrust_family/location/share_engine.dart';
import 'package:zerotrust_family/location/share_store.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/driving_page.dart';

import 'home_page_test.dart' show phoneSize;
import 'location_test.dart' show spaceKey;
import 'support/app.dart';
import 'support/phone.dart';

final t0 = DateTime.utc(2026, 11, 22, 8);

/// One sample a second along a straight road heading north from
/// (32.0, 34.8), at the given speeds (m/s). Distance follows the speed.
List<DriveSample> road(
  List<double> speeds, {
  DateTime? from,
  double startLat = 32.0,
  Map<int, double> jolts = const {},
  Set<int> screen = const {},
  bool noSpeedAfterJolt = false,
}) {
  final start = from ?? t0;
  var lat = startLat;
  final out = <DriveSample>[];
  for (var i = 0; i < speeds.length; i++) {
    lat += speeds[i] / 111320;
    out.add(
      DriveSample(
        at: start.add(Duration(seconds: i)),
        speedMps: speeds[i],
        lat: lat,
        lng: 34.8,
        accuracyM: 5,
        peakG: jolts[i] ?? 0.1,
        screenOn: screen.contains(i),
      ),
    );
  }
  return out;
}

List<double> steady(double mps, int seconds) =>
    List<double>.filled(seconds, mps);

void main() {
  group('drive tracker', () {
    test('a drive: distance, top speed, hard braking, phone use', () {
      final tracker = DriveTracker(newId: () => 'd1');
      final speeds = <double>[
        ...steady(15, 120),
        // Braking from 15 to 5 m/s in 2 s: 5 m/s², hard.
        10, 5,
        ...steady(5, 10),
        // Gentle speed-up: not counted.
        6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        ...steady(15, 120),
        // Slowing down gently.
        13, 11, 9, 7, 5, 3, 1,
        // Stopped at the destination.
        ...steady(0, 150),
      ];
      final samples = road(speeds, screen: {for (var i = 30; i < 100; i++) i});
      expect(tracker.add(samples), isEmpty);
      expect(tracker.active, isTrue);
      // Three minutes without moving: the drive ends.
      final done = tracker.add(
        road(
          steady(0, 1),
          from: samples.last.at.add(const Duration(seconds: 60)),
        ),
      );
      expect(done, hasLength(1));
      final d = done.single;
      expect(d.id, 'd1');
      expect(d.hardBrakes, 1);
      expect(d.rapidStarts, 0);
      expect(d.topSpeedMps, 15);
      expect(d.phoneUseSeconds, 70);
      final meters = speeds.fold<double>(0, (a, b) => a + b);
      expect(d.distanceM, closeTo(meters - 15, 30));
      // Ends when the car last moved, not three minutes later.
      expect(d.end, samples[speeds.length - 152].at);
      expect(tracker.active, isFalse);
    });

    test('a short hop is not a drive', () {
      final tracker = DriveTracker();
      tracker.add(road([...steady(10, 30), ...steady(0, 10)]));
      expect(tracker.tick(t0.add(const Duration(minutes: 10))), isNull);
    });

    test('a drive that went quiet ends on the next wake-up', () {
      final tracker = DriveTracker();
      tracker.add(road(steady(20, 200)));
      expect(tracker.tick(t0.add(const Duration(seconds: 250))), isNull);
      final d = tracker.tick(t0.add(const Duration(minutes: 10)));
      expect(d, isNotNull);
      expect(d!.distanceM, closeTo(4000, 40));
    });

    test('starts where the phone began moving', () {
      final tracker = DriveTracker();
      tracker.hint(
        Fix(lat: 31.99, lng: 34.8, at: t0.subtract(const Duration(minutes: 4))),
      );
      tracker.add(road(steady(20, 200)));
      final d = tracker.tick(t0.add(const Duration(minutes: 10)))!;
      expect(d.start, t0.subtract(const Duration(minutes: 4)));
      expect(d.startLat, 31.99);
      expect(d.distanceM, greaterThan(4000 + 1000));
    });

    test('a jump of bad positions adds no distance', () {
      final tracker = DriveTracker();
      final samples = road(steady(20, 200));
      samples[100] = DriveSample(
        at: samples[100].at,
        speedMps: 20,
        lat: 33.0,
        lng: 34.8,
        accuracyM: 5,
      );
      tracker.add(samples);
      final d = tracker.tick(t0.add(const Duration(minutes: 10)))!;
      expect(d.distanceM, lessThan(4100));
    });

    test('samples from the service are checked', () {
      final s = DriveSample.fromMap({
        't': t0.millisecondsSinceEpoch,
        'sp': 12.5,
        'la': 32.1,
        'lo': 34.9,
        'ac': 4.0,
        'g': 1.2,
        'scr': true,
      })!;
      expect(s.speedMps, 12.5);
      expect(s.hasLocation, isTrue);
      expect(s.peakG, 1.2);
      expect(s.screenOn, isTrue);
      expect(DriveSample.fromMap({'sp': 3}), isNull);
      final bad = DriveSample.fromMap({
        't': 1,
        'sp': -1,
        'la': 200.0,
        'lo': 34.0,
        'g': double.nan,
      })!;
      expect(bad.speedMps, isNull);
      expect(bad.hasLocation, isFalse);
      expect(bad.peakG, 0);
    });

    test('summaries survive the store and keep 30 days', () async {
      final store = InMemoryDriveStore();
      final old = DriveSummary(
        id: 'old',
        start: t0.subtract(const Duration(days: 40)),
        end: t0.subtract(const Duration(days: 40)),
        distanceM: 1,
        topSpeedMps: 1,
      );
      await store.save([StoredDrive(old)]);
      final d = DriveSummary(
        id: 'new',
        start: t0,
        end: t0.add(const Duration(minutes: 20)),
        distanceM: 12345,
        topSpeedMps: 26.4,
        hardBrakes: 2,
        startLat: 32,
        endLng: 34.9,
      );
      await store.add(StoredDrive(d, unsent: ['c']), t0);
      expect(store.drives.map((s) => s.drive.id), ['new']);
      final back = StoredDrive.fromJson(store.drives.single.toJson())!;
      expect(back.unsent, ['c']);
      expect(back.drive.distanceM, 12345);
      expect(back.drive.topSpeedMps, 26.4);
      expect(back.drive.hardBrakes, 2);
      expect(back.drive.startLat, 32);
      expect(back.drive.endLng, 34.9);
    });
  });

  group('crash detector', () {
    test('a hard impact at speed, then stopped: a crash', () {
      final crashes = CrashDetector();
      final samples = road(
        [...steady(20, 10), ...steady(0, 15)],
        jolts: {10: 6.0},
      );
      CrashSignal? found;
      for (final s in samples) {
        found ??= crashes.add([s]);
      }
      expect(found, isNotNull);
      expect(found!.at, samples[10].at);
      expect(found.lat, isNotNull);
    });

    test('a jolt while driving on (pothole, dropped phone) is not', () {
      final crashes = CrashDetector();
      expect(crashes.add(road(steady(20, 60), jolts: {10: 6.0})), isNull);
      expect(crashes.watching, isFalse);
    });

    test('a jolt while slow (phone dropped in a car park) is not', () {
      final crashes = CrashDetector();
      expect(
        crashes.add(road([...steady(2, 10), ...steady(0, 30)], jolts: {10: 8})),
        isNull,
      );
    });

    test('no satellite speed after the impact still counts as stopped', () {
      final crashes = CrashDetector();
      final samples = [
        ...road(steady(25, 10), jolts: {9: 7.0}),
        for (var i = 10; i < 25; i++)
          DriveSample(at: t0.add(Duration(seconds: i))),
      ];
      expect(crashes.add(samples), isNotNull);
    });
  });

  group('engine', () {
    late InMemoryLocationServer server;
    late InMemoryShareStore store;
    late InMemoryDriveStore drives;
    late ShareEngine engine;
    late DateTime now;
    late Map<String, dynamic> devices;

    Future<CirclePackage> package(String id, {bool shareDrives = false}) async {
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: id,
        epoch: 1,
      );
      return CirclePackage(
        spaceId: id,
        epoch: 1,
        boxPublic: await LocationBox.publicKeyOf(box),
        shareDrives: shareDrives,
      );
    }

    setUp(() async {
      now = t0;
      server = InMemoryLocationServer()
        ..members['home'] = {mum, dad}
        ..members['work'] = {mum, teen}
        ..epochs['home'] = 1
        ..epochs['work'] = 1;
      store = InMemoryShareStore(
        ShareState.fresh(mum).copyWith(
          circles: [
            await package('home', shareDrives: true),
            await package('work'),
          ],
          drives: true,
          crashDetection: true,
        ),
      );
      drives = InMemoryDriveStore();
      engine = ShareEngine(
        store: store,
        backend: InMemoryLocationBackend(userId: mum, server: server),
        drives: drives,
        clock: () => now,
      );
      devices = {
        '$mum/${store.state!.deviceId}': (await Signing.fromSeed(
          store.state!.deviceSeed,
        )).publicKeyBytes,
      };
    });

    Future<List<FamilyEvent>> eventsOf(String spaceId) async {
      final rows = await InMemoryLocationBackend(
        userId: spaceId == 'home' ? dad : teen,
        server: server,
      ).events(spaceId, since: DateTime.utc(2000));
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: spaceId,
        epoch: 1,
      );
      return [
        for (final r in rows)
          ?await openEvent(
            r,
            devicePublic: devices['${r.userId}/${r.deviceId}'],
            box: (_) async => box,
          ),
      ];
    }

    test('a drive is kept here and reaches only circles that get it', () async {
      // Driving noticed by the schedule.
      for (var i = 0; i < 3; i++) {
        now = t0.add(Duration(seconds: 45 * i));
        await engine.onFix(
          Fix(lat: 32.0, lng: 34.8 + i * 0.01, at: now, speedMps: 20),
          const DeviceStatus(),
        );
      }
      expect(
        engine.wantsDriveSensors(store.state, now),
        isTrue,
        reason: 'driving with drive summaries on',
      );
      await engine.onDrive(road(steady(20, 300), from: now));
      now = now.add(const Duration(minutes: 15));
      await engine.current();
      expect(drives.drives, hasLength(1));
      expect(drives.drives.single.unsent, isEmpty);
      final home = await eventsOf('home');
      final drive = home.singleWhere((e) => e.kind == FamilyEventKind.drive);
      expect(drive.drive!.distanceM, greaterThan(5000));
      expect(
        (await eventsOf('work')).where((e) => e.kind == FamilyEventKind.drive),
        isEmpty,
      );
    });

    test('a drive that could not be sent goes out later', () async {
      server.offline = true;
      await engine.onDrive(road(steady(20, 300)));
      now = t0.add(const Duration(minutes: 15));
      await engine.current();
      expect(drives.drives.single.unsent, ['home']);
      server.offline = false;
      now = now.add(const Duration(minutes: 1));
      await engine.current();
      expect(drives.drives.single.unsent, isEmpty);
      expect(
        (await eventsOf('home')).where((e) => e.kind == FamilyEventKind.drive),
        hasLength(1),
      );
    });

    test('no sensors while paused or with both features off', () async {
      expect(engine.wantsDriveSensors(store.state, now), isFalse);
      store.state = store.state!.copyWith(pausedOpenEnded: true);
      await engine.onDrive(road(steady(20, 30)));
      expect(engine.wantsDriveSensors(store.state, now), isFalse);
      expect(engine.tracker.active, isFalse);
    });

    test('a crash counts down, then alerts every circle', () async {
      await engine.onDrive(
        road([...steady(20, 10), ...steady(0, 15)], jolts: {10: 6.0}),
      );
      final crash = store.state!.crash!;
      expect(crash.deadline, now.add(ShareEngine.crashCountdown));
      expect(await eventsOf('home'), isEmpty, reason: 'not before the end');

      now = crash.deadline.add(const Duration(seconds: 1));
      await engine.onMotion();
      final state = store.state!;
      expect(state.crash, isNull);
      expect(state.sos!.spaces..sort(), ['home', 'work']);
      expect(state.liveUntil, now.add(ShareEngine.liveAfterAlarm));
      for (final c in ['home', 'work']) {
        final sos = (await eventsOf(c)).single;
        expect(sos.kind, FamilyEventKind.sos);
        expect(sos.crash, isTrue);
        expect(sos.hasLocation, isTrue);
      }

      // "I'm safe" tells both.
      await engine.endSos();
      expect(store.state!.sos, isNull);
      for (final c in ['home', 'work']) {
        expect(
          (await eventsOf(c)).map((e) => e.kind),
          contains(FamilyEventKind.sosEnd),
        );
      }
    });

    test("I'm OK stops the countdown; nobody is told", () async {
      await engine.onDrive(
        road([...steady(20, 10), ...steady(0, 15)], jolts: {10: 6.0}),
      );
      expect(await engine.cancelCrash(), isTrue);
      now = now.add(const Duration(minutes: 5));
      await engine.onMotion();
      expect(store.state!.sos, isNull);
      expect(await eventsOf('home'), isEmpty);
    });

    test('Send SOS now does not wait', () async {
      await engine.onDrive(
        road([...steady(20, 10), ...steady(0, 15)], jolts: {10: 6.0}),
      );
      expect(await engine.crashSosNow(), isTrue);
      expect((await eventsOf('home')).single.crash, isTrue);
    });

    test('crash detection off: a crash is not looked for', () async {
      store.state = store.state!.copyWith(crashDetection: false);
      await engine.onDrive(
        road([...steady(20, 10), ...steady(0, 15)], jolts: {10: 6.0}),
      );
      expect(store.state!.crash, isNull);
    });

    test('drive events never ring on other phones', () async {
      final alerts = AlertEngine(
        store: InMemoryAlertStore(
          AlertState(
            userId: dad,
            circles: {
              'home': AlertCircle(
                spaceId: 'home',
                boxes: {
                  1: await LocationBox.boxSeed(
                    spaceKey: spaceKey(1),
                    spaceId: 'home',
                    epoch: 1,
                  ),
                },
                devices: devices.cast(),
                cursor: DateTime.utc(2000),
              ),
            },
          ),
        ),
        backend: InMemoryLocationBackend(userId: dad, server: server),
        clock: () => now,
      );
      await engine.onDrive(road(steady(20, 300)));
      now = t0.add(const Duration(minutes: 15));
      await engine.current();
      expect(await alerts.check(), isEmpty);
    });
  });

  group('screens', () {
    late FamilyData family;
    setUp(() async {
      family = FamilyData(
        ready: true,
        loading: false,
        circles: [
          circleOf('c1', 'Home', [
            await member(mum, 'Mum', role: SpaceRole.admin),
            await member(dad, 'Dad', seed: 2),
          ]),
        ],
      );
    });

    ShareState sharing({bool drives = false, CrashRun? crash}) =>
        ShareState.fresh(mum).copyWith(
          circles: [
            CirclePackage(spaceId: 'c1', epoch: 1, boxPublic: spaceKey(1)),
          ],
          drives: drives,
          crash: () => crash,
        );

    testWidgets('driving settings and my drives', (tester) async {
      phoneSize(tester);
      final drive = DriveSummary(
        id: 'd1',
        start: DateTime(2026, 11, 22, 8),
        end: DateTime(2026, 11, 22, 8, 25),
        distanceM: 15300,
        topSpeedMps: 25,
        hardBrakes: 2,
        phoneUseSeconds: 180,
      );
      await tester.pumpWidget(
        app(
          const DrivingPage(spaceId: 'c1'),
          family: family,
          share: sharing(),
          drives: [drive],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drives-switch')));
      await tester.pumpAndSettle();
      expect(shareActions.ref.read(shareStoreProvider), isNotNull);
      final store =
          shareActions.ref.read(shareStoreProvider) as InMemoryShareStore;
      expect(store.state!.drives, isTrue);

      // Sharing drives with the circle needs Plus.
      await tester.tap(find.byKey(const Key('share-drives-switch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('needs-plus')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.state!.circles.single.shareDrives, isFalse);

      // Crash detection explains itself first.
      await tester.ensureVisible(find.byKey(const Key('crash-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('crash-switch')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not call emergency services'),
        findsWidgets,
      );
      await tester.tap(find.byKey(const Key('crash-consent')));
      await tester.pumpAndSettle();
      expect(store.state!.crashDetection, isTrue);

      await tester.scrollUntilVisible(find.textContaining('15.3 km'), 200);
      expect(find.textContaining('15.3 km'), findsOneWidget);
      expect(find.textContaining('2 hard brakes'), findsOneWidget);
      expect(find.textContaining('Phone used 3 min'), findsOneWidget);
    });

    testWidgets('with Plus, drives go to the circle', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const DrivingPage(spaceId: 'c1'),
          family: family,
          share: sharing(drives: true),
          plus: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share-drives-switch')));
      await tester.pumpAndSettle();
      final store =
          shareActions.ref.read(shareStoreProvider) as InMemoryShareStore;
      expect(store.state!.circles.single.shareDrives, isTrue);
      await tester.scrollUntilVisible(
        find.textContaining('No drives yet'),
        200,
      );
    });

    testWidgets('a crash countdown shows on the circle with its buttons', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const CirclePage(spaceId: 'c1'),
          family: family,
          share: sharing(
            crash: CrashRun(
              at: DateTime.now(),
              deadline: DateTime.now().add(const Duration(seconds: 60)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final banner = tester.getRect(find.byKey(const Key('crash-banner')));
      final ok = tester.getRect(find.byKey(const Key('crash-ok')));
      final sos = tester.getRect(find.byKey(const Key('crash-sos')));
      expect(ok.width, greaterThan(80));
      expect(sos.width, greaterThan(80));
      expect(ok.center.dy, sos.center.dy);
      expect(banner.contains(ok.center) && banner.contains(sos.center), isTrue);
      await tester.tap(find.byKey(const Key('crash-ok')));
      await tester.pumpAndSettle();
      expect(shareActions.calls, contains('crash ok'));
      expect(find.byKey(const Key('crash-banner')), findsNothing);
    });

    testWidgets('a crash SOS and a drive read clearly in Hebrew', (
      tester,
    ) async {
      late AppL10n l;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              l = context.l;
              return const SizedBox();
            },
          ),
          locale: ZtLanguages.hebrew,
        ),
      );
      await tester.pumpAndSettle();
      final sos = FamilyEvent(
        id: 'x',
        kind: FamilyEventKind.sos,
        at: t0,
        crash: true,
      );
      expect(eventLine(l, 'דנה', null, sos), contains('תאונת דרכים'));
      final drive = FamilyEvent(
        id: 'y',
        kind: FamilyEventKind.drive,
        at: t0,
        drive: DriveSummary(
          id: 'y',
          start: t0,
          end: t0,
          distanceM: 12400,
          topSpeedMps: 25,
        ),
      );
      expect(eventLine(l, 'דנה', null, drive), contains('12.4'));
      expect(eventLine(l, 'דנה', null, drive), contains('90'));
    });
  });
}
