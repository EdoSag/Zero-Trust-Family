import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/hub.dart';
import '../l10n/l10n.dart';
import '../model/family_hub.dart';

/// L-2: the circle's shared calendar, lists and medicines in one place.
/// The items belong to ZT Calendar, ZT Tasks and ZT Meds, which keep them
/// in the circle (S-10); here they're read-only.
class HubPage extends ConsumerWidget {
  const HubPage({super.key, required this.spaceId});

  final String spaceId;

  static Future<void> open(BuildContext context, String spaceId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => HubPage(spaceId: spaceId)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final hub = ref.watch(circleHubProvider(spaceId));
    return Scaffold(
      appBar: AppBar(title: Text(l.hubTitle)),
      body: switch (hub) {
        AsyncData(:final value) => _HubBody(hub: value),
        AsyncError() => const _HubBody(hub: FamilyHub()),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.hub});
  final FamilyHub hub;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    if (hub.isEmpty) {
      return Center(
        key: const Key('hub-empty'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l.hubEmptyTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l.hubEmptyBody, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    Widget heading(String text, Key key) => Padding(
      key: key,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (hub.comingUp.isNotEmpty) ...[
          heading(l.hubComingUp, const Key('hub-coming-up')),
          for (final i in hub.comingUp)
            _ItemTile(item: i, icon: Icons.event_outlined),
        ],
        if (hub.lists.isNotEmpty) ...[
          heading(l.hubLists, const Key('hub-lists')),
          for (final list in hub.lists) _ListCard(list: list),
        ],
        if (hub.medsToday.isNotEmpty) ...[
          heading(l.hubMedsToday, const Key('hub-meds')),
          for (final i in hub.medsToday)
            _ItemTile(item: i, icon: Icons.medication_outlined, timeOnly: true),
        ],
        if (hub.other.isNotEmpty) ...[
          heading(l.hubOther, const Key('hub-other')),
          for (final i in hub.other)
            _ItemTile(item: i, icon: Icons.apps_outlined),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            l.hubReadOnly,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Today 18:30", "Tomorrow 09:00", "Mon 3 Dec 10:00".
String hubWhen(AppL10n l, DateTime at, DateTime now, {bool timeOnly = false}) {
  final local = at.toLocal();
  final time = DateFormat.Hm(l.localeName).format(local);
  if (timeOnly) return time;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  final date = diff == 0
      ? l.hubToday
      : diff == 1
      ? l.hubTomorrow
      : DateFormat.MMMEd(l.localeName).format(local);
  return '$date $time';
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.icon,
    this.timeOnly = false,
  });

  final HubItem item;
  final IconData icon;
  final bool timeOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final now = DateTime.now();
    final at = item.summary.at, due = item.summary.due;
    final parts = <String>[
      if (at != null) hubWhen(l, at, now, timeOnly: timeOnly),
      if (at == null && due != null) l.hubDue(hubWhen(l, due, now)),
      if (item.app == FamilyHub.meds && item.done) l.hubTaken,
    ];
    return ListTile(
      key: Key('hub-item-${item.itemId}'),
      leading: Icon(
        item.app == FamilyHub.meds && item.done
            ? Icons.check_circle_outline
            : icon,
      ),
      title: Text(item.title),
      subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list});
  final HubList list;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final title = list.id == null
        ? l.hubOtherTasks
        : (list.title ?? l.hubUnnamedList);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        key: Key('hub-list-${list.id ?? 'none'}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: Text(title, style: theme.textTheme.titleMedium),
                subtitle: list.doneCount > 0
                    ? Text(l.hubDoneCount(list.doneCount))
                    : null,
              ),
              if (list.open.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 8),
                  child: Text(l.hubAllDone),
                ),
              for (final i in list.open)
                ListTile(
                  key: Key('hub-item-${i.itemId}'),
                  dense: true,
                  leading: const Icon(Icons.radio_button_unchecked),
                  title: Text(i.title),
                  subtitle: i.summary.due == null
                      ? null
                      : Text(l.hubDue(hubWhen(l, i.summary.due!, now))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
