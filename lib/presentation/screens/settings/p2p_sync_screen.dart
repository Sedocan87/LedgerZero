import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/device_utils.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/p2p/local_discovery_service.dart';

class P2PSyncScreen extends ConsumerStatefulWidget {
  const P2PSyncScreen({super.key});

  @override
  ConsumerState<P2PSyncScreen> createState() => _P2PSyncScreenState();
}

class _P2PSyncScreenState extends ConsumerState<P2PSyncScreen> {
  String _deviceName = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadDeviceName();
  }

  Future<void> _loadDeviceName() async {
    final name = await DeviceUtils.getDeviceName();
    if (mounted) {
      setState(() {
        _deviceName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryService = ref.watch(localDiscoveryServiceProvider);

    // We need to listen to the stream of devices
    // The provider returns the service, we can access the stream from it.
    // Better to have a StreamProvider for UI, but accessing stream directly in StreamBuilder is fine too.

    return Scaffold(
      appBar: AppBar(title: const Text('Local P2P Sync')),
      body: Column(
        children: [
          // Local Device Info
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Device',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _deviceName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Visible to others on local network',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<DiscoveredDevice>>(
              stream: discoveryService.devicesStream,
              initialData: const [],
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];

                if (devices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_tethering_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No peers found nearby'),
                        Text(
                          'Make sure other devices are on the same Wi-Fi\nand have P2P Sync enabled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.phone_android),
                      title: Text(device.name),
                      subtitle: Text('${device.ip}:${device.port}'),
                      trailing: const Icon(Icons.wifi, color: Colors.green),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
