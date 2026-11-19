import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/location/family_event.dart';
import 'package:zerotrust_family/location/geofence.dart';
import 'package:zerotrust_family/location/timeline.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/history_page.dart';
import 'package:zt_places/zt_places.dart';

import 'home_page_test.dart' show phoneSize;
import 'support/app.dart';
import 'support/phone.dart';

FamilyEvent point(DateTime at, double lat, {double lng = 34.8}) => FamilyEvent(
  id: 'p${at.millisecondsSinceEpoch}',
  kind: FamilyEventKind.point,
  at: at,
  lat: lat,
  lng: lng,
);

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  group('timeline', () {
    final t0 = DateTime.utc(2026, 11, 19, 7);
    DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
    const home = WatchedPlace(id: 'home', lat: 32.0, lng: 34.8, radiusM: 150);

    test('home, a drive, school; newest first', () {
      final events = [
        point(at(0), 32.0),
        point(at(15), 32.0001),
        point(at(30), 32.0),
        // On the way: two quick points 1+ km apart.
        point(at(33), 32.01),
        point(at(36), 32.02),
        // School, still there.
        point(at(40), 32.03),
        point(at(55), 32.0301),
        FamilyEvent(
          id: 'c',
          kind: FamilyEventKind.checkin,
          at: at(41),
          note: 'At school',
        ),
      ];
      final list = buildTimeline(events, places: const [home]);
      // The check-in came a minute after getting to school.
      expect(list.map((e) => e.runtimeType), [Moment, Stop, Move, Stop]);
      final school = list[1] as Stop;
      expect(school.ongoing, isTrue);
      expect(school.start, at(40));
      expect(school.placeId, isNull);
      final drive = list[2] as Move;
      expect(drive.start, at(30));
      expect(drive.end, at(40));
      expect(drive.meters, closeTo(3336, 30));
      final stay = list[3] as Stop;
      expect(stay.placeId, 'home');
      expect(stay.length, const Duration(minutes: 30));
      expect(stay.ongoing, isFalse);
    });

    test('a few minutes somewhere is not a stop', () {
      final list = buildTimeline([
        point(at(0), 32.0),
        point(at(20), 32.0),
        point(at(23), 32.05),
        point(at(26), 32.1),
        point(at(46), 32.1),
      ]);
      expect(list.map((e) => e.runtimeType), [Stop, Move, Stop]);
    });

    test('nothing sent: nothing shown', () {
      expect(buildTimeline(const []), isEmpty);
    });
  });

  group('screens', () {
    late FamilyData family;
    setUp(() async {
      family = FamilyData(
        ready: true,
        loading: false,
        circles: [
          circleOf('c1', 'Sagrons', [
            await member(mum, 'Mum', role: SpaceRole.admin),
            await member(dad, 'Dad', seed: 2),
          ]),
        ],
      );
    });

    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    DateTime atToday(int h, [int m = 0]) =>
        DateTime(midnight.year, midnight.month, midnight.day, h, m);

    testWidgets('a member\'s day: stops, the drive and a check-in', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const HistoryPage(spaceId: 'c1', userId: dad, name: 'Dad'),
          family: family,
          places: const [
            ZtPlace(id: 'home', name: 'Home', latitude: 32, longitude: 34.8),
          ],
          history: {
            midnight: [
              Stop(
                start: atToday(8, 10),
                end: atToday(8, 40),
                lat: 32.03,
                lng: 34.8,
                ongoing: true,
              ),
              Moment(
                FamilyEvent(
                  id: 'c',
                  kind: FamilyEventKind.checkin,
                  at: atToday(8, 11),
                  note: 'At school',
                ),
              ),
              Move(start: atToday(7, 50), end: atToday(8, 10), meters: 3240),
              Stop(
                start: atToday(6),
                end: atToday(7, 50),
                lat: 32,
                lng: 34.8,
                placeId: 'home',
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dad: history'), findsOneWidget);
      expect(find.text('Since 08:10'), findsOneWidget);
      expect(find.text('On the move: 3.2 km, 20 min'), findsOneWidget);
      expect(find.text('At Home'), findsOneWidget);
      expect(find.text('06:00 to 07:50, 1 h 50 min'), findsOneWidget);
      // Newest at the top, in order, under the day chips.
      final chips = tester.getRect(find.byKey(const Key('history-days')));
      final rows = [
        for (var i = 0; i < 4; i++)
          tester.getRect(find.byKey(Key('history-$i'))),
      ];
      expect(rows.first.top, greaterThanOrEqualTo(chips.bottom));
      for (var i = 1; i < 4; i++) {
        expect(rows[i].top, greaterThanOrEqualTo(rows[i - 1].bottom));
      }

      // Yesterday: nothing.
      await tapKey(tester, const Key('history-day-1'));
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(yesterday.isBefore(midnight), isTrue);
      // Seven days of chips by default.
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-day-6')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('history-days')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const Key('history-day-6')), findsOneWidget);
      expect(find.byKey(const Key('history-day-7')), findsNothing);
    });

    Future<void> openCircle(
      WidgetTester tester, {
      bool plus = false,
      String me = mum,
      Locale locale = ZtLanguages.english,
      List<ZtPlace> places = const [],
    }) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const CirclePage(spaceId: 'c1'),
          family: family,
          plus: plus,
          me: me,
          locale: locale,
          places: places,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('erase-history')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a member opens their history', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(const CirclePage(spaceId: 'c1'), family: family),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(Key('member-$dad')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, Key('member-$dad'));
      expect(find.byType(HistoryPage), findsOneWidget);
      expect(find.text('Dad: history'), findsOneWidget);
    });

    testWidgets('free owner: 30 days asks for Plus, 3 days saves', (
      tester,
    ) async {
      await openCircle(tester);
      final keep = tester.getRect(find.byKey(const Key('history-keep')));
      final erase = tester.getRect(find.byKey(const Key('erase-history')));
      expect(erase.top, greaterThanOrEqualTo(keep.bottom));
      expect(find.textContaining('7 days'), findsOneWidget);

      await tapKey(tester, const Key('history-keep'));
      // Plus marks the longer choices, in order.
      final seven = tester.getRect(find.byKey(const Key('history-keep-7')));
      final thirty = tester.getRect(find.byKey(const Key('history-keep-30')));
      expect(thirty.top, greaterThan(seven.bottom));
      expect(find.text('Plus'), findsNWidgets(2));
      await tapKey(tester, const Key('history-keep-30'));
      expect(find.byKey(const Key('needs-plus')), findsOneWidget);
      expect(locationServer.historyDays, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tapKey(tester, const Key('history-keep'));
      await tapKey(tester, const Key('history-keep-3'));
      expect(locationServer.historyDays['c1'], 3);
      expect(find.textContaining('3 days'), findsOneWidget);
    });

    testWidgets('Plus owner keeps 30 days', (tester) async {
      await openCircle(tester, plus: true);
      locationServer.plus.add(mum);
      await tapKey(tester, const Key('history-keep'));
      expect(find.text('Plus'), findsNothing);
      await tapKey(tester, const Key('history-keep-30'));
      expect(locationServer.historyDays['c1'], 30);
    });

    testWidgets('members see the window but can\'t change it; can erase', (
      tester,
    ) async {
      family = FamilyData(
        ready: true,
        loading: false,
        circles: [
          circleOf('c1', 'Sagrons', [
            await member(mum, 'Mum', role: SpaceRole.admin),
            await member(dad, 'Dad', seed: 2),
          ], isAdmin: false),
        ],
      );
      await openCircle(tester, me: dad);
      expect(
        find.textContaining("Only the circle's owner can change this."),
        findsOneWidget,
      );
      await tapKey(tester, const Key('history-keep'));
      expect(find.byKey(const Key('history-keep-3')), findsNothing);

      await tapKey(tester, const Key('erase-history'));
      await tapKey(tester, const Key('erase-history-confirm'));
      expect(
        find.text('Your history in this circle was erased'),
        findsOneWidget,
      );
    });

    testWidgets('a sixth place needs Plus', (tester) async {
      final five = [
        for (var i = 0; i < 5; i++)
          ZtPlace(id: 'p$i', name: 'Place $i', latitude: 32, longitude: 34.8),
      ];
      await openCircle(tester, places: five);
      await tester.scrollUntilVisible(
        find.byKey(const Key('add-place')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, const Key('add-place'));
      expect(find.byKey(const Key('needs-plus')), findsOneWidget);
      expect(find.textContaining('More than 5 places'), findsOneWidget);
    });

    testWidgets('Hebrew: history settings translated', (tester) async {
      await openCircle(tester, locale: ZtLanguages.hebrew);
      expect(find.text('היסטוריה'), findsOneWidget);
      expect(find.text('למחוק את ההיסטוריה שלי במעגל'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
