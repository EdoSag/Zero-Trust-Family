import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/ui/circle_page.dart';
import 'package:zerotrust_family/ui/home_page.dart';

import 'support/app.dart';
import 'support/phone.dart';

void main() {
  test('every English string has a Hebrew one, with the same placeholders', () {
    Map<String, Object?> read(String name) =>
        (jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map)
            .cast<String, Object?>();
    final en = read('app_en.arb');
    final he = read('app_he.arb');
    final keys = en.keys.where((k) => !k.startsWith('@')).toSet();
    expect(he.keys.where((k) => !k.startsWith('@')).toSet(), keys);
    final placeholder = RegExp(r'\{(\w+)[,}]');
    for (final k in keys) {
      final a = placeholder.allMatches(en[k]! as String).map((m) => m[1]);
      final b = placeholder.allMatches(he[k]! as String).map((m) => m[1]);
      expect(b.toSet(), a.toSet(), reason: k);
      // Really translated: Hebrew letters in every string.
      expect(RegExp(r'[֐-׿]').hasMatch(he[k]! as String), isTrue, reason: k);
    }
  });

  testWidgets('Hebrew: right to left, translated, nothing overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final family = FamilyData(
      ready: true,
      loading: false,
      pending: const [PendingCircle('p1')],
      circles: [
        circleOf('c1', 'הבית', [
          await member(mum, 'אמא', role: SpaceRole.admin),
          await member(dad, 'אבא', seed: 2),
        ]),
      ],
    );
    await tester.pumpWidget(
      app(const HomePage(), family: family, locale: ZtLanguages.hebrew),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(HomePage))),
      TextDirection.rtl,
    );
    expect(find.text('משפחה'), findsOneWidget);
    expect(find.text('2 חברים'), findsOneWidget);
    expect(find.text('ממתינים לאישור'), findsOneWidget);
    // The waiting card's icon leads on the right, its close button on the
    // left.
    final icon = tester.getRect(find.byIcon(Icons.hourglass_top));
    final close = tester.getRect(find.byIcon(Icons.close));
    expect(icon.left, greaterThan(close.right));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('הבית'));
    await tester.pumpAndSettle();
    expect(find.byType(CirclePage), findsOneWidget);
    expect(find.text('אמא (את/ה)'), findsOneWidget);
    expect(find.text('בעלים'), findsOneWidget);
    // Avatars are on the right of the names.
    final avatar = tester.getRect(find.byType(CircleAvatar).first);
    final name = tester.getRect(find.text('אמא (את/ה)'));
    expect(avatar.left, greaterThan(name.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hebrew first run fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const HomePage(), locale: ZtLanguages.hebrew));
    await tester.pumpAndSettle();
    expect(find.text('פותחים מעגל משפחתי'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
