import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'connectivity_service_test.mocks.dart';

@GenerateMocks([Connectivity])
void main() {
  late MockConnectivity mockConnectivity;
  late ConnectivityService service;
  late StreamController<List<ConnectivityResult>> controller;

  setUp(() {
    mockConnectivity = MockConnectivity();
    controller = StreamController<List<ConnectivityResult>>();

    when(mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => controller.stream);

    when(mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
  });

  tearDown(() {
    controller.close();
  });

  test('initializes with correct status', () async {
    service = ConnectivityService(connectivity: mockConnectivity);
    // Allow initial check to complete
    await Future.delayed(Duration.zero);

    expect(await service.isConnected, true);
  });

  test('emits offline when connection is lost', () async {
    service = ConnectivityService(connectivity: mockConnectivity);

    expectLater(
      service.connectionStatusStream,
      emitsInOrder([
        ConnectionStatus.online, // Initial check
        ConnectionStatus.offline,
      ]),
    );

    // Initial check
    await Future.delayed(Duration.zero);

    // Change to none
    controller.add([ConnectivityResult.none]);
  });

  test('emits online when connection is restored', () async {
    // Start with none
    when(mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    service = ConnectivityService(connectivity: mockConnectivity);

    expectLater(
      service.connectionStatusStream,
      emitsInOrder([
        ConnectionStatus.offline, // Initial
        ConnectionStatus.online,
      ]),
    );

    await Future.delayed(Duration.zero);

    // Change to wifi
    controller.add([ConnectivityResult.wifi]);
  });
}
