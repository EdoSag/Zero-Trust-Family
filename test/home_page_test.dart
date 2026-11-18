import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/home_page.dart';

import 'support/app.dart';
import 'support/phone.dart';

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first run explains circles, with both ways in below', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('Start your family circle'));
    final create = tester.getRect(find.byKey(const Key('create-circle')));
    final join = tester.getRect(find.byKey(const Key('join-circle')));
    // Explanation, then Create, then Join, each under the other and all
    // on screen without scrolling.
    expect(create.top, greaterThan(title.bottom));
    expect(join.top, greaterThan(create.bottom));
    expect(join.bottom, lessThan(740));
    // Full-width buttons, same width.
    expect(create.width, join.width);
    expect(create.width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a circle asks for its name, then yours', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-circle')));
    await tester.pumpAndSettle();
    expect(find.text('New circle'), findsOneWidget);
    // An empty name is refused.
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(actions.created, isEmpty);

    await tester.enterText(find.byType(TextFormField), '  The  Sagrons ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Your name in the circle'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Mum');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(actions.created.single, ('The Sagrons', 'Mum'));
  });

  testWidgets('circles list by name with their members; waiting ones first', (
    tester,
  ) async {
    phoneSize(tester);
    final family = FamilyData(
      ready: true,
      loading: false,
      pending: const [PendingCircle('p1')],
      circles: [
        circleOf('c1', 'Home', [
          await member(mum, 'Mum', role: SpaceRole.admin),
          await member(dad, 'Dad', seed: 2),
          await member(teen, 'Noa', seed: 3),
        ]),
        circleOf('c2', null, [await member(mum, 'Mum', seed: 1)]),
      ],
    );
    await tester.pumpWidget(app(const HomePage(), family: family));
    await tester.pumpAndSettle();

    expect(find.text('Start your family circle'), findsNothing);
    final waiting = tester.getRect(find.text('Waiting to be let in'));
    final home = tester.getRect(find.text('Home'));
    final count = tester.getRect(find.text('3 members'));
    // A circle whose name hasn't synced yet still shows.
    final unnamed = tester.getRect(find.text('Family circle'));
    expect(find.text('1 member'), findsOneWidget);
    expect(home.top, greaterThan(waiting.bottom));
    expect(count.top, greaterThanOrEqualTo(home.bottom));
    expect(unnamed.top, greaterThan(count.bottom));
    // The buttons stay under the last circle.
    final create = tester.getRect(find.byKey(const Key('create-circle')));
    expect(create.top, greaterThan(unnamed.bottom));

    await tester.tap(find.byTooltip('Stop waiting'));
    await tester.pump();
    expect(actions.forgotten, ['p1']);
  });

  testWidgets('a circle shows its members, owner first, and marks you', (
    tester,
  ) async {
    phoneSize(tester);
    final family = FamilyData(
      ready: true,
      loading: false,
      circles: [
        circleOf('c1', 'Home', [
          await member(dad, 'Dad', seed: 2),
          await member(mum, 'Mum', role: SpaceRole.admin),
        ]),
      ],
    );
    await tester.pumpWidget(
      app(const CirclePage(spaceId: 'c1'), family: family),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    final soon = tester.getRect(find.text('Location sharing comes next'));
    final mumRow = tester.getRect(find.text('Mum (you)'));
    final dadRow = tester.getRect(find.text('Dad'));
    final manage = tester.getRect(find.text('Members and invites'));
    final invite = tester.getRect(find.byKey(const Key('invite')));
    expect(mumRow.top, greaterThan(soon.bottom));
    expect(dadRow.top, greaterThan(mumRow.bottom));
    expect(manage.top, greaterThan(dadRow.bottom));
    expect(invite.top, greaterThan(manage.bottom));
    expect(invite.bottom, lessThan(740));
    // "Owner" sits under Mum's name, not Dad's.
    final owner = tester.getRect(find.text('Owner'));
    expect(owner.top, greaterThanOrEqualTo(mumRow.bottom));
    expect(owner.bottom, lessThanOrEqualTo(dadRow.top));

    await tester.tap(find.byTooltip('Rename circle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Our home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(actions.renamed.single, ('c1', 'Our home'));
  });

  testWidgets('a member who is not an owner cannot rename or invite', (
    tester,
  ) async {
    phoneSize(tester);
    final family = FamilyData(
      ready: true,
      loading: false,
      circles: [
        circleOf('c1', 'Home', [
          await member(dad, 'Dad', seed: 2),
          await member(mum, 'Mum', role: SpaceRole.admin),
        ], isAdmin: false),
      ],
    );
    await tester.pumpWidget(
      app(
        const CirclePage(spaceId: 'c1'),
        family: family,
        me: dad,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dad (you)'), findsOneWidget);
    expect(find.byTooltip('Rename circle'), findsNothing);
    expect(find.byKey(const Key('invite')), findsNothing);
    expect(find.text('Members and invites'), findsOneWidget);
  });

  testWidgets('a circle that is gone says so instead of an empty page', (
    tester,
  ) async {
    await tester.pumpWidget(app(const CirclePage(spaceId: 'gone')));
    await tester.pumpAndSettle();
    expect(find.text("You're no longer in this circle."), findsOneWidget);
  });
}
