import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/location/share_store.dart';
import 'package:zerotrust_family/ui/circle_page.dart';

import 'home_page_test.dart' show phoneSize;
import 'support/app.dart';
import 'support/phone.dart';

void main() {
  late FamilyData family;
  final sharing = ShareState.fresh(mum).copyWith(
    circles: [CirclePackage(spaceId: 'c1', epoch: 1, boxPublic: Uint8List(32))],
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

  /// The card is taller than a phone screen: scroll to a button first.
  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Rect rect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  Future<void> open(
    WidgetTester tester, {
    ShareState? share,
    Locale locale = ZtLanguages.english,
  }) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        const CirclePage(spaceId: 'c1'),
        family: family,
        share: share,
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('sos')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without sharing it says why, and has no buttons', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const CirclePage(spaceId: 'c1'), family: family),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('safety-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Share your location with this circle'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('checkin')), findsNothing);
    expect(find.byKey(const Key('sos')), findsNothing);
  });

  testWidgets('buttons stack in order, SOS last, inside the card', (
    tester,
  ) async {
    await open(tester, share: sharing);
    final card = rect(tester, 'safety-card');
    final checkin = rect(tester, 'checkin');
    final ask = rect(tester, 'ask');
    final timer = rect(tester, 'timer');
    final sos = rect(tester, 'sos');
    expect(ask.top, greaterThanOrEqualTo(checkin.bottom));
    expect(timer.top, greaterThanOrEqualTo(ask.bottom));
    expect(sos.top, greaterThanOrEqualTo(timer.bottom));
    for (final r in [checkin, ask, timer, sos]) {
      expect(r.left, greaterThanOrEqualTo(card.left));
      expect(r.right, lessThanOrEqualTo(card.right));
      expect(r.width, greaterThanOrEqualTo(card.width - 64));
    }
    expect(sos.bottom, lessThanOrEqualTo(card.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('check in with a note', (tester) async {
    await open(tester, share: sharing);
    await tapKey(tester, const Key('checkin'));
    await tester.enterText(find.byKey(const Key('checkin-note')), 'At school');
    await tapKey(tester, const Key('checkin-send'));
    expect(shareActions.calls.last, 'checkin c1 At school');
    expect(find.text('Checked in'), findsOneWidget);
  });

  testWidgets('offline: the check-in says it did not go', (tester) async {
    await open(tester, share: sharing);
    shareActions.online = false;
    await tapKey(tester, const Key('checkin'));
    await tapKey(tester, const Key('checkin-send'));
    expect(find.textContaining("Couldn't send"), findsOneWidget);
  });

  testWidgets('ask lists everyone but me', (tester) async {
    await open(tester, share: sharing);
    await tapKey(tester, const Key('ask'));
    expect(find.byKey(Key('ask-$mum')), findsNothing);
    final d = rect(tester, 'ask-$dad');
    final n = rect(tester, 'ask-$teen');
    expect(n.top, greaterThanOrEqualTo(d.bottom));
    await tapKey(tester, Key('ask-$teen'));
    expect(shareActions.calls.last, 'ask c1 $teen');
    expect(find.text('Asked Noa to check in'), findsOneWidget);
  });

  testWidgets('timer: an hour, then the banner, then I\'m OK', (tester) async {
    await open(tester, share: sharing);
    await tapKey(tester, const Key('timer'));
    expect(find.text('In 30 minutes'), findsOneWidget);
    expect(find.text('In 2 hours'), findsOneWidget);
    await tapKey(tester, const Key('timer-60'));
    expect(shareActions.calls.last, 'timer c1');

    // The banner sits above the buttons, and the timer button is off.
    final banner = rect(tester, 'timer-active');
    expect(rect(tester, 'checkin').top, greaterThan(banner.bottom));
    expect(
      tester.widget<ButtonStyleButton>(find.byKey(const Key('timer'))).enabled,
      isFalse,
    );
    await tapKey(tester, const Key('timer-ok'));
    expect(shareActions.calls.last, 'timer end');
    expect(find.byKey(const Key('timer-active')), findsNothing);
  });

  testWidgets('SOS: a tap only explains, a 2 second hold sends', (
    tester,
  ) async {
    await open(tester, share: sharing);
    await tapKey(tester, const Key('sos'));
    expect(shareActions.calls, isEmpty);
    expect(
      find.textContaining('Hold the button for 2 seconds'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('sos')));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sos'))),
    );
    // Frame by frame, as on a phone.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(shareActions.calls, isEmpty);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(shareActions.calls, ['sos c1']);
    expect(find.byKey(const Key('sos-active')), findsOneWidget);

    await tapKey(tester, const Key('sos-end'));
    expect(shareActions.calls.last, 'sos end');
    expect(find.byKey(const Key('sos-active')), findsNothing);
  });

  testWidgets('Hebrew: translated, icons on the right', (tester) async {
    await open(tester, share: sharing, locale: ZtLanguages.hebrew);
    expect(find.text('בטיחות'), findsOneWidget);
    expect(find.text('אני כאן'), findsOneWidget);
    expect(find.text('לחיצה ארוכה ל-SOS'), findsOneWidget);
    final icon = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('checkin')),
        matching: find.byIcon(Icons.check_circle_outline),
      ),
    );
    expect(icon.left, greaterThan(tester.getRect(find.text('אני כאן')).right));
    expect(tester.takeException(), isNull);
  });
}
