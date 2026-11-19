import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'family_event.dart';
import 'location_backend.dart';
import 'location_box.dart';

/// What this phone needs to show one circle's alerts while the app is
/// locked: the circle's box seeds (they open only this circle's location
/// updates and events), which device keys speak for whom, and the names of
/// people and places. Kept in the Android Keystore, outside the vault, and
/// only for circles the person opted in for (plan decision 2, option A).
class AlertCircle {
  const AlertCircle({
    required this.spaceId,
    this.boxes = const {},
    this.devices = const {},
    this.names = const {},
    this.places = const {},
    this.muted = const {},
    required this.cursor,
    this.seen = const [],
    this.timers = const {},
  });

  final String spaceId;

  /// Key epoch → box seed.
  final Map<int, Uint8List> boxes;

  /// `userId/deviceId` → Ed25519 public key.
  final Map<String, Uint8List> devices;

  /// userId → name, placeId → name.
  final Map<String, String> names;
  final Map<String, String> places;

  /// People this phone doesn't want alerts about.
  final Set<String> muted;

  /// The newest event already looked at (server time).
  final DateTime cursor;

  /// Ids of the latest events shown, so none is shown twice.
  final List<String> seen;

  /// Members' running safety timers (userId → deadline), watched here too,
  /// so a missed one alerts even if the member's phone is off. A deadline
  /// already alerted on is kept (marked) until the member checks in.
  final Map<String, ({DateTime until, bool alerted})> timers;

  static const maxSeen = 200;

  AlertCircle copyWith({
    Map<int, Uint8List>? boxes,
    Map<String, Uint8List>? devices,
    Map<String, String>? names,
    Map<String, String>? places,
    Set<String>? muted,
    DateTime? cursor,
    List<String>? seen,
    Map<String, ({DateTime until, bool alerted})>? timers,
  }) => AlertCircle(
    spaceId: spaceId,
    boxes: boxes ?? this.boxes,
    devices: devices ?? this.devices,
    names: names ?? this.names,
    places: places ?? this.places,
    muted: muted ?? this.muted,
    cursor: cursor ?? this.cursor,
    seen: seen ?? this.seen,
    timers: timers ?? this.timers,
  );

  Map<String, Object?> toJson() => {
    'space': spaceId,
    'boxes': {
      for (final e in boxes.entries) '${e.key}': ZtBase64.encode(e.value),
    },
    'devices': {
      for (final e in devices.entries) e.key: ZtBase64.encode(e.value),
    },
    'names': names,
    'places': places,
    'muted': muted.toList(),
    'cursor': cursor.toUtc().toIso8601String(),
    'seen': seen,
    'timers': {
      for (final e in timers.entries)
        e.key: {
          'until': e.value.until.toUtc().toIso8601String(),
          if (e.value.alerted) 'alerted': true,
        },
    },
  };

  static AlertCircle fromJson(Map<String, Object?> j) {
    Map<String, Object?> map(String k) =>
        ((j[k] as Map?) ?? const {}).cast<String, Object?>();
    return AlertCircle(
      spaceId: j['space']! as String,
      boxes: {
        for (final e in map('boxes').entries)
          if (int.tryParse(e.key) != null && e.value is String)
            int.parse(e.key): ZtBase64.decode(e.value! as String),
      },
      devices: {
        for (final e in map('devices').entries)
          if (e.value is String) e.key: ZtBase64.decode(e.value! as String),
      },
      names: {
        for (final e in map('names').entries)
          if (e.value is String) e.key: e.value! as String,
      },
      places: {
        for (final e in map('places').entries)
          if (e.value is String) e.key: e.value! as String,
      },
      muted: {
        for (final m in (j['muted'] as List? ?? const []))
          if (m is String) m,
      },
      cursor:
          DateTime.tryParse(j['cursor'] as String? ?? '') ??
          DateTime.now().toUtc(),
      seen: [
        for (final s in (j['seen'] as List? ?? const []))
          if (s is String) s,
      ],
      timers: {
        for (final e in map('timers').entries)
          if (e.value is Map &&
              DateTime.tryParse((e.value! as Map)['until'] as String? ?? '') !=
                  null)
            e.key: (
              until: DateTime.parse((e.value! as Map)['until'] as String),
              alerted: (e.value! as Map)['alerted'] == true,
            ),
      },
    );
  }
}

/// Quiet hours: alerts arrive silently between [startMinute] and
/// [endMinute] (minutes after local midnight; may wrap past midnight).
class QuietHours {
  const QuietHours(this.startMinute, this.endMinute);
  final int startMinute;
  final int endMinute;

  static const standard = QuietHours(22 * 60, 7 * 60);

  bool at(DateTime localTime) {
    final m = localTime.hour * 60 + localTime.minute;
    if (startMinute == endMinute) return false;
    return startMinute < endMinute
        ? m >= startMinute && m < endMinute
        : m >= startMinute || m < endMinute;
  }

  Map<String, Object?> toJson() => {'s': startMinute, 'e': endMinute};

  static QuietHours? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['s'];
    final e = j['e'];
    if (s is! int || e is! int) return null;
    if (s < 0 || s >= 1440 || e < 0 || e >= 1440) return null;
    return QuietHours(s, e);
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}

/// This phone's alert settings.
class AlertState {
  const AlertState({required this.userId, this.circles = const {}, this.quiet});

  /// The account that set them up; another account signing in drops them.
  final String userId;
  final Map<String, AlertCircle> circles;
  final QuietHours? quiet;

  bool get on => circles.isNotEmpty;

  AlertState copyWith({
    Map<String, AlertCircle>? circles,
    QuietHours? Function()? quiet,
  }) => AlertState(
    userId: userId,
    circles: circles ?? this.circles,
    quiet: quiet == null ? this.quiet : quiet(),
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'user': userId,
    'circles': [for (final c in circles.values) c.toJson()],
    if (quiet != null) 'quiet': quiet!.toJson(),
  };

  static AlertState fromJson(Map<String, Object?> j) => AlertState(
    userId: j['user']! as String,
    circles: {
      for (final c in (j['circles'] as List? ?? const []))
        if (c is Map)
          c['space'] as String: AlertCircle.fromJson(c.cast<String, Object?>()),
    },
    quiet: QuietHours.fromJson(j['quiet']),
  );
}

abstract class AlertStore {
  Future<AlertState?> load();
  Future<void> save(AlertState state);
  Future<void> clear();
}

class SecureAlertStore implements AlertStore {
  SecureAlertStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'zt_family_alerts'),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'alerts';

  @override
  Future<AlertState?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return AlertState.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null; // Unreadable (restored to another phone): no alerts.
    }
  }

  @override
  Future<void> save(AlertState state) =>
      _storage.write(key: _key, value: jsonEncode(state.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryAlertStore implements AlertStore {
  InMemoryAlertStore([this.state]);
  AlertState? state;

  @override
  Future<AlertState?> load() async => state;

  @override
  Future<void> save(AlertState state) async => this.state = state;

  @override
  Future<void> clear() async => state = null;
}

/// One alert to show: "Dana arrived at School".
class AlertHit {
  const AlertHit({
    required this.spaceId,
    required this.eventId,
    required this.userId,
    required this.name,
    required this.placeName,
    required this.event,
    required this.quiet,
  });

  final String spaceId;
  final String eventId;
  final String userId;
  final String name;

  /// Null when the place was removed or hasn't synced to this phone.
  final String? placeName;
  final FamilyEvent event;

  /// Inside quiet hours: shown without sound.
  final bool quiet;

  /// SOS or a missed safety timer: loud, past quiet hours.
  bool get urgent =>
      event.kind == FamilyEventKind.sos ||
      event.kind == FamilyEventKind.overdue;

  /// Someone asked this phone's person to check in: the notification gets
  /// an "I'm OK" button.
  bool get asksMe => event.kind == FamilyEventKind.ask;

  /// A stable notification id for this event.
  int get notificationId => eventId.hashCode & 0x3fffffff;
}

/// Reads new events of the circles this phone has alerts on, while locked.
///
/// Only events signed by a device its member published, sealed for this
/// circle and bound to their row are shown; anything else is skipped, as
/// are this account's own events, muted people, repeats and events older
/// than [maxAge] (a phone that was off all day doesn't ring for each one).
class AlertEngine {
  AlertEngine({
    required this.store,
    required this.backend,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AlertStore store;
  final LocationBackend backend;
  final DateTime Function() _clock;

  static const maxAge = Duration(hours: 2);

  static const pageSize = 100;
  static const maxPages = 10;

  Future<void> _queue = Future.value();

  /// One check at a time (realtime and the service can ask together).
  Future<List<AlertHit>> check() {
    final done = _queue.then((_) => _check());
    _queue = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<List<AlertHit>> _check() async {
    final state = await store.load();
    if (state == null || !state.on) return const [];
    final me = backend.userId;
    if (me == null || me != state.userId) {
      // Signed out or another account: these alerts aren't theirs.
      await store.clear();
      return const [];
    }
    final now = _clock();
    final quiet = state.quiet?.at(now.toLocal()) ?? false;
    final hits = <AlertHit>[];
    final circles = <String, AlertCircle>{};
    for (final circle in state.circles.values) {
      final rows = <LocationRow>[];
      try {
        // Page through: history points can fill a page.
        var since = circle.cursor;
        for (var page = 0; page < maxPages; page++) {
          final got = await backend.events(
            circle.spaceId,
            since: since,
            limit: pageSize,
          );
          rows.addAll(got);
          final last = got.lastOrNull?.sentAt;
          if (got.length < pageSize || last == null) break;
          since = last;
        }
      } on SignedOutException {
        await store.clear();
        return const [];
      } on Object {
        circles[circle.spaceId] = circle; // Offline: next time.
        continue;
      }
      var cursor = circle.cursor;
      final seen = [...circle.seen];
      final boxes = <int, SimpleKeyPair>{};
      final timers = {...circle.timers};
      AlertHit hit(String userId, FamilyEvent event) => AlertHit(
        spaceId: circle.spaceId,
        eventId: event.id,
        userId: userId,
        name: circle.names[userId] ?? '',
        placeName: event.placeId == null ? null : circle.places[event.placeId],
        event: event,
        quiet: quiet,
      );
      for (final row in rows) {
        final sentAt = row.sentAt;
        if (sentAt != null && sentAt.isAfter(cursor)) cursor = sentAt;
        if (row.userId == me) continue;
        final event = await _open(circle, row, boxes);
        if (event == null) continue;
        // History points never alert, and are too many to remember.
        if (event.kind == FamilyEventKind.point) continue;
        if (seen.contains(event.id)) continue;
        seen.add(event.id);
        // Timers are followed even for muted people: a missed one alerts.
        final had = timers[row.userId];
        switch (event.kind) {
          case FamilyEventKind.timer when event.until != null:
            timers[row.userId] = (until: event.until!, alerted: false);
          case FamilyEventKind.checkin ||
              FamilyEventKind.timerEnd ||
              FamilyEventKind.overdue:
            timers.remove(row.userId);
          default:
        }
        if (now.difference(event.at) > maxAge) continue;
        final urgent =
            event.kind == FamilyEventKind.sos ||
            event.kind == FamilyEventKind.overdue;
        // This phone already alerted on the missed timer by itself.
        if (event.kind == FamilyEventKind.overdue && had?.alerted == true) {
          continue;
        }
        if (event.kind == FamilyEventKind.ask && event.to != me) continue;
        // Whoever got the SOS also hears that it ended.
        if (!urgent &&
            event.kind != FamilyEventKind.ask &&
            event.kind != FamilyEventKind.sosEnd &&
            circle.muted.contains(row.userId)) {
          continue;
        }
        hits.add(hit(row.userId, event));
      }
      // A timer that ran out with no word from its phone.
      for (final e in [...timers.entries]) {
        if (e.value.alerted || now.isBefore(e.value.until)) continue;
        timers[e.key] = (until: e.value.until, alerted: true);
        if (now.difference(e.value.until) > maxAge) continue;
        hits.add(
          hit(
            e.key,
            FamilyEvent(
              id: 'late-${e.key}-${e.value.until.millisecondsSinceEpoch}',
              kind: FamilyEventKind.overdue,
              at: e.value.until,
              until: e.value.until,
            ),
          ),
        );
      }
      circles[circle.spaceId] = circle.copyWith(
        cursor: cursor,
        timers: timers,
        seen: seen.length > AlertCircle.maxSeen
            ? seen.sublist(seen.length - AlertCircle.maxSeen)
            : seen,
      );
    }
    // Settings may have changed while this ran: keep theirs, move cursors.
    final latest = await store.load();
    if (latest != null && latest.userId == state.userId) {
      await store.save(
        latest.copyWith(
          circles: {
            for (final c in latest.circles.values)
              c.spaceId: circles[c.spaceId] == null
                  ? c
                  : c.copyWith(
                      cursor: circles[c.spaceId]!.cursor,
                      seen: circles[c.spaceId]!.seen,
                      timers: circles[c.spaceId]!.timers,
                    ),
          },
        ),
      );
    }
    return hits;
  }

  static Future<FamilyEvent?> _open(
    AlertCircle circle,
    LocationRow row,
    Map<int, SimpleKeyPair> boxes,
  ) => openEvent(
    row,
    devicePublic: circle.devices['${row.userId}/${row.deviceId}'],
    box: (epoch) async {
      if (boxes.containsKey(epoch)) return boxes[epoch];
      final seed = circle.boxes[epoch];
      if (seed == null) return null;
      return boxes[epoch] = await LocationBox.fromSeed(seed);
    },
  );
}

/// Opens one `family_events` row, or null when it isn't genuine (unknown
/// device, bad signature, moved between rows, no key for its epoch) or
/// isn't an event this version knows.
Future<FamilyEvent?> openEvent(
  LocationRow row, {
  required Uint8List? devicePublic,
  required Future<SimpleKeyPair?> Function(int epoch) box,
}) async {
  if (devicePublic == null) return null;
  final context = LocationBox.context(
    table: 'family_events',
    spaceId: row.spaceId,
    userId: row.userId,
    deviceId: row.deviceId,
    epoch: row.epoch,
  );
  try {
    final ok = await Signing.verify(
      LocationBox.signedBytes(context, row.payload),
      signature: row.signature,
      publicKey: devicePublic,
    );
    if (!ok) return null;
    final key = await box(row.epoch);
    if (key == null) return null;
    return FamilyEvent.decode(
      await LocationBox.open(row.payload, box: key, context: context),
    );
  } on Object {
    return null;
  }
}
