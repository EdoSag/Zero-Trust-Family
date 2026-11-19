import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/family_data.dart';
import '../data/locations.dart';
import '../l10n/l10n.dart';
import 'common.dart';
import 'family_map.dart';
import 'places_section.dart';
import 'share_card.dart';

/// One family circle: the map, this phone's sharing, where everyone is, and
/// the way to invite and manage members.
class CirclePage extends ConsumerStatefulWidget {
  const CirclePage({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<CirclePage> createState() => _CirclePageState();
}

class _CirclePageState extends ConsumerState<CirclePage> {
  final MapController _map = MapController();

  String get spaceId => widget.spaceId;

  /// Centers the map on a member; without a map, opens the phone's own
  /// maps app (the person chooses to share that position with it).
  Future<void> _show(MemberLocation m, String? mapUrl) async {
    final lat = m.update.lat!, lng = m.update.lng!;
    if (mapUrl != null) {
      _map.move(LatLng(lat, lng), 16);
      return;
    }
    await launchUrl(Uri.parse('geo:$lat,$lng?q=$lat,$lng'));
  }

  Future<void> _rename(BuildContext context, CircleData circle) async {
    final l = context.l;
    final name = await askCircleName(
      context,
      title: l.renameCircle,
      label: l.circleName,
      hint: l.circleNameHint,
      required: l.circleNameRequired,
      confirm: l.save,
      cancel: l.cancel,
      initial: circle.name ?? '',
    );
    if (name == null) return;
    try {
      await ref.read(familyActionsProvider).renameCircle(spaceId, name);
    } on Object {
      if (context.mounted) showSnack(context, l.couldNotSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final family = ref.watch(familyProvider).value;
    final circle = family?.circle(spaceId);
    if (circle == null) {
      // Left, removed, or deleted while this page was open.
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: family == null || family.loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.circleGone, textAlign: TextAlign.center),
                ),
        ),
      );
    }
    final title = circle.name ?? l.unnamedCircle;
    final me = ref.watch(myUserIdProvider);
    final locations =
        ref.watch(circleLocationsProvider(spaceId)).value ?? const {};
    final names = {for (final m in circle.members) m.userId: m.name};
    final mapUrl = familyMapUrl();
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (circle.isAdmin)
            IconButton(
              tooltip: l.renameCircle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, circle),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          if (mapUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  key: const Key('family-map'),
                  height: 280,
                  child: FamilyMap(
                    url: mapUrl,
                    locations: locations,
                    names: names,
                    controller: _map,
                  ),
                ),
              ),
            ),
          ShareCard(spaceId: widget.spaceId),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
            child: Text(
              l.membersHeading,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final m in circle.members)
            ListTile(
              key: Key('member-${m.userId}'),
              leading: MemberAvatar(name: m.name),
              title: Text(() {
                final name = m.name.isEmpty ? l.unnamedMember : m.name;
                final shown = m.userId == me ? l.youSuffix(name) : name;
                return m.role == SpaceRole.admin
                    ? '$shown · ${l.owner}'
                    : shown;
              }()),
              subtitle: Text(
                locationSummary(l, locations[m.userId], now),
                key: Key('member-status-${m.userId}'),
              ),
              trailing: locations[m.userId]?.update.hasLocation == true
                  ? IconButton(
                      tooltip: l.showOnMap,
                      icon: const Icon(Icons.place_outlined),
                      onPressed: () => _show(locations[m.userId]!, mapUrl),
                    )
                  : null,
            ),
          PlacesSection(spaceId: spaceId, locations: locations, names: names),
          RecentSection(spaceId: spaceId, names: names),
          AlertsCard(spaceId: spaceId, members: circle.members, me: me),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text(l.manageMembers),
            subtitle: Text(l.manageMembersHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ZtSpacePage.open(
              context,
              spaceId: spaceId,
              title: title,
              description: l.circleDescription,
            ),
          ),
          if (circle.isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton.icon(
                key: const Key('invite'),
                onPressed: () => ZtSpacePage.open(
                  context,
                  spaceId: spaceId,
                  title: title,
                  description: l.circleDescription,
                  inviteNow: true,
                ),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l.inviteSomeone),
              ),
            ),
        ],
      ),
    );
  }
}
