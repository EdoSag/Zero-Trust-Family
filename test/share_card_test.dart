import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/l10n/l10n.dart';
import 'package:zerotrust_family/location/location_update.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/share_card.dart';

import 'home_page_test.dart' show phoneSize;
import 'support/app.dart';
import 'support/phone.dart';

void main() {
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

  Rect rect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  testWidgets('turning sharing on explains it first, then asks Android', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const CirclePage(spaceId: 'c1'), family: family),
    );
    await tester.pumpAndSettle();

    final card = rect(tester, 'share-card');
    final on = rect(tester, 'share-on');
    expect(find.text("You're not sharing your location"), findsOneWidget);
    // The button sits inside the card (its rect counts the margin), under
    // its text, full width.
    expect(
      on.top,
      greaterThan(
        tester
            .getRect(
              find.text(
                'Turn on sharing so this circle can see where you are.',
              ),
            )
            .bottom,
      ),
    );
    expect(on.bottom, lessThanOrEqualTo(card.bottom));
    expect(on.width, greaterThanOrEqualTo(card.width - 64));

    // "Not now" leaves everything off, and Android isn't asked.
    await tester.tap(find.byKey(const Key('share-on')));
    await tester.pumpAndSettle();
    expect(find.text('Share your location'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(shareService.requests, 0);
    expect(shareActions.calls, isEmpty);

    await tester.tap(find.byKey(const Key('share-on')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-consent-continue')));
    await tester.pumpAndSettle();
    expect(shareService.requests, 1);
    expect(shareActions.calls, ['start c1']);
    expect(find.text("You're sharing your location"), findsOneWidget);

    // Pause, Share live and Stop stack under the text (the suite's buttons
    // are full width), all inside the card.
    final pause = rect(tester, 'share-pause');
    final live = rect(tester, 'share-live');
    final off = rect(tester, 'share-off');
    expect(
      pause.top,
      greaterThan(
        tester.getRect(find.text("You're sharing your location")).bottom,
      ),
    );
    expect(live.top, greaterThanOrEqualTo(pause.bottom));
    expect(off.top, greaterThanOrEqualTo(live.bottom));
    expect(off.bottom, lessThanOrEqualTo(rect(tester, 'share-card').bottom));
  });

  testWidgets('without "all the time" it still shares, and says how to fix', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        const CirclePage(spaceId: 'c1'),
        family: family,
        service: FakeShareService(
          granted: const SharePermissions(
            location: true,
            background: false,
            notifications: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-on')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-consent-continue')));
    await tester.pumpAndSettle();
    expect(shareActions.calls, ['start c1']);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('no location permission: nothing starts', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(
        const CirclePage(spaceId: 'c1'),
        family: family,
        service: FakeShareService(
          granted: const SharePermissions(
            location: false,
            background: false,
            notifications: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-on')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-consent-continue')));
    await tester.pumpAndSettle();
    expect(shareActions.calls, isEmpty);
    expect(
      find.text('ZT Family needs location access to share where you are.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('pause for an hour, then resume', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      app(const CirclePage(spaceId: 'c1'), family: family),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-on')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-consent-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share-pause')));
    await tester.pumpAndSettle();
    final hour = rect(tester, 'pause-hour');
    final tomorrow = rect(tester, 'pause-tomorrow');
    final open = rect(tester, 'pause-open');
    expect(tomorrow.top, greaterThanOrEqualTo(hour.bottom));
    expect(open.top, greaterThanOrEqualTo(tomorrow.bottom));
    await tester.tap(find.byKey(const Key('pause-hour')));
    await tester.pumpAndSettle();
    expect(shareActions.calls.last, 'pause 60');
    expect(find.text('Sharing is paused'), findsOneWidget);
    expect(find.byKey(const Key('share-live')), findsNothing);

    await tester.tap(find.byKey(const Key('share-resume')));
    await tester.pumpAndSettle();
    expect(shareActions.calls.last, 'resume');
    expect(find.text("You're sharing your location"), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-live')));
    await tester.pumpAndSettle();
    expect(find.text('Sharing live'), findsOneWidget);
    expect(find.text('Stop live'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-off')));
    await tester.pumpAndSettle();
    expect(shareActions.calls.last, 'stop c1');
    expect(find.text("You're not sharing your location"), findsOneWidget);
  });

  testWidgets('member status reads paused, charging and time ago', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = context.l;
    final now = DateTime(2026, 11, 19, 12);
    MemberLocation at(LocationUpdate u) =>
        MemberLocation(userId: dad, deviceId: 'd', update: u);

    expect(locationSummary(l, null, now), 'Not sharing');
    expect(
      locationSummary(
        l,
        at(
          LocationUpdate(
            at: now.subtract(const Duration(seconds: 20)),
            lat: 1,
            lng: 1,
            battery: 30,
            charging: true,
            mode: MotionMode.still,
          ),
        ),
        now,
      ),
      'Just now · Charging 30%',
    );
    expect(
      locationSummary(
        l,
        at(
          LocationUpdate(
            at: now,
            mode: MotionMode.still,
            pausedOpenEnded: true,
          ),
        ),
        now,
      ),
      'Paused',
    );
    expect(ago(l, now.subtract(const Duration(hours: 3)), now), '3 hours ago');
  });
}
