import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_places/zt_places.dart';

import '../data/alerts.dart';
import '../data/locations.dart';
import '../data/places.dart';
import '../l10n/event_text.dart';
import '../l10n/l10n.dart';
import '../location/alerts.dart';
import '../location/family_event.dart';
import '../location/schedule.dart';
import 'common.dart';
import 'place_page.dart';

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Who is at [place] now, from their latest shared position.
List<String> whoIsAt(ZtPlace place, Map<String, MemberLocation> locations) => [
  for (final m in locations.values)
    if (m.update.hasLocation &&
        !m.update.paused &&
        haversine(
              place.latitude,
              place.longitude,
              m.update.lat!,
              m.update.lng!,
            ) <=
            place.radiusMeters)
      m.userId,
];

/// The circle's places, who is at each, and a way to add one.
class PlacesSection extends ConsumerWidget {
  const PlacesSection({
    super.key,
    required this.spaceId,
    required this.locations,
    required this.names,
  });

  final String spaceId;
  final Map<String, MemberLocation> locations;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final places = ref.watch(circlePlacesProvider(spaceId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l.placesHeading),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(l.placesEmpty),
          ),
        for (final p in places)
          ListTile(
            key: Key('place-${p.id}'),
            leading: const Icon(Icons.place_outlined),
            title: Text(p.name),
            subtitle: Text(() {
              final here = whoIsAt(p, locations);
              if (here.isEmpty) return l.meters(p.radiusMeters.round());
              return l.placeHere(
                here.map((id) => names[id] ?? l.unnamedMember).join(', '),
              );
            }()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PlacePage.open(context, spaceId: spaceId, place: p),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('add-place'),
              onPressed: () => PlacePage.open(context, spaceId: spaceId),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l.addPlace),
            ),
          ),
        ),
      ],
    );
  }
}

/// The last day's arrivals and departures.
class RecentSection extends ConsumerWidget {
  const RecentSection({super.key, required this.spaceId, required this.names});

  final String spaceId;
  final Map<String, String> names;

  static const shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final events = ref.watch(circleEventsProvider(spaceId)).value ?? const [];
    if (events.isEmpty) return const SizedBox.shrink();
    final places = {
      for (final p
          in ref.watch(circlePlacesProvider(spaceId)).value ??
              const <ZtPlace>[])
        p.id: p.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l.recentHeading),
        for (final e in events.take(shown))
          ListTile(
            key: Key('event-${e.event.id}'),
            dense: true,
            leading: Icon(
              e.event.kind == FamilyEventKind.arrive
                  ? Icons.login
                  : Icons.logout,
            ),
            title: Text(
              eventLine(
                l,
                names[e.userId] ?? l.unnamedMember,
                places[e.event.placeId],
                e.event.kind,
              ),
            ),
            subtitle: Text(
              DateFormat.Hm(l.localeName).format(e.event.at.toLocal()),
            ),
          ),
      ],
    );
  }
}

/// Alerts on this phone for one circle: on or off (they work while the app
/// is locked), who to get them about, and quiet hours.
class AlertsCard extends ConsumerStatefulWidget {
  const AlertsCard({
    super.key,
    required this.spaceId,
    required this.members,
    required this.me,
  });

  final String spaceId;
  final List<SpaceMember> members;
  final String? me;

  @override
  ConsumerState<AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends ConsumerState<AlertsCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } on Object {
      if (mounted) showSnack(context, context.l.couldNotSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool on) => _run(() async {
    final l = context.l;
    final actions = ref.read(alertActionsProvider);
    if (!on) return actions.disable(widget.spaceId);
    await ref.read(shareServiceProvider).requestNotifications();
    final ok = await actions.enable(widget.spaceId);
    if (!ok && mounted) showSnack(context, l.circleKeyNotReady);
  });

  Future<void> _quietHours(QuietHours? current) async {
    final l = context.l;
    final choice = await showModalBottomSheet<(QuietHours?,)>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('quiet-off'),
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l.quietOff),
              onTap: () => Navigator.pop(context, (null,)),
            ),
            ListTile(
              key: const Key('quiet-night'),
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(
                l.quietRange(
                  _hm(context, QuietHours.standard.startMinute),
                  _hm(context, QuietHours.standard.endMinute),
                ),
              ),
              onTap: () => Navigator.pop(context, (QuietHours.standard,)),
            ),
            ListTile(
              key: const Key('quiet-custom'),
              leading: const Icon(Icons.schedule),
              title: Text(l.quietCustom),
              onTap: () async {
                final from = await showTimePicker(
                  context: context,
                  helpText: l.quietFrom,
                  initialTime: _time(
                    current?.startMinute ?? QuietHours.standard.startMinute,
                  ),
                );
                if (from == null || !context.mounted) return;
                final to = await showTimePicker(
                  context: context,
                  helpText: l.quietTo,
                  initialTime: _time(
                    current?.endMinute ?? QuietHours.standard.endMinute,
                  ),
                );
                if (to == null || !context.mounted) return;
                Navigator.pop(context, (
                  QuietHours(
                    from.hour * 60 + from.minute,
                    to.hour * 60 + to.minute,
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _run(() => ref.read(alertActionsProvider).setQuietHours(choice.$1));
  }

  static TimeOfDay _time(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

  static String _hm(BuildContext context, int minute) => DateFormat.Hm(
    context.l.localeName,
  ).format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final state = ref.watch(alertStateProvider).value;
    final circle = state?.circles[widget.spaceId];
    final on = circle != null;
    final quiet = state?.quiet;
    final others = [
      for (final m in widget.members)
        if (m.userId != widget.me) m,
    ];
    return Card(
      key: const Key('alerts-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const Key('alerts-locked'),
            value: on,
            onChanged: _busy ? null : _toggle,
            title: Text(l.alertsTitle),
            subtitle: Text(l.alertsBody),
          ),
          if (on) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                l.alertsAbout,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final m in others)
              CheckboxListTile(
                key: Key('alert-about-${m.userId}'),
                value: !circle.muted.contains(m.userId),
                onChanged: _busy
                    ? null
                    : (v) => _run(
                        () => ref
                            .read(alertActionsProvider)
                            .setMuted(widget.spaceId, m.userId, v != true),
                      ),
                title: Text(m.name.isEmpty ? l.unnamedMember : m.name),
              ),
            ListTile(
              key: const Key('quiet-hours'),
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(l.quietHours),
              subtitle: Text(
                quiet == null
                    ? l.quietOff
                    : l.quietOnSummary(
                        _hm(context, quiet.startMinute),
                        _hm(context, quiet.endMinute),
                      ),
              ),
              onTap: _busy ? null : () => _quietHours(quiet),
            ),
          ],
        ],
      ),
    );
  }
}
