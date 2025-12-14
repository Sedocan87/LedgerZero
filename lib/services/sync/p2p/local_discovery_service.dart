import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class DiscoveredDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  @override
  String toString() =>
      'DiscoveredDevice(id: $id, name: $name, ip: $ip, port: $port)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DiscoveredDevice &&
        other.id == id &&
        other.ip == ip &&
        other.port == port;
  }

  @override
  int get hashCode => id.hashCode ^ ip.hashCode ^ port.hashCode;
}

class LocalDiscoveryService {
  static const String _serviceType = '_ledgerzero._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final StreamController<List<DiscoveredDevice>> _devicesController =
      StreamController.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  final Map<String, DiscoveredDevice> _discoveredDevices = {};

  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  Future<void> initialize() async {
    // Request permissions (Android 13+ needs nearby wifi devices permission)
    // iOS needs NSLocalNetworkUsageDescription
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // Basic check, might need more specific handling based on SDK version
      // For now, we assume user grants necessary runtime permissions if prompt appears
    }
  }

  Future<void> startBroadcasting({
    required int port,
    required String deviceName,
  }) async {
    if (_isBroadcasting) {
      return;
    }

    try {
      final service = BonsoirService(
        name: await DeviceUtils.getDeviceUuid(),
        type: _serviceType,
        port: port,
        attributes: {'name': deviceName},
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.start();

      _isBroadcasting = true;
      Logger.info('mDNS broadcast started: $deviceName on port $port');
    } catch (e) {
      Logger.error('Failed to start mDNS broadcast', e);
      _isBroadcasting = false;
    }
  }

  Future<void> stopBroadcasting() async {
    if (!_isBroadcasting) {
      return;
    }

    await _broadcast?.stop();
    _broadcast = null;
    _isBroadcasting = false;
    Logger.info('mDNS broadcast stopped');
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      return;
    }

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);

      _discovery!.eventStream!.listen((event) {
        // Use typed event classes based on new bonsoir API
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          final service = event.service;
          Logger.info('Service found: ${service.name}');
          // Try to resolve immediately
          event.service.resolve(_discovery!.serviceResolver);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final service = event.service;
          final host = service.host;
          Logger.info(
            'Service resolved: ${service.name} at $host:${service.port}',
          );
          _addOrUpdateDevice(service);
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          final service = event.service;
          Logger.info('Service lost: ${service.name}');
          _removeDevice(service.name);
        }
      });

      await _discovery!.start();
      _isDiscovering = true;
      Logger.info('mDNS discovery started');
    } catch (e) {
      Logger.error('Failed to start mDNS discovery', e);
      _isDiscovering = false;
    }
  }

  void _addOrUpdateDevice(BonsoirService service) {
    final uuid = service.name;
    final ip = service.host;
    final port = service.port;
    final name = service.attributes['name'] ?? 'Unknown Device';

    if (ip != null) {
      final device = DiscoveredDevice(id: uuid, name: name, ip: ip, port: port);

      _discoveredDevices[uuid] = device;
      _devicesController.add(_discoveredDevices.values.toList());
    }
  }

  void _removeDevice(String uuid) {
    if (_discoveredDevices.containsKey(uuid)) {
      _discoveredDevices.remove(uuid);
      _devicesController.add(_discoveredDevices.values.toList());
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) {
      return;
    }

    await _discovery?.stop();
    _discovery = null;
    _isDiscovering = false;
    _discoveredDevices.clear();
    _devicesController.add([]);
    Logger.info('mDNS discovery stopped');
  }

  Future<void> dispose() async {
    await stopBroadcasting();
    await stopDiscovery();
    await _devicesController.close();
  }
}
