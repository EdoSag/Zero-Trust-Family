import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/app/family_config.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/model/family_hub.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/hub_page.dart';

import 'home_page_test.dart' show phoneSize;
import 'support/app.dart';
import 'support/phone.dart';

LocalItem item(
  String id,
  String title,
  String kind, {
  DateTime? at,
  DateTime? due,
  bool? done,
  String? list,
  bool deleted = false,
}) => LocalItem(
  itemId: id,
  updatedAt: DateTime.utc(2026),
  deleted: deleted,
  json: deleted
      ? null
      : ZtFamilySummary(
          title: title,
          kind: kind,
          at: at,
          due: due,
          done: done,
          list: list,
        ).addTo({'kind': kind, 'private': 'app fields'}),
);

void main() {
  // Local times, as the phone shows them.
  final now = DateTime(2026, 11, 23, 9);
  final today = DateTime(2026, 11, 23);

  FamilyHub sample() => FamilyHub.of([
    // ZT Family's own items are not the hub's.
    LocalItem(
      itemId: 'family.circle',
      updatedAt: _epoch,
      json: const {'name': 'Sagrons', 'kind': 'family.circle'},
    ),
    item(
      'calendar/event/dinner',
      'Dinner at Grandma',
      'calendar.event',
      at: today.add(const Duration(hours: 19)),
    ),
    item(
      'calendar/event/dentist',
      'Dentist',
      'calendar.event',
      at: today.add(const Duration(days: 2, hours: 10)),
    ),
    item(
      'calendar/event/past',
      'Yesterday',
      'calendar.event',
      at: today.subtract(const Duration(hours: 3)),
    ),
    item(
      'calendar/event/far',
      'Far away',
      'calendar.event',
      at: today.add(const Duration(days: 20)),
    ),
    item('calendar/event/gone', 'Deleted', 'calendar.event', deleted: true),
    item('tasks/list/shop', 'Shopping', 'tasks.list'),
    item('tasks/list/chores', 'Chores', 'tasks.list'),
    item(
      'tasks/item/milk',
      'Milk',
      'tasks.item',
      list: 'tasks/list/shop',
      done: false,
    ),
    item(
      'tasks/item/bread',
      'Bread',
      'tasks.item',
      list: 'tasks/list/shop',
      done: true,
    ),
    item(
      'tasks/item/bins',
      'Take out the bins',
      'tasks.item',
      list: 'tasks/list/chores',
      done: true,
    ),
    item(
      'tasks/item/loose',
      'Call the plumber',
      'tasks.item',
      due: today.add(const Duration(days: 1, hours: 12)),
    ),
    item(
      'meds/dose/evening',
      'Vitamin D',
      'meds.dose',
      at: today.add(const Duration(hours: 20)),
      done: false,
    ),
    item(
      'meds/dose/morning',
      'Ritalin 10 mg',
      'meds.dose',
      at: today.add(const Duration(hours: 8)),
      done: true,
    ),
    item(
      'meds/dose/tomorrow',
      'Tomorrow',
      'meds.dose',
      at: today.add(const Duration(days: 1, hours: 8)),
    ),
    item('notes/note/x', 'Wifi password', 'notes.note'),
    // No summary: left out.
    LocalItem(
      itemId: 'tasks/item/bare',
      updatedAt: _epoch,
      json: const {'kind': 'tasks.item'},
    ),
  ], now);

  group('hub', () {
    test('sorts the circle\'s items into calendar, lists, meds', () {
      final hub = sample();
      expect(hub.comingUp.map((i) => i.title), [
        'Dinner at Grandma',
        'Dentist',
      ]);
      expect(hub.lists.map((l) => l.title), ['Shopping', null, 'Chores']);
      final shop = hub.lists.first;
      expect(shop.open.map((i) => i.title), ['Milk']);
      expect(shop.doneCount, 1);
      expect(hub.lists[1].open.single.title, 'Call the plumber');
      expect(hub.lists[2].open, isEmpty);
      expect(hub.lists[2].doneCount, 1);
      expect(hub.medsToday.map((i) => i.title), ['Ritalin 10 mg', 'Vitamin D']);
      expect(hub.medsToday.first.done, isTrue);
      expect(hub.other.single.title, 'Wifi password');
      expect(hub.isEmpty, isFalse);
    });

    test('a circle with only its own items is empty', () {
      expect(
        FamilyHub.of([
          LocalItem(itemId: 'family.place/home', updatedAt: _epoch),
        ], now).isEmpty,
        isTrue,
      );
    });

    test('Family checks the circle with the suite\'s one policy', () {
      expect(identical(familySpacePolicy, ZtFamilySpace.policy), isTrue);
      expect(familySpacePolicy.adminOnlyKinds, {'family.circle'});
      expect(familySpacePolicy.ownedPrefixes, {'family.me/'});
    });
  });

  group('page', () {
    testWidgets('sections in order, lists as cards', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(app(const HubPage(spaceId: 'c1'), hub: sample()));
      await tester.pumpAndSettle();
      expect(find.text('Family hub'), findsOneWidget);
      final comingUp = tester.getRect(find.byKey(const Key('hub-coming-up')));
      final dinner = tester.getRect(
        find.byKey(const Key('hub-item-calendar/event/dinner')),
      );
      final lists = tester.getRect(find.byKey(const Key('hub-lists')));
      expect(dinner.top, greaterThanOrEqualTo(comingUp.bottom));
      expect(lists.top, greaterThan(dinner.bottom));
      final shop = tester.getRect(
        find.byKey(const Key('hub-list-tasks/list/shop')),
      );
      expect(shop.top, greaterThanOrEqualTo(lists.bottom));
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);
      expect(find.text('1 done'), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(const Key('hub-other')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final meds = tester.getRect(find.byKey(const Key('hub-meds')));
      final other = tester.getRect(find.byKey(const Key('hub-other')));
      expect(other.top, greaterThan(meds.bottom));
      expect(find.textContaining('Taken'), findsOneWidget);
    });

    testWidgets('empty: says where items come from', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(app(const HubPage(spaceId: 'c1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hub-empty')), findsOneWidget);
      expect(find.textContaining('ZT Calendar'), findsOneWidget);
    });

    testWidgets('Hebrew', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const HubPage(spaceId: 'c1'),
          hub: sample(),
          locale: ZtLanguages.hebrew,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('מרכז המשפחה'), findsOneWidget);
      expect(find.text('בקרוב'), findsOneWidget);
      expect(find.text('רשימות'), findsOneWidget);
    });

    testWidgets('the circle page opens it', (tester) async {
      phoneSize(tester);
      final family = FamilyData(
        ready: true,
        loading: false,
        circles: [
          circleOf('c1', 'Sagrons', [
            await member(mum, 'Mum', role: SpaceRole.admin),
          ]),
        ],
      );
      await tester.pumpWidget(
        app(
          const CirclePage(spaceId: 'c1'),
          family: family,
          hub: sample(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('hub')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('hub')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hub-coming-up')), findsOneWidget);
    });
  });
}

final _epoch = DateTime.utc(2026);
