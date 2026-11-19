import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/history.dart';
import '../data/places.dart';
import '../l10n/event_text.dart';
import '../l10n/l10n.dart';
import '../location/timeline.dart';
import 'places_section.dart' show eventIcon;

/// "3 h 5 min" or "40 min".
String durationText(AppL10n l, Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return l.durationMinutes(minutes);
  return l.durationHours(minutes ~/ 60, minutes % 60);
}

/// "850 m" or "3.2 km".
String distanceText(AppL10n l, double meters) {
  if (meters < 1000) return l.meters((meters / 10).round() * 10);
  return l.kilometers(NumberFormat('0.0', l.localeName).format(meters / 1000));
}

/// One member's history in a circle, a day at a time, for as many days as
/// the circle keeps.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({
    super.key,
    required this.spaceId,
    required this.userId,
    required this.name,
  });

  final String spaceId;
  final String userId;
  final String name;

  static Future<void> open(
    BuildContext context, {
    required String spaceId,
    required String userId,
    required String name,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => HistoryPage(spaceId: spaceId, userId: userId, name: name),
    ),
  );

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _back = 0;

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  String _dayLabel(AppL10n l, int back, DateTime day) => switch (back) {
    0 => l.historyToday,
    1 => l.historyYesterday,
    _ => DateFormat.MMMEd(l.localeName).format(day),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final days =
        ref.watch(historyDaysProvider(widget.spaceId)).value ??
        freeHistoryDaysShown;
    final today = _midnight(DateTime.now());
    final back = _back.clamp(0, days - 1);
    final day = DateTime(today.year, today.month, today.day - back);
    final entries = ref.watch(
      memberHistoryProvider((
        spaceId: widget.spaceId,
        userId: widget.userId,
        day: day,
      )),
    );
    final places = {
      for (final p
          in ref.watch(circlePlacesProvider(widget.spaceId)).value ?? const [])
        p.id: p.name,
    };
    final hm = DateFormat.Hm(l.localeName);
    return Scaffold(
      appBar: AppBar(title: Text(l.historyOf(widget.name))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              key: const Key('history-days'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (var i = 0; i < days; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: Key('history-day-$i'),
                      label: Text(
                        _dayLabel(
                          l,
                          i,
                          DateTime(today.year, today.month, today.day - i),
                        ),
                      ),
                      selected: i == back,
                      onSelected: (_) => setState(() => _back = i),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l.historyCouldNotLoad,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l.historyEmpty,
                          key: const Key('history-empty'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      key: const Key('history-list'),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final (i, e) in list.indexed)
                          switch (e) {
                            Stop() => ListTile(
                              key: Key('history-$i'),
                              leading: Icon(
                                e.placeId != null
                                    ? Icons.place
                                    : Icons.place_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                places[e.placeId] != null
                                    ? l.historyAt(places[e.placeId]!)
                                    : l.historyStayed,
                              ),
                              subtitle: Text(
                                e.ongoing
                                    ? l.historySince(
                                        hm.format(e.start.toLocal()),
                                      )
                                    : l.historyRange(
                                        hm.format(e.start.toLocal()),
                                        hm.format(e.end.toLocal()),
                                        durationText(l, e.length),
                                      ),
                              ),
                            ),
                            Move() => ListTile(
                              key: Key('history-$i'),
                              dense: true,
                              leading: const Icon(Icons.more_vert),
                              title: Text(
                                l.historyMoved(
                                  distanceText(l, e.meters),
                                  durationText(l, e.length),
                                ),
                              ),
                            ),
                            Moment() => ListTile(
                              key: Key('history-$i'),
                              leading: Icon(eventIcon(e.event.kind)),
                              title: Text(
                                eventLine(
                                  l,
                                  widget.name,
                                  places[e.event.placeId],
                                  e.event,
                                ),
                              ),
                              subtitle: Text(hm.format(e.event.at.toLocal())),
                            ),
                          },
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Days shown before the circle's setting loads.
const freeHistoryDaysShown = 7;
