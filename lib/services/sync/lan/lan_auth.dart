import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';

/// Authenticates requests and responses between paired phones with
/// HMAC-SHA256 under the pair key.
///
/// Request header `X-LZ-Auth`: scheme, device id, unix seconds, nonce and
/// mac, separated by spaces. Two schemes:
///
/// * `v1`: mac over `v1`, method, path, device id, time, nonce and the
///   SHA-256 of the body;
/// * `v2`: the same plus the **recipient's** device id, so a captured
///   request cannot be replayed to another paired phone (which would store
///   the replayer's address for the sender until the next beacon).
///
/// A server accepts both; a client signs `v2` only for a phone that said
/// it understands it (`LanFolderState.authVersion`, kept in
/// `LanPeer.authVersion`), so a phone on an app version that only knows
/// `v1` keeps working.
///
/// The server accepts a request only within [maxSkew] of its own
/// clock and never the same nonce twice (replay). The response carries
/// `X-LZ-Mac` over the status, the request nonce and the SHA-256 of the
/// response body, so a device on the network cannot answer in place of the
/// paired phone either. (The sync files themselves are additionally
/// AES-GCM encrypted with the sync key.)
class LanAuth {
  LanAuth(Uint8List pairKey, {DateTime Function()? clock})
    : _hmac = Hmac(sha256, pairKey),
      _clock = clock ?? DateTime.now;

  final Hmac _hmac;
  final DateTime Function() _clock;
  final _seenNonces = <String>{};
  final _nonceOrder = <String>[];

  /// The newest request scheme this app signs and accepts.
  static const int version = 2;

  static const String header = 'x-lz-auth';
  static const String responseHeader = 'x-lz-mac';
  static const Duration maxSkew = Duration(minutes: 2);
  static const int _maxNonces = 2000;

  /// The value of [header] for a request, and its nonce. With [recipient]
  /// (the device id of the phone the request goes to) the request is
  /// signed `v2`, otherwise `v1`.
  ({String value, String nonce}) sign({
    required String method,
    required String path,
    required String deviceId,
    required List<int> body,
    String? recipient,
  }) {
    final ts = _clock().millisecondsSinceEpoch ~/ 1000;
    final nonce = base64Url.encode(secureRandomBytes(12));
    final scheme = recipient == null ? 'v1' : 'v2';
    final mac = _requestMac(
      scheme: scheme,
      method: method,
      path: path,
      deviceId: deviceId,
      timestamp: '$ts',
      nonce: nonce,
      recipient: recipient,
      body: body,
    );
    return (value: '$scheme $deviceId $ts $nonce $mac', nonce: nonce);
  }

  String _requestMac({
    required String scheme,
    required String method,
    required String path,
    required String deviceId,
    required String timestamp,
    required String nonce,
    required String? recipient,
    required List<int> body,
  }) => _mac([
    scheme,
    method,
    path,
    deviceId,
    timestamp,
    nonce,
    if (scheme == 'v2') recipient ?? '',
    _hash(body),
  ]);

  /// The fields of a [header] value, or null when it is not one. Nothing
  /// is verified: this is the cheap check a server makes before it reads
  /// the body.
  static ({String scheme, String deviceId, int timestamp})? parse(
    String? value,
  ) {
    final parts = value?.split(' ');
    if (parts == null ||
        parts.length != 5 ||
        (parts[0] != 'v1' && parts[0] != 'v2')) {
      return null;
    }
    final ts = int.tryParse(parts[2]);
    if (ts == null) {
      return null;
    }
    return (scheme: parts[0], deviceId: parts[1], timestamp: ts);
  }

  /// Whether a request stamped [timestamp] (seconds) is within [maxSkew]
  /// of this phone's clock.
  bool inWindow(int timestamp) =>
      _clock()
          .difference(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000))
          .abs() <=
      maxSkew;

  /// Checks a request; returns its device id and nonce, or `null` when it
  /// is not authentic, too old or replayed.
  ({String deviceId, String nonce})? verify({
    required String? value,
    required String method,
    required String path,
    required List<int> body,
    String? self,
  }) {
    return switch (check(
      value: value,
      method: method,
      path: path,
      body: body,
      self: self,
    )) {
      LanAuthOk(:final deviceId, :final nonce) => (
        deviceId: deviceId,
        nonce: nonce,
      ),
      _ => null,
    };
  }

  /// Like [verify], but tells a request signed under the pair key whose
  /// clock differs by more than [maxSkew] ([LanAuthSkewed]) from one that
  /// is not authentic or replayed ([LanAuthRejected]). The signature is
  /// checked first, so only a paired phone learns about the skew.
  ///
  /// [self] is this phone's device id: a `v2` request must name it as the
  /// recipient (without [self] a `v2` request is rejected).
  LanAuthCheck check({
    required String? value,
    required String method,
    required String path,
    required List<int> body,
    String? self,
  }) {
    final parts = value?.split(' ');
    if (parts == null ||
        parts.length != 5 ||
        (parts[0] != 'v1' && parts[0] != 'v2')) {
      return const LanAuthRejected();
    }
    final [scheme, deviceId, tsText, nonce, mac] = parts;
    final ts = int.tryParse(tsText);
    if (ts == null || (scheme == 'v2' && self == null)) {
      return const LanAuthRejected();
    }
    final expected = _requestMac(
      scheme: scheme,
      method: method,
      path: path,
      deviceId: deviceId,
      timestamp: tsText,
      nonce: nonce,
      recipient: self,
      body: body,
    );
    if (!constantTimeEquals(utf8.encode(expected), utf8.encode(mac))) {
      return const LanAuthRejected();
    }
    final skew = _clock().difference(
      DateTime.fromMillisecondsSinceEpoch(ts * 1000),
    );
    if (skew.abs() > maxSkew) {
      return LanAuthSkewed(deviceId: deviceId, nonce: nonce, skew: skew);
    }
    if (!_seenNonces.add(nonce)) {
      return const LanAuthRejected();
    }
    _nonceOrder.add(nonce);
    if (_nonceOrder.length > _maxNonces) {
      _seenNonces.remove(_nonceOrder.removeAt(0));
    }
    return LanAuthOk(deviceId: deviceId, nonce: nonce);
  }

  /// [responseHeader] for a response to the request with [nonce].
  String signResponse({
    required int status,
    required String nonce,
    required List<int> body,
  }) => _mac(['v1r', '$status', nonce, _hash(body)]);

  bool verifyResponse({
    required String? value,
    required int status,
    required String nonce,
    required List<int> body,
  }) {
    if (value == null) {
      return false;
    }
    final expected = signResponse(status: status, nonce: nonce, body: body);
    return constantTimeEquals(utf8.encode(expected), utf8.encode(value));
  }

  /// Tag for discovery beacons of [deviceId] on [port] in [minute] (minutes
  /// since the epoch); accepted for the neighbouring minutes too.
  String beaconTag(String deviceId, int port, int minute) =>
      _mac(['beacon', deviceId, '$port', '$minute']);

  /// Seconds since the epoch of this phone's clock (for the skew header).
  int get nowSeconds => _clock().millisecondsSinceEpoch ~/ 1000;

  String _mac(List<String> fields) =>
      base64Url.encode(_hmac.convert(utf8.encode(fields.join('\n'))).bytes);

  static String _hash(List<int> body) => sha256.convert(body).toString();
}

/// Outcome of [LanAuth.check].
sealed class LanAuthCheck {
  const LanAuthCheck();
}

class LanAuthOk extends LanAuthCheck {
  const LanAuthOk({required this.deviceId, required this.nonce});
  final String deviceId;
  final String nonce;
}

/// Signed under the pair key, but the sender's clock is off by [skew]
/// (this phone's time minus the sender's).
class LanAuthSkewed extends LanAuthCheck {
  const LanAuthSkewed({
    required this.deviceId,
    required this.nonce,
    required this.skew,
  });
  final String deviceId;
  final String nonce;
  final Duration skew;
}

class LanAuthRejected extends LanAuthCheck {
  const LanAuthRejected();
}
