import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/locations.dart';
import '../l10n/l10n.dart';
import 'common.dart';

/// "Updated 5 min ago", "Paused", "Sharing live", with battery.
String locationSummary(AppL10n l, MemberLocation? m, DateTime now) {
  if (m == null) return l.notSharing;
  final u = m.update;
  final parts = <String>[];
  if (u.paused) {
    final until = u.pausedUntil;
    parts.add(
      u.pausedOpenEnded || until == null
          ? l.pausedStatus
          : l.pausedUntil(DateFormat.Hm(l.localeName).format(until.toLocal())),
    );
  } else {
    parts.add(ago(l, u.at, now));
    if (u.approximate && u.hasLocation) parts.add(l.approximateStatus);
  }
  if (u.battery != null) {
    parts.add(
      u.charging ? l.batteryCharging(u.battery!) : l.battery(u.battery!),
    );
  }
  return parts.join(' · ');
}

String ago(AppL10n l, DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return l.justNow;
  if (d.inMinutes < 60) return l.minutesAgo(d.inMinutes);
  if (d.inHours < 24) return l.hoursAgo(d.inHours);
  return DateFormat.MMMd(l.localeName).add_Hm().format(at.toLocal());
}

/// This phone's sharing with one circle: turn on and off, pause, share
/// live.
class ShareCard extends ConsumerStatefulWidget {
  const ShareCard({super.key, required this.spaceId});
  final String spaceId;

  @override
  ConsumerState<ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends ConsumerState<ShareCard> {
  bool _busy = false;
  bool _needsAlways = false;

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } on Object {
      if (mounted) showSnack(context, context.l.couldNotSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOn() async {
    final l = context.l;
    // Google Play's prominent disclosure, before the system asks.
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined),
        title: Text(l.shareConsentTitle),
        content: Text(l.shareConsentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.notNow),
          ),
          FilledButton(
            key: const Key('share-consent-continue'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.continueLabel),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _run(() async {
      final service = ref.read(shareServiceProvider);
      final granted = await service.requestPermissions();
      if (!granted.location) {
        if (mounted) showSnack(context, l.locationPermissionNeeded);
        return;
      }
      _needsAlways = !granted.background;
      try {
        await ref.read(shareActionsProvider).startSharing(widget.spaceId);
      } on StateError {
        if (mounted) showSnack(context, l.circleKeyNotReady);
      }
    });
  }

  Future<void> _turnOff() =>
      _run(() => ref.read(shareActionsProvider).stopSharing(widget.spaceId));

  Future<void> _pause() async {
    final l = context.l;
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('pause-hour'),
              leading: const Icon(Icons.timer_outlined),
              title: Text(l.pauseHour),
              onTap: () => Navigator.pop(context, const Duration(hours: 1)),
            ),
            ListTile(
              key: const Key('pause-tomorrow'),
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(l.pauseTomorrow),
              onTap: () {
                final now = DateTime.now();
                final morning = DateTime(now.year, now.month, now.day + 1, 7);
                Navigator.pop(context, morning.difference(now));
              },
            ),
            ListTile(
              key: const Key('pause-open'),
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(l.pauseUntilResumed),
              // Zero stands for "until I turn it back on".
              onTap: () => Navigator.pop(context, Duration.zero),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _run(
      () => ref
          .read(shareActionsProvider)
          .pause(choice == Duration.zero ? null : choice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final state = ref.watch(shareStateProvider).value;
    final sharing = state?.sharesWith(widget.spaceId) ?? false;
    final now = DateTime.now();
    final paused = state?.pausedAt(now) ?? false;
    final live = state?.liveUntil != null && now.isBefore(state!.liveUntil!);
    final mine = state?.circles
        .where((c) => c.spaceId == widget.spaceId)
        .firstOrNull;
    final stale = mine?.stale ?? false;
    final approximate = mine?.approximate ?? false;

    final (icon, title, body) = !sharing
        ? (Icons.location_off_outlined, l.shareOffTitle, l.shareOffBody)
        : paused
        ? (
            Icons.pause_circle_outline,
            l.sharePausedTitle,
            state!.pausedOpenEnded || state.pausedUntil == null
                ? l.sharePausedOpenBody
                : l.sharePausedUntilBody(
                    DateFormat.Hm(l.localeName).format(state.pausedUntil!),
                  ),
          )
        : live
        ? (
            Icons.radar,
            l.shareLiveTitle,
            l.shareLiveBody(
              DateFormat.Hm(l.localeName).format(state.liveUntil!),
            ),
          )
        : (Icons.location_on, l.shareOnTitle, l.shareOnBody);

    return Card(
      key: const Key('share-card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: sharing && !paused
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(body),
                      if (sharing && stale) ...[
                        const SizedBox(height: 8),
                        Text(
                          l.shareStale,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      if (sharing && _needsAlways) ...[
                        const SizedBox(height: 8),
                        Text(l.needsAlwaysHint),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: openAppSettings,
                            child: Text(l.openSettings),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!sharing)
              FilledButton.icon(
                key: const Key('share-on'),
                onPressed: _busy ? null : _turnOn,
                icon: const Icon(Icons.location_on_outlined),
                label: Text(l.shareTurnOn),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (paused)
                    FilledButton.icon(
                      key: const Key('share-resume'),
                      onPressed: _busy
                          ? null
                          : () => _run(ref.read(shareActionsProvider).resume),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l.resume),
                    )
                  else
                    OutlinedButton.icon(
                      key: const Key('share-pause'),
                      onPressed: _busy ? null : _pause,
                      icon: const Icon(Icons.pause),
                      label: Text(l.pause),
                    ),
                  if (!paused)
                    OutlinedButton.icon(
                      key: const Key('share-live'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              live
                                  ? ref.read(shareActionsProvider).stopLive
                                  : ref.read(shareActionsProvider).shareLive,
                            ),
                      icon: Icon(
                        live ? Icons.stop_circle_outlined : Icons.radar,
                      ),
                      label: Text(live ? l.stopLive : l.shareLiveHour),
                    ),
                  TextButton(
                    key: const Key('share-off'),
                    onPressed: _busy ? null : _turnOff,
                    child: Text(l.shareTurnOff),
                  ),
                ],
              ),
            if (sharing)
              SwitchListTile(
                key: const Key('share-approximate'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.approximateSwitch),
                subtitle: Text(l.approximateBody),
                value: approximate,
                onChanged: _busy
                    ? null
                    : (on) => _run(
                        () => ref
                            .read(shareActionsProvider)
                            .setApproximate(widget.spaceId, on),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
