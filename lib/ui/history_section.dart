import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/history.dart';
import '../l10n/l10n.dart';
import '../location/location_backend.dart';
import 'common.dart';

/// Says what Plus adds, with a way to the plans. Safety stays free.
Future<void> showNeedsPlus(BuildContext context, String text) {
  final l = context.l;
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const Key('needs-plus'),
      title: Text(l.plusBadge),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('see-plans'),
          onPressed: () {
            Navigator.pop(dialog);
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ZtPlansScreen()),
            );
          },
          child: Text(l.seePlans),
        ),
      ],
    ),
  );
}

/// How long the circle keeps history (the owner chooses), and erasing
/// your own.
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({
    super.key,
    required this.spaceId,
    required this.isOwner,
  });

  final String spaceId;
  final bool isOwner;

  static const choices = [1, 3, 7, 14, 30];

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() task, {String? done}) async {
    final l = context.l;
    setState(() => _busy = true);
    try {
      await task();
      if (mounted && done != null) showSnack(context, done);
    } on NeedsPlusException {
      if (mounted) await showNeedsPlus(context, l.historyNeedsPlus);
    } on Object {
      if (mounted) showSnack(context, l.couldNotSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(int current) async {
    final l = context.l;
    final plus = ref.read(familyPlusProvider);
    final days = await showModalBottomSheet<int>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l.historyDaysTitle)),
            for (final d in HistorySection.choices)
              ListTile(
                key: Key('history-keep-$d'),
                leading: Icon(
                  d == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(l.historyDays(d)),
                trailing: d > freeHistoryDays && !plus
                    ? Chip(label: Text(l.plusBadge))
                    : null,
                onTap: () => Navigator.pop(sheet, d),
              ),
          ],
        ),
      ),
    );
    if (days == null || days == current || !mounted) return;
    if (days > freeHistoryDays && !plus) {
      await showNeedsPlus(context, l.historyNeedsPlus);
      return;
    }
    await _run(
      () => ref.read(historyActionsProvider).setDays(widget.spaceId, days),
    );
  }

  Future<void> _erase() async {
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.eraseMyHistory),
        content: Text(l.eraseMyHistoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('erase-history-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.erase),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref.read(historyActionsProvider).eraseMine(widget.spaceId),
      done: l.historyErased,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final days = ref.watch(historyDaysProvider(widget.spaceId)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(
            l.historyHeading,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          key: const Key('history-keep'),
          leading: const Icon(Icons.history),
          title: Text(l.historyDaysTitle),
          subtitle: Text(
            [
              if (days != null) l.historyDays(days),
              l.historyKeptBody,
              if (!widget.isOwner) l.historyOwnerOnly,
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: widget.isOwner ? const Icon(Icons.chevron_right) : null,
          onTap: widget.isOwner && days != null && !_busy
              ? () => _choose(days)
              : null,
        ),
        ListTile(
          key: const Key('erase-history'),
          leading: const Icon(Icons.delete_sweep_outlined),
          title: Text(l.eraseMyHistory),
          onTap: _busy ? null : _erase,
        ),
      ],
    );
  }
}
