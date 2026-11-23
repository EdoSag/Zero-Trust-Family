import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../data/locations.dart';
import '../l10n/l10n.dart';
import '../location/trip_share.dart';
import 'common.dart';

/// "Share my trip" (L-1): a link anyone can open to see where this phone
/// is, for a limited time.
class TripPage extends ConsumerStatefulWidget {
  const TripPage({super.key, this.name});

  /// This member's name, shown on the trip page.
  final String? name;

  static Future<void> open(BuildContext context, {String? name}) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => TripPage(name: name)));

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  static const _lengths = [
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];

  Duration _length = TripShare.defaultLength;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    TripShare? trip;
    try {
      trip = await ref
          .read(shareActionsProvider)
          .startTrip(length: _length, name: widget.name);
    } on Object {
      if (mounted) showSnack(context, context.l.couldNotSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Straight to the share sheet, to pick who gets the link.
    if (trip != null && mounted) unawaited(_send(trip));
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareActionsProvider).stopTrip();
      if (mounted) showSnack(context, context.l.tripStopped);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(DateTime at) =>
      DateFormat.Hm(context.l.localeName).format(at.toLocal());

  Future<void> _send(TripShare trip) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: context.l.tripShareText(_time(trip.until), trip.link),
        ),
      );
    } on Object {
      // No share sheet (tests, or none on this phone): copy instead.
      if (mounted) await _copy(trip);
    }
  }

  Future<void> _copy(TripShare trip) async {
    await Clipboard.setData(ClipboardData(text: trip.link));
    if (mounted) showSnack(context, context.l.tripCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final state = ref.watch(shareStateProvider).value;
    final now = DateTime.now();
    final trip = state?.trip;
    final active = trip != null && trip.activeAt(now);
    final sharing = state?.sharing ?? false;
    final paused = state?.pausedAt(now) ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.tripTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (active) ...[
            Card(
              key: const Key('trip-active'),
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.tripActive(_time(trip.until)),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.tripActiveBody,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      trip.link,
                      key: const Key('trip-link'),
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (paused) ...[
                      const SizedBox(height: 8),
                      Text(
                        l.tripPausedNote,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('trip-send'),
                    onPressed: () => _send(trip),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l.tripSend),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('trip-copy'),
                    onPressed: () => _copy(trip),
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(l.tripCopy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('trip-stop'),
              onPressed: _busy ? null : _stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l.tripStop),
            ),
          ] else ...[
            Text(l.tripBody),
            const SizedBox(height: 16),
            if (!sharing) ...[
              Card(
                child: ListTile(
                  key: const Key('trip-needs-sharing'),
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.tripNeedsSharing),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(l.tripLength, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Duration>(
              key: const Key('trip-length'),
              segments: [
                for (final d in _lengths)
                  ButtonSegment(
                    value: d,
                    label: Text(switch (d.inHours) {
                      1 => l.tripOneHour,
                      2 => l.tripTwoHours,
                      _ => l.tripFourHours,
                    }),
                  ),
              ],
              selected: {_length},
              onSelectionChanged: (s) => setState(() => _length = s.first),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('trip-start'),
              onPressed: sharing && !_busy ? _start : null,
              icon: const Icon(Icons.route_outlined),
              label: Text(l.tripStart),
            ),
          ],
        ],
      ),
    );
  }
}
