import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ledger_zero/services/sync/p2p/local_discovery_service.dart';
import 'package:ledger_zero/services/sync/p2p/sync_server.dart';
import 'package:ledger_zero/services/sync/transport/local_sync_transport.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([LocalDiscoveryService, SyncServer, http.Client])
import 'local_sync_transport_test.mocks.dart';

void main() {
  late MockLocalDiscoveryService mockDiscovery;
  late MockSyncServer mockServer;
  late MockClient mockClient;
  late LocalSyncTransport transport;

  setUp(() {
    mockDiscovery = MockLocalDiscoveryService();
    mockServer = MockSyncServer();
    mockClient = MockClient();

    // Default stubs
    when(mockDiscovery.initialize()).thenAnswer((_) async {});
    when(
      mockDiscovery.startBroadcasting(
        port: anyNamed('port'),
        deviceName: anyNamed('deviceName'),
      ),
    ).thenAnswer((_) async {});
    when(mockDiscovery.startDiscovery()).thenAnswer((_) async {});
    when(mockDiscovery.dispose()).thenAnswer((_) async {});
    when(mockDiscovery.devicesStream).thenAnswer((_) => const Stream.empty());

    when(mockServer.start()).thenAnswer((_) async {});
    when(mockServer.stop()).thenAnswer((_) async {});
    when(mockServer.port).thenReturn(8080);

    // Mock DeviceUtils indirectly? DeviceUtils is static.
    // We assume it works or returns "Unknown Device" in test env as we didn't mock package_info_plus/device_info_plus platform channel here specifically?
    // Wait, DeviceUtils uses platform channels. I might need to mock them if I run this test.
    // Or just accept "Unknown Device".
    SharedPreferences.setMockInitialValues(
      {},
    ); // For DeviceUtils internal prefs

    transport = LocalSyncTransport(
      mockDiscovery,
      mockServer,
      client: mockClient,
    );
  });

  test('initialize starts services', () async {
    // Act
    await transport.initialize();

    // Assert
    verify(mockDiscovery.initialize()).called(1);
    verify(mockServer.start()).called(1);
    verify(
      mockDiscovery.startBroadcasting(
        port: anyNamed('port'),
        deviceName: anyNamed('deviceName'),
      ),
    ).called(1);
    verify(mockDiscovery.startDiscovery()).called(1);
  });

  test('listDeltas polls peers', () async {
    // Arrange
    final controller = StreamController<List<DiscoveredDevice>>();
    when(mockDiscovery.devicesStream).thenAnswer((_) => controller.stream);

    await transport.initialize();

    // Add a peer
    final peer = DiscoveredDevice(
      id: 'peer1',
      name: 'Peer 1',
      ip: '192.168.1.100',
      port: 9000,
    );
    controller.add([peer]);
    await Future.delayed(Duration.zero);

    // Mock HTTP response from peer
    when(
      mockClient.get(any),
    ).thenAnswer((_) async => http.Response('["delta1.json"]', 200));

    // Act
    final result = await transport.listDeltas();

    // Assert
    expect(result.length, 1);
    expect(result.first.name, 'delta1.json');
    expect(result.first.metadata?['peer_ip'], '192.168.1.100');

    await controller.close();
  });

  test('uploadDelta pushes to peers', () async {
    // Arrange
    final controller = StreamController<List<DiscoveredDevice>>();
    when(mockDiscovery.devicesStream).thenAnswer((_) => controller.stream);
    await transport.initialize();

    final peer = DiscoveredDevice(
      id: 'peer1',
      name: 'Peer 1',
      ip: '192.168.1.100',
      port: 9000,
    );
    controller.add([peer]);
    await Future.delayed(Duration.zero);

    // Mock File
    // We can't easily mock File since it's from dart:io and SyncTransport expects it.
    // We'll create a temp file.
    final tempDir = await Directory.systemTemp.createTemp();
    final file = File('${tempDir.path}/test_delta.json.gz');
    await file.writeAsString('test data');

    // Mock HTTP Post
    when(
      mockClient.post(
        any,
        body: anyNamed('body'),
        headers: anyNamed('headers'),
      ),
    ).thenAnswer((_) async => http.Response('Uploaded', 200));

    // Act
    final result = await transport.uploadDelta(file, 'test_delta.json.gz');

    // Assert
    expect(result, 'test_delta.json.gz');
    verify(
      mockClient.post(
        any,
        body: anyNamed('body'),
        headers: anyNamed('headers'),
      ),
    ).called(1);

    await tempDir.delete(recursive: true);
    await controller.close();
  });
}
