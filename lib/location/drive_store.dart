import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'drive.dart';

/// A drive kept on this phone, and the circles it still has to reach
/// (sharing failed offline).
class StoredDrive {
  const StoredDrive(this.drive, {this.unsent = const []});
  final DriveSummary drive;
  final List<String> unsent;

  StoredDrive copyWith({List<String>? unsent}) =>
      StoredDrive(drive, unsent: unsent ?? this.unsent);

  Map<String, Object?> toJson() => {
    ...drive.toJson(),
    if (unsent.isNotEmpty) 'unsent': unsent,
  };

  static StoredDrive? fromJson(Object? json) {
    final drive = DriveSummary.fromJson(json);
    if (drive == null) return null;
    return StoredDrive(
      drive,
      unsent: [
        for (final s in ((json as Map)['unsent'] as List? ?? const []))
          if (s is String) s,
      ],
    );
  }
}

/// This phone's own drives, newest first. They never leave the phone except
/// as an encrypted summary to a circle the driver chose. Kept for [keep],
/// and only for the account that drove them: another account signing in on
/// this phone finds none (the old ones are erased).
abstract class DriveStore {
  static const keep = Duration(days: 30);
  static const maxDrives = 300;

  /// What is stored, and for which account.
  Future<(String?, List<StoredDrive>)> read();
  Future<void> write(String owner, List<StoredDrive> drives);
  Future<void> clear();

  /// [owner]'s drives, without those past [keep] (erased as they're found,
  /// so turning drive summaries off still forgets old drives on time).
  Future<List<StoredDrive>> load(String owner, DateTime now) async {
    final (stored, drives) = await read();
    if (drives.isEmpty) return const [];
    if (stored != owner) {
      await clear();
      return const [];
    }
    final kept = trim(drives, now);
    if (kept.length != drives.length) await write(owner, kept);
    return kept;
  }

  Future<void> save(String owner, List<StoredDrive> drives) =>
      write(owner, drives);

  /// Adds [drive], dropping old ones.
  Future<void> add(String owner, StoredDrive drive, DateTime now) async {
    await write(owner, trim([drive, ...await load(owner, now)], now));
  }

  static List<StoredDrive> trim(List<StoredDrive> drives, DateTime now) {
    final sorted = [...drives]
      ..sort((a, b) => b.drive.start.compareTo(a.drive.start));
    return [
      for (final d in sorted.take(maxDrives))
        if (now.difference(d.drive.end) <= keep) d,
    ];
  }
}

class SecureDriveStore extends DriveStore {
  SecureDriveStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'zt_family_drives'),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'drives';

  @override
  Future<(String?, List<StoredDrive>)> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return (null, const <StoredDrive>[]);
      final json = jsonDecode(raw);
      if (json is! Map) return (null, const <StoredDrive>[]);
      return (
        json['owner'] as String?,
        [
          for (final d in (json['drives'] as List? ?? const []))
            ?StoredDrive.fromJson(d),
        ],
      );
    } on Object {
      return (null, const <StoredDrive>[]);
    }
  }

  @override
  Future<void> write(String owner, List<StoredDrive> drives) => _storage.write(
    key: _key,
    value: jsonEncode({
      'owner': owner,
      'drives': [for (final d in drives) d.toJson()],
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryDriveStore extends DriveStore {
  String? owner;
  List<StoredDrive> drives = [];

  @override
  Future<(String?, List<StoredDrive>)> read() async => (owner, drives);

  @override
  Future<void> write(String owner, List<StoredDrive> drives) async {
    this.owner = owner;
    this.drives = drives;
  }

  @override
  Future<void> clear() async {
    owner = null;
    drives = [];
  }
}
