import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/lan/lan_auth.dart';
import 'package:ledger_zero/services/sync/lan/lan_discovery.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/lan/lan_protocol.dart';
import 'package:ledger_zero/services/sync/lan/local_sync_folder.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';

/// Wi-Fi sync between paired phones (docs/SYNC_ARCHITECTURE.md, "Local
/// Wi-Fi").
///
/// The sync engine runs unchanged against [transport], a folder on this
/// phone ([LocalSyncFolder]). While the app is in the foreground and
/// paired, this service runs a [LanServer] (the paired phones read and
/// write that folder) and [LanDiscovery] (finds them on the network). The
/// transport exchanges files with the paired phones whenever the engine
/// lists the folder and pushes each new file it uploads. Everything the
/// phones exchange is already encrypted with the sync key; the pair key
/// authenticates the requests.
class LanSyncService {
  LanSyncService({
    required this.folder,
    required this.pairingStore,
    required this.peers,
    required this.deviceId,
    required this.deviceName,
    this.onActivity,
    this.serverPort = LanServer.defaultPort,
    this.discoveryPort = LanDiscovery.defaultPort,
    this.bindAddress,
    this.broadcastAddress,
  });

  final LocalSyncFolder folder;
  final LanPairingStore pairingStore;
  final LanPeers peers;
  final String deviceId;

  /// Shown on the other phone (e.g. "Google Pixel 8"); set once known.
  String deviceName;

  /// A paired phone appeared or sent files: run a sync.
  void Function()? onActivity;

  final int serverPort;
  final int discoveryPort;
  final InternetAddress? bindAddress;
  final InternetAddress? broadcastAddress;

  LanPairing? _pairing;
  LanAuth? _auth;
  LanServer? _server;
  LanDiscovery? _discovery;
  LanReplicator? _replicator;
  bool _loaded = false;

  late final SyncTransport transport = _LanSyncTransport(this);

  bool get isPaired => _pairing != null;

  /// Difference between the paired phone's clock and this one's (theirs
  /// minus ours) as last measured; null before the first exchange.
  Duration? get peerClockSkew => _replicator?.lastPeerSkew;
  LanPairing? get pairing => _pairing;
  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// Reads the stored pairing (once).
  Future<LanPairing?> load() async {
    if (!_loaded) {
      _loaded = true;
      _setPairing(await pairingStore.read());
    }
    return _pairing;
  }

  /// Stores [pairing] (first phone or after scanning a code).
  Future<void> pair(LanPairing pairing) async {
    await pairingStore.write(pairing);
    _loaded = true;
    await stop();
    _setPairing(pairing);
  }

  /// Remembers the phone a pairing code came from, so the first exchange
  /// can reach it before discovery has found it.
  Future<void> addPeerFromCode(LanPairingCode code) async {
    for (final endpoint in code.endpoints) {
      await peers.upsert(
        LanPeer(
          deviceId: code.deviceId,
          name: code.deviceName,
          host: endpoint.host,
          port: endpoint.port,
        ),
      );
      final peer = peers[code.deviceId]!;
      if (await _replicator!.syncWith(peer)) {
        return;
      }
    }
  }

  /// Turns Wi-Fi sync off: stops, forgets the pairing, the peers and the
  /// folder.
  Future<void> unpair() async {
    await stop();
    await pairingStore.delete();
    await peers.clear();
    await folder.clear();
    _setPairing(null);
  }

  void _setPairing(LanPairing? pairing) {
    _pairing = pairing;
    if (pairing == null) {
      _replicator = null;
      _auth = null;
      return;
    }
    final auth = LanAuth(pairing.pairKey);
    _replicator = LanReplicator(
      folder: folder,
      client: LanClient(auth: LanAuth(pairing.pairKey), deviceId: deviceId),
      peers: peers,
      deviceId: deviceId,
      deviceName: () => deviceName,
      localPort: () => port,
    );
    _auth = auth;
  }

  /// Starts the server and discovery (app in the foreground, paired).
  Future<void> start() async {
    final auth = _auth;
    if (auth == null || _server != null) {
      return;
    }
    final server = LanServer(
      folder: folder,
      auth: auth,
      deviceId: deviceId,
      deviceName: () => deviceName,
      peers: peers,
      onReceived: () => onActivity?.call(),
      preferredPort: serverPort,
      bindAddress: bindAddress,
    );
    try {
      await server.start();
      _server = server;
      final discovery = LanDiscovery(
        auth: auth,
        deviceId: deviceId,
        deviceName: () => deviceName,
        serverPort: () => port,
        peers: peers,
        onPeerSeen: (_) => onActivity?.call(),
        port: discoveryPort,
        broadcastAddress: broadcastAddress,
      );
      try {
        await discovery.start();
        _discovery = discovery;
      } catch (e) {
        Logger.warning('Wi-Fi sync discovery unavailable: $e');
      }
    } catch (e) {
      Logger.warning('Wi-Fi sync server could not start: $e');
      await server.stop();
    }
  }

  Future<void> stop() async {
    await _discovery?.stop();
    _discovery = null;
    await _server?.stop();
    _server = null;
  }

  /// This phone's IPv4 addresses on the local network, for the pairing
  /// code.
  Future<List<LanEndpoint>> localEndpoints() async {
    final port = this.port ?? serverPort;
    final result = <LanEndpoint>[];
    try {
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && !address.isLinkLocal) {
            result.add(LanEndpoint(address.address, port));
          }
        }
      }
    } catch (e) {
      Logger.warning('Network interfaces unavailable: $e');
    }
    return result;
  }

  /// The pairing code shown on this phone.
  Future<LanPairingCode?> pairingCode() async {
    final pairing = _pairing;
    if (pairing == null) {
      return null;
    }
    return LanPairingCode(
      pairing: pairing,
      deviceId: deviceId,
      deviceName: deviceName,
      endpoints: await localEndpoints(),
    );
  }

  Future<void> _replicate() async {
    try {
      await _replicator?.syncWithPeers();
    } on LanManifestMismatchException {
      throw const SyncException(
        'paired phones use different sync folders',
        kind: SyncErrorKind.pairingMismatch,
      );
    } on LanClockSkewException catch (e) {
      throw SyncException(
        'clock skew of ${e.skew.inMinutes} min',
        kind: SyncErrorKind.clockSkew,
        originalError: e,
      );
    }
  }
}

class _LanSyncTransport implements SyncTransport {
  _LanSyncTransport(this._service);

  final LanSyncService _service;

  @override
  String get name => 'local_wifi';

  @override
  Future<List<RemoteFile>> listFiles() async {
    await _service._replicate();
    final files = await _service.folder.list();
    return [
      for (final entry in files.entries)
        RemoteFile(entry.key, entry.key, size: entry.value),
    ];
  }

  @override
  Future<Uint8List> download(RemoteFile file) async {
    final bytes = await _service.folder.read(file.name);
    if (bytes == null) {
      throw SyncException('missing local sync file ${file.name}');
    }
    return bytes;
  }

  @override
  Future<void> upload(String name, Uint8List bytes) async {
    await _service.folder.write(name, bytes);
    await _service._replicator?.push(name, bytes);
  }

  @override
  Future<void> delete(RemoteFile file) =>
      _service.folder.delete(file.name, record: true);

  @override
  Future<void> dispose() async {}
}
