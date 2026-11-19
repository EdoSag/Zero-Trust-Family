import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_family/app/family_config.dart';
import 'package:zerotrust_family/data/family_data.dart';
import 'package:zerotrust_family/data/alerts.dart';
import 'package:zerotrust_family/data/locations.dart';
import 'package:zerotrust_family/data/places.dart';
import 'package:zerotrust_family/l10n/l10n.dart';
import 'package:zerotrust_family/location/alerts.dart';
import 'package:zerotrust_family/location/location_backend.dart';
import 'package:zerotrust_family/location/share_store.dart';
import 'package:zerotrust_family/model/circle.dart';
import 'package:zt_places/zt_places.dart';
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
late FakeShareActions shareActions;
late InMemoryAlertStore alertStore;
late FakePlaceActions placeActions;
late FakeAlertActions alertActions;

class FakePlaceActions extends PlaceActions {
  FakePlaceActions(super.ref);
  final saved = <(String, ZtPlace)>[];
  final removed = <(String, String)>[];

  @override
  Future<bool> save(String spaceId, ZtPlace place) async {
    saved.add((spaceId, place));
    return true;
  }

  @override
  Future<void> remove(String spaceId, String placeId) async =>
      removed.add((spaceId, placeId));
}

/// Keeps the alert store in step without a real circle key.
class FakeAlertActions extends AlertActions {
  FakeAlertActions(super.ref);

  Future<void> _set(AlertState state) async {
    await alertStore.save(state);
    ref.read(alertRevisionProvider.notifier).bump();
  }

  AlertState get _now =>
      alertStore.state ?? AlertState(userId: ref.read(myUserIdProvider)!);

  @override
  Future<bool> enable(String spaceId) async {
    await _set(
      _now.copyWith(
        circles: {
          ..._now.circles,
          spaceId: AlertCircle(spaceId: spaceId, cursor: DateTime.now()),
        },
      ),
    );
    return true;
  }

  @override
  Future<void> disable(String spaceId) async =>
      _set(_now.copyWith(circles: {..._now.circles}..remove(spaceId)));

  @override
  Future<void> refresh() async {}
}

late FakeShareService shareService;

/// The Android service, as the share card sees it.
class FakeShareService implements ShareServiceControl {
  FakeShareService({
    this.granted = const SharePermissions(
      location: true,
      background: true,
      notifications: true,
    ),
  });

  SharePermissions granted;
  int requests = 0;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> poke() async {}
  @override
  Future<SharePermissions> permissions() async => granted;
  @override
  Future<bool> requestNotifications() async => granted.notifications;
  @override
  Future<SharePermissions> requestPermissions() async {
    requests++;
    return granted;
  }
}

/// Records what the share card asks for and keeps the store in step, so
/// the card redraws as it would on a phone.
class FakeShareActions extends ShareActions {
  FakeShareActions(super.ref);

  final calls = <String>[];
  InMemoryShareStore get _mem =>
      ref.read(shareStoreProvider) as InMemoryShareStore;

  Future<void> _set(ShareState state) async {
    await _mem.save(state);
    ref.read(shareRevisionProvider.notifier).bump();
  }

  ShareState get _now =>
      _mem.state ?? ShareState.fresh(ref.read(myUserIdProvider)!);

  @override
  Future<void> startSharing(String spaceId) async {
    calls.add('start $spaceId');
    await _set(
      _now.copyWith(
        circles: [
          CirclePackage(spaceId: spaceId, epoch: 1, boxPublic: Uint8List(32)),
        ],
      ),
    );
  }

  @override
  Future<void> stopSharing(String spaceId) async {
    calls.add('stop $spaceId');
    await _set(_now.copyWith(circles: const []));
  }

  @override
  Future<void> pause(Duration? duration) async {
    calls.add('pause ${duration?.inMinutes}');
    await _set(
      _now.copyWith(
        pausedUntil: () =>
            duration == null ? null : DateTime.now().add(duration),
        pausedOpenEnded: duration == null,
      ),
    );
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    await _set(_now.copyWith(pausedUntil: () => null, pausedOpenEnded: false));
  }

  @override
  Future<void> shareLive([Duration duration = const Duration(hours: 1)]) async {
    calls.add('live');
    await _set(_now.copyWith(liveUntil: () => DateTime.now().add(duration)));
  }

  @override
  Future<void> stopLive() async {
    calls.add('stop live');
    await _set(_now.copyWith(liveUntil: () => null));
  }

  @override
  Future<void> refreshPackages() async {}
}

Widget app(
  Widget home, {
  FamilyData family = const FamilyData(ready: true, loading: false),
  Locale locale = ZtLanguages.english,
  String me = mum,
  ShareState? share,
  Map<String, MemberLocation> locations = const {},
  FakeShareService? service,
  List<ZtPlace> places = const [],
  List<CircleEvent> events = const [],
  AlertState? alerts,
}) {
  alertStore = InMemoryAlertStore(alerts);
  shareService = service ?? FakeShareService();
  return ProviderScope(
    overrides: [
      ztAppConfigProvider.overrideWithValue(familyAppConfig),
      ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      familyProvider.overrideWith((ref) async => family),
      myUserIdProvider.overrideWithValue(me),
      ztPendingJoinsProvider.overrideWith((ref) async => const []),
      ztSharingNameProvider.overrideWith(_MemoryName.new),
      familyActionsProvider.overrideWith((ref) => actions = FakeActions(ref)),
      shareStoreProvider.overrideWithValue(InMemoryShareStore(share)),
      locationBackendProvider.overrideWithValue(
        InMemoryLocationBackend(userId: me),
      ),
      shareServiceProvider.overrideWithValue(shareService),
      shareActionsProvider.overrideWith(
        (ref) => shareActions = FakeShareActions(ref),
      ),
      circleLocationsProvider.overrideWith((ref, spaceId) async => locations),
      circlePlacesProvider.overrideWith((ref, spaceId) async => places),
      circleEventsProvider.overrideWith((ref, spaceId) async => events),
      alertStoreProvider.overrideWithValue(alertStore),
      placeActionsProvider.overrideWith(
        (ref) => placeActions = FakePlaceActions(ref),
      ),
      alertActionsProvider.overrideWith(
        (ref) => alertActions = FakeAlertActions(ref),
      ),
      placeLocatorProvider.overrideWithValue(
        ZtPlaceRemindersFake(location: const ZtLatLng(32.0853, 34.7818)),
      ),
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
          ref.watch(shareActionsProvider);
          ref.watch(placeActionsProvider);
          ref.watch(alertActionsProvider);
          return child!;
        },
      ),
      home: home,
    ),
  );
}
