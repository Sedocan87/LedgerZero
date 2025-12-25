import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/p2p/local_discovery_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

class P2PSyncScreen extends ConsumerStatefulWidget {
  const P2PSyncScreen({super.key});

  @override
  ConsumerState<P2PSyncScreen> createState() => _P2PSyncScreenState();
}

class _P2PSyncScreenState extends ConsumerState<P2PSyncScreen> {
  String _deviceName = 'Unknown';
  String? _localIp;
  bool _isBroadcasting = false;
  bool _isDiscovering = false;
  bool _showQrCode = false;
  static const int _syncPort = 8765;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadDeviceName();
    await _getLocalIp();
    // Try to start mDNS discovery in background
    _startMdnsDiscovery();
  }

  Future<void> _loadDeviceName() async {
    final name = await DeviceUtils.getDeviceName();
    if (mounted) {
      setState(() => _deviceName = name);
    }
  }

  Future<void> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            if (mounted) {
              setState(() => _localIp = addr.address);
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get local IP: $e');
    }
  }

  Future<void> _startMdnsDiscovery() async {
    final discoveryService = ref.read(localDiscoveryServiceProvider);

    try {
      await discoveryService.startBroadcasting(
        port: _syncPort,
        deviceName: _deviceName,
      );
      await discoveryService.startDiscovery();

      if (mounted) {
        setState(() {
          _isBroadcasting = true;
          _isDiscovering = true;
        });
      }
    } catch (e) {
      debugPrint('mDNS error: $e');
    }
  }

  @override
  void dispose() {
    final discoveryService = ref.read(localDiscoveryServiceProvider);
    discoveryService.stopBroadcasting();
    discoveryService.stopDiscovery();
    super.dispose();
  }

  String _generateQrData() {
    if (_localIp == null) return '';

    final data = {
      'type': 'ledgerzero_p2p',
      'ip': _localIp,
      'port': _syncPort,
      'name': _deviceName,
    };
    return jsonEncode(data);
  }

  void _showQrScanner() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission required to scan QR codes'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const _QrScannerPage()),
    );

    if (result != null && mounted) {
      _handleScannedQr(result);
    }
  }

  void _handleScannedQr(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      if (json['type'] != 'ledgerzero_p2p') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
        return;
      }

      final device = DiscoveredDevice(
        id: json['ip'] ?? 'unknown',
        name: json['name'] ?? 'Unknown Device',
        ip: json['ip'],
        port: json['port'] ?? _syncPort,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found device: ${device.name} at ${device.ip}'),
          action: SnackBarAction(
            label: 'Connect',
            onPressed: () {
              // TODO: Initiate actual sync with device
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connecting to ${device.name}...')),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to parse QR code: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discoveryService = ref.watch(localDiscoveryServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Local P2P Sync')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Device Info Card
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surfaceContainerHighest,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Device', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(_deviceName, style: theme.textTheme.headlineSmall),
                  if (_localIp != null)
                    Text(
                      'IP: $_localIp:$_syncPort',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // QR Code Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Show My QR Code Button
                  Card(
                    child: InkWell(
                      onTap: () => setState(() => _showQrCode = !_showQrCode),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _showQrCode ? Icons.qr_code_2 : Icons.qr_code,
                              size: 40,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Show My QR Code',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Let another device scan to connect',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _showQrCode
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // QR Code Display
                  if (_showQrCode && _localIp != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _generateQrData(),
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan this code with another device',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],

                  if (_showQrCode && _localIp == null)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Unable to get network address'),
                    ),

                  const SizedBox(height: 16),

                  // Scan QR Code Button
                  Card(
                    child: InkWell(
                      onTap: _showQrScanner,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 40,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scan QR Code',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Connect to another device',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // mDNS Discovery Section (background)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Auto-discovered Devices',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (_isDiscovering)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<DiscoveredDevice>>(
                    stream: discoveryService.devicesStream,
                    initialData: const [],
                    builder: (context, snapshot) {
                      final devices = snapshot.data ?? [];

                      if (devices.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.wifi_find,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No devices found via auto-discovery',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Use QR code pairing instead',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: devices
                            .map(
                              (device) => ListTile(
                                leading: const Icon(Icons.phone_android),
                                title: Text(device.name),
                                subtitle: Text('${device.ip}:${device.port}'),
                                trailing: const Icon(
                                  Icons.wifi,
                                  color: Colors.green,
                                ),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Sync with ${device.name} - coming soon',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// QR Scanner Page
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_scanned) return;

          final barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              _scanned = true;
              Navigator.of(context).pop(barcode.rawValue);
              return;
            }
          }
        },
      ),
    );
  }
}
