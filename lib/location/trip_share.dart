import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'location_update.dart';

/// "Share my trip" (L-1): this phone's location for a limited time, for
/// anyone with a link like `https://zerotrust.bz/trip/#<id>.<key>`.
///
/// The phone seals each update with AES-256-GCM under [key]. The key is
/// only in the link after the `#`, which browsers never send to a server,
/// so the server (table `family_trip_shares`) keeps text it can't read.
/// The trip page on the website opens it in the browser (trip.js there:
/// keep the two in step).
class TripShare {
  const TripShare({
    required this.id,
    required this.key,
    required this.startedAt,
    required this.until,
    this.name,
  });

  /// 16 random bytes, base64url without padding (22 characters).
  final String id;

  /// 32 random bytes.
  final Uint8List key;
  final DateTime startedAt;
  final DateTime until;

  /// Shown on the trip page ("Dana's trip"), sealed with the rest.
  final String? name;

  /// How long a trip is shared unless the person chooses otherwise.
  static const defaultLength = Duration(hours: 1);

  /// The server ends any share 4 hours after it started.
  static const maxLength = Duration(hours: 4);

  static const linkBase = 'https://zerotrust.bz/trip/';

  String get link => '$linkBase#$id.${_b64url(key)}';

  bool activeAt(DateTime now) => now.isBefore(until);

  static TripShare create(DateTime now, {Duration? length, String? name}) {
    var span = length ?? defaultLength;
    if (span > maxLength) span = maxLength;
    final trimmed = name?.trim();
    return TripShare(
      id: _b64url(Kdf.randomBytes(16)),
      key: Kdf.randomBytes(32),
      startedAt: now.toUtc(),
      until: now.add(span).toUtc(),
      name: trimmed == null || trimmed.isEmpty
          ? null
          : String.fromCharCodes(trimmed.runes.take(60)),
    );
  }

  TripShare copyWith({DateTime? until}) => TripShare(
    id: id,
    key: key,
    startedAt: startedAt,
    until: until ?? this.until,
    name: name,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'key': ZtBase64.encode(key),
    'start': startedAt.toIso8601String(),
    'until': until.toIso8601String(),
    if (name != null) 'name': name,
  };

  static TripShare? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], key = json['key'];
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    final until = DateTime.tryParse(json['until'] as String? ?? '');
    if (id is! String || key is! String || start == null || until == null) {
      return null;
    }
    return TripShare(
      id: id,
      key: ZtBase64.decode(key),
      startedAt: start,
      until: until,
      name: json['name'] as String?,
    );
  }

  /// What the trip page shows: where, how sure, how fast, battery, and
  /// whether the phone is paused (then no position).
  Map<String, Object?> point(LocationUpdate update) => {
    'v': 1,
    if (name != null) 'n': name,
    'st': startedAt.millisecondsSinceEpoch,
    'un': until.millisecondsSinceEpoch,
    'at': update.at.millisecondsSinceEpoch,
    if (update.lat != null) 'la': update.lat,
    if (update.lng != null) 'lo': update.lng,
    if (update.accuracyM != null) 'ac': update.accuracyM!.round(),
    if (update.speedMps != null) 'sp': _round1(update.speedMps!),
    if (update.heading != null) 'hd': update.heading!.round(),
    if (update.battery != null) 'b': update.battery,
    if (update.charging) 'ch': true,
    if (update.paused) 'pz': true,
  };

  static const _aadPrefix = 'zt-family-trip-v1|';

  /// Seals [point] for the server: JSON `{"v":1,"iv":…,"ct":…}`, base64,
  /// where ct is the ciphertext followed by the 16-byte tag (as WebCrypto
  /// gives and takes it). The trip id is the associated data, so a sealed
  /// update only opens as this trip.
  Future<String> seal(Map<String, Object?> point) async {
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(point)),
      secretKey: SecretKey(key),
      nonce: Kdf.randomBytes(12),
      aad: utf8.encode('$_aadPrefix$id'),
    );
    return jsonEncode({
      'v': 1,
      'iv': base64.encode(box.nonce),
      'ct': base64.encode([...box.cipherText, ...box.mac.bytes]),
    });
  }

  /// Opens what [seal] made (tests; the website does this in the browser).
  Future<Map<String, Object?>> open(String sealed) async {
    final json = (jsonDecode(sealed) as Map).cast<String, Object?>();
    final iv = base64.decode(json['iv']! as String);
    final ct = base64.decode(json['ct']! as String);
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(
        ct.sublist(0, ct.length - 16),
        nonce: iv,
        mac: Mac(ct.sublist(ct.length - 16)),
      ),
      secretKey: SecretKey(key),
      aad: utf8.encode('$_aadPrefix$id'),
    );
    return (jsonDecode(utf8.decode(plain)) as Map).cast<String, Object?>();
  }

  /// The id and key from a trip link, or null.
  static (String, Uint8List)? parseLink(String link) {
    final hash = link.indexOf('#');
    if (hash < 0) return null;
    final parts = link.substring(hash + 1).split('.');
    if (parts.length != 2 || parts[0].length != 22) return null;
    try {
      final key = _fromB64url(parts[1]);
      return key.length == 32 ? (parts[0], key) : null;
    } on FormatException {
      return null;
    }
  }

  static double _round1(double v) => (v * 10).roundToDouble() / 10;

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _fromB64url(String s) =>
      base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));
}
