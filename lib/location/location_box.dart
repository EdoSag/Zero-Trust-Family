import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The crypto behind location sharing (plan section 3).
///
/// A circle's **location box** is an X25519 key pair derived from the
/// circle's space key for one key epoch. Every member derives the private
/// half after unlocking, the same way on every phone. The public half is all
/// a sharing phone's background service needs: it seals each update to the
/// circle and can't read anyone's location, its own included. When someone
/// leaves or is removed, the space key rotates, and so does the box.
///
/// Each phone that shares has its own **device key** (Ed25519, kept in the
/// Android Keystore by flutter_secure_storage). The member publishes its
/// public half as a space item under `family.me/<user id>/`, which only
/// that member can write, so readers know which device keys speak for whom.
abstract final class LocationBox {
  static final X25519 _x25519 = X25519();
  static const _boxInfo = 'zt/family/location-box/v1';
  static const _sealInfo = 'zt/family/seal/v1';

  /// Wire format version, first byte of every payload.
  static const version = 1;

  /// The circle's box for [epoch], derived from that epoch's space key.
  static Future<SimpleKeyPair> derive({
    required List<int> spaceKey,
    required String spaceId,
    required int epoch,
  }) async {
    final seed = await boxSeed(
      spaceKey: spaceKey,
      spaceId: spaceId,
      epoch: epoch,
    );
    try {
      return await fromSeed(seed);
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  /// The 32 bytes the box is made from. A phone that opted in to alerts
  /// while locked keeps this (not the space key) in the Keystore: it opens
  /// location updates and events of this circle and epoch, nothing else.
  static Future<Uint8List> boxSeed({
    required List<int> spaceKey,
    required String spaceId,
    required int epoch,
  }) => Kdf.hkdf(spaceKey, '$_boxInfo|$spaceId|$epoch');

  static Future<SimpleKeyPair> fromSeed(List<int> seed) =>
      _x25519.newKeyPairFromSeed(seed);

  static Future<Uint8List> publicKeyOf(SimpleKeyPair box) async =>
      Uint8List.fromList((await box.extractPublicKey()).bytes);

  /// Seals [plaintext] for the circle: `version || ephemeralPublic(32) ||
  /// AES-256-GCM box`, bound to [context] (circle, member, device, epoch, so
  /// the server can't move a payload to another row).
  static Future<Uint8List> seal(
    List<int> plaintext, {
    required List<int> boxPublic,
    required String context,
  }) async {
    final eph = await _x25519.newKeyPair();
    final ephPublic = (await eph.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(boxPublic, type: KeyPairType.x25519),
    );
    final key = await Kdf.hkdf(
      await shared.extractBytes(),
      _sealInfo,
      salt: [...ephPublic, ...boxPublic],
    );
    try {
      final sealed = await SealedBox.seal(
        plaintext,
        key,
        aad: utf8.encode('$_sealInfo|$context'),
      );
      return Uint8List.fromList([version, ...ephPublic, ...sealed]);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Opens a payload from [seal]. Throws [FormatException] or
  /// [SecretBoxAuthenticationError] when it isn't for this box and context.
  static Future<Uint8List> open(
    List<int> payload, {
    required SimpleKeyPair box,
    required String context,
  }) async {
    if (payload.length < 1 + 32 + 12 + 16 || payload[0] != version) {
      throw const FormatException('Not a location payload');
    }
    final ephPublic = payload.sublist(1, 33);
    final boxPublic = (await box.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: box,
      remotePublicKey: SimplePublicKey(ephPublic, type: KeyPairType.x25519),
    );
    final key = await Kdf.hkdf(
      await shared.extractBytes(),
      _sealInfo,
      salt: [...ephPublic, ...boxPublic],
    );
    try {
      return await SealedBox.open(
        payload.sublist(33),
        key,
        aad: utf8.encode('$_sealInfo|$context'),
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// What a sealed payload is bound to.
  static String context({
    required String table,
    required String spaceId,
    required String userId,
    required String deviceId,
    required int epoch,
  }) => '$table|$spaceId|$userId|$deviceId|$epoch';

  /// The bytes a device signs: the context, then the payload.
  static Uint8List signedBytes(String context, List<int> payload) =>
      Uint8List.fromList([
        ...utf8.encode('zt/family/sig/v1|$context|'),
        ...payload,
      ]);
}

/// Pads to a fixed bucket so the server can't tell updates apart by size
/// (a moving phone's update has speed and heading, a still one doesn't).
abstract final class PayloadPadding {
  static const bucket = 256;

  static Uint8List pad(List<int> data) {
    final length = ((data.length + 2 + bucket - 1) ~/ bucket) * bucket;
    final out = Uint8List(length);
    out[0] = data.length >> 8;
    out[1] = data.length & 0xff;
    out.setRange(2, 2 + data.length, data);
    return out;
  }

  static Uint8List unpad(List<int> padded) {
    if (padded.length < 2) throw const FormatException('Too short');
    final length = (padded[0] << 8) | padded[1];
    if (length > padded.length - 2) throw const FormatException('Bad length');
    return Uint8List.fromList(padded.sublist(2, 2 + length));
  }
}
