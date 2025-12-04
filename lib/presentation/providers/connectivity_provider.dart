import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final connectivityStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectionStatusStream;
});
