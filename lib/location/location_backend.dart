import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of `family_latest` (a device's newest sealed update) or of
/// `family_events` (one arrival, departure, and later check-ins and SOS).
class LocationRow {
  const LocationRow({
    required this.spaceId,
    required this.userId,
    required this.deviceId,
    required this.epoch,
    required this.payload,
    required this.signature,
    this.sentAt,
  });

  final String spaceId;
  final String userId;
  final String deviceId;
  final int epoch;
  final Uint8List payload;
  final Uint8List signature;

  /// Set by the server.
  final DateTime? sentAt;
}

/// The circle's key changed since this phone last opened the app.
class StaleKeyException implements Exception {
  const StaleKeyException();
}

/// This account is no longer in the circle (or it was deleted).
class NotInCircleException implements Exception {
  const NotInCircleException();
}

/// Nobody is signed in on this phone.
class SignedOutException implements Exception {
  const SignedOutException();
}

/// Where sealed location updates go: `family_latest` (Core migration
/// `20261118120000_family_location_tables`).
abstract class LocationBackend {
  /// The signed-in account, or null.
  String? get userId;

  Future<void> putLatest(LocationRow row);
  Future<void> deleteLatest({
    required String spaceId,
    required String deviceId,
  });
  Future<List<LocationRow>> latest(String spaceId);

  /// Fires when a circle's rows change (realtime), while listened to.
  Stream<void> changes(String spaceId);

  /// Adds one sealed event to `family_events`.
  Future<void> insertEvent(LocationRow row);

  /// A circle's events sent after [since], oldest first (at most [limit]).
  /// [newestFirst] gives the newest [limit] instead, newest first.
  Future<List<LocationRow>> events(
    String spaceId, {
    required DateTime since,
    int limit = 100,
    bool newestFirst = false,
  });

  /// Fires when someone adds an event to one of [spaceIds] (realtime).
  Stream<void> eventInserts(List<String> spaceIds);

  /// One member's events from [from] to [to], oldest first: their history.
  Future<List<LocationRow>> memberEvents(
    String spaceId,
    String userId, {
    required DateTime from,
    required DateTime to,
    int limit = 2000,
  });

  /// Erases every event this account sent to [spaceId].
  Future<void> eraseMyEvents(String spaceId);

  /// How many days the circle keeps history (7 when never set).
  Future<int> historyDays(String spaceId);

  /// Sets it (owners only; over 7 days needs Plus).
  Future<void> setHistoryDays(String spaceId, int days);

  /// Puts a trip share's sealed update (`family_trip_shares`, Core
  /// migration `family_trip_shares`), shown until [expiresAt].
  Future<void> putTrip({
    required String id,
    required String payload,
    required DateTime expiresAt,
  });

  /// Takes a trip share off the server (nothing if it's gone already).
  Future<void> deleteTrip(String id);
}

/// The trip share ended on the server (its time ran out).
class TripEndedException implements Exception {
  const TripEndedException();
}

/// Over 7 days of history without Plus.
class NeedsPlusException implements Exception {
  const NeedsPlusException();
}

/// Days of history a circle keeps when nobody chose.
const defaultHistoryDays = 7;

/// The most days of history without Plus.
const freeHistoryDays = 7;

class SupabaseLocationBackend implements LocationBackend {
  SupabaseLocationBackend([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  @override
  String? get userId => client.auth.currentUser?.id;

  /// The background service may run for hours with the app closed, so the
  /// session is refreshed here before it expires. This is the only client
  /// in the app, so there's no second copy of the refresh token to race.
  Future<void> _fresh() async {
    final session = client.auth.currentSession;
    if (session == null) throw const SignedOutException();
    final expiresAt = session.expiresAt;
    final soon = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
    if (expiresAt == null || expiresAt < soon) {
      try {
        await client.auth.refreshSession();
      } on AuthException catch (e) {
        if (e.statusCode == '400' || e.statusCode == '401') {
          throw const SignedOutException();
        }
        rethrow;
      }
    }
  }

  @override
  Future<void> putLatest(LocationRow row) async {
    await _fresh();
    try {
      await client.from('family_latest').upsert({
        'space_id': row.spaceId,
        'user_id': row.userId,
        'device_id': row.deviceId,
        'key_epoch': row.epoch,
        'payload': _toHex(row.payload),
        'signature': _toHex(row.signature),
      }, onConflict: 'space_id,user_id,device_id');
    } on PostgrestException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> deleteLatest({
    required String spaceId,
    required String deviceId,
  }) async {
    await _fresh();
    final me = userId;
    if (me == null) throw const SignedOutException();
    await client
        .from('family_latest')
        .delete()
        .eq('space_id', spaceId)
        .eq('user_id', me)
        .eq('device_id', deviceId);
  }

  @override
  Future<List<LocationRow>> latest(String spaceId) async {
    final rows = await client
        .from('family_latest')
        .select(
          'space_id,user_id,device_id,key_epoch,payload,signature,sent_at',
        )
        .eq('space_id', spaceId);
    return [for (final r in rows) _row(r)];
  }

  @override
  Stream<void> changes(String spaceId) {
    late final StreamController<void> out;
    RealtimeChannel? channel;
    out = StreamController<void>(
      onListen: () {
        channel = client
            .channel('family_latest:$spaceId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'family_latest',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'space_id',
                value: spaceId,
              ),
              callback: (_) => out.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        final c = channel;
        channel = null;
        if (c != null) await client.removeChannel(c);
      },
    );
    return out.stream;
  }

  @override
  Future<void> insertEvent(LocationRow row) async {
    await _fresh();
    try {
      await client.from('family_events').insert({
        'space_id': row.spaceId,
        'user_id': row.userId,
        'device_id': row.deviceId,
        'key_epoch': row.epoch,
        'payload': _toHex(row.payload),
        'signature': _toHex(row.signature),
      });
    } on PostgrestException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<LocationRow>> events(
    String spaceId, {
    required DateTime since,
    int limit = 100,
    bool newestFirst = false,
  }) async {
    await _fresh();
    final rows = await client
        .from('family_events')
        .select(
          'space_id,user_id,device_id,key_epoch,payload,signature,sent_at',
        )
        .eq('space_id', spaceId)
        .gt('sent_at', since.toUtc().toIso8601String())
        .order('sent_at', ascending: !newestFirst)
        .limit(limit);
    return [for (final r in rows) _row(r)];
  }

  @override
  Future<List<LocationRow>> memberEvents(
    String spaceId,
    String userId, {
    required DateTime from,
    required DateTime to,
    int limit = 2000,
  }) async {
    await _fresh();
    final rows = await client
        .from('family_events')
        .select(
          'space_id,user_id,device_id,key_epoch,payload,signature,sent_at',
        )
        .eq('space_id', spaceId)
        .eq('user_id', userId)
        .gte('sent_at', from.toUtc().toIso8601String())
        .lt('sent_at', to.toUtc().toIso8601String())
        .order('sent_at')
        .limit(limit);
    return [for (final r in rows) _row(r)];
  }

  @override
  Future<void> eraseMyEvents(String spaceId) async {
    await _fresh();
    final me = userId;
    if (me == null) throw const SignedOutException();
    await client
        .from('family_events')
        .delete()
        .eq('space_id', spaceId)
        .eq('user_id', me);
  }

  @override
  Future<void> putTrip({
    required String id,
    required String payload,
    required DateTime expiresAt,
  }) async {
    await _fresh();
    try {
      await client.from('family_trip_shares').upsert({
        'id': id,
        'payload': payload,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      }, onConflict: 'id');
    } on PostgrestException catch (e) {
      if (e.message.contains('family_trip_ended')) {
        throw const TripEndedException();
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    await _fresh();
    await client.from('family_trip_shares').delete().eq('id', id);
  }

  @override
  Future<int> historyDays(String spaceId) async {
    await _fresh();
    final row = await client
        .from('family_settings')
        .select('history_days')
        .eq('space_id', spaceId)
        .maybeSingle();
    return (row?['history_days'] as num?)?.toInt() ?? defaultHistoryDays;
  }

  @override
  Future<void> setHistoryDays(String spaceId, int days) async {
    await _fresh();
    try {
      await client.rpc<void>(
        'family_set_history_days',
        params: {'p_space': spaceId, 'p_days': days},
      );
    } on PostgrestException catch (e) {
      if ('${e.message} ${e.details ?? ''}'.contains('family_needs_plus')) {
        throw const NeedsPlusException();
      }
      throw _map(e);
    }
  }

  @override
  Stream<void> eventInserts(List<String> spaceIds) {
    late final StreamController<void> out;
    final channels = <RealtimeChannel>[];
    out = StreamController<void>(
      onListen: () {
        for (final id in spaceIds) {
          channels.add(
            client
                .channel('family_events:$id')
                .onPostgresChanges(
                  event: PostgresChangeEvent.insert,
                  schema: 'public',
                  table: 'family_events',
                  filter: PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'space_id',
                    value: id,
                  ),
                  callback: (_) => out.add(null),
                )
                .subscribe(),
          );
        }
      },
      onCancel: () async {
        final all = [...channels];
        channels.clear();
        for (final c in all) {
          await client.removeChannel(c);
        }
      },
    );
    return out.stream;
  }

  static LocationRow _row(Map<String, dynamic> r) => LocationRow(
    spaceId: r['space_id'] as String,
    userId: r['user_id'] as String,
    deviceId: r['device_id'] as String,
    epoch: r['key_epoch'] as int,
    payload: _fromHex(r['payload'] as String),
    signature: _fromHex(r['signature'] as String),
    sentAt: DateTime.tryParse(r['sent_at'] as String? ?? ''),
  );

  static Exception _map(PostgrestException e) {
    final text = '${e.message} ${e.details ?? ''}';
    if (text.contains('zt_space_key_stale')) return const StaleKeyException();
    if (e.code == '42501' ||
        e.code == '23503' ||
        text.contains('family_not_a_circle')) {
      return const NotInCircleException();
    }
    return e;
  }
}

/// PostgREST takes and returns `bytea` as `\x` followed by hex.
String _toHex(List<int> bytes) {
  final b = StringBuffer(r'\x');
  for (final v in bytes) {
    b.write(v.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

Uint8List _fromHex(String text) {
  final hex = text.startsWith(r'\x') ? text.substring(2) : text;
  if (hex.length.isOdd) throw const FormatException('Odd hex');
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// For tests: one shared in-memory table, with the server's checks that
/// matter here (members only, current key epoch, own rows only).
class InMemoryLocationBackend implements LocationBackend {
  InMemoryLocationBackend({
    required this.userId,
    InMemoryLocationServer? server,
  }) : server = server ?? InMemoryLocationServer();

  @override
  String? userId;
  final InMemoryLocationServer server;

  @override
  Future<void> putLatest(LocationRow row) async {
    final me = userId;
    if (me == null) throw const SignedOutException();
    final members = server.members[row.spaceId];
    if (members == null || !members.contains(me)) {
      throw const NotInCircleException();
    }
    if (server.epochs[row.spaceId] != row.epoch) {
      throw const StaleKeyException();
    }
    server.rows['${row.spaceId}|$me|${row.deviceId}'] = LocationRow(
      spaceId: row.spaceId,
      userId: me,
      deviceId: row.deviceId,
      epoch: row.epoch,
      payload: row.payload,
      signature: row.signature,
      sentAt: DateTime.now().toUtc(),
    );
    server._changed(row.spaceId);
  }

  @override
  Future<void> deleteLatest({
    required String spaceId,
    required String deviceId,
  }) async {
    if (server.offline) throw StateError('offline');
    server.rows.remove('$spaceId|$userId|$deviceId');
    server._changed(spaceId);
  }

  @override
  Future<List<LocationRow>> latest(String spaceId) async {
    final members = server.members[spaceId];
    if (members == null || !members.contains(userId)) return const [];
    return server.rows.values.where((r) => r.spaceId == spaceId).toList();
  }

  @override
  Stream<void> changes(String spaceId) =>
      server._stream.where((id) => id == spaceId).map((_) {});

  @override
  Future<void> insertEvent(LocationRow row) async {
    if (server.offline) throw StateError('offline');
    final me = userId;
    if (me == null) throw const SignedOutException();
    final members = server.members[row.spaceId];
    if (members == null || !members.contains(me)) {
      throw const NotInCircleException();
    }
    if (server.epochs[row.spaceId] != row.epoch) {
      throw const StaleKeyException();
    }
    // Strictly increasing, as the server's clock would be in practice.
    var at = server.now().toUtc();
    final last = server.events.lastOrNull?.sentAt;
    if (last != null && !at.isAfter(last)) {
      at = last.add(const Duration(milliseconds: 1));
    }
    server.events.add(
      LocationRow(
        spaceId: row.spaceId,
        userId: me,
        deviceId: row.deviceId,
        epoch: row.epoch,
        payload: row.payload,
        signature: row.signature,
        sentAt: at,
      ),
    );
    server._events.add(row.spaceId);
  }

  @override
  Future<List<LocationRow>> events(
    String spaceId, {
    required DateTime since,
    int limit = 100,
    bool newestFirst = false,
  }) async {
    final members = server.members[spaceId];
    if (members == null || !members.contains(userId)) return const [];
    final all = server.events.where(
      (e) => e.spaceId == spaceId && e.sentAt!.isAfter(since),
    );
    return (newestFirst ? all.toList().reversed : all).take(limit).toList();
  }

  @override
  Future<List<LocationRow>> memberEvents(
    String spaceId,
    String userId, {
    required DateTime from,
    required DateTime to,
    int limit = 2000,
  }) async {
    final members = server.members[spaceId];
    if (members == null || !members.contains(this.userId)) return const [];
    return server.events
        .where(
          (e) =>
              e.spaceId == spaceId &&
              e.userId == userId &&
              !e.sentAt!.isBefore(from) &&
              e.sentAt!.isBefore(to),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> eraseMyEvents(String spaceId) async {
    server.events.removeWhere(
      (e) => e.spaceId == spaceId && e.userId == userId,
    );
  }

  @override
  Future<int> historyDays(String spaceId) async =>
      server.historyDays[spaceId] ?? defaultHistoryDays;

  @override
  Future<void> setHistoryDays(String spaceId, int days) async {
    if (days > freeHistoryDays && !server.plus.contains(userId)) {
      throw const NeedsPlusException();
    }
    server.historyDays[spaceId] = days;
  }

  @override
  Future<void> putTrip({
    required String id,
    required String payload,
    required DateTime expiresAt,
  }) async {
    if (server.offline) throw StateError('offline');
    final me = userId;
    if (me == null) throw const SignedOutException();
    final old = server.trips[id];
    if (old != null && old.owner != me) throw StateError('not yours');
    if (!expiresAt.isAfter(server.now())) throw const TripEndedException();
    server.trips[id] = (owner: me, payload: payload, expiresAt: expiresAt);
  }

  @override
  Future<void> deleteTrip(String id) async {
    if (server.offline) throw StateError('offline');
    if (server.trips[id]?.owner == userId) server.trips.remove(id);
  }

  @override
  Stream<void> eventInserts(List<String> spaceIds) =>
      server._events.stream.where(spaceIds.contains).map((_) {});
}

class InMemoryLocationServer {
  /// Every write fails, as with no connection.
  bool offline = false;
  final Map<String, Set<String>> members = {};
  final Map<String, int> epochs = {};
  final Map<String, LocationRow> rows = {};
  final List<LocationRow> events = [];
  final Map<String, int> historyDays = {};

  /// `family_trip_shares` rows by id.
  final Map<String, ({String owner, String payload, DateTime expiresAt})>
  trips = {};

  /// Accounts with Plus.
  final Set<String> plus = {};
  DateTime Function() now = DateTime.now;
  final _events = StreamController<String>.broadcast();
  final _controller = StreamController<String>.broadcast();
  Stream<String> get _stream => _controller.stream;
  void _changed(String spaceId) => _controller.add(spaceId);
}
