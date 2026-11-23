import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'geofence.dart';

/// What a sharing phone's background service needs for one circle: the
/// circle's location box public key for the current key epoch, and where
/// the circle's places are (to tell the circle "arrived at Home"). No one's
/// location and no names, so a stolen phone with a locked app reveals only
/// the places this phone watches.
class CirclePackage {
  const CirclePackage({
    required this.spaceId,
    required this.epoch,
    required this.boxPublic,
    this.stale = false,
    this.places = const [],
    this.inside = const {},
    this.shareDrives = false,
    this.approximate = false,
  });

  final String spaceId;
  final int epoch;
  final Uint8List boxPublic;

  /// The circle's places, and whether this phone is in each (by place id).
  final List<WatchedPlace> places;
  final Map<String, bool> inside;

  /// The circle's key changed (someone left or was removed): sharing to it
  /// waits until the app is opened and the new key is known.
  final bool stale;

  /// This phone's driver shares drive summaries with the circle.
  final bool shareDrives;

  /// This phone shows the circle only roughly where it is (L-5).
  final bool approximate;

  CirclePackage copyWith({
    int? epoch,
    Uint8List? boxPublic,
    bool? stale,
    List<WatchedPlace>? places,
    Map<String, bool>? inside,
    bool? shareDrives,
    bool? approximate,
  }) => CirclePackage(
    spaceId: spaceId,
    epoch: epoch ?? this.epoch,
    boxPublic: boxPublic ?? this.boxPublic,
    stale: stale ?? this.stale,
    places: places ?? this.places,
    inside: inside ?? this.inside,
    shareDrives: shareDrives ?? this.shareDrives,
    approximate: approximate ?? this.approximate,
  );

  Map<String, Object?> toJson() => {
    'space': spaceId,
    'epoch': epoch,
    'box': ZtBase64.encode(boxPublic),
    if (stale) 'stale': true,
    if (places.isNotEmpty) 'places': [for (final p in places) p.toJson()],
    if (inside.isNotEmpty) 'inside': inside,
    if (shareDrives) 'drives': true,
    if (approximate) 'approximate': true,
  };

  static CirclePackage fromJson(Map<String, Object?> json) => CirclePackage(
    spaceId: json['space']! as String,
    epoch: json['epoch']! as int,
    boxPublic: ZtBase64.decode(json['box']! as String),
    stale: json['stale'] == true,
    places: [
      for (final p in (json['places'] as List? ?? const []))
        ?WatchedPlace.fromJson(p),
    ],
    inside: {
      for (final e in ((json['inside'] as Map?) ?? const {}).entries)
        if (e.key is String && e.value is bool)
          e.key as String: e.value as bool,
    },
    shareDrives: json['drives'] == true,
    approximate: json['approximate'] == true,
  );
}

/// This phone's sharing state, kept outside the vault (in the Android
/// Keystore) so the background service can use it while the app is locked.
/// A running safety timer or SOS of this phone, in one circle.
class SafetyRun {
  const SafetyRun({
    required this.spaceId,
    required this.until,
    this.also = const [],
  });

  final String spaceId;

  /// The timer's deadline; for an SOS, when its live sharing ends.
  final DateTime until;

  /// More circles the same SOS went to (a crash alerts every circle).
  final List<String> also;

  List<String> get spaces => [spaceId, ...also];

  Map<String, Object?> toJson() => {
    'space': spaceId,
    'until': until.toUtc().toIso8601String(),
    if (also.isNotEmpty) 'also': also,
  };

  static SafetyRun? fromJson(Object? json) {
    if (json is! Map) return null;
    final space = json['space'];
    final until = DateTime.tryParse(json['until'] as String? ?? '');
    if (space is! String || until == null) return null;
    return SafetyRun(
      spaceId: space,
      until: until,
      also: [
        for (final a in (json['also'] as List? ?? const []))
          if (a is String) a,
      ],
    );
  }
}

/// A crash this phone detected: it alerts every circle at [deadline]
/// unless the driver says they're OK first.
class CrashRun {
  const CrashRun({
    required this.at,
    required this.deadline,
    this.lat,
    this.lng,
    this.sent = const [],
  });

  final DateTime at;
  final DateTime deadline;
  final double? lat;
  final double? lng;

  /// Circles its SOS already reached. Non-empty: the countdown is over and
  /// the SOS is still being retried for the others (offline).
  final List<String> sent;

  bool get counting => sent.isEmpty;

  CrashRun copyWith({List<String>? sent}) => CrashRun(
    at: at,
    deadline: deadline,
    lat: lat,
    lng: lng,
    sent: sent ?? this.sent,
  );

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'deadline': deadline.toUtc().toIso8601String(),
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (sent.isNotEmpty) 'sent': sent,
  };

  static CrashRun? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    final deadline = DateTime.tryParse(json['deadline'] as String? ?? '');
    if (at == null || deadline == null) return null;
    return CrashRun(
      at: at,
      deadline: deadline,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      sent: [
        for (final s in (json['sent'] as List? ?? const []))
          if (s is String) s,
      ],
    );
  }
}

class ShareState {
  const ShareState({
    required this.userId,
    required this.deviceId,
    required this.deviceSeed,
    this.circles = const [],
    this.pausedUntil,
    this.pausedOpenEnded = false,
    this.liveUntil,
    this.timer,
    this.sos,
    this.pendingDeletes = const [],
    this.drives = false,
    this.crashDetection = false,
    this.crash,
    this.sosEndPending = const [],
  });

  /// The account that turned sharing on. Another account signing in on
  /// this phone stops it.
  final String userId;

  /// This phone's id and Ed25519 seed (its device key).
  final String deviceId;
  final Uint8List deviceSeed;

  /// Circles this phone shares its location with.
  final List<CirclePackage> circles;

  final DateTime? pausedUntil;
  final bool pausedOpenEnded;
  final DateTime? liveUntil;

  /// "Alert my circle if I don't check in by ..."; the service sends the
  /// alert itself when the time passes.
  final SafetyRun? timer;

  /// An SOS this phone sent and hasn't ended.
  final SafetyRun? sos;

  /// Circles whose last location of this phone still has to come off the
  /// server (sharing was stopped while offline). Retried until it works.
  final List<String> pendingDeletes;

  /// Drive summaries: this phone keeps a summary of each drive (on the
  /// phone; circles get it only where [CirclePackage.shareDrives] is on).
  final bool drives;

  /// Crash detection while driving.
  final bool crashDetection;

  /// A detected crash counting down to an SOS.
  final CrashRun? crash;

  /// Circles still to be told an SOS ended ("I'm safe" reached the others
  /// while this phone went offline). Retried with every update.
  final List<String> sosEndPending;

  bool get sharing => circles.isNotEmpty;

  bool pausedAt(DateTime now) =>
      pausedOpenEnded || (pausedUntil != null && now.isBefore(pausedUntil!));

  bool sharesWith(String spaceId) => circles.any((c) => c.spaceId == spaceId);

  ShareState copyWith({
    List<CirclePackage>? circles,
    DateTime? Function()? pausedUntil,
    bool? pausedOpenEnded,
    DateTime? Function()? liveUntil,
    SafetyRun? Function()? timer,
    SafetyRun? Function()? sos,
    List<String>? pendingDeletes,
    bool? drives,
    bool? crashDetection,
    CrashRun? Function()? crash,
    List<String>? sosEndPending,
  }) => ShareState(
    userId: userId,
    deviceId: deviceId,
    deviceSeed: deviceSeed,
    circles: circles ?? this.circles,
    pausedUntil: pausedUntil == null ? this.pausedUntil : pausedUntil(),
    pausedOpenEnded: pausedOpenEnded ?? this.pausedOpenEnded,
    liveUntil: liveUntil == null ? this.liveUntil : liveUntil(),
    timer: timer == null ? this.timer : timer(),
    sos: sos == null ? this.sos : sos(),
    pendingDeletes: pendingDeletes ?? this.pendingDeletes,
    drives: drives ?? this.drives,
    crashDetection: crashDetection ?? this.crashDetection,
    crash: crash == null ? this.crash : crash(),
    sosEndPending: sosEndPending ?? this.sosEndPending,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'user': userId,
    'device': deviceId,
    'seed': ZtBase64.encode(deviceSeed),
    'circles': [for (final c in circles) c.toJson()],
    if (pausedUntil != null) 'pausedUntil': pausedUntil!.toIso8601String(),
    if (pausedOpenEnded) 'pausedOpenEnded': true,
    if (liveUntil != null) 'liveUntil': liveUntil!.toIso8601String(),
    if (timer != null) 'timer': timer!.toJson(),
    if (sos != null) 'sos': sos!.toJson(),
    if (pendingDeletes.isNotEmpty) 'pendingDeletes': pendingDeletes,
    if (drives) 'drives': true,
    if (crashDetection) 'crashDetection': true,
    if (crash != null) 'crash': crash!.toJson(),
    if (sosEndPending.isNotEmpty) 'sosEndPending': sosEndPending,
  };

  static ShareState fromJson(Map<String, Object?> json) => ShareState(
    userId: json['user']! as String,
    deviceId: json['device']! as String,
    deviceSeed: ZtBase64.decode(json['seed']! as String),
    circles: [
      for (final c in (json['circles'] as List? ?? const []))
        CirclePackage.fromJson((c as Map).cast<String, Object?>()),
    ],
    pausedUntil: DateTime.tryParse(json['pausedUntil'] as String? ?? ''),
    pausedOpenEnded: json['pausedOpenEnded'] == true,
    liveUntil: DateTime.tryParse(json['liveUntil'] as String? ?? ''),
    timer: SafetyRun.fromJson(json['timer']),
    sos: SafetyRun.fromJson(json['sos']),
    pendingDeletes: [
      for (final d in (json['pendingDeletes'] as List? ?? const []))
        if (d is String) d,
    ],
    drives: json['drives'] == true,
    crashDetection: json['crashDetection'] == true,
    crash: CrashRun.fromJson(json['crash']),
    sosEndPending: [
      for (final s in (json['sosEndPending'] as List? ?? const []))
        if (s is String) s,
    ],
  );

  /// A new device identity for [userId].
  static ShareState fresh(String userId) => ShareState(
    userId: userId,
    deviceId: _hex(Kdf.randomBytes(12)),
    deviceSeed: Kdf.randomBytes(32),
  );
}

abstract class ShareStore {
  Future<ShareState?> load();
  Future<void> save(ShareState state);
  Future<void> clear();
}

class SecureShareStore implements ShareStore {
  SecureShareStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'zt_family_share'),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'share';

  @override
  Future<ShareState?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return ShareState.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null; // Unreadable: sharing starts over.
    }
  }

  @override
  Future<void> save(ShareState state) =>
      _storage.write(key: _key, value: jsonEncode(state.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryShareStore implements ShareStore {
  InMemoryShareStore([this.state]);
  ShareState? state;

  @override
  Future<ShareState?> load() async => state;

  @override
  Future<void> save(ShareState state) async => this.state = state;

  @override
  Future<void> clear() async => state = null;
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
