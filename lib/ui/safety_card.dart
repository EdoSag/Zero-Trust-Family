import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/locations.dart';
import '../l10n/l10n.dart';
import '../location/family_event.dart';
import 'common.dart';

/// Check-ins, the safety timer and SOS for one circle. They go out with
/// this phone's location, so they need sharing on for the circle.
class SafetyCard extends ConsumerStatefulWidget {
  const SafetyCard({
    super.key,
    required this.spaceId,
    required this.members,
    required this.me,
  });

  final String spaceId;
  final List<SpaceMember> members;
  final String? me;

  @override
  ConsumerState<SafetyCard> createState() => _SafetyCardState();
}

class _SafetyCardState extends ConsumerState<SafetyCard> {
  bool _busy = false;

  Future<void> _send(
    Future<bool> Function(ShareActions a) run, {
    required String done,
  }) async {
    final l = context.l;
    setState(() => _busy = true);
    var sent = false;
    try {
      sent = await run(ref.read(shareActionsProvider));
    } on Object {
      sent = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, sent ? done : l.couldNotSend);
  }

  Future<void> _checkIn() async {
    final l = context.l;
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(l: l),
    );
    if (note == null) return;
    await _send(
      (a) => a.checkIn(widget.spaceId, note: note),
      done: l.checkinSent,
    );
  }

  Future<void> _ask() async {
    final l = context.l;
    final others = [
      for (final m in widget.members)
        if (m.userId != widget.me) m,
    ];
    final who = await showModalBottomSheet<SpaceMember>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l.askWho)),
            for (final m in others)
              ListTile(
                key: Key('ask-${m.userId}'),
                leading: MemberAvatar(name: m.name),
                title: Text(m.name.isEmpty ? l.unnamedMember : m.name),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (who == null) return;
    await _send(
      (a) => a.askCheckIn(widget.spaceId, who.userId),
      done: l.askSent(who.name.isEmpty ? l.unnamedMember : who.name),
    );
  }

  Future<void> _timer() async {
    final l = context.l;
    final now = DateTime.now();
    final until = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l.timerQuestion)),
            for (final minutes in const [30, 60, 120])
              ListTile(
                key: Key('timer-$minutes'),
                leading: const Icon(Icons.timer_outlined),
                title: Text(
                  minutes < 60
                      ? l.timerInMinutes(minutes)
                      : l.timerInHours(minutes ~/ 60),
                ),
                onTap: () =>
                    Navigator.pop(context, now.add(Duration(minutes: minutes))),
              ),
            ListTile(
              key: const Key('timer-pick'),
              leading: const Icon(Icons.schedule),
              title: Text(l.timerPick),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    now.add(const Duration(hours: 1)),
                  ),
                );
                if (t == null || !context.mounted) return;
                var at = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  t.hour,
                  t.minute,
                );
                if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
                Navigator.pop(context, at);
              },
            ),
          ],
        ),
      ),
    );
    if (until == null) return;
    await _send(
      (a) => a.startTimer(widget.spaceId, until),
      done: l.timerStarted(DateFormat.Hm(l.localeName).format(until)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final state = ref.watch(shareStateProvider).value;
    final sharing = state?.sharesWith(widget.spaceId) ?? false;
    final timer = state?.timer;
    final sos = state?.sos;
    final hm = DateFormat.Hm(l.localeName);
    return Card(
      key: const Key('safety-card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.safetyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (!sharing) ...[
              Text(l.safetyNeedsSharing),
            ] else ...[
              if (sos != null)
                _Banner(
                  key: const Key('sos-active'),
                  color: theme.colorScheme.errorContainer,
                  text: l.sosActive,
                  action: l.imSafe,
                  actionKey: const Key('sos-end'),
                  onAction: _busy
                      ? null
                      : () => _send((a) => a.endSos(), done: l.sosEnded),
                ),
              if (timer != null && timer.spaceId == widget.spaceId)
                _Banner(
                  key: const Key('timer-active'),
                  color: theme.colorScheme.secondaryContainer,
                  text: l.timerActive(hm.format(timer.until.toLocal())),
                  action: l.imOk,
                  actionKey: const Key('timer-ok'),
                  onAction: _busy
                      ? null
                      : () => _send((a) => a.endTimer(), done: l.timerEnded),
                ),
              Text(l.safetyBody),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('checkin'),
                onPressed: _busy ? null : _checkIn,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(l.checkinButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('ask'),
                onPressed: _busy ? null : _ask,
                icon: const Icon(Icons.help_outline),
                label: Text(l.askButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('timer'),
                onPressed: _busy || timer != null ? null : _timer,
                icon: const Icon(Icons.timer_outlined),
                label: Text(l.timerButton),
              ),
              const SizedBox(height: 12),
              _SosButton(
                enabled: !_busy && sos == null,
                onSend: () =>
                    _send((a) => a.startSos(widget.spaceId), done: l.sosSent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.color,
    required this.text,
    required this.action,
    required this.actionKey,
    required this.onAction,
  });

  final Color color;
  final String text;
  final String action;
  final Key actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text),
        const SizedBox(height: 8),
        FilledButton(key: actionKey, onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}

/// SOS goes out only after holding the button for [hold], so a pocket or a
/// stray tap doesn't send it. A tap says so.
class _SosButton extends StatefulWidget {
  const _SosButton({required this.enabled, required this.onSend});

  final bool enabled;
  final VoidCallback onSend;

  static const hold = Duration(seconds: 2);

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    duration: _SosButton.hold,
  );

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _progress.reset();
        widget.onSend();
      }
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const Key('sos'),
      onTapDown: widget.enabled ? (_) => _progress.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              if (_progress.isAnimating) {
                _progress.reset();
                showSnack(context, l.sosHoldHint);
              }
            }
          : null,
      onTapCancel: () {
        if (_progress.isAnimating) _progress.reset();
      },
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.enabled
                ? scheme.error
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: _progress.value,
                  child: ColoredBox(
                    color: scheme.onError.withValues(alpha: 0.25),
                  ),
                ),
              ),
              Text(
                l.sosButton,
                style: TextStyle(
                  color: widget.enabled
                      ? scheme.onError
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.l});
  final AppL10n l;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      title: Text(l.checkinTitle),
      content: TextField(
        key: const Key('checkin-note'),
        controller: _note,
        maxLength: FamilyEvent.maxNote,
        decoration: InputDecoration(
          labelText: l.checkinNote,
          hintText: l.checkinNoteHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('checkin-send'),
          onPressed: () => Navigator.pop(context, _note.text),
          child: Text(l.send),
        ),
      ],
    );
  }
}
