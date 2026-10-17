import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/lan/lan_auth.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';

/// Finds the paired phones on the local network with UDP broadcast
/// beacons on [port].
///
/// While running, a beacon `{v, d (device id), n (name), p (server port),
/// m (minute), t (tag)}` is broadcast every [interval]. The tag is an HMAC
/// under the pair key ([LanAuth.beaconTag]), so only paired phones are
/// recognised (others are ignored) and nobody can redirect the phones to a
/// fake address. A beacon from a paired phone updates its address in
/// [LanPeers] and calls [onPeerSeen].
///
/// Networks that block broadcasts (guest Wi-Fi, some mesh systems) fall
/// back to the address in the pairing code and the last known address.
class LanDiscovery {
  LanDiscovery({
    required this.auth,
    required this.deviceId,
    required this.deviceName,
    required this.serverPort,
    required this.peers,
    this.onPeerSeen,
    this.interval = const Duration(seconds: 15),
    this.port = defaultPort,
    this.broadcastAddress,
  });

  final LanAuth auth;
  final String deviceId;
  final String Function() deviceName;
  final int? Function() serverPort;
  final LanPeers peers;
  final void Function(LanPeer peer)? onPeerSeen;
  final Duration interval;
  final int port;

  /// Defaults to 255.255.255.255; tests use loopback.
  final InternetAddress? broadcastAddress;

  static const int defaultPort = 47322;

  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start() async {
    if (_socket != null) {
      return;
    }
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            unawaited(_onDatagram(datagram));
          }
        }
      },
      // Send errors (no route, network gone) arrive here; the next beacon
      // tries again.
      onError: (Object e) => Logger.info('Wi-Fi sync beacon: $e'),
    );
    _socket = socket;
    announce();
    _timer = Timer.periodic(interval, (_) => announce());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }

  /// Broadcasts one beacon now.
  void announce() {
    final socket = _socket;
    final serverPort = this.serverPort();
    if (socket == null || serverPort == null || port == 0) {
      return;
    }
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final beacon = utf8.encode(
      jsonEncode({
        'v': 1,
        'd': deviceId,
        'n': deviceName(),
        'p': serverPort,
        'm': minute,
        't': auth.beaconTag(deviceId, serverPort, minute),
      }),
    );
    try {
      socket.send(
        beacon,
        broadcastAddress ?? InternetAddress('255.255.255.255'),
        port,
      );
    } catch (e) {
      Logger.info('Wi-Fi sync beacon not sent: $e');
    }
  }

  Future<void> _onDatagram(Datagram datagram) async {
    try {
      final json =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, Object?>;
      final device = json['d'];
      final serverPort = json['p'];
      final minute = json['m'];
      final tag = json['t'];
      if (json['v'] != 1 ||
          device is! String ||
          device == deviceId ||
          serverPort is! int ||
          minute is! int ||
          tag is! String) {
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      if ((now - minute).abs() > 1 ||
          auth.beaconTag(device, serverPort, minute) != tag) {
        return;
      }
      final known = peers[device];
      final peer = LanPeer(
        deviceId: device,
        name: json['n'] as String? ?? '',
        host: datagram.address.address,
        port: serverPort,
        lastSeen: DateTime.now(),
      );
      await peers.upsert(peer);
      final synced = known?.lastSync;
      if (known?.host != peer.host ||
          known?.port != peer.port ||
          synced == null ||
          DateTime.now().difference(synced) > const Duration(minutes: 2)) {
        onPeerSeen?.call(peers[device]!);
      }
    } catch (_) {
      // Not a beacon of ours.
    }
  }
}
