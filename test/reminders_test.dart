import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/location/alerts.dart';
import 'package:zerotrust_family/location/family_event.dart';
import 'package:zerotrust_family/location/geofence.dart';
import 'package:zerotrust_family/location/location_backend.dart';
import 'package:zerotrust_family/location/location_box.dart';
import 'package:zerotrust_family/location/reminders.dart';
import 'package:zerotrust_family/location/schedule.dart';
import 'package:zerotrust_family/location/share_engine.dart';
import 'package:zerotrust_family/location/share_store.dart';
import 'package:zerotrust_family/ui/reminders_page.dart';
import 'package:zt_places/zt_places.dart';

import 'home_page_test.dart' show phoneSize;
import 'location_test.dart' show spaceKey;
import 'support/app.dart';
import 'support/phone.dart';

final t0 = DateTime.utc(2026, 11, 22, 15);

FamilyEvent ev(
  String id,
  FamilyEventKind kind, {
  String? to,
  String? ref,
  bool onLeave = false,
  int minutes = 0,
}) => FamilyEvent(
  id: id,
  kind: kind,
  at: t0.add(Duration(minutes: minutes)),
  to: to,
  ref: ref,
  placeId: 'school',
  onLeave: onLeave,
);

void main() {
  group('open reminders', () {
    test('only its member closes it by going off; only its sender or '
        'member by taking it back', () {
      final open = openReminders([
        (userId: mum, event: ev('r1', FamilyEventKind.remind, to: teen)),
        (userId: mum, event: ev('r2', FamilyEventKind.remind, to: teen)),
        (userId: dad, event: ev('r3', FamilyEventKind.remind, to: teen)),
        (
          userId: mum,
          event: ev('r4', FamilyEventKind.remind, to: dad, minutes: 5),
        ),
        // Went off on the teen's phone.
        (userId: teen, event: ev('d1', FamilyEventKind.remindDone, ref: 'r1')),
        // Someone else can't say it went off...
        (userId: dad, event: ev('d2', FamilyEventKind.remindDone, ref: 'r2')),
        // ...or take back someone else's.
        (userId: mum, event: ev('c3', FamilyEventKind.remindCancel, ref: 'r3')),
        (userId: mum, event: ev('c4', FamilyEventKind.remindCancel, ref: 'r4')),
      ]);
      expect(open.map((r) => r.id), ['r2', 'r3']);
      expect(open.first.from, mum);
      expect(open.first.to, teen);
    });

    test('a reminder survives the store', () {
      const r = PlaceReminder(
        id: 'r',
        from: mum,
        placeId: 'school',
        onLeave: true,
        note: 'call me',
        fromName: 'Mum',
        placeName: 'School',
      );
      final package = CirclePackage(
        spaceId: 'c',
        epoch: 1,
        boxPublic: spaceKey(1),
        reminders: const [r],
      );
      final back = CirclePackage.fromJson(package.toJson());
      expect(back.reminders, [r]);
    });
  });

  group('engine', () {
    late InMemoryLocationServer server;
    late InMemoryShareStore teenStore;
    late ShareEngine teenPhone;
    late ShareEngine mumPhone;
    late Map<String, dynamic> devices;
    final fired = <PlaceReminder>[];
    var now = t0;

    Future<CirclePackage> package() async {
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: 'family',
        epoch: 1,
      );
      return CirclePackage(
        spaceId: 'family',
        epoch: 1,
        boxPublic: await LocationBox.publicKeyOf(box),
        places: const [
          WatchedPlace(id: 'school', lat: 32.0853, lng: 34.7818, radiusM: 150),
        ],
      );
    }

    setUp(() async {
      now = t0;
      fired.clear();
      server = InMemoryLocationServer()
        ..members['family'] = {mum, teen}
        ..epochs['family'] = 1;
      teenStore = InMemoryShareStore(
        ShareState.fresh(teen).copyWith(circles: [await package()]),
      );
      teenPhone = ShareEngine(
        store: teenStore,
        backend: InMemoryLocationBackend(userId: teen, server: server),
        clock: () => now,
      )..onReminder = (_, r) => fired.add(r);
      final mumStore = InMemoryShareStore(
        ShareState.fresh(mum).copyWith(circles: [await package()]),
      );
      mumPhone = ShareEngine(
        store: mumStore,
        backend: InMemoryLocationBackend(userId: mum, server: server),
        clock: () => now,
      );
      devices = {
        for (final s in [teenStore, mumStore])
          '${s.state!.userId}/${s.state!.deviceId}': (await Signing.fromSeed(
            s.state!.deviceSeed,
          )).publicKeyBytes,
      };
    });

    Future<List<({String userId, FamilyEvent event})>> events() async {
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: 'family',
        epoch: 1,
      );
      final rows = await InMemoryLocationBackend(
        userId: mum,
        server: server,
      ).events('family', since: DateTime.utc(2000));
      return [
        for (final r in rows)
          if (await openEvent(
                r,
                devicePublic: devices['${r.userId}/${r.deviceId}'],
                box: (_) async => box,
              )
              case final e?)
            (userId: r.userId, event: e),
      ];
    }

    test('set on one phone, goes off on the other, sender told', () async {
      final id = await mumPhone.remind(
        'family',
        to: teen,
        placeId: 'school',
        note: 'Call me',
      );
      expect(id, isNotNull);
      var open = openReminders(await events());
      expect(open.single.event.note, 'Call me');

      // The teen's phone picks it up (unlocked, or by an alert).
      await teenPhone.updateReminders(
        'family',
        replace: [
          PlaceReminder.fromEvent(
            open.single.from,
            open.single.event,
            fromName: 'Mum',
            placeName: 'School',
          )!,
        ],
      );

      // Away, then at school.
      await teenPhone.onFix(
        Fix(lat: 32.2, lng: 34.9, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(fired, isEmpty);
      now = now.add(const Duration(minutes: 20));
      await teenPhone.onFix(
        Fix(lat: 32.0853, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(fired.single.note, 'Call me');
      expect(fired.single.fromName, 'Mum');
      expect(teenStore.state!.circles.single.reminders, isEmpty);
      final done = (await events()).singleWhere(
        (e) => e.event.kind == FamilyEventKind.remindDone,
      );
      expect(done.event.to, mum);
      expect(done.event.ref, id);
      open = openReminders(await events());
      expect(open, isEmpty);

      // Once only.
      now = now.add(const Duration(minutes: 20));
      await teenPhone.onFix(
        Fix(lat: 32.2, lng: 34.9, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      now = now.add(const Duration(minutes: 20));
      await teenPhone.onFix(
        Fix(lat: 32.0853, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(fired, hasLength(1));
    });

    test('a leaving reminder waits for leaving', () async {
      await teenPhone.updateReminders(
        'family',
        add: const [
          PlaceReminder(id: 'r', from: mum, placeId: 'school', onLeave: true),
        ],
      );
      await teenPhone.onFix(
        Fix(lat: 32.2, lng: 34.9, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      now = now.add(const Duration(minutes: 20));
      await teenPhone.onFix(
        Fix(lat: 32.0853, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(fired, isEmpty);
      now = now.add(const Duration(minutes: 20));
      await teenPhone.onFix(
        Fix(lat: 32.2, lng: 34.9, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(fired.single.id, 'r');
    });

    test('goes off offline; its sender is told once back online, and it '
        'is not armed again meanwhile', () async {
      const r = PlaceReminder(id: 'r', from: mum, placeId: 'school');
      await teenPhone.updateReminders('family', add: const [r]);
      await teenPhone.onFix(
        Fix(lat: 32.2, lng: 34.9, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      server.offline = true;
      now = now.add(const Duration(minutes: 20));
      await teenPhone.onFix(
        Fix(lat: 32.0853, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(fired.single.id, 'r');
      expect(teenStore.state!.circles.single.reminders, isEmpty);
      expect(teenStore.state!.circles.single.fired.single.id, 'r');

      // The app syncs from the circle's events, where it's still open.
      await teenPhone.updateReminders('family', replace: const [r]);
      expect(teenStore.state!.circles.single.reminders, isEmpty);

      server.offline = false;
      now = now.add(const Duration(minutes: 5));
      await teenPhone.onFix(
        Fix(lat: 32.0854, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      final done = (await events()).singleWhere(
        (e) => e.event.kind == FamilyEventKind.remindDone,
      );
      expect(done.event.ref, 'r');
      expect(teenStore.state!.circles.single.fired, isEmpty);
      expect(fired, hasLength(1));

      // The fired list survives the store.
      final package = teenStore.state!.circles.single.copyWith(
        fired: const [r],
      );
      expect(CirclePackage.fromJson(package.toJson()).fired, const [r]);
    });

    test('a cancel seen while locked counts only from its sender or its '
        'member', () async {
      const r = PlaceReminder(id: 'r', from: mum, placeId: 'school');
      await teenPhone.updateReminders('family', add: const [r]);
      await teenPhone.updateReminders(
        'family',
        drop: const ['r'],
        droppedBy: dad,
      );
      expect(teenStore.state!.circles.single.reminders, const [r]);
      await teenPhone.updateReminders(
        'family',
        drop: const ['r'],
        droppedBy: mum,
      );
      expect(teenStore.state!.circles.single.reminders, isEmpty);
      await teenPhone.updateReminders('family', add: const [r]);
      await teenPhone.updateReminders(
        'family',
        drop: const ['r'],
        droppedBy: teen,
      );
      expect(teenStore.state!.circles.single.reminders, isEmpty);
    });

    test('taken back: closed for everyone', () async {
      final id = await mumPhone.remind('family', to: teen, placeId: 'school');
      expect(await mumPhone.cancelReminder('family', id!, to: teen), isTrue);
      expect(openReminders(await events()), isEmpty);
    });

    test('its member can turn it down', () async {
      final id = await mumPhone.remind('family', to: teen, placeId: 'school');
      expect(await teenPhone.cancelReminder('family', id!, to: mum), isTrue);
      expect(openReminders(await events()), isEmpty);
    });

    test('while locked, only its member is alerted about it', () async {
      AlertEngine alertsFor(String user) => AlertEngine(
        store: InMemoryAlertStore(
          AlertState(
            userId: user,
            circles: {
              'family': AlertCircle(
                spaceId: 'family',
                boxes: {1: Uint8List(0)},
                devices: devices.cast(),
                cursor: DateTime.utc(2000),
              ),
            },
          ),
        ),
        backend: InMemoryLocationBackend(userId: user, server: server),
        clock: () => now,
      );
      server.members['family']!.add(dad);
      Future<AlertEngine> withSeed(String user) async {
        final a = alertsFor(user);
        final s = await a.store.load();
        await a.store.save(
          s!.copyWith(
            circles: {
              'family': s.circles['family']!.copyWith(
                boxes: {
                  1: await LocationBox.boxSeed(
                    spaceKey: spaceKey(1),
                    spaceId: 'family',
                    epoch: 1,
                  ),
                },
              ),
            },
          ),
        );
        return a;
      }

      final teenAlerts = await withSeed(teen);
      final dadAlerts = await withSeed(dad);
      await mumPhone.remind('family', to: teen, placeId: 'school');
      final hit = (await teenAlerts.check()).single;
      expect(hit.event.kind, FamilyEventKind.remind);
      expect(hit.silent, isFalse);
      expect(await dadAlerts.check(), isEmpty);
    });
  });

  testWidgets('reminders page: list, who set it, and a new one', (
    tester,
  ) async {
    phoneSize(tester);
    final members = [
      await member(mum, 'Mum', role: SpaceRole.admin),
      await member(teen, 'Noa', seed: 3),
    ];
    await tester.pumpWidget(
      app(
        RemindersPage(spaceId: 'c1', members: members, me: mum),
        places: const [
          ZtPlace(id: 'school', name: 'School', latitude: 32, longitude: 34.8),
        ],
        reminders: [
          OpenReminder(
            from: mum,
            event: ev('r1', FamilyEventKind.remind, to: teen).copyNote('Call'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Call'), findsOneWidget);
    expect(
      find.text('For Noa, when arriving at School · from Mum (you)'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reminder-cancel-r1')));
    await tester.pumpAndSettle();
    expect(reminderActions.calls, contains('cancel c1 r1'));

    await tester.tap(find.byKey(const Key('reminder-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaving'));
    await tester.enterText(find.byKey(const Key('reminder-note')), 'Text me');
    await tester.tap(find.byKey(const Key('reminder-send')));
    await tester.pumpAndSettle();
    expect(
      reminderActions.calls,
      contains('create c1 $teen school leave Text me'),
    );
    expect(find.text('Reminder set'), findsOneWidget);
  });
}

extension on FamilyEvent {
  FamilyEvent copyNote(String note) => FamilyEvent(
    id: id,
    kind: kind,
    at: at,
    to: to,
    placeId: placeId,
    onLeave: onLeave,
    note: note,
  );
}
