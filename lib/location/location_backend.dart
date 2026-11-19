import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of `family_latest`: a device's newest sealed update.
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
}

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
    return [
      for (final r in rows)
        LocationRow(
          spaceId: r['space_id'] as String,
          userId: r['user_id'] as String,
          deviceId: r['device_id'] as String,
          epoch: r['key_epoch'] as int,
          payload: _fromHex(r['payload'] as String),
          signature: _fromHex(r['signature'] as String),
          sentAt: DateTime.tryParse(r['sent_at'] as String? ?? ''),
        ),
    ];
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
}

class InMemoryLocationServer {
  final Map<String, Set<String>> members = {};
  final Map<String, int> epochs = {};
  final Map<String, LocationRow> rows = {};
  final _controller = StreamController<String>.broadcast();
  Stream<String> get _stream => _controller.stream;
  void _changed(String spaceId) => _controller.add(spaceId);
}
