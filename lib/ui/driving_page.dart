import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/history.dart';
import '../data/locations.dart';
import '../l10n/event_text.dart';
import '../l10n/l10n.dart';
import '../location/drive.dart';
import 'common.dart';
import 'history_page.dart' show distanceText, durationText;
import 'history_section.dart' show showNeedsPlus;

/// Drive summaries and crash detection for this phone, and whether this
/// circle gets this phone's drives.
class DrivingPage extends ConsumerStatefulWidget {
  const DrivingPage({super.key, required this.spaceId});

  final String spaceId;

  static Future<void> open(BuildContext context, String spaceId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DrivingPage(spaceId: spaceId)),
      );

  @override
  ConsumerState<DrivingPage> createState() => _DrivingPageState();
}

class _DrivingPageState extends ConsumerState<DrivingPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(ShareActions a) task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task(ref.read(shareActionsProvider));
    } on Object {
      if (mounted) showSnack(context, context.l.couldNotSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _crash(bool on) async {
    final l = context.l;
    if (on) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: const Icon(Icons.car_crash_outlined),
          title: Text(l.crashSwitch),
          content: Text('${l.crashSwitchBody}\n\n${l.crashDisclaimer}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const Key('crash-consent'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.turnOn),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    await _run((a) => a.setCrashDetection(on));
  }

  Future<void> _erase() async {
    final l = context.l;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.eraseMyDrives),
        content: Text(l.eraseMyDrivesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('erase-drives-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.erase),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await ref.read(shareEngineProvider).drives.clear();
    ref.invalidate(myDrivesProvider);
    if (mounted) showSnack(context, l.drivesErased);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final state = ref.watch(shareStateProvider).value;
    final circle = state?.circles
        .where((c) => c.spaceId == widget.spaceId)
        .firstOrNull;
    final sharing = circle != null;
    final plus = ref.watch(familyPlusProvider);
    final drives = ref.watch(myDrivesProvider).value ?? const [];
    final enabled = sharing && !_busy;
    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.drivingTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!sharing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.drivingNeedsSharing),
                ),
              ),
            ),
          SwitchListTile(
            key: const Key('drives-switch'),
            secondary: const Icon(Icons.directions_car_outlined),
            title: Text(l.drivesSwitch),
            subtitle: Text(l.drivesSwitchBody),
            value: state?.drives ?? false,
            onChanged: enabled ? (on) => _run((a) => a.setDrives(on)) : null,
          ),
          SwitchListTile(
            key: const Key('share-drives-switch'),
            secondary: const Icon(Icons.group_outlined),
            title: Text(l.shareDrivesSwitch),
            subtitle: Text(l.shareDrivesBody),
            value: circle?.shareDrives ?? false,
            onChanged: enabled && (state?.drives ?? false)
                ? (on) async {
                    if (on && !plus) {
                      await showNeedsPlus(context, l.shareDrivesNeedsPlus);
                      return;
                    }
                    await _run((a) => a.setShareDrives(widget.spaceId, on));
                  }
                : null,
          ),
          SwitchListTile(
            key: const Key('crash-switch'),
            secondary: const Icon(Icons.car_crash_outlined),
            title: Text(l.crashSwitch),
            subtitle: Text(l.crashSwitchBody),
            value: state?.crashDetection ?? false,
            onChanged: enabled ? _crash : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.crashDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          heading(l.myDrivesHeading),
          if (drives.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l.noDrivesYet),
            ),
          for (final d in drives) DriveTile(drive: d),
          if (drives.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('erase-drives'),
                  onPressed: _erase,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.eraseMyDrives),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One drive: when, how far, how long, top speed, and what stood out.
class DriveTile extends StatelessWidget {
  const DriveTile({super.key, required this.drive});
  final DriveSummary drive;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final day = DateFormat.MMMd(l.localeName);
    final hm = DateFormat.Hm(l.localeName);
    final start = drive.start.toLocal();
    final end = drive.end.toLocal();
    final notes = <String>[
      l.driveSpeeds(kmh(l, drive.topSpeedMps), kmh(l, drive.averageSpeedMps)),
      if (drive.hardBrakes > 0) l.hardBrakes(drive.hardBrakes),
      if (drive.rapidStarts > 0) l.rapidStarts(drive.rapidStarts),
      if (drive.phoneUseSeconds >= 60)
        l.phoneUseMinutes(drive.phoneUseSeconds ~/ 60),
    ];
    return ListTile(
      key: Key('drive-${drive.id}'),
      leading: const Icon(Icons.directions_car_outlined),
      title: Text(
        '${day.format(start)} ${hm.format(start)}–${hm.format(end)} · '
        '${distanceText(l, drive.distanceM)} · '
        '${durationText(l, drive.length)}',
      ),
      subtitle: Text(notes.join(' · ')),
    );
  }
}

/// A crash this phone detected, counting down to an SOS, with "I'm OK" and
/// "Send SOS now". Shown on top of every circle while it runs.
class CrashBanner extends ConsumerWidget {
  const CrashBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crash = ref.watch(shareStateProvider).value?.crash;
    if (crash == null) return const SizedBox.shrink();
    final l = context.l;
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.Hms(l.localeName).format(crash.deadline.toLocal());
    final actions = ref.read(shareActionsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        key: const Key('crash-banner'),
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.crashCountdownTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.crashCountdownBody(time),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('crash-ok'),
                      onPressed: () => actions.cancelCrash(),
                      child: Text(l.imOk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('crash-sos'),
                      onPressed: () => actions.crashSosNow(),
                      child: Text(l.crashSendNow),
                    ),
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
