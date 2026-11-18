import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/app/family_config.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/l10n/l10n.dart';
import 'package:zerotrust_family/model/circle.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import 'phone.dart';

/// A member as the circle's encrypted list holds them.
Future<SpaceMember> member(
  String userId,
  String name, {
  SpaceRole role = SpaceRole.member,
  int seed = 1,
}) async => SpaceMember(
  userId: userId,
  name: name,
  identity: (await ZtIdentity.fromDek(dek(seed))).public,
  role: role,
);

CircleData circleOf(
  String id,
  String? name,
  List<SpaceMember> members, {
  bool isAdmin = true,
}) => CircleData(
  spaceId: id,
  circle: name == null ? null : Circle(name: name),
  members: sortMembers(members),
  isAdmin: isAdmin,
);

/// Records what the screens ask for instead of talking to a server.
class FakeActions extends FamilyActions {
  FakeActions(super.ref);

  final created = <(String name, String myName)>[];
  final renamed = <(String spaceId, String name)>[];
  final forgotten = <String>[];

  @override
  Future<String> createCircle({
    required String name,
    required String myName,
  }) async {
    created.add((Circle.cleanName(name)!, myName));
    return 'new-circle';
  }

  @override
  Future<void> renameCircle(String spaceId, String name) async =>
      renamed.add((spaceId, Circle.cleanName(name)!));

  @override
  Future<void> forgetJoin(String spaceId) async => forgotten.add(spaceId);

  @override
  Future<void> rememberJoin(String spaceId) async {}

  @override
  Future<void> tidyPending(Set<String> joined) async {}
}

class _MemoryName extends ZtSharingName {
  _MemoryName(super.ref);
  String name = '';
  @override
  Future<String> read() async => name;
  @override
  Future<void> save(String name) async => this.name = name;
}

late FakeActions actions;

Widget app(
  Widget home, {
  FamilyData family = const FamilyData(ready: true, loading: false),
  Locale locale = ZtLanguages.english,
  String me = mum,
}) {
  return ProviderScope(
    overrides: [
      ztAppConfigProvider.overrideWithValue(familyAppConfig),
      ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      familyProvider.overrideWith((ref) async => family),
      myUserIdProvider.overrideWithValue(me),
      ztPendingJoinsProvider.overrideWith((ref) async => const []),
      ztSharingNameProvider.overrideWith(_MemoryName.new),
      familyActionsProvider.overrideWith((ref) => actions = FakeActions(ref)),
    ],
    child: MaterialApp(
      // The suite's real theme: its full-width buttons break rows that a
      // plain theme lets through.
      theme: ZtTheme.light(accent: familyAppConfig.accent),
      locale: locale,
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        ...ZtLanguages.delegates,
      ],
      // Made up front, so a test can ask what was done before anything was.
      builder: (context, child) => Consumer(
        builder: (context, ref, _) {
          ref.watch(familyActionsProvider);
          return child!;
        },
      ),
      home: home,
    ),
  );
}
