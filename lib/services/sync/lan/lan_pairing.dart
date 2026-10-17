import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/secure_store.dart';

/// The shared secrets of phones that sync over Wi-Fi.
///
/// * [pairKey] (32 random bytes) authenticates every request between the
///   phones (HMAC-SHA256, see `LanAuth`); without it nobody on the network
///   can list, read or write sync files.
/// * [passphrase] is the sync passphrase of the shared folder: the engine
///   derives the file encryption key from it (Argon2id + HKDF, see
///   docs/SYNC_ARCHITECTURE.md). It is generated, never typed: the user
///   only moves it to the other phone with the pairing QR code.
///
/// Both travel only in the pairing code, which the user shows on one phone
/// and scans on the other.
class LanPairing {
  const LanPairing({required this.pairKey, required this.passphrase});

  final Uint8List pairKey;
  final String passphrase;

  static const int pairKeyLength = 32;

  /// New secrets for the first phone.
  factory LanPairing.generate() => LanPairing(
    pairKey: secureRandomBytes(pairKeyLength),
    passphrase: _randomPassphrase(),
  );

  /// 26 Crockford-base32 characters (130 bits).
  static String _randomPassphrase() {
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    final bytes = secureRandomBytes(26);
    return String.fromCharCodes([
      for (final b in bytes) alphabet.codeUnitAt(b & 31),
    ]);
  }

  Map<String, Object?> toJson() => {
    'k': base64Url.encode(pairKey),
    'p': passphrase,
  };

  factory LanPairing.fromJson(Map<String, Object?> json) {
    final key = base64Url.decode(json['k'] as String);
    final passphrase = json['p'] as String;
    if (key.length != pairKeyLength || passphrase.length < 10) {
      throw const FormatException('Invalid pairing');
    }
    return LanPairing(pairKey: key, passphrase: passphrase);
  }
}

/// Where to reach a phone, as written into the pairing code.
class LanEndpoint {
  const LanEndpoint(this.host, this.port);

  final String host;
  final int port;

  @override
  String toString() => '$host:$port';

  static LanEndpoint? tryParse(String text) {
    final i = text.lastIndexOf(':');
    if (i <= 0) {
      return null;
    }
    final port = int.tryParse(text.substring(i + 1));
    if (port == null || port <= 0 || port > 65535) {
      return null;
    }
    return LanEndpoint(text.substring(0, i), port);
  }
}

/// What the pairing QR code (or the typed code) carries: the secrets, the
/// showing phone's device id and name, and its current addresses, so the
/// other phone can connect even where discovery is blocked.
class LanPairingCode {
  const LanPairingCode({
    required this.pairing,
    required this.deviceId,
    required this.deviceName,
    required this.endpoints,
  });

  final LanPairing pairing;
  final String deviceId;
  final String deviceName;
  final List<LanEndpoint> endpoints;

  static const String prefix = 'lzpair1:';

  String encode() =>
      prefix +
      base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                ...pairing.toJson(),
                'd': deviceId,
                'n': deviceName,
                'a': [for (final e in endpoints) e.toString()],
              }),
            ),
          )
          .replaceAll('=', '');

  /// Parses a scanned or typed code; whitespace is ignored. Throws
  /// [FormatException] for anything else.
  static LanPairingCode decode(String text) {
    final compact = text.replaceAll(RegExp(r'\s'), '');
    if (!compact.startsWith(prefix)) {
      throw const FormatException('Not a LedgerZero pairing code');
    }
    var payload = compact.substring(prefix.length);
    payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(base64Url.decode(payload)));
    } catch (_) {
      throw const FormatException('Damaged pairing code');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Damaged pairing code');
    }
    final deviceId = json['d'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw const FormatException('Damaged pairing code');
    }
    return LanPairingCode(
      pairing: LanPairing.fromJson(json),
      deviceId: deviceId,
      deviceName: json['n'] as String? ?? '',
      endpoints: [
        for (final a in (json['a'] as List? ?? const []))
          if (a is String) ?LanEndpoint.tryParse(a),
      ],
    );
  }
}

/// Keeps the [LanPairing] in the KeyStore-protected secure storage.
class LanPairingStore {
  const LanPairingStore(this._store);

  final SecureStore _store;

  static const String storageKey = 'lz_lan_pairing_v1';

  Future<LanPairing?> read() async {
    final value = await _store.read(storageKey);
    if (value == null) {
      return null;
    }
    return LanPairing.fromJson(jsonDecode(value) as Map<String, Object?>);
  }

  Future<void> write(LanPairing pairing) =>
      _store.write(storageKey, jsonEncode(pairing.toJson()));

  Future<void> delete() => _store.delete(storageKey);
}
