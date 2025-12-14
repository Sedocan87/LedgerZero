import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:ledger_zero/services/sync/p2p/local_discovery_service.dart';
import 'package:ledger_zero/services/sync/p2p/sync_server.dart';

class LocalSyncTransport implements SyncTransport {
  final LocalDiscoveryService _discoveryService;
  final SyncServer _syncServer;
  final http.Client _client;

  List<DiscoveredDevice> _peers = [];
  StreamSubscription? _peersSubscription;

  LocalSyncTransport(
    this._discoveryService,
    this._syncServer, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'local_p2p';

  @override
  String get displayName => 'Nearby Devices (P2P)';

  @override
  Future<void> initialize() async {
    await _discoveryService.initialize();
    await _syncServer.start();

    final deviceName = await DeviceUtils.getDeviceName();
    await _discoveryService.startBroadcasting(
      port: _syncServer.port,
      deviceName: deviceName,
    );
    await _discoveryService.startDiscovery();

    _peersSubscription = _discoveryService.devicesStream.listen((devices) {
      _peers = devices;
      Logger.info('LocalSyncTransport: Discovered ${devices.length} peers');
    });
  }

  @override
  Future<void> dispose() async {
    await _peersSubscription?.cancel();
    await _discoveryService.dispose();
    await _syncServer.stop();
  }

  @override
  Future<List<RemoteFile>> listDeltas() async {
    final allRemoteFiles = <RemoteFile>[];
    final processedFilenames = <String>{}; // Deduplication

    for (final peer in _peers) {
      try {
        final url = Uri.parse('http://${peer.ip}:${peer.port}/deltas');
        final response = await _client
            .get(url)
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> filenames = jsonDecode(response.body);
          for (final filename in filenames) {
            if (filename is String && !processedFilenames.contains(filename)) {
              processedFilenames.add(filename);
              allRemoteFiles.add(
                RemoteFile(
                  filename,
                  filename,
                  metadata: {'peer_ip': peer.ip, 'peer_port': peer.port},
                ),
              );
            }
          }
        }
      } catch (e) {
        Logger.warning(
          'Failed to list deltas from peer ${peer.name} (${peer.ip}): $e',
        );
      }
    }
    return allRemoteFiles;
  }

  @override
  Future<File> downloadDelta(RemoteFile remoteFile, String savePath) async {
    final ip = remoteFile.metadata?['peer_ip'];
    final port = remoteFile.metadata?['peer_port'];

    if (ip == null || port == null) {
      throw Exception('Peer info missing for ${remoteFile.name}');
    }

    try {
      final url = Uri.parse('http://$ip:$port/deltas/${remoteFile.name}');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception(
          'Failed to download ${remoteFile.name}: ${response.statusCode}',
        );
      }
    } catch (e) {
      Logger.error('Error downloading from $ip:$port', e);
      rethrow;
    }
  }

  @override
  Future<String?> uploadDelta(File localFile, String filename) async {
    int successCount = 0;

    for (final peer in _peers) {
      try {
        final url = Uri.parse(
          'http://${peer.ip}:${peer.port}/upload?filename=$filename',
        );
        final bytes = await localFile.readAsBytes();
        final response = await _client
            .post(
              url,
              body: bytes,
              headers: {'content-type': 'application/octet-stream'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          successCount++;
          Logger.info('Uploaded $filename to ${peer.name}');
        }
      } catch (e) {
        Logger.warning('Failed to upload to ${peer.name}: $e');
      }
    }

    if (successCount > 0) {
      return filename;
    }

    return null;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    // No-op for P2P
  }
}
