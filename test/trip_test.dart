import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/location/location_backend.dart';
import 'package:zerotrust_family/location/location_box.dart';
import 'package:zerotrust_family/location/location_update.dart';
import 'package:zerotrust_family/location/schedule.dart';
import 'package:zerotrust_family/location/share_engine.dart';
import 'package:zerotrust_family/location/share_store.dart';
import 'package:zerotrust_family/location/trip_share.dart';
import 'package:zerotrust_family/ui/trip_page.dart';

import 'home_page_test.dart' show phoneSize;
import 'location_test.dart' show spaceKey;
import 'support/app.dart';
import 'support/phone.dart';

void main() {
  final now = DateTime.utc(2026, 11, 22, 9);

  group('trip link', () {
    test('a link holds a 16-byte id and a 32-byte key after the #', () {
      final trip = TripShare.create(now, name: '  Dana  ');
      expect(trip.link, startsWith('https://zerotrust.bz/trip/#'));
      expect(trip.id, hasLength(22));
      expect(trip.name, 'Dana');
      expect(trip.until, now.add(const Duration(hours: 1)));
      final (id, key) = TripShare.parseLink(trip.link)!;
      expect(id, trip.id);
      expect(key, trip.key);
      expect(TripShare.parseLink('https://zerotrust.bz/trip/'), isNull);
      expect(TripShare.parseLink('https://zerotrust.bz/trip/#abc.def'), isNull);
    });

    test('never longer than 4 hours', () {
      final trip = TripShare.create(now, length: const Duration(hours: 9));
      expect(trip.until, now.add(const Duration(hours: 4)));
    });

    test('sealed updates open with the key, only as this trip', () async {
      final trip = TripShare.create(now, name: 'Dana');
      final update = LocationUpdate(
        at: now,
        lat: 32.0853,
        lng: 34.7818,
        accuracyM: 7.6,
        speedMps: 12.34,
        battery: 80,
      );
      final sealed = await trip.seal(trip.point(update));
      // Nothing readable on the server.
      expect(sealed, isNot(contains('32.08')));
      expect(sealed, isNot(contains('Dana')));
      final open = await trip.open(sealed);
      expect(open['la'], 32.0853);
      expect(open['lo'], 34.7818);
      expect(open['ac'], 8);
      expect(open['sp'], 12.3);
      expect(open['b'], 80);
      expect(open['n'], 'Dana');
      expect(open['un'], trip.until.millisecondsSinceEpoch);
      // Another trip id (associated data) or key can't open it.
      final other = TripShare(
        id: 'A' * 22,
        key: trip.key,
        startedAt: trip.startedAt,
        until: trip.until,
      );
      await expectLater(other.open(sealed), throwsA(anything));
      // The format the trip page reads.
      final json = jsonDecode(sealed) as Map;
      expect(json['v'], 1);
      expect(base64.decode(json['iv'] as String), hasLength(12));
    });

    test('survives the share store', () {
      final trip = TripShare.create(now, name: 'Dana');
      final state = ShareState.fresh(
        mum,
      ).copyWith(trip: () => trip, tripDeletes: ['x']);
      final back = ShareState.fromJson(
        (jsonDecode(jsonEncode(state.toJson())) as Map).cast(),
      );
      expect(back.trip!.link, trip.link);
      expect(back.trip!.until, trip.until);
      expect(back.trip!.name, 'Dana');
      expect(back.tripDeletes, ['x']);
    });
  });

  group('engine', () {
    late InMemoryLocationServer server;
    late InMemoryShareStore store;
    late ShareEngine engine;
    var clock = now;

    setUp(() async {
      clock = now;
      server = InMemoryLocationServer()
        ..members['family'] = {mum, teen}
        ..epochs['family'] = 1
        ..now = () => clock;
      final box = await LocationBox.derive(
        spaceKey: spaceKey(1),
        spaceId: 'family',
        epoch: 1,
      );
      store = InMemoryShareStore(
        ShareState.fresh(teen).copyWith(
          circles: [
            CirclePackage(
              spaceId: 'family',
              epoch: 1,
              boxPublic: await LocationBox.publicKeyOf(box),
            ),
          ],
        ),
      );
      engine = ShareEngine(
        store: store,
        backend: InMemoryLocationBackend(userId: teen, server: server),
        clock: () => clock,
      );
    });

    Future<Map<String, Object?>> seen(TripShare trip) async =>
        trip.open(server.trips[trip.id]!.payload);

    test('starting puts the trip on the server; fixes follow', () async {
      await engine.onFix(
        Fix(lat: 32.1, lng: 34.8, at: now, accuracyM: 5),
        const DeviceStatus(battery: 60),
      );
      final trip = (await engine.startTrip(name: 'Teen'))!;
      expect(store.state!.trip!.id, trip.id);
      expect(server.trips[trip.id]!.owner, teen);
      expect(server.trips[trip.id]!.expiresAt, trip.until);
      var point = await seen(trip);
      expect(point['la'], 32.1);
      expect(point['b'], 60);
      expect(point['n'], 'Teen');

      clock = now.add(const Duration(minutes: 5));
      await engine.onFix(
        Fix(lat: 32.2, lng: 34.9, at: clock, accuracyM: 5),
        const DeviceStatus(battery: 59),
      );
      point = await seen(trip);
      expect(point['la'], 32.2);
    });

    test('stopping takes it off; offline, later', () async {
      final trip = (await engine.startTrip())!;
      expect(server.trips, contains(trip.id));
      server.offline = true;
      await engine.stopTrip();
      expect(store.state!.trip, isNull);
      expect(store.state!.tripDeletes, [trip.id]);
      expect(server.trips, contains(trip.id));
      server.offline = false;
      await engine.retryDeletes();
      expect(server.trips, isEmpty);
      expect(store.state!.tripDeletes, isEmpty);
    });

    test('a new trip ends the old link', () async {
      final first = (await engine.startTrip())!;
      final second = (await engine.startTrip())!;
      expect(server.trips.keys, [second.id]);
      expect(first.id, isNot(second.id));
    });

    test('ends by itself when its time is up', () async {
      final trip = (await engine.startTrip())!;
      clock = now.add(const Duration(hours: 1, minutes: 1));
      await engine.onFix(
        Fix(lat: 32.2, lng: 34.9, at: clock, accuracyM: 5),
        const DeviceStatus(),
      );
      expect(store.state!.trip, isNull);
      expect(server.trips, isNot(contains(trip.id)));
    });

    test('paused: the link says so and shows no position', () async {
      await engine.onFix(
        Fix(lat: 32.1, lng: 34.8, at: now, accuracyM: 5),
        const DeviceStatus(),
      );
      final trip = (await engine.startTrip())!;
      await store.save(store.state!.copyWith(pausedOpenEnded: true));
      await engine.sendNow();
      final point = await seen(trip);
      expect(point['pz'], isTrue);
      expect(point.containsKey('la'), isFalse);
    });

    test('needs sharing on; stopping the last circle ends it', () async {
      final trip = (await engine.startTrip())!;
      expect(await engine.stopCircle('family'), 0);
      expect(store.state!.trip, isNull);
      expect(server.trips, isNot(contains(trip.id)));
      expect(await engine.startTrip(), isNull);
    });
  });

  group('page', () {
    testWidgets('start, then the link with send, copy and stop', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const TripPage(name: 'Mum'),
          share: ShareState.fresh(mum).copyWith(
            circles: [
              CirclePackage(spaceId: 'c1', epoch: 1, boxPublic: spaceKey(1)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share my trip'), findsOneWidget);
      expect(find.byKey(const Key('trip-needs-sharing')), findsNothing);
      await tester.tap(find.text('2 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-start')));
      await tester.pumpAndSettle();
      expect(shareActions.calls, contains('trip 2'));
      expect(find.byKey(const Key('trip-active')), findsOneWidget);
      expect(find.textContaining('zerotrust.bz/trip/#'), findsOneWidget);

      // Send and copy side by side, both visible, under the card.
      final card = tester.getRect(find.byKey(const Key('trip-active')));
      final send = tester.getRect(find.byKey(const Key('trip-send')));
      final copy = tester.getRect(find.byKey(const Key('trip-copy')));
      expect(send.top, greaterThan(card.bottom));
      expect(send.center.dy, closeTo(copy.center.dy, 1));
      expect(send.width, greaterThan(100));
      expect(copy.width, greaterThan(100));
      expect(copy.left, greaterThan(send.right));

      await tester.tap(find.byKey(const Key('trip-stop')));
      await tester.pumpAndSettle();
      expect(shareActions.calls, contains('stop trip'));
      expect(find.byKey(const Key('trip-start')), findsOneWidget);
    });

    testWidgets('without sharing on, says so and cannot start', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(app(const TripPage(), share: null));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip-needs-sharing')), findsOneWidget);
      final start = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('trip-start')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets('Hebrew', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const TripPage(),
          locale: ZtLanguages.hebrew,
          share: ShareState.fresh(mum).copyWith(
            circles: [
              CirclePackage(spaceId: 'c1', epoch: 1, boxPublic: spaceKey(1)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('שיתוף המסלול שלי'), findsOneWidget);
      expect(find.text('התחלת שיתוף'), findsOneWidget);
    });
  });
}
