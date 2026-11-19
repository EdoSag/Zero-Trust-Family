import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/alerts.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/location/alerts.dart';
import 'package:zerotrust_family/location/family_event.dart';
import 'package:zerotrust_family/location/location_update.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/place_page.dart';
import 'package:zt_places/zt_places.dart';

import 'home_page_test.dart' show phoneSize;
import 'support/app.dart';
import 'support/phone.dart';

void main() {
  late FamilyData family;
  const home = ZtPlace(
    id: 'home',
    name: 'Home',
    latitude: 32.0,
    longitude: 34.8,
  );

  setUp(() async {
    family = FamilyData(
      ready: true,
      loading: false,
      circles: [
        circleOf('c1', 'Sagrons', [
          await member(mum, 'Mum', role: SpaceRole.admin),
          await member(dad, 'Dad', seed: 2),
          await member(teen, 'Noa', seed: 3),
        ]),
      ],
    );
  });

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('places list who is there, under the members', (tester) async {
    phoneSize(tester);
    // The members come first, the places after them.
    await tester.pumpWidget(
      app(
        const CirclePage(spaceId: 'c1'),
        family: family,
        places: const [home],
        locations: {
          dad: MemberLocation(
            userId: dad,
            deviceId: 'd',
            update: LocationUpdate(
              at: DateTime.now(),
              lat: 32.0005,
              lng: 34.8,
              mode: MotionMode.still,
            ),
          ),
        },
        events: [
          CircleEvent(
            userId: dad,
            event: FamilyEvent(
              id: 'e1',
              kind: FamilyEventKind.arrive,
              at: DateTime(2026, 11, 19, 14, 5),
              placeId: 'home',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(Key('member-$teen')));
    final noa = tester.getRect(find.byKey(Key('member-$teen')));
    final placesTop = tester.getRect(find.text('Places')).top;
    expect(placesTop, greaterThanOrEqualTo(noa.bottom));
    await scrollTo(tester, find.byKey(const Key('add-place')));

    final heading = tester.getRect(find.text('Places'));
    final place = tester.getRect(find.byKey(const Key('place-home')));
    final add = tester.getRect(find.byKey(const Key('add-place')));
    expect(place.top, greaterThanOrEqualTo(heading.bottom));
    expect(add.top, greaterThanOrEqualTo(place.bottom));
    expect(find.text('Here now: Dad'), findsOneWidget);

    await scrollTo(tester, find.byKey(const Key('event-e1')));
    expect(find.text('Dad arrived at Home'), findsOneWidget);
    // "Today", then its events under it.
    final today = tester.getRect(find.text('Today'));
    final event = tester.getRect(find.byKey(const Key('event-e1')));
    expect(event.top, greaterThanOrEqualTo(today.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a place: name, where I am, size, save', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const PlacePage(spaceId: 'c1'), family: family),
    );
    await tester.pumpAndSettle();

    // Nothing filled in: both are asked for.
    await tester.tap(find.byKey(const Key('place-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Choose where the place is'), findsOneWidget);
    expect(placeActions.saved, isEmpty);

    await tester.enterText(find.byKey(const Key('place-name')), ' School ');
    await tester.tap(find.byKey(const Key('place-here')));
    await tester.pumpAndSettle();
    expect(find.text('32.08530, 34.78180'), findsOneWidget);
    await tester.tap(find.byKey(const Key('radius-300')));
    await tester.pumpAndSettle();

    // Name, then position, then the button under them, all on screen.
    final name = tester.getRect(find.byKey(const Key('place-name')));
    final where = tester.getRect(find.byKey(const Key('place-position')));
    final here = tester.getRect(find.byKey(const Key('place-here')));
    final save = tester.getRect(find.byKey(const Key('place-save')));
    expect(where.top, greaterThan(name.bottom));
    expect(here.top, greaterThan(where.bottom));
    expect(save.top, greaterThan(here.bottom));
    expect(save.bottom, lessThan(740));

    await tester.tap(find.byKey(const Key('place-save')));
    await tester.pumpAndSettle();
    final (space, place) = placeActions.saved.single;
    expect(space, 'c1');
    expect(place.name, 'School');
    expect(place.latitude, 32.0853);
    expect(place.radiusMeters, 300);
  });

  testWidgets('a pasted map link sets the place; removing asks first', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        const PlacePage(spaceId: 'c1', place: home),
        family: family,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit place'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('place-paste')),
      'https://www.openstreetmap.org/#map=17/31.7683/35.2137',
    );
    await tester.pumpAndSettle();
    expect(find.text('31.76830, 35.21370'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-place')));
    await tester.pumpAndSettle();
    expect(find.text('Remove Home?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-place-confirm')));
    await tester.pumpAndSettle();
    expect(placeActions.removed.single, ('c1', 'home'));
  });

  testWidgets('alerts: opt in, choose who, quiet hours', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const CirclePage(spaceId: 'c1'), family: family),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('alerts-locked')));
    expect(find.byKey(Key('alert-about-$dad')), findsNothing);

    await tester.tap(find.byKey(const Key('alerts-locked')));
    await tester.pumpAndSettle();
    expect(alertStore.state!.circles.keys, ['c1']);
    await scrollTo(tester, find.byKey(const Key('quiet-hours')));

    // Everyone but me, under the switch; quiet hours last.
    final toggle = tester.getRect(find.byKey(const Key('alerts-locked')));
    final aboutDad = tester.getRect(find.byKey(Key('alert-about-$dad')));
    final aboutNoa = tester.getRect(find.byKey(Key('alert-about-$teen')));
    final quiet = tester.getRect(find.byKey(const Key('quiet-hours')));
    expect(find.byKey(Key('alert-about-$mum')), findsNothing);
    expect(aboutDad.top, greaterThan(toggle.bottom));
    expect(aboutNoa.top, greaterThanOrEqualTo(aboutDad.bottom));
    expect(quiet.top, greaterThanOrEqualTo(aboutNoa.bottom));

    await tester.tap(find.byKey(Key('alert-about-$teen')));
    await tester.pumpAndSettle();
    expect(alertStore.state!.circles['c1']!.muted, {teen});

    await tester.tap(find.byKey(const Key('quiet-hours')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiet-night')));
    await tester.pumpAndSettle();
    expect(alertStore.state!.quiet, QuietHours.standard);
    expect(find.text('22:00 to 07:00, alerts without sound'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alerts-locked')));
    await tester.pumpAndSettle();
    expect(alertStore.state!.circles, isEmpty);
  });

  testWidgets('Hebrew: places and alerts are translated', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        const CirclePage(spaceId: 'c1'),
        family: family,
        places: const [home],
        locale: ZtLanguages.hebrew,
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('alerts-locked')));
    expect(find.text('מקומות'), findsOneWidget);
    expect(find.text('התראות בטלפון הזה'), findsOneWidget);
    // Right to left: the place icon is on the right of its name.
    final icon = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('place-home')),
        matching: find.byIcon(Icons.place_outlined),
      ),
    );
    final name = tester.getRect(find.text('Home'));
    expect(icon.left, greaterThan(name.right));
    expect(tester.takeException(), isNull);
  });
}
