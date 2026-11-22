import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/l10n/l10n.dart';
import 'package:zerotrust_family/location/alerts.dart';
import 'package:zerotrust_family/location/approximate.dart';
import 'package:zerotrust_family/location/family_event.dart';
import 'package:zerotrust_family/location/geofence.dart';
import 'package:zerotrust_family/location/location_backend.dart';
import 'package:zerotrust_family/location/location_box.dart';
import 'package:zerotrust_family/location/location_update.dart';
import 'package:zerotrust_family/location/schedule.dart';
import 'package:zerotrust_family/location/share_engine.dart';
import 'package:zerotrust_family/location/share_store.dart';
import 'package:zerotrust_family/ui/share_card.dart';

import 'home_page_test.dart' show phoneSize;
import 'location_test.dart' show spaceKey;
import 'support/app.dart';
import 'support/phone.dart';

void main() {
  group('snapping', () {
    test('nearby spots share one cell centre; far ones do not', () {
      final a = Approximate.snap(32.0853, 34.7818);
      final b = Approximate.snap(32.0855, 34.7820);
      expect(a, b);
      final far = Approximate.snap(32.12, 34.7818);
      expect(far, isNot(a));
      // The centre is within a cell of the real spot, never on it.
      expect(haversine(32.0853, 34.7818, a.$1, a.$2), lessThan(3000));
      expect(a.$1, isNot(32.0853));
    });

    test('cells stay about 3 km wide away from the equator', () {
      for (final lat in [0.5, 32.0, 60.0]) {
        final here = Approximate.snap(lat, 10.0);
        // Walk east until the cell changes.
        var lng = 10.0;
        while (Approximate.snap(lat, lng) == here) {
          lng += 0.001;
        }
        final next = Approximate.snap(lat, lng);
        final width = haversine(here.$1, here.$2, next.$1, next.$2);
        expect(width, inInclusiveRange(2500, 3500), reason: 'at $lat');
      }
    });

    test('works at the date line and poles', () {
      final (la, lo) = Approximate.snap(89.99, 179.999);
      expect(la.abs(), lessThanOrEqualTo(90));
      expect(lo.abs(), lessThanOrEqualTo(180));
      final (la2, lo2) = Approximate.snap(-33.9, -179.999);
      expect(la2, closeTo(-33.9, 0.03));
      expect(lo2.abs(), lessThanOrEqualTo(180));
    });

    test('an SOS keeps the exact spot; a check-in does not', () {
      final at = DateTime.utc(2026);
      final sos = FamilyEvent(
        id: 's',
        kind: FamilyEventKind.sos,
        at: at,
        lat: 32.0853,
        lng: 34.7818,
      );
      expect(Approximate.event(sos).lat, 32.0853);
      final checkin = Approximate.event(
        FamilyEvent(
          id: 'c',
          kind: FamilyEventKind.checkin,
          at: at,
          lat: 32.0853,
          lng: 34.7818,
          accuracyM: 5,
        ),
      );
      expect(checkin.lat, isNot(32.0853));
      expect(checkin.accuracyM, Approximate.radiusM);
      expect(checkin.approximate, isTrue);
    });
  });

  group('engine', () {
    late InMemoryLocationServer server;
    late InMemoryShareStore store;
    late ShareEngine engine;
    late Map<String, dynamic> devices;
    final now = DateTime.utc(2026, 11, 22, 9);

    Future<CirclePackage> package(String id, {bool approximate = false}) async {
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: id,
        epoch: 1,
      );
      return CirclePackage(
        spaceId: id,
        epoch: 1,
        boxPublic: await LocationBox.publicKeyOf(box),
        approximate: approximate,
        places: [
          WatchedPlace(id: 'school', lat: 32.0853, lng: 34.7818, radiusM: 150),
        ],
      );
    }

    setUp(() async {
      server = InMemoryLocationServer()
        ..members['family'] = {mum, teen}
        ..members['friends'] = {teen, dad}
        ..epochs['family'] = 1
        ..epochs['friends'] = 1;
      store = InMemoryShareStore(
        ShareState.fresh(teen).copyWith(
          circles: [
            await package('family'),
            await package('friends', approximate: true),
          ],
        ),
      );
      engine = ShareEngine(
        store: store,
        backend: InMemoryLocationBackend(userId: teen, server: server),
        clock: () => now,
      );
      devices = {
        '$teen/${store.state!.deviceId}': (await Signing.fromSeed(
          store.state!.deviceSeed,
        )).publicKeyBytes,
      };
    });

    Future<LocationUpdate> seenIn(String spaceId) async {
      final seen = await openCircleLocations(
        spaceId: spaceId,
        rows: await InMemoryLocationBackend(
          userId: spaceId == 'family' ? mum : dad,
          server: server,
        ).latest(spaceId),
        devices: devices.cast(),
        spaceKey: spaceKey,
      );
      return seen[teen]!.update;
    }

    Future<List<FamilyEvent>> eventsIn(String spaceId) async {
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: spaceId,
        epoch: 1,
      );
      return [
        for (final r in await InMemoryLocationBackend(
          userId: spaceId == 'family' ? mum : dad,
          server: server,
        ).events(spaceId, since: DateTime.utc(2000)))
          ?await openEvent(
            r,
            devicePublic: devices['${r.userId}/${r.deviceId}'],
            box: (_) async => box,
          ),
      ];
    }

    test('one circle gets the exact spot, the other only the area', () async {
      // Away from school first, so arriving there is a crossing.
      await engine.onFix(
        Fix(lat: 32.2, lng: 34.9, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      await engine.onFix(
        Fix(
          lat: 32.0853,
          lng: 34.7818,
          at: now.add(const Duration(minutes: 5)),
          accuracyM: 8,
          speedMps: 1.2,
          heading: 90,
        ),
        const DeviceStatus(battery: 50),
      );
      final family = await seenIn('family');
      expect(family.lat, 32.0853);
      expect(family.approximate, isFalse);
      final friends = await seenIn('friends');
      expect(friends.approximate, isTrue);
      expect((friends.lat, friends.lng), Approximate.snap(32.0853, 34.7818));
      expect(friends.accuracyM, Approximate.radiusM);
      expect(friends.speedMps, isNull);
      expect(friends.heading, isNull);
      expect(friends.battery, 50);

      // Arrivals and history points: the area only.
      for (final e in await eventsIn('friends')) {
        if (!e.hasLocation) continue;
        expect(e.approximate, isTrue);
        expect([
          Approximate.snap(32.0853, 34.7818),
          Approximate.snap(32.2, 34.9),
        ], contains((e.lat, e.lng)));
      }
      final arrive = (await eventsIn(
        'friends',
      )).firstWhere((e) => e.kind == FamilyEventKind.arrive);
      expect(arrive.placeId, 'school');
      expect(
        (await eventsIn(
          'family',
        )).firstWhere((e) => e.kind == FamilyEventKind.arrive).lat,
        32.0853,
      );
    });

    test('during an SOS every circle gets the exact spot', () async {
      await engine.onFix(
        Fix(lat: 32.0853, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      expect(await engine.startSos('family'), isTrue);
      await engine.onFix(
        Fix(lat: 32.0901, lng: 34.7801, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      final friends = await seenIn('friends');
      expect(friends.lat, 32.0901);
      expect(friends.approximate, isFalse);
    });

    test('an approximate member never rings with an exact place', () async {
      final alerts = AlertEngine(
        store: InMemoryAlertStore(
          AlertState(
            userId: dad,
            circles: {
              'friends': AlertCircle(
                spaceId: 'friends',
                boxes: {
                  1: await LocationBox.boxSeed(
                    spaceKey: spaceKey(1),
                    spaceId: 'friends',
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
      await engine.onFix(
        Fix(lat: 32.0853, lng: 34.7818, at: now, accuracyM: 8),
        const DeviceStatus(),
      );
      await engine.checkIn('friends');
      final checkin = (await alerts.check()).firstWhere(
        (h) => h.event.kind == FamilyEventKind.checkin,
      );
      expect(checkin.event.lat, isNot(32.0853));
    });
  });

  testWidgets('the switch is on the share card and says what it does', (
    tester,
  ) async {
    phoneSize(tester);
    final family = FamilyData(
      ready: true,
      loading: false,
      circles: [
        circleOf('c1', 'Friends', [
          await member(mum, 'Mum', role: SpaceRole.admin),
        ]),
      ],
    );
    await tester.pumpWidget(
      app(
        const Scaffold(body: ShareCard(spaceId: 'c1')),
        family: family,
        share: ShareState.fresh(mum).copyWith(
          circles: [
            CirclePackage(spaceId: 'c1', epoch: 1, boxPublic: spaceKey(1)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byKey(const Key('share-card')));
    final toggle = tester.getRect(find.byKey(const Key('share-approximate')));
    final off = tester.getRect(find.byKey(const Key('share-off')));
    expect(toggle.top, greaterThanOrEqualTo(off.bottom));
    expect(toggle.bottom, lessThanOrEqualTo(card.bottom));
    expect(find.textContaining('about 3 km'), findsOneWidget);
    await tester.tap(find.byKey(const Key('share-approximate')));
    await tester.pumpAndSettle();
    expect(shareActions.calls, contains('approximate c1 true'));
  });

  test('the member list says a position is approximate', () {
    // Through the summary line the circle shows under each member.
    final now = DateTime.now();
    final l = lookupAppL10n(const Locale('en'));
    final line = locationSummary(
      l,
      MemberLocation(
        userId: dad,
        deviceId: 'd',
        update: LocationUpdate(at: now, lat: 32, lng: 34, approximate: true),
      ),
      now,
    );
    expect(line, contains('Approximate'));
  });
}
