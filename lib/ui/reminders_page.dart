import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zt_places/zt_places.dart';

import '../data/places.dart';
import '../data/reminders.dart';
import '../l10n/l10n.dart';
import '../location/family_event.dart';
import '../location/reminders.dart';
import 'common.dart';

/// Place reminders (L-4): "remind Dana to call me when she gets to School".
/// The reminder goes off on Dana's own phone, which tells the sender.
class RemindersPage extends ConsumerWidget {
  const RemindersPage({
    super.key,
    required this.spaceId,
    required this.members,
    required this.me,
  });

  final String spaceId;
  final List<SpaceMember> members;
  final String? me;

  static Future<void> open(
    BuildContext context, {
    required String spaceId,
    required List<SpaceMember> members,
    required String? me,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RemindersPage(spaceId: spaceId, members: members, me: me),
    ),
  );

  String _name(AppL10n l, String userId) {
    for (final m in members) {
      if (m.userId == userId) {
        final n = m.name.isEmpty ? l.unnamedMember : m.name;
        return userId == me ? l.youSuffix(n) : n;
      }
    }
    return l.unnamedMember;
  }

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final l = context.l;
    final places = await ref.read(circlePlacesProvider(spaceId).future);
    if (!context.mounted) return;
    if (places.isEmpty) {
      showSnack(context, l.reminderNeedsPlace);
      return;
    }
    final draft = await showDialog<_Draft>(
      context: context,
      builder: (_) => _NewReminderDialog(
        members: members,
        places: places,
        me: me,
        name: (id) => _name(l, id),
      ),
    );
    if (draft == null || !context.mounted) return;
    var ok = false;
    try {
      ok = await ref
          .read(reminderActionsProvider)
          .create(
            spaceId,
            to: draft.to,
            placeId: draft.placeId,
            onLeave: draft.onLeave,
            note: draft.note,
          );
    } on Object {
      ok = false;
    }
    if (!context.mounted) return;
    showSnack(context, ok ? l.reminderSent : l.reminderNotSent);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final reminders = ref.watch(circleRemindersProvider(spaceId));
    final places = {
      for (final p
          in ref.watch(circlePlacesProvider(spaceId)).value ??
              const <ZtPlace>[])
        p.id: p.name,
    };
    final list = reminders.value ?? const <OpenReminder>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('reminder-new'),
        onPressed: () => _new(context, ref),
        icon: const Icon(Icons.notification_add_outlined),
        label: Text(l.reminderNew),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(l.remindersBody),
          ),
          if (reminders.hasError)
            ListTile(title: Text(l.historyCouldNotLoad))
          else if (reminders.isLoading && list.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (list.isEmpty)
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(l.remindersEmpty),
            ),
          for (final r in list)
            ListTile(
              key: Key('reminder-${r.id}'),
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(
                r.event.note?.isNotEmpty == true
                    ? r.event.note!
                    : l.reminderNoNote,
              ),
              subtitle: Text(
                l.reminderFor(
                  _name(l, r.to),
                  r.event.onLeave
                      ? l.reminderLeaving(
                          places[r.event.placeId] ?? l.unknownPlace,
                        )
                      : l.reminderArriving(
                          places[r.event.placeId] ?? l.unknownPlace,
                        ),
                  _name(l, r.from),
                ),
              ),
              trailing: r.from == me || r.to == me
                  ? IconButton(
                      key: Key('reminder-cancel-${r.id}'),
                      tooltip: l.reminderCancel,
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        final ok = await ref
                            .read(reminderActionsProvider)
                            .cancel(spaceId, r);
                        if (context.mounted && !ok) {
                          showSnack(context, l.couldNotSend);
                        }
                      },
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Draft {
  const _Draft(this.to, this.placeId, this.onLeave, this.note);
  final String to;
  final String placeId;
  final bool onLeave;
  final String note;
}

class _NewReminderDialog extends StatefulWidget {
  const _NewReminderDialog({
    required this.members,
    required this.places,
    required this.me,
    required this.name,
  });

  final List<SpaceMember> members;
  final List<ZtPlace> places;
  final String? me;
  final String Function(String userId) name;

  @override
  State<_NewReminderDialog> createState() => _NewReminderDialogState();
}

class _NewReminderDialogState extends State<_NewReminderDialog> {
  late String _to = widget.members
      .firstWhere(
        (m) => m.userId != widget.me,
        orElse: () => widget.members.first,
      )
      .userId;
  late String _place = widget.places.first.id;
  bool _leave = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return AlertDialog(
      title: Text(l.reminderNew),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('reminder-who'),
              initialValue: _to,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.reminderWho),
              items: [
                for (final m in widget.members)
                  DropdownMenuItem(
                    value: m.userId,
                    child: Text(
                      widget.name(m.userId),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _to = v ?? _to),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('reminder-place'),
              initialValue: _place,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.reminderWhere),
              items: [
                for (final p in widget.places)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _place = v ?? _place),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('reminder-when'),
              segments: [
                ButtonSegment(value: false, label: Text(l.reminderOnArrive)),
                ButtonSegment(value: true, label: Text(l.reminderOnLeave)),
              ],
              selected: {_leave},
              onSelectionChanged: (s) => setState(() => _leave = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reminder-note'),
              controller: _note,
              maxLength: FamilyEvent.maxNote,
              decoration: InputDecoration(
                labelText: l.reminderWhat,
                hintText: l.reminderWhatHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('reminder-send'),
          onPressed: () =>
              Navigator.pop(context, _Draft(_to, _place, _leave, _note.text)),
          child: Text(l.send),
        ),
      ],
    );
  }
}
