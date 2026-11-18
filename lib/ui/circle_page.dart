import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import '../data/family_data.dart';
import '../l10n/l10n.dart';
import 'common.dart';

/// One family circle: who is in it, and the way to invite and manage them.
/// The map, places and check-ins are added here in the next phases.
class CirclePage extends ConsumerWidget {
  const CirclePage({super.key, required this.spaceId});

  final String spaceId;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    CircleData circle,
  ) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (circle.isAdmin)
            IconButton(
              tooltip: l.renameCircle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, ref, circle),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.locationSoonTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(l.locationSoonBody),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                return m.userId == me ? l.youSuffix(name) : name;
              }()),
              subtitle: m.role == SpaceRole.admin ? Text(l.owner) : null,
            ),
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
