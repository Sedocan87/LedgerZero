import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final connectivityStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectionStatusStream;
});
