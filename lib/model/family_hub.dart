import 'package:zero_trust_core/zero_trust_core.dart';

/// One item another app keeps in the circle (S-10), as the hub shows it.
class HubItem {
  const HubItem({
    required this.itemId,
    required this.app,
    required this.summary,
  });

  final String itemId;

  /// `calendar`, `tasks`, `meds`, ...
  final String app;
  final ZtFamilySummary summary;

  String get title => summary.title;
  bool get done => summary.done ?? false;

  /// When it happens, else when it's due.
  DateTime? get when => summary.at ?? summary.due;
}

/// A ZT Tasks list in the circle (shopping, chores) with its open items.
class HubList {
  const HubList({
    required this.id,
    required this.title,
    required this.open,
    required this.doneCount,
  });

  /// The list's item id, or null for tasks that name no list.
  final String? id;

  /// Null when the list item isn't in the circle (or tasks name no list).
  final String? title;
  final List<HubItem> open;
  final int doneCount;
}

/// L-2: the circle's shared calendar, lists and medicines in one place,
/// read from the items the suite's apps keep in the family circle.
class FamilyHub {
  const FamilyHub({
    this.comingUp = const [],
    this.lists = const [],
    this.medsToday = const [],
    this.other = const [],
  });

  /// Calendar events from the start of today, for [days] days, soonest
  /// first.
  final List<HubItem> comingUp;

  /// Task lists, those with open items first, then by name.
  final List<HubList> lists;

  /// Today's medicine doses, by time.
  final List<HubItem> medsToday;

  /// Items of other apps, soonest first.
  final List<HubItem> other;

  bool get isEmpty =>
      comingUp.isEmpty && lists.isEmpty && medsToday.isEmpty && other.isEmpty;

  static const days = 14;

  static const calendar = 'calendar';
  static const tasks = 'tasks';
  static const meds = 'meds';

  /// Builds the hub from a circle's items. ZT Family's own items, deleted
  /// ones, and items without a summary are left out. [now] is local time.
  static FamilyHub of(Iterable<LocalItem> items, DateTime now) {
    final all = <HubItem>[];
    for (final item in items) {
      if (item.deleted) continue;
      final app = ZtFamilySpace.appOf(item.itemId);
      if (app == null) continue;
      final summary = ZtFamilySummary.of(item.json);
      if (summary == null) continue;
      all.add(HubItem(itemId: item.itemId, app: app, summary: summary));
    }

    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final horizon = DateTime(now.year, now.month, now.day + days);
    int bySoonest(HubItem a, HubItem b) {
      final wa = a.when, wb = b.when;
      if (wa == null && wb == null) return a.title.compareTo(b.title);
      if (wa == null) return 1;
      if (wb == null) return -1;
      final c = wa.compareTo(wb);
      return c != 0 ? c : a.title.compareTo(b.title);
    }

    final comingUp = <HubItem>[];
    final medsToday = <HubItem>[];
    final other = <HubItem>[];
    final listTitles = <String, String>{};
    final listItems = <String?, List<HubItem>>{};
    for (final i in all) {
      switch (i.app) {
        case calendar:
          final at = i.summary.at?.toLocal();
          if (at != null && !at.isBefore(today) && at.isBefore(horizon)) {
            comingUp.add(i);
          }
        case tasks:
          if (i.summary.kind == 'tasks.list') {
            listTitles[i.itemId] = i.title;
          } else {
            (listItems[i.summary.list] ??= []).add(i);
          }
        case meds:
          final at = i.summary.at?.toLocal();
          if (at != null && !at.isBefore(today) && at.isBefore(tomorrow)) {
            medsToday.add(i);
          }
        default:
          other.add(i);
      }
    }

    final lists = <HubList>[
      for (final id in {...listTitles.keys, ...listItems.keys})
        HubList(
          id: id,
          title: id == null ? null : listTitles[id],
          open: [
            for (final i in listItems[id] ?? const <HubItem>[])
              if (!i.done) i,
          ]..sort(bySoonest),
          doneCount: (listItems[id] ?? const <HubItem>[])
              .where((i) => i.done)
              .length,
        ),
    ];
    lists.sort((a, b) {
      final byOpen = (b.open.isNotEmpty ? 1 : 0) - (a.open.isNotEmpty ? 1 : 0);
      if (byOpen != 0) return byOpen;
      // Tasks that name no list go last.
      if (a.title == null || b.title == null) {
        return a.title == null ? (b.title == null ? 0 : 1) : -1;
      }
      return a.title!.toLowerCase().compareTo(b.title!.toLowerCase());
    });

    return FamilyHub(
      comingUp: comingUp..sort(bySoonest),
      lists: lists,
      medsToday: medsToday..sort(bySoonest),
      other: other..sort(bySoonest),
    );
  }
}
