import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import '../data/family_data.dart';
import '../l10n/l10n.dart';
import 'circle_page.dart';
import 'common.dart';
import 'join.dart';
import 'settings_page.dart';

/// Creates a circle: asks for its name, then for the name the others will
/// see this account under, and opens the new circle ready to invite.
Future<void> createCircle(BuildContext context, WidgetRef ref) async {
  final l = context.l;
  final name = await askCircleName(
    context,
    title: l.newCircleTitle,
    label: l.circleName,
    hint: l.circleNameHint,
    required: l.circleNameRequired,
    confirm: l.create,
    cancel: l.cancel,
  );
  if (name == null || !context.mounted) return;
  final myName = await ztAskSharingName(context, ref, title: l.yourNameTitle);
  if (myName == null || !context.mounted) return;
  try {
    final id = await ref
        .read(familyActionsProvider)
        .createCircle(name: name, myName: myName);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => CirclePage(spaceId: id)));
  } on Object {
    if (context.mounted) showSnack(context, l.couldNotCreate);
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final family = ref.watch(familyProvider).value ?? const FamilyData();
    final empty = family.circles.isEmpty && family.pending.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FamilySettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: family.loading && empty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (family.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      l.couldNotLoad,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ZtJoinRequestCards(
                  titleOf: (id) => family.circle(id)?.name ?? l.unnamedCircle,
                ),
                for (final p in family.pending) _WaitingCard(pending: p),
                for (final c in family.circles) _CircleCard(circle: c),
                if (empty) const _Welcome(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        key: const Key('create-circle'),
                        onPressed: family.ready
                            ? () => createCircle(context, ref)
                            : null,
                        icon: const Icon(Icons.add),
                        label: Text(l.createCircle),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('join-circle'),
                        onPressed: family.ready
                            ? () => joinCircle(context, ref)
                            : null,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(l.joinCircle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        children: [
          Icon(
            Icons.family_restroom,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l.emptyTitle,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l.emptyBody,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle});
  final CircleData circle;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    // A few faces, then "+N".
    const shown = 5;
    final members = circle.members;
    return Card(
      key: Key('circle-${circle.spaceId}'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CirclePage(spaceId: circle.spaceId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                circle.name ?? l.unnamedCircle,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                l.membersCount(members.length),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final m in members.take(shown))
                    MemberAvatar(name: m.name, radius: 16),
                  if (members.length > shown)
                    Text(
                      '+${members.length - shown}',
                      style: theme.textTheme.labelLarge,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingCard extends ConsumerWidget {
  const _WaitingCard({required this.pending});
  final PendingCircle pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return Card(
      key: Key('waiting-${pending.spaceId}'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.hourglass_top),
        title: Text(l.waitingTitle),
        subtitle: Text(l.waitingBody),
        trailing: IconButton(
          tooltip: l.stopWaiting,
          icon: const Icon(Icons.close),
          onPressed: () => ref
              .read(familyActionsProvider)
              .forgetJoin(pending.spaceId)
              .ignore(),
        ),
        onTap: () => ZtSpacePage.open(
          context,
          spaceId: pending.spaceId,
          title: l.unnamedCircle,
        ),
      ),
    );
  }
}
