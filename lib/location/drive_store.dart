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
/// as an encrypted summary to a circle the driver chose. Kept for [keep].
abstract class DriveStore {
  static const keep = Duration(days: 30);
  static const maxDrives = 300;

  Future<List<StoredDrive>> load();
  Future<void> save(List<StoredDrive> drives);
  Future<void> clear();

  /// Adds [drive], dropping old ones.
  Future<void> add(StoredDrive drive, DateTime now) async {
    await save(trim([drive, ...await load()], now));
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
  Future<List<StoredDrive>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const [];
      return [
        for (final d in (jsonDecode(raw) as List)) ?StoredDrive.fromJson(d),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(List<StoredDrive> drives) => _storage.write(
    key: _key,
    value: jsonEncode([for (final d in drives) d.toJson()]),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryDriveStore extends DriveStore {
  List<StoredDrive> drives = [];

  @override
  Future<List<StoredDrive>> load() async => drives;

  @override
  Future<void> save(List<StoredDrive> drives) async => this.drives = drives;

  @override
  Future<void> clear() async => drives = [];
}
